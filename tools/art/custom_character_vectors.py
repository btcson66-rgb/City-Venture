"""Editable, shared high-resolution character art. SVG geometry, not bitmap enlargement.

All appearances use one 32x48 logical rig. Each source renders directly at 4x,
and the same curves drive the face, hair and clothing in the portrait.
No game data, body capabilities, collision footprints or save keys change.
"""
from pathlib import Path
import json, math, sys

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'docs/art_sources/custom_character_20261001/vectors'
ASSETS=ROOT/'game/assets'
INK='#24344e'
_clip_seq=0
def bob(pose,tick):
    return [0,-.45,0,-.45][tick] if pose in ['', 'carry'] else 0 if pose=='sit' else [0,-.18,0,-.18][tick]
HAIR_BOXES=json.loads((SOURCE.parent/'hair_boxes.json').read_text()) if (SOURCE.parent/'hair_boxes.json').exists() else {}

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
def head(face='round',direction=0):
    if direction==2:
        return path('M 13.5 16 L 18.5 16 L 18.7 21 Q 16 23 13.3 21 Z','url(#skin)','#999',.18)
    im=material('head',face,direction,(10.5,3.5,12.5,18) if direction==1 else (8.2,3.5,15.6,18))
    if im:
        global _clip_seq
        _clip_seq+=1;cid=f'scalp_{_clip_seq}'
        return f'<defs><clipPath id="{cid}"><rect x="6" y="{6 if direction==1 else 7}" width="22" height="18"/></clipPath></defs><g clip-path="url(#{cid})">{im}</g>'
    if direction==1:
        shape='M 11 6 C 12 3 19 3 21 7 L 21 11 L 22.3 12.5 Q 23 13 21.5 13.8 L 21.2 16 Q 20.5 19 16.4 19 Q 11 18 10.8 12 Z'
        ear=ellipse(13.4,12.7,1.2,1.6,'url(#skin)','#999',.24)
    else:
        shapes={'round':'M 9.2 8 C 9.2 3 22.8 3 22.8 8 L 22.3 13 Q 22 18 16 19.3 Q 10 18 9.7 13 Z',
         'oval':'M 10 8 C 10 3 22 3 22 8 L 21.6 14 Q 21 18.5 16 19.6 Q 11 18.5 10.4 14 Z',
         'square':'M 9 8 C 9 3 23 3 23 8 L 22.6 16 Q 21.5 18.6 19 19 L 13 19 Q 10.4 18.6 9.4 16 Z',
         'heart':'M 9 8 C 9 3 23 3 23 8 Q 23 12 21.5 14.5 L 17.3 19 Q 16 20 14.7 19 L 10.5 14.5 Q 9 12 9 8 Z'}
        shape=shapes[face]
        ear=ellipse(9.3,12.5,.95,1.7,'url(#skin)','#b0b0b0',.24)+ellipse(22.7,12.5,.95,1.7,'url(#skin)','#aaa',.24)
    result=path('M 13.5 16 L 18.5 16 L 18.7 21 Q 16 23 13.3 21 Z','url(#skin)')+ear+path(shape,'url(#skin)','#8b8b8b',.25)
    if direction!=2:
        result+=line('M 17.1 12.8 Q 16.4 14.9 17.4 15.3 L 16.5 15.6','#acacac',.28)+line('M 13.5 18 Q 16 19 18.3 17.9','#b7b7b7',.2)
        result+=ellipse(11.2,15.2,.85,.45,'#ececec')+ellipse(20.3,15.2,.85,.45,'#d5d5d5')
    return textured(result,'head',face,direction,(8.2,3.5,15.6,18))
