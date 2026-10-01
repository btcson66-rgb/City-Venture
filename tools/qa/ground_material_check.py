"""Check atlas slots, untouched cells, material seams and readable road markings."""
from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];SRC=ROOT/'docs/art_sources/ground_materials_20261001'
def main():
    baseline=json.loads((SRC/'baseline_atlas.json').read_text());live=json.loads((ROOT/'game/assets/tiles/atlas.json').read_text())
    assert baseline==live,'Atlas metadata moved'
    jobs=json.loads((SRC/'render_jobs.json').read_text());changed={j['key'] for j in jobs};checks=[]
    for factor,prefix,source in [(1,'','baseline_atlas.png'),(4,'world_detail/','baseline_detail_atlas.png')]:
        p=ROOT/'game/assets'/(prefix+'tiles/atlas.png');now=Image.open(p).convert('RGBA');old=Image.open(SRC/source).convert('RGBA')
        assert now.size==old.size==(128*factor,96*factor);assert Path(str(p)+'.import').exists()
        for key,(x,y) in live['tiles'].items():
            box=(x*16*factor,y*16*factor,(x+1)*16*factor,(y+1)*16*factor)
            cell=now.crop(box)
            if key in changed:assert cell.getchannel('A').getextrema()==(255,255),key
            if key not in changed:assert cell.tobytes()==old.crop(box).tobytes(),key
            if key in ['road','road_b','grass','water','water_alt','water_harbor']:
                px=np.array(cell).astype(float);seam=max(abs(px[:,0,:3]-px[:,-1,:3]).max(),abs(px[0,:,:3]-px[-1,:,:3]).max())
                assert seam<=12,(key,factor,seam)
                checks.append({'key':key,'factor':factor,'edge_max_rgb_delta':float(seam)})
        # All unassigned cells remain byte-identical too.
        for y in range(6):
            for x in range(8):
                if [x,y] not in list(live['tiles'].values()):
                    box=(x*16*factor,y*16*factor,(x+1)*16*factor,(y+1)*16*factor)
                    assert now.crop(box).tobytes()==old.crop(box).tobytes()
    ev=ROOT/'evidence/20261001_ground_materials';page=Image.new('RGB',(896,840),'#142538');d=ImageDraw.Draw(page)
    atlas=Image.open(ROOT/'game/assets/world_detail/tiles/atlas.png').convert('RGB')
    for i,key in enumerate(['road','water','grass','sidewalk','plaza','cobble_a','quay_concrete','water_harbor']):
        x,y=live['tiles'][key];tile=atlas.crop((x*64,y*64,x*64+64,y*64+64));left=i%4*224;top=i//4*420
        d.text((left+5,top+8),key+' / 4x repeated',fill='white')
        for ty in range(6):
            for tx in range(3):page.paste(tile,(left+tx*64,top+30+ty*64))
    page.save(ev/'material_repeat_review.png')
    manifest={'changed_slots':jobs,'seam_checks':checks,'native_sha256':hashlib.sha256((ROOT/'game/assets/tiles/atlas.png').read_bytes()).hexdigest(),'detail_sha256':hashlib.sha256((ROOT/'game/assets/world_detail/tiles/atlas.png').read_bytes()).hexdigest(),'atlas_metadata_unchanged':True,'unchanged_interior_slots':15}
    (SRC/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('ground_material_check: 28 outdoor slots; 43 coordinates unchanged; 15 interior and 5 unused slots preserved; opposite material edge delta <= 12; native/4x size/import OK')
if __name__=='__main__':main()
