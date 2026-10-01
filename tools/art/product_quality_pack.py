"""Pack six original item sprites and extend existing procedural effects as SVG."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageOps,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/"docs/art_sources/product_quality_20261001";AS=ROOT/"game/assets"
manifest=[]
rows=json.loads((SRC/"generated_manifest.json").read_text(encoding="utf-8"))
review=Image.new("RGB",(900,240),"#102035");d=ImageDraw.Draw(review)
for i,row in enumerate(rows):
    name=row["name"];im=Image.open(SRC/"originals"/(name+".png")).convert("RGBA")
    assert im.getchannel("A").getextrema()[0]==0,name
    mask=im.getchannel("A").point(lambda v:255 if v>8 else 0);box=mask.getbbox()
    cropped=im.crop(box);fit=ImageOps.contain(cropped,(56,56),Image.Resampling.LANCZOS)
    hi=Image.new("RGBA",(64,64));hi.alpha_composite(fit,((64-fit.width)//2,64-4-fit.height))
    native=hi.resize((16,16),Image.Resampling.LANCZOS)
    native.save(AS/"props"/(name+".png"));(AS/"world_detail/props").mkdir(exist_ok=True,parents=True);hi.save(AS/"world_detail/props"/(name+".png"))
    x=i*150;d.text((x+3,4),name.replace("product_",""),fill="white")
    review.paste(hi.resize((128,128),Image.Resampling.NEAREST),(x+10,25),hi.resize((128,128),Image.Resampling.NEAREST))
    review.paste(native.resize((64,64),Image.Resampling.NEAREST),(x+42,165),native.resize((64,64),Image.Resampling.NEAREST))
    manifest.append({"asset":"props/"+name,"size":[16,16],"source":"originals/"+name+".png","crop":box,"frames":1})
    row["source"]="originals/"+name+".png";row.pop("path",None)
(SRC/"generated_manifest.json").write_text(json.dumps(rows,indent=2)+"\n",encoding="utf-8")
review.save(SRC/"product_review.png")
(SRC/"vectors").mkdir(exist_ok=True)
for name,size,col,spread,strength in [("glow_small",(32,32),"#ffe7b6",.42,205/255),("glow_warm",(64,64),"#ffd69d",.43,205/255),("glow_wide",(96,48),"#ffdaab",.39,205/255),("shadow",(24,8),"#0b131d",.42,205/255*.52)]:
    w,h=size
    stops="".join(f'<stop offset="{k/20}" stop-color="{col}" stop-opacity="{max(0,1-k/20)**(1/spread)*strength}"/>' for k in range(21))
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs><radialGradient id="g">{stops}</radialGradient></defs><rect width="{w}" height="{h}" fill="url(#g)"/></svg>'
    (SRC/"vectors"/(name+".svg")).write_text(svg,encoding="utf-8")
    manifest.append({"asset":"effects/"+name,"size":size,"source":"vectors/"+name+".svg","frames":1})
for name,size,radii in [("sparkle",(64,16),(2.3,4,5.5,3.2)),("water_sparkle",(64,8),(3,5,7,4))]:
    w,h=size;parts=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">']
    for f,r in enumerate(radii):
        cx=f*16+8;cy=h/2
        if name=="sparkle":
            parts.append(f'<path d="M{cx-r} {cy}H{cx+r}M{cx} {cy-r}V{cy+r}" fill="none" stroke="#f9dc95" stroke-opacity=".37" stroke-width="2" stroke-linecap="round"/><path d="M{cx-r} {cy}H{cx+r}M{cx} {cy-r}V{cy+r}" fill="none" stroke="#fff8de" stroke-opacity=".86" stroke-width=".9" stroke-linecap="round"/><circle cx="{cx}" cy="{cy}" r="1.15" fill="#fffff8"/>')
        else:
            parts.append(f'<path d="M{cx-r/2} {cy}H{cx+r/2}" stroke="#9bdbf4" stroke-opacity=".7" stroke-width="1" stroke-linecap="round"/><path d="M{cx-1} {cy-2}H{cx+1}" stroke="#d5f4fa" stroke-opacity=".51" stroke-width=".8"/><circle cx="{cx}" cy="{cy-1}" r=".55" fill="#effbfa" fill-opacity=".82"/>')
    parts.append("</svg>");(SRC/"vectors"/(name+".svg")).write_text("".join(parts),encoding="utf-8")
    manifest.append({"asset":"effects/"+name,"size":size,"source":"vectors/"+name+".svg","frames":4})
# Preserve already approved app identity. 256px detail uses native1024, 1024px detail is disclosed interpolation.
original=Image.open(AS/"ui/app_icon_1024.png").convert("RGBA")
for name,size in [("app_icon",(256,256)),("app_icon_1024",(1024,1024))]:
    target=AS/"world_detail/ui"/(name+".png");target.parent.mkdir(parents=True,exist_ok=True)
    original.resize((size[0]*4,size[1]*4),Image.Resampling.LANCZOS).save(target)
    manifest.append({"asset":"ui/"+name,"size":size,"source":"game/assets/ui/app_icon_1024.png","frames":1,"identity_unchanged":True,"detail_interpolation":name=="app_icon_1024"})
(SRC/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print("product pack: 6 new original sprites, 6 procedural vectors, 2 preserved app exports")

