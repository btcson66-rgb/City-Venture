# A5 頭像驗收

## 交件

- 既有 45 張基本頭像圖層全部由 `tools/art/a5_portraits.py` 重建；R1 後新增的 `business_suit_detail`、`courier_detail` 兩張也一併重建。原圖層合計 47 張，wiki 早期表格的「45」未包含 R1 的兩張細節層。
- 新增 `acc_glasses_round.png`、`acc_glasses_square.png`，各 64×64，附 Godot `.png.import`。遊戲 `Art.portrait_layers` 已有對應讀取路徑，無須改程式。
- 原有檔名、畫布與四格順序不變；遊戲 scripts、data、tests 與走路圖均未修改。

## 視覺修正

- 64px 內將輪廓邊緣向內柔化，不讓半透明黑色滲出造成染色光暈。
- 思考表情增加不對稱半垂眼和偏側緊抿嘴；驚訝表情加強挑眉及圓形嘴部下唇；保留開心表情閉眼微笑。
- 圓框與方框眼鏡均對齊眼睛座標，透明鏡片不遮住瞳色。Priya 為圓框、Ana 與 Daniel 為方框。
- 既有髮型、膚色、服裝與 NPC 染色維持資料原設定，保留 12 位角色身份辨識。

## 實測與證據

- `npc_lineup_before_after.png`：用 `game/data/npcs/*.json` 中的外觀與染色依遊戲圖層順序組出的 12 位角色對照。
- `expressions_before_after.png`：Maya、Priya、Daniel、Elena 四表情對照。其餘 8 位也由 `tools/art/a5_preview.py` 逐一檢查四張不重複。
- `glasses_fit.png`：三位戴眼鏡 NPC 的配件對位。
- `02_creator_in_game.png`：遊戲內角色創建畫面。
- 49/49 圖片尺寸正確；Godot 4.5.1 headless import 成功；單元測試 67/67；`--bot=shots` 28 張、0 failure；`python tools/wiki_check.py` 通過；`python tools/qa/pose_check.py` 回報 `pose_check: OK`。

A5 保持 64×64 頭像圖層契約；專屬 NPC 全身與 256×64 個人頭像屬 wiki 的 B10 後續批次。
