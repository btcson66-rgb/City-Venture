"""Record the asset delivery and actual before/after evidence."""
from pathlib import Path
import json
import shutil
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def run():
    source = ROOT / 'docs/art_sources/city_traffic_20261001'
    evidence = ROOT / 'evidence/20261001_city_traffic'
    rows = json.loads((source / 'manifest.json').read_text())
    appendix = ['\n## 全遊戲美術優化：街道車流批 · 2026-10-01', '',
                '美術：五種街道車輛、轎車／掀背車前後視圖、入城列車已交原尺寸、4× 和匯入檔。既有原尺寸已直接替換，所有舊檔尺寸保持不變。車身灰階可染色，車窗／輪胎／輪圈保留固定細節；光罩只包含發光像素。', '',
                '接線限制：現有 Car、Skyline、ArrivalScene 仍讀原尺寸。4× 與車灯層未接入車流，本批不改 scripts / data / tests。Claude 接線時須保持原尺寸車長、offset、輪胎基線、碰撞與交通速度；不可直接把 4× 寬度當作邏輯車長。', '',
                '全遊戲覆蓋盤點：`../art_sources/city_traffic_20261001/whole_game_inventory.md`。檔案覆蓋不代表品質已驗收；角色品質另見 PR #46。完整遊戲美術優化仍進行中。', '',
                '來源、裁切與 SHA-256：`../art_sources/city_traffic_20261001/manifest.json`、`sources.json`、`crops.json`。實機證據：`evidence/20261001_city_traffic/`。', '', '本批檔案：', '']
    appendix += ['- `' + row['path'].removeprefix('game/assets/') + '` — ' + str(tuple(row['size'])) for row in rows]
    appendix += ['', '燈層對應的 sprite key：' + ', '.join('`' + key + '`' for key in sorted({Path(row['path']).stem.removesuffix('_lights') for row in rows if row['path'].endswith('_lights.png')})) + '。']
    wiki = ROOT / 'docs/wiki/13_runtime_art.md'
    text = wiki.read_text(encoding='utf-8')
    marker = '\n## 全遊戲美術優化：街道車流批 · 2026-10-01'
    wiki.write_text(text.split(marker)[0] + '\n'.join(appendix) + '\n', encoding='utf-8')
    logs = evidence / 'logs'
    logs.mkdir(exist_ok=True)
    for filename in ['traffic-baseline-import.log', 'traffic-before-shots.log', 'traffic-art-import.log', 'traffic-after-shots.log', 'traffic-tests.log', 'traffic-wiki.log', 'traffic-art-check.log']:
        if (ROOT / filename).exists():
            shutil.copy2(ROOT / filename, logs / filename)
    for name in ['01_main_menu.png', '03_arrival.png', '04_district_riverside_riverside_apartment.png', '14_district_financial_nexus_bank.png']:
        paths = [evidence / kind / 'screenshots' / name for kind in ['before', 'after']]
        if not all(p.exists() for p in paths):
            continue
        images = [Image.open(p).convert('RGB') for p in paths]
        result = Image.new('RGB', (images[0].width * 2, images[0].height + 24), '#121f31')
        d = ImageDraw.Draw(result)
        for i, im in enumerate(images):
            d.text((i * im.width + 12, 6), ['BEFORE', 'AFTER'][i], fill='#b2d6f2')
            result.paste(im, (i * im.width, 24))
        result.save(evidence / ('comparison_' + name))
    print(f'traffic_document: documented {len(rows)} assets and archived evidence')


if __name__ == '__main__':
    run()
