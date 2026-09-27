"""Layered character sprites (32x48 frames) and portraits (64x64).

Sheet layout for every sprite layer: 4 columns (walk frames 0..3) x 3 rows
(0 = down/front, 1 = side facing right, 2 = up/back)  -> 128 x 144 px.
Frame 0 doubles as the idle pose. Left-facing = flip_h of row 1.

Tinted layers (skin, hair, brows, iris, tintable clothes) are drawn with a
grayscale ramp and coloured in-engine with `modulate`.
"""
from __future__ import annotations

from pixel import (Mask, new, shaded, fill, put, rect, hline, vline, save, ramp, hexc,
                   shade, lighten, GRAY_SKIN, GRAY_HAIR, GRAY_CLOTH, PAL)

FW, FH = 32, 48
DIRS = ("down", "side", "up")
PRESENTATIONS = ("masculine", "feminine", "neutral")
FACES = ("round", "oval", "square", "heart")
EYES = ("round", "almond", "narrow", "wide")
BROWS = ("straight", "arched", "thick", "soft")
MOUTHS = ("smile", "neutral", "grin", "small")
HAIRS = ("messy", "short_neat", "buzz", "side_part", "bob", "long", "ponytail", "bun")
LASH = (43, 33, 48)
LIP = (150, 78, 78)
LIP_DARK = (104, 52, 58)
WHITE = (250, 250, 252)


# ------------------------------------------------------------ pose/geometry
def pose(d, f):
    step = f in (1, 3)
    return {
        "bob": -1 if step else 0,
        "lift_l": 2 if f == 1 else 0,
        "lift_r": 2 if f == 3 else 0,
        "swing": {0: 0, 1: 1, 2: 0, 3: -1}[f],
    }


def torso_x(pres):
    if pres == "masculine":
        return (9, 22), (10, 21)
    if pres == "feminine":
        return (10, 21), (11, 20)
    return (10, 21), (10, 21)


def head_mask(face, d, bob):
    m = Mask(FW, FH)
    y = bob
    if d == "side":
        m.ellipse(10, 4 + y, 21, 18 + y)
        m.px(22, 12 + y).px(22, 13 + y)  # nose
        if face == "square":
            m.rect(12, 15 + y, 20, 18 + y)
        if face == "heart":
            m.rect(11, 6 + y, 20, 12 + y)
        return m
    if face == "round":
        m.ellipse(9, 4 + y, 22, 18 + y)
    elif face == "oval":
        m.ellipse(10, 4 + y, 21, 18 + y)
        m.rect(10, 8 + y, 21, 13 + y)
    elif face == "square":
        m.ellipse(9, 4 + y, 22, 13 + y)
        m.rect(9, 8 + y, 22, 16 + y)
        m.rect(10, 17 + y, 21, 18 + y)
    else:  # heart
        m.ellipse(9, 4 + y, 22, 15 + y)
        m.poly([(10, 11 + y), (21, 11 + y), (19, 16 + y), (17, 18 + y), (14, 18 + y), (12, 16 + y)])
    return m


def ears(d, bob):
    m = Mask(FW, FH)
    if d == "down":
        m.rect(8, 11 + bob, 8, 13 + bob).rect(23, 11 + bob, 23, 13 + bob)
    elif d == "up":
        m.rect(8, 11 + bob, 8, 13 + bob).rect(23, 11 + bob, 23, 13 + bob)
    else:
        m.rect(14, 11 + bob, 15, 13 + bob)
    return m


def body_parts(pres, d, f):
    p = pose(d, f)
    b = p["bob"]
    parts = {}
    (sx0, sx1), (wx0, wx1) = torso_x(pres)
    neck = Mask(FW, FH)
    torso = Mask(FW, FH)
    arm_back = Mask(FW, FH)   # drawn behind torso (side view)
    arms = Mask(FW, FH)
    hands = Mask(FW, FH)
    legs = []
    feet = []
    if d in ("down", "up"):
        neck.rect(14, 17 + b, 17, 20 + b)
        torso.rect(sx0 + 1, 20 + b, sx1 - 1, 20 + b)
        torso.rect(sx0, 21 + b, sx1, 26 + b)
        torso.rect(wx0, 27 + b, wx1, 30 + b)
        torso.rect(10, 31 + b, 21, 33 + b)
        sw = p["swing"] if d == "down" else -p["swing"]
        # left arm (screen left)
        la_end = 30 + b - sw
        ra_end = 30 + b + sw
        arms.rect(sx0 - 3, 21 + b, sx0 - 1, la_end)
        arms.rect(sx1 + 1, 21 + b, sx1 + 3, ra_end)
        hands.rect(sx0 - 3, la_end + 1, sx0 - 1, la_end + 3)
        hands.rect(sx1 + 1, ra_end + 1, sx1 + 3, ra_end + 3)
        for (x0, x1, lift) in ((11, 15, p["lift_l"]), (16, 20, p["lift_r"])):
            lm = Mask(FW, FH).rect(x0, 32 + b, x1, 44 - lift)
            legs.append(lm)
            fm = Mask(FW, FH).rect(x0 - (1 if x0 == 11 else 0), 43 - lift, x1 + (1 if x1 == 20 else 0), 46 - lift)
            feet.append(fm)
    else:
        neck.rect(14, 17 + b, 17, 20 + b)
        torso.rect(11 if pres == "masculine" else 12, 20 + b, 20, 33 + b)
        if pres == "feminine":
            torso.px(12, 27 + b, 0).px(19, 27 + b, 0)
        s = p["swing"]
        # stride: frame1 leg A forward, frame3 leg B forward
        if f in (1, 3):
            front = (15, 19)
            back = (11, 15)
        else:
            front = (13, 17)
            back = (14, 18)
        bm = Mask(FW, FH).rect(back[0], 32 + b, back[1], 44)
        fm = Mask(FW, FH).rect(front[0], 32 + b, front[1], 44)
        legs = [bm, fm]
        feet = [Mask(FW, FH).rect(back[0], 43, back[1] + 2, 46), Mask(FW, FH).rect(front[0], 43, front[1] + 2, 46)]
        ax = 14 + 2 * s
        arms.rect(14, 21 + b, 17, 24 + b)
        arms.poly([(14, 24 + b), (17, 24 + b), (17 + 2 * s, 30 + b), (14 + 2 * s, 30 + b)])
        hands.rect(ax, 31 + b, ax + 3, 33 + b)
        arm_back.rect(13 - s, 22 + b, 15 - s, 29 + b)
    parts.update(neck=neck, torso=torso, arms=arms, arm_back=arm_back, hands=hands, legs=legs, feet=feet, bob=b)
    return parts


