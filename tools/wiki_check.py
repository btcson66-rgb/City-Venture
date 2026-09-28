#!/usr/bin/env python3
"""Check that docs/wiki/ documents every art asset and every game data id.

The wiki is the contract between the gameplay track and the art track, so it must not fall behind the files.
This lists anything in game/assets/ or game/data/ that the wiki never mentions and exits non-zero if there is any.

    python3 tools/wiki_check.py            # report, exit 1 on gaps
    python3 tools/wiki_check.py --verbose  # also print counts per area
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
WIKI = os.path.join(ROOT, "docs", "wiki")

# Layered character/portrait files are documented by their parts, e.g. outfit_barista_feminine_top.png is covered
# when `barista` and `feminine` appear; hair_bob_back.png when `bob` appears.
LAYER_PREFIXES = ("body_", "hair_", "eyes_", "iris_", "brows_", "mouth_", "outfit_", "acc_", "head_")
LAYER_SUFFIXES = ("_back", "_front", "_top", "_bottom", "_shoes")
PRESENTATIONS = ("masculine", "feminine", "neutral")


def wiki_text() -> str:
    parts = []
    for p in sorted(glob.glob(os.path.join(WIKI, "*.md"))):
        with open(p, encoding="utf-8") as f:
            parts.append(f.read())
    return "\n".join(parts)


def tokens(text: str) -> set:
    """Every identifier-like word in the wiki (code spans and plain text alike)."""
    return set(re.findall(r"[A-Za-z0-9_]+", text))


def layer_parts(name: str) -> list:
    for pre in LAYER_PREFIXES:
        if name.startswith(pre):
            core = name[len(pre):]
            for suf in LAYER_SUFFIXES:
                if core.endswith(suf):
                    core = core[: -len(suf)]
            if pre == "acc_":
                return [core]
            bits = core.split("_")
            pres = [b for b in bits if b in PRESENTATIONS]
            rest = "_".join(b for b in bits if b not in PRESENTATIONS)
            return pres + ([rest] if rest else [])
    return [name]


def asset_gaps(words: set) -> tuple:
    gaps, count = [], 0
    for path in sorted(glob.glob(os.path.join(GAME, "assets", "**", "*.png"), recursive=True)):
        rel = os.path.relpath(path, os.path.join(GAME, "assets"))
        folder = rel.split(os.sep)[0]
        if folder in ("fonts", "audio"):
            continue
        count += 1
        name = os.path.splitext(os.path.basename(rel))[0]
        if name.endswith("_lights"):
            name = name[: -len("_lights")]
        if folder in ("characters", "portraits"):
            ok = all(p in words for p in layer_parts(name))
        else:
            ok = name in words
        if not ok:
            gaps.append("asset  " + rel)
    # tile atlas cells are named in atlas.json rather than as files
    with open(os.path.join(GAME, "assets", "tiles", "atlas.json"), encoding="utf-8") as f:
        for tile in json.load(f)["tiles"]:
            count += 1
            if tile not in words and not (tile.startswith(("floor_", "wall_")) and tile.split("_", 1)[1] in words):
                gaps.append("tile   " + tile)
    for path in sorted(glob.glob(os.path.join(GAME, "assets", "audio", "*", "*.ogg"))):
        count += 1
        name = os.path.splitext(os.path.basename(path))[0]
        if name not in words:
            gaps.append("audio  " + os.path.relpath(path, os.path.join(GAME, "assets")))
    return gaps, count


def data_gaps(words: set) -> tuple:
    gaps, count = [], 0

    def need(kind: str, ident: str) -> None:
        nonlocal count
        count += 1
        if ident not in words:
            gaps.append("%-6s %s" % (kind, ident))

    def ids(folder: str) -> list:
        out = []
        for p in sorted(glob.glob(os.path.join(GAME, "data", folder, "*.json"))):
            with open(p, encoding="utf-8") as f:
                out.append(json.load(f)["id"])
        return out

    for folder in ("npcs", "buildings", "districts", "products", "suppliers", "companies", "businesses", "regions",
                   "events", "jobs"):
        for i in ids(folder):
            need(folder[:6], i)
    with open(os.path.join(GAME, "data", "city", "aurelia.json"), encoding="utf-8") as f:
        for d in json.load(f)["districts"]:
            need("city", d["id"])
    with open(os.path.join(GAME, "data", "story", "chapters.json"), encoding="utf-8") as f:
        for c in json.load(f)["chapters"]:
            need("story", c["id"])
    with open(os.path.join(GAME, "data", "character", "options.json"), encoding="utf-8") as f:
        opts = json.load(f)
    for group in ("presentations", "face_shapes", "hairstyles", "hair_colors", "skin_tones", "eye_shapes", "eye_colors",
                  "eyebrows", "mouths", "outfits", "accessories"):
        for o in opts[group]:
            need("option", o["id"])
    with open(os.path.join(GAME, "data", "economy", "saas.json"), encoding="utf-8") as f:
        for i in json.load(f)["ideas"]:
            need("saas", i["id"])
    with open(os.path.join(GAME, "data", "economy", "staff.json"), encoding="utf-8") as f:
        for r in json.load(f)["roles"]:
            need("staff", r)
    return gaps, count


def main() -> int:
    words = tokens(wiki_text())
    a_gaps, a_count = asset_gaps(words)
    d_gaps, d_count = data_gaps(words)
    if "--verbose" in sys.argv:
        print("checked %d assets and %d data ids against %d wiki pages" %
              (a_count, d_count, len(glob.glob(os.path.join(WIKI, "*.md")))))
    gaps = a_gaps + d_gaps
    if gaps:
        print("Not documented in docs/wiki/ (%d):" % len(gaps))
        for g in gaps:
            print("  " + g)
        return 1
    print("wiki_check: OK (%d assets, %d data ids)" % (a_count, d_count))
    return 0


if __name__ == "__main__":
    sys.exit(main())
