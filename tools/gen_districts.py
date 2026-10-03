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
    # "name|fallback": the facade Codex is drawing, and what stands in until it lands (re-run this script then)
    "old_town": ["rowhouse_brick|apartment_mid", "@okafor_lettings", "arcade_arches|retail_arcade", "@corner_cafe_unit",
                 "clock_tower|civic_annex", "@old_town_studio", "rowhouse_brick|riverside_walkup"],
    # fillers: no fallback that carries a painted sign board (a filler's sign text comes from the facade art)
    "harbor": ["warehouse_shed|shop_row_awning", "@pier7_warehouse", "cold_store|retail_arcade", "@dockside_motors",
               "container_stack|riverside_walkup", "@harbor_point_fitness", "@customs_house"],
}
LABELS = {
    "riverside": {"east": "STARTUP HUB →"}, "startup_hub": {"west": "← RIVERSIDE"},
    "civic_center": {"east": "FINANCIAL →", "west": "← SHOPPING ST"}, "financial": {"west": "← CIVIC CENTER"},
    "shopping_street": {"east": "CIVIC CENTER →", "west": "← OLD TOWN"},
    "old_town": {"east": "SHOPPING ST →"},
    "harbor": {},
}
# weekend market (Shopping Street): stalls are out Sat/Sun 09:00-18:00, packed away otherwise
MARKET_HOURS = {"days": "sat,sun", "from": "09:00", "to": "18:00"}
STALLS = ["market_stall_rose", "market_stall_sage", "market_stall_cream"]


def has_prop(name):
    return os.path.exists(os.path.join(PROPS, name + ".png"))


def prop_size(name):
    """Design (footprint) size: board-converted sprites may overhang it (assets/sprite_meta.json)."""
    from PIL import Image
    im = Image.open(os.path.join(PROPS, name + ".png"))
    m = SPRITE_META.get("props/" + name, {})
    return int(m.get("dw", im.width)), int(m.get("dh", im.height - int(m.get("top", 0))))


SPRITE_META = json.load(open(os.path.join(os.path.dirname(PROPS), "sprite_meta.json"))) \
    if os.path.exists(os.path.join(os.path.dirname(PROPS), "sprite_meta.json")) else {}


