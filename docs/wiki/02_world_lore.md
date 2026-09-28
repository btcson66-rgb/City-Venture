# 02 世界觀與背景設定

## 一句話

2031 年 6 月 1 日下午兩點，一個普通人帶著 $30,000 搭火車來到 Aurelia 市，從租來的小套房和一台筆電開始，一步一步把一門小生意做成公司。公司可以倒，人不會 game over。

## 核心精神（影響美術的部分）

| 原則 | 對畫面的意思 |
|------|-------------|
| 真實的商業，不是數值遊戲 | 畫面呈現真的店、真的辦公室、真的文件。沒有「+20 效率」的光環特效 |
| 沒有職業、沒有 buff | 衣服、家具、車都是外觀和生活感。只有少數家具是功能點（筆電、床、打包桌） |
| 公司會失敗，人不會 | 破產畫面要冷靜、有尊嚴，不能嘲諷；「重新開始」要有希望感 |
| 生活感 | 城市要有路人、車流、營業時間、日夜。店會打烊，窗會亮燈 |
| 加密貨幣只在第 9 章「結算危機」之後出現 | 前面的畫面**完全不能有**幣圈符號。之後出現也要中性、教育性，不能賭場化 |

## Aurelia 市

| 項目 | 設定 |
|------|------|
| 名稱 | Aurelia City（奧瑞利亞市） |
| 人口 | 320 萬 |
| 面積 | 62 km² |
| 地理 | 一條河穿過市中心往南流進海灣。河岸是 Riverside，海灣邊是港口 |
| 氣質 | 現代、乾淨、綠化多的中型國際都市。玻璃高樓和紅磚老街並存 |
| 市徽 | `interiors/seal.png`（市政廳牆上的圓形徽章）：藍底金環，中間一個「A」。定稿可以加入河流和橋的圖案 |
| 交通 | 5 條捷運線、公車、計程車。目前玩家走路或搭捷運 |

### 12 個區域

詳細視覺設定見 [03 城市區域](03_districts.md)。

| id | 名稱 | 狀態 | 一句話 |
|----|------|------|--------|
| `riverside` | Riverside 河岸區 | 已實作 | 公園、咖啡店、河景。玩家的第一個家 |
| `startup_hub` | Startup Hub 新創園區 | 已實作 | 共享辦公、育成中心、很多咖啡因的創業者 |
| `civic_center` | Civic Center 市政中心 | 已實作 | 市政廳、許可、公司登記、公共服務 |
| `financial` | Financial District 金融區 | 已實作 | 銀行、高樓、投資人、律師 |
| `shopping_street` | Shopping Street 購物街 | 規劃中 P1 | 零售、餐廳、夜生活 |
| `harbor` | Harbor 港區 | 規劃中 P1 | 貨櫃、海關、貨運 |
| `old_town` | Old Town 老城區 | 規劃中 P1 | 低租金、老店、藝術 |
| `residential` | Residential 住宅區 | 規劃中 P1 | 學校、公園、家庭 |
| `university` | University 大學區 | 規劃中 P1 | 研究和人才 |
| `luxury_heights` | Luxury Heights 豪宅區 | 規劃中 P3 | 頂樓豪宅、俱樂部、高級餐廳 |
| `airport` | International Airport 國際機場 | 規劃中 P2 | 國內、國際、貨運、私人航空 |
| `industrial` | Industrial Zone 工業區 | 規劃中 P3 | 工廠和原料 |

### 捷運

| 線 | 名稱 | 顏色 | 停靠 |
|----|------|------|------|
| M1 | Central Line | `#E05A4F` 紅 | Civic Center · Financial · Riverside |
| M2 | Riverside Line | `#4D8AD6` 藍 | Riverside · Startup Hub |
| M3 | Harbor Line | `#5FB06E` 綠 | Harbor · Riverside |
| M4 | Airport Line | `#E2B452` 金 | Financial · Airport |
| M5 | Loop Line | `#966EC4` 紫 | Startup Hub · Civic Center · Luxury Heights · Shopping Street |

票價 $2.80。捷運視窗只列出已開放的站；規劃中的站以一行文字列出（「Planned stations (P1)」）。

## 海外七國

目前只在世界地圖上看得到（P2 才能去）。每一區在美術上要有自己的建築語彙，但仍然是同一個像素風格。

