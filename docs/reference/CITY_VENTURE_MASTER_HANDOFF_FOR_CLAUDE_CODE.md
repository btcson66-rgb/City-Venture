# CITY VENTURE — MASTER GAME HANDOFF
## Complete Product, Narrative, Gameplay, World, Economy, Visual, and Implementation Bible
### Version: Master Handoff v1.0
### Intended recipient: Claude Code / implementation agent
### Language: Traditional Chinese for design notes; English identifiers are acceptable in code

---

# 0. CLAUDE CODE：先讀這裡

這份檔案是 CITY VENTURE 目前所有已確認遊戲方向的「唯一主規格」。

實作時請把本文件視為產品基準，不要自行把遊戲改成：
- 純 Dashboard 經營遊戲
- 點擊放置型 Idle Game
- 傳統 RPG 數值養成
- Crypto 投機遊戲
- NFT / Play-to-Earn 遊戲
- Pay-to-Win 遊戲
- 純文字商業模擬器
- 只有選單而沒有城市世界的 Tycoon UI

本專案的核心是：

> 一個玩家可以真正生活、移動、進入建築、創業、經營公司、購屋、開車、跨國發展的現代像素風商業人生 RPG。

最重要的結構是：

WORLD MAP
→ CITY MAP / CITY EXPLORATION
→ BUILDING EXTERIOR
→ BUILDING INTERIOR
→ CONTEXTUAL MANAGEMENT UI

公司 Dashboard 只在玩家進入公司、辦公室或特定管理設備後才出現。

---

# 1. 一句話定位

CITY VENTURE 是一款「現代城市創業人生 RPG」。

玩家帶著有限資金搬進 Aurelia City，自由選擇自己想做的生意，從第一筆收入、第一個客戶、第一間公司開始，逐步面對現金流、員工、供應商、銀行、法規、競爭、供應鏈、國際市場與跨境支付。

玩家最後可以：
- 經營一間穩定的小店
- 建立全國品牌
- 成為跨國企業
- 發展多產業控股集團
- 持有豪宅、跑車、私人飛機
- 改變城市天際線
- 進入全球市場

遊戲不替玩家定義成功。

---

# 2. 已確認、不可任意修改的核心決策

## 2.1 玩家沒有「職業屬性加成」

禁止以下設計：
- Engineer +20% 開發
- Sales +15% 談判
- Rich Family +30% 起始資金
- Intelligence / Charisma / Luck 點數
- 職業 Buff
- 天賦樹帶來無條件收入加成

角色建立只決定：
- 外觀
- 名字
- 身分呈現
- 服裝
- 個人風格

玩家真正的差異來自：
- 選擇做什麼生意
- 如何定價
- 如何控制成本
- 接不接某張訂單
- 要不要借錢
- 要不要擴張
- 要不要進海外市場
- 用什麼支付方式
- 如何處理危機
- 是否轉型
- 是否跨產業

---

## 2.2 玩家不是選「職業」，而是選「生意」

開局捏完角色後，玩家直接在城市裡尋找或選擇第一門生意。

例如：
- 電商
- SaaS
- 咖啡店
- 物流
- 製造
- 房地產
- 顧問
- 國際貿易
- 媒體
- 飯店
- 汽車
- 能源

不鎖路線。

玩家可以：
咖啡店 → 食品品牌 → 工廠 → 電商 → 海外加盟

也可以：
電商 → 物流 → 製造 → 地產 → 控股集團

---

## 2.3 每一筆錢要有來源

不要使用模糊的：
> Company Income +$5,000/day

要讓玩家知道：
- 賣了多少
- 單價多少
- 成本多少
- 毛利多少
- 固定成本多少
- 稅前利益多少
- 現金什麼時候真正入帳

例如咖啡店：

84 cups × $7.80 = $655.20 revenue

扣除：
- Ingredients $181
- Labor $220
- Rent Allocation $95
- Utilities $19

Net Operating Profit = $140.20

SaaS：

1,242 subscribers × $20 = $24,840 MRR

扣除：
- Server
- Support
- Ads
- Salaries
- Refunds

---

## 2.4 問題本身就是遊戲內容

玩家公司越大，問題要改變。

Solo：
> 今天怎麼拿到第一個客戶？

10 人：
> 這個月發不發得出薪水？

100 人：
> 管理層、流程、部門是否失控？

1,000 人：
> 法規、海外、文化、供應鏈、匯率。

跨國企業：
> 併購、金融市場、地緣政治、跨境結算、監管。

---

## 2.5 沒有永遠正確的商業選項

每個選擇都應該有 trade-off。

銀行匯款：
+ 制度成熟
+ 可追蹤
- 較慢
- 跨境費用

Stablecoin：
+ 24/7
+ 快
+ 可程式化
- 技術風險
- 錢包風險
- 合規成本
- 對手方 / depeg 風險

自建工廠：
+ 毛利潛力
+ 控制力
- 固定成本
- 庫存
- 設備
- 人力

外包：
+ 彈性
- 單位成本較高
- 品質控制困難

---

## 2.6 Crypto 不是遊戲一開始的主角

遊戲前期應該像正常現代城市創業遊戲。

玩家先理解：
- 銀行
- 現金流
- 信用
- 國際匯款
- 信用狀
- Payment Processor
- Escrow
- 外匯

直到公司跨境後，才自然出現：
- Stablecoin
- Blockchain Settlement
- Smart Contract Escrow
- BTC 類資產

遊戲不能告訴玩家：
> Crypto 一定比較好。

要讓玩家自己理解：
> 它在某些問題上提供不同解法，但同樣帶來新風險。

---

## 2.7 破產不是 Game Over

公司可以倒閉。

玩家仍然活著。

可能發生：

公司關閉
→ 清算設備
→ 賣車
→ 搬回便宜住宅
→ 信用受損
→ 重新創業

失敗本身要成為玩家故事的一部分。

---

## 2.8 Multiplayer 不是首發必要功能

真人玩家公司合作暫時保留：

CITY VENTURE: ENTERPRISE NETWORK

未來大型更新或付費 Expansion。

功能可能包括：
- 玩家公司互相報價
- Counter Offer
- 長期供應合約
- OEM
- 物流
- 採購
- 加盟
- 授權
- Joint Venture
- 合資
- 長期服務合約

不得 Pay-to-Win。

付費內容應該買：
> 新玩法

不是：
> 公司收入 +50%

---

# 3. 遊戲的三層世界結構

## Layer 1 — World Map

玩家可看到全球虛構市場。

功能：
- 國家 / 經濟區
- 航線
- 海運
- 全球事件
- 市場資訊
- 海外分公司
- 海外投資
- 國際合約

---

## Layer 2 — City Exploration

玩家進入一座城市後，不應只看到 UI。

