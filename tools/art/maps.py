"""City map (angled Aurelia overview) and World Map placeholders, 640x360.
Labels/markers are drawn at runtime from data, so these are clean backdrops.
"""
from __future__ import annotations

import math
import random

from pixel import PAL, Mask, new, shaded, fill, put, get, rect, hline, vline, box, save, ramp, shade, lighten, mix

W, H = 640, 360

# keep in sync with game/data/city/aurelia.json map_pos
DISTRICTS = {
    "residential": (150, 92, "res"), "luxury_heights": (318, 58, "lux"), "airport": (548, 70, "air"),
    "civic_center": (392, 132, "civic"), "financial": (292, 180, "fin"), "shopping_street": (128, 190, "shop"),
    "startup_hub": (500, 205, "startup"), "riverside": (362, 262, "river"), "harbor": (292, 318, "harbor"),
    "old_town": (228, 118, "old"), "university": (590, 150, "uni"), "industrial": (44, 150, "ind"),
}


def noise2(seed):
    rnd = random.Random(seed)
    g = [[rnd.random() for _ in range(40)] for _ in range(40)]

    def f(x, y):
        x0, y0 = int(x) % 39, int(y) % 39
        fx, fy = x - int(x), y - int(y)
        a = g[y0][x0] * (1 - fx) + g[y0][x0 + 1] * fx
        b = g[y0 + 1][x0] * (1 - fx) + g[y0 + 1][x0 + 1] * fx
        return a * (1 - fy) + b * fy
    return f


def river_path():
    pts = []
    for i in range(0, 101):
        t = i / 100
        x = 660 - t * 470
        y = 150 + t * 150 + 22 * math.sin(t * 7.0)
        pts.append((x, y))
    return pts


def city_map(out):
    im = new(W, H, (40, 90, 140))
    n = noise2(3)
    land = Mask(W, H)
    # coastline: bay bottom-left
    bay = Mask(W, H).poly([(0, 222), (60, 214), (120, 196), (175, 206), (215, 236), (250, 272), (286, 318),
                           (310, 360), (0, 360)])
    for y in range(H):
        for x in range(W):
            wob = (n(x / 16, y / 16) - 0.5) * 10
            if not bay.get(int(x + wob), int(y + wob)) and y < 344 + 8 * n(x / 30, 3):
                land.px(x, y)
    rp = river_path()
    river = Mask(W, H)
    for (x, y) in rp:
        river.ellipse(x - 9, y - 7, x + 9, y + 7)
    land.subtract(river)
    # land base
    for x, y in land.pixels():
        v = n(x / 18, y / 18)
        c = mix(PAL["grass_400"], PAL["grass_300"], v)
        put(im, x, y, c)
    # water shimmer
    rnd = random.Random(9)
    for _ in range(900):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if not land.get(x, y):
            hline(im, x, x + rnd.randint(1, 4), y, (70, 130, 180))
    # coast outline + sand
    for x, y in land.pixels():
        if not land.get(x + 1, y) or not land.get(x - 1, y) or not land.get(x, y + 1) or not land.get(x, y - 1):
            put(im, x, y, (214, 204, 170))
    # road grid
    for key, (cx, cy, kind) in DISTRICTS.items():
        r = KINDS[kind]["r"]
        pm = Mask(W, H).ellipse(cx - r - 6, cy - r * 0.6 - 10, cx + r + 6, cy + r * 0.6 + 6)
        for x, y in pm.pixels():
            if land.get(x, y):
                c = get(im, x, y)
                put(im, x, y, mix(c[:3], (206, 204, 190), 0.55))
    for yy in (40, 110, 170, 236, 300):
        for x in range(W):
            y = yy + int(6 * math.sin(x / 90))
            if land.get(x, y):
                put(im, x, y, (224, 222, 212)); put(im, x, y + 1, (170, 170, 164))
    for xx in (70, 200, 330, 450, 580):
        for y in range(H):
            x = xx + int((y - 180) * 0.3)
            if 0 <= x < W and land.get(x, y):
                put(im, x, y, (224, 222, 212)); put(im, x + 1, y, (170, 170, 164))
    # bridges over river
    for t in (0.18, 0.42, 0.66):
        x, y = rp[int(t * 100)]
        rect(im, int(x) - 1, int(y) - 12, int(x) + 1, int(y) + 12, (200, 196, 186))
    # district clusters
    for key, (cx, cy, kind) in DISTRICTS.items():
        cluster(im, land, cx, cy, kind, hash(key) % 1000)
    # airport runways
    for (x0, y0, x1) in ((500, 40, 610), (512, 60, 624)):
        for x in range(x0, x1):
            y = y0 + int((x - x0) * -0.18)
            rect(im, x, y, x, y + 5, (110, 114, 124))
            if x % 8 < 4:
                put(im, x, y + 2, (240, 240, 240))
    save(im, f"{out}/city_map/aurelia_map.png")


