"""Street layer v2: ground tiles and street furniture in the style of Concept Board A (Financial
District street) and Board G (frontages): stone pavers, granite curbs, textured asphalt, lush
multi-cluster trees with grates, banner lamps, bollards, planters, glass bus shelters, wayfinding.
"""
from __future__ import annotations

import math
import random

from PIL import ImageDraw

from pixel import PAL, Mask, new, shaded, fill, put, get, rect, hline, vline, box, save, ramp, shade, lighten, mix, paste
from font3x5 import draw_text, draw_text_centered

T = 16


def jitter(c, rnd, amt=0.04):
    k = 1 + rnd.uniform(-amt, amt)
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


def blend(img, x, y, col, a):
    if 0 <= x < img.width and 0 <= y < img.height:
        o = img.getpixel((x, y))
        if o[3]:
            img.putpixel((x, y), tuple(int(o[i] * (1 - a) + col[i] * a) for i in range(3)) + (o[3],))


def shadow_ellipse(img, cx, cy, rx, ry, a=90):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            d = ((x - cx) / max(1, rx)) ** 2 + ((y - cy) / max(1, ry)) ** 2
            if d <= 1:
                aa = int(a * (1 - d * 0.6))
                o = get(img, x, y)
                if o[3] == 0:
                    put(img, x, y, (16, 24, 38, aa))


# ================================================================ tiles
def t_pavers(seed=0, base=(214, 208, 196)):
    rnd = random.Random(seed)
    im = new(T, T, base)
    # running-bond 8x4 stones
    for row in range(4):
        y0 = row * 4
        off = 4 if row % 2 else 0
        for x0 in range(-off, T, 8):
            c = jitter(base, rnd, 0.05)
            rect(im, max(0, x0), y0, min(T - 1, x0 + 7), y0 + 3, c)
            hline(im, max(0, x0), min(T - 1, x0 + 6), y0, lighten(c, 0.12))
            hline(im, max(0, x0), min(T - 1, x0 + 7), y0 + 3, shade(c, 0.84))
            if 0 <= x0 + 7 < T:
                vline(im, x0 + 7, y0, y0 + 3, shade(c, 0.8))
    for _ in range(3):
        put(im, rnd.randrange(T), rnd.randrange(T), shade(base, 0.9))
    return im


def t_slab(seed=0, base=(222, 214, 198)):
    rnd = random.Random(seed)
    im = new(T, T, jitter(base, rnd, 0.03))
    hline(im, 0, T - 1, 0, lighten(base, 0.12))
    vline(im, 0, 0, T - 1, lighten(base, 0.08))
    hline(im, 0, T - 1, T - 1, shade(base, 0.82))
    vline(im, T - 1, 0, T - 1, shade(base, 0.84))
    for _ in range(6):
        put(im, rnd.randrange(1, T - 1), rnd.randrange(1, T - 1), jitter(base, rnd, 0.08))
    return im


def t_asphalt(kind="plain", seed=1):
    rnd = random.Random(seed)
    base = (72, 78, 90)
    im = new(T, T, base)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.22:
                put(im, x, y, (80, 86, 98))
            elif r < 0.36:
                put(im, x, y, (64, 70, 82))
    if kind == "plain" and seed % 3 == 0:
        for i in range(5):
            put(im, 3 + i, 9 + (i % 2), (56, 60, 70))
    white = (236, 234, 222)
    if kind == "dash_h":
        rect(im, 1, 7, 12, 8, white)
        for x in range(1, 13):
            if rnd.random() < 0.15:
                put(im, x, 7 + rnd.randint(0, 1), (200, 200, 194))
    elif kind == "cross_h":
        for x in (1, 7, 13):
            rect(im, x, 0, min(T - 1, x + 3), T - 1, white)
            for y in range(T):
                if rnd.random() < 0.12:
                    put(im, x + rnd.randint(0, 3), y, (190, 192, 190))
    elif kind == "cross_v":
        for y in (1, 7, 13):
            rect(im, 0, y, T - 1, min(T - 1, y + 3), white)
    elif kind == "edge_top":
        hline(im, 0, T - 1, 2, (232, 196, 84))
        hline(im, 0, T - 1, 4, (232, 196, 84))
    elif kind == "edge_bottom":
        hline(im, 0, T - 1, 11, (232, 196, 84))
        hline(im, 0, T - 1, 13, (232, 196, 84))
    elif kind == "parking":
        vline(im, 0, 0, T - 1, (230, 230, 226))
    elif kind == "manhole":
        m = Mask(T, T).ellipse(3, 3, 12, 12)
        shaded(im, m, ramp((96, 100, 110)), 0, 0)
        for y in range(5, 11, 2):
            hline(im, 5, 10, y, (70, 74, 84))
    return im


