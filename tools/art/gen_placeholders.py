"""Generate every CITY VENTURE placeholder asset into game/assets/.
Usage: python3 tools/art/gen_placeholders.py [out_dir]
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import chars
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "game", "assets")
only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
def want(k): return only is None or k in only
if want("chars"): chars.generate(OUT)
try:
    import env
    if want("env"): env.generate(OUT)
except ImportError:
    pass
try:
    import ui
    if want("ui"): ui.generate(OUT)
except ImportError:
    pass
try:
    import maps
    if want("maps"): maps.generate(OUT)
except ImportError:
    pass
print("done ->", OUT)
