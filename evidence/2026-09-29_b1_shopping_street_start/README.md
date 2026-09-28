# B1 購物街起步（2026-09-29）

這是 B1 的第一批可交接美術，並非整批 B1 的完成宣告。

## 已交圖檔

- 七棟 Shopping Street 建築，各有本體與 `_lights`：Threadline、Crestline、Lantern Bistro、Pop-up Unit 5、騎樓商場、雨遮店排、電影院。`buildings_meta.json` 同步紀錄實際尺寸、門與 runtime 招牌素底。
- Threadline 六件室內家具：`clothing_rack`、`mannequin`、`fitting_room`、`checkout_counter`、`mirror_full`、`shoe_shelf`。採用現有 `wood_dark` 地板和 `white_modern` 牆磚；新增家具 footprint 寫入 `sprite_meta.json`。
- 購物街街道物件：三色市集攤、串燈及夜間發光層、花攤、長花台、腳踏車架。既有 sidewalk 地磚沿用。

`b1_art_contrast_sheet.png` 把七棟新建築、全部新街道物件、全部 Threadline 家具及既有 Bloom 立面放在同一張圖上檢查比例與色調。`shopping_street_night.png` 檢查夜燈克制程度；各類素材亦有獨立預覽圖。

## 驗收與交接

- Godot 4.5.1 匯入成功；67/67 單元測試；既有場景巡禮 28 張、0 failure。
- `wiki_check`、`pose_check`、`map_label_check` 都 OK；七棟建築的圖尺寸與 metadata 一致，夜燈圖齊全。
- 新購物街尚未接到地區資料，實機巡禮不會顯示這批新立面。Claude 線須新增地區擺放、Threadline 室內配置、進入／購買與串燈時段邏輯，本文不宣稱這些流程已驗收。

## B1 剩餘

五套服裝的三體型走路圖和頭像、帽子／包包／手錶／識別證／耳麥配件、Nina，及遊戲接線後的三體型與新區實機驗收。現階段保持 Draft PR，後續美術可在同一 B1 分支繼續。
