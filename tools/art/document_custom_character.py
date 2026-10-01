"""Build the delivery inventory and wiki's explicit asset coverage."""
from pathlib import Path
import json,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'docs/art_sources/custom_character_20261001'
jobs=json.loads((SOURCE/'render_jobs.json').read_text())
inventory=[]
for job in jobs:
    paths=[]
    for prefix,factor in [('',1),('world_detail/',4)]:
        p=ROOT/'game/assets'/(prefix+job['key']+'.png')
        assert Image.open(p).size==tuple(x*factor for x in job['size']),p
        assert Path(str(p)+'.import').exists(),p
        paths.append({'path':p.relative_to(ROOT).as_posix(),'size':list(Image.open(p).size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    inventory.append({'key':job['key'],'source':job['source'],'outputs':paths})
(SOURCE/'manifest.json').write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8')
wiki=ROOT/'docs/wiki/13_runtime_art.md'
content=wiki.read_text(encoding='utf-8')
marker='\n## 2026-10-01 自訂角色品質修正\n'
content=content.split(marker)[0]
content+=marker+'\n美術狀態：完整分層素材已交（原尺寸、4×、匯入檔）；建立器、頭像與全身預览共用素材。六種膚色、三種外型、四種臉型、八種髮型與現有服裝不再切換到另一套低解析輪廓。保留具名 NPC 專屬覆寫。\n\n'
content+='`Art.tex` 保留既有 logical key，優先讀高解析分層圖；移除只有預設造型才會使用的單張主角覆寫。四表情 `*_expressions` 層獨立於走路影格，頭像與建立器全身同步。腳底 (16,46)、32×48 邏輯格、碰撞與存檔外觀欄位不變。\n\n'
content+='材質原畫由 imagegen 生成，SVG 原稿負責分層與姿勢；所有提示詞、原畫、打包邊界和可重建來源見 `docs/art_sources/custom_character_20261001/`。完整實機證據見 `evidence/20261001_character_customization/README.md`。這批不宣稱已完成所有建築與未推出內容的美術。\n\n'
content+='共有 %d 個圖層/姿勢檔名；下列每項各交原尺寸及 world_detail 4×：\n\n'%len(jobs)
content+='\n'.join('- `'+j['key'].split('/')[-1]+'`' for j in jobs)+'\n'
content+='\n分層名稱的完整部件索引（供 wiki_check 按 prefix 解析）：\n\n'
parts=set()
for job in jobs:
    name=job['key'].split('/')[-1]
    for pose in ['sit','idle','phone','interact','carry']:
        if name.endswith('_'+pose):name=name[:-len(pose)-1];break
    for prefix in ['body_','hair_','eyes_','iris_','brows_','mouth_','outfit_','acc_','head_']:
        if name.startswith(prefix):
            core=name[len(prefix):]
            for suffix in ['_detail','_back','_front','_top','_bottom','_shoes']:
                if core.endswith(suffix):core=core[:-len(suffix)]
            core='_'.join(x for x in core.split('_') if x not in ['masculine','feminine','neutral']) if prefix!='acc_' else core
            parts.add(core);break
content+=', '.join('`'+p+'`' for p in sorted(parts))+'\n'
wiki.write_text(content,encoding='utf-8')
print('custom_character_inventory: %d native + %d detail PNG/import pairs verified'%(len(jobs),len(jobs)))
