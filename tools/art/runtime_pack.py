"""Pack generated runtime art; preserve original logical footprints and alpha.

This is atlas slicing/resizing, not illustration generation. Originals + prompts
live in docs/art_sources/runtime_20260930. Re-run after adding source entries.
"""
from pathlib import Path
import json
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/art_sources/runtime_20260930'
ASSETS = ROOT / 'game/assets'
OUT = ASSETS / 'world_detail'

# Hand-checked object bounds in the generated 1536x1024 atlas; unlike regular
# animation sheets, the generator varied the furniture column widths.
FURNITURE = [
 ('bed',(12,64,322,317)), ('wardrobe',(340,23,493,318)),
 ('bookshelf',(534,22,745,318)), ('desk_laptop',(778,110,1083,317)),
 ('office_chair',(1111,70,1267,319)), ('plant_big',(1298,25,1535,321)),
 ('fridge',(26,325,181,562)), ('kitchen',(183,375,492,562)),
 ('sofa',(494,392,801,562)), ('coffee_table',(803,415,990,550)),
 ('tv',(991,380,1218,562)), ('exec_desk',(1219,367,1535,562)),
 ('monitor_desk',(9,581,298,790)), ('cafe_counter',(301,580,613,790)),
 ('cafe_table',(616,618,772,790)), ('cafe_chair',(778,598,913,790)),
 ('bank_counter',(916,590,1256,790)), ('waiting_sofa',(1260,624,1535,790)),
 ('parcel_shelf',(12,794,246,1010)), ('packing_table',(248,807,540,1010)),
 ('community_table',(542,803,919,1010)), ('display_case',(923,796,1186,1010)),
 ('atm',(1190,790,1324,1010)), ('plant',(1330,809,1535,1010)),
]
ALIASES = {'chair':'office_chair','plant_bank':'plant_big','lounge_sofa':'sofa',
           'civic_counter':'bank_counter','postpoint_counter':'bank_counter',
           'desk':'desk_laptop'}
FIXTURES = ['window_day','window_night','whiteboard','menu_board','rug_navy',
            'rug','water_cooler','printer','filing_cabinet','hanging_light',
            'phone_booth','glass_wall','bench_civic','brochure_stand','info_kiosk','sconce']


def trimmed(cell):
    # Exclude negligible alpha noise from bounds, retain actual generated alpha.
    box = cell.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    if not box:
        raise ValueError('Empty generated cell')
    return cell.crop(box)


def save_prop(cell, name):
    oldpath = ASSETS / 'interiors' / (name + '.png')
    if not oldpath.exists():
        return
    old = Image.open(oldpath).convert('RGBA')
    box = old.getchannel('A').point(lambda a: 255 if a > 32 else 0).getbbox()
    x,y,r,b = box
    # Furniture must occupy its original design bounds even when source aspect
    # differs; transparent margins, ground contact and y-sort anchor stay fixed.
    detail = trimmed(cell).resize(((r-x)*4,(b-y)*4), Image.Resampling.LANCZOS)
    target = Image.new('RGBA', (old.width*4,old.height*4))
    target.paste(detail,(x*4,y*4))
    dest = OUT/'interiors'/(name+'.png')
    dest.parent.mkdir(parents=True, exist_ok=True)
    target.save(dest)


