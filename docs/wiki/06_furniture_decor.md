# 06 家具與裝潢目錄

這一頁列出所有**室內家具**、**街道物件**和**地磚**：現有的每一件，加上規劃中要新畫的每一件。

- 室內家具：`game/assets/interiors/<id>.png`。街道物件：`game/assets/props/<id>.png`。
- 兩者放置方式相同（`scripts/world/world_scene.gd` → `add_prop`）：資料的 `x, y` 是佔位的**左上角**，前後遮擋依**底邊**排序。所以物件的底邊要畫在它「站在地上」的位置。
- 室內家具腳下由程式自動加一片影子（`effects/shadow`），不要畫進圖裡。
- 比地面佔位大的物件，要在 `game/assets/sprite_meta.json` 寫 `dw`、`dh`（碰撞大小）和 `left`、`top`（偏移）。目前有 30 筆。
- A2 美術批次已統一整理現有 68 張室內物件：保留相同尺寸與碰撞契約，修整表面色階，七項關鍵家具重畫。其他地區的物件仍依各批次持續精修。
- A4 美術批次精修現有 28 張街道物件（商品圖示除外）與 atlas 中 23 格地面磚；物件尺寸及 `sprite_meta.json` 不變。護柱、樹籬等高頻物件降低視覺重量，河水與馬路的重複紋理淡化；見 `evidence/2026-09-28_a4_streets/`。

---

## 室內家具（現有 73 張）

「用在」欄：家 = Riverside Tower 7C，Bloom = Bloom Coffee，B&B = Bean & Byte，銀行 = Nexus Bank，2B = Suite 2B，程式 = 由程式自動放置。

#### 功能點

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `desk_laptop` | 書桌加筆電 | 48×41 | 家 | **玩家的第一個 Company OS 入口**。筆電螢幕要亮，看得出是重點 |
| `packing_table` | 打包桌 | 48×34 | 2B 家 | **打包出貨的互動點**：膠帶、紙箱、秤 |
| `wardrobe` | 衣櫃 | 34×54 | 家 | **換衣服的互動點** |
| `whiteboard` | 白板 | 66×43 | 2B | 2B 的互動點 |

#### 櫃台

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `bank_counter` | 銀行櫃台 | 144×44 | 銀行 | A2 已重畫：木頭、金邊、玻璃隔板，與市政櫃台分開 |
| `brochure_stand` | DM 立架 | 18×30 | PostPoint |  |
| `cafe_counter` | 咖啡吧台 | 100×44 | B&B Bloom | 含咖啡機、磨豆機、收銀機 |
| `civic_counter` | 市政服務櫃台 | 144×44 | 市政廳 | A2 已重畫：淺色石材、01／02 號碼燈 |
| `display_case` | 甜點冷藏櫃 | 42×36 | Bloom |  |
| `postpoint_counter` | 寄件櫃台 | 80×44 | PostPoint | 含秤 |

#### 桌子

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `cafe_table` | 咖啡小圓桌 | 26×24 | B&B Bloom |  |
| `coffee_table` | 茶几 | 34×33 | Co-work 家 |  |
| `community_table` | 共享長桌 | 66×44 | Co-work | 上面有筆電和杯子 |
| `desk` | 書桌 | 44×37 | — | 備用。老城套房用 |
| `exec_desk` | 主管辦公桌 | 66×43 | 2B Co-work 銀行 | 共享辦公櫃台、銀行經理、2B 老闆桌共用 |
| `monitor_desk` | 雙螢幕辦公桌 | 66×36 | 2B Co-work | 員工坐的桌子 |

