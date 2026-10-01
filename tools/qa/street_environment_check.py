"""Check native/detail pairing, old footprints and aligned interactive metadata."""
from pathlib import Path
import io
import json
import subprocess
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

def run():
    folder = ROOT / 'docs/art_sources/street_environment_20261001'
    manifest = json.loads((folder / 'manifest.json').read_text())
    meta = json.loads((ROOT / 'game/assets/buildings/buildings_meta.json').read_text())
    definitions = json.loads((folder / 'layout.json').read_text())
    for row in manifest:
        path = ROOT / row['path']
        im = Image.open(path).convert('RGBA')
        assert list(im.size) == row['size']
        assert path.with_suffix('.png.import').exists(), path
        if '/world_detail/' not in row['path']:
            old = subprocess.run(['git','show','HEAD:' + row['path']],cwd=ROOT,capture_output=True)
            if old.returncode == 0:
                assert Image.open(io.BytesIO(old.stdout)).size == im.size, path
            detail = ROOT / row['path'].replace('game/assets/', 'game/assets/world_detail/')
            assert Image.open(detail).size == tuple(v * 4 for v in im.size)
        if path.stem.endswith('_lights'):
            a = np.asarray(im)
            pixels = a[a[:,:,3] > 32].astype(float)
            assert len(pixels) > 0, path
            assert np.all(pixels[:,0] > pixels[:,2]), path
            # Never emit the entire facade or metal pole.
            body = Image.open(path.with_name(path.name.replace('_lights',''))).convert('RGBA')
            assert np.count_nonzero(a[:,:,3] > 32) < np.count_nonzero(np.asarray(body)[:,:,3] > 32) * .45, path
    for key, definition in definitions.items():
        if definition['folder'] != 'buildings':
            continue
        width, height = meta[key]['size']
        for field in ['door','sign']:
            if field not in definition:
                continue
            x,y,w,h = meta[key][field]
            assert 0 <= x < x+w <= width and 0 <= y < y+h <= height, (key,field)
    print(f'street_environment_check: {len(definitions)} originals; {len(manifest)} PNG/import pairs; 4x, footprints, door/sign bounds and emission-only checks: OK')

if __name__ == '__main__':
    run()
