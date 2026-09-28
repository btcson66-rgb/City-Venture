"""Review A1 walking layers without changing any game data or assets.

Usage: python tools/art/preview_a1.py game evidence/2026-09-28_a1_characters
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


game = Path(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
assets = game / "assets" / "characters"
options = json.loads((game / "data" / "character" / "options.json").read_text(encoding="utf-8"))


def color(group: str, key: str) -> str:
    return next(item["color"] for item in options[group] if item["id"] == key)


def load(name: str) -> Image.Image:
    return Image.open(assets / f"{name}.png").convert("RGBA")


def tint(im: Image.Image, hex_color: str) -> Image.Image:
    raw = hex_color.lstrip("#")
    col = tuple(int(raw[i:i + 2], 16) for i in (0, 2, 4))
    rgb = ImageChops.multiply(im.convert("RGB"), Image.new("RGB", im.size, col))
    return Image.merge("RGBA", (*rgb.split(), im.getchannel("A")))


def compose(look: dict) -> Image.Image:
    pres = look["presentation"]
    face = look["face"]
    hair = look["hair"]
    outfit = look["outfit"]
    hc = color("hair_colors", look["hair_color"])
    layers = [
        tint(load(f"hair_{hair}_back"), hc),
        tint(load(f"body_{pres}_{face}"), color("skin_tones", look["skin"])),
        tint(load(f"outfit_{outfit}_{pres}_bottom"), look.get("bottom_tint", "#ffffff")),
        load(f"outfit_{outfit}_{pres}_shoes"),
        tint(load(f"outfit_{outfit}_{pres}_top"), look.get("top_tint", "#ffffff")),
        load(f"eyes_{look['eye_shape']}"),
        tint(load(f"iris_{look['eye_shape']}"), color("eye_colors", look["eye_color"])),
        tint(load(f"brows_{look['brows']}"), hc),
        load(f"mouth_{look['mouth']}"),
        tint(load(f"hair_{hair}_front"), hc),
    ]
    combined = Image.new("RGBA", (128, 144))
    for layer in layers:
        combined.alpha_composite(layer)
    return combined


base = dict(presentation="neutral", face="round", hair="short_neat",
            hair_color="brown", skin="s2", eye_shape="round",
            eye_color="brown", brows="straight", mouth="smile",
            outfit="startup_casual")


def board(filename: str, entries: list[tuple[str, Image.Image]], cols: int,
          scale: int = 4, frames: int = 1) -> None:
    cw, ch = 32 * frames * scale + 16, 48 * scale + 34
    rows = (len(entries) + cols - 1) // cols
    page = Image.new("RGB", (cols * cw + 12, rows * ch + 12), "#d2e0ec")
    draw = ImageDraw.Draw(page)
    for i, (label, sprite) in enumerate(entries):
        x, y = (i % cols) * cw + 12, (i // cols) * ch + 12
        draw.rounded_rectangle((x - 4, y - 4, x + cw - 13, y + ch - 16),
                               radius=7, fill="#e9f1f8", outline="#728aa3")
        page.paste(sprite.resize((sprite.width * scale, sprite.height * scale),
                                 Image.Resampling.NEAREST), (x, y),
                   sprite.resize((sprite.width * scale, sprite.height * scale),
                                 Image.Resampling.NEAREST))
        draw.text((x + 3, y + 48 * scale + 4), label, fill="#15283e")
    page.save(out / filename)


hair_entries = []
for style in ("messy", "short_neat", "buzz", "side_part", "bob", "long", "ponytail", "bun"):
    look = {**base, "hair": style}
    hair_entries.append((style, compose(look).crop((0, 0, 32, 48))))
board("after_hair_styles.png", hair_entries, 8)

outfit_entries = []
for style in ("startup_casual", "office_professional", "home", "barista",
              "business_suit", "civic_staff", "courier", "casual_tee", "casual_jacket"):
    outfit_entries.append((style, compose({**base, "outfit": style}).crop((0, 0, 32, 48))))
board("after_outfits.png", outfit_entries, 5)

body_entries = []
for pres in ("masculine", "feminine", "neutral"):
    body_entries.append((pres, compose({**base, "presentation": pres}).crop((0, 0, 32, 48))))
board("after_body_types.png", body_entries, 3)

npc_entries = []
for file in sorted((game / "data" / "npcs").glob("*.json")):
    npc = json.loads(file.read_text(encoding="utf-8"))
    if "appearance" not in npc:
        continue
    tints = npc.get("outfit_tints", {})
    look = {**npc["appearance"], "outfit": npc["outfit"],
            "top_tint": tints.get("top", "#ffffff"),
            "bottom_tint": tints.get("bottom", "#ffffff")}
    npc_entries.append((npc["id"], compose(look).crop((0, 0, 32, 48))))
board("after_named_npcs.png", npc_entries, 6)

walk = compose(base)
for direction, row in (("front", 0), ("side", 1), ("back", 2)):
    board(f"after_walk_{direction}.png",
          [(direction, walk.crop((0, row * 48, 128, row * 48 + 48)))], 1,
          scale=6, frames=4)

print(f"A1 review boards: {len(npc_entries)} NPCs, 8 hairstyles, 9 outfits")
