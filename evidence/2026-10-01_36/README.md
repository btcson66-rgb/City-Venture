# #36 公司關閉後的合約與收款

基底：e6accdb，從最新 claude/exciting-bardeen-y71ixv fetch 後建立獨立分支 codex/36-contract-closure。規則採 issue #36 的擁有者留言。Godot 4.5.1，繁體中文 1280×720；測試使用隔離的 user://。

## 驗證

- unit_tests.log：234/234 通過；關閉前的應收款只以 80% 清算一次，跨過付款日不再入帳；舊合約不能耗用新公司存貨，防呆與畫面原因皆驗證。
- i18n.log：2971 msgids，missing 0；wiki_check.log：OK。
- walkthrough.log / walkthrough_result.json：完整繁中流程；0 failures。最後一行：`2386.2s [12月4日（週四） 下午 12:53] BOT FINISHED — 0 failure(s) · 2386.2s real`。
- closure_ui_result.json：獨立介面檢查 0 failures。真實 CloseCompany、StartOver 操作，再以新公司重開合約頁核對舊合約三種終態與停用交貨。短流程不代替完整 walkthrough。
- interaction_focus.log / interaction_focus_result.json：彈窗打斷真實互動焦點的回歸檢查，0 failures；同時保持操作前正確焦點驗證。
- english_audit.json 與 closure_ui_english_audit.json 保留原始稽核。既有 English 語言選項與 AUR 公司登記碼保留；新增終態、原因與歷史說明都有繁中。

## 截圖

- 08_live_invoice_before_closure.png：清算前已交貨、尚未收款的發票。
- 09_contract_closure_statement.png：真實關閉公司的清算報表，應收款 80% 回收。
- 10_closed_contract_withdrawn.png：未回覆報價撤回。
- 11_closed_contract_terminated.png：未交貨合約終止，不另外罰款。
- 12_closed_contract_sold_to_collector.png：發票隨清算售予催收公司，不能再交貨或收款。

## 舊存檔

game/tests/fixtures/contracts_before_closure_pre36.json 與 contracts_closed_pre36.json 均由未修改的 e6accdb 以 SaveSystem.save_to() 產生。前者測試讀回後安全清算；後者保留舊版已清算卻仍有未終止合約與排程的狀態。讀回只修正終態、故事決定旗標及 con.* 排程，原總帳保持不變，不重跑清算。再次 reconcile 不重複歷史；不捏造 delivered / paid。

## 分支衝突

#21 尚未合併，本分支從最新基底開始，沒有串接未合併分支。可能衝突：company_os.gd、walkthrough.gd、bot.gd、glossary.json、help.json、tools/i18n/zh_TW.json、game/i18n/*、GAME_DATA_SCHEMA.md、wiki/13_core_loop_and_work.md。合併時保留兩邊的新功能與翻譯。#37 決策視窗與教學綠色 ✓ 修正未修改。

最終全套單元測試：`234/234 tests passed in 19.7s`。