def block(im, x, y, w, d, hgt, top, front, windows=True, rnd=None):
    # front face
    rect(im, x, y - hgt, x + w - 1, y, front)
    vline(im, x + w - 1, y - hgt, y, shade(front, 0.8))
    if windows and hgt > 5:
        for yy in range(y - hgt + 2, y - 1, 3):
            for xx in range(x + 1, x + w - 2, 2):
                if rnd is None or rnd.random() < 0.7:
                    put(im, xx, yy, lighten(front, 0.35))
    # top face
    rect(im, x, y - hgt - d, x + w - 1, y - hgt - 1, top)
    hline(im, x, x + w - 1, y - hgt - d, lighten(top, 0.2))


KINDS = {
    "fin": dict(n=34, hmin=18, hmax=58, top=(170, 196, 226), front=(70, 104, 150), r=40),
    "startup": dict(n=30, hmin=8, hmax=26, top=(220, 226, 232), front=(110, 150, 196), r=38),
    "river": dict(n=28, hmin=6, hmax=18, top=(236, 222, 200), front=(190, 130, 100), r=36),
    "res": dict(n=34, hmin=6, hmax=14, top=(230, 214, 194), front=(200, 150, 120), r=42),
    "lux": dict(n=10, hmin=16, hmax=40, top=(236, 230, 240), front=(150, 140, 190), r=34),
    "civic": dict(n=8, hmin=8, hmax=16, top=(240, 234, 220), front=(200, 190, 170), r=28),
    "shop": dict(n=30, hmin=6, hmax=16, top=(240, 220, 210), front=(210, 110, 120), r=40),
    "harbor": dict(n=12, hmin=5, hmax=10, top=(160, 176, 200), front=(80, 110, 160), r=40),
    "old": dict(n=14, hmin=5, hmax=11, top=(220, 190, 160), front=(170, 100, 80), r=32),
    "uni": dict(n=10, hmin=6, hmax=14, top=(236, 226, 206), front=(170, 120, 90), r=32),
    "ind": dict(n=10, hmin=6, hmax=12, top=(180, 184, 190), front=(120, 124, 134), r=36),
    "air": dict(n=5, hmin=6, hmax=10, top=(220, 226, 232), front=(130, 150, 176), r=26),
}


