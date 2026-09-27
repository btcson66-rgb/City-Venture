"""Neo-Civic building facades v2 — volumetric 3/4 buildings modelled on Concept Boards A/G.

Each building is drawn in an oblique projection: front facade + a receding right side wall +
a visible roof plane with rooftop equipment/greenery. Glass shows lit interiors (desks, plants,
people, ceiling lights) behind a tinted, reflective pane. Floors read through projecting slabs.
Ground floors get proper storefronts: canopies, awnings, signage bands, display windows.
Outputs <id>.png, <id>_lights.png (night overlay) and metadata (door/sign/front rect).
"""
from __future__ import annotations

import json
import math
import random

from PIL import ImageDraw

from pixel import (PAL, Mask, new, shaded, fill, put, get, rect, hline, vline, box, save, ramp,
                   shade, lighten, mix)
from font3x5 import draw_text, draw_text_centered, text_width

SKY_REFLECT = (178, 214, 242)

# ------------------------------------------------------------------ concept-board textures
# Glass reflects the Board-G day skyline, and shop/office glass shows the Board-H/C interiors, so the
# facades carry the same painted detail as the concept boards (falls back to flat paint without OpenCV).
_TEX: dict = {}
_REF_OFF = [0, 0]
BOARD_INTERIORS = {
    "office": [("H", (16, 157, 380, 362)), ("H", (533, 157, 885, 362)), ("H", (16, 797, 393, 992))],
    "lobby": [("H", (533, 157, 885, 362)), ("H", (16, 472, 383, 690))],
    "bank": [("H", (16, 472, 383, 690))],
    "civic": [("H", (16, 472, 383, 690))],
    "cafe": [("H", (518, 472, 835, 690)), ("C", (736, 300, 1000, 500))],
    "shop": [("H", (515, 797, 850, 990)), ("H", (518, 472, 835, 690))],
    "home": [("H", (1025, 157, 1330, 362)), ("H", (967, 797, 1318, 965))],
}
TEX_H = 48


