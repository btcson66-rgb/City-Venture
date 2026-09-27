"""Small pixel-art toolkit used by the CITY VENTURE placeholder generator.

Everything is deterministic: the same code always produces the same PNGs.
Shapes are built as 1-bit masks and then rendered with an automatic
outline + top-left light ramp, which keeps every asset on the same
lighting model (Neo-Civic Pixel Realism: clean outlines, soft 3-tone ramps).
"""
from __future__ import annotations

import os
import random
from PIL import Image, ImageDraw

# ---------------------------------------------------------------- palette
PAL = {
    # UI / night navy family
    "ink": (8, 14, 26),
    "navy_900": (13, 27, 43),
    "navy_800": (18, 31, 49),
    "navy_700": (27, 39, 63),
    "navy_600": (38, 56, 88),
    "navy_500": (50, 65, 94),
    "blue_500": (52, 106, 176),
    "blue_400": (77, 138, 214),
    "blue_300": (132, 180, 232),
    "sky_200": (178, 214, 242),
    "sky_100": (214, 234, 250),
    "white": (252, 254, 255),
    "offwhite": (236, 232, 226),
    "gray_300": (168, 173, 199),
    "gray_400": (132, 142, 166),
    "gray_500": (99, 103, 122),
    "gray_600": (74, 80, 97),
    # accents
    "green_500": (96, 178, 110),
    "green_cash": (111, 207, 128),
    "red_500": (224, 104, 83),
    "gold_500": (226, 180, 82),
    "purple_500": (150, 110, 196),
    # environment
    "leaf_300": (157, 181, 107),
    "leaf_400": (129, 157, 70),
    "leaf_500": (93, 113, 61),
    "leaf_600": (62, 92, 87),
    "leaf_700": (40, 64, 58),
    "grass_300": (132, 170, 92),
    "grass_400": (110, 150, 78),
    "grass_500": (88, 126, 66),
    "asphalt_400": (78, 84, 96),
    "asphalt_500": (64, 69, 80),
    "asphalt_600": (52, 56, 66),
    "pave_200": (206, 200, 190),
    "pave_300": (186, 180, 170),
    "pave_400": (160, 154, 146),
    "stone_200": (222, 214, 198),
    "stone_300": (200, 190, 172),
    "stone_400": (170, 160, 144),
    "brick_400": (170, 92, 70),
    "brick_500": (140, 72, 58),
    "wood_300": (196, 142, 94),
    "wood_400": (160, 108, 68),
    "wood_500": (122, 80, 52),
    "wood_600": (92, 60, 40),
    "water_300": (96, 160, 214),
    "water_400": (66, 128, 190),
    "water_500": (46, 98, 158),
    "glass_300": (150, 196, 228),
    "glass_400": (104, 158, 206),
    "glass_500": (70, 116, 170),
    "glass_600": (48, 80, 124),
    "concrete_300": (196, 198, 200),
    "concrete_400": (168, 170, 174),
    "concrete_500": (136, 140, 146),
    "metal_400": (120, 136, 156),
    "metal_500": (88, 104, 126),
    "amber": (255, 196, 110),
    "amber_soft": (255, 222, 160),
    "coral": (224, 104, 83),
    "taupe": (148, 129, 124),
    "teal_500": (52, 76, 86),
}


def hexc(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


def lighten(c, k):
    return tuple(max(0, min(255, int(v + (255 - v) * k))) for v in c[:3])


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def ramp(base, out_k=0.42, sh_k=0.78, hi_k=0.22):
    """(outline, shadow, base, highlight) for a coloured material."""
    base = tuple(base[:3])
    return (shade(base, out_k), shade(base, sh_k), base, lighten(base, hi_k))


# grayscale ramps for tinted layers (modulated in-engine)
GRAY_SKIN = ((92, 92, 92), (206, 206, 206), (238, 238, 238), (252, 252, 252))
GRAY_HAIR = ((70, 70, 70), (168, 168, 168), (214, 214, 214), (246, 246, 246))
GRAY_CLOTH = ((80, 80, 80), (184, 184, 184), (226, 226, 226), (250, 250, 250))


# ---------------------------------------------------------------- masks
class Mask:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("1", (w, h), 0)
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, v=1):
        """inclusive rect"""
        if x1 < x0 or y1 < y0:
            return self
        self.d.rectangle([x0, y0, x1, y1], fill=v)
        return self

    def ellipse(self, x0, y0, x1, y1, v=1):
        self.d.ellipse([x0, y0, x1, y1], fill=v)
        return self

    def poly(self, pts, v=1):
        self.d.polygon(pts, fill=v)
        return self

    def line(self, pts, v=1, width=1):
        self.d.line(pts, fill=v, width=width)
        return self

    def px(self, x, y, v=1):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((x, y), v)
        return self

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.im.getpixel((x, y)) != 0
        return False

    def union(self, other):
        for y in range(self.h):
            for x in range(self.w):
                if other.get(x, y):
                    self.px(x, y, 1)
        return self

    def subtract(self, other):
        for y in range(self.h):
            for x in range(self.w):
                if other.get(x, y):
                    self.px(x, y, 0)
        return self

    def intersect(self, other):
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y) and not other.get(x, y):
                    self.px(x, y, 0)
        return self

    def copy(self):
        m = Mask(self.w, self.h)
        m.im = self.im.copy()
        m.d = ImageDraw.Draw(m.im)
        return m

    def shifted(self, dx, dy):
        m = Mask(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x - dx, y - dy):
                    m.px(x, y, 1)
        return m

    def mirrored(self):
        m = Mask(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                if self.get(self.w - 1 - x, y):
                    m.px(x, y, 1)
        return m

    def pixels(self):
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y):
                    yield x, y

    def bbox(self):
        return self.im.getbbox()


