"""Editable UI geometry extends the established semantic icon system and navy surfaces."""
from pathlib import Path
from math import cos,pi,sin,radians
import json
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'docs/art_sources/ui_quality_20261001'
INK='#e8f2fa';BLUE='#66bef9';GOLD='#f6c465';GREEN='#71d3a0';RED='#fb897f';VIOLET='#c0a6f9'
S=8
ICONS=['cash', 'clock', 'calendar', 'sun', 'moon', 'objective', 'star', 'home', 'company', 'map', 'people', 'tasks', 'phone', 'inventory', 'parcel', 'orders', 'finance', 'contracts', 'bank', 'warning', 'check', 'lock', 'metro', 'mail', 'settings', 'save', 'laptop', 'coffee', 'arrow_right', 'close', 'plus', 'minus', 'walk', 'shop', 'civic', 'startup', 'river', 'financial', 'dollar', 'info', 'world', 'sleep', 'shirt']
def color(value):
    if value is None:return 'none'
    return value if isinstance(value,str) else '#'+''.join(f'{int(x):02x}' for x in value[:3])
def icon(name):
    parts=[]
    def line(points,c=INK,w=1.55):
        parts.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in points)+f'" fill="none" stroke="{color(c)}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')
    def rect(box,c=INK,fill=None,radius=1.2,w=1.5):
        x,y,r,b=box;parts.append(f'<rect x="{x}" y="{y}" width="{r-x}" height="{b-y}" rx="{radius}" fill="{color(fill)}" stroke="{color(c)}" stroke-width="{w}"/>')
    def ellipse(box,c=INK,fill=None,w=1.5):
        x,y,r,b=box;parts.append(f'<ellipse cx="{(x+r)/2}" cy="{(y+b)/2}" rx="{(r-x)/2}" ry="{(b-y)/2}" fill="{color(fill)}" stroke="{color(c)}" stroke-width="{w}"/>')
    def poly(points,c=INK,fill=None,w=1.5):
        parts.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in points)+f'" fill="{color(fill)}" stroke="{color(c)}" stroke-width="{w}" stroke-linejoin="round"/>')
    class Arc:
        def arc(self,box,start,end,fill,width):
            x,y,r,b=[v/S for v in box];cx,cy=(x+r)/2,(y+b)/2;rx,ry=(r-x)/2,(b-y)/2
            angles=[start+(end+360-start if end<start else end-start)*i/40 for i in range(41)]
            line([(cx+rx*cos(radians(a)),cy+ry*sin(radians(a))) for a in angles],fill,width/S)
    d=Arc()
    if name in ("sun","moon","clock","dollar","info","world"):
        ellipse((2.2,2.2,13.8,13.8), BLUE)
        if name == "sun":
            ellipse((5.1,5.1,10.9,10.9), GOLD, GOLD)
            for a in range(8):
                t=a*pi/4
                line([(8+7*cos(t),8+7*sin(t)),(8+5.8*cos(t),8+5.8*sin(t))],GOLD,1.2)
        elif name == "moon":
            ellipse((5.3,4.1,11.7,11.2),GOLD,GOLD)
            ellipse((7.6,2.7,13,8.7),BLUE,(22,43,72,255),0.7)
        elif name == "clock":
            line([(8,4.5),(8,8),(10.7,9.3)],INK,1.6)
        elif name == "dollar":
            line([(9.8,5.4),(6.5,5.4),(5.7,6.4),(9.6,8.1),(10,9.6),(6.4,10.5)],GREEN,1.5)
            line([(8,3.8),(8,12.2)],GREEN,1.2)
        elif name == "info":
            ellipse((7.25,4.2,8.75,5.7),INK,INK,0.5)
            line([(8,7.5),(8,11.4)],INK,1.8)
        else:
            ellipse((5.3,2.5,10.7,13.5),BLUE)
            line([(2.9,8),(13.1,8)],BLUE,1)
            line([(4,5),(12,5)],INK,0.9)
            line([(4,11),(12,11)],INK,0.9)
    elif name in ("star","objective"):
        pts=[(8+6.2*cos(-pi/2+i*pi/5),8+6.2*sin(-pi/2+i*pi/5)) if i%2==0 else
             (8+2.7*cos(-pi/2+i*pi/5),8+2.7*sin(-pi/2+i*pi/5)) for i in range(10)]
        poly(pts,GOLD,GOLD if name=="objective" else None,1.4)
    elif name == "calendar":
        rect((2.2,3.4,13.8,13.5),INK,None,1)
        line([(2.5,6.4),(13.5,6.4)],BLUE,1.4)
        for x in (5,10): line([(x,2.2),(x,4.5)],GOLD,1.6)
        for x,y in ((5,9),(8,9),(11,9),(5,11.5),(8,11.5)): ellipse((x-.55,y-.55,x+.55,y+.55),BLUE,BLUE,.4)
    elif name == "cash":
        rect((1.5,4,14.5,12),GREEN,None,1.3)
        ellipse((6,5,10,11),GREEN)
        line([(2.8,6),(4,6)],GREEN,1)
        line([(12,10),(13.2,10)],GREEN,1)
    elif name in ("home","company","financial","bank","civic"):
        if name=="home":
            poly([(1.7,7.5),(8,2.1),(14.3,7.5)],BLUE,None,1.6)
            line([(3.7,7.4),(3.7,13.6),(12.3,13.6),(12.3,7.4)],INK)
            rect((6.9,9,9.1,13.6),GOLD,None,.5,1.2)
        elif name in ("bank","civic"):
            poly([(1.4,5.3),(8,2),(14.6,5.3)],GOLD,None,1.5)
            for x in (3.2,7,10.8): line([(x,6.2),(x,11.8)],INK,1.5)
            line([(2,12.7),(14,12.7)],INK,1.7)
            if name=="civic": ellipse((7,2,9,4),GOLD,GOLD,.5)
        else:
            widths=[(3,12,7),(8,9,11)] if name=="financial" else [(4,3,12)]
            for x,y,xx in widths: rect((x,y,xx,13.6),BLUE,None,.7,1.5)
            for x,y in ((5.5,5.3),(5.5,8.3),(9.4,6.3),(9.4,9.3)):
                if name=="company" or x < 7: rect((x,y,x+1.2,y+1.3),GOLD,GOLD,.3,.5)
            if name=="financial": line([(13,12),(13,3)],GREEN,1.5)
    elif name == "map":
        poly([(1.7,4),(5.5,2.3),(10.2,4),(14.3,2.3),(14.3,12.3),(10.2,14),(5.5,12.3),(1.7,14)],BLUE,None,1.4)
        line([(5.5,2.8),(5.5,12.2)],INK,1)
        line([(10.2,4.2),(10.2,13.4)],INK,1)
    elif name == "people":
        ellipse((3,2.5,7,6.5),INK)
        ellipse((9,2.5,13,6.5),BLUE)
        line([(1.8,13),(2.4,9.3),(4,8),(6,8),(7.2,9.3)],INK)
        line([(8.8,9.3),(10,8),(12,8),(13.6,9.3),(14.2,13)],BLUE)
    elif name in ("tasks","contracts"):
        rect((3,2,13,14),INK,None,1)
        rect((5.5,1.2,10.5,3.5),BLUE,(22,43,72,255),.8,1.2)
        if name=="tasks":
            for y in (6,9,12):
                line([(5,y),(6,y+1),(7.5,y-1)],GREEN,1)
                line([(9,y),(11,y)],INK,1)
        else:
            for y in (6,8.5): line([(5.3,y),(10.8,y)],INK,1)
            line([(6,11),(8,12),(11,10.5)],GOLD,1.2)
    elif name == "phone":
        rect((4.5,1.4,11.5,14.6),BLUE,None,1.2)
        line([(5.5,11.5),(10.5,11.5)],INK,1)
        ellipse((7.5,12.3,8.5,13.3),GOLD,GOLD,.4)
    elif name in ("inventory","parcel"):
        poly([(2,5),(8,2),(14,5),(8,8)],GOLD,None,1.4)
        poly([(2,5),(8,8),(8,14),(2,11)],INK,None,1.4)
        poly([(8,8),(14,5),(14,11),(8,14)],INK,None,1.4)
        if name=="parcel": line([(5,3.6),(11,6.6),(11,9)],BLUE,1.1)
    elif name == "orders":
        line([(1.5,3.5),(3.8,3.5),(5.6,11),(12.5,11),(14,5.5),(4.6,5.5)],INK,1.5)
        for x in (6.5,12): ellipse((x-.7,12.3,x+.7,13.7),BLUE,BLUE,.5)
    elif name == "finance":
        for x,y,c in ((2.5,9,BLUE),(6.7,6,GOLD),(10.9,3,GREEN)):
            rect((x,y,x+2,13.5),c,c,.5,.5)
        line([(1.5,14.3),(14.5,14.3)],INK,1)
    elif name == "warning":
        poly([(8,1.7),(14.6,13.7),(1.4,13.7)],GOLD,None,1.7)
        line([(8,6),(8,9.4)],GOLD,1.6)
        ellipse((7.2,11,8.8,12.6),GOLD,GOLD,.3)
    elif name == "check": line([(2.4,8),(6.4,11.6),(13.7,3.8)],GREEN,2.1)
    elif name == "lock":
        d.arc((4*S,2*S,12*S,11*S),180,360,fill=INK,width=round(1.7*S))
        rect((3,7,13,14),GOLD,None,1.1)
        ellipse((7.2,9.2,8.8,10.8),GOLD,GOLD,.4)
    elif name == "metro":
        rect((3,1.5,13,12.3),BLUE,None,2)
        rect((4.5,3.6,11.5,7),INK,None,.6,1)
        for x in (5.1,10.9): ellipse((x-.6,9,x+.6,10.2),GOLD,GOLD,.4)
        line([(4.5,14),(6,12.2)],INK,1.2)
        line([(11.5,14),(10,12.2)],INK,1.2)
    elif name == "mail":
        rect((1.5,4,14.5,12.6),INK,None,1)
        line([(2,4.7),(8,9),(14,4.7)],BLUE,1.5)
    elif name == "settings":
        pts=[]
        for i in range(16):
            t=2*pi*i/16; r=6.6 if i%2==0 else 5.2
            pts.append((8+r*cos(t),8+r*sin(t)))
        poly(pts,INK,None,1.3)
        ellipse((5.8,5.8,10.2,10.2),BLUE)
    elif name == "save":
        rect((2,2,14,14),BLUE,None,1)
        rect((5,2.2,11,6),INK,None,.3,1)
        rect((5,9.3,11,13.6),INK,None,.3,1)
    elif name == "laptop":
        rect((3,2.5,13,10.6),BLUE,None,.8)
        line([(1.5,13),(14.5,13)],INK,2)
        line([(7,10.8),(9,10.8)],GOLD,1)
    elif name == "coffee":
        line([(2.5,6),(3.4,12),(10.6,12),(11.5,6),(2.5,6)],INK,1.5)
        d.arc((9*S,6*S,14*S,11*S),280,100,fill=GOLD,width=round(1.5*S))
        line([(5.5,4.6),(5.5,2.5)],BLUE,1)
        line([(8.5,4.6),(8.5,2.5)],BLUE,1)
    elif name == "arrow_right": line([(2.5,8),(13.3,8),(8.8,3.6),(13.3,8),(8.8,12.4)],INK,1.9)
    elif name == "close":
        line([(3,3),(13,13)],INK,1.9)
        line([(13,3),(3,13)],INK,1.9)
    elif name == "plus":
        line([(8,2.5),(8,13.5)],INK,1.9)
        line([(2.5,8),(13.5,8)],INK,1.9)
    elif name == "minus": line([(2.5,8),(13.5,8)],INK,1.9)
    elif name == "walk":
        ellipse((6.6,1.1,9.4,3.9),INK,INK,.5)
        line([(8,4.5),(7,8.5),(4,10)],INK,1.5)
        line([(7,8.5),(11,9.4),(13,13.5)],BLUE,1.5)
        line([(7,8.5),(4,13.8)],INK,1.5)
    elif name == "shop":
        rect((2,6.5,14,14),INK,None,.6)
        poly([(1.5,6.4),(3.5,2.6),(12.5,2.6),(14.5,6.4)],RED,None,1.4)
        line([(2.5,6.5),(13.5,6.5)],RED,1.5)
        rect((6.5,9,9.5,14),BLUE,None,.5,1)
    elif name == "startup":
        poly([(5,11),(5,5),(8,1.2),(11,5),(11,11),(8,13)],BLUE,None,1.3)
        ellipse((6.5,5,9.5,8),INK)
        line([(5,10),(2.8,12.5)],RED,1.3)
        line([(11,10),(13.2,12.5)],RED,1.3)
        line([(8,13),(8,15)],GOLD,1.5)
    elif name == "river":
        for y in (4,8,12): line([(2,y+1),(5,y-1),(8,y+1),(11,y-1),(14,y+1)],BLUE,1.5)
    elif name == "sleep":
        rect((2,7,14,12),INK,None,.8,1.4)
        rect((3,5,7,8),BLUE,None,.7,1.2)
        line([(2,4),(2,14)],INK,1.4)
        line([(14,10),(14,14)],INK,1.4)
    elif name == "shirt":
        poly([(5,2),(3,3.5),(1.5,7),(4,8.5),(4,13.7),(12,13.7),(12,8.5),(14.5,7),(13,3.5),(11,2),(9.5,4),(6.5,4)],BLUE,None,1.4)
        line([(6.5,4),(8,6),(9.5,4)],INK,1)
    else:
        raise ValueError(name)
    return "".join(parts)

