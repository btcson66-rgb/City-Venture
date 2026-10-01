"""Document isolated atlas delivery and archive actual runtime evidence."""
from pathlib import Path
import json,shutil
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]

def run():
    source=ROOT/'docs/art_sources/street_utilities_20261001'
    rows=json.loads((source/'manifest.json').read_text())
    wiki=ROOT/'docs/wiki/13_runtime_art.md';marker='\n## 街道公共設施品質批 · 2026-10-01'
    lines=[marker,'','美術：22 種街道公共設施、市集攤位、串燈已交原尺寸／4×及匯入檔，共48 PNG。現有WorldScene自動載入高解析props；原尺寸和舊metadata保持，未改 scripts / data / tests，未移動地磚。告示牌、導引牌、菜單板、旗幟留白；文字／地鐵識別符號仍需Claude以程式疊字，本批未冒稱已接線。','',
           '圖片、原提示詞、裁切和雜湊：docs/art_sources/street_utilities_20261001；前後實機：evidence/20261001_street_utilities。整個遊戲美術優化仍進行中，未驗收內容不算完成。','']
    lines+=['- `'+r['path'].removeprefix('game/assets/')+'` — '+str(tuple(r['size'])) for r in rows]
    lines+=['','sprite keys：'+', '.join('`'+name+'`' for name in json.loads((source/'crops.json').read_text()))+'。']
    wiki.write_text(wiki.read_text(encoding='utf-8').split(marker)[0]+'\n'.join(lines)+'\n',encoding='utf-8')
    evidence=ROOT/'evidence/20261001_street_utilities';logs=evidence/'logs';logs.mkdir(parents=True,exist_ok=True)
    for p in ROOT.glob('utilities-*.log'):
        shutil.copy2(p,logs/p.name)
    for name in ['04_district_riverside_riverside_apartment.png','10_district_startup_hub_small_office.png','12_district_civic_center_city_hall.png','51_shopping_street_market.png']:
        paths=[evidence/kind/'screenshots'/name for kind in ['before','after']]
        if not all(p.exists() for p in paths):
            continue
        images=[Image.open(p).convert('RGB') for p in paths];out=Image.new('RGB',(images[0].width*2,images[0].height+24),'#121f31');d=ImageDraw.Draw(out)
        for i,im in enumerate(images):
            out.paste(im,(i*im.width,24));d.text((i*im.width+12,6),['BEFORE','AFTER'][i],fill='white')
        out.save(evidence/('comparison_'+name))
    print(f'street_utilities_document: {len(rows)} assets documented; runtime evidence archived')

if __name__=='__main__':
    run()
