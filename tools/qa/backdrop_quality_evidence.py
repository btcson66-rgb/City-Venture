from pathlib import Path
import subprocess,json,shutil
from PIL import Image,ImageDraw
r=Path(".");e=r/"evidence/20261001_backdrop_quality"
(e/"logs").mkdir(exist_ok=True)
for path in r.glob("backdrop-*.log"):
    text=path.read_text(encoding="utf-8-sig",errors="replace")
    assert "ERROR:" not in text,path
    shutil.copy2(path,e/"logs"/path.name)
for phase in ["before","after"]:
    report=json.loads((e/phase/"walkthrough_result.json").read_text(encoding="utf-8"))
    assert report["failures"]==[] and report["screenshots"]==53 and report["steps"]==63,report
for name in ["menu","creator_wardrobe","chapter_2","chapter_4","chapter_6","location_bloom_coffee","location_small_office"]:
    a=Image.open(e/"actual_before"/(name+".png")).convert("RGB")
    b=Image.open(e/"actual_after"/(name+".png")).convert("RGB")
    sheet=Image.new("RGB",(a.width*2,a.height+24),"#102035");sheet.paste(a,(0,24));sheet.paste(b,(a.width,24))
    d=ImageDraw.Draw(sheet);d.text((8,6),"BEFORE - native runtime",fill="white");d.text((a.width+8,6),"AFTER - native runtime",fill="white")
    sheet.save(e/("compare_"+name+".png"))
imports=subprocess.check_output(["git","ls-files","game/assets"],text=True).splitlines()
imports=[x for x in imports if x.endswith(".import")]
for i in range(0,len(imports),100):subprocess.run(["git","restore","--"]+imports[i:i+100],check=True)
print("backdrop evidence: 2x18 actual presentations, 7 comparisons, before/after 53-shot tours; import churn restored")

