# 08 物品與商品

遊戲沒有傳統 RPG 的背包和裝備。「物品」分成五類：

1. **電商商品**：玩家進貨、上架、打包、寄出的東西
2. **生活消費**：咖啡、餐點、日用品
3. **公司與品牌標誌**：合作公司、供應商、玩家的 SaaS 產品
4. **文件**：合約、發票、登記證，出現在 Company OS 和決策視窗
5. **收藏品**：規劃中，用來裝潢房子

---

## 1. 電商商品（已實作 4 種）

資料在 `game/data/products/<id>.json`，圖示是 `props/product_<id>.png`（16×16）。用在：

- Company OS 的庫存、訂單、上架頁
- 家裡和 2B 的庫存紙箱旁（規劃）

| id | 名稱 | 類別 | 建議售價 | 售價範圍 | 運送級距 | 圖示 | 美術 |
|----|------|------|---------|---------|---------|------|------|
| `wireless_earbuds` | Wireless Earbuds 無線耳機 | electronics | $42 | $20–90 | small | `props/product_earbuds` | GEN |
| `desk_lamp` | LED Desk Lamp LED 檯燈 | home | $29 | $12–60 | medium | `props/product_desk_lamp` | GEN |
| `water_bottle` | Insulated Water Bottle 保溫瓶 | lifestyle | $19 | $8–40 | small | `props/product_water_bottle` | GEN |
| `phone_stand` | Aluminium Phone Stand 鋁合金手機支架 | electronics | $12 | $5–25 | small | `props/product_phone_stand` | GEN |
| （預設） | Parcel 包裹 | — | — | — | — | `props/product_parcel` | GEN |

**LED 檯燈是故事道具**：第 5 章 Crestline 一次訂 800 盞。規劃在 Crestline 旗艦店裡放 `lamp_display` 陳列架，讓玩家看到自己的燈上架。

### 供應商報價（`data/suppliers/`）

| 供應商 | 商品 | 單位成本 | 最低訂量 | 交期 | 瑕疵率 |
|--------|------|---------|---------|------|--------|
| TradeLink Wholesale（本地，Ken） | 耳機 / 檯燈 / 保溫瓶 / 支架 | $18 / $11.50 / $6.80 / $3.40 | 50 / 40 / 60 / 80 | 2 天 | 2–5% |
| Harbor Home Goods（本地） | 檯燈 / 保溫瓶 | $12.40 / $7.40 | 80 / 120 | 3 天 | 0.5–1% |
| Lumina Direct（海外代理） | 耳機 / 支架 | $13.20 / $2.10 | 200 / 400 | 12 天 | 4–9% |

### 商品美術規格

| 用途 | 檔案 | 尺寸 | 狀態 |
|------|------|------|------|
| 清單圖示 | `props/product_<id>.png` | 16×16 | 已實作 · GEN · `重繪` |
| **商品照**（上架頁、Studio Lumen 拍照後） | `products/<id>_photo.png` | 64×64 | 規劃中 P1 · `新增` · `需接線` |
| 商品照（拍照前，手機隨手拍版） | `products/<id>_photo_raw.png` | 64×64 | 規劃中 P1 · `新增` · `需接線`。同一件商品，光線差、背景亂，讓玩家看得出「專業攝影」的差別 |
| 手上拿著 | 搬箱姿勢用 `interiors/box` 即可 | — | — |

### 規劃中的商品（候選，P1）

擴充電商商品的候選清單。每一種都需要 16×16 圖示和 64×64 商品照。

| id | 名稱 | 類別 | 參考售價 | 可能的供應商 | 為什麼要有它 |
|----|------|------|---------|-------------|-------------|
| `yoga_mat` | 瑜珈墊 | lifestyle | $32 | Harbor Home Goods | 可以賣給 Harbor Point Fitness（B2B） |
| `ceramic_mug` | 陶瓷馬克杯 | home | $16 | Harbor Home Goods | 易碎：退貨率高 |
| `bluetooth_speaker` | 藍牙喇叭 | electronics | $55 | Lumina Direct | 高單價、高瑕疵 |
| `usb_c_hub` | USB-C 轉接器 | electronics | $24 | Lumina Direct（P2 改從 Zenkai 直購） | 賣給新創族群 |
| `tote_bag` | 帆布托特包 | lifestyle | $14 | TradeLink | 季節性不明顯，穩定 |
| `plant_pot` | 桌上型盆栽 | home | $18 | Harbor Home Goods | 大件、運費高 |
| `phone_case` | 手機殼 | electronics | $15 | Lumina Direct | 款式多，庫存管理難 |
| `scented_candle` | 香氛蠟燭 | home | $22 | TradeLink | 年底旺季（規劃季節需求） |

---

## 2. 生活消費

| id | 名稱 | 在哪裡買 | 價格 | 圖示 | 狀態 |
|----|------|---------|------|------|------|
| `coffee` | 咖啡 | Bloom Coffee | $4.50 | `props/product_coffee`（16×16，目前沒用到） | 已實作 |
| `coffee` | 燕麥拿鐵（資料 id 同樣是 `coffee`） | Bean & Byte | $5.20 | 共用咖啡圖示 | 已實作 |
| `groceries` | 日用品 | FreshMart | 規劃 | `新增` 16×16 購物袋 | 規劃中 P1 |
| `bistro_meal` | 餐點 | Lantern Bistro | 規劃 | `新增` 16×16 餐盤 | 規劃中 P1 |
| `gym_pass` | 健身日票 | Harbor Point Fitness | 規劃 | `新增` 16×16 啞鈴 | 規劃中 P1 |
| `metro_ticket` | 捷運票 | 各站 | $2.80 | `ui/icons/metro` | 已實作 |

