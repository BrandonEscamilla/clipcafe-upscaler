#!/bin/zsh
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClipCafe Upscaler.app"
DIST_DIR="$APP_DIR/dist"
TARGET_APP="$DIST_DIR/$APP_NAME"
APPLICATIONS_APP="$HOME/Applications/$APP_NAME"
LAUNCHER="$APP_DIR/start_webapp.sh"

mkdir -p "$DIST_DIR" "$HOME/Applications"
chmod +x "$LAUNCHER" "$APP_DIR/stop_webapp.sh" "$APP_DIR/run.command"

osacompile -o "$TARGET_APP" <<EOF
on run
  set launcherPath to POSIX file "$LAUNCHER"
  set cmd to quoted form of POSIX path of launcherPath & " >/dev/null 2>&1 &"
  do shell script cmd
end run
EOF

cp -R "$TARGET_APP" "$APPLICATIONS_APP"
echo "Created: $TARGET_APP"
echo "Installed: $APPLICATIONS_APP"
