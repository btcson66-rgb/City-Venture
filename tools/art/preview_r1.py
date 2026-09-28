"""Build R1 outfit tint comparison without touching game data."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


game, output = Path(sys.argv[1]), Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
chars = game / "assets" / "characters"
portraits = game / "assets" / "portraits"
cfg = json.loads((game / "data" / "character" / "options.json").read_text(encoding="utf-8"))


def colour(section, key):
    return next(v["color"] for v in cfg[section] if v["id"] == key)


def load(root, name):
    return Image.open(root / (name + ".png")).convert("RGBA")


def tint(im, hex_code):
    rgb = tuple(bytes.fromhex(hex_code.lstrip("#")))
    shaded = ImageChops.multiply(im.convert("RGB"), Image.new("RGB", im.size, rgb))
    return Image.merge("RGBA", (*shaded.split(), im.getchannel("A")))


def layers(app, outfit, top_colour):
    pres, hair, eyes = app["presentation"], app["hair"], app["eye_shape"]
    base = f"outfit_{outfit}_{pres}"
    hair_c = colour("hair_colors", app["hair_color"])
    out = Image.new("RGBA", (128, 144))
    parts = [
        tint(load(chars, f"hair_{hair}_back"), hair_c),
        tint(load(chars, f"body_{pres}_{app['face']}"), colour("skin_tones", app["skin"])),
        tint(load(chars, base + "_bottom"), top_colour),
        load(chars, base + "_bottom_detail"),
        load(chars, base + "_shoes"),
        tint(load(chars, base + "_top"), top_colour),
        load(chars, base + "_top_detail"),
        load(chars, f"eyes_{eyes}"),
        tint(load(chars, f"iris_{eyes}"), colour("eye_colors", app["eye_color"])),
        tint(load(chars, f"brows_{app['brows']}"), hair_c),
        load(chars, f"mouth_{app['mouth']}"),
        tint(load(chars, f"hair_{hair}_front"), hair_c),
    ]
    for part in parts:
        out.alpha_composite(part)
    return out.crop((0, 0, 32, 48))


variants = [
    ("Marcus · charcoal", "marcus", "#3a3d44"),
    ("Tom · light gray", "tom", "#b8bcc4"),
    ("Daniel · navy", "daniel", "#2c3e66"),
    ("Sofia · burgundy", "sofia", "#6e2e3a"),
    ("Dara · PostPoint", "dara", "#d0503c"),
]
scale, cell_w, cell_h = 5, 190, 292
page = Image.new("RGB", (cell_w * len(variants), cell_h), "#dbe8f2")
draw = ImageDraw.Draw(page)
for i, (label, npc_id, shade) in enumerate(variants):
    npc = json.loads((game / "data" / "npcs" / f"{npc_id}.json").read_text(encoding="utf-8"))
    sprite = layers(npc["appearance"], npc["outfit"], shade)
    draw.rounded_rectangle((i * cell_w + 8, 8, (i + 1) * cell_w - 8, cell_h - 8),
                           radius=8, fill="#eef4fa", outline="#738aa1")
    large = sprite.resize((32 * scale, 48 * scale), Image.Resampling.NEAREST)
    page.paste(large, (i * cell_w + 15, 16), large)
    draw.text((i * cell_w + 13, 264), label, fill="#182c43")
page.save(output / "after_tint_variants.png")

for outfit in ("business_suit", "courier"):
    cloth = load(chars, f"outfit_{outfit}_masculine_top")
    assert all(r == g == b for r, g, b, a in cloth.getdata() if a), outfit
    detail = load(chars, f"outfit_{outfit}_masculine_top_detail")
    assert any(r != g or g != b for r, g, b, a in detail.getdata() if a), outfit
print("R1: grayscale fabric and full-colour detail verified")
