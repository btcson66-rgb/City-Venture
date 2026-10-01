"""Extract inspected atlas objects without background removal or repainting."""
from pathlib import Path
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'docs/art_sources/city_frontage_20261001'
rows=json.loads((SRC/'atlas_layout.json').read_text())
defs={}
for atlas,name,bounds,door,sign,emit in rows:
    im=Image.open(SRC/(atlas+'.png')).convert('RGBA').crop(bounds)
    im.save(SRC/'originals'/(name+'.png'))
    def local(rect):return [rect[0]-bounds[0],rect[1]-bounds[1],rect[2]-bounds[0],rect[3]-bounds[1]]
    defs[name]={'folder':'buildings','door':local(door),'sign':local(sign),'emit':[local(r) for r in emit]}
if (SRC/'originals/metro_entrance.png').exists():
    defs['metro_entrance']=json.loads((SRC/'metro_layout.json').read_text())
if (SRC/'finance.png').exists():
    (SRC/'originals/finance_tower.png').write_bytes((SRC/'finance.png').read_bytes())
    defs['finance_tower']=json.loads((SRC/'finance_layout.json').read_text())
(SRC/'layout.json').write_text(json.dumps(defs,indent=2)+'\n',encoding='utf8')
print(f'frontage_extract: {len(defs)} individual originals')