def t_curb(top=True):
    im = t_asphalt("plain", 7)
    granite = (176, 176, 178)
    if top:
        rect(im, 0, 0, T - 1, 3, granite)
        hline(im, 0, T - 1, 0, (206, 206, 208))
        hline(im, 0, T - 1, 3, (130, 132, 138))
        for x in range(0, T, 8):
            vline(im, x, 0, 3, (150, 150, 154))
        rect(im, 0, 4, T - 1, 5, (58, 62, 72))    # gutter shadow
    else:
        rect(im, 0, 12, T - 1, 15, granite)
        hline(im, 0, T - 1, 12, (212, 212, 214))
        hline(im, 0, T - 1, 11, (54, 58, 68))
        for x in range(0, T, 8):
            vline(im, x, 12, 15, (150, 150, 154))
    return im


def t_grass(v=0):
    rnd = random.Random(20 + v)
    base = (104, 150, 76)
    im = new(T, T, base)
    for y in range(T):
        for x in range(T):
            r = rnd.random()
            if r < 0.2:
                put(im, x, y, (122, 168, 86))
            elif r < 0.34:
                put(im, x, y, (88, 130, 66))
    for _ in range(7):
        x, y = rnd.randrange(T), rnd.randrange(1, T)
        put(im, x, y, (140, 184, 96))
        put(im, x, y - 1, (122, 168, 86))
    if v == 1:
        for (x, y, c) in ((3, 4, (250, 226, 120)), (11, 9, (244, 160, 180)), (7, 13, (252, 252, 252)), (13, 2, (200, 170, 240))):
            put(im, x, y, c)
            put(im, x, y + 1, (70, 120, 60))
    return im


def t_hedge_ground():
    return t_grass(2)


def t_water(v=0):
    rnd = random.Random(70 + v)
    im = new(T, T, (58, 118, 180))
    for y in range(T):
        for x in range(T):
            if rnd.random() < 0.18:
                put(im, x, y, (50, 104, 166))
    for _ in range(3):
        x, y = rnd.randrange(12), rnd.randrange(T)
        hline(im, x, x + 3, y, (104, 164, 214))
        put(im, x + 1, y - 1 if y > 0 else y, (140, 190, 230))
    if v == 1:
        put(im, 5, 5, (230, 244, 255))
        put(im, 11, 12, (230, 244, 255))
    return im


def t_water_edge():
    im = t_water(0)
    stone = (190, 184, 170)
    rect(im, 0, 0, T - 1, 5, stone)
    hline(im, 0, T - 1, 0, (220, 214, 200))
    hline(im, 0, T - 1, 5, (120, 116, 108))
    for x in range(0, T, 8):
        vline(im, x, 0, 5, (160, 154, 142))
    rect(im, 0, 6, T - 1, 7, (38, 84, 136))
    return im


def t_boards():
    rnd = random.Random(9)
    im = new(T, T)
    for i, y in enumerate(range(0, T, 4)):
        c = jitter((190, 136, 90), rnd, 0.06)
        rect(im, 0, y, T - 1, y + 3, c)
        hline(im, 0, T - 1, y, lighten(c, 0.12))
        hline(im, 0, T - 1, y + 3, shade(c, 0.75))
        put(im, 2 + (i * 5) % 12, y + 1, shade(c, 0.6))
    return im


def t_soil():
    rnd = random.Random(5)
    im = new(T, T, (104, 78, 58))
    for _ in range(40):
        put(im, rnd.randrange(T), rnd.randrange(T), rnd.choice([(90, 66, 48), (122, 92, 68), (84, 62, 46)]))
    return im


