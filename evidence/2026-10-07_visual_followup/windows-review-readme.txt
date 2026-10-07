CITY VENTURE — 美術修正測試包第二版 / PR #147
2026-10-07，原遊戲版本 0.2.1-beta 的美術修正分支。

解壓縮後執行 CityVenture.exe；PCK 已內嵌，不需安裝。
本包為 Windows x64。請確認使用這個第二版，舊的 art146 包沒有本輪修改。

本輪：固定首頁背景、延伸柏油與實際道路出口、打包桌內容尺寸與捲動、路牌向量箭頭與文字界限、參考圖共享人物頭髮/臉型/衣服、14 套服裝一致步態與原定染色、同臉六膚色、備援建築重疊、靜態庭園與街景植栽。

驗證：938/938 完整測試；最後庭園與牌面調整另 13/13 專項；40 條實際步行連線、打包流程零失敗；12 區 45 張街面巡查。Quadro RTX 4000 / 1280×720，獨立視窗 240 幀中位 16.660 ms、p95 16.978 ms。Windows 成品原生 120 幀啟動 exit 0。

紀錄：docs/qa/2026-10-07_art_followup.md 與 evidence/2026-10-07_visual_followup/。
原圖、精確 imagegen prompts、裁切 manifest：docs/art_sources/reference_character_20261006/。

本機試玩包 READY_FOR_REVIEW；Draft PR，未合併或公開發佈。低階電腦/Web/手機 GPU 尚未驗證。兩個上游大存檔解壓診斷保留，沒有修改存檔設計。
