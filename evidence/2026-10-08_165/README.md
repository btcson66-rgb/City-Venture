# #165：練習、週帳單與通知收尾

Base: `b00bb9b7` (#162 / #163 merged). Godot 4.5.1, native OpenGL, isolated QA saves.

## Before / after game-feel-review

| 原則 | 修改前 | 修改後／證據 |
|---|---|---|
| F1 | PARTIAL：熟手包裝被帶進練習；數字鍵無反應 | PASS in scope：六種舊活動可選練習；只有高亮控制的數字鍵生效；practice tour 保留新手首次教學、正式工作、領薪、重看、跳過 |
| F2 | PASS：預設輕鬆 | PASS：未新增計時；練習仍不计分、不改收入 |
| F3 | N/A | N/A：本張未改解鎖入口 |
| F4 | PARTIAL：成熟 Finance 很密 | PARTIAL：本張修預測，不重排 Finance；交 #164 |
| F5 | PASS：既有帳單助理 | PASS：手動帳單按保存的到期日預測；自動帳單按實際週出帳時點 |
| F6 | PARTIAL | PARTIAL：舊存檔開始卡少一行安全練習說明；Finance 密度由 #164 處理 |
| F7 | PARTIAL：獨立 save round-trip 依賴場景殘留 | PASS in scope：獨立設定 Riverside 場景；歷史 fixtures 六玩法不強制練習；重複遷移不覆寫已存選擇 |
| F8 | PASS in scope | PASS in scope：沿用安靜配色與既有觸控範圍 |

新手：先跟著高亮貨架按數字鍵；正確分揀後自然前進到破損包裹處理。練習沒有付款或評分副作用。既有完整 practice tour 從真實首次 barista 工作一路到領薪。

熟手：沒有完整歷史的舊存檔直接看開始卡；「先練習一次」和「?」仍可選。已做過的工作由保存紀錄補記，不清空選擇或產生收入。

## 截圖與量化

計數來自原生 Control 文本：字數為非換行字符數，數字以連續數字／小數為一組；包含可捲動內容，不能當成同時在 viewport 中可見的密度。步驟為該指定任務必要操作。

| 相同任務／狀態 | 步驟 前→後 | 字數 前→後 | 數字 前→後 |
|---|---:|---:|---:|
| 舊存檔開始包裝：跳過強制練習→開始／直接開始 | 2→1 | 75→60 | 0→0 |
| 分揀練習第一個高亮貨架 | 1→1 | 118→118 | 11→11 |
| Finance 預測內容（排除 QA 玩家姓名差異） | 1→1 | 864→864 | 107→107 |

數字鍵修改後的下一張畫面是破損包裹步驟，字數 88、數字 0；這是教學前進，不能宣稱同狀態密度下降。預測修正用到期日單元測試驗證，週彙總通常仍是一週七天的費用。

Desktop before/after: 1280×720 zh_TW。追加 after-mobile-en-large: 640×360 English、大字與觸控模式。已實際看過開始卡與鍵盤步驟；本張沒有 matching mobile before，亦未驗證實體手機。

## 重現與驗證

`--bot=cleanup --lang=zh_TW --out=<isolated>`；修改前加 `--cleanup-before`。`--bot=practice` 跑所有十八種課程（含 consulting 變體）與真實首次工作、薪水、重看、跳過。

驗證摘要與原始 log / JUnit 附於本資料夾；新文案英文稽核 0。修改前英文稽核的兩項是 QA 玩家名字 Cleanup Tour，非玩家文案。歷史 save fixture 全部載入、ledger 平衡；沒新增任何金錢交易。HUD 原先只顯示 Ledger 的真實現金，沒有另一套預測；Company OS / Cond 使用共同 Forecast。

共用檔案修改範圍：GameState / SaveSystem 只新增版本與可選練習遷移；UIRoot 移除退役 arrival 訂閱；Living 新增共享週出帳邊界。資源匯入設定、export presets、build-size、網頁 CI 均無修改。

Final checks: **988/988** unit tests (407.4 s), no GDScript runtime/parse errors; systems **14/14**, save **88/88**, cleanup **6/6**. Rendered cleanup + all practice lessons: **0 failures**, after zh_TW English audit **0**. i18n **8230/8230, missing 0**; wiki OK; beta **0 hits**; map adjacency OK; diff whitespace OK. Engine shutdown retains inherited RID/ObjectDB leak warnings. Self-review also fixed the formal packing layout fixture so it cannot silently abort inside automatic practice.