def t_floor(kind):
    rnd = random.Random(hash(kind) % 1000)
    if kind == "wood_warm" or kind == "wood_dark":
        base = (178, 126, 84) if kind == "wood_warm" else (122, 86, 60)
        im = new(T, T, base)
        for i, y in enumerate(range(0, T, 4)):
            c = jitter(base, rnd, 0.07)
            rect(im, 0, y, T - 1, y + 3, c)
            hline(im, 0, T - 1, y + 3, shade(c, 0.78))
            hline(im, 0, T - 1, y, lighten(c, 0.08))
            jx = (i * 7 + 3) % T
            vline(im, jx, y, y + 3, shade(c, 0.75))
            for x in range(T):
                if rnd.random() < 0.08:
                    put(im, x, y + 1 + rnd.randint(0, 1), shade(c, 0.9))
        return im
    if kind == "tile_white":
        im = new(T, T, (230, 232, 234))
        for (x0, y0) in ((0, 0), (8, 0), (0, 8), (8, 8)):
            c = jitter((232, 234, 236), rnd, 0.015)
            rect(im, x0, y0, x0 + 7, y0 + 7, c)
            hline(im, x0, x0 + 7, y0 + 7, (206, 210, 216))
            vline(im, x0 + 7, y0, y0 + 7, (206, 210, 216))
            put(im, x0 + 1, y0 + 1, (250, 252, 255))
        return im
    if kind == "checker":
        im = new(T, T)
        for (x0, y0, c) in ((0, 0, (224, 214, 196)), (8, 0, (62, 66, 76)), (0, 8, (62, 66, 76)), (8, 8, (224, 214, 196))):
            rect(im, x0, y0, x0 + 7, y0 + 7, c)
            put(im, x0 + 1, y0 + 1, lighten(c, 0.2))
        return im
    if kind == "carpet_navy":
        im = new(T, T, (48, 62, 98))
        for y in range(T):
            for x in range(T):
                if (x + y * 3) % 7 == 0:
                    put(im, x, y, (58, 74, 112))
                elif rnd.random() < 0.1:
                    put(im, x, y, (42, 54, 88))
        return im
    if kind == "marble":
        im = new(T, T, (234, 230, 222))
        hline(im, 0, T - 1, T - 1, (206, 200, 190))
        vline(im, T - 1, 0, T - 1, (206, 200, 190))
        x, y = rnd.randint(0, 5), 0
        while y < T - 1 and x < T - 1:
            put(im, x, y, (206, 200, 192))
            x += rnd.choice([0, 1, 1])
            y += 1
        put(im, 2, 2, (250, 250, 248))
        return im
    if kind == "concrete":
        im = new(T, T, (180, 182, 186))
        for y in range(T):
            for x in range(T):
                if rnd.random() < 0.12:
                    put(im, x, y, jitter((180, 182, 186), rnd, 0.05))
        hline(im, 0, T - 1, T - 1, (160, 162, 168))
        for i in range(4):
            put(im, 4 + i, 3 + i, (196, 198, 202))
        return im
    return new(T, T, (200, 200, 200))


def t_wall(kind):
    rnd = random.Random(hash(kind) % 997)
    if kind == "plaster_warm":
        im = new(T, T, (232, 218, 196))
        for _ in range(20):
            put(im, rnd.randrange(T), rnd.randrange(T), jitter((232, 218, 196), rnd, 0.03))
        return im
    if kind == "brick":
        im = new(T, T, (164, 92, 70))
        for row in range(4):
            y0 = row * 4
            off = 4 if row % 2 else 0
            for x0 in range(-off, T, 8):
                c = jitter((164, 92, 70), rnd, 0.08)
                rect(im, max(0, x0), y0, min(T - 1, x0 + 6), y0 + 2, c)
                hline(im, max(0, x0), min(T - 1, x0 + 6), y0, lighten(c, 0.1))
            hline(im, 0, T - 1, y0 + 3, (196, 170, 150))
        return im
    if kind == "navy_panel":
        im = new(T, T, (40, 56, 88))
        vline(im, T - 1, 0, T - 1, (30, 42, 68))
        hline(im, 0, T - 1, 0, (56, 74, 110))
        return im
    if kind == "wood_panel":
        im = new(T, T, (150, 104, 70))
        for x in range(0, T, 4):
            c = jitter((150, 104, 70), rnd, 0.05)
            rect(im, x, 0, x + 3, T - 1, c)
            vline(im, x + 3, 0, T - 1, shade(c, 0.78))
            vline(im, x, 0, T - 1, lighten(c, 0.08))
        return im
    if kind == "marble_wall":
        im = new(T, T, (222, 216, 204))
        hline(im, 0, T - 1, T - 1, (198, 190, 178))
        vline(im, T - 1, 0, T - 1, (198, 190, 178))
        return im
    if kind == "white_modern":
        im = new(T, T, (236, 238, 240))
        vline(im, T - 1, 0, T - 1, (222, 224, 228))
        return im
    if kind == "concrete_wall":
        im = new(T, T, (172, 174, 178))
        put(im, 4, 4, (154, 156, 160))
        put(im, 11, 11, (154, 156, 160))
        return im
    return new(T, T, (200, 200, 200))