#### 座椅

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `armchair` | 單人扶手椅 | 22×24 | — | 備用。規劃給 Quay、俱樂部 |
| `bench_civic` | 市政長椅 | 48×20 | 市政廳 | 木面金屬腳 |
| `cafe_chair` | 咖啡椅 | 14×22 | B&B Bloom | 不擋路（solid: false） |
| `chair` | 木椅 | 22×27 | 家 |  |
| `lounge_sofa` | 休息區沙發 | 58×42 | Co-work |  |
| `office_chair` | 辦公椅 | 18×27 | 2B Co-work 銀行 |  |
| `sofa` | 雙人沙發 | 52×34 | 家 |  |
| `stool` | 高腳凳 | 12×16 | — | 備用。規劃給吧台 |
| `waiting_sofa` | 候位沙發 | 52×30 | 銀行 |  |

#### 收納

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `bookshelf` | 書櫃 | 34×52 | 2B 家 |  |
| `filing_cabinet` | 檔案櫃 | 20×36 | 2B 銀行 |  |
| `lockers` | 置物櫃 | 38×46 | Co-work |  |
| `parcel_shelf` | 包裹架 | 50×46 | PostPoint |  |

#### 住家

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `bed` | 單人床 | 52×58 | 家 | 第 1 階住家的床 |
| `fridge` | 冰箱 | 24×46 | 家 |  |
| `kitchen` | 小廚房 | 66×46 | 家 | 流理台加爐子 |
| `tv` | 電視 | 48×40 | 家 |  |

#### 辦公

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `printer` | 印表機 | 26×28 | Co-work |  |
| `server_rack` | 伺服器機櫃 | 24×40 | — | 備用。規劃給 Horizon Labs、實驗室（SaaS 的視覺） |
| `water_cooler` | 飲水機 | 14×34 | Co-work |  |

#### 銀行

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `atm` | 提款機 | 26×42 | 銀行 | 螢幕要有微光 |
| `brochure` | DM 架（桌上） | 16×30 | 銀行 |  |
| `queue_barrier` | 排隊欄杆 | 52×35 | 銀行 |  |

#### 市政

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `info_kiosk` | 資訊機台 | 22×36 | 市政廳 |  |
| `ticket_machine` | 取號機 | 20×36 | 市政廳 |  |

#### 隔間

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `glass_wall` | 玻璃會議室 | 68×52 | Co-work | 看得到裡面的會議桌 |
| `phone_booth` | 電話亭 | 28×48 | Co-work |  |

#### 植物

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `plant` | 小盆栽 | 18×30 | PostPoint 家 |  |
| `plant_bank` | 大型盆栽（銀行款） | 30×44 | B&B Co-work |  |
| `plant_big` | 大型盆栽 | 32×44 | 2B B&B Bloom Co-work 家 市政廳 銀行 |  |

#### 燈具

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `hanging_light` | 吊燈 | 16×30 | B&B Bloom | 晚上發光 |
| `sconce` | 壁燈 | 10×12 | Bloom 市政廳 銀行 | 晚上發光 |

#### 牆面

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `cork_board` | 軟木公佈欄 | 58×38 | Bloom Co-work | 便條用色塊，不要寫字 |
| `framed_art` | 掛畫 A | 20×16 | 2B Bloom Co-work 家 市政廳 |  |
| `framed_art_b` | 掛畫 B | 20×16 | B&B Co-work 家 銀行 |  |
| `menu_board` | 咖啡菜單板 | 66×34 | B&B Bloom | A2 已改為咖啡杯圖示與色塊，圖中無需翻譯的文字 |
| `seal` | 市徽 | 32×32 | 市政廳 | 藍底金環加「A」 |

#### 招牌

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `logo_bloom` | Bloom Coffee 牆面招牌 | 70×32 | Bloom | **圖裡有英文字**：品牌名不翻譯，屬於例外 |
| `logo_bytebean` | Bean & Byte 牆面招牌 | 70×32 | B&B | 同上 |
| `logo_city_hall` | CITY OF AURELIA 牆面招牌 | 77×32 | 市政廳 | 同上 |
| `logo_cowork` | NEXUS WORK · MEET · CREATE | 122×32 | Co-work | 同上 |
| `logo_nexus_bank` | NEXUS BANK 牆面招牌 | 70×32 | 銀行 | 同上 |
| `logo_postpoint` | POSTPOINT 牆面招牌 | 70×32 | PostPoint | 同上 |

