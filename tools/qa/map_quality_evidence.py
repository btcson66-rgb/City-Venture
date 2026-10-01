from pathlib import Path
import subprocess,json,shutil
from PIL import Image,ImageDraw
r=Path(".");e=r/"evidence/20261001_map_quality"
(e/"logs").mkdir(exist_ok=True)
for f in ["map-before-import.log","map-before-shots.log","map-after-import.log","map-tests.log","map-gallery.log","map-gallery-zhTW.log","map-after-shots.log"]:
    shutil.copy2(r/f,e/"logs"/f)
for f in ["26_city_map.png","27_world_map.png"]:
    a=Image.open(e/"before/screenshots"/f).convert("RGB");b=Image.open(e/"after/screenshots"/f).convert("RGB")
    o=Image.new("RGB",(a.width+b.width,max(a.height,b.height)+24),"#102035");o.paste(a,(0,24));o.paste(b,(a.width,24))
    d=ImageDraw.Draw(o);d.text((8,6),"BEFORE - native runtime",fill="white");d.text((a.width+8,6),"AFTER - native runtime",fill="white")
    o.save(e/("compare_"+("city_map" if "city" in f else "world_map")+".png"))
for phase in ["before","after"]:
    result=json.loads((e/phase/"walkthrough_result.json").read_text(encoding="utf-8"))
    assert result["failures"]==[],result
    assert result["screenshots"]==53 and result["steps"]==63,result
p=r/"docs/art_sources/map_quality_20261001/generated_manifest.json"
rows=json.loads(p.read_text(encoding="utf-8"))
for row in rows:row["source"]="originals/"+row["name"]+".png";row.pop("path",None)
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
imports=subprocess.check_output(["git","ls-files","game/assets"],text=True).splitlines()
imports=[p for p in imports if p.endswith(".import")]
for i in range(0,len(imports),100):subprocess.run(["git","restore","--"]+imports[i:i+100],check=True)
print("evidence archived; tracked import churn restored, new imports retained")

