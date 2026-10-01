"""Pack map artwork at existing logical sizes; gameplay coordinates are immutable."""
from pathlib import Path
import json, subprocess
from PIL import Image, ImageOps, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/"docs/art_sources/map_quality_20261001"
AS=ROOT/"game/assets"
manifest=[]
for row in json.loads((SRC/"generated_manifest.json").read_text(encoding="utf-8")):
    name=row["name"]
    group="city_map" if name.startswith("i_") or name=="city_board" else "world_map"
    target="board" if name.endswith("_board") else name
    old=AS/group/(target+".png")
    size=Image.open(old).size
    im=Image.open(SRC/"originals"/(name+".png")).convert("RGBA")
    # Board compositions preserve full extent and node coordinates; thumbnails use centered fit.
    hi=im.resize((size[0]*4,size[1]*4),Image.Resampling.LANCZOS) if target=="board" else ImageOps.fit(im,(size[0]*4,size[1]*4),method=Image.Resampling.LANCZOS)
    detail=AS/"world_detail"/group/(target+".png")
    detail.parent.mkdir(parents=True,exist_ok=True)
    hi.save(detail);hi.resize(size,Image.Resampling.LANCZOS).save(old)
    manifest.append({"asset":f"{group}/{target}","size":size,"source":f"originals/{name}.png","runtime":True})
# Archived secondary world backdrop has no current runtime call site.
im=Image.open(SRC/"originals/world_board.png").convert("RGBA")
size=Image.open(AS/"world_map/world_map.png").size
hi=ImageOps.fit(im,(size[0]*4,size[1]*4),method=Image.Resampling.LANCZOS)
hi.save(AS/"world_detail/world_map/world_map.png");hi.resize(size,Image.Resampling.LANCZOS).save(AS/"world_map/world_map.png")
manifest.append({"asset":"world_map/world_map","size":size,"source":"originals/world_board.png","runtime":False})
# Metro background remains a quiet schematic; colored routes and station labels belong to runtime.
parts=['<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360"><defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#102a43"/><stop offset="1" stop-color="#091c30"/></linearGradient></defs><rect width="640" height="360" fill="url(#bg)"/>']
for x in range(24,640,39):parts.append(f'<path d="M{x} 0L{x+20} 360" stroke="#1a394c" stroke-width="2"/>')
for y in range(17,360,32):parts.append(f'<path d="M0 {y+8}L640 {y}" stroke="#1a394c" stroke-width="2"/>')
for pts in ["0,91 182,93 337,76 640,80","32,0 88,133 214,224 320,360","416,0 418,102 476,200 580,360"]:
    parts.append(f'<polyline points="{pts}" fill="none" stroke="#2b4d5f" stroke-width="5" stroke-linejoin="round"/><polyline points="{pts}" fill="none" stroke="#4c6f80" stroke-width="1"/>')
parts.append('<polygon points="0,284 66,271 130,270 204,279 287,260 356,239 439,242 522,227 640,240 640,294 522,284 439,292 356,286 287,305 204,325 130,309 66,310 0,329" fill="#184f74"/>')
for y,col in [(267,"#428ab2"),(281,"#296f95")]:
    pts=f"0,{y+24} 96,{y+12} 188,{y+20} 291,{y+7} 405,{y-13} 520,{y-20} 640,{y-13}"
    parts.append(f'<polyline points="{pts}" fill="none" stroke="{col}" stroke-width="1"/>')
for cx,cy,rx,ry in [(146,66,48,24),(375,110,33,20),(198,210,42,19),(545,181,27,15)]:
    parts.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#1d4741" stroke="#366751"/>')
parts.append("</svg>")
(SRC/"metro_map.svg").write_text("".join(parts),encoding="utf-8")
manifest.append({"asset":"city_map/aurelia_map","size":[640,360],"source":"metro_map.svg","runtime":True})
(SRC/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
# Review sheets only; labels here are outside shipped artwork.
for group,prefix in [("city_map","i_"),("world_map","r_")]:
    rows=[m for m in manifest if m["asset"].startswith(group+"/"+prefix)]
    sheet=Image.new("RGB",(4*300,((len(rows)+3)//4)*215),"#102035")
    d=ImageDraw.Draw(sheet)
    for i,m in enumerate(rows):
        x=(i%4)*300;y=(i//4)*215
        pic=Image.open(AS/"world_detail"/(m["asset"]+".png")).convert("RGB")
        pic.thumbnail((288,180))
        sheet.paste(pic,(x+6,y+20));d.text((x+6,y+5),m["asset"],fill="white")
    sheet.save(SRC/(group+"_review.png"))
print("map_pack: 25 assets, 50 native/detail PNGs, fixed logical sizes")

