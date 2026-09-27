"""Environment placeholders: ground tiles, building facades (+night lights and
metadata), street props, interior tiles/props, vehicles, product icons.

Buildings are 3/4 top-down facades whose full sprite rect is their map
footprint (collision) except the door. Each building writes
`buildings/<id>.png`, `buildings/<id>_lights.png` and an entry in
`buildings/buildings_meta.json` (door rect, sign rect, size).
"""
from __future__ import annotations

import json
import os
import random

from pixel import (PAL, Mask, new, shaded, fill, put, get, rect, hline, vline, box, save, ramp,
                   shade, lighten, mix, dither, glow, paste)
from font3x5 import draw_text, draw_text_centered, text_width

T = 16


# ================================================================ tiles
def tile_grass(v=0):
    im = new(T, T, PAL["grass_400"])
    rnd = random.Random(10 + v)
    for _ in range(14):
        x, y = rnd.randrange(T), rnd.randrange(T)
        put(im, x, y, PAL["grass_300"] if rnd.random() < 0.6 else PAL["grass_500"])
    for _ in range(4):
        x, y = rnd.randrange(T), rnd.randrange(T - 1)
        put(im, x, y, PAL["grass_300"]); put(im, x, y + 1, PAL["grass_500"])
    if v == 1:
        for (x, y, c) in ((3, 4, (240, 220, 120)), (11, 9, (240, 150, 170)), (7, 13, (250, 250, 250))):
            put(im, x, y, c)
    return im


def tile_sidewalk(v=0):
    im = new(T, T, PAL["pave_200"])
    hline(im, 0, 15, 15, PAL["pave_400"]); vline(im, 15, 0, 15, PAL["pave_400"])
    hline(im, 0, 15, 7, PAL["pave_300"])
    vline(im, 7 if v == 0 else 3, 0, 6, PAL["pave_300"]); vline(im, 11 if v == 0 else 9, 8, 14, PAL["pave_300"])
    put(im, 2, 2, (220, 214, 204)); put(im, 12, 11, (220, 214, 204))
    return im


def tile_asphalt(kind="plain"):
    im = new(T, T, PAL["asphalt_500"])
    rnd = random.Random(33)
    for _ in range(10):
        put(im, rnd.randrange(T), rnd.randrange(T), PAL["asphalt_400"] if rnd.random() < .5 else PAL["asphalt_600"])
    if kind == "dash_h":
        rect(im, 2, 7, 11, 8, (236, 232, 214))
    elif kind == "dash_v":
        rect(im, 7, 2, 8, 11, (236, 232, 214))
    elif kind == "cross_h":  # stripes running vertically, for crossing a horizontal road
        for x in (1, 6, 11):
            rect(im, x, 0, x + 3, 15, (238, 238, 232))
    elif kind == "cross_v":
        for y in (1, 6, 11):
            rect(im, 0, y, 15, y + 3, (238, 238, 232))
    elif kind == "edge_top":
        hline(im, 0, 15, 1, (230, 200, 90))
    elif kind == "edge_bottom":
        hline(im, 0, 15, 14, (230, 200, 90))
    elif kind == "parking":
        vline(im, 0, 0, 15, (230, 230, 226))
    return im


def tile_curb(top=True):
    im = tile_asphalt()
    if top:
        rect(im, 0, 0, 15, 3, PAL["concrete_400"]); hline(im, 0, 15, 3, PAL["concrete_500"]); hline(im, 0, 15, 4, PAL["asphalt_600"])
    else:
        rect(im, 0, 12, 15, 15, PAL["concrete_400"]); hline(im, 0, 15, 12, PAL["concrete_300"])
    return im


def tile_water(v=0):
    im = new(T, T, PAL["water_400"])
    rnd = random.Random(70 + v)
    for _ in range(3):
        x, y = rnd.randrange(12), rnd.randrange(T)
        hline(im, x, x + 3, y, PAL["water_300"])
    for _ in range(3):
        x, y = rnd.randrange(12), rnd.randrange(T)
        hline(im, x, x + 2, y, PAL["water_500"])
    if v == 1:
        put(im, 5, 5, (220, 240, 255)); put(im, 11, 12, (220, 240, 255))
    return im


def tile_water_edge():
    im = tile_water()
    rect(im, 0, 0, 15, 4, PAL["stone_300"]); hline(im, 0, 15, 4, PAL["stone_400"]); hline(im, 0, 15, 5, PAL["water_500"])
    for x in range(0, 16, 8):
        vline(im, x, 0, 3, PAL["stone_400"])
    return im


def tile_boards():
    im = new(T, T, PAL["wood_300"])
    for y in (3, 7, 11, 15):
        hline(im, 0, 15, y, PAL["wood_400"])
    put(im, 4, 1, PAL["wood_400"]); put(im, 12, 9, PAL["wood_400"])
    return im


def tile_plaza(v=0):
    im = new(T, T, PAL["stone_200"] if v == 0 else PAL["stone_300"])
    hline(im, 0, 15, 15, PAL["stone_400"]); vline(im, 15, 0, 15, PAL["stone_400"])
    put(im, 1, 1, lighten(PAL["stone_200"], 0.3))
    return im


def tile_garden():
    im = new(T, T, (112, 86, 64))
    rnd = random.Random(5)
    for _ in range(12):
        put(im, rnd.randrange(T), rnd.randrange(T), (92, 70, 52))
    return im


