#!/bin/zsh
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ClipCafe Upscaler"
BUNDLE_NAME="$APP_NAME.app"
DIST_DIR="$APP_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
BUILD_DIR="$DIST_DIR/portable_build"
APP_BUNDLE="$BUILD_DIR/$BUNDLE_NAME"
RUNTIME_SRC_DEFAULT="$HOME/Documents/code/video2x/build/video2x-install"
RUNTIME_SRC="${VIDEO2X_SOURCE_RUNTIME:-$RUNTIME_SRC_DEFAULT}"
RUNTIME_DEST="$APP_BUNDLE/Contents/Resources/runtime/video2x-install"
BACKEND_DEST="$APP_BUNDLE/Contents/Resources/backend"
MODEL_SRC_DEFAULT="$HOME/Documents/code/video2x/models"
MODEL_SRC="${VIDEO2X_MODEL_SOURCE:-$MODEL_SRC_DEFAULT}"

if [[ ! -d "$RUNTIME_SRC" ]]; then
  echo "Missing runtime source: $RUNTIME_SRC"
  echo "Set VIDEO2X_SOURCE_RUNTIME to your built video2x-install path."
  exit 1
fi
if [[ ! -d "$MODEL_SRC" ]]; then
  echo "Missing model source: $MODEL_SRC"
  echo "Set VIDEO2X_MODEL_SOURCE to your Video2X models folder."
  exit 1
fi

mkdir -p "$BUILD_DIR" "$RELEASE_DIR"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

# Copy backend app
mkdir -p "$BACKEND_DEST"
cp "$APP_DIR/app.py" "$BACKEND_DEST/"
cp "$APP_DIR/requirements.txt" "$BACKEND_DEST/"
cp "$APP_DIR/start_webapp.sh" "$BACKEND_DEST/"
cp "$APP_DIR/stop_webapp.sh" "$BACKEND_DEST/"
cp -R "$APP_DIR/templates" "$BACKEND_DEST/"
cp -R "$APP_DIR/static" "$BACKEND_DEST/"
mkdir -p "$BACKEND_DEST/uploads" "$BACKEND_DEST/outputs" "$BACKEND_DEST/tmp"

# Create bundled Python env for truly one-click local run.
python3 -m venv "$BACKEND_DEST/.venv"
source "$BACKEND_DEST/.venv/bin/activate"
pip install -r "$BACKEND_DEST/requirements.txt"

# Copy runtime
mkdir -p "$(dirname "$RUNTIME_DEST")"
cp -R "$RUNTIME_SRC" "$RUNTIME_DEST"
cp -R "$MODEL_SRC" "$APP_BUNDLE/Contents/Resources/runtime/models"

# Ensure install binary and main dylib can resolve local runtime libs.
install_name_tool -add_rpath "@executable_path/../lib" "$RUNTIME_DEST/bin/video2x" 2>/dev/null || true
install_name_tool -add_rpath "@loader_path" "$RUNTIME_DEST/lib/libvideo2x.dylib" 2>/dev/null || true

# Optional copy for Vulkan loader to reduce runtime warnings on some setups.
cp /opt/homebrew/opt/vulkan-loader/lib/libvulkan.1.dylib "$RUNTIME_DEST/lib/" 2>/dev/null || true

# Native launcher executable in app bundle.
cat > "$APP_BUNDLE/Contents/MacOS/clipcafe-launch" <<'EOF'
#!/bin/zsh
set -euo pipefail

CONTENTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$CONTENTS_DIR/Resources/backend"
RUNTIME_DIR="$CONTENTS_DIR/Resources/runtime/video2x-install"

export VIDEO2X_RUNTIME_DIR="$RUNTIME_DIR"
cd "$BACKEND_DIR"
exec "$BACKEND_DIR/start_webapp.sh"
EOF
chmod +x "$APP_BUNDLE/Contents/MacOS/clipcafe-launch"

# Basic metadata
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>clipcafe-launch</string>
  <key>CFBundleIdentifier</key>
  <string>com.brandonescamilla.clipcafe</string>
  <key>CFBundleVersion</key>
  <string>0.1.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.video</string>
</dict>
</plist>
EOF

# Ad-hoc sign to reduce local launch friction.
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

# Zip artifact
ZIP_PATH="$RELEASE_DIR/ClipCafe-Upscaler-macOS-arm64.zip"
rm -f "$ZIP_PATH"
(
  cd "$BUILD_DIR"
  ditto -c -k --sequesterRsrc --keepParent "$BUNDLE_NAME" "$ZIP_PATH"
)

echo "Portable app created: $APP_BUNDLE"
echo "Release zip: $ZIP_PATH"
