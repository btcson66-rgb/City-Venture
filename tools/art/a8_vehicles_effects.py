"""A8: softly antialiased vehicles and atmospheric effects at original sizes."""
from pathlib import Path
from math import hypot

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets"
S = 6


def layer(w, h): return Image.new("RGBA", (w*S,h*S))
def poly(d, pts, fill): d.polygon([(round(x*S),round(y*S)) for x,y in pts],fill=fill)
def rounded(d, box, r, fill, outline=None, width=1):
    d.rounded_rectangle(tuple(round(v*S) for v in box),radius=round(r*S),fill=fill,
                        outline=outline,width=round(width*S))
def ellipse(d, box, fill, outline=None, width=1):
    d.ellipse(tuple(round(v*S) for v in box),fill=fill,outline=outline,width=round(width*S))
def line(d, pts, fill, width=1):
    d.line([(round(x*S),round(y*S)) for x,y in pts],fill=fill,width=round(width*S),joint="curve")
def save(im,path,size): im.resize(size,Image.Resampling.LANCZOS).save(path,optimize=True)


def side(kind):
    dims={"sedan":(64,28),"compact":(52,26),"taxi":(64,28),"van":(72,36),"bus":(112,44)}
    w,h=dims[kind]
    b=layer(w,h);q=layer(w,h);db=ImageDraw.Draw(b);dq=ImageDraw.Draw(q)
    if kind in ("sedan","taxi","compact"):
        compact=kind=="compact"
        roof_y=h-(22 if compact else 25)
        front=round(w*.77);rear=round(w*.24)
        poly(db,[(2,h-14),(6,h-17),(rear-6,h-17),(rear+3,roof_y),
                 (front-7,roof_y),(front+4,h-17),(w-5,h-16),(w-2,h-12),
                 (w-3,h-7),(3,h-7)],(207,207,207,255))
        line(db,[(4,h-15),(w-6,h-15)],(244,244,244,255),1.3)
        line(db,[(4,h-9),(w-3,h-9)],(143,143,143,255),1)
        poly(dq,[(rear+3,roof_y+2),(round(w*.5)-2,roof_y+2),(round(w*.5)-2,h-18),(rear-3,h-18)],(47,78,112,255))
        poly(dq,[(round(w*.5)+1,roof_y+2),(front-7,roof_y+2),(front+1,h-18),(round(w*.5)+1,h-18)],(61,101,137,255))
        line(dq,[(rear+5,roof_y+3),(round(w*.5)-4,roof_y+3)],(157,201,223,255),.8)
        line(dq,[(round(w*.5)+3,roof_y+3),(front-7,roof_y+3)],(169,213,234,255),.8)
        line(dq,[(round(w*.5),roof_y+1),(round(w*.5),h-17)],(37,57,75,255),1.1)
        line(dq,[(round(w*.5),h-17),(round(w*.5),h-8)],(140,146,151,180),.7)
        rounded(dq,(front-3,h-13,front+1,h-12),.3,(245,245,236,255))
        rounded(dq,(w-4,h-14,w-1,h-11),.6,(255,230,155,255))
        rounded(dq,(1,h-14,3,h-11),.4,(225,84,76,255))
        if kind=="taxi":
            rounded(dq,(w*.43,roof_y-3,w*.57,roof_y+.2),.6,(244,229,169,255),
                    (76,78,83,255),.5)
    elif kind=="van":
        poly(db,[(2,7),(w-16,7),(w-4,13),(w-2,h-8),(3,h-8)],(208,208,208,255))
        rounded(db,(3,9,w-17,h-15),1.2,(222,222,222,255))
        line(db,[(3,8),(w-16,8)],(246,246,246,255),1)
        poly(dq,[(w-16,10),(w-6,14),(w-5,21),(w-16,21)],(56,92,126,255))
        line(dq,[(w-15,11),(w-7,14)],(160,205,226,255),1)
        line(dq,[(8,19),(w-22,19)],(125,164,193,135),1)
        rounded(dq,(w-3,h-15,w-1,h-12),.5,(255,229,164,255))
    else:
        poly(db,[(3,5),(w-15,5),(w-3,10),(w-2,h-8),(2,h-8)],(214,214,214,255))
        line(db,[(4,7),(w-16,7)],(250,250,250,255),1)
        for x in range(8,w-23,14):
            rounded(dq,(x,10,x+10,21),1,(49,83,118,255))
            line(dq,[(x+1,11),(x+9,11)],(153,203,229,255),1)
            ellipse(dq,(x+3,17,x+7,20),(69,81,100,180))
        rounded(dq,(w-18,10,w-5,27),1,(50,85,119,255))
        line(dq,[(w-16,11),(w-6,11)],(153,203,229,255),1)
        rounded(dq,(4,24,w-3,27),1,(68,121,182,255))
        rounded(dq,(w-3,h-15,w-1,h-12),.5,(255,229,164,255))
    wheel_x=(16,w-22) if kind=="bus" else (round(w*.23),round(w*.78))
    for cx in wheel_x:
        ellipse(dq,(cx-5,h-11,cx+5,h-1),(34,39,47,255))
        ellipse(dq,(cx-2.6,h-8.6,cx+2.6,h-3.4),(163,176,184,255))
        ellipse(dq,(cx-.9,h-6.9,cx+.9,h-5.1),(72,87,100,255))
    line(dq,[(4,h-8),(w-4,h-8)],(85,99,112,160),.6)
    return b,q,(w,h)