#### 窗

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `window_day` | 窗（白天） | 52×42 | 2B B&B Bloom Co-work 家 市政廳 銀行 | 窗外是城市天際線 |
| `window_night` | 窗（夜晚） | 52×42 | （夜間切換） | 窗外亮燈 |
| `window_wide_day` | 寬窗（白天） | 96×48 | — | 備用。規劃給高階住宅和總部 |
| `window_wide_night` | 寬窗（夜晚） | 96×48 | — | 備用 |

#### 地面

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `door_mat` | 門口地墊 | 32×10 | 程式 | 程式自動放在每個室內的出口。要一眼看出「這裡是出口」 |
| `rug` | 地毯（暖色） | 64×40 | 家 |  |
| `rug_navy` | 地毯（海軍藍） | 64×40 | 2B Co-work 市政廳 銀行 |  |
| `rug_small` | 小地毯 | 40×24 | Bloom |  |

#### 庫存

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `box` | 紙箱 | 16×14 | 程式 | **庫存顯示**：每 10 件一個，疊起來。要能疊得好看（上下 9 px、左右 12 px） |

#### 地板

| id | 名稱 | 尺寸 | 用在 | 備註 |
|----|------|------|------|------|
| `floor_concrete` | 水泥地板 | 512×320 | 程式 | 512×320 大圖，備用 |
| `floor_marble` | 大理石地板 | 512×320 | 程式 | 512×320 大圖 |
| `floor_wood_cafe` | 咖啡館木地板 | 512×320 | 程式 | 512×320 大圖 |
| `floor_wood_dark` | 深色木地板 | 512×320 | 程式 | 512×320 大圖 |
| `floor_wood_warm` | 暖色木地板 | 512×320 | 程式 | 512×320 大圖 |

---

## 街道物件（現有 34 張）

#### 綠化

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `flower_bed` | 花圃 | 36×22 | 市政×2、河岸×2、新創×1 |  |
| `hedge` | 樹籬 | 48×20 | 市政×7、金融×7、河岸×4、新創×10 |  |
| `planter` | 大花台 | 36×32 | 市政×2、金融×4、新創×3 |  |
| `planter_small` | 小花台 | 24×28 | 金融×1、河岸×4、新創×6 |  |
| `tree_round` | 圓冠樹 A | 68×92 | 市政×9、金融×8、河岸×15、新創×10 |  |
| `tree_round_b` | 圓冠樹 B | 64×92 | 市政×5、金融×2、河岸×5、新創×6 |  |
| `tree_tall` | 高瘦樹 | 40×90 | 金融×2 |  |

#### 燈具

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `lamp` | 路燈 | 20×72 | 河岸×4、新創×3 | 晚上疊 glow |
| `lamp_banner` | 旗燈 | 20×72 | 市政×4、金融×5、河岸×6、新創×7 | 路燈加區域主色旗幟 |

#### 座椅

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `bench` | 公園長椅 | 36×25 | 市政×2、金融×1、河岸×3、新創×2 |  |
| `umbrella_table` | 洋傘桌（綠） | 36×38 | 河岸×2 | Bloom Coffee 門口 |
| `umbrella_table_blue` | 洋傘桌（藍） | 36×38 | 新創×2 | Bean & Byte 門口 |

#### 看板

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `billboard` | 大型看板 | 68×60 | 金融×1、河岸×1、新創×1 | 內容用色塊，不要寫字 |
| `business_board` | 戶外業務看板 | 44×56 | 新創×1 | Startup Hub 的地標，暗示室內的 Business Board |
| `cafe_board` | 咖啡立牌 | 16×22 | 河岸×1、新創×1 | A 字型黑板 |
| `digital_sign` | 數位看板 | 22×55 | 市政×1、金融×1、河岸×1、新創×1 | 螢幕微亮 |
| `direction_sign` | 方向指示牌 | 44×50 | 市政×1、金融×1、河岸×1、新創×1 | 箭頭，不寫字 |