def ground_tiles():
    tiles = [
        ("grass", lambda: t_grass(0)), ("grass_flowers", lambda: t_grass(1)),
        ("sidewalk", lambda: t_pavers(1)), ("sidewalk_alt", lambda: t_pavers(2, (194, 188, 178))),
        ("road", lambda: t_asphalt("plain", 1)), ("road_dash_h", lambda: t_asphalt("dash_h", 2)),
        ("road_dash_v", lambda: t_asphalt("plain", 4)), ("crosswalk_h", lambda: t_asphalt("cross_h", 5)),
        ("crosswalk_v", lambda: t_asphalt("cross_v", 6)), ("curb_top", lambda: t_curb(True)),
        ("curb_bottom", lambda: t_curb(False)), ("water", lambda: t_water(0)),
        ("water_alt", lambda: t_water(1)), ("water_edge", t_water_edge),
        ("boards", t_boards), ("plaza", lambda: t_slab(3)), ("plaza_alt", lambda: t_slab(4, (206, 198, 184))),
        ("garden", t_soil), ("road_edge_top", lambda: t_asphalt("edge_top", 8)),
        ("road_edge_bottom", lambda: t_asphalt("edge_bottom", 9)), ("parking", lambda: t_asphalt("parking", 10)),
        ("manhole", lambda: t_asphalt("manhole", 11)), ("road_b", lambda: t_asphalt("plain", 3)),
    ]
    return tiles


