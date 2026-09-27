"""Interior furniture v2 (Concept Board H). 3/4 top-down furniture with a lit top surface, a shaded
front face, crisp outline and small life details (mugs, books, plants, screens)."""
from __future__ import annotations

import random

from PIL import ImageDraw

from pixel import PAL, Mask, new, shaded, fill, put, get, rect, hline, vline, box, save, ramp, shade, lighten, mix
from font3x5 import draw_text, draw_text_centered, text_width

OUT_K = 0.45


def block(im, x0, y0, x1, y1, top_h, col, top_col=None, outline=True):
    """Furniture block: top surface (depth top_h) above a front face."""
    top_col = top_col or lighten(col, 0.18)
    rect(im, x0, y0, x1, y0 + top_h - 1, top_col)
    hline(im, x0 + 1, x1 - 1, y0 + 1, lighten(top_col, 0.15))
    rect(im, x0, y0 + top_h, x1, y1, col)
    hline(im, x0, x1, y0 + top_h, shade(col, 0.8))
    hline(im, x0, x1, y1, shade(col, 0.7))
    if outline:
        o = shade(col, OUT_K)
        hline(im, x0, x1, y0, o)
        hline(im, x0, x1, y1, o)
        vline(im, x0, y0, y1, o)
        vline(im, x1, y0, y1, o)


def mug(im, x, y, col=(240, 240, 240)):
    rect(im, x, y, x + 2, y + 2, col)
    put(im, x + 3, y + 1, col)
    put(im, x + 1, y, (120, 80, 50))


def book_row(im, x0, x1, y, h, rnd):
    x = x0
    while x < x1:
        bw = rnd.randint(1, 3)
        bh = rnd.randint(h - 3, h)
        c = rnd.choice([(200, 80, 70), (70, 110, 170), (230, 200, 120), (90, 140, 100), (226, 222, 214), (60, 60, 70), (150, 110, 180), (224, 140, 80)])
        rect(im, x, y + h - bh, min(x1, x + bw - 1), y + h - 1, c)
        if bw >= 2:
            vline(im, x, y + h - bh, y + h - 1, lighten(c, 0.2))
        x += bw
        if rnd.random() < 0.12:
            x += 2


def small_plant(im, x, y, pot=(230, 226, 216)):
    rect(im, x, y + 3, x + 4, y + 6, pot)
    hline(im, x, x + 4, y + 6, shade(pot, 0.7))
    for (dx, dy, c) in ((1, 0, PAL["leaf_300"]), (2, -1, PAL["leaf_400"]), (3, 0, PAL["leaf_400"]), (0, 1, PAL["leaf_500"]), (4, 1, PAL["leaf_500"]), (2, 1, PAL["leaf_300"]), (2, 2, PAL["leaf_500"])):
        put(im, x + dx, y + dy + 1, c)


# ---------------------------------------------------------------- apartment
def bed():
    im = new(46, 58)
    rnd = random.Random(1)
    wood = (120, 84, 58)
    block(im, 0, 0, 45, 12, 3, wood)                       # headboard
    for x in range(4, 44, 6):
        vline(im, x, 4, 11, shade(wood, 0.85))
    rect(im, 2, 11, 43, 55, (236, 236, 240))               # sheet
    vline(im, 2, 11, 55, (180, 180, 190))
    vline(im, 43, 11, 55, (180, 180, 190))
    for x0 in (5, 25):                                      # pillows
        rect(im, x0, 13, x0 + 15, 20, (250, 250, 252))
        hline(im, x0, x0 + 15, 20, (206, 208, 216))
        hline(im, x0 + 1, x0 + 14, 14, (255, 255, 255))
    duvet = (64, 88, 140)
    rect(im, 2, 24, 43, 55, duvet)
    hline(im, 2, 43, 24, lighten(duvet, 0.35))
    hline(im, 2, 43, 25, lighten(duvet, 0.2))
    for y in range(28, 55, 5):
        for x in range(4 + (y % 2) * 3, 43, 6):
            put(im, x, y, lighten(duvet, 0.18))
    rect(im, 2, 45, 43, 49, (226, 186, 90))                # throw
    hline(im, 2, 43, 45, (246, 210, 120))
    hline(im, 2, 43, 56, shade(duvet, 0.6))
    rect(im, 1, 56, 44, 57, shade(wood, 0.6))
    return im