應該可以：
- 移動
- 走路
- 搭 Metro
- 開車
- 前往建築
- 進入商店
- 前往公司
- 去銀行
- 去市政府
- 去港口
- 去機場
- 回家
- 找 NPC

推薦視角：
2D 高解析像素風 top-down / 2.5D isometric-like exploration。

不要做成完整 3D。

---

## Layer 3 — Building Interior / Management

玩家進入：
- 自己公司
- 商店
- 銀行
- 公寓
- 市政府
- 倉庫
- 工廠
- 咖啡店
- 車商
- 機場
- 港口

才進入對應功能。

例如：

進自己辦公室
→ 坐到桌子
→ 開啟 Company OS

進銀行
→ 櫃台 / Banker
→ Loan / Account / Finance

進家中
→ 睡覺 / 裝潢 / 換衣服 / Laptop

---

# 4. 開場故事

玩家捏完角色。

畫面：

列車進入 Aurelia City。

手機顯示：

BANK BALANCE
$30,000

RENT DUE IN 14 DAYS
$1,250

玩家抵達 Riverside District。

第一間住處：

小型租屋。

內容：
- 床
- 小桌
- Laptop
- Phone
- 衣櫃
- 簡易廚房
- 幾個紙箱

朋友 Maya 傳訊息：

> 「真的辭職了？」

> 「所以你現在要做什麼？」

回答選項例如：
- 我要開公司。
- 我先看看這座城市。
- 我想自己做點東西。
- 我也還不知道。

沒有任何 Buff。

只影響對話。

第一個主要目標：

> Earn your first $1.

第二個目標：

> Generate enough income to pay your next rent.

第三個：

> Decide whether to formalize your business.

---

# 5. 主城市：AURELIA CITY

人口設定約 320 萬。

現代、國際、金融與產業高度混合的港灣城市。

它不是現實世界某一個城市，但視覺靈感可混合：
- 東京
- 新加坡
- 台北
- 首爾
- 溫哥華
- 紐約
- 香港

但不可直接複製。

---

# 6. AURELIA 主要區域

## 6.1 Riverside

玩家初始區。

內容：
- 小公寓
- 河岸
- 咖啡店
- 小型商店
- 公園
- Metro
- 便利生活

適合：
- 早期住宅
- 小生意
- 社交
- 日常生活

---

## 6.2 Startup Hub

內容：
- Co-working Space
- Startup Office
- Accelerator
- VC Office
- Event Space
- Cafe
- Software Firms

用途：
- SaaS
- 顧問
- 新創
- 招募
- 融資
- 人脈

---

## 6.3 Financial District

內容：
- Banks
- Investment Firms
- Corporate Towers
- Law Firms
- Accounting
- Consulting
- Stock / financial services

後期玩家公司總部可以搬來這裡。

---

## 6.4 Shopping Street

內容：
- 零售
- 咖啡
- 餐廳
- 服裝
- 百貨
- 消費品牌
- 夜生活

---

## 6.5 Harbor

內容：
- Container Port
- Warehouse
- Customs
- Freight
- Shipping
- Cold Chain

物流與國際貿易核心。

---

## 6.6 Industrial Zone

內容：
- Factory
- Manufacturing
- Equipment
- Energy
- Materials

---

## 6.7 Civic Center

內容：
- City Hall
- Business Registration
- Permit
- Tax Office
- Public Service
- Regulation

玩家很多公司法規流程在這裡完成。

---

## 6.8 Residential District

內容：
- 中階住宅
- 學校
- 公園
- 生活商店
- 社區

---

## 6.9 Luxury Heights

內容：
- Penthouse
- Villas
- Luxury Shopping
- Private Clubs
- Fine Dining
- High-end Car Dealership

---

## 6.10 International Airport

內容：
- Domestic
- International
- Business Class
- Cargo
- Charter
- Private Aviation

---

## 6.11 University District

內容：
- Research
- Talent
- Student Market
- Collaboration
- Innovation

---

## 6.12 Old Town

內容：
- 低租金老店
- 歷史建築
- 小商業
- 創業初期場地
- 藝術與文化

---

# 7. 世界市場

---

## 7.1 Northridge

定位：
Tech & Media

特色：
- 軟體
- SaaS
- 媒體
- 高薪人才
- 高市場消費力

風險：
- 成本高
- 競爭強
- 法規成熟

---

## 7.2 Auroria

定位：
Finance & Design

特色：
- 金融
- 精品
- 設計
- 高端消費

風險：
- 消費者保護嚴格
- 法規複雜
- 營運成本高

---

## 7.3 Zenkai

定位：
Advanced Technology & Manufacturing

特色：
- 半導體
- 電子
- 精密製造
- R&D

風險：
- 品質標準高
- 技術競爭
- 供應鏈依存

---

## 7.4 Solterra

定位：
Resources & Agriculture

特色：
- 食品
- 農業
- 天然資源
- 成長型市場

風險：
- 基礎建設
- 氣候
- 商品價格

---

## 7.5 Almeria

定位：
Trade & Energy

特色：
- 能源
- 航空
- 基礎建設
- 國際貿易

---

## 7.6 Karu

定位：
Emerging Market

特色：
- 年輕人口
- 快速成長
- 基礎建設需求

風險：
- 制度不成熟
- 匯率
- 政治
- 物流

---

## 7.7 Lumina

定位：
Manufacturing & Logistics

特色：
- 製造
- 港口
- 電子
- 物流
- 年輕消費市場

---

# 8. 主要生意系統

首發建議完整做好 6 種：
1. Ecommerce
2. SaaS
3. Food / Cafe
4. Logistics
5. Manufacturing
6. Real Estate

後續：
7. Consulting
8. International Trade
9. Media
10. Hotel / Tourism
11. Automotive
12. Energy

以下全部應該資料驅動，避免寫死。

---

# 9. ECOMMERCE / CONSUMER BRAND

## 起點

玩家找到批發品。

例如：

Wireless Earbuds
Wholesale $18
Market Price $30–55
MOQ 50

玩家決定：
- MOQ
- 進貨量
- 定價
- 是否投廣告
- 包裝
- 品牌

---

## 第一筆收入

商品：
採購
→ 拍照
→ Listing
→ Price
→ Ad
→ Order
→ Shipping
→ Review
→ Return

---

## 中期

解鎖：
- Warehouse
- Staff
- Ads
- Customer Service
- Inventory Forecast
- Multiple SKUs

---

## 後期

可發展：
- Own Brand
- DTC
- Retail Store
- International Sales
- Marketplace
- Acquisition

---

## 危機

- 庫存過剩
- Product Trend End
- Supplier Price Increase
- Poor Reviews
- Return Spike
- Counterfeit
- Platform Fee Increase
- Ad CAC Spike

