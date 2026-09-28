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
            # Standing actions retain the whole walking silhouette. Moving
            # only a rectangular torso or head band leaves a transparent seam
            # through the layered composite at the 32x48 target scale.
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
    if pose == "idle":
        if sleeve and tick:
            # A restrained two-frame breath, expressed by shifting the chest
            # highlight instead of tearing the waistline open.
            c = frame.getpixel((16, 24))
            if c[3]:
                d.point((16, 23), fill=c)
    elif pose in ("phone","interact"):
        if sleeve:
            c = next((frame.getpixel((x,24)) for x in (11,12,17)
                      if frame.getpixel((x,24))[3] == 255), (90,90,110,255))
            if pose == "phone":
                points = [(22,26),(25,24),(26,20),(24,17)] if direction != 1 else [(19,26),(22,24),(23,20),(21,17)]
                d.line(points, fill=c, width=4)
            else:
                d.line([(22,27),(26,25),(30,24)] if direction != 1
                       else [(19,27),(24,25),(30,24)], fill=c, width=4)
        if skin:
            if pose == "phone":
                d.rounded_rectangle((23 if direction != 1 else 20,15,25 if direction != 1 else 22,18), radius=1, fill=(238,238,238,255))
            else:
                d.rounded_rectangle((28,23,31,26), radius=1, fill=(238,238,238,255))
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
            if direction == 2:
                # Back view: the carton is behind the torso. Only its narrow
                # outer edges remain visible beside the forearms.
                d.rounded_rectangle((9,32,11,38), radius=1, fill="#bd8758")
                d.rounded_rectangle((22,32,24,38), radius=1, fill="#d4a36d")
            else:
                shift = (0, 1, 0, -1)[tick if tick < 2 else 0]
                d.polygon([(9+shift,34),(16+shift,31),(24+shift,34),(17+shift,37)], fill="#ebc58c")
                d.polygon([(9+shift,34),(17+shift,37),(17+shift,43),(9+shift,40)], fill="#bd8758")
                d.polygon([(17+shift,37),(24+shift,34),(24+shift,40),(17+shift,43)], fill="#d4a36d")
                d.line((12+shift,33,21+shift,36), fill="#fbdfa5", width=2)
                d.line((17+shift,37,17+shift,42), fill="#f0c786", width=2)
        if sleeve:
            c = next((frame.getpixel((x,25)) for x in (12,18)
                      if frame.getpixel((x,25))[3] == 255), (90,90,110,255))
            d.line((10,27,11,34), fill=c, width=4)
            d.line((23,27,22,34), fill=c, width=4)


def close_single_pixel_seams(frame: Image.Image, walk: Image.Image) -> None:
    """Keep new pose layers no more perforated than their walk counterpart."""
    def seam_rows(im: Image.Image) -> dict[int, list[int]]:
        alpha = im.getchannel("A").load()
        return {y: [x for x in range(32) if not alpha[x,y] and alpha[x,y-1] and alpha[x,y+1]]
                for y in range(1,47)}

    baseline = max((len(xs) for xs in seam_rows(walk).values()), default=0)
    for y, xs in seam_rows(frame).items():
        if len(xs) < baseline + 4:
            continue
        for x in xs:
            frame.putpixel((x,y), frame.getpixel((x,y-1)))


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
                walk = sheet.crop((0,direction*48,32,direction*48+48))
                close_single_pixel_seams(sprite, walk)
                result.paste(sprite,(frame*32,direction*48))
        result.save(output / f"{path.stem}_{pose}.png", optimize=True)
print(f"R3: {len(names)} layers × {len(POSES)} poses = {len(names)*len(POSES)} sheets")
