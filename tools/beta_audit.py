"""Reject unfinished text reachable by players; inactive data stays available for future content."""
from __future__ import annotations

import json
import re
from pathlib import Path

from i18n_extract import DATA_KEYS, DATA_ID_KEYS, gd_literals, unescape

ROOT = Path(__file__).resolve().parents[1]
BANNED = re.compile(r"\bplanned\b|\bP[123]\b|not in this build|later build|coming soon|placeholder|not part of this build", re.I)
# Exact text, not substring exemptions: these describe a completed route or a shipment delay.
ALLOW = {
    "Stops planned %d / %d  ·  route so far %.1f km": "Number of delivery stops already added to the route.",
    "All %d stops planned  ·  round trip %.1f km": "All delivery stops have been added to the route.",
    "They can ship it again, {days} days later than planned.": "A shipment is delayed relative to its original schedule.",
    "{supplier} sends new stock at no extra cost. It arrives {days} days later than planned.": "Replacement shipment delay, not unfinished functionality.",
}
VISIBLE_KEYS = DATA_KEYS | DATA_ID_KEYS | {"closed_reason"}


def visible_text(value, key="", path=""):
    if isinstance(value, dict):
        if value.get("status", "active") != "active":
            return
        for k, v in value.items():
            if k == "interior" and not value.get("enterable", True):
                continue
            yield from visible_text(v, k, path + "/" + k)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            yield from visible_text(v, key, path + "/" + str(i))
    elif isinstance(value, str) and key in VISIBLE_KEYS:
        yield path, value


def hits(text):
    return bool(BANNED.search(text)) and text not in ALLOW


def audit(root=ROOT):
    findings = []
    for f in sorted((root / "game/data").rglob("*.json")):
        for key, text in visible_text(json.loads(f.read_text(encoding="utf-8"))):
            if hits(text):
                findings.append((str(f.relative_to(root)) + key, text))
    for f in sorted((root / "game").rglob("*.gd")):
        if "tests" in f.relative_to(root / "game").parts:
            continue
        source = f.read_text(encoding="utf-8")
        lines = source.splitlines()
        for n, line in enumerate(lines, 1):
            # Helpers translate their argument just like labels; scan every presentation helper.
            if line.lstrip().startswith("#") or not re.search(r'I18n\.t\(|UIK\.(?:label|wrap|chip|title|button|kv|tip|label_tip)\(', line):
                continue
            for literal in gd_literals(line):
                text = unescape(literal)
                if hits(text):
                    findings.append((str(f.relative_to(root)) + ":" + str(n), text))
        # Calls may put their first string argument on the next line.
        clean = "\n".join("" if line.lstrip().startswith("#") else line for line in lines)
        for match in re.finditer(r'(?:I18n\.t|UIK\.(?:label|wrap|chip|title|button|kv|tip|label_tip))\(\s*\n\s*("(?:\\.|[^"\\])*")', clean):
            text = unescape(match.group(1)[1:-1])
            if hits(text):
                n = clean.count("\n", 0, match.start()) + 1
                findings.append((str(f.relative_to(root)) + ":" + str(n), text))
    return findings


if __name__ == "__main__":
    found = audit()
    for where, text in found:
        print(f"{where}: {text}")
    print(f"beta_audit: {len(found)} hits")
    raise SystemExit(bool(found))
