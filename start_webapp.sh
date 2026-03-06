#!/bin/zsh
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$APP_DIR/tmp/webapp.pid"
LOG_FILE="$APP_DIR/tmp/webapp.log"
URL="http://127.0.0.1:5001"
PORT="5001"

# Runtime location priority:
# 1) env VIDEO2X_RUNTIME_DIR
# 2) bundled runtime in ../runtime/video2x-install (for packaged .app)
# 3) local dev build path
DEFAULT_RUNTIME="$HOME/Documents/code/video2x/build"
BUNDLED_RUNTIME="$(cd "$APP_DIR/.." 2>/dev/null && pwd)/runtime/video2x-install"
RUNTIME_DIR="${VIDEO2X_RUNTIME_DIR:-}"
if [[ -z "$RUNTIME_DIR" ]]; then
  if [[ -d "$BUNDLED_RUNTIME" ]]; then
    RUNTIME_DIR="$BUNDLED_RUNTIME"
  else
    RUNTIME_DIR="$DEFAULT_RUNTIME"
  fi
fi

mkdir -p "$APP_DIR/tmp"

port_has_listener() {
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1
}

is_running() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "${pid}" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

if ! port_has_listener && ! is_running; then
  cd "$APP_DIR"

  if [[ ! -d ".venv" ]]; then
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
  else
    source .venv/bin/activate
    python - <<'PY'
import importlib.util, subprocess, sys
if not importlib.util.find_spec("flask"):
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
PY
  fi

  export VIDEO2X_RUNTIME_DIR="$RUNTIME_DIR"
  nohup "$APP_DIR/.venv/bin/python" "$APP_DIR/app.py" >> "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1
fi

open "$URL"