---

# 10. SAAS / SOFTWARE

## 起點

可先接案。

例：

Bloom Cafe
Online reservation system
Budget $7,500

玩家決定：
- 自己做
- Outsource
- Hire Freelancer
- Delay

---

## 轉型

接案收入可以拿來做自己的 SaaS。

產品例：
- CRM
- POS
- Booking
- Project Management
- AI Tool
- Analytics
- HR

---

## 核心商業數字

- MRR
- ARR
- Paid Users
- Churn
- CAC
- Server Cost
- Support
- Enterprise Pipeline

---

## 後期

- Enterprise
- International
- API
- AI
- Acquisition
- Funding
- Global SaaS Company

---

## 危機

- Server Outage
- Data Breach
- Major Customer Churn
- Technical Debt
- Regulation
- Staff Exodus

---

# 11. CAFE / FOOD

## 起點

選店址：

Old Town：
低租金 / 中客流

Riverside：
中租金 / 穩定住宅客群

Financial District：
高租金 / 高客單

---

## 每日核心

Foot Traffic
× Conversion
× Average Ticket
= Revenue

扣：
- Ingredients
- Labor
- Rent
- Utilities
- Delivery Platform
- Waste

---

## 成長

Food Cart
→ Cafe
→ Second Store
→ Central Kitchen
→ Chain
→ Franchise
→ Food Brand
→ Overseas

---

## 危機

- Food Safety
- Ingredient Price
- Rent Increase
- Bad Review
- Staff Shortage
- Competitor
- Viral Popularity

---

# 12. LOGISTICS

## 起點

二手 Van。

工作：
- Furniture Delivery
- Ecommerce
- Restaurant Supply
- Documents
- Small Freight

---

## 核心

每輛車有：
- Capacity
- Time
- Fuel
- Maintenance

玩家要決定：
- 接哪些單
- 路線
- 時間
- 是否外包

---

## 成長

1 Van
→ Fleet
→ Warehouse
→ City Logistics
→ Contract Logistics
→ Port
→ Freight Forwarding
→ Air Cargo
→ Global Logistics

---

## 危機

- Oil Price
- Accident
- Driver Shortage
- Port Congestion
- Cargo Damage
- SLA Failure

---

# 13. MANUFACTURING

## 起點

小型 OEM。

產品：
- Accessories
- Home Goods
- Food Processing
- Electronic Accessories

---

## 流程

Raw Material
→ Equipment
→ Labor
→ Production
→ QC
→ Inventory
→ Shipping

---

## 指標

- Yield
- Capacity
- Downtime
- Unit Cost
- Defect Rate
- Lead Time

---

## 後期

- Automation
- Smart Factory
- Own Brand
- Overseas Plants

---

## 危機

- Equipment Breakdown
- Recall
- Material Shortage
- Tariff
- Client Cancellation
- Quality Failure

---

# 14. REAL ESTATE

## 起點

可選：
- Brokerage
- Rental Arbitrage
- Small Renovation

---

## 成長

Broker
→ Rental
→ Commercial Property
→ Land
→ Development
→ Luxury
→ Mall
→ Urban Development

---

## 特殊回饋

玩家的大型建案完成後：

必須真的出現在城市地圖。

例如：

VENTURE TOWER

成為永久地標。

---

## 危機

- Interest Rates
- Vacancy
- Construction Delay
- Material Cost
- Regulation
- Neighborhood Opposition
- Property Cycle

---

# 15. CONSULTING

開始：
個人接案。

服務：
- Marketing
- Strategy
- Finance
- Operations

限制：
時間就是庫存。

玩家必須管理：
- 報價
- Deadline
- Capacity
- Staff
- Quality

成長：

Freelancer
→ Boutique Firm
→ Corporate Clients
→ International Consulting Firm

---

# 16. INTERNATIONAL TRADE

玩法：

找便宜供應地
→ 找買家
→ 報價
→ 貿易條件
→ 保險
→ 報關
→ Shipping
→ FX
→ Payment

收入：
- Margin
- Commission
- Service Fee

後期：

Warehouse
→ Logistics
→ Own Brand
→ Manufacturing

這是跨境金融最早自然出現的路線之一。

---

# 17. MEDIA / ADVERTISING

起點：
- Video
- Design
- Social Media
- Ad Creative

發展：

Freelancer
→ Agency
→ Production
→ Creator Network
→ Media Group

核心：
- Clients
- Audience
- Campaign
- Reputation
- Delivery

---

# 18. HOTEL / TOURISM

發展：

B&B
→ Boutique Hotel
→ Business Hotel
→ Resort
→ International Hotel Group

核心：
- Occupancy
- ADR
- Reviews
- Seasonality
- Labor

---

# 19. AUTOMOTIVE

起點：
- Used Cars
- Rental

發展：
- Dealership
- Fleet
- Modification
- EV Startup
- Vehicle Brand

---

# 20. ENERGY

中後期產業。

Solar Installer
→ Solar Farm
→ Battery
→ EV Charging
→ Energy Company

高度依賴：
- Policy
- Subsidy
- Commodity Prices
- Grid
- Capital

---

# 21. 跨產業集團

玩家永遠可以成立第二家公司。

例：

Horizon Group
├ Horizon Retail
├ Horizon Logistics
├ Horizon Manufacturing
├ Horizon Properties
└ Horizon Capital

跨公司可有：
- Internal Contracts
- Transfer Pricing
- Shared Logistics
- Shared Property
- Shared Finance

但不要太早複雜化。

---

# 22. 公司階段

Stage 0 — Solo
Stage 1 — Small Business
Stage 2 — Growing Company
Stage 3 — Corporation
Stage 4 — National Company
Stage 5 — Multinational
Stage 6 — Global Group

階段不給 Buff。

只是：
- 組織變大
- 問題變複雜
- 可用工具變多

---

# 23. 合約系統

所有重要 B2B 行為盡量使用 Contract。

基本欄位：
- Buyer
- Seller
- Product / Service
- Quantity
- Unit Price
- Total
- Delivery Date
- Payment Terms
- Penalty
- Quality Requirement
- Currency
- Settlement Method

玩家可以：
- Accept
- Reject
- Counter Offer

例：

50,000 units
$8.20/unit
Net 30
Delivery 45 days
On-time SLA 97%

玩家可反提：

$7.80/unit
Net 45
Delivery 30 days

---

# 24. NPC 設計原則

NPC 不是 Buff。

NPC 是真實角色。

可能是：
- 客戶
- 員工
- 供應商
- 房東
- Banker
- Investor
- Government Staff
- Competitor
- Journalist
- Friend
- Neighbor

---

# 25. 主要 NPC

## Maya
玩家老朋友。

作用：
- 開場
- 日常
- 讓玩家保持「生活」感
- 不一定參與公司

