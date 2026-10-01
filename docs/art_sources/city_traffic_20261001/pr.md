街道車流原本仍顯示簡單的方塊車窗與輪圈。這批替換轎車、掀背小車、計程車、廂型車、公車、轎車與小車前後視圖及入城列車，延續原參考圖的藍灰玻璃、左上光源及可染色白色車身。舊檔名和邏輯尺寸全部保持不變；交 56 個原尺寸／4× PNG 及 import，含獨立 emission-only 燈層。沒有改 scripts、data、tests。

起點：pull 最新 `claude/exciting-bardeen-y71ixv`，`a57c87a9`。角色品質 PR #46 保持獨立；本批没有將角色分支混入。

實機證據：`evidence/20261001_city_traffic/before/screenshots`、`after/screenshots`、`comparison_*.png`。每套 53 張截圖；隨機車流位置略有差異。素材染色技術預覽另列 `vehicle_tint_gallery.png`，不冒充實機畫面。原圖、提示詞、裁切、SHA-256 與全遊戲未驗收項目盤點在 `docs/art_sources/city_traffic_20261001/`。

驗證：
- Godot 4.5.1 headless import：exit 0，無錯誤。
- `228/228 tests passed in 16.8s`
- `BOT FINISHED — 0 failure(s) · 50.7s real`，53 張、63 步；English audit 0。
- `wiki_check: OK (1650 assets, 191 data ids)`
- `traffic_art_check: 56 PNG/import pairs; unchanged existing footprints; neutral tint layers; emission-only masks: OK`
- 本批不動角色與地圖，pose_check / map_label_check 不適用。

Claude 接線：現有 `Car`、`Skyline`、`ArrivalScene` 仍讀原尺寸。原尺寸新圖已在實機直接替換；4× 車圖與獨立車燈未接入。請保持原尺寸的車長、offset、輪胎基線及交通碰撞，讓渲染尺度等於 native / detail；不要把 4× 寬度當行車長度。側視左右翻轉的燈層須和本體對齐。前後視圖没有街區停車資料的新增接線，本批不新增玩法。

這是全遊戲美術優化的車流批，**整個遊戲尚未全部優化完成**。建築、地材、道具、所有行人、室內、介面、地圖及未推出內容仍需逐項視覺驗收。完整 40–60 分鐘故事 walkthrough 未執行；保持 Draft。

交件檢查表：
- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）；附美術打包／QA工具、wiki和證據
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（既有尺寸全部保持，不需要 metadata 變更）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（最後一行如上）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（不適用，沒有動角色圖）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過（不適用，沒有動地圖）
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