HAIR={
 'messy':'M 8.1 11 L 7.8 7.2 L 10 7 L 9 4.5 L 12.8 5 L 12 2.8 L 16 4 L 17.5 2.5 L 19 4.3 L 22.1 3.8 L 21.7 6 L 24.1 6.7 L 23 10.5 L 21.6 13 L 20.8 8.6 L 18 10 L 18.4 7.3 L 14.4 10.3 L 14.8 7.7 L 11.1 11 L 10.7 9.2 L 9.7 13 Z',
 'short_neat':'M 8.9 11 L 9.1 7 C 9 2.3 22.9 2.3 23 7 L 22.3 12.7 L 20.9 9 L 21 6.8 Q 15 8 11 7.5 L 10.6 12.6 Z',
 'buzz':'M 9.4 9.5 L 9.4 6.8 C 10 2.8 22 2.8 22.6 6.8 L 22.6 10 L 21.5 7.9 Q 16 6 10.5 8.1 Z',
 'side_part':'M 8.7 12 L 8.5 7 C 9 1.4 23 2.4 23.1 7 L 22 13 L 20.9 8.5 L 20 6.5 Q 14.8 11.5 10.7 10 L 10.4 13 Z',
 'bob':'M 8 18 L 7.5 8 C 7.4 1.1 24.6 1.1 24.5 8 L 24 18 L 21.6 18 L 21.1 9.7 L 19.5 7.5 L 18 10 L 12.2 8.3 L 10.8 11 L 10.4 18 Z',
 'long':'M 7.3 22 L 7.5 8 C 8 1 24 1 24.5 8 L 24.7 22 L 21.8 21 L 21.2 10 Q 17 10 15.1 7.4 L 12 10.2 L 10.8 9.5 L 10.2 21 Z',
 'ponytail':'M 8.5 11 L 8.7 7 C 8.5 2.1 23.5 2.1 23.2 7 L 22.2 12.3 L 21 8.8 Q 16 9 12.1 7.3 L 10.8 10.4 L 10.2 13 Z',
 'bun':'M 9 11 L 9 7 C 9 2.4 23 2.4 23 7 L 22 12 L 21 8.6 Q 16 9 11 7.8 L 10.8 12.2 Z'}
def hair(style,front=True,direction=0):
    box=HAIR_BOXES.get(style, {}).get(str(direction),(8,2.5,16,15))
    if style=='ponytail' and direction==0:box=(7.1,2.2,20.2,20.5)
    im=material('hair',style,direction,box)
    if im:return im if front else ''
    back=''
    if style=='long':back=path('M 8 7 Q 16 0 24 7 L 24 25 Q 21 26 19 24 Q 15 27 12 24 L 8 25 Z','url(#hair)','#707070',.22)
    elif style=='bob':back=path('M 8 7 Q 16 1 24 7 L 24 20 Q 16 22 8 20 Z','url(#hair)','#707070',.22)
    elif style=='ponytail':back=path('M 20 6 Q 28 4 25.5 14 Q 25 20 21 22 Q 23 17 20.7 14 Q 18 10 20 6 Z','url(#hair)','#707070',.22)
    elif style=='bun':back=ellipse(19,3.6,3.7,2.7,'url(#hair)','#666',.22)
    if not front:return back
    shape=HAIR[style]
    if direction==1:
        shape={'messy':'M 10 11 L 9 6 L 11 5 L 10.7 3.8 L 14 4 L 16 2.5 L 18 4 L 22 4.6 L 23 7 L 20.5 8.9 L 18.3 7.5 L 15 9.5 L 15.4 12 L 13.6 11 L 12 14 Z',
        'short_neat':'M 10 13 L 9.6 7 Q 10 2.5 19 3.7 Q 23 4.2 22 7.5 L 18 8 L 15.7 10 L 14.8 13 L 13 11 L 12 14 Z',
        'buzz':'M 10.3 12 L 10 7 Q 10.7 3.2 18.7 3.8 L 21.5 5.2 L 21.8 7 L 17 7.9 L 14.6 9 L 13 12 Z',
        'side_part':'M 10 13 L 9.3 7 Q 10 2.2 19.8 3.5 Q 24 4 22 7.6 L 18.3 10 L 17 8.2 L 14.5 11 L 13 14 Z',
        'bob':'M 8.8 19 L 8 7 Q 9 1.6 19 3.2 Q 24 4 22.5 8 L 19 10 L 17 7.8 L 16 12 L 16 18 Q 13 21 8.8 19 Z',
        'long':'M 8 24 L 8 7 Q 10 1.5 19 3.2 Q 24 4 22 8.6 L 19 10 L 17 8 L 16 14 L 17 24 Q 12 26 8 24 Z',
        'ponytail':'M 10 13 L 9 7 Q 10 2.6 19 3.2 Q 22 4 22 8 L 18 9 Q 15 9 14 12 L 12 14 Z',
        'bun':'M 10 13 L 9.5 7 Q 10 2.9 19 3.8 L 22 5 L 21.6 8 L 17 8.8 L 14.4 12 L 12.5 13.7 Z'}[style]
    if direction==2:
        shape='M 9 7 Q 9 1.5 23 5 Q 25 12 22 16 Q 17 19 10 15 Q 8 11 9 7 Z'
        if style in ('long','bob'):shape=HAIR[style].replace('L 21.6 18 L 21.1 9.7 L 19.5 7.5 L 18 10 L 12.2 8.3 L 10.8 11 L 10.4 18','') if style=='bob' else 'M 8 7 Q 8 1 24 5 L 24 24 Q 20 26 17 24 Q 14 26 8 24 Z'
    result=path(shape,'url(#hair)','#686868',.23)
    if style!='buzz':
        result+=line('M 11 6 Q 14 4 17.5 5 M 12.5 5.6 Q 15.5 4.6 18.5 5.4','#ededed',.24)
        result+=line('M 20 6 Q 22 8 21.5 10 M 10.5 8 Q 11 9 10.9 10.7','#a2a2a2',.22)
    return result