| id | 名稱 | 定位 | 產業 | 優勢 | 風險 | 飛行 / 海運 | 視覺關鍵詞 |
|----|------|------|------|------|------|------------|-----------|
| `aurelia` | Aurelia | 本國市場 | 金融、科技、貿易、生活 | 一切從這裡開始 | — | 0 / 0 | 河、橋、玻璃和紅磚 |
| `northridge` | Northridge | 科技與媒體 | 軟體、SaaS、媒體 | 高薪人才、大市場 | 成本高、競爭強、法規成熟 | 10 h / 18 天 | 冷色玻璃園區、雪山、有機建築 |
| `auroria` | Auroria | 金融與設計 | 金融、精品、設計 | 高消費客群 | 消費者保護嚴、法規複雜、營運成本高 | 12 h / 16 天 | 石造老城、精品街、河畔拱廊 |
| `lumina` | Lumina | 製造與物流 | 製造、港口、電子、物流 | 年輕消費者、工廠價 | 品質不穩、交期長 | 7 h / 14 天 | 大型貨櫃港、工業園、霓虹市場（克制） |
| `zenkai` | Zenkai | 先進科技製造 | 半導體、電子、精密製造、研發 | 供應鏈深 | 品質門檻高、科技競爭、供應鏈依賴 | 6 h / 12 天 | 無塵廠房、整齊的城市格線、鐵道 |
| `solterra` | Solterra | 資源與農業 | 食品、農業、天然資源 | 成長市場 | 基礎建設、氣候、原物料價格 | 14 h / 18 天 | 梯田、穀倉、暖陽色土地 |
| `almeria` | Almeria | 貿易與能源 | 能源、航空、基礎建設、貿易 | 貿易樞紐 | 能源價格波動 | 11 h / 16 天 | 沙色港城、風機和太陽能板、轉運機場 |
| `karu` | Karu | 新興市場 | 基礎建設、消費 | 人口年輕、成長快 | 制度不成熟、匯率、政治、物流 | 16 h / 20 天 | 工地塔吊、熱鬧市集、新舊並陳 |

進入條件（P2）：登記公司，並開好國際銀行帳戶。

## 十年時間線（`data/world/years.json`）

遊戲以年為大週期，每年有一個世界主題，影響利率、運費和新聞標題。

| 年 | 主題 | 狀態 | 畫面上的變化（規劃） |
|----|------|------|----------------------|
| 1 | The Opportunity 機會之年 | 已實作 | 低利率、創業熱潮。新聞板和手機頭條 |
| 2 | Growth Fever 成長狂熱 | 規劃中 | 街上多了新店和工地圍籬 |
| 3 | Supply Shock 供應衝擊 | 規劃中 | 港口塞船、貨架變空、運費看板變紅 |
| 4 | The Green Shift 綠色轉型 | 規劃中 | 屋頂出現太陽能板、電動車和充電樁 |
| 5 | Clearing Crisis 結算危機 | 規劃中 | 銀行排隊、「付款處理中」告示 |
| 6 | Digital Finance Boom 數位金融熱 | 規劃中 | 新金融公司看板（中性設計，不用幣圈 logo） |
| 7 | Bridge Exploit 跨鏈橋事件 | 規劃中 | 新聞快報、辦公室氣氛緊張 |
| 8 | Regulation Wave 監管浪潮 | 規劃中 | 市政廳多了新櫃台、合規文件 |
| 9 | Global Consolidation 全球整併 | 規劃中 | 企業併購、摩天樓換招牌 |
| 10 | Legacy 傳承 | 規劃中 | 人生回顧畫面 |

## 故事章節

世界有主線，玩家的人生不固定。每章給目標和引導箭頭，但不規定玩家成為哪種人。

