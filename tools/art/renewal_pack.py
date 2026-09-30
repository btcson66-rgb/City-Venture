"""Pack original generated artwork into the existing Godot image contracts.

No illustration is drawn here: this only crops atlas cells, resizes, quantizes,
and packs already-generated art, like finalize_backdrops.py. Never regenerates
gameplay sprites. Run from the root with Python 3 and Pillow.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageOps
from finalize_backdrops import fit
from ui import gen_panels

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/art_sources/renewal_20260929'
ASSETS = ROOT / 'game/assets'
EVIDENCE = ROOT / 'evidence/2026-09-29_art_renewal'
SCENES = {
    'skyline_day': [('backdrops/skyline_day', (1300, 320))],
    'skyline_dusk': [('backdrops/skyline_dusk', (1300, 320))],
    'skyline_night': [('backdrops/skyline_night', (1300, 320))],
    'menu': [('backdrops/menu', (752, 360)), ('cards/riverside', (192, 108))],
    'apartment': [('cards/riverside_apartment', (192, 108)), ('backdrops/chapter_2', (640, 360))],
    'office': [('cards/small_office', (192, 108)), ('backdrops/chapter_4', (640, 360))],
    'bank': [('cards/nexus_bank', (192, 108))],
    'cafe': [('cards/bloom_coffee', (192, 108))],
    'cowork': [('cards/nexus_cowork', (192, 108))],
    'tech_cafe': [('cards/byte_and_bean', (192, 108))],
    'city_hall': [('cards/city_hall', (192, 108)), ('cards/civic_center', (192, 108)), ('backdrops/chapter_3', (640, 360))],
    'arrival': [('backdrops/arrival', (640, 360))],
    'train': [('backdrops/chapter_1', (640, 360))],
    'warehouse': [('backdrops/chapter_5', (640, 360)), ('cards/postpoint_riverside', (192, 108))],
    'night_office': [('backdrops/chapter_6', (640, 360))],
    'wardrobe': [('backdrops/wardrobe', (200, 250))],
    'financial': [('cards/financial', (192, 108))],
    'startup': [('cards/startup_hub', (192, 108))],
    'fresh_start': [('backdrops/insolvency', (640, 360))],
}


def portrait(source, target, layout):
    with Image.open(source) as src:
        src = src.convert('RGB')
        frames = []
        for i in range(4):
            if layout == 'row4':
                box = (round(i * src.width / 4), 0, round((i + 1) * src.width / 4), src.height)
            else:
                x, y = i % 2, i // 2
                box = (round(x * src.width / 2), round(y * src.height / 2),
                       round((x + 1) * src.width / 2), round((y + 1) * src.height / 2))
            # Contain non-square generated cells: do not distort faces or cut hair.
            cell = ImageOps.pad(src.crop(box), (64, 64), method=Image.Resampling.BOX, color='#1B273F')
            frames.append(cell)
        atlas = Image.new('RGB', (256, 64), '#1B273F')
        for i, frame in enumerate(frames):
            atlas.paste(frame, (i * 64, 0))
        atlas = atlas.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGBA')
        atlas.save(target)


def main():
    gen_panels(str(ASSETS), only={'panel', 'panel_glass', 'button', 'button_hover',
                                'button_primary', 'button_primary_hover', 'card'})
    entries = json.loads((SOURCE / 'sources.json').read_text(encoding='utf-8'))
    report = []
    for entry in entries:
        source = SOURCE / (entry['id'] + '.png')
        if not source.exists():
            raise FileNotFoundError(source)
        if entry['layout'] == 'scene':
            outputs = SCENES[entry['id']]
        else:
            outputs = [('portraits/npc_' + entry['id'], (256, 64))]
        for name, size in outputs:
            target = ASSETS / (name + '.png')
            target.parent.mkdir(parents=True, exist_ok=True)
            if entry['layout'] == 'scene':
                fit(source, target, size)
            else:
                portrait(source, target, entry['layout'])
            with Image.open(target) as im:
                assert im.size == size
                assert im.getchannel('A').getextrema() == (255, 255)
                colors = len(im.getcolors(65536) or [])
                assert 0 < colors <= 192
            report.append({'asset': str(target.relative_to(ROOT)).replace('\\', '/'),
                           'source': str(source.relative_to(ROOT)).replace('\\', '/'),
                           'size': size, 'colors': colors,
                           'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / 'asset_manifest.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'Packed and validated {len(report)} assets.')


if __name__ == '__main__':
    main()