def eye_pair(shape='round',expression=0,direction=0,part='eyes'):
    if direction==2:return ''
    result=''; positions=[(12,11.3),(19,11.3)] if direction==0 else [(19.1,11.3)]
    height={'round':1.12,'almond':.92,'narrow':.65,'wide':1.38}[shape]
    for x,y in positions:
        if expression==1:
            if part=='eyes':result+=line(f'M {x-1.8} {y+.3} Q {x} {y-1.4} {x+1.8} {y+.3}',INK,.48)
            continue
        hh=height*(1.25 if expression==3 else .85 if expression==2 else 1)
        if part=='eyes':
            result+=path(f'M {x-1.65} {y} Q {x} {y-hh*1.8} {x+1.65} {y} Q {x+1.5} {y+hh} {x} {y+hh} Q {x-1.5} {y+hh} {x-1.65} {y} Z','#f8f8fa','#44383e',.22)
            result+=line(f'M {x-1.75} {y-.15} Q {x} {y-hh*1.7} {x+1.75} {y-.15}','#392d35',.32)
        elif part=='eyes_detail':
            xx=x+(.4 if expression==2 else 0)
            result+=ellipse(xx-.26,y-.5,.23,.3,'#fff')+ellipse(xx+.3,y+.48,.11,.14,'#f7f6ee')
        else:
            xx=x+(.4 if expression==2 else 0)
            result+=ellipse(xx,y,.87,hh*.83,'url(#iris)','#555',.2)+ellipse(xx,y,.34,hh*.71,'#202020')
            result+=line(f'M {xx-.58} {y+.34} L {xx-.43} {y+.5} M {xx+.56} {y+.34} L {xx+.43} {y+.5}','#a3a3a3',.12)
    return result
def brow(style='straight',expression=0,direction=0):
    if direction==2:return ''
    result='';ys=[9.0,9.0]
    if expression==1:ys=[8.7,8.7]
    elif expression==2:ys=[9.2,8.1]
    elif expression==3:ys=[7.7,7.7]
    for i,x in enumerate([12,19] if direction==0 else [19.1]):
        y=ys[i];curve=y-(.6 if style=='arched' else .2)
        result+=line(f'M {x-1.7} {y} Q {x} {curve} {x+1.7} {y-.1}','#c8c8c8' if style=='soft' else '#f5f5f5',.7 if style=='thick' else .37)
    return result
