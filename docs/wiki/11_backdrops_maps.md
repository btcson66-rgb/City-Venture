# 11 背景、卡片與地圖

## 全螢幕背景（`game/assets/backdrops/`）

| 檔案 | 尺寸 | 用在 | 美術 | 內容 |
|------|------|------|------|------|
| `menu` | 752×360 | 主選單，會慢慢左右平移（所以比畫面寬 112 px） | **CODEX 原創 2026-09-29** | 河岸新創街區、預設主角與 Maya |
| `arrival` | 640×360 | 開場「抵達 Aurelia」：列車進城 | **CODEX 原創 2026-09-29** | 河岸天際線、橋、倒影；動態列車與近景橋由程式疊加 |
| `skyline_day` | 1300×320 | 每個街區建築後面的遠景，視差捲動 | **CODEX 原創 2026-09-29** | 藍色現代建築與河岸 |
| `skyline_dusk` | 1300×320 | 黃昏交叉淡入 | **CODEX 原創 2026-09-29** | 同構圖桃色天空與琥珀窗光，既有接點已使用 |
| `skyline_night` | 1300×320 | 同上，晚上交叉淡入 | **CODEX 原創 2026-09-29** | 同構圖靛藍夜景、選擇性亮窗 |
| `wardrobe` | 200×250 | 捏臉畫面的角色背景 | **CODEX 原創 2026-09-29** | 空置暖木更衣室，人物由遊戲疊加 |

目前原畫與 prompt 在 `docs/art_sources/renewal_20260929/`，重建指令為 `python tools/art/renewal_pack.py`。舊 `finalize_backdrops.py` 是 v2 的歷史重建工具，會恢復舊 menu / arrival，勿用來重建本批。

**2026-09-29 狀態更新**：下列規劃清單中的 `chapter_1`、`chapter_2`、`chapter_3`、`chapter_4`、`chapter_5`、`chapter_6`、`insolvency` 和 `skyline_dusk` 已交付並接入；chapter_7–12 和其餘未列項目仍為規劃。六章順序為列車、首單包裹、市政登記、員工桌、檯燈訂單、深夜現金曲線。

### 規劃中的背景

| 檔案 | 尺寸 | 用在 | 優先 | 內容 |
|------|------|------|------|------|
| `skyline_dusk` | 1300×320 | 黃昏（17–19 點）的中間階段。沒有這張時，日夜兩張直接交叉 | P1 · 程式已接好 | 橘紫色天空、窗戶開始亮 |
| `skyline_harbor_day/night` | 1300×320 | 港區專用遠景：吊車、貨輪、海 | P1 | |
| `skyline_oldtown_day/night` | 1300×320 | 老城專用遠景：鐘樓、紅瓦屋頂 | P1 | |
| `chapter_<n>` | 640×360 | **章節標題卡**：每章開始時的全螢幕插圖（章名由程式畫） | P1 · 程式已接好 | 見下表 |
| `insolvency` | 640×360 | 公司結束後按「重新開始」出現的「重新出發」畫面 | P1 · 程式已接好 | 清晨的河岸，一個人坐在長椅上看日出。冷靜、有希望，不悲情 |
| `skyline_<district>_<day/dusk/night>` | 1300×320 | 某一區專屬的天際線，有這張就取代共用的天際線 | P1 · 程式已接好 | 例如港區的吊車和貨輪 |
| `month_close` | 640×360 | 月結報告的背景（模糊的辦公桌） | P2 · `需接線` | |
| `travel_plane` | 640×360 | 出國過場：從機窗看雲 | P2 · `需接線` | |
| `legacy` | 640×360 | 第 10 年「人生回顧」 | P3 · `需接線` | 玩家的城市在黃昏，所有擁有的建築亮燈 |
| `loading` | 640×360 | 讀檔畫面 | P2 | Aurelia 清晨的俯瞰 |

### 章節標題卡

| 章 | 檔案 | 畫面 |
|----|------|------|
| 1 Arrival | `chapter_1` | 列車窗外第一次看到 Aurelia，手機亮著 |
| 2 First Customer | `chapter_2` | 小套房地上一個封好的紙箱，旁邊是筆電 |
| 3 Open for Business | `chapter_3` | 市政廳台階，手上拿著登記證 |
| 4 Growing Pains | `chapter_4` | Suite 2B 裡第一位員工的空桌子，桌上有歡迎卡片 |
| 5 The Big Contract | `chapter_5` | 800 盞檯燈堆滿倉庫，Daniel 的資料夾 |
| 6 Cash Is Oxygen | `chapter_6` | 深夜的辦公室，螢幕上的現金曲線 |
| 7 Supply Shock | `chapter_7` | 港口塞滿貨輪 |
| 8 Green Shift | `chapter_8` | 屋頂的太陽能板和城市 |
| 9 Clearing Crisis | `chapter_9` | 銀行外排隊的人、「處理中」的沙漏 |
| 10 Digital Rails | `chapter_10` | 抽象的光軌穿過城市（**不用任何加密貨幣標誌**） |
| 11 The Other Side of Trust | `chapter_11` | 斷掉的橋（比喻），新聞快報 |
| 12 Regulation & Scale | `chapter_12` | 金融區頂樓會議室，窗外是世界地圖 |

---

## 地點卡（`game/assets/cards/`，192×108）

**2026-09-29 更新**：下表全部 12 張已換成原創圖（CODEX 原創更新），原畫與來源對照見 `docs/art_sources/renewal_20260929/sources.json` 及 `evidence/2026-09-29_art_renewal/asset_manifest.json`。以下 A6 註記保留歷史背景。地點卡代表場景氛圍，並非可行走房間／街道已重建。

第一次走進一個街區或建築時，左下角浮出一張卡：圖片、「NEW LOCATION」、名稱、營業時間。建築沒有卡時，改用它所在街區的卡。

