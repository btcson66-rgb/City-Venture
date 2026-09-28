"""Finish the R7 art fixes without regenerating unrelated asset batches."""
from pathlib import Path
import sys

from PIL import Image, ImageEnhance, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
import chars
import a6_maps_cards as maps
from concepts import CARDS

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "game" / "assets"

for name in ("startup_hub", "civic_center"):
    board, box, _ = CARDS[name]
    maps.clean_card(name, board, box).resize((144, 90), Image.Resampling.LANCZOS).save(
        ASSETS / "city_map" / f"i_{name}.png")

# Suppress the oversized marble veins while retaining tile edges and a readable
# light/dark tile rhythm under the bank and city hall furniture.
floor_path = ASSETS / "interiors" / "floor_marble.png"
floor = Image.open(floor_path).convert("RGB")
smoothed = floor.filter(ImageFilter.MedianFilter(9))
smoothed = Image.blend(floor, smoothed, 0.76)
smoothed = ImageEnhance.Contrast(smoothed).enhance(1.08)
smoothed.save(floor_path)

for outfit in ("barista", "civic_staff"):
    for presentation in chars.PRESENTATIONS:
        top, detail, bottom, _, shoes, portrait, portrait_detail = chars.split_outfit_material(
            outfit, presentation)
        base = ASSETS / "characters" / f"outfit_{outfit}_{presentation}"
        top.save(f"{base}_top.png", optimize=True)
        detail.save(f"{base}_top_detail.png", optimize=True)
    portrait.save(ASSETS / "portraits" / f"outfit_{outfit}.png", optimize=True)
    portrait_detail.save(ASSETS / "portraits" / f"outfit_{outfit}_detail.png", optimize=True)

print("R7: map previews, marble floor, and two tintable uniforms written")
