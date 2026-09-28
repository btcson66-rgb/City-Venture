"""Rebuild the A6 map/card batch from the licensed in-repo concept boards.

Run from the repository root: python tools/art/a6_maps_cards.py
Coordinates are in final asset pixels.  Gameplay map coordinates stay untouched.
"""
from __future__ import annotations

import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw

from concepts import (
    CARDS, CITY_MAP_BOX, CITY_MAP_SIZE, DISTRICT_TILES,
    REGION_PREVIEWS, WORLD_MAP_BOX, WORLD_MAP_SIZE, crop,
)

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "game" / "assets"


def soft_crop(board: str, box: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
    """Use antialiased full-colour sampling, without the old palette reduction."""
    return Image.fromarray(crop(board, box)).resize(size, Image.Resampling.LANCZOS).convert("RGB")


def glass_panel(im: Image.Image, box: tuple[int, int, int, int], tint=(8, 28, 52)) -> None:
    """Replace painted English labels with a quiet, text-free cartographic field."""
    x0, y0, x1, y1 = box
    overlay = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(overlay)
    d.rounded_rectangle((x0, y0, x1, y1), radius=3, fill=(*tint, 255), outline=(65, 117, 160, 255), width=1)
    im.paste(Image.alpha_composite(im.convert("RGBA"), overlay).convert("RGB"))


def source_rect_to_asset(rect, source_box, target_size, pad=0):
    sx0, sy0, sx1, sy1 = source_box
    w, h = target_size
    x0, y0, x1, y1 = rect
    return (
        max(0, round((x0 - sx0) * w / (sx1 - sx0)) - pad),
        max(0, round((y0 - sy0) * h / (sy1 - sy0)) - pad),
        min(w - 1, round((x1 - sx0) * w / (sx1 - sx0)) + pad),
        min(h - 1, round((y1 - sy0) * h / (sy1 - sy0)) + pad),
    )


def city_board() -> Image.Image:
    im = soft_crop("F", CITY_MAP_BOX, CITY_MAP_SIZE)
    data = json.loads((ROOT / "game/data/city/aurelia.json").read_text(encoding="utf-8"))
    for district in data["districts"]:
        label = district.get("board", {}).get("label")
        if label:
            glass_panel(im, source_rect_to_asset(label, CITY_MAP_BOX, CITY_MAP_SIZE, pad=1))
    # The reference board also paints an English city-statistics box.
    glass_panel(im, (362, 252, 457, 304))
    # Metro Station is a runtime shortcut without a district board.label.
    glass_panel(im, (339, 194, 456, 230))
    return im


def world_board() -> Image.Image:
    im = soft_crop("E", WORLD_MAP_BOX, WORLD_MAP_SIZE)
    for path in sorted((ROOT / "game/data/regions").glob("*.json")):
        region = json.loads(path.read_text(encoding="utf-8"))
        label = region.get("board", {}).get("label")
        if label:
            glass_panel(im, source_rect_to_asset(label, WORLD_MAP_BOX, WORLD_MAP_SIZE, pad=1))
    # Replace the concept board's English tagline with ocean texture so no
    # unused empty label box remains in the bottom-left corner.
    sea = im.crop((2, 188, 145, 220)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    im.paste(sea, (2, 222))
    return im


def metro_board() -> Image.Image:
    """Quiet metro street diagram; the coloured lines are drawn by Godot."""
    scale = 3
    im = Image.new("RGB", (640 * scale, 360 * scale), (10, 29, 50))
    d = ImageDraw.Draw(im)
    s = lambda pts: [(x * scale, y * scale) for x, y in pts]
    # Low-contrast street grid with irregular blocks, sampled smoothly at 3x.
    for x in range(24, 640, 39):
        d.line(s([(x, 0), (x + 20, 360)]), fill=(26, 57, 76), width=2 * scale)
    for y in range(17, 360, 32):
        d.line(s([(0, y + 8), (640, y)]), fill=(26, 57, 76), width=2 * scale)
    for pts in (
        [(0, 91), (182, 93), (337, 76), (640, 80)],
        [(32, 0), (88, 133), (214, 224), (320, 360)],
        [(416, 0), (418, 102), (476, 200), (580, 360)],
    ):
        d.line(s(pts), fill=(43, 77, 95), width=5 * scale, joint="curve")
        d.line(s(pts), fill=(76, 111, 128), width=scale, joint="curve")
    # River and waterfront occupy the same lower-city zone as the reference map.
    d.polygon(s([(0, 284), (66, 271), (130, 270), (204, 279), (287, 260),
                 (356, 239), (439, 242), (522, 227), (640, 240),
                 (640, 294), (522, 284), (439, 292), (356, 286),
                 (287, 305), (204, 325), (130, 309), (66, 310), (0, 329)]),
              fill=(24, 79, 116))
    for y, alpha in ((267, (66, 138, 178)), (281, (41, 111, 149))):
        d.line(s([(0, y + 24), (96, y + 12), (188, y + 20), (291, y + 7),
                  (405, y - 13), (520, y - 20), (640, y - 13)]), fill=alpha, width=scale)
    for cx, cy, rx, ry in ((146, 66, 48, 24), (375, 110, 33, 20),
                            (198, 210, 42, 19), (545, 181, 27, 15)):
        d.ellipse((scale * (cx-rx), scale * (cy-ry), scale * (cx+rx), scale * (cy+ry)),
                  fill=(29, 71, 65), outline=(54, 103, 81), width=scale)
    return im.resize((640, 360), Image.Resampling.LANCZOS)


# Text and lettered-brand panels on the 192x108 cards.  Coordinates are final
# card pixels; the masks are repainted as clean sign materials / graphic icons.
TEXT_ZONES = {
    # Brand names remain as identity marks; slogans, menus and mural copy do not.
    "byte_and_bean": [(38, 35, 111, 51), (95, 7, 129, 55), (130, 7, 159, 55)],
    "city_hall": [(98, 19, 133, 39)],
    "civic_center": [(98, 19, 133, 39)],
    "financial": [(46, 18, 67, 66), (70, 20, 88, 67), (91, 51, 111, 80)],
    "nexus_cowork": [(14, 25, 80, 41)],
    "riverside": [(0, 7, 31, 55)],
    "small_office": [(32, 20, 120, 57)],
    "startup_hub": [(151, 43, 188, 78)],
}


def clean_card(card_id: str, board: str, box) -> Image.Image:
    im = soft_crop(board, box, (192, 108))
    zones = TEXT_ZONES.get(card_id, [])
    if zones:
        # Inpaint on the full-resolution crop first: narrow letters preserve the
        # surrounding facade better than a flat rectangle on the final image.
        arr = np.asarray(im).copy()
        mask = np.zeros((108, 192), np.uint8)
        for x0, y0, x1, y1 in zones:
            cv2.rectangle(mask, (x0, y0), (x1, y1), 255, -1)
        arr = cv2.inpaint(arr, mask, 4, cv2.INPAINT_TELEA)
        im = Image.fromarray(arr)
    # Re-establish architectural sign surfaces over areas with broad lettering.
    d = ImageDraw.Draw(im, "RGBA")
    if card_id == "byte_and_bean":
        d.rectangle((38, 36, 113, 50), fill=(211, 174, 145, 240))
        for left, right in ((95, 129), (130, 159)):
            d.rectangle((left, 7, right, 54), fill=(30, 35, 47, 245))
            for y in (18, 29, 40):
                d.ellipse((left + 8, y, left + 12, y + 4), fill=(210, 166, 98, 255))
    elif card_id in ("city_hall", "civic_center"):
        d.polygon([(99, 20), (132, 18), (132, 39), (99, 40)], fill=(220, 203, 174, 246))
        d.line((103, 34, 128, 33), fill=(164, 147, 126, 255), width=1)
    elif card_id == "financial":
        for b in ((47, 19, 66, 65), (71, 21, 87, 66), (92, 52, 109, 79)):
            d.rectangle(b, fill=(32, 97, 181, 252))
            cx = (b[0] + b[2]) // 2
            cy = b[1] + 13
            d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), outline=(231, 243, 250, 255), width=1)
    elif card_id == "nexus_cowork":
        d.rectangle((14, 26, 80, 41), fill=(225, 200, 163, 245))
    elif card_id == "riverside":
        d.rectangle((0, 8, 29, 53), fill=(25, 105, 182, 255))
        d.arc((15, 20, 24, 31), 0, 180, fill=(227, 243, 255, 255), width=2)
        d.arc((15, 26, 24, 38), 0, 180, fill=(227, 243, 255, 255), width=2)
    elif card_id == "small_office":
        d.polygon([(32, 22), (112, 19), (119, 55), (31, 58)], fill=(232, 219, 195, 249))
        d.line((62, 47, 77, 39, 90, 43, 107, 29), fill=(66, 105, 166, 255), width=2)
    elif card_id == "startup_hub":
        d.polygon([(152, 42), (188, 40), (188, 77), (152, 79)], fill=(225, 218, 194, 247))
    return im


