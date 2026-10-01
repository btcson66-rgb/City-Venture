"""Check actual asset contract: logical footprints, four-times pairs and tint."""
from pathlib import Path
import io,json,subprocess
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
manifest=json.loads((ROOT/'docs/art_sources/interior_completion_20261001/manifest.json').read_text())
for ent in manifest:
    p=ROOT/ent['path'];im=Image.open(p).convert('RGBA')
    assert list(im.size)==ent['size'],p
    assert Path(str(p)+'.import').exists(),p
    if '/world_detail/' in ent['path']:
        native=ROOT/ent['path'].replace('/world_detail/','/')
        assert im.size==tuple(n*4 for n in Image.open(native).size),p
    elif not p.stem.endswith('_lights'):
        old=Image.open(io.BytesIO(subprocess.check_output(['git','show','HEAD:'+ent['path']],cwd=ROOT)))
        assert im.size==old.size,p
man=Image.open(ROOT/'game/assets/world_detail/interiors/mannequin.png').convert('RGBA')
a=np.array(man);rgb=a[:,:,:3].astype(int);spread=rgb.max(2)-rgb.min(2)
assert np.quantile(spread[a[:,:,3]>96],.99)<16,'Mannequin contains colored dye surface'
light=np.array(Image.open(ROOT/'game/assets/world_detail/interiors/server_rack_lights.png'))
body=np.array(Image.open(ROOT/'game/assets/world_detail/interiors/server_rack.png'))
assert 0<np.count_nonzero(light[:,:,3]>96)<np.count_nonzero(body[:,:,3]>96)*.25,'Emission covers casing'
print(f'interior_art_check: {len(manifest)} PNG/import, unchanged logical sizes, exact 4x, neutral tint and isolated emission: OK')
