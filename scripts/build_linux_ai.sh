#!/usr/bin/env bash
set -euo pipefail

# ========= CONFIG =========
APP_NAME="polaris_launcher"
APP_DISPLAY_NAME="Polaris Launcher"
ICON_FILE="polaris_launcher.png"
CATEGORY="Utility"

FLUTTER_BUNDLE="build/linux/x64/release/bundle"
APPDIR="AppDir"

LINUXDEPLOY="./scripts/linuxdeploy-x86_64.appimage"
APPIMAGETOOL="./scripts/appimagetool-x86_64.appimage"
# ==========================

echo "▶ Building Flutter app"
#flutter build linux --release

echo "▶ Verifying executable"
file "${FLUTTER_BUNDLE}/${APP_NAME}" | grep -q ELF

echo "▶ Cleaning AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}"

echo "▶ Creating desktop file"
cat > "${APP_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${APP_DISPLAY_NAME}
Exec=${APP_NAME}
Icon=${APP_NAME}
Categories=${CATEGORY};
EOF

chmod +x "${LINUXDEPLOY}" "${APPIMAGETOOL}"

export NO_STRIP=1

echo "▶ Running linuxdeploy (executable only)"
"${LINUXDEPLOY}" \
  --appdir "${APPDIR}" \
  --executable "${FLUTTER_BUNDLE}/${APP_NAME}" \
  --desktop-file "${APP_NAME}.desktop" \
  --icon-file "${ICON_FILE}"

echo "▶ Copying Flutter runtime files"
cp -r "${FLUTTER_BUNDLE}/data" "${APPDIR}/usr/bin/"
mkdir -p "${APPDIR}/usr/bin/lib"
for lib in ${FLUTTER_BUNDLE}/lib/*.so; do
    cp -r $lib "${APPDIR}/usr/bin/lib"
done


echo "▶ Building AppImage"
"${LINUXDEPLOY}" --appdir "${APPDIR}" --output appimage

echo "✔ AppImage build complete"
ls -lh *.AppImage
