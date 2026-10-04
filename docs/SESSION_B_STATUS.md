# Session B 工作總表

十六張已完成實作、自我審查與測試，全部維持 Draft PR，依下表順序合併。最新整合程式來源 50fa523a：676/676 單元測試（301.2 秒），市政第19–24章短版0失敗（89.3秒），跨公司招募／期權／月結短版0失敗（42.5秒）；無SCRIPT ERROR。i18n6605 missing0、wiki307 IDs OK、beta0。表內為各張最新全套測試數，重複包含共同測試，不能相加。

新存檔第1–24章完整 walkthrough 在f3618370完成：0失敗、3588步、403張原始擷取、8041.8秒，最後現金／時間／位置正常存讀檔通過。後段獨立產業採受控fixture，原獲利／交付／換匯斷言沒有降低。六次watchdog提示後均恢復，原始輸出保留。完整流程之後的跨公司歸屬、個別basis與月結捲動修正，另在50fa523a做上述全套及相關native複驗，不宣稱full跑在最終程式提交。

歷史失敗、無效市府捕獲與中止報告原樣保留，未列PASS。正常讀回原第13章自動存檔的接續另有0失敗／1505步／3797.9秒，包含實際換匯$855.40；這是分段接續，與新存檔full分開記錄。原始完成城市存檔的ZIP與SHA-256一致。

| 工單 | Draft PR | 全套測試數 | 自我審查修正 | 仍需注意 |
|---|---|---|---|---|
| #86 | [#102](https://github.com/btcson66-rgb/City-Venture/pull/102) | 471/471 | 存檔 fixture、共享教學、到期、翻譯與 OEM 報價；車商先決條件與方位漏譯 | 飯店以真實團體訂房代旺季；能源沿用補助對話 |
| #30 | [#103](https://github.com/btcson66-rgb/City-Venture/pull/103) | 481/481 | FX 隨機順序、退款對象、跨境時間；上游兩邊功能合併 | — |
| #31 | [#105](https://github.com/btcson66-rgb/City-Venture/pull/105) | 491/491 | 商品位置、實際售價、試營運與報關下一步；海關入口與暫停後價格恢復；實際住處補貨、季節性缺貨與價格恢復 | 保留早期失敗紀錄；full 修正後 0 失敗 |
| #70 | [#106](https://github.com/btcson66-rgb/City-Venture/pull/106) | 511/511；專項13/13 | L/C 時點、重複庫存、違約風險、FX 部門加總 | 三 seeds 不足以推論損失機率 |
| #42 | [#121](https://github.com/btcson66-rgb/City-Venture/pull/121) | 529/529 | 實際付款、關閉、股權/部門加總、拒絕報價冷卻；上游兩邊曝險、關閉與交付合併 | 旅程卡沿用素材；長期對比是明列模型 |
| #43 | [#122](https://github.com/btcson66-rgb/City-Venture/pull/122) | 548/548 | 重複出售、關閉事件、舊估值/款項與新公司隔離；已合併驗證前序修正 | 市占/90 天比較是模型 |
| #35 | [#124](https://github.com/btcson66-rgb/City-Venture/pull/124) | 556/556 | 實際產業、還款、月結、透支與跨公司成就；已合併驗證前序修正 | 圖示列美術 backlog |
| #92 | [#125](https://github.com/btcson66-rgb/City-Venture/pull/125) | 564/564 | 負淨值、工時、主按鈕、原局保存與測試槽隔離；已合併驗證前序修正 | 三策略為受控實際動作；舊工時不補造 |
| #93 | [#126](https://github.com/btcson66-rgb/City-Venture/pull/126) | 577/577 | 重開/套利、持股稀釋、路演選項、IPO 撤回 | #90 未合併，依授權採 NPC 公司 |
| #91 | [#130](https://github.com/btcson66-rgb/City-Venture/pull/130) | 594/594 | 公司狀態、歷史款項、內部成本、擔保/出售與倉儲權限；貨物與危機決策原公司歸屬、舊存檔遷移、實際改道費與關閉清理 | 合併報表未含完整會計準則的期間切割與商譽 |
| #32 | [#131](https://github.com/btcson66-rgb/City-Venture/pull/131) | 603/603 | 住處設備、退租權限、在途容量、現金不足恢復 | — |
| #94 | [#134](https://github.com/btcson66-rgb/City-Venture/pull/134) | 614/614 | 售價套利、欠租/利息、車輛位置與存檔 | 駕駛採路線與時間模型 |
| #33 | [#136](https://github.com/btcson66-rgb/City-Venture/pull/136) | 625/625 | 分店執照、豆數、清潔工時、檢查、成本/圖表 | 採購日認列食材成本；未估老闆機會成本 |
| #34 | [#138](https://github.com/btcson66-rgb/City-Venture/pull/138) | 634/634 | 車輛重複排程、維修寄貨、過期合約、磨損與分攤 | 逐車利潤按里程分攤；未估老闆機會成本 |
| #41 | [#140](https://github.com/btcson66-rgb/City-Venture/pull/140) | 645/645 | 返庫/租約/員工/車輛邊界；返家、銀行繞行、真實補貨、拒絕報價與管理畫面；真正個人資金救援 | ShopLane 比較不含線上運費與退貨 |
| #99 | [#144](https://github.com/btcson66-rgb/City-Venture/pull/144) | 676/676 | 缺團隊選項、城市政策/股權/成本；無效市府存檔拒絕與有效原始捕獲讀回；原公司期權/挖角、個別投資成本與三帳戶月結可點擊 | full 在 f3618370；後續修改另測；美術待製作、三 seeds 非機率推估 |

所有章節與支線均有已完成／已不可能的no-soft-lock覆蓋；舊存檔、公司關閉、跨公司與重複交易保留測試。費用、單價、帳目備註用Fmt.money，真假條件顯示✓／✗及下一步；真實帳務、危機消退、實際取捨與繁中文案均經自我審查。#93的#90依賴尚未合併，沿用授權NPC退路；#99已包含#86及#43。

證據為JPG，每章至少兩張，各工單資料夾低於20 MB，最大約6.1 MB。專用美術仍列art backlog。指定base最後fetch為f097b906；上游修正以merge向後整合、兩邊新增內容與功能保留、翻譯重抽取。沒有rebase、合併PR或發布；沒有實作Session A/C工單或更動原工作區美術。

完整來源／結果：[reviewed-final-source.json](evidence/99-city-future/reviewed-final-source.json)、[new-game-full-completed-source.json](evidence/99-city-future/new-game-full-completed-source.json)，原始輸出與存檔封存見同一證據目錄。
