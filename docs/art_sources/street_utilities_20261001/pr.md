街道公共設施原本多為簡化色塊，告示文字也直接烘焙在素材。本批重新精修22種公共物件／市集攤位：阻車柱、消防栓、路錐、垃圾桶、計時器、數位廣告屏、导引牌、地鐵識別板、菜單板、候車亭、車架、噴泉、旗桿、花攤、廣告板、商業公告板、欄杆、藍色戶外桌椅、三種攤位與串燈。

從最新Claude `9145015` pull開始。交48個原尺寸／4×PNG及import，含digital_sign和string_lights獨立亮部光罩。現有WorldScene會自動讀4×props，已在實際巡禮顯示。原尺寸、metadata、地磚位置保持，不改scripts/data/tests。原圖、提示詞、裁切與雜湊：docs/art_sources/street_utilities_20261001。

驗證：Godot4.5.1import exit0；`251/251 tests passed in 16.7s`；`BOT FINISHED — 0 failure(s) · 50.7s real`，53張／63步，英文審核0；`wiki_check: OK (1638 assets, 191 data ids)`；`map_label_check: OK`；`street_utilities_check: 48 PNG/import pairs; existing footprints, 4x and isolated light masks: OK`。角色未修改，pose_check不適用。

前後對比：evidence/20261001_street_utilities。素材圖集不是實機證據；原始before/after截圖、並排圖及原始log均保留。生成圖集跨格的碎片已以人工檢查的物件範圍修正。

Claude接線：所有告示、方向、菜單、廣告、旗幟和地鐵識別面留白，需程式覆蓋文字／識別符號；本批未新增UI/data接線。不得把素材無文字宣稱文字入口已完整。metro_entrance立面另保留，不在本批。

全遊戲美術優化尚未完成；角色#46、車流#49、建築／植栽#50是獨立批次，本批不混入。完整40–60分鐘故事walkthrough未執行，保持Draft。

交件檢查表：
- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）；附美術工具、wiki與證據
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（所有既有尺寸保持）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（最後一行如上）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（不適用）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過（不動地圖，額外執行通過）
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
