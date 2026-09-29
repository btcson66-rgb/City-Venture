# 05 室內場景

## 室內的共同規格

資料在 `game/data/buildings/<id>.json` 的 `interior`。畫面由 `scripts/world/interior.gd` 組裝：

```
┌──────────────────────────────────────────────┐ y=0
│ 牆（3 格高 = 48 px）：wall_<材質> 地磚       │  ← 窗戶、招牌、畫、壁燈掛這裡（"wall": true）
├──────────────────────────────────────────────┤ y=48
│                                              │
│ 地板：interiors/floor_<材質>.png（大圖）     │  ← 家具、櫃台、NPC、互動點
│ 沒有大圖時用 tiles 的 floor_<材質> 地磚      │
│                                              │
│                 [ door_mat ]                 │  ← 出口：程式自動放在底部中央，並加脈動的 EXIT 標記
└──────────────────────────────────────────────┘
```

- 尺寸以 16 px 格子計。最大的是市政廳 32×17 格（512×272 px）。
- **地板大圖** `floor_*.png` 是 512×320 的不重複地板，程式從左上角裁切需要的大小。新地板照這個尺寸做。
- 家具位置是資料，不是美術。要移動家具就改 JSON，不要改圖。
- 家具比地面佔位大（例如高櫃、床）時，把佔位寫進 `game/assets/sprite_meta.json`：`dw`/`dh` 是碰撞佔位大小，`left`/`top` 是偏移。
- `"glow": true` 的物件（吊燈、壁燈）晚上會疊 `effects/glow_*`。
- `"night": "window_night"` 的窗戶會依時間切換。
- **互動點**（interactables）是看不見的區塊，玩家靠近時出現按鍵提示。要讓玩家知道能互動，靠的是那裡的家具本身。

### 目前的地板與牆

| 材質 id | 地板大圖 | 地磚 | 用在 |
|---------|----------|------|------|
| `wood_warm` | `floor_wood_warm.png` ✓ | ✓ | 公寓、Bloom Coffee、Nexus Co-work |
| `wood_dark` | `floor_wood_dark.png` ✓ | ✓ | Suite 2B |
| `wood_cafe` | `floor_wood_cafe.png` ✓ | ✓ | Bean & Byte |
| `marble` | `floor_marble.png` ✓ | ✓ | 市政廳、Nexus Bank |
| `concrete` | `floor_concrete.png` ✓ | ✓ | （備用：倉庫、工坊） |
| `tile_white` | ✗ | ✓ | PostPoint |
| `checker` | ✗ | ✓ | （備用：餐廳、老城咖啡） |
| `carpet_navy` | ✗ | ✓ | （備用：高級辦公室、俱樂部） |

| 牆 id | 用在 | 備註 |
|-------|------|------|
| `plaster_warm` | 公寓 | 程式另外畫踢腳板和頂線 |
| `brick` | Bloom Coffee、Suite 2B | |
| `wood_panel` | Bean & Byte | |
| `marble_wall` | 市政廳、Nexus Bank | |
| `white_modern` | Nexus Co-work、PostPoint | |
| `navy_panel` | （備用） | |
| `concrete_wall` | （備用） | |

**A2 美術更新（2026-09-28）**：現有五張 512×320 地板保留較細的原始紋理並柔化色階；新增 `floor_tile_white.png`、`floor_checker.png`、`floor_carpet_navy.png` 三張同尺寸地板。七款牆磚已在 atlas 的原格位更新，家具與牆磚的尺寸、佔位資料不變。八個現有室內場景的改前／改後實機畫面及日夜窗戶見 `evidence/2026-09-28_a2_interiors/`。

---

## 已完成的室內（8 個）

### 1. Riverside Tower 7C（玩家的家）· `riverside_apartment`

| 項目 | 內容 |
|------|------|
| 大小 | 24×15 格（384×240） · 地板 `wood_warm` · 牆 `plaster_warm` |
| 營業 | 24 小時 |
| 氣質 | 剛搬進來的小套房：一張床、一台筆電、一張打包桌，紙箱越堆越多。溫暖、有點亂、有希望 |
| 家具 | `bed` · `desk_laptop` · `chair` · `sofa` · `coffee_table` · `tv` · `bookshelf` · `kitchen` · `fridge` · `wardrobe` · `packing_table` · `plant` · `plant_big` · `rug` · `framed_art` · `framed_art_b` · `window_day`/`window_night` |
| 互動 | 筆電 → Company OS · 床 → 睡覺 · 衣櫃 → 換衣服 · 打包桌 → 打包出貨 |
| 庫存顯示 | 家裡每 10 件庫存堆一個 `box`（最多 20 個，5 個一排往上疊），在 x=300, y=112 |
| 升級規劃 | 住宅階梯：7C 套房 → Maple Court 公寓 → Quay Residences → 頂樓豪宅 → 別墅（見下方規劃） |

