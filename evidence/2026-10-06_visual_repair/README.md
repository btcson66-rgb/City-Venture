# 美術修正驗證索引（2026-10-06，Issue #146）

基線：d4c47a6c7b737debebd0081fedb4c835a6a8f154。分支：codex/visual-repair-20261006。

- before/：新版未修正的五個原生畫面。
- after/：修正中途畫面；final/：角色、所有城市區域、Company OS 中英文頁籤及最大 UI/字型的原生畫面與邊界檢查。
- tour/：80 張實際流程巡覽，walkthrough_result.json 記錄 90 步，零流程失敗；english_audit.json 無漏翻。原始巡覽截圖位於 tour/screenshots/，audit_contact 圖為檢視用縮圖。
- walking/：40 條有向城市連線實際步行，130 步、零流程失敗。首次巡覽的一個 daily 漏翻保留在紀錄，修正後另以執行期測試驗證。
- native-performance/：獨立原生視窗、暖機後 240 個牆鐘幀時間，p50 16.646 ms、p95 16.971 ms、max 17.588 ms。硬體 Quadro RTX 4000 / Godot 4.5.1 / 1280×720；不能推論低階或 Web。
- stress/：三日、每日 5000 訂單、50 員工、兩公司、所有產業；短期檢查零失敗，保存合成測試存檔。
- raw/：包含初次失敗、修復後測試、匯入、匯出及原生 exe 啟動記錄。不可把初次失敗當作最終結果，也不可抹除中途失敗。

## 可重跑指令

於 repository 根目錄，用 Godot 4.5.1 執行：

```powershell
python tools/art/custom_character_vectors.py
node tools/art/render_custom_character.cjs
python tools/qa/pose_check.py
Godot --headless --path game --editor --import --quit
Godot --headless --path game res://tests/test_runner.tscn
Godot --path game res://tests/visual_repair/probe.tscn -- --out=<絕對證據目錄>
Godot --path game res://tests/visual_repair/probe.tscn -- --perf-only --out=<絕對證據目錄>
Godot --headless --path game --export-release 'Windows Desktop' ../build/review146/CityVenture.exe
```

其餘巡覽與壓測以 raw 日誌和專案既有 QA 指令為準。圖層源與輸出一併提交，CI 加入包含走路的 pose_check；新版版面與日常營業時間檢查自動納入 unit runner。

完整原因分析：docs/qa/2026-10-06_art_regression.md。交付狀態 READY_FOR_REVIEW；不代表玩家已接受主觀美術品質，也未合併、發佈或上架。大資料存檔測試會輸出兩個上游 Decompression failed 診斷，斷言通過與無錯誤輸出須分開看待。
