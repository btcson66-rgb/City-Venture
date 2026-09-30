# #24 防卡關交件證據

分支：`codex/24-no-softlocks`；起始基底：`89e6ac0`，交件基底更新為 `93deb2c`（claude/exciting-bardeen-y71ixv）。Godot 4.5.1、Windows、OpenGL 相容渲染、1280×720、繁中。

## 修正

- 55 個主線 objective 啟動即檢查；從第一個未完成項接續，已完成整章的結束動作只執行一次。
- 保留提前做完的預測、調價、上架與退貨收據；新聞用年代收據，舊存檔遷移不跨年。
- 拒絕／撤回／過期合約仍前進；簽約公司關閉後明說原交易失效，故事不再等交貨或收款。
- 第 6 章兩個負現金月結可以前進，明說未恢復；第 7 章既有兩個虧損月份路徑不再假稱獲利。
- 18 步教學提前完成會連續跳過；日票過期改用家中電腦，離職／下架顯示補救文字與箭頭，第一單失效排程可重試。
- 長決策內容改為捲動，避免第 11 章決策／結果確認按鈕落到畫面外；確認按鈕有穩定名稱 `DecisionOK`。
- 合約拒絕／撤回／過期使用失效訊息，不跳出未實際備貨／交貨的成功提示。
- Pier 7 舊布局的貨架覆蓋門口出生點。基底 `98ef0fc` 已重新配置港區家具，本 PR 採用該布局、不另改 building 資料；新增所有室內出生點的碰撞間距回歸檢查。

本批於 2026-09-30 開始，驗證延續至 2026-10-01；沿用開始日期的證據目錄。

完整主線是在 `d1fc3dc` 基底上跑到 0 failures；交件時基底新增 `93deb2c` 的同一長決策修正，已同步。衝突保留本分支已完整驗證的固定 180px 捲動區，並採納基底三個以上選項時的較小圖片尺寸；同步後再跑全部單元測試與繁中補救截圖測試。故事、融資與付款程式沒有更動。

逐項三問稽核表在 [AUDIT.md](AUDIT.md)，亦完整貼入 Draft PR。

## 驗證