def desk_laptop():
    im = new(48, 34)
    wood = (170, 120, 80)
    block(im, 0, 8, 47, 20, 6, wood)
    rect(im, 2, 21, 4, 33, shade(wood, 0.65))
    rect(im, 43, 21, 45, 33, shade(wood, 0.65))
    rect(im, 4, 21, 43, 23, shade(wood, 0.75))             # drawer rail
    # laptop
    rect(im, 16, 0, 31, 8, (46, 50, 62))
    rect(im, 17, 1, 30, 7, (70, 150, 220))
    hline(im, 18, 26, 2, (220, 240, 255))
    hline(im, 18, 24, 4, (160, 210, 250))
    rect(im, 15, 9, 32, 10, (180, 186, 196))
    # desk lamp
    vline(im, 40, 1, 9, (60, 60, 66))
    rect(im, 37, 0, 43, 2, (226, 186, 90))
    put(im, 40, 3, (255, 240, 190))
    mug(im, 7, 9, (240, 236, 226))
    small_plant(im, 4, 2)
    rect(im, 34, 10, 38, 11, (240, 240, 244))              # notebook
    return im


def chair_office(col=(46, 52, 66)):
    im = new(18, 26)
    rect(im, 3, 0, 14, 11, col)
    hline(im, 3, 14, 0, lighten(col, 0.3))
    vline(im, 3, 0, 11, lighten(col, 0.15))
    block(im, 2, 11, 15, 16, 3, col)
    vline(im, 8, 17, 21, (110, 114, 124))
    hline(im, 3, 14, 22, (90, 94, 104))
    for x in (3, 8, 14):
        put(im, x, 23, (40, 40, 44))
    return im


