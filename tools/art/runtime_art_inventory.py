"""Audit asset resolution coverage, without treating a file as visual acceptance."""
from collections import Counter
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def run():
    assets = ROOT / 'game/assets'
    rows = []
    for path in sorted(assets.rglob('*.png')):
        key = path.relative_to(assets).as_posix()
        if key.startswith('world_detail/'):
            continue
        detail = assets / 'world_detail' / key
        size = Image.open(path).size
        detail_size = Image.open(detail).size if detail.exists() else None
        rows.append({'key': key, 'category': key.split('/')[0], 'native': list(size), 'detail': list(detail_size) if detail_size else None,
                     'exact_4x': detail_size == tuple(d * 4 for d in size),
                     'visual_status': 'NOT_YET_EVALUATED', 'runtime_binding': 'NOT_YET_EVALUATED'})
    out = ROOT / 'docs/art_sources/city_traffic_20261001'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'whole_game_inventory.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    count = Counter(row['category'] for row in rows)
    detail_count = Counter(row['category'] for row in rows if row['detail'])
    four_count = Counter(row['category'] for row in rows if row['exact_4x'])
    md = ['# 全遊戲美術覆蓋盤點 · 2026-10-01', '', '檔案存在與高解析覆蓋不代表實機品質通過。每類需逐場景檢查載入、比例、日夜、動畫、碰撞及遮擋；未檢查項目維持 NOT_YET_EVALUATED。', '',
          '| 類別 | 原尺寸 PNG | 有 detail | 正確 4× | 視覺驗收 |', '|---|---:|---:|---:|---|']
    for category, n in sorted(count.items()):
        md.append(f'| {category} | {n} | {detail_count[category]} | {four_count[category]} | NOT_YET_EVALUATED |')
    md.extend(['', '## 工作順序與驗收邊界', '',
               '- 角色建立／行人／員工：既有角色品質 PR #46，須合併後再逐街區檢查不同膚色、體型、髮型、服裝和動作。',
               '- 車流／停車／列車：本批交替換原尺寸、4×與獨立燈層；實機對比見 evidence/20261001_city_traffic。',
               '- 建築與地面：確認所有街區的正式素材、高解析載入、招牌空白區、門位與材質接縫。',
               '- 室內／物件：確認全部室內的家具、工作道具、牆地材、光罩、遮擋與座位；別名素材需檢查是否失去物件辨識度。',
               '- 介面／地圖／章節與事件卡／商品／特效：逐頁查可讀性、輪廓、風格、日夜與缺漏。',
               '- 未接線素材仍標 Planned/需接線；未推出街區和故事不得以現有截圖宣告驗收完成。', '',
               '完整逐檔 JSON：whole_game_inventory.json。此文件是盤點，不是全遊戲已完成的宣告。'])
    (out / 'whole_game_inventory.md').write_text('\n'.join(md) + '\n', encoding='utf-8')
    print('\n'.join(md[4:4 + len(count) + 2]))


if __name__ == '__main__':
    run()
