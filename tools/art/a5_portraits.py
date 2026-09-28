"""Rebuild 45 base layers, two R1 detail layers and two ready-wired glasses.

Run from the repository root: python tools/art/a5_portraits.py
Only game/assets/portraits is written. Walking sprites and NPC data are not.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

import chars

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "game" / "assets" / "portraits"


def soften_edges(im: Image.Image) -> Image.Image:
    """Keep 64px alignment while reducing the rigid stair-step silhouette."""
    im = im.convert("RGBA")
    original = im.getchannel("A")
    alpha = ImageChops.darker(original, original.filter(ImageFilter.GaussianBlur(0.36)))
    # The edge only softens inward; transparent black pixels never become
    # visible and therefore cannot form a halo after Godot tinting.
    alpha = alpha.point(lambda n: 0 if n < 14 else n)
    im.putalpha(alpha)
    return im


def save(name: str, im: Image.Image) -> None:
    soften_edges(im).save(OUT / (name + ".png"))


def expressive_eyes(shape: str) -> tuple[Image.Image, Image.Image]:
    lash, iris = chars.draw_p_eyes(shape)
    # The thinking frame now has a visible asymmetric, half-lidded gaze;
    # surprised keeps a fully open eye and happy keeps the closed smile arc.
    d = ImageDraw.Draw(lash)
    ox = 2 * 64
    for x in (20, 36):
        d.line((ox + x + 1, 28, ox + x + 6, 28), fill=chars.LASH, width=1)
    return lash, iris


def expressive_brows(style: str) -> Image.Image:
    im = chars.draw_p_brows(style)
    d = ImageDraw.Draw(im)
    # A raised inner brow makes surprise legible even on narrow-eyed faces.
    ox = 3 * 64
    for x in (20, 36):
        d.line((ox + x + 1, 20, ox + x + 6, 19), fill=(105, 105, 105, 228), width=1)
    return im


def expressive_mouth(style: str) -> Image.Image:
    im = chars.draw_p_mouth(style)
    d = ImageDraw.Draw(im)
    # Thinking is a pressed, off-centre mouth rather than a second neutral.
    ox = 2 * 64
    d.line((ox + 31, 45, ox + 37, 44), fill=chars.LIP_DARK, width=1)
    # Surprised receives a tiny lower-lip highlight to round its open mouth.
    ox = 3 * 64
    d.line((ox + 31, 47, ox + 34, 47), fill=(211, 124, 130, 230), width=1)
    return im


def portrait_glasses(kind: str) -> Image.Image:
    """Transparent, antialiased frames at the portrait eye coordinates."""
    scale = 4
    im = Image.new("RGBA", (64 * scale, 64 * scale))
    d = ImageDraw.Draw(im)
    ink = (33, 43, 61, 252) if kind == "square" else (81, 58, 55, 252)
    glint = (189, 207, 216, 175)
    def box(coords): return tuple(round(n * scale) for n in coords)
    for x0 in (17, 33):
        x1 = x0 + 14
        if kind == "round":
            d.ellipse(box((x0, 25, x1, 37)), outline=ink, width=6)
            d.arc(box((x0 + 2, 27, x1 - 2, 35)), 200, 310, fill=glint, width=2)
        else:
            d.rounded_rectangle(box((x0, 25, x1, 36)), radius=3 * scale,
                                outline=ink, width=7)
            d.line(box((x0 + 2, 27, x0 + 7, 27)), fill=glint, width=2)
    d.arc(box((29, 27, 35, 32)), 190, 345, fill=ink, width=5)
    d.line(box((13, 28, 17, 29)), fill=ink, width=5)
    d.line(box((47, 29, 51, 28)), fill=ink, width=5)
    return im.resize((64, 64), Image.Resampling.LANCZOS)


def generate() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for face in chars.FACES:
        save(f"head_{face}", chars.draw_p_head(face))
    for shape in chars.EYES:
        lash, iris = expressive_eyes(shape)
        save(f"eyes_{shape}", lash)
        save(f"iris_{shape}", iris)
    for style in chars.BROWS:
        save(f"brows_{style}", expressive_brows(style))
    for style in chars.MOUTHS:
        save(f"mouth_{style}", expressive_mouth(style))
    for style in chars.HAIRS:
        back, front = chars.draw_p_hair(style)
        save(f"hair_{style}_back", back)
        save(f"hair_{style}_front", front)
    for outfit in chars.OUTFITS:
        if outfit in ("business_suit", "courier"):
            parts = chars.split_outfit_material(outfit, "neutral")
            save(f"outfit_{outfit}", parts[5])
            save(f"outfit_{outfit}_detail", parts[6])
        else:
            save(f"outfit_{outfit}", chars.draw_p_outfit(outfit))
    for kind in ("round", "square"):
        portrait_glasses(kind).save(OUT / f"acc_glasses_{kind}.png")
    files = sorted(OUT.glob("*.png"))
    assert len(files) == 49, f"Expected 45 base + 2 R1 details + 2 glasses, got {len(files)}"
    print("A5: 45 base layers + 2 R1 details + 2 glasses written")


if __name__ == "__main__":
    generate()
