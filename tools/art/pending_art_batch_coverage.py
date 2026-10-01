"""Read-only union of pending art batches; file coverage is not runtime acceptance."""
from pathlib import Path
from collections import Counter
import subprocess,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
BASE="9145015af512ba98bc7560162c0de61a5ec01d70"
BATCHES=[("City-Venture-character-quality",46),("City-Venture-traffic-quality",49),("City-Venture-environment-quality",50),("City-Venture-utilities-quality",51),("City-Venture-interior-quality",54),("City-Venture-frontage-quality",55),("City-Venture-wardrobe-quality",56),("City-Venture-ground-quality",57),("City-Venture-ui-quality",58),("City-Venture-map-quality",59),("City-Venture-backdrop-quality",60)]
assets={p.relative_to(ROOT/"game/assets").as_posix():(p,"Claude base") for p in (ROOT/"game/assets").rglob("*.png")}
batches=[]
for folder,pr in BATCHES:
    checkout=ROOT.parent/folder
    common=subprocess.check_output(["git","merge-base",BASE,"HEAD"],cwd=checkout,text=True).strip()
    files=subprocess.check_output(["git","diff","--name-only",common,"HEAD","--","game/assets"],cwd=checkout,text=True).splitlines()
    head=subprocess.check_output(["git","rev-parse","HEAD"],cwd=checkout,text=True).strip()
    batches.append({"pr":pr,"head":head,"merge_base":common,"runtime_integration":"NOT_VERIFIED_AS_COMBINED_GAME"})
    for file in files:
        if file.endswith(".png") and (checkout/file).exists():
            key=Path(file).relative_to("game/assets").as_posix()
            assets[key]=(checkout/file,f"PR #{pr}")
rows=[]
for key,(p,owner) in sorted(assets.items()):
    if key.startswith("world_detail/"):continue
    size=Image.open(p).size
    detail=assets.get("world_detail/"+key)
    dsize=Image.open(detail[0]).size if detail else None
    rows.append({"asset":key,"category":key.split("/")[0],"native":size,"source":owner,"detail":dsize,"detail_source":detail[1] if detail else None,"exact_4x":dsize==tuple(v*4 for v in size),"combined_runtime":"NOT_VERIFIED"})
out=ROOT/"docs/art_sources/backdrop_quality_20261001"
(out/"pending_batch_coverage.json").write_text(json.dumps({"base":BASE,"batches":batches,"assets":rows},indent=2)+"\n",encoding="utf-8")
groups=Counter(r["category"] for r in rows)
ok=Counter(r["category"] for r in rows if r["exact_4x"])
md=["# 待合併美術批覆蓋盤點","",f"基底：{BASE}。讀取11個Draft批的美術差異，未合併、未更動任何遊戲。這是PNG檔案覆蓋，不能作為整合後實機品質PASS。","", "| 類別 | 原尺寸PNG | 正確4× | 仍缺或尺寸不符 |","|---|---:|---:|---:|"]
for category,num in sorted(groups.items()):md.append(f"| {category} | {num} | {ok[category]} | {num-ok[category]} |")
md.extend(["","## 尚待處理的圖檔",""])
for row in rows:
    if not row["exact_4x"]:md.append(f'- {row["asset"]}：{"缺detail" if row["detail"] is None else "detail尺寸不符"}')
md.extend(["","## 已知整合品質問題","",
"- 所有Draft尚未一起合併；本盤點僅讀取差異，各批實拍分別驗收，combined runtime維持NOT_VERIFIED。",
"- #46包含自訂角色高解析/表情接線；不同膚色、體型、髮型、服裝及姿勢的最終整合仍需再逐街區實拍。具名NPC走路欄與表情欄需Claude分離。",
"- #56五套商店服裝需套用正式配色metadata；現行程式會忽略原stand_in配色。單元測試250/251，唯一失敗是尚硬編碼暫代服裝的測試，不屬於本美術線可修改範圍。",
"- 外觀、車輛、地磚、UI、地圖及背景多仍載native；detail檔案存在不代表渲染已載4×。Claude需保留logical尺寸、atlas格子與燈光強度接入。",
"- #60部分背景的4×輸出需來源插值，比例已公開；不是額外原生像素細節。",
"- 個別Draft的53張巡禮不能取代合併後40–60分鐘繁中故事和全街區日夜/碰撞/遮擋驗收。",""])
(out/"pending_batch_coverage.md").write_text("\n".join(md),encoding="utf-8")
print("\n".join(md[:6+len(groups)]))
print(f"TOTAL {len(rows)} native PNG; {sum(r['exact_4x'] for r in rows)} exact 4x; {sum(not r['exact_4x'] for r in rows)} remaining")
