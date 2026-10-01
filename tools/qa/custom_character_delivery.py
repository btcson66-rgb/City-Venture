"""Package reproducible evidence and compare unchanged logical dimensions."""
from pathlib import Path
import json,subprocess,io,shutil
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
EV=ROOT/'evidence/20261001_character_customization'
(EV/'logs').mkdir(exist_ok=True)
logs={'final-import.log':'import.log','character-tests.log':'tests.log','custom-coverage.log':'coverage.log','custom-pose.log':'pose.log','character-wiki.log':'wiki.log','character-map.log':'map_labels.log','custom-creator.log':'creator.log','custom-gallery.log':'gallery.log','character-shots.log':'tour.log'}
for src,target in logs.items():shutil.copyfile(ROOT/src,EV/'logs'/target)
for skin in ['s2','s6']:
    before=Image.open(EV/f'before/creator_{skin}.png').convert('RGB')
    after=Image.open(EV/f'after/creator_{skin}.png').convert('RGB')
    comparison=Image.new('RGB',(1280,752),'#101e30');draw=ImageDraw.Draw(comparison)
    draw.text((14,8),f'{skin} BEFORE / actual creator',fill='white');draw.text((654,8),f'{skin} AFTER / actual creator',fill='white')
    comparison.paste(before.crop((0,0,640,720)),(0,32));comparison.paste(after.crop((0,0,640,720)),(640,32))
    comparison.save(EV/f'comparison_{skin}.png')
manifest=json.loads((ROOT/'docs/art_sources/custom_character_20261001/manifest.json').read_text())
tracked=set(subprocess.check_output(['git','ls-files','game/assets'],cwd=ROOT,text=True).splitlines())
unchanged=0
for entry in manifest:
    for output in entry['outputs']:
        path=output['path']
        if path not in tracked:continue
        data=subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT)
        assert Image.open(io.BytesIO(data)).size==tuple(output['size']),path
        unchanged+=1
print('custom_character_delivery: %d existing PNG logical dimensions unchanged; evidence packaged'%unchanged)
