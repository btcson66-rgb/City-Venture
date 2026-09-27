# CITY VENTURE — Spec Readback

> 來源：`docs/reference/CITY_VENTURE_MASTER_HANDOFF_FOR_CLAUDE_CODE.md`（Master Handoff v1.0，3,824 行，§0–§100 全部讀完）
> 以及 5 張已確認概念板（`docs/reference/concept_boards/`）與使用者 kickoff 指令。
> 目的：用我自己的話回述產品基準，讓使用者能在寫 code 前抓出誤解。
> 本文件**不**重新設計遊戲。發現的模糊處列在 §H，並寫明我採取的處理方式。

---

## A. 我理解的遊戲核心

### A.1 玩家在玩什麼

玩家扮演一個剛辭職、搬進 **Aurelia City** 的普通人。起點只有 **$30,000、一台 Laptop、一支 Phone、一間 Riverside 小租屋**，房租 $1,250 十四天後到期。

玩家不是在「點按鈕等收入」，而是在一座可以走動的城市裡**過生活並經營生意**：走出家門、去咖啡店、去 Co-working、看 Business Board、找供應商、進貨、上架、出貨、處理退貨、繳房租、去市政府登記公司、去銀行開帳戶、租辦公室，最後坐在自己辦公桌前打開 Company OS。

### A.2 核心 Loop

```
生活（時間流動、房租、生活支出）
  → 在城市中移動、進入建築、遇到 NPC / 機會
  → 做商業決策（進什麼貨、訂什麼價、要不要投廣告、接不接單、要不要借錢）
  → 模擬引擎產生結果（訂單、退貨、評價、應收應付、現金）
  → 問題出現（現金不足、供應商漲價、大單、客訴）
  → 玩家再回到城市去處理（銀行、市政府、辦公室、供應商）
  → 月結：看清楚每一塊錢從哪來、去哪
```

短循環是「一天」（早上／下午／晚上／夜晚）；中循環是「一個月」（Month Close）；長循環是「十年世界年表」與公司階段 Stage 0–6。

### A.3 城市探索與公司管理的關係

**城市是遊戲本體，管理介面是城市裡的工具。**

- 管理介面（Company OS）只能在「特定地點的特定設備」開啟：公寓 Laptop、Co-working 租用桌、Small Office 辦公桌／Management Terminal。
- 很多商業功能**必須實際去某棟建築**才能完成：公司登記在 City Hall、商業帳戶在 Bank、辦公室在 Startup Hub 租、貨放在家裡或辦公室要去那裡打包。
- 移動與時間有成本：走路、搭 Metro 都消耗遊戲時間；商店有營業時間。因此「在哪裡」是一個真的決策，而不是裝飾。

### A.4 商業模擬的核心

- **每一筆錢都有來源**（§2.3）：賣了幾件 × 單價、COGS、平台費、運費、廣告、退款、房租——全部逐項可追。
- **每個選擇都有 trade-off**（§2.5）：便宜供應商 vs 高品質、Courier vs 自己送、投廣告 vs 省錢、接大單 vs 現金流壓力。
- **Profit ≠ Cash**：營收認列（交貨）與現金入帳（平台週結、B2B Net 30）分開；應收／應付（AR／AP）要真實存在。
- 問題隨公司規模改變（§2.4），Stage 不給 Buff，只是讓組織與問題變複雜（§22）。
- 自問準則（§95）：「這是在模擬一個真正的選擇，還是在加一個數字？」

### A.5 Story 的核心

**世界有主線，玩家沒有固定人生**（§26）。

- 世界會按 Year 1–10 年表發生總體事件（利率、供應鏈、能源政策、清算危機…），所有產業受到**不同**影響（§62）。
- 玩家自己決定怎麼參與；個人故事由系統記錄成 **Life Timeline** 與 **Legacy**（§68–69），沒有 S/A/B 評分、沒有唯一好結局。
- 章節（Chapter 1–12）是「世界狀態 + 玩家進度」觸發的情境，不是固定劇本。
- 對話短、自然、有個性；**教育透過處境，不透過講課**（使用者 §31–33）。

