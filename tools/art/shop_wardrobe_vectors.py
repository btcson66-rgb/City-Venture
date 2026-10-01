"""Five shop outfits on a shared editable rig; no gameplay or options changes."""
from pathlib import Path
import json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'docs/art_sources/shop_wardrobe_20261001/vectors'
INK='#24344e'
_clip_seq=0
def compatibility_sleeve(garment,pres,direction,tick,pose):
    global _clip_seq
    name='outfit_business_suit_'+pres+'_top'+('_'+pose if pose else '')+'.png'
    mask=Image.open(SOURCE.parent/'rig_masks'/name).crop((tick*32,direction*48,(tick+1)*32,(direction+1)*48))
    pixels=mask.load();shape=''
    for y in range(48):
        start=None
        for x in range(33):
            opaque=x<32 and pixels[x,y]>96
            if opaque and start is None:start=x
            if not opaque and start is not None:
                shape+=rect(start,y,x-start,1,'white',0);start=None
    _clip_seq+=1;cid=f'legacy_rig_{_clip_seq}'
    pattern=f'<pattern id="{cid}" width="4" height="4" patternUnits="userSpaceOnUse"><image href="../components/fabric_{garment}_{direction}.png" width="4" height="4"/></pattern>'
    return f'<defs>{pattern}</defs>'+shape.replace('fill="white"',f'fill="url(#{cid})"')
def bob(pose,tick):
    return [0,-.45,0,-.45][tick] if pose in ['', 'carry'] else 0 if pose=='sit' else [0,-.18,0,-.18][tick]

def material(family,key,direction,box):
    component=SOURCE.parent/'components'/f'{family}_{key}_{direction}.png'
    if not component.exists():return ''
    x,y,w,h=box
    return f'<image href="../components/{component.name}" x="{x}" y="{y}" width="{w}" height="{h}" preserveAspectRatio="none"/>'

def textured(content,family,key,direction,box):
    global _clip_seq
    im=material(family,key,direction,box)
    if not im:return content
    _clip_seq+=1;cid=f'texture_{_clip_seq}'
    return content+f'<defs><clipPath id="{cid}">{content}</clipPath></defs><g clip-path="url(#{cid})">{im}</g>'

def path(d,fill,stroke=None,width=.35):
    return f'<path d="{d}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"' if stroke else '')+'/>'

def ellipse(x,y,rx,ry,fill,stroke=None,width=.35):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{width}"' if stroke else '')+'/>'

def line(d,color,width=.35):return path(d,'none',color,width)

def rect(x,y,w,h,fill,rx=.2,stroke=None):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width=".3"' if stroke else '')+'/>'

def group(content,transform=''):return f'<g transform="{transform}">{content}</g>'

DEFS='''<defs>
 <linearGradient id="skin" x1="0" y1="0" x2="1" y2=".7"><stop stop-color="#ffffff"/><stop offset=".48" stop-color="#f3f3f3"/><stop offset="1" stop-color="#b9b9b9"/></linearGradient>
 <linearGradient id="hair" x1="0" y1="0" x2=".9" y2="1"><stop stop-color="#ffffff"/><stop offset=".33" stop-color="#dbdbdb"/><stop offset=".76" stop-color="#909090"/><stop offset="1" stop-color="#666666"/></linearGradient>
 <linearGradient id="cloth" x1="0" y1="0" x2="1" y2=".7"><stop stop-color="#eeeeee"/><stop offset=".4" stop-color="#bbbbbb"/><stop offset="1" stop-color="#717171"/></linearGradient>
 <linearGradient id="navy" x1="0" y1="0" x2="1" y2=".7"><stop stop-color="#50647d"/><stop offset=".5" stop-color="#344157"/><stop offset="1" stop-color="#1d293d"/></linearGradient>
 <linearGradient id="white" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#faf8f3"/><stop offset=".65" stop-color="#dedfe4"/><stop offset="1" stop-color="#a9b6c8"/></linearGradient>
 <linearGradient id="denim" x1="0" y1="0" x2="1" y2=".6"><stop stop-color="#657896"/><stop offset=".5" stop-color="#3b526e"/><stop offset="1" stop-color="#23364e"/></linearGradient>
 <radialGradient id="iris"><stop stop-color="#d8d8d8"/><stop offset=".65" stop-color="#fafafa"/><stop offset="1" stop-color="#707070"/></radialGradient>
 <linearGradient id="leather" x1="0" y1="0" x2="1" y2=".8"><stop stop-color="#bd9870"/><stop offset=".4" stop-color="#96714e"/><stop offset="1" stop-color="#594636"/></linearGradient>
 </defs>'''