def mouth(style='smile',expression=0,direction=0):
    if direction==2:return ''
    x=16 if direction==0 else 20.5;y=16.5
    if expression==3:return ellipse(x,y,.65,1.05,'#643e46','#77515a',.22)+ellipse(x,y+.3,.35,.3,'#be7d83')
    if expression==1 or style=='grin':return path(f'M {x-1.8} {y-.25} Q {x} {y+.1} {x+1.8} {y-.25} Q {x+1.1} {y+1.65} {x} {y+1.5} Q {x-1.1} {y+1.65} {x-1.8} {y-.25} Z','#f8f6ef','#8c636b',.22)
    if expression==2 or style=='neutral':return line(f'M {x-1.1} {y+.3} Q {x} {y} {x+1.1} {y+.1}','#97717a',.3)
    if style=='small':return line(f'M {x-.6} {y} Q {x} {y+.4} {x+.6} {y}','#97717a',.3)
    return line(f'M {x-1.2} {y} Q {x} {y+.9} {x+1.2} {y}','#97717a',.3)
def body(pres,face,direction,tick,pose):
    b=bob(pose,tick)
    shift=[0,1.4,-1.4,.8][tick] if pose in ['', 'carry'] else 0
    sx={'masculine':8.8,'feminine':10.4,'neutral':9.6}[pres];right=32-sx
    if direction==1:sx=12;right=21
    yend=43.8
    result=group(head(face,direction),'translate(2.24 2.66) scale(.86)')
    if pose=='sit':result=group(result,'translate(0 3)')
    result+=path(f'M {sx+2} 20 Q 16 18.5 {right-2} 20 L {right} 32 Q 16 34 {sx} 32 Z','url(#skin)')
    for side,x in enumerate([sx-.5,right-.8]):
        delta=shift if side==0 else -shift
        if pose in ('phone','interact','carry'):
            yy=25 if pose=='phone' else 29
            xx=17 if pose=='phone' else x+(-3 if side else 3)
            result+=path(f'M {x} 22 Q {x-1} 27 {x} 30 Q {x+1} 31 {xx} {yy} L {xx+1.4} {yy+1.5} Q {x+3} 34 {x+2} 30 L {x+2} 22 Z','url(#skin)','#aeaeae',.18)
        else:result+=path(f'M {x} 21 Q {x-1.4} 24 {x-.8+delta*.25} 29 L {x-.8+delta*.25} 33 Q {x+.2} 34.8 {x+1.5+delta*.25} 33 L {x+2} 24 Z','url(#skin)','#a5a5a5',.18)
    result+=path(f'M {sx+2} 31 L {right-2} 31 L {right-3} {yend} L {right-5.7} {yend} L 16 35 L {sx+5.7} {yend} L {sx+3} {yend} Z','url(#skin)')
    return group(result,f'translate(0 {b})')
OUTFITS=['startup_casual','office_professional','home','barista','business_suit','civic_staff','courier','casual_tee','casual_jacket']
def clothing(oid,pres,direction,tick,pose,part):
    sx={'masculine':8.1,'feminine':9.7,'neutral':8.9}[pres];r=32-sx
    if direction==1:sx=11.7;r=21.6
    b=bob(pose,tick);swing=[0,1.4,-1.4,.8][tick] if pose in ['', 'carry'] else 0
    yend=43.8
    gray=oid in ['business_suit','courier','casual_tee','casual_jacket']
    color='url(#cloth)' if gray else 'url(#white)' if oid=='office_professional' else 'url(#navy)' if oid!='home' else '#a7b4c8'
    inner='url(#white)';bottom='url(#cloth)' if gray else 'url(#denim)' if oid=='startup_casual' else 'url(#navy)'
    result=''
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
        if oid in ['startup_casual','business_suit','casual_jacket'] and direction!=2 and not (SOURCE.parent/'components'/f'clothing_{oid}_{direction}.png').exists():
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
    if part in ['top','bottom','shoes']:
        width={'masculine':18.1,'feminine':14.9,'neutral':16.5}[pres]
        box=((32-width)/2,19,width,27) if direction!=1 else (10.5,19,12.7,27)
        result=textured(result,'clothing',oid,direction,box)
    return group(result,f'translate(0 {b})')
