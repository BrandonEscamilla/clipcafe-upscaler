# ClipCafe Upscaler

Cinematic video upscaling for macOS, powered by Video2X.

## Why this exists

ClipCafe Upscaler is a local-first wrapper around Video2X workflows:

- Upload a video in your browser
- Pick a quality preset
- Process locally on your Mac GPU
- Download the result

## Attribution

This project is built on top of Video2X and clearly credits that foundation.

- Upstream: https://github.com/k4yt3x/video2x
- License reference: see `THIRD_PARTY_NOTICES.md`

## Features

- Polished local UI
- Job queue + live logs + progress
- Downloadable output per job
- Support links (GitHub Sponsors / Ko-fi / Buy Me A Coffee)

## Quick Start (dev)

```bash
cd clipcafe-upscaler
./run.command
```

Open: `http://127.0.0.1:5001`

## Build a Clickable App (repo-linked)

```bash
./build_app_bundle.sh
```

Creates and installs:

- `dist/ClipCafe Upscaler.app`
- `~/Applications/ClipCafe Upscaler.app`

## Build a Portable One-Click Release (recommended for users)

```bash
./build_portable_release.sh
```

Creates:

- `dist/portable_build/ClipCafe Upscaler.app`
- `dist/release/ClipCafe-Upscaler-macOS-arm64.zip`

This bundle includes:

- ClipCafe backend
- Python virtual environment
- Video2X runtime folder

## Configure Support Links

Set these env vars before launch if you want custom links:

- `CLIPCAFE_GITHUB_SPONSORS`
- `CLIPCAFE_KOFI`
- `CLIPCAFE_BMC`

## Notes

- macOS only.
- This app performs processing locally.
- Runtime quality/speed depends on GPU and chosen preset.