def tile_floor(kind):
    if kind == "wood_warm":
        im = new(T, T, (176, 124, 82))
        for y in (3, 7, 11, 15):
            hline(im, 0, 15, y, (148, 102, 66))
        for (x, y) in ((5, 0), (12, 4), (2, 8), (9, 12)):
            vline(im, x, y, y + 2, (148, 102, 66))
        put(im, 7, 1, (196, 144, 100))
    elif kind == "wood_dark":
        im = new(T, T, (118, 82, 58))
        for y in (3, 7, 11, 15):
            hline(im, 0, 15, y, (96, 66, 46))
        for (x, y) in ((5, 0), (12, 4), (2, 8), (9, 12)):
            vline(im, x, y, y + 2, (96, 66, 46))
    elif kind == "tile_white":
        im = new(T, T, (226, 228, 230))
        hline(im, 0, 15, 15, (196, 200, 206)); vline(im, 15, 0, 15, (196, 200, 206))
        hline(im, 0, 15, 7, (206, 210, 214)); vline(im, 7, 0, 15, (206, 210, 214))
    elif kind == "checker":
        im = new(T, T, (60, 64, 74))
        rect(im, 0, 0, 7, 7, (214, 206, 190)); rect(im, 8, 8, 15, 15, (214, 206, 190))
    elif kind == "carpet_navy":
        im = new(T, T, (48, 62, 96))
        dither(im, 0, 0, 15, 15, (56, 72, 108), 0.25, seed=3)
    elif kind == "marble":
        im = new(T, T, (230, 226, 218))
        hline(im, 0, 15, 15, (200, 194, 184)); vline(im, 15, 0, 15, (200, 194, 184))
        for i in range(6):
            put(im, 2 + i, 3 + i // 2, (214, 208, 198))
    elif kind == "concrete":
        im = new(T, T, (176, 178, 180))
        dither(im, 0, 0, 15, 15, (164, 166, 170), 0.12, seed=9, pattern="rand")
        hline(im, 0, 15, 15, (156, 158, 162))
    else:
        im = new(T, T, (200, 200, 200))
    return im


def tile_wall(kind):
    if kind == "plaster_warm":
        im = new(T, T, (226, 212, 192))
        dither(im, 0, 0, 15, 15, (216, 200, 180), 0.08, seed=4, pattern="rand")
    elif kind == "brick":
        im = new(T, T, (164, 94, 70))
        for y in (3, 7, 11, 15):
            hline(im, 0, 15, y, (120, 70, 56))
        for y0, off in ((0, 0), (4, 4), (8, 0), (12, 4)):
            for x in range(off, 16, 8):
                vline(im, x, y0, y0 + 2, (120, 70, 56))
    elif kind == "navy_panel":
        im = new(T, T, (40, 56, 88))
        vline(im, 15, 0, 15, (30, 42, 68)); hline(im, 0, 15, 0, (52, 70, 106))
    elif kind == "wood_panel":
        im = new(T, T, (150, 104, 70))
        for x in (3, 7, 11, 15):
            vline(im, x, 0, 15, (124, 84, 56))
    elif kind == "marble_wall":
        im = new(T, T, (214, 208, 196))
        hline(im, 0, 15, 15, (190, 182, 170)); vline(im, 15, 0, 15, (190, 182, 170))
    elif kind == "white_modern":
        im = new(T, T, (234, 236, 238))
        vline(im, 15, 0, 15, (218, 220, 224))
    elif kind == "concrete_wall":
        im = new(T, T, (170, 172, 176))
        put(im, 4, 4, (150, 152, 156)); put(im, 11, 11, (150, 152, 156))
        hline(im, 0, 15, 15, (150, 152, 156))
    else:
        im = new(T, T, (200, 200, 200))
    return im


GROUND_TILES = [
    ("grass", lambda: tile_grass(0)), ("grass_flowers", lambda: tile_grass(1)),
    ("sidewalk", lambda: tile_sidewalk(0)), ("sidewalk_alt", lambda: tile_sidewalk(1)),
    ("road", lambda: tile_asphalt()), ("road_dash_h", lambda: tile_asphalt("dash_h")),
    ("road_dash_v", lambda: tile_asphalt("dash_v")), ("crosswalk_h", lambda: tile_asphalt("cross_h")),
    ("crosswalk_v", lambda: tile_asphalt("cross_v")), ("curb_top", lambda: tile_curb(True)),
    ("curb_bottom", lambda: tile_curb(False)), ("water", lambda: tile_water(0)),
    ("water_alt", lambda: tile_water(1)), ("water_edge", tile_water_edge),
    ("boards", tile_boards), ("plaza", lambda: tile_plaza(0)), ("plaza_alt", lambda: tile_plaza(1)),
    ("garden", tile_garden), ("road_edge_top", lambda: tile_asphalt("edge_top")),
    ("road_edge_bottom", lambda: tile_asphalt("edge_bottom")), ("parking", lambda: tile_asphalt("parking")),
]
FLOORS = ["wood_warm", "wood_dark", "tile_white", "checker", "carpet_navy", "marble", "concrete"]
WALLS = ["plaster_warm", "brick", "navy_panel", "wood_panel", "marble_wall", "white_modern", "concrete_wall"]


def gen_tiles(out):
    names = [n for n, _ in GROUND_TILES] + ["floor_" + f for f in FLOORS] + ["wall_" + w for w in WALLS]
    fns = [f for _, f in GROUND_TILES] + [(lambda k=f: tile_floor(k)) for f in FLOORS] + [(lambda k=w: tile_wall(k)) for w in WALLS]
    cols = 8
    rows = (len(names) + cols - 1) // cols
    atlas = new(cols * T, rows * T)
    index = {}
    for i, (n, fn) in enumerate(zip(names, fns)):
        x, y = (i % cols), (i // cols)
        paste(atlas, fn(), x * T, y * T)
        index[n] = [x, y]
    save(atlas, f"{out}/tiles/atlas.png")
    with open(f"{out}/tiles/atlas.json", "w") as fh:
        json.dump({"tile_size": T, "tiles": index}, fh, indent=1)


# ================================================================ buildings
MAT = {
    "brick": (170, 96, 72), "concrete": (196, 198, 200), "stone": (222, 212, 192), "glass": PAL["glass_400"],
    "metal": (120, 136, 156), "plaster": (236, 228, 214), "wood": (160, 112, 72), "navy": (52, 66, 100),
    "cream": (236, 226, 204), "darkglass": (60, 84, 118), "blue_metal": (60, 92, 150),
}


def mat_fill(im, x0, y0, x1, y1, mat, seed=0):
    c = MAT.get(mat, mat) if isinstance(mat, str) else mat
    rect(im, x0, y0, x1, y1, c)
    if mat == "brick":
        dark = shade(c, 0.78)
        for y in range(y0 + 3, y1 + 1, 4):
            hline(im, x0, x1, y, dark)
        for yy in range(y0, y1 + 1, 4):
            off = 4 if ((yy - y0) // 4) % 2 else 0
            for x in range(x0 + off, x1 + 1, 8):
                vline(im, x, yy, min(y1, yy + 2), dark)
        dither(im, x0, y0, x1, y1, lighten(c, 0.1), 0.04, seed=seed, pattern="rand")
    elif mat in ("concrete", "plaster", "cream"):
        for x in range(x0 + 23, x1, 24):
            vline(im, x, y0, y1, shade(c, 0.9))
        dither(im, x0, y0, x1, y1, shade(c, 0.95), 0.05, seed=seed, pattern="rand")
    elif mat == "stone":
        for y in range(y0 + 7, y1 + 1, 8):
            hline(im, x0, x1, y, shade(c, 0.86))
        for yy in range(y0, y1 + 1, 8):
            off = 8 if ((yy - y0) // 8) % 2 else 0
            for x in range(x0 + off, x1 + 1, 16):
                vline(im, x, yy, min(y1, yy + 6), shade(c, 0.88))
    elif mat in ("glass", "darkglass"):
        for y in range(y0, y1 + 1):
            t = (y - y0) / max(1, (y1 - y0))
            hline(im, x0, x1, y, mix(lighten(c, 0.2), shade(c, 0.85), t))
        for x in range(x0 + 11, x1, 12):
            vline(im, x, y0, y1, PAL["metal_500"])
        # diagonal sky reflections
        for k in range(x0 - (y1 - y0), x1, 40):
            for i in range(0, y1 - y0 + 1):
                for w in range(3):
                    xx = k + i // 2 + w
                    if x0 <= xx <= x1:
                        put(im, xx, y1 - i, lighten(get(im, xx, y1 - i)[:3], 0.18))
    elif mat in ("metal", "blue_metal"):
        for x in range(x0, x1 + 1, 4):
            vline(im, x, y0, y1, shade(c, 0.85))
    elif mat == "wood":
        for x in range(x0, x1 + 1, 3):
            vline(im, x, y0, y1, shade(c, 0.86))


def window(im, lights, x, y, w, h, frame=(58, 64, 78), glass=None, lit=False, sill=True, mull=True):
    glass = glass or PAL["glass_500"]
    rect(im, x, y, x + w - 1, y + h - 1, frame)
    rect(im, x + 1, y + 1, x + w - 2, y + h - 2, glass)
    hline(im, x + 1, x + w - 2, y + 1, lighten(glass, 0.25))
    for i in range(min(w, h) // 2):
        put(im, x + 2 + i, y + h - 3 - i, lighten(glass, 0.35))
    if mull and w >= 10:
        vline(im, x + w // 2, y + 1, y + h - 2, frame)
    if sill:
        hline(im, x - 1, x + w, y + h, (214, 214, 214))
    if lit:
        for yy in range(y + 1, y + h - 1):
            t = (yy - y) / h
            hline(lights, x + 1, x + w - 2, yy, (255, int(214 - 40 * t), int(140 - 50 * t), 225))
        if mull and w >= 10:
            vline(lights, x + w // 2, y + 1, y + h - 2, (0, 0, 0, 0))


def door(im, x, y, w, h, kind="glass", col=None):
    if kind == "glass":
        rect(im, x, y, x + w - 1, y + h - 1, (46, 52, 64))
        rect(im, x + 1, y + 1, x + w - 2, y + h - 1, (70, 110, 150))
        vline(im, x + w // 2, y + 1, y + h - 1, (46, 52, 64))
        hline(im, x + 1, x + w - 2, y + 1, (140, 180, 214))
        put(im, x + w // 2 - 2, y + h // 2, (220, 220, 220)); put(im, x + w // 2 + 2, y + h // 2, (220, 220, 220))
    else:
        c = col or (122, 80, 52)
        rect(im, x, y, x + w - 1, y + h - 1, shade(c, 0.6))
        rect(im, x + 1, y + 1, x + w - 2, y + h - 1, c)
        rect(im, x + 3, y + 3, x + w - 4, y + h // 2 - 1, lighten(c, 0.12))
        put(im, x + w - 4, y + h // 2 + 2, (230, 200, 120))


def roof(im, w, rh, kind, seed=0):
    rnd = random.Random(seed)
    top = (178, 182, 188) if kind != "dark" else (92, 98, 110)
    rect(im, 0, 0, w - 1, rh - 1, top)
    hline(im, 0, w - 1, 0, shade(top, 0.7)); vline(im, 0, 0, rh - 1, shade(top, 0.7)); vline(im, w - 1, 0, rh - 1, shade(top, 0.7))
    rect(im, 0, rh - 3, w - 1, rh - 1, shade(top, 0.82))
    hline(im, 0, w - 1, rh - 1, shade(top, 0.6))
    if kind in ("green", "terrace"):
        for x in range(4, w - 12, 18):
            if rnd.random() < 0.8:
                m = Mask(im.width, im.height).ellipse(x, 2, x + 12, rh - 5)
                shaded(im, m, ramp(PAL["leaf_400"]), 0, 0)
    else:
        for x in range(6, w - 16, 26):
            if rnd.random() < 0.7:
                box(im, x, 3, x + 11, rh - 6, (150, 156, 164), (100, 104, 112), (190, 194, 200))
                hline(im, x + 2, x + 9, 5, (110, 116, 124))


def awning(im, x0, x1, y, col, stripes=True, depth=6):
    for yy in range(depth):
        for x in range(x0, x1 + 1):
            c = col if (not stripes or ((x - x0) // 4) % 2 == 0) else (244, 240, 232)
            if yy == depth - 1:
                c = shade(c, 0.7)
            put(im, x, y + yy, c)
    hline(im, x0, x1, y, shade(col, 0.6))
    for x in range(x0, x1 + 1, 4):
        put(im, x, y + depth, shade(col, 0.6))


def plant_box(im, x, y, w=14):
    rect(im, x, y + 6, x + w - 1, y + 10, (90, 96, 106)); hline(im, x, x + w - 1, y + 6, (130, 136, 146))
    m = Mask(im.width, im.height).ellipse(x - 1, y, x + w, y + 8)
    shaded(im, m, ramp(PAL["leaf_400"]), 0, 0)


def building(spec, seed=0):
    """Generic facade builder. Returns (img, lights, meta)."""
    rnd = random.Random(seed)
    w = spec["w"]
    rh = spec.get("roof_h", 18)
    fh = spec.get("floor_h", 40)
    gh = spec.get("ground_h", 56)
    floors = spec.get("floors", 2)
    base = 4
    h = rh + floors * fh + gh + base
    im = new(w, h)
    lt = new(w, h)
    roof(im, w, rh, spec.get("roof", "ac"), seed)
    y_f = rh
    mat = spec.get("mat", "concrete")
    mat_fill(im, 0, y_f, w - 1, h - base - 1, mat, seed)
    vline(im, 0, y_f, h - base - 1, shade(MAT.get(mat, (128, 128, 128)), 0.6))
    vline(im, w - 1, y_f, h - base - 1, shade(MAT.get(mat, (128, 128, 128)), 0.6))
    # upper floors
    ws = spec.get("window", "punched")
    lit_p = spec.get("lit", 0.55)
    for fl in range(floors):
        fy = y_f + fl * fh
        hline(im, 1, w - 2, fy, shade(MAT.get(mat, (128, 128, 128)), 0.8))
        if ws == "curtain":
            # mullion grid over glass already; add lit panes
            for x in range(1, w - 12, 12):
                if rnd.random() < lit_p:
                    for yy in range(fy + 3, fy + fh - 3):
                        hline(lt, x + 1, x + 10, yy, (255, 214, 140, 150))
            hline(im, 1, w - 2, fy + fh - 2, (180, 190, 200))
            continue
        ww = spec.get("win_w", 18)
        wh = spec.get("win_h", 20)
        gap = spec.get("win_gap", 10)
        n = max(1, (w - 8 + gap) // (ww + gap))
        tot = n * ww + (n - 1) * gap
        x0 = (w - tot) // 2
        for i in range(n):
            wx = x0 + i * (ww + gap)
            wy = fy + (fh - wh) // 2 - 2
            window(im, lt, wx, wy, ww, wh, lit=rnd.random() < lit_p)
            if ws == "balcony":
                by = wy + wh + 1
                rect(im, wx - 3, by, wx + ww + 2, by + 2, (208, 208, 210))
                rect(im, wx - 3, by - 6, wx + ww + 2, by - 1, (190, 214, 232))
                hline(im, wx - 3, wx + ww + 2, by - 6, (120, 130, 140))
                if rnd.random() < 0.5:
                    m = Mask(w, h).ellipse(wx - 2, by - 9, wx + 5, by - 2)
                    shaded(im, m, ramp(PAL["leaf_400"]), 0, 0)
    # ground floor
    gy = y_f + floors * fh
    hline(im, 1, w - 2, gy, shade(MAT.get(mat, (128, 128, 128)), 0.7))
    gmat = spec.get("ground_mat")
    if gmat:
        mat_fill(im, 1, gy + 1, w - 2, h - base - 1, gmat, seed + 1)
    gk = spec.get("ground", "shop")
    dw, dh = spec.get("door_w", 20), spec.get("door_h", 30)
    dx = spec.get("door_x", (w - dw) // 2)
    dy = h - base - dh
    meta = {"size": [w, h], "door": [dx, dy, dw, dh]}
    sign = None
    if gk in ("shop", "cafe"):
        sy = gy + 4
        sign = [8, sy, w - 16, 10]
        rect(im, 6, sy - 1, w - 7, sy + 10, spec.get("sign_col", (34, 44, 62)))
        hline(im, 6, w - 7, sy - 1, (90, 100, 120))
        aw_y = sy + 12
        if spec.get("awning"):
            awning(im, 4, w - 5, aw_y, spec["awning"], stripes=spec.get("stripes", True))
            aw_y += 7
        gx0, gx1 = 6, w - 7
        rect(im, gx0, aw_y + 1, gx1, h - base - 1, (46, 52, 64))
        rect(im, gx0 + 1, aw_y + 2, gx1 - 1, h - base - 1, (98, 140, 176))
        for x in range(gx0 + 12, gx1, 14):
            vline(im, x, aw_y + 2, h - base - 1, (46, 52, 64))
        hline(im, gx0 + 1, gx1 - 1, aw_y + 2, (160, 196, 222))
        # interior hints
        for x in range(gx0 + 4, gx1 - 6, 22):
            rect(im, x, h - base - 12, x + 8, h - base - 6, (150, 110, 80))
            put(im, x + 2, h - base - 14, (240, 230, 210))
        rect(lt, gx0 + 1, aw_y + 2, gx1 - 1, h - base - 1, (255, 214, 150, 170))
        door(im, dx, dy, dw, dh, "glass")
        rect(lt, dx + 1, dy + 1, dx + dw - 2, dy + dh - 1, (255, 222, 160, 200))
    elif gk == "lobby":
        rect(im, dx - 14, dy - 8, dx + dw + 13, dy - 5, (60, 66, 80))
        hline(im, dx - 14, dx + dw + 13, dy - 8, (110, 116, 130))
        for sx in (dx - 26, dx + dw + 6):
            window(im, lt, sx, dy + 2, 20, dh - 8, lit=True, sill=False)
        door(im, dx, dy, dw, dh, "glass")
        rect(lt, dx + 1, dy + 1, dx + dw - 2, dy + dh - 1, (255, 222, 160, 200))
        if spec.get("planters", True):
            plant_box(im, 6, h - base - 12)
            plant_box(im, w - 20, h - base - 12)
        sign = [dx - 12, dy - 20, dw + 24, 10]
        rect(im, sign[0], sign[1], sign[0] + sign[2] - 1, sign[1] + sign[3] - 1, spec.get("sign_col", (34, 44, 62)))
    elif gk == "residential":
        door(im, dx, dy, dw, dh, "wood", spec.get("door_col"))
        rect(im, dx - 3, dy - 3, dx + dw + 2, dy - 1, (70, 76, 90))
        for sx in (12, w - 32):
            window(im, lt, sx, gy + 14, 20, 22, lit=rnd.random() < lit_p)
        rect(lt, dx + 2, dy - 2, dx + dw - 3, dy - 2, (255, 230, 170, 200))
        sign = [dx - 10, dy - 14, dw + 20, 8]
    elif gk == "civic":
        col_c = (236, 230, 214)
        rect(im, 4, gy + 2, w - 5, gy + 8, (214, 206, 190))
        hline(im, 4, w - 5, gy + 8, (170, 162, 148))
        for x in range(10, w - 14, 22):
            rect(im, x, gy + 9, x + 7, h - base - 8, col_c)
            vline(im, x + 7, gy + 9, h - base - 8, (200, 192, 176))
            vline(im, x, gy + 9, h - base - 8, (250, 246, 236))
            rect(im, x + 8, gy + 12, x + 21, h - base - 9, (78, 110, 146))
            rect(lt, x + 8, gy + 12, x + 21, h - base - 9, (255, 220, 160, 150))
        for i in range(3):
            rect(im, 2 + i * 2, h - base - 8 + i * 3, w - 3 - i * 2, h - base - 6 + i * 3, (208 - i * 8, 200 - i * 8, 186 - i * 8))
        door(im, dx, dy - 6, dw, dh, "glass")
        meta["door"] = [dx, dy - 6, dw, dh + 6]
        sign = [dx - 24, gy + 2, dw + 48, 7]
    # base / shadow line
    rect(im, 0, h - base, w - 1, h - 1, (0, 0, 0, 0))
    hline(im, 1, w - 2, h - base, (90, 94, 104))
    for x in range(2, w - 2):
        put(im, x, h - base + 1, (60, 64, 74, 110))
    if spec.get("brand"):
        b = spec["brand"]
        draw_brand(im, lt, b, spec)
    # volume: cornice under the roof, lit left edge, shaded right edge
    mc = MAT.get(mat, (128, 128, 128))
    rect(im, 0, rh, w - 1, rh + 1, lighten(mc, 0.25) if mat not in ("glass", "darkglass") else (200, 206, 214))
    hline(im, 0, w - 1, rh + 2, shade(mc, 0.62))
    for y in range(rh, h - base):
        for x in range(w - 6, w - 1):
            c = get(im, x, y)
            if c[3]:
                put(im, x, y, shade(c[:3], 0.84 if x < w - 3 else 0.74) + (c[3],))
        c = get(im, 1, y)
        if c[3]:
            put(im, 1, y, lighten(c[:3], 0.12) + (c[3],))
    meta["sign"] = sign
    meta["sign_text"] = spec.get("sign_text", "")
    return im, lt, meta


def draw_brand(im, lt, b, spec):
    kind = b.get("kind")
    x, y = b["x"], b["y"]
    if kind == "vertical_banner":
        rect(im, x, y, x + 13, y + b.get("h", 48), b["col"])
        hline(im, x, x + 13, y, lighten(b["col"], 0.3))
        yy = y + 4
        for ch in b["text"]:
            draw_text_centered(im, x + 7, yy, ch, (250, 250, 250))
            yy += 7
        rect(lt, x + 1, y + 1, x + 12, y + b.get("h", 48) - 1, (255, 240, 200, 60))
    elif kind == "logo_m":
        rect(im, x, y, x + 13, y + 13, (46, 98, 196))
        draw_text_centered(im, x + 7, y + 4, "M", (255, 255, 255))
        rect(lt, x, y, x + 13, y + 13, (140, 190, 255, 140))
    elif kind == "text":
        draw_text_centered(im, x, y, b["text"], b["col"], b.get("scale", 1))


BUILDINGS = {
    "riverside_tower": {"w": 176, "floors": 5, "floor_h": 36, "ground_h": 56, "mat": "cream", "window": "balcony",
                        "win_w": 20, "win_h": 18, "win_gap": 12, "ground": "lobby", "roof": "green", "ground_mat": "stone",
                        "sign_text": "RIVERSIDE TOWER"},
    "bloom_block": {"w": 160, "floors": 2, "floor_h": 38, "ground_h": 60, "mat": "brick", "window": "punched",
                    "ground": "cafe", "awning": (72, 128, 84), "sign_col": (38, 64, 48), "roof": "green",
                    "sign_text": "BLOOM COFFEE"},
    "postpoint": {"w": 112, "floors": 1, "floor_h": 34, "ground_h": 58, "mat": "plaster", "window": "punched", "win_w": 16,
                  "ground": "shop", "awning": (46, 98, 176), "stripes": False, "sign_col": (224, 104, 83), "roof": "ac",
                  "sign_text": "POSTPOINT"},
    "riverside_walkup": {"w": 128, "floors": 3, "floor_h": 36, "ground_h": 48, "mat": "brick", "window": "punched",
                         "win_w": 16, "ground": "residential", "roof": "ac", "door_w": 18, "door_h": 28},
    "riverside_shops": {"w": 144, "floors": 2, "floor_h": 36, "ground_h": 56, "mat": "plaster", "window": "punched",
                        "ground": "shop", "awning": (190, 120, 60), "roof": "green", "sign_text": "FRESH+ MARKET",
                        "sign_col": (60, 110, 70)},
    "nexus_cowork": {"w": 192, "floors": 3, "floor_h": 40, "ground_h": 60, "mat": "concrete", "window": "punched",
                     "win_w": 24, "win_h": 22, "win_gap": 10, "ground": "lobby", "roof": "terrace", "ground_mat": "darkglass",
                     "sign_text": "NEXUS CO-WORK", "sign_col": (30, 50, 96)},
    "horizon_labs": {"w": 176, "floors": 4, "floor_h": 38, "ground_h": 58, "mat": "glass", "window": "curtain",
                     "ground": "lobby", "roof": "terrace", "sign_text": "HORIZON LABS", "lit": 0.7,
                     "brand": {"kind": "vertical_banner", "x": 150, "y": 50, "text": "HL", "col": (46, 98, 196), "h": 40}},
    "suite_building": {"w": 144, "floors": 3, "floor_h": 38, "ground_h": 56, "mat": "brick", "window": "punched",
                       "win_w": 22, "win_h": 22, "ground": "lobby", "roof": "green", "ground_mat": "navy",
                       "sign_text": "22 FOUNDERS LANE"},
    "byte_bean": {"w": 128, "floors": 1, "floor_h": 36, "ground_h": 60, "mat": "wood", "window": "punched",
                  "ground": "cafe", "awning": (60, 60, 70), "stripes": False, "sign_col": (30, 30, 36), "roof": "green",
                  "sign_text": "BYTE & BEAN"},
    "nexus_bank": {"w": 208, "floors": 3, "floor_h": 40, "ground_h": 64, "mat": "stone", "window": "punched",
                   "win_w": 14, "win_h": 26, "win_gap": 14, "ground": "civic", "roof": "ac", "door_w": 24, "door_h": 32,
                   "sign_text": "NEXUS BANK"},
    "city_hall": {"w": 256, "floors": 2, "floor_h": 44, "ground_h": 70, "mat": "stone", "window": "punched",
                  "win_w": 16, "win_h": 28, "win_gap": 12, "ground": "civic", "roof": "green", "door_w": 28, "door_h": 34,
                  "sign_text": "AURELIA CITY HALL"},
    "glass_tower": {"w": 160, "floors": 8, "floor_h": 34, "ground_h": 56, "mat": "glass", "window": "curtain",
                    "ground": "lobby", "roof": "ac", "lit": 0.45, "planters": False},
    "office_slab": {"w": 176, "floors": 6, "floor_h": 34, "ground_h": 56, "mat": "concrete", "window": "punched",
                    "win_w": 22, "win_h": 18, "win_gap": 8, "ground": "lobby", "roof": "ac"},
    "apartment_mid": {"w": 160, "floors": 5, "floor_h": 34, "ground_h": 50, "mat": "plaster", "window": "balcony",
                      "win_w": 18, "win_h": 16, "win_gap": 12, "ground": "residential", "roof": "green"},
    "brick_shops": {"w": 144, "floors": 2, "floor_h": 36, "ground_h": 56, "mat": "brick", "window": "punched",
                    "ground": "shop", "awning": (180, 70, 60), "roof": "ac", "sign_text": "KURO RAMEN", "sign_col": (40, 30, 30)},
    "civic_annex": {"w": 160, "floors": 3, "floor_h": 38, "ground_h": 56, "mat": "cream", "window": "punched",
                    "win_w": 14, "win_h": 24, "ground": "lobby", "roof": "ac", "sign_text": "TAX OFFICE"},
    "finance_tower": {"w": 176, "floors": 9, "floor_h": 32, "ground_h": 60, "mat": "darkglass", "window": "curtain",
                      "ground": "lobby", "roof": "ac", "lit": 0.5, "sign_text": "ARC CAPITAL"},
}


def metro_entrance():
    w, h = 80, 64
    im = new(w, h)
    lt = new(w, h)
    # canopy
    m = Mask(w, h).poly([(4, 18), (76, 18), (70, 8), (10, 8)])
    shaded(im, m, ramp((150, 200, 230)), 0, 0)
    rect(im, 4, 18, 75, 21, (60, 70, 90))
    for x in (8, 71):
        rect(im, x, 22, x + 1, 58, (70, 80, 96))
    rect(im, 12, 26, 67, 58, (54, 60, 72))
    for i, y in enumerate(range(30, 58, 4)):
        rect(im, 14 + i, y, 65 - i, y + 1, (130, 136, 146))
    rect(im, 32, 0, 47, 12, (46, 98, 196)); draw_text_centered(im, 40, 4, "M", (255, 255, 255))
    rect(lt, 32, 0, 47, 12, (120, 180, 255, 150))
    rect(lt, 12, 26, 67, 30, (255, 230, 170, 120))
    hline(im, 2, 77, 60, (90, 94, 104))
    meta = {"size": [w, h], "door": [26, 34, 28, 26], "sign": None, "sign_text": ""}
    return im, lt, meta


def gen_buildings(out):
    metas = {}
    for i, (bid, spec) in enumerate(BUILDINGS.items()):
        im, lt, meta = building(spec, seed=100 + i)
        save(im, f"{out}/buildings/{bid}.png")
        save(lt, f"{out}/buildings/{bid}_lights.png")
        metas[bid] = meta
    im, lt, meta = metro_entrance()
    save(im, f"{out}/buildings/metro_entrance.png"); save(lt, f"{out}/buildings/metro_entrance_lights.png")
    metas["metro_entrance"] = meta
    with open(f"{out}/buildings/buildings_meta.json", "w") as fh:
        json.dump(metas, fh, indent=1)


# ================================================================ props
def canvas(w, h):
    return new(w, h)


def p_tree(kind="round", seed=0):
    rnd = random.Random(seed)
    if kind == "round":
        w, h = 32, 48
        im = canvas(w, h)
        rect(im, 14, 30, 17, 44, (104, 72, 50)); vline(im, 14, 30, 44, (80, 54, 38))
        for (x0, y0, x1, y1, c) in ((3, 6, 28, 32, PAL["leaf_500"]), (5, 2, 26, 26, PAL["leaf_400"]), (9, 4, 22, 18, PAL["leaf_300"])):
            m = Mask(w, h).ellipse(x0, y0, x1, y1)
            shaded(im, m, ramp(c), 0, 0, outline=(c == PAL["leaf_500"]))
        for _ in range(14):
            x, y = rnd.randrange(6, 26), rnd.randrange(4, 28)
            if get(im, x, y)[3]:
                put(im, x, y, PAL["leaf_300"] if rnd.random() < .5 else PAL["leaf_500"])
        # shadow
        for x in range(8, 24):
            put(im, x, 45, (40, 50, 40, 90)); put(im, x + 1, 46, (40, 50, 40, 60))
        return im
    w, h = 24, 56
    im = canvas(w, h)
    rect(im, 11, 40, 13, 52, (104, 72, 50))
    m = Mask(w, h).ellipse(3, 2, 20, 44)
    shaded(im, m, ramp(PAL["leaf_600"]), 0, 0)
    m2 = Mask(w, h).ellipse(6, 4, 16, 30)
    shaded(im, m2, ramp(PAL["leaf_500"]), 0, 0, outline=False)
    for x in range(6, 18):
        put(im, x, 53, (40, 50, 40, 90))
    return im


def p_lamp():
    im = canvas(12, 48)
    rect(im, 5, 8, 6, 44, (60, 66, 80)); vline(im, 5, 8, 44, (90, 98, 112))
    rect(im, 2, 3, 9, 7, (60, 66, 80)); rect(im, 3, 7, 8, 8, (255, 232, 170))
    rect(im, 3, 44, 8, 46, (60, 66, 80))
    return im


def p_bench():
    im = canvas(32, 20)
    rect(im, 1, 2, 30, 5, PAL["wood_400"]); hline(im, 1, 30, 2, PAL["wood_300"])
    rect(im, 1, 9, 30, 12, PAL["wood_400"]); hline(im, 1, 30, 9, PAL["wood_300"])
    for x in (3, 27):
        rect(im, x, 6, x + 1, 17, (60, 66, 80))
    hline(im, 1, 30, 13, PAL["wood_600"])
    for x in range(2, 30):
        put(im, x, 18, (40, 44, 50, 80))
    return im


def p_planter():
    im = canvas(32, 24)
    box(im, 1, 10, 30, 22, (120, 126, 138), (80, 84, 96), (160, 166, 176))
    m = Mask(32, 24).ellipse(1, 0, 30, 14)
    shaded(im, m, ramp(PAL["leaf_400"]), 0, 0)
    for (x, y, c) in ((8, 4, (240, 150, 170)), (20, 6, (250, 230, 120)), (14, 3, (250, 250, 250))):
        put(im, x, y, c)
    return im


def p_trash():
    im = canvas(12, 18)
    box(im, 1, 3, 10, 16, (70, 96, 84), (40, 56, 50), (100, 130, 116))
    rect(im, 0, 1, 11, 3, (60, 66, 80))
    return im


def p_bike():
    im = canvas(32, 20)
    for cx in (7, 24):
        m = Mask(32, 20).ellipse(cx - 5, 8, cx + 5, 18)
        m2 = Mask(32, 20).ellipse(cx - 3, 10, cx + 3, 16)
        fill(im, m, (40, 40, 48)); fill(im, m2, (0, 0, 0, 0)[:3]) if False else None
        for x, y in m2.pixels():
            put(im, x, y, (0, 0, 0, 0))
    for (a, b) in (((7, 13), (15, 13)), ((15, 13), (20, 6)), ((24, 13), (20, 6)), ((12, 6), (20, 6))):
        Mask(32, 20).line([a, b])
        from PIL import ImageDraw
        ImageDraw.Draw(im).line([a, b], fill=(46, 98, 176, 255))
    rect(im, 10, 4, 14, 5, (40, 40, 48)); rect(im, 19, 3, 22, 4, (40, 40, 48))
    return im


def p_metro_sign():
    im = canvas(16, 40)
    rect(im, 7, 12, 8, 38, (60, 66, 80))
    box(im, 1, 0, 14, 13, (46, 98, 196), (30, 60, 130))
    draw_text_centered(im, 8, 4, "M", (255, 255, 255))
    return im


def p_cafe_board():
    im = canvas(14, 20)
    m = Mask(14, 20).poly([(2, 0), (11, 0), (13, 19), (0, 19)])
    fill(im, m, (46, 44, 48))
    rect(im, 3, 2, 10, 15, (30, 34, 34))
    for y in (4, 7, 10, 13):
        hline(im, 4, 9, y, (230, 230, 220) if y != 7 else (240, 200, 120))
    return im


def p_umbrella_table():
    im = canvas(32, 36)
    m = Mask(32, 36).poly([(1, 12), (30, 12), (22, 2), (9, 2)])
    shaded(im, m, ramp((72, 128, 84)), 0, 0)
    for x in range(1, 31, 6):
        vline(im, x, 12, 13, (240, 240, 232))
    rect(im, 15, 13, 16, 30, (80, 80, 90))
    m2 = Mask(32, 36).ellipse(6, 24, 25, 32)
    shaded(im, m2, ramp((230, 230, 232)), 0, 0)
    return im


def p_bus_stop():
    im = canvas(48, 44)
    rect(im, 1, 2, 46, 5, (60, 66, 80))
    rect(im, 3, 6, 44, 34, (170, 206, 230, 160))
    rect(im, 2, 6, 3, 40, (60, 66, 80)); rect(im, 44, 6, 45, 40, (60, 66, 80))
    rect(im, 6, 28, 40, 31, PAL["wood_400"])
    rect(im, 30, 9, 41, 24, (240, 240, 244)); rect(im, 31, 10, 40, 16, (46, 98, 196))
    return im


def p_billboard():
    im = canvas(64, 56)
    rect(im, 30, 30, 33, 54, (70, 76, 90))
    box(im, 0, 0, 63, 31, (30, 40, 60), (20, 26, 40))
    rect(im, 3, 3, 60, 28, (60, 120, 190))
    for y in range(3, 29):
        hline(im, 3, 60, y, mix((90, 160, 220), (46, 98, 176), (y - 3) / 25))
    draw_text(im, 7, 7, "BIG IDEAS", (255, 255, 255))
    draw_text(im, 7, 15, "BRIGHTER", (255, 255, 255))
    draw_text(im, 7, 21, "TOMORROWS", (255, 230, 140))
    return im


def p_digital_sign():
    im = canvas(20, 40)
    rect(im, 8, 30, 11, 38, (60, 66, 80))
    box(im, 0, 0, 19, 30, (40, 46, 60), (24, 28, 38))
    rect(im, 2, 2, 17, 27, (40, 110, 180))
    rect(im, 4, 5, 15, 9, (255, 255, 255)); rect(im, 4, 12, 12, 13, (200, 230, 255)); rect(im, 4, 16, 14, 17, (200, 230, 255))
    return im


def p_hydrant():
    im = canvas(10, 14)
    box(im, 2, 3, 7, 12, (200, 70, 60), (120, 40, 36), (230, 110, 96))
    rect(im, 1, 5, 8, 6, (200, 70, 60)); rect(im, 3, 1, 6, 3, (170, 60, 50))
    return im


def p_cone():
    im = canvas(10, 12)
    m = Mask(10, 12).poly([(4, 0), (5, 0), (8, 10), (1, 10)])
    fill(im, m, (240, 130, 50)); hline(im, 3, 6, 5, (250, 250, 250))
    rect(im, 0, 10, 9, 11, (60, 60, 60))
    return im


def p_parking_meter():
    im = canvas(8, 22)
    rect(im, 3, 8, 4, 21, (70, 76, 90)); box(im, 1, 0, 6, 8, (100, 110, 126), (60, 66, 80))
    put(im, 3, 3, (140, 230, 160))
    return im


def p_direction_sign():
    im = canvas(28, 40)
    rect(im, 13, 6, 14, 38, (60, 66, 80))
    for i, y in enumerate((2, 12, 22)):
        box(im, 1, y, 26, y + 7, (40, 60, 100), (24, 36, 60))
        put(im, 23, y + 3, (255, 255, 255)); put(im, 24, y + 4, (255, 255, 255)); put(im, 23, y + 5, (255, 255, 255))
        hline(im, 4, 18, y + 4, (220, 226, 240))
    return im


def p_business_board():
    im = canvas(40, 52)
    rect(im, 4, 34, 6, 50, (60, 66, 80)); rect(im, 33, 34, 35, 50, (60, 66, 80))
    box(im, 0, 0, 39, 35, (46, 56, 80), (26, 32, 48), (70, 84, 114))
    rect(im, 3, 7, 36, 32, (196, 160, 110))
    rnd = random.Random(4)
    for (x, y, c) in ((5, 9, (250, 250, 240)), (17, 10, (250, 230, 140)), (27, 9, (180, 220, 250)),
                      (6, 20, (250, 200, 200)), (17, 21, (250, 250, 240)), (27, 20, (200, 240, 200))):
        rect(im, x, y, x + 8, y + 9, c)
        hline(im, x + 1, x + 7, y + 3, (120, 120, 130)); hline(im, x + 1, x + 5, y + 5, (120, 120, 130))
        put(im, x + 4, y, (220, 60, 60))
    draw_text_centered(im, 20, 1, "BOARD", (250, 250, 250))
    return im


def p_flagpole():
    im = canvas(20, 64)
    rect(im, 2, 2, 3, 62, (200, 204, 212))
    rect(im, 4, 3, 18, 13, (46, 98, 196)); rect(im, 4, 3, 18, 4, (250, 250, 250))
    m = Mask(20, 64).ellipse(8, 6, 13, 11)
    fill(im, m, (250, 220, 120))
    rect(im, 0, 61, 5, 63, (120, 126, 138))
    return im


def p_fountain():
    im = canvas(64, 40)
    m = Mask(64, 40).ellipse(0, 12, 63, 39)
    shaded(im, m, ramp((200, 196, 186)), 0, 0)
    m2 = Mask(64, 40).ellipse(5, 15, 58, 35)
    fill(im, m2, PAL["water_400"])
    for x in (16, 30, 44):
        hline(im, x, x + 4, 24, PAL["water_300"])
    rect(im, 29, 4, 34, 26, (200, 196, 186))
    for (x, y) in ((31, 0), (27, 3), (36, 3), (31, 2)):
        put(im, x, y, (200, 230, 255))
    return im


def p_flower_bed():
    im = canvas(32, 16)
    box(im, 0, 6, 31, 15, (120, 96, 72), (80, 60, 44))
    rnd = random.Random(8)
    m = Mask(32, 16).ellipse(1, 0, 30, 10)
    shaded(im, m, ramp(PAL["leaf_400"]), 0, 0)
    for _ in range(10):
        put(im, rnd.randrange(3, 29), rnd.randrange(1, 8), rnd.choice([(240, 150, 170), (250, 230, 120), (250, 250, 250), (230, 110, 90)]))
    return im


def p_car_shadow():
    return None


STREET_PROPS = {
    "tree_round": lambda: p_tree("round", 1), "tree_round_b": lambda: p_tree("round", 7), "tree_tall": lambda: p_tree("tall"),
    "lamp": p_lamp, "bench": p_bench, "planter": p_planter, "trash_bin": p_trash, "bike": p_bike,
    "metro_sign": p_metro_sign, "cafe_board": p_cafe_board, "umbrella_table": p_umbrella_table, "bus_stop": p_bus_stop,
    "billboard": p_billboard, "digital_sign": p_digital_sign, "hydrant": p_hydrant, "cone": p_cone,
    "parking_meter": p_parking_meter, "direction_sign": p_direction_sign, "business_board": p_business_board,
    "flagpole": p_flagpole, "fountain": p_fountain, "flower_bed": p_flower_bed,
}


# ================================================================ interior props
def ip_bed():
    im = canvas(40, 52)
    box(im, 0, 0, 39, 10, PAL["wood_500"], PAL["wood_600"], PAL["wood_400"])
    box(im, 1, 8, 38, 50, (236, 236, 240), (150, 150, 160))
    rect(im, 4, 11, 17, 18, (250, 250, 252)); rect(im, 22, 11, 35, 18, (250, 250, 252))
    rect(im, 1, 22, 38, 50, (58, 78, 128)); hline(im, 1, 38, 22, (90, 110, 160)); hline(im, 1, 38, 49, (40, 54, 90))
    for y in range(26, 48, 6):
        hline(im, 3, 36, y, (66, 88, 140))
    return im


def ip_desk(with_laptop=True, w=44, h=30, col=None):
    im = canvas(w, h)
    c = col or PAL["wood_400"]
    rect(im, 0, 6, w - 1, 12, c); hline(im, 0, w - 1, 6, lighten(c, 0.2)); hline(im, 0, w - 1, 12, shade(c, 0.6))
    rect(im, 1, 13, 3, h - 2, shade(c, 0.7)); rect(im, w - 4, 13, w - 2, h - 2, shade(c, 0.7))
    rect(im, 1, 13, w - 2, 15, shade(c, 0.8))
    if with_laptop:
        rect(im, w // 2 - 8, 0, w // 2 + 7, 6, (40, 46, 58)); rect(im, w // 2 - 7, 1, w // 2 + 6, 5, (90, 160, 220))
        hline(im, w // 2 - 9, w // 2 + 8, 7, (170, 176, 188))
        put(im, w // 2 - 5, 2, (230, 240, 250))
    return im


def ip_chair(col=(50, 56, 70)):
    im = canvas(16, 24)
    box(im, 2, 0, 13, 12, col, shade(col, 0.6), lighten(col, 0.2))
    box(im, 1, 11, 14, 16, col, shade(col, 0.6))
    rect(im, 7, 17, 8, 21, (80, 84, 96)); hline(im, 3, 12, 22, (80, 84, 96))
    return im


def ip_sofa(w=48, col=(96, 110, 150)):
    im = canvas(w, 28)
    box(im, 0, 0, w - 1, 12, col, shade(col, 0.6), lighten(col, 0.2))
    box(im, 0, 10, w - 1, 22, shade(col, 0.9), shade(col, 0.55))
    for x in range(w // 3, w - 4, w // 3):
        vline(im, x, 12, 21, shade(col, 0.7))
    rect(im, 0, 4, 4, 24, shade(col, 0.8)); rect(im, w - 5, 4, w - 1, 24, shade(col, 0.8))
    rect(im, 2, 24, 4, 27, (60, 50, 44)); rect(im, w - 5, 24, w - 3, 27, (60, 50, 44))
    return im


def ip_coffee_table():
    im = canvas(32, 18)
    box(im, 0, 2, 31, 9, PAL["wood_400"], PAL["wood_600"], PAL["wood_300"])
    rect(im, 2, 10, 3, 16, PAL["wood_600"]); rect(im, 28, 10, 29, 16, PAL["wood_600"])
    rect(im, 12, 0, 16, 3, (240, 240, 240))
    return im


def ip_bookshelf(w=32, h=48):
    im = canvas(w, h)
    box(im, 0, 0, w - 1, h - 1, PAL["wood_500"], PAL["wood_600"])
    rnd = random.Random(w + h)
    for y in range(3, h - 4, 11):
        rect(im, 2, y, w - 3, y + 8, PAL["wood_600"])
        x = 3
        while x < w - 4:
            bw = rnd.randint(2, 3)
            c = rnd.choice([(200, 80, 70), (70, 110, 170), (230, 200, 120), (90, 140, 100), (220, 220, 220), (60, 60, 70)])
            rect(im, x, y + rnd.randint(1, 3), x + bw - 1, y + 8, c)
            x += bw + (1 if rnd.random() < 0.3 else 0)
        hline(im, 1, w - 2, y + 9, PAL["wood_400"])
    return im


def ip_tv():
    im = canvas(44, 36)
    box(im, 4, 0, 39, 20, (30, 32, 40), (18, 18, 24))
    rect(im, 6, 2, 37, 18, (46, 70, 110)); hline(im, 6, 37, 2, (80, 110, 160))
    box(im, 0, 22, 43, 34, PAL["wood_400"], PAL["wood_600"], PAL["wood_300"])
    rect(im, 20, 20, 23, 22, (30, 32, 40))
    return im


def ip_kitchen(w=64):
    im = canvas(w, 44)
    box(im, 0, 0, w - 1, 16, (230, 230, 232), (170, 170, 176))
    rect(im, 4, 3, 20, 12, (200, 220, 236))
    box(im, 0, 16, w - 1, 43, (214, 206, 190), (150, 142, 130), (236, 230, 218))
    hline(im, 0, w - 1, 20, (90, 96, 108))
    for x in range(12, w, 16):
        vline(im, x, 22, 42, (170, 162, 150)); put(im, x - 3, 30, (120, 120, 130))
    rect(im, w - 22, 17, w - 8, 19, (80, 84, 96))
    rect(im, 28, 8, 34, 15, (60, 60, 66)); put(im, 30, 7, (200, 200, 210))
    return im


def ip_fridge():
    im = canvas(22, 44)
    box(im, 0, 0, 21, 43, (226, 230, 236), (150, 156, 166), (246, 248, 250))
    hline(im, 1, 20, 16, (160, 166, 176)); vline(im, 18, 4, 12, (140, 146, 156)); vline(im, 18, 20, 30, (140, 146, 156))
    return im


def ip_wardrobe():
    im = canvas(32, 52)
    box(im, 0, 0, 31, 51, PAL["wood_300"], PAL["wood_500"], lighten(PAL["wood_300"], 0.2))
    vline(im, 15, 2, 49, PAL["wood_500"]); vline(im, 16, 2, 49, PAL["wood_400"])
    put(im, 13, 26, (230, 200, 120)); put(im, 18, 26, (230, 200, 120))
    return im


def ip_plant(big=False):
    w, h = (20, 36) if big else (16, 28)
    im = canvas(w, h)
    box(im, 3, h - 10, w - 4, h - 1, (220, 214, 204), (150, 144, 134))
    m = Mask(w, h).ellipse(0, 0, w - 1, h - 8)
    shaded(im, m, ramp(PAL["leaf_400"]), 0, 0)
    for i in range(0, w, 4):
        put(im, i + 1, 3 + (i % 3), PAL["leaf_300"])
    return im


def ip_rug(w=64, h=40, col=(150, 130, 110)):
    im = canvas(w, h)
    rect(im, 0, 0, w - 1, h - 1, col)
    box(im, 3, 3, w - 4, h - 4, shade(col, 0.9), lighten(col, 0.2))
    for x in range(0, w, 2):
        put(im, x, 0, lighten(col, 0.3)); put(im, x, h - 1, lighten(col, 0.3))
    return im


def ip_box():
    im = canvas(16, 14)
    box(im, 0, 0, 15, 13, (196, 156, 108), (130, 100, 70), (220, 186, 140))
    hline(im, 1, 14, 4, (170, 130, 90)); vline(im, 7, 0, 4, (230, 220, 190)); vline(im, 8, 0, 4, (230, 220, 190))
    return im


def ip_packing_table():
    im = ip_desk(False, 44, 30, (150, 150, 158))
    rect(im, 6, 0, 17, 6, (196, 156, 108)); rect(im, 24, 2, 31, 6, (220, 220, 226))
    rect(im, 34, 1, 38, 6, (140, 90, 70))
    return im


def ip_counter(w=96, col=(120, 84, 58), top=(236, 232, 224)):
    im = canvas(w, 40)
    rect(im, 0, 8, w - 1, 12, top); hline(im, 0, w - 1, 8, lighten(top, 0.3)); hline(im, 0, w - 1, 12, shade(top, 0.7))
    rect(im, 0, 13, w - 1, 39, col)
    for x in range(0, w, 6):
        vline(im, x, 14, 38, shade(col, 0.85))
    hline(im, 0, w - 1, 39, shade(col, 0.5))
    return im


def ip_cafe_counter():
    im = ip_counter(96, (120, 84, 58))
    box(im, 8, 0, 26, 8, (180, 184, 192), (100, 104, 112), (220, 224, 230))
    rect(im, 12, 3, 14, 6, (40, 40, 44)); rect(im, 20, 3, 22, 6, (40, 40, 44))
    box(im, 60, 0, 84, 8, (220, 230, 236), (140, 150, 160))
    for x in (64, 70, 76):
        rect(im, x, 3, x + 3, 6, (200, 150, 90))
    rect(im, 40, 3, 46, 8, (60, 60, 70))
    return im


def ip_menu_board():
    im = canvas(56, 28)
    box(im, 0, 0, 55, 27, (34, 40, 40), (80, 60, 44))
    draw_text(im, 4, 3, "MENU", (240, 220, 160))
    for i, y in enumerate((11, 16, 21)):
        hline(im, 4, 30, y, (220, 220, 214)); hline(im, 40, 50, y, (240, 200, 120))
    return im


def ip_display_case():
    im = canvas(40, 30)
    box(im, 0, 10, 39, 29, (120, 84, 58), (80, 56, 40))
    rect(im, 1, 0, 38, 10, (200, 226, 240, 170)); hline(im, 1, 38, 0, (230, 240, 250))
    for x in (4, 13, 22, 31):
        m = Mask(40, 30).ellipse(x, 4, x + 6, 9)
        fill(im, m, (210, 150, 90))
    return im


def ip_cafe_table():
    im = canvas(24, 22)
    m = Mask(24, 22).ellipse(0, 0, 23, 10)
    shaded(im, m, ramp((236, 232, 224)), 0, 0)
    rect(im, 11, 10, 12, 19, (60, 60, 70)); hline(im, 7, 16, 20, (60, 60, 70))
    rect(im, 8, 3, 10, 5, (250, 250, 250)); put(im, 9, 3, (150, 100, 60))
    return im


def ip_hanging_light():
    im = canvas(12, 28)
    vline(im, 6, 0, 16, (40, 40, 44))
    m = Mask(12, 28).poly([(2, 24), (10, 24), (8, 17), (4, 17)])
    fill(im, m, (40, 40, 44)); hline(im, 3, 9, 25, (255, 230, 170))
    return im


def ip_monitor_desk():
    im = canvas(64, 34)
    rect(im, 0, 10, 63, 15, (236, 236, 238)); hline(im, 0, 63, 10, (250, 250, 252)); hline(im, 0, 63, 15, (170, 170, 176))
    rect(im, 2, 16, 3, 33, (120, 126, 136)); rect(im, 60, 16, 61, 33, (120, 126, 136)); rect(im, 31, 16, 32, 33, (120, 126, 136))
    for x in (8, 38):
        box(im, x, 0, x + 17, 10, (40, 44, 54), (24, 26, 32))
        rect(im, x + 2, 2, x + 15, 7, (70, 130, 190)); hline(im, x + 2, x + 15, 2, (130, 180, 230))
        rect(im, x + 8, 10, x + 9, 11, (40, 44, 54))
    return im


def ip_glass_wall(w=64, h=48):
    im = canvas(w, h)
    rect(im, 0, 0, w - 1, h - 1, (180, 214, 236, 110))
    rect(im, 0, 0, w - 1, 1, (70, 80, 96)); rect(im, 0, h - 2, w - 1, h - 1, (70, 80, 96))
    for x in range(0, w, 16):
        vline(im, x, 0, h - 1, (70, 80, 96))
    for i in range(10):
        put(im, 4 + i, 20 - i, (230, 245, 255, 180))
    return im


def ip_phone_booth():
    im = canvas(28, 48)
    box(im, 0, 0, 27, 47, (46, 56, 80), (24, 30, 46))
    rect(im, 3, 4, 24, 44, (180, 214, 236, 150)); rect(im, 8, 30, 20, 33, (150, 110, 80))
    return im


def ip_printer():
    im = canvas(24, 26)
    box(im, 0, 8, 23, 25, (220, 222, 228), (140, 146, 156), (240, 242, 246))
    rect(im, 3, 3, 20, 8, (200, 204, 210)); rect(im, 5, 0, 18, 4, (250, 250, 252))
    put(im, 19, 12, (120, 220, 140))
    return im


def ip_lockers():
    im = canvas(36, 44)
    for i in range(3):
        box(im, i * 12, 0, i * 12 + 11, 43, (120, 140, 170), (70, 84, 110), (150, 170, 200))
        for y in (8, 10, 12):
            hline(im, i * 12 + 3, i * 12 + 8, y, (80, 96, 124))
        put(im, i * 12 + 9, 22, (230, 230, 236))
    return im


def ip_cork_board():
    im = canvas(56, 36)
    box(im, 0, 0, 55, 35, PAL["wood_500"], PAL["wood_600"])
    rect(im, 3, 3, 52, 32, (196, 160, 110))
    for (x, y, c) in ((6, 6, (250, 250, 240)), (18, 8, (250, 230, 140)), (31, 6, (180, 220, 250)), (43, 9, (250, 200, 200)),
                      (8, 19, (200, 240, 200)), (21, 20, (250, 250, 240)), (34, 19, (250, 230, 140))):
        rect(im, x, y, x + 9, y + 10, c)
        hline(im, x + 1, x + 8, y + 3, (120, 120, 130)); hline(im, x + 1, x + 6, y + 6, (120, 120, 130))
        put(im, x + 4, y, (220, 60, 60))
    return im


def ip_whiteboard():
    im = canvas(64, 40)
    box(im, 0, 0, 63, 34, (246, 248, 250), (150, 156, 166))
    draw_text(im, 4, 4, "IDEAS", (46, 98, 176))
    draw_text(im, 4, 11, "PEOPLE", (46, 98, 176))
    draw_text(im, 4, 18, "PRODUCT", (46, 98, 176))
    draw_text(im, 4, 25, "GROWTH", (46, 98, 176))
    for i in range(14):
        put(im, 40 + i, 26 - i, (224, 104, 83))
    put(im, 53, 13, (224, 104, 83)); put(im, 52, 13, (224, 104, 83)); put(im, 53, 14, (224, 104, 83))
    rect(im, 6, 35, 7, 39, (120, 126, 136)); rect(im, 56, 35, 57, 39, (120, 126, 136))
    return im


def ip_exec_desk():
    im = canvas(64, 36)
    rect(im, 0, 12, 63, 17, (92, 62, 42)); hline(im, 0, 63, 12, (130, 92, 62))
    rect(im, 0, 18, 63, 35, (74, 50, 34))
    for x in range(8, 60, 18):
        rect(im, x, 21, x + 12, 32, (84, 58, 40))
    box(im, 22, 0, 41, 12, (30, 34, 44), (18, 20, 26))
    rect(im, 24, 2, 39, 9, (70, 130, 190))
    rect(im, 46, 8, 52, 11, (230, 230, 236))
    return im


def ip_bank_counter():
    im = ip_counter(144, (60, 70, 96), (230, 226, 218))
    for x in range(8, 140, 36):
        rect(im, x, 0, x + 22, 7, (200, 226, 240, 150))
        hline(im, x, x + 22, 0, (120, 130, 150))
    rect(im, 60, 20, 84, 30, (46, 98, 196))
    draw_text_centered(im, 72, 23, "NEXUS", (255, 255, 255))
    return im


def ip_atm():
    im = canvas(22, 40)
    box(im, 0, 0, 21, 39, (70, 84, 110), (40, 48, 64), (100, 116, 146))
    rect(im, 3, 4, 18, 14, (90, 170, 230)); draw_text_centered(im, 11, 7, "ATM", (255, 255, 255))
    rect(im, 5, 18, 16, 24, (40, 46, 58))
    for y in (19, 21, 23):
        for x in (6, 9, 12, 15):
            put(im, x, y, (200, 204, 212))
    rect(im, 6, 28, 15, 29, (30, 30, 36))
    return im


def ip_queue_barrier():
    im = canvas(48, 22)
    for x in (2, 44):
        rect(im, x, 4, x + 1, 19, (200, 190, 150)); rect(im, x - 1, 19, x + 2, 21, (150, 140, 110))
    for x in range(4, 44):
        put(im, x, 6 + (abs(x - 24) < 12), (46, 98, 196))
    return im


def ip_brochure():
    im = canvas(16, 30)
    rect(im, 7, 14, 8, 28, (120, 126, 136)); box(im, 1, 0, 14, 14, (200, 204, 212), (120, 126, 136))
    for y in (2, 7):
        rect(im, 3, y, 6, y + 4, (46, 98, 196)); rect(im, 9, y, 12, y + 4, (224, 104, 83))
    return im


def ip_logo_wall(text="NEXUS BANK", col=(40, 56, 88)):
    w = max(64, text_width(text) + 16)
    im = canvas(w, 32)
    box(im, 0, 0, w - 1, 31, col, shade(col, 0.6), lighten(col, 0.15))
    draw_text_centered(im, w // 2, 13, text, (240, 220, 160))
    return im


def ip_ticket_machine():
    im = canvas(18, 34)
    box(im, 0, 0, 17, 33, (220, 222, 228), (140, 146, 156))
    rect(im, 3, 3, 14, 12, (60, 140, 200)); rect(im, 6, 16, 11, 18, (40, 40, 44)); rect(im, 6, 22, 11, 23, (250, 250, 250))
    return im


def ip_seal():
    im = canvas(32, 32)
    m = Mask(32, 32).ellipse(0, 0, 31, 31)
    shaded(im, m, ramp((226, 186, 90)), 0, 0)
    m2 = Mask(32, 32).ellipse(5, 5, 26, 26)
    fill(im, m2, (46, 70, 130))
    draw_text_centered(im, 16, 13, "A", (250, 230, 160))
    return im


def ip_parcel_shelf():
    im = canvas(48, 44)
    box(im, 0, 0, 47, 43, (140, 146, 156), (90, 94, 104))
    rnd = random.Random(11)
    for y in (3, 17, 31):
        hline(im, 1, 46, y + 11, (100, 104, 114))
        x = 3
        while x < 42:
            bw = rnd.randint(7, 11)
            rect(im, x, y + 11 - rnd.randint(6, 10), min(45, x + bw), y + 10, (196, 156, 108))
            x += bw + 2
    return im


def ip_window(night=False, w=48, h=40, seed=0):
    im = canvas(w, h)
    rnd = random.Random(seed)
    box(im, 0, 0, w - 1, h - 1, (70, 76, 90), (50, 54, 64))
    for y in range(2, h - 2):
        t = (y - 2) / (h - 4)
        c = mix((150, 200, 240), (220, 236, 248), t) if not night else mix((24, 30, 64), (70, 60, 110), t)
        hline(im, 2, w - 3, y, c)
    # skyline silhouettes
    x = 2
    while x < w - 3:
        bw = rnd.randint(5, 10)
        bh = rnd.randint(8, h - 12)
        col = (120, 150, 190) if not night else (30, 36, 60)
        rect(im, x, h - 3 - bh, min(w - 3, x + bw), h - 3, col)
        for yy in range(h - bh, h - 4, 3):
            for xx in range(x + 1, min(w - 4, x + bw), 2):
                if night and rnd.random() < 0.45:
                    put(im, xx, yy, (255, 214, 140))
                elif not night and rnd.random() < 0.2:
                    put(im, xx, yy, (180, 210, 240))
        x += bw + 1
    vline(im, w // 2, 1, h - 2, (70, 76, 90))
    hline(im, 1, w - 2, h // 2 - 4, (70, 76, 90))
    return im


def ip_door_mat():
    im = canvas(32, 10)
    rect(im, 0, 0, 31, 9, (90, 70, 60)); box(im, 2, 2, 29, 7, (110, 86, 72), None)
    return im


def ip_stool():
    im = canvas(12, 16)
    m = Mask(12, 16).ellipse(0, 0, 11, 5)
    fill(im, m, (60, 60, 70)); rect(im, 5, 5, 6, 14, (120, 126, 136)); hline(im, 2, 9, 14, (120, 126, 136))
    return im


def ip_water_cooler():
    im = canvas(14, 34)
    box(im, 1, 14, 12, 33, (230, 232, 236), (150, 156, 166))
    m = Mask(14, 34).ellipse(1, 0, 12, 14)
    fill(im, m, (140, 200, 240)); put(im, 4, 4, (220, 240, 255))
    return im


def ip_bench_civic():
    im = canvas(48, 20)
    box(im, 0, 4, 47, 10, (120, 126, 138), (80, 84, 96), (160, 166, 176))
    rect(im, 3, 11, 4, 18, (80, 84, 96)); rect(im, 43, 11, 44, 18, (80, 84, 96))
    return im


def ip_info_kiosk():
    im = canvas(22, 36)
    box(im, 2, 0, 19, 24, (40, 56, 88), (24, 32, 52))
    rect(im, 4, 2, 17, 18, (90, 170, 230)); draw_text_centered(im, 11, 6, "I", (255, 255, 255))
    rect(im, 8, 24, 13, 34, (120, 126, 136))
    return im


def ip_filing():
    im = canvas(20, 36)
    box(im, 0, 0, 19, 35, (150, 156, 168), (100, 104, 116), (180, 186, 196))
    for y in (8, 19, 30):
        hline(im, 2, 17, y, (100, 104, 116)); rect(im, 8, y - 5, 11, y - 4, (220, 220, 226))
    return im


INTERIOR_PROPS = {
    "bed": ip_bed, "desk_laptop": ip_desk, "desk": lambda: ip_desk(False), "chair": ip_chair,
    "office_chair": lambda: ip_chair((40, 44, 54)), "sofa": ip_sofa, "lounge_sofa": lambda: ip_sofa(56, (70, 96, 130)),
    "waiting_sofa": lambda: ip_sofa(48, (40, 56, 88)), "coffee_table": ip_coffee_table, "bookshelf": ip_bookshelf,
    "tv": ip_tv, "kitchen": ip_kitchen, "fridge": ip_fridge, "wardrobe": ip_wardrobe, "plant": ip_plant,
    "plant_big": lambda: ip_plant(True), "rug": ip_rug, "rug_navy": lambda: ip_rug(64, 40, (60, 78, 120)),
    "rug_small": lambda: ip_rug(40, 24, (170, 140, 110)), "box": ip_box, "packing_table": ip_packing_table,
    "cafe_counter": ip_cafe_counter, "menu_board": ip_menu_board, "display_case": ip_display_case,
    "cafe_table": ip_cafe_table, "cafe_chair": lambda: ip_chair((120, 84, 58)), "hanging_light": ip_hanging_light,
    "monitor_desk": ip_monitor_desk, "glass_wall": ip_glass_wall, "phone_booth": ip_phone_booth, "printer": ip_printer,
    "lockers": ip_lockers, "cork_board": ip_cork_board, "whiteboard": ip_whiteboard, "exec_desk": ip_exec_desk,
    "bank_counter": ip_bank_counter, "atm": ip_atm, "queue_barrier": ip_queue_barrier, "brochure": ip_brochure,
    "logo_nexus_bank": lambda: ip_logo_wall("NEXUS BANK"), "logo_city_hall": lambda: ip_logo_wall("CITY OF AURELIA", (46, 60, 96)),
    "logo_cowork": lambda: ip_logo_wall("NEXUS  WORK - MEET - CREATE", (30, 50, 96)),
    "logo_bloom": lambda: ip_logo_wall("BLOOM COFFEE", (38, 64, 48)), "logo_postpoint": lambda: ip_logo_wall("POSTPOINT", (180, 80, 64)),
    "logo_bytebean": lambda: ip_logo_wall("BYTE & BEAN", (30, 30, 36)),
    "civic_counter": lambda: ip_counter(144, (46, 60, 96), (236, 232, 224)), "ticket_machine": ip_ticket_machine,
    "seal": ip_seal, "parcel_shelf": ip_parcel_shelf, "postpoint_counter": lambda: ip_counter(80, (180, 80, 64)),
    "window_day": lambda: ip_window(False, 48, 40, 1), "window_night": lambda: ip_window(True, 48, 40, 1),
    "window_wide_day": lambda: ip_window(False, 96, 48, 2), "window_wide_night": lambda: ip_window(True, 96, 48, 2),
    "door_mat": ip_door_mat, "stool": ip_stool, "water_cooler": ip_water_cooler, "bench_civic": ip_bench_civic,
    "info_kiosk": ip_info_kiosk, "filing_cabinet": ip_filing, "brochure_stand": ip_brochure,
}


# ================================================================ vehicles
def v_side(kind):
    specs = {"sedan": (64, 28), "compact": (52, 26), "taxi": (64, 28), "van": (72, 36), "bus": (112, 44)}
    w, h = specs[kind]
    body = canvas(w, h)
    det = canvas(w, h)
    g = ((80, 80, 80), (184, 184, 184), (228, 228, 228), (250, 250, 250))
    if kind in ("sedan", "taxi", "compact"):
        m = Mask(w, h)
        m.rect(1, h - 16, w - 2, h - 6)
        cab0, cab1 = (int(w * 0.28), int(w * 0.72)) if kind != "compact" else (int(w * 0.22), int(w * 0.78))
        m.poly([(cab0 - 6, h - 16), (cab1 + 4, h - 16), (cab1 - 2, h - 25 + (2 if kind == "compact" else 0)), (cab0 + 2, h - 25 + (2 if kind == "compact" else 0))])
        m.rect(0, h - 13, 2, h - 8).rect(w - 3, h - 13, w - 1, h - 8)
        shaded(body, m, g, 0, 0, sh_depth=2)
        # windows
        wm = Mask(w, h).poly([(cab0 - 3, h - 16), (cab1 + 1, h - 16), (cab1 - 3, h - 23 + (2 if kind == "compact" else 0)), (cab0 + 3, h - 23 + (2 if kind == "compact" else 0))])
        fill(det, wm, (60, 80, 110))
        vline(det, (cab0 + cab1) // 2, h - 23, h - 16, (40, 44, 54))
        for x, y in list(wm.pixels())[:6]:
            put(det, x + 2, y, (170, 200, 230))
        hline(det, 2, w - 3, h - 12, (255, 255, 255, 60))
        # lights
        rect(det, w - 3, h - 13, w - 1, h - 11, (255, 240, 180)); rect(det, 0, h - 13, 1, h - 11, (220, 60, 60))
        if kind == "taxi":
            rect(det, (cab0 + cab1) // 2 - 4, h - 27, (cab0 + cab1) // 2 + 3, h - 25, (250, 250, 250))
    elif kind == "van":
        m = Mask(w, h).rect(1, 6, w - 2, h - 6)
        m.poly([(w - 2, 10), (w - 2, 6), (w - 14, 6)])
        shaded(body, m, g, 0, 0, sh_depth=2)
        rect(det, w - 16, 9, w - 4, 17, (60, 80, 110))
        rect(det, 6, 12, w - 22, 20, (255, 255, 255, 40))
        rect(det, w - 3, h - 12, w - 1, h - 10, (255, 240, 180))
    else:  # bus
        m = Mask(w, h).rect(1, 4, w - 2, h - 6)
        shaded(body, m, g, 0, 0, sh_depth=2)
        for x in range(8, w - 14, 14):
            rect(det, x, 9, x + 11, 19, (60, 80, 110))
            put(det, x + 1, 10, (170, 200, 230))
        rect(det, w - 12, 9, w - 4, 28, (60, 80, 110))
        hline(det, 2, w - 3, 23, (46, 98, 196))
        rect(det, w - 3, h - 12, w - 1, h - 10, (255, 240, 180))
    # wheels
    for cx in ((int(w * 0.22), int(w * 0.78)) if kind != "bus" else (16, w - 22)):
        m = Mask(w, h).ellipse(cx - 5, h - 11, cx + 5, h - 1)
        fill(det, m, (30, 30, 36))
        m2 = Mask(w, h).ellipse(cx - 2, h - 8, cx + 2, h - 4)
        fill(det, m2, (150, 156, 166))
    for x in range(3, w - 3):
        put(det, x, h - 1, (0, 0, 0, 70))
    return body, det


def v_front(kind, back=False):
    w, h = (32, 40) if kind != "compact" else (30, 36)
    body = canvas(w, h)
    det = canvas(w, h)
    g = ((80, 80, 80), (184, 184, 184), (228, 228, 228), (250, 250, 250))
    m = Mask(w, h).rect(2, 10, w - 3, h - 6)
    m.poly([(5, 10), (w - 6, 10), (w - 8, 2), (7, 2)])
    shaded(body, m, g, 0, 0, sh_depth=2)
    wm = Mask(w, h).poly([(7, 11), (w - 8, 11), (w - 10, 4), (9, 4)])
    fill(det, wm, (60, 80, 110))
    hline(det, 10, w - 11, 5, (170, 200, 230))
    if back:
        rect(det, 3, h - 14, 7, h - 12, (220, 60, 60)); rect(det, w - 8, h - 14, w - 4, h - 12, (220, 60, 60))
        rect(det, 11, h - 12, w - 12, h - 9, (230, 230, 230))
    else:
        rect(det, 3, h - 14, 7, h - 12, (255, 244, 200)); rect(det, w - 8, h - 14, w - 4, h - 12, (255, 244, 200))
        rect(det, 10, h - 12, w - 11, h - 9, (60, 64, 74))
    rect(det, 1, h - 7, 5, h - 1, (30, 30, 36)); rect(det, w - 6, h - 7, w - 2, h - 1, (30, 30, 36))
    return body, det


def gen_vehicles(out):
    for k in ("sedan", "compact", "taxi", "van", "bus"):
        b, d = v_side(k)
        save(b, f"{out}/vehicles/{k}_side_body.png"); save(d, f"{out}/vehicles/{k}_side_detail.png")
    for k in ("sedan", "compact"):
        b, d = v_front(k)
        save(b, f"{out}/vehicles/{k}_front_body.png"); save(d, f"{out}/vehicles/{k}_front_detail.png")
        b, d = v_front(k, True)
        save(b, f"{out}/vehicles/{k}_back_body.png"); save(d, f"{out}/vehicles/{k}_back_detail.png")


# ================================================================ products + effects
def gen_products(out):
    def earbuds():
        im = canvas(16, 16)
        m = Mask(16, 16).ellipse(1, 3, 14, 14)
        shaded(im, m, ramp((240, 240, 244)), 0, 0)
        rect(im, 4, 7, 5, 11, (40, 40, 48)); rect(im, 10, 7, 11, 11, (40, 40, 48))
        return im

    def lamp():
        im = canvas(16, 16)
        rect(im, 3, 13, 12, 14, (60, 66, 80)); vline(im, 7, 6, 13, (60, 66, 80))
        m = Mask(16, 16).poly([(4, 1), (12, 1), (14, 7), (2, 7)])
        shaded(im, m, ramp((226, 180, 82)), 0, 0)
        return im

    def bottle():
        im = canvas(16, 16)
        m = Mask(16, 16).rect(5, 3, 10, 15)
        shaded(im, m, ramp((96, 178, 190)), 0, 0)
        rect(im, 6, 0, 9, 3, (60, 66, 80))
        return im

    def stand():
        im = canvas(16, 16)
        m = Mask(16, 16).poly([(3, 14), (13, 14), (11, 10), (7, 3), (5, 3), (8, 10)])
        shaded(im, m, ramp((130, 140, 160)), 0, 0)
        return im

    def parcel():
        im = canvas(16, 16)
        box(im, 1, 3, 14, 14, (196, 156, 108), (130, 100, 70), (220, 186, 140))
        vline(im, 7, 3, 14, (230, 220, 190)); rect(im, 9, 9, 13, 12, (250, 250, 250))
        return im

    def coffee():
        im = canvas(16, 16)
        box(im, 4, 4, 11, 14, (250, 250, 250), (170, 170, 176))
        rect(im, 4, 7, 11, 10, (72, 128, 84)); rect(im, 3, 2, 12, 4, (60, 60, 66))
        return im

    for n, fn in (("earbuds", earbuds), ("desk_lamp", lamp), ("water_bottle", bottle), ("phone_stand", stand),
                  ("parcel", parcel), ("coffee", coffee)):
        save(fn(), f"{out}/props/product_{n}.png")
    save(glow(64, 64, (255, 214, 150)), f"{out}/effects/glow_warm.png")
    save(glow(32, 32, (255, 230, 180)), f"{out}/effects/glow_small.png")
    save(glow(96, 48, (255, 214, 150), 0.8), f"{out}/effects/glow_wide.png")
    # shadow blob
    sh = canvas(24, 8)
    m = Mask(24, 8).ellipse(0, 0, 23, 7)
    fill(sh, m, (0, 0, 0))
    for x, y in m.pixels():
        put(sh, x, y, (10, 16, 30, 80))
    save(sh, f"{out}/effects/shadow.png")
    # interaction sparkle 4 frames
    sp = canvas(64, 16)
    for f in range(4):
        r = [2, 4, 6, 4][f]
        cx = f * 16 + 8
        for i in range(-r, r + 1):
            put(sp, cx + i, 8, (255, 240, 180, 220 - abs(i) * 25)); put(sp, cx, 8 + i, (255, 240, 180, 220 - abs(i) * 25))
    save(sp, f"{out}/effects/sparkle.png")


def generate(out):
    gen_tiles(out)
    gen_buildings(out)
    for k, fn in STREET_PROPS.items():
        save(fn(), f"{out}/props/{k}.png")
    for k, fn in INTERIOR_PROPS.items():
        save(fn(), f"{out}/interiors/{k}.png")
    gen_vehicles(out)
    gen_products(out)
