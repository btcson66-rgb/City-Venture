# 五套商店服裝 · 2026-10-01

美術狀態：原畫、分層 SVG、原尺寸、4×、姿勢和頭像已交。布料為灰階，襯衫、領帶、針織內搭、反光條、斜背包等使用不染色的 detail 層。每套三體型、六種動作（走路及五種姿勢）、三方向；370 個 logical key 各有 native 和 detail，合計 740 PNG。

`originals/` 保存五套服裝的透明原畫；每套正面、側面、背面。`prompts.json` 是確切提示詞；`crop_manifest.json` 記錄透明邊界與布料取樣。裁切、去色及分層為染色系統所需的機械處理，沒有用舊服裝放大冒充新材質。

`rig_masks/` 保存 Claude 基線 9145015 的 18 張袖口 alpha，讓新衣服接到舊版伸手及手機姿勢的手部。共享 SVG 骨架也與角色品質 PR #46 的新輪廓相容。這裡只處理衣服，沒有更換任何膚色、頭部或手部圖層。

重建：`python tools/art/shop_wardrobe_extract.py` → `python tools/art/shop_wardrobe_vectors.py` → `node tools/art/render_shop_wardrobe.cjs` → Godot import。裁切工具保留已封存的 rig alpha，避免基線更新後改變相容形狀。可使用環境變數 CITY_SHARP 指定 Sharp 路徑。

程式待接：`game/assets/outfit_palette.json` 是正式服裝的預設色。現在 `_resolve_outfit` 遇到正式圖會直接返回空 tint，玩家衣服呈白／灰色；Claude 應在正式素材的分支套入 defaults，再以明確 NPC tint 覆寫。`top_detail`、鞋和頭像 detail 保持白色 modulation；購物街的五色大衣和 Nina 炭灰色使用既有 NPC 設定即可。

4× 的自訂圖層載入由角色品質 PR #46 的 cosmetic wiring 提供，本批不修改任何 game scripts/data/tests/autoload。獨立素材預覽、實機矩陣與目前未接色的實景會分別標示，不能當成程式已接好的證據。
