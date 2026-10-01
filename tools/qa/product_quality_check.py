from pathlib import Path
import json,subprocess
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
rows=json.loads((ROOT/"docs/art_sources/product_quality_20261001/manifest.json").read_text())
for row in rows:
    n=ROOT/"game/assets"/(row["asset"]+".png");d=ROOT/"game/assets/world_detail"/(row["asset"]+".png")
    a=Image.open(n).convert("RGBA");b=Image.open(d).convert("RGBA");w,h=row["size"]
    assert a.size==(w,h) and b.size==(w*4,h*4),row
    assert Path(str(n)+".import").exists() and Path(str(d)+".import").exists(),row
    if not row["asset"].startswith("ui/"):
        assert a.getchannel("A").getextrema()[0]==0 and b.getchannel("A").getextrema()[0]==0,row
        assert a.getchannel("A").getbbox() is not None,row
    if row["frames"]==4:
        for f in range(4):
            assert a.crop((f*w//4,0,(f+1)*w//4,h)).getchannel("A").getbbox(),row
            assert b.crop((f*w,0,(f+1)*w,h*4)).getchannel("A").getbbox(),row
for name in ["app_icon","app_icon_1024"]:
    path="game/assets/ui/"+name+".png"
    original=subprocess.check_output(["git","show","HEAD:"+path],cwd=ROOT)
    assert (ROOT/path).read_bytes()==original,"App identity changed"
protected=subprocess.check_output(["git","diff","--name-only","HEAD","--","game/scripts","game/data","game/tests","game/autoload"],cwd=ROOT,text=True)
assert not protected.strip(),protected
print("product_quality_check: 14 native/detail contracts, transparency, 4-frame layouts/imports OK; app identity/gameplay unchanged")

