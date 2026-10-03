"""Extract translatable text from the game into gettext catalogues.

  python3 tools/i18n_extract.py            # write game/i18n/messages.pot + <locale>.po, report coverage
  python3 tools/i18n_extract.py --check    # exit 1 if any msgid lacks a zh_TW translation

Source language is English. Translations are authored in tools/i18n/<locale>.json ({msgid: msgstr});
zh_CN is generated from zh_TW with OpenCC (Taiwan -> Mainland phrasing) unless tools/i18n/zh_CN.json
overrides an entry. Brand names that should stay English are simply translated to themselves.
"""
from __future__ import annotations

import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GAME = os.path.join(ROOT, "game")
SRC = os.path.join(ROOT, "tools", "i18n")
OUT = os.path.join(GAME, "i18n")

SKIP_LINE = re.compile(r'push_warning|push_error|print\(|log_line|assert\(|get_node|find_child|has_node|'
                       r'\.name\s*==|\.name\s*=|InputMap|load\(|preload\(|Art\.tex|Art\.icon|"--|b\.name|tooltip_text = o|'
                       r'\.set_(?:stylebox|color|constant|font|font_size|icon)\(|for sb_name in|ScrollBar"\]|^\s*"done": ')
DATA_KEYS = {"options", "audience", "budget","name", "text", "label", "detail", "outcome", "lines", "risks", "strengths", "industries", "goal", "blurb",
             "skip_text", "audiences", "slogan", "visual", "tone",
             "pitch", "title", "archetype", "entry_requirement", "role", "outfits_planned", "accessories_planned",
             "headlines", "headlines_incident", "headlines_after", "return_reasons_defective", "return_reasons_normal", "subtitle", "category", "quality_req",
             "sub", "1", "2", "3", "4", "5", "reason", "hint", "desc", "description", "item", "sign", "sign_text", "employer", "requires_text", "needs_text", "agent_line", "what", "why", "good", "effect", "licence", "location", "unit_label", "client_name"}
DATA_ID_KEYS = {"revenue_models", "cost_types", "growth_paths"}   # snake_case ids shown as words
SKIP_DATA_FILES = ("companies/",)                # company names stay as they are (NPC names map to themselves)
SKIP_KEYS_IN = {"economy/marketplace.json": {"customer_first_names", "customer_last_initials"}}


def is_text(v: str) -> bool:
    if re.fullmatch(r"[a-z0-9_./:#%,\-]*", v):
        return False
    if v.startswith(("res://", "user://")):
        return False
    if re.fullmatch(r"[A-Za-z0-9]+_", v) or re.fullmatch(r"[A-Z]{1,5}-?%[0-9]*d", v):
        return False
    words = re.sub(r"%[-+0-9.]*[sdfx%]", "", v)
    return re.search(r"[A-Za-z]{2,}", words) is not None


def gd_literals(line: str):
    i = 0
    while i < len(line):
        c = line[i]
        if c == "#":
            return
        if c == '"':
            j = i + 1
            while j < len(line):
                if line[j] == "\\":
                    j += 2
                    continue
                if line[j] == '"':
                    break
                j += 1
            yield line[i + 1:j]
            i = j + 1
            continue
        i += 1


def unescape(s: str) -> str:
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in s else s


