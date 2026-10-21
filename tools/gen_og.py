#!/usr/bin/env python3
"""生成 og:image（1200×630）。用真实界面截图 + 品牌字，不画假 UI。"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import pathlib

def app_version() -> str:
    """版本号只认 build_app.sh 里那一处，别到处抄。"""
    import re, pathlib
    src = (pathlib.Path(__file__).resolve().parent.parent / "build_app.sh").read_text(encoding="utf-8")
    m = re.search(r'VERSION="\$\{VERSION:-([^}]+)\}', src)
    return m.group(1) if m else "0.0.0"


DOCS = pathlib.Path(__file__).resolve().parent.parent / "docs"
W, H = 1200, 630
PAPER = (245, 248, 252)
INK = (11, 26, 43)
BLUE = (26, 75, 140)
MUTED = (100, 116, 139)
ORANGE = (232, 108, 0)

# 本机没有 PingFang.ttc（macOS 新版挪走了），用冬青黑体：idx 0 = W3，idx 2 = W6
CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"

def font(size, bold=False):
    try:
        return ImageFont.truetype(CN, size, index=2 if bold else 0)
    except Exception:
        try:
            return ImageFont.truetype(CN, size)
        except Exception:
            return ImageFont.load_default()

img = Image.new("RGB", (W, H), PAPER)
d = ImageDraw.Draw(img)

# 背景：右上角一团很淡的蓝光
glow = Image.new("L", (W, H), 0)
gd = ImageDraw.Draw(glow)
gd.ellipse((640, -260, 1400, 420), fill=52)
glow = glow.filter(ImageFilter.GaussianBlur(90))
img.paste(Image.new("RGB", (W, H), (222, 234, 248)), (0, 0), glow)
d = ImageDraw.Draw(img)

# 细网格线，弱到几乎看不见
for x in range(0, W, 60):
    d.line([(x, 0), (x, H)], fill=(233, 240, 249))
for y in range(0, H, 60):
    d.line([(0, y), (W, y)], fill=(233, 240, 249))

# 左侧文案
icon = Image.open(DOCS / "img" / "appicon.png").convert("RGBA").resize((46, 46), Image.LANCZOS)
img.paste(icon, (72, 64), icon)
d.text((132, 74), "PowerPulse", font=font(27, True), fill=INK)
d.text((132, 108), f"macOS 菜单栏电源监控 · {app_version()}", font=font(15), fill=MUTED)

d.text((72, 196), "菜单栏里，", font=font(58, True), fill=INK)
d.text((72, 268), "看清每一瓦。", font=font(58, True), fill=BLUE)
d.text((72, 368), "墙插、系统、电池三笔功率", font=font(21), fill=MUTED)
d.text((72, 400), "必须能互相加减。", font=font(21), fill=MUTED)

for i, t in enumerate(["MIT 开源", "每秒采样", "macOS 14+"]):
    x = 72 + i * 132
    d.rounded_rectangle((x, 470, x + 118, 506), 18, fill=(255, 255, 255), outline=(226, 234, 244))
    d.ellipse((x + 13, 483, x + 21, 491), fill=(15, 138, 74))
    d.text((x + 29, 481), t, font=font(14), fill=INK)

# 右侧截图
shot = Image.open(DOCS / "img" / "panel-flow.png").convert("RGB")
sw = 560
sh = int(shot.height * sw / shot.width)
shot = shot.resize((sw, sh), Image.LANCZOS)
max_h = 540
if shot.height > max_h:                       # 按高度反推宽度，底部不裁
    sw = int(shot.width * max_h / shot.height)
    shot = shot.resize((sw, max_h), Image.LANCZOS)

card = Image.new("RGBA", (sw + 24, 600), (0, 0, 0, 0))
card.paste(shot, (12, 12))
mask = Image.new("L", card.size, 0)
md = ImageDraw.Draw(mask)
md.rounded_rectangle((12, 12, 12 + sw, 12 + shot.height), 18, fill=255)
shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((14, 20, 14 + sw, 20 + shot.height), 20, fill=(16, 44, 84, 70))
shadow = shadow.filter(ImageFilter.GaussianBlur(18))

px, py = 596, 44
img.paste(shadow, (px - 12, py - 12), shadow)
rounded = Image.new("RGBA", (sw, shot.height), (0, 0, 0, 0))
rounded.paste(shot, (0, 0))
rmask = Image.new("L", (sw, shot.height), 0)
ImageDraw.Draw(rmask).rounded_rectangle((0, 0, sw, shot.height), 18, fill=255)
img.paste(rounded, (px, py), rmask)

# 右下角橙色小注
d.text((72, 556), "AutumnPants · github.com/777cola/PowerPulse", font=font(13), fill=(130, 146, 166))

img.save(DOCS / "img" / "og.png", optimize=True)
print("wrote docs/img/og.png", img.size)
