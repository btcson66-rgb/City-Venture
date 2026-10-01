# #21 進貨取消與供應商退貨

基底：e6accdb，從最新 claude/exciting-bardeen-y71ixv fetch 後建立獨立分支 codex/21-po-returns。Godot 4.5.1，繁體中文 1280×720；測試使用隔離的 user://，不讀寫玩家存檔。

## 驗證

- unit_tests.log：全套單元測試，包含期限、預付款、未落地跨境付款、票期、合作社、部分退貨、預留庫存、平均成本、退貨排程存讀、公司歸屬、清算後不重複退款、進口限制及舊存檔。
- i18n.log：3011 msgids，missing 0。
- wiki_check.log：OK。
- walkthrough.log / walkthrough_result.json：完整繁中流程，包含第 2 章後以真實按鈕取消額外進貨單；0 failures。最後一行：`2475.5s [12月5日（週五） 下午 12:53] BOT FINISHED — 0 failure(s) · 2475.5s real`。
- return_ui_result.json：獨立退貨介面檢查，0 failures；經真實 −/+、ConfirmReturn 操作退 5 件，再核對排程到期收款。此短流程不代替完整 walkthrough。
- interaction_focus.log / interaction_focus_result.json：真實互動焦點建立同幀開啟說明彈窗，關閉後實際使用床鋪；0 failures。導航保留已確認的到達結果，按 E 前仍驗證正確焦點。
- english_audit.json 與 return_ui_english_audit.json 保留原始稽核；語言選項 English 等既有文字與識別碼逐項核對，新退款與取消文字都有繁中。

## 截圖

- purchase_cancel_confirmation / purchase_cancelled_operations：完整 walkthrough 的額外進貨與取消。
- 08_purchase_return_confirmation.png：可退數量、−/+、退款、手續費、運費、日期與確認按鈕，視窗依內容調整高度並置中。
- 09_purchase_return_pending.png：出庫後庫存減少，退款尚未入帳。
- 10_purchase_return_received.png：供應商收貨後退款入帳。

## 舊存檔與帳務

game/tests/fixtures/purchase_returns_pre21.json 是在未修改的 e6accdb 上以 SaveSystem.save_to() 產生的實際存檔。新欄位按需建立，沒有改名或刪除舊欄位。單元測試載入它、取消舊 PO 並核對總帳；另測新退貨排程存讀與公司開戶後的應收款原持有人。所有金錢移動經 Ledger。

## 待審查政策與分支衝突

跨鏈橋凍結中的款項目前不允許取消，介面明示須等橋恢復；一般 awaiting_payment 可立即退本金、已付結算費不退。凍結款項如何處理未在 #21 指定，請審查這項政策。沒有把凍結資產直接當成可用現金。

#36 同樣從 e6accdb 開始，尚未包含本分支；可能衝突：company_os.gd、walkthrough.gd、bot.gd、glossary.json、help.json、tools/i18n/zh_TW.json、game/i18n/*、GAME_DATA_SCHEMA.md、wiki/13_core_loop_and_work.md。合併時需保留兩邊新增內容。#37 決策視窗與教學綠色 ✓ 修正未修改。

最終全套單元測試：`243/243 tests passed in 19.5s`。
