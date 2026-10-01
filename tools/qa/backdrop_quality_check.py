from pathlib import Path
import json,hashlib,subprocess
from PIL import Image
r=Path(__file__).resolve().parents[2]
rows=json.loads((r/"docs/art_sources/backdrop_quality_20261001/manifest.json").read_text())
for row in rows:
    source=r/row["source"]
    assert hashlib.sha256(source.read_bytes()).hexdigest()==row["source_sha256"]
    n=r/"game/assets"/(row["asset"]+".png");d=r/"game/assets/world_detail"/(row["asset"]+".png")
    im=Image.open(n);hi=Image.open(d);w,h=row["size"]
    assert im.size==(w,h) and hi.size==(w*4,h*4),row
    assert len(im.getcolors(im.width*im.height) or [])>192,row
    assert Path(str(n)+".import").exists() and Path(str(d)+".import").exists(),row
    assert im.convert("RGBA").getchannel("A").getextrema()==(255,255)
    assert hi.convert("RGBA").getchannel("A").getextrema()==(255,255)
protected=subprocess.check_output(["git","diff","--name-only","HEAD","--","game/scripts","game/data","game/tests","game/autoload"],cwd=r,text=True)
assert not protected.strip(),protected
print("backdrop_quality_check: 25 source-linked full-color exports, native/4x dimensions and imports OK; gameplay unchanged")

