# 自訂角色品質修正 · 2026-10-01

起點：`claude/exciting-bardeen-y71ixv` 的 `e6accdb`，新 worktree / `codex/art-character-customization-quality`；已 pull。未接舊 Codex 分支。

## 問題與修正

改前：只有完全相同的預設造型讀高解析 `player_default`；換一格膚色便回到舊的分層像素角色。`before/creator_s2.png` 與 `before/creator_s6.png` 為修正前真正的建立器截圖。

改後：預設和自訂外觀都使用完整分層素材，既有 logical keys 優先讀 world_detail。膚色只染 body/head；髮型、五官、服裝與配件的選項保持獨立。九套現有服裝、五種姿勢均有原尺寸與 4× 版本；五套商店服裝保留既有 stand_in 設計。加入獨立四表情五官層，頭像和全身預覽同步。修掉檢查中發現的衣領重疊、馬尾／後髮頭皮外露、舊制服 detail 層漏補，以及女性裙装坐姿斷層。

1040 組素材，每組原尺寸 PNG、4× PNG 及各自 `.png.import`。原始材質、SVG 原稿、提示詞、裁切位置、SHA-256 和重建工具在 `docs/art_sources/custom_character_20261001/`。所有原尺寸、腳底錨點與碰撞不變，不需改 buildings_meta / sprite_meta / tile atlas。

必要渲染修正：`game/autoload/art.gd` 的高解析分層讀取；`character_rig.gd` 的獨立表情圖層；`character_creator.gd` 將預覽表情傳給全身圖。只影響顯示；沒有改 game/data、game/tests、交易、故事、存檔欄位或能力。這是本次使用者要求修好建立器的接線，並非前一輪純素材批次。

## 實機證據

- `comparison_s2.png` / `comparison_s6.png`：左右為真正建立器前後截圖，僅裁切和並排，沒有重繪。
- `after/creator_s1.png` 至 `creator_s6.png`：六種膚色的完整建立器。
- `after/matrix_*.png`：26 頁真正 CharacterRig / PortraitView 渲染，涵蓋全部建立器選項、五套商店 stand_in、三種外型 × 六膚色、四表情及五姿勢三方向。這些頁面是驗收畫面，不是遊戲新增 UI。
- `after/world_saved_custom_*.png`：自訂外觀經既有 player template 的 JSON 序列化往返，在真正公寓場景重建後的走路／坐姿／手機／互動／搬運圖。不是完整 SaveSystem 磁碟存檔驗收；既有存檔測試隨全套測試執行。
- `tour/screenshots/`：標準遊戲 bot 實機巡檢，53 張畫面；`tour/walkthrough_result.json`：63 steps、0 failures。

## 驗收

Windows 使用 Godot 4.5.1 console；`python` 等同工單的 `python3`。bot 的 `/tmp/shots` 改成本批 evidence 絕對路徑。

| 檢查 | 結果 | 記錄 |
|---|---|---|
| godot --headless --path game --import | 最終 exit 0、無錯誤 | logs/import.log |
| Godot 全套測試 | **227/227 tests passed in 15.1s** | logs/tests.log |
| 自訂角色回歸檢查 | **8094 combinations; 1040 texture/pose checks; 0 failures** | logs/coverage.log |
| --bot=shots | **BOT FINISHED — 0 failure(s)**；53 screenshots、63 steps | logs/tour.log / tour/walkthrough_result.json |
| wiki_check | **OK (2800 assets, 191 data ids)** | logs/wiki.log |
| pose_check | **OK** | logs/pose.log |
| map_label_check | **OK**；本批未改地圖 | logs/map_labels.log |
| 原尺寸 + 4× + 匯入檔 | **1040 + 1040 PNG/import pairs**；尺寸逐檔檢查 | docs/art_sources/.../manifest.json |

新的乾淨 worktree 首次全匯入在字型預匯入階段異常退出；重試成功。最早尚未完成匯入時的空白截圖已由成功匯入後重新拍攝的 before 證據取代，沒有把失敗畫面或未匯入狀態當成美術比較。

視覺覆核：實際檢查六種膚色、八種髮型、所有服裝和配件矩陣，以及三方向姿勢與表情頁；可直接開 PNG 檢查。這批確認的是可自訂角色的連貫性與完整素材覆蓋；不以這些檢查宣稱全遊戲所有建築、未推出服裝或未接入內容都已完成，也不把自動測試等同主觀美感保證。
