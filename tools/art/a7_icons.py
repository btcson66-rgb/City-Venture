"""A7: coherent 16 px antialiased line icons for the navy game UI.

Run from any directory: python tools/art/a7_icons.py
"""
from pathlib import Path
from math import cos, pi, sin

from PIL import Image, ImageDraw

from ui import ICONS

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "ui"
S = 8
INK = (232, 242, 250, 255)
BLUE = (102, 190, 249, 255)
GOLD = (246, 196, 101, 255)
GREEN = (113, 211, 160, 255)
RED = (251, 137, 127, 255)
VIOLET = (192, 166, 249, 255)


def render(name: str) -> Image.Image:
    im = Image.new("RGBA", (16*S, 16*S))
    d = ImageDraw.Draw(im)
    def p(pt): return tuple(round(v*S) for v in pt)
    def line(points, c=INK, w=1.55):
        coords = [p(pt) for pt in points]
        d.line(coords, fill=c, width=round(w*S), joint="curve")
        r = round(w*S/2)
        for x,y in (coords[0], coords[-1]): d.ellipse((x-r,y-r,x+r,y+r), fill=c)
    def rect(box, c=INK, fill=None, radius=1.2, w=1.5):
        d.rounded_rectangle(tuple(round(v*S) for v in box), radius=round(radius*S), fill=fill, outline=c, width=round(w*S))
    def ellipse(box, c=INK, fill=None, w=1.5):
        d.ellipse(tuple(round(v*S) for v in box), outline=c, fill=fill, width=round(w*S))
    def poly(points,c=INK,fill=None,w=1.5):
        pts=[p(pt) for pt in points]
        d.polygon(pts,fill=fill)
        if c: d.line(pts+[pts[0]],fill=c,width=round(w*S),joint="curve")

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
        line([(1.8,3),(7,3),(2,9),(7,9)],INK,1.4)
        line([(9,6),(14,6),(10,12),(14,12)],BLUE,1.4)
    elif name == "shirt":
        poly([(5,2),(3,3.5),(1.5,7),(4,8.5),(4,13.7),(12,13.7),(12,8.5),(14.5,7),(13,3.5),(11,2),(9.5,4),(6.5,4)],BLUE,None,1.4)
        line([(6.5,4),(8,6),(9.5,4)],INK,1)
    else:
        raise ValueError(name)
    return im.resize((16,16),Image.Resampling.LANCZOS)


def main() -> None:
    atlas=Image.new("RGBA",(128,96))
    for i,name in enumerate(ICONS):
        icon=render(name)
        icon.save(OUT / "icons" / f"{name}.png", optimize=True)
        atlas.alpha_composite(icon,((i%8)*16,(i//8)*16))
    atlas.save(OUT / "icons_atlas.png",optimize=True)
    print(f"A7: {len(ICONS)} icons and atlas")


if __name__ == "__main__": main()
