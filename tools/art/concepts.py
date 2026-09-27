"""Concept-board -> game-ready sprite conversion (Handoff §83: AI concept art must be
converted into consistent game-ready sprites before use).

Pipeline per asset: crop from a board -> key out the dark board background (border-connected
flood region) -> de-fringe -> area-downscale in premultiplied alpha -> unsharp -> binary alpha ->
palette quantise (per-asset, then snapped to the shared City Venture ramp) -> optional 1px outline.

Boards live in docs/reference/concept_boards/. Everything here is deterministic, so the art can be
regenerated from source at any time (tools/art/gen_placeholders.py calls generate()).
"""
from __future__ import annotations

import json
import os
from functools import lru_cache

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

try:
    import cv2  # type: ignore
except Exception:  # pragma: no cover - optional, only needed for keying
    cv2 = None

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BOARDS = os.path.join(ROOT, "docs", "reference", "concept_boards")
BOARD_FILES = {
    "A": "A_baseline_character_world_ui.webp",
    "C": "C_day_city.png",
    "D": "D_night_luxury.png",
    "E": "E_world_map_hi.png",
    "F": "F_city_map_hi.png",
    "G": "G_building_exteriors_hi.png",
    "H": "H_building_interiors.webp",
}


@lru_cache(maxsize=None)
def board(key: str) -> np.ndarray:
    return np.asarray(Image.open(os.path.join(BOARDS, BOARD_FILES[key])).convert("RGB")).copy()


def crop(key: str, box) -> np.ndarray:
    x0, y0, x1, y1 = box
    return board(key)[y0:y1, x0:x1].copy()


# --------------------------------------------------------------------------- keying
def key_background(rgb: np.ndarray, tol: float = 30.0, bg=None, grow: int = 1) -> np.ndarray:
    """Return RGBA where the board background connected to the crop border is transparent."""
    h, w, _ = rgb.shape
    f = rgb.astype(np.float32)
    if bg is None:
        border = np.concatenate([f[0], f[-1], f[:, 0], f[:, -1]])
        bg = np.median(border, axis=0)
    d = np.sqrt(((f - np.asarray(bg, np.float32)) ** 2).sum(-1))
    # background = low distance to bg colour AND dark-ish (board panels are navy)
    cand = (d < tol).astype(np.uint8)
    n, lab = cv2.connectedComponents(cand, connectivity=4)
    touch = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]])).tolist())
    touch.discard(0)
    bgmask = np.isin(lab, list(touch)) & (cand > 0)
    # fringe: pixels next to background that are still close-ish to bg get dropped too
    if grow > 0:
        k = np.ones((3, 3), np.uint8)
        near = cv2.dilate(bgmask.astype(np.uint8), k, iterations=grow) > 0
        bgmask |= near & (d < tol * 1.8)
    a = np.where(bgmask, 0, 255).astype(np.uint8)
    # drop tiny islands (text specks, noise)
    n2, lab2, stats, _ = cv2.connectedComponentsWithStats((a > 0).astype(np.uint8), connectivity=8)
    for i in range(1, n2):
        if stats[i, cv2.CC_STAT_AREA] < 6:
            a[lab2 == i] = 0
    return np.dstack([rgb, a])


def components(rgba: np.ndarray, merge: int = 3, min_area: int = 60):
    """Bounding boxes of opaque blobs (after dilating by `merge` px)."""
    m = (rgba[..., 3] > 0).astype(np.uint8)
    if merge:
        m = cv2.dilate(m, np.ones((merge * 2 + 1, merge * 2 + 1), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    out = []
    for i in range(1, n):
        x, y, w, h, area = stats[i]
        if area >= min_area:
            out.append((int(x), int(y), int(x + w), int(y + h)))
    out.sort(key=lambda b: (b[0], b[1]))
    return out


# --------------------------------------------------------------------------- resampling
def downscale(rgba: np.ndarray, size) -> np.ndarray:
    """Area-average in premultiplied alpha (no dark halos), then binarise alpha."""
    w, h = size
    f = rgba.astype(np.float32) / 255.0
    a = f[..., 3:4]
    pm = np.concatenate([f[..., :3] * a, a], -1)
    r = cv2.resize(pm, (w, h), interpolation=cv2.INTER_AREA)
    alpha = r[..., 3:4]
    rgb = np.where(alpha > 1e-4, r[..., :3] / np.maximum(alpha, 1e-4), 0)
    out = np.concatenate([np.clip(rgb, 0, 1), (alpha > 0.5).astype(np.float32)], -1)
    return (out * 255).round().astype(np.uint8)


def resize_rgb(rgb: np.ndarray, size) -> np.ndarray:
    return cv2.resize(rgb, size, interpolation=cv2.INTER_AREA)


def unsharp(rgb: np.ndarray, amount: float = 0.6, radius: float = 1.0) -> np.ndarray:
    f = rgb.astype(np.float32)
    blur = cv2.GaussianBlur(f, (0, 0), radius)
    return np.clip(f + (f - blur) * amount, 0, 255).astype(np.uint8)


def boost(rgb: np.ndarray, sat: float = 1.08, contrast: float = 1.05) -> np.ndarray:
    f = rgb.astype(np.float32) / 255.0
    g = f.mean(-1, keepdims=True)
    f = g + (f - g) * sat
    f = 0.5 + (f - 0.5) * contrast
    return (np.clip(f, 0, 1) * 255).astype(np.uint8)


def quantize(rgba: np.ndarray, colors: int = 32) -> np.ndarray:
    rgb = Image.fromarray(np.ascontiguousarray(rgba[..., :3]))
    a = rgba[..., 3]
    q = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.asarray(q), a])
    out[a == 0, :3] = 0
    return out