def end(kind,back=False):
    w,h=(30,36) if kind=="compact" else (32,40)
    b=layer(w,h);q=layer(w,h);db=ImageDraw.Draw(b);dq=ImageDraw.Draw(q)
    poly(db,[(7,3),(w-8,3),(w-4,11),(w-2,h-9),(w-5,h-5),(4,h-5),(2,h-9),(4,11)],(210,210,210,255))
    line(db,[(7,4),(w-8,4)],(248,248,248,255),1)
    poly(dq,[(9,5),(w-10,5),(w-6,13),(6,13)],(52,89,123,255))
    line(dq,[(10,6),(w-11,6)],(165,210,234,255),1)
    rounded(dq,(5,h-15,w-6,h-12),1,(75,90,105,210))
    for x in (3,w-8):
        rounded(dq,(x,h-17,x+5,h-13),.7,(225,79,74,255) if back else (250,237,189,255))
    for x in (3,w-6): rounded(dq,(x,h-7,x+3,h-2),1,(32,37,44,255))
    if back: rounded(dq,(w*.39,h-12,w*.61,h-10),.4,(222,230,234,255))
    else: line(dq,[(w*.35,h-10),(w*.65,h-10)],(111,133,146,255),1)
    return b,q,(w,h)


def metro():
    w,h=124,40
    im=layer(w,h);d=ImageDraw.Draw(im)
    rounded(d,(2,5,w-3,h-7),4,(219,225,229,255))
    line(d,[(4,6),(w-5,6)],(253,253,249,255),1)
    for x in range(8,w-13,14):
        rounded(d,(x,11,x+10,21),1,(39,71,102,255))
        rounded(d,(x+1,13,x+9,19),.5,(177,201,205,255))
        line(d,[(x+1,12),(x+9,12)],(232,241,241,255),.7)
    for x in (w//2-6,w//2+2): rounded(d,(x,11,x+3,h-9),.3,(100,116,128,255))
    rounded(d,(3,24,w-4,27),1,(206,65,70,255))
    line(d,[(4,28),(w-5,28)],(246,244,238,255),.8)
    rounded(d,(3,h-8,w-4,h-5),.8,(66,74,84,255))
    for x in (13,30,w-30,w-13): rounded(d,(x-5,h-5,x+5,h-2),1,(38,44,51,255))
    return im,(w,h)


def radial(size,col,spread=.36):
    w,h=size
    im=Image.new("RGBA",size)
    px=im.load()
    for y in range(h):
        for x in range(w):
            r=hypot((x+.5-w/2)/(w*.5),(y+.5-h/2)/(h*.5))
            a=max(0,1-r)**(1/spread)
            px[x,y]=(*col,round(a*205))
    return im


def effects():
    folder=OUT/"effects"
    for n,size,col,spread in (("glow_small",(32,32),(255,231,182),.42),
                               ("glow_warm",(64,64),(255,214,157),.43),
                               ("glow_wide",(96,48),(255,218,171),.39)):
        radial(size,col,spread).save(folder/f"{n}.png",optimize=True)
    shadow=radial((24,8),(11,19,29),.42)
    shadow.putalpha(shadow.getchannel("A").point(lambda v:round(v*.52)))
    shadow.save(folder/"shadow.png",optimize=True)
    spark=Image.new("RGBA",(64,16));sd=ImageDraw.Draw(spark)
    for frame,r in enumerate((2.3,4,5.5,3.2)):
        cx=frame*16+8;cy=8
        for j in (1,0):
            c=(249,220,149,95) if j else (255,248,222,220)
            rr=r+j*.7
            sd.line((cx-rr,cy,cx+rr,cy),fill=c,width=2 if j else 1)
            sd.line((cx,cy-rr,cx,cy+rr),fill=c,width=2 if j else 1)
        sd.ellipse((cx-1,cy-1,cx+1,cy+1),fill=(255,255,248,255))
    spark.save(folder/"sparkle.png",optimize=True)
    water=Image.new("RGBA",(64,8));wd=ImageDraw.Draw(water)
    for frame,length in enumerate((3,5,7,4)):
        cx=frame*16+8;cy=4
        wd.line((cx-length/2,cy,cx+length/2,cy),fill=(155,219,244,180),width=1)
        wd.line((cx-1,cy-2,cx+1,cy-2),fill=(213,244,250,130),width=1)
        wd.point((cx,cy-1),fill=(239,251,250,210))
    water.save(folder/"water_sparkle.png",optimize=True)


def main():
    folder=OUT/"vehicles"
    for k in ("sedan","compact","taxi","van","bus"):
        body,detail,size=side(k)
        save(body,folder/f"{k}_side_body.png",size)
        save(detail,folder/f"{k}_side_detail.png",size)
    for k in ("sedan","compact"):
        for back in (False,True):
            body,detail,size=end(k,back)
            direction="back" if back else "front"
            save(body,folder/f"{k}_{direction}_body.png",size)
            save(detail,folder/f"{k}_{direction}_detail.png",size)
    train,size=metro()
    save(train,folder/"metro_train.png",size)
    effects()
    print("A8: 19 vehicles, 6 effects")


if __name__=="__main__": main()
