# 03 城市區域

## 街區的共同版型

每個可走的街區都是一條**橫向捲動的長條街**。資料在 `game/data/districts/<id>.json`。由 `tools/gen_districts.py` 依建築尺寸排版。

```
 y(格)  ┌───────────────────────────────────────────────────────────┐
  0     │ 天際線背景 backdrops/skyline_day|night（視差捲動）         │
        │ 建築立面一排（可進入的建築 + 填充建築），門開在 y≈20       │
 20     │ 上人行道 sidewalk（門口、路燈、樹、招牌）                  │
 24     │ 路緣 curb_top                                              │
 25–30  │ 馬路兩線道（車流 y=424 往左、y=478 往右，單位 px）         │
 31     │ 下人行道                                                   │
 34–48  │ 區域特色帶：河岸公園＋河（Riverside）、廣場（Startup Hub）│
        │ 規劃中：碼頭、市集、校園草地、遊樂場……                    │
        └───────────────────────────────────────────────────────────┘
        ← 出口箭頭（走到邊緣換區）              捷運入口 →
```

- 寬度 80–120 格（1280–1920 px），高 44–48 格。
- 每區有一個捷運入口（`buildings/metro_entrance.png`）、一或兩個走路出口。
- 路人密度依時段變化（早、午、晚、夜），車流密度 0.6–1.0。
- 小地圖顏色是 `minimap_color`。

---

## 已開放的區域

### Riverside 河岸區 · `riverside`

| 項目 | 內容 |
|------|------|
| 狀態 | 已實作 · 美術 `CONV` + `GEN v3` |
| 尺寸 | 120×48 格 |
| 氣質 | 玩家的第一個家。綠樹、河景、暖色紅磚和咖啡香。白天悠閒，晚上窗戶暖黃 |
| 音樂 | 資料欄位 `day_city`。目前所有街區都依時間播 `day` / `night` 兩首（`autoload/sound.gd`） |
| 小地圖色 | `#5F8A5A` |
| 地面 | 上廣場 → 人行道 → 馬路（3 條斑馬線）→ 人行道 → **河岸草地、木棧道（boards）、花圃** → 水岸 → **河** |
| 可進入建築 | `riverside_apartment` Riverside Tower（家）· `bloom_coffee` Bloom Coffee · `postpoint_riverside` PostPoint |
| 填充建築 | `riverside_walkup` ×2 · `riverside_shops` · `apartment_mid` · `brick_shops` · `office_slab` · `glass_tower` |
| 街道物件 | 路燈 `lamp` ×4、旗燈 `lamp_banner` ×6、圓樹 `tree_round` ×15 / `tree_round_b` ×5、護柱 `bollard` ×42、河岸欄杆 `railing` ×30、樹籬 `hedge` ×4、長椅 ×3、花圃 ×2、噴水池、公車站、看板、數位看板、指示牌、咖啡立牌、洋傘桌 ×2、腳踏車 ×2、小盆栽 ×4 |
| 出口 | 東 → Startup Hub |
| 捷運 | M1、M2、M3 |
| 美術重點 | 河面要有波光（規劃特效 `water_sparkle`），夜晚要有路燈倒影。木棧道和欄杆是河岸的招牌畫面 |

### Startup Hub 新創園區 · `startup_hub`

| 項目 | 內容 |
|------|------|
| 狀態 | 已實作 · 美術 `CONV` + `GEN v3` |
| 尺寸 | 112×48 格 |
| 氣質 | 玻璃、露台、植栽、筆電和燕麥拿鐵。年輕、有活力、主色是橘 |
| 小地圖色 | `#5D6F9A` |
| 地面 | 上廣場 → 人行道 → 馬路 → 人行道 → **大廣場、花園、草地** |
| 可進入建築 | `nexus_cowork` Nexus Co-work · `byte_and_bean` Bean & Byte · `small_office` 22 Founders Lane（Suite 2B） |
| 填充建築 | `office_slab` ×2 · `horizon_labs` · `glass_tower` · `apartment_mid` |
| 街道物件 | 業務看板 `business_board`（Business Board 的戶外版）、藍洋傘桌 ×2、樹籬 ×10、旗燈 ×7、路燈 ×3、樹 ×16、護柱 ×41、盆栽 ×9 |
| 出口 | 西 → Riverside |
| 捷運 | M2、M5 |
| 美術重點 | 共享辦公大樓要看得到裡面在工作的人；Horizon Labs 是「未來可租的樓層」的預告 |

