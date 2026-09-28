"""B1 first slice: Threadline's six interior fixtures, sized for 32 px tiles."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"game"/"assets"/"interiors"
S=4
NAVY=(39,52,73,255)
EDGE=(24,37,54,255)
GOLD=(218,181,116,255)
WOOD=(151,110,78,255)
LIGHT=(231,229,213,255)
BLUE=(84,139,178,255)


def image(w,h):
    im=Image.new("RGBA",(w*S,h*S))
    return im,ImageDraw.Draw(im)
def box(d,coords,fill,outline=None,r=0,width=1):
    b=tuple(round(v*S) for v in coords)
    d.rounded_rectangle(b,radius=r*S,fill=fill,outline=outline,width=width*S)
def ln(d,pts,fill,width=1):
    d.line([(round(x*S),round(y*S)) for x,y in pts],fill=fill,width=width*S,joint="curve")
def ellipse(d,b,fill,outline=None,width=1):
    d.ellipse(tuple(round(v*S) for v in b),fill=fill,outline=outline,width=width*S)
def poly(d,pts,fill,outline=None,width=1):
    p=[(round(x*S),round(y*S)) for x,y in pts]
    d.polygon(p,fill=fill)
    if outline:d.line(p+[p[0]],fill=outline,width=width*S,joint="curve")
def save(n,im,size):
    im.resize(size,Image.Resampling.LANCZOS).save(OUT/f"{n}.png",optimize=True)


def clothing_rack():
    w,h=72,54;im,d=image(w,h)
    for x in (5,66):
        box(d,(x,9,x+3,50),NAVY,EDGE,1)
        box(d,(x-3,49,x+7,51),GOLD,EDGE,1)
    box(d,(7,9,69,12),GOLD,EDGE,1)
    for i,col in enumerate(((56,76,110,255),(222,214,190,255),(108,148,145,255),
                            (171,111,120,255),(50,60,84,255))):
        cx=14+i*11
        ln(d,[(cx,13),(cx,16),(cx-4,19),(cx+4,19)],LIGHT,1)
        poly(d,[(cx-4,19),(cx-7,25),(cx-5,28),(cx-4,26),(cx-4,44),
                (cx+4,44),(cx+4,26),(cx+5,28),(cx+7,25),(cx+4,19)],col,EDGE,1)
        ln(d,[(cx-2,21),(cx+2,21)],(235,224,207,170),1)
    save("clothing_rack",im,(w,h))


def mannequin():
    w,h=28,58;im,d=image(w,h)
    ellipse(d,(9,4,18,13),(226,194,161,255),EDGE)
    box(d,(12,13,15,17),(207,176,146,255))
    poly(d,[(8,18),(12,16),(16,16),(20,18),(21,33),(18,36),(10,36),(7,33)],
         (88,101,124,255),EDGE)
    poly(d,[(10,36),(18,36),(20,49),(8,49)],(207,180,153,255),EDGE)
    ln(d,[(14,48),(14,53)],NAVY,2)
    box(d,(5,53,23,56),WOOD,EDGE,1)
    ln(d,[(9,21),(18,21)],GOLD,1)
    save("mannequin",im,(w,h))


def fitting_room():
    w,h=48,70;im,d=image(w,h)
    box(d,(3,3,44,67),(56,48,57,255),EDGE,2,2)
    box(d,(7,8,40,62),(214,195,164,255),None,1)
    poly(d,[(7,7),(24,7),(23,50),(18,57),(7,59)],(46,61,89,255),EDGE)
    poly(d,[(40,7),(25,7),(26,52),(30,58),(40,59)],(55,73,104,255),EDGE)
    ln(d,[(10,10),(13,22),(12,42),(17,54)],(111,137,165,180),1)
    ln(d,[(36,10),(33,22),(34,44),(29,54)],(110,134,159,180),1)
    box(d,(3,3,44,8),WOOD,EDGE,1)
    box(d,(4,63,43,67),GOLD,EDGE,1)
    save("fitting_room",im,(w,h))


def checkout_counter():
    w,h=88,42;im,d=image(w,h)
    box(d,(5,17,82,39),NAVY,EDGE,2,2)
    box(d,(4,15,83,21),WOOD,EDGE,2)
    ln(d,[(8,24),(79,24)],GOLD,1)
    box(d,(12,26,38,35),(59,76,98,255),None,1)
    box(d,(53,22,75,34),(62,75,91,255),None,1)
    box(d,(60,6,75,16),EDGE,EDGE,1)
    box(d,(62,8,73,14),(86,172,213,255),None,1)
    ln(d,[(67,16),(67,20)],GOLD,1)
    box(d,(19,10,34,15),(235,226,204,255),EDGE,1)
    box(d,(6,38,82,40),(24,33,47,255),None,1)
    save("checkout_counter",im,(w,h))


def mirror_full():
    w,h=34,70;im,d=image(w,h)
    box(d,(3,2,31,66),WOOD,EDGE,4,2)
    box(d,(6,5,28,61),(71,113,151,255),None,3)
    poly(d,[(8,7),(14,7),(25,54),(21,59)],(165,204,220,130))
    ln(d,[(8,57),(26,12)],(226,241,244,130),1)
    box(d,(2,65,32,68),GOLD,EDGE,1)
    save("mirror_full",im,(w,h))


def shoe_shelf():
    w,h=70,52;im,d=image(w,h)
    box(d,(4,6,66,49),WOOD,EDGE,2,2)
    box(d,(7,9,63,44),(49,59,77,255),None,1)
    for y in (19,31,43):
        box(d,(6,y,64,y+2),GOLD,EDGE,1)
    colors=((232,231,221,255),(71,117,160,255),(184,104,99,255),
            (230,217,188,255),(69,79,103,255))
    for row,y in enumerate((13,25,37)):
        for j,col in enumerate(colors):
            x=9+j*11
            poly(d,[(x,y+3),(x+3,y),(x+6,y+1),(x+8,y+4),(x+8,y+6),(x,y+6)],col,EDGE,1)
    box(d,(5,46,65,50),(82,61,50,255),EDGE,1)
    save("shoe_shelf",im,(w,h))


def main():
    for fn in (clothing_rack,mannequin,fitting_room,checkout_counter,mirror_full,shoe_shelf):fn()
    print("B1 Threadline: 6 interior fixtures")


if __name__=="__main__":main()
