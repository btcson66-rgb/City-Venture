import io, subprocess, tarfile, shutil
from pathlib import Path
root=Path('qa-output/167-baseline-probed').resolve()
root.mkdir(exist_ok=True)
tracked=set(subprocess.check_output(['git','ls-tree','-r','--name-only','c66bb702','game'],text=True).splitlines())
paths=sorted({'/'.join(p.split('/')[:2]) for p in tracked if not p.startswith('game/assets/')})
raw=subprocess.check_output(['git','archive','c66bb702',*paths])
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
    archive.extractall(root,filter='data')
game=root/'game'
if not (game/'assets').exists():
    subprocess.run(['cmd','/c','mklink','/J',str(game/'assets'),str(Path('game/assets').resolve())],check=True)
probe=game/'scripts/qa/web_smoke_probe.gd'
probe.parent.mkdir(exist_ok=True)
shutil.copyfile('game/scripts/qa/web_smoke_probe.gd',probe)
boot=game/'scripts/boot.gd'
body=boot.read_text(encoding='utf-8')
body=body.replace('\tI18n.init()','\tI18n.init()\n\tif OS.has_feature("web"):\n\t\tget_tree().root.add_child(load("res://scripts/qa/web_smoke_probe.gd").new())',1)
boot.write_text(body,encoding='utf-8')
print(root)
