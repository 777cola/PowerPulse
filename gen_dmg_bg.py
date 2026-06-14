
from PIL import Image, ImageDraw, ImageFont
import os

width, height = 600, 400
output_path = r"/Users/qjh/Library/Mobile Documents/com~apple~CloudDocs/QI JUNHAO/AI/Hermes/MAC电源软件/PowerPulse/.dmg_background.png"

# Dark gradient background
img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Gradient fill
for y in range(height):
    ratio = y / height
    r = int(28 + ratio * 15)
    g = int(30 + ratio * 15)
    b = int(38 + ratio * 15)
    draw.line([(0, y), (width, y)], fill=(r, g, b, 255))

# Subtle center glow
for y in range(0, height, 2):
    for x in range(0, width, 2):
        cx, cy = width/2, height * 0.4
        dist = ((x - cx)**2 + (y - cy)**2) ** 0.5
        max_dist = 350
        if dist < max_dist:
            alpha = int(40 * (1 - dist/max_dist))
            rr, gg, bb, _ = img.getpixel((x, y))
            new_r = min(255, rr + alpha)
            new_g = min(255, gg + alpha)
            new_b = min(255, bb + alpha)
            draw.point((x, y), fill=(new_r, new_g, new_b, 255))

# Try to load a font
font_large = None
font_medium = None
font_small = None

font_paths = [
    '/System/Library/Fonts/Helvetica.ttc',
    '/System/Library/Fonts/PingFang.ttc',
]

for fp in font_paths:
    if os.path.exists(fp):
        try:
            font_large = ImageFont.truetype(fp, 30)
            font_medium = ImageFont.truetype(fp, 19)
            font_small = ImageFont.truetype(fp, 13)
            print(f"Using font: {fp}")
            break
        except:
            pass

if font_large is None:
    font_large = ImageFont.load_default()
    font_medium = ImageFont.load_default()
    font_small = ImageFont.load_default()

# App icon area (left side)
icon_x, icon_y = 148, 155
icon_size = 80

# Rounded rect for app icon placeholder
draw.rounded_rectangle(
    [icon_x-5, icon_y-5, icon_x+icon_size+5, icon_y+icon_size+5],
    radius=18, fill=(60, 65, 75, 255), outline=(100, 105, 115, 255), width=2
)

# Lightning bolt symbol in icon
bolt_color = (100, 200, 255, 255)
draw.polygon([
    (icon_x + icon_size//2, icon_y + 12),
    (icon_x + 18, icon_y + icon_size//2 + 2),
    (icon_x + icon_size//2 - 2, icon_y + icon_size//2 - 2),
    (icon_x + icon_size - 14, icon_y + icon_size - 10),
], fill=bolt_color)

# App name below icon
app_name = "PowerPulse"
bbox = draw.textbbox((0, 0), app_name, font=font_large)
tw = bbox[2] - bbox[0]
draw.text((icon_x + icon_size//2 - tw//2, icon_y + icon_size + 18), app_name, fill=(220, 225, 235, 255), font=font_large)

# Applications folder icon (right side)  
appfolder_x, appfolder_y = 368, 145
folder_size = 80

# Folder shape - back part
draw.rounded_rectangle(
    [appfolder_x, appfolder_y + 10, appfolder_x + folder_size, appfolder_y + folder_size],
    radius=8, fill=(80, 140, 220, 255),
)
# Front tab
draw.polygon([
    (appfolder_x, appfolder_y + 10),
    (appfolder_x + 25, appfolder_y),
    (appfolder_x + 45, appfolder_y),
    (appfolder_x + 55, appfolder_y + 10),
], fill=(80, 140, 220, 255))

# "Applications" label
label = "Applications"
bbox = draw.textbbox((0, 0), label, font=font_medium)
tw = bbox[2] - bbox[0]
draw.text((appfolder_x + folder_size//2 - tw//2, appfolder_y + folder_size + 18), label, fill=(180, 190, 210, 255), font=font_medium)

# Arrow from app to folder
arrow_start_x = icon_x + icon_size + 15
arrow_end_x = appfolder_x - 10
arrow_y = icon_y + icon_size//2 + 5

# Arrow line
draw.line([(arrow_start_x, arrow_y), (arrow_end_x - 15, arrow_y)], fill=(120, 180, 255, 255), width=4)

# Arrow head
draw.polygon([
    (arrow_end_x, arrow_y),
    (arrow_end_x - 20, arrow_y - 10),
    (arrow_end_x - 20, arrow_y + 10),
], fill=(120, 180, 255, 255))

# Top title
title = "PowerPulse"
bbox = draw.textbbox((0, 0), title, font=font_large)
tw = bbox[2] - bbox[0]
draw.text((width//2 - tw//2, 38), title, fill=(220, 225, 235, 255), font=font_large)

# Subtitle
subtitle = "macOS Menu Bar Power & System Monitor"
bbox = draw.textbbox((0, 0), subtitle, font=font_small)
tw = bbox[2] - bbox[0]
draw.text((width//2 - tw//2, 78), subtitle, fill=(130, 140, 160, 255), font=font_small)

# Bottom instruction
instruction = "Drag  PowerPulse  to  Applications  to  install"
bbox = draw.textbbox((0, 0), instruction, font=font_small)
tw = bbox[2] - bbox[0]
draw.text((width//2 - tw//2, height - 52), instruction, fill=(180, 190, 210, 255), font=font_small)

# Bottom line separator
draw.line([(40, height - 38), (width - 40, height - 38)], fill=(60, 65, 75, 255), width=1)

# Save
img.save(output_path, 'PNG')
print(f"Background saved: {output_path}")
print(f"Size: {os.path.getsize(output_path)} bytes")
