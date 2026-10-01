# #52 貸款入口與資格清單 — 2026-10-01

從最新基底 `cacf0b5f750e1a65fcd6f967f531e38499b7b239` 開立 `codex/52-loan-access`。使用 Godot 4.5.1；QA 存檔使用獨立目錄，測試用 override 不納入交件或打包。

## 驗證

- 單元測試末行：`265/265 tests passed in 16.3s`（unit.log）。六種資格各有失敗案例、合約替代條件、禁貸界線、原額度權重／千元取整／上限、櫃台會面、預約存讀檔、不可借款介面及當日下午簽約皆涵蓋；複式簿記保持平衡。
- 完整繁中 walkthrough 末行：`2796.8s [12月4日（週四） 下午 12:54] BOT FINISHED — 0 failure(s) · 2796.8s real`；walkthrough_result.json：0 失敗、224 張原始截圖。原始全流程截圖保留在本機 QA 輸出，本資料夾只收錄工單相關 JPG。
- 貸款操作 tour：繁中、簡中均 0 失敗（loan_access_* 報告）。實際點擊宣傳冊導航、走到常設貸款牌、預約、手機任務、Marcus 拒貸對話、櫃台開戶、會面、取消與確認簽約。取消時金額與時間不變；確認後當日 17:00 結束，首期仍於 30 天後，尚未扣款；確認框依翻譯內容自動調整高度。
- 語言稽核完整輸出有 31 項：既有語言選項、人員／客戶姓名、SHOPLANE 品牌與 AUR 登記字號；見 english_audit.json 及逐項核對的 english_audit_review.json，本工單新增文字漏譯 0；貸款繁中／簡中 tour 各只有既有語言選項 `English`，沒有本工單新增文字漏譯。
- `python3 tools/i18n_extract.py --check`：missing 0；使用 opencc-python-reimplemented 產生 zh_CN。
- `python3 tools/wiki_check.py`：OK（3830 assets、191 data ids）。
- `bash tools/package_release.sh` 成功產生 Windows、Linux、macOS、Web 四包；package.log 與 package-SHA256SUMS.txt 記錄輸出。套件位於本機 dist/，沒有提交到 repo。
- 舊存檔：實際載入既有 `contracts_before_closure_pre36.json`，新資格清單可讀、原帳本與合約未改動。貸款與存檔欄位不刪改；新 appointment 欄位只在預約時建立，缺省代表沒有預約。

## 測試方式與範圍

完整 walkthrough 不跳章，走原有遊戲操作。短 tour 使用新存檔；為隔離貸款介面回歸，交通位置、14 天公司歷史和 $6,000 庫存帳值採 fixture；它不是經濟平衡驗收。登記／正常經營／故事融資由完整 walkthrough 覆蓋。短 tour 的開戶、會面、預約、對話與借款均走真實輸入。執行：`godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=walkthrough --lang=zh_TW --from=loan_access --out=<獨立輸出目錄>`，簡中改 `--lang=zh_CN`。

畫面沿用既有海軍藍面板、字型與配色；經理桌旁資訊架重用現有 brochure 素材，沒有改 game/assets/ 或 tools/art/。

## 截圖（JPG 品質 85）

| 檔案 | 證據 |
|---|---|
| 08_loan_ineligible_top.jpg | 不合格清單：條件、目前值、門檻、差額與辦理地點 |
| 09_loan_ineligible_formula.jpg | 額度條件與完整五項公式、毛利差額建議 |
| 10_loan_permanent_manager_sign.jpg | 經理桌旁可見資訊架、永久互動與值班時段 |
| 11_loan_marcus_off_duty.jpg | 非值班時可預約，顯示日期與辦理地點 |
| 12_loan_phone_reminder.jpg | 手機任務保留預約提醒 |
| 13_loan_signing_confirmation.jpg | 動態高度確認框，事前說明時間成本及首期日期 |
| 14_loan_success_today.jpg | 當日 17:00 入帳、貸款餘額與 30 天後首期 |
| zh_CN_signing_confirmation.jpg | 簡中確認文字與可見按鈕 |