def outline(rgba: np.ndarray, color=(18, 24, 40), only_dark_edges: bool = False) -> np.ndarray:
    """1px outline around the silhouette on transparent neighbours (pixel-art 'clean outline')."""
    a = rgba[..., 3] > 0
    k = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], np.uint8)
    ring = (cv2.dilate(a.astype(np.uint8), k) > 0) & ~a
    out = rgba.copy()
    out[ring] = (*color, 255)
    return out


def darken_edge(rgba: np.ndarray, f: float = 0.55) -> np.ndarray:
    """Darken the outermost opaque ring instead of adding pixels (keeps sprite size)."""
    a = rgba[..., 3] > 0
    k = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], np.uint8)
    inner = cv2.erode(a.astype(np.uint8), k, borderValue=0) > 0
    edge = a & ~inner
    out = rgba.copy()
    out[edge, :3] = (out[edge, :3].astype(np.float32) * f + np.array([14, 18, 34]) * (1 - f)).astype(np.uint8)
    return out


def trim(rgba: np.ndarray) -> np.ndarray:
    ys, xs = np.nonzero(rgba[..., 3])
    if len(xs) == 0:
        return rgba
    return rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def fit_canvas(rgba: np.ndarray, canvas, anchor: str = "bottom", pad: int = 0) -> np.ndarray:
    """Scale sprite art to fit inside `canvas` (w,h) keeping aspect, anchored bottom-centre."""
    cw, ch = canvas
    h, w = rgba.shape[:2]
    s = min((cw - pad * 2) / w, (ch - pad) / h)
    nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
    small = downscale(rgba, (nw, nh))
    out = np.zeros((ch, cw, 4), np.uint8)
    x = (cw - nw) // 2
    y = ch - nh if anchor == "bottom" else (ch - nh) // 2
    out[y:y + nh, x:x + nw] = small
    return out


def sprite(key, box, canvas=None, scale=None, tol=30.0, colors=32, edge=True, sharpen=0.5,
           sat=1.06, keep=None, anchor="bottom", pad=0, bg=None, grow=1, stretch=False) -> np.ndarray:
    """Full conversion of one board region into a game sprite."""
    rgb = crop(key, box)
    rgba = key_background(rgb, tol=tol, bg=bg, grow=grow)
    if keep is not None:  # keep only the blob(s) intersecting these local boxes
        mask = np.zeros(rgba.shape[:2], bool)
        m = (rgba[..., 3] > 0).astype(np.uint8)
        n, lab = cv2.connectedComponents(m, connectivity=8)
        for (x0, y0, x1, y1) in keep:
            ids = np.unique(lab[y0:y1, x0:x1])
            mask |= np.isin(lab, ids[ids > 0])
        rgba[~mask, 3] = 0
    rgba = trim(rgba)
    rgba[..., :3] = boost(rgba[..., :3], sat=sat)
    if canvas is not None and stretch:
        small = downscale(rgba, canvas)
    elif canvas is not None:
        small = fit_canvas(rgba, canvas, anchor=anchor, pad=pad)
    else:
        h, w = rgba.shape[:2]
        small = downscale(rgba, (max(1, int(round(w * scale))), max(1, int(round(h * scale)))))
    if sharpen:
        small[..., :3] = unsharp(small[..., :3], sharpen)
    small = quantize(small, colors)
    if edge:
        small = darken_edge(small)
    return small


def scene(key, box, size, colors=96, sharpen=0.45, sat=1.05) -> np.ndarray:
    """A full-bleed backdrop (no keying)."""
    rgb = crop(key, box)
    small = resize_rgb(rgb, size)
    if sharpen:
        small = unsharp(small, sharpen)
    small = boost(small, sat=sat)
    q = Image.fromarray(small).quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB"))


