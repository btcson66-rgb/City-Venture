from pathlib import Path
import subprocess,json,shutil,io
from PIL import Image,ImageDraw
r=Path(".");e=r/"evidence/20261001_product_quality";(e/"logs").mkdir(exist_ok=True)
for path in r.glob("product-*.log"):
    assert "ERROR:" not in path.read_text(encoding="utf-8-sig",errors="replace"),path
    shutil.copy2(path,e/"logs"/path.name)
for phase in ["before","after"]:
    x=json.loads((e/phase/"walkthrough_result.json").read_text(encoding="utf-8"))
    assert x["failures"]==[] and x["screenshots"]==53 and x["steps"]==63,x
for name in ["07_district_riverside_south.png","11_district_startup_hub_south.png","24_interior_riverside_apartment.png"]:
    if not (e/"before/screenshots"/name).exists():continue
    a=Image.open(e/"before/screenshots"/name);b=Image.open(e/"after/screenshots"/name)
    o=Image.new("RGB",(a.width*2,a.height+24),"#102035");o.paste(a,(0,24));o.paste(b,(a.width,24))
    d=ImageDraw.Draw(o);d.text((8,6),"BEFORE - actual runtime",fill="white");d.text((a.width+8,6),"AFTER - actual runtime",fill="white")
    o.save(e/("compare_"+name))
names=["coffee","desk_lamp","earbuds","parcel","phone_stand","water_bottle"]
sheet=Image.new("RGB",(900,320),"#102035");d=ImageDraw.Draw(sheet)
for i,name in enumerate(names):
    path="game/assets/props/product_"+name+".png"
    before=Image.open(io.BytesIO(subprocess.check_output(["git","show","HEAD:"+path]))).convert("RGBA").resize((128,128),Image.Resampling.NEAREST)
    after=Image.open(path).convert("RGBA").resize((128,128),Image.Resampling.NEAREST)
    x=i*150;sheet.paste(before,(x+10,24),before);sheet.paste(after,(x+10,180),after)
    d.text((x+3,3),name+" BEFORE",fill="white");d.text((x+3,158),"AFTER native x8",fill="white")
sheet.save(e/"compare_product_sprites.png")
imports=[p for p in subprocess.check_output(["git","ls-files","game/assets"],text=True).splitlines() if p.endswith(".import")]
for i in range(0,len(imports),100):subprocess.run(["git","restore","--"]+imports[i:i+100],check=True)
print("product evidence archived; tracked import churn restored")
