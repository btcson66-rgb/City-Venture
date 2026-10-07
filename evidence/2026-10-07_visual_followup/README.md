# 美術第二輪驗證索引 — 2026-10-07

Issue #146、同一 Draft PR #147；前輪 2060c89c，基線 d4c47a6c。READY_FOR_REVIEW，沒有合併或公開發佈。

最終結果：
- accepted-v2/：參考圖重建後捏臉、三種外型 × 14 套服裝 × 三方向、六膚色世界/肖像一致性、打包桌與車道盡頭真實切換；checks.json 兩項 true。其中街面截圖早於最後庭園/北向窄路牌調整。
- frontage-delivery/：最終 12 區、45 張連續街面。使用凍結且隱藏角色的攝影 fixture，避免攝影位置誤觸出口；此為美術巡查，實際步行另見 walking_verified/。
- all-scenes-final/：12 區、Company OS 9 頁籤 × 中英文、最大字型/UI、對話。邊界全部 true；此輪附帶幀資料有同時 CPU 測試，效能結論只用下一項。
- native-performance-final/：所有其他 Godot 程序結束後的獨立原生視窗。240 幀、p50 16.660 ms、p95 16.978 ms、max 18.182 ms，391,042,524 bytes 材質快取。
- walking_verified/：40 條有向連線、130 步、零失敗與漏翻；packing/：實際中型/大型裝箱、封箱、寄送、退款零失敗。
- stress-final/：三日、5000 訂單/日、50 員工、兩公司、全產業、1901 紋理請求，short 預算零失敗；不是 Web 長期驗收。
- unit-final.xml 和 raw/followup-unit-final.log：938/938、357.6 秒；最後純景觀/北向牌調整之後的專項 13/13 見 raw/followup-layout-delivery.log。
- raw/followup-export-delivery.log、raw/followup-packaged-delivery.log、package_receipt.json：最終匯出、120 幀原生啟動 exit 0 與 exe 雜湊。
- raw/followup-hair-pose.log：所有服裝/外型/方向/姿勢的共用人物合成檢查通過；hair-crop-review.png 是 24 個方向裁切目視檢查。

initial/、final/、review/、verified/、accepted/、frontage-final/、frontage-verified/ 與其他日誌保留中途畫面和失敗。不要將這些舊圖當最終結果，或刪除初次步行/路牌檢查失敗。

重跑用專案 Godot 4.5.1：probe.tscn 的 --followup、--frontage-only、--perf-only 與 --out=<絕對證據目錄>。單元測試 res://tests/test_runner.tscn；專項 --filter=test_visual_layout。打包/步行為 --bot=packing / --bot=map_adjacency。原圖、精確 imagegen prompts 和 crop manifest 在 docs/art_sources/reference_character_20261006/。

根因與防止再犯：docs/qa/2026-10-07_art_followup.md。低階/Web/手機 GPU 未驗證，兩個上游大存檔 Decompression failed 診斷保留。主觀品質仍待玩家試玩。

GitHub 交付核對：delivery_verification.json 記錄來源 ff607b44 的 6 項 CI 全部 SUCCESS、ZIP 與 exe SHA256；windows-review-manifest.json 與 windows-review-readme.txt 保存實際測試包內的版本與說明。