# ================================================================ props
def tree_round(seed=1, w=64, h=92, tones=None):
    rnd = random.Random(seed)
    im = new(w, h)
    cx = w // 2
    # grate + shadow
    shadow_ellipse(im, cx, h - 5, 22, 5, 80)
    rect(im, cx - 7, h - 7, cx + 6, h - 4, (70, 74, 84))
    for x in range(cx - 6, cx + 6, 2):
        vline(im, x, h - 6, h - 5, (46, 50, 58))
    # trunk
    rect(im, cx - 2, h - 34, cx + 2, h - 6, (110, 78, 54))
    vline(im, cx - 2, h - 36, h - 6, (136, 100, 70))
    vline(im, cx + 2, h - 36, h - 6, (84, 58, 40))
    put(im, cx - 3, h - 30, (110, 78, 54))
    put(im, cx + 3, h - 26, (110, 78, 54))
    tones = tones or [(58, 98, 60), (84, 132, 66), (118, 166, 80), (164, 200, 108)]
    clusters = []
    for i in range(14):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0, 17)
        clusters.append((cx + int(math.cos(a) * r), 36 + int(math.sin(a) * r * 0.75), rnd.randint(11, 15)))
    clusters.sort(key=lambda c: c[1])
    def clump(px, py):
        # value noise on a 3px lattice → leaf clumps
        hsh = ((px // 3) * 73856093) ^ ((py // 3) * 19349663) ^ seed * 83492791
        return ((hsh >> 3) % 1000) / 1000.0 - 0.5
    for (x, y, s) in clusters:
        m = Mask(w, h).ellipse(x - s, y - s, x + s, y + s)
        for px, py in m.pixels():
            dx, dy = (px - x) / s, (py - y) / s
            light = -dx * 0.6 - dy * 0.8 + clump(px, py) * 0.9 + clump(px + 1, py + 2) * 0.3
            if light > 0.45:
                c = tones[3]
            elif light > 0.0:
                c = tones[2]
            elif light > -0.55:
                c = tones[1]
            else:
                c = tones[0]
            put(im, px, py, c)
    # outline + speckle
    edge = []
    for y in range(h):
        for x in range(w):
            p = get(im, x, y)
            if p[3] and y < h - 36 and any(get(im, x + dx, y + dy)[3] == 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                edge.append((x, y))
    for (x, y) in edge:
        put(im, x, y, shade(tones[0], 0.7))
    for _ in range(90):
        x, y = rnd.randrange(w), rnd.randrange(h - 36)
        p = get(im, x, y)
        if p[3] and p[:3] in (tones[1], tones[2]):
            put(im, x, y, tones[3] if rnd.random() < 0.5 else tones[0])
    return im


def tree_tall(seed=3):
    rnd = random.Random(seed)
    w, h = 34, 90
    im = new(w, h)
    cx = w // 2
    shadow_ellipse(im, cx, h - 4, 12, 3, 80)
    rect(im, cx - 1, h - 16, cx + 1, h - 4, (104, 74, 52))
    tones = [(44, 80, 62), (62, 108, 76), (90, 142, 88), (140, 184, 110)]
    for i in range(9):
        y = 12 + i * 7
        s = 8 + min(i, 5)
        x = cx + rnd.randint(-2, 2)
        m = Mask(w, h).ellipse(x - s, y - s, x + s, y + s)
        for px, py in m.pixels():
            dx, dy = (px - x) / s, (py - y) / s
            light = -dx * 0.7 - dy * 0.6
            put(im, px, py, tones[3] if light > 0.5 else tones[2] if light > 0 else tones[1] if light > -0.6 else tones[0])
    return im


def lamp(banner=None):
    w, h = 20, 72
    im = new(w, h)
    shadow_ellipse(im, 8, h - 3, 5, 2, 70)
    pole = (54, 60, 74)
    rect(im, 7, 8, 8, h - 4, pole)
    vline(im, 7, 8, h - 4, (86, 94, 110))
    rect(im, 5, h - 5, 10, h - 3, pole)
    # arm + head
    hline(im, 8, 15, 8, pole)
    rect(im, 12, 6, 18, 8, (40, 44, 54))
    hline(im, 13, 17, 9, (255, 236, 180))
    if banner:
        rect(im, 9, 18, 15, 38, banner)
        hline(im, 9, 15, 18, lighten(banner, 0.3))
        vline(im, 15, 18, 38, shade(banner, 0.7))
        for (x, y) in ((11, 24), (12, 23), (13, 24), (11, 26), (13, 26)):
            put(im, x, y, (240, 240, 250))
        hline(im, 10, 14, 32, (226, 186, 90))
    return im


def bench():
    im = new(36, 22)
    shadow_ellipse(im, 18, 19, 16, 3, 60)
    frame = (58, 62, 74)
    for x in (4, 30):
        rect(im, x, 6, x + 1, 18, frame)
    for i, y in enumerate((2, 5, 10, 13)):
        c = (176, 124, 80) if i % 2 == 0 else (158, 110, 70)
        rect(im, 1, y, 34, y + 1, c)
        hline(im, 1, 34, y, lighten(c, 0.15))
    hline(im, 1, 34, 15, (110, 76, 50))
    return im


def planter(big=True):
    w, h = (36, 30) if big else (24, 22)
    im = new(w, h)
    shadow_ellipse(im, w // 2, h - 3, w // 2 - 1, 3, 70)
    body = (164, 166, 170)
    rect(im, 1, h - 12, w - 2, h - 3, body)
    hline(im, 1, w - 2, h - 12, (206, 208, 212))
    hline(im, 1, w - 2, h - 3, (120, 122, 128))
    vline(im, w - 2, h - 12, h - 3, (134, 136, 142))
    rnd = random.Random(w)
    tones = [(58, 98, 60), (84, 132, 66), (118, 166, 80), (164, 200, 108)]
    for i in range(5 if big else 3):
        x = 5 + i * (w - 10) // max(1, (4 if big else 2))
        s = rnd.randint(5, 7)
        m = Mask(w, h).ellipse(x - s, h - 14 - s, x + s, h - 12)
        for px, py in m.pixels():
            dy = (py - (h - 14 - s // 2)) / s
            put(im, px, py, tones[3] if dy < -0.6 else tones[2] if dy < -0.1 else tones[1])
    for _ in range(8):
        put(im, rnd.randint(3, w - 4), rnd.randint(h - 22, h - 14), rnd.choice([(244, 160, 180), (250, 226, 120), (252, 252, 252), (230, 110, 90)]))
    return im


def bollard():
    im = new(8, 16)
    shadow_ellipse(im, 4, 14, 3, 1, 70)
    rect(im, 2, 3, 5, 14, (60, 64, 76))
    vline(im, 2, 3, 14, (96, 102, 116))
    rect(im, 1, 2, 6, 3, (74, 80, 94))
    hline(im, 2, 5, 6, (220, 220, 226))
    return im


def trash():
    im = new(18, 22)
    shadow_ellipse(im, 9, 20, 8, 2, 60)
    for i, c in enumerate(((70, 110, 90), (60, 90, 150))):
        x = 1 + i * 8
        rect(im, x, 6, x + 7, 19, c)
        vline(im, x, 6, 19, lighten(c, 0.2))
        vline(im, x + 7, 6, 19, shade(c, 0.7))
        rect(im, x, 4, x + 7, 6, (52, 56, 66))
        hline(im, x + 2, x + 5, 5, (20, 22, 28))
    return im


def bike_rack():
    im = new(36, 22)
    shadow_ellipse(im, 18, 19, 16, 2, 60)
    d = ImageDraw.Draw(im)
    for bx, col in ((2, (46, 98, 176)), (18, (200, 80, 70))):
        for cx in (bx + 4, bx + 13):
            d.ellipse([cx - 4, 10, cx + 4, 18], outline=(34, 36, 44, 255))
            put(im, cx, 14, (120, 124, 134))
        d.line([(bx + 4, 14), (bx + 8, 8), (bx + 13, 14)], fill=col + (255,))
        d.line([(bx + 8, 8), (bx + 12, 8)], fill=col + (255,))
        d.line([(bx + 8, 8), (bx + 7, 6)], fill=(40, 40, 46, 255))
        d.line([(bx + 12, 8), (bx + 13, 6)], fill=(40, 40, 46, 255))
    return im


def metro_pillar():
    im = new(18, 50)
    shadow_ellipse(im, 9, 47, 6, 2, 70)
    rect(im, 3, 14, 14, 47, (40, 46, 60))
    vline(im, 3, 14, 47, (70, 78, 96))
    rect(im, 5, 18, 12, 36, (60, 140, 210))
    for y in range(20, 35, 3):
        hline(im, 6, 11, y, (190, 230, 255))
    rect(im, 1, 0, 16, 14, (46, 98, 196))
    hline(im, 1, 16, 0, (110, 160, 230))
    draw_text_centered(im, 9, 5, "M", (255, 255, 255))
    return im


def cafe_board():
    im = new(16, 22)
    shadow_ellipse(im, 8, 20, 7, 2, 60)
    m = Mask(16, 22).poly([(3, 0), (12, 0), (15, 20), (0, 20)])
    fill(im, m, (70, 50, 36))
    rect(im, 3, 2, 12, 16, (34, 40, 38))
    hline(im, 4, 11, 4, (250, 230, 160))
    for y in (7, 10, 13):
        hline(im, 4, 11, y, (220, 220, 214))
    return im


def umbrella_table(col=(62, 120, 78)):
    im = new(36, 38)
    shadow_ellipse(im, 18, 34, 14, 3, 70)
    m = Mask(36, 38).poly([(1, 14), (34, 14), (26, 3), (9, 3)])
    for px, py in m.pixels():
        seg = (px // 5) % 2
        c = col if seg == 0 else (244, 240, 230)
        put(im, px, py, mix(lighten(c, 0.15), shade(c, 0.85), (py - 3) / 11))
    hline(im, 1, 34, 14, shade(col, 0.6))
    rect(im, 17, 15, 18, 30, (70, 74, 86))
    m2 = Mask(36, 38).ellipse(7, 26, 28, 33)
    shaded(im, m2, ramp((236, 236, 232)), 0, 0)
    for x in (4, 30):
        rect(im, x, 26, x + 3, 32, (60, 66, 80))
    return im


def bus_shelter():
    w, h = 56, 46
    im = new(w, h)
    shadow_ellipse(im, w // 2, h - 3, w // 2 - 2, 3, 60)
    rect(im, 1, 2, w - 2, 5, (46, 52, 66))
    hline(im, 1, w - 2, 2, (100, 110, 130))
    for x in range(3, w - 18):
        for y in range(6, h - 8):
            put(im, x, y, (190, 220, 238, 120))
    rect(im, 2, 6, 3, h - 4, (60, 66, 80))
    rect(im, w - 18, 6, w - 3, h - 8, (40, 46, 60))
    rect(im, w - 16, 8, w - 5, h - 11, (70, 150, 220))
    draw_text(im, w - 15, 10, "BUS", (255, 255, 255))
    rect(im, 6, h - 16, w - 22, h - 13, (170, 120, 80))
    return im


def billboard():
    w, h = 68, 60
    im = new(w, h)
    shadow_ellipse(im, w // 2, h - 3, 12, 2, 70)
    rect(im, 31, 32, 35, h - 4, (60, 66, 80))
    rect(im, 0, 0, w - 1, 33, (30, 38, 56))
    for y in range(3, 31):
        hline(im, 3, w - 4, y, mix((110, 176, 236), (46, 98, 176), (y - 3) / 28))
    draw_text(im, 7, 7, "BIG IDEAS", (255, 255, 255))
    draw_text(im, 7, 15, "BRIGHTER", (255, 255, 255))
    draw_text(im, 7, 22, "TOMORROWS", (255, 230, 140))
    return im


def digital_kiosk():
    w, h = 22, 46
    im = new(w, h)
    shadow_ellipse(im, 11, h - 3, 8, 2, 70)
    rect(im, 2, 2, w - 3, h - 4, (36, 42, 56))
    hline(im, 2, w - 3, 2, (80, 90, 110))
    rect(im, 4, 5, w - 5, h - 10, (40, 110, 186))
    rect(im, 5, 8, w - 6, 13, (240, 246, 255))
    for y in (17, 21, 25, 29):
        hline(im, 5, w - 7, y, (170, 214, 250))
    rect(im, 5, 33, w - 6, 35, (255, 200, 90))
    return im


def wayfinding(labels=("FINANCIAL", "STATION", "RIVERSIDE")):
    w, h = 44, 50
    im = new(w, h)
    shadow_ellipse(im, 21, h - 3, 6, 2, 70)
    rect(im, 20, 8, 22, h - 4, (54, 60, 74))
    for i in range(3):
        y = 2 + i * 10
        rect(im, 1, y, w - 2, y + 8, (30, 46, 80))
        hline(im, 1, w - 2, y, (80, 110, 160))
        put(im, w - 5, y + 3, (255, 255, 255))
        put(im, w - 4, y + 4, (255, 255, 255))
        put(im, w - 5, y + 5, (255, 255, 255))
        hline(im, 3, w - 9, y + 4, (220, 228, 244))
    return im


def business_board():
    w, h = 44, 56
    im = new(w, h)
    shadow_ellipse(im, 22, h - 3, 18, 3, 70)
    for x in (4, 38):
        rect(im, x, 34, x + 2, h - 4, (54, 60, 74))
    rect(im, 0, 0, w - 1, 36, (40, 52, 80))
    hline(im, 0, w - 1, 0, (90, 110, 150))
    rect(im, 3, 8, w - 4, 33, (200, 164, 114))
    for (x, y, c) in ((5, 10, (250, 250, 240)), (17, 11, (250, 230, 140)), (29, 10, (180, 220, 250)),
                      (6, 21, (250, 200, 200)), (18, 22, (250, 250, 240)), (30, 21, (200, 240, 200))):
        rect(im, x, y, x + 9, y + 9, c)
        hline(im, x + 1, x + 7, y + 3, (120, 120, 130))
        hline(im, x + 1, x + 5, y + 5, (120, 120, 130))
        put(im, x + 4, y, (220, 60, 60))
    draw_text_centered(im, 22, 2, "BOARD", (250, 250, 250))
    return im


def hedge(w=48):
    h = 20
    im = new(w, h)
    rnd = random.Random(w)
    tones = [(50, 88, 56), (70, 118, 64), (98, 148, 76), (140, 184, 100)]
    rect(im, 0, 8, w - 1, h - 3, tones[1])
    for x in range(0, w, 5):
        s = rnd.randint(4, 6)
        m = Mask(w, h).ellipse(x - s, 8 - s, x + s, 8 + s)
        for px, py in m.pixels():
            put(im, px, py, tones[3] if py < 5 else tones[2])
    hline(im, 0, w - 1, h - 3, tones[0])
    for _ in range(20):
        put(im, rnd.randrange(w), rnd.randrange(4, h - 3), rnd.choice(tones))
    return im


def railing(w=64):
    im = new(w, 14)
    for x in range(0, w, 16):
        rect(im, x + 1, 2, x + 2, 12, (70, 76, 90))
    hline(im, 0, w - 1, 2, (150, 160, 176))
    hline(im, 0, w - 1, 3, (80, 86, 100))
    hline(im, 0, w - 1, 7, (110, 118, 132))
    return im


def fountain():
    w, h = 68, 44
    im = new(w, h)
    shadow_ellipse(im, w // 2, h - 4, w // 2 - 2, 5, 60)
    m = Mask(w, h).ellipse(1, 14, w - 2, h - 4)
    shaded(im, m, ramp((206, 200, 188)), 0, 0)
    m2 = Mask(w, h).ellipse(6, 17, w - 7, h - 8)
    for px, py in m2.pixels():
        put(im, px, py, mix((110, 170, 220), (60, 120, 182), (py - 17) / 14))
    for x in (18, 32, 46):
        hline(im, x, x + 5, 26, (180, 220, 250))
    rect(im, 30, 4, 37, 28, (214, 208, 196))
    vline(im, 30, 4, 28, (236, 232, 222))
    for (x, y) in ((33, 0), (29, 3), (38, 3), (33, 2), (27, 7), (40, 7)):
        put(im, x, y, (200, 232, 255))
    return im


def flower_bed(w=36):
    im = new(w, 18)
    rnd = random.Random(w + 3)
    rect(im, 0, 8, w - 1, 17, (150, 150, 156))
    hline(im, 0, w - 1, 8, (196, 196, 200))
    rect(im, 1, 9, w - 2, 12, (104, 78, 58))
    tones = [(70, 118, 64), (98, 148, 76), (140, 184, 100)]
    for x in range(1, w - 1, 3):
        s = rnd.randint(3, 4)
        m = Mask(w, 18).ellipse(x - s, 9 - s, x + s, 9 + s // 2)
        fill(im, m, rnd.choice(tones))
    for _ in range(16):
        put(im, rnd.randrange(2, w - 2), rnd.randrange(3, 10), rnd.choice([(244, 150, 170), (250, 226, 120), (252, 252, 252), (226, 96, 80), (190, 160, 240)]))
    return im


def flagpole():
    im = new(22, 66)
    shadow_ellipse(im, 4, 63, 4, 2, 70)
    rect(im, 3, 2, 4, 62, (206, 210, 218))
    for y in range(4, 16):
        for x in range(5, 20):
            wave = int(math.sin((x - 5) / 3.0) * 1.2)
            put(im, x, y + wave, (46, 98, 196) if y > 5 else (250, 250, 250))
    m = Mask(22, 66).ellipse(9, 7, 14, 12)
    fill(im, m, (250, 220, 120))
    rect(im, 1, 62, 6, 64, (120, 126, 138))
    return im


def hydrant():
    im = new(10, 16)
    shadow_ellipse(im, 5, 14, 4, 1, 60)
    rect(im, 2, 4, 7, 14, (200, 70, 60))
    vline(im, 2, 4, 14, (230, 110, 96))
    rect(im, 1, 6, 8, 7, (180, 60, 50))
    rect(im, 3, 2, 6, 4, (170, 60, 50))
    return im


def cone():
    im = new(10, 14)
    m = Mask(10, 14).poly([(4, 0), (5, 0), (8, 11), (1, 11)])
    fill(im, m, (240, 130, 50))
    hline(im, 3, 6, 5, (250, 250, 250))
    rect(im, 0, 11, 9, 12, (60, 60, 60))
    return im


def parking_meter():
    im = new(8, 24)
    rect(im, 3, 8, 4, 22, (70, 76, 90))
    box(im, 1, 0, 6, 8, (100, 110, 126), (60, 66, 80))
    put(im, 3, 3, (140, 230, 160))
    return im


def street_props():
    return {
        "tree_round": lambda: tree_round(1), "tree_round_b": lambda: tree_round(7, tones=[(52, 90, 70), (76, 124, 80), (110, 160, 96), (156, 196, 120)]),
        "tree_tall": tree_tall, "lamp": lambda: lamp(), "lamp_banner": lambda: lamp((46, 98, 176)),
        "bench": bench, "planter": lambda: planter(True), "planter_small": lambda: planter(False), "bollard": bollard,
        "trash_bin": trash, "bike": bike_rack, "metro_sign": metro_pillar, "cafe_board": cafe_board,
        "umbrella_table": lambda: umbrella_table(), "umbrella_table_blue": lambda: umbrella_table((46, 98, 176)),
        "bus_stop": bus_shelter, "billboard": billboard, "digital_sign": digital_kiosk, "direction_sign": wayfinding,
        "business_board": business_board, "hedge": lambda: hedge(48), "railing": lambda: railing(64), "fountain": fountain,
        "flower_bed": lambda: flower_bed(36), "flagpole": flagpole, "hydrant": hydrant, "cone": cone, "parking_meter": parking_meter,
    }