---

## Daniel Wong
大型零售採購。

功能：
玩家可能透過他拿到第一張真正大型訂單。

但大型訂單也可能害死現金流。

---

## Elena Park
VC Investor。

她提供資本，但條件不一定划算。

玩家可拒絕。

---

## Marcus Reed
Bank Executive。

代表：
傳統金融。

不是反派。

---

## Lina Zhao
Cross-border Payment Founder。

在 Clearing Crisis 前後出場。

向玩家介紹新的 settlement rail。

---

## Omar Haddad
International Trader。

開啟海外供應鏈與國際交易。

---

## Victor Hale
大型企業家。

可能：
- 客戶
- 競爭對手
- 收購者
- 合作者

不能固定設定他為反派。

---

# 26. 故事架構：世界有主線，玩家沒有固定人生

CITY VENTURE 的世界會發生事件。

玩家選擇怎麼參與。

---

# 27. STORY CIRCLE

## 1 — YOU
玩家搬入 Aurelia。

只有：
$30,000
Laptop
Phone
Rental Apartment

---

## 2 — NEED
房租、水電、生活支出持續扣。

玩家必須產生收入。

---

## 3 — GO
玩家開始第一門生意。

第一次：
- Listing
- Client
- Store
- Contract
- Delivery

---

## 4 — SEARCH
玩家學會：
- Cost
- Price
- Cash Flow
- Customer
- Supplier
- Staff

---

## 5 — FIND
第一次真正成功。

可能：
- 大訂單
- 熱門店
- SaaS 快速成長
- 大客戶

玩家開始：
- 搬公司
- 招人
- 買車
- 換房

---

## 6 — TAKE
成功帶來代價。

- 現金流
- 管理
- Debt
- Supply Chain
- Regulation

接著世界發生 Clearing Crisis。

---

## 7 — RETURN
玩家進入海外。

開始面對：
- FX
- Customs
- Regulation
- International Banking
- Settlement
- Geopolitics

---

## 8 — CHANGE
玩家不再只是創業者。

可能成為：
- Local Business Owner
- Global Founder
- Industrial Group
- Property Developer
- Technology Company
- Trade Empire

遊戲最後不問：
> 你賺多少？

而是：
> 你建立了什麼？

---

# 28. 世界十年年表

## Year 1 — THE OPPORTUNITY
經濟成長。
利率低。
創業潮。

教玩家：
第一筆收入。

---

## Year 2 — GROWTH FEVER
房租、人事、房價上升。

快速成長的人開始遇到現金流壓力。

---

## Year 3 — SUPPLY SHOCK
全球供應鏈混亂。

海運大幅漲價。

影響：
- Ecommerce
- Manufacturing
- Trade

物流可能得到新機會。

---

## Year 4 — THE GREEN SHIFT
新能源政策出現。

新市場：
- EV
- Battery
- Solar
- Charging

---

## Year 5 — CLEARING CRISIS
主要國際金融清算出現嚴重中斷。

跨境付款延遲。

海外供應商開始要求：
> Prepay or alternative settlement.

這時才正式帶出：

- Bank Wire
- Payment Processor
- Stablecoin
- Other rails

---

## Year 6 — DIGITAL FINANCE BOOM
數位金融快速成長。

新的：
- Stablecoin
- Digital Assets
- Settlement Platforms
- Smart Contract

同時 Scam 增加。

---

## Year 7 — BRIDGE EXPLOIT
大型跨鏈系統遭攻擊。

玩家理解：

新金融工具不是沒有風險。

重要台詞：

> 「我們解決了一個信任問題，卻創造了另一個。」

---

## Year 8 — REGULATION WAVE
各國開始推出更完整的數位資產與金融監管。

Compliance 變成：
競爭成本
也是競爭優勢。

---

## Year 9 — GLOBAL CONSOLIDATION
全球併購潮。

玩家可能：
- Acquire
- Merge
- Be Acquired
- IPO
- Stay Private

---

## Year 10 — LEGACY
主線不強制結束。

進入長期 Sandbox。

系統開始生成玩家人生與企業 Legacy。

---

# 29. CRYPTO / BLOCKCHAIN 的正確定位

Crypto 是工具，不是遊戲目的。

---

## 情境 A：跨境付款

供應商：

> 「款項三天了還沒到。」

玩家比較：

Bank Wire
vs
Payment Processor
vs
Stablecoin

---

## 情境 B：Escrow

雙方互不信任。

玩家比較：

Lawyer Escrow
Bank Letter of Credit
Smart Contract Escrow

---

## 情境 C：Treasury

公司資產配置：

- Cash
- Bonds
- Foreign Currency
- BTC-like asset
- Stablecoin

每種有不同：
- Liquidity
- Volatility
- Counterparty Risk
- Regulation
- Operational Risk

---

# 30. 法規玩法

不要做：
法條 Quiz。

要做：
營運條件。

例：

玩家開支付公司。

監管要求：

- KYC
- AML
- Capital
- Cybersecurity
- Record Keeping
- Consumer Protection

玩家可以：
- 做完整合規
- 延後
- 只進其他市場
- 不做這產業

但所有選擇都有成本。

---

# 31. 法規內容原則

實際遊戲可以參考現實制度的概念：

- 公司登記
- 稅
- 勞動
- 消費者保護
- 資料保護
- Banking
- AML
- KYC
- Digital Asset Regulation
- Customs
- Product Safety
- Securities

但遊戲世界使用虛構國家。

不要把真實法規逐字塞進遊戲。

---

# 32. 全球事件系統

Event Engine 要支援：

CUSTOMER
- Big Order
- Cancel
- Late Payment
- Price Pressure

STAFF
- Resignation
- Hiring Shortage
- Conflict
- Management Failure

SUPPLY
- Shortage
- Strike
- Port Congestion
- Disaster

FINANCE
- Rate Hike
- Rate Cut
- Credit Tightening
- FX Shock

REGULATION
- New Tax
- Environmental Rule
- Import Rule
- Data Law

MARKET
- New Competitor
- Trend Boom
- Trend Collapse
- Consumer Shift

---

# 33. 城市生活系統

企業之外，玩家要有生活。

---

## 33.1 住宅

Small Apartment
→ Apartment
→ Premium Residence
→ Penthouse
→ Villa

---

## 33.2 裝潢

玩家可以放：
- Bed
- Sofa
- Desk
- TV
- Art
- Plants
- Bookshelf
- Kitchen
- Gym
- Bar
- Collection
- Office Corner
- Garage

裝潢主要提供：
- 個人化
- 收藏
- 視覺成就感
- 某些功能點

不要變成重數值 Buff。

---

# 34. 車輛

車不是純收藏。

城市交通時間會受到影響。

車輛階級：

