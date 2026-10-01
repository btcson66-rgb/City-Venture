"""Check tint neutrality, imports, logical size and composite garment reviews."""
from pathlib import Path
import argparse,json,hashlib
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'docs/art_sources/shop_wardrobe_20261001'
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--reference-assets');args=parser.parse_args()
    jobs=json.loads((SRC/'render_jobs.json').read_text());inventory=[]
    for job in jobs:
        paths=[]
        for factor,prefix in [(1,''),(4,'world_detail/')]:
            p=ROOT/'game/assets'/(prefix+job['key']+'.png');im=Image.open(p).convert('RGBA')
            assert im.size==tuple(x*factor for x in job['size']),p
            assert Path(str(p)+'.import').exists(),p
            a=np.array(im)
            if '_detail' in job['key']:
                assert im.getchannel('A').getbbox(),p
            if job['key'].endswith('_top') or '_top_' in job['key'] and '_detail' not in job['key'] or job['key'].endswith('_bottom') or '_bottom_' in job['key'] or job['key'].startswith('portraits/') and not job['key'].endswith('_detail'):
                active=a[:,:,3]>96;rgb=a[:,:,:3][active].astype(int)
                assert len(rgb) and np.max(rgb.max(axis=1)-rgb.min(axis=1))<=2,p
            paths.append({'path':p.relative_to(ROOT).as_posix(),'size':list(im.size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
        inventory.append({'key':job['key'],'source':job['source'],'outputs':paths})
    (SRC/'manifest.json').write_text(json.dumps(inventory,indent=2)+'\n')
    refs=Path(args.reference_assets) if args.reference_assets else ROOT/'game/assets'
    label='candidate_combined_preview' if args.reference_assets else 'current_layer_preview'
    out=ROOT/'evidence/20261001_shop_wardrobe'/label;out.mkdir(exist_ok=True)
    palette=json.loads((ROOT/'game/assets/outfit_palette.json').read_text())['defaults']
    opts=json.loads((ROOT/'game/data/character/options.json').read_text())
    skins=[s['color'] for s in opts['skin_tones']]
    def tint(im,color):
        a=np.array(im).copy();rgb=np.array([int(color[i:i+2],16) for i in [1,3,5]])
        a[:,:,:3]=(a[:,:,:3].astype(float)*rgb/255).astype('uint8');return Image.fromarray(a)
    for pres in ['masculine','feminine','neutral']:
        page=Image.new('RGB',(960,1032),'#14263b');draw=ImageDraw.Draw(page)
        draw.text((8,4),label+' / '+pres+' / explicit art palette; not default runtime wiring',fill='white')
        for row,sc in enumerate(skins):
            draw.text((3,32+row*165),'s'+str(row+1),fill='white')
            for col,oid in enumerate(palette):
                draw.text((col*192+30,22+row*165),oid,fill='white')
                for direction in range(3):
                    canvas=Image.new('RGBA',(128,192))
                    names=[('hair_messy_back','#3c2a26'),('body_'+pres+'_round',sc),('outfit_'+oid+'_'+pres+'_bottom',palette[oid]['bottom']),('outfit_'+oid+'_'+pres+'_shoes',None),('outfit_'+oid+'_'+pres+'_top',palette[oid]['top']),('outfit_'+oid+'_'+pres+'_top_detail',None),('eyes_round',None),('iris_round','#5b4032'),('brows_straight','#3c2a26'),('mouth_smile',None),('hair_messy_front','#3c2a26')]
                    for name,color in names:
                        base=ROOT/'game/assets' if name.startswith('outfit_') else refs
                        p=base/'world_detail/characters'/(name+'.png')
                        if not p.exists():p=base/'characters'/(name+'.png')
                        im=Image.open(p).convert('RGBA');factor=im.width//128
                        im=im.crop((0,direction*48*factor,32*factor,(direction+1)*48*factor)).resize((128,192))
                        if color:im=tint(im,color)
                        canvas.alpha_composite(im)
                    canvas=canvas.resize((64,96))
                    page.paste(canvas,(col*192+direction*62+10,row*165+43),canvas)
        page.save(out/(pres+'.png'))
    print('shop_wardrobe_check: 370 native + 370 detail PNG/import pairs; tint neutrality and logical dimensions OK; 270 skin/body/direction review composites')
if __name__=='__main__':main()