### Civic Center 市政中心 · `civic_center`

| 項目 | 內容 |
|------|------|
| 狀態 | 已實作 · 美術 `CONV` + `GEN v3` |
| 尺寸 | 80×44 格 |
| 氣質 | 石材、旗桿、噴水池廣場。莊重但親民，藍色主調 |
| 音樂 | 資料欄位 `civic`（尚未有專屬曲目） |
| 小地圖色 | `#8A8470` |
| 可進入建築 | `city_hall` Aurelia City Hall |
| 填充建築 | `civic_annex` · `office_slab` · `brick_shops` · `glass_tower` |
| 街道物件 | 旗桿 ×2、噴水池、樹 ×14、樹籬 ×7、花圃 ×2、長椅 ×2、護柱 ×30 |
| 出口 | 西 → Shopping Street · 東 → Financial |
| 捷運 | M1、M5 |
| 規劃 | 填充建築 `civic_annex` 的招牌已經是 TAX OFFICE；P2 讓它可以進入，成為 `tax_office` 稅務局（見 [04](04_buildings.md)） |

### Financial District 金融區 · `financial`

| 項目 | 內容 |
|------|------|
| 狀態 | 已實作 · 美術 `CONV` + `GEN v3` |
| 尺寸 | 80×44 格 |
| 氣質 | 高樓、玻璃帷幕、西裝。白天冷藍，晚上是全城最亮的區 |
| 音樂 | 資料欄位 `financial`（尚未有專屬曲目） |
| 小地圖色 | `#4A5A80` |
| 可進入建築 | `nexus_bank` Nexus Bank |
| 填充建築 | `finance_tower` ×2 · `glass_tower` · `office_slab` |
| 街道物件 | 高樹 `tree_tall` ×2、旗燈 ×5、盆栽 ×5、看板、數位看板、樹籬 ×7 |
| 出口 | 西 → Civic Center |
| 捷運 | M1、M4 |
| 規劃 | P1 加入 `northlight_capital` Elena 的創投辦公室；P3 玩家總部可以搬到 `finance_tower` |

### Shopping Street 購物街 · `shopping_street`

