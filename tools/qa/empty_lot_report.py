"""Audit 96px-wide frontage gaps and 96x96 street-side open lots, using native art geometry.

Sky behind facades, water and designated travel lanes are retained intentionally.
Trees alone do not complete a lot. Run before/after with --out <json>.
"""
from pathlib import Path
import argparse, json
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
DECORATIVE_ONLY = ('tree', 'planter', 'grass', 'flower', 'bollard')

def dimensions(folder, sprite):
    p = ROOT / 'game/assets' / folder / (sprite + '.png')
    if p.exists():
        with Image.open(p) as image: return image.size
    p = ROOT / 'game/assets/world_detail' / folder / (sprite + '.png')
    if p.exists():
        with Image.open(p) as image: return tuple(n // 4 for n in image.size)
    return (0, 0)

def frontage_spans(d):
    exteriors = [json.loads((ROOT / 'game/data/buildings' / (b + '.json')).read_text(encoding='utf-8'))['exterior'] for b in d.get('buildings', [])]
    spans = []
    for e in exteriors + d.get('fillers', []):
        w, h = dimensions('buildings', e['sprite'])
        if not w: w, h = dimensions('buildings', e.get('fallback', ''))
        spans.append((e['x'], e['x'] + w))
    return sorted(spans)

def intersects(a, b):
    x,y,w,h=a; u,v,r,s=b
    return x<u+r and u<x+w and y<v+s and v<y+h

def inspect(d):
    candidates=[]; end=0
    limit=int(d.get('walk_corridors', [[d['size_tiles'][0]*16]])[0][0])
    for a,b in frontage_spans(d)+[(limit, limit)]:
        if a-end>=96: candidates.append({'rect':[end,224,a-end,96], 'kind':'frontage'})
        end=max(end,b)
    # Full-size lower lots: exclude water, but bare paving is still a candidate.
    for x in range(0,limit-95,96):
        water=False
        for g in d.get('ground',[]):
            if 'water' in g['type'] and intersects([x,544,96,96], [n*16 for n in g['rect']]): water=True
        if not water: candidates.append({'rect':[x,544,96,96], 'kind':'street_side'})
    props=[]
    for p in d.get('props',[]):
        if any(k in p['sprite'] for k in DECORATIVE_ONLY):continue
        w,h=dimensions('props', p['sprite'])
        props.append([p['x'],p['y'],w,h])
    metro=d.get('metro',{})
    if metro:props.append([metro['x'],metro['y'],80,66])
    for c in candidates:
        r=c['rect']
        spaces=[s for s in d.get('public_spaces',[]) if intersects(r,s['rect']) and any(intersects(s['rect'],p) for p in props)]
        # A whole frontage gap needs explicit coverage, not one bench at its edge.
        if c['kind']=='frontage':
            covered=sum(max(0,min(r[0]+r[2],s['rect'][0]+s['rect'][2])-max(r[0],s['rect'][0])) for s in spaces)
            samples=[[x,r[1],min(96,r[0]+r[2]-x),r[3]] for x in range(int(r[0]),int(r[0]+r[2])-31,96)]
            c['handled']=covered>=r[2]-32 and all(any(intersects(sample,p) for p in props) for sample in samples)
        else:c['handled']=any(intersects(r,p) for p in props)
        c['spaces']=[s['name'] for s in spaces]
    return {'district':d['id'], 'lots':candidates, 'unhandled':sum(not c['handled'] for c in candidates),
            'retained':[{'rect':[0,0,limit,224],'reason':'Distant skyline behind the building row; not a playable lot.'},
                        {'rect':[0,320,d['size_tiles'][0]*16,224],'reason':'Pavements, crossings and through-road remain clear for travel.'},
                        {'rect':[limit,0,d['size_tiles'][0]*16-limit,d['size_tiles'][1]*16],'reason':'Narrow planted exit connector; preserve the unobstructed portal and crossing.'},
                        {'rect':[0,640,limit,d['size_tiles'][1]*16-640],'reason':'Clear promenade edge or waterfront behind the rest courts; not a building lot.'}]
                       +[{'rect':[n*16 for n in g['rect']], 'reason':'Waterfront water remains open; preserve shoreline and animated water.'} for g in d.get('ground',[]) if 'water' in g['type']]}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path);args=ap.parse_args()
    rows=[inspect(json.loads(p.read_text(encoding='utf-8'))) for p in sorted((ROOT/'game/data/districts').glob('*.json'))]
    report={'threshold_pixels':[96,96],'districts':rows,'unhandled':sum(r['unhandled'] for r in rows)}
    if args.out:args.out.parent.mkdir(parents=True,exist_ok=True);args.out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    for r in rows:print(f"{r['district']}: {r['unhandled']} unhandled / {len(r['lots'])} inspected lots")
    print(f"TOTAL: {report['unhandled']} unhandled lots; {len(rows)} districts")
    return bool(report['unhandled'])
if __name__=='__main__':raise SystemExit(main())
