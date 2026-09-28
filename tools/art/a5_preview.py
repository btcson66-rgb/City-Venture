"""Render A5 portraits using the same layer order and tints as Art.portrait_layers.

Usage: python tools/art/a5_preview.py OUTPUT_DIRECTORY
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "game/assets/portraits"
OPTIONS = json.loads((ROOT / "game/data/character/options.json").read_text(encoding="utf-8"))
COLORS = {key: {item["id"]: item["color"] for item in OPTIONS[key]}
          for key in ("hair_colors", "skin_tones", "eye_colors")}
NPC_IDS = ("maya", "jun", "lee", "priya", "ken", "ana",
           "sofia", "marcus", "tom", "dara", "daniel", "elena")


def tint(im: Image.Image, color: str) -> Image.Image:
    rgb = ImageChops.multiply(im.convert("RGB"), Image.new("RGB", im.size, color))
    return Image.merge("RGBA", (*rgb.split(), im.getchannel("A")))


def layer(name: str, color: str | None, frame: int) -> Image.Image:
    im = Image.open(ASSETS / f"{name}.png").convert("RGBA")
    if im.width == 256:
        im = im.crop((frame * 64, 0, (frame + 1) * 64, 64))
    return tint(im, color) if color else im


def npc(npc_id: str) -> dict:
    return json.loads((ROOT / "game/data/npcs" / f"{npc_id}.json").read_text(encoding="utf-8"))


def compose(data: dict, frame: int = 0) -> Image.Image:
    app = data["appearance"]
    hair = COLORS["hair_colors"][app["hair_color"]]
    eye = COLORS["eye_colors"][app["eye_color"]]
    skin = COLORS["skin_tones"][app["skin"]]
    outfit = data["outfit"]
    items = [
        (f"hair_{app['hair']}_back", hair),
        (f"head_{app['face']}", skin),
        (f"outfit_{outfit}", data.get("outfit_tints", {}).get("top", "#ffffff")),
    ]
    if (ASSETS / f"outfit_{outfit}_detail.png").exists():
        items.append((f"outfit_{outfit}_detail", None))
    items += [
        (f"eyes_{app['eye_shape']}", None),
        (f"iris_{app['eye_shape']}", eye),
        (f"brows_{app['brows']}", hair),
        (f"mouth_{app['mouth']}", None),
        (f"hair_{app['hair']}_front", hair),
    ]
    acc = app.get("accessory", "none")
    if acc != "none" and (ASSETS / f"acc_{acc}.png").exists():
        items.append((f"acc_{acc}", None))
    out = Image.new("RGBA", (64, 64), "#213955")
    for name, color in items:
        out.alpha_composite(layer(name, color, frame))
    return out.convert("RGB")


def generate(directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    lineup = Image.new("RGB", (4 * 148, 3 * 170), "#10223a")
    draw = ImageDraw.Draw(lineup)
    neutral_images = []
    for i, npc_id in enumerate(NPC_IDS):
        frames = [compose(npc(npc_id), frame) for frame in range(4)]
        assert len({frame.tobytes() for frame in frames}) == 4, f"Expression duplicate: {npc_id}"
        neutral_images.append(frames[0].tobytes())
        p = frames[0].resize((128, 128), Image.Resampling.NEAREST)
        x, y = (i % 4) * 148 + 10, (i // 4) * 170 + 5
        lineup.paste(p, (x, y))
        draw.text((x, y + 133), npc_id, fill="white")
    lineup.save(directory / "npc_lineup.png")
    assert len(set(neutral_images)) == 12, "Two named NPC portraits are identical"

    sample = ("maya", "priya", "daniel", "elena")
    expressions = Image.new("RGB", (4 * 128, len(sample) * 128), "#10223a")
    for i, npc_id in enumerate(sample):
        for frame in range(4):
            expressions.paste(compose(npc(npc_id), frame).resize((128, 128), Image.Resampling.NEAREST),
                              (frame * 128, i * 128))
    expressions.save(directory / "expressions.png")

    glasses = Image.new("RGB", (3 * 128, 128), "#10223a")
    for i, npc_id in enumerate(("priya", "ana", "daniel")):
        glasses.paste(compose(npc(npc_id)).resize((128, 128), Image.Resampling.NEAREST),
                      (i * 128, 0))
    glasses.save(directory / "glasses_fit.png")
    print("A5 preview: 12 distinct NPCs, 4 distinct expressions each, 3 glasses users")


if __name__ == "__main__":
    generate(Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "evidence/a5_preview")
