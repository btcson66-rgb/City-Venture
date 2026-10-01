"""Losslessly separate generated atlas cells. No painting or substitute art generation."""
from pathlib import Path
from PIL import Image
import json
import numpy as np
from collections import deque
import custom_character_vectors as v

root=v.SOURCE.parent
target=root/'components';target.mkdir(exist_ok=True)
manifest={}
families={'hair':list(v.HAIR),'clothing':v.OUTFITS,'head':['round','oval','square','heart']}
for family,keys in families.items():
    atlas=Image.open(root/(family+'_material.png')).convert('RGBA')
    for col,key in enumerate(keys):
        for row in range(3):
            cell=atlas.crop((round(col*atlas.width/len(keys)),round(row*atlas.height/3),round((col+1)*atlas.width/len(keys)),round((row+1)*atlas.height/3)))
            # Atlas packing uses the principal subject's bounds, not stray low-alpha edge noise.
            # Pixel colour and alpha inside the crop are preserved unchanged.
            mask=np.array(cell.getchannel('A'))>96
            seen=np.zeros(mask.shape,dtype=bool);best=[]
            for yy,xx in zip(*np.nonzero(mask)):
                if seen[yy,xx]:continue
                queue=deque([(xx,yy)]);seen[yy,xx]=True;points=[]
                while queue:
                    x,y=queue.popleft();points.append((x,y))
                    for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                        if 0<=nx<cell.width and 0<=ny<cell.height and mask[ny,nx] and not seen[ny,nx]:
                            seen[ny,nx]=True;queue.append((nx,ny))
                if len(points)>len(best):best=points
            bounds=(max(0,min(x for x,y in best)-2),max(0,min(y for x,y in best)-2),min(cell.width,max(x for x,y in best)+3),min(cell.height,max(y for x,y in best)+3)) if best else None
            if not bounds:raise ValueError(f'Empty component {family}/{key}/{row}')
            component=cell.crop(bounds)
            if family in ['hair','head']:
                alpha=component.getchannel('A');component=component.convert('L').convert('RGBA');component.putalpha(alpha)
            name=f'{family}_{key}_{row}.png'
            component.save(target/name)
            manifest[name]={'source':f'{family}_material.png','cell':[col,row],'crop':list(map(int,bounds)),'size':list(component.size)}
(root/'component_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Packed generated material components:',len(manifest))
guide=Image.open(root/'hair_guide.png').convert('RGBA');boxes={}
for col,key in enumerate(v.HAIR):
    boxes[key]={}
    for row in range(3):
        cell=guide.crop((col*128,row*192,(col+1)*128,(row+1)*192))
        x,y,r,b=cell.getbbox()
        boxes[key][str(row)]=[x/4,y/4,(r-x)/4,(b-y)/4]
(root/'hair_boxes.json').write_text(json.dumps(boxes,indent=2)+'\n')
