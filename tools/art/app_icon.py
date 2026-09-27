"""App icon: the Board-D night skyline in a rounded navy tile with a gold 'CV' pixel monogram.
Writes game/assets/ui/app_icon.png (256), app_icon.ico (16-256) and app_icon_1024.png (store/macOS)."""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import concepts as C  # noqa: E402

ROOT = C.ROOT
OUT = os.path.join(ROOT, "game", "assets", "ui")


def build(size=256):
    S = 64  # draw on a 64-px pixel grid, then scale up with nearest neighbour
    tile = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sky = C.crop("D", (1010, 10, 1250, 130))
    sky = Image.fromarray(C.resize_rgb(sky, (S, 32)))
    q = sky.quantize(colors=24, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    grad = Image.new("RGB", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(a * (1 - t) + b * t) for a, b in zip((14, 20, 48), (40, 44, 96)))
        gd.line([(0, y), (S, y)], fill=c)
    grad.paste(q, (0, S - 32 - 6))
    # water line
    gd.rectangle([0, S - 6, S, S], fill=(18, 26, 60))
    for x in range(2, S, 5):
        gd.point((x, S - 4), fill=(236, 170, 110))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=12, fill=255)
    tile.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle([0, 0, S - 1, S - 1], radius=12, outline=(226, 180, 82), width=2)
    # monogram in the Pixelify title face
    font = ImageFont.truetype(os.path.join(ROOT, "game", "assets", "fonts", "PixelifySans.ttf"), 22)
    tw = d.textlength("CV", font=font)
    x, y = (S - tw) / 2, 7
    for dx, dy in ((1, 1), (2, 2)):
        d.text((x + dx, y + dy), "CV", font=font, fill=(10, 14, 30, 255))
    d.text((x, y), "CV", font=font, fill=(246, 206, 110, 255))
    # snap alpha to the pixel grid
    a = np.array(tile)
    a[..., 3] = np.where(a[..., 3] > 127, 255, 0)
    tile = Image.fromarray(a)
    return tile.resize((size, size), Image.NEAREST)


def main():
    os.makedirs(OUT, exist_ok=True)
    big = build(1024)
    big.save(os.path.join(OUT, "app_icon_1024.png"))
    icon = build(256)
    icon.save(os.path.join(OUT, "app_icon.png"))
    icon.save(os.path.join(OUT, "app_icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("app icon ->", OUT)


if __name__ == "__main__":
    main()
