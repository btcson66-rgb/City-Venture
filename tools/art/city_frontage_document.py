"""Make asset review sheets, status appendix and actual screenshot comparisons."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];S=ROOT/'docs/art_sources/city_frontage_20261001';E=ROOT/'evidence/20261001_city_frontage'
defs=json.loads((S/'layout.json').read_text())
for kind in ['body','lights']:
    out=Image.new('RGB',(1200,((len(defs)+3)//4)*320),'#142033');d=ImageDraw.Draw(out)
    for i,name in enumerate(defs):
        suffix='_lights' if kind=='lights' else ''
        im=Image.open(ROOT/'game/assets/world_detail/buildings'/(name+suffix+'.png')).convert('RGBA');im.thumbnail((285,280),Image.Resampling.LANCZOS)
        x=(i%4)*300+(300-im.width)//2;y=(i//4)*320
        out.paste(im,(x,y+280-im.height),im);d.text(((i%4)*300+8,y+290),name,fill='white')
    out.save(S/(kind+'_preview.png'))
wiki=ROOT/'docs/wiki/13_runtime_art.md';text=wiki.read_text(encoding='utf8');marker='## City frontage completion · 2026-10-01'
if marker in text:text=text[:text.index(marker)].rstrip()+'\n'
text+='\n'+marker+'\n\n美術：19 種其餘城市建築已交原尺寸與 4× PNG，另附各建築獨立光罩和 import；門口、空白招牌框 metadata 對齊新圖，舊尺寸和街區邏輯位置不變。原尺寸已自動載入。4× 的街區/主選單建築入口仍由 Claude 接線；不是完整遊戲品質驗收。\n\n'
for name in defs:text+=f'- buildings/{name}: game/assets/buildings/{name}.png + game/assets/buildings/{name}_lights.png + game/assets/world_detail/buildings/{name}.png + game/assets/world_detail/buildings/{name}_lights.png\n'
wiki.write_text(text,encoding='utf8')
for name in ['06_district_riverside_postpoint_riverside.png','08_district_startup_hub_nexus_cowork.png','12_district_civic_center_city_hall.png','16_district_shopping_street_threadline_apparel.png','17_district_shopping_street_lantern_bistro.png','18_district_shopping_street_crestline_flagship.png','50_shopping_street_night.png']:
    a=E/'before/screenshots'/name;b=E/'after/screenshots'/name
    if not a.exists() or not b.exists():continue
    a=Image.open(a).convert('RGB');b=Image.open(b).convert('RGB');out=Image.new('RGB',(a.width+b.width,max(a.height,b.height)+28),'#142033');out.paste(a,(0,28));out.paste(b,(a.width,28));d=ImageDraw.Draw(out);d.text((8,8),'Before - actual Godot',fill='white');d.text((a.width+8,8),'After - actual Godot',fill='white');out.save(E/('compare_'+name))
print('frontage_document: body/light review, wiki status, actual comparisons')