def save(arr: np.ndarray, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    Image.fromarray(arr).save(path)


# --------------------------------------------------------------------------- survey tool
def survey(key, box, out, tol=30.0, merge=3, min_area=60, zoom=3):
    """Annotated contact sheet of detected blobs (dev aid for picking crop boxes)."""
    rgb = crop(key, box)
    rgba = key_background(rgb, tol=tol)
    comps = components(rgba, merge=merge, min_area=min_area)
    vis = Image.fromarray(rgba).convert("RGBA")
    bgc = Image.new("RGBA", vis.size, (255, 0, 255, 255))
    bgc.alpha_composite(vis)
    big = bgc.resize((vis.width * zoom, vis.height * zoom), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for i, (x0, y0, x1, y1) in enumerate(comps):
        d.rectangle([x0 * zoom, y0 * zoom, x1 * zoom - 1, y1 * zoom - 1], outline=(0, 255, 0))
        d.text((x0 * zoom + 2, y0 * zoom + 2), str(i), fill=(255, 255, 0))
    big.save(out)
    bx, by = box[0], box[1]
    return [(i, (bx + c[0], by + c[1], bx + c[2], by + c[3])) for i, c in enumerate(comps)]


def key_floor(rgba: np.ndarray, tol: float = 26.0, rows: int = 3) -> np.ndarray:
    """Also remove a light ground strip (board 'sidewalk' under street props) touching the bottom edge."""
    rgb = rgba[..., :3].astype(np.float32)
    a = rgba[..., 3] > 0
    bottom = rgb[-rows:][a[-rows:]]
    if len(bottom) == 0:
        return rgba
    ref = np.median(bottom, axis=0)
    d = np.sqrt(((rgb - ref) ** 2).sum(-1))
    cand = ((d < tol) & a).astype(np.uint8)
    n, lab = cv2.connectedComponents(cand, connectivity=4)
    ids = set(np.unique(lab[-1]).tolist()) - {0}
    out = rgba.copy()
    out[np.isin(lab, list(ids)), 3] = 0
    return out


# --------------------------------------------------------------------------- asset specs
# name: (board, box, design_wh, dict(opts))
#   fit: "w" = art width -> design width, "h" = art height -> design height, or a float scale
#   The texture canvas grows past the design box when the art is bigger; the overhang is written to
#   sprite_meta.json ({"top": px above, "left": px left of the design box}) so placement data and
#   collisions stay valid.
STREET = {
    "lamp": ("C", (792, 850, 830, 1062), (20, 72), {"fit": "h", "floor": True, "glow": [10, 8], "largest": 1.0, "drop_blue": True}),
    "lamp_banner": ("C", (792, 850, 830, 1062), (20, 72), {"fit": "h", "floor": True, "glow": [10, 8], "largest": 1.0}),
    "bench": ("C", (829, 863, 900, 914), (36, 22), {"fit": "w"}),
    "tree_round": ("A", (1163, 806, 1237, 886), (64, 92), {"fit": 1.0, "colors": 40, "largest": 1.0}),
    "tree_round_b": ("G", (1029, 921, 1085, 1021), (64, 92), {"fit": "h", "colors": 40}),
    "tree_tall": ("C", (900, 849, 953, 972), (34, 90), {"fit": "h", "colors": 40, "largest": 1.0}),
    "planter": ("C", (1125, 993, 1201, 1064), (36, 30), {"fit": "w", "floor": True, "largest": 1.0}),
    "planter_small": ("C", (866, 969, 898, 1022), (24, 22), {"fit": 0.6}),
    "flower_bed": ("C", (963, 919, 1039, 965), (36, 18), {"fit": "w"}),
    "trash_bin": ("C", (970, 867, 1001, 918), (18, 22), {"fit": "h"}),
    "digital_sign": ("C", (1041, 931, 1083, 1052), (22, 46), {"fit": 0.46, "floor": True}),
    "metro_sign": ("C", (1085, 921, 1128, 1062), (18, 50), {"fit": 0.42, "floor": True}),
    "cafe_board": ("C", (895, 1001, 941, 1064), (16, 22), {"fit": "h", "floor": True}),
    "cone": ("C", (848, 1016, 884, 1063), (10, 14), {"fit": "h", "floor": True}),
    "bollard": ("G", (1255, 1007, 1281, 1067), (8, 16), {"fit": "h"}),
}

INTERIOR = {
    "desk_laptop": ("H", (16, 365, 77, 418), (48, 34), {"fit": "w"}),
    "desk": ("H", (16, 365, 77, 418), (44, 30), {"fit": "w"}),
    "office_chair": ("H", (85, 367, 116, 413), (18, 26), {"fit": 0.62, "tol": 16}),
    "whiteboard": ("H", (181, 367, 241, 420), (66, 42), {"fit": 0.95}),
    "bookshelf": ("H", (252, 368, 289, 420), (34, 52), {"fit": 1.0}),
    "plant": ("H", (296, 369, 331, 419), (18, 30), {"fit": 0.66}),
    "plant_big": ("H", (340, 370, 382, 420), (26, 44), {"fit": 0.9}),
    "exec_desk": ("H", (536, 367, 608, 416), (66, 38), {"fit": "w"}),
    "chair": ("H", (618, 366, 659, 416), (18, 26), {"fit": 0.6, "tol": 16}),
    "sofa": ("H", (700, 373, 753, 416), (52, 30), {"fit": 1.0, "largest": 1.0}),
    "bed": ("H", (1023, 370, 1085, 418), (46, 58), {"fit": 0.95}),
    "coffee_table": ("H", (1134, 368, 1177, 415), (34, 20), {"fit": 0.85}),
    "tv": ("H", (1223, 369, 1271, 414), (48, 38), {"fit": 1.0, "tol": 12}),
    "kitchen": ("H", (1314, 368, 1376, 416), (66, 46), {"fit": 1.05}),
    "atm": ("H", (186, 690, 226, 744), (24, 42), {"fit": 0.8}),
    "plant_bank": ("H", (235, 690, 280, 745), (26, 44), {"fit": 0.8}),
    "brochure_stand": ("H", (294, 694, 329, 745), (16, 30), {"fit": 0.62}),
    "queue_barrier": ("H", (349, 697, 404, 742), (52, 24), {"fit": 0.95}),
    "waiting_sofa": ("H", (98, 700, 180, 743), (50, 30), {"fit": 0.7}),
    "cafe_table": ("H", (522, 692, 578, 744), (26, 24), {"fit": 0.55}),
    "cafe_chair": ("H", (583, 695, 620, 745), (14, 22), {"fit": 0.5}),
    "armchair": ("H", (624, 700, 665, 745), (22, 24), {"fit": 0.55}),
    "display_case": ("H", (736, 698, 780, 744), (42, 32), {"fit": 0.95}),
    "hanging_light": ("H", (898, 686, 938, 745), (14, 30), {"fit": 0.5}),
    "monitor_desk": ("H", (1058, 695, 1128, 743), (66, 36), {"fit": "w"}),
    "filing_cabinet": ("H", (1262, 697, 1287, 744), (20, 36), {"fit": 0.8}),
    "lockers": ("H", (344, 1000, 388, 1049), (38, 46), {"fit": 0.95}),
    "phone_booth": ("H", (235, 994, 274, 1052), (28, 48), {"fit": 0.85}),
    "lounge_sofa": ("H", (280, 996, 340, 1048), (58, 30), {"fit": 0.95}),
    "ticket_machine": ("A", (1265, 807, 1299, 864), (20, 36), {"fit": "h", "largest": 1.0}),
    "info_kiosk": ("A", (1386, 802, 1425, 872), (22, 36), {"fit": "h", "largest": 1.0}),
    "community_table": ("H", (16, 995, 100, 1052), (66, 44), {"fit": 0.8}),
    "server_rack": ("H", (1133, 695, 1173, 744), (24, 40), {"fit": 0.8, "largest": 1.0}),
}
# composites: several board pieces side by side in one sprite (long counters)
COMPOSITE = {
    "bank_counter": ([("H", (19, 691, 94, 742)), ("H", (19, 691, 94, 742))], (144, 44), 1.0),
    "civic_counter": ([("H", (19, 691, 94, 742)), ("H", (19, 691, 94, 742))], (144, 44), 1.0),
    "cafe_counter": ([("H", (671, 694, 731, 745)), ("H", (736, 698, 780, 744))], (100, 44), 0.98),
}


def _cut(key, box, tol=30.0, floor=False, largest=0.04):
    rgba = key_background(crop(key, box), tol=tol)
    if floor:
        rgba = key_floor(rgba)
    # keep the largest blob plus anything comparably big (drops label text / neighbour specks)
    m = (rgba[..., 3] > 0).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    if n > 2:
        big = stats[1:, cv2.CC_STAT_AREA].max()
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] < big * min(largest, 0.999):
                rgba[lab == i, 3] = 0
    return trim(rgba)


def _despeckle(rgba, max_px=2):
    m = (rgba[..., 3] > 0).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] <= max_px:
            rgba[lab == i, 3] = 0
    return rgba


