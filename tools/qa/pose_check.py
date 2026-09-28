#!/usr/bin/env python3
"""Check character pose art the way the game assembles it (autoload/art.gd → character_layers).

Composes every outfit × presentation for every pose, direction and frame the game plays, and reports:
  missing   a layer has no <layer>_<pose>.png (the rig would stay on the walk sheet)
  gap       an empty row splits the character in two (e.g. a breathing frame shifted by 1 px)
  float     a separate piece of 3+ px not attached to the body (a hand or tie drifting off)
  skin      more bare torso than the same direction's walk frame (a top layer that doesn't cover)
  hole      a layer gets a 1 px transparent seam of 4+ px that its walk frame doesn't have

    python3 tools/qa/pose_check.py            # summary; exit 1 when anything is found
    python3 tools/qa/pose_check.py --list     # every finding
"""
import collections
import itertools
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CH = os.path.join(ROOT, "game", "assets", "characters")
# frames the game actually plays per pose (scripts/world/character_rig.gd → POSES); check both breathing frames
# even while the rig holds one, so the art is ready when it goes back to two
POSES = {"": 4, "sit": 2, "idle": 2, "phone": 2, "interact": 2, "carry": 4}
DIRS = ("down", "side", "up")
_cache = {}


def sheet(name):
    if name not in _cache:
        p = os.path.join(CH, name + ".png")
        _cache[name] = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    return _cache[name]


def cell(name, row, f):
    im = sheet(name)
    return None if im is None else im.crop((f * 32, row * 48, f * 32 + 32, row * 48 + 48))


def layers(pres, outfit, hair="buzz", face="round"):
    base = "outfit_%s_%s" % (outfit, pres)
    L = ["hair_%s_back" % hair, "body_%s_%s" % (pres, face), base + "_bottom"]
    if sheet(base + "_bottom_detail") is not None:
        L.append(base + "_bottom_detail")
    L += [base + "_shoes", base + "_top"]
    if sheet(base + "_top_detail") is not None:
        L.append(base + "_top_detail")
    return L + ["eyes_round", "iris_round", "brows_straight", "mouth_smile", "hair_%s_front" % hair]


def compose(names, pose, row, f):
    out, parts = Image.new("RGBA", (32, 48)), {}
    for n in names:
        im = cell(n + ("_" + pose if pose else ""), row, f)
        if im is None:
            return None, n
        out.alpha_composite(im)
        parts[n] = im
    return out, parts


def empty_rows(a):
    px = a.load()
    rows = [sum(1 for x in range(32) if px[x, y]) for y in range(48)]
    return [y for y in range(1, 47) if rows[y] == 0 and any(rows[:y]) and any(rows[y + 1:])]


def pieces(a):
    px, seen, sizes = a.load(), set(), []
    for y, x in itertools.product(range(48), range(32)):
        if px[x, y] and (x, y) not in seen:
            stack, size = [(x, y)], 0
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                size += 1
                for dx, dy in itertools.product((-1, 0, 1), repeat=2):
                    n = (cx + dx, cy + dy)
                    if 0 <= n[0] < 32 and 0 <= n[1] < 48 and px[n] and n not in seen:
                        seen.add(n)
                        stack.append(n)
            sizes.append(size)
    return sorted(sizes, reverse=True)


def bare_torso(parts, body):
    b = parts[body].getchannel("A").load()
    cover = Image.new("L", (32, 48))
    for n, im in parts.items():
        if n.startswith(("outfit_", "hair_")):
            cover.paste(255, mask=im.getchannel("A"))
    c = cover.load()
    return sum(1 for y in range(18, 36) for x in range(32) if b[x, y] and not c[x, y])


def seam(im):
    px = im.getchannel("A").load()
    rows = collections.Counter(y for y in range(1, 47) for x in range(32) if not px[x, y] and px[x, y - 1] and px[x, y + 1])
    return max(rows.values()) if rows else 0


def main():
    outfits = sorted({f[len("outfit_"):].rsplit("_", 2)[0] for f in os.listdir(CH)
                      if f.startswith("outfit_") and f.endswith("_top.png")})
    found = collections.defaultdict(list)
    for outfit, pres in itertools.product(outfits, ("masculine", "feminine", "neutral")):
        names = layers(pres, outfit)
        body = names[1]
        for row, d in enumerate(DIRS):
            walk, wparts = compose(names, "", row, 0)
            base_skin = bare_torso(wparts, body)
            for pose, nf in POSES.items():
                if not pose:
                    continue
                for f in range(nf):
                    im, parts = compose(names, pose, row, f)
                    tag = "%s/%s %s %s f%d" % (outfit, pres, pose, d, f + 1)
                    if im is None:
                        found["missing"].append("%s: %s_%s" % (tag, parts, pose))
                        continue
                    a = im.getchannel("A")
                    g = empty_rows(a)
                    if g:
                        found["gap"].append("%s y=%s" % (tag, g))
                    p = pieces(a)
                    if len(p) > 1 and p[1] >= 3:
                        found["float"].append("%s pieces=%s" % (tag, p[:3]))
                    if pose != "sit":   # sitting lowers the face into the torso band; compare standing poses only
                        s = bare_torso(parts, body) - base_skin
                        if s > 8:
                            found["skin"].append("%s +%dpx" % (tag, s))
    # per-layer seams for every layer that has pose sheets (hair and accessories included)
    for f in sorted(os.listdir(CH)):
        base = f[:-4]
        if not f.endswith(".png") or any(base.endswith("_" + p) for p in POSES if p) or base.startswith("npc_"):
            continue
        for pose, nf in POSES.items():
            if not pose or sheet(base + "_" + pose) is None:
                continue
            for row, fr in itertools.product(range(3), range(nf)):
                w, pz = seam(cell(base, row, 0)), seam(cell(base + "_" + pose, row, fr))
                if pz >= w + 4:
                    found["hole"].append("%s_%s %s f%d: %d→%d px" % (base, pose, DIRS[row], fr + 1, w, pz))
    if not found:
        print("pose_check: OK")
        return 0
    for kind in ("missing", "gap", "float", "skin", "hole"):
        items = found.get(kind, [])
        if not items:
            continue
        by = collections.Counter(" ".join(s.split(" ")[1:4]).split(":")[0] if kind != "hole" else
                                 s.split(" ")[0].rsplit("_", 1)[1] + " " + " ".join(s.split(" ")[1:3]).rstrip(":")
                                 for s in items)
        print("%-8s %4d  %s" % (kind, len(items), ", ".join("%s ×%d" % kv for kv in by.most_common(6))))
        if "--list" in sys.argv:
            for s in items:
                print("         " + s)
    return 1


if __name__ == "__main__":
    sys.exit(main())