#### 路邊

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `bollard` | 護柱 | 8×16 | 市政×30、金融×30、河岸×42、新創×41 | 數量最多的物件（每區 30–42 個），要低調 |
| `cone` | 三角錐 | 12×14 | — | 備用：施工、活動 |
| `hydrant` | 消防栓 | 10×16 | — | 備用 |
| `parking_meter` | 停車計時器 | 8×24 | — | 備用：P1 車輛系統 |
| `railing` | 河岸欄杆 | 64×14 | 河岸×30 | Riverside 河岸一整排 |
| `trash_bin` | 垃圾桶 | 18×22 | 市政×1、新創×1 |  |

#### 交通

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `bike` | 停放的腳踏車 | 36×22 | 市政×1、金融×1、河岸×2 |  |
| `bus_stop` | 公車亭 | 56×46 | 河岸×1 | 玻璃雨棚 |
| `metro_sign` | 捷運標誌柱 | 18×59 | — | 備用。目前捷運的 M 標誌畫在 metro_entrance 立面裡 |

#### 市政

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `flagpole` | 旗桿 | 22×66 | 市政×2 | 旗子規劃加 2 格飄動動畫 |
| `fountain` | 噴水池 | 68×44 | 市政×1、河岸×1 | 規劃加水花動畫 |

#### 商品

| id | 名稱 | 尺寸 | 用在（區域×數量） | 備註 |
|----|------|------|------------------|------|
| `product_coffee` | 咖啡杯 | 16×16 | — | 16×16，備用。見 [08](08_items.md) |
| `product_desk_lamp` | LED 檯燈 | 16×16 | — | 同上 |
| `product_earbuds` | 無線耳機 | 16×16 | — | 同上 |
| `product_parcel` | 包裹 | 16×16 | — | Company OS 的預設商品圖示 |
| `product_phone_stand` | 手機支架 | 16×16 | — | 同上 |
| `product_water_bottle` | 保溫瓶 | 16×16 | — | 同上 |

---

## 地磚（`tiles/atlas.png`，128×80，每格 16×16）

名稱對應的格子座標在 `tiles/atlas.json`。新增地磚要把 atlas 加大（寬維持 128，往下加列），並在 json 補座標。

| 類別 | 地磚 id |
|------|---------|
| 草地 | `grass` · `grass_flowers` · `garden` |
| 人行道、廣場 | `sidewalk` · `sidewalk_alt` · `plaza` · `plaza_alt` · `boards`（河岸木棧道） |
| 馬路 | `road` · `road_b` · `road_dash_h` · `road_dash_v` · `crosswalk_h` · `crosswalk_v` · `curb_top` · `curb_bottom` · `road_edge_top` · `road_edge_bottom` · `parking` · `manhole` |
| 水 | `water` · `water_alt` · `water_edge` |
| 室內地板 | `floor_wood_warm` · `floor_wood_dark` · `floor_wood_cafe` · `floor_tile_white` · `floor_checker` · `floor_carpet_navy` · `floor_marble` · `floor_concrete` |
| 室內牆 | `wall_plaster_warm` · `wall_brick` · `wall_navy_panel` · `wall_wood_panel` · `wall_marble_wall` · `wall_white_modern` · `wall_concrete_wall` |

**規劃新增地磚**

| id | 用在 | 優先 |
|----|------|------|
| `cobble` / `cobble_alt` | Old Town 石板路 | P1 |
| `quay` / `quay_edge` | Harbor 碼頭岸壁（水泥加黃色警示線） | P1 |
| `market_paving` | Shopping Street 徒步區 | P1 |
| `rubber_floor` | 健身房地板 | P1 |
| `lawn_campus` | University 草坪（修剪條紋） | P1 |
| `playground_soft` | Residential 遊樂場安全地墊 | P1 |
| `tarmac` | Airport 停機坪 | P2 |
| `floor_rubber` / `floor_terrazzo` / `floor_herringbone` | 健身房、航廈、高級住宅的地板大圖（512×320） | P1–P3 |
| `wall_glass_office` / `wall_green_club` / `wall_corrugated` | 總部、俱樂部、倉庫的牆 | P1–P3 |

