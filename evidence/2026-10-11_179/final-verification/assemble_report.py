"""Collect final raw results and selected actual captures; run from repository root."""
import hashlib
import itertools
import json
import shutil
from pathlib import Path

root = Path(__file__).resolve().parent
web = root / "web"
results = []
for engine, view, size, locale in itertools.product(
    ["chromium", "webkit"], ["portrait", "landscape", "tablet"],
    ["default", "large"], ["zh_TW", "en"],
):
    name = f"{engine}-{view}-{size}-{locale}"
    result = json.loads((web / name / "result.json").read_text(encoding="utf-8"))
    results.append(result)
    destination = root / "browser-results" / name
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(web / name / "result.json", destination / "result.json")
    if result["status"] == "FAIL" and (web / name / "failure_state.json").exists():
        shutil.copyfile(web / name / "failure_state.json", destination / "failure_state.json")
    for shot in (web / name).glob("*.jpg"):
        if "failure" in shot.name and result["status"] == "PASS":
            continue  # Earlier aborted-worker screenshots are not the final case result.
        if any(label in shot.name for label in ["first_job_paid", "company_os", "reload_loaded", "failure"]):
            shutil.copyfile(shot, destination / shot.name)

pck = Path("build/web/index.pck")
summary = {
    "runtime_source": "8cb2234c6c238495119f57d3d689c4344a05e9b7",
    "qa_fixture_source": "08f213cdb38b44c5e3941ab1fc9d998118cced6d",
    "chromium_graphics": "zh_TW: ANGLE SwiftShader; en: --enable-gpu --use-angle=d3d11 (Quadro RTX 4000). Renderer probe confirmed both backends available; not a performance comparison.",
    "pck_bytes": pck.stat().st_size,
    "pck_sha256": hashlib.sha256(pck.read_bytes()).hexdigest(),
    "web_cases": len(results),
    "chromium_pass": sum(r["name"].startswith("chromium-") and r["status"] == "PASS" and not r["console_errors"] for r in results),
    "webkit_pass": sum(r["name"].startswith("webkit-") and r["status"] == "PASS" and not r["console_errors"] for r in results),
    "results": results,
    "native_practice_slow": json.loads((root / "practice-slow-final/walkthrough_result.json").read_text()),
    "native_practice_large": json.loads((root / "practice-large/walkthrough_result.json").read_text()),
    "native_industries": json.loads((root / "industries-qualified/walkthrough_result.json").read_text()),
    "industry_audit_review": json.loads((root / "industry-audit-review.json").read_text()),
    "open_issues": [186, 187],
    "physical_mobile_safari": "NOT VERIFIED",
    "human_blind_novice_or_10h_replay": "NOT VERIFIED",
}
(root / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
lines = [
    "# 最終補充驗證", "",
    "同一份實際 build/web：127227328 bytes，SHA256 `4a8bd9340f15384c8e3abb0627b8c92ffbb33a9cd2336e7d7cdbc879b81c6efc`。Runtime 8cb2234c；後續 08f213cd 只修獨立產業 QA 開始狀態和技術版本字串 audit，沒有改遊戲。最終 PR CI 另見 PR Checks。", "",
    "提交 log 僅移除行尾空白、統一換行；沒有改時間、步驟、錯誤或結果。原始 result/audit JSON 與截圖保留，失敗結果沒有改成通過。", "",
    "## Web 觸控", "",
    "Playwright、隔離 browser storage、COOP/COEP HTTP server、device_scale_factor=1、is_mobile/has_touch=true。Default font_size=1；Extra Large font_size=3。核心流程以玩家觸控完成角色建立、新遊戲、第一次練習、正式六筆工作、收款、Company OS、存檔與重新載入；probe 只讀狀態。第一個 default zh_TW portrait case 另包含捷運、睡眠、銀行預約與通知。", "",
    "Chromium 繁中使用 ANGLE SwiftShader；英文使用 `--enable-gpu --use-angle=d3d11`。同一主機的 WebGL2 renderer probe 分別回傳 SwiftShader Device／NVIDIA Quadro RTX 4000 D3D11。這是功能驗證，不混用為效能比較。後續重現 script 預設使用硬體 D3D11；原始 zh_TW 結果保留。", "",
    "| 引擎／viewport／文字／語系 | 結果 | Console/page errors | 觸控 | 證據 |",
    "|---|---|---:|---:|---|",
]
for result in results:
    name = result["name"]
    links = [f"[JSON](browser-results/{name}/result.json)"]
    for shot in sorted((root / "browser-results" / name).glob("*.jpg")):
        label = "錯誤畫面" if "failure" in shot.name else ("Company OS" if "company_os" in shot.name else ("收款" if "first_job_paid" in shot.name else "讀檔"))
        links.append(f"[{label}](browser-results/{name}/{shot.name})")
    lines.append(f'| {name} | {result["status"]} | {len(result["console_errors"])} | {result["touches"]} | {" / ".join(links)} |')
lines += [
    "", "Chromium 功能通過不等於畫面完全通過：直式 Company OS 橫向裁切（英文預設字體也可見）／大字 HUD 擁擠已記錄 [#186](https://github.com/btcson66-rgb/City-Venture/issues/186)。WebKit 26.5 / Windows 在啟動時重現 WebGL framebuffer console error，記錄 [#187](https://github.com/btcson66-rgb/City-Venture/issues/187)，不能算 Safari 通過，也不能推論實體 Safari 必然失敗。兩項都保留原始失敗畫面／JSON。", "",
    "重現：安裝 Playwright browsers，從 repo root 執行 `python evidence/2026-10-11_179/final-verification/export_core_smoke.py --export-dir build/web --out qa-output/final-core-web`。串行單一 worker；沒有操作遊戲狀態。`assemble_report.py` 整理原始結果與選定實際截圖，不修改截圖。", "",
    "## 原生遊玩與失敗歷史", "",
    "Godot 4.5.1，Windows OpenGL3，1280×720，zh_TW；一般 tour 預設文字，practice-large 為 Extra Large／touch 模式。原生代表 JPG 縮至 800×450 quality 85；Web JPG 保留 viewport 尺寸。每個 `--out` 下的 saves 獨立，bot 在選單讀存檔前指定 SaveSystem.DIR，沒有覆寫玩家存檔。", "",
    "重現：`godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=practice --slow-work --lang=zh_TW --out=<isolated-output>`；大字改 `--practice-large`；產業改 `--bot=walkthrough --from=industries`（QA source 08f213cd）。Claude 對照是 4bfff0a4 的相同 practice 流程。", "",
    "- 長等待 first-job：正式工作 65 秒等待、溫和錯杯重試、六筆工作收款 +$79.75、重看／熟練跳過；最終 72 截圖／290 步／0 failures。Extra Large 全 18 小遊戲練習回歸 0 failures。",
    "- 六產業：78 截圖／399 步／0 failures；真實租約、機器／員工、第一張發票、飯店訂房、能源裝設、車商買賣及存讀檔／Ledger 平衡。Raw English audit 7 段皆為既有房仲人名；人工逐字比對設定，未翻譯 prose 0，原始 audit 沒有改寫。",
    "- 初次長等待 run 有 1 個 parcel_sort_game practice 失敗；保留 practice/walkthrough_result.json 與 log。Claude 基線普通／相同長等待和 final 大字／長等待重跑均 0 failures，沒有修改小遊戲，不能據此聲稱已修產品 bug。",
    "- 首次六產業 run 16 failures 是獨立 founder QA fixture 沒有授予實際 ch11/ch12 功能 gate；修正 fixture 後完整重跑 0 failures。先前並行 Web worker 因資源競爭中止，保留 parallel-aborted-results.json；不算通過，表中為串行最終結果。",
    "", "## 玩家觀察", "",
    "初玩自動化：看到第一份工作卡，按練習，依亮起的杯子／機器／收款完成工作。\n正式工作長等待沒有失去收入；錯杯有溫和提示並能重試。\n收款畫面及金額讓成果可辨識，能重看練習。\n熟練路線：重看／跳過可用，六產業存讀檔可延續營運。\n困惑仍有直式大字 HUD／Company OS 擁擠；自動化不能證明真人覺得好玩。", "",
    "實體手機／平板、實體 Safari、真人無外部指引盲測、真人十小時重玩仍 NOT VERIFIED。此環境未提供可操作的實體裝置／真人受測者；不把模擬 viewport 或 bot 當作這些證據。", "",
    "| F 原則 | 補充結果 |", "|---|---|",
    "| F1 | PASS 自動化首次練習、重看與跳過；真人盲測未驗證。 |",
    "| F2 | PASS 正常工作長等待與收入；沒有新增計時玩法。 |",
    "| F3 | PASS #178 未解鎖產業入口隱藏、已營運舊存檔仍可用。 |",
    "| F4 | PARTIAL #178 能源開業下一步清楚；Web 直式 Company OS 仍擁擠，#186。 |",
    "| F5 | N/A 本次沒有新增管理／自動化玩法。 |",
    "| F6 | PARTIAL 大字觸控功能可用，但直式部分文字截斷，#186。 |",
    "| F7 | PASS 溫和錯杯、重試、存讀檔／Ledger 與產業營運回歸。 |",
    "| F8 | PASS 本次出口／街景強調低調；PARTIAL Web 直式 HUD 提示擁擠，#186。 |", "",
    "[原生代表截圖](gallery/)；各 native tour 的 walkthrough_result、english_audit 和 log 一併保留。Protected Session I 路徑未改，玩法、經濟、存檔格式未改。",
]
(root / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print(json.dumps({k: summary[k] for k in ["web_cases", "chromium_pass", "webkit_pass", "pck_bytes", "pck_sha256"]}))