每天的生活費是 $32，縮減開支時降到 $18。房租每月 $1,250，14 號到期。

### 咖啡店事業的菜單（P3，`cafe` 產業）

玩家開自己的咖啡店後，需要菜單品項圖示（16×16）：`espresso`、`latte`、`cold_brew`、`croissant`、`sandwich`、`cake_slice`、`muffin`、`tea`。

---

## 3. 公司與品牌標誌

### 合作公司標誌

規劃用在：手機訊息的頭像、合約標題、供應商清單、事件視窗。`需接線`

- **檔案**：`logos/<company_id>.png`
- **尺寸**：32×32（加一張 16×16 小版 `logos/<company_id>_16.png`）
- **規則**：只用圖形，**不要放公司名字**（名字由程式畫在旁邊）

| company_id | 公司 | 設計方向 |
|------------|------|----------|
| `tradelink_wholesale` | TradeLink Wholesale | 藍白，兩個箱子交疊成一個箭頭 |
| `harbor_home_goods` | Harbor Home Goods | 深綠，房子加一道波浪 |
| `lumina_direct` | Lumina Direct | 橘色，地球加船錨 |
| `shoplane` | ShopLane | 珊瑚紅，購物袋底部是一條道路 |
| `crestline_retail` | Crestline Retail Group | 海軍藍加金，三道山脊線 |
| `harbor_point_fitness` | Harbor Point Fitness | 青綠，浪花加一個點 |
| `northlight_capital` | Northlight Capital | 淡藍，北極星 |
| `studio_lumen` | Studio Lumen | 黑白，相機光圈 |
| `nexus` | Nexus（Bank、Co-work） | 海軍藍底加金色「N」（沿用現有招牌） |
| `postpoint` | PostPoint | 紅底白色包裹 |
| `aurelia_jobs` | Aurelia Jobs | 藍色公事包 |
| `aurelia_city` | City of Aurelia | 市徽（沿用 `interiors/seal`） |
| `client_generic` | 顧問案客戶 | 灰色大樓剪影（隨機客戶共用） |

### 玩家的 SaaS 產品 logo

SaaS 分頁的產品頭像。`需接線`

| 檔案 | 產品 | 設計方向 | 尺寸 |
|------|------|----------|------|
| `logos/saas_salon_booking.png` | Chairly | 理髮椅剪影，圓角方形 app icon，粉紫 | 32×32 |
| `logos/saas_freelancer_invoicing.png` | Paidly | 打勾的收據，綠 | 32×32 |
| `logos/saas_shop_inventory.png` | Stockroom | 三個疊起來的箱子，橘 | 32×32 |

SaaS 功能更新（Mobile app、Team accounts、Integrations、Reports、Automations、API、Offline mode、Custom branding）發布時，規劃用 16×16 的小圖示：`feature_mobile`、`feature_team`、`feature_integrations`、`feature_reports`、`feature_automations`、`feature_api`、`feature_offline`、`feature_branding`。

---

## 4. 文件（規劃中 P2 · `需接線`）

決策視窗和 Company OS 目前只有文字。規劃在重要時刻顯示一張文件插圖，讓「簽約」有重量。

| id | 文件 | 出現時機 | 尺寸 | 規則 |
|----|------|---------|------|------|
| `doc_registration` | 公司登記證 | 第 3 章登記完成 | 96×72 | 紙張加市徽浮水印。**公司名由程式寫上去** |
| `doc_lease` | 租約 | 租下 Suite 2B | 96×72 | 紙張加鑰匙 |
| `doc_contract` | 合約 | 接下 B2B 訂單（Crestline） | 96×72 | 兩個簽名欄（線條） |
| `doc_loan` | 貸款合約 | Nexus Bank 貸款 | 96×72 | 銀行抬頭色帶 |
| `doc_invoice` | 發票 | 顧問案交件 | 96×72 | 表格線條 |
| `doc_term_sheet` | 投資條件書 | Elena 的提案 | 96×72 | Northlight 抬頭 |
| `doc_month_close` | 月結報告 | 月結視窗的頁首裝飾 | 160×32 | 帳本紙紋 |
| `doc_closing_statement` | 清算報告 | 公司結束 | 96×72 | 冷靜、不嘲諷 |

文件上**所有字都由程式畫**，美術只畫紙張、印章、線條、抬頭色帶。

---

## 5. 收藏品（規劃中 P3）

住得更好之後，可以買收藏品放進 `collection_case` 或掛在牆上。**只有外觀，沒有數值**。

| id | 名稱 | 在哪裡買 | 尺寸 |
|----|------|---------|------|
| `art_print_*` | 畫作（6 幅） | Gallery Nine | 40×32 牆面 |
| `sculpture_*` | 小雕塑（3 座） | Gallery Nine | 24×24 |
| `vinyl_set` | 黑膠唱片組 | Old Town 舊書攤 | 24×16 |
| `model_ship` | 船模 | Harbor | 32×24 |
| `first_dollar_frame` | 裱框的第一塊錢 | 第 2 章第一筆訂單後自動獲得 | 16×16 牆面 |
| `crestline_plaque` | Crestline 合作紀念牌 | 第 5 章完成後自動獲得 | 24×16 牆面 |
| `founder_photo` | 公司創立合照 | 第 3 章完成後自動獲得 | 24×20 牆面 |

後三件是**人生紀念品**：劇情里程碑會自動留下一件，掛在家裡或辦公室，讓玩家回頭看得到自己走過的路。