### 2. Bloom Coffee · `bloom_coffee`

| 項目 | 內容 |
|------|------|
| 大小 | 26×16 格 · 地板 `wood_warm` · 牆 `brick` |
| 營業 | 每天 07:00–20:00 |
| 氣質 | 河岸的社區咖啡店：紅磚牆、吊燈、軟木板上貼滿傳單，是玩家第一個「社交場所」 |
| 家具 | `cafe_counter` · `display_case` · `menu_board` · `logo_bloom` · `cafe_table` ×4 · `cafe_chair` ×8 · `hanging_light` ×4 · `sconce` · `framed_art` · `cork_board` · `plant_big` ×2 · `rug_small` · `window_day` ×2 |
| 互動 | 點咖啡（$4.50）· 讀新聞板 · 用筆電開 Company OS · 員工門（咖啡師打工） |
| NPC | Jun（櫃台）、Maya（週末的窗邊桌） |

### 3. Bean & Byte · `byte_and_bean`

| 項目 | 內容 |
|------|------|
| 大小 | 20×13 格 · 地板 `wood_cafe` · 牆 `wood_panel` |
| 營業 | 每天 07:00–19:00 |
| 氣質 | 新創園區的科技咖啡店：木牆、筆電、插座很多 |
| 家具 | `cafe_counter` · `menu_board` · `logo_bytebean` · `cafe_table` · `cafe_chair` · `hanging_light` · `framed_art_b` · `plant_big` · `plant_bank` · `window_day` |
| 互動 | 點燕麥拿鐵（$5.20）· 用筆電開 Company OS |
| NPC | Lee（櫃台） |

### 4. Nexus Co-work · `nexus_cowork`

| 項目 | 內容 |
|------|------|
| 大小 | 30×18 格 · 地板 `wood_warm` · 牆 `white_modern` |
| 營業 | 每天 07:00–22:00 |
| 氣質 | 明亮開放的共享辦公：櫃台、長桌、電話亭、玻璃會議室、休息區沙發 |
| 家具 | `exec_desk`（櫃台）· `monitor_desk` · `office_chair` · `community_table` · `glass_wall` · `phone_booth` · `lockers` · `printer` · `water_cooler` · `lounge_sofa` · `coffee_table` · `cork_board` · `logo_cowork` · `framed_art` · `framed_art_b` · `plant_big` · `plant_bank` · `rug_navy` · `window_day` |
| 互動 | 櫃台 → 租桌、日票 · 共享桌 → Company OS · **Business Board**（選事業、找打工）· 員工門 |
| NPC | Priya（櫃台）· Ken（週二、四）· Elena（週三）· Daniel（週四傍晚） |

### 5. 22 Founders Lane, Suite 2B（玩家的辦公室）· `small_office`

| 項目 | 內容 |
|------|------|
| 大小 | 24×15 格 · 地板 `wood_dark` · 牆 `brick` |
| 營業 | 08:00–20:00；租下後 24 小時 |
| 氣質 | 紅磚牆、深色木地板的小辦公室，會從空蕩蕩變成坐滿員工。白板上現在是手繪圖表和便條，沒有可讀的字。定稿可以分成四塊，對應概念板的 IDEAS / PEOPLE / PRODUCT / GROWTH，但要用圖示代替文字 |
| 家具 | `exec_desk` · `monitor_desk` · `office_chair` · `whiteboard` · `bookshelf` · `filing_cabinet` · `packing_table` · `plant_big` · `rug_navy` · `framed_art` · `window_day` · **`company_sign`**（程式畫：牆上的公司名牌） |
| 互動 | 辦公桌 → Company OS · 白板 · 打包桌 |
| 員工位置 | 1 個打包員位置、5 個辦公桌位置（依雇用人數出現） |
| 庫存顯示 | 同家裡，x=292, y=112 |
| NPC | Tom（租賃仲介，週一到六 9–18） |

### 6. Nexus Bank · `nexus_bank`

