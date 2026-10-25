#!/bin/bash
# 一条命令出 .app。不依赖 Xcode：CLT 的 swiftc 直接编译
# （SwiftUI 在这台机器上编译不了 —— 没有 Xcode 就缺 SwiftUIMacros 插件，本版已改纯 AppKit）
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="PowerPulse"

# 签名身份：默认 ad-hoc；要分发就传 Developer ID
#   IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="powerpulse" ./build_app.sh
IDENTITY="${IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APP_DIR="$PROJECT_DIR/$APP_NAME.app"
VERSION="${VERSION:-2.1.6}"
BUILD_NUM="${BUILD_NUM:-216}"

cd "$PROJECT_DIR"

echo "🔨 编译主程序 $APP_NAME $VERSION ..."
mkdir -p build
xcrun --sdk macosx swiftc -swift-version 5 -O -whole-module-optimization \
  -target arm64-apple-macos14.0 \
  -framework AppKit -framework IOKit -framework Metal \
  -framework UserNotifications -framework ServiceManagement -framework WidgetKit \
  -lsqlite3 \
  -o "build/$APP_NAME" \
  Sources/*.swift SourcesWidget/WidgetSnapshot.swift

echo "📦 打包 .app ..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "build/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>PowerPulse</string>
    <key>CFBundleDisplayName</key><string>PowerPulse</string>
    <key>CFBundleIdentifier</key><string>com.autumnpants.powerpulse</string>
    <key>CFBundleVersion</key><string>${BUILD_NUM}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>PowerPulse</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHumanReadableCopyright</key><string>MIT © AutumnPants</string>
</dict>
</plist>
EOF

if [ -f assets/AppIcon.icns ]; then
  cp assets/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# ad-hoc 签名：本机运行足够；对外分发仍会被 Gatekeeper 拦，README 说明右键打开
# 注意不要用 --deep：那会把已带 entitlement 的 appex 重新签一遍、把 entitlement 洗掉
cat > "build/app.entitlements" <<AENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.application-groups</key><array><string>group.com.autumnpants.powerpulse</string></array>
</dict></plist>
AENT
# 外层签名放到最后：必须等内容全部就位（尤其是 appex），否则签名封不住插件

# ---------- 桌面小组件（WidgetKit） ----------
WIDGET_NAME="PowerPulseWidget"
EXT_DIR="$APP_DIR/Contents/PlugIns/$WIDGET_NAME.appex"
if [ -d SourcesWidget ]; then
  echo "🧩 编译小组件 $WIDGET_NAME ..."
  mkdir -p build/widget
  xcrun --sdk macosx swiftc -swift-version 5 -O -parse-as-library \
    -target arm64-apple-macos14.0 \
    -framework SwiftUI -framework WidgetKit \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -o "build/widget/$WIDGET_NAME" \
    SourcesWidget/*.swift
  mkdir -p "$EXT_DIR/Contents/MacOS"
  cp "build/widget/$WIDGET_NAME" "$EXT_DIR/Contents/MacOS/$WIDGET_NAME"
  cat > "$EXT_DIR/Contents/Info.plist" <<WEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$WIDGET_NAME</string>
    <key>CFBundleDisplayName</key><string>PowerPulse</string>
    <key>CFBundleIdentifier</key><string>com.autumnpants.powerpulse.widget</string>
    <key>CFBundleVersion</key><string>${BUILD_NUM}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundlePackageType</key><string>XPC!</string>
    <key>CFBundleExecutable</key><string>$WIDGET_NAME</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
WEOF
  echo -n "XPC!????" > "$EXT_DIR/Contents/PkgInfo"

  # 关键：widget 扩展必须带 app-sandbox entitlement，否则 pluginkit 根本不收录（ad-hoc 签名也可以）
  cat > "build/widget.entitlements" <<WENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.application-groups</key><array><string>group.com.autumnpants.powerpulse</string></array>
</dict></plist>
WENT
  if [ "$IDENTITY" = "-" ]; then
    codesign --force --sign - --entitlements "build/widget.entitlements" "$EXT_DIR" >/dev/null 2>&1 || echo "⚠️  appex 签名失败"
  else
    codesign --force --options runtime --timestamp --sign "$IDENTITY" \
      --entitlements "build/widget.entitlements" "$EXT_DIR" || { echo "❌ appex 签名失败"; exit 1; }
  fi
fi

# ---------- 签名外层（顺序：先 appex 后 app，且不要 --deep） ----------
if [ "$IDENTITY" = "-" ]; then
  codesign --force --sign - --entitlements "build/app.entitlements" "$APP_DIR" >/dev/null 2>&1 \
    || echo "⚠️  ad-hoc 签名失败（不影响本机运行）"
  echo "🔏 已用 ad-hoc 签名（对外分发仍会被 Gatekeeper 拦）"
else
  codesign --force --options runtime --timestamp --sign "$IDENTITY" \
    --entitlements "build/app.entitlements" "$APP_DIR" || { echo "❌ app 签名失败"; exit 1; }
  echo "🔏 已用 Developer ID 签名：$IDENTITY"
  codesign --verify --strict --verbose=2 "$APP_DIR" 2>&1 | tail -2
fi

# ---------- 可选：公证 ----------
if [ -n "$NOTARY_PROFILE" ]; then
  echo "📮 提交公证（profile: $NOTARY_PROFILE）..."
  rm -f build/notarize.zip
  ditto -c -k --keepParent "$APP_DIR" build/notarize.zip
  xcrun notarytool submit build/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait \
    || { echo "❌ 公证失败"; exit 1; }
  xcrun stapler staple "$APP_DIR" || { echo "❌ stapler 失败"; exit 1; }
  spctl -a -vvv -t install "$APP_DIR" 2>&1 | tail -2
  echo "✅ 公证并装订完成"
fi

echo ""
echo "✅ 完成：$APP_DIR"
echo "   安装：cp -R \"$APP_DIR\" /Applications/ && open /Applications/$APP_NAME.app"