| 項目 | 內容 |
|------|------|
| 狀態 | 已實作（2026-09-29）· 美術 Codex B1 起步：七棟立面、街道物件、Threadline 家具。**Crestline 和 Lantern Bistro 室內用現有家具暫代**；五套服裝用現有服裝換色暫代（見 [07](07_characters.md#服裝)） |
| 尺寸 | 90×44 格 |
| 氣質 | 雨遮、櫥窗、串燈。晚上是暖色招牌（**克制，不是霓虹**），週末有市集攤位 |
| 主色 | `#E2649A` 玫瑰 |
| 小地圖色 | `#8A5A78` |
| 地面 | 上廣場 → 人行道 → 馬路（2 條斑馬線）→ 人行道 → **市集廣場**（`plaza_alt`） |
| 可進入建築 | `threadline_apparel` Threadline 服飾店（買衣服、試衣間換裝，店員 Nina）· `lantern_bistro` Lantern Bistro（點招牌套餐 $22，計入「餐飲」支出）· `crestline_flagship` Crestline 旗艦店（第 5 章交貨後展示台上有玩家的 LED 檯燈；Daniel 在接洽大訂單後週末 11–16 點會在店裡）· `popup_unit` Pop-up Unit 5（空店面，看租約公告；承租是規劃中 P3） |
| 填充建築 | `retail_arcade` 騎樓商場 · `cinema_front` 電影院 · `shop_row_awning` 雨遮店排 |
| 街道物件 | 市集攤 `market_stall_rose` / `_sage` / `_cream` 各 2（**週六、週日 09–18 點才擺出來**，其他時間收起、可以穿過）、串燈 `string_lights` ×4（晚上發光，掛在 6 支路燈 `lamp` 之間）、花攤 `kiosk_flower`、長花台 `planter_long` ×2、腳踏車架 `bike_rack` ×2、長椅 ×3、北側人行道的樹、旗燈、護柱、盆栽、餐廳洋傘桌 |
| 路人 | 多穿 Luxury Citywear（大衣顏色會變） |
| 出口 | 東 → Civic Center（步行 8 分鐘；Civic Center 西側新增出口）· 西 → Old Town（步行 6 分鐘；西端有「← OLD TOWN」指示牌） |
| 捷運 | M5 |
| 音樂 | 資料欄位 `day_city`（規劃：輕快 city pop，晚上轉 lounge） |
| 規劃 | `street_performer_spot` 街頭藝人；地點卡照片 `locations/i_shopping_street`；Pop-up 承租（P3） |

### Old Town 老城區 · `old_town`

| 項目 | 內容 |
|------|------|
| 狀態 | **已實作**（2026-09-30；遊戲中文顯示為「舊城區」）· 美術**B3 已交**（2026-09-30）：立面、地磚、街道物件、室內家具和 Okafor 專屬圖已有原尺寸／4× 版。資料裡每一項都寫了正式的圖名，加一個 `fallback`（先借現有的圖）。正式圖一放進 `game/assets/`，遊戲就自動換上，不用改程式（見「暫代對照表」） |
| 尺寸 | 88×44 格（1408×704 px） |
| 氣質 | 低租金、老店、紅磚、石板路、拱廊、鐘樓。傍晚最美。人潮和車流都比購物街稀（車流密度 0.45） |
| 主色 | `#D8A24A` 琥珀 |
| 小地圖色 | `#a0674a` |
| 音樂 | 資料欄位 `day_city`（沿用購物街的曲目；規劃：爵士吉他、手風琴） |
| 地面 | 上方石板廣場 `cobble_a`（y 0–20）→ 人行道 `sidewalk_alt` → 馬路 `road_b`（2 條斑馬線，在 x=30、x=66 格）→ 人行道 → 下方石板廣場 `cobble_b`（y 34–44）。**B3 已加入 `cobble_a`/`cobble_b`（原 atlas 空格 `(6,4)`、`(7,4)`）**（`ground` 項目的 `fallback`） |
| 可進入建築 | `okafor_lettings` Okafor Lettings 租屋行（x=215）· `corner_cafe_unit` 轉角咖啡店（x=594；玩家的咖啡店）· `old_town_studio` Studio 1A 老城套房（x=954；只能參觀，搬家是規劃中） |
| 填充建築 | `rowhouse_brick` 紅磚連棟屋 ×2（x=20、x=1108）· `arcade_arches` 拱廊（x=387）· `clock_tower` 鐘樓（x=766，地標） |
| 街道物件 | 70 件：鑄鐵路燈 `old_lamp` ×8、護柱 `bollard` ×32、樹籬 ×8、圓樹 `tree_round` / `tree_round_b` 各 ×4、小圓桌 `cafe_chairs_bistro` ×2、長椅 ×2、爬藤架 `ivy_trellis` ×2、小盆栽、咖啡立牌 `cafe_board`、指示牌、數位看板、噴水池、壁畫牆 `mural_wall`、舊書攤 `bookstall`、垃圾桶 |
| 路人 | 密度依時段 7 / 11 / 9 / 3（早 / 午 / 晚 / 夜）；服裝混合休閒外套、T 恤、居家服、西裝和城市精品 |
| 出口 | 東 → Shopping Street（步行 6 分鐘，落點在購物街西端） |
| 捷運 | M5 Loop Line（Old Town 是 M5 的最後一站）。捷運入口在街區東側（x≈1180），離東邊出口不遠 |
| 怎麼去 | ① 任何街區的捷運入口 → 選 Old Town（車資 $2.80；到購物街 5 分、市政中心 8 分、金融區 11 分、新創園區 13 分、河岸 16 分）② 從購物街一路往西走到底 |

**暫代對照表**（沒有正式圖時，遊戲畫什麼）

| 正式圖（B3 已交） | 到圖前的暫代 | 位置 |
|------------------|------|------|
| `buildings/okafor_lettings` | `brick_shops` | 立面 |
| `buildings/corner_cafe_unit` | `shop_row_awning` | 立面 |
| `buildings/old_town_studio` | `riverside_walkup` | 立面 |
| `buildings/rowhouse_brick` | `apartment_mid`（x=20）· `riverside_walkup`（x=1108） | 填充建築 |
| `buildings/arcade_arches` | `retail_arcade` | 填充建築 |
| `buildings/clock_tower` | `civic_annex` | 填充建築 |
| 地磚 `cobble_a`、`cobble_b` | `plaza` | 地面 |
| `props/old_lamp` | `lamp` | 街道物件 |
| `props/cafe_chairs_bistro` | `umbrella_table` | 街道物件 |
| `props/mural_wall` | `billboard` | 街道物件 |
| `props/bookstall` | `kiosk_flower` | 街道物件 |
| `props/ivy_trellis` | `flower_bed` | 街道物件 |

暫代的機制是資料裡的 `fallback` 欄位（見 [GAME_DATA_SCHEMA](../GAME_DATA_SCHEMA.md) 的 1.8、1.9）。室內家具的暫代見 [05](05_interiors.md#old-town已實作--2026-09-30)。

**玩法**：Old Town 是「咖啡店」這個產業的所在地。到 Okafor Lettings 向 Mr. Okafor 租轉角店面，再裝潢、辦食品處理執照、進貨、開店，流程見 [13](13_core_loop_and_work.md#咖啡店產業old-town)。**還沒有**：搬進 Studio 1A（規劃中）、藝廊、印刷行、轉角工坊（規劃中，見下）。
### Harbor 港區 · `harbor`

| 項目 | 內容 |
|------|------|
| 狀態 | **已實作**（2026-09-30）· 物流業（`logistics`）的起點。立面、地磚和街道物件的正式美術還沒交，全部用暫代圖（見下）；設定稿和美術清單在下面「規劃中的區域」的 Harbor 條目和 `90_codex_art_backlog.md` B2 |
| 尺寸 | 88×46 格 |
| 主色 | `#4A8CE8` 藍 |
| 小地圖色 | `#4A7A92` |
| 地面 | 上廣場（被天際線蓋掉）→ 人行道 → 馬路（2 條斑馬線）→ 人行道 → **碼頭水泥地 `quay_concrete`**（暫代 `plaza`）→ **岸緣 `quay_edge`**（暫代 `boards`）→ **港區海水 `water_harbor`**（暫代 `water`）。三種新地磚交件後，資料不用改，加進 `atlas.png` 和 `atlas.json` 就會換上 |
| 可進入建築 | `pier7_warehouse` Pier 7 倉庫（**在倉庫裡租**：櫃台開租約視窗；租下後是第二個庫存地點，有打包檯，見 `13_core_loop_and_work.md`）· `dockside_motors` Dockside Motors（Sam Okoro 賣第一台貨車，見 `09_vehicles.md`）· `harbor_point_fitness` Harbor Point Fitness（Rosa 的健身房：進得去、能看看櫃台和課表；她本人和會員還沒做）· `customs_house` Aurelia 海關大樓（**進不去**，門口的字說明「進口許可與清關還沒納入這個版本」；資料欄位 `closed_reason`） |
| 填充建築 | `warehouse_shed`（暫代 `shop_row_awning`）· `cold_store`（暫代 `retail_arcade`）· `container_stack`（暫代 `riverside_walkup`） |
| 立面暫代 | `pier7_warehouse` → `brick_shops` · `dockside_motors` → `byte_bean` · `harbor_point_fitness` → `popup_unit` · `customs_house` → `civic_annex`；招牌字由程式畫 |
| 街道物件 | 已放（有合理的暫代）：`harbor_lamp`（暫代 `lamp`）、`mooring_bollard`（暫代 `bollard`）、`crate` 和 `pallet_stack`（暫代 `product_parcel` 紙箱）、路錐、長椅、垃圾桶、岸邊欄杆 `railing`、門口的停車收費柱。**還沒放**（沒有不突兀的暫代，交件後加進 `gen_districts.py` 的 `harbor_quay()` 再跑一次）：`container_red` / `_blue` / `_green`、`forklift`、`rope_coil`、`life_ring`、`crane_gantry`（背景） |
| 路人 | 多穿 `logistics_site`、`courier`、`casual_jacket` |
| 出口 | 無（只能搭捷運，M3 港區線 ⇄ 河濱區，8 分鐘；到其他區 15–24 分鐘，寫在 `city/aurelia.json` 的 `travel_min`） |
| 捷運 | M3 |
| 街區資料 | `data/districts/harbor.json`（用 `tools/gen_districts.py harbor` 排版） |

---

## 規劃中的區域

以下是**設定稿**，程式和美術都還沒做（Harbor 已經開放，見上；它的設定稿保留在下面當美術清單）。每區都照上面的版型：一排建築、兩線道、一條特色帶。每區需要的美術清單在最後的「每區交付清單」。

### Harbor 港區 · `harbor` · P1（設定稿，已開放）

| 項目 | 設定 |
|------|------|
| 一句話 | 貨櫃、海關、貨運 |
| 主色 | `#4A8CE8` 藍 |
| 氣質 | 藍灰金屬、橘紅貨櫃、吊車、繩索、海鷗。清晨有霧，晚上是工作燈的冷白光 |
| 特色帶 | **碼頭**：岸壁、繫船柱、停靠的貨輪（背景）、貨櫃堆 |
| 可進入建築 | `pier7_warehouse` Pier 7 倉庫（可租倉儲，第二個庫存地點）· `customs_house` Aurelia 海關大樓（P2 進口關稅）· `haddad_trading` Haddad Trading 辦公室（Omar Haddad，P2 國際貿易）· `harbor_point_fitness` Harbor Point Fitness 健身房（Rosa 的店，現在只在手機出現） |
| 填充建築 | `warehouse_shed` 倉庫棚 · `cold_store` 冷凍倉 · `container_stack` 貨櫃堆（當建築用）· `crane_gantry` 岸邊吊車（高，當背景剪影） |
| 新街道物件 | `container_red` / `container_blue` / `container_green` 貨櫃、`pallet_stack` 棧板堆、`crate` 木箱、`mooring_bollard` 繫船柱、`rope_coil` 繩圈、`life_ring` 救生圈、`buoy` 浮標、`forklift`（停放）、`harbor_lamp` 高桿工作燈 |
| 車輛 | `truck` 貨櫃車、`forklift`、`van` 送貨車 |
| NPC | Omar Haddad、Rosa Lim、Ines Duarte（海關） |
| 捷運 | M3 |
| 音樂 | 低音、慢節奏；環境音有海鷗、船笛、金屬碰撞 |

### Old Town 老城區的後續建築 · P1–P3

Old Town 本身已開放（見上）。以下是設定稿裡**還沒做**的部分：

| 項目 | 設定 |
|------|------|
| 尚未開放的建築 | `gallery_nine` Gallery Nine 藝廊（買收藏品裝潢）· `ember_print` Ember 印刷行（P3 媒體業、行銷印刷品）· `corner_workshop` 轉角工坊（P3 小量製造） |
| 尚未開放的玩法 | Studio 1A（`old_town_studio`）目前只能參觀。搬進去、降級住宅（公司倒閉後的去處）是**規劃中** |
| 美術已交（B3） | `mural_wall`、`ivy_trellis`、`old_lamp`（含發光層）、`bookstall`、`cafe_chairs_bistro`、地磚 `cobble_a` / `cobble_b`；地點卡四張。原尺寸／4× 版本均已交 |
| 選配背景待畫 | 老城天際線 `skyline_old_town_day` / `_night`；地點卡已交（見 [90 工單 B3](90_codex_art_backlog.md#b3-老城區咖啡店產業)） |
| 捷運 | 已開放（M5 Loop Line 的最後一站） |
| 音樂 | 規劃：爵士吉他、手風琴（現在沿用 `day_city`） |

### Residential 住宅區 · `residential` · Implemented #65

已開放 Maple Court、Birch Row、Harlow & Finch、Lot 7 與 M5 Loop／Old Town 步行連接。房產玩法見 [房地產](20_real_estate.md)。下表的 FreshMart、社區中心、Maya 搬家及公園物件保留為後續生活擴充規劃。

| 項目 | 設定 |
|------|------|
| 一句話 | 學校、公園、家庭 |
| 主色 | `#5EC46A` 綠 |
| 氣質 | 中層公寓、陽台、晾衣、樹蔭、溜滑梯。週末早上最熱鬧 |
| 特色帶 | 社區公園和遊樂場 |
| 可進入建築 | `maple_court` Maple Court 公寓（**住宅第 2 階**；Maya 的新家，支線「幫 Maya 搬家」）· `freshmart` FreshMart 超市（生活費、買日用品）· `community_center` 社區中心（活動、招募兼職員工） |
| 填充建築 | `apartment_balcony` 陽台公寓 · `townhouse_row` 連棟透天 · `school_front` 小學正門（不可進入） |
| 新街道物件 | `swing_set` 鞦韆、`slide` 溜滑梯、`sandbox` 沙坑、`basketball_hoop` 籃球架、`mailbox_bank` 信箱牆、`laundry_line` 晾衣繩（陽台用） |
| 捷運 | M5 Loop 已開放；另有 Old Town 步行出口 |
| 音樂 | 溫暖木吉他 |

### University 大學區 · `university` · P1

Implemented #66: M1 connects the district. Enter `aurelia_university`, `the_loft`, `campus_radio`; mentor Dr. Imani Cole, Kai Morgan and Nia Park provide client/recruitment access. Full current media workflow is in [21_media.md](21_media.md). The older institute/innovation-lab and M2 extension concepts below remain future art/world requests.

| 項目 | 設定 |
|------|------|
| 一句話 | 研究和人才 |
| 主色 | `#4AB8C8` 青 |
| 氣質 | 草坪、紅磚老校舍和玻璃研究大樓並排，學生、腳踏車、社團攤位 |
| 特色帶 | 校園大草坪，學生坐著讀書 |
| 可進入建築 | `aurelia_institute` Aurelia Institute of Technology 主館（就業博覽會：招募實習生和員工）· `innovation_lab` 創新實驗室（P3 研發合作；Prof. Hana Sato） |
| 填充建築 | `lecture_hall` 講堂 · `library_front` 圖書館正面 · `dorm_block` 宿舍 |
| 新街道物件 | `bike_rack` 腳踏車架、`club_booth` 社團攤位、`campus_sign`（無字）、`lawn_students`（放 NPC 用，無圖） |
| NPC | Prof. Hana Sato、學生路人（新服裝 `student`） |
| 捷運 | 規劃延伸 M2 |
| 音樂 | 明亮 lo-fi |

### Luxury Heights 豪宅區 · `luxury_heights` · P3

Implemented #67: M5 connects the district. Enter `the_aster`, `skyline_grand`, `observation_deck`; Henri Dubois, Priya Nair, Owen Blake and Vera Stone support the hotel business. Full workflow in [22_hotel.md](22_hotel.md). The penthouse, villa, club, motors and Aurum dining concepts below remain future requests.

| 項目 | 設定 |
|------|------|
| 一句話 | 頂樓豪宅、俱樂部、高級餐廳 |
| 主色 | `#B46BE0` 紫（只用在點綴） |
| 氣質 | 參考 Board D：黃昏天際線、玻璃頂樓、泳池、門僮。安靜、昂貴 |
| 可進入建築 | `skyline_penthouse` 頂樓豪宅（住宅第 4 階）· `hillside_villa` 山坡別墅（住宅第 5 階）· `meridian_club` Meridian 會員俱樂部（Victor Hale）· `crown_motors` Crown Motors 名車展示中心 · `aurum_dining` Aurum 高級餐廳 |
| 新街道物件 | 門僮亭、修剪整齊的樹、噴泉、代客泊車牌 |
| NPC | Victor Hale |
| 捷運 | M5 |

### International Airport 國際機場 · `airport` · P2

| 項目 | 設定 |
|------|------|
| 一句話 | 國內、國際、貨運、私人航空 |
| 可進入 | `terminal_international` 國際航廈（買機票、出國）· `cargo_terminal` 貨運站（空運）· `private_aviation` 私人航空貴賓室（P3 私人飛機） |
| 外觀 | 大片玻璃航廈、停機坪上的飛機（背景）、塔台 |
| 捷運 | M4 |
| 特殊 | 版型可以改成「航廈內部就是街區」，不一定要有馬路 |

### Industrial Zone 工業區 · `industrial` · P3

| 項目 | 設定 |
|------|------|
| 一句話 | 工廠和原料 |
| 主色 | `#8A93A6` 灰 |
| 可進入 | `factory_unit` 可租廠房（小量 OEM）· `solaris_energy` Solaris 太陽能公司（第 8 章綠色轉型）· `materials_yard` 原料場 |
| 外觀 | 鋸齒屋頂廠房、煙囪（白色水蒸氣，不是黑煙）、太陽能板、卡車裝卸口 |

---

## 現有區域的規劃中建築

| id | 名稱 | 區域 | 優先 | 用途 |
|----|------|------|------|------|
| `northlight_capital` | Northlight Capital | Financial | P1 | Elena Park 的創投辦公室（第 6 章簽約地點） |
| `launchpad_accelerator` | Launchpad 育成中心 | Startup Hub | P1 | 加速器計畫、Demo Day |
| `horizon_labs`（改為可進入） | Horizon Labs 3F | Startup Hub | P1 | **辦公第 3 階**：整層新創辦公室 |
| `tax_office` | Aurelia 稅務局（沿用 `civic_annex` 立面） | Civic Center | P2 | 報稅、罰款、合規 |
| `metro_station_interior` | 捷運月台 | 全部 | P1 | 搭車時的過場畫面 |
| `quay_residences` | The Quay Residences | Riverside | P3 | **住宅第 3 階**：河岸高級公寓 |

## 每區交付清單（新區域的美術最低需求）

開一個新區域需要：

| 類型 | 數量 | 規格 |
|------|------|------|
| 可進入建築立面 + `_lights` | 2–5 | 見 [04 建築外觀](04_buildings.md) |
| 填充建築 + `_lights` | 3–4 | 同上 |
| 區域特色街道物件 | 6–10 | 見 [06 家具與裝潢](06_furniture_decor.md#規劃中的街道物件) |
| 地磚（如果需要新地面） | 2–4 | 16×16，加進 `tiles/atlas.png` 和 `atlas.json` |
| 地點卡 | 1 張區域卡 + 每棟可進入建築 1 張 | `cards/<id>.png` 192×108 |
| 城市地圖縮圖 | 已有 | `city_map/i_<id>.png` 144×90（已有，定稿時重繪） |
| 室內場景 | 每棟可進入建築 1 個 | 見 [05 室內場景](05_interiors.md) |
| 天際線（選配） | 0–1 對 | 如果和共用的 `skyline_day/night` 差太多（例如港區） |

## Harbor 美術交付 B2 · 2026-09-30

美術：已交；街區、NPC 排程、租倉與買貨車玩法待 Claude 線接入。七棟立面、港口日夜天際線、吊車、十款街道物件、三款地磚、三張地點卡及送貨地圖均完成。地磚僅追加 atlas 第 5 行（0,5）–（2,5）；原 38 格像素及座標保留。B3 PR 使用第 4 行兩個空格，合併兩批時須保留各自新增格。

## 戶外地面美術品質更新 · 2026-10-01

美術狀態：28 個戶外地磚格重新製作，涵蓋七個已實作街區的道路、鋪面、草地、水面、木步道及老城／港區特色材質。`tiles/atlas.png` 128×96 和 `world_detail/tiles/atlas.png` 512×384，均附 import；atlas 的 43 個座標不動，15 格室內及 5 個空位像素保持原樣。原畫、提示詞、SVG 與逐格保全／接縫檢查在 `docs/art_sources/ground_materials_20261001/`。

原尺寸替換已由既有 TileMap 載入；4× atlas 仍需 Claude 保持 16×16 邏輯尺寸接入高解析投影。七街區日夜實拍和改前／改後在 `evidence/20261001_ground_materials/`。此狀態只涵蓋本批地面，其他獨立 Draft 的角色、車流與建築尚須整合驗收。

## 地圖美術品質批 · 2026-10-01

美術：25 個城市／世界／捷運素材的原尺寸及 4× 已交，含匯入檔。城市主圖、12 個街區選取、8 個世界區域選取與捷運原生 UI 已驗收（英文與繁中），53 張實拍巡禮 0 失敗。其餘一張車站預覽和備用世界背景只交素材，沒有 runtime call site。點位、地圖資料和狀態未改。高解析載入仍待 Claude 接線，須保留邏輯尺寸與點擊座標。證據：`evidence/20261001_map_quality/README.md`。

