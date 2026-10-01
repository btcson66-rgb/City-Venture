"""Record delivered files and assemble unedited runtime comparison screenshots."""
from pathlib import Path
import json
import shutil
from PIL import Image,ImageDraw

ROOT = Path(__file__).resolve().parents[2]

def run():
    source = ROOT / 'docs/art_sources/street_environment_20261001'
    rows = json.loads((source / 'manifest.json').read_text())
    wiki = ROOT / 'docs/wiki/13_runtime_art.md'
    marker = '\n## 街道環境品質批 · 2026-10-01'
    text = [marker,'','美術：七種常見立面與十三種路邊物件重新精修，原尺寸、4×、PNG import與發光層已交。圖上的招牌與旗幟留空白，門位、招牌與路燈 glow metadata 已按新圖對齊。沒有修改 scripts / data / tests，沒有移動地磚。','',
            '實機原尺寸建築已替換；路邊物件由現有 WorldScene 自動讀 4×。District 與主選單建築仍讀原尺寸，4× 接線由 Claude 處理；全遊戲美術優化仍未完成。來源／裁切／提示詞：docs/art_sources/street_environment_20261001。前後截圖：evidence/20261001_street_environment。','', '交付檔案：','']
    text += ['- `' + row['path'].removeprefix('game/assets/') + '` — ' + str(tuple(row['size'])) for row in rows]
    text += ['', 'sprite keys：' + ', '.join('`' + name + '`' for name in json.loads((source/'layout.json').read_text())) + '。']
    wiki.write_text(wiki.read_text(encoding='utf-8').split(marker)[0]+'\n'.join(text)+'\n',encoding='utf-8')
    evidence = ROOT / 'evidence/20261001_street_environment'
    logs = evidence/'logs'
    logs.mkdir(parents=True,exist_ok=True)
    for path in ROOT.glob('environment-*.log'):
        shutil.copy2(path,logs/path.name)
    for name in ['04_district_riverside_riverside_apartment.png','08_district_startup_hub_nexus_cowork.png','11_district_startup_hub_south.png','01_main_menu.png']:
        paths=[evidence/kind/'screenshots'/name for kind in ['before','after']]
        if not all(p.exists() for p in paths):
            continue
        images=[Image.open(p).convert('RGB') for p in paths]
        out=Image.new('RGB',(images[0].width*2,images[0].height+24),'#121f31')
        d=ImageDraw.Draw(out)
        for i,im in enumerate(images):
            out.paste(im,(i*im.width,24));d.text((i*im.width+12,6),['BEFORE','AFTER'][i],fill='white')
        out.save(evidence/('comparison_'+name))
    print(f'street_environment_document: {len(rows)} assets documented; runtime evidence archived')

if __name__ == '__main__':
    run()
