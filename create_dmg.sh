#!/bin/bash
set -e

# ============================================================
#  PowerPulse DMG Installer Creator (Professional Edition)
#  Creates a polished DMG with background image, icon layout,
#  README, and drag-to-install experience.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PowerPulse"
APP_PATH="$SCRIPT_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-Installer"
DMG_PATH="$SCRIPT_DIR/$DMG_NAME.dmg"
DMG_RW="$SCRIPT_DIR/.${DMG_NAME}_rw.dmg"
VOLUME_NAME="$APP_NAME Installer"
TEMP_DIR="$SCRIPT_DIR/.dmg_staging"
BACKGROUND_SRC="$SCRIPT_DIR/.dmg_background.png"
README_SRC="$SCRIPT_DIR/.dmg_readme.txt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   PowerPulse DMG Creator (Pro)          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Pre-flight checks ──────────────────────────────
echo "🔍 Checking prerequisites..."

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: $APP_NAME.app not found!${NC}"
    echo "   Run: ./build_app.sh first"
    exit 1
fi

if [ ! -f "$BACKGROUND_SRC" ]; then
    echo "⚠️  Background image not found, generating..."
    python3 "$SCRIPT_DIR/gen_dmg_bg.py"
fi

if [ ! -f "$README_SRC" ]; then
    echo -e "${RED}❌ README.txt not found!${NC}"
    exit 1
fi

# ── Cleanup ─────────────────────────────────────────
echo "🧹 Cleaning up previous artifacts..."
rm -f "$DMG_PATH"
rm -f "$DMG_RW"
rm -rf "$TEMP_DIR"

# Unmount any existing volume with same name
if [ -d "/Volumes/$VOLUME_NAME" ]; then
    hdiutil detach "/Volumes/$VOLUME_NAME" -force 2>/dev/null || true
fi

# ── Stage files ─────────────────────────────────────
echo "📦 Staging files..."

mkdir -p "$TEMP_DIR/.background"
cp -R "$APP_PATH" "$TEMP_DIR/"
ln -s /Applications "$TEMP_DIR/Applications"
cp "$README_SRC" "$TEMP_DIR/README.txt"
cp "$BACKGROUND_SRC" "$TEMP_DIR/.background/dmg_background.png"

echo "   ✓ $APP_NAME.app"
echo "   ✓ Applications shortcut"
echo "   ✓ README.txt"
echo "   ✓ Background image"

# ── Create read-write DMG ───────────────────────────
echo ""
echo "💿 Creating DMG (read-write)..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov \
    -format UDRW \
    -fs "HFS+" \
    -size 20m \
    "$DMG_RW" > /dev/null

# ── Mount DMG ───────────────────────────────────────
echo "📌 Mounting DMG..."
DEVICE=$(hdiutil attach -readwrite -nobrowse -noautoopen "$DMG_RW" 2>&1 | awk '/Apple_HFS/ {print $1}')
MOUNT_POINT="/Volumes/$VOLUME_NAME"

if [ -z "$DEVICE" ]; then
    # Fallback: try to get the mount from volume name
    DEVICE=$(hdiutil attach -readwrite -nobrowse -noautoopen "$DMG_RW" 2>&1 | grep -o '/dev/disk[0-9]*s[0-9]*' | tail -1)
fi

echo "   Device: $DEVICE"
echo "   Mount:  $MOUNT_POINT"

# Wait for mount
sleep 1

# ── Set Finder layout via AppleScript ───────────────
echo "🎨 Setting up DMG layout..."

osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        -- Open the window
        open
        
        -- Wait for window
        delay 0.5
        
        -- Window properties
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 800, 600}
        
        -- View options
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        
        -- Background image (classic Mac path notation)
        set background picture of theViewOptions to file ".background:dmg_background.png"
        
        -- Position icons (Finder coordinates from top-left of content area)
        -- Background centers: App icon at (188,195), AppFolder at (408,185)
        set position of item "$APP_NAME.app" of container window to {188, 195}
        set position of item "Applications" of container window to {408, 185}
        set position of item "README.txt" of container window to {300, 360}
        
        -- Update and close/reopen to apply
        update without registering applications
        delay 1
        
        close
        delay 0.5
        open
        delay 1
        
        update without registering applications
        delay 1
    end tell
end tell
EOF

echo "   ✓ Window bounds: {200, 200, 800, 600}"
echo "   ✓ Icon size: 80px"
echo "   ✓ App icon position: {188, 195}"
echo "   ✓ Applications position: {408, 185}"
echo "   ✓ README position: {300, 360}"
echo "   ✓ Background image set"

# ── Set custom volume icon (optional) ───────────────
# Can be added later: cp volume_icon.icns "$MOUNT_POINT/.VolumeIcon.icns"

# ── Unmount ─────────────────────────────────────────
echo ""
echo "📤 Unmounting DMG..."
hdiutil detach "$DEVICE" -force 2>/dev/null || true

# Small delay to ensure clean unmount
sleep 1

# ── Convert to compressed read-only DMG ─────────────
echo "🗜️  Compressing DMG..."
hdiutil convert "$DMG_RW" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" > /dev/null

# ── Cleanup ─────────────────────────────────────────
rm -f "$DMG_RW"
rm -rf "$TEMP_DIR"

# ── Results ─────────────────────────────────────────
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ DMG Created Successfully!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  📍 Location: ${BLUE}$DMG_PATH${NC}"
echo -e "  📏 Size:     ${BLUE}$DMG_SIZE${NC}"
echo ""
echo "  📤 To share: Send $DMG_NAME.dmg to others."
echo "  📥 To test:  Double-click the DMG to preview."
echo ""