def clothing(oid,pres,direction,tick,pose,part):
    garment=oid
    oid={'executive':'business_suit','formal_evening':'business_suit','luxury_citywear':'casual_jacket','travel':'casual_jacket','logistics_site':'casual_jacket'}[oid]
    sx={'masculine':8.1,'feminine':9.7,'neutral':8.9}[pres];r=32-sx
    if direction==1:sx=11.7;r=21.6
    b=bob(pose,tick);swing=[0,1.4,-1.4,.8][tick] if pose in ['', 'carry'] else 0
    yend=43.8
    gray=oid in ['business_suit','courier','casual_tee','casual_jacket']
    color='url(#cloth)' if gray else 'url(#white)' if oid=='office_professional' else 'url(#navy)' if oid!='home' else '#a7b4c8'
    inner='url(#white)';bottom='url(#cloth)' if gray else 'url(#denim)' if oid=='startup_casual' else 'url(#navy)'
    result=''
    if part=='top_detail':
        if direction==0:
            if garment in ['executive','formal_evening']:result=rect(13,19,6,9,'white')+rect(19,21,3,3,'white')
            elif garment=='luxury_citywear':result=rect(13,19,6,13,'white')
            elif garment=='travel':result=rect(18.7,28,5.3,6,'white')+path('M 13 19 L 21 29 L 20 30 L 12 20 Z','white')
            else:result=rect(11,24.5,10,2,'white')+rect(11,28.5,10,1.7,'white')+rect(7,20,4.6,12,'white')+rect(20.4,20,4.6,12,'white')
        elif direction==1:
            if garment in ['executive','formal_evening','luxury_citywear']:result=rect(18.3,19,3.7,10,'white')
            elif garment=='travel':result=rect(17.3,27,5.8,7,'white')
            else:result=rect(12,24.5,9,2,'white')+rect(12,28.5,9,1.7,'white')
        elif garment=='travel':result=rect(10.4,28,5.3,6,'white')+path('M 21 19 L 12 29 L 13 30 L 22 20 Z','white')
        elif garment=='logistics_site':result=rect(11,24.5,10,2,'white')+rect(11,28.5,10,1.7,'white')+rect(7,20,4.6,12,'white')+rect(20.4,20,4.6,12,'white')
        width={'masculine':18.1,'feminine':14.9,'neutral':16.5}[pres]
        box=((32-width)/2,19,width,27) if direction!=1 else (10.5,19,12.7,27)
        global _clip_seq
        _clip_seq+=1;cid=f'detail_{_clip_seq}'
        return f'<defs><clipPath id="{cid}" transform="translate(0 {b})">{result}</clipPath></defs><g clip-path="url(#{cid})">{group(material("clothing_color",garment,direction,box),f"translate(0 {b})")}</g>'
    if part=='bottom':
        if pose=='sit':
            if direction==1:result=path('M 12 32 L 21 32 L 27 36 Q 28 37 26 39 L 23 44 L 19.5 44 L 22 38 L 13 38 Z',bottom,INK,.25)
            else:result=path(f'M {sx+2} 31 L {r-2} 31 L {r} 37 L {r-1} 44 L {r-4.2} 44 L {r-4} 38 L 16 35.5 L {sx+4} 38 L {sx+4.2} 44 L {sx+1} 44 L {sx} 37 Z',bottom,INK,.25)
        else:
            result=path(f'M {sx+2} 31 L {r-2} 31 L {r-2+swing*.18} 44 L {r-5.1+swing*.18} 44 L 16 35 L {sx+5.1-swing*.18} 44 L {sx+2-swing*.18} 44 Z',bottom,INK,.25)
        result+=line(f'M {sx+3} 32 Q {sx+3} 34 {sx+5} 35 M {r-3} 32 Q {r-3} 34 {r-5} 35', '#6f839f' if not gray else '#ddd',.24)
        result+=line(f'M {sx+3.3} 37 L {sx+3.7} 41.8 M {r-3.3} 37 L {r-3.7} 41.8','#53647c' if not gray else '#999',.23)
        if oid=='office_professional' and pres=='feminine' and direction!=1:result=path(f'M {sx+2} 31 L {r-2} 31 L {r} 39 Q 16 40 {sx} 39 Z','url(#navy)',INK,.25)
    elif part=='shoes':
        xs=[sx+1.1-swing*.18,r-5.5+swing*.18] if direction!=1 else [11.4-swing*.2,17.6+swing*.2]
        if pose=='sit' and direction==1:xs=[19.1,22.3]
        for x in xs:
            result+=path(f'M {x} 43 L {x+3.5} 43 L {x+4.4} 45 Q {x+4.5} 46 {x+.1} 46 L {x-.3} 45 Z','url(#white)' if oid in ['startup_casual','home','casual_tee'] else '#2b3443',INK,.25)
            result+=line(f'M {x} 45.6 L {x+4.1} 45.6','#d8dce4',.25)
            if oid in ['startup_casual','home','casual_tee']:result+=line(f'M {x+1} 43.6 L {x+2.5} 43.6 M {x+1.1} 44.2 L {x+2.7} 44.2','#8c9aaa',.2)
    elif part=='top':
        result=path(f'M 13.5 19.3 Q {sx+1} 19 {sx} 21 L {sx+1.6} 31.8 Q 16 33 {r-1.6} 31.8 L {r} 21 Q {r-1} 19 18.5 19.3 L 16 22 Z',color,INK,.25)
        for side,x in enumerate([sx-1,r-1.2]):
            delta=swing if side==0 else -swing
            yy=27.8 if oid in ['office_professional','courier','casual_tee','barista'] else 31
            if pose in ('phone','interact','carry'):
                xx=17 if pose=='phone' else x+(3 if side==0 else -3);end=24.5 if pose=='phone' else 28.4
                result+=path(f'M {x} 20.5 Q {x-1} 24 {x} 28 L {xx} {end} L {xx+1.5} {end+1.5} L {x+2} 31 L {x+2.6} 22 Z',color,INK,.22)
            else:result+=path(f'M {x} 20.5 Q {x-1} 24 {x+delta*.25} {yy} L {x+2.4+delta*.25} {yy} L {x+2.6} 22 Z',color,INK,.22)
        if False:
            if direction==1:
                result+=path('M 18 19.5 L 20.5 21 L 21 32 L 18.5 32 Z',inner)+path('M 17 19.6 L 19.5 21.8 L 18.4 24 L 20 25.5 L 18.2 30 L 16.5 21 Z',color,INK,.2)
            else:
                result+=path('M 13.4 19.4 L 16 21 L 18.6 19.4 L 18 32 L 14 32 Z',inner)
                result+=path('M 12.8 19.4 L 15.1 21.8 L 13.7 24.1 L 15.7 25.2 L 13.8 30 L 12 21 Z',color,INK,.2)+path('M 19.2 19.4 L 16.9 21.8 L 18.3 24.1 L 16.3 25.2 L 18.2 30 L 20 21 Z',color,INK,.2)
        elif direction!=2:
            result+=line('M 13.1 19.8 Q 16 23 18.9 19.8', '#8c9cae' if not gray else '#888',.34)
            if oid=='home':result+=line('M 14 21.5 L 14 26 M 18 21.5 L 18 26','#e9ebed',.28)+line('M 12 29 Q 16 27 20 29 L 20 31 L 12 31 Z','#8999b1',.28)
        result+=line(f'M {sx+2.4} 27 L {sx+3.4} 29.4 M {r-2.4} 27 L {r-3.4} 29.4','#929eaf' if not gray else '#888',.24)
        if oid=='barista' and direction!=2:result+=path('M 12 21 L 20 21 L 21 32 L 11 32 Z','#bb9370',INK,.22)+rect(13,26,6,3,'#a78060')
        if oid=='civic_staff':result+=path('M 12 19 L 16 23 L 20 19 L 21 32 L 11 32 Z','url(#navy)',INK,.25)
        if oid=='office_professional' and direction!=2:result+=line('M 13.4 20 L 15.5 27 L 18.6 20','#35577e',.36)+rect(14.5,26.5,3,3,'#f5f5ef',.1,'#456681')
    elif part=='top_detail' and direction!=2:
        if oid=='business_suit':result=path('M 14 19.5 L 16 21 L 18 19.5 L 18 24 L 14 24 Z','url(#white)')+path('M 16 21 L 15.3 22.1 L 15.5 27 L 16 28 L 16.7 27 L 16.7 22.1 Z','#b55e60',INK,.12)
        elif oid=='courier':result=rect(18.3,22.1,2.7,1.3,'#e5cf9f',.1)+line('M 14 20 L 16 22 L 18 20','#f7edda',.3)
        elif oid=='barista':
            result=path('M 12 21 L 20 21 L 21 32 L 11 32 Z','#bb9370',INK,.22)+rect(13,26,6,3,'#a78060')
            result=textured(result,'clothing',oid,direction,(7.75,19,16.5,27))
        elif oid=='civic_staff':result=rect(18.8,22,2.3,1.2,'#d9b67b')
    if part=='top' and garment=='luxury_citywear':
        hem=37 if pose!='sit' else 38
        result+=path(f'M {sx+1.6} 29 L {r-1.6} 29 L {r-.4} {hem} Q 16 {hem+1} {sx+.4} {hem} Z',color,INK,.25)
    if part=='top' and garment=='travel':
        bag_x=18.7 if direction==0 else 10.7 if direction==2 else 17.6
        result+=rect(bag_x,29.1,4.6,4.5,'url(#leather)',.6,INK)
    if part in ['top','bottom','shoes']:
        width={'masculine':18.1,'feminine':14.9,'neutral':16.5}[pres]
        box=((32-width)/2,19,width,27) if direction!=1 else (10.5,19,12.7,27)
        result=textured(result,'clothing_color' if part=='shoes' else 'clothing',garment,direction,box)
    result=group(result,f'translate(0 {b})')
    if part=='top':result=compatibility_sleeve(garment,pres,direction,tick,pose)+result
    return result