- Used Compact
- Sedan
- SUV
- Sports Car
- Luxury Car

用途：
- City Travel
- Client Visit
- Logistics
- Lifestyle

---

# 35. 私人飛機

私人飛機不是：

+20 Efficiency

真正改變：

Travel Time。

例：

Aurelia → Auroria

Commercial:
消耗大半個遊戲日 + 固定班次

Private Jet:
幾小時 + 自由排程

代價：
- Purchase
- Maintenance
- Crew
- Fuel
- Hangar
- Insurance

如果公司規模不夠：

私人飛機可以把玩家現金流拖垮。

---

# 36. 角色建立 / 捏臉系統

玩家一開始必須能建立自己的角色。

純 cosmetic。

---

## 36.1 可調整

Face Shape
Hairstyle
Hair Color
Skin Tone
Eye Shape
Eye Color
Eyebrows
Mouth

---

## 36.2 身體 / 表現

提供多種 base presentation：

- Masculine
- Feminine
- Neutral / Free Style

不要給任何能力差異。

---

## 36.3 服裝分類

STARTUP CASUAL
OFFICE PROFESSIONAL
EXECUTIVE
LOGISTICS / SITE
LUXURY CITYWEAR
TRAVEL
HOME
FORMAL EVENING

---

## 36.4 配件

- Glasses
- Hats
- Bags
- Jewelry
- Watches
- Shoes
- Backpack
- Lanyard

---

# 37. 美術總方向

使用目前已確認的第一版 CITY VENTURE 視覺。

風格名稱：

# NEO-CIVIC PIXEL REALISM

關鍵詞：

Modern
Pixel Art
Contemporary
Clean
Premium
Warm
Readable
Urban
Business
Life Simulation

---

# 38. 不要的美術方向

禁止整款遊戲變成：

- 8-bit nostalgia
- SNES fantasy
- Cyberpunk
- Purple Crypto Neon
- Bitcoin Logo Everywhere
- Casino Aesthetic
- Mobile Gacha
- Low-effort pixel filters
- AI-looking inconsistent backgrounds

---

# 39. 像素尺度

角色應該是：

高解析像素風。

參考尺度：

Base character sprite:
約 32–48 px 寬
48–64 px 高

遊戲實際顯示可 nearest-neighbor scale 2x–4x。

環境：
16–32 px tiles / modular units。

不要做成過小 8×8 sprite。

角色需要能看出：
- 髮型
- 外套
- 鞋
- 包
- 表情
- 正裝 / 休閒差異

---

# 40. 角色視覺

基準角色風格：

- anime-inspired but grounded
- 頭身略 stylized
- 現代服裝
- 乾淨輪廓
- 中等細節
- 有明顯表情

需要：

Front
Side
Back

Expressions：

Neutral
Happy
Confident
Determined
Surprised
Thinking
Excited
Relaxed
Serious

---

# 41. 白天城市風格

畫面：

乾淨現代城市。

Financial District：
- Glass towers
- Trees
- Metro
- Cars
- Pedestrians
- Corporate signage
- Crosswalk
- Skybridge

色調：
- Sky Blue
- White
- Navy
- Green
- Warm Beige

不要：
過度霓虹。

---

# 42. 夜間城市風格

夜間要更 premium。

包含：

Financial District at Night
Luxury Skyline at Dusk
Penthouse Terrace
Executive Office
Luxury Condo
Nightlife Street

色彩：
- Navy
- Indigo
- Warm Amber
- Soft Purple
- Reflection

夜景可更 cinematic。

---

# 43. WORLD MAP 美術

世界地圖採：

高解析 Pixel World Map。

要有：

- Continents
- City Nodes
- Air Routes
- Shipping Routes
- Planes
- Cargo Ships
- Region Cards
- Mission Markers

世界市場：

Northridge
Auroria
Zenkai
Solterra
Almeria
Karu
Lumina

World Map UI 必須明確顯示：

- Flight time
- Shipping time
- Market
- Key industries
- Entry requirement
- Business opportunities

---

# 44. CITY MAP 美術

主城市：

Isometric / angled pixel map。

主要標籤：

Financial District
Startup Hub
Riverside
Harbor
Residential District
Metro Station
Airport
Shopping Street
Civic Center
Luxury Heights

地圖不是純 UI。

要讓玩家感覺：
這是一個真正可以走進去的城市。

---

# 45. METRO MAP

簡潔現代。

建議 5 線：

M1 Central Line
M2 Riverside Line
M3 Harbor Line
M4 Airport Line
M5 Loop Line

Metro 顯示：

Central → Airport 28 min
Central → Harbor 18 min
Startup → Financial 8 min
Riverside → Shopping 6 min

---

# 46. BUILDING EXTERIORS 美術規格

需要建立一致的 modular building kit。

---

## STARTUP OFFICE

Glass
Terraces
Plants
Open Workspace visible

Example brand:
Horizon Labs

---

## BANK

Stone + Glass
Reliable
Clean
Institutional

Example:
Nexus Bank

---

## APARTMENT TOWER

Retail Podium
Balconies
Warm interiors
Rooftop greenery

---

## MIXED-USE BLOCK

Ground-floor:
Cafe
Restaurant
Market
Books
Retail

Upper:
Office / Apartment

---

## HARBOR WAREHOUSE

Industrial
Blue/gray metal
Loading bays
Forklift
Containers

---

## CITY HALL

Modern civic architecture.

Stone
Glass
Flags
Public Plaza

---

## LUXURY CONDO

Curved glass
Large balconies
Premium entrance
Landscaping

---

## CAR DEALERSHIP

Glass showroom
Outdoor vehicles
Large signage

---

## AIRPORT

Large glass terminal
Control Tower
Taxi
Bus
Aircraft

---

# 47. 建築材質

需要 Pixel asset：

Glass
Concrete
Brick
Metal
Stone
Wood

---

# 48. 街道物件

需要：

Tree
Planter
Bench
Lamp
Traffic Cone
Bike
Metro Sign
Trash Bin
Digital Sign
Cafe Board
Umbrella
Street Direction Sign
Bus Stop
Billboard
Parking Meter

---

# 49. BUILDING INTERIORS

所有重要建築至少有可進入版本。

---

## Startup Office

功能：

Use Computer
Team Meeting
Whiteboard
Decorate

美術：

Open desks
Plants
Monitor
Bookshelf
Industrial lights

牆面可有：

IDEAS
PEOPLE
PRODUCT
GROWTH

---

## Executive Office

功能：

Manage Company
View Statistics
Client Meeting
Achievements

美術：

Executive Desk
Leather Chair
Sofa
Bookshelf
Trophy
City View

---

## Apartment / Home

功能：

Sleep
Change Outfit
Laptop
Decorate

內容：

