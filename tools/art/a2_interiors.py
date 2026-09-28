"""A2 interior paint pass. Run on a clean input directory, never the game tree.

python tools/art/a2_interiors.py game/assets /path/to/output-assets
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw


source = Path(sys.argv[1])
dest = Path(sys.argv[2])
(dest / "interiors").mkdir(parents=True, exist_ok=True)
(dest / "tiles").mkdir(parents=True, exist_ok=True)


def soften(im: Image.Image) -> Image.Image:
    """Soften interior colour blocks while retaining exact opaque silhouettes."""
    src = im.convert("RGBA")
    out = src.copy()
    old, new = src.load(), out.load()
    w, h = src.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = old[x, y]
            if not a:
                continue
            around = [old[xx, yy] for xx, yy in ((x-1,y),(x+1,y),(x,y-1),(x,y+1))
                      if 0 <= xx < w and 0 <= yy < h and old[xx, yy][3] == 255]
            if len(around) >= 3:
                avg = tuple(sum(v[i] for v in around) / len(around) for i in range(3))
                r, g, b = (int(v * .74 + avg[i] * .26) for i, v in enumerate((r,g,b)))
            # Reference interiors share cool shadows and warm top-left light.
            lum = (r + g + b) / 3
            if lum < 105:
                r, g, b = int(r*.96), int(g*.99), min(255, int(b*1.04))
            elif lum > 165:
                r, g, b = min(255,int(r*1.025)), min(255,int(g*1.018)), b
            new[x, y] = (r, g, b, a)
    return out


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def bank_counter():
    im = canvas(144, 44); d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 15, 141, 41), radius=3, fill="#f0e7d7", outline="#5b6070", width=2)
    d.rectangle((5, 21, 139, 24), fill="#d5c7ad")
    for x in (3, 72, 141):
        d.rectangle((x, 12, x+1, 39), fill="#b38d50")
    d.rounded_rectangle((0, 14, 143, 19), radius=2, fill="#5d483b", outline="#d5a95b")
    for x in (12, 80):
        d.rectangle((x, 4, x+51, 16), fill="#b6d6e5", outline="#416077")
        d.line((x+3, 14, x+48, 6), fill="#e8f7fb", width=2)
        d.rectangle((x+21, 25, x+27, 28), fill="#c9a358")
        d.rounded_rectangle((x+3, 31, x+47, 36), radius=2, fill="#d8cab6")
    for x in (61, 129):
        d.rectangle((x, 1, x+3, 15), fill="#b38d50")
    return im


def civic_counter():
    im = canvas(144, 44); d = ImageDraw.Draw(im)
    d.rounded_rectangle((2, 13, 141, 41), radius=4, fill="#e4e8ea", outline="#677987", width=2)
    d.rectangle((5, 21, 139, 23), fill="#b8c6d0")
    d.rounded_rectangle((0, 12, 143, 17), radius=2, fill="#566d86")
    for x, n in ((14, "01"), (81, "02")):
        d.rounded_rectangle((x, 1, x+30, 11), radius=2, fill="#263d5b", outline="#8ab8d4")
        d.text((x+9, 2), n, fill="#e9f7fa")
        d.rectangle((x+4, 25, x+46, 27), fill="#c6d5dd")
        d.rounded_rectangle((x+5, 32, x+47, 36), radius=2, fill="#b3c2cb")
    d.ellipse((65, 25, 74, 34), fill="#6f95aa")
    return im


def menu_board():
    im = canvas(66, 34); d = ImageDraw.Draw(im)
    d.rounded_rectangle((1, 1, 64, 32), radius=3, fill="#263841", outline="#b98d58", width=2)
    for x, drink, price in ((7, "#e8c188", "#ca9365"), (28, "#f0d8a9", "#9ac1aa"), (49, "#c6dfcf", "#d6a483")):
        d.rounded_rectangle((x, 10, x+10, 20), radius=2, fill=drink)
        d.arc((x+8, 11, x+15, 18), 260, 90, fill="#f4efe0", width=2)
        d.arc((x+1, 4, x+7, 11), 180, 350, fill="#d8e9dc")
        d.rounded_rectangle((x-1, 24, x+14, 27), radius=1, fill=price)
    return im


def desk_laptop():
    im = canvas(48, 41); d = ImageDraw.Draw(im)
    d.polygon([(3,20),(34,16),(46,22),(14,28)], fill="#ae744d")
    d.line([(3,20),(14,28),(46,22)], fill="#e7b174", width=2)
    d.polygon([(10,27),(14,27),(14,40),(11,40)], fill="#59413a")
    d.polygon([(41,23),(44,22),(44,37),(41,39)], fill="#59413a")
    d.rounded_rectangle((11,4,31,20), radius=2, fill="#1e3149", outline="#7c94a4", width=2)
    d.rectangle((14,7,28,17), fill="#3477a0")
    d.polygon([(14,17),(28,8),(28,17)], fill="#5dc3d5")
    d.line((16,10,23,10), fill="#c0f4ff", width=2)
    d.polygon([(10,20),(31,20),(36,24),(12,25)], fill="#b8c9ce")
    d.line((15,22,31,22), fill="#6a8497")
    d.ellipse((37,19,42,23), fill="#f0e7dc", outline="#6a5b53")
    return im


def packing_table():
    im = canvas(48, 34); d = ImageDraw.Draw(im)
    d.polygon([(2,16),(39,14),(47,19),(10,22)], fill="#b88e6b", outline="#624c3c")
    d.polygon([(7,21),(10,21),(10,33),(7,33)], fill="#445064")
    d.polygon([(40,20),(43,20),(43,33),(40,33)], fill="#445064")
    d.polygon([(6,9),(20,8),(25,15),(11,17)], fill="#c8975b", outline="#765334")
    d.line((13,9,17,16), fill="#ead3a3", width=2)
    d.polygon([(23,7),(35,6),(38,14),(26,16)], fill="#d2a268", outline="#765334")
    d.line((28,7,31,15), fill="#f6d58f", width=2)
    d.ellipse((34,16,43,23), fill="#d0a544", outline="#725723", width=2)
    d.ellipse((37,18,40,21), fill="#3b5362")
    return im


def wardrobe():
    im = canvas(34, 54); d = ImageDraw.Draw(im)
    d.rounded_rectangle((1,1,32,51), radius=3, fill="#a9774b", outline="#49382f", width=2)
    d.polygon([(15,5),(29,4),(30,44),(15,46)], fill="#493832")
    d.polygon([(16,8),(26,9),(27,43),(16,44)], fill="#d6baa0")
    for x,c in ((18,"#547287"),(22,"#c69980"),(26,"#789671")):
        d.line((x,14,x,37), fill=c, width=3)
        d.line((x,11,x+2,13), fill="#e1d5bf")
    d.polygon([(1,3),(15,5),(15,48),(1,50)], fill="#b88355", outline="#704b38")
    d.line((3,5,3,47), fill="#e1ae70", width=2)
    d.ellipse((11,26,13,29), fill="#e2c071")
    d.rectangle((4,51,29,53), fill="#4c3930")
    return im


def box():
    im = canvas(16,14); d = ImageDraw.Draw(im)
    d.polygon([(1,4),(8,1),(15,4),(8,7)], fill="#edc68b", outline="#865c3c")
    d.polygon([(1,4),(8,7),(8,13),(1,10)], fill="#bd8858", outline="#865c3c")
    d.polygon([(8,7),(15,4),(15,10),(8,13)], fill="#d7a269", outline="#865c3c")
    d.line((5,3,12,5), fill="#f7db9e", width=2)
    d.line((8,7,8,12), fill="#f2cd83", width=2)
    return im


SPECIAL = {"bank_counter": bank_counter, "civic_counter": civic_counter,
           "menu_board": menu_board, "desk_laptop": desk_laptop,
           "packing_table": packing_table, "wardrobe": wardrobe, "box": box}


def floor(kind):
    im = Image.new("RGB", (512, 320))
    d = ImageDraw.Draw(im)
    rng = random.Random("city-venture-a2-" + kind)
    palettes = {
        "wood_warm": ((181,132,88),(207,160,105),(118,80,58)),
        "wood_dark": ((83,69,70),(112,86,76),(48,48,60)),
        "wood_cafe": ((140,102,75),(178,130,90),(78,63,58)),
        "marble": ((217,217,207),(245,241,225),(151,164,171)),
        "concrete": ((137,151,157),(166,178,179),(95,112,120)),
        "tile_white": ((214,223,225),(244,244,238),(168,190,199)),
        "checker": ((195,195,188),(236,229,214),(109,124,135)),
        "carpet_navy": ((40,63,92),(62,87,115),(23,43,70)),
    }
    base, light, dark = palettes[kind]
    if kind.startswith("wood"):
        d.rectangle((0,0,511,319), fill=dark)
        for row,y in enumerate(range(0,320,24)):
            offset = 0 if row % 2 else -64
            for x in range(offset,512,128):
                variation = rng.randint(-13,13)
                col = tuple(max(0,min(255,v+variation)) for v in base)
                d.rectangle((x+1,y+1,x+126,y+22), fill=col)
                d.line((x+3,y+3,x+125,y+3), fill=light, width=2)
                d.line((x+8,y+17,x+95,y+17), fill=tuple(int(v*.89) for v in col))
    elif kind == "carpet_navy":
        d.rectangle((0,0,511,319), fill=base)
        for y in range(0,320,4):
            d.line((0,y,511,y), fill=tuple(int(v*.94) for v in base))
        for y in range(0,320,32):
            for x in range(0,512,32):
                d.line((x+2,y+2,x+30,y+2), fill=light)
                d.line((x+2,y+2,x+2,y+30), fill=dark)
    else:
        d.rectangle((0,0,511,319), fill=dark)
        size = 32 if kind in ("checker","tile_white") else 48
        for y in range(0,320,size):
            for x in range(0,512,size):
                primary = dark if kind == "checker" and (x//size+y//size)%2 else base
                variation = rng.randint(-7,7)
                col = tuple(max(0,min(255,v+variation)) for v in primary)
                d.rectangle((x+1,y+1,x+size-1,y+size-1), fill=col)
                d.line((x+2,y+2,x+size-3,y+2), fill=light, width=2)
                if kind == "marble" and rng.random() < .4:
                    d.line((x+8,y+size-6,x+size-8,y+7), fill=light)
    return im.convert("RGBA")


interiors = source / "interiors"
names = [p for p in sorted(interiors.glob("*.png")) if not p.stem.startswith("floor_")]
assert len(names) == 68, len(names)
for path in names:
    original = Image.open(path).convert("RGBA")
    result = SPECIAL[path.stem]() if path.stem in SPECIAL else soften(original)
    assert result.size == original.size, path.name
    result.save(dest / "interiors" / path.name)

for name in ("wood_warm","wood_dark","wood_cafe","marble","concrete"):
    # These existing wide textures already have fine, nonrepeating grain.
    # Retain it and soften only colour transitions; broad new planks made the
    # 640×360 game look more blocky in the actual interior screenshots.
    softened = soften(Image.open(interiors / f"floor_{name}.png"))
    softened.save(dest / "interiors" / f"floor_{name}.png")
for name in ("tile_white","checker","carpet_navy"):
    floor(name).save(dest / "interiors" / f"floor_{name}.png")

atlas = Image.open(source / "tiles" / "atlas.png").convert("RGBA")
from json import loads
index = loads((source / "tiles" / "atlas.json").read_text(encoding="utf-8"))["tiles"]
wall_palette = {
    "wall_plaster_warm": ((237,218,193),(202,176,152)),
    "wall_brick": ((171,105,84),(116,72,65)),
    "wall_navy_panel": ((45,69,102),(27,47,78)),
    "wall_wood_panel": ((174,125,83),(107,74,58)),
    "wall_marble_wall": ((229,226,212),(167,179,185)),
    "wall_white_modern": ((230,236,236),(177,197,205)),
    "wall_concrete_wall": ((152,166,169),(101,119,128)),
}
for name,(base,shade) in wall_palette.items():
    tx, ty = index[name]
    tile = Image.new("RGBA",(16,16),base+(255,)); d=ImageDraw.Draw(tile)
    d.line((0,0,15,0),fill=tuple(min(255,v+13) for v in base),width=2)
    d.line((0,15,15,15),fill=shade)
    if name == "wall_brick":
        for y in (5,11):
            d.line((0,y,15,y),fill=shade)
        for x in (4,12):
            d.line((x,1,x,4),fill=shade)
        d.line((8,6,8,10),fill=shade)
    elif name in ("wall_navy_panel","wall_wood_panel"):
        for x in (4,11): d.line((x,2,x,14),fill=shade)
    elif name == "wall_marble_wall":
        d.line((3,13,12,4),fill=(209,215,213))
    elif name == "wall_concrete_wall":
        d.line((2,7,14,7),fill=shade)
    atlas.paste(tile,(tx*16,ty*16))
atlas.save(dest / "tiles" / "atlas.png")
print("A2:",len(names),"furnishings, 8 floors, 7 wall tiles")
