# 待合併美術批覆蓋盤點

基底：9145015af512ba98bc7560162c0de61a5ec01d70。讀取11個Draft批的美術差異，未合併、未更動任何遊戲。這是PNG檔案覆蓋，不能作為整合後實機品質PASS。

| 類別 | 原尺寸PNG | 正確4× | 仍缺或尺寸不符 |
|---|---:|---:|---:|
| backdrops | 21 | 21 | 0 |
| buildings | 76 | 76 | 0 |
| cards | 19 | 19 | 0 |
| characters | 1351 | 1351 | 0 |
| city_map | 15 | 15 | 0 |
| effects | 6 | 0 | 6 |
| events | 4 | 4 | 0 |
| interiors | 101 | 101 | 0 |
| logos | 2 | 2 | 0 |
| minigames | 2 | 2 | 0 |
| portraits | 83 | 83 | 0 |
| products | 2 | 2 | 0 |
| props | 68 | 62 | 6 |
| tiles | 6 | 6 | 0 |
| ui | 69 | 67 | 2 |
| vehicles | 34 | 34 | 0 |
| world_map | 10 | 10 | 0 |

## 尚待處理的圖檔

- effects/glow_small.png：缺detail
- effects/glow_warm.png：缺detail
- effects/glow_wide.png：缺detail
- effects/shadow.png：缺detail
- effects/sparkle.png：缺detail
- effects/water_sparkle.png：缺detail
- props/product_coffee.png：缺detail
- props/product_desk_lamp.png：缺detail
- props/product_earbuds.png：缺detail
- props/product_parcel.png：缺detail
- props/product_phone_stand.png：缺detail
- props/product_water_bottle.png：缺detail
- ui/app_icon.png：缺detail
- ui/app_icon_1024.png：缺detail

## 已知整合品質問題

- 所有Draft尚未一起合併；本盤點僅讀取差異，各批實拍分別驗收，combined runtime維持NOT_VERIFIED。
- #46包含自訂角色高解析/表情接線；不同膚色、體型、髮型、服裝及姿勢的最終整合仍需再逐街區實拍。具名NPC走路欄與表情欄需Claude分離。
- #56五套商店服裝需套用正式配色metadata；現行程式會忽略原stand_in配色。單元測試250/251，唯一失敗是尚硬編碼暫代服裝的測試，不屬於本美術線可修改範圍。
- 外觀、車輛、地磚、UI、地圖及背景多仍載native；detail檔案存在不代表渲染已載4×。Claude需保留logical尺寸、atlas格子與燈光強度接入。
- #60部分背景的4×輸出需來源插值，比例已公開；不是額外原生像素細節。
- 個別Draft的53張巡禮不能取代合併後40–60分鐘繁中故事和全街區日夜/碰撞/遮擋驗收。