# ------------------------------------------------------------ sheets
def sheet():
    return new(FW * 4, FH * 3)


def each_frame():
    for r, d in enumerate(DIRS):
        for f in range(4):
            yield r, d, f, f * FW, r * FH


def draw_body(pres, face):
    img = sheet()
    for r, d, f, ox, oy in each_frame():
        P = body_parts(pres, d, f)
        for lm in P["legs"]:
            shaded(img, lm, GRAY_SKIN, ox, oy)
        if d == "side":
            shaded(img, P["arm_back"], shade_ramp(GRAY_SKIN, 0.9), ox, oy)
        shaded(img, P["torso"], GRAY_SKIN, ox, oy)
        shaded(img, P["neck"], GRAY_SKIN, ox, oy, hi=False)
        shaded(img, P["arms"], GRAY_SKIN, ox, oy)
        shaded(img, P["hands"], GRAY_SKIN, ox, oy)
        hm = head_mask(face, d, P["bob"])
        em = ears(d, P["bob"])
        shaded(img, em, GRAY_SKIN, ox, oy, hi=False)
        shaded(img, hm, GRAY_SKIN, ox, oy)
        if d == "down":
            # soft cheek/nose shading
            put(img, ox + 16, oy + 14 + P["bob"], GRAY_SKIN[1])
    return img


def shade_ramp(rp, k):
    return tuple(shade(c, k) for c in rp)


# ---- face features (down + side rows only)
EYE_POS = {"down": [(12, 10), (18, 10)], "side": [(18, 10)]}


def draw_eyes(shape):
    lash = sheet()
    iris = sheet()
    for r, d, f, ox, oy in each_frame():
        if d == "up":
            continue
        b = pose(d, f)["bob"]
        for (ex, ey) in EYE_POS[d]:
            x, y = ox + ex, oy + ey + b
            if shape == "round":
                hline(lash, x, x + 1, y, LASH)
                put(iris, x, y + 1, (210, 210, 210)); put(lash, x + 1, y + 1, WHITE)
                put(iris, x, y + 2, (170, 170, 170)); put(iris, x + 1, y + 2, (210, 210, 210))
                if d == "side":
                    put(lash, x + 1, y + 1, WHITE)
            elif shape == "almond":
                hline(lash, x - (1 if ex < 16 else 0), x + 1 + (1 if ex >= 16 else 0), y, LASH)
                put(iris, x, y + 1, (190, 190, 190)); put(iris, x + 1, y + 1, (190, 190, 190))
                put(lash, x + (1 if ex < 16 else 0), y + 1, (40, 30, 44))
            elif shape == "narrow":
                hline(lash, x, x + 1, y + 1, LASH)
                put(iris, x + (1 if ex < 16 else 0), y + 1, (150, 150, 150))
            else:  # wide
                hline(lash, x, x + 1, y, LASH)
                put(lash, x, y + 1, WHITE); put(iris, x + 1, y + 1, (215, 215, 215))
                put(iris, x, y + 2, (190, 190, 190)); put(iris, x + 1, y + 2, (150, 150, 150))
                hline(lash, x, x + 1, y + 3, (120, 90, 90))
    return lash, iris


def draw_brows(style):
    img = sheet()
    c = (100, 100, 100)
    for r, d, f, ox, oy in each_frame():
        if d == "up":
            continue
        b = pose(d, f)["bob"]
        for (ex, ey) in EYE_POS[d]:
            x, y = ox + ex, oy + ey - 1 + b
            if style == "straight":
                hline(img, x - 1 if ex < 16 else x, x + 1 if ex < 16 else x + 2, y, c)
            elif style == "arched":
                put(img, x - (1 if ex < 16 else -2), y, c)
                hline(img, x, x + 1, y - 1, c)
            elif style == "thick":
                hline(img, x - 1 if ex < 16 else x, x + 1 if ex < 16 else x + 2, y, c)
                hline(img, x, x + 1, y - 1, (80, 80, 80))
            else:  # soft
                hline(img, x, x + 1, y, (150, 150, 150))
    return img


def draw_mouth(style):
    img = sheet()
    for r, d, f, ox, oy in each_frame():
        if d == "up":
            continue
        b = pose(d, f)["bob"]
        if d == "down":
            x, y = ox + 15, oy + 15 + b
            if style == "smile":
                put(img, x - 1, y, LIP); put(img, x, y + 1, LIP); put(img, x + 1, y + 1, LIP); put(img, x + 2, y, LIP)
            elif style == "neutral":
                hline(img, x, x + 1, y + 1, LIP)
            elif style == "grin":
                hline(img, x - 1, x + 2, y, LIP_DARK); hline(img, x, x + 1, y + 1, WHITE)
                put(img, x - 1, y + 1, LIP); put(img, x + 2, y + 1, LIP)
            else:
                put(img, x, y + 1, LIP)
        else:
            x, y = ox + 20, oy + 15 + b
            if style in ("smile", "grin"):
                put(img, x, y + 1, LIP); put(img, x + 1, y, LIP)
            else:
                hline(img, x, x + 1, y + 1, LIP)
    return img


# ---- hair
def dilate(m, r=1):
    out = m.copy()
    for x, y in list(m.pixels()):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                out.px(x + dx, y + dy)
    return out


def hair_masks(style, d, b):
    """returns (back_mask, front_mask) for a frame."""
    head = head_mask("round", d, b)
    cap_base = dilate(head, 1)
    front = Mask(FW, FH)
    back = Mask(FW, FH)
    Y = lambda v: v + b
    if d == "down":
        top = Mask(FW, FH).rect(0, 0, 31, Y(8))
        cap = cap_base.copy().intersect(top)
        if style == "buzz":
            cap = head.copy().intersect(Mask(FW, FH).rect(0, 0, 31, Y(7)))
            cap.union(Mask(FW, FH).rect(9, Y(8), 9, Y(9)).rect(22, Y(8), 22, Y(9)))
            front.union(cap)
            return back, front
        front.union(cap)
        if style == "messy":
            for sx, top in ((9, 3), (12, 1), (16, 2), (19, 3)):
                front.poly([(sx, Y(5)), (sx + 4, Y(5)), (sx + 2, Y(top))])
            front.poly([(9, Y(8)), (13, Y(8)), (11, Y(11))])
            front.poly([(13, Y(8)), (17, Y(8)), (15, Y(10))])
            front.poly([(17, Y(8)), (22, Y(8)), (20, Y(11))])
            front.rect(8, Y(8), 9, Y(13)).rect(22, Y(8), 23, Y(13))
        elif style == "short_neat":
            front.rect(9, Y(8), 22, Y(8))
            front.rect(8, Y(6), 9, Y(12)).rect(22, Y(6), 23, Y(12))
            front.rect(10, Y(2), 21, Y(3))
        elif style == "side_part":
            front.poly([(9, Y(8)), (17, Y(8)), (11, Y(11)), (9, Y(11))])
            front.rect(8, Y(7), 9, Y(12)).rect(22, Y(7), 23, Y(11))
            front.rect(10, Y(2), 20, Y(3))
        elif style in ("bob", "long"):
            front.rect(9, Y(8), 22, Y(9))
            front.rect(7, Y(6), 9, Y(17)).rect(22, Y(6), 24, Y(17))
            if style == "long":
                back.rect(8, Y(10), 23, Y(27))
                back.poly([(8, Y(27)), (23, Y(27)), (21, Y(29)), (10, Y(29))])
        elif style == "ponytail":
            front.rect(9, Y(8), 22, Y(8))
            front.rect(8, Y(6), 9, Y(12)).rect(22, Y(6), 23, Y(12))
            back.rect(23, Y(9), 25, Y(19))
        elif style == "bun":
            front.rect(9, Y(8), 22, Y(8))
            front.rect(8, Y(6), 9, Y(11)).rect(22, Y(6), 23, Y(11))
            front.ellipse(12, Y(0), 19, Y(5))
        return back, front
    if d == "up":
        cap = cap_base.copy().intersect(Mask(FW, FH).rect(0, 0, 31, Y(16)))
        front.union(cap)
        if style == "buzz":
            front = head.copy().intersect(Mask(FW, FH).rect(0, 0, 31, Y(15)))
        elif style == "messy":
            for sx, top in ((9, 3), (12, 1), (16, 2), (19, 3)):
                front.poly([(sx, Y(5)), (sx + 4, Y(5)), (sx + 2, Y(top))])
            front.poly([(10, Y(15)), (21, Y(15)), (18, Y(18)), (13, Y(18))])
        elif style == "bob":
            front.rect(7, Y(8), 24, Y(18))
        elif style == "long":
            front.rect(8, Y(8), 23, Y(28))
            front.poly([(8, Y(28)), (23, Y(28)), (21, Y(30)), (10, Y(30))])
        elif style == "ponytail":
            front.rect(14, Y(14), 17, Y(26))
            front.ellipse(13, Y(12), 18, Y(16))
        elif style == "bun":
            front.ellipse(12, Y(0), 19, Y(5))
        return back, front
    # side (facing right)
    cap = cap_base.copy().intersect(Mask(FW, FH).rect(0, 0, 31, Y(8)))
    backhalf = cap_base.copy().intersect(Mask(FW, FH).rect(0, 0, 15, Y(15)))
    front.union(cap).union(backhalf)
    if style == "buzz":
        front = head.copy().intersect(Mask(FW, FH).rect(0, 0, 31, Y(7)))
        front.union(head.copy().intersect(Mask(FW, FH).rect(0, 0, 13, Y(14))))
    elif style == "messy":
        for sx, top in ((10, 2), (13, 1), (17, 3)):
            front.poly([(sx, Y(5)), (sx + 4, Y(5)), (sx + 3, Y(top))])
        front.poly([(17, Y(8)), (22, Y(8)), (21, Y(11))])
        front.poly([(8, Y(10)), (10, Y(8)), (10, Y(16))])
    elif style == "short_neat":
        front.rect(17, Y(8), 21, Y(8))
    elif style == "side_part":
        front.poly([(15, Y(8)), (22, Y(8)), (22, Y(10))])
    elif style == "bob":
        front.rect(8, Y(8), 14, Y(17))
        front.rect(16, Y(8), 21, Y(9))
    elif style == "long":
        front.rect(16, Y(8), 21, Y(9))
        back.rect(8, Y(10), 14, Y(28))
    elif style == "ponytail":
        front.rect(16, Y(8), 21, Y(8))
        back.poly([(9, Y(9)), (11, Y(9)), (9, Y(22)), (6, Y(20))])
    elif style == "bun":
        front.ellipse(8, Y(1), 14, Y(7))
    return back, front


