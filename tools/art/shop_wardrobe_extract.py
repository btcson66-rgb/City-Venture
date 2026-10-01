"""Crop transparent garment views for the shared SVG rig. No repainting."""
from pathlib import Path
from PIL import Image
import numpy as np
import json
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'docs/art_sources/shop_wardrobe_20261001'
CUTS={'executive':[160,660,730,1080,1130], 'luxury_citywear':[50,570,603,972,985], 'travel':[40,562,589,940,966], 'formal_evening':[190,663,751,1033,1098], 'logistics_site':[50,566,600,932,959]}
def main():
    out=SRC/'components';out.mkdir(exist_ok=True);manifest=[]
    for key,c in CUTS.items():
        im=Image.open(SRC/'originals'/f'{key}.png').convert('RGBA'); w,h=im.size
        for d,(l,r) in enumerate([(c[0],c[1]),(c[2],c[3]),(c[4],w)]):
            view=im.crop((l,0,r,h)); box=view.getchannel('A').point(lambda a:255 if a>96 else 0).getbbox()
            target=out/f'clothing_{key}_{d}.png';garment=view.crop(box)
            garment.save(out/f'clothing_color_{key}_{d}.png')
            gw,gh=garment.size;alpha=garment.getchannel('A')
            candidates=[]
            for yy in range(int(gh*.16),int(gh*.35),8):
                for xx in range(int(gw*.13),int(gw*.40),8):
                    if alpha.crop((xx,yy,xx+24,yy+24)).getextrema()[0]>245:
                        candidates.append(((xx-gw*.24)**2+(yy-gh*.25)**2,xx,yy))
            assert candidates,(key,d)
            _,xx,yy=min(candidates)
            garment.crop((xx,yy,xx+24,yy+24)).save(out/f'fabric_{key}_{d}.png')
            rgba=np.array(garment);rgb=rgba[:,:,:3].astype(float)
            gray=rgb[:,:,0]*.2126+rgb[:,:,1]*.7152+rgb[:,:,2]*.0722
            fabric=gray[yy:yy+24,xx:xx+24]
            gain=min(6,225/max(1,float(np.median(fabric))))
            rgba[:,:,:3]=np.clip(gray*gain,0,255).astype('uint8')[:,:,None]
            gray_im=Image.fromarray(rgba);gray_im.save(target)
            gray_im.crop((xx,yy,xx+24,yy+24)).save(out/f'fabric_{key}_{d}.png')
            manifest.append({'key':key,'direction':d,'source_size':[w,h],'column':[l,0,r,h],'alpha_crop':box,'fabric_crop':[xx,yy,xx+24,yy+24],'output':target.relative_to(ROOT).as_posix()})
    (SRC/'crop_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    masks=SRC/'rig_masks';masks.mkdir(exist_ok=True)
    for pres in ['masculine','feminine','neutral']:
        for pose in ['', 'sit','idle','phone','interact','carry']:
            name='outfit_business_suit_'+pres+'_top'+('_'+pose if pose else '')+'.png'
            if not (masks/name).exists():
                Image.open(ROOT/'game/assets/characters'/name).getchannel('A').save(masks/name)
    print('Cropped 15 garment views; archived 18 existing rig alpha masks.')
if __name__=='__main__':main()
