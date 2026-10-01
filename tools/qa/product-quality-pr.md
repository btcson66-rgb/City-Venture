商品圖仍是低解析小圖，六種光影/水面特效及兩個app輸出缺完整4×。本批重製六個透明商品sprite，將既有程序特效转成SVG直接输出，并補app圖示的高解析尺寸配對；native尺寸、動畫格位與遊戲資料保持原樣。

基底：claude/exciting-bardeen-y71ixv @9145015af512ba98bc7560162c0de61a5ec01d70，fetch/pull後獨立分支，沒有動game/scripts、game/data、game/tests或game/autoload。

交付：12native替換+14detail=26PNG，附import。商品各有獨立原圖與提示詞。app native未改，1024圖之4096輸出有插值，已公開。六個特效維持既有alpha強度和動畫4frame格位。

驗證：
- import exit0，無ERROR。
- 最後一行：`251/251 tests passed in 16.3s`
- --bot=shots：53截圖/63步/0失敗，50.6s，English audit0。
- 七街區共14個日夜場景實拍；QA以現有add_prop放六個商品，確認texture64×64、scale=.25、logical16×16。QA擺放不視為原本遊戲擺設。
- product_quality_check：14素材的尺寸/alpha/4frame/import及app identity/gameplay邊界OK。
- wiki_check：OK（1627 assets,191 data ids）。
- evidence/20261001_product_quality：前後巡禮、實拍對照、商品素材對照、實際日夜和QA擺放，附logs。

Claude接線：
- props已自動讀detail/.25縮放。商品資料icon欄位不等於UI目前畫圖，完整目錄圖片顯示仍須確認。
- glow/shadow/sparkle目前多讀native；改detail時維持logical尺寸、四格動畫及alpha強度，不能把光罩和陰影放大四倍。
- app既有識別與project設定未改，detail僅配對輸出。
- 完整40–60分鐘繁中故事流程未跑，維持Draft。

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

