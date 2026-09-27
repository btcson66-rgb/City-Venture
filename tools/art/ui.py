"""Neo-Civic UI kit: 9-slice panels, buttons, tabs, icons (16x16), phone frame."""
from __future__ import annotations

import json
from PIL import ImageDraw

from pixel import PAL, Mask, new, shaded, fill, put, rect, hline, vline, box, save, ramp, shade, lighten, mix, paste
from font3x5 import draw_text_centered


def nine(w, h, fill_c, border, hi=None, sh=None, cut=True, alpha=255):
    im = new(w, h)
    rect(im, 1, 1, w - 2, h - 2, tuple(fill_c) + (alpha,))
    hline(im, 1, w - 2, 0, border); hline(im, 1, w - 2, h - 1, border)
    vline(im, 0, 1, h - 2, border); vline(im, w - 1, 1, h - 2, border)
    if not cut:
        put(im, 0, 0, border); put(im, w - 1, 0, border); put(im, 0, h - 1, border); put(im, w - 1, h - 1, border)
    if hi:
        hline(im, 2, w - 3, 1, hi)
    if sh:
        hline(im, 2, w - 3, h - 2, sh)
    return im


def grad_panel(w, h, top, bottom, border, hi, alpha=246, accent=None):
    """Board A style panel: vertical gradient, 1px border, lit top edge, cut corners."""
    im = new(w, h)
    for y in range(1, h - 1):
        c = mix(top, bottom, (y - 1) / max(1, h - 3))
        hline(im, 1, w - 2, y, tuple(c) + (alpha,))
    hline(im, 1, w - 2, 0, border)
    hline(im, 1, w - 2, h - 1, shade(border, 0.7))
    vline(im, 0, 1, h - 2, border)
    vline(im, w - 1, 1, h - 2, shade(border, 0.8))
    hline(im, 2, w - 3, 1, hi)
    if accent:
        hline(im, 3, 8, 0, accent)
    return im


