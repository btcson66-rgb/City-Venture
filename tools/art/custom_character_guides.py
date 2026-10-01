"""Produce editable component guides for the production texture passes."""
import custom_character_vectors as v
from pathlib import Path

root=v.SOURCE.parent
root.mkdir(parents=True,exist_ok=True)
hair=''
for col,style in enumerate(v.HAIR):
    for row in range(3):
        hair+=v.group(v.hair(style,False,row)+v.hair(style,True,row),f'translate({col*32} {row*48})')
(root/'hair_guide.svg').write_text(v.svg(256,144,hair))
cloth=''
for col,oid in enumerate(v.OUTFITS):
    for row in range(3):
        cell=''.join(v.clothing(oid,'neutral',row,0,'',part) for part in ['bottom','shoes','top','top_detail'])
        cloth+=v.group(cell,f'translate({col*32} {row*48})')
(root/'clothing_guide.svg').write_text(v.svg(288,144,cloth))
head=''
for col,face in enumerate(['round','oval','square','heart']):
    for row in range(3):
        head+=v.group(v.head(face,row),f'translate({col*32} {row*48})')
(root/'head_guide.svg').write_text(v.svg(128,144,head))