def _finish(rgba, colors=32, sharpen=0.5, edge=True):
    rgba = _despeckle(rgba)
    rgba[..., :3] = unsharp(rgba[..., :3], sharpen) if sharpen else rgba[..., :3]
    rgba = quantize(rgba, colors)
    return darken_edge(rgba) if edge else rgba


def _place(art, design):
    """Put art bottom-centred on the design box; grow canvas if needed. Returns (img, meta)."""
    dw, dh = design
    ah, aw = art.shape[:2]
    left = max(0, (aw - dw + 1) // 2)
    top = max(0, ah - dh)
    cw, ch = max(dw, aw) + (1 if aw > dw and (aw - dw) % 2 else 0), max(dh, ah)
    cw = max(cw, left * 2 + dw)
    out = np.zeros((ch, cw, 4), np.uint8)
    x = left + (dw - aw) // 2
    out[ch - ah:ch, x:x + aw] = art
    meta = {}
    if top:
        meta["top"] = top
    if left:
        meta["left"] = left
    if meta:
        meta["dw"], meta["dh"] = dw, dh
    return out, meta


def build_sprite(key, box, design, opts):
    art = _cut(key, box, tol=opts.get("tol", 30.0), floor=opts.get("floor", False), largest=opts.get("largest", 0.04))
    if opts.get("drop_blue"):  # strip the hanging banners off the banner lamp -> plain lamp post
        f = art[..., :3].astype(np.int32)
        blue = (f[..., 2] > f[..., 0] + 40) & (f[..., 2] > 90) | ((f[..., :3].min(-1) > 170) & (np.arange(art.shape[1])[None, :] != art.shape[1] // 2))
        pole = np.zeros(art.shape[:2], bool)
        cx = art.shape[1] // 2
        pole[:, cx - 2:cx + 2] = True
        art[blue & ~pole, 3] = 0
        f2 = art[..., :3].astype(np.int32)
        art[(f2[..., 2] > f2[..., 0] + 40) & (f2[..., 2] > 90), :3] = (34, 38, 52)  # banner edge on the pole -> pole colour
        m = (art[..., 3] > 0).astype(np.uint8)
        n, lab, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
        if n > 2:
            keep = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
            art[(lab != keep), 3] = 0
        art = trim(art)
    art[..., :3] = boost(art[..., :3], sat=opts.get("sat", 1.06))
    ah, aw = art.shape[:2]
    fit = opts.get("fit", "w")
    s = design[0] / aw if fit == "w" else (design[1] / ah if fit == "h" else float(fit))
    art = downscale(art, (max(1, round(aw * s)), max(1, round(ah * s))))
    art = _finish(art, opts.get("colors", 32), opts.get("sharpen", 0.5))
    return _place(art, design)


def build_composite(parts, design, s):
    pieces = []
    for key, box in parts:
        p = _cut(key, box)
        p[..., :3] = boost(p[..., :3])
        pieces.append(downscale(p, (max(1, round(p.shape[1] * s)), max(1, round(p.shape[0] * s)))))
    h = max(p.shape[0] for p in pieces)
    w = sum(p.shape[1] for p in pieces) - 2 * (len(pieces) - 1)
    art = np.zeros((h, w, 4), np.uint8)
    x = 0
    for p in pieces:
        region = art[h - p.shape[0]:h, x:x + p.shape[1]]
        m = p[..., 3] > 0
        region[m] = p[m]
        x += p.shape[1] - 2
    if w > design[0]:
        art = downscale(art, (design[0], max(1, round(h * design[0] / w))))
    art = _finish(art)
    return _place(art, design)


# --------------------------------------------------------------------------- windows (interiors)
SKY_DAY = ("G", (700, 2, 1330, 128))
SKY_NIGHT = ("D", (770, 2, 1350, 132))
SKY_GOLD = ("A", (660, 2, 1350, 132))


def _pane(src, w, h, x_frac=0.0):
    key, (x0, y0, x1, y1) = src
    sw, sh = x1 - x0, y1 - y0
    # take a window-shaped slice of the banner (cover), offset along the skyline for variety
    ch = sh
    cw = int(round(ch * w / h))
    if cw > sw:
        cw, ch = sw, int(round(sw * h / w))
    cx = x0 + int((sw - cw) * x_frac)
    cy = y0 + (sh - ch)
    return resize_rgb(crop(key, (cx, cy, cx + cw, cy + ch)), (w, h))


def window_sprite(night, w, h, x_frac):
    img = np.zeros((h, w, 4), np.uint8)
    frame = np.array([62, 68, 84])
    img[..., :3] = frame
    img[..., 3] = 255
    pane = _pane(SKY_NIGHT if night else SKY_DAY, w - 4, h - 5, x_frac)
    pane = unsharp(pane, 0.4)
    img[2:h - 3, 2:w - 2, :3] = pane
    # glass sheen: two soft diagonal highlights
    if not night:
        for y in range(2, h - 3):
            for dx, a in ((0, 0.22), (1, 0.16), (5, 0.12)):
                x = 2 + (y * 3) // 4 + dx + w // 5
                if 2 <= x < w - 2:
                    img[y, x, :3] = (img[y, x, :3] * (1 - a) + 255 * a).astype(np.uint8)
    # mullions + transom
    img[1:h - 2, w // 2, :3] = frame
    img[h // 3, 1:w - 1, :3] = frame
    # curtains (soft linen folds) and sill
    lin = [np.array([232, 224, 208]), np.array([214, 204, 186]), np.array([196, 186, 168])]
    for i in range(4):
        img[1:h - 2, 1 + i, :3] = lin[i % 3]
        img[1:h - 2, w - 2 - i, :3] = lin[(i + 1) % 3]
    img[h - 3:h, :, :3] = np.array([226, 228, 232])
    img[h - 1, :, :3] = np.array([150, 154, 164])
    img[0, :, :3] = np.array([44, 48, 60])
    return quantize(img, 48)


# --------------------------------------------------------------------------- backdrops & cards
def cover(key, box, size, colors=128, sharpen=0.4):
    """Scale a board region to *cover* size (crop the overflow, centred)."""
    x0, y0, x1, y1 = box
    w, h = size
    sw, sh = x1 - x0, y1 - y0
    s = max(w / sw, h / sh)
    cw, ch = int(round(w / s)), int(round(h / s))
    cx, cy = x0 + (sw - cw) // 2, y0 + (sh - ch) // 2
    return scene(key, (cx, cy, cx + cw, cy + ch), size, colors=colors, sharpen=sharpen)


def _fix_city_hall_sign(rgb: np.ndarray, ox: int, oy: int) -> np.ndarray:
    """Board G's City Hall says 'RIVERDALE'; this city is Aurelia. Inpaint and re-letter the sign."""
    from PIL import ImageFont
    x0, y0, x1, y1 = 704 - ox, 549 - oy, 764 - ox, 568 - oy
    if x1 <= 0 or y1 <= 0 or x0 >= rgb.shape[1] or y0 >= rgb.shape[0]:
        return rgb
    x0, y0 = max(0, x0), max(0, y0)
    region = rgb[y0:y1, x0:x1].astype(np.int32)
    mask = np.zeros(rgb.shape[:2], np.uint8)
    mask[y0:y1, x0:x1] = (region.sum(-1) < 420).astype(np.uint8) * 255
    mask = cv2.dilate(mask, np.ones((3, 3), np.uint8))
    out = cv2.inpaint(np.ascontiguousarray(rgb), mask, 3, cv2.INPAINT_TELEA)
    im = Image.fromarray(out)
    d = ImageDraw.Draw(im)
    font = ImageFont.truetype(os.path.join(ROOT, "game", "assets", "fonts", "Inter.ttf"), 12)
    try:
        font.set_variation_by_axes([760])
    except Exception:
        pass
    text = "AURELIA"
    tw = d.textlength(text, font=font)
    d.text(((x0 + x1) / 2 - tw / 2, y0 + 1), text, font=font, fill=(34, 46, 92))
    return np.asarray(im)


def card(key, box, size=(192, 108), fix=None):
    x0, y0, x1, y1 = box
    rgb = crop(key, box)
    if fix == "city_hall":
        rgb = _fix_city_hall_sign(rgb, x0, y0)
    small = resize_rgb(rgb, size)
    small = boost(unsharp(small, 0.4), sat=1.05)
    q = Image.fromarray(small).quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB"))


CARDS = {
    "riverside": ("C", (100, 548, 562, 808), None),
    "financial": ("C", (60, 172, 657, 508), None),
    "startup_hub": ("F", (880, 840, 1262, 1055), None),
    "civic_center": ("G", (508, 510, 888, 724), "city_hall"),
    "city_hall": ("G", (508, 510, 888, 724), "city_hall"),
    "nexus_bank": ("G", (452, 170, 760, 343), None),
    "riverside_apartment": ("H", (1025, 165, 1330, 337), None),
    "bloom_coffee": ("G", (1062, 230, 1368, 402), None),
    "byte_and_bean": ("H", (518, 480, 835, 658), None),
    "nexus_cowork": ("H", (30, 797, 377, 992), None),
    "small_office": ("H", (16, 157, 380, 362), None),
}

# Board F district marker tiles (image part only) and Board E region previews
DISTRICT_TILES = {
    "financial": (18, 876, 106, 935), "startup_hub": (114, 876, 202, 935), "riverside": (210, 876, 298, 935),
    "harbor": (307, 876, 396, 935), "residential": (403, 876, 497, 935),
    "shopping_street": (18, 980, 106, 1042), "civic_center": (114, 980, 202, 1042),
    "luxury_heights": (210, 980, 298, 1042), "airport": (307, 980, 396, 1042), "metro": (403, 980, 497, 1042),
    "old_town": (214, 392, 334, 467), "university": (640, 228, 760, 303), "industrial": (60, 585, 200, 672),
}
REGION_PREVIEWS = {
    "northridge": ("E", (18, 580, 116, 682)), "auroria": ("E", (123, 580, 231, 682)),
    "zenkai": ("E", (239, 580, 346, 682)), "solterra": ("E", (356, 580, 459, 682)),
    "almeria": ("E", (468, 580, 576, 682)), "karu": ("E", (586, 580, 699, 682)),
    "lumina": ("E", (709, 580, 829, 682)), "aurelia": ("E", (1000, 250, 1300, 480)),
}
CITY_MAP_BOX = (14, 155, 990, 805)
CITY_MAP_SIZE = (458, 305)
WORLD_MAP_BOX = (12, 150, 940, 545)
WORLD_MAP_SIZE = (600, 255)


def skyline_strip(src, size=(1300, 320), top=None):
    """Banner skyline mirrored into a wide strip, sky extended upward with the banner's own top colour."""
    key, box = src
    band = crop(key, box)
    bh = band.shape[0]
    wide = np.concatenate([band, band[:, ::-1]], axis=1)
    wide = resize_rgb(wide, (size[0], int(round(bh * size[0] / wide.shape[1]))))
    bh = wide.shape[0]
    out = np.zeros((size[1], size[0], 3), np.uint8)
    edge = wide[:4].reshape(-1, 3).astype(np.float32).mean(0)
    top = np.array(top if top is not None else edge * 0.55, np.float32)
    ys = size[1] - bh
    for y in range(ys):
        t = y / max(1, ys - 1)
        out[y] = (top * (1 - t) + edge * t).astype(np.uint8)
    out[ys:] = wide
    # blend the seam between gradient and banner
    for i in range(6):
        a = (i + 1) / 7
        out[ys + i] = (out[ys + i] * a + edge * (1 - a)).astype(np.uint8)
    q = Image.fromarray(unsharp(out, 0.3)).quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB"))


def arrival_backdrop():
    """640x360 dusk: extended sky, Board D skyline, river with a rippled reflection (train/bridge drawn in-game)."""
    W, H = 640, 360
    key, (x0, y0, x1, y1) = SKY_NIGHT
    band = crop(key, (860, y0, x1, y1 - 6))
    s = W / band.shape[1]
    band = resize_rgb(band, (W, int(round(band.shape[0] * s))))
    bh = band.shape[0]
    horizon = 262
    out = np.zeros((H, W, 3), np.float32)
    ys = horizon - bh
    edge = band[:3].reshape(-1, 3).astype(np.float32).mean(0)
    top = np.array([16, 20, 48], np.float32)
    for y in range(ys):
        t = (y / max(1, ys - 1)) ** 1.4
        out[y] = top * (1 - t) + edge * t
    rng = np.random.default_rng(7)
    for _ in range(70):
        x, y = rng.integers(0, W), rng.integers(0, int(ys * 0.8))
        out[y, x] = np.minimum(255, out[y, x] + rng.uniform(60, 160))
    out[ys:horizon] = band
    for i in range(8):
        a = (i + 1) / 9
        out[ys + i] = out[ys + i] * a + edge * (1 - a)
    # river: flipped skyline, darkened, blue-shifted, horizontally rippled
    refl = band[::-1].astype(np.float32)
    for y in range(horizon, H):
        k = y - horizon
        src = refl[min(k, bh - 1)] if k < bh else refl[-1]
        shift = int(round(np.sin(k * 0.9) * (1 + k * 0.05)))
        row = np.roll(src, shift, axis=0)
        fade = 0.55 * np.exp(-k / 90.0)
        water = np.array([22, 30, 66], np.float32) * (1 + k / 300)
        out[y] = row * fade + water * (1 - fade)
    for _ in range(90):  # glints
        x, y = rng.integers(0, W - 8), rng.integers(horizon + 4, H)
        out[y, x:x + rng.integers(2, 8)] += np.array([80, 60, 30], np.float32)
    rgb = np.clip(out, 0, 255).astype(np.uint8)
    q = Image.fromarray(unsharp(rgb, 0.3)).quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB"))


# --------------------------------------------------------------------------- entry point
def generate(assets_dir: str) -> None:
    if cv2 is None:
        print("concepts: OpenCV missing, board conversion skipped (pip install opencv-python-headless)")
        return
    meta = {}
    for name, (k, b, d, o) in STREET.items():
        img, m = build_sprite(k, b, d, o)
        save(img, os.path.join(assets_dir, "props", name + ".png"))
        if "glow" in o:
            m["glow"] = o["glow"]
            m.setdefault("dw", d[0])
            m.setdefault("dh", d[1])
        if m:
            meta["props/" + name] = m
    for name, (k, b, d, o) in INTERIOR.items():
        img, m = build_sprite(k, b, d, o)
        save(img, os.path.join(assets_dir, "interiors", name + ".png"))
        if m:
            meta["interiors/" + name] = m
    for name, (parts, d, s) in COMPOSITE.items():
        img, m = build_composite(parts, d, s)
        save(img, os.path.join(assets_dir, "interiors", name + ".png"))
        if m:
            meta["interiors/" + name] = m
    for night in (False, True):
        sfx = "night" if night else "day"
        save(window_sprite(night, 52, 42, 0.18), os.path.join(assets_dir, "interiors", "window_%s.png" % sfx))
        save(window_sprite(night, 96, 48, 0.55), os.path.join(assets_dir, "interiors", "window_wide_%s.png" % sfx))
    with open(os.path.join(assets_dir, "sprite_meta.json"), "w") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
    bd = os.path.join(assets_dir, "backdrops")
    save(cover("C", (736, 172, 1438, 508), (752, 360)), os.path.join(bd, "menu.png"))
    save(arrival_backdrop(), os.path.join(bd, "arrival.png"))
    save(skyline_strip(SKY_DAY, top=(92, 150, 226)), os.path.join(bd, "skyline_day.png"))
    save(skyline_strip(SKY_NIGHT, top=(14, 18, 44)), os.path.join(bd, "skyline_night.png"))
    for cid, (k, b, fix) in CARDS.items():
        save(card(k, b, fix=fix), os.path.join(assets_dir, "cards", cid + ".png"))
    save(scene("F", CITY_MAP_BOX, CITY_MAP_SIZE, colors=160, sharpen=0.35), os.path.join(assets_dir, "city_map", "board.png"))
    save(scene("E", WORLD_MAP_BOX, WORLD_MAP_SIZE, colors=160, sharpen=0.35), os.path.join(assets_dir, "world_map", "board.png"))
    for did, b in DISTRICT_TILES.items():
        k, box = ("F", b)
        if did in CARDS:
            k, box = CARDS[did][0], CARDS[did][1]
        img = card(k, box, (144, 90), fix=CARDS.get(did, (0, 0, None))[2]) if did in CARDS else cover(k, box, (144, 90), colors=128)
        save(img, os.path.join(assets_dir, "city_map", "i_" + did + ".png"))
    for rid, (k, b) in REGION_PREVIEWS.items():
        save(cover(k, b, (64, 40), colors=96), os.path.join(assets_dir, "world_map", "r_" + rid + ".png"))
    generate_floors(assets_dir)
    print("concepts: board conversion done (%d sprites with overhang meta)" % len(meta))


if __name__ == "__main__":
    import sys
    generate(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "game", "assets"))


# --------------------------------------------------------------------------- continuous interior floors
# One large non-repeating floor image per material (the boards' interiors read as continuous wood /
# polished stone with light pooling, not a visible 16px tile grid).
def _noise(h, w, scale, rng):
    small = rng.random((max(2, h // scale + 2), max(2, w // scale + 2))).astype(np.float32)
    return cv2.resize(small, (w, h), interpolation=cv2.INTER_CUBIC)


def floor_image(kind, w=512, h=320, seed=5):
    rng = np.random.default_rng(seed + sum(map(ord, kind)))
    img = np.zeros((h, w, 3), np.float32)
    if kind in ("wood_warm", "wood_dark", "wood_cafe"):
        base = {"wood_warm": (184, 132, 88), "wood_dark": (120, 84, 58), "wood_cafe": (150, 100, 66)}[kind]
        ph = 6
        for y0 in range(0, h, ph):
            x = -rng.integers(0, 90)
            while x < w:
                L = int(rng.integers(70, 150))
                c = np.array(base, np.float32) * rng.uniform(0.86, 1.1) + rng.uniform(-6, 6, 3)
                x0, x1 = max(0, x), min(w, x + L)
                if x1 > x0:
                    seg = np.tile(c, (ph, x1 - x0, 1))
                    grain = _noise(ph, x1 - x0, 9, rng)[..., None] * 0.14 + 0.93
                    seg = seg * grain
                    seg[0] = seg[0] * 1.07          # lit top edge
                    seg[-1] = seg[-1] * 0.72        # plank gap
                    img[y0:y0 + ph, x0:x1] = seg[:min(ph, h - y0)]
                    img[y0:y0 + ph - 1, x0] *= 0.78  # butt joint
                x += L
    elif kind == "marble":
        slab = 40
        v = _noise(h, w, 70, rng) + _noise(h, w, 24, rng) * 0.35
        veins = (np.abs(np.sin(v * 1.6 * np.pi)) < 0.03).astype(np.float32)
        veins = cv2.GaussianBlur(veins, (0, 0), 0.8)
        img[:] = np.array([238, 234, 226], np.float32)
        img -= veins[..., None] * np.array([18, 18, 16], np.float32)
        img -= (_noise(h, w, 34, rng)[..., None] - 0.5) * 16
        for y in range(0, h, slab):
            img[y] *= 0.9
        for x in range(0, w, slab * 2):
            img[:, x] *= 0.92
    elif kind == "concrete":
        img[:] = np.array([176, 176, 174], np.float32)
        img += (_noise(h, w, 30, rng)[..., None] - 0.5) * 22 + (_noise(h, w, 4, rng)[..., None] - 0.5) * 8
        for y in range(0, h, 64):
            img[y] *= 0.86
        for x in range(0, w, 96):
            img[:, x] *= 0.88
    else:
        return None
    # soft sheen band + gentle vignette (light from the windows at the top)
    yy = np.linspace(0, 1, h)[:, None, None]
    xx = np.linspace(-1, 1, w)[None, :, None]
    img *= 1.06 - 0.12 * yy
    img *= 1.0 - 0.06 * (xx ** 2)
    rgb = np.clip(img, 0, 255).astype(np.uint8)
    q = Image.fromarray(rgb).quantize(colors=40, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return np.asarray(q.convert("RGB"))


def generate_floors(assets_dir):
    for k in ("wood_warm", "wood_dark", "wood_cafe", "marble", "concrete"):
        save(floor_image(k), os.path.join(assets_dir, "interiors", "floor_" + k + ".png"))
