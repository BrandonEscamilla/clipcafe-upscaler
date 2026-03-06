# ClipCafe Upscaler

[![Release](https://img.shields.io/github/v/release/BrandonEscamilla/clipcafe-upscaler?label=release)](https://github.com/BrandonEscamilla/clipcafe-upscaler/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon)-111827)](https://github.com/BrandonEscamilla/clipcafe-upscaler)
[![License](https://img.shields.io/badge/license-AGPLv3-2563eb)](./LICENSE)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-Support-ff5f5f?logo=ko-fi&logoColor=white)](https://ko-fi.com/brandon_escamilla)

Cinematic video upscaling for macOS, powered by Video2X.

## Support The Project

- Ko-fi: https://ko-fi.com/brandon_escamilla
- GitHub Sponsors: https://github.com/sponsors/BrandonEscamilla

## What You Get

- Drag-in style upload form
- Presets for speed vs quality
- Live status, logs, and progress
- One-click download of result
- First-run setup wizard if runtime is not auto-detected

## Attribution

ClipCafe Upscaler is based on Video2X and keeps explicit attribution.

- Upstream: https://github.com/k4yt3x/video2x
- Notices: [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)
- License: [LICENSE](./LICENSE)

## Quick Start (Dev)

```bash
cd clipcafe-upscaler
./run.command
```

Then open: `http://127.0.0.1:5001`

## Build A Clickable App

```bash
./scripts/generate_app_icon.sh
./build_app_bundle.sh
```

Outputs:

- `dist/ClipCafe Upscaler.app`
- `~/Applications/ClipCafe Upscaler.app`

## Build Portable Release Zip

```bash
./scripts/generate_app_icon.sh
./build_portable_release.sh
```

Outputs:

- `dist/portable_build/ClipCafe Upscaler.app`
- `dist/release/ClipCafe-Upscaler-macOS-arm64.zip`

Portable bundle includes:

- ClipCafe backend
- Bundled Python virtualenv
- Video2X runtime
- Video2X model files

## Optional Env Vars

- `CLIPCAFE_GITHUB_SPONSORS`
- `CLIPCAFE_KOFI`
- `VIDEO2X_RUNTIME_DIR`

## Notes

- macOS only.
- Processing happens locally on your machine.
- Performance/quality depends on chosen preset and GPU.
