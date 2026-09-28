# R7 小修正（2026-09-29）

## 改動

- 七棟有文字的建築招牌寬度增至工單下限，文字素底與 metadata 同步。三棟無名稱建築改為入口雨遮或門牌，`sign` 設為 `null`。
- 中央車站的地圖補丁由實際 `board_extra.metro.label` 座標產生；世界地圖左下角過時標語與空白補丁以周圍海面補去。
- 四張地點卡改為有透視、材質和圖示的菜單、白板、市徽、布旗；城市地圖預覽同步更新。
- 銀行／市政用大理石地板的過大紋路淡化，稍增石材對比。
- 咖啡師圍裙、市政職員背心改為可染色灰階布料，原色襯衫、名牌及其他細節放在不染色圖層；走路與五種姿勢都有對應圖層。

## 驗收

- `python tools/qa/map_label_check.py`: `OK`
- `python tools/qa/pose_check.py`: `OK`
- `python tools/wiki_check.py`: `OK`
- Godot 4.5.1 匯入：成功
- Godot 測試：67/67；截圖巡禮：28 張、0 failure

`cards_comparison.png` 與四張建築對照圖是修正前後的素材截圖。`shots/screenshots/` 是修正後的完整實機巡禮，`tests.txt` 和 `shots.txt` 保留執行記錄。

## 接線與剩餘事項

現有角色分層載入器會自動讀取 `_top_detail` 和頭像 `_detail`。要讓 NPC 穿上不同色圍裙／背心，Claude 線可於角色資料提供 `outfit_tints.top`；本批未修改遊戲資料或程式。可出租樓層的公司招牌若非常長，仍由既有的文字縮放邏輯處理。