def accessory(kind,direction,pose):
    if kind=='backpack':
        if direction==0:
            return line('M 10 20 Q 9.8 24 11 29 M 22 20 Q 22.2 24 21 29','#71543b',1.1)+line('M 10.2 20 L 11.2 28.5 M 21.8 20 L 20.8 28.5','#c8a580',.25)+rect(10.1,26,1.4,1,'#b8bdc6',.15)+rect(20.5,26,1.4,1,'#b8bdc6',.15)
        if direction==1:
            return path('M 9.6 20.5 Q 7 20.5 7 24 L 7.8 32 Q 9.8 34 12.1 32 L 11.7 22 Z','url(#leather)',INK,.3)+line('M 8.1 23 L 8.6 30 M 9.2 21 Q 13 19 14.2 22 L 15 28','#bca17e',.32)+path('M 7.7 27 L 10.9 26.4 L 11.1 30.4 L 8 31 Z','#836345',INK,.18)+line('M 8.2 28 L 10.3 27.6','#bc9b76',.2)
        return path('M 10.5 21 Q 16 18.5 21.5 21 L 21.7 31.6 Q 16 34.2 10.3 31.6 Z','url(#leather)',INK,.3)+path('M 14 20 Q 16 17.4 18 20','none','#765943',.5)+rect(11.8,26,8.4,5,'#8c6b4b',1,INK)+line('M 12.3 26.7 L 19.7 26.7 M 11.5 23 Q 16 22 20.5 23 M 11.1 24 L 11.1 29.7 M 20.9 24 L 20.9 29.7','#c4a27d',.2)+rect(15.2,23,1.6,1.3,'#b8b6ac',.2)
    if direction==2:return ''
    shape='round' if kind.endswith('round') else 'square';result=''
    xs=[12,19] if direction==0 else [19]
    for x in xs:result+=(ellipse(x,11.7,2.3,2,'none',INK,.35) if shape=='round' else rect(x-2.3,10,4.6,3.5,'none',.6,INK))
    if direction==0:result+=line('M 14.3 11.4 Q 16 10.9 16.7 11.4',INK,.3)
    return result
