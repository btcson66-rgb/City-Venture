"""Compose ground material atlas cells without changing any atlas coordinates."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'docs/art_sources/ground_materials_20261001'
def rect(x,y,w,h,color,opacity=1):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}" opacity="{opacity}"/>'
def line(x1,y1,x2,y2,color,width=.25):return f'<path d="M {x1} {y1} L {x2} {y2}" fill="none" stroke="{color}" stroke-width="{width}"/>'
def material(name):
    # Quiet material placement: avoid a four-way mirror pattern becoming visible at native size.
    colors={'asphalt':'#303b48','stone':'#c3beb1','water':'#28678f','grass':'#587847'}
    opacity=.28 if name in ['asphalt','stone'] else .38
    return rect(0,0,16,16,colors[name])+f'<image href="../originals/{name}.png" width="16" height="16" opacity="{opacity}" preserveAspectRatio="none"/>'
def stone_slabs(variant=0):
    body=material('stone')
    body+=line(0,8,16,8,'#938f83',.3)
    for x,y in [(4 if variant else 8,0),(12 if variant else 8,8)]:
        body+=line(x,y,x,y+8,'#938f83',.3)+line(x+.28,y+.4,x+.28,y+7.6,'#ded7c9',.2)
    return body
def tile(key):
    if key.startswith('grass'):
        body=material('grass')
        if key=='grass_flowers':
            for x,y,c in [(3.3,4.4,'#e0c775'),(10.8,10.3,'#c8859b'),(6.5,13.1,'#e7e5d4')]:
                body+=f'<circle cx="{x}" cy="{y}" r=".4" fill="{c}"/>'
        return body
    if key.startswith('water'):
        body=material('water')
        if key=='water_edge':body+=rect(0,0,16,4,'#c1b9a7')+line(0,4,16,4,'#747974',.45)
        if key=='water_harbor':body+=rect(0,0,16,16,'#17445b',.14)
        return body
    if key in ['sidewalk','sidewalk_alt','plaza','plaza_alt','quay_concrete']:return stone_slabs(key.endswith('alt'))
    if key.startswith('cobble'):
        body=material('stone')+rect(0,0,16,16,'#9c988d',.13)
        for y in range(0,16,4):
            body+=line(0,y,16,y,'#797b78',.4)
            for x in range(-4 if y%8 else 0,16,8):
                body+=line(x,y,x,y+4,'#797b78',.4)+line(x+.4,y+.4,x+7.6,y+.4,'#d9d0bd',.25)
        return body
    if key=='boards':
        body=rect(0,0,16,16,'#a08a6d')
        for y in range(0,16,4):
            body+=line(0,y,16,y,'#685f51',.35)+line(0,y+.6,16,y+.6,'#b7a286',.25)
            body+=f'<path d="M 0 {y+2} C 5 {y+1} 8 {y+3} 16 {y+2}" fill="none" stroke="#8d795f" stroke-width=".2"/>'
        return body
    if key=='garden':return material('stone')+rect(0,0,16,16,'#593f2e',.86)
    body=material('asphalt');white='#dddcd3';yellow='#cbb570'
    if key=='road_dash_h':body+=rect(2,7,10,2,white)
    elif key=='road_dash_v':body+=rect(7,2,2,10,white)
    elif key=='crosswalk_h':
        for x in [1,6,11]:body+=rect(x,0,3,16,white)
    elif key=='crosswalk_v':
        for y in [1,6,11]:body+=rect(0,y,16,3,white)
    elif key=='road_edge_top':body+=rect(0,1,16,.8,yellow)
    elif key=='road_edge_bottom':body+=rect(0,14,16,.8,yellow)
    elif key=='parking':body+=rect(0,0,1,16,white)
    elif key=='manhole':
        body+='<circle cx="8" cy="8" r="4.1" fill="#566067" stroke="#263541" stroke-width=".35"/>'
        for y in [5.5,7,8.5,10]:body+=line(5.5,y,10.5,y,'#818989',.3)
    elif key in ['curb_top','curb_bottom','quay_edge']:
        y=0 if key!='curb_bottom' else 12
        body+=rect(0,y,16,4,'#bab6aa')+line(0,y+.6,16,y+.6,'#d6d1c4',.3)+line(0,y+3.5,16,y+3.5,'#686f6d',.4)
        body+=line(8,y,8,y+4,'#979b93',.25)
        if key=='quay_edge':
            for x in range(0,16,4):body+=f'<path d="M {x} 4 L {x+2} 4 L {x+4} 6 L {x+2} 6 Z" fill="#c9af65"/>'
    return body
def main():
    index=json.loads((SRC/'baseline_atlas.json').read_text())['tiles'];out=SRC/'vectors';out.mkdir(exist_ok=True);jobs=[]
    for key,coord in index.items():
        if key.startswith(('floor_','wall_')):continue
        p=out/(key+'.svg');p.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 16 16">'+tile(key)+'</svg>')
        jobs.append({'key':key,'coord':coord,'source':p.relative_to(ROOT).as_posix()})
    (SRC/'render_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
    print('Editable ground sources:',len(jobs))
if __name__=='__main__':main()