| 項目 | 內容 |
|------|------|
| 大小 | 30×16 格 · 地板 `marble` · 牆 `marble_wall` |
| 營業 | 週一到五 09:00–16:00 |
| 氣質 | 大理石、金色點綴、安靜。排隊欄杆和候位沙發，右後方是經理的辦公桌 |
| 家具 | `bank_counter` · `atm` · `queue_barrier` · `waiting_sofa` · `exec_desk` · `office_chair` · `filing_cabinet` · `brochure` · `logo_nexus_bank` · `framed_art_b` · `plant_big` · `rug_navy` · `sconce` · `window_day` |
| 互動 | 櫃台 → 企業帳戶 · ATM → 餘額 · 讀「小企業貸款」DM · 員工門（銀行櫃員打工） |
| NPC | Sofia（櫃台）· Marcus Reed（經理桌，週一到五 13–16） |

### 7. Aurelia City Hall · `city_hall`

| 項目 | 內容 |
|------|------|
| 大小 | 32×17 格（最大）· 地板 `marble` · 牆 `marble_wall` |
| 營業 | 週一到五 09:00–17:00 |
| 氣質 | 挑高大廳、市徽、長椅、取號機。公家機關，但明亮友善 |
| 家具 | `civic_counter` · `ticket_machine` · `info_kiosk` · `bench_civic` · `seal` · `logo_city_hall` · `framed_art` · `plant_big` · `rug_navy` · `sconce` · `window_day` |
| 互動 | 登記櫃台 → 公司登記 · 取號 · 許可與法規（雇主登記）· 員工門（市政職員打工） |
| NPC | Ana（櫃台） |

### 8. PostPoint · `postpoint_riverside`

| 項目 | 內容 |
|------|------|
| 大小 | 18×12 格（最小）· 地板 `tile_white` · 牆 `white_modern` |
| 營業 | 每天 08:00–21:00 |
| 氣質 | 小而忙的寄件門市：包裹架、秤、紅色識別 |
| 家具 | `postpoint_counter` · `parcel_shelf` · `brochure_stand` · `logo_postpoint` · `plant` |
| 互動 | 寄件 · 員工門（包裹分揀打工） |
| NPC | Dara（櫃台） |

---

## 規劃中的室內

每個室內列出**需要的家具**。已有的家具直接用，**粗體**是要新畫的（規格見 [06 家具與裝潢目錄](06_furniture_decor.md)）。

### 住宅階梯（P1–P3）

| id | 名稱 | 階 | 大小（格） | 地板 / 牆 | 家具 | 互動 |
|----|------|----|-----------|-----------|------|------|
| `riverside_apartment` | Riverside Tower 7C | 1 | 24×15 | wood_warm / plaster_warm | （已完成） | 筆電、床、衣櫃、打包桌 |
| `maple_court_apartment` | Maple Court 4A | 2 | 28×16 | wood_warm / plaster_warm | 現有住家組 + **`bed_double`**、**`dining_table`**、**`bookshelf_tall`**、**`balcony_door`** | 同上 + 招待朋友 |
| `quay_residence` | The Quay 12F | 3 | 32×17 | wood_dark / white_modern | **`sofa_l`**、**`kitchen_island`**、**`tv_wall`**、**`art_large`**、**`home_office_corner`**、`window_wide_day` | 同上 + 居家辦公角 |
| `skyline_penthouse` | Skyline Penthouse | 4 | 36×18 | marble / white_modern | **`bar_counter`**、**`piano`**、**`home_gym`**、**`collection_case`**、**`pool_edge`**（牆上的窗外泳池）、`window_wide_night` | 同上 + 收藏櫃 |
| `hillside_villa` | Hillside Villa | 5 | 40×18 | wood_warm / white_modern | 上面全部 + **`fireplace`**、**`garage_door`**（車庫）、**`library_wall`** | 同上 + 車庫 |
| `old_town_studio` | Old Town Studio | 0 | 18×12 | wood_dark / brick | `bed`（舊）、`desk`、`chair`、**`hot_plate`**、`box` | 公司倒閉後的「降級住宅」：小、舊，但有窗外的老城夕陽 |
| `wardrobe_room` | 更衣室 | 3+ | 14×10 | carpet_navy / white_modern | **`clothing_rack`**、**`mirror_full`**、**`shoe_shelf`**、`wardrobe` | 換衣服（大房子的衣櫃互動升級版） |

### 辦公階梯（P1–P3）

