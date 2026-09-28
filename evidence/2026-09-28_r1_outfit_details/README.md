# R1 可染色布料與不染色細節

## 交付

- `business_suit`、`courier` 的三種體型 `top`、`bottom` 改為灰階布料，共 12 張；新增六張全彩 `top_detail`。褲裝沒有需保色的細節，因此不建立空白 `bottom_detail`。
- 兩套頭像衣領改為灰階，新增 `portraits/outfit_business_suit_detail.png`、`outfit_courier_detail.png`。
- `tools/art/chars.py` 可重現拆層；`tools/art/preview_r1.py` 會檢查灰階與全彩層並產生染色對照。
- 不修改 NPC 染色資料、遊戲規則或腳本。Claude 線可將四名西裝 NPC 及 Dara 的顏色接入既有資料。

## 改前與改後

[改前 12 位 NPC](before_named_npcs.png)；[改後四種西裝及 PostPoint 紅](after_tint_variants.png)。改後圖為原角色圖層以指定色彩組合的驗收預覽，NPC 資料尚未寫入這些新染色值。

![R1 染色對照](after_tint_variants.png)

## 驗證

- 8 張新 PNG 均附 `.png.import`；尺寸為 128×144（六張角色細節）或 64×64（兩張頭像細節）。
- Godot 4.5.1 匯入成功；單元測試 **64/64 passed**；截圖巡禮 **28 張、0 failure(s)**。
- `python tools/wiki_check.py`：`OK (514 assets, 156 data ids)`。
- R1 預覽程式驗證布料像素為灰階，領帶、襯衫、腰包細節保留全彩。

## 後續

`barista` 圍裙及 `civic_staff` 名牌屬此需求的可選延伸，留待後續獨立美術批次。此 PR 只處理優先指定的西裝與快遞服。