def P(name, x, base_y, solid=None, **kw):
    """A prop standing on base_y. "name|fallback": use the fallback sprite's size until the new sprite exists."""
    fb = ""
    if "|" in name:
        name, fb = name.split("|")
    w, h = prop_size(name if has_prop(name) or not fb else fb)
    d = {"sprite": name, "x": int(x), "y": int(base_y - h)}
    if fb:
        d["fallback"] = fb
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
            if sprite not in META:
                sprite = b["exterior"]["fallback"]
            b["exterior"]["x"] = x
            json.dump(b, open(os.path.join(DATA, "buildings", bid + ".json"), "w"), indent=1, ensure_ascii=False)
            m = META[sprite]
            doors.append((x + m["door"][0] + m["door"][2] / 2, b["type"], bid, x, m))
        else:
            sprite, _, fb = item.partition("|")
            f = {"sprite": sprite, "x": x}
            if fb:
                f["fallback"] = fb
                if sprite not in META:
                    sprite = fb
            fillers.append(f)
            m = META[sprite]
            door = m.get("door") or [m["size"][0] // 2 - 10, 0, 20, 0]   # fillers may have no door at all
            doors.append((x + door[0] + door[2] / 2, "filler", sprite, x, m))
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
            if did == "harbor":   # a working quay: a lamp every other bay instead of trees
                if k % 2 == 1:
                    props.append(P("harbor_lamp|lamp", px - 8, 384, [6, 66, 5, 4], glow=True))
            elif k % 2 == 0:
                props.append(P("tree_round" if (k // 2) % 3 else "tree_round_b", px - 32, 382, [28, 84, 8, 6]))
            elif did == "old_town":
                props.append(P("old_lamp|lamp", px - 8, 384, [6, 66, 5, 4], glow=True))
            else:
                props.append(P("lamp_banner", px - 8, 384, [6, 66, 5, 4], glow=True))
        px += 80
        k += 1
    for bx in range(28, width - 20, 36):
        if not near_door(bx, 18):
            props.append(P("mooring_bollard|bollard" if did == "harbor" else "bollard", bx, 386, [2, 11, 4, 3]))
    # --- per building dressing
    for (dx, typ, bid, bx, m) in doors:
        if typ == "own_cafe":   # the player's café: two bistro tables and a chalkboard
            props.append(P("cafe_chairs_bistro|umbrella_table", dx + 26, 366, [10, 30, 16, 6]))
            props.append(P("cafe_chairs_bistro|umbrella_table", dx + 66, 366, [10, 30, 16, 6]))
            props.append(P("cafe_board", dx - 30, 346, [2, 16, 12, 4]))
        elif typ == "lettings":
            props.append(P("planter_small", dx + 18, 342, [1, 14, 22, 6]))
        elif typ == "warehouse":   # pallets by the door (a parcel crate stands in for the pallet stack)
            props.append(P("pallet_stack|product_parcel", dx + 30, 350, [1, 12, 14, 4]))
            props.append(P("pallet_stack|product_parcel", dx + 46, 352, [1, 12, 14, 4]))
            props.append(P("pallet_stack|product_parcel", dx + 38, 338, solid=False))
        elif typ == "van_dealer":
            props.append(P("cone", dx - 44, 350, [1, 12, 10, 4]))
            props.append(P("cone", dx + 46, 350, [1, 12, 10, 4]))
            props.append(P("parking_meter", dx + 62, 350, [2, 18, 6, 4]))
        elif typ == "gym":
            props.append(P("bike_rack", dx - 66, 350, [1, 20, 52, 5]))
            props.append(P("planter_small", dx + 20, 342, [1, 14, 22, 6]))
        elif typ == "customs":
            props.append(P("planter", dx - 70, 346, [1, 18, 34, 8]))
            props.append(P("planter", dx + 36, 346, [1, 18, 34, 8]))
            props.append(P("flagpole", dx - 96, 344, [1, 60, 6, 5]))
        elif typ == "cafe":
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
            names = ["crate|product_parcel", "trash_bin", "cone"] if did == "harbor" else ["planter_small", "trash_bin", "bike"]
            props.append(P(rnd.choice(names), dx + rnd.randint(20, 40), 346, [1, 12, 16, 5]))
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
        if p.get("_era") or p.get("_gen") or name in ("railing", "hedge"):
            continue  # generated dressing is rebuilt below
        if p.get("_base", y_base + OLD_H.get(p["sprite"], 0)) < 470:
            continue  # north side regenerated above
        if name in ("lamp",):
            name = "lamp"
        try:
            w, h = prop_size(name if has_prop(name) else p.get("fallback", name))
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
    if did == "old_town" and not any(p.get("_base", 0) >= 470 for p in props):
        props += old_town_square()
    if did == "harbor":
        props += harbor_quay()   # rebuilt on every run (no _base): the quay has no hand-placed dressing to keep
    props += era_props(did)  # regenerated explicitly; retain conditions and far layer
    # river railing / hedges along the park
    if did == "riverside":
        for rx in range(0, width, 64):
            props.append(P("railing", rx, 656, [0, 10, 64, 4]))
        for hx in (120, 440, 1240, 1560):
            props.append(P("hedge", hx, 560, [0, 12, 48, 6]))
    elif did == "harbor":   # a safety rail along the quay edge, no hedges
        for rx in range(0, width, 64):
            props.append(P("railing", rx, 656, [0, 10, 64, 4]))
    else:
        for hx in range(8, width - 40, 180):
            props.append(P("hedge", hx, d["bounds"]["bottom"] - 2, [0, 12, 48, 6]))
    # the south squares are kept from the last run *and* regenerated: keep the regenerated one (it has its collision)
    last = {}
    for i, p in enumerate(props):
        last[(p["sprite"], p["x"], p["y"])] = i
    props = [p for i, p in enumerate(props) if last[(p["sprite"], p["x"], p["y"])] == i]
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


def old_town_square():
    """Old Town's south side: a small square round the fountain, a mural wall, a bookstall, benches under old lamps."""
    out = [dict(P("fountain", 600, 610, [4, 22, 60, 16]), _base=610)]
    for lx in (520, 700):
        out.append(dict(P("old_lamp|lamp", lx, 604, [6, 66, 5, 4], glow=True), _base=604))
    for bx in (540, 650):
        out.append(dict(P("bench", bx, 668, [1, 12, 34, 7]), _base=668))
    out.append(dict(P("mural_wall|billboard", 180, 600, [30, 54, 8, 4]), _base=600))
    out.append(dict(P("bookstall|kiosk_flower", 900, 640, [4, 18, 32, 11]), _base=640))
    out.append(dict(P("ivy_trellis|flower_bed", 330, 640, [0, 8, 36, 8]), _base=640))
    out.append(dict(P("ivy_trellis|flower_bed", 1040, 640, [0, 8, 36, 8]), _base=640))
    for tx in (60, 1160):
        out.append(dict(P("tree_round_b", tx, 626, [28, 84, 8, 6]), _base=626))
    out.append(dict(P("trash_bin", 760, 660, [1, 14, 16, 6]), _base=660))
    return out


def era_props(did):
    """Decorative era additions are rebuilt without borrowing business charging income."""
    if did == "riverside":
        return [{"sprite": "port_cranes_far", "x": 1050, "y": 694,
                 "if": "world_year>=3", "wall": True, "solid": False, "_era": True}]
    if did in ("shopping_street", "financial"):
        return [{"sprite": "ev_charger", "x": x, "y": 348,
                 "if": "world_year>=4", "solid": False, "_era": True} for x in (100, 180)]
    return []


def harbor_quay():
    """Harbor's south side: the quay apron with work lamps, mooring bollards along the edge, crate stacks, cones and a
    bench or two. Only props with an honest stand-in are placed (a parcel crate for crates, the street bollard and lamp).
    Waiting on art, added here when it lands: container_red/_blue/_green, pallet_stack, forklift, rope_coil, life_ring,
    crane_gantry (backdrop). Re-run this script then, so positions use the real sprite sizes."""
    out = []
    for lx in (180, 520, 860, 1250):
        out.append(P("harbor_lamp|lamp", lx, 612, [6, 66, 5, 4], glow=True))
    for bx in range(60, 1380, 132):
        out.append(P("mooring_bollard|bollard", bx, 642, [2, 11, 4, 3]))
    # crate stacks: two on the ground, one on top
    for cx in (300, 704, 1020):
        out.append(P("crate|product_parcel", cx, 626, [1, 12, 14, 4]))
        out.append(P("crate|product_parcel", cx + 18, 628, [1, 12, 14, 4]))
        out.append(P("crate|product_parcel", cx + 9, 614, solid=False))
    for cx in (450, 640, 950):
        out.append(P("cone", cx, 596, [1, 12, 10, 4]))
    for bx in (560, 1090):
        out.append(P("bench", bx, 636, [1, 12, 34, 7]))
    out.append(P("trash_bin", 780, 636, [1, 14, 16, 6]))
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