| id | 名稱 | 階 | 大小（格） | 家具 | 員工位置 |
|----|------|----|-----------|------|---------|
| `nexus_cowork` | 共享桌 | 1 | （已完成） | — | 0 |
| `small_office` | Suite 2B | 2 | （已完成） | — | 6 |
| `horizon_labs_3f` | Horizon Labs 3F | 3 | 36×18 | 現有辦公組 + **`reception_desk`**、**`meeting_table`**、**`pantry`**、`server_rack`、`glass_wall`、**`staff_desk_pod`**（四人桌） | 16 |
| `finance_tower_hq` | Arc Tower 28F 總部 | 4 | 40×18 | **`exec_desk_premium`**、**`boardroom_table`**、**`reception_logo_wall`**、`carpet_navy`、`window_wide_night` | 30 |
| `logistics_control_room` | 物流控制室 | P3 | 24×14 | **`control_screens`**（大型螢幕牆，內容用色塊）、`monitor_desk` ×4 | 4 |

### Shopping Street（已實作 · 2026-09-29）

四間都能進去。**Threadline 的家具全部是 Codex B1 正式圖。**其他三間先用現有家具暫代，粗體的新家具到位後替換：Crestline 用衣架、鞋架、假人、小茶几（燈具展示台暫代）；Lantern Bistro 用咖啡店的桌椅、吧台和廚房；Pop-up 是放了幾個紙箱的空房。

| id | 名稱 | 大小（格） | 地板 / 牆 | 家具 | 互動 | NPC |
|----|------|-----------|-----------|------|------|-----|
| `threadline_apparel` | Threadline | 24×14 | wood_dark / white_modern | **`clothing_rack`** ×4、**`mannequin`** ×3（可換裝色）、**`fitting_room`**、**`checkout_counter`**、**`mirror_full`**、**`shoe_shelf`**、`plant_big` | 已實作：逛衣架 → 買衣服（Executive、Luxury Citywear、Travel、Formal Evening、Logistics/Site）· 試衣間換裝 | Nina（10–21） |
| `crestline_flagship` | Crestline 旗艦店 | 30×16 | marble / white_modern | **`retail_shelf`** ×4、**`display_table`**、**`checkout_counter`** ×2、**`escalator`**（背景）、**`lamp_display`**（玩家的檯燈陳列）| 已實作：看燈具展示台（第 5 章交貨後出現玩家的 LED 檯燈）· 週末和 Daniel 見面 | Daniel（接洽大訂單後，週六日 11–16） |
| `lantern_bistro` | Lantern Bistro | 22×14 | checker / brick | **`dining_table`** ×4、**`bar_counter`**、**`kitchen_pass`**、`hanging_light` ×4、`menu_board`、`plant` | 已實作：點招牌套餐 $22（50 分鐘，計入「餐飲」）· 規劃：和 NPC 約飯 | 用餐客人（路人）；服務生規劃中 |
| `popup_unit` | Pop-up Unit 5 | 16×11 | concrete / white_modern | 空房 → 租下後：**`retail_shelf`**、**`checkout_counter`**、`box` | 已實作：看租約公告 · 規劃：開實體店（P3） | — |

### Harbor（P1–P2）

| id | 名稱 | 大小（格） | 地板 / 牆 | 家具 | 互動 | NPC |
|----|------|-----------|-----------|------|------|-----|
| `pier7_warehouse` | Pier 7 Warehouse | 32×18 | concrete / concrete_wall | **`pallet_rack`** ×4（庫存越多越滿）、**`packing_line`**、**`forklift`**、**`loading_dock_door`**、`box`、`packing_table` | 第二個庫存地點、大量打包、雇倉管 | 倉管員工 |
| `customs_house` | 海關大樓 | 26×15 | marble / marble_wall | `civic_counter`、`ticket_machine`、`bench_civic`、**`xray_scanner`**、**`customs_crates`** | 報關、繳關稅（P2） | Ines Duarte |
| `haddad_trading` | Haddad Trading | 22×14 | wood_dark / brick | `exec_desk`、**`world_map_wall`**（無字）、**`sample_crates`**、`lounge_sofa`、**`tea_set`** | 海外供應商、國際合約（P2） | Omar Haddad |
| `harbor_point_fitness` | Harbor Point Fitness | 26×14 | **`rubber_floor`**（新）/ white_modern | **`treadmill`** ×3、**`weight_rack`**、**`yoga_mat`** ×3、**`reception_desk`**、`water_cooler`、`lockers` | 運動（生活）、和 Rosa 談 B2B 訂單 | Rosa Lim |