### A.6 Crypto 在這個遊戲中的定位

- **工具，不是目的**（§29）。前期完全不出現（§2.6）。
- 玩家先學銀行、現金流、信用、國際匯款、信用狀、Payment Processor、Escrow、外匯。
- 直到**跨境生意 + Year 5 Clearing Crisis**，海外供應商說「款項三天還沒到」，Stablecoin／Blockchain Settlement／Smart Contract Escrow 才作為**其中一個**選項出現。
- 必須同時呈現優點（24/7、快、可程式化）與風險（技術、錢包、合規、對手方、depeg），Year 7 Bridge Exploit 讓玩家體驗「我們解決了一個信任問題，卻創造了另一個」。
- 遊戲內 Crypto 永遠是**純模擬**：不接真錢包、真 USDC、真鏈、真錢（使用者 §24）。

### A.7 玩家成功／失敗如何形成

- **成功沒有被定義**（§1、§96）：Riverside 一間很成功的咖啡店與跨國控股集團都是完整玩法。
- 成功來自玩家的**決策品質**：定價、成本控制、接單、借貸、擴張、支付方式、危機處理、轉型。
- **失敗是故事的一部分**（§2.7）：公司可以倒閉，玩家仍活著 → 清算設備 → 賣車 → 搬回便宜住宅 → 信用受損 → 重新創業。絕不直接 Game Over。

---

## B. 不可違反的 Product Rules

| # | 規則 | 來源 | 在實作上的具體意義 |
|---|------|------|------------------|
| R1 | **沒有職業 Buff** | §2.1 | 不存在 Engineer/Sales/Rich Family 等起始加成；不存在 Intelligence/Charisma/Luck。 |
| R2 | **沒有角色能力值決定商業成功** | §2.1, §94 | Player 資料結構中**不得**有影響商業公式的屬性欄位；Code review 檢查點。 |
| R3 | **玩家選的是生意，不是職業** | §2.2 | 開局後在城市（Business Board）發現並選擇生意；路線不鎖、可跨產業。 |
| R4 | **每門生意必須有實際收入來源** | §2.3, §91 | 收入必須來自訂單／合約／客流 × 單價等可追溯交易；禁止「Company Income +$X/day」。每個產業要有真的不同玩法，不只是換 icon 與公式。 |
| R5 | **Dashboard 只能是 Company OS** | §0, §52 | 只能在 Laptop／Office desk／Management Terminal 開啟；絕不當主畫面。 |
| R6 | **玩家要能探索城市** | §3 Layer 2, §94 | 走路、移動於地點間、看到 NPC 與車流；城市不能是卡片或選單。 |
| R7 | **玩家可以進入建築** | §3 Layer 3, §49 | 進入 Interior Scene → 走到互動點 → 開功能；不是 Click → Menu。 |
| R8 | **世界地圖與城市地圖必須存在** | §3, §43–45 | 場景架構必須包含 World Map → City Map；World Map 的海外玩法屬 P2，但架構與畫面層級要在。 |
| R9 | **Crypto 不能一開始就出現** | §2.6 | Year 5 Clearing Crisis 之前不出現任何 Crypto 相關 UI／對話／選項。 |
| R10 | **Crypto 不能被描述成永遠比較好** | §2.5, §29 | 所有 settlement option 必須資料化其 trade-off（速度、費用、技術／合規／對手方風險）。 |
| R11 | **破產不能直接 Game Over** | §2.7, §93-15 | 現金趨近 0 → 警告 → 賣庫存／縮減支出 → 繼續玩；正式 Bankruptcy 流程未來擴充。 |
| R12 | **Multiplayer 暫時不能當 P0** | §2.8, §70, 使用者 §23 | 不實作 Enterprise Network；只保留 `CompanyEntity ↔ CompanyEntity` 的合約邊界。 |
| R13 | **不能 Pay-to-Win** | §2.8 | 付費內容只能是新玩法，不是收入倍率。目前不做任何付費。 |
| R14 | **必須使用現代高品質像素風** | §37–39, §83 | Neo-Civic Pixel Realism；Placeholder 也要遵守 pixel grid、比例、調色盤、UI theme；禁止純色塊冒充最終視覺。 |
| R15 | **沒有永遠正確的商業選項** | §2.5 | 每個選擇資料化成本與風險。 |
| R16 | **NPC 不是 Buff** | §24 | NPC 是有角色、行程、關係與商業身分的人，不是數值加成。 |
| R17 | **裝潢、車、飛機不給純數值 Buff** | §33.2, §34, §35 | 車改變旅行時間、飛機改變航程時間，並附帶真實成本。 |
| R18 | **法規是營運條件，不是 Quiz** | §30 | 法規 = 成本／流程／准入條件的選擇。 |
| R19 | **資料驅動** | §73 | 商品、生意、事件、NPC、建築、故事、區域放在 `/data`，不寫死在 Scene Script。 |
| R20 | **不假裝完成** | 使用者 §28, §94 | 狀態分為 Implemented / Mocked / Placeholder / Planned / Blocked。 |