def sofa(w=52, col=(92, 110, 150)):
    im = new(w, 30)
    rect(im, 0, 0, w - 1, 12, col)                          # back
    hline(im, 0, w - 1, 0, lighten(col, 0.3))
    hline(im, 1, w - 2, 1, lighten(col, 0.15))
    rect(im, 0, 10, w - 1, 23, shade(col, 0.92))            # seat
    hline(im, 0, w - 1, 12, lighten(col, 0.1))
    for x in range(w // 3, w - 4, w // 3):
        vline(im, x, 12, 22, shade(col, 0.72))
    rect(im, 0, 4, 5, 25, shade(col, 0.82))                 # arms
    rect(im, w - 6, 4, w - 1, 25, shade(col, 0.82))
    hline(im, 0, 5, 4, lighten(col, 0.2))
    hline(im, w - 6, w - 1, 4, lighten(col, 0.2))
    rect(im, 8, 5, 16, 11, (226, 186, 90))                  # cushions
    rect(im, w - 18, 5, w - 10, 11, (236, 232, 222))
    hline(im, 0, w - 1, 23, shade(col, 0.55))
    rect(im, 2, 24, 4, 29, (70, 54, 40))
    rect(im, w - 5, 24, w - 3, 29, (70, 54, 40))
    return im


def coffee_table():
    im = new(34, 20)
    wood = (150, 104, 68)
    block(im, 0, 2, 33, 10, 5, wood)
    rect(im, 2, 11, 3, 18, shade(wood, 0.6))
    rect(im, 30, 11, 31, 18, shade(wood, 0.6))
    rect(im, 5, 1, 12, 4, (200, 80, 70))
    rect(im, 6, 0, 13, 2, (70, 110, 170))
    mug(im, 22, 2)
    return im


def bookshelf(w=34, h=52):
    rnd = random.Random(w * h)
    im = new(w, h)
    wood = (120, 84, 58)
    rect(im, 0, 0, w - 1, h - 1, wood)
    rect(im, 2, 2, w - 3, h - 3, shade(wood, 0.55))
    for y in range(3, h - 6, 12):
        book_row(im, 3, w - 4, y, 10, rnd)
        if rnd.random() < 0.5:
            small_plant(im, w - 9, y + 2)
        rect(im, 1, y + 10, w - 2, y + 11, lighten(wood, 0.12))
    vline(im, 0, 0, h - 1, shade(wood, 0.5))
    vline(im, w - 1, 0, h - 1, shade(wood, 0.5))
    hline(im, 0, w - 1, 0, lighten(wood, 0.2))
    return im


def tv_unit():
    im = new(48, 38)
    rect(im, 4, 0, 43, 21, (22, 24, 30))
    rect(im, 6, 2, 41, 19, (40, 70, 120))
    for y in range(2, 20):
        hline(im, 6, 41, y, mix((70, 120, 190), (30, 50, 90), (y - 2) / 18))
    hline(im, 8, 30, 5, (150, 200, 250))
    rect(im, 22, 21, 25, 23, (30, 32, 40))
    wood = (160, 112, 72)
    block(im, 0, 23, 47, 37, 4, wood)
    for x in (16, 32):
        vline(im, x, 28, 36, shade(wood, 0.7))
    put(im, 8, 31, (230, 200, 120))
    put(im, 40, 31, (230, 200, 120))
    return im


def kitchen(w=66):
    im = new(w, 46)
    rnd = random.Random(4)
    # upper cabinets + backsplash
    rect(im, 0, 0, w - 1, 12, (236, 236, 232))
    for x in range(0, w, 16):
        vline(im, x, 0, 12, (200, 200, 196))
        put(im, x + 12, 8, (150, 150, 156))
    hline(im, 0, w - 1, 12, (180, 180, 176))
    for y in range(13, 20, 3):
        for x in range(0, w, 4):
            rect(im, x + (y % 2) * 2, y, x + 2 + (y % 2) * 2, y + 1, (200, 224, 226))
    rect(im, 0, 13, w - 1, 19, (170, 206, 210))
    for y in range(13, 20, 2):
        for x in range((y % 4), w, 4):
            put(im, x, y, (214, 236, 238))
    # counter
    block(im, 0, 20, w - 1, 45, 4, (220, 212, 198), (240, 236, 228))
    for x in range(12, w, 16):
        vline(im, x, 25, 44, (180, 172, 160))
        put(im, x - 3, 30, (120, 120, 130))
    # sink + stove
    rect(im, 6, 21, 18, 23, (170, 176, 188))
    put(im, 12, 20, (200, 204, 214))
    rect(im, w - 24, 21, w - 8, 23, (50, 52, 60))
    for x in (w - 21, w - 13):
        put(im, x, 22, (200, 80, 60))
    rect(im, 26, 16, 32, 20, (60, 60, 66))   # kettle/appliance
    put(im, 27, 17, (220, 220, 226))
    return im


def fridge():
    im = new(24, 46)
    c = (226, 230, 236)
    rect(im, 0, 0, 23, 45, c)
    hline(im, 0, 23, 0, (246, 248, 250))
    vline(im, 0, 0, 45, (160, 166, 176))
    vline(im, 23, 0, 45, (150, 156, 166))
    hline(im, 1, 22, 16, (170, 176, 186))
    rect(im, 19, 4, 20, 12, (140, 146, 156))
    rect(im, 19, 20, 20, 32, (140, 146, 156))
    rect(im, 5, 5, 8, 8, (240, 200, 90))
    rect(im, 10, 22, 14, 26, (120, 180, 230))
    hline(im, 0, 23, 45, (120, 126, 136))
    return im


def wardrobe():
    im = new(34, 54)
    wood = (186, 136, 92)
    rect(im, 0, 0, 33, 53, wood)
    hline(im, 0, 33, 0, lighten(wood, 0.25))
    rect(im, 2, 3, 15, 50, lighten(wood, 0.06))
    rect(im, 18, 3, 31, 50, lighten(wood, 0.06))
    vline(im, 16, 2, 51, shade(wood, 0.6))
    vline(im, 17, 2, 51, shade(wood, 0.75))
    for x in (13, 20):
        rect(im, x, 24, x, 29, (226, 196, 120))
    vline(im, 0, 0, 53, shade(wood, 0.5))
    vline(im, 33, 0, 53, shade(wood, 0.5))
    hline(im, 0, 33, 53, shade(wood, 0.5))
    return im


def plant(big=False, kind="monstera"):
    w, h = (26, 44) if big else (18, 30)
    im = new(w, h)
    rnd = random.Random(w + (1 if kind == "monstera" else 7))
    pot = (226, 220, 206) if kind == "monstera" else (70, 74, 86)
    rect(im, 4, h - 10, w - 5, h - 1, pot)
    hline(im, 4, w - 5, h - 10, lighten(pot, 0.2))
    vline(im, w - 5, h - 10, h - 1, shade(pot, 0.75))
    hline(im, 4, w - 5, h - 1, shade(pot, 0.6))
    tones = [(44, 88, 56), (70, 124, 66), (104, 160, 80), (150, 196, 104)]
    cx = w // 2
    for i in range(9 if big else 6):
        lx = cx + rnd.randint(-w // 2 + 3, w // 2 - 3)
        ly = rnd.randint(2, h - 14)
        s = rnd.randint(3, 5) if big else rnd.randint(2, 4)
        d = ImageDraw.Draw(im)
        d.line([(cx, h - 10), (lx, ly + s)], fill=(60, 100, 60, 255))
        m = Mask(w, h).ellipse(lx - s, ly - s // 2, lx + s, ly + s)
        for px, py in m.pixels():
            put(im, px, py, tones[3] if (px - lx) + (py - ly) < -s // 2 else tones[2] if px < lx else tones[1])
        put(im, lx, ly + s, tones[0])
    return im


def rug(w=64, h=40, col=(168, 120, 96), accent=(226, 196, 150)):
    im = new(w, h)
    rect(im, 0, 0, w - 1, h - 1, col)
    rect(im, 3, 3, w - 4, h - 4, shade(col, 0.9))
    rect(im, 5, 5, w - 6, h - 6, col)
    for x in range(8, w - 8, 6):
        for y in range(8, h - 8, 6):
            put(im, x, y, accent)
            put(im, x + 1, y + 1, shade(accent, 0.8))
    for x in range(0, w, 2):
        put(im, x, 0, lighten(col, 0.3))
        put(im, x, h - 1, lighten(col, 0.3))
    return im


def boxes():
    im = new(16, 14)
    c = (200, 158, 108)
    rect(im, 0, 0, 15, 13, c)
    hline(im, 0, 15, 0, lighten(c, 0.25))
    rect(im, 0, 1, 15, 4, lighten(c, 0.1))
    vline(im, 7, 0, 5, (236, 226, 196))
    vline(im, 8, 0, 5, (236, 226, 196))
    rect(im, 10, 7, 14, 10, (250, 250, 250))
    hline(im, 11, 13, 8, (120, 120, 130))
    vline(im, 0, 0, 13, shade(c, 0.6))
    vline(im, 15, 0, 13, shade(c, 0.6))
    hline(im, 0, 15, 13, shade(c, 0.55))
    return im


def packing_table():
    im = new(48, 34)
    steel = (150, 156, 168)
    block(im, 0, 8, 47, 18, 6, steel, (196, 202, 212))
    rect(im, 2, 19, 3, 33, shade(steel, 0.6))
    rect(im, 44, 19, 45, 33, shade(steel, 0.6))
    rect(im, 3, 26, 44, 27, shade(steel, 0.7))
    rect(im, 6, 0, 19, 9, (200, 158, 108))          # open box
    hline(im, 6, 19, 0, (226, 190, 140))
    rect(im, 8, 2, 17, 5, (170, 130, 86))
    rect(im, 24, 5, 33, 9, (236, 236, 240))          # label printer
    rect(im, 25, 3, 32, 5, (60, 64, 76))
    put(im, 31, 4, (120, 230, 140))
    rect(im, 36, 4, 42, 9, (130, 90, 70))            # tape roll
    put(im, 39, 6, (60, 40, 30))
    rect(im, 8, 28, 20, 32, (200, 158, 108))         # boxes below
    rect(im, 24, 29, 34, 32, (190, 148, 98))
    return im


# ---------------------------------------------------------------- cafe
def cafe_counter():
    im = new(100, 44)
    wood = (120, 84, 58)
    block(im, 0, 10, 99, 43, 5, wood, (236, 232, 222))
    for x in range(4, 99, 6):
        vline(im, x, 16, 42, shade(wood, 0.85))
    hline(im, 0, 99, 16, shade(wood, 0.6))
    # espresso machine (chrome)
    rect(im, 8, 0, 30, 10, (186, 192, 204))
    hline(im, 8, 30, 0, (236, 240, 248))
    vline(im, 30, 0, 10, (120, 126, 140))
    rect(im, 11, 3, 13, 7, (40, 40, 46))
    rect(im, 23, 3, 25, 7, (40, 40, 46))
    rect(im, 16, 2, 20, 4, (226, 186, 90))
    put(im, 12, 9, (250, 250, 250))
    put(im, 24, 9, (250, 250, 250))
    # grinder
    rect(im, 34, 1, 40, 10, (40, 40, 46))
    rect(im, 35, 0, 39, 3, (90, 60, 40))
    # cups stack + register
    for i in range(3):
        rect(im, 46 + i * 5, 6, 49 + i * 5, 10, (250, 250, 250))
        hline(im, 46 + i * 5, 49 + i * 5, 6, (72, 128, 84))
    rect(im, 66, 3, 78, 10, (50, 54, 66))
    rect(im, 67, 4, 77, 7, (90, 180, 230))
    # pastries
    rect(im, 82, 5, 96, 10, (230, 236, 240))
    for x in (84, 88, 92):
        rect(im, x, 7, x + 2, 9, (210, 150, 90))
    return im


def menu_board():
    # 3x5 glyphs need a 1px gap between rows (6px pitch) or the lines fuse into noise.
    im = new(66, 34)
    rect(im, 0, 0, 65, 33, (96, 70, 50))
    rect(im, 2, 2, 63, 31, (38, 44, 42))
    draw_text(im, 5, 4, "MENU", (244, 226, 170))
    hline(im, 5, 60, 10, (70, 80, 76))
    items = [("FLAT WHITE", "4.5"), ("LATTE", "4.8"), ("COLD BREW", "5.0")]
    for i, (a, b) in enumerate(items):
        draw_text(im, 5, 13 + i * 6, a, (230, 230, 222))
        draw_text(im, 61 - text_width(b), 13 + i * 6, b, (244, 200, 120))
    return im


def display_case():
    im = new(42, 32)
    wood = (120, 84, 58)
    block(im, 0, 12, 41, 31, 3, wood)
    for x in range(1, 41):
        for y in range(0, 12):
            put(im, x, y, (206, 230, 244, 140))
    hline(im, 1, 40, 0, (240, 248, 255))
    hline(im, 1, 40, 6, (180, 200, 214))
    rnd = random.Random(3)
    for x in range(4, 38, 7):
        c = rnd.choice([(214, 150, 90), (230, 200, 140), (170, 100, 70), (240, 180, 190)])
        rect(im, x, 8, x + 4, 11, c)
        rect(im, x + 1, 2, x + 4, 5, rnd.choice([(214, 150, 90), (250, 230, 200)]))
    return im


def cafe_table():
    im = new(26, 24)
    m = Mask(26, 24).ellipse(0, 0, 25, 11)
    shaded(im, m, ramp((236, 230, 220)), 0, 0)
    rect(im, 12, 11, 13, 20, (54, 56, 64))
    hline(im, 8, 17, 21, (54, 56, 64))
    mug(im, 7, 3)
    rect(im, 15, 3, 19, 5, (230, 200, 150))
    return im


def cafe_chair():
    im = new(14, 22)
    wood = (140, 94, 60)
    rect(im, 2, 0, 11, 2, wood)
    for x in (2, 11):
        vline(im, x, 0, 12, wood)
    for x in (4, 7, 9):
        vline(im, x, 1, 10, shade(wood, 0.8))
    block(im, 1, 11, 12, 14, 2, wood)
    for x in (2, 11):
        vline(im, x, 15, 21, shade(wood, 0.6))
    return im


def pendant():
    im = new(14, 30)
    vline(im, 7, 0, 18, (40, 40, 44))
    m = Mask(14, 30).poly([(2, 26), (12, 26), (10, 18), (4, 18)])
    fill(im, m, (46, 50, 58))
    hline(im, 4, 10, 18, (90, 96, 108))
    hline(im, 3, 11, 27, (255, 232, 170))
    return im


# ---------------------------------------------------------------- office / cowork
def monitor_desk():
    im = new(66, 36)
    top = (236, 236, 238)
    block(im, 0, 10, 65, 16, 5, (200, 200, 204), top)
    for x in (2, 32, 62):
        rect(im, x, 17, x + 1, 35, (120, 126, 136))
    rnd = random.Random(8)
    for x in (6, 36):
        rect(im, x, 0, x + 19, 10, (32, 36, 46))
        rect(im, x + 1, 1, x + 18, 8, (50, 90, 150))
        for y in range(2, 8, 2):
            hline(im, x + 2, x + 2 + rnd.randint(6, 14), y, rnd.choice([(150, 210, 250), (240, 200, 120), (120, 220, 160)]))
        rect(im, x + 9, 10, x + 10, 11, (32, 36, 46))
        rect(im, x + 4, 12, x + 15, 13, (60, 64, 76))    # keyboard
    mug(im, 28, 11)
    small_plant(im, 58, 4)
    return im


def glass_room():
    w, h = 68, 52
    im = new(w, h)
    for x in range(1, w - 1):
        for y in range(1, h - 1):
            put(im, x, y, (190, 220, 238, 90))
    rect(im, 0, 0, w - 1, 1, (70, 80, 96))
    rect(im, 0, h - 2, w - 1, h - 1, (70, 80, 96))
    for x in range(0, w, 17):
        vline(im, x, 0, h - 1, (70, 80, 96))
    # meeting table + chairs inside
    block(im, 16, 20, 51, 30, 5, (120, 84, 58), (170, 124, 84))
    for x in (18, 30, 42):
        rect(im, x, 15, x + 5, 19, (46, 52, 66))
        rect(im, x, 31, x + 5, 35, (46, 52, 66))
    rect(im, 4, 6, 14, 14, (240, 240, 244))   # wall screen
    rect(im, 5, 7, 13, 12, (60, 130, 200))
    for i in range(12):
        put(im, 50 + i // 2, 44 - i, (240, 250, 255, 200))
    return im


def printer():
    im = new(26, 28)
    block(im, 0, 8, 25, 27, 4, (206, 208, 214), (232, 234, 238))
    rect(im, 3, 3, 22, 8, (190, 194, 202))
    rect(im, 6, 0, 19, 4, (252, 252, 252))
    put(im, 20, 13, (120, 220, 140))
    hline(im, 4, 20, 20, (150, 156, 166))
    return im


def lockers():
    im = new(38, 46)
    for i in range(3):
        c = [(110, 140, 176), (90, 120, 160), (120, 150, 186)][i]
        x = i * 12
        rect(im, x, 0, x + 11, 45, c)
        hline(im, x, x + 11, 0, lighten(c, 0.3))
        vline(im, x + 11, 0, 45, shade(c, 0.6))
        for y in (6, 8, 10):
            hline(im, x + 3, x + 8, y, shade(c, 0.7))
        put(im, x + 9, 24, (236, 236, 240))
    return im


def cork_board():
    im = new(58, 38)
    rect(im, 0, 0, 57, 37, (110, 78, 54))
    rect(im, 2, 2, 55, 35, (200, 164, 114))
    rnd = random.Random(2)
    for x in range(3, 55):
        for y in range(3, 35):
            if rnd.random() < 0.08:
                put(im, x, y, (186, 150, 102))
    notes = [(5, 5, (252, 250, 236)), (18, 7, (250, 230, 140)), (31, 5, (180, 220, 250)), (43, 8, (250, 200, 200)),
             (7, 20, (200, 240, 200)), (21, 21, (252, 250, 236)), (34, 20, (250, 230, 140)), (45, 22, (180, 220, 250))]
    for (x, y, c) in notes:
        rect(im, x, y, x + 9, y + 10, c)
        hline(im, x, x + 9, y + 10, shade(c, 0.8))
        hline(im, x + 1, x + 8, y + 3, (120, 120, 130))
        hline(im, x + 1, x + 6, y + 5, (120, 120, 130))
        put(im, x + 4, y, rnd.choice([(220, 60, 60), (60, 120, 220), (60, 170, 90)]))
    return im


def whiteboard():
    im = new(66, 42)
    rect(im, 0, 0, 65, 35, (150, 156, 166))
    rect(im, 2, 2, 63, 33, (248, 250, 252))
    draw_text(im, 5, 5, "IDEAS", (46, 98, 176))
    draw_text(im, 5, 12, "PEOPLE", (46, 98, 176))
    draw_text(im, 5, 19, "PRODUCT", (46, 98, 176))
    draw_text(im, 5, 26, "GROWTH", (46, 98, 176))
    d = ImageDraw.Draw(im)
    d.line([(38, 28), (44, 22), (49, 25), (58, 12)], fill=(224, 104, 83, 255))
    put(im, 57, 12, (224, 104, 83))
    put(im, 58, 13, (224, 104, 83))
    rect(im, 40, 30, 58, 31, (160, 164, 176))
    for x in (43, 48, 53):
        rect(im, x, 29, x + 3, 30, [(220, 60, 60), (60, 120, 220), (40, 40, 40)][(x - 43) // 5])
    rect(im, 6, 36, 7, 41, (120, 126, 136))
    rect(im, 58, 36, 59, 41, (120, 126, 136))
    return im


def exec_desk():
    im = new(66, 38)
    wood = (96, 64, 44)
    block(im, 0, 12, 65, 37, 6, wood, (136, 96, 66))
    for x in range(8, 60, 18):
        rect(im, x, 22, x + 12, 34, lighten(wood, 0.06))
        put(im, x + 6, 27, (226, 196, 120))
    rect(im, 22, 0, 41, 12, (28, 32, 42))
    rect(im, 23, 1, 40, 9, (60, 120, 190))
    hline(im, 24, 34, 3, (180, 220, 250))
    hline(im, 24, 30, 5, (240, 200, 120))
    rect(im, 30, 12, 33, 13, (28, 32, 42))
    rect(im, 46, 10, 54, 13, (236, 236, 240))
    mug(im, 12, 10)
    small_plant(im, 57, 4)
    return im


# ---------------------------------------------------------------- bank / civic / parcel
def counter_marble(w=144, col=(46, 58, 90), sign=None):
    im = new(w, 44)
    block(im, 0, 10, w - 1, 43, 5, col, (234, 230, 222))
    for x in range(0, w, 12):
        vline(im, x, 16, 42, shade(col, 0.85))
    hline(im, 0, w - 1, 16, shade(col, 0.55))
    for x in range(6, w - 20, 36):
        for xx in range(x, x + 24):
            for y in range(0, 10):
                put(im, xx, y, (210, 232, 244, 120))
        hline(im, x, x + 23, 0, (130, 140, 160))
        rect(im, x + 8, 7, x + 15, 9, (60, 64, 76))    # card terminal/keyboard
    if sign:
        tw = text_width(sign)
        rect(im, w // 2 - tw // 2 - 4, 22, w // 2 + tw // 2 + 4, 30, (226, 186, 90))
        draw_text_centered(im, w // 2 + 1, 24, sign, (40, 40, 50))
    return im


def atm():
    im = new(24, 42)
    rect(im, 0, 0, 23, 41, (60, 74, 104))
    hline(im, 0, 23, 0, (110, 130, 170))
    vline(im, 23, 0, 41, (40, 50, 72))
    rect(im, 3, 4, 20, 15, (90, 170, 230))
    draw_text_centered(im, 12, 7, "ATM", (255, 255, 255))
    rect(im, 5, 18, 18, 25, (36, 40, 52))
    for y in (19, 21, 23):
        for x in (6, 9, 12, 15):
            put(im, x, y, (200, 204, 212))
    rect(im, 6, 29, 17, 30, (24, 24, 30))
    put(im, 18, 29, (120, 230, 140))
    return im


def stanchions():
    im = new(52, 24)
    for x in (2, 48):
        rect(im, x, 4, x + 1, 20, (214, 196, 140))
        rect(im, x - 1, 20, x + 2, 22, (170, 150, 100))
        put(im, x, 3, (240, 226, 170))
    for x in range(4, 48):
        put(im, x, 7 + int(3 * (1 - ((x - 26) / 22) ** 2)), (46, 70, 140))
    return im


def ticket_machine():
    im = new(20, 36)
    rect(im, 0, 0, 19, 35, (226, 228, 234))
    vline(im, 19, 0, 35, (160, 166, 176))
    rect(im, 3, 3, 16, 13, (60, 140, 200))
    draw_text_centered(im, 10, 6, "A12", (255, 255, 255))
    rect(im, 6, 17, 13, 19, (40, 40, 44))
    rect(im, 6, 24, 13, 25, (250, 250, 250))
    return im


def parcel_shelf():
    im = new(50, 46)
    steel = (130, 136, 148)
    rect(im, 0, 0, 1, 45, steel)
    rect(im, 48, 0, 49, 45, steel)
    rnd = random.Random(11)
    for y in (13, 28, 43):
        rect(im, 0, y, 49, y + 1, steel)
        x = 3
        while x < 45:
            bw = rnd.randint(7, 12)
            bh = rnd.randint(6, 11)
            c = rnd.choice([(200, 158, 108), (190, 148, 98), (214, 178, 128), (240, 240, 240)])
            rect(im, x, y - bh, min(46, x + bw), y - 1, c)
            hline(im, x, min(46, x + bw), y - bh, lighten(c, 0.2))
            if c != (240, 240, 240):
                vline(im, x + bw // 2, y - bh, y - bh + 2, (236, 226, 196))
            x += bw + 2
    return im


def logo_wall(text, col=(40, 56, 88), accent=(240, 220, 160)):
    tw = text_width(text)
    w = max(70, tw + 22)
    im = new(w, 32)
    rect(im, 0, 0, w - 1, 31, col)
    hline(im, 0, w - 1, 0, lighten(col, 0.25))
    hline(im, 0, w - 1, 31, shade(col, 0.6))
    rect(im, 2, 2, w - 3, 29, lighten(col, 0.05))
    draw_text_centered(im, w // 2, 14, text, accent)
    hline(im, w // 2 - tw // 2, w // 2 + tw // 2, 21, accent)
    return im


def window(night=False, w=52, h=42, seed=1):
    rnd = random.Random(seed)
    im = new(w, h)
    frame = (70, 76, 90)
    rect(im, 0, 0, w - 1, h - 1, frame)
    for y in range(2, h - 2):
        t = (y - 2) / (h - 4)
        c = mix((150, 204, 244), (226, 240, 250), t) if not night else mix((22, 28, 62), (82, 64, 118), t)
        hline(im, 2, w - 3, y, c)
    if not night:
        for cx, cy in ((10, 8), (34, 6)):
            for dx in range(-4, 5):
                put(im, cx + dx, cy, (250, 252, 255))
                put(im, cx + dx // 2, cy - 1, (250, 252, 255))
    x = 2
    while x < w - 3:
        bw = rnd.randint(5, 10)
        bh = rnd.randint(8, h - 12)
        col = (110, 146, 190) if not night else (28, 34, 60)
        rect(im, x, h - 3 - bh, min(w - 3, x + bw), h - 3, col)
        rect(im, x, h - 3 - bh, min(w - 3, x + bw), h - 3 - bh, lighten(col, 0.2))
        for yy in range(h - bh, h - 4, 3):
            for xx in range(x + 1, min(w - 4, x + bw), 2):
                if night and rnd.random() < 0.5:
                    put(im, xx, yy, (255, 214, 140))
                elif not night and rnd.random() < 0.25:
                    put(im, xx, yy, (190, 220, 244))
        x += bw + 1
    vline(im, w // 2, 1, h - 2, frame)
    hline(im, 1, w - 2, h // 3, frame)
    # curtains
    for x in range(1, 5):
        vline(im, x, 1, h - 2, (230, 222, 206) if x % 2 else (214, 204, 186))
        vline(im, w - 1 - x, 1, h - 2, (230, 222, 206) if x % 2 else (214, 204, 186))
    hline(im, 0, w - 1, h - 1, (230, 230, 232))
    return im


def framed_art(seed=1):
    rnd = random.Random(seed)
    im = new(20, 16)
    rect(im, 0, 0, 19, 15, (60, 44, 34))
    rect(im, 2, 2, 17, 13, (240, 236, 226))
    for i in range(3):
        c = rnd.choice([(224, 104, 83), (46, 98, 196), (226, 186, 90), (90, 150, 110)])
        m = Mask(20, 16).ellipse(3 + i * 4, 4 + rnd.randint(0, 3), 7 + i * 4 + rnd.randint(0, 3), 11)
        fill(im, m, c)
    return im


def sconce():
    im = new(10, 12)
    rect(im, 3, 3, 6, 9, (226, 186, 90))
    hline(im, 2, 7, 2, (255, 236, 190))
    put(im, 4, 10, (80, 80, 90))
    return im


def interior_props():
    return {
        "bed": bed, "desk_laptop": desk_laptop, "chair": lambda: chair_office((56, 60, 74)), "office_chair": lambda: chair_office((40, 44, 56)),
        "sofa": lambda: sofa(52, (92, 110, 150)), "lounge_sofa": lambda: sofa(58, (70, 96, 130)), "waiting_sofa": lambda: sofa(50, (40, 56, 88)),
        "coffee_table": coffee_table, "bookshelf": bookshelf, "tv": tv_unit, "kitchen": kitchen, "fridge": fridge, "wardrobe": wardrobe,
        "plant": lambda: plant(False), "plant_big": lambda: plant(True), "rug": rug, "rug_navy": lambda: rug(64, 40, (58, 76, 118), (150, 170, 210)),
        "rug_small": lambda: rug(40, 24, (176, 144, 112), (236, 214, 170)), "box": boxes, "packing_table": packing_table,
        "cafe_counter": cafe_counter, "menu_board": menu_board, "display_case": display_case, "cafe_table": cafe_table,
        "cafe_chair": cafe_chair, "hanging_light": pendant, "monitor_desk": monitor_desk, "glass_wall": glass_room,
        "printer": printer, "lockers": lockers, "cork_board": cork_board, "whiteboard": whiteboard, "exec_desk": exec_desk,
        "bank_counter": lambda: counter_marble(144, (40, 56, 90), "NEXUS"), "civic_counter": lambda: counter_marble(144, (46, 60, 96), "SERVICES"),
        "postpoint_counter": lambda: counter_marble(80, (180, 80, 64)), "atm": atm, "queue_barrier": stanchions,
        "ticket_machine": ticket_machine, "parcel_shelf": parcel_shelf,
        "logo_nexus_bank": lambda: logo_wall("NEXUS BANK", (34, 46, 76), (226, 186, 90)),
        "logo_city_hall": lambda: logo_wall("CITY OF AURELIA", (46, 60, 96), (240, 220, 160)),
        "logo_cowork": lambda: logo_wall("NEXUS  WORK - MEET - CREATE", (28, 46, 92), (230, 240, 255)),
        "logo_bloom": lambda: logo_wall("BLOOM COFFEE", (38, 66, 50), (230, 244, 220)),
        "logo_postpoint": lambda: logo_wall("POSTPOINT", (190, 84, 66), (255, 244, 230)),
        "logo_bytebean": lambda: logo_wall("BEAN & BYTE", (30, 30, 36), (240, 220, 180)),
        "window_day": lambda: window(False, 52, 42, 1), "window_night": lambda: window(True, 52, 42, 1),
        "framed_art": lambda: framed_art(1), "framed_art_b": lambda: framed_art(5), "sconce": sconce,
    }
