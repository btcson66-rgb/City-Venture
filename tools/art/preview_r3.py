"""Review assembled R3 poses for a named NPC across all directions."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


game, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
assets = game / "assets" / "characters"
options = json.loads((game / "data" / "character" / "options.json").read_text(encoding="utf-8"))


def colour(group, name):
    return next(x["color"] for x in options[group] if x["id"] == name)


def load(name):
    return Image.open(assets / (name + ".png")).convert("RGBA")


def tint(im, code):
    rgb = tuple(bytes.fromhex(code.lstrip("#")))
    channels = ImageChops.multiply(im.convert("RGB"), Image.new("RGB", im.size, rgb))
    return Image.merge("RGBA", (*channels.split(), im.getchannel("A")))


def assembled(npc, pose):
    app = npc["appearance"]
    pre, hair, eye, outfit = app["presentation"], app["hair"], app["eye_shape"], npc["outfit"]
    suffix = "_" + pose if pose else ""
    hc = colour("hair_colors", app["hair_color"])
    top_col = npc.get("outfit_tints", {}).get("top", "#ffffff")
    bottom_col = npc.get("outfit_tints", {}).get("bottom", "#ffffff")
    base = f"outfit_{outfit}_{pre}"
    layers = [
        tint(load(f"hair_{hair}_back{suffix}"),hc),
        tint(load(f"body_{pre}_{app['face']}{suffix}"),colour("skin_tones",app["skin"])),
        tint(load(base+"_bottom"+suffix),bottom_col),
        load(base+"_shoes"+suffix),
        tint(load(base+"_top"+suffix),top_col),
    ]
    detail = base + "_top_detail" + suffix
    if (assets/(detail+".png")).exists():
        layers.append(load(detail))
    layers += [
        load(f"eyes_{eye}{suffix}"),
        tint(load(f"iris_{eye}{suffix}"),colour("eye_colors",app["eye_color"])),
        tint(load(f"brows_{app['brows']}{suffix}"),hc),
        load(f"mouth_{app['mouth']}{suffix}"),
        tint(load(f"hair_{hair}_front{suffix}"),hc),
    ]
    accessory = app.get("accessory", "none")
    if accessory != "none":
        layers.append(load(f"acc_{accessory}{suffix}"))
    merged = Image.new("RGBA",(128,144))
    for layer in layers:
        merged.alpha_composite(layer)
    return merged


npc = json.loads((game / "data" / "npcs" / "daniel.json").read_text(encoding="utf-8"))
names = ("walk", "sit", "idle", "phone", "interact", "carry")
scale = 4
page = Image.new("RGB",(6*128*scale+24, 3*48*scale+84),"#e4edf4")
draw = ImageDraw.Draw(page)
for i,name in enumerate(names):
    image = assembled(npc,"" if name == "walk" else name)
    for row in range(3):
        fragment = image.crop((0,row*48,128,row*48+48))
        enlarged = fragment.resize((128*scale,48*scale),Image.Resampling.NEAREST)
        x,y = 12+i*128*scale, 24+row*48*scale
        page.paste(enlarged,(x,y),enlarged)
    draw.text((12+i*128*scale, 6),name,fill="#18324c")
page.save(out/"after_daniel_all_poses.png")
before = Image.new("RGB", (128*scale+24, 3*48*scale+84), "#e4edf4")
before_draw = ImageDraw.Draw(before)
walk = assembled(npc, "")
for row in range(3):
    fragment = walk.crop((0,row*48,128,row*48+48))
    enlarged = fragment.resize((128*scale,48*scale),Image.Resampling.NEAREST)
    before.paste(enlarged,(12,24+row*48*scale),enlarged)
before_draw.text((12,6),"walk pose before R3",fill="#18324c")
before.save(out/"before_daniel_walk_only.png")
print("R3 assembled preview: walk + 5 poses, 3 directions")
