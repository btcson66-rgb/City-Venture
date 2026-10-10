"""Audit complete vehicle silhouettes, combining body/detail layers before counting components."""
from pathlib import Path
from collections import deque
from PIL import Image
import json
ROOT = Path(__file__).resolve().parents[2]

def components(image):
    image.thumbnail((496, 496))
    alpha=image.getchannel('A'); w,h=image.size
    todo={(x,y) for y in range(h) for x in range(w) if alpha.getpixel((x,y))>32}
    sizes=[]
    while todo:
        q=deque([todo.pop()]); count=0
        while q:
            x,y=q.popleft(); count+=1
            for point in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if point in todo:todo.remove(point);q.append(point)
        sizes.append(count)
    return sorted(sizes,reverse=True)

def run():
    rows=[]; errors=[]
    for folder in [ROOT/'game/assets/vehicles',ROOT/'game/assets/world_detail/vehicles']:
        for path in sorted(folder.glob('*.png')):
            if path.stem.endswith(('_detail','_lights')):continue
            image=Image.open(path).convert('RGBA')
            if path.stem.endswith('_body'):
                detail=path.with_name(path.stem[:-5]+'_detail.png')
                if detail.exists():image.alpha_composite(Image.open(detail).convert('RGBA'))
            sizes=components(image)
            # Antialiasing flecks are harmless; a second substantial opaque vehicle is not.
            bodies=[n for n in sizes if n>=max(24,sizes[0]*0.12)] if sizes else []
            rows.append({'path':path.relative_to(ROOT).as_posix(),'components':sizes[:8],'main_bodies':len(bodies)})
            if len(bodies)!=1:errors.append(str(path.relative_to(ROOT)))
    print(json.dumps({'vehicles':rows,'failures':errors},indent=2))
    return len(errors)
if __name__=='__main__':raise SystemExit(bool(run()))