def board_tex():
    if "reflect" in _TEX or "none" in _TEX:
        return _TEX
    try:
        import numpy as np
        import cv2
        import concepts as C
        sky = C.crop("G", (700, 2, 1330, 128))
        sky = np.concatenate([sky, sky[:, ::-1]], 1)
        _TEX["reflect"] = cv2.resize(sky, (sky.shape[1] * 110 // sky.shape[0], 110), interpolation=cv2.INTER_AREA)
        for k, lst in BOARD_INTERIORS.items():
            ims = []
            for key, box in lst:
                im = C.crop(key, box)
                ims.append(cv2.resize(im, (im.shape[1] * TEX_H // im.shape[0], TEX_H), interpolation=cv2.INTER_AREA))
            _TEX["in_" + k] = ims
    except Exception as e:  # pragma: no cover
        print("facades: board textures unavailable (%s); using flat paint" % e)
        _TEX["none"] = True
    return _TEX


ROOF_PLANTS = [("C", (1084, 859, 1121, 916)), ("G", (1086, 932, 1128, 985)), ("G", (1128, 925, 1164, 984)),
               ("C", (1130, 846, 1168, 890)), ("C", (1170, 846, 1199, 890)), ("G", (1227, 965, 1282, 1010)),
               ("C", (822, 966, 866, 1029))]


def roof_plants():
    """Board-converted potted plants/planters for roof edges and ledges (RGBA PIL images, ~16px tall)."""
    if "plants" in _TEX:
        return _TEX["plants"]
    out = []
    try:
        from PIL import Image
        import concepts as C
        for key, box in ROOF_PLANTS:
            art = C._cut(key, box, largest=1.0)
            h = 18
            w = max(4, round(art.shape[1] * h / art.shape[0]))
            out.append(Image.fromarray(C._finish(C.downscale(art, (w, h)), 24, 0.4)))
    except Exception as e:  # pragma: no cover
        print("facades: roof plants unavailable (%s)" % e)
    _TEX["plants"] = out
    return out


def set_reflect_offset(seed):
    _REF_OFF[0] = (seed * 97) % 600
    _REF_OFF[1] = (seed * 31) % 30


# ------------------------------------------------------------------ primitives
def poly(img, pts, col):
    d = ImageDraw.Draw(img)
    c = tuple(col[:3]) + ((col[3],) if len(col) > 3 else (255,))
    d.polygon(pts, fill=c)


def vgrad(img, x0, y0, x1, y1, top, bottom, alpha=255):
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, (y1 - y0))
        c = mix(top, bottom, t)
        for x in range(x0, x1 + 1):
            put(img, x, y, c + (alpha,))


def blend_px(img, x, y, col, a):
    if not (0 <= x < img.width and 0 <= y < img.height):
        return
    o = img.getpixel((x, y))
    if o[3] == 0:
        return
    r = tuple(int(o[i] * (1 - a) + col[i] * a) for i in range(3))
    img.putpixel((x, y), r + (o[3],))


def darken_rect(img, x0, y0, x1, y1, k):
    for y in range(max(0, y0), min(img.height, y1 + 1)):
        for x in range(max(0, x0), min(img.width, x1 + 1)):
            o = img.getpixel((x, y))
            if o[3]:
                img.putpixel((x, y), shade(o[:3], k) + (o[3],))


def noise_rect(img, x0, y0, x1, y1, amt, rnd):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rnd.random() < 0.18:
                o = get(img, x, y)
                if o[3]:
                    k = 1 + rnd.uniform(-amt, amt)
                    put(img, x, y, tuple(max(0, min(255, int(v * k))) for v in o[:3]) + (o[3],))


# ------------------------------------------------------------------ interiors seen through glass
def pane_interior(img, lt, x0, y0, x1, y1, rnd, kind="office", lit=True, day_dim=0.78):
    """Paint what you see through a window: back wall, ceiling light, furniture, people."""
    if x1 - x0 < 3 or y1 - y0 < 4:
        return
    h = y1 - y0 + 1
    tex = board_tex()
    ims = tex.get("in_" + kind)
    if ims:
        im = ims[rnd.randrange(len(ims))]
        w = x1 - x0 + 1
        ox = rnd.randint(0, max(0, im.shape[1] - w - 1))
        oy = int(max(0, TEX_H - h) * 0.55)
        for y in range(y0, y1 + 1):
            sy = oy + (y - y0) if h <= TEX_H else (y - y0) * TEX_H // h
            row = im[min(TEX_H - 1, sy)]
            for x in range(x0, x1 + 1):
                c = row[min(im.shape[1] - 1, ox + x - x0)]
                put(img, x, y, (min(255, int(c[0] * day_dim)), min(255, int(c[1] * day_dim)), min(255, int(c[2] * day_dim)), 255))
        if lit and lt is not None:
            for y in range(y0, y1 + 1):
                t = (y - y0) / max(1, h)
                for x in range(x0, x1 + 1):
                    put(lt, x, y, (255, int(210 - 30 * t), int(140 - 40 * t), int(215 - 50 * t)))
        return
    wall = {"office": (214, 206, 190), "home": (226, 196, 160), "shop": (240, 214, 170), "lobby": (236, 214, 176),
            "cafe": (196, 150, 110), "civic": (214, 206, 190), "bank": (200, 196, 190)}.get(kind, (214, 206, 190))
    ceil = shade(wall, 0.72)
    wall_d = shade(wall, day_dim)
    vgrad(img, x0, y0, x1, y1, shade(ceil, day_dim), wall_d)
    # ceiling light strip
    hline(img, x0, x1, y0, shade(ceil, 0.6))
    if x1 - x0 > 5:
        hline(img, x0 + 2, x1 - 2, y0 + 1, (255, 244, 214))
    floor_y = y1 - max(1, h // 5)
    rect(img, x0, floor_y, x1, y1, shade(wall_d, 0.8))
    r = rnd.random()
    cx = (x0 + x1) // 2
    if kind in ("office", "lobby", "bank") and r < 0.6 and x1 - x0 >= 6:
        # desk with monitor
        rect(img, x0 + 1, floor_y - 2, x1 - 1, floor_y - 1, (120, 96, 70))
        rect(img, cx - 2, floor_y - 5, cx + 1, floor_y - 3, (40, 46, 60))
        put(img, cx - 1, floor_y - 4, (120, 190, 240))
        if rnd.random() < 0.5:
            rect(img, cx + 2, floor_y - 6, cx + 3, floor_y - 2, (50, 54, 70))   # person
            put(img, cx + 2, floor_y - 7, (230, 190, 160))
    elif kind in ("home",) and r < 0.7:
        # curtains + lamp
        cc = rnd.choice([(230, 220, 200), (190, 160, 130), (170, 190, 210), (220, 170, 150)])
        vline(img, x0, y0 + 1, y1, cc)
        vline(img, x1, y0 + 1, y1, cc)
        if rnd.random() < 0.5:
            vline(img, x0 + 1, y0 + 1, y1, shade(cc, 0.85))
        if rnd.random() < 0.5:
            put(img, cx, floor_y - 4, (255, 226, 160))
            vline(img, cx, floor_y - 3, floor_y - 1, (90, 70, 50))
    elif kind in ("shop", "cafe"):
        # shelves / counter / customers
        rect(img, x0 + 1, floor_y - 3, x1 - 1, floor_y - 1, (150, 104, 70))
        for x in range(x0 + 1, x1, 3):
            put(img, x, floor_y - 4, rnd.choice([(240, 230, 210), (200, 90, 80), (90, 150, 110), (230, 200, 120)]))
        if rnd.random() < 0.6:
            px = rnd.randint(x0 + 1, max(x0 + 1, x1 - 2))
            rect(img, px, floor_y - 6, px + 1, floor_y - 1, rnd.choice([(60, 70, 110), (140, 60, 60), (70, 90, 70)]))
            put(img, px, floor_y - 7, (230, 190, 160))
    if rnd.random() < 0.25 and x1 - x0 >= 5:
        # plant in the corner
        put(img, x1 - 1, floor_y - 3, PAL["leaf_400"])
        put(img, x1 - 2, floor_y - 2, PAL["leaf_500"])
        put(img, x1 - 1, floor_y - 2, PAL["leaf_300"])
    if lit and lt is not None:
        for y in range(y0, y1 + 1):
            t = (y - y0) / max(1, h)
            for x in range(x0, x1 + 1):
                put(lt, x, y, (255, int(210 - 30 * t), int(140 - 40 * t), int(215 - 50 * t)))


def glass_over(img, x0, y0, x1, y1, tint=(70, 120, 180), a=0.42, rnd=None, reflect=True):
    """Tinted glass with a vertical sky gradient and diagonal reflection streaks."""
    h = y1 - y0 + 1
    ref = board_tex().get("reflect")
    for y in range(y0, y1 + 1):
        t = (y - y0) / max(1, h)
        c = mix(lighten(tint, 0.55), shade(tint, 0.85), t)
        if ref is not None:
            rrow = ref[(y + _REF_OFF[1]) % ref.shape[0]]
        for x in range(x0, x1 + 1):
            if ref is not None:
                rc = rrow[(x + _REF_OFF[0]) % ref.shape[1]]
                cc = mix((int(rc[0]), int(rc[1]), int(rc[2])), tint, 0.3)
                blend_px(img, x, y, cc, min(0.95, a * 1.15 * (1.2 - 0.3 * t)))
            else:
                blend_px(img, x, y, c, min(0.95, a * (1.25 - 0.35 * t)))
    if reflect:
        off = (rnd.randint(0, 20) if rnd else 0)
        for k in range(x0 - h - off, x1 + 1, 17):
            for i in range(h):
                for w in range(2):
                    xx = k + i + w
                    if x0 <= xx <= x1:
                        blend_px(img, xx, y1 - i, SKY_REFLECT, 0.28)
        # top highlight
        for x in range(x0, x1 + 1):
            blend_px(img, x, y0, (230, 244, 255), 0.35)


def window_unit(img, lt, x, y, w, h, frame, rnd, kind="office", lit_p=0.55, sill=True, reveal=True, mullion=True, tint=(62, 124, 200), day_dim=0.6, alpha=0.52):
    rect(img, x, y, x + w - 1, y + h - 1, frame)
    lit = rnd.random() < lit_p
    pane_interior(img, lt, x + 1, y + 1, x + w - 2, y + h - 2, rnd, kind, lit, day_dim)
    glass_over(img, x + 1, y + 1, x + w - 2, y + h - 2, tint, alpha, rnd)
    if reveal:
        hline(img, x + 1, x + w - 2, y + 1, shade(frame, 0.7))
        vline(img, x + 1, y + 1, y + h - 2, shade(frame, 0.75))
    if mullion and w >= 12:
        vline(img, x + w // 2, y + 1, y + h - 2, frame)
        if lt is not None:
            vline(lt, x + w // 2, y + 1, y + h - 2, (0, 0, 0, 0))
    if mullion and h >= 18:
        hline(img, x + 1, x + w - 2, y + h // 3, frame)
        if lt is not None:
            hline(lt, x + 1, x + w - 2, y + h // 3, (0, 0, 0, 0))
    if sill:
        hline(img, x - 1, x + w, y + h, lighten(frame, 0.55))
        hline(img, x - 1, x + w, y + h + 1, shade(frame, 0.6))


# ------------------------------------------------------------------ materials
MATS = {
    "limestone": (226, 214, 190), "cream": (236, 226, 204), "brick": (168, 92, 70), "red_brick": (150, 70, 56),
    "concrete": (194, 196, 198), "dark_panel": (58, 66, 84), "navy_panel": (44, 58, 92), "white": (238, 240, 242),
    "wood": (164, 114, 72), "terracotta": (196, 126, 90), "metal": (122, 138, 158), "warm_grey": (170, 160, 150),
    "sand": (214, 196, 160), "blue_metal": (58, 92, 150),
}


def cladding(img, x0, y0, x1, y1, mat, rnd):
    c = MATS.get(mat, mat) if isinstance(mat, str) else mat
    rect(img, x0, y0, x1, y1, c)
    if mat in ("brick", "red_brick"):
        mort = lighten(c, 0.35)
        dark = shade(c, 0.82)
        for y in range(y0, y1 + 1):
            row = (y - y0) // 3
            if (y - y0) % 3 == 2:
                hline(img, x0, x1, y, shade(c, 0.72))
                continue
            off = 3 if row % 2 else 0
            for x in range(x0 + off, x1 + 1, 6):
                put(img, x, y, shade(c, 0.72))
        for _ in range((x1 - x0) * (y1 - y0) // 14):
            xx, yy = rnd.randint(x0, x1), rnd.randint(y0, y1)
            put(img, xx, yy, rnd.choice([lighten(c, 0.12), dark, shade(c, 0.9)]))
    elif mat in ("limestone", "cream", "sand", "warm_grey"):
        for y in range(y0 + 7, y1 + 1, 8):
            hline(img, x0, x1, y, shade(c, 0.88))
        for yy in range(y0, y1 + 1, 8):
            off = 12 if ((yy - y0) // 8) % 2 else 0
            for x in range(x0 + off, x1 + 1, 24):
                vline(img, x, yy, min(y1, yy + 6), shade(c, 0.9))
        noise_rect(img, x0, y0, x1, y1, 0.035, rnd)
    elif mat in ("concrete", "white"):
        for x in range(x0 + 15, x1, 16):
            vline(img, x, y0, y1, shade(c, 0.9))
        noise_rect(img, x0, y0, x1, y1, 0.03, rnd)
    elif mat in ("dark_panel", "navy_panel", "blue_metal", "metal"):
        for x in range(x0 + 3, x1, 4):
            vline(img, x, y0, y1, shade(c, 0.88))
        for x in range(x0 + 1, x1, 4):
            vline(img, x, y0, y1, lighten(c, 0.07))
    elif mat == "wood":
        for x in range(x0, x1 + 1, 3):
            vline(img, x, y0, y1, shade(c, 0.84))
        noise_rect(img, x0, y0, x1, y1, 0.06, rnd)
    elif mat == "terracotta":
        for y in range(y0 + 3, y1 + 1, 4):
            hline(img, x0, x1, y, shade(c, 0.85))


# ------------------------------------------------------------------ building
class B:
    def __init__(self, w, depth, total_h, roof_extra=18):
        self.W, self.D = w, depth
        self.img = new(w + depth, total_h + depth // 2 + roof_extra + 4)
        self.lt = new(w + depth, total_h + depth // 2 + roof_extra + 4)
        self.base = self.img.height - 4          # ground line
        self.top = self.base - total_h            # top of the front facade
        self.rnd = random.Random(w * 31 + total_h)

    # oblique side wall between y_top..base
    def side(self, y_top, mat_col, windows=None, lit_p=0.5, kind="office", glass=False):
        W, D, img = self.W, self.D, self.img
        dy = D // 2
        poly(img, [(W, y_top), (W + D - 1, y_top - dy), (W + D - 1, self.base - dy), (W, self.base)], shade(mat_col, 0.66))
        # vertical texture
        for x in range(W + 2, W + D, 4):
            k = (x - W) / D
            y0 = int(y_top - dy * k) + 1
            y1 = int(self.base - dy * k) - 1
            vline(img, x, y0, y1, shade(mat_col, 0.6))
        if windows:
            fh, first_y, n_floors = windows
            for f in range(n_floors):
                wy = first_y + f * fh
                for col in range(2):
                    cx0 = W + 3 + col * (D // 2)
                    cw = max(3, D // 2 - 5)
                    for x in range(cx0, cx0 + cw):
                        k = (x - W) / D
                        y0 = int(wy - dy * k) + 2
                        y1 = y0 + fh - 8
                        c_frame = (44, 50, 64)
                        vline(img, x, y0, y1, c_frame)
                    lit = self.rnd.random() < lit_p
                    for x in range(cx0 + 1, cx0 + cw - 1):
                        k = (x - W) / D
                        y0 = int(wy - dy * k) + 3
                        y1 = y0 + fh - 10
                        vline(img, x, y0, y1, (84, 118, 160) if not glass else (70, 110, 160))
                        if lit:
                            vline(self.lt, x, y0, y1, (255, 205, 140, 170))
                        put(img, x, y0, (150, 190, 226))
        # edge line
        vline(img, W, y_top, self.base, shade(mat_col, 0.45))
        # roof plane edge on side
        ImageDraw.Draw(img).line([(W, y_top), (W + D - 1, y_top - dy)], fill=lighten(mat_col, 0.2) + (255,))

    def roof(self, y_top, col=(186, 188, 192), kind="ac", inset=0):
        W, D, img = self.W, self.D, self.img
        dy = D // 2
        poly(img, [(inset, y_top), (W - 1, y_top), (W + D - 1, y_top - dy), (inset + D, y_top - dy)], col)
        # parapet lip
        ImageDraw.Draw(img).line([(inset, y_top), (W - 1, y_top)], fill=lighten(col, 0.25) + (255,))
        ImageDraw.Draw(img).line([(inset + D, y_top - dy), (W + D - 1, y_top - dy)], fill=shade(col, 0.75) + (255,))
        rnd = self.rnd
        if kind in ("green", "terrace"):
            for i in range(max(2, W // 26)):
                x = inset + 6 + i * 24 + rnd.randint(0, 6)
                y = y_top - rnd.randint(2, max(3, dy - 3))
                if x > W + D - 16:
                    continue
                self.bush(x, y, rnd.choice([10, 12, 14]))
            if kind == "terrace":
                for x in range(inset + 1, W - 1, 3):
                    vline(img, x, y_top - 4, y_top - 1, (160, 190, 210))
                hline(img, inset, W - 1, y_top - 4, (220, 230, 240))
        elif kind == "ac":
            for i in range(max(1, W // 40)):
                x = inset + 8 + i * 36 + rnd.randint(0, 8)
                if x > W - 10:
                    continue
                y = y_top - rnd.randint(2, max(3, dy - 2))
                self.box3(x, y, 12, 6, 5, (168, 172, 180))
            if W > 120 and rnd.random() < 0.6:
                # water tank
                x = inset + W // 2 + 10
                y = y_top - dy // 2
                rect(img, x, y - 12, x + 8, y, (140, 120, 100))
                hline(img, x - 1, x + 9, y - 13, (110, 94, 80))
        elif kind == "solar":
            for i in range(W // 22):
                x = inset + 6 + i * 20
                y = y_top - dy + 3
                poly(img, [(x, y + 6), (x + 14, y + 6), (x + 18, y), (x + 4, y)], (46, 70, 120))
                ImageDraw.Draw(img).line([(x + 2, y + 3), (x + 16, y + 3)], fill=(90, 130, 190, 255))

    def box3(self, x, y, w, h, d, col):
        img = self.img
        rect(img, x, y - h, x + w - 1, y, col)
        poly(img, [(x, y - h), (x + w - 1, y - h), (x + w - 1 + d, y - h - d // 2), (x + d, y - h - d // 2)], lighten(col, 0.18))
        poly(img, [(x + w - 1, y - h), (x + w - 1 + d, y - h - d // 2), (x + w - 1 + d, y - d // 2), (x + w - 1, y)], shade(col, 0.7))
        hline(img, x + 2, x + w - 3, y - h + 2, shade(col, 0.75))
        hline(img, x + 2, x + w - 3, y - h + 4, shade(col, 0.75))

    def bush(self, x, y, s):
        img = self.img
        plants = roof_plants()
        if plants:
            p = plants[self.rnd.randrange(len(plants))]
            if s < 8:
                p = p.resize((max(3, p.width * 12 // 16), 12), 0)
            img.alpha_composite(p, (int(x), int(y - p.height + 2)))
            return
        m = Mask(img.width, img.height).ellipse(x, y - s, x + s + 4, y)
        shaded(img, m, ramp(PAL["leaf_400"]), 0, 0, sh_depth=2)
        m2 = Mask(img.width, img.height).ellipse(x + 2, y - s + 1, x + s // 2 + 3, y - s // 2)
        fill(img, m2, PAL["leaf_300"])
        for _ in range(3):
            put(img, x + self.rnd.randint(2, s), y - self.rnd.randint(2, s - 2), (240, 170, 190) if self.rnd.random() < 0.5 else (250, 240, 170))

    def slab(self, y, col, depth=2, x0=0, x1=None):
        x1 = self.W - 1 if x1 is None else x1
        hline(self.img, x0, x1, y, lighten(col, 0.3))
        for i in range(1, depth + 1):
            hline(self.img, x0, x1, y + i, shade(col, 0.85 - 0.1 * i))
        for x in range(x0, x1 + 1):
            blend_px(self.img, x, y + depth + 1, (0, 0, 0), 0.25)

    def ground_shadow(self):
        img = self.img
        for x in range(0, self.W + self.D):
            for i in range(3):
                put(img, x, self.base + 1 + i, (20, 26, 40, 90 - i * 28))


# ------------------------------------------------------------------ storefront pieces
def canopy(b, x0, x1, y, depth=6, col=(40, 46, 60), lights=True):
    img = b.img
    rect(img, x0, y, x1, y + 2, col)
    hline(img, x0, x1, y, lighten(col, 0.3))
    poly(img, [(x0, y), (x1, y), (x1 + depth // 2, y - depth // 2), (x0 + depth // 2, y - depth // 2)], lighten(col, 0.15))
    for x in range(x0, x1 + 1):
        blend_px(img, x, y + 3, (0, 0, 0), 0.35)
        blend_px(img, x, y + 4, (0, 0, 0), 0.18)
    if lights:
        for x in range(x0 + 4, x1 - 2, 10):
            put(img, x, y + 3, (255, 236, 180))
            put(b.lt, x, y + 3, (255, 236, 180, 255))
            for k in range(1, 10):
                a = max(0, 90 - k * 10)
                for dx in range(-k // 3, k // 3 + 1):
                    put(b.lt, x + dx, y + 3 + k, (255, 220, 150, a))


def awning(b, x0, x1, y, col, stripes=True, depth=7):
    img = b.img
    for yy in range(depth):
        for x in range(x0 - yy // 3, x1 + 1 + yy // 3):
            c = col if (not stripes or ((x - x0) // 4) % 2 == 0) else (246, 242, 232)
            c = mix(lighten(c, 0.15), shade(c, 0.9), yy / depth)
            put(img, x, y + yy, c)
    # scalloped edge
    for x in range(x0 - depth // 3, x1 + 1 + depth // 3):
        if (x - x0) % 4 in (1, 2):
            put(img, x, y + depth, shade(col, 0.75))
    hline(img, x0, x1, y, shade(col, 0.6))
    for x in range(x0 - 2, x1 + 3):
        blend_px(img, x, y + depth + 1, (0, 0, 0), 0.35)
        blend_px(img, x, y + depth + 2, (0, 0, 0), 0.2)


def sign_band(b, x0, x1, y, h, col, text=None, text_col=(250, 244, 226), glow=True):
    img = b.img
    rect(img, x0, y, x1, y + h - 1, col)
    hline(img, x0, x1, y, lighten(col, 0.25))
    hline(img, x0, x1, y + h - 1, shade(col, 0.6))
    if glow:
        for x in range(x0 + 2, x1 - 1):
            put(b.lt, x, y + h // 2, (255, 236, 190, 70))


def display_window(b, x0, x1, y0, y1, kind="shop", tint=(90, 130, 170), frame=(40, 46, 60)):
    img = b.img
    rect(img, x0, y0, x1, y1, frame)
    seg = 14
    x = x0 + 1
    while x < x1:
        xe = min(x1 - 1, x + seg - 2)
        pane_interior(img, b.lt, x, y0 + 1, xe, y1 - 1, b.rnd, kind, True, 1.05)
        glass_over(img, x, y0 + 1, xe, y1 - 1, (120, 170, 210), 0.18, b.rnd)
        x = xe + 2
    hline(img, x0, x1, y1, lighten(frame, 0.4))


def glass_door(b, x, y, w, h):
    img = b.img
    rect(img, x, y, x + w - 1, y + h - 1, (38, 42, 54))
    pane_interior(img, b.lt, x + 1, y + 1, x + w // 2 - 1, y + h - 1, b.rnd, "lobby", True, 0.95)
    pane_interior(img, b.lt, x + w // 2 + 1, y + 1, x + w - 2, y + h - 1, b.rnd, "lobby", True, 0.95)
    glass_over(img, x + 1, y + 1, x + w - 2, y + h - 1, (80, 120, 160), 0.3, b.rnd)
    vline(img, x + w // 2, y, y + h - 1, (38, 42, 54))
    rect(img, x + w // 2 - 2, y + h // 2 - 2, x + w // 2 - 2, y + h // 2 + 2, (220, 220, 226))
    rect(img, x + w // 2 + 2, y + h // 2 - 2, x + w // 2 + 2, y + h // 2 + 2, (220, 220, 226))


def wall_lamp(b, x, y):
    rect(b.img, x, y, x + 1, y + 3, (40, 40, 44))
    put(b.img, x, y + 1, (255, 230, 170))
    for k in range(1, 7):
        for dx in range(-k // 2, k // 2 + 1):
            put(b.lt, x + dx, y + 2 + k, (255, 220, 150, max(0, 110 - k * 16)))
    put(b.lt, x, y + 1, (255, 240, 200, 255))


def planter_box(b, x, y, w):
    img = b.img
    rect(img, x, y - 5, x + w - 1, y, (84, 90, 104))
    hline(img, x, x + w - 1, y - 5, (130, 136, 150))
    for i in range(0, w, 7):
        b.bush(x + i - 2, y - 4, 8)


def logo(b, kind, x, y, s, col, bg=None):
    img = b.img
    if bg:
        rect(img, x - 2, y - 2, x + s + 1, y + s + 1, bg)
    if kind == "horizon":
        poly(img, [(x + s // 2, y), (x + s, y + s), (x + s * 3 // 4, y + s), (x + s // 2, y + s // 2 - 1), (x + s // 4, y + s), (x, y + s)], col)
    elif kind == "nexus":
        rect(img, x, y, x + 2, y + s, col)
        rect(img, x + s - 2, y, x + s, y + s, col)
        ImageDraw.Draw(img).line([(x + 1, y), (x + s - 1, y + s)], fill=col + (255,), width=3)
    elif kind == "leaf":
        m = Mask(img.width, img.height).ellipse(x, y + s // 4, x + s, y + s)
        fill(img, m, col)
        vline(img, x + s // 2, y, y + s, shade(col, 0.6))
    elif kind == "m":
        rect(img, x, y, x + s, y + s, (46, 98, 196))
        draw_text_centered(img, x + s // 2 + 1, y + s // 2 - 2, "M", (255, 255, 255))
    elif kind == "civic":
        m = Mask(img.width, img.height).ellipse(x, y, x + s, y + s)
        fill(img, m, (226, 186, 90))
        m2 = Mask(img.width, img.height).ellipse(x + 2, y + 2, x + s - 2, y + s - 2)
        fill(img, m2, (46, 70, 130))
        draw_text_centered(img, x + s // 2 + 1, y + s // 2 - 2, "A", (250, 230, 160))
    for xx in range(x - 1, x + s + 2):
        for yy in range(y - 1, y + s + 2):
            if get(img, xx, yy)[:3] == tuple(col[:3]):
                put(b.lt, xx, yy, tuple(col[:3]) + (150,))


def banner(b, x, y, h, col, text):
    img = b.img
    rect(img, x, y, x + 11, y + h, col)
    hline(img, x, x + 11, y, lighten(col, 0.3))
    vline(img, x + 11, y, y + h, shade(col, 0.7))
    yy = y + 4
    for ch in text:
        draw_text_centered(img, x + 6, yy, ch, (250, 250, 250))
        yy += 7
    for xx in range(x + 1, x + 11):
        for k in range(y + 1, y + h):
            put(b.lt, xx, k, (255, 240, 210, 40))


def column(b, x, y0, y1, w, col):
    img = b.img
    for i in range(w):
        t = i / max(1, w - 1)
        k = 1.12 - 0.5 * abs(t - 0.35) * 1.6
        vline(img, x + i, y0, y1, shade(col, max(0.55, min(1.15, k))) if k < 1 else lighten(col, k - 1))
    rect(img, x - 1, y0 - 2, x + w, y0, lighten(col, 0.1))
    rect(img, x - 1, y1, x + w, y1 + 2, shade(col, 0.85))


def steps(b, x0, x1, y, n=3):
    for i in range(n):
        c = shade((214, 206, 190), 1 - 0.07 * i)
        rect(b.img, x0 - i * 3, y + i * 3, x1 + i * 3, y + i * 3 + 2, c)
        hline(b.img, x0 - i * 3, x1 + i * 3, y + i * 3, lighten(c, 0.2))


# ------------------------------------------------------------------ building styles
def build(bid, spec):
    set_reflect_offset(sum(ord(ch) for ch in bid))
    style = spec["style"]
    W = spec["w"]
    D = spec.get("depth", 22)
    floors = spec.get("floors", 3)
    fh = spec.get("fh", 34)
    gh = spec.get("gh", 58)
    total = gh + floors * fh + 6
    b = B(W, D, total, spec.get("roof_extra", 18))
    rnd = b.rnd
    img = b.img
    base = b.base
    top = b.top
    mat = spec.get("mat", "concrete")
    mc = MATS.get(mat, (180, 180, 180))
    meta = {"size": [img.width, img.height], "front_w": W, "depth": D}
    # --- side and roof first
    upper_top = top
    setback = spec.get("setback", 0)
    b.side(top, mc if style != "glass" else (70, 110, 160), windows=(fh, top + 6, floors) if style not in ("civic",) else None,
           lit_p=spec.get("lit", 0.5), glass=style == "glass")
    b.roof(top, (182, 186, 192) if style != "glass" else (150, 164, 184), spec.get("roof", "ac"))
    # --- front facade body
    if style == "glass":
        # curtain wall with interiors, slabs, fins
        rect(img, 0, top, W - 1, base - gh, (52, 62, 82))
        pane_w = spec.get("pane", 12)
        for f in range(floors):
            fy = top + 4 + f * fh
            b.slab(fy - 4, (200, 206, 214), 2)
            x = 2
            while x + pane_w <= W - 2:
                window_unit(img, b.lt, x, fy, pane_w, fh - 6, (40, 50, 70), rnd, "office", spec.get("lit", 0.6),
                            sill=False, reveal=False, mullion=False, tint=spec.get("tint", (58, 122, 204)), day_dim=0.5, alpha=0.62)
                x += pane_w + 1
            if spec.get("fins"):
                for fx in range(2, W - 2, pane_w * 2 + 2):
                    vline(img, fx - 1, fy - 1, fy + fh - 6, (210, 216, 224))
        b.slab(base - gh - 4, (210, 214, 220), 3)
    elif style in ("stone", "civic"):
        cladding(img, 0, top, W - 1, base - gh, mat, rnd)
        ww = spec.get("ww", 14)
        wh = spec.get("wh", fh - 10)
        gap = spec.get("gap", 12)
        n = max(1, (W - 12 + gap) // (ww + gap))
        x0 = (W - (n * ww + (n - 1) * gap)) // 2
        for f in range(floors):
            fy = top + 6 + f * fh
            for i in range(n):
                window_unit(img, b.lt, x0 + i * (ww + gap), fy, ww, wh, (60, 64, 76), rnd, spec.get("kind", "office"), spec.get("lit", 0.45))
            if f < floors - 1:
                hline(img, 0, W - 1, fy + fh - 3, shade(mc, 0.82))
        # cornice
        rect(img, 0, top, W - 1, top + 3, lighten(mc, 0.12))
        hline(img, 0, W - 1, top + 4, shade(mc, 0.7))
    elif style in ("brick", "residential", "plaster"):
        cladding(img, 0, top, W - 1, base - gh, mat, rnd)
        ww = spec.get("ww", 16)
        wh = spec.get("wh", fh - 12)
        gap = spec.get("gap", 10)
        n = max(1, (W - 10 + gap) // (ww + gap))
        x0 = (W - (n * ww + (n - 1) * gap)) // 2
        for f in range(floors):
            fy = top + 7 + f * fh
            for i in range(n):
                wx = x0 + i * (ww + gap)
                frame = (236, 236, 232) if style == "brick" else (70, 74, 86)
                window_unit(img, b.lt, wx, fy, ww, wh, frame, rnd, spec.get("kind", "home"), spec.get("lit", 0.5))
                if style == "brick":
                    rect(img, wx - 1, fy - 3, wx + ww, fy - 1, (214, 206, 190))  # lintel
                if spec.get("balcony"):
                    by = fy + wh + 2
                    rect(img, wx - 4, by, wx + ww + 3, by + 2, (214, 214, 216))
                    for xx in range(wx - 4, wx + ww + 4):
                        for yy in range(by - 7, by):
                            blend_px(img, xx, yy, (190, 220, 240), 0.45)
                    hline(img, wx - 4, wx + ww + 3, by - 7, (230, 236, 240))
                    if rnd.random() < 0.45:
                        b.bush(wx - 3, by - 1, 7)
                    for xx in range(wx - 4, wx + ww + 4):
                        blend_px(img, xx, by + 3, (0, 0, 0), 0.25)
                elif spec.get("flowerbox") and rnd.random() < 0.5:
                    rect(img, wx, fy + wh + 2, wx + ww - 1, fy + wh + 4, (120, 80, 60))
                    for xx in range(wx, wx + ww, 2):
                        put(img, xx, fy + wh + 1, rnd.choice([(230, 110, 120), (250, 220, 120), PAL["leaf_400"]]))
            if spec.get("ac_units") and rnd.random() < 0.5:
                b.box3(x0 + rnd.randint(0, n - 1) * (ww + gap) + ww - 4, fy + wh + 1, 6, 5, 3, (200, 204, 210))
        rect(img, 0, top, W - 1, top + 2, lighten(mc, 0.15))
        hline(img, 0, W - 1, top + 3, shade(mc, 0.7))
    elif style == "loft":
        cladding(img, 0, top, W - 1, base - gh, mat, rnd)
        for f in range(floors):
            fy = top + 6 + f * fh
            b.slab(fy - 3, (60, 64, 76), 1)
            x = 6
            while x + 30 <= W - 4:
                window_unit(img, b.lt, x, fy, 30, fh - 9, (40, 44, 56), rnd, "office", spec.get("lit", 0.6), mullion=True)
                x += 36
    # --- ground floor
    gy = base - gh
    gk = spec.get("ground", "lobby")
    dw = spec.get("dw", 22)
    dh = spec.get("dh", 30)
    dx = spec.get("dx", (W - dw) // 2)
    dy = base - dh
    sign = None
    if gk in ("shop", "cafe"):
        gmat = spec.get("gmat", mat)
        cladding(img, 0, gy, W - 1, base - 1, gmat, rnd)
        sgn_col = spec.get("sign_col", (34, 44, 62))
        sign_band(b, 4, W - 5, gy + 4, 12, sgn_col)
        sign = [6, gy + 5, W - 12, 10]
        if spec.get("logo"):
            logo(b, spec["logo"], W - 20, gy + 5, 9, spec.get("logo_col", (240, 240, 230)))
            sign = [6, gy + 5, W - 28, 10]
        aw_y = gy + 18
        if spec.get("awning"):
            awning(b, 4, W - 5, aw_y, spec["awning"], spec.get("stripes", True))
            aw_y += 9
        display_window(b, 6, W - 7, aw_y + 1, base - 3, "cafe" if gk == "cafe" else "shop")
        glass_door(b, dx, dy, dw, dh)
        # plinth
        rect(img, 0, base - 2, W - 1, base - 1, shade(MATS.get(gmat, (150, 150, 150)), 0.7))
    elif gk == "lobby":
        gmat = spec.get("gmat", "dark_panel")
        cladding(img, 0, gy, W - 1, base - 1, gmat, rnd)
        # double-height lobby glass across most of the width
        lx0, lx1 = 8, W - 9
        rect(img, lx0, gy + 12, lx1, base - 1, (38, 42, 54))
        x = lx0 + 1
        while x < lx1:
            xe = min(lx1 - 1, x + 12)
            pane_interior(img, b.lt, x, gy + 13, xe, base - 2, rnd, "lobby", True, 1.05)
            glass_over(img, x, gy + 13, xe, base - 2, (110, 160, 210), 0.22, rnd)
            x = xe + 2
        canopy(b, dx - 14, dx + dw + 13, dy - 8, 8)
        glass_door(b, dx, dy, dw, dh)
        sign = [dx - 12, gy + 2, dw + 24, 9]
        sign_band(b, sign[0], sign[0] + sign[2] - 1, sign[1] - 1, 11, spec.get("sign_col", (30, 36, 50)))
        if spec.get("planters", True):
            planter_box(b, 4, base - 1, 18)
            planter_box(b, W - 22, base - 1, 18)
        wall_lamp(b, dx - 6, dy + 6)
        wall_lamp(b, dx + dw + 4, dy + 6)
    elif gk == "residential":
        gmat = spec.get("gmat", mat)
        cladding(img, 0, gy, W - 1, base - 1, gmat, rnd)
        for sx in (8, W - 30):
            window_unit(img, b.lt, sx, gy + 12, 22, gh - 22, (70, 74, 86), rnd, "home", 0.6)
        rect(img, dx - 3, dy - 5, dx + dw + 2, dy - 2, (60, 66, 82))
        hline(img, dx - 3, dx + dw + 2, dy - 5, (110, 116, 130))
        rect(img, dx, dy, dx + dw - 1, base - 1, (110, 76, 52))
        rect(img, dx + 2, dy + 2, dx + dw - 3, dy + dh // 2, (150, 190, 220))
        put(img, dx + dw - 4, dy + dh // 2 + 3, (230, 200, 120))
        wall_lamp(b, dx - 5, dy + 2)
        sign = [dx - 12, dy - 14, dw + 24, 8]
    elif gk == "civic":
        cladding(img, 0, gy, W - 1, base - 1, mat, rnd)
        rect(img, 4, gy + 1, W - 5, gy + 9, lighten(mc, 0.08))
        hline(img, 4, W - 5, gy + 9, shade(mc, 0.7))
        cw = 8
        xs = list(range(12, W - 16, 24))
        for x in xs:
            rect(img, x + cw, gy + 14, x + 23, base - 10, (40, 46, 60))
            pane_interior(img, b.lt, x + cw + 1, gy + 15, x + 22, base - 11, rnd, "civic", True, 0.9)
            glass_over(img, x + cw + 1, gy + 15, x + 22, base - 11, (90, 130, 170), 0.3, rnd)
        for x in xs:
            column(b, x, gy + 12, base - 10, cw, (236, 230, 214))
        steps(b, 6, W - 7, base - 8, 3)
        glass_door(b, dx, dy - 8, dw, dh)
        meta_door_shift = 8
        # Board-G style name plate: navy panel with a gold rule (text is drawn in-game)
        sx0, sx1 = max(4, dx - 34), min(W - 5, dx + dw + 34)
        rect(img, sx0, gy, sx1, gy + 11, (30, 44, 82))
        hline(img, sx0, sx1, gy, (206, 170, 92))
        hline(img, sx0, sx1, gy + 11, (206, 170, 92))
        hline(img, sx0 + 1, sx1 - 1, gy + 1, (46, 64, 112))
        sign = [sx0, gy + 1, sx1 - sx0, 10]
        dy = dy - 8
    # entrance shadow, ground contact
    b.ground_shadow()
    # brand pieces
    for br in spec.get("brands", []):
        if br[0] == "banner":
            banner(b, br[1], br[2], br[3], br[4], br[5])
        elif br[0] == "logo":
            logo(b, br[1], br[2], br[3], br[4], br[5], br[6] if len(br) > 6 else None)
        elif br[0] == "pylon":
            x, y, h, col = br[1], br[2], br[3], br[4]
            rect(img, x, y, x + 20, y + h, col)
            hline(img, x, x + 20, y, lighten(col, 0.3))
            vline(img, x + 20, y, y + h, shade(col, 0.6))
            logo(b, br[5], x + 4, y + 8, 12, br[6] if len(br) > 6 else (255, 255, 255))
    meta["door"] = [dx, dy, dw, dh]
    meta["sign"] = sign
    meta["sign_text"] = spec.get("sign_text", "")
    return img, b.lt, meta


SPECS = {
    "riverside_tower": dict(style="residential", w=176, depth=26, floors=6, fh=32, gh=58, mat="cream", balcony=True,
                            ww=20, wh=18, gap=12, ground="lobby", gmat="limestone", roof="green", lit=0.55, kind="home",
                            sign_text="RIVERSIDE TOWER", sign_col=(40, 54, 80)),
    "bloom_block": dict(style="brick", w=160, depth=22, floors=2, fh=36, gh=62, mat="brick", ground="cafe", awning=(62, 120, 78),
                        sign_col=(38, 66, 50), roof="green", flowerbox=True, logo="leaf", logo_col=(210, 240, 200), sign_text="BLOOM COFFEE"),
    "postpoint": dict(style="plaster", w=112, depth=18, floors=1, fh=34, gh=60, mat="white", ground="shop", awning=(46, 98, 176),
                      stripes=False, sign_col=(206, 92, 70), roof="ac", ww=16, sign_text="POSTPOINT", kind="office"),
    "riverside_walkup": dict(style="brick", w=128, depth=18, floors=3, fh=34, gh=50, mat="red_brick", ground="residential",
                             dw=18, dh=28, roof="ac", flowerbox=True, ac_units=True),
    "riverside_shops": dict(style="plaster", w=144, depth=20, floors=2, fh=34, gh=58, mat="sand", ground="shop", awning=(190, 120, 60),
                            roof="green", sign_text="FRESH+ MARKET", sign_col=(56, 110, 68), ac_units=True),
    "nexus_cowork": dict(style="loft", w=192, depth=24, floors=3, fh=38, gh=62, mat="concrete", ground="lobby", gmat="navy_panel",
                         roof="terrace", sign_text="NEXUS CO-WORK", sign_col=(28, 48, 96), lit=0.7,
                         brands=[("logo", "nexus", 168, 30, 14, (240, 244, 255), (30, 50, 100))]),
    "horizon_labs": dict(style="glass", w=176, depth=26, floors=4, fh=36, gh=60, roof="terrace", pane=12, fins=True, lit=0.7,
                         ground="lobby", gmat="dark_panel", sign_text="HORIZON LABS",
                         brands=[("pylon", 148, 40, 60, (240, 243, 247), "horizon", (46, 98, 196))]),
    "suite_building": dict(style="brick", w=144, depth=20, floors=3, fh=36, gh=58, mat="brick", ww=24, wh=24, ground="lobby",
                           gmat="navy_panel", roof="green", lit=0.55, kind="office", sign_text="22 FOUNDERS LANE"),
    "byte_bean": dict(style="plaster", w=128, depth=18, floors=1, fh=34, gh=62, mat="wood", ground="cafe", awning=(52, 52, 62),
                      stripes=False, sign_col=(28, 28, 34), roof="green", sign_text="BEAN & BYTE", kind="home"),
    "nexus_bank": dict(style="stone", w=208, depth=26, floors=3, fh=40, gh=66, mat="limestone", ww=16, wh=28, gap=14,
                       ground="civic", roof="ac", dw=26, dh=32, sign_text="NEXUS BANK", lit=0.4,
                       brands=[("logo", "nexus", 96, 14, 14, (226, 186, 90), (34, 44, 70))]),
    "city_hall": dict(style="civic", w=256, depth=28, floors=2, fh=44, gh=72, mat="limestone", ww=16, wh=30, gap=14,
                      ground="civic", roof="green", dw=30, dh=34, sign_text="AURELIA CITY HALL", lit=0.4,
                      brands=[("logo", "civic", 120, 8, 16, (226, 186, 90))]),
    "glass_tower": dict(style="glass", w=160, depth=28, floors=8, fh=32, gh=58, roof="ac", pane=10, lit=0.5, ground="lobby",
                        gmat="dark_panel", planters=False),
    "office_slab": dict(style="stone", w=176, depth=24, floors=6, fh=32, gh=58, mat="concrete", ww=22, wh=20, gap=8,
                        ground="lobby", roof="solar", lit=0.5, gmat="dark_panel"),
    "apartment_mid": dict(style="residential", w=160, depth=22, floors=5, fh=32, gh=52, mat="sand", balcony=True, ww=18, wh=16,
                          gap=12, ground="residential", roof="green", kind="home"),
    "brick_shops": dict(style="brick", w=144, depth=20, floors=2, fh=34, gh=58, mat="brick", ground="shop", awning=(176, 62, 54),
                        roof="ac", sign_text="KURO RAMEN", sign_col=(40, 28, 28), flowerbox=True, kind="home"),
    "civic_annex": dict(style="stone", w=160, depth=22, floors=3, fh=36, gh=58, mat="cream", ww=14, wh=24, ground="lobby",
                        gmat="limestone", roof="ac", sign_text="TAX OFFICE"),
    "finance_tower": dict(style="glass", w=176, depth=30, floors=9, fh=30, gh=62, roof="ac", pane=11, fins=True, lit=0.55,
                          ground="lobby", gmat="navy_panel", sign_text="ARC CAPITAL",
                          brands=[("banner", 150, 60, 44, (46, 70, 130), "ARC")]),
}


def metro_entrance():
    w, h = 88, 70
    img = new(w, h)
    lt = new(w, h)
    b = type("X", (), {})()
    # glass canopy with steel frame
    poly(img, [(4, 22), (84, 22), (78, 10), (10, 10)], (150, 200, 232, 200))
    ImageDraw.Draw(img).line([(4, 22), (84, 22)], fill=(60, 70, 90, 255), width=2)
    ImageDraw.Draw(img).line([(10, 10), (78, 10)], fill=(90, 100, 120, 255))
    for x in (8, 78):
        rect(img, x, 23, x + 2, 62, (70, 80, 96))
    rect(img, 12, 28, 76, 62, (50, 56, 70))
    for i, y in enumerate(range(32, 62, 4)):
        rect(img, 14 + i, y, 74 - i, y + 1, (140, 146, 158))
        hline(img, 14 + i, 74 - i, y + 2, (90, 96, 110))
    rect(img, 12, 28, 76, 30, (255, 230, 170))
    rect(lt, 12, 28, 76, 34, (255, 230, 170, 150))
    # pillar sign
    rect(img, 36, 0, 51, 14, (46, 98, 196))
    draw_text_centered(img, 44, 5, "M", (255, 255, 255))
    rect(lt, 36, 0, 51, 14, (130, 190, 255, 180))
    for x in range(2, 86):
        put(img, x, 64, (20, 26, 40, 90))
        put(img, x, 65, (20, 26, 40, 50))
    return img, lt, {"size": [w, h], "door": [28, 36, 32, 26], "sign": None, "sign_text": "", "front_w": w, "depth": 0}


def generate(out):
    metas = {}
    for bid, spec in SPECS.items():
        img, lt, meta = build(bid, spec)
        save(img, f"{out}/buildings/{bid}.png")
        save(lt, f"{out}/buildings/{bid}_lights.png")
        metas[bid] = meta
    img, lt, meta = metro_entrance()
    save(img, f"{out}/buildings/metro_entrance.png")
    save(lt, f"{out}/buildings/metro_entrance_lights.png")
    metas["metro_entrance"] = meta
    with open(f"{out}/buildings/buildings_meta.json", "w") as fh:
        json.dump(metas, fh, indent=1)
