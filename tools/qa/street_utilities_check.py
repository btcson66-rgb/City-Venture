"""Validate preserved logical sizes and atlas crops before delivery."""
from pathlib import Path
import io,json,subprocess
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]

def run():
    rows=json.loads((ROOT/'docs/art_sources/street_utilities_20261001/manifest.json').read_text())
    for row in rows:
        path=ROOT/row['path'];im=Image.open(path)
        assert list(im.size)==row['size']
        assert path.with_suffix('.png.import').exists(),path
        assert im.getchannel('A').getbbox(),path
        if '/world_detail/' not in row['path']:
            old=subprocess.run(['git','show','HEAD:'+row['path']],cwd=ROOT,capture_output=True)
            if old.returncode==0:
                assert Image.open(io.BytesIO(old.stdout)).size==im.size,path
            detail=ROOT/row['path'].replace('game/assets/','game/assets/world_detail/')
            assert Image.open(detail).size==tuple(v*4 for v in im.size)
        if path.stem.endswith('_lights') and path.stem!='string_lights':
            base=Image.open(path.with_name(path.stem[:-7]+'.png'))
            assert np.count_nonzero(np.asarray(im.getchannel('A'))>32) < np.count_nonzero(np.asarray(base.getchannel('A'))>32)*.65,path
    print(f'street_utilities_check: {len(rows)} PNG/import pairs; existing footprints, 4x and isolated light masks: OK')

if __name__=='__main__':
    run()
