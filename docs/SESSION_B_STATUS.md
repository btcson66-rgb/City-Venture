# Session B 工作總表（最終完整驗證尚未通過）

依序完成各工單的實作與專項測試；十五張 PR 維持 Draft。#99 尚未開 PR，等待上一張整合 gate 通過。以下測試數為各工單當時的完整 suite，不可相加；最新整合 suite 為 667/667（220.1 秒），i18n 6603 missing 0、wiki 307 OK、beta 0。

新全流程 70a0bdd5 完成第1–24章：2 失敗、3418 steps、403 captures、8021.9 秒，無 SCRIPT ERROR。兩項為第7章真正月利潤 -$826.09；其餘功能斷言通過。f5e3c75a 修正版以實際 PriceUp 輸入應對1.8倍運費，兩項獲利斷言完整保留，正在重新驗證。不能把歷史失敗或尚在執行的流程標成 PASS。

| 工單 | Draft PR | 測試數 | 自我審查修正 | 仍需注意 |
|---|---|---|---|---|
| #86 | [102](https://github.com/btcson66-rgb/City-Venture/pull/102) | 471/471 | 存檔 fixture、共享教學、到期、翻譯與 OEM 報價；車商先决條件與方位漏譯 | 飯店以真實團體訂房代旺季；能源沿用補助對話 |
| #30 | [103](https://github.com/btcson66-rgb/City-Venture/pull/103) | 285/285 | FX 隨機順序、退款對象、跨境時間 | 早期 beta/full gate 由整合尾端重新驗證 |
| #31 | [105](https://github.com/btcson66-rgb/City-Venture/pull/105) | 295/295 | 商品位置、實際售價、試營運與報關下一步 | 舊完整 tour 63 失敗；整合回歸另列 |
| #70 | [106](https://github.com/btcson66-rgb/City-Venture/pull/106) | 510/510；最終專項13/13 | L/C 時點、重複庫存、違約風險、FX 部門加總 | 三 seeds 不推論損失機率；原始完整 gate 待收尾 |
| #42 | [121](https://github.com/btcson66-rgb/City-Venture/pull/121) | 503/503；後續專項18/18 | 實際付款、關閉、股權/部門加總、拒絕報價冷卻 | 旅程卡沿用素材；長期對比是明列模型 |
| #43 | [122](https://github.com/btcson66-rgb/City-Venture/pull/122) | 522/522 | 重複出售、關閉事件、舊估值/款項與新公司隔離 | 市占/90 天比較是模型 |
| #35 | [124](https://github.com/btcson66-rgb/City-Venture/pull/124) | 530/530 | 實際產業、還款、月結、透支與跨公司成就 | 圖示列美術 backlog |
| #92 | [125](https://github.com/btcson66-rgb/City-Venture/pull/125) | 538/538；後續專項8/8 | 負淨值、工時、主按鈕、原局保存與測試槽隔離 | 三策略為受控實際動作；舊工時不補造 |
| #93 | [126](https://github.com/btcson66-rgb/City-Venture/pull/126) | 551/551 | 重開/套利、持股稀釋、路演選項、IPO 撤回 | 依授權用 NPC 公司；舊完整 tour 58 失敗 |
| #91 | [130](https://github.com/btcson66-rgb/City-Venture/pull/130) | 563/563；專項12/12 | 公司狀態、歷史款項、內部成本、擔保/出售與倉儲權限 | 合併報表未含完整會計準則的期間切割與商譽 |
| #32 | [131](https://github.com/btcson66-rgb/City-Venture/pull/131) | 572/572 | 住處設備、退租權限、在途容量、現金不足恢復 | 原始 full gate 待整合驗證 |
| #94 | [134](https://github.com/btcson66-rgb/City-Venture/pull/134) | 583/583 | 售價套利、欠租/利息、車輛位置與存檔 | 駕駛為路線/時間模型；旧 full 無完成結果 |
| #33 | [136](https://github.com/btcson66-rgb/City-Venture/pull/136) | 594/594 | 分店執照、豆數、清潔工時、檢查、成本/圖表 | 採購日認列食材成本；未估老闆機會成本 |
| #34 | [138](https://github.com/btcson66-rgb/City-Venture/pull/138) | 603/603 | 車輛重複排程、維修寄貨、過期合約、磨損與分攤 | 逐車利潤按里程分攤；未估老闆機會成本 |
| #41 | [140](https://github.com/btcson66-rgb/City-Venture/pull/140) | 640/640 | 返庫/租約/員工/車輛邊界；返家、銀行繞行、真實補貨、拒絕報價與管理畫面；真正個人資金救援 | 真實第17–18章接續0失敗；新全流程僅第7章兩個獲利斷言失敗，修正版重跑中 |
| #99 | 待完整 gate 通過 | 667/667；專項27/27 | 缺團隊選項、城市政策/股權/成本；無效市府存檔拒絕與有效原始捕獲讀回 | 最後完整驗證重跑中；專用素材列 backlog |

所有章節與支線均有已完成／不可能繼續的 no-soft-lock 覆蓋；舊存檔、公司關閉、跨公司與重複交易邊界保留測試。#93 使用授權的 NPC 公司退路。專用美術列 backlog。未修改 Session A 工單；沒有合併 PR、rebase 或發布。個別證據資料夾均低於20 MB，圖片皆 JPG。