---

## C. 世界架構

```
WORLD MAP                    全球虛構市場（Aurelia + 7 個海外市場）、航線、海運、全球事件
  └─ CITY (Aurelia City)     城市地圖（isometric overview）、Metro 網路、12 個區域
       └─ DISTRICT           可走動的街區場景（街道、人行道、車流、NPC、道具、出入口）
            └─ BUILDING EXTERIOR   建築立面 + 門 + 招牌（營業時間、玩家公司名招牌）
                 └─ BUILDING INTERIOR   可走動室內（家具碰撞、NPC、可互動物件）
                      └─ CONTEXTUAL MANAGEMENT UI   依設備開啟：Company OS / 銀行櫃台 / 登記窗口 / 衣櫃…
```

- **Aurelia City**：人口約 320 萬的現代港灣城市，靈感混合東京、新加坡、台北、首爾、溫哥華、紐約、香港，但不可直接複製。
- **Aurelia 12 區**：Riverside（起始）、Startup Hub、Financial District、Shopping Street、Harbor、Industrial Zone、Civic Center、Residential District、Luxury Heights、International Airport、University District、Old Town。
- **Metro 5 線**：M1 Central、M2 Riverside、M3 Harbor、M4 Airport、M5 Loop。
- **海外 7 市場**：Northridge（Tech & Media）、Auroria（Finance & Design）、Zenkai（Advanced Tech & Manufacturing）、Solterra（Resources & Agriculture）、Almeria（Trade & Energy）、Karu（Emerging）、Lumina（Manufacturing & Logistics）。
- **交通**：Walking / Metro / Car / Flight，皆消耗遊戲時間（§80）。
- **視角**：2D 高解析像素 top-down / 2.5D isometric-like；**不做完整 3D**。

Vertical Slice 範圍（§88 + §99 + 使用者指令）：Riverside、Startup Hub 完整可走；Civic Center、Financial District 為可走的小街區（承載 City Hall、Bank）；可進入 Apartment、Cafe、Co-working、Small Office、Bank、City Hall。

---

## D. 產業

所有產業資料驅動（§8、§73）。

### P0 / Initial Full Industries（首發完整六產業）

