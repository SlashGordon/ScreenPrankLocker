#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ScreenPrankLocker"
BUNDLE_ID="com.pranklocker.screenpranklocker"
VERSION="1.0.0"
UNIVERSAL_DIR=".build/universal"
APP_DIR="build/${APP_NAME}.app"
PKG_DIR="build"

create_plist() {
    cat > "$1" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Screen Prank Locker</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>Screen Prank Locker uses the camera to photograph anyone who tries to use your locked computer.</string>
    <key>LSUIElement</key>
    <false/>
</dict>
</plist>
PLIST
}

cmd_build() {
    echo "==> Building for arm64 (Apple Silicon)..."
    swift build -c release --arch arm64

    echo "==> Building for x86_64 (Intel)..."
    swift build -c release --arch x86_64

    echo "==> Stitching together Universal Binary..."
    local ARM_BIN_PATH=$(swift build -c release --arch arm64 --show-bin-path)
    local X86_BIN_PATH=$(swift build -c release --arch x86_64 --show-bin-path)

    mkdir -p "${UNIVERSAL_DIR}"
    
    # We manually use lipo to guarantee the fat binary is created exactly where we want it
    lipo -create -output "${UNIVERSAL_DIR}/${APP_NAME}" "${ARM_BIN_PATH}/${APP_NAME}" "${X86_BIN_PATH}/${APP_NAME}"
    
    echo "==> Universal binary created at ${UNIVERSAL_DIR}/${APP_NAME}"
}

cmd_app() {
    cmd_build
    echo "==> Creating ${APP_NAME}.app bundle"
    rm -rf "${APP_DIR}"
    mkdir -p "${APP_DIR}/Contents/MacOS"
    mkdir -p "${APP_DIR}/Contents/Resources"

    # Copy the manually created fat executable
    cp "${UNIVERSAL_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/"

    # Resources are architecture-independent, so we safely grab them from the arm64 build
    local ARM_BIN_PATH=$(swift build -c release --arch arm64 --show-bin-path)
    # Copy any resource bundle produced by SwiftPM (e.g. ScreenPrankLocker_ScreenPrankLocker.bundle)
    for bundle in "${ARM_BIN_PATH}"/${APP_NAME}_*.bundle; do
        if [ -d "$bundle" ]; then
            cp -R "$bundle" "${APP_DIR}/Contents/Resources/"
            # Also place a copy at the app root for resource accessors that look there
            cp -R "$bundle" "${APP_DIR}/"
        fi
    done

    # Also copy the source Resources directory as a fallback so assets are always available
    if [ -d "${SCRIPT_DIR}/Sources/ScreenPrankLocker/Resources" ]; then
        cp -R "${SCRIPT_DIR}/Sources/ScreenPrankLocker/Resources" "${APP_DIR}/Contents/Resources/"
    fi

    # Copy app icon
    if [ -f "${SCRIPT_DIR}/AppIcon.icns" ]; then
        cp "${SCRIPT_DIR}/AppIcon.icns" "${APP_DIR}/Contents/Resources/"
    fi

    # Create Info.plist
    create_plist "${APP_DIR}/Contents/Info.plist"

    echo "==> ${APP_DIR} created"
}

cmd_pkg() {
    cmd_app
    echo "==> Building installer package"
    mkdir -p "${PKG_DIR}"
    pkgbuild \
        --root "${APP_DIR}" \
        --identifier "${BUNDLE_ID}" \
        --version "${VERSION}" \
        --install-location "/Applications/${APP_NAME}.app" \
        "${PKG_DIR}/${APP_NAME}-${VERSION}.pkg"
    echo "==> ${PKG_DIR}/${APP_NAME}-${VERSION}.pkg created"
}

cmd_dmg() {
    cmd_app
    echo "==> Building DMG"
    mkdir -p "${PKG_DIR}"
    local DMG_TMP="${PKG_DIR}/dmg_tmp"
    rm -rf "${DMG_TMP}"
    mkdir -p "${DMG_TMP}"
    cp -R "${APP_DIR}" "${DMG_TMP}/"
    ln -s /Applications "${DMG_TMP}/Applications"
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_TMP}" \
        -ov -format UDZO \
        "${PKG_DIR}/${APP_NAME}-${VERSION}.dmg"
    rm -rf "${DMG_TMP}"
    echo "==> ${PKG_DIR}/${APP_NAME}-${VERSION}.dmg created"
}

cmd_install() {
    cmd_app
    echo "==> Installing to /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "${APP_DIR}" "/Applications/${APP_NAME}.app"
    echo "==> Installed to /Applications/${APP_NAME}.app"
}

cmd_test() {
    swift test
}

cmd_run() {
    cmd_build
    "${UNIVERSAL_DIR}/${APP_NAME}"
}

cmd_clean() {
    swift package clean
    rm -rf build/
    rm -rf "${UNIVERSAL_DIR}"
}

cmd_help() {
    echo "Usage: ./build.sh <command>"
    echo ""
    echo "Commands:"
    echo "  build    Build universal release binary"
    echo "  app      Create .app bundle"
    echo "  pkg      Create .pkg installer"
    echo "  dmg      Create .dmg disk image"
    echo "  install  Install to /Applications"
    echo "  test     Run tests"
    echo "  run      Build and run"
    echo "  clean    Remove build artifacts"
    echo "  help     Show this help"
}

case "${1:-help}" in
    build)   cmd_build ;;
    app)     cmd_app ;;
    pkg)     cmd_pkg ;;
    dmg)     cmd_dmg ;;
    install) cmd_install ;;
    test)    cmd_test ;;
    run)     cmd_run ;;
    clean)   cmd_clean ;;
    help)    cmd_help ;;
    *)       echo "Unknown command: $1"; cmd_help; exit 1 ;;
esac