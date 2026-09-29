"""Lay out district frontages and street dressing into game/data/districts/*.json.

Keeps each district's ground, exits, spawns, metro, traffic and pedestrian paths, and regenerates:
building x positions (from real sprite widths), filler facades, and the street furniture
(trees between doors, banner lamps, curb bollards, planters, café terraces, wayfinding, park).
The output is plain data: the game still builds districts purely from JSON.
"""
import json
import os
import random

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA = os.path.join(ROOT, "game", "data")
META = json.load(open(os.path.join(ROOT, "game", "assets", "buildings", "buildings_meta.json")))
PROPS = os.path.join(ROOT, "game", "assets", "props")

BASE = 320

ROWS = {
    "riverside": ["riverside_walkup", "@riverside_apartment", "@bloom_coffee", "riverside_shops", "@postpoint_riverside",
                  "apartment_mid", "brick_shops", "office_slab", "glass_tower", "riverside_walkup"],
    "startup_hub": ["office_slab", "@nexus_cowork", "@byte_and_bean", "horizon_labs", "@small_office", "glass_tower",
                    "apartment_mid", "office_slab"],
    "civic_center": ["civic_annex", "@city_hall", "office_slab", "brick_shops", "glass_tower"],
    "financial": ["finance_tower", "@nexus_bank", "glass_tower", "finance_tower", "office_slab"],
    "shopping_street": ["retail_arcade", "@threadline_apparel", "@lantern_bistro", "cinema_front", "@crestline_flagship",
                        "shop_row_awning", "@popup_unit"],
}
LABELS = {
    "riverside": {"east": "STARTUP HUB →"}, "startup_hub": {"west": "← RIVERSIDE"},
    "civic_center": {"east": "FINANCIAL →", "west": "← SHOPPING ST"}, "financial": {"west": "← CIVIC CENTER"},
    "shopping_street": {"east": "CIVIC CENTER →"},
}
# weekend market (Shopping Street): stalls are out Sat/Sun 09:00-18:00, packed away otherwise
MARKET_HOURS = {"days": "sat,sun", "from": "09:00", "to": "18:00"}
STALLS = ["market_stall_rose", "market_stall_sage", "market_stall_cream"]


def prop_size(name):
    """Design (footprint) size: board-converted sprites may overhang it (assets/sprite_meta.json)."""
    from PIL import Image
    im = Image.open(os.path.join(PROPS, name + ".png"))
    m = SPRITE_META.get("props/" + name, {})
    return int(m.get("dw", im.width)), int(m.get("dh", im.height - int(m.get("top", 0))))


SPRITE_META = json.load(open(os.path.join(os.path.dirname(PROPS), "sprite_meta.json"))) \
    if os.path.exists(os.path.join(os.path.dirname(PROPS), "sprite_meta.json")) else {}


def P(name, x, base_y, solid=None, **kw):
    w, h = prop_size(name)
    d = {"sprite": name, "x": int(x), "y": int(base_y - h)}
    if solid is not None:
        d["solid"] = solid
    d.update(kw)
    return d


