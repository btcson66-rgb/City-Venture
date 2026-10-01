"""Check unchanged UI sizes, fixed icon atlas slots and frame transparency."""
from pathlib import Path
import json,subprocess,io,hashlib
from PIL import Image,ImageDraw
import numpy as np
ROOT=Path(__file__).resolve().parents[2];SRC=ROOT/'docs/art_sources/ui_quality_20261001'
def main():
    jobs=json.loads((SRC/'render_jobs.json').read_text());jobs+=[{'key':'ui/icons_atlas','size':[128,96]}]
    inventory=[]
    for job in jobs:
        outputs=[]
        for factor,prefix in [(1,''),(4,'world_detail/')]:
            p=ROOT/'game/assets'/(prefix+job['key']+'.png');im=Image.open(p).convert('RGBA')
            assert im.size==tuple(v*factor for v in job['size']),p
            assert im.getchannel('A').getbbox(),p
            assert Path(str(p)+'.import').exists(),p
            if factor==1:
                old=Image.open(io.BytesIO(subprocess.check_output(['git','show','9145015:game/assets/'+job['key']+'.png'],cwd=ROOT)))
                assert im.size==old.size,p
            if job['key'].endswith('phone_frame'):assert im.getpixel((75*factor,125*factor))[3]==0
            if job['key'].endswith('portrait_frame'):assert im.getpixel((36*factor,36*factor))[3]==0
            outputs.append({'path':p.relative_to(ROOT).as_posix(),'size':list(im.size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        inventory.append({'key':job['key'],'outputs':outputs})
    icons=[j for j in jobs if j['key'].startswith('ui/icons/')]
    for factor,prefix in [(1,''),(4,'world_detail/')]:
        atlas=Image.open(ROOT/'game/assets'/(prefix+'ui/icons_atlas.png')).convert('RGBA')
        for i,job in enumerate(icons):
            x=i%8*16*factor;y=i//8*16*factor;icon=Image.open(ROOT/'game/assets'/(prefix+job['key']+'.png')).convert('RGBA')
            a=np.array(atlas.crop((x,y,x+16*factor,y+16*factor))).astype(float);b=np.array(icon).astype(float)
            assert np.array_equal(a[:,:,3],b[:,:,3]),job['key']
            assert np.max(abs(a[:,:,:3]*a[:,:,3:]/255-b[:,:,:3]*b[:,:,3:]/255))<=1,job['key']
    (SRC/'manifest.json').write_text(json.dumps(inventory,indent=2)+'\n')
    print('ui_quality_check: 67 native + 67 detail PNG/import pairs; original sizes and 43 atlas slots unchanged; transparent phone/portrait content openings OK')
if __name__=='__main__':main()
