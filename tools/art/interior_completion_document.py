"""Create review contact sheet, wiki asset status and before/after comparisons."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
import json
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'docs/art_sources/interior_completion_20261001'
manifest=json.loads((SRC/'manifest.json').read_text())
names=[Path(x['path']).stem for x in manifest if 'world_detail' in x['path'] and not Path(x['path']).stem.startswith('floor_')]
preview=Image.new('RGB',(1100,((len(names)+4)//5)*210),'#142033');draw=ImageDraw.Draw(preview)
for i,name in enumerate(names):
    im=Image.open(ROOT/'game/assets/world_detail/interiors'/(name+'.png')).convert('RGBA')
    im.thumbnail((204,180),Image.Resampling.LANCZOS)
    x=(i%5)*220+(220-im.width)//2;y=(i//5)*210
    preview.paste(im,(x,y+180-im.height),im)
    draw.text(((i%5)*220+8,y+189),name,fill='white')
preview.save(SRC/'packed_preview.png')
wiki=ROOT/'docs/wiki/13_runtime_art.md'
text=wiki.read_text(encoding='utf8')
marker='## Interior completion quality · 2026-10-01'
if marker in text:text=text[:text.index(marker)].rstrip()+'\n'
text+='\n'+marker+'\n\n美術：25 種室內物件及 8 種地板已交原尺寸、4× PNG 與 import。家具、窗景經既有 world_detail 入口自動載入；七種地板重複拼接原材質，修正配對尺寸而保留既有紋理比例。假人使用中性材質。\n\n程式接線：六個招牌保留空白文字區，需 Claude 疊在地點招牌上；箱堆的獨立 Art.tex 入口仍使用原尺寸。新 server_rack_lights 提供機櫃指示燈。不是完整遊戲或所有室內的最終驗收。\n\n'
for name in dict.fromkeys(Path(e['path']).stem for e in manifest if 'world_detail' not in e['path']):
    text+=f'- interiors/{name}: game/assets/interiors/{name}.png + game/assets/world_detail/interiors/{name}.png\n'
wiki.write_text(text,encoding='utf8')
E=ROOT/'evidence/20261001_interior_completion'
for filename in ['44_interior_riverside_apartment.png','30_interior_city_hall.png','46_interior_threadline_apparel.png','53_threadline_wearing_executive.png']:
    a=E/'before/screenshots'/filename;b=E/'after/screenshots'/filename
    if not a.exists() or not b.exists():continue
    ia=Image.open(a).convert('RGB');ib=Image.open(b).convert('RGB')
    out=Image.new('RGB',(ia.width+ib.width,max(ia.height,ib.height)+28),'#142033')
    out.paste(ia,(0,28));out.paste(ib,(ia.width,28));d=ImageDraw.Draw(out);d.text((8,8),'Before - actual Godot',fill='white');d.text((ia.width+8,8),'After - actual Godot',fill='white')
    out.save(E/('compare_'+filename))
print('interior_document: review sheet, asset wiki status and available actual comparisons')