---

## 規劃中的家具（要新畫的）

尺寸是建議值，照同類現有家具抓。畫好後用實際尺寸，比地面佔位大的寫進 `sprite_meta.json`。

### 住宅升級組（P1–P3）

住宅階梯每升一階，家具更大、更精緻。設計原則（企劃書 §33.2）：**裝潢是個人化、收藏和成就感，不是數值 buff**。只有少數家具是功能點。

| id | 名稱 | 建議尺寸 | 階 | 功能 |
|----|------|----------|----|------|
| `bed_double` | 雙人床 | 64×60 | 2 | 睡覺 |
| `dining_table` | 四人餐桌 | 56×40 | 2 | 裝飾 |
| `bookshelf_tall` | 高書櫃 | 40×64 | 2 | 裝飾 |
| `balcony_door` | 陽台落地窗 | 48×48 | 2 | 牆面，日夜切換 |
| `sofa_l` | L 型沙發 | 80×48 | 3 | 裝飾 |
| `kitchen_island` | 中島廚房 | 72×44 | 3 | 裝飾 |
| `tv_wall` | 電視牆 | 72×44 | 3 | 裝飾 |
| `art_large` | 大型畫作 | 40×32 | 3 | 牆面，可換畫（收藏品） |
| `home_office_corner` | 居家辦公角 | 56×44 | 3 | **Company OS 入口** |
| `bar_counter` | 吧台 | 72×40 | 4 | 裝飾（俱樂部、餐廳共用） |
| `piano` | 平台鋼琴 | 56×48 | 4 | 裝飾 |
| `home_gym` | 居家健身器材 | 48×44 | 4 | 裝飾 |
| `collection_case` | 收藏展示櫃 | 44×56 | 4 | 放收藏品 |
| `pool_edge` | 窗外泳池 | 96×48 | 4 | 牆面 |
| `fireplace` | 壁爐 | 56×48 | 5 | 晚上發光 |
| `garage_door` | 車庫門 | 64×48 | 5 | 通往車庫 |
| `library_wall` | 書牆 | 96×48 | 5 | 牆面 |
| `hot_plate` | 電爐 | 24×20 | 0 | 老城套房 |
| `clothing_rack` | 衣架 | 40×48 | 更衣室、服飾店 | **B1 已交、已接**（Threadline 逛衣架、Crestline） |
| `mirror_full` | 全身鏡 | 20×44 | 更衣室、服飾店 | **B1 已交、已接**（Threadline） |
| `shoe_shelf` | 鞋架 | 36×32 | 更衣室、服飾店 | **B1 已交、已接**（Threadline、Crestline） |

### 辦公升級組（P1–P3）

| id | 名稱 | 建議尺寸 | 用在 |
|----|------|----------|------|
| `reception_desk` | 接待櫃台 | 80×40 | Horizon Labs 3F、健身房 |
| `meeting_table` | 會議桌（6 人） | 80×44 | Horizon Labs 3F |
| `pantry` | 茶水間 | 72×46 | Horizon Labs 3F |
| `staff_desk_pod` | 四人辦公桌組 | 80×56 | Horizon Labs 3F（員工坐這裡） |
| `exec_desk_premium` | 高級主管桌 | 72×44 | 總部 |
| `boardroom_table` | 董事會長桌 | 112×48 | 總部、Northlight Capital |
| `reception_logo_wall` | 接待區公司牆 | 96×48 | 總部（程式畫公司名） |
| `control_screens` | 螢幕牆 | 112×48 | 物流控制室（內容用色塊和線條） |

### 零售、餐飲組（P1）