def sheet(source, target):
    im = Image.open(source).convert('RGBA')
    cells = []
    for y in range(3):
        for x in range(4):
            cells.append(trimmed(im.crop((round(x*im.width/4),round(y*im.height/3),
                                         round((x+1)*im.width/4),round((y+1)*im.height/3)))))
    factor = min(176/max(c.height for c in cells),112/max(c.width for c in cells))
    atlas = Image.new('RGBA',(512,576))
    for i,c in enumerate(cells):
        if target.stem in ['npc_ken','npc_lee','npc_sofia','npc_tom'] and i//4 == 1:
            c = ImageOps.mirror(c)  # generated profile faces left; engine expects right
        c = c.resize((round(c.width*factor),round(c.height*factor)),Image.Resampling.LANCZOS)
        atlas.paste(c,((i%4)*128+(128-c.width)//2,(i//4)*192+184-c.height))
    target.parent.mkdir(parents=True,exist_ok=True)
    atlas.save(target)


def seated(source, names):
    im=Image.open(source).convert('RGBA')
    rows=[0,.354,.697,1] if source.stem=='guests' else [0,.375,.719,1]
    for x,name in enumerate(names):
        cells=[trimmed(im.crop((round(x*im.width/len(names)),round(rows[y]*im.height),
                               round((x+1)*im.width/len(names)),round(rows[y+1]*im.height)))) for y in range(3)]
        factor=min(132/max(c.height for c in cells),112/max(c.width for c in cells))
        atlas=Image.new('RGBA',(512,576))
        for y,c in enumerate(cells):
            c=c.resize((round(c.width*factor),round(c.height*factor)),Image.Resampling.LANCZOS)
            for f in range(4):
                atlas.paste(c,(f*128+(128-c.width)//2,y*192+184-c.height))
        atlas.save(OUT/'characters'/('npc_'+name+'_sit.png'))
        if name.startswith('guest_'):
            atlas.save(OUT/'characters'/('npc_'+name+'.png'))


def main():
    im = Image.open(SOURCE/'furniture.png').convert('RGBA')
    cells = {}
    for name,box in FURNITURE:
        cells[name] = im.crop(tuple(round(v*(im.width/1536 if i%2==0 else im.height/1024)) for i,v in enumerate(box)))
        save_prop(cells[name],name)
    for name,src in ALIASES.items():
        save_prop(cells[src],name)
    if (SOURCE/'fixtures.png').exists():
        im=Image.open(SOURCE/'fixtures.png').convert('RGBA')
        for i,name in enumerate(FIXTURES):
            x,y=i%4,i//4
            # The wide divider and bench cross the nominal grid; reviewed bounds.
            bounds={0:(18,45,312,288),1:(329,45,629,288),
                    2:(640,65,912,284),3:(919,64,1243,284),
                    4:(14,353,319,556),5:(328,353,632,560),
                    6:(704,303,853,590),7:(925,323,1238,590),
                    8:(73,600,247,911),9:(358,594,587,910),
                    10:(632,593,886,909),11:(887,621,1254,909),
                    12:(8,950,430,1210),13:(447,910,625,1240),
                    14:(667,901,865,1240),15:(975,912,1234,1220)}
            box=bounds.get(i,(round(x*1254/4),round(y*1254/4),round((x+1)*1254/4),round((y+1)*1254/4)))
            c=im.crop(tuple(round(v*im.width/1254) for v in box))
            save_prop(c,name)
            if name=='rug': save_prop(c,'rug_small')
            if name=='brochure_stand': save_prop(c,'brochure')
            if name=='info_kiosk': save_prop(c,'ticket_machine')
    im=Image.open(SOURCE/'materials.png').convert('RGBA')
    im.crop((round(im.width*2/3),round(im.height/2),im.width,im.height)).save(OUT/'interiors/wall_plaster.png')
    for name,i in {'wood_warm':0,'wood_cafe':0,'wood_dark':1,'marble':2,'tile_white':2,'carpet_navy':3,'concrete':4}.items():
        x,y=i%3,i//3
        c=im.crop((round(x*im.width/3),round(y*im.height/2),round((x+1)*im.width/3),round((y+1)*im.height/2)))
        c.resize((768,768),Image.Resampling.LANCZOS).save(OUT/'interiors'/('floor_'+name+'.png'))
    sheet(SOURCE/'player.png',OUT/'characters/player_default.png')
    for path in SOURCE.glob('npc_*.png'):
        sheet(path,OUT/'characters'/path.name)
    if (SOURCE/'seated.png').exists():
        seated(SOURCE/'seated.png',['maya','elena','daniel','ken','marcus'])
    if (SOURCE/'guests.png').exists():
        seated(SOURCE/'guests.png',['guest_'+str(i) for i in range(6)])
    # Repack existing expression originals without discarding their facial detail.
    portraits=ROOT/'docs/art_sources/renewal_20260929'
    for ent in json.loads((portraits/'sources.json').read_text(encoding='utf-8')):
        if ent['layout']=='scene': continue
        im=Image.open(portraits/(ent['id']+'.png')).convert('RGBA')
        atlas=Image.new('RGBA',(1024,256))
        for i in range(4):
            x,y=(i,0) if ent['layout']=='row4' else (i%2,i//2)
            cols,rows=(4,1) if ent['layout']=='row4' else (2,2)
            c=im.crop((round(x*im.width/cols),round(y*im.height/rows),round((x+1)*im.width/cols),round((y+1)*im.height/rows)))
            atlas.paste(ImageOps.pad(c,(256,256),method=Image.Resampling.LANCZOS,color='#1b273f'),(i*256,0))
        dest=OUT/'portraits'/('npc_'+ent['id']+'.png')
        dest.parent.mkdir(parents=True,exist_ok=True)
        atlas.save(dest)
    if (SOURCE/'founder_portrait.png').exists():
        im=Image.open(SOURCE/'founder_portrait.png').convert('RGBA')
        atlas=Image.new('RGBA',(1024,256))
        for i in range(4):
            x,y=i%2,i//2
            c=im.crop((round(x*im.width/2),round(y*im.height/2),round((x+1)*im.width/2),round((y+1)*im.height/2)))
            atlas.paste(c.resize((256,256),Image.Resampling.LANCZOS),(i*256,0))
        atlas.save(OUT/'portraits/player_default.png')
    print('Packed runtime furniture, materials, characters and expressions.')


if __name__=='__main__':main()
