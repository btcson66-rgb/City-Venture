# #22 存檔攜帶、自動備份與歷史回歸

## 規格對照

- 暫停與讀檔清單：ExportSave / ImportSave、save_export 說明，英文與繁中皆實際操作。
- 桌面檔案選擇：真實輸入 Enter 確認匯出；開另一局後，以檔案視窗匯入並繼續原玩家／現金／帳本。
- Web：Chromium 真實滑鼠點擊下載、FileReader 選檔、匯入後重新整理讀回 IndexedDB，另載入真正 0.1.8 舊檔。
- 驗證：完整核心結構、版本、有限數值、帳本平衡及餘額一致；驗證成功後才遷移、寫入空槽。
- 全槽滿：選擇槽、確認取代、先備份；關閉選擇會清掉待匯入資料。
- 備份：主檔之外保留最近三份；損壞時恢復最近可用備份並保留損壞原檔。
- 失敗：無效 JSON、未來版本、損壞資料、備份失敗、寫入失敗皆保留原主檔位元組。
- 真實 0.1.5／0.1.6／0.1.7／0.1.8 第三章存檔：每份載入、故事檢查、推進三天、帳本平衡、Company OS 全分頁。
- docs/CODEX_GUIDE、SAVE_TRANSFER、fixture README 已記錄每次發版補真實存檔與來源。

## 自我審查修正

原先備份以搬移方式讓主檔短暫消失，改為先複製、完成暫存檔後 rename。補上備份失敗不覆蓋、損壞內部訂單／位置／entity 拒絕匯入、取消選擇清理、Web callback 完成後釋放。實看檔案選擇視窗後修正內建英文標籤、CJK 標題字型、儲存提示與旧檔教學 Skip 的語言初始化問題。

新畫面皆看過：無破圖或溢出；金額為 Fmt.money0、天數有單位；主要操作可立即執行。繁中 audit 的新畫面紀錄僅測試自訂玩家名 Save Traveler／Another Game 與語言選項 English，並非漏翻。完整 walkthrough 的既有 audit 另保留原始輸出，不以文字偵測數當作視覺驗收。

Web QA 匯出只額外包含測試腳本以執行相同遊戲程式；正式四平台包仍排除 tests。僅 localhost 驗收，未上傳 itch.io。瀏覽器測試涵蓋 Chromium；未聲稱已驗證所有瀏覽器或 macOS/Linux 實機。

最終測試結果與時間見附帶原始 log、JUnit、result.json；歷史來源 commit 見 fixture README，雜湊见 historical_sources.json。所有截圖 JPG，整份證據低於 20 MB。
