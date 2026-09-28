"""A7 app icon: a smooth city skyline and clear CV mark, built at 1024 px."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "ui"
N = 1024


def build() -> Image.Image:
    sky = Image.new("RGBA", (N, N))
    d = ImageDraw.Draw(sky)
    for y in range(N):
        t = y / (N - 1)
        d.line((0, y, N, y), fill=(int(12+28*t), int(31+34*t), int(68+32*t), 255))
    sunset = Image.new("RGBA", (N, N))
    ImageDraw.Draw(sunset).ellipse((560, 230, 1120, 780), fill=(239, 164, 115, 130))
    sunset = sunset.filter(ImageFilter.GaussianBlur(130))
    sky = Image.alpha_composite(sky, sunset)
    d = ImageDraw.Draw(sky)
    for x, w, h, c in ((50,126,305,(43,81,121)), (161,83,430,(56,112,162)),
                       (245,125,365,(43,81,121)), (363,116,545,(74,146,204)),
                       (500,95,405,(56,112,162)), (605,115,610,(74,146,204)),
                       (733,120,460,(56,112,162)), (840,120,545,(74,146,204))):
        y = 820 - h
        d.rounded_rectangle((x,y,x+w,830),radius=8,fill=(*c,255))
        d.line((x+5,y+7,x+w-5,y+7),fill=(145,206,242,190),width=7)
        for wx in range(x+18,x+w-8,27):
            for wy in range(y+32,795,43):
                if (wx*7+wy*3)%5:
                    d.rounded_rectangle((wx,wy,wx+9,wy+17),radius=2,fill=(167,214,230,110))
    d.polygon([(370,286),(420,245),(470,286)],fill=(110,183,225,255))
    d.polygon([(618,199),(660,154),(702,199)],fill=(136,202,240,255))
    d.rounded_rectangle((45,785,979,873),radius=22,fill=(16,48,82,255))
    for y,c in ((799,(96,186,225,190)),(826,(235,170,117,135)),(851,(86,164,211,150))):
        d.arc((45,y-24,980,y+28),2,178,fill=c,width=5)
    # Large letters remain recognisable when the whole icon is reduced to 32 px.
    font = ImageFont.truetype(str(ROOT / "game/assets/fonts/Inter.ttf"),418)
    bbox = d.textbbox((0,0),"CV",font=font,stroke_width=6)
    x = (N-(bbox[2]-bbox[0]))//2-bbox[0]
    y = 155-bbox[1]
    mark = Image.new("RGBA",(N,N))
    ImageDraw.Draw(mark).text((x,y),"CV",font=font,fill=(240,247,252,255),
                              stroke_width=10,stroke_fill=(22,48,79,255))
    glow = mark.filter(ImageFilter.GaussianBlur(17))
    glow.putalpha(glow.getchannel("A").point(lambda v:int(v*.7)))
    sky = Image.alpha_composite(sky,glow)
    sky = Image.alpha_composite(sky,mark)
    d = ImageDraw.Draw(sky)
    d.rounded_rectangle((20,20,1004,1004),radius=203,outline=(231,185,104,255),width=18)
    d.arc((37,37,987,987),189,350,fill=(250,222,156,255),width=7)
    mask = Image.new("L",(N,N))
    ImageDraw.Draw(mask).rounded_rectangle((12,12,1012,1012),radius=210,fill=255)
    sky.putalpha(mask)
    return sky


def main() -> None:
    OUT.mkdir(parents=True,exist_ok=True)
    big = build()
    big.save(OUT / "app_icon_1024.png",optimize=True)
    small = big.resize((256,256),Image.Resampling.LANCZOS)
    small.save(OUT / "app_icon.png",optimize=True)
    small.save(OUT / "app_icon.ico",sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
    print("A7: 1024/256 app icons and ICO")


if __name__ == "__main__": main()