| 產業 | 收入來源 | 核心數字 | 起點 → 成長 | 危機 |
|------|---------|---------|------------|------|
| **Ecommerce / Consumer Brand**（Vertical Slice 首做） | 商品銷售（件數 × 售價） | Wholesale、MOQ、庫存、售價、轉換、廣告 CAC、退貨、評價 | 批發品 → Listing → Warehouse/Staff/多 SKU → Own Brand/DTC/Retail/International | 庫存過剩、趨勢結束、供應商漲價、差評、退貨潮、仿冒、平台費上升、CAC 上升 |
| **SaaS / Software** | 接案款 → 訂閱 MRR | MRR/ARR、Paid Users、Churn、CAC、Server、Support、Enterprise Pipeline | 接案（Bloom Cafe 訂位系統 $7,500）→ 自有 SaaS → Enterprise/International/API | Outage、Data Breach、大客戶流失、技術債、法規、人才流失 |
| **Food / Cafe** | 客流 × 轉換 × 客單 | 食材、人力、租金、水電、外送平台、耗損 | Food Cart → Cafe → 二店 → 中央廚房 → 連鎖 → 加盟 → 海外 | 食安、原料漲價、租金、差評、缺工、競爭、爆紅 |
| **Logistics** | 運送單價 | 車輛容量、時間、油、維修、SLA | 1 Van → Fleet → Warehouse → Contract Logistics → Port → Freight Forwarding → Air Cargo | 油價、事故、缺司機、港口壅塞、貨損、SLA 失敗 |
| **Manufacturing** | OEM 單價 × 產量 | Yield、Capacity、Downtime、Unit Cost、Defect Rate、Lead Time | 小型 OEM → Automation → Smart Factory → Own Brand → 海外廠 | 設備故障、召回、缺料、關稅、客戶取消、品質失敗 |
| **Real Estate** | 佣金／租金／開發 | 利率、空置、工期、材料 | Broker → Rental → Commercial → Land → Development → Luxury → Mall → Urban（建案真的出現在城市地圖，例 VENTURE TOWER） | 利率、空置、延期、材料、法規、鄰里反對、景氣循環 |

### Future（後續產業）

| 產業 | 核心 |
|------|------|
| Consulting | 時間就是庫存；報價、Deadline、Capacity |
| International Trade | 供應地 → 買家 → 報價 → 貿易條件 → 保險 → 報關 → Shipping → FX → Payment；跨境金融最早出現的路線 |
| Media / Advertising | Clients、Audience、Campaign、Reputation |
| Hotel / Tourism | Occupancy、ADR、Reviews、Seasonality |
| Automotive | Used Cars/Rental → Dealership → EV Startup |
| Energy | Solar → Battery → EV Charging；高度依賴政策與資本 |

跨產業集團（§21）：玩家永遠可成立第二家公司（例 Horizon Group），但「不要太早複雜化」→ P3。

---

## E. 世界故事線（Year 1–10）

| Year | 名稱 | 世界狀態 | 對玩家的意義 |
|------|------|---------|------------|
| 1 | **The Opportunity** | 經濟成長、低利率、創業潮 | 第一筆收入 |
| 2 | **Growth Fever** | 房租、人事、房價上升 | 快速成長者遇到現金流壓力 |
| 3 | **Supply Shock** | 全球供應鏈混亂、海運大漲 | Ecommerce／製造／貿易受傷；物流得到機會 |
| 4 | **The Green Shift** | 新能源政策 | EV、Battery、Solar、Charging 新市場；可完全不參與 |
| 5 | **Clearing Crisis** | 國際清算嚴重中斷、跨境付款延遲 | 海外供應商要求預付或替代結算；**第一次**比較 Bank Wire / Payment Processor / Stablecoin / 其他 rails |
| 6 | **Digital Finance Boom** | Stablecoin、數位資產、Settlement Platform、Smart Contract 成長；Scam 同時增加 | 新工具＋新詐騙 |
| 7 | **Bridge Exploit** | 大型跨鏈系統遭攻擊 | 「我們解決了一個信任問題，卻創造了另一個。」Technology does not remove risk. It changes risk. |
| 8 | **Regulation Wave** | 數位資產與金融監管完整化 | Compliance 同時是成本與競爭優勢 |
| 9 | **Global Consolidation** | 全球併購潮 | Acquire / Merge / Be Acquired / IPO / Stay Private |
| 10 | **Legacy** | 主線不強制結束 → 長期 Sandbox | 系統生成玩家人生與企業 Legacy（The Builder / Merchant / Innovator / Operator / Local Legend / Comeback / Quiet Owner，不排名） |

