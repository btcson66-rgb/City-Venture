"""Validate the canonical walking graph against district geometry. No third-party dependencies."""
from pathlib import Path
from collections import deque
import json, math, sys
ROOT=Path(__file__).resolve().parents[2]
OPPOSITE={'N':'S','E':'W','S':'N','W':'E'}
CELL=8

def direction(a,b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    return ('E' if dx>0 else 'W') if abs(dx)>abs(dy) else ('S' if dy>0 else 'N')

def geometry(d):
    w,h=[int(n)*16 for n in d['size_tiles']]
    top=float(d.get('bounds',{}).get('top',322))-2
    bottom=float(d.get('bounds',{}).get('bottom',h-8))
    solids=[]
    for y,height in [(0,top),(bottom,h-bottom)]:
        spans=[(0,w)]
        for c in d.get('walk_corridors',[]):
            if c[1]>=y+height or c[1]+c[3]<=y:continue
            spans=[part for a,b in spans for part in [(a,min(b,c[0])),(max(a,c[0]+c[2]),b)] if part[1]>part[0]]
        solids.extend((a,y,b-a,height) for a,b in spans)
    for p in d.get('props',[]):
        if isinstance(p.get('solid'),list):
            a,b,c,e=p['solid'];solids.append((p['x']+a,p['y']+b,c,e))
    m=d.get('metro',{})
    if m:solids.append((m['x']+6,m['y']+20,68,34))
    solids.extend([(-8,0,8,h),(w,0,10,h),(0,-8,w,8),(0,h,w,8)])
    return w,h,solids

def navigation(d):
    w,h,solids=geometry(d);nx,ny=w//CELL,h//CELL;blocked=set()
    for x,y,rw,rh in solids:
        for j in range(max(0,math.floor((y-4)/CELL)),min(ny,math.ceil((y+rh+3)/CELL))):
            for i in range(max(0,math.floor((x-6)/CELL)),min(nx,math.ceil((x+rw+6)/CELL))):blocked.add((i,j))
    # Ground with no paint, or water, is not a pedestrian route.
    for j in range(ny):
        for i in range(nx):
            tile=None
            for g in d.get('ground',[]):
                x,y,gw,gh=g['rect']
                if x<=i*CELL//16<x+gw and y<=j*CELL//16<y+gh and (i*CELL//16-x)%max(1,int(g.get('step',1)))==0:tile=g['type']
            if tile is None or 'water' in tile:blocked.add((i,j))
    return nx,ny,blocked

def check(city,districts):
    errors=[];graph=city.get('adjacency',{});positions={d['id']:d['map_pos'] for d in city['districts']}
    if set(graph)!=set(positions):errors.append('adjacency must include every city district')
    navs={k:navigation(d) for k,d in districts.items()}
    for a,neighbors in graph.items():
        if a not in districts:errors.append(f'{a}: missing district');continue
        d=districts[a];w,h,_=geometry(d);nx,ny,blocked=navs[a]
        exits=d.get('exits',[])
        if len(exits)!=len(neighbors) or {ex['to'] for ex in exits}!=set(neighbors):errors.append(f'{a}: exits must match neighbors exactly')
        # Check reachability from the existing metro pavement, including the player clearance used by AStar.
        m=d.get('metro',{});start=(int(m.get('x',32)+40)//CELL,int(m.get('y',280)+66)//CELL)
        reached=set();queue=deque([start])
        while queue:
            cell=queue.popleft()
            if cell in reached or cell in blocked or not (0<=cell[0]<nx and 0<=cell[1]<ny):continue
            reached.add(cell);i,j=cell;queue.extend([(i-1,j),(i+1,j),(i,j-1),(i,j+1)])
        for b,side in neighbors.items():
            if b not in graph or graph[b].get(a)!=OPPOSITE.get(side):errors.append(f'{a}>{b}: missing opposite adjacency');continue
            if side!=direction(positions[a],positions[b]):errors.append(f'{a}>{b}: wrong map_pos direction')
            rows=[ex for ex in exits if ex['to']==b]
            if len(rows)!=1:errors.append(f'{a}>{b}: needs exactly one exit');continue
            ex=rows[0];x,y,rw,rh=ex['rect']
            if ex.get('direction')!=side:errors.append(f'{a}>{b}: wrong exit direction')
            edges={'N':y==0,'S':y+rh==h,'W':x==0,'E':x+rw==w}
            if not edges.get(side):errors.append(f'{a}>{b}: exit is not on its matching edge')
            point=(int(x+rw/2)//CELL,int(y+rh/2)//CELL)
            if side=='E':point=(point[0]-1,point[1])
            if side=='S':point=(point[0],point[1]-1)
            if point not in reached:errors.append(f'{a}>{b}: exit blocked/unpainted/unreachable from metro')
            spawn=districts[b].get('spawns',{}).get(ex.get('spawn',''))
            if spawn is None:errors.append(f'{a}>{b}: target spawn missing');continue
            tw,th,_=geometry(districts[b]);tnx,tny,tblocked=navs[b];sc=(int(spawn[0])//CELL,int(spawn[1])//CELL)
            if not(0<=sc[0]<tnx and 0<=sc[1]<tny) or sc in tblocked:errors.append(f'{a}>{b}: spawn blocked/unpainted')
            opposite=OPPOSITE[side]
            on_side={'W':spawn[0]<=80,'E':spawn[0]>=tw-80,'N':spawn[1]<=80,'S':spawn[1]>=th-80}
            if not on_side[opposite]:errors.append(f'{a}>{b}: spawn must enter from {opposite}')
            if any(r['rect'][0]<=spawn[0]<=r['rect'][0]+r['rect'][2] and r['rect'][1]<=spawn[1]<=r['rect'][1]+r['rect'][3] for r in districts[b].get('exits',[])):errors.append(f'{a}>{b}: spawn retriggers an exit')
    if graph:
        seen=set();queue=list(graph)[:1]
        while queue:
            a=queue.pop()
            if a in seen:continue
            seen.add(a);queue.extend(graph.get(a,{}))
        if seen!=set(graph):errors.append('walking graph is disconnected')
    return errors

def load():
    city=json.loads((ROOT/'game/data/city/aurelia.json').read_text(encoding='utf-8'))
    districts={p.stem:json.loads(p.read_text(encoding='utf-8')) for p in (ROOT/'game/data/districts').glob('*.json')}
    return city,districts

if __name__=='__main__':
    city,districts=load();errors=check(city,districts)
    if errors:
        print('\n'.join(errors));sys.exit(1)
    print(f"map_adjacency_check: OK ({len(city['adjacency'])} districts, {sum(map(len,city['adjacency'].values()))//2} links, all exits/spawns reachable)")
