"""Generate every layered character pose without changing the walking sheets.

python tools/art/r3_poses.py game/assets/characters /path/to/output
Every input sheet receives sit, idle, phone, interact and carry at 128×144.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw


source = Path(sys.argv[1])
output = Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
names = sorted(p for p in source.glob("*.png")
               if not p.stem.endswith(("_sit","_idle","_phone","_interact","_carry")))
assert len(names) == 134, f"Expected A1 + R1's 134 layers; found {len(names)}"
POSES = ("sit", "idle", "phone", "interact", "carry")


def remap(frame: Image.Image, pose: str, direction: int, tick: int) -> Image.Image:
    out = Image.new("RGBA", (32,48))
    source_pixels, target = frame.load(), out.load()
    for y in range(48):
        for x in range(32):
            pixel = source_pixels[x,y]
            if pixel[3] == 0:
                continue
            nx, ny = x, y
            if pose == "sit":
                if y < 19:
                    ny = y + 3 + tick
                elif y < 34:
                    ny = y + 3
                else:
                    ny = 36 + round((y - 34) * .73)
                    if direction == 1:
                        nx += round((y - 34) * .47)
                    else:
                        nx += -2 if x < 16 else 2
            elif pose == "idle":
                if tick and 5 <= y < 31:
                    ny = y - 1
            elif pose == "phone":
                if tick and y < 19:
                    ny = y - 1
            elif pose == "interact":
                if tick and y < 19:
                    nx = x + 1
            elif pose == "carry":
                # Follow the existing four-frame contact cycle with less bounce.
                if y < 19 and tick in (1,3):
                    ny = y + 1
            if 0 <= nx < 32 and 0 <= ny < 48:
                target[nx,ny] = pixel
    return out


def action(frame: Image.Image, name: str, pose: str, direction: int, tick: int) -> None:
    d = ImageDraw.Draw(frame)
    skin = name.startswith("body_")
    sleeve = name.startswith("outfit_") and name.endswith("_top")
    trousers = name.startswith("outfit_") and name.endswith("_bottom")
    shoes = name.startswith("outfit_") and name.endswith("_shoes")
    if not (skin or sleeve or trousers or shoes):
        return
    if pose in ("phone","interact"):
        # Retire the straight right arm, then place the sleeve and hand together.
        if skin or sleeve:
            if direction == 1:
                d.rectangle((16,22,21,34), fill=(0,0,0,0))
            else:
                d.rectangle((23,23,30,35), fill=(0,0,0,0))
        if sleeve:
            c = next((frame.getpixel((x,24)) for x in (11,12,17)
                      if frame.getpixel((x,24))[3] == 255), (90,90,110,255))
            if pose == "phone":
                points = [(21,22),(23,21),(24,16),(22,15)] if direction != 1 else [(16,22),(20,20),(22,16)]
                d.line(points, fill=c, width=3)
            else:
                d.line([(21,22),(25,22),(29,21)] if direction != 1
                       else [(17,22),(23,22),(29,21)], fill=c, width=3)
        if skin:
            if pose == "phone":
                d.rounded_rectangle((21,12,24,16), radius=1, fill=(238,238,238,255))
            else:
                d.rounded_rectangle((28,20,31,24), radius=1, fill=(238,238,238,255))
    elif pose == "sit":
        if trousers:
            c = next((frame.getpixel((x,37)) for x in (13,18,11,20)
                      if frame.getpixel((x,37))[3] == 255), (96,99,107,255))
            # Visible horizontal thighs and knees distinguish sitting from an
            # abbreviated standing sprite at the original 32x48 scale.
            d.rounded_rectangle((9,35,23,39), radius=2, fill=c)
        if sleeve:
            c = next((frame.getpixel((x,25)) for x in (12,18)
                      if frame.getpixel((x,25))[3] == 255), (90,90,110,255))
            # Hands rest on a lap or keyboard; second frame is a small tap.
            y = 35 + tick
            d.line((10,y,14,y), fill=c, width=2)
            d.line((18,y,22,y), fill=c, width=2)
        if skin:
            d.point((14,37+tick), fill=(238,238,238,255))
            d.point((18,37+tick), fill=(238,238,238,255))
    elif pose == "carry":
        if shoes:
            # Shoes are the existing untinted outfit layer. A low-held carton
            # stays brown even for a player wearing tintable clothes.
            d.polygon([(9,34),(16,31),(24,34),(17,37)], fill="#ebc58c")
            d.polygon([(9,34),(17,37),(17,43),(9,40)], fill="#bd8758")
            d.polygon([(17,37),(24,34),(24,40),(17,43)], fill="#d4a36d")
            d.line((12,33,21,36), fill="#fbdfa5", width=2)
            d.line((17,37,17,42), fill="#f0c786", width=2)
        if sleeve:
            c = next((frame.getpixel((x,25)) for x in (12,18)
                      if frame.getpixel((x,25))[3] == 255), (90,90,110,255))
            d.line((8,25,10,33), fill=c, width=3)
            d.line((24,25,22,33), fill=c, width=3)


for path in names:
    sheet = Image.open(path).convert("RGBA")
    assert sheet.size == (128,144), path.name
    for pose in POSES:
        result = Image.new("RGBA", sheet.size)
        for direction in range(3):
            for frame in range(4):
                tick = frame % 2
                src_frame = frame if pose == "carry" else 0
                src = sheet.crop((src_frame*32,direction*48,src_frame*32+32,direction*48+48))
                sprite = remap(src,pose,direction,tick)
                action(sprite,path.stem,pose,direction,tick)
                result.paste(sprite,(frame*32,direction*48))
        result.save(output / f"{path.stem}_{pose}.png", optimize=True)
print(f"R3: {len(names)} layers × {len(POSES)} poses = {len(names)*len(POSES)} sheets")