個人章節（§56–67）：Ch1 Arrival → Ch2 First Customer → Ch3 Open for Business → Ch4 Growing Pains → Ch5 The Big Contract（Daniel，$420,000 Net 60）→ Ch6 Cash Is Oxygen → Ch7 Supply Shock → Ch8 Green Shift → Ch9 Clearing Crisis → Ch10 Digital Rails → Ch11 The Other Side of Trust → Ch12 Regulation & Scale。

Story Circle（§27）：YOU → NEED → GO → SEARCH → FIND → TAKE → RETURN → CHANGE；結尾問「你建立了什麼？」而不是「你賺多少？」。

主要 NPC（§25）：Maya（老朋友、生活感）、Daniel Wong（大型零售採購；大單也可能害死現金流）、Elena Park（VC，條件不一定划算）、Marcus Reed（銀行主管，傳統金融，**不是反派**）、Lina Zhao（跨境支付創辦人，Clearing Crisis 前後出場）、Omar Haddad（國際貿易商）、Victor Hale（大企業家，客戶／對手／收購者／合作者，**不能固定為反派**）。

---

## F. 美術方向 — **NEO-CIVIC PIXEL REALISM**

關鍵詞：Modern · Pixel Art · Contemporary · Clean · Premium · Warm · Readable · Urban · Business · Life Simulation。
使用者明確認可的基準：**Visual Board A**（深海軍藍 UI、藍色城市、溫暖室內）。

**禁止**：8-bit 懷舊、SNES 奇幻、Cyberpunk、紫色 Crypto 霓虹、到處 Bitcoin logo、賭場美學、手遊 Gacha、低成本像素濾鏡、AI 感不一致背景、未經轉換的 AI 生圖當最終 sprite。

| 項目 | 規格 |
|------|------|
| **Character** | Base sprite 約 32–48 px 寬 × 48–64 px 高；nearest-neighbor 放大 2×–4×；anime-inspired but grounded、頭身略 stylized、現代服裝、乾淨輪廓、中等細節；Front / Side / Back；需看得出髮型、外套、鞋、包、表情、正裝／休閒差異。表情：Neutral、Happy、Confident、Determined、Cheerful、Surprised、Thinking、Excited、Relaxed、Serious。 |
| **City** | 環境 16–32 px tiles／modular units；乾淨現代城市：玻璃塔、樹、Metro、車、行人、企業招牌、斑馬線、天橋。 |
| **Building Exterior** | 一致的 modular kit；Startup Office（玻璃、露台、植物、可見開放辦公）、Bank（石材＋玻璃、機構感）、Apartment Tower（零售裙樓、陽台、暖光、屋頂綠化）、Mixed-use（一樓 Cafe/餐廳/市場，上層辦公/住宅）、Harbor Warehouse（藍灰金屬、卸貨口、堆高機、貨櫃）、City Hall（石＋玻璃、旗、廣場）、Luxury Condo、Car Dealership、Airport。材質：Glass、Concrete、Brick、Metal、Stone、Wood。 |
| **Building Interior** | 每個場景都要有 Interactable Objects。Startup Office 牆面 IDEAS / PEOPLE / PRODUCT / GROWTH；溫暖木質、植物、吊燈、窗外城市。 |
| **Day** | Sky Blue、White、Navy、Green、Warm Beige；Sunny／Clean／Green／Busy／Modern；不過度霓虹。 |
| **Night** | 更 premium、cinematic：Navy、Indigo、Warm Amber、Soft Purple、濕地反光；窗戶暖光、路燈。 |
| **World Map** | 高解析 Pixel World Map：大陸、城市節點、航線、海運線、飛機、貨櫃船、Region Card、Mission Marker、Legend；顯示 Flight time、Shipping time、Market、Key industries、Entry requirement、Business opportunities。 |
| **City Map** | Isometric／angled pixel map，區域標籤卡（Financial、Startup、Riverside、Harbor、Residential、Metro、Airport、Shopping、Civic、Luxury）；Metro map、Minimap、Marker icons、Neighborhood zoom。要讓人覺得「這是可以走進去的城市」。 |
| **UI** | Dark Navy、Blue、White、Muted Gray；Accent：Green = 正向現金流、Red = 風險／虧損、Gold = premium、Purple = luxury/special；避免過度 neon。HUD 只留 Time/Date、Money、Objective、Minimap、Context prompt。 |
| **Character Creator** | Face Shape、Hairstyle、Hair Color、Skin Tone、Eye Shape、Eye Color、Eyebrows、Mouth；Presentation：Masculine / Feminine / Neutral（純外觀）；Tabs：Outfit、Accessories、Glasses、Hats、Bags、Jewelry；保留高解析 modern pixel aesthetic。 |
| **Vehicles** | Used Compact、Sedan、SUV、Sports Car、Luxury Car；Board A 的 Modern Sedan（多色、多角度）。車輛影響城市旅行時間。 |
| **Luxury Assets** | Board D：Luxury Skyline at Dusk、Financial District Night、Executive Office、Luxury Condo、Rooftop Lounge、Premium Restaurant、Members Club；Penthouse、Villa、Private Jet（改變跨國旅行時間，附真實成本）。 |

