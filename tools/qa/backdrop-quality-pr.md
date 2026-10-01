背景和地點卡的上一輪原畫有完整色彩，但遊戲輸出曾縮成192色，造成玻璃漸層、植物和室內光影資訊損失。本批直接從同一套19張原畫重新裁切輸出13張背景及12張地點卡，取消色盤縮減，補齊4×版本，保持構圖、方向、尺寸與檔名。

基底：claude/exciting-bardeen-y71ixv @ 9145015af512ba98bc7560162c0de61a5ec01d70，fetch/pull後獨立分支。未改game/scripts、game/data、game/tests、game/autoload。來源雜湊和source尺寸見manifest。部分背景4×需插值（尤其三張天際線2.394倍），不是憑空增加原畫細節；地點卡的4×768×432仍小於原画1672×941。此批不是新生成25個場景。

驗證：
- import exit0，無ERROR。
- 最後一行：`251/251 tests passed in 16.4s`
- --bot=shots：53截圖/63步/0失敗，English audit0，50.9s。
- 前後各18張繁中原生UI實拍：選單、建角衣櫥、抵達、六章標題卡、重新出發、八個地點卡。使用遊戲既有UIRoot方法，並非劇情完整走查。
- backdrop_quality_check：25 source-linked full-color exports，native/4×尺寸、import、sourcehash和gameplay邊界OK。
- wiki_check：OK（1638 assets,191 data ids）。
- 證據：`evidence/20261001_backdrop_quality/`，含7張前後對比、36張展示實拍、兩組53張巡禮及logs。

Claude接線：
- native已自動改善色彩。4×載入時保留章節640×360、衣櫥200×250、地點192×108等logical尺寸。
- Backdrop和天際線使用physical texture dimensions，改detail時須固定原logical大小及pan範圍，避免4倍的裁切、平移和比例。
- ChapterCard已有EXPAND_IGNORE_SIZE；地點卡和衣櫥須相應固定viewport。
- 保持Draft，40–60分鐘完整繁中故事流程未執行。

交件檢查表：
- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（N/A：尺寸未變）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（貼最後一行，見上）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（N/A：未動角色）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過（N/A：未動地圖）
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明

