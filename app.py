#!/usr/bin/env python3
import os
import platform
import re
import subprocess
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path

from flask import Flask, jsonify, redirect, render_template, request, send_file, url_for
from werkzeug.exceptions import RequestEntityTooLarge
from werkzeug.utils import secure_filename

APP_NAME = "ClipCafe Upscaler"
TAGLINE = "Cinematic Upscale, Powered by Video2X"

BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "uploads"
OUTPUT_DIR = BASE_DIR / "outputs"
TMP_DIR = BASE_DIR / "tmp"

for path in (UPLOAD_DIR, OUTPUT_DIR, TMP_DIR):
    path.mkdir(parents=True, exist_ok=True)

SUPPORT_LINKS = {
    "github_sponsors": os.getenv("CLIPCAFE_GITHUB_SPONSORS", "https://github.com/sponsors/BrandonEscamilla"),
    "kofi": os.getenv("CLIPCAFE_KOFI", "https://ko-fi.com/brandon_escamilla"),
    "buymeacoffee": os.getenv("CLIPCAFE_BMC", "https://buymeacoffee.com/"),
}

# Prefer bundled runtime when packaged. Fallback to local development path.
BUNDLED_RUNTIME = BASE_DIR.parent / "runtime" / "video2x-install"
LOCAL_DEV_RUNTIME = Path("/Users/brandonescamilla/Documents/code/video2x/build")



def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()



def _resolve_runtime_paths() -> tuple[Path, Path, Path]:
    runtime_override = os.getenv("VIDEO2X_RUNTIME_DIR")
    if runtime_override:
        runtime_dir = Path(runtime_override)
    elif BUNDLED_RUNTIME.exists():
        runtime_dir = BUNDLED_RUNTIME
    else:
        runtime_dir = LOCAL_DEV_RUNTIME

    bin_override = os.getenv("VIDEO2X_BIN")
    if bin_override:
        video2x_bin = Path(bin_override)
    else:
        install_bin = runtime_dir / "bin" / "video2x"
        build_bin = runtime_dir / "video2x"
        video2x_bin = install_bin if install_bin.exists() else build_bin

    workdir_override = os.getenv("VIDEO2X_WORKDIR")
    if workdir_override:
        workdir = Path(workdir_override)
    else:
        # Video2X expects model paths like models/realesrgan/... relative to cwd.
        if (runtime_dir / "models").exists():
            workdir = runtime_dir
        elif (runtime_dir.parent / "models").exists():
            workdir = runtime_dir.parent
        elif (BASE_DIR / "models").exists():
            workdir = BASE_DIR
        else:
            workdir = runtime_dir

    return runtime_dir, video2x_bin, workdir


VIDEO2X_RUNTIME_DIR, VIDEO2X_BIN, VIDEO2X_WORKDIR = _resolve_runtime_paths()

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 2 * 1024 * 1024 * 1024  # 2 GB

JOBS_LOCK = threading.Lock()
JOBS: dict[str, dict] = {}

FRAME_RE = re.compile(r"frame=(\d+)/(\d+)")

PRESETS = {
    "social_fast": {
        "label": "Social Fast 2x",
        "desc": "Best speed/quality balance for TikTok, Reels, Shorts.",
        "args": [
            "-p",
            "realesrgan",
            "--realesrgan-model",
            "realesr-animevideov3",
            "-s",
            "2",
            "-c",
            "libx264",
            "-e",
            "crf=20",
            "-e",
            "preset=veryfast",
        ],
    },
    "quality_2x": {
        "label": "Creator Quality 2x",
        "desc": "Sharper upscale while staying practical on Mac.",
        "args": [
            "-p",
            "realesrgan",
            "--realesrgan-model",
            "realesrgan-plus",
            "-s",
            "2",
            "-c",
            "libx264",
            "-e",
            "crf=18",
            "-e",
            "preset=medium",
        ],
    },
    "master_4x": {
        "label": "Master 4x (Slow)",
        "desc": "Maximum detail. Use for final renders, not quick drafts.",
        "args": [
            "-p",
            "realesrgan",
            "--realesrgan-model",
            "realesrgan-plus",
            "-s",
            "4",
            "-c",
            "libx265",
            "--pix-fmt",
            "yuv420p10le",
            "-e",
            "crf=17",
            "-e",
            "preset=slow",
        ],
    },
}



def _append_log(job_id: str, line: str) -> None:
    clean_line = line.rstrip()
    with JOBS_LOCK:
        job = JOBS[job_id]
        logs = job["logs"]
        logs.append(clean_line)
        if len(logs) > 600:
            del logs[:300]

        match = FRAME_RE.search(clean_line)
        if match:
            current = int(match.group(1))
            total = int(match.group(2))
            if total > 0:
                job["progress"] = round((current / total) * 100, 2)