def postpoint_card() -> Image.Image:
    # A dedicated street vignette using the actual PostPoint facade, rendered
    # over an in-repo city reference; no English sign is baked into this card.
    bg = clean_card("riverside", "C", CARDS["riverside"][1]).convert("RGBA")
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 94, 191, 107), fill=(148, 150, 140, 255))
    facade = Image.open(ASSETS / "buildings/postpoint.png").convert("RGBA")
    facade = facade.resize((98, 99), Image.Resampling.LANCZOS)
    fd = ImageDraw.Draw(facade)
    fd.rectangle((4, 56, 93, 71), fill=(192, 79, 67, 255))
    fd.rectangle((42, 59, 58, 67), fill=(251, 237, 217, 255))
    fd.line((50, 59, 50, 67), fill=(192, 79, 67, 255), width=1)
    bg.alpha_composite(facade, (47, 6))
    d = ImageDraw.Draw(bg)
    d.ellipse((33, 77, 45, 93), fill=(32, 107, 58, 255))
    d.ellipse((142, 76, 154, 94), fill=(41, 113, 62, 255))
    d.rectangle((0, 103, 191, 107), fill=(67, 83, 98, 255))
    return bg.convert("RGB")


def generate() -> None:
    city_board().save(ASSETS / "city_map/board.png")
    world_board().save(ASSETS / "world_map/board.png")
    metro_board().save(ASSETS / "city_map/aurelia_map.png")
    for cid, (board, box, _fix) in CARDS.items():
        if cid == "financial":
            box = (56, 216, 486, 458)  # city canyon, excluding the huge text billboard
        clean_card(cid, board, box).save(ASSETS / "cards" / f"{cid}.png")
    postpoint_card().save(ASSETS / "cards/postpoint_riverside.png")
    for did, box in DISTRICT_TILES.items():
        if did in CARDS:
            board, box = CARDS[did][:2]
            if did == "financial":
                box = (56, 216, 486, 458)
            im = clean_card(did, board, box).resize((144, 90), Image.Resampling.LANCZOS)
        else:
            im = soft_crop("F", box, (144, 90))
        im.save(ASSETS / "city_map" / f"i_{did}.png")
    for rid, (board, box) in REGION_PREVIEWS.items():
        soft_crop(board, box, (64, 40)).save(ASSETS / "world_map" / f"r_{rid}.png")
    print("A6: 15 city map, 9 world map, 12 location cards written")


if __name__ == "__main__":
    generate()
