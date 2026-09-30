"""Publish local runtime evidence, keeping concept art separate from game captures."""
from pathlib import Path
import json, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art_sources/runtime_20260930'
EVIDENCE=ROOT/'evidence/2026-09-30_runtime_art'
names={'riverside_apartment':'河岸公寓','small_office':'創業辦公室','bloom_coffee':'河岸咖啡館',
       'byte_and_bean':'科技咖啡館','nexus_bank':'銀行','nexus_cowork':'共享辦公室',
       'city_hall':'市政廳','postpoint_riverside':'物流據點'}
figures=[]
for key,label in names.items():
    figures.append(f'<figure><a href="../../../evidence/2026-09-30_runtime_art/review/interior_{key}.png"><img loading="lazy" src="../../../evidence/2026-09-30_runtime_art/review/interior_{key}.png" alt="{label}實拍"></a><figcaption>{label} · Godot 實際場景</figcaption></figure>')
for key,label in [('dialogue_neutral','平靜'),('dialogue_happy','開心'),('dialogue_thinking','思考'),('dialogue_surprised','驚訝'),('apartment_night','公寓夜間')]:
    figures.append(f'<figure><a href="../../../evidence/2026-09-30_runtime_art/review/{key}.png"><img loading="lazy" src="../../../evidence/2026-09-30_runtime_art/review/{key}.png" alt="{label}"></a><figcaption>{label} · 實際渲染</figcaption></figure>')
page='''<!doctype html><html lang="zh-Hant"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>City Venture · 遊戲實拍更新</title><style>
*{box-sizing:border-box}body{margin:0;background:#0c1928;color:#edf4fa;font:17px/1.7 system-ui,sans-serif}main{max-width:1450px;margin:auto;padding:38px 28px}h1{font-size:42px;margin:8px 0}h2{margin-top:40px}p{max-width:960px;color:#b1c6d8}a{color:#8fcbf6}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,520px),1fr));gap:24px}figure{margin:0;background:#17293a;border:1px solid #345068;border-radius:8px;overflow:hidden}img{display:block;width:100%;height:auto}figcaption{padding:12px 16px}small{color:#d4b577}.compare{position:relative;max-width:1000px}.compare img{width:100%}.compare #after{position:absolute;inset:0;clip-path:inset(0 0 0 50%)}input{width:min(100%,1000px)}button{background:#24465f;color:white;border:1px solid #81b2d3;padding:10px 20px;cursor:pointer}nav{display:flex;gap:24px;flex-wrap:wrap}</style><main><small>CITY VENTURE / RUNTIME ART / 2026.09.30</small><h1>把美術放進真正的遊戲</h1><p>以下皆由 Godot 的實際場景擷取。角色、家具、對話和日夜窗景使用遊戲中的素材與渲染；展示截圖關閉新地點介紹卡和教學提示，以便檢查場景。</p><nav><a href="../renewal_20260929/gallery.html">原畫展示</a><a href="../../../evidence/2026-09-30_runtime_art/README.md">驗收與範圍</a><a href="sources.json">生成來源與完整提示詞</a></nav><h2>公寓前後比較</h2><p>左側為上一輪遊戲畫面，右側為新版。滑動查看；兩次截圖的 HUD、主角站位與提示狀態不同。</p><div class="compare"><img src="../../../evidence/2026-09-29_art_renewal/after/screenshots/24_interior_riverside_apartment.png" alt="上一輪"><img id="after" src="../../../evidence/2026-09-30_runtime_art/review/interior_riverside_apartment.png" alt="新版"></div><input aria-label="前後比較" type="range" value="50" oninput="document.getElementById('after').style.clipPath='inset(0 0 0 '+this.value+'%)'"><h2>八個室內與對話表情</h2><section>'''+''.join(figures)+'''</section><h2>完成範圍</h2><p>100 個高解析 runtime 素材：主要家具、窗景、材質，預設主角走路與頭像，12 位具名 NPC 的方向與表情、5 位具名角色坐姿、6 位室內顧客。249 項實際場景檢查、67 項遊戲單元測試通過。</p><p>仍有落差：自訂主角、換裝、街道行人、僱員、部分裝飾與建築外觀仍用原素材；坐姿尚未提供四表情。這是已接入的室內與人物更新，不代表整款遊戲已達原畫品質。</p></main></html>'''
(OUT/'gallery.html').write_text(page,encoding='utf-8')
report=[]
for f in sorted((ROOT/'game/assets/world_detail').rglob('*.png')):
    report.append({'asset':f.relative_to(ROOT).as_posix(),'size':Image.open(f).size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
(EVIDENCE/'asset_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Runtime gallery and manifest written:',len(report),'assets')
