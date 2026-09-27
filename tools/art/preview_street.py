"""Compose a mock district strip from generated assets to judge the look without the engine."""
import json, sys
from PIL import Image
A = sys.argv[1]; OUT = sys.argv[2]
atlas = Image.open(A + "/tiles/atlas.png"); idx = json.load(open(A + "/tiles/atlas.json"))["tiles"]
def tile(n):
    x, y = idx[n]; return atlas.crop((x*16, y*16, x*16+16, y*16+16))
W, H = 1040, 460
c = Image.new("RGBA", (W, H), (0, 0, 0, 255))
rows = [("plaza_alt", 0, 20), ("sidewalk", 20, 24), ("curb_top", 24, 25), ("road", 25, 30), ("curb_bottom", 30, 31), ("sidewalk", 31, 34), ("grass", 34, 40)]
for name, r0, r1 in rows:
    for r in range(r0, r1):
        for col in range(W // 16 + 1):
            t = name
            if name == "road" and r == 27 and col % 2 == 0: t = "road_dash_h"
            if name == "road" and 10 <= col <= 12: t = "crosswalk_h"
            if name == "grass" and r in (36, 37): t = "boards"
            c.paste(tile(t), (col*16, r*16 - 180))
base = 320 - 180
x = 16
for b in ["riverside_walkup", "riverside_tower", "bloom_block", "riverside_shops", "postpoint", "horizon_labs"]:
    im = Image.open(A + "/buildings/%s.png" % b)
    c.alpha_composite(im, (x, base + 4 - im.height))
    x += im.width + 6
def prop(n, x, y):
    im = Image.open(A + "/props/%s.png" % n); c.alpha_composite(im, (x, y - im.height))
for px in range(60, W, 150): prop("tree_round", px, base + 30)
for px in range(130, W, 150): prop("lamp_banner", px, base + 24)
for px in range(20, W, 40): prop("bollard", px, base + 62)
prop("planter", 470, base + 40); prop("umbrella_table", 520, base + 44); prop("cafe_board", 580, base + 30)
prop("bench", 300, base + 150); prop("fountain", 620, base + 180); prop("hedge", 100, base + 150); prop("flower_bed", 800, base + 150)
prop("bus_stop", 880, base + 150); prop("metro_sign", 420, base + 150); prop("direction_sign", 980, base + 40); prop("digital_sign", 760, base + 40)
for px in (200, 700): prop("tree_round_b", px, base + 200)
c.crop((0, 0, W, H)).resize((W*2//2*1, H), Image.NEAREST).save(OUT)