def _run_video2x(job_id: str) -> None:
    with JOBS_LOCK:
        job = JOBS[job_id]
        cmd = job["cmd"]

    try:
        with JOBS_LOCK:
            JOBS[job_id]["status"] = "running"
            JOBS[job_id]["started_at"] = _utc_now_iso()

        env = os.environ.copy()
        env.setdefault("CPPFLAGS", "-I/opt/homebrew/opt/libomp/include")
        env.setdefault("LDFLAGS", "-L/opt/homebrew/opt/libomp/lib")
        env.setdefault("CXXFLAGS", "-Xpreprocessor -fopenmp")
        env.setdefault("OpenMP_ROOT", "/opt/homebrew/opt/libomp")

        candidate_lib_dirs = [
            VIDEO2X_RUNTIME_DIR / "lib",
            VIDEO2X_RUNTIME_DIR,
        ]
        for lib_dir in candidate_lib_dirs:
            if lib_dir.exists():
                current_dyld = env.get("DYLD_LIBRARY_PATH", "")
                prefix = str(lib_dir)
                env["DYLD_LIBRARY_PATH"] = (
                    f"{prefix}:{current_dyld}" if current_dyld else prefix
                )

        proc = subprocess.Popen(
            cmd,
            cwd=str(VIDEO2X_WORKDIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env=env,
        )

        assert proc.stdout is not None
        for line in proc.stdout:
            _append_log(job_id, line)
        return_code = proc.wait()

        with JOBS_LOCK:
            JOBS[job_id]["return_code"] = return_code
            JOBS[job_id]["finished_at"] = _utc_now_iso()
            JOBS[job_id]["status"] = "done" if return_code == 0 else "failed"
            JOBS[job_id]["progress"] = 100.0 if return_code == 0 else JOBS[job_id]["progress"]
    except Exception as exc:
        with JOBS_LOCK:
            JOBS[job_id]["status"] = "failed"
            JOBS[job_id]["error"] = str(exc)
            JOBS[job_id]["finished_at"] = _utc_now_iso()


@app.get("/")
def index():
    runtime_ready = VIDEO2X_BIN.exists()
    runtime_hint = str(VIDEO2X_BIN)
    return render_template(
        "index.html",
        app_name=APP_NAME,
        tagline=TAGLINE,
        presets=PRESETS,
        is_macos=(platform.system() == "Darwin"),
        runtime_ready=runtime_ready,
        runtime_hint=runtime_hint,
        error=request.args.get("error", ""),
        support_links=SUPPORT_LINKS,
    )


@app.get("/health")
def health():
    return jsonify({"ok": True, "app": APP_NAME, "runtime": str(VIDEO2X_BIN)})


@app.post("/start")
def start_job():
    try:
        if not VIDEO2X_BIN.exists():
            return redirect(
                url_for(
                    "index",
                    error=f"Runtime missing. Expected: {VIDEO2X_BIN}",
                )
            )

        uploaded = request.files.get("video")
        if not uploaded or uploaded.filename == "":
            return redirect(url_for("index", error="Please upload a video file."))

        preset = request.form.get("preset", "social_fast")
        if preset not in PRESETS:
            return redirect(url_for("index", error="Invalid preset selected."))

        device = request.form.get("device", "0").strip() or "0"
        copy_audio = request.form.get("copy_audio") == "on"

        safe_name = secure_filename(uploaded.filename)
        if not safe_name:
            return redirect(url_for("index", error="Invalid file name."))

        stem = Path(safe_name).stem or "video"
        job_id = uuid.uuid4().hex[:12]

        input_path = UPLOAD_DIR / f"{job_id}_{safe_name}"
        output_path = OUTPUT_DIR / f"{stem}_{preset}_{job_id}.mp4"
        uploaded.save(input_path)

        cmd = [
            str(VIDEO2X_BIN),
            "--no-progress",
            "-i",
            str(input_path),
            "-o",
            str(output_path),
            *PRESETS[preset]["args"],
            "-d",
            device,
        ]
        if not copy_audio:
            cmd.append("--no-copy-audio-streams")

        with JOBS_LOCK:
            JOBS[job_id] = {
                "id": job_id,
                "status": "queued",
                "preset": preset,
                "input_path": str(input_path),
                "output_path": str(output_path),
                "cmd": cmd,
                "logs": [],
                "progress": 0.0,
                "created_at": _utc_now_iso(),
            }

        thread = threading.Thread(target=_run_video2x, args=(job_id,), daemon=True)
        thread.start()
        return redirect(url_for("job_page", job_id=job_id))
    except Exception as exc:
        app.logger.exception("Failed to start conversion")
        return redirect(url_for("index", error=f"Start failed: {exc}"))


@app.get("/job/<job_id>")
def job_page(job_id: str):
    with JOBS_LOCK:
        if job_id not in JOBS:
            return "Job not found.", 404
    return render_template("job.html", app_name=APP_NAME, job_id=job_id, support_links=SUPPORT_LINKS)


@app.get("/api/job/<job_id>")
def job_status(job_id: str):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if not job:
            return jsonify({"error": "not found"}), 404

        output_exists = Path(job["output_path"]).exists()
        size = Path(job["output_path"]).stat().st_size if output_exists else 0
        return jsonify(
            {
                "id": job["id"],
                "status": job["status"],
                "preset": job["preset"],
                "output_path": job["output_path"],
                "output_exists": output_exists,
                "output_size": size,
                "progress": job.get("progress", 0.0),
                "return_code": job.get("return_code"),
                "error": job.get("error"),
                "logs": job["logs"][-120:],
            }
        )


@app.get("/download/<job_id>")
def download(job_id: str):
    with JOBS_LOCK:
        job = JOBS.get(job_id)
        if not job:
            return "Job not found.", 404
        output_path = Path(job["output_path"])

    if not output_path.exists():
        return "Output not ready yet.", 404

    return send_file(output_path, as_attachment=True)


@app.errorhandler(RequestEntityTooLarge)
def file_too_large(_exc):
    return redirect(url_for("index", error="File too large (max 2 GB)."))


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5001, debug=False)