概念板取樣的調色盤錨點（Board A 右下角 palette strip）：Off-white `#FCFEFF`、Navy `#1B273F`／`#32415E`、Coral Red `#E06853`、Deep Teal `#344C56`、Forest `#3E5C57`、Warm Taupe `#94817C`、Leaf Green `#8FA663`、Slate `#334459`、Lavender Gray `#A8ADC7`、Slate Blue `#848EA6`；UI 背景 `#0D1B2B`／`#121F31`、Accent Blue `#346AB0`。

音樂（§86）：非 Retro Chiptune 為主；Day = lo-fi／modern urban，Office = minimal electronic，Night = downtempo。音效避免賭場金幣聲、Arcade jackpot。

---

## G. Vertical Slice（CITY-VENTURE-VERTICAL-SLICE-001）驗收清單

合併 §93 Definition of Done、§99 Milestone、使用者指令 §5–§29：

1. New Game
2. Character Creator（全部 8 項臉部參數 + 3 種 Presentation + 服裝 Startup Casual / Office Professional / Home；純 cosmetic）
3. Arrival Sequence（列車進 Aurelia、手機顯示 $30,000 / Rent $1,250 due in 14 days）→ Riverside Apartment；Laptop + Phone；Maya 訊息；目標「Earn Your First Dollar」
4. Riverside 真實可走：Apartment、Cafe、Co-working（經 Startup Hub）、室外、NPC、車流、環境
5. Startup Hub：Street、Co-working、Small Office、Cafe、NPC、Business Board
6. 室內：Apartment、Cafe、Co-working、Small Office、Bank、City Hall（進入 → 走到互動點 → 開功能）
7. Ecommerce 完整鏈：Product、Supplier、Wholesale Cost、MOQ、Inventory、Listing、Price、Customer Order、Shipping、Return、Review、Advertising、Revenue、Expenses、Cash；產品從 data file 讀
8. Month Close：Revenue、COGS、OpEx、Rent、Advertising、Shipping、Refunds、Profit、Cash；Profit ≠ Cash；AR/AP 至少預留
9. Business Registration（Civic Center / City Hall：Company Name → 出現在 Company OS、Contract、Office Sign、Timeline）
10. Company OS（Small Office 辦公桌互動開啟）：Overview、Finance、Sales、Operations、Inventory、People、Contracts
11. Story Chapter 1–3
12. ≥3 個 Dynamic Event，真的影響 Money / Inventory / Decision
13. Failure State：Warning → Sell Inventory / Reduce Spending → Continue
14. Save / Load（Character、Appearance、Date、Time、Cash、Position、Inventory、Orders、Company、Story）
15. Time System（Morning/Afternoon/Evening/Night、Open/Closed）
16. Placeholder Pixel Art 遵守 pixel grid／比例／調色盤／UI theme
17. HUD 簡潔：Money、Time、Objective、Minimap、Interaction Prompt
18. Metro stub、Day/Night
19. Evidence：screenshots/、videos/、logs/、test-reports/、`QA_REPORT.md`；5–10 分鐘不剪輯 gameplay video
20. 30-minute human playtest（需要真人；我只能提供自動化 walkthrough 並誠實標註）