def svg(w,h,content):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*4}" height="{h*4}" viewBox="0 0 {w} {h}">{DEFS}{content}</svg>'
def build():
    SOURCE.mkdir(parents=True,exist_ok=True);jobs=[]
    opts=json.loads((ROOT/'game/data/character/options.json').read_text())
    cs=[]
    for pres in ['masculine','feminine','neutral']:
        for face in ['round','oval','square','heart']:cs.append(('body_'+pres+'_'+face,lambda d,f,p,pr=pres,fa=face:body(pr,fa,d,f,p)))
    for ha in HAIR:
        for side in ['back','front']:cs.append(('hair_'+ha+'_'+side,lambda d,f,p,ha=ha,side=side:hair(ha,side=='front',d)))
    for eye in ['round','almond','narrow','wide']:
        for part in ['eyes','iris','eyes_detail']:
            cs.append((part+'_'+eye,lambda d,f,p,eye=eye,part=part:eye_pair(eye,0,d,part)))
            cs.append((part+'_'+eye+'_expressions',lambda d,f,p,eye=eye,part=part:eye_pair(eye,f,d,part)))
    for br in ['straight','arched','thick','soft']:
        cs.append(('brows_'+br,lambda d,f,p,br=br:brow(br,0,d)))
        cs.append(('brows_'+br+'_expressions',lambda d,f,p,br=br:brow(br,f,d)))
    for mo in ['smile','neutral','grin','small']:
        cs.append(('mouth_'+mo,lambda d,f,p,mo=mo:mouth(mo,0,d)))
        cs.append(('mouth_'+mo+'_expressions',lambda d,f,p,mo=mo:mouth(mo,f,d)))
    for oid in OUTFITS:
        for pr in ['masculine','feminine','neutral']:
            for part in ['top','bottom','shoes']+(['top_detail'] if oid in ['business_suit','courier','barista','civic_staff'] else []):cs.append(('outfit_'+oid+'_'+pr+'_'+part,lambda d,f,p,o=oid,pr=pr,part=part:clothing(o,pr,d,f,p,part)))
    for acc in ['glasses_round','glasses_square','backpack']:cs.append(('acc_'+acc,lambda d,f,p,acc=acc:accessory(acc,d,p)))
    for name,fn in cs:
        for pose in ['', 'sit','idle','phone','interact','carry']:
            content=''
            for row in range(3):
                for f in range(4):
                    cell=fn(row,f,pose)
                    if name.startswith(('hair_','eyes_','iris_','brows_','mouth_','acc_glasses')):
                        cell=group(cell,'translate(2.24 2.66) scale(.86)')
                        dy=3 if pose=='sit' else 0 if name.endswith('_expressions') else bob(pose,f)
                        if name.startswith('acc_glasses') and pose in ['idle','phone','interact']:dy=0
                        cell=group(cell,f'translate(0 {dy})')
                    content+=group(cell,f'translate({f*32} {row*48})')
            key='characters/'+name+('_'+pose if pose else '')
            p=SOURCE/(key.replace('/','_')+'.svg');p.write_text(svg(128,144,content));jobs.append({'source':p.relative_to(ROOT).as_posix(),'key':key,'size':[128,144]})
    ps=[]
    # Portrait shares the very same face/hair curves, including four expressions.
    transform='translate(-9 -4) scale(2.6)'
    for face in ['round','oval','square','heart']:ps.append(('head_'+face,1,lambda e,face=face:head(face)))
    for ha in HAIR:
        for side in ['back','front']:ps.append(('hair_'+ha+'_'+side,1,lambda e,ha=ha,side=side:hair(ha,side=='front')))
    for eye in ['round','almond','narrow','wide']:
        for part in ['eyes','iris','eyes_detail']:ps.append((part+'_'+eye,4,lambda e,eye=eye,part=part:eye_pair(eye,e,0,part)))
    for br in ['straight','arched','thick','soft']:ps.append(('brows_'+br,4,lambda e,br=br:brow(br,e)))
    for mo in ['smile','neutral','grin','small']:ps.append(('mouth_'+mo,4,lambda e,mo=mo:mouth(mo,e)))
    for oid in OUTFITS:
        ps.append(('outfit_'+oid,1,lambda e,oid=oid:clothing(oid,'neutral',0,0,'','top')))
        if oid in ['business_suit','courier','barista','civic_staff']:ps.append(('outfit_'+oid+'_detail',1,lambda e,oid=oid:clothing(oid,'neutral',0,0,'','top_detail')))
    for acc in ['glasses_round','glasses_square','backpack']:ps.append(('acc_'+acc,1,lambda e,acc=acc:accessory(acc,0,'')))
    for name,n,fn in ps:
        content=''.join(group(group(fn(i),transform),f'translate({i*64} 0)') for i in range(n))
        key='portraits/'+name;p=SOURCE/(key.replace('/','_')+'.svg');p.write_text(svg(64*n,64,content));jobs.append({'source':p.relative_to(ROOT).as_posix(),'key':key,'size':[64*n,64]})
    (SOURCE.parent/'render_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
    print('Editable vector sources:',len(jobs))
if __name__=='__main__':build()