def cluster(im, land, cx, cy, kind, seed):
    k = KINDS[kind]
    rnd = random.Random(seed)
    pts = []
    for _ in range(k["n"]):
        a = rnd.random() * math.tau
        r = rnd.random() ** 0.7 * k["r"]
        pts.append((int(cx + math.cos(a) * r), int(cy + math.sin(a) * r * 0.6)))
    pts.sort(key=lambda p: p[1])
    for (x, y) in pts:
        if not land.get(x, y) or not land.get(x + 10, y):
            continue
        w = rnd.randint(7, 12)
        hgt = rnd.randint(k["hmin"], k["hmax"])
        block(im, x, y, w, 4, hgt, k["top"], k["front"], rnd=rnd)
    # trees
    for _ in range(20):
        x = cx + rnd.randint(-k["r"], k["r"])
        y = cy + rnd.randint(-k["r"] // 2, k["r"] // 2)
        if land.get(x, y) and get(im, x, y)[1] > get(im, x, y)[0]:
            put(im, x, y, PAL["leaf_500"]); put(im, x, y - 1, PAL["leaf_400"])
    if kind == "harbor":
        for i in range(4):
            x = cx - 36 + i * 14
            y = cy + 10
            if land.get(x, y):
                vline(im, x, y - 18, y, (200, 70, 60)); hline(im, x - 4, x + 8, y - 18, (200, 70, 60))
        for i in range(10):
            x = cx - 20 + (i % 5) * 7
            y = cy + 20 + (i // 5) * 4
            rect(im, x, y, x + 5, y + 2, rnd.choice([(200, 90, 70), (70, 120, 180), (230, 180, 80), (90, 150, 110)]))


def world_map(out):
    im = new(W, H)
    for y in range(H):
        for x in range(W):
            t = y / H
            c = mix((30, 70, 120), (22, 52, 96), t)
            if (x + y) % 7 == 0 and (x * 3 + y) % 11 == 0:
                c = lighten(c, 0.08)
            put(im, x, y, c)
    n = noise2(21)
    blobs = [  # (cx, cy, rx, ry)
        (120, 100, 90, 60), (90, 70, 50, 30), (160, 150, 40, 30),          # north continent (Northridge)
        (185, 250, 42, 70), (170, 210, 30, 30),                             # south (Solterra)
        (310, 90, 50, 34), (290, 70, 30, 20),                               # Auroria
        (320, 215, 55, 75),                                                  # Karu
        (375, 150, 34, 30),                                                  # Almeria
        (470, 100, 90, 55), (520, 70, 60, 34),                              # Zenkai region
        (505, 195, 30, 22), (540, 225, 26, 16),                             # Lumina
        (575, 160, 22, 30),                                                  # Aurelia coast
        (560, 290, 45, 28),                                                  # southern continent
    ]
    land = Mask(W, H)
    for y in range(H):
        for x in range(W):
            v = 0
            for (cx, cy, rx, ry) in blobs:
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                v = max(v, 1 - d)
            v += (n(x / 14, y / 14) - 0.5) * 0.3
            if v > 0.1:
                land.px(x, y)
    for x, y in land.pixels():
        v = n(x / 10 + 5, y / 10)
        c = mix((96, 150, 84), (140, 176, 96), v)
        if y < 60:
            c = mix(c, (214, 222, 226), 0.4)
        dd = ((x - 340) / 60) ** 2 + ((y - 190) / 40) ** 2
        if dd < 1:
            c = mix(c, (200, 176, 120), 0.5 * (1 - dd))
        put(im, x, y, c)
    for x, y in list(land.pixels()):
        if not land.get(x + 1, y) or not land.get(x - 1, y) or not land.get(x, y + 1) or not land.get(x, y - 1):
            put(im, x, y, (226, 214, 170))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if not land.get(x + dx, y + dy):
                    put(im, x + dx, y + dy, (70, 130, 180))
    rnd = random.Random(4)
    for _ in range(40):
        x, y = rnd.randrange(W), rnd.randrange(H)
        if land.get(x, y):
            put(im, x, y, (120, 100, 80)); put(im, x + 1, y, (160, 140, 110)); put(im, x, y - 1, (230, 230, 230))
    # clouds
    for _ in range(14):
        cx, cy = rnd.randrange(W), rnd.randrange(H)
        for k in range(4):
            m = Mask(W, H).ellipse(cx + k * 6 - 10, cy - 3 + (k % 2) * 2, cx + k * 6, cy + 5)
            for x, y in m.pixels():
                c = get(im, x, y)
                put(im, x, y, lighten(c[:3], 0.55))
    save(im, f"{out}/world_map/world_map.png")


def generate(out):
    city_map(out)
    world_map(out)
