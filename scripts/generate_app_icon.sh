#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/assets"
ICONSET="$ASSETS/ClipCafe.iconset"
BASE="$ASSETS/ClipCafe-1024.png"
ICNS="$ASSETS/ClipCafe.icns"

mkdir -p "$ASSETS"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

ffmpeg -y -f lavfi -i "color=c=#0f766e:s=1024x1024,format=rgba" \
  -vf "drawbox=x=86:y=86:w=852:h=852:color=#0b4f48@1:t=fill,drawbox=x=86:y=86:w=852:h=852:color=#c6f6dd@0.38:t=8,drawbox=x=248:y=248:w=528:h=528:color=#34d399@0.92:t=fill,drawbox=x=304:y=304:w=416:h=416:color=#0f766e@1:t=fill,drawbox=x=448:y=354:w=128:h=316:color=#ecfdf5@1:t=fill,drawbox=x=354:y=448:w=316:h=128:color=#ecfdf5@1:t=fill" \
  -frames:v 1 "$BASE" >/dev/null 2>&1

make_icon() {
  local size="$1"
  local out1="$ICONSET/icon_${size}x${size}.png"
  local out2="$ICONSET/icon_${size}x${size}@2x.png"
  sips -z "$size" "$size" "$BASE" --out "$out1" >/dev/null
  local size2=$((size * 2))
  sips -z "$size2" "$size2" "$BASE" --out "$out2" >/dev/null
}

make_icon 16
make_icon 32
make_icon 128
make_icon 256
make_icon 512

iconutil -c icns "$ICONSET" -o "$ICNS"
echo "Generated icon: $ICNS"
