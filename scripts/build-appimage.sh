#!/usr/bin/env bash
# Empacota o build Linux (build/linux/x64/release/bundle) num AppImage.
#   scripts/build-appimage.sh 0.2.0
set -euo pipefail
version="$1"
appdir="build/AppDir"
rm -rf "$appdir" && mkdir -p "$appdir/app" dist
cp -r build/linux/x64/release/bundle/. "$appdir/app/"
cp packaging/linux/tostao.png "$appdir/tostao.png"
cp packaging/linux/tostao.desktop "$appdir/tostao.desktop"
cat > "$appdir/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/app/tostao" "$@"
RUN
chmod +x "$appdir/AppRun"

tool="build/appimagetool"
if [ ! -x "$tool" ]; then
  curl -fsSL -o "$tool" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
  chmod +x "$tool"
fi
ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$tool" "$appdir" "dist/Tostao_${version}_linux-x86_64.AppImage"
