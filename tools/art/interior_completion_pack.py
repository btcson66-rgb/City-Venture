"""Technical atlas cropping and floor repeat packing; no illustration drawing."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'docs/art_sources/interior_completion_20261001'
A=ROOT/'game/assets'
BOUNDS={
'retail':{
'checkout_counter':(38,8,554,325),'clothing_rack':(589,9,953,325),'fitting_room':(1116,2,1465,327),
'lockers':(170,354,371,674),'mannequin':(677,327,870,680),'mirror_full':(1171,350,1386,679),
'queue_barrier':(91,699,479,979),'shoe_shelf':(577,699,1004,982),'server_rack':(1152,681,1400,993)},
'small':{
'armchair':(40,43,438,382),'box':(596,121,942,370),'cork_board':(1080,50,1500,370),
'door_mat':(25,463,533,661),'framed_art':(604,391,929,675),'framed_art_b':(1117,397,1456,676),
'stool':(85,683,370,1003),'window_wide_day':(441,695,973,995),'window_wide_night':(993,696,1525,995)},
'identity':{
'logo_bloom':(20,185,427,416),'logo_bytebean':(427,186,840,416),'logo_city_hall':(840,187,1230,416),
'logo_cowork':(1230,187,1758,416),'logo_nexus_bank':(18,489,518,721),'logo_postpoint':(518,489,1006,721),'seal':(1006,437,1360,786)}
}
FLOORS=['carpet_navy','concrete','marble','tile_white','wood_cafe','wood_dark','wood_warm']
def save(name,im):
    logical=Image.open(A/'interiors'/(name+'.png')).size
    for folder,bitmap in [('interiors',im.resize(logical,Image.Resampling.LANCZOS)),('world_detail/interiors',im)]:
        path=A/folder/(name+'.png');path.parent.mkdir(parents=True,exist_ok=True);bitmap.save(path)
        records.append({'path':path.relative_to(ROOT).as_posix(),'size':list(bitmap.size),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
def repeat(tile,size):
    out=Image.new('RGBA',size)
    for y in range(0,size[1],tile.height):
        for x in range(0,size[0],tile.width): out.paste(tile,(x,y))
    return out
records=[];crops={}
for atlas,objects in BOUNDS.items():
    original=Image.open(SRC/(atlas+'.png')).convert('RGBA')
    for name,rect in objects.items():
        cell=original.crop(rect)
        if name=='mannequin' and (SRC/'mannequin.png').exists(): cell=Image.open(SRC/'mannequin.png').convert('RGBA')
        box=cell.getchannel('A').point(lambda a:255 if a>96 else 0).getbbox()
        assert box,name
        cell=cell.crop(box)
        logical=Image.open(A/'interiors'/(name+'.png')).size
        size=tuple(x*4 for x in logical);ratio=min(size[0]/cell.width,size[1]/cell.height)
        cell=cell.resize((round(cell.width*ratio),round(cell.height*ratio)),Image.Resampling.LANCZOS)
        out=Image.new('RGBA',size);out.alpha_composite(cell,((size[0]-cell.width)//2,size[1]-cell.height))
        save(name,out);crops[name]={'atlas':atlas,'cell':rect,'alpha_bounds':box,'size':size}
        if name=='server_rack':
            arr=np.array(out);rgb=arr[:,:,:3].astype(float)
            emit=(rgb[:,:,2]>170)&(rgb[:,:,1]>130)&(rgb[:,:,2]>rgb[:,:,0]*1.25)
            arr[:,:,3]=np.where(emit,arr[:,:,3],0)
            light=Image.fromarray(arr)
            for folder,im in [('interiors',light.resize(logical,Image.Resampling.LANCZOS)),('world_detail/interiors',light)]:
                path=A/folder/(name+'_lights.png');im.save(path);records.append({'path':path.relative_to(ROOT).as_posix(),'size':list(im.size),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
for name in FLOORS:
    filename='floor_'+name+'.png';archive=SRC/('original_'+filename)
    if not archive.exists(): archive.write_bytes((A/'world_detail/interiors'/filename).read_bytes())
    tile=Image.open(archive).convert('RGBA');logical=Image.open(A/'interiors'/filename).size
    save('floor_'+name,repeat(tile,tuple(x*4 for x in logical)))
# Two-by-two checker crop; repeated without smoothing tile boundaries.
checker=Image.open(SRC/'checker.png').convert('RGBA').crop((0,0,318,314)).resize((256,256),Image.Resampling.LANCZOS)
save('floor_checker',repeat(checker,(2048,1280)))
crops['floor_checker']={'atlas':'checker','cell':[0,0,318,314],'repeat_tile':[256,256]}
(SRC/'manifest.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf8')
(SRC/'crops.json').write_text(json.dumps(crops,indent=2)+'\n',encoding='utf8')
print(f'interior_pack: {len(records)} PNG native/detail, {len(BOUNDS["retail"])+len(BOUNDS["small"])+len(BOUNDS["identity"])} fixtures and 8 floors')