def svg(w,h,content):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*4}" height="{h*4}" viewBox="0 0 {w} {h}">{DEFS}{content}</svg>'
OUTFITS=['executive','luxury_citywear','travel','formal_evening','logistics_site']
def build():
    SOURCE.mkdir(parents=True,exist_ok=True); jobs=[]
    for oid in OUTFITS:
        for pres in ['masculine','feminine','neutral']:
            for part in ['top','bottom','shoes','top_detail']:
                for pose in ['', 'sit','idle','phone','interact','carry']:
                    content=''.join(group(clothing(oid,pres,row,f,pose,part),f'translate({f*32} {row*48})') for row in range(3) for f in range(4))
                    key=f'characters/outfit_{oid}_{pres}_{part}'+('_'+pose if pose else '')
                    p=SOURCE/(key.replace('/','_')+'.svg');p.write_text(svg(128,144,content));jobs.append({'source':p.relative_to(ROOT).as_posix(),'key':key,'size':[128,144]})
        for part,suffix in [('top',''),('top_detail','_detail')]:
            key='portraits/outfit_'+oid+suffix
            p=SOURCE/(key.replace('/','_')+'.svg');p.write_text(svg(64,64,group(clothing(oid,'neutral',0,0,'',part),'translate(-9 -4) scale(2.6)')))
            jobs.append({'source':p.relative_to(ROOT).as_posix(),'key':key,'size':[64,64]})
    (SOURCE.parent/'render_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
    print('Editable shop outfit sources:',len(jobs))
if __name__=='__main__':build()