| 檔案 | 地點 | 美術 |
|------|------|------|
| `riverside` | Riverside 區 | CODEX A6（R2：旗幟無標語） |
| `startup_hub` | Startup Hub 區 | CODEX A6 |
| `civic_center` | Civic Center 區 | CODEX A6 |
| `financial` | Financial 區 | CODEX A6 |
| `riverside_apartment` | Riverside Tower | CODEX A6 |
| `bloom_coffee` | Bloom Coffee | CODEX A6 |
| `byte_and_bean` | Bean & Byte | CODEX A6 |
| `nexus_cowork` | Nexus Co-work | CODEX A6 |
| `small_office` | 22 Founders Lane | CODEX A6 |
| `nexus_bank` | Nexus Bank | CODEX A6 |
| `city_hall` | Aurelia City Hall | CODEX A6（圖上不印地點名） |
| `postpoint_riverside` | PostPoint | CODEX A6（專屬卡，無字包裹圖示） |

**製作規則**：每個新區域一張，每棟新的可進入建築一張（清單見 [03](03_districts.md) 和 [04](04_buildings.md)），檔名等於 id。構圖：3/4 角度的建築或室內的「招牌畫面」。A6 移除標語、海報、菜單與可翻譯的地點名稱；R2 明確允許的品牌識別招牌保留。卡片上的地點名稱和營業時間仍由程式畫。

---

## 城市地圖（`game/assets/city_map/`）

| 檔案 | 尺寸 | 用在 | 美術 |
|------|------|------|------|
| `board` | 458×305 | 城市地圖視窗的主圖（手機 City App、地圖快捷鍵） | CODEX A6（Board F，標籤區無字） |
| `aurelia_map` | 640×360 | 捷運視窗的背景 | CODEX A6（深藍無字街道／河道底圖，路線由程式疊加） |
| `i_<district>` | 144×90 | 選到某區時，右側資訊欄的區域照片（13 張） | CODEX A6 |

13 張區域照片：`i_riverside` · `i_startup_hub` · `i_civic_center` · `i_financial` · `i_shopping_street` · `i_harbor` · `i_residential` · `i_luxury_heights` · `i_airport` · `i_old_town` · `i_university` · `i_industrial` · `i_metro`

**規則**：

- 區域名稱的標籤是程式畫的按鈕，位置在 `data/city/aurelia.json` 的 `board.label`（x1, y1, x2, y2），圖釘在 `board.pin`。**底圖的標籤位置要留素底**。
- 改了底圖構圖，就要一起改 `aurelia.json` 的座標。

**規劃（P1）**：

- 定稿重繪 `board`：Board F 的等角城市圖，要能看出河、海灣、每一區的特色建築（港區吊車、老城鐘樓、大學草坪、機場跑道）。
- 未開放的區域，標籤由程式標成「Planned」。底圖照常畫完整的區域，不用畫鎖住或變暗的樣子。
- 捷運路線圖（M1–M5）目前由程式畫線，維持。

---

## 世界地圖（`game/assets/world_map/`）

| 檔案 | 尺寸 | 用在 | 美術 |
|------|------|------|------|
| `board` | 600×255 | 世界地圖視窗的主圖 | CODEX A6（Board E，標籤區無字） |
| `world_map` | 640×360 | 保留（程式目前沒用到） | GEN |
| `r_<region>` | 64×40 | 每個市場的縮圖，出現在標籤和資訊欄（8 張） | CODEX A6（Board E） |

8 張市場縮圖：`r_aurelia` · `r_northridge` · `r_auroria` · `r_lumina` · `r_zenkai` · `r_solterra` · `r_almeria` · `r_karu`。每一區的視覺關鍵詞見 [02 世界觀](02_world_lore.md)。

**規則**：同城市地圖，標籤位置在 `data/regions/<id>.json` 的 `board`。航線和海運線由程式畫（`scripts/ui/modals/world_routes.gd`）。

**規劃（P2）**：飛機和貨輪小圖示（見 [09 交通工具](09_vehicles.md)）、每個市場一張 192×108 的地點卡 `cards/region_<id>.png`。

---

## 規劃：事件插圖

事件視窗（決策視窗）目前只有文字和一個頭像。標題下的 **160×90** 小插圖程式已接好：`events/<event_id>.png` 放進去就會出現。

| 事件 id | 插圖 |
|---------|------|
| `customer_return` / `customer_return_first` | 拆開的紙箱，商品放在旁邊 |
| `supplier_price_increase` | 供應商報價單，價格那一欄畫紅圈（無字） |
| `unexpected_large_order` | 一大疊訂單和一個計算機 |
| `crestline_big_offer` | Crestline 的資料夾放在會議桌上 |
| `ad_cost_spike` | 廣告後台的長條圖一路往上 |
| `viral_mention` | 手機螢幕上的愛心和分享數往上跳（**不是**金幣噴發） |
| `elena_offer` | 條件書和一支鋼筆 |
| `supply_shock_plan` | 港口外排隊的貨櫃船，前景一張被紅筆圈起來的運費單（無字） |
| `low_cash_warning` | 空了一半的錢包，旁邊是一疊帳單 |

檔名：`events/<event_id>.png`。

## C10 第 10–12 章 · 美術已交 2026-09-30

`backdrops/chapter_10.png`、`chapter_11.png`、`chapter_12.png`：640×360 / 2560×1440。分別以光軌、斷橋與新聞手機、頂樓會議室與世界投影表達數位結算、信任、監管與規模。`events/rail_frozen.png`、`events/acquisition_offer.png`：160×90 / 640×360，鎖住的付款光軌及空白收購文件與兩支筆。無文字、數字、真實品牌或加密貨幣符號。