- `unit.log`：`226/226 tests passed in 16.3s`；沒有 SCRIPT ERROR / ERROR / FAIL。
- `python tools/i18n_extract.py`：missing 0；Windows 來源路徑正規化後正確排除測試文字，已再產生三份 gettext catalog。
- `python tools/wiki_check.py`：`wiki_check: OK (1613 assets, 191 data ids)`。
- `recovery/walkthrough_result.json`：6 個補救情境、7 張截圖，`BOT FINISHED — 0 failure(s) · 18.3s real`；`recovery/english_audit.json`：0 英文缺漏。
- `endgame-check/`：獨立 QA 存檔、`--from=ch10` 快速檢查，`BOT FINISHED — 0 failure(s) · 404.7s real`。前九章使用既有測試 fixture，這份結果只驗證第 10–12 章，不代替完整 walkthrough。英文稽核 18 項為 PO／KYC 識別碼、公司與語言名稱；本次新增句子 0 項。
- `full-walkthrough/`：`BOT FINISHED — 0 failure(s) · 2520.7s real`；從 New Game 完整執行，218 張原始截圖（repo 保留投資、決策結果、結局與讀檔畫面），1649 筆步驟紀錄，結尾確認 55/55 主線目標、帳務平衡及存檔讀回。
- `full-walkthrough/english_audit.json`：54 項，已逐項核對，只有 Ben Tan／Hana Wu 人名、English 語言名、ShopLane／Lantern Books 品牌，以及 PO／AUR／KYC 識別文字。本次新增文字沒有漏翻，原始稽核未過濾或刪除。
- `full-walkthrough/financing_receipt.json` 與投資截圖：記錄實際投資決策及帳本的 $40,000 股權入帳；完整日誌沒有人工補資金。
- 首次完整測試在第 8 章失敗並中止：`failed-attempt/walkthrough_log.txt` 與截圖記錄機器人 10 月 2 日上架，但貨單預定 10 月 4 日到貨。早期將 8 次兩小時等待改為 40；更新基底後採用基底的 8 次逐日睡眠，保留新增的到貨斷言；未修改交期或玩家資金。
- 第二次在第 8 章上架已通過，但週一 07:59 嘗試進入 09:00 才開門的市政廳：`failed-attempt-2/` 保留記錄。機器人補上 09:00–15:00 的出發條件，未更改營業時間。
- 同時靜態檢查後續等待：第 9 章多週進口的 30 次等待改為逐日睡眠（與第 10–12 章相同）；沒有改交期或結算結果。
- 第三次已通過第 8 章與 Lina 對話，但一次睡眠點擊未生效，機器人走路在阻擋視窗下沒有計算逾時而停住：`failed-attempt-3/` 保留日誌與僅此遊戲視窗的診斷截圖。測試端改為最多三次睡眠輸入及持續計算走路逾時，沒有用手動輸入接續該輪。
- 第 10–12 章快速檢查發現第 11 章長決策結果的 OK 在畫面外，`failed-endgame/` 保存記錄。決策捲動與確認可見性修正有單元測試及繁中實際輸入截圖測試。
- 另一次完整測試在港區租約後出門失敗：`failed-harbor/` 保存原貨架堵門畫面與連鎖失敗。早期曾移開兩座底排貨架，更新到 `d1fc3dc` 後改採基底的新布局，並保留碰撞回歸檢查及完整重跑。
- `harbor-check/`：買車、租倉、離開倉庫、送貨及存檔讀回，`BOT FINISHED — 0 failure(s) · 161.2s real`。`--from=harbor` 的前九章使用 fixture，只驗證港區，不代替完整主線；英文稽核 2 項為 English 語言名與 AUR 登記字號。
- 跳章 fixture 沒有前九章的上架／銷售收入；將港區與最後三章串跑時，公司現金不足申請費，所以將港區檢查限定於物流流程，後續資金以完整主線驗證，不將該輪當成成功。
- 完整流程下一輪在第 11 章資金不足：`failed-financing/` 保留付款畫面與首次失敗日誌。原 bot 拒絕 Elena 的投資並在港區前人工補資金；現改為實際點選既有投資選項（$40,000 換 20% 股權），移除人工補資金。價格、股份比例、利率及玩法規則均保留，重新從 New Game 驗證。
- 舊存檔：保留 SAVE_FORMAT 1、所有既有欄位與教學版本／步驟索引；有存檔讀取、年代收據、合約狀態重建與 unread-era save/load 回歸測試。

## 補救情境截圖

| 圖 | 顯示內容 |
|---|---|
| recovery/screenshots/01_quit_job_recovery.png | 尚未做班就離職：繁中教學叫玩家重新應徵，箭頭指向出口，再往 Bloom Coffee |
| recovery/screenshots/02_paused_listing_recovery.png | 第一單前下架：教學叫玩家到 Sales 重新上架；必要時到 Operations 補貨 |
| recovery/screenshots/03_early_forecast_next_chapter.png | 提前看過預測：直接完成第 4 章，進入第 5 章 |
| recovery/screenshots/04_negative_cash_honest_message.png | 現金仍為負卻可接續：Maya 明說還沒恢復，不假稱成功 |
| recovery/screenshots/05_long_decision_scroll.png | 長決策放在捲動內容中，視窗維持在畫面內 |
| recovery/screenshots/06_decision_outcome_reachable.png | 結果確認按鈕完整可見，機器人點擊後實際關閉 |
| recovery/screenshots/07_declined_contract_honest_message.png | 合約未成仍可接續，訊息不假稱已備貨／交貨 |

## 範圍及後續

沒有修改美術素材、價格或存檔格式，沒有新增畫面／商業概念（glossary、help card 無新增適用項）；既有決策確認按鈕補穩定名稱。原工作樹保持在原美術分支。

公司關閉後的實際合約清算與收款排程另列 [#36](https://github.com/btcson66-rgb/City-Venture/issues/36)，只有靜態發現，尚未在本 PR 修正或重現。數值經濟可達性留給 #29。

可能與後續 #21、#22、#25、#29、#30–#35 衝突的共同檔案：`chapters.json`、`save_system.gd`、`contracts.gd`、`story_engine.gd`、`tutorial.gd`、`walkthrough.gd`、`tools/i18n/zh_TW.json` 及產生的 `.po/.pot`。下一張 #21 等 #24 審查合併後再從最新基底開。