Bed
Sofa
Coffee Table
Bookshelf
TV
Plant
Kitchen
Rug

---

## Bank Lobby

功能：

Open Account
Apply Loan
Talk to Banker
ATM

---

## Cafe

功能：

Coffee
Chat
Laptop
News

---

## Logistics Control Room

功能：

View Deliveries
Assign Vehicles
Monitor Map
Upgrade Systems

---

## Co-working Space

功能：

Rent Desk
Book Meeting
Network
Printer

---

## Clothing Store

功能：

Browse
Try On
Buy
Unlock Collection

---

## Wardrobe / Customization Room

功能：

Change Hairstyle
Change Outfit
Accessories
Save Preset
Randomize Look

---

# 50. UI 風格

主色：

Dark Navy
Blue
White
Muted gray

Accent：
Green for positive cash flow
Red for risk / loss
Gold for premium
Purple for luxury / special

避免：
過度 neon。

---

# 51. In-game HUD

HUD 要輕量。

只留：

- Time / Date
- Money
- Current objective
- Minimal Minimap
- Context prompt

不要一直遮住城市。

---

# 52. Company OS

只有在：
Office / Laptop / Management Terminal
開啟。

Menu：

Overview
Finance
Sales
Operations
Inventory
People
Contracts
Property
International
Reports

---

# 53. Company Overview

顯示：

Monthly Revenue
Monthly Profit
Cash
Accounts Receivable
Accounts Payable
Employees
Company Value

不要把數據簡化成一條「Business Power」。

---

# 54. 任務系統

任務類型：

MAIN STORY
BUSINESS OPPORTUNITY
SIDE MISSION
CLIENT MEETING
RECRUIT
PROPERTY
INVESTMENT
EVENT
SHOP
FOOD
TRAVEL
INFORMATION
SPECIAL EVENT

---

# 55. 任務不是打怪

例：

MAIN:
Earn Your First Dollar

BUSINESS:
A Local Cafe Needs a Booking Website

SIDE:
Help Maya Move Into Her New Apartment

CLIENT:
Meet Daniel at Riverside Cafe

PROPERTY:
Tour an Office Space

INVESTMENT:
Elena Wants to Talk

---

# 56. 第一章完整遊玩流程

## CHAPTER 1 — ARRIVAL

1. Character Creator
2. Arrival train cutscene
3. Riverside apartment
4. Maya message
5. Tutorial: phone
6. Walk to neighborhood
7. Visit Cafe
8. Visit Co-working
9. Discover business board
10. Select / discover first business route

目標：
First $1

---

# 57. 第二章

## CHAPTER 2 — FIRST CUSTOMER

依產業動態生成：

Ecommerce：
First Order

SaaS：
First Client

Cafe：
First Day Open

Logistics：
First Delivery

Manufacturing：
First Production Batch

Real Estate：
First Commission

---

# 58. 第三章

## CHAPTER 3 — OPEN FOR BUSINESS

玩家正式登記公司。

去 Civic Center。

需要：
- Company Name
- Business Type
- Basic registration fee
- Address

完成後玩家第一次看到：

[PLAYER COMPANY NAME]

真正出現在門牌 / UI。

---

# 59. 第四章

## CHAPTER 4 — GROWING PAINS

玩家第一次面臨：

- Too Many Orders
- Not Enough Time
- Inventory
- Staff
- Rent
- Cash

學到：
Revenue != Cash.

---

# 60. 第五章

## CHAPTER 5 — THE BIG CONTRACT

Daniel 提供一張大型合約。

條件可能：

$420,000
Net 60
Strict SLA

玩家可以：
Accept
Reject
Counter

如果接：
營收暴增
但 Working Capital 壓力巨大。

---

# 61. 第六章

## CHAPTER 6 — CASH IS OXYGEN

即使帳面獲利，
玩家可能沒現金。

選擇：

- Bank Loan
- Investor
- Cut Expenses
- Delay Expansion
- Sell Asset
- Negotiate Payment Terms

---

# 62. 第七章

SUPPLY SHOCK

全球物流價格上升。

玩家不同產業受到不同影響。

這裡要展現：
世界事件不是單純所有人 -10%。

---

# 63. 第八章

GREEN SHIFT

新能源成為新商機。

玩家可以：

完全不參與。

或：

投資
合作
轉型
成立新公司。

---

# 64. 第九章

CLEARING CRISIS

跨境金融危機。

玩家海外供應商：

> Payment still pending.

玩家第一次比較 Settlement options。

這是 Crypto 教育最重要章節。

---

# 65. 第十章

DIGITAL RAILS

玩家看到：
Stablecoin
Blockchain
Smart Contract

不是強制使用。

---

# 66. 第十一章

THE OTHER SIDE OF TRUST

Bridge exploit。

新金融也會失敗。

玩家理解：
Technology does not remove risk.
It changes risk.

---

# 67. 第十二章

REGULATION & SCALE

玩家公司已成跨國企業。

核心：
Compliance
Governance
Risk
M&A
Global Expansion

---

# 68. LIFE TIMELINE

遊戲自動記錄重要事件。

例如：

2031
Founded Horizon Labs

2032
First employee

2033
Revenue > $1M

2034
First international contract

2035
Cash-flow crisis

2036
Restructured

2038
Entered Auroria

2040
Acquired rival

2042
Group valuation $3.7B

玩家可以在：

Home Office
Company HQ
Legacy Screen

查看。

---

# 69. LEGACY

不給：
S / A / B / C Ranking。

只描述玩家歷史。

可能生成：

The Builder
The Merchant
The Innovator
The Operator
The Local Legend
The Comeback
The Quiet Owner

但不要說哪個比較好。

---

# 70. 未來多人 Expansion

名稱：

CITY VENTURE — ENTERPRISE NETWORK

核心：

玩家 A Company
↕ Contract
玩家 B Company

功能：

Supply
Procurement
OEM
Logistics
Franchise
License
Joint Venture
Long-term Contract

多人模式需等單機經濟完整後再做。

---

# 71. 技術實作方向

推薦：

Godot 4.x
2D
Desktop-first
Windows priority

原因：
- Pixel Art
- 2D City
- Fast iteration
- Lightweight
- Data-driven simulation

如果 repo 已有其他合理技術棧，先 readback，再決定是否保留。

---

# 72. 場景架構建議

Scenes:

Boot
CharacterCreator
WorldMap
CityMap
DistrictScene
BuildingExterior
BuildingInterior
Apartment
Office
Bank
Cafe
Harbor
Airport
CompanyOS

---

# 73. Data-driven 原則

不要把商業事件硬寫在 Scene Script。

建議資料：

/data/businesses/
/data/products/
/data/contracts/
/data/events/
/data/regions/
/data/buildings/
/data/npcs/
/data/story/
/data/regulations/

