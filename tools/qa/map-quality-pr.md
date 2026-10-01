城市與世界地圖使用舊概念板裁圖，部分文字與空標籤底板烘焙在圖內，21 個區域預覽缺少完整高解析版本。本批重製主圖與獨立區域預覽，並把捷運底圖轉成可重建 SVG；所有 25 個素材交付原尺寸及 4×，保留既有檔名、尺寸與點位。

基底：claude/exciting-bardeen-y71ixv @ 9145015af512ba98bc7560162c0de61a5ec01d70，先 fetch/pull，独立批次。只動美術素材、wiki、source 與 art QA；未改 game/scripts、game/data、game/tests、game/autoload。

驗證：
- import：exit 0，無 ERROR。
- 最後一行：`251/251 tests passed in 15.5s`
- --bot=shots：53 screenshots / 63 steps / 0 failures；English audit 0。
- 原生模態：12 城市街區 + 8 世界區域的20次 label-button 選取，以及捷運底圖，英文與繁體中文實拍；全無錯誤。
- map_quality_check / map_label_check：OK。
- wiki_check：OK（1638 assets, 191 data ids）。
- 證據：`evidence/20261001_map_quality/`，含 before/after、實拍對比、23張英文及23張繁中模態截圖與logs。
- 保持 Draft：40–60 分鐘完整繁中劇情走查未執行。

Claude 接線：
1. 地圖模態目前使用原尺寸，實拍已換新美術；4× 載入須固定主圖458×305/600×255，預覽144×90/64×40，设置TextureRect EXPAND_IGNORE_SIZE及stretch。不得把城市/世界的board座標、點擊區域乘4。
2. 捷運維持220×124 viewport，路線/站點座標不變。
3. world_map/world_map 備用背景與 city_map/i_metro 沒有目前模態直接載入路徑；僅交素材。海外依舊 P2 規劃，未宣稱可遊玩。
4. 25素材 native及4×尺寸未變，無須修改 buildings_meta/sprite_meta/atlas.json。此批沒有發光立面或路燈，不需燈層。

交件檢查表：
- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（N/A：尺寸未變）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（最後一行見上）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（N/A：未動角色）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明

