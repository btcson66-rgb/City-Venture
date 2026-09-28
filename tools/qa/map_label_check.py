#!/usr/bin/env python3
"""Check that the blank "label spots" painted into the map boards match where the game draws its labels.

The city and world map boards (game/assets/city_map/board.png, world_map/board.png) have flat dark patches where
the game puts live, translatable labels (data/city/aurelia.json and data/regions/*.json → board.label, plus the
metro label and legend in aurelia.json → board_extra). The game draws each label card over its spot, so:

  orphan    a painted patch that no label covers: an empty dark box on the map
  overhang  a patch that sticks out past its label by more than 3 px on some side: a dark rim around the card

    python3 tools/qa/map_label_check.py      # exit 1 when anything is found
"""
import glob
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")
SLACK = 3
MIN_PATCH = 150   # px; smaller flat areas are part of the picture


def to_map(r, box, map_w):
    s = map_w / box[2]
    return ((r[0] - box[0]) * s, (r[1] - box[1]) * s, (r[2] - box[0]) * s, (r[3] - box[1]) * s)


def patches(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    counts = {}
    for y in range(h):
        for x in range(w):
            counts[px[x, y]] = counts.get(px[x, y], 0) + 1
    fill = max(counts, key=counts.get)   # the flat label-spot colour is the most common one
    seen, out = set(), []
    for y in range(h):
        for x in range(w):
            if px[x, y] != fill or (x, y) in seen:
                continue
            stack, xs, ys = [(x, y)], [], []
            seen.add((x, y))
            while stack:
                a, b = stack.pop()
                xs.append(a)
                ys.append(b)
                for n in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n] == fill:
                        seen.add(n)
                        stack.append(n)
            if len(xs) >= MIN_PATCH:
                out.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1))
    return out


def check(name, board, labels):
    found = []
    for p in patches(board):
        best = None
        for lname, r in labels:
            ox = min(p[2], r[2]) - max(p[0], r[0])
            oy = min(p[3], r[3]) - max(p[1], r[1])
            if ox > 0 and oy > 0 and (best is None or ox * oy > best[0]):
                best = (ox * oy, lname, r)
        if best is None:
            found.append("orphan    %s patch at %s (map px) has no label over it" % (name, p))
            continue
        _, lname, r = best
        over = {"left": r[0] - p[0], "top": r[1] - p[1], "right": p[2] - r[2], "bottom": p[3] - r[3]}
        sides = ["%s %d" % (k, round(v)) for k, v in over.items() if v > SLACK]
        if sides:
            found.append("overhang  %s patch %s sticks out past '%s' %s by: %s px" %
                         (name, p, lname, tuple(round(v) for v in r), ", ".join(sides)))
    return found


def main():
    city = json.load(open(os.path.join(GAME, "data", "city", "aurelia.json"), encoding="utf-8"))
    cbox, wbox = (14, 155, 976, 650), (12, 150, 928, 395)   # MAP_BOX in city_map_modal.gd / world_map_modal.gd
    labels = [(d["id"], to_map(d["board"]["label"], cbox, 458)) for d in city["districts"] if "board" in d]
    extra = city.get("board_extra", {})
    if "metro" in extra:
        labels.append(("metro", to_map(extra["metro"]["label"], cbox, 458)))
    if "legend" in extra:
        labels.append(("legend", to_map(extra["legend"], cbox, 458)))
    found = check("city_map", os.path.join(GAME, "assets", "city_map", "board.png"), labels)
    regions = []
    for f in sorted(glob.glob(os.path.join(GAME, "data", "regions", "*.json"))):
        r = json.load(open(f, encoding="utf-8"))
        regions.append((r["id"], to_map(r["board"]["label"], wbox, 600)))
    found += check("world_map", os.path.join(GAME, "assets", "world_map", "board.png"), regions)
    if not found:
        print("map_label_check: OK")
        return 0
    print("\n".join(found))
    return 1


if __name__ == "__main__":
    sys.exit(main())