### Old Town（P1）

| id | 名稱 | 大小（格） | 地板 / 牆 | 家具 | 互動 | NPC |
|----|------|-----------|-----------|------|------|-----|
| `okafor_lettings` | Okafor Lettings | 16×11 | wood_dark / wood_panel | `exec_desk`、`filing_cabinet`、**`listing_board`**（房屋照片用色塊）、`chair` | 租屋、換住處、退租 | Mr. Okafor |
| `gallery_nine` | Gallery Nine | 24×13 | concrete / white_modern | **`art_large`** ×5、**`sculpture_plinth`** ×2、**`gallery_bench`** | 買收藏品（裝潢用） | 藝廊員（路人） |
| `ember_print` | Ember Print | 18×12 | concrete / brick | **`printing_press`**、**`paper_rolls`**、**`poster_rack`**、`desk` | 印行銷品（P3 媒體業） | — |
| `corner_workshop` | Corner Workshop | 20×12 | concrete / brick | **`workbench`** ×2、**`tool_wall`**、**`3d_printer`**、`box` | 小量製造（P3） | — |

### Residential、University（P1）

| id | 名稱 | 大小（格） | 家具 | 互動 | NPC |
|----|------|-----------|------|------|-----|
| `freshmart` | FreshMart | 26×14 | **`grocery_shelf`** ×4、**`produce_stand`**、**`checkout_counter`** ×2、**`shopping_cart`**、`fridge` | 買日用品（生活費） | 收銀員 |
| `community_center` | 社區中心 | 22×13 | `bench_civic`、`cork_board`、**`folding_table`**、`bookshelf` | 社區活動、招募兼職 | — |
| `aurelia_institute` | AIT 主館 | 30×16 | `bench_civic`、`info_kiosk`、**`career_fair_booth`** ×3、`cork_board`、`plant_big` | 就業博覽會：招募實習生和員工 | 學生 |
| `innovation_lab` | 創新實驗室 | 26×14 | **`lab_bench`** ×3、`server_rack`、`whiteboard`、`monitor_desk`、**`prototype_display`** | 研發合作（P3） | Prof. Hana Sato |

### 其他（P1–P3）

| id | 名稱 | 優先 | 家具重點 | NPC |
|----|------|------|----------|-----|
| `northlight_capital` | Northlight Capital | P1 | `exec_desk`、**`boardroom_table`**、`lounge_sofa`、`art_large`、`window_wide_day` | Elena Park |
| `launchpad_accelerator` | Launchpad | P1 | `community_table`、**`stage`**（Demo Day 小舞台）、**`beanbag`** ×3、`whiteboard` | 導師（路人） |
| `metro_station_interior` | 捷運月台 | P1 | **`platform_edge`**、**`metro_bench`**、**`departure_board`**（程式畫字）、`metro_train` | 通勤路人 |
| `tax_office` | 稅務局 | P2 | `civic_counter`、`ticket_machine`、`bench_civic`、`filing_cabinet` | 稅務員 |
| `terminal_international` | 國際航廈 | P2 | **`checkin_counter`** ×3、**`seat_row`** ×4、**`departure_board`**、**`luggage_belt`**、`plant_big` | 旅客 |
| `cargo_terminal` | 貨運站 | P2 | `pallet_rack`、**`uld_container`**（航空貨櫃）、`forklift` | — |
| `private_aviation` | 私人航空貴賓室 | P3 | `lounge_sofa`、`bar_counter`、`window_wide_day`（窗外私人飛機） | — |
| `meridian_club` | Meridian Club | P3 | **`leather_armchair`** ×4、**`fireplace`**、`bar_counter`、**`billiard_table`**、`bookshelf` | Victor Hale |
| `crown_motors` | Crown Motors | P3 | **`car_turntable`**（放車輛 sprite）、`exec_desk`、`lounge_sofa` | 業務（路人） |
| `aurum_dining` | Aurum | P3 | `dining_table`（高級版 **`dining_table_fine`**）、**`wine_wall`**、`hanging_light` | 服務生 |
| `factory_unit` | 廠房 | P3 | **`assembly_line`**、**`qc_station`**、`pallet_rack`、`forklift` | 工人（新服裝 `site`） |
| `solaris_energy` | Solaris Energy | P3 | `monitor_desk`、**`solar_panel_sample`**、**`battery_rack`** | — |
