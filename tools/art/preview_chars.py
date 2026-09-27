import sys, os
from PIL import Image, ImageChops
sys.path.insert(0, os.path.dirname(__file__))
import chars
OUT = sys.argv[1]
A = os.path.join(OUT, "assets")
def tint(im, col):
    r,g,b,a = im.split()
    col = Image.new("RGB", im.size, col)
    rgb = ImageChops.multiply(Image.merge("RGB",(r,g,b)), col)
    return Image.merge("RGBA", (*rgb.split(), a))
def load(p): return Image.open(os.path.join(A,p)).convert("RGBA")
def compose(cfg):
    pres, face = cfg["pres"], cfg["face"]
    L = []
    L.append(tint(load(f"characters/hair_{cfg['hair']}_back.png"), cfg["hair_col"]))
    L.append(tint(load(f"characters/body_{pres}_{face}.png"), cfg["skin"]))
    o = cfg["outfit"]
    L.append(tint(load(f"characters/outfit_{o}_{pres}_bottom.png"), cfg.get("bot",(255,255,255))))
    L.append(load(f"characters/outfit_{o}_{pres}_shoes.png"))
    L.append(tint(load(f"characters/outfit_{o}_{pres}_top.png"), cfg.get("top",(255,255,255))))
    L.append(load(f"characters/eyes_{cfg['eyes']}.png"))
    L.append(tint(load(f"characters/iris_{cfg['eyes']}.png"), cfg["eye_col"]))
    L.append(tint(load(f"characters/brows_{cfg['brows']}.png"), cfg["hair_col"]))
    L.append(load(f"characters/mouth_{cfg['mouth']}.png"))
    L.append(tint(load(f"characters/hair_{cfg['hair']}_front.png"), cfg["hair_col"]))
    base = Image.new("RGBA", L[0].size, (0,0,0,0))
    for l in L: base.alpha_composite(l)
    return base
def pcompose(cfg):
    L = [tint(load(f"portraits/hair_{cfg['hair']}_back.png"), cfg["hair_col"])]
    L.append(tint(load(f"portraits/head_{cfg['face']}.png"), cfg["skin"]))
    L.append(tint(load(f"portraits/outfit_{cfg['outfit']}.png"), cfg.get("top",(255,255,255))))
    head = L[1]
    out=[]
    for e in range(4):
        base = Image.new("RGBA",(64,64),(40,56,88,255))
        for l in L: base.alpha_composite(l.crop((0,0,64,64)))
        for n,t in ((f"portraits/eyes_{cfg['eyes']}.png",None),(f"portraits/iris_{cfg['eyes']}.png",cfg["eye_col"]),(f"portraits/brows_{cfg['brows']}.png",cfg["hair_col"]),(f"portraits/mouth_{cfg['mouth']}.png",None)):
            im = load(n); im = tint(im,t) if t else im
            base.alpha_composite(im.crop((e*64,0,e*64+64,64)))
        base.alpha_composite(tint(load(f"portraits/hair_{cfg['hair']}_front.png"), cfg["hair_col"]))
        out.append(base)
    return out
cfgs = [
 dict(pres="masculine",face="round",hair="messy",hair_col=(80,56,44),skin=(250,212,186),eyes="round",eye_col=(120,80,50),brows="straight",mouth="smile",outfit="startup_casual"),
 dict(pres="feminine",face="oval",hair="bob",hair_col=(40,30,34),skin=(236,190,160),eyes="almond",eye_col=(70,110,160),brows="arched",mouth="neutral",outfit="office_professional"),
 dict(pres="neutral",face="heart",hair="ponytail",hair_col=(215,176,110),skin=(180,124,92),eyes="wide",eye_col=(90,140,90),brows="soft",mouth="grin",outfit="home"),
 dict(pres="masculine",face="square",hair="short_neat",hair_col=(30,26,28),skin=(130,86,62),eyes="narrow",eye_col=(60,40,30),brows="thick",mouth="small",outfit="business_suit"),
 dict(pres="feminine",face="round",hair="long",hair_col=(150,70,50),skin=(255,224,200),eyes="round",eye_col=(100,80,60),brows="arched",mouth="smile",outfit="barista"),
 dict(pres="neutral",face="oval",hair="bun",hair_col=(60,70,120),skin=(220,170,130),eyes="almond",eye_col=(80,80,80),brows="straight",mouth="neutral",outfit="casual_tee",top=(120,190,150),bot=(90,110,160)),
 dict(pres="masculine",face="heart",hair="side_part",hair_col=(110,80,60),skin=(240,200,170),eyes="wide",eye_col=(60,90,130),brows="straight",mouth="smile",outfit="courier"),
 dict(pres="feminine",face="square",hair="buzz",hair_col=(20,20,20),skin=(110,74,54),eyes="round",eye_col=(50,30,20),brows="thick",mouth="grin",outfit="civic_staff"),
]
sheets=[compose(c) for c in cfgs]
W=sheets[0].width; H=sheets[0].height
canvas=Image.new("RGBA",(W*4+30, H*2+20),(210,224,236,255))
for i,s in enumerate(sheets):
    canvas.alpha_composite(s,((i%4)*(W+8), (i//4)*(H+8)))
canvas=canvas.resize((canvas.width*3,canvas.height*3),Image.NEAREST)
canvas.save(os.path.join(OUT,"preview_chars.png"))
ps=[]
for c in cfgs[:6]: ps += pcompose(c)[:4]
pc=Image.new("RGBA",(64*8, 64*3),(0,0,0,255))
for i,p in enumerate(ps[:24]): pc.alpha_composite(p,((i%8)*64,(i//8)*64))
pc=pc.resize((pc.width*2,pc.height*2),Image.NEAREST); pc.save(os.path.join(OUT,"preview_portraits.png"))