def gen_panels(out):
    P = {}
    P["panel"] = grad_panel(24, 24, (24, 40, 64), (12, 22, 38), (66, 96, 146), (96, 132, 190), 248, (120, 170, 240))
    P["panel_glass"] = grad_panel(24, 24, (20, 34, 56), (10, 18, 32), (58, 84, 128), (80, 112, 160), 222)
    P["inset"] = nine(16, 16, PAL["navy_900"], PAL["navy_700"], None, None)
    P["header"] = nine(16, 16, PAL["navy_700"], PAL["navy_600"], lighten(PAL["navy_700"], 0.12), None)
    P["button"] = grad_panel(16, 16, (46, 68, 108), (30, 46, 76), (70, 110, 176), (100, 140, 206), 255)
    P["button_hover"] = grad_panel(16, 16, (72, 120, 196), (46, 88, 158), (132, 180, 240), (170, 206, 250), 255)
    P["button_pressed"] = nine(16, 16, PAL["navy_700"], PAL["blue_400"], shade(PAL["navy_700"], 0.8), None)
    P["button_disabled"] = nine(16, 16, (40, 46, 60), (64, 70, 86), None, None)
    P["button_primary"] = grad_panel(16, 16, (70, 160, 104), (40, 112, 70), (120, 210, 140), (160, 232, 176), 255)
    P["button_primary_hover"] = grad_panel(16, 16, (90, 186, 124), (54, 136, 88), (170, 240, 184), (200, 250, 210), 255)
    P["button_danger"] = nine(16, 16, (150, 64, 56), (224, 104, 83), (180, 84, 72), (100, 40, 36))
    P["tab"] = nine(16, 16, PAL["navy_800"], PAL["navy_600"], None, None)
    P["tab_active"] = grad_panel(16, 16, (64, 116, 196), (40, 82, 150), (132, 180, 240), (170, 206, 250), 255)
    P["tooltip"] = nine(16, 16, (240, 242, 246), PAL["navy_500"], None, None)
    P["card"] = grad_panel(16, 16, (32, 48, 76), (22, 34, 56), (52, 74, 112), (70, 98, 144), 255)
    P["card_gold"] = nine(16, 16, PAL["navy_700"], PAL["gold_500"], None, None)
    P["bar_bg"] = nine(8, 8, PAL["navy_900"], PAL["navy_600"], None, None)
    P["bar_fill"] = nine(8, 8, PAL["blue_400"], PAL["blue_300"], lighten(PAL["blue_400"], 0.3), None)
    P["bar_fill_green"] = nine(8, 8, PAL["green_500"], PAL["green_cash"], None, None)
    P["field"] = nine(16, 16, (10, 20, 34), PAL["blue_500"], None, None)
    P["prompt_key"] = nine(12, 12, (240, 242, 246), (140, 150, 170), None, (190, 196, 210), cut=True)
    for k, im in P.items():
        save(im, f"{out}/ui/{k}.png")
    # phone frame
    w, h = 150, 250
    ph = new(w, h)
    m = Mask(w, h)
    m.rect(8, 0, w - 9, h - 1).rect(0, 8, w - 1, h - 9)
    for (cx, cy) in ((8, 8), (w - 9, 8), (8, h - 9), (w - 9, h - 9)):
        m.ellipse(cx - 8, cy - 8, cx + 8, cy + 8)
    shaded(ph, m, ((14, 18, 26), (30, 34, 44), (40, 44, 56), (70, 76, 92)), 0, 0)
    for x, y in Mask(w, h).rect(7, 16, w - 8, h - 17).pixels():
        put(ph, x, y, (0, 0, 0, 0))
    rect(ph, w // 2 - 14, 6, w // 2 + 13, 9, (20, 22, 30))
    put(ph, w // 2 + 18, 7, (60, 80, 120))
    rect(ph, w // 2 - 16, h - 11, w // 2 + 15, h - 10, (90, 96, 110))
    save(ph, f"{out}/ui/phone_frame.png")
    # dialogue portrait frame 72x72
    pf = new(72, 72)
    box(pf, 0, 0, 71, 71, PAL["navy_700"], PAL["blue_400"], None, None)
    for x, y in Mask(72, 72).rect(4, 4, 67, 67).pixels():
        put(pf, x, y, (0, 0, 0, 0))
    hline(pf, 2, 69, 2, PAL["blue_300"])
    save(pf, f"{out}/ui/portrait_frame.png")


# ---------------------------------------------------------------- icons
def ic():
    return new(16, 16)


def draw_icon(name):
    im = ic()
    d = ImageDraw.Draw(im)
    W = (244, 246, 250, 255)
    B = PAL["blue_400"] + (255,)
    G = PAL["green_cash"] + (255,)
    R = PAL["red_500"] + (255,)
    Y = PAL["gold_500"] + (255,)
    O = (20, 28, 44, 255)
    if name == "cash":
        box(im, 1, 4, 14, 12, (86, 170, 104), (40, 90, 56), (130, 210, 140))
        m = Mask(16, 16).ellipse(5, 5, 10, 11); fill(im, m, (200, 240, 200))
        rect(im, 7, 6, 8, 10, (60, 130, 80))
    elif name == "clock":
        m = Mask(16, 16).ellipse(1, 1, 14, 14); shaded(im, m, ramp((236, 240, 246)), 0, 0)
        vline(im, 7, 4, 8, O[:3]); hline(im, 8, 10, 8, O[:3])
    elif name == "calendar":
        box(im, 1, 3, 14, 14, (240, 242, 246), (120, 130, 150)); rect(im, 1, 3, 14, 6, PAL["red_500"])
        vline(im, 4, 1, 4, O[:3]); vline(im, 11, 1, 4, O[:3])
        for y in (8, 11):
            for x in (4, 7, 10):
                rect(im, x, y, x + 1, y + 1, (120, 130, 150))
    elif name == "sun":
        m = Mask(16, 16).ellipse(4, 4, 11, 11); fill(im, m, (255, 204, 90))
        for (a, b) in (((7, 0), (8, 2)), ((7, 13), (8, 15)), ((0, 7), (2, 8)), ((13, 7), (15, 8))):
            rect(im, a[0], a[1], b[0], b[1], (255, 204, 90))
        for p in ((2, 2), (13, 2), (2, 13), (13, 13)):
            put(im, *p, (255, 204, 90))
    elif name == "moon":
        m = Mask(16, 16).ellipse(2, 2, 13, 13); m2 = Mask(16, 16).ellipse(5, 0, 16, 11)
        m.subtract(m2); fill(im, m, (220, 214, 250))
    elif name in ("objective", "star"):
        pts = [(8, 0), (10, 5), (15, 6), (11, 10), (12, 15), (8, 12), (4, 15), (5, 10), (1, 6), (6, 5)]
        m = Mask(16, 16).poly(pts); shaded(im, m, ramp((255, 204, 90)), 0, 0)
    elif name == "home":
        m = Mask(16, 16).poly([(1, 8), (8, 1), (15, 8)]); shaded(im, m, ramp(PAL["red_500"]), 0, 0)
        box(im, 3, 8, 12, 14, (240, 240, 244), (140, 146, 160)); rect(im, 7, 10, 9, 14, (120, 84, 58))
    elif name == "company":
        box(im, 3, 1, 12, 15, PAL["blue_400"], PAL["navy_600"], PAL["blue_300"])
        for y in (3, 6, 9):
            rect(im, 5, y, 6, y + 1, (220, 236, 250)); rect(im, 9, y, 10, y + 1, (220, 236, 250))
        rect(im, 7, 12, 8, 15, PAL["navy_700"])
    elif name == "map":
        m = Mask(16, 16).poly([(1, 3), (5, 1), (10, 3), (15, 1), (15, 13), (10, 15), (5, 13), (1, 15)])
        shaded(im, m, ramp((150, 200, 150)), 0, 0)
        vline(im, 5, 2, 13, (90, 140, 90)); vline(im, 10, 3, 14, (90, 140, 90))
        put(im, 12, 6, PAL["red_500"]); put(im, 12, 7, PAL["red_500"])
    elif name == "people":
        for cx, col in ((5, (150, 180, 230)), (10, (240, 246, 250))):
            m = Mask(16, 16).ellipse(cx - 2, 2, cx + 2, 6); fill(im, m, col)
            m2 = Mask(16, 16).ellipse(cx - 4, 8, cx + 4, 17); fill(im, m2, col)
    elif name == "tasks":
        box(im, 2, 1, 13, 15, (240, 242, 246), (120, 130, 150))
        for y in (4, 8, 12):
            rect(im, 4, y, 5, y + 1, PAL["green_cash"]); hline(im, 7, 11, y, (120, 130, 150))
    elif name == "phone":
        box(im, 4, 0, 11, 15, (40, 44, 56), (20, 22, 30)); rect(im, 5, 2, 10, 12, PAL["blue_400"])
    elif name in ("inventory", "parcel"):
        box(im, 1, 4, 14, 14, (196, 156, 108), (120, 90, 64), (220, 186, 140))
        rect(im, 1, 4, 14, 6, (176, 136, 90)); vline(im, 7, 4, 14, (230, 220, 190))
    elif name == "orders":
        d.line([(1, 3), (4, 3), (6, 11), (13, 11), (14, 5), (5, 5)], fill=W, width=1)
        put(im, 7, 13, W); put(im, 12, 13, W)
    elif name == "finance":
        rect(im, 2, 9, 4, 14, B); rect(im, 6, 6, 8, 14, B); rect(im, 10, 3, 12, 14, G)
        hline(im, 1, 14, 15, W)
    elif name == "contracts":
        box(im, 3, 1, 12, 15, (240, 242, 246), (120, 130, 150))
        for y in (4, 6, 8):
            hline(im, 5, 10, y, (140, 150, 170))
        d.line([(5, 12), (7, 11), (9, 13), (11, 11)], fill=PAL["blue_500"] + (255,))
    elif name == "bank":
        m = Mask(16, 16).poly([(1, 5), (8, 1), (15, 5)]); fill(im, m, (230, 226, 214))
        for x in (3, 7, 11):
            rect(im, x, 6, x + 1, 12, (230, 226, 214))
        rect(im, 1, 13, 14, 14, (230, 226, 214))
    elif name == "warning":
        m = Mask(16, 16).poly([(8, 1), (15, 14), (1, 14)]); shaded(im, m, ramp((250, 200, 80)), 0, 0)
        vline(im, 7, 5, 9, O[:3]); vline(im, 8, 5, 9, O[:3]); rect(im, 7, 11, 8, 12, O[:3])
    elif name == "check":
        d.line([(2, 8), (6, 12), (14, 3)], fill=G, width=2)
    elif name == "lock":
        box(im, 3, 7, 12, 14, (226, 180, 82), (130, 100, 40))
        d.arc([4, 1, 11, 10], 180, 360, fill=(200, 204, 214, 255), width=2)
        rect(im, 7, 9, 8, 11, (80, 60, 30))
    elif name == "metro":
        box(im, 2, 1, 13, 12, PAL["blue_500"], PAL["navy_600"]); rect(im, 4, 3, 11, 6, (220, 236, 250))
        put(im, 4, 9, (255, 240, 180)); put(im, 11, 9, (255, 240, 180))
        d.line([(3, 15), (5, 12)], fill=W); d.line([(12, 15), (10, 12)], fill=W)
    elif name == "mail":
        box(im, 1, 3, 14, 12, (240, 242, 246), (120, 130, 150))
        d.line([(1, 3), (8, 9), (14, 3)], fill=(120, 130, 150, 255))
    elif name == "settings":
        m = Mask(16, 16).ellipse(2, 2, 13, 13)
        for (x, y) in ((7, 0), (7, 13), (0, 7), (13, 7)):
            m.rect(x, y, x + 2, y + 2)
        m.subtract(Mask(16, 16).ellipse(5, 5, 10, 10)); shaded(im, m, ramp((170, 180, 200)), 0, 0)
    elif name == "save":
        box(im, 1, 1, 14, 14, PAL["blue_500"], PAL["navy_600"]); rect(im, 4, 2, 11, 6, (220, 230, 240))
        rect(im, 4, 9, 11, 13, (40, 50, 70))
    elif name == "laptop":
        box(im, 2, 2, 13, 10, (60, 66, 80), (30, 34, 44)); rect(im, 3, 3, 12, 9, PAL["blue_400"])
        rect(im, 0, 11, 15, 12, (170, 176, 190))
    elif name == "coffee":
        box(im, 3, 4, 11, 14, (250, 250, 250), (160, 160, 170)); rect(im, 3, 7, 11, 10, (72, 128, 84))
        rect(im, 2, 2, 12, 4, (60, 60, 66))
    elif name == "arrow_right":
        m = Mask(16, 16).poly([(3, 6), (9, 6), (9, 2), (14, 8), (9, 14), (9, 10), (3, 10)]); fill(im, m, W[:3])
    elif name == "close":
        d.line([(3, 3), (12, 12)], fill=W, width=2); d.line([(12, 3), (3, 12)], fill=W, width=2)
    elif name == "plus":
        rect(im, 7, 3, 8, 12, W); rect(im, 3, 7, 12, 8, W)
    elif name == "minus":
        rect(im, 3, 7, 12, 8, W)
    elif name == "walk":
        m = Mask(16, 16).ellipse(6, 0, 9, 3); fill(im, m, W[:3])
        d.line([(7, 4), (7, 9), (4, 14)], fill=W, width=2); d.line([(7, 9), (10, 14)], fill=W, width=2)
        d.line([(4, 7), (10, 6)], fill=W)
    elif name == "shop":
        box(im, 2, 6, 13, 14, (240, 242, 246), (140, 146, 160))
        for x in range(1, 15):
            put(im, x, 4 if (x // 2) % 2 == 0 else 5, PAL["red_500"])
        rect(im, 1, 3, 14, 5, PAL["red_500"]); rect(im, 6, 9, 9, 14, PAL["blue_400"])
    elif name == "civic":
        m = Mask(16, 16).poly([(1, 5), (8, 1), (15, 5)]); fill(im, m, (230, 226, 214))
        m2 = Mask(16, 16).ellipse(5, 0, 10, 5); fill(im, m2, (226, 180, 82))
        for x in (3, 7, 11):
            rect(im, x, 6, x + 1, 12, (230, 226, 214))
        rect(im, 1, 13, 14, 14, (230, 226, 214))
    elif name == "startup":
        m = Mask(16, 16).poly([(8, 0), (11, 5), (11, 11), (5, 11), (5, 5)]); shaded(im, m, ramp((240, 242, 246)), 0, 0)
        rect(im, 7, 4, 8, 5, PAL["blue_400"]); rect(im, 3, 9, 4, 13, R[:3]); rect(im, 11, 9, 12, 13, R[:3])
        rect(im, 6, 12, 9, 15, (255, 170, 80))
    elif name == "river":
        m = Mask(16, 16).ellipse(3, 4, 12, 13); shaded(im, m, ramp(PAL["leaf_400"]), 0, 0)
        rect(im, 7, 11, 8, 15, (120, 84, 58))
    elif name == "financial":
        rect(im, 2, 8, 4, 14, W); rect(im, 6, 4, 9, 14, B); rect(im, 11, 1, 13, 14, W)
    elif name == "dollar":
        m = Mask(16, 16).ellipse(1, 1, 14, 14); shaded(im, m, ramp((86, 170, 104)), 0, 0)
        rect(im, 7, 3, 8, 12, (220, 250, 220)); hline(im, 5, 10, 5, (220, 250, 220)); hline(im, 5, 10, 10, (220, 250, 220))
    elif name == "info":
        m = Mask(16, 16).ellipse(1, 1, 14, 14); shaded(im, m, ramp(PAL["blue_400"]), 0, 0)
        rect(im, 7, 3, 8, 4, (255, 255, 255)); rect(im, 7, 6, 8, 12, (255, 255, 255))
    elif name == "world":
        m = Mask(16, 16).ellipse(1, 1, 14, 14); shaded(im, m, ramp(PAL["water_400"]), 0, 0)
        m2 = Mask(16, 16).poly([(4, 3), (8, 4), (7, 8), (4, 9), (3, 6)]); fill(im, m2, PAL["grass_300"])
        m3 = Mask(16, 16).poly([(10, 7), (13, 8), (12, 12), (9, 11)]); fill(im, m3, PAL["grass_300"])
    elif name == "sleep":
        for (x, y, s) in ((2, 8, 5), (7, 4, 4), (11, 1, 3)):
            hline(im, x, x + s, y, W); d.line([(x + s, y), (x, y + s)], fill=W); hline(im, x, x + s, y + s, W)
    elif name == "shirt":
        m = Mask(16, 16).poly([(1, 4), (5, 1), (10, 1), (14, 4), (12, 7), (11, 6), (11, 15), (4, 15), (4, 6), (3, 7)])
        shaded(im, m, ramp(PAL["blue_400"]), 0, 0)
    return im


ICONS = ["cash", "clock", "calendar", "sun", "moon", "objective", "star", "home", "company", "map", "people", "tasks",
         "phone", "inventory", "parcel", "orders", "finance", "contracts", "bank", "warning", "check", "lock", "metro",
         "mail", "settings", "save", "laptop", "coffee", "arrow_right", "close", "plus", "minus", "walk", "shop", "civic",
         "startup", "river", "financial", "dollar", "info", "world", "sleep", "shirt"]


def generate(out):
    gen_panels(out)
    cols = 8
    atlas = new(16 * cols, 16 * ((len(ICONS) + cols - 1) // cols))
    idx = {}
    for i, n in enumerate(ICONS):
        im = draw_icon(n)
        save(im, f"{out}/ui/icons/{n}.png")
        paste(atlas, im, (i % cols) * 16, (i // cols) * 16)
        idx[n] = [i % cols, i // cols]
    save(atlas, f"{out}/ui/icons_atlas.png")