| 章 | id | 標題 | 狀態 | 核心 | 主要場景 |
|----|----|------|------|------|----------|
| 1 | `ch1_arrival` | Arrival 抵達 | 已實作 | 看手機、逛河岸、喝咖啡、到共享辦公挑第一門生意 | 公寓、Bloom Coffee、Nexus Co-work |
| 2 | `ch2_first_customer` | First Customer 第一位客人 | 已實作 | 進貨、拍照上架、第一張訂單、打包寄出 | 公寓筆電、打包桌、PostPoint |
| 3 | `ch3_open_for_business` | Open for Business 正式開業 | 已實作 | 公司登記、開公司帳戶、選辦公地點 | 市政廳、Nexus Bank、Suite 2B |
| 4 | `ch4_growing_pains` | Growing Pains 成長的痛 | 已實作 | 登記雇主、徵才、第一次發薪、看現金預測 | 市政廳、Suite 2B |
| 5 | `ch5_big_contract` | The Big Contract 大合約 | 已實作 | Daniel Wong 的 800 盞檯燈訂單，60 天票期 | Nexus Co-work、Suite 2B |
| 6 | `ch6_cash_is_oxygen` | Cash Is Oxygen 現金是氧氣 | 已實作 | 用貸款、投資或砍成本撐過缺口，收回貨款 | Nexus Bank、Company OS |
| 7 | — | Supply Shock 供應衝擊 | 規劃中 | 全球物流漲價，不同產業受影響程度不同 | 港區、供應商 |
| 8 | — | Green Shift 綠色轉型 | 規劃中 | 新能源商機，可以不參與 | 工業區、太陽能公司 |
| 9 | — | Clearing Crisis 結算危機 | 規劃中 | 跨境付款卡住，第一次比較結算方式。Lina Zhao 登場 | 銀行、海外供應商 |
| 10 | — | Digital Rails 數位軌道 | 規劃中 | 認識穩定幣、區塊鏈、智能合約，不強迫使用 | Lina 的辦公室 |
| 11 | — | The Other Side of Trust 信任的另一面 | 規劃中 | 跨鏈橋被駭。技術不會消除風險，只會改變風險 | 新聞、辦公室 |
| 12 | — | Regulation & Scale 監管與規模 | 規劃中 | 跨國企業的合規、治理、併購 | 金融區總部、機場 |

## 公司與品牌（全部虛構）