def surface(key,w,h):
    recipes={
      'panel':('#20364b','#102033','#53748e'), 'panel_glass':('#22374b','#122135','#4a6c88'),
      'inset':('#102033','#0c1726','#304b67'), 'header':('#28455f','#1a3048','#577b99'),
      'button':('#2b4965','#1b314a','#6484a0'), 'button_hover':('#3d6b94','#284d74','#9dc8e7'),
      'button_pressed':('#1b3553','#24486d','#4d9cdb'), 'button_disabled':('#2c3441','#242d3b','#4a566a'),
      'button_primary':('#438ac1','#275d97','#a3d0ec'), 'button_primary_hover':('#569fd1','#3278b3','#c4e8fb'),
      'button_danger':('#914b48','#66323b','#cc8070'), 'tab':('#1c334a','#13273c','#466782'),
      'tab_active':('#427ebe','#295d99','#97c4ee'), 'tooltip':('#f4f4ee','#e4e8e8','#7e96ae'),
      'card':('#213c52','#142c40','#55768e'), 'card_gold':('#293c50','#182b41','#b79860'),
      'bar_bg':('#102035','#0b192b','#4b6584'), 'bar_fill':('#78c6f0','#438bbd','#a4def4'),
      'bar_fill_green':('#80d1b0','#408b74','#a7e9cf'), 'field':('#11233b','#0c1930','#507a9f'),
      'prompt_key':('#f3f4ed','#d5dee2','#8c9eae')}
    if key in ['phone_frame','portrait_frame']:
        margin=7 if key=='phone_frame' else 4;radius=9 if key=='phone_frame' else 2
        body=f'<rect x=".5" y=".5" width="{w-1}" height="{h-1}" rx="{radius}" fill="url(#surface)" stroke="#527697" stroke-width="1"/>'
        body+=f'<rect x="1.8" y="1.8" width="{w-3.6}" height="{h-3.6}" rx="{radius-1}" fill="none" stroke="#90b5d0" stroke-width=".6"/>'
        # Even-odd frame hole keeps exactly the existing logical transparent content area.
        hole_y=16 if key=='phone_frame' else margin
        hole_h=h-33 if key=='phone_frame' else h-2*margin
        mask=f'<mask id="frame"><rect width="{w}" height="{h}" fill="white"/><rect x="{margin}" y="{hole_y}" width="{w-2*margin}" height="{hole_h}" fill="black"/></mask>'
        body=mask+'<g mask="url(#frame)">'+body+'</g>'
        if key=='phone_frame':
            body+=f'<rect x="{w/2-14}" y="6" width="28" height="3" rx="1.5" fill="#0b1b30"/><circle cx="{w/2+19}" cy="7.5" r="1" fill="#80c0e5"/><rect x="{w/2-16}" y="{h-11}" width="32" height="2" rx="1" fill="#96bdd5"/>'
        top,bottom,border='#263f5b','#101e33','#537693'
    else:
        top,bottom,border=recipes[key]
        opacity=.95 if key=='panel_glass' else 1
        body=f'<rect x=".5" y=".5" width="{w-1}" height="{h-1}" rx="1.2" fill="url(#surface)" fill-opacity="{opacity}" stroke="{border}" stroke-width="1"/>'
        body+=f'<path d="M 2 1.5 H {w-2}" fill="none" stroke="#d4e6ee" stroke-opacity=".32" stroke-width=".7"/>'
        body+=f'<path d="M 2 {h-1.5} H {w-2}" fill="none" stroke="#08152a" stroke-opacity=".48" stroke-width=".7"/>'
    return f'<defs><linearGradient id="surface" x1="0" y1="0" x2="0" y2="1"><stop stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>'+body

def main():
    out=SRC/'vectors';out.mkdir(parents=True,exist_ok=True);jobs=[]
    for name in ICONS:
        key='ui/icons/'+name;p=out/(name+'.svg')
        p.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 16 16">'+icon(name)+'</svg>')
        jobs.append({'key':key,'source':p.relative_to(ROOT).as_posix(),'size':[16,16]})
    from PIL import Image
    for p in sorted((ROOT/'game/assets/ui').glob('*.png')):
        if p.stem in ['app_icon','app_icon_1024','icons_atlas']:continue
        w,h=Image.open(p).size;svg=out/(p.stem+'.svg')
        svg.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*4}" height="{h*4}" viewBox="0 0 {w} {h}">'+surface(p.stem,w,h)+'</svg>')
        jobs.append({'key':'ui/'+p.stem,'source':svg.relative_to(ROOT).as_posix(),'size':[w,h]})
    (SRC/'render_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
    print('Editable UI sources:',len(jobs))
if __name__=='__main__':main()