def draw_hair(style):
    back_img = sheet()
    front_img = sheet()
    for r, d, f, ox, oy in each_frame():
        b = pose(d, f)["bob"]
        bm, fm = hair_masks(style, d, b)
        if d == "up":
            # everything visible from behind lives in the front layer
            fm.union(bm)
            bm = Mask(FW, FH)
        shaded(back_img, bm, GRAY_HAIR, ox, oy, sh_depth=2)
        shaded(front_img, fm, GRAY_HAIR, ox, oy, sh_depth=1)
        # strand accents
        for x, y in list(fm.pixels()):
            if (x * 7 + y * 3) % 11 == 0 and fm.get(x, y + 1) and fm.get(x, y - 1) and fm.get(x - 1, y) and fm.get(x + 1, y):
                put(front_img, ox + x, oy + y, GRAY_HAIR[1])
    return back_img, front_img


# ---- outfits
OUTFITS = {
    # id: spec. "tint": which sheets are grayscale (tinted in engine)
    "startup_casual": {"top": "blazer", "top_col": (48, 52, 66), "inner": (240, 240, 236), "bottom": "jeans",
                        "bottom_col": (44, 62, 102), "shoes": (236, 236, 236), "sole": (150, 150, 160)},
    "office_professional": {"top": "shirt", "top_col": (232, 236, 242), "lanyard": (40, 60, 110), "badge": (77, 138, 214),
                            "bottom": "slacks", "bottom_col": (62, 66, 78), "skirt_for_feminine": True,
                            "shoes": (34, 34, 40), "sole": (20, 20, 24)},
    "home": {"top": "hoodie", "top_col": (168, 176, 194), "bottom": "joggers", "bottom_col": (48, 50, 60),
             "shoes": (200, 204, 214), "sole": (140, 140, 150)},
    "barista": {"top": "apron_tee", "top_col": (40, 42, 48), "apron": (184, 140, 98), "bottom": "slacks",
                "bottom_col": (52, 50, 56), "shoes": (96, 64, 44), "sole": (60, 40, 30)},
    "business_suit": {"top": "suit", "top_col": (38, 50, 86), "inner": (236, 238, 242), "tie": (200, 84, 70),
                      "bottom": "slacks", "bottom_col": (38, 50, 86), "shoes": (30, 30, 34), "sole": (18, 18, 20)},
    "civic_staff": {"top": "vest", "top_col": (176, 204, 232), "vest": (46, 60, 94), "bottom": "slacks",
                    "bottom_col": (92, 96, 108), "shoes": (40, 36, 36), "sole": (24, 22, 22)},
    "courier": {"top": "polo", "top_col": (232, 132, 64), "bottom": "cargo", "bottom_col": (58, 62, 60),
                "shoes": (40, 40, 44), "sole": (24, 24, 26)},
    "casual_tee": {"top": "tee", "top_col": None, "bottom": "jeans", "bottom_col": None,
                   "shoes": (236, 236, 236), "sole": (150, 150, 160), "tint": ["top", "bottom"]},
    "casual_jacket": {"top": "jacket", "top_col": None, "inner": (238, 238, 234), "bottom": "slacks", "bottom_col": None,
                      "shoes": (52, 48, 48), "sole": (30, 28, 28), "tint": ["top", "bottom"]},
}


def cloth_ramp(col):
    if col is None:
        return GRAY_CLOTH
    return ramp(col, 0.45, 0.8, 0.18)


