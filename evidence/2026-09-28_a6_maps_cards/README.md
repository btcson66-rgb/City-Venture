# A6 地圖與地點卡（含 R2）驗收

## 範圍

- 城市地圖 15 張：`board`、`aurelia_map`、13 張 `i_*`。
- 世界地圖 9 張：`board`、8 張 `r_*`。未使用的 `world_map/world_map.png` 保留原狀。
- 地點卡 12 張：11 張既有卡重製、1 張 PostPoint 專屬卡；新增檔案含 Godot `.png.import`。
- 圖片尺寸、檔名和資料中的 `board.label`、`board.pin`、`map_pos` 均未變更。遊戲 scripts、data、tests 均未修改。

## 美術處理

從專案內的 Board C、E、F、G、H 重新取樣，使用完整 RGB 與 Lanczos 縮圖，避免舊版減色後的格狀邊緣。城市／世界主圖上對應 runtime 標籤的位置塗成無字深藍底，避免程式標籤和參考圖英文重疊。捷運圖改為無字的深藍街道、河道示意圖；彩色路線和站點仍由遊戲繪製。

R2：Riverside 旗幟只留符號；辦公室口號、咖啡館菜單、路牌及海報的文字改成材質或符號。依 R2 明文例外，Nexus 等品牌識別招牌保留。PostPoint 使用遊戲實際店面造型，卡片上以包裹符號代替英文招牌。

重建：`python tools/art/a6_maps_cards.py`。這只覆寫 A6 的 36 張美術圖片；不執行 `concepts.generate()`，因此不會重產其他批次資產。

## 對照與實測

- `city_map_before_after.png`、`world_map_before_after.png`、`metro_before_after.png`：底圖前後。
- `cards_before_after.png`：六張代表性卡片前後；`riverside_card.png`、`financial_card.png`、`postpoint_riverside_card.png` 可單獨檢查。
- `16_city_map_in_game.png`、`17_world_map_in_game.png`：遊戲 runtime 標籤疊合，未改座標。
- 36/36 圖片尺寸正確；Godot 4.5.1 headless import 成功；單元測試 67/67；`--bot=shots` 28 張、0 failure；`python tools/wiki_check.py` 通過。

圖片是原始碼中可重現的視覺證據。地點卡中的品牌招牌保留屬 R2 指定例外，並非可翻譯的敘述文字。
