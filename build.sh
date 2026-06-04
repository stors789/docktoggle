#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCES_DIR="$PROJECT_DIR/Sources"
RESOURCES_DIR="$PROJECT_DIR/Resources"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="DockToggle"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE="$BUILD_DIR/$APP_NAME"

ARCH="$(uname -m)"
SDK_PATH="$(xcrun --show-sdk-path --sdk macosx 2>/dev/null || echo "")"

echo "=== Cleaning previous build ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "=== Compiling DockToggle ==="
echo "Architecture: $ARCH"
echo "SDK: $SDK_PATH"

SWIFT_FILES=$(find "$SOURCES_DIR" -name "*.swift" | sort)

if [ -n "$SDK_PATH" ]; then
    SDK_FLAGS="-sdk $SDK_PATH"
else
    SDK_FLAGS=""
fi

swiftc \
    -o "$EXECUTABLE" \
    $SDK_FLAGS \
    -target "$ARCH-apple-macos14.0" \
    -framework SwiftUI \
    -framework AppKit \
    -framework ApplicationServices \
    -framework ServiceManagement \
    -framework CoreGraphics \
    $SWIFT_FILES

echo "=== Creating app bundle ==="
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$RESOURCES_DIR/DockToggle.icns" "$APP_BUNDLE/Contents/Resources/DockToggle.icns"

echo -n 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "=== Code signing (ad-hoc) ==="
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 || true

echo ""
echo "=== Build complete ==="
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run: open '$APP_BUNDLE'"
echo ""
echo "Note: First launch will request Accessibility and Input Monitoring permissions."
echo "You may need to grant them in System Preferences > Privacy & Security."