def draw_outfit(oid, pres):
    spec = OUTFITS[oid]
    top = sheet()
    bottom = sheet()
    shoes = sheet()
    tr = cloth_ramp(spec["top_col"])
    br = cloth_ramp(spec["bottom_col"])
    kind = spec["top"]
    skirt = spec.get("skirt_for_feminine") and pres == "feminine"
    for r, d, f, ox, oy in each_frame():
        P = body_parts(pres, d, f)
        b = P["bob"]
        cx = 16
        # ---------------- bottom
        if skirt:
            sk = Mask(FW, FH)
            if d == "side":
                sk.poly([(12, 31 + b), (19, 31 + b), (21, 38), (11, 38)])
            else:
                sk.poly([(10, 31 + b), (21, 31 + b), (22, 38), (9, 38)])
            shaded(bottom, sk, br, ox, oy)
        else:
            for i, lm in enumerate(P["legs"]):
                pm = lm.copy().intersect(Mask(FW, FH).rect(0, 0, 31, 42))
                rr = br if not (d == "side" and i == 0) else shade_ramp(br, 0.88)
                shaded(bottom, pm, rr, ox, oy)
            if spec["bottom"] == "joggers":
                for lm in P["legs"]:
                    bb = lm.bbox()
                    if bb:
                        hline(bottom, ox + bb[0] + 1, ox + bb[2] - 2, oy + min(bb[3] - 1, 42), shade(spec["bottom_col"], 0.7))
            if spec["bottom"] == "cargo" and d != "up":
                for lm in P["legs"]:
                    bb = lm.bbox()
                    if bb:
                        rect(bottom, ox + bb[0] + 1, oy + 36, ox + bb[0] + 2, oy + 38, shade(spec["bottom_col"], 0.75))
            # belt / waistband
            wb = Mask(FW, FH)
            if d == "side":
                wb.rect(12, 31 + b, 19, 32 + b)
            else:
                wb.rect(10, 31 + b, 21, 32 + b)
            shaded(bottom, wb, br, ox, oy, hi=False)
        sr = ramp(spec["shoes"], 0.45, 0.82, 0.15)
        for i, fm in enumerate(P["feet"]):
            shaded(shoes, fm, sr, ox, oy, hi=False)
            bb = fm.bbox()
            if bb:
                hline(shoes, ox + bb[0] + 1, ox + bb[2] - 2, oy + bb[3] - 1, spec["sole"])
        # ---------------- top
        torso = P["torso"].copy()
        sleeves = P["arms"].copy()
        short_sleeves = kind in ("tee", "polo", "apron_tee")
        if short_sleeves:
            sleeves.intersect(Mask(FW, FH).rect(0, 0, 31, 25 + b))
        if kind == "hoodie":
            torso.union(Mask(FW, FH).rect(10, 32 + b, 21, 34 + b) if d != "side" else Mask(FW, FH).rect(12, 32 + b, 19, 34 + b))
        if d == "side":
            back_sl = P["arm_back"].copy()
            if short_sleeves:
                back_sl.intersect(Mask(FW, FH).rect(0, 0, 31, 25 + b))
            shaded(top, back_sl, shade_ramp(tr, 0.85), ox, oy)
        shaded(top, torso, tr, ox, oy)
        # details
        if d == "down":
            if kind in ("blazer", "suit", "jacket"):
                inner = spec.get("inner", (236, 236, 236))
                for yy in range(20 + b, 30 + b):
                    w = max(0, 2 - (yy - 20 - b) // 4)
                    hline(top, ox + cx - 1 - w, ox + cx + w, oy + yy, inner)
                # lapels
                put(top, ox + cx - 3, oy + 21 + b, tr[0]); put(top, ox + cx + 2, oy + 21 + b, tr[0])
                put(top, ox + cx - 2, oy + 24 + b, tr[0]); put(top, ox + cx + 1, oy + 24 + b, tr[0])
                vline(top, ox + cx - 1, oy + 30 + b, oy + 33 + b, tr[0])
                if kind == "suit":
                    vline(top, ox + cx - 1, oy + 21 + b, oy + 27 + b, spec["tie"]); vline(top, ox + cx, oy + 21 + b, oy + 27 + b, shade(spec["tie"], 0.8))
                put(top, ox + cx + 3, oy + 28 + b, tr[0])  # button/pocket hint
            elif kind == "shirt":
                put(top, ox + cx - 2, oy + 20 + b, (200, 206, 214)); put(top, ox + cx + 1, oy + 20 + b, (200, 206, 214))
                vline(top, ox + cx - 1, oy + 22 + b, oy + 32 + b, (210, 214, 222))
                lc = spec["lanyard"]
                for i in range(5):
                    put(top, ox + cx - 3 + i // 2, oy + 21 + b + i, lc)
                    put(top, ox + cx + 2 - i // 2, oy + 21 + b + i, lc)
                rect(top, ox + cx - 1, oy + 26 + b, ox + cx, oy + 28 + b, spec["badge"])
                put(top, ox + cx - 1, oy + 26 + b, (240, 244, 250))
            elif kind == "hoodie":
                hood = shade(spec["top_col"], 0.82)
                hline(top, ox + cx - 4, ox + cx + 3, oy + 20 + b, hood)
                put(top, ox + cx - 2, oy + 22 + b, (240, 240, 244)); put(top, ox + cx + 1, oy + 22 + b, (240, 240, 244))
                put(top, ox + cx - 2, oy + 23 + b, (240, 240, 244)); put(top, ox + cx + 1, oy + 23 + b, (240, 240, 244))
                rect(top, ox + cx - 4, oy + 28 + b, ox + cx + 3, oy + 30 + b, shade(spec["top_col"], 0.86))
            elif kind == "apron_tee":
                ap = ramp(spec["apron"], 0.5, 0.82, 0.15)
                am = Mask(FW, FH).rect(11, 24 + b, 20, 37)
                shaded(top, am, ap, ox, oy)
                vline(top, ox + 12, oy + 20 + b, oy + 23 + b, spec["apron"]); vline(top, ox + 19, oy + 20 + b, oy + 23 + b, spec["apron"])
                rect(top, ox + 14, oy + 29 + b, ox + 17, oy + 30 + b, shade(spec["apron"], 0.8))
            elif kind == "vest":
                vm = Mask(FW, FH).rect(11, 22 + b, 20, 32 + b)
                vm.subtract(Mask(FW, FH).poly([(14, 21 + b), (17, 21 + b), (16, 26 + b), (15, 26 + b)]))
                shaded(top, vm, ramp(spec["vest"], 0.5, 0.8, 0.15), ox, oy)
                put(top, ox + 15, oy + 29 + b, (220, 220, 230))
            elif kind == "polo":
                rect(top, ox + cx - 2, oy + 20 + b, ox + cx + 1, oy + 21 + b, shade(spec["top_col"], 0.75))
                vline(top, ox + cx, oy + 21 + b, oy + 23 + b, shade(spec["top_col"], 0.65))
            elif kind == "tee":
                hline(top, ox + cx - 2, ox + cx + 1, oy + 20 + b, GRAY_CLOTH[1])
        elif d == "up":
            vline(top, ox + cx - 1, oy + 22 + b, oy + 32 + b, tr[1])
            if kind == "hoodie":
                hm = Mask(FW, FH).ellipse(11, 18 + b, 20, 24 + b)
                shaded(top, hm, shade_ramp(tr, 0.92), ox, oy)
            if kind == "apron_tee":
                hline(top, ox + 11, ox + 20, oy + 29 + b, spec["apron"])
        else:  # side
            if kind in ("blazer", "suit", "jacket"):
                inner = spec.get("inner", (236, 236, 236))
                vline(top, ox + 19, oy + 20 + b, oy + 28 + b, inner)
                if kind == "suit":
                    vline(top, ox + 19, oy + 21 + b, oy + 26 + b, spec["tie"])
            if kind == "shirt":
                vline(top, ox + 18, oy + 21 + b, oy + 25 + b, spec["lanyard"])
                rect(top, ox + 18, oy + 26 + b, ox + 19, oy + 28 + b, spec["badge"])
            if kind == "apron_tee":
                am = Mask(FW, FH).rect(16, 24 + b, 20, 37)
                shaded(top, am, ramp(spec["apron"], 0.5, 0.82, 0.15), ox, oy)
            if kind == "vest":
                vm = Mask(FW, FH).rect(12, 22 + b, 19, 32 + b)
                shaded(top, vm, ramp(spec["vest"], 0.5, 0.8, 0.15), ox, oy)
            if kind == "hoodie":
                hm = Mask(FW, FH).ellipse(9, 18 + b, 15, 24 + b)
                shaded(top, hm, shade_ramp(tr, 0.92), ox, oy)
        shaded(top, sleeves, tr, ox, oy)
        if d == "down" and kind in ("blazer", "suit", "shirt", "hoodie", "jacket"):
            bb = P["arms"].bbox()
    return top, bottom, shoes


# ---- accessories
def draw_glasses(kind):
    img = sheet()
    fr = (40, 40, 52)
    lens = (190, 214, 236, 150)
    for r, d, f, ox, oy in each_frame():
        if d == "up":
            continue
        b = pose(d, f)["bob"]
        for (ex, ey) in EYE_POS[d]:
            x, y = ox + ex - 1, oy + ey + b
            if kind == "round":
                hline(img, x + 1, x + 2, y - 1 + 1, fr); hline(img, x + 1, x + 2, y + 3, fr)
                vline(img, x, y + 1, y + 2, fr); vline(img, x + 3, y + 1, y + 2, fr)
            else:
                hline(img, x, x + 3, y, fr); hline(img, x, x + 3, y + 3, fr)
                vline(img, x, y, y + 3, fr); vline(img, x + 3, y, y + 3, fr)
        if d == "down":
            hline(img, ox + 15, ox + 16, oy + 11 + b, fr)
        else:
            hline(img, ox + 13, ox + 16, oy + 11 + b, fr)
    return img


def draw_backpack():
    img = sheet()
    rp = ramp((70, 88, 120), 0.45, 0.8, 0.18)
    for r, d, f, ox, oy in each_frame():
        b = pose(d, f)["bob"]
        if d == "down":
            vline(img, ox + 11, oy + 21 + b, oy + 28 + b, rp[0]); vline(img, ox + 20, oy + 21 + b, oy + 28 + b, rp[0])
        elif d == "up":
            m = Mask(FW, FH).rect(10, 21 + b, 21, 33 + b)
            shaded(img, m, rp, ox, oy)
            rect(img, ox + 12, oy + 27 + b, ox + 19, oy + 31 + b, rp[1])
        else:
            m = Mask(FW, FH).rect(8, 21 + b, 12, 32 + b)
            shaded(img, m, rp, ox, oy)
    return img


# ------------------------------------------------------------ portraits
PW = PH = 64


def psheet(frames=4):
    return new(PW * frames, PH)


def p_head(face):
    m = Mask(PW, PH)
    if face == "round":
        m.ellipse(15, 8, 48, 50)
    elif face == "oval":
        m.ellipse(17, 8, 46, 52)
    elif face == "square":
        m.ellipse(15, 8, 48, 38)
        m.rect(15, 24, 48, 44)
        m.poly([(15, 44), (48, 44), (42, 51), (21, 51)])
    else:
        m.ellipse(14, 8, 49, 42)
        m.poly([(15, 30), (48, 30), (40, 47), (32, 53), (23, 47)])
    return m


def draw_p_head(face):
    img = psheet(1)
    neck = Mask(PW, PH).rect(26, 44, 37, 58)
    shaded(img, neck, shade_ramp(GRAY_SKIN, 0.9), 0, 0)
    ears_m = Mask(PW, PH).ellipse(11, 27, 18, 38).ellipse(45, 27, 52, 38)
    shaded(img, ears_m, GRAY_SKIN, 0, 0, hi=False)
    hm = p_head(face)
    shaded(img, hm, GRAY_SKIN, 0, 0, sh_depth=2)
    # nose + cheek
    put(img, 32, 37, GRAY_SKIN[1]); put(img, 33, 38, GRAY_SKIN[1])
    return img


P_EYES = [(20, 27), (36, 27)]  # top-left of each 8x7 eye box
EXPR = ("neutral", "happy", "thinking", "surprised")


def draw_p_eyes(shape):
    lash = psheet(4)
    iris = psheet(4)
    for e, ex_name in enumerate(EXPR):
        ox = e * PW
        for i, (x0, y0) in enumerate(P_EYES):
            x, y = ox + x0, y0
            if ex_name == "happy":
                # closed smiling arcs
                hline(lash, x + 1, x + 6, y + 3, LASH)
                put(lash, x, y + 4, LASH); put(lash, x + 7, y + 4, LASH)
                hline(lash, x + 2, x + 5, y + 2, LASH)
                continue
            h = {"round": 6, "almond": 5, "narrow": 3, "wide": 7}[shape]
            if ex_name == "surprised":
                h += 1
            top = y + (7 - h)
            # sclera
            rect(lash, x + 1, top + 1, x + 6, top + h - 1, WHITE)
            # iris
            shift = 0
            up = 0
            if ex_name == "thinking":
                shift, up = (2 if i == 1 else 2), 1
            iw = 4 if ex_name != "surprised" else 3
            ix0 = x + 2 + shift - (1 if shape == "wide" else 0)
            ix0 = min(ix0, x + 6 - iw + 1)
            for yy in range(top + 1, top + h):
                for xx in range(ix0, ix0 + iw):
                    g = 215 if yy < top + 1 + (h - 1) // 2 else 160
                    if yy == top + h - 1:
                        g = 190
                    put(iris, xx, yy - up, (g, g, g))
            # pupil + highlight
            px0 = ix0 + 1
            rect(lash, px0, top + 2 - up, px0 + (1 if ex_name != "surprised" else 0), top + min(h - 1, 4) - up, (28, 22, 34))
            put(lash, ix0, top + 1 - up + 1, WHITE)
            put(lash, ix0 + 1, top + 1 - up + 1, WHITE) if shape in ("round", "wide") else None
            # upper lash line (thicker) + corners
            hline(lash, x, x + 7, top, LASH)
            hline(lash, x + 1, x + 6, top - 1 if shape != "narrow" else top, LASH)
            if shape == "almond":
                put(lash, x + (7 if i == 1 else 0), top + 1, LASH)
            if shape != "narrow":
                hline(lash, x + 2, x + 5, top + h, (150, 110, 110))
    return lash, iris


def draw_p_brows(style):
    img = psheet(4)
    c = (100, 100, 100)
    for e, ex_name in enumerate(EXPR):
        ox = e * PW
        for i, (x0, y0) in enumerate(P_EYES):
            x = ox + x0
            y = y0 - 4
            lift = {"neutral": 0, "happy": 1, "thinking": 0, "surprised": 3}[ex_name]
            if ex_name == "thinking" and i == 1:
                lift = 2
            y -= lift
            inner_down = 1 if (ex_name == "thinking" and i == 0) else 0
            thick = 2 if style == "thick" else 1
            col = (150, 150, 150) if style == "soft" else c
            for t in range(thick):
                if style == "arched":
                    hline(img, x + 1, x + 6, y - 1 + t, col)
                    put(img, x, y + t, col); put(img, x + 7, y + t, col)
                else:
                    hline(img, x, x + 7, y + t, col)
            if inner_down:
                put(img, x + 7, y + 1, col)
    return img


def draw_p_mouth(style):
    img = psheet(4)
    for e, ex_name in enumerate(EXPR):
        ox = e * PW
        x, y = ox + 29, 43
        if ex_name == "happy" or (ex_name == "neutral" and style == "grin"):
            rect(img, x - 1, y, x + 6, y + 2, LIP_DARK)
            hline(img, x, x + 5, y, WHITE)
            hline(img, x + 1, x + 4, y + 2, (210, 110, 110))
            put(img, x - 2, y - 1, LIP); put(img, x + 7, y - 1, LIP)
        elif ex_name == "surprised":
            rect(img, x + 1, y - 1, x + 4, y + 2, LIP_DARK)
            hline(img, x + 2, x + 3, y + 3, LIP)
        elif ex_name == "thinking":
            hline(img, x + 2, x + 6, y + 1, LIP)
            put(img, x + 1, y + 2, LIP)
        else:
            if style == "smile":
                hline(img, x, x + 5, y + 1, LIP); put(img, x - 1, y, LIP); put(img, x + 6, y, LIP)
            elif style == "neutral":
                hline(img, x + 1, x + 4, y + 1, LIP)
            elif style == "small":
                hline(img, x + 2, x + 3, y + 1, LIP)
    return img


def p_hair_masks(style):
    head = p_head("round")
    back = Mask(PW, PH)
    front = Mask(PW, PH)
    cap = dilate(head, 2).intersect(Mask(PW, PH).rect(0, 0, 63, 22))
    if style == "buzz":
        cap = head.copy().intersect(Mask(PW, PH).rect(0, 0, 63, 17))
        front.union(cap)
        return back, front
    front.union(cap)
    if style == "messy":
        for sx, top in ((15, 6), (22, 2), (31, 4), (39, 1), (44, 7)):
            front.poly([(sx, 13), (sx + 9, 13), (sx + 4, top)])
        front.poly([(16, 20), (27, 20), (21, 30)])
        front.poly([(26, 20), (36, 20), (31, 27)])
        front.poly([(35, 20), (47, 20), (43, 31)])
        front.rect(11, 16, 16, 34).rect(47, 16, 52, 34)
    elif style == "short_neat":
        front.rect(15, 20, 48, 22)
        front.rect(12, 14, 16, 32).rect(47, 14, 51, 32)
    elif style == "side_part":
        front.poly([(15, 20), (42, 20), (22, 30), (15, 30)])
        front.rect(12, 14, 16, 33).rect(47, 14, 51, 30)
    elif style in ("bob", "long"):
        front.rect(15, 20, 48, 24)
        front.rect(9, 16, 17, 50).rect(46, 16, 54, 50)
        back.rect(10, 20, 53, 52)
        if style == "long":
            back.rect(8, 30, 55, 63)
            front.rect(9, 40, 16, 63).rect(47, 40, 54, 63)
    elif style == "ponytail":
        front.rect(15, 20, 48, 22)
        front.rect(12, 14, 16, 32).rect(47, 14, 51, 32)
        back.poly([(47, 16), (58, 22), (58, 44), (52, 40)])
    elif style == "bun":
        front.rect(15, 20, 48, 22)
        front.rect(12, 14, 16, 30).rect(47, 14, 51, 30)
        front.ellipse(24, 0, 40, 12)
    return back, front


def draw_p_hair(style):
    b_img = psheet(1)
    f_img = psheet(1)
    bm, fm = p_hair_masks(style)
    shaded(b_img, bm, shade_ramp(GRAY_HAIR, 0.85), 0, 0, sh_depth=2)
    shaded(f_img, fm, GRAY_HAIR, 0, 0, sh_depth=2)
    for x, y in list(fm.pixels()):
        if (x * 5 + y * 2) % 9 == 0 and fm.get(x, y - 1) and fm.get(x, y + 2) and fm.get(x - 1, y) and fm.get(x + 1, y):
            put(f_img, x, y, GRAY_HAIR[1])
            put(f_img, x, y + 1, GRAY_HAIR[1])
    return b_img, f_img


def draw_p_outfit(oid):
    spec = OUTFITS[oid]
    img = psheet(1)
    tr = cloth_ramp(spec["top_col"])
    kind = spec["top"]
    sh = Mask(PW, PH)
    sh.poly([(6, 63), (10, 54), (22, 50), (41, 50), (53, 54), (57, 63)])
    shaded(img, sh, tr, 0, 0, sh_depth=2)
    if kind in ("blazer", "suit", "jacket"):
        inner = spec.get("inner", (236, 236, 236))
        m = Mask(PW, PH).poly([(25, 50), (38, 50), (34, 63), (29, 63)])
        fill(img, m, inner)
        for i in range(10):
            put(img, 24 + i // 2, 50 + i, tr[0]); put(img, 39 - i // 2, 50 + i, tr[0])
        if kind == "suit":
            fill(img, Mask(PW, PH).poly([(30, 52), (33, 52), (34, 63), (29, 63)]), spec["tie"])
    elif kind == "shirt":
        fill(img, Mask(PW, PH).poly([(24, 49), (31, 55), (28, 57)]), (214, 220, 230))
        fill(img, Mask(PW, PH).poly([(39, 49), (32, 55), (35, 57)]), (214, 220, 230))
        for i in range(12):
            put(img, 22 + i // 3, 51 + i, spec["lanyard"]); put(img, 41 - i // 3, 51 + i, spec["lanyard"])
    elif kind == "hoodie":
        fill(img, Mask(PW, PH).poly([(18, 50), (45, 50), (40, 56), (23, 56)]), shade(spec["top_col"], 0.8))
        vline(img, 28, 56, 62, (240, 240, 244)); vline(img, 35, 56, 62, (240, 240, 244))
    elif kind == "apron_tee":
        fill(img, Mask(PW, PH).rect(20, 56, 43, 63), spec["apron"])
        vline(img, 22, 50, 56, spec["apron"]); vline(img, 41, 50, 56, spec["apron"])
    elif kind == "vest":
        fill(img, Mask(PW, PH).poly([(14, 56), (27, 52), (31, 63), (12, 63)]), spec["vest"])
        fill(img, Mask(PW, PH).poly([(49, 56), (36, 52), (32, 63), (51, 63)]), spec["vest"])
    elif kind == "polo":
        fill(img, Mask(PW, PH).poly([(24, 49), (31, 54), (27, 56)]), shade(spec["top_col"], 0.78))
        fill(img, Mask(PW, PH).poly([(39, 49), (32, 54), (36, 56)]), shade(spec["top_col"], 0.78))
    elif kind == "tee":
        hline(img, 25, 38, 51, GRAY_CLOTH[1])
    return img


# ------------------------------------------------------------ main
def generate(out):
    import os
    c = os.path.join(out, "characters")
    p = os.path.join(out, "portraits")
    for pres in PRESENTATIONS:
        for face in FACES:
            save(draw_body(pres, face), f"{c}/body_{pres}_{face}.png")
    for e in EYES:
        l, i = draw_eyes(e)
        save(l, f"{c}/eyes_{e}.png"); save(i, f"{c}/iris_{e}.png")
        pl, pi = draw_p_eyes(e)
        save(pl, f"{p}/eyes_{e}.png"); save(pi, f"{p}/iris_{e}.png")
    for s in BROWS:
        save(draw_brows(s), f"{c}/brows_{s}.png")
        save(draw_p_brows(s), f"{p}/brows_{s}.png")
    for s in MOUTHS:
        save(draw_mouth(s), f"{c}/mouth_{s}.png")
        save(draw_p_mouth(s), f"{p}/mouth_{s}.png")
    for s in HAIRS:
        b, f = draw_hair(s)
        save(b, f"{c}/hair_{s}_back.png"); save(f, f"{c}/hair_{s}_front.png")
        pb, pf = draw_p_hair(s)
        save(pb, f"{p}/hair_{s}_back.png"); save(pf, f"{p}/hair_{s}_front.png")
    for oid in OUTFITS:
        for pres in PRESENTATIONS:
            t, b, s = draw_outfit(oid, pres)
            save(t, f"{c}/outfit_{oid}_{pres}_top.png")
            save(b, f"{c}/outfit_{oid}_{pres}_bottom.png")
            save(s, f"{c}/outfit_{oid}_{pres}_shoes.png")
        save(draw_p_outfit(oid), f"{p}/outfit_{oid}.png")
    for g in ("round", "square"):
        save(draw_glasses(g), f"{c}/acc_glasses_{g}.png")
    save(draw_backpack(), f"{c}/acc_backpack.png")
    for face in FACES:
        save(draw_p_head(face), f"{p}/head_{face}.png")