def layout(did):
    path = os.path.join(DATA, "districts", did + ".json")
    d = json.load(open(path))
    width = d["size_tiles"][0] * 16
    rnd = random.Random(did)
    bdefs = {}
    for f in os.listdir(os.path.join(DATA, "buildings")):
        b = json.load(open(os.path.join(DATA, "buildings", f)))
        bdefs[b["id"]] = b
    x = 20
    fillers = []
    doors = []
    fronts = []
    for item in ROWS[did]:
        if item.startswith("@"):
            bid = item[1:]
            b = bdefs[bid]
            sprite = b["exterior"]["sprite"]
            b["exterior"]["x"] = x
            json.dump(b, open(os.path.join(DATA, "buildings", bid + ".json"), "w"), indent=1, ensure_ascii=False)
            m = META[sprite]
            doors.append((x + m["door"][0] + m["door"][2] / 2, b["type"], bid, x, m))
        else:
            sprite = item
            fillers.append({"sprite": sprite, "x": x})
            m = META[sprite]
            doors.append((x + m["door"][0] + m["door"][2] / 2, "filler", sprite, x, m))
        fronts.append((x, x + META[sprite]["size"][0]))
        x += META[sprite]["size"][0] + rnd.randint(6, 14)
    assert x < width - 40, "%s frontage too long (%d > %d)" % (did, x, width)
    d["fillers"] = fillers
    door_xs = [dx for dx, *_ in doors]

    def near_door(px, r=26):
        return any(abs(px - dx) < r for dx in door_xs)

    props = []
    # --- north sidewalk: trees in pits & banner lamps between doors, bollards on the curb
    px = 60
    k = 0
    while px < width - 40:
        if not near_door(px, 34):
            if k % 2 == 0:
                props.append(P("tree_round" if (k // 2) % 3 else "tree_round_b", px - 32, 382, [28, 84, 8, 6]))
            else:
                props.append(P("lamp_banner", px - 8, 384, [6, 66, 5, 4], glow=True))
        px += 80
        k += 1
    for bx in range(28, width - 20, 36):
        if not near_door(bx, 18):
            props.append(P("bollard", bx, 386, [2, 11, 4, 3]))
    # --- per building dressing
    for (dx, typ, bid, bx, m) in doors:
        if typ == "cafe":
            props.append(P("umbrella_table" if bid == "bloom_coffee" else "umbrella_table_blue", dx + 24, 366, [10, 30, 16, 6]))
            props.append(P("umbrella_table" if bid == "bloom_coffee" else "umbrella_table_blue", dx + 64, 366, [10, 30, 16, 6]))
            props.append(P("cafe_board", dx - 30, 346, [2, 16, 12, 4]))
            props.append(P("planter_small", dx - 58, 344, [1, 14, 22, 6]))
        elif typ in ("home", "coworking", "office"):
            props.append(P("planter_small", dx - 40, 342, [1, 14, 22, 6]))
            props.append(P("planter_small", dx + 18, 342, [1, 14, 22, 6]))
        elif typ == "parcel":
            props.append(P("bike", dx + 26, 348, [2, 14, 32, 5]))
        elif typ == "retail":
            props.append(P("planter_small", dx - 40, 342, [1, 14, 22, 6]))
            props.append(P("planter_small", dx + 18, 342, [1, 14, 22, 6]))
        elif typ == "restaurant":
            props.append(P("umbrella_table", dx + 24, 366, [10, 30, 16, 6]))
            props.append(P("umbrella_table", dx + 64, 366, [10, 30, 16, 6]))
            props.append(P("cafe_board", dx - 30, 346, [2, 16, 12, 4]))
        elif typ == "retail_space":
            props.append(P("bike_rack", dx + 20, 350, [1, 20, 52, 5]))
        elif typ in ("bank", "civic"):
            props.append(P("planter", dx - 70, 346, [1, 18, 34, 8]))
            props.append(P("planter", dx + 36, 346, [1, 18, 34, 8]))
            if typ == "civic":
                props.append(P("flagpole", dx - 96, 344, [1, 60, 6, 5]))
                props.append(P("flagpole", dx + 80, 344, [1, 60, 6, 5]))
        elif typ == "filler" and rnd.random() < 0.5:
            props.append(P(rnd.choice(["planter_small", "trash_bin", "bike"]), dx + rnd.randint(20, 40), 346, [1, 12, 16, 5]))
    # wayfinding near exits
    for ex in d.get("exits", []):
        side = "west" if ex["rect"][0] < 20 else "east"
        sx = 40 if side == "west" else width - 70
        props.append(P("direction_sign", sx, 358, [18, 44, 6, 4], label=LABELS[did].get(side, "")))
    props.append(P("digital_sign", width // 2 + 40, 350, [4, 38, 14, 6]))
    # --- south side: keep previous park/plaza dressing but swap in v2 props
    old = json.load(open(path)).get("props", [])
    for p in old:
        y_base = p["y"]
        name = p["sprite"]
        if p.get("_gen") or name in ("railing", "hedge"):
            continue  # generated dressing is rebuilt below
        if p.get("_base", y_base + OLD_H.get(p["sprite"], 0)) < 470:
            continue  # north side regenerated above
        if name in ("lamp",):
            name = "lamp"
        try:
            w, h = prop_size(name)
        except FileNotFoundError:
            continue
        # old data stored top-left with old heights; re-anchor on the old base line
        from PIL import Image
        old_base = p.get("_base", p["y"] + OLD_H.get(p["sprite"], h))
        np = {k: v for k, v in p.items() if k not in ("solid",)}
        np["y"] = int(old_base - h)
        np["_base"] = int(old_base)
        sol = SOLIDS.get(name)
        if sol:
            np["solid"] = sol
        props.append(np)
    if did == "shopping_street":
        props += market_square()
    # river railing / hedges along the park
    if did == "riverside":
        for rx in range(0, width, 64):
            props.append(P("railing", rx, 656, [0, 10, 64, 4]))
        for hx in (120, 440, 1240, 1560):
            props.append(P("hedge", hx, 560, [0, 12, 48, 6]))
    else:
        for hx in range(8, width - 40, 180):
            props.append(P("hedge", hx, d["bounds"]["bottom"] - 2, [0, 12, 48, 6]))
    for p in props:
        if "_base" not in p:
            p["_gen"] = True
    d["props"] = props
    json.dump(d, open(path, "w"), indent=1, ensure_ascii=False)
    return len(props)


def market_square():
    """Shopping Street's south plaza: two market runs under string lights, a flower kiosk, benches and planters."""
    out = []
    for x0 in (380, 900):
        for i in range(3):   # lamp posts carrying two spans of string lights
            out.append(P("lamp", x0 + i * 128, 604, [6, 66, 5, 4], glow=True, _base=604))
        for i in range(2):
            out.append({"sprite": "string_lights", "x": x0 + 10 + i * 128, "y": 540, "overhead": True, "_base": 572})
        for i in range(3):
            st = P(STALLS[(i + (x0 // 900)) % 3], x0 + 14 + i * 116, 648, [2, 27, 56, 10], show=MARKET_HOURS)
            st["_base"] = 648
            out.append(st)
    out.append(dict(P("kiosk_flower", 700, 640, [4, 18, 32, 11]), _base=640))
    for bx in (740, 792, 1230):
        out.append(dict(P("bench", bx, 684, [1, 12, 34, 7]), _base=684))
    for px in (560, 1120):
        out.append(dict(P("planter_long", px, 684, [2, 4, 72, 11]), _base=684))
    out.append(dict(P("bike_rack", 1290, 612, [1, 12, 52, 10]), _base=612))
    for tx in (40, 1360):
        out.append(dict(P("tree_round", tx, 626, [28, 84, 8, 6]), _base=626))
    return out


# heights of the v1 props (for re-anchoring legacy south-side dressing)
OLD_H = {"tree_round": 48, "tree_round_b": 48, "tree_tall": 56, "lamp": 48, "bench": 20, "planter": 24, "trash_bin": 18,
         "bike": 20, "metro_sign": 40, "cafe_board": 20, "umbrella_table": 36, "bus_stop": 44, "billboard": 56,
         "digital_sign": 40, "hydrant": 14, "cone": 12, "parking_meter": 22, "direction_sign": 40, "business_board": 52,
         "flagpole": 64, "fountain": 40, "flower_bed": 16}
SOLIDS = {"tree_round": [28, 84, 8, 6], "tree_round_b": [28, 84, 8, 6], "tree_tall": [14, 84, 6, 4], "lamp": [6, 66, 5, 4],
          "bench": [1, 12, 34, 7], "planter": [1, 18, 34, 8], "trash_bin": [1, 14, 16, 6], "bike": [2, 14, 32, 5],
          "bus_stop": [2, 34, 52, 8], "billboard": [30, 54, 8, 4], "digital_sign": [4, 38, 14, 6], "business_board": [2, 44, 40, 8],
          "flagpole": [0, 60, 6, 6], "fountain": [4, 22, 60, 16], "flower_bed": [0, 8, 36, 8], "metro_sign": [3, 42, 12, 6]}

if __name__ == "__main__":
    import sys
    for did in (sys.argv[1:] or ROWS):
        print(did, layout(did), "props")
