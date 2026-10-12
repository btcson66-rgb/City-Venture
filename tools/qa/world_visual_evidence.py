"""Compact native rendered screenshots for review; preserve capture dimensions in a manifest."""
from pathlib import Path
from PIL import Image
import argparse,json,re,hashlib
def main():
    parser=argparse.ArgumentParser();parser.add_argument('evidence',type=Path);args=parser.parse_args()
    rows=[]
    for phase in ['before','after','mobile-large-en']:
        for p in sorted((args.evidence/phase/'screenshots').glob('*.png')):
            name=re.sub(r'^\d+_','',p.stem)
            if phase=='mobile-large-en' and not ('helio_' in name or '_exit_' in name):continue
            if phase=='mobile-large-en' and '_exit_' in name and not name.startswith('riverside_'):continue
            out=args.evidence/'gallery'/phase/(name+'.jpg');out.parent.mkdir(parents=True,exist_ok=True)
            image=Image.open(p).convert('RGB');native=image.size
            image.thumbnail((800,600),Image.Resampling.LANCZOS);image.save(out,quality=85,optimize=True)
            rows.append({'phase':phase,'name':name,'capture_pixels':native,'review_pixels':image.size,
                         'file':out.relative_to(args.evidence).as_posix(),'sha256':hashlib.sha256(out.read_bytes()).hexdigest()})
    size=sum((args.evidence/r['file']).stat().st_size for r in rows)
    (args.evidence/'capture_manifest.json').write_text(json.dumps({'bytes':size,'screenshots':rows},indent=2),encoding='utf-8')
    print(f'{len(rows)} review JPGs; {size/1e6:.3f} MB; original renderer dimensions recorded')
    assert size<19_000_000,'Evidence exceeds ticket budget; retain raw captures locally and compact review JPGs further'
if __name__=='__main__':main()
