#!/bin/zsh
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClipCafe Upscaler.app"
DIST_DIR="$APP_DIR/dist"
TARGET_APP="$DIST_DIR/$APP_NAME"
APPLICATIONS_APP="$HOME/Applications/$APP_NAME"
LAUNCHER="$APP_DIR/start_webapp.sh"
ICON_SRC="$APP_DIR/assets/ClipCafe.icns"

mkdir -p "$DIST_DIR" "$HOME/Applications"
chmod +x "$LAUNCHER" "$APP_DIR/stop_webapp.sh" "$APP_DIR/run.command"

if [[ ! -f "$ICON_SRC" && -x "$APP_DIR/scripts/generate_app_icon.sh" ]]; then
  "$APP_DIR/scripts/generate_app_icon.sh"
fi

osacompile -o "$TARGET_APP" <<EOF
on run
  set launcherPath to POSIX file "$LAUNCHER"
  set cmd to quoted form of POSIX path of launcherPath & " >/dev/null 2>&1 &"
  do shell script cmd
end run
EOF

if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$TARGET_APP/Contents/Resources/ClipCafe.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile ClipCafe.icns" "$TARGET_APP/Contents/Info.plist" >/dev/null 2>&1 || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string ClipCafe.icns" "$TARGET_APP/Contents/Info.plist"
fi

rm -rf "$APPLICATIONS_APP"
cp -R "$TARGET_APP" "$APPLICATIONS_APP"
echo "Created: $TARGET_APP"
echo "Installed: $APPLICATIONS_APP"
