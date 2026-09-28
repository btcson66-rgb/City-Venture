"""B1 first slice: Shopping Street street furniture and restrained night lights."""
from pathlib import Path
from PIL import Image, ImageDraw

from b1_threadline import image, box, ln, ellipse, poly, S, EDGE, GOLD, WOOD, NAVY

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"game"/"assets"/"props"


def save(name,im,size):
    im.resize(size,Image.Resampling.LANCZOS).save(OUT/f"{name}.png",optimize=True)


def market_stall(name,awning):
    w,h=64,50;im,d=image(w,h)
    for x in (6,55):
        box(d,(x,13,x+3,45),WOOD,EDGE,1)
        box(d,(x-2,43,x+7,47),WOOD,EDGE,1)
    poly(d,[(4,12),(12,3),(52,3),(60,12)],awning,EDGE)
    ln(d,[(7,10),(57,10)],(240,222,190,255),1)
    for x in range(12,56,12):ln(d,[(x,4),(x-2,12)],(249,238,215,160),1)
    box(d,(7,29,57,40),(183,139,94,255),EDGE,1,2)
    ln(d,[(8,31),(56,31)],GOLD,1)
    for x,col in ((16,(225,159,110,255)),(26,(106,160,130,255)),
                  (37,(223,197,114,255)),(48,(183,105,120,255))):
        box(d,(x-4,25,x+4,30),col,EDGE,1)
    save(name,im,(w,h))


def string_lights():
    w,h=128,32;im,d=image(w,h);lt=Image.new("RGBA",(w*S,h*S));ld=ImageDraw.Draw(lt)
    ln(d,[(2,3),(26,11),(53,15),(78,14),(103,10),(126,3)],(51,58,72,255),1)
    for x,y in ((12,7),(27,11),(43,14),(59,15),(75,14),(91,12),(108,9),(121,5)):
        ln(d,[(x,y),(x,y+4)],(86,69,58,255),1)
        ellipse(d,(x-2,y+3,x+2,y+8),(244,209,143,255),EDGE)
        ellipse(ld,(x-4,y+1,x+4,y+10),(255,209,135,105))
    save("string_lights",im,(w,h));save("string_lights_lights",lt,(w,h))


def kiosk_flower():
    w,h=48,46;im,d=image(w,h)
    box(d,(7,18,41,40),(154,111,80,255),EDGE,2)
    box(d,(6,16,42,22),WOOD,EDGE,1)
    for x,col in ((12,(219,118,134,255)),(21,(242,200,125,255)),
                  (30,(233,145,165,255)),(38,(203,104,118,255))):
        ln(d,[(x,18),(x,9)],(79,126,90,255),1)
        for dx,dy in ((-3,0),(0,-3),(3,0),(0,3)):
            ellipse(d,(x+dx-2,7+dy-2,x+dx+2,7+dy+2),col)
        ellipse(d,(x-1,6,x+1,8),(241,215,154,255))
    box(d,(8,39,40,43),(95,69,55,255),EDGE,1)
    save("kiosk_flower",im,(w,h))


def planter_long():
    w,h=80,28;im,d=image(w,h)
    box(d,(3,13,77,25),(120,111,103,255),EDGE,2)
    ln(d,[(5,15),(75,15)],(202,191,168,255),1)
    for x in range(9,75,8):
        ellipse(d,(x-4,7,x+6,18),(55,104,73,255))
        ellipse(d,(x,4,x+8,14),(91,143,84,255))
        ellipse(d,(x+2,7,x+6,11),(174,201,129,255))
    save("planter_long",im,(w,h))


def bike_rack():
    w,h=54,32;im,d=image(w,h)
    box(d,(3,27,51,30),(97,111,120,255),EDGE,1)
    for x in (9,24,39):
        d.arc((x*S,5*S,(x+11)*S,30*S),180,360,fill=(152,166,173,255),width=2*S)
        ln(d,[(x,17),(x,28)],(152,166,173,255),2)
        ln(d,[(x+11,17),(x+11,28)],(152,166,173,255),2)
    save("bike_rack",im,(w,h))


def main():
    market_stall("market_stall_rose",(197,115,137,255))
    market_stall("market_stall_sage",(104,151,128,255))
    market_stall("market_stall_cream",(225,211,182,255))
    string_lights();kiosk_flower();planter_long();bike_rack()
    print("B1 Shopping Street: 8 street prop sprites")


if __name__=="__main__":main()