JSON / Resource 皆可。

---

# 74. Business Definition 示意

```json
{
  "id": "ecommerce",
  "name": "Ecommerce",
  "starting_capital_min": 1500,
  "revenue_models": [
    "product_sales"
  ],
  "cost_types": [
    "inventory",
    "ads",
    "shipping",
    "returns"
  ],
  "growth_paths": [
    "own_brand",
    "retail",
    "international"
  ]
}
```

---

# 75. Contract Definition 示意

```json
{
  "buyer": "daniel_retail_group",
  "seller": "player_company",
  "product_id": "coffee_beans",
  "quantity": 50000,
  "unit_price": 8.2,
  "payment_terms_days": 30,
  "delivery_days": 45,
  "sla_on_time": 0.97,
  "penalty_rate": 0.05
}
```

---

# 76. Event Definition 示意

```json
{
  "id": "port_congestion",
  "category": "supply_chain",
  "affected_regions": ["aurelia", "lumina"],
  "duration_days": 21,
  "effects": {
    "sea_shipping_cost_multiplier": 1.6,
    "sea_shipping_time_multiplier": 1.4
  }
}
```

事件效果可以量化。

但事件故事文字與 NPC 反應也要同步。

---

# 77. Economy Engine 最低需求

需要追蹤：

Player Cash
Company Cash
Revenue
Expenses
Receivables
Payables
Inventory
Debt
Assets
Property
Vehicles
Contracts
Employees
Market Demand
Prices
Interest Rate
FX
Shipping Cost

---

# 78. SAVE SYSTEM

必須可保存：

Character
Appearance
World Date
Player Position
Home
Furniture
Companies
Company Finances
Contracts
Inventory
Vehicles
Properties
NPC Relationships
Story Flags
Global Events
World Markets
Timeline

---

# 79. 時間系統

建議：

遊戲日。

不是 Real-time MMO。

一天約：
10–20 分鐘真實時間可調。

重要活動可以：
Pause / Schedule。

玩家應該能規劃：

Morning
Afternoon
Evening

---

# 80. 交通

Walking
Metro
Car
Flight

旅行要消耗遊戲時間。

這是城市空間有意義的關鍵。

---

# 81. AI / NPC 行為最低需求

NPC 不需要一開始就複雜 AI。

但至少：

Daily Schedule
Building Destination
Dialogue State
Relationship
Business Role

城市要看起來有人生活。

---

# 82. 世界動態最低需求

Traffic
Pedestrians
Day/Night
Weather optional
Shop Open/Close
Office activity
Harbor activity
Airport traffic

---

# 83. 像素圖資產規格

所有新素材必須維持：

Neo-Civic Pixel Realism。

需建立：

characters/
buildings/
interiors/
vehicles/
props/
ui/
world_map/
city_map/
portraits/
effects/

不要混入風格不一致的 AI 圖。

如果使用 AI 生成作為 concept：
必須再轉成一致 game-ready sprite。

---

# 84. 目前已確認的視覺概念板內容

以下內容是已經討論並接受的視覺設計方向，Claude Code 實作 UI / placeholder / asset spec 時要遵守。

---

## VISUAL BOARD A — CITY VENTURE BASELINE

主要內容：

Main Character
- Front
- Side
- Back

Expressions:
- Neutral
- Happy
- Determined
- Cheerful
- Surprised
- Thinking

Outfits:
- Default
- Office
- Casual City
- Executive

World:
- Financial District daytime

Interior:
- Startup Office
- Apartment

Vehicle:
- Modern Sedan

UI:
- Lv / Money / Time
- Company panel
- Goals

Palette:
Dark navy UI
Blue city
Warm interiors

這是目前使用者最明確表示「這個風格不錯」的基準。

---

## VISUAL BOARD B — CHARACTER CREATOR

已確定：

Character Creator 需要：

Face Shape
Hairstyle
Hair Color
Skin Tone
Eye Shape
Eye Color
Eyebrows
Mouth

提供：

Masculine
Feminine
Neutral

但全部只是 presentation。

Outfit Tabs：

Outfit
Accessories
Glasses
Hats
Bags
Jewelry

角色建立畫面需要保留：
高解析 modern pixel aesthetic。

---

## VISUAL BOARD C — DAY CITY

需要有：

Financial District
Mixed-use Neighborhood
Riverside Promenade
Startup Office
Apartment

場景感：

Sunny
Clean
Green
Busy
Modern

Street Props：
Bench
Tree
Lamp
Metro
Bike
Sign
Cafe Board

---

## VISUAL BOARD D — NIGHT / LUXURY

需要有：

Luxury Skyline at Dusk
Financial District Night
Executive Office
Luxury Condo
Rooftop Lounge
Premium Restaurant
Members Club

色調：

Navy
Purple
Amber
Warm Interior
Wet Reflection

---

## VISUAL BOARD E — WORLD MAP

需要：

World Map
Region Cards
Air Routes
Shipping Routes
Airport Network
Harbor
Travel UI
Mission Marker
Legend

---

## VISUAL BOARD F — CITY MAP

需要：

Isometric Main City Map

District labels：

Residential
Luxury Heights
Airport
Civic Center
Financial
Startup
Riverside
Metro
Harbor
Shopping

Metro map
Minimap
Marker icons
Neighborhood zoom

---

## VISUAL BOARD G — BUILDING EXTERIORS

需要：

Startup Office Building
Bank
Apartment Tower
Mixed-use Shops
Harbor Warehouse
City Hall
Luxury Condo
Car Dealership
Airport Terminal

以及：

Facade Materials
Architecture Props

---

## VISUAL BOARD H — BUILDING INTERIORS

需要：

Startup Office
Executive Office
Apartment
Bank Lobby
Cafe
Logistics Control Room
Co-working
Clothing Store
Wardrobe / Customization

每個場景都必須有：

Interactable Objects。

---

# 85. 品牌 / Signage 視覺語言

遊戲中虛構品牌可以建立一致品牌系統。

目前 concept 名稱：

Horizon Labs
Nexus Bank
Nexus Motors
Bloom Coffee
City Port Logistics
Riverside Tower

這些都只是暫定，可在最終品牌階段統一。

---

# 86. 音樂方向

非 Retro Chiptune 為主。

建議：

Day City：
Lo-fi / modern urban / light electronic

Office：
Minimal electronic

Financial District：
Clean corporate ambient

Night：
Downtempo / premium electronic

Harbor：
Industrial ambient

World Map：
Global modern ambient

仍可以有輕微 pixel-game texture。

---

# 87. 音效

Footsteps
Traffic
Metro
Cafe ambience
Office keyboard
Door
Phone notification
Cash register
Port crane
Airport
Car
Rain

避免：
Casino coin sound
Arcade jackpot

