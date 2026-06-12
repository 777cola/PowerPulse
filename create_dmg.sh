#!/bin/bash
set -e

# PowerPulse DMG Installer Creator
# Creates a distributable DMG with drag-to-install

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PowerPulse"
APP_PATH="$PROJECT_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-Installer"
DMG_PATH="$PROJECT_DIR/$DMG_NAME.dmg"
VOLUME_NAME="$APP_NAME Installer"
TEMP_DIR="$PROJECT_DIR/.dmg_temp"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: $APP_NAME.app not found!"
    echo "   Run ./build_app.sh first to build the app."
    exit 1
fi

echo "📦 Creating DMG installer for $APP_NAME..."

# Clean up previous artifacts
rm -f "$DMG_PATH"
rm -rf "$TEMP_DIR"

# Create temporary directory structure
mkdir -p "$TEMP_DIR"

# Copy app to temp directory
echo "   Copying $APP_NAME.app..."
cp -R "$APP_PATH" "$TEMP_DIR/"

# Create symbolic link to Applications folder
echo "   Creating Applications shortcut..."
ln -s /Applications "$TEMP_DIR/Applications"

# Create DMG
echo "   Building DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Get file size
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo "✅ DMG installer created successfully!"
echo "📍 Location: $DMG_PATH"
echo "📏 Size: $DMG_SIZE"
echo ""
echo "📤 To share: Send the $DMG_NAME.dmg file to others."
echo "📥 To install: Recipients double-click the DMG, then drag $APP_NAME to Applications."
