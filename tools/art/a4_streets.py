"""Refine the 28 existing street props and the 23 ground-atlas cells.

Run once against a clean A3 asset tree, writing to a separate output tree:
    python tools/art/a4_streets.py game/assets <output-dir>

The 16x16 atlas indices, sprite dimensions, transparency and product icons are
preserved. A2 interior floor/wall cells are copied unchanged from the input.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import street


source, output = Path(sys.argv[1]), Path(sys.argv[2])
(output / "props").mkdir(parents=True, exist_ok=True)
(output / "tiles").mkdir(parents=True, exist_ok=True)
names = sorted(p for p in (source / "props").glob("*.png") if not p.stem.startswith("product_"))
assert len(names) == 28, f"Expected 28 street props, got {len(names)}"


def softened_interior(image: Image.Image, strength: float) -> Image.Image:
    image = image.convert("RGBA")
    softened = image.convert("RGB").filter(ImageFilter.GaussianBlur(0.48))
    original = image.load()
    blur = softened.load()
    out = image.copy()
    target = out.load()
    for y in range(1, image.height - 1):
        for x in range(1, image.width - 1):
            if not all(original[x + dx, y + dy][3] == 255
                       for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1))):
                continue
            c = original[x, y]
            target[x, y] = tuple(round(c[i] * (1 - strength) + blur[x, y][i] * strength)
                                  for i in range(3)) + (255,)
    return out


for path in names:
    image = Image.open(path).convert("RGBA")
    organic = path.stem.startswith(("tree_", "planter", "flower_", "hedge"))
    quiet = path.stem in {"bollard", "hedge", "railing", "parking_meter", "cone"}
    rgb = image.convert("RGB")
    rgb = ImageEnhance.Color(rgb).enhance(0.86 if quiet else 0.98)
    rgb = ImageEnhance.Contrast(rgb).enhance(0.90 if quiet else 0.985)
    rgb = ImageEnhance.Brightness(rgb).enhance(0.97 if quiet else 1.012)
    image = Image.merge("RGBA", (*rgb.split(), image.getchannel("A")))
    image = softened_interior(image, 0.33 if organic else 0.13)
    if path.stem in {"lamp", "lamp_banner"}:
        # Current converted lamp head is centered at (10, 8), matching the
        # `sprite_meta.json` glow anchor exactly. Warm only opaque head pixels.
        for y in range(6, 10):
            for x in range(8, 13):
                r, g, b, a = image.getpixel((x, y))
                if a and r > 70:
                    image.putpixel((x, y), (max(r, 217), max(g, 183), max(b, 139), a))
    assert image.size == Image.open(path).size
    image.save(output / "props" / path.name, optimize=True)


atlas = Image.open(source / "tiles" / "atlas.png").convert("RGBA")
original_atlas = atlas.copy()
index = json.loads((source / "tiles" / "atlas.json").read_text(encoding="utf-8"))["tiles"]
ground = street.ground_tiles()
assert len(ground) == 23
for name, make in ground:
    tile = make().convert("RGBA")
    tile = ImageEnhance.Contrast(tile).enhance(0.985)
    x, y = index[name]
    atlas.paste(tile, (x * 16, y * 16))

for name, (x, y) in index.items():
    if name in {n for n, _ in ground}:
        continue
    box = (x * 16, y * 16, x * 16 + 16, y * 16 + 16)
    assert atlas.crop(box).tobytes() == original_atlas.crop(box).tobytes(), name

atlas.save(output / "tiles" / "atlas.png", optimize=True)
print(f"A4: {len(names)} props + {len(ground)} ground cells; interior atlas cells unchanged")
