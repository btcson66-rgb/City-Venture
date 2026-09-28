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
| 出口 | 東 → Financial |
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

---

## 規劃中的區域

以下是**設定稿**，程式和美術都還沒做。每區都照上面的版型：一排建築、兩線道、一條特色帶。每區需要的美術清單在最後的「每區交付清單」。

### Shopping Street 購物街 · `shopping_street` · P1

| 項目 | 設定 |
|------|------|
| 一句話 | 零售、餐廳、夜生活 |
| 主色 | `#E2649A` 玫瑰 |
| 氣質 | 行人徒步街加一段馬路。雨遮、櫥窗、串燈。晚上是暖色招牌（**克制，不是霓虹**），週末有市集攤位 |
| 特色帶 | 徒步廣場＋週末市集（攤位白天出現、晚上收起） |
| 可進入建築 | `threadline_apparel` Threadline 服飾店（**衣櫃系統**：買 Executive、Luxury Citywear、Travel、Formal 服裝）· `crestline_flagship` Crestline 百貨旗艦店（Daniel 公司的門市，看得到玩家的檯燈上架）· `lantern_bistro` Lantern Bistro 餐廳 · `popup_unit` Pop-up Unit 5 可租的快閃店面（P3 零售/咖啡業） |
| 填充建築 | `retail_arcade` 騎樓商場 · `shop_row_awning` 雨遮店排 · `cinema_front` 電影院門面 |
| 新街道物件 | `market_stall` 市集攤（3 色）、`string_lights` 串燈（夜間發光）、`kiosk_flower` 花攤、`planter_long` 長花台、`bike_rack` 腳踏車架、`street_performer_spot` 街頭藝人位置標記（放 NPC 用，無圖） |
| NPC | Nina（Threadline 店員） |
| 捷運 | M5 |
| 音樂 | 輕快 city pop，晚上轉 lounge |

### Harbor 港區 · `harbor` · P1

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

### Old Town 老城區 · `old_town` · P1

| 項目 | 設定 |
|------|------|
| 一句話 | 低租金、老店、藝術 |
| 主色 | `#D8A24A` 琥珀 |
| 氣質 | 紅磚、石板路、拱廊、爬藤、老招牌、壁畫。傍晚最美 |
| 特色帶 | 石板路小廣場、鐘樓、壁畫牆 |
| 可進入建築 | `old_town_studio` 老城套房（最便宜的住處；公司倒閉後的「降級住宅」）· `okafor_lettings` Okafor 租屋行（房東 Mr. Okafor）· `gallery_nine` Gallery Nine 藝廊（買收藏品裝潢）· `ember_print` Ember 印刷行（P3 媒體業、行銷印刷品）· `corner_workshop` 轉角工坊（P3 小量製造） |
| 填充建築 | `rowhouse_brick` 紅磚連棟屋 · `arcade_arches` 拱廊 · `clock_tower` 鐘樓（地標） |
| 新街道物件 | `cobble` 地磚（新 tile）、`mural_wall` 壁畫牆（無字）、`ivy_trellis` 爬藤架、`old_lamp` 鑄鐵路燈、`bookstall` 舊書攤、`cafe_chairs_bistro` 小圓桌 |
| NPC | Mr. Okafor（現在只在手機出現） |
| 捷運 | 無（從 Civic Center 走過去） |
| 音樂 | 爵士吉他、手風琴 |

### Residential 住宅區 · `residential` · P1

| 項目 | 設定 |
|------|------|
| 一句話 | 學校、公園、家庭 |
| 主色 | `#5EC46A` 綠 |
| 氣質 | 中層公寓、陽台、晾衣、樹蔭、溜滑梯。週末早上最熱鬧 |
| 特色帶 | 社區公園和遊樂場 |
| 可進入建築 | `maple_court` Maple Court 公寓（**住宅第 2 階**；Maya 的新家，支線「幫 Maya 搬家」）· `freshmart` FreshMart 超市（生活費、買日用品）· `community_center` 社區中心（活動、招募兼職員工） |
| 填充建築 | `apartment_balcony` 陽台公寓 · `townhouse_row` 連棟透天 · `school_front` 小學正門（不可進入） |
| 新街道物件 | `swing_set` 鞦韆、`slide` 溜滑梯、`sandbox` 沙坑、`basketball_hoop` 籃球架、`mailbox_bank` 信箱牆、`laundry_line` 晾衣繩（陽台用） |
| 捷運 | 無（規劃公車站） |
| 音樂 | 溫暖木吉他 |

### University 大學區 · `university` · P1

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
