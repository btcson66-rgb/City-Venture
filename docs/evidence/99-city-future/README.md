# #99 城市的未來 — 驗證證據

第三季六章各四個 StoryEngine 步驟。Native tour 使用已具第二季資格的隔離公司 fixture；採購、供應商付款/交付/失敗、六個決策、六張 Legacy 卡與企業 Legacy 接續都走真正畫面。等待以 Clock 加速，每個模擬小時仍執行正常系統；未捏造服務交付或收入。

- 第三季完整短版 tour：0 failures、134 steps、34 screenshots、89.3 秒。另外同提交家中 Company OS 路徑 **0 failures、161 steps、34 screenshots、125.3 秒**，確認不改寫先前企業結局。每章附三張 JPG（採購預算、決策、成果），另有六張成果卡與 Legacy 接續。
- 專項單元測試 27/27；包含六章 already-done / impossible、舊存檔無效果、實際存讀檔、公司關閉、公共合作、重複付款/選擇防護、禁止行賄、調薪/文化/導師時間、選擇權歸屬/離職失效與股權守恆、真正補助/建案工期/房產稅、危機逐步消退、零品質與無交付不得退款、過期不得付保證費、返回世界清除底層 Company OS。
- 修正前完整單元測試 **665/665，213.0 秒**；沒有 SCRIPT ERROR。新增真正市府存檔讀回測試後，666/666 完整測試通過（226.5 秒），沒有 SCRIPT ERROR。新增已完成原始捕獲檔的讀回測試後，再跑 667 項完整測試。
- 翻譯 6594/6594，missing 0；wiki_check OK（307 data IDs）；beta_audit 0 hits。English audit 五筆為公司名、語言選單、beta 版本、既有 NPC 稱謂與 Legacy 名稱；新增服務、費用、單位與下一步均已翻譯。
- 120 天三策略、三 seeds、九次真實交易：全部六章完成、每次六個決策、帳目平衡、Segments 與公司營運利潤吻合。保守平均 -$2,659.54，一般 +$4,048.07，激進 -$29,127.84。一般也有真正貨損/信用損失且每次有負數壓力情境報價，三個 seed 不足以推論獲利機率。
- JPG evidence 與報告約 1.7 MB，低於 20 MB；不修改 assets。

自我審查修正：無公司團隊時補第二個實際人才選項；將調整值移入 JSON；都市計畫只影響建案而非租金；UI 閱讀選擇權不會偷投董事會票；供應商失敗改顯示可繼續的實際下一步；未使用材料退回真正已付成本、避免虛構收入或重複退款；失敗低規格提案品質限定 0–100%；補上城市桌的現有圖示映射；抽取服務與單字單位避免 missing 0 卻漏譯。

整個 Session B 完整 walkthrough 仍由 #41 的最新隔離程序執行，尚未完成，不宣稱 PASS。前兩次 full 失敗的紀錄仍保留於 #41；修正後的各短版 regression 已通過。#99 Draft PR 等前張最終自我審查完成才開。

素材限制：博覽會場館、重建後港口與選舉海報是 art backlog 項目；功能以既有 City Hall、Harbor 與職業角色素材接入。政策目前對現有房產稅、能源補助、建案期限生效，不額外新增公司所得稅或重寫租金。

實際遊玩存檔讀回抓到市府實體缺少既有存檔必要欄位 `id` 與 `bank_account`。源提交 704fc55c 的原始捕獲 `game/tests/fixtures/saves/city_future_704fc55c.json` 雖然 tour 畫面通過，**讀回無效**；保留未改動原檔作為拒絕無效存檔的回歸 fixture，不能視為有效版本存檔。先前滿槽與新遊戲攔截也涉及這些無效城市存檔，撤回「僅因滿槽測試資料」的歸因。已補齊市府實體欄位並通過實際採購存讀檔測試；修正提交對應的六章遊玩捕獲與讀回驗證尚待完成。

修正後有效捕獲：源提交 `4a5319d5a13f760284aeffeb81dce8f5290f1ad3`，原始檔 `game/tests/fixtures/saves/city_future_4a5319d5.json`。六章 Company OS tour **0 failures、162 steps、34 screenshots、125.1 秒**，沒有 SCRIPT ERROR，並新增正常匯入驗證檢查。27/27 專項測試再以正常 SaveSystem.load_data 讀回同一檔案，確認六章完成、六卡已閱讀、企業 independent 結局、實際採購收據、帳目平衡與重複 reconciliation 不重新付款。Hash 與來源見 valid-played-save-source.json；先前無效原檔保留為負向回歸。