| id | 名稱 | 建議尺寸 | 用在 |
|----|------|----------|------|
| `mannequin` | 假人（灰階，可染色） | 20×48 | Threadline（**B1 已交、已接**，擺放時用 `tint` 染色）、Crestline 暫用 |
| `fitting_room` | 試衣間（布簾） | 40×56 | Threadline（**B1 已交、已接**） |
| `checkout_counter` | 結帳櫃台 | 64×40 | Threadline、Crestline（**B1 已交、已接**）、FreshMart、快閃店 |
| `retail_shelf` | 商品貨架 | 48×48 | Crestline、快閃店 |
| `display_table` | 陳列桌 | 48×32 | Crestline |
| `lamp_display` | 檯燈陳列架 | 48×48 | Crestline（放玩家的 LED 檯燈） |
| `escalator` | 手扶梯（背景） | 64×64 | Crestline |
| `grocery_shelf` | 超市貨架 | 64×48 | FreshMart |
| `produce_stand` | 蔬果台 | 56×36 | FreshMart |
| `shopping_cart` | 購物車 | 20×20 | FreshMart |
| `kitchen_pass` | 出餐口 | 80×40 | Lantern Bistro |
| `dining_table_fine` | 高級餐桌（白桌巾） | 40×36 | Aurum |
| `wine_wall` | 酒牆 | 96×48 | Aurum |

### 倉儲、物流、製造組（P1–P3）

| id | 名稱 | 建議尺寸 | 用在 | 備註 |
|----|------|----------|------|------|
| `pallet_rack` | 棧板貨架 | 64×64 | Pier 7、貨運站、廠房 | **依庫存多寡有 3 種滿度**：`pallet_rack_empty` / `_half` / `_full` |
| `packing_line` | 包裝線 | 96×40 | Pier 7 | 輸送帶，規劃 2 格動畫 |
| `forklift` | 堆高機 | 40×36 | Pier 7、港區街道、廠房 | 也當街道物件 |
| `loading_dock_door` | 裝卸捲門 | 64×48 | Pier 7 | 牆面 |
| `assembly_line` | 組裝線 | 112×40 | 廠房 | |
| `qc_station` | 品檢台 | 48×36 | 廠房 | |
| `workbench` | 工作台 | 56×36 | 工坊 | |
| `tool_wall` | 工具牆 | 64×40 | 工坊 | 牆面 |
| `3d_printer` | 3D 印表機 | 24×32 | 工坊 | |
| `printing_press` | 印刷機 | 64×44 | Ember Print | |
| `paper_rolls` | 紙捲 | 32×28 | Ember Print | |
| `poster_rack` | 海報架 | 40×48 | Ember Print | 海報用色塊 |
| `uld_container` | 航空貨櫃 | 44×40 | 貨運站 | |
| `xray_scanner` | X 光機 | 64×40 | 海關 | |
| `customs_crates` | 待檢木箱 | 48×36 | 海關 | |
| `sample_crates` | 樣品箱 | 40×32 | Haddad Trading | |

### 其他場景組（P1–P3）

