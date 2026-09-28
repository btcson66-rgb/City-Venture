"""Prepare approved wide artwork for the fixed-size Godot backdrops.

Run from the repository root: python tools/art/finalize_backdrops.py
Sources live outside game/ so Godot only imports the final pixel-size images.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs" / "art_sources"
OUTPUT = ROOT / "game" / "assets" / "backdrops"


def fit(source: Path, destination: Path, size: tuple[int, int]) -> None:
    with Image.open(source) as image:
        image = image.convert("RGB")
        target_ratio = size[0] / size[1]
        source_ratio = image.width / image.height
        if source_ratio > target_ratio:
            width = round(image.height * target_ratio)
            left = (image.width - width) // 2
            image = image.crop((left, 0, left + width, image.height))
        else:
            height = round(image.width / target_ratio)
            top = (image.height - height) // 2
            image = image.crop((0, top, image.width, top + height))
        # Area reduction retains tiny windows and people; palette snap restores
        # clean pixel clusters at the game's 1x canvas size.
        image = image.resize(size, Image.Resampling.BOX)
        image = image.quantize(colors=192, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
        image.convert("RGBA").save(destination)
        print(f"{destination.relative_to(ROOT)}: {size[0]}x{size[1]}")


if __name__ == "__main__":
    fit(SOURCE / "menu_v2_source.png", OUTPUT / "menu.png", (752, 360))
    fit(SOURCE / "arrival_v2_source.png", OUTPUT / "arrival.png", (640, 360))
