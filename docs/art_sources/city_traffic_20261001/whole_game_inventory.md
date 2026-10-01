# 全遊戲美術覆蓋盤點 · 2026-10-01

檔案存在與高解析覆蓋不代表實機品質通過。每類需逐場景檢查載入、比例、日夜、動畫、碰撞及遮擋；未檢查項目維持 NOT_YET_EVALUATED。

| 類別 | 原尺寸 PNG | 有 detail | 正確 4× | 視覺驗收 |
|---|---:|---:|---:|---|
| backdrops | 21 | 8 | 8 | NOT_YET_EVALUATED |
| buildings | 76 | 26 | 26 | NOT_YET_EVALUATED |
| cards | 19 | 7 | 7 | NOT_YET_EVALUATED |
| characters | 847 | 7 | 7 | NOT_YET_EVALUATED |
| city_map | 15 | 0 | 0 | NOT_YET_EVALUATED |
| effects | 6 | 0 | 0 | NOT_YET_EVALUATED |
| events | 4 | 4 | 4 | NOT_YET_EVALUATED |
| interiors | 100 | 74 | 67 | NOT_YET_EVALUATED |
| logos | 2 | 2 | 2 | NOT_YET_EVALUATED |
| minigames | 2 | 2 | 2 | NOT_YET_EVALUATED |
| portraits | 68 | 17 | 17 | NOT_YET_EVALUATED |
| products | 2 | 2 | 2 | NOT_YET_EVALUATED |
| props | 65 | 23 | 23 | NOT_YET_EVALUATED |
| tiles | 6 | 6 | 6 | NOT_YET_EVALUATED |
| ui | 69 | 0 | 0 | NOT_YET_EVALUATED |
| vehicles | 34 | 34 | 34 | NOT_YET_EVALUATED |
| world_map | 10 | 0 | 0 | NOT_YET_EVALUATED |

## 工作順序與驗收邊界

- 角色建立／行人／員工：既有角色品質 PR #46，須合併後再逐街區檢查不同膚色、體型、髮型、服裝和動作。
- 車流／停車／列車：本批交替換原尺寸、4×與獨立燈層；實機對比見 evidence/20261001_city_traffic。
- 建築與地面：確認所有街區的正式素材、高解析載入、招牌空白區、門位與材質接縫。
- 室內／物件：確認全部室內的家具、工作道具、牆地材、光罩、遮擋與座位；別名素材需檢查是否失去物件辨識度。
- 介面／地圖／章節與事件卡／商品／特效：逐頁查可讀性、輪廓、風格、日夜與缺漏。
- 未接線素材仍標 Planned/需接線；未推出街區和故事不得以現有截圖宣告驗收完成。

完整逐檔 JSON：whole_game_inventory.json。此文件是盤點，不是全遊戲已完成的宣告。
