#!/usr/bin/env bash
# PowerPulse 一行安装
#
#   curl -fsSL https://raw.githubusercontent.com/777cola/PowerPulse/main/install.sh | bash
#
# 为什么不用浏览器下载：浏览器会给文件打 com.apple.quarantine 标记，
# 没公证的 App 第一次打开就会被 Gatekeeper 拦。curl 下载不带这个标记，
# 装完直接就能开，一次弹窗都没有。

set -euo pipefail

REPO="777cola/PowerPulse"
APP="PowerPulse.app"
DEST="/Applications/$APP"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

say() { printf '\033[1m%s\033[0m\n' "$*"; }

say "→ 查询最新版本"
URL="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' \
  | head -1 | cut -d'"' -f4)"

if [ -z "$URL" ]; then
  echo "取不到下载地址。手动安装：https://github.com/$REPO/releases/latest" >&2
  exit 1
fi

say "→ 下载 $(basename "$URL")"
curl -fL --progress-bar "$URL" -o "$TMP/p.zip"

say "→ 解压"
ditto -x -k "$TMP/p.zip" "$TMP/out"
SRC="$(find "$TMP/out" -maxdepth 2 -name "$APP" -type d | head -1)"
[ -n "$SRC" ] || { echo "压缩包里没找到 $APP" >&2; exit 1; }

if [ -d "$DEST" ]; then
  say "→ 关掉正在运行的旧版本"
  osascript -e 'quit app "PowerPulse"' 2>/dev/null || true
  sleep 1
  rm -rf "$DEST"
fi

say "→ 安装到 /Applications"
cp -R "$SRC" "$DEST"
# curl 下载本来就没有隔离标记，这里只是兜底（例如被代理软件重新打过标）
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

VER="$(defaults read "$DEST/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "?")"
say "✓ PowerPulse $VER 已安装，正在启动"
open "$DEST"