---

# 88. 首發範圍：不要一次做太大

第一個真正可玩 Vertical Slice：

Aurelia：
Riverside
Startup Hub
Financial District
Civic Center

可進入：

Apartment
Cafe
Co-working
Small Office
Bank
City Hall

一條完整生意：

Ecommerce 或 SaaS

推薦先做：
Ecommerce

原因：
從商品、庫存、訂單、物流、現金流都可以測試核心商業系統。

---

# 89. Vertical Slice 故事

Day 1:
Arrival

Day 2:
Discover wholesale market

Day 3:
Buy first inventory

Day 4:
Create listing

Day 5:
First order

Day 7:
Return / customer complaint

Day 10:
Need more inventory

Day 14:
Rent due

Day 20:
Large order opportunity

Day 30:
Month close

完成後玩家應該理解：

Money
Inventory
Revenue
Cost
Cash Flow
Customer

---

# 90. 第二條產業

加入 SaaS。

重用：
- Client
- Contract
- Payment
- Office
- Hiring

但商業邏輯完全不同。

---

# 91. 再加入餐飲、物流、製造、地產

每加入一個產業，要確認：

真的有不同玩法。

不要只是：
不同 icon + 不同收入公式。

---

# 92. Claude Code 開發優先順序

P0
- Project Boot
- Save
- Time
- Character Creator
- World / City navigation
- Basic player movement
- Apartment
- First business
- Finance
- Orders / contracts
- Story Chapter 1
- UI
- Pixel placeholder

P1
- Bank
- Civic
- NPC
- Vehicles
- More districts
- Second business
- Dynamic Events

P2
- Overseas
- Airport
- World Map
- FX
- Settlement
- Clearing Crisis

P3
- More industries
- Property
- Luxury
- Holdings

P4
- Enterprise Network multiplayer expansion

---

# 93. Definition of Done — Vertical Slice

不能只說「功能完成」。

至少：

1. New Game
2. Character Creator
3. Spawn in Apartment
4. Walk outside
5. City exploration
6. Enter buildings
7. Start business
8. Earn first revenue
9. Pay real costs
10. Inventory / customers work
11. Save / load
12. Day progresses
13. Month close
14. Story mission
15. Bankruptcy condition does not instantly game-over
16. UI matches visual bible
17. 30-minute human playtest
18. No blocking errors

---

# 94. 不可接受的偷工方式

不要：

- 把城市做成幾個卡片
- 玩家永遠站在 Dashboard
- 所有建築只是 menu
- 所有生意只有一個收入按鈕
- 所有 NPC 都是 text popup
- Crypto 一開場就出現
- 用角色能力值替代真正商業邏輯
- 用 Pay-to-Win
- 用 AI 生圖直接當最終 sprite，風格不一致
- 宣稱 Multiplayer 已完成但其實只是 mock

---

# 95. 開發時的產品原則

每做一個功能，問：

> 這是在模擬一個真正的選擇，還是在加一個數字？

如果只是加數字：
通常要重新設計。

---

# 96. CITY VENTURE 最終願景

玩家開始：

小公寓
$30,000
Laptop
Phone

幾十個遊戲年後：

他可能站在自己公司總部頂樓。

窗外：

有一棟他自己蓋的 Venture Tower。

港口：

他的物流公司正在裝貨。

機場：

他的私人飛機準備飛往 Zenkai。

手機：

海外供應商要求使用新的 settlement rail。

公司：

正在考慮一筆跨國併購。

家裡：

牆上顯示玩家從第一筆訂單開始的完整人生年表。

但另一個玩家可能：

從來沒有成為億萬富翁。

他只是在 Riverside 經營一間非常成功的咖啡店。

這兩種都是完整玩法。

---

# 97. 最後一句產品核心

> CITY VENTURE 不是一款「告訴玩家成功是什麼」的遊戲。

> 它是一座城市、一個經濟世界和一套真實的商業規則，讓玩家自己決定要建立什麼。

---

# 98. Claude Code 接手任務

接手後請：

1. 先完整閱讀本文件。
2. 檢查目前 repo / prototype。
3. 不要立即重寫。
4. 建立 ARCHITECTURE.md。
5. 建立 ROADMAP.md。
6. 建立 GAME_DATA_SCHEMA.md。
7. 建立 ART_ASSET_MANIFEST.md。
8. 建立 STORY_IMPLEMENTATION.md。
9. 將現有 Dashboard 降級為「Company OS」。
10. 建立 World Map → City → Building → Company OS 的場景架構。
11. 先完成 Aurelia Vertical Slice。
12. 每個 milestone 都需要實際可玩測試。
13. 所有完成聲明都需附實際 evidence。
14. 不要提前實作 Multiplayer。
15. 不要把核心商業模擬簡化成 passive income。

---

# 99. 建議第一個 Claude Code Milestone

## CITY-VENTURE-VERTICAL-SLICE-001

目標：

建立第一個真正「像遊戲」而不是 Dashboard 的版本。

必須包含：

- Character Creator
- Riverside
- Startup Hub
- Apartment
- Cafe
- Co-working
- Small Office
- Basic walking
- Metro stub
- Day / Night
- Ecommerce first business
- First order
- First customer issue
- Inventory
- Money
- Rent
- Company registration
- Company OS
- Save / Load
- Story Chapters 1–3
- Pixel art placeholder consistent with Visual Bible

完成後錄製：
- 5–10 分鐘 gameplay walkthrough
- 從 New Game 開始
- 不跳步

並提供：
- build
- test report
- screenshots
- video
- known issues

---

# 100. 專案目前的核心共識摘要

1. 現代像素風。
2. 世界地圖不是 Dashboard。
3. 玩家可以在城市裡生活。
4. 進公司才進管理介面。
5. 可以捏臉。
6. 沒有職業 Buff。
7. 玩家選的是生意。
8. 每個生意要有不同賺錢方式。
9. 每個產業可以成長與轉型。
10. 可以跨產業。
11. 可以跨國。
12. 法規是玩法。
13. Crypto 是後期工具。
14. Crypto 有優點也有風險。
15. 可以買房。
16. 可以裝潢。
17. 可以買車。
18. 可以買豪宅。
19. 私人飛機真的影響跨國移動。
20. 公司可以破產，但玩家可以重來。
21. 世界有經濟事件。
22. 玩家人生沒有固定劇本。
23. 玩家歷史會被記錄。
24. 最終沒有單一「最佳結局」。
25. 真人玩家公司合作留給未來 Enterprise Network Expansion。
26. 付費不能直接賣競爭優勢。
27. 品質優先。
28. 所有內容都應該讓玩家感覺自己真的在經營一家公司、生活在一座城市，而不是操作一份試算表。

END OF MASTER HANDOFF
