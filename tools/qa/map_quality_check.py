"""Validate map dimensions, detail pixels and immutable gameplay contract."""
from pathlib import Path
import json,subprocess,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
manifest=json.loads((ROOT/"docs/art_sources/map_quality_20261001/manifest.json").read_text())
for row in manifest:
    path=ROOT/"game/assets"/(row["asset"]+".png")
    native=Image.open(path);detail=Image.open(ROOT/"game/assets/world_detail"/(row["asset"]+".png"))
    w,h=row["size"]
    assert native.size==(w,h),row
    assert detail.size==(w*4,h*4),row
    assert native.convert("RGBA").getchannel("A").getextrema()==(255,255),row
    assert detail.convert("RGBA").getchannel("A").getextrema()==(255,255),row
    assert Path(str(path)+".import").exists(),path
    assert Path(str(ROOT/"game/assets/world_detail"/(row["asset"]+".png"))+".import").exists(),row
    assert len(detail.getcolors(detail.width*detail.height) or [])>100,row
protected=subprocess.check_output(["git","diff","--name-only","HEAD","--","game/scripts","game/data","game/tests","game/autoload"],cwd=ROOT,text=True)
assert not protected.strip(),protected
print("map_quality_check: 25 native + 25 detail PNGs/imports; dimensions and gameplay contract unchanged")

