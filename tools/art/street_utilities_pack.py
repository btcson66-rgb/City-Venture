"""Technical nine-cell atlas slicing; no drawing or background removal."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'docs/art_sources/street_utilities_20261001'
ASSETS=ROOT/'game/assets'
SETS={'utilities':['bollard','hydrant','cone','trash_bin','parking_meter','digital_sign','direction_sign','metro_sign','cafe_board'],
      'structures':['bus_stop','bike_rack','fountain','flagpole','kiosk_flower','billboard','business_board','railing','umbrella_table_blue'],
      'market':['market_stall_cream','market_stall_rose','market_stall_sage','string_lights']}
BOUNDS={
 'bollard':(160,95,270,365),'hydrant':(526,80,738,365),'cone':(948,116,1127,365),
 'trash_bin':(132,478,309,772),'parking_meter':(578,438,678,782),'digital_sign':(948,430,1138,800),
 'direction_sign':(78,844,366,1176),'metro_sign':(551,810,710,1199),'cafe_board':(940,883,1188,1175),
 'bus_stop':(12,56,455,366),'bike_rack':(467,143,815,365),'fountain':(837,63,1245,371),
 'flagpole':(103,393,345,798),'kiosk_flower':(448,459,802,761),'billboard':(835,423,1243,798),
 'business_board':(37,830,407,1208),'railing':(428,960,835,1111),'umbrella_table_blue':(860,810,1227,1208)}

def run():
    rows=[]
    crops={}
    for atlas,names in SETS.items():
        path=SOURCE/(atlas+'.png')
        if not path.exists():
            continue
        original=Image.open(path).convert('RGBA')
        for i,name in enumerate(names):
            columns=4 if atlas=='market' else 3
            atlas_rows=1 if atlas=='market' else 3
            rect=(round(i%columns*original.width/columns),round(i//columns*original.height/atlas_rows),round((i%columns+1)*original.width/columns),round((i//columns+1)*original.height/atlas_rows))
            if atlas=='market':
                # Generator varies column widths; inspected object bounds preserve all stall supports.
                edges=[0,524,1035,1550,original.width]
                rect=(edges[i],0,edges[i+1],original.height)
            else:
                rect=BOUNDS[name]
            cell=original.crop(rect)
            bounds=cell.getchannel('A').point(lambda a:255 if a>96 else 0).getbbox()
            assert bounds,name
            cell=cell.crop(bounds)
            logical=Image.open(ASSETS/'props'/(name+'.png')).size
            size=tuple(x*4 for x in logical)
            ratio=min(size[0]/cell.width,size[1]/cell.height)
            cell=cell.resize((round(cell.width*ratio),round(cell.height*ratio)),Image.Resampling.LANCZOS)
            # Respect design footprint overhang: top/left meta still uses original coordinates.
            out=Image.new('RGBA',size)
            out.alpha_composite(cell,((size[0]-cell.width)//2,size[1]-cell.height))
            variants={'':out}
            if name=='digital_sign':
                a=np.asarray(out).copy();rgb=a[:,:,:3].astype(float)
                mask=(rgb[:,:,2]>160)&(rgb[:,:,1]>140)&(rgb[:,:,2]>rgb[:,:,0]*1.10)
                a[:,:,3]=np.where(mask,a[:,:,3],0)
                variants['_lights']=Image.fromarray(a)
            if name=='string_lights':
                a=np.asarray(out).copy();rgb=a[:,:,:3].astype(float)
                mask=(rgb[:,:,0]>200)&(rgb[:,:,1]>130)&(rgb[:,:,0]>rgb[:,:,2]*1.35)
                a[:,:,3]=np.where(mask,a[:,:,3],0)
                variants['_lights']=Image.fromarray(a)
            for suffix,im in variants.items():
                for folder,bitmap in [('props',im.resize(logical,Image.Resampling.LANCZOS)),('world_detail/props',im)]:
                    dest=ASSETS/folder/(name+suffix+'.png');dest.parent.mkdir(parents=True,exist_ok=True);bitmap.save(dest)
                    rows.append({'path':dest.relative_to(ROOT).as_posix(),'size':list(bitmap.size),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
            crops[name]={'atlas':atlas,'cell':rect,'bounds':bounds,'size':size}
    (SOURCE/'manifest.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    (SOURCE/'crops.json').write_text(json.dumps(crops,indent=2)+'\n',encoding='utf-8')
    print(f'street_utilities_pack: {len(crops)} props, {len(rows)} native/detail PNG, unchanged logical footprints')

if __name__=='__main__':
    run()