def extract() -> dict:
    ids: dict[str, set] = {}
    files = [f for f in glob.glob(os.path.join(GAME, "**", "*.gd"), recursive=True)
             if "/tests/" not in f.replace("\\", "/") and not f.endswith(("i18n.gd", "data_db.gd", "bug_report.gd"))]
    for f in sorted(files):
        rel = os.path.relpath(f, GAME).replace("\\", "/")
        for n, line in enumerate(open(f, encoding="utf-8"), 1):
            if line.strip().startswith("#") or SKIP_LINE.search(line):
                continue
            for lit in gd_literals(line):
                v = unescape(lit)
                if is_text(v):
                    ids.setdefault(v, set()).add("%s:%d" % (rel, n))
    # facade sign texts live with the building art (read, never written: assets/ is the art track's)
    data_files = sorted(glob.glob(os.path.join(GAME, "data", "**", "*.json"), recursive=True)) + \
        [os.path.join(GAME, "assets", "buildings", "buildings_meta.json")]
    for f in data_files:
        if not os.path.exists(f):
            continue
        rel = os.path.relpath(f, os.path.join(GAME, "data")).replace("\\", "/")
        if rel.startswith(SKIP_DATA_FILES):
            continue
        skip_keys = SKIP_KEYS_IN.get(rel, set())

        def walk(o, key):
            if isinstance(o, dict):
                for k, v in o.items():
                    if k not in skip_keys:
                        walk(v, k)
            elif isinstance(o, list):
                for v in o:
                    walk(v, key)
            elif isinstance(o, str) and key in DATA_KEYS and is_text(o):
                ids.setdefault(o, set()).add("data/" + rel)
            elif isinstance(o, str) and key == "role" and rel.startswith("npcs/") and o.strip():
                ids.setdefault(o, set()).add("data/" + rel)   # one-word roles ("barista", "friend") are shown too
            elif isinstance(o, str) and key in DATA_ID_KEYS:
                ids.setdefault(o.replace("_", " "), set()).add("data/" + rel)
        walk(json.load(open(f, encoding="utf-8")), "")
    return ids


def po_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def write_po(path: str, locale: str, ids: dict, tr: dict) -> None:
    lines = ['msgid ""', 'msgstr ""', '"Project-Id-Version: CITY VENTURE\\n"', '"MIME-Version: 1.0\\n"',
             '"Content-Type: text/plain; charset=UTF-8\\n"', '"Content-Transfer-Encoding: 8bit\\n"']
    if locale:
        lines.append('"Language: %s\\n"' % locale)
    lines.append("")
    for msgid in sorted(ids):
        refs = sorted(ids[msgid])
        lines.append("#: " + " ".join(refs[:4]))
        lines.append('msgid "%s"' % po_escape(msgid))
        lines.append('msgstr "%s"' % po_escape(tr.get(msgid, "") if locale else ""))
        lines.append("")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))


def load_json(name: str) -> dict:
    p = os.path.join(SRC, name)
    if not os.path.exists(p):
        return {}
    d = {}
    for f in sorted(glob.glob(p.replace(".json", "*.json"))):   # zh_TW.json, zh_TW_2.json, ...
        d.update(json.load(open(f, encoding="utf-8")))
    return d


def to_simplified(tw: dict) -> dict:
    try:
        import opencc  # opencc-python-reimplemented
        cc = opencc.OpenCC("tw2sp")
    except Exception:
        print("i18n: OpenCC missing (pip install opencc-python-reimplemented); zh_CN left untranslated")
        return {}
    return {k: cc.convert(v) for k, v in tw.items()}


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    ids = extract()
    write_po(os.path.join(OUT, "messages.pot"), "", ids, {})
    tw = load_json("zh_TW.json")
    cn = to_simplified(tw)
    cn.update(load_json("zh_CN.json"))
    write_po(os.path.join(OUT, "zh_TW.po"), "zh_TW", ids, tw)
    write_po(os.path.join(OUT, "zh_CN.po"), "zh_CN", ids, cn)
    missing = [m for m in ids if not tw.get(m)]
    stale = [m for m in tw if m not in ids]
    print("i18n: %d msgids · zh_TW translated %d · missing %d · unused %d" % (len(ids), len(ids) - len(missing), len(missing), len(stale)))
    if "--missing" in sys.argv:
        json.dump({m: "" for m in sorted(missing)}, open(os.path.join(SRC, "_missing.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    if "--check" in sys.argv and missing:
        for m in missing[:40]:
            print("  missing:", m)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
