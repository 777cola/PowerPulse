#!/usr/bin/env python3
"""给 README 出深/浅两套不透明截图。

站点用的是原始半透明 PNG（放在浅色页面上就是灰玻璃），README 里那层灰会糊成一片。
这里把面板合成到对应的底色上，加圆角和细边，再由 <picture> 按主题切换。

用法：先渲染两套原始截图
  ./build/PowerPulse --selftest /tmp/rd_light --plugged
  ./build/PowerPulse --selftest /tmp/rd_dark  --plugged --dark
  python3 tools/readme_shots.py /tmp/rd_light /tmp/rd_dark
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "img"

NAMES = [("flow", 0), ("monitor", 1), ("history", 2), ("adapter", 3)]

THEMES = {
    "light": {"top": (247, 249, 252), "bottom": (238, 242, 248), "border": (26, 75, 140, 46)},
    "dark": {"top": (26, 33, 46), "bottom": (10, 13, 18), "border": (255, 255, 255, 26)},
}
RADIUS = 28


def backdrop(w: int, h: int, top, bottom) -> Image.Image:
    img = Image.new("RGB", (w, h), bottom)
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def compose(panel_path: Path, theme: dict, dst: Path) -> None:
    panel = Image.open(panel_path).convert("RGBA")
    w, h = panel.size
    canvas = backdrop(w, h, theme["top"], theme["bottom"])
    canvas.paste(panel, (0, 0), panel)
    canvas = canvas.convert("RGBA")

    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=RADIUS, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(canvas, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle([0, 0, w - 1, h - 1], radius=RADIUS,
                                          outline=theme["border"], width=2)

    out.convert("RGB").save(dst, optimize=True)
    print(f"{dst.name} {out.size} {dst.stat().st_size // 1024} KB")


def main() -> None:
    light_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/rd_light")
    dark_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "/tmp/rd_dark")
    for name, idx in NAMES:
        for theme_name, folder in (("light", light_dir), ("dark", dark_dir)):
            prefix = "dark" if theme_name == "dark" else "light"
            compose(folder / f"{prefix}-final-{idx}.png", THEMES[theme_name],
                    OUT / f"readme-{name}-{theme_name}.png")


if __name__ == "__main__":
    main()