| id | 名稱 | 建議尺寸 | 用在 |
|----|------|----------|------|
| `treadmill` | 跑步機 | 36×36 | 健身房 |
| `weight_rack` | 啞鈴架 | 48×32 | 健身房 |
| `yoga_mat` | 瑜珈墊 | 32×16 | 健身房 |
| `listing_board` | 房屋資訊牆 | 64×40 | Okafor Lettings（牆面） |
| `sculpture_plinth` | 雕塑台座 | 24×40 | Gallery Nine |
| `gallery_bench` | 藝廊長凳 | 48×20 | Gallery Nine |
| `folding_table` | 摺疊桌 | 48×28 | 社區中心 |
| `career_fair_booth` | 就業博覽會攤位 | 64×56 | AIT 主館 |
| `lab_bench` | 實驗桌 | 64×36 | 創新實驗室 |
| `prototype_display` | 原型展示台 | 32×40 | 創新實驗室 |
| `world_map_wall` | 世界地圖牆 | 96×48 | Haddad Trading（牆面，無字） |
| `tea_set` | 茶具 | 24×16 | Haddad Trading |
| `stage` | 小舞台 | 112×32 | Launchpad |
| `beanbag` | 懶骨頭 | 24×20 | Launchpad |
| `platform_edge` | 月台邊（黃線） | 16×16 地磚 | 捷運月台 |
| `metro_bench` | 月台長椅 | 48×20 | 捷運月台 |
| `departure_board` | 時刻表看板 | 80×32 | 月台、航廈（**只畫框和底，字由程式畫**） |
| `checkin_counter` | 報到櫃台 | 80×40 | 航廈 |
| `seat_row` | 候機排椅 | 80×24 | 航廈 |
| `luggage_belt` | 行李轉盤 | 112×40 | 航廈 |
| `leather_armchair` | 皮革扶手椅 | 28×28 | Meridian Club |
| `billiard_table` | 撞球桌 | 72×44 | Meridian Club |
| `car_turntable` | 展車轉盤 | 96×40 | Crown Motors（上面放車輛 sprite） |
| `solar_panel_sample` | 太陽能板樣品 | 40×40 | Solaris |
| `battery_rack` | 儲能電池櫃 | 32×48 | Solaris |

---

## 規劃中的街道物件

| id | 名稱 | 建議尺寸 | 區域 | 備註 |
|----|------|----------|------|------|
| `market_stall` | 市集攤位 | 48×48 | Shopping Street | **B1 已交、已接**：`market_stall_rose` / `_sage` / `_cream`（64×50），週末 09–18 擺出 |
| `string_lights` | 串燈 | 96×16 | Shopping Street、Old Town | **B1 已交、已接**（128×32 加 `_lights`，掛在路燈之間，畫在行人上方） |
| `kiosk_flower` | 花攤 | 40×40 | Shopping Street | **B1 已交、已接** |
| `planter_long` | 長花台 | 64×24 | Shopping Street | **B1 已交、已接** |
| `bike_rack` | 腳踏車架 | 40×20 | Shopping Street、University | **B1 已交、已接** |
| `container_red` / `_blue` / `_green` | 貨櫃 | 96×40 | Harbor | 可疊 |
| `pallet_stack` | 棧板堆 | 32×24 | Harbor | |
| `crate` | 木箱 | 16×16 | Harbor | |
| `mooring_bollard` | 繫船柱 | 16×16 | Harbor | |
| `rope_coil` | 繩圈 | 16×10 | Harbor | |
| `life_ring` | 救生圈（掛柱） | 16×32 | Harbor | |
| `buoy` | 浮標 | 16×24 | Harbor | 規劃加上下浮動動畫 |
| `harbor_lamp` | 高桿工作燈 | 24×120 | Harbor | 冷白光 glow |
| `mural_wall` | 壁畫牆 | 96×64 | Old Town | 圖案，不寫字 |
| `ivy_trellis` | 爬藤架 | 32×48 | Old Town | |
| `old_lamp` | 鑄鐵路燈 | 20×72 | Old Town | 暖黃光 |
| `bookstall` | 舊書攤 | 48×36 | Old Town | |
| `cafe_chairs_bistro` | 小圓桌組 | 36×32 | Old Town | |
| `swing_set` | 鞦韆 | 56×44 | Residential | |
| `slide` | 溜滑梯 | 56×48 | Residential | |
| `sandbox` | 沙坑 | 48×24 | Residential | |
| `basketball_hoop` | 籃球架 | 32×72 | Residential | |
| `mailbox_bank` | 信箱牆 | 40×40 | Residential | |
| `laundry_line` | 晾衣繩 | 48×16 | Residential | 掛在陽台 |
| `club_booth` | 社團攤位 | 48×44 | University | |
| `campus_sign` | 校園指示牌 | 32×40 | University | 不寫字 |
| `ev_charger` | 充電樁 | 16×36 | 全部（第 4 年綠色轉型後出現） | |
| `construction_fence` | 工地圍籬 | 64×32 | 全部（第 2 年成長狂熱） | |
