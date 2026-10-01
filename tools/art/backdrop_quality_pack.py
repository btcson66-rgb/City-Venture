"""Export approved illustrations directly, without palette snapping."""
from pathlib import Path
import ast,json,hashlib
from PIL import Image,ImageOps
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/"docs/art_sources/renewal_20260929"
out=ROOT/"docs/art_sources/backdrop_quality_20261001"
tree=ast.parse((ROOT/"tools/art/renewal_pack.py").read_text(encoding="utf-8"))
scenes=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=="SCENES" for t in n.targets))
manifest=[]
for name,targets in scenes.items():
    original=Image.open(source/(name+".png")).convert("RGBA")
    for asset,size in targets:
        native=ROOT/"game/assets"/(asset+".png")
        assert Image.open(native).size==size,(asset,size)
        # Use original artwork for both exports, never enlarge palette-reduced native PNG.
        hi=ImageOps.fit(original,(size[0]*4,size[1]*4),method=Image.Resampling.LANCZOS)
        low=ImageOps.fit(original,size,method=Image.Resampling.LANCZOS)
        detail=ROOT/"game/assets/world_detail"/(asset+".png")
        detail.parent.mkdir(parents=True,exist_ok=True)
        low.save(native);hi.save(detail)
        ratio=max(size[0]*4/original.width,size[1]*4/original.height)
        manifest.append({"asset":asset,"size":size,"source":str((source/(name+".png")).relative_to(ROOT)).replace("\\","/"),"source_size":original.size,"source_sha256":hashlib.sha256((source/(name+".png")).read_bytes()).hexdigest(),"detail_upsample_ratio":round(max(1,ratio),3)})
(out/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print(f"backdrop_pack: {len(manifest)} assets / {len(manifest)*2} native+detail PNGs")
print("4x export preserves original source detail; assets requiring interpolation disclosed in manifest")

