"""Verify traffic tint layers, aspect-preserving footprints and emission-only masks."""
from pathlib import Path
import json
import subprocess
import io
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]


def run():
    source = ROOT / 'docs/art_sources/city_traffic_20261001'
    rows = json.loads((source / 'manifest.json').read_text())
    for row in rows:
        path = ROOT / row['path']
        image = Image.open(path).convert('RGBA')
        assert list(image.size) == row['size']
        assert path.with_suffix('.png.import').exists(), path
        if 'world_detail' not in row['path']:
            old = subprocess.run(['git', 'show', 'origin/claude/exciting-bardeen-y71ixv:' + row['path']], cwd=ROOT, capture_output=True)
            if old.returncode == 0:
                assert Image.open(io.BytesIO(old.stdout)).size == image.size, path
        if path.stem.endswith('_body'):
            a = np.asarray(image)
            pixels = a[a[:, :, 3] > 0]
            assert np.all(pixels[:, 0] == pixels[:, 1]) and np.all(pixels[:, 1] == pixels[:, 2]), path
        if path.stem.endswith('_lights'):
            a = np.asarray(image)
            pixels = a[a[:, :, 3] > 32]
            assert len(pixels) > 0, path
            assert np.all(pixels[:, 0].astype(int) > pixels[:, 2].astype(int) * 1.2), path
    keys = ['sedan_side', 'compact_side', 'taxi_side', 'van_side', 'bus_side', 'sedan_front', 'sedan_back', 'compact_front', 'compact_back']
    sheet = Image.new('RGB', (1200, 720), '#121f31')
    draw = ImageDraw.Draw(sheet)
    for i, key in enumerate(keys):
        x, y = (i % 3) * 400, (i // 3) * 240
        draw.text((x + 12, y + 8), key, fill='#b2d6f2')
        for j, tint in enumerate([(244, 246, 250), (70, 110, 180), (60, 64, 76)]):
            body = Image.open(ROOT / f'game/assets/world_detail/vehicles/{key}_body.png').convert('RGBA')
            a = np.asarray(body).copy()
            a[:, :, :3] = np.rint(a[:, :, :3].astype(float) * np.array(tint) / 255).astype(np.uint8)
            result = Image.fromarray(a)
            result.alpha_composite(Image.open(ROOT / f'game/assets/world_detail/vehicles/{key}_detail.png').convert('RGBA'))
            result.thumbnail((368, 56), Image.Resampling.LANCZOS)
            sheet.paste(result, (x + 16, y + 32 + j * 65), result)
    out = ROOT / 'evidence/20261001_city_traffic'
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / 'vehicle_tint_gallery.png')
    print(f'traffic_art_check: {len(rows)} PNG/import pairs; unchanged existing footprints; neutral tint layers; emission-only masks: OK')


if __name__ == '__main__':
    run()