def fill(img, mask, col, ox=0, oy=0):
    col = tuple(col) + ((255,) if len(col) == 3 else ())
    for x, y in mask.pixels():
        put(img, x + ox, y + oy, col)


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        if len(col) == 3:
            col = tuple(col) + (255,)
        img.putpixel((x, y), col)


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))
    return (0, 0, 0, 0)


def shaded(img, mask, rp, ox=0, oy=0, outline=True, hi=True, sh=True, sh_depth=1, outline_mask=None):
    """Render mask with outline + top-left light.

    rp = (outline, shadow, base, highlight)
    outline_mask: optional mask; boundary pixels touching it are NOT outlined
    (used to merge parts seamlessly).
    """
    o, s, b, h = rp
    for x, y in mask.pixels():
        edge = False
        if outline:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if not mask.get(x + dx, y + dy):
                    if outline_mask is not None and outline_mask.get(x + dx, y + dy):
                        continue
                    edge = True
                    break
        if edge:
            c = o
        else:
            c = b
            if sh:
                for k in range(1, sh_depth + 1):
                    if not mask.get(x + k, y + k) or not mask.get(x + k, y) and not mask.get(x, y + k):
                        c = s
                        break
                if c == b and not mask.get(x, y + 2) and mask.get(x, y + 1):
                    c = s
            if hi and c == b:
                if not mask.get(x - 1, y - 1) or not mask.get(x, y - 2):
                    c = h
        put(img, x + ox, y + oy, c)


def outline_only(img, mask, col, ox=0, oy=0):
    for x, y in mask.pixels():
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if not mask.get(x + dx, y + dy):
                put(img, x + ox, y + oy, col)
                break


def new(w, h, bg=None):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0) if bg is None else tuple(bg) + (255,))


def rect(img, x0, y0, x1, y1, col):
    """inclusive filled rect"""
    if len(col) == 3:
        col = tuple(col) + (255,)
    for y in range(max(0, y0), min(img.height, y1 + 1)):
        for x in range(max(0, x0), min(img.width, x1 + 1)):
            img.putpixel((x, y), col)


def hline(img, x0, x1, y, col):
    rect(img, x0, y, x1, y, col)


def vline(img, x, y0, y1, col):
    rect(img, x, y0, x, y1, col)


def box(img, x0, y0, x1, y1, fill_col, out_col=None, hi_col=None, sh_col=None):
    rect(img, x0, y0, x1, y1, fill_col)
    if hi_col:
        hline(img, x0 + 1, x1 - 1, y0 + 1, hi_col)
    if sh_col:
        hline(img, x0 + 1, x1 - 1, y1 - 1, sh_col)
    if out_col:
        hline(img, x0, x1, y0, out_col)
        hline(img, x0, x1, y1, out_col)
        vline(img, x0, y0, y1, out_col)
        vline(img, x1, y0, y1, out_col)


def dither(img, x0, y0, x1, y1, col, density=0.5, seed=1, pattern="checker"):
    rnd = random.Random(seed)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if pattern == "checker":
                if (x + y) % 2 == 0 and rnd.random() < density * 2:
                    put(img, x, y, col)
            else:
                if rnd.random() < density:
                    put(img, x, y, col)


def paste(dst, src, x, y):
    dst.alpha_composite(src, (x, y))


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def glow(w, h, col, strength=1.0):
    """soft radial glow (additive in engine). Pixel-stepped falloff."""
    img = new(w, h)
    cx, cy = (w - 1) / 2, (h - 1) / 2
    for y in range(h):
        for x in range(w):
            d = (((x - cx) / (w / 2)) ** 2 + ((y - cy) / (h / 2)) ** 2) ** 0.5
            if d < 1:
                a = (1 - d) ** 1.6
                a = round(a * 4) / 4  # stepped for pixel feel
                put(img, x, y, tuple(col[:3]) + (int(200 * a * strength),))
    return img
