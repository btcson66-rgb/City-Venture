# 五套商店服裝品質批 · PARTIAL

基線：新分支 codex/art-shop-wardrobe-completion 從 Claude 最新 9145015 建立並 pull；不承接舊 Codex 分支。只交美術、調色 metadata、美術重建/QA 工具和文件；game/scripts、game/data、game/tests、autoload 均未修改。

交件：五套服裝各自原畫；三種身形，top / bottom / shoes / top_detail，走路及 sit / idle / phone / interact / carry；五套頭像各有衣領和 detail。370 native + 370 world_detail PNG，所有 PNG 附 .import。透明裁切、灰階布料、固定色細節、SVG 與雜湊均可追溯。

驗收：Godot import exit 0，無 ERROR；pose_check OK；wiki_check OK (2353 assets, 191 data ids)。截圖巡禮 53 張、63 步、0 failures，English audit 0。test_runner 結果 **250/251**；唯一失敗是 test_shop_outfits_draw_as_stand_ins_until_their_art_exists，硬性要求 business_suit 暫代和舊暫代 tint。正式圖已自動取代暫代；測試須由 Claude 更新，這裡沒有改測試或藏掉失敗。

`before/`、`after/` 是實際截圖巡禮；compare_*.png 是實拍對比。`actual_unwired/` 是未修改程式時的 33 張真實 CharacterRig / PortraitView 矩陣，以及五張商店實景。`actual_palette_preview/` 使用同一真實元件，QA 明確傳入美術 palette；不是正式遊戲預設色已接線的證據。`current_layer_preview/` 是素材合成；`candidate_combined_preview/` 以 PR #46 的待合入角色圖層合成，並非本分支實機結果。

待 Claude 接線：正式檔名存在時 _resolve_outfit 會直接返回傳入 tint（玩家通常空），因此丟失 stand_in 中的預設色。請從 assets/outfit_palette.json 套入正式預設色，再用明確 NPC tint 覆寫，details / shoes 不染。4× 自訂圖層載入與角色表情修正依賴 PR #46。現有五色路人大衣應保持可染色。測試應同時驗證未有圖的 fallback 與正式圖存在時的替換。

本批無地圖、地磚或建築尺寸變動，map_label_check 不適用；全故事 40–60 分鐘 walkthrough 未跑，維持 Draft。全遊戲美術優化仍包含地面、介面、地圖、配件與其他盤點缺口，不能據此宣告全部完成。