遊戲裡出現的公司。美術需要它們的 logo（見 [08 物品](08_items.md#合作公司標誌)），所有 logo 都不能像真實品牌。

| id | 名稱 | 產業 | 關係人 | 在遊戲中的角色 | 視覺 |
|----|------|------|--------|---------------|------|
| `tradelink_wholesale` | TradeLink Wholesale | 批發 | Ken | 本地批發商，可靠但不是最便宜 | 藍白、箱子圖形 |
| `lumina_direct` | Lumina Direct | 進口代理 | — | 海外工廠價，交期長、MOQ 大、瑕疵多 | 橘色、船錨或地球 |
| `harbor_home_goods` | Harbor Home Goods | 居家用品 | — | 品質較好的居家用品，MOQ 較高 | 深綠、房子圖形 |
| `shoplane` | ShopLane | 電商平台 | — | 玩家開店的線上市集，抽成 10%，每週撥款 | 珊瑚紅、購物道路 |
| `crestline_retail` | Crestline Retail Group | 零售 | Daniel Wong | 大型零售通路，第 5 章大訂單 | 海軍藍配金、山脊線 |
| `harbor_point_fitness` | Harbor Point Fitness | 健身 | Rosa Lim | B2B 客戶，會議價 | 青綠、浪花 |
| `northlight_capital` | Northlight Capital | 創投 | Elena Park | 第 6 章投資人選項 | 白配淡藍、北極星 |
| `studio_lumen` | Studio Lumen | 攝影 | — | 商品攝影 | 黑白、光圈 |
| `nexus` | Nexus（Bank / Co-work） | 銀行、共享辦公 | Sofia、Marcus、Priya | 同一集團的兩個品牌 | 海軍藍配金色「N」 |
| `postpoint` | PostPoint | 物流門市 | Dara | 寄件、收件 | 紅配白、包裹 |
| `bloom_coffee` | Bloom Coffee | 咖啡 | Jun、Maya | 河岸咖啡店 | 深綠配米白、花苞 |
| `byte_and_bean` | Bean & Byte | 咖啡 | Lee | 新創園區咖啡店 | 棕配青綠、咖啡豆加游標 |
| `horizon_labs` | Horizon Labs | 科技 | — | 新創園區的鄰居大樓（外觀） | 橘色日出線 |
| `aurelia_jobs` | Aurelia Jobs | 求職平台 | — | 手機裡的打工訊息 | 藍色公事包 |

### 玩家的 SaaS 產品（`data/economy/saas.json`）

| id | 名稱 | 做什麼 | logo 方向 |
|----|------|--------|----------|
| `salon_booking` | Chairly | 美髮沙龍線上預約 | 理髮椅剪影、圓角 |
| `freelancer_invoicing` | Paidly | 自由工作者的發票和催款 | 打勾的收據 |
| `shop_inventory` | Stockroom | 小網店的庫存管理 | 疊起來的箱子 |

## 產業（`data/businesses/`）

玩家可以經營的事業。企劃的鐵則是**每個產業要玩起來真的不一樣**，不只是換一個圖示。每個產業需要的美術場景如下。

| id | 產業 | 狀態 | 玩法核心 | 需要的美術場景 |
|----|------|------|---------|---------------|
| `ecommerce` | Ecommerce 電商 | 已實作 | 批發進貨、網路販售，現金壓在紙箱裡 | 住家打包桌、PostPoint、紙箱堆（已有） |
| `consulting` | Freelance Consulting 自由顧問 | 已實作 | 時間就是庫存：接案、做工時、開發票、收款 | 筆電、咖啡店、共享辦公（已有） |
| `saas` | SaaS / Software 軟體訂閱 | 已實作 | 先投入開發工時，上線後看訂閱、流失和伺服器成本 | 辦公室、`server_rack`、雙螢幕桌（部分已有） |
| `cafe` | Cafe / Food 咖啡餐飲 | 規劃中 P3 | 來客數 × 轉換率 × 客單價，房租從不休息 | 快閃店面、咖啡吧台、菜單品項 |
| `logistics` | Logistics 物流 | 規劃中 P3 | 從一台二手貨車開始，每小時、每公升油都算數 | Pier 7 倉庫、貨車、控制室 |
| `manufacturing` | Manufacturing 製造 | 規劃中 P3 | 小量代工：良率、停機、瑕疵 | 工坊、廠房、組裝線 |
| `real_estate` | Real Estate 房地產 | 規劃中 P3 | 先賺仲介佣金，最後在天際線上蓋自己的樓 | Okafor 租屋行、VENTURE TOWER |
| `international_trade` | International Trade 國際貿易 | 規劃中 P2 | 找貨源、找買家、跨境運貨 | Haddad Trading、海關、世界地圖 |
| `media` | Media / Advertising 媒體廣告 | 規劃中 | 行銷活動、創作者、聲譽 | Ember 印刷行、攝影棚 |
| `hotel` | Hotel / Tourism 飯店觀光 | 規劃中 | 住房率、平均房價、淡旺季 | 飯店大廳、客房 |
| `automotive` | Automotive 汽車 | 規劃中 | 二手車、租車，也許有一天做電動車品牌 | Crown Motors、車輛 |
| `energy` | Energy 能源 | 規劃中 | 從屋頂太陽能到電網規模，受政策左右 | Solaris Energy、太陽能板 |

## 打工（`data/jobs/`）

在 Business Board 的「Part-time jobs」分頁應徵。走到工作地點的員工門，按 E 上班。每份工作有 3 個職級和一個小福利。

| id | 工作 | 雇主 | 職級 | 福利 | 規劃的美術 |
|----|------|------|------|------|-----------|
| `barista` | 咖啡師 | Bloom Coffee | Barista → Shift Lead → Café Manager | 在 Bloom 免費喝咖啡 | 上班時主角換上 `barista` 服裝 |
| `parcel_sorter` | 包裹分揀 | PostPoint Riverside | Parcel Sorter → Route Planner → Depot Supervisor | 自己寄件打 85 折 | `courier` 服裝，加搬箱姿勢 |
| `cowork_host` | 共享辦公接待 | Nexus Co-work | Community Host → Events Lead → Community Manager | 免費使用共享桌 | `office_professional` 加識別證 |
| `city_clerk` | 市政職員 | City Hall | Records Clerk → Licensing Officer → Senior Officer | 公司登記費半價 | `civic_staff` 服裝 |
| `bank_teller` | 銀行櫃員 | Nexus Bank | Teller Trainee → Teller → Personal Banker | 免透支手續費 | `business_suit` 服裝 |

目前上班是黑幕快轉。規劃（P1 · `需接線`）：上班時畫面上的主角換上該工作的制服，站在櫃台後面。

## 隨機事件（`data/events/`）

事件以決策視窗呈現，目前沒有插圖（規劃：事件插圖 160×90，見 [11](11_backdrops_maps.md#規劃事件插圖)）。

| id | 類別 | 內容 |
|----|------|------|
| `customer_return_first` / `customer_return` | 客戶 | 退貨 |
| `supplier_price_increase` | 供應 | 供應商漲價 |
| `unexpected_large_order` | 客戶 | B2B 大單，有票期 |
| `crestline_big_offer` | 客戶 | Crestline 的 800 盞燈 |
| `ad_cost_spike` | 市場 | 廣告費暴漲 |
| `viral_mention` | 市場 | 被網紅推薦 |
| `elena_offer` | 財務 | Elena 的投資條件 |
| `low_cash_warning` | 財務 | 現金快見底 |