---

## H. 規格中的模糊處與我採取的處理方式

依使用者 §34 優先序：已確認 Product Rules → Master Handoff → 既有 Prototype（無）→ 最小合理實作。以下都**不改變核心玩法**：

| # | 模糊處 | 處理 |
|---|--------|------|
| H1 | §88 首發區域列 Riverside、Startup Hub、Financial District、Civic Center；§99 只列 Riverside、Startup Hub。 | Riverside、Startup Hub 為完整街區；Civic Center、Financial District 做成較小但真的可走的街區（承載 City Hall、Nexus Bank），經 Metro stub 或步行抵達。 |
| H2 | 表情列表：§40 列 9 種、Board A 列 6 種。 | Manifest 取聯集；Slice 先做 Portrait 用的 Neutral / Happy / Thinking / Surprised。 |
| H3 | 服裝：§36.3 八類、Board A 四種、使用者指定至少三種。 | Slice 實作 Startup Casual、Office Professional、Home；其餘在 Manifest 標 Planned。 |
| H4 | §79 一天 10–20 分鐘真實時間，但 Slice 要跑完一個月。 | 清醒時段約 11 分鐘真實時間（可調）；床上 Sleep 跳到隔天早上；另有 Hold-to-fast-forward。 |
| H5 | §89 Day 2 / 3 / 4… 的故事排程。 | 視為「典型節奏」而非硬性鎖定：依玩家行動觸發，並以日期做提示（例 Day 14 房租、Day 20 大單機會條件）。 |
| H6 | 「Earn your first $1」要在營收認列還是現金入帳時完成？ | 在第一筆訂單**送達（營收認列）**時完成；同時手機顯示「平台款項將於週一撥付」— 讓 Profit ≠ Cash 從第一筆就自然出現。 |
| H7 | 公司登記前，生意屬於誰？現金是否分開？（§77 同時追蹤 Player Cash 與 Company Cash） | 登記前為個人賣家（使用個人帳戶）；登記後在 Bank 開立商業帳戶並注資，之後公司與個人現金分帳。 |
| H8 | 為何需要登記公司？ | 用真實商業理由而非強制劇情：個人賣家帳號有月銷售上限、B2B 客戶要求發票抬頭與公司主體、辦公室租約需要公司。 |
| H9 | 遊戲內文字語言。設計文件為繁中、概念板為英文。 | UI 與對話先以英文（與 Visual Bible 一致）實作，文字全部放在 data，保留 zh-TW 在地化。**若使用者希望遊戲內預設繁中，請告知**（需要 CJK 像素字型）。 |
| H10 | World Map 屬 P2，但 Product Rule 說「世界地圖與城市地圖必須存在」。 | Slice 內建立 World Map 場景層級與畫面（Aurelia + 7 市場資訊），海外旅行標為 **Planned（P2）** 並在 UI 明示鎖定原因；不假裝可玩。 |
| H11 | Company OS 除 Small Office 外可否在 Laptop 開？（使用者 §15 vs Handoff §52） | Handoff §52 明列 Office / Laptop / Management Terminal；故公寓 Laptop 與 Co-working 桌也能開，但一律需**走到設備並互動**。登記前標題為 Personal Seller，登記後顯示公司名。 |
