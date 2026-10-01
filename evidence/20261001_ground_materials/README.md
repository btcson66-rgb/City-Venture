# 戶外地面品質批

基線：fresh Claude 9145015，新分支 codex/art-ground-materials-quality，先 pull。28 格戶外 atlas 重製；43 座標不移動，15 室內及 5 unused cell 像素保持原樣。native atlas 128×96，4× 512×384；import 皆存在。源圖、SVG、提示詞和 manifest 可重建。

驗收：Godot import exit 0、ERROR 0；`251/251 tests passed in 15.6s`；截圖巡禮 53 screenshots / 63 steps / 0 failures（50.8s），English audit 0；wiki_check OK (1613 assets, 191 data ids)；map_label_check OK。pose_check N/A（未動角色）。ground_material_check 確認位置／尺寸、未改區域保全及低對比材質邊界最大差 <=12/255。

`before/`、`after/` 為遊戲實拍巡禮；compare_*.png 为逐張並排。`actual_ground/` 是七街區 × 白天／晚上共 14 張實機地面檢視，使用現有 renderer，沒有替換成高解析預覽。`material_repeat_review.png` 為 4× 素材平鋪觀感檢查，不是實機證據。

原尺寸地面替換會立即可見；4× atlas 仍需 Claude 在 TileMap 中以 16×16 logical projection 正確載入，不可直接用 16px texture region 讀 4× atlas。此批不動 game/scripts、game/data、game/tests 或任何玩法、導航、碰撞。獨立 Draft 的角色／車流／建築尚待整合；本批不能代表全遊戲畫質完成。

完整 zh_TW story walkthrough 未跑，保持 Draft。來源格式見 docs/art_sources/ground_materials_20261001/README.md。
