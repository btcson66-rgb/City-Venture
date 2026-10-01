# 04 建築外觀

**互動探索（#39）**：門口提示從建築的 `category`、`hours` 與當下開門狀態組合，打烊時列出開門時間。
手機「城市指南」依街區讀取所有建築及捷運資料；新街區或建築改為 active 後自動列出，無須修改畫面清單。
「帶我去」沿用 Tutorial 金色箭頭，帶玩家走到門口；關門時仍須等營業時間才能進入。

**美術品質補齊（2026-10-01）**：另 19 種城市立面已更新，交原尺寸及 4× 本體／獨立光罩 PNG/import；門口、空白招牌 metadata 對齊新圖。實機與驗收見 `evidence/20261001_city_frontage/README.md`。原尺寸已載入，4× 建築渲染仍需 Claude 接線；不代表全遊戲美術已驗收。

**A3 美術更新（2026-09-28）**：現有 18 棟立面與夜燈已更新。三維側牆保留材質細節且比正面略暗，門口有深色凹槽及亮暗門框，招牌區保留素底，夜間上層窗格採約六成亮燈機率。原有尺寸、門與招牌 metadata 未變；四街區日夜截圖見 `evidence/2026-09-28_a3_facades/`。以下各列的 `CONV+GEN v3` 描述原始產生方式，A3 為其後續精修。

所有立面在 `game/assets/buildings/`。每棟有兩張圖：

- `<facade>.png`：本體
- `<facade>_lights.png`：夜間燈光疊圖，同尺寸，只畫亮的部分

位置資料在 `buildings_meta.json`：

| 欄位 | 意思 |
|------|------|
| `size` [w, h] | 圖片尺寸 |
| `front_w` | 正面寬度；右邊剩下的是側牆 |
| `depth` | 側牆寬（= `size.w − front_w`） |
| `door` [x, y, w, h] | 門的位置。玩家走到這裡按 E 進門，程式也會在這裡畫出入口標記 |
| `sign` [x, y, w, h] | 招牌區。程式在這裡畫 `sign_text`（可翻譯）。**美術只畫空白招牌底** |
| `sign_text` | 招牌文字（英文原文，遊戲內會翻譯） |

改了尺寸或門的位置，就要改 `buildings_meta.json`，然後跑 `python3 tools/gen_districts.py` 重排街區。

---

## 可進入的建築（已實作）

| 立面 id | 建築 id | 名稱 | 區域 | 尺寸 | 正面 / 側牆 | 門 | 招牌區 | 美術 | 視覺設定 |
|---------|---------|------|------|------|-------------|----|--------|------|----------|
| `riverside_tower` | `riverside_apartment` | Riverside Tower | Riverside | 202×291 | 176 / 26 | 77,257 22×30 | 65,231 46×9 | CONV+GEN v3 | 玩家的家。零售裙樓，上面是陽台住宅，暖色室內光，屋頂綠化（Board G「Apartment Tower」） |
| `bloom_block` | `bloom_coffee` | Bloom Coffee | Riverside | 182×173 | 160 / 22 | 69,139 22×30 | 6,112 132×10 | CONV+GEN v3 | 紅磚混合使用建築。一樓咖啡店：綠色招牌、條紋雨遮、大玻璃看得到客人；樓上住宅，屋頂有盆栽 |
| `postpoint` | `postpoint_riverside` | PostPoint | Riverside | 130×131 | 112 / 18 | 45,97 22×30 | 6,72 100×10 | CONV+GEN v3 | 小型物流門市。紅白配色，櫥窗裡有紙箱和秤 |
| `nexus_cowork` | `nexus_cowork` | Nexus Co-work | Startup Hub | 216×216 | 192 / 24 | 85,182 22×30 | 73,152 46×9 | CONV+GEN v3 | 白色現代建築、大面玻璃，看得到工作中的人；屋頂露台和植物（Board H「NEXUS – Work · Meet · Create」） |
| `byte_bean` | `byte_and_bean` | Bean & Byte | Startup Hub | 146×133 | 128 / 18 | 53,99 22×30 | 6,72 116×10 | CONV+GEN v3 | 木作門面的科技咖啡店，棕色配青綠 |
| `suite_building` | `small_office` | 22 Founders Lane | Startup Hub | 164×204 | 144 / 20 | 61,170 22×30 | 49,144 46×9 | CONV+GEN v3 | 紅磚小辦公樓。租下 Suite 2B 後，招牌區改顯示「玩家公司名 · 2B」（程式畫） |
| `nexus_bank` | `nexus_bank` | Nexus Bank | Financial | 234×227 | 208 / 26 | 91,183 26×32 | 57,158 94×10 | CONV+GEN v3 | 米色石材、列柱、玻璃大門，屋頂金色「N」（Board G「Bank」） |
| `city_hall` | `city_hall` | Aurelia City Hall | Civic Center | 284×202 | 256 / 28 | 113,156 30×34 | 79,127 98×10 | CONV+GEN v3 | 石材加玻璃、旗幟、台階和廣場（Board G「City Hall」）。最寬的建築 |

## 填充建築（不能進入）

| 立面 id | 尺寸 | 正面 / 側牆 | 招牌文字 | 出現在 | 美術 | 視覺設定 |
|---------|------|-------------|----------|--------|------|----------|
| `riverside_walkup` | 146×189 | 128 / 18 | （無） | Riverside ×2 | CONV+GEN v3 | 四層無電梯老公寓，窗台花箱 |
| `riverside_shops` | 164×164 | 144 / 20 | FRESH+ MARKET | Riverside | CONV+GEN v3 | 社區超市，水果攤擺到門口 |
| `apartment_mid` | 182×251 | 160 / 22 | （無） | Riverside、Startup Hub | CONV+GEN v3 | 中層公寓，陽台欄杆 |
| `brick_shops` | 164×164 | 144 / 20 | KURO RAMEN | Riverside、Civic | CONV+GEN v3 | 紅磚店面，拉麵店的布簾 |
| `office_slab` | 200×290 | 176 / 24 | （無） | 四區都有 | CONV+GEN v3 | 方正的中高層辦公樓 |
| `glass_tower` | 188×356 | 160 / 28 | （無） | 四區都有 | CONV+GEN v3 | 藍色玻璃帷幕高樓，會反射天空 |
| `horizon_labs` | 202×245 | 176 / 26 | HORIZON LABS | Startup Hub | CONV+GEN v3 | 新創大樓：玻璃、露台、植物。**P1 改成可進入**（辦公第 3 階） |
| `civic_annex` | 182×205 | 160 / 22 | TAX OFFICE | Civic Center | CONV+GEN v3 | 市政附屬大樓。**P2 改成可進入**，成為稅務局 |
| `finance_tower` | 206×375 | 176 / 30 | ARC CAPITAL | Financial ×2 | CONV+GEN v3 | 全城最高的建築，深色玻璃加石材基座。**P3 玩家總部**可以租其中一層 |
| `metro_entrance` | 88×70 | 88 / 0 | （無） | 四區都有 | CONV+GEN v3 | 捷運入口：往下的樓梯、M 字標誌柱、玻璃雨棚。門 28,36 32×26 |

> 注意：招牌文字（FRESH+ MARKET、KURO RAMEN、ARC CAPITAL）是填充建築的店名，也是世界觀的一部分。它們都是虛構的名字。

---

## 規劃中的建築

尺寸是**建議值**，照同一類現有建築抓。定稿時照實際尺寸填 `buildings_meta.json` 即可。每棟都要交本體加 `_lights`。

### Shopping Street（已實作 · 2026-09-29）

七棟都已由 Codex B1 交圖（含 `_lights`），已接進遊戲，招牌文字由程式畫。`popup_unit` 目前的招牌是「UNIT 5 · TO LET」，承租後改成玩家店名是規劃中（P3）。

| 立面 id | 名稱 | 可進入 | 建議尺寸 | 招牌文字 | 視覺設定 |
|---------|------|--------|----------|----------|----------|
| `threadline_apparel` | Threadline | ✓ | 182×190 | THREADLINE | 兩層服飾店：大櫥窗裡有 3 個假人穿不同服裝（Executive、Citywear、Formal），黑色門框，暖白燈 |
| `crestline_flagship` | Crestline | ✓ | 260×230 | CRESTLINE | 三層百貨：海軍藍配金色門框、旋轉門、樓層櫥窗，山脊線標誌做成金屬浮雕（無字） |
| `lantern_bistro` | Lantern Bistro | ✓ | 164×170 | LANTERN BISTRO | 暖色小餐館：門口一排燈籠形吊燈、戶外座位、黑板立牌（無字） |
| `popup_unit` | Pop-up Unit 5 | ✓ | 130×131 | （玩家店名，程式畫） | 白色空店面、大玻璃、「招租」貼紙（用符號，不寫字）。租下後變成玩家的店 |
| `retail_arcade` | 騎樓商場 | ✗ | 200×200 | （無） | 拱形騎樓下一排小店 |
| `shop_row_awning` | 雨遮店排 | ✗ | 164×164 | （無） | 三間小店，雨遮顏色各不同 |
| `cinema_front` | 電影院 | ✗ | 200×220 | AURELIA CINEMA | 裝飾藝術風格門面、燈泡邊框的片名看板（看板內容用色塊） |

### Harbor（已實作 · 2026-09-30，美術待交）

四棟可進入建築和三棟填充建築都已接進遊戲（`data/buildings/`、`data/districts/harbor.json`），立面圖沒交之前資料用 `fallback` 暫代：交件並更新 `buildings_meta.json` 後跑 `python3 tools/gen_districts.py harbor` 重排即可。招牌文字由程式畫（`exterior.sign`），暫代立面的舊招牌字會被蓋掉。

| 立面 id | 建築 id | 目前暫代 | 說明 |
|---------|---------|----------|------|
| `pier7_warehouse` | `pier7_warehouse` | `brick_shops` | 24 小時可進；在裡面的櫃台租倉位 |
| `dockside_motors` | `dockside_motors` | `byte_bean` | 週一到週六 08–18；Sam Okoro 在櫃台後面 |
| `harbor_point_fitness` | `harbor_point_fitness` | `popup_unit` | 每天 06–22；可看櫃台和課表 |
| `customs_house` | `customs_house` | `civic_annex` | **進不去**（`closed_reason`：進口許可與清關還沒納入這個版本）；仍有一個小室內場景，讓截圖巡禮和工具載得起來 |
| `warehouse_shed` / `cold_store` / `container_stack` | （填充） | `shop_row_awning` / `retail_arcade` / `riverside_walkup` | 不可進入 |

下表是給美術的設定稿（尺寸是建議值）：

| 立面 id | 名稱 | 可進入 | 建議尺寸 | 招牌文字 | 視覺設定 |
|---------|------|--------|----------|----------|----------|
| `pier7_warehouse` | Pier 7 Warehouse | ✓ | 280×190 | PIER 7 | 藍灰波浪鐵皮、三個捲門（一個開著看得到棧板）、裝卸平台、外牆大號「7」 |
| `customs_house` | Aurelia Customs House | ✓ | 240×220 | CUSTOMS HOUSE | 老港務大樓：紅磚加白色石材、鐘、旗杆 |
| `haddad_trading` | Haddad Trading | ✓ | 164×200 | HADDAD TRADING | 港邊改建的倉庫辦公室：鐵窗框、室內暖光、門口擺著樣品木箱 |
| `harbor_point_fitness` | Harbor Point Fitness | ✓ | 182×173 | HARBOR POINT | 青綠色健身房：落地窗看得到跑步機，屋頂有浪花圖形 |
| `warehouse_shed` | 倉庫棚 | ✗ | 220×150 | （無） | 低矮大倉庫 |
| `cold_store` | 冷凍倉 | ✗ | 200×170 | （無） | 白色隔熱板、冷凝機組、藍色燈 |
| `container_stack` | 貨櫃堆 | ✗ | 180×120 | （無） | 三層貨櫃，紅藍綠黃 |
| `crane_gantry` | 岸邊吊車 | ✗ | 160×360 | （無） | 高大的紅白吊車剪影，放在最後面 |

### Old Town（已實作 · 2026-09-30 · B3 美術已交）

三棟可進入建築和三種填充立面都已經在遊戲裡，**B3 已交六款正式立面及各自 `_lights`，原尺寸／4× 版與 metadata 均已完成**。遊戲現在畫的是資料裡 `exterior.fallback` 指定的現有立面（見 [03](03_districts.md#old-town-老城區--old_town) 的暫代對照表）。正式圖放進 `game/assets/buildings/` 並在 `buildings_meta.json` 登記尺寸、門和招牌區之後，遊戲即讀取正式圖。B3 的尺寸已放入現有街區位置驗證；如後續要重排，由 Claude 線改資料。

| 立面 id | 建築 id | 名稱 | 可進入 | 建議尺寸 | 招牌文字 | 營業 | 暫代 | 視覺設定 |
|---------|---------|------|--------|----------|----------|------|------|----------|
| `okafor_lettings` | `okafor_lettings` | Okafor Lettings | ✓ | 164×164 | OKAFOR LETTINGS | 週一到六 09:00–18:00 | `brick_shops` | 老式租屋行：櫥窗貼滿房屋照片（色塊，無字），綠色木門。租轉角咖啡店面的地方 |
| `corner_cafe_unit` | `corner_cafe_unit` | Corner Café Unit（玩家的咖啡店） | ✓ | 約 164×164 | 租之前「CORNER UNIT · TO LET」；**租下後改顯示玩家取的店名**（程式畫，預設「<公司名> Café」，可在 Company OS 咖啡店分頁改名） | 租之前 08:00–18:00；租下後 24 小時可進（`always_if_lease`） | `shop_row_awning` | 一樓小店面，大窗、遮陽棚、門口兩張小圓桌。招牌板留空。這棟是 Old Town 最重要的畫面 |
| `old_town_studio` | `old_town_studio` | Studio 1A, Lantern Row | ✓（只能參觀） | 146×189 | LANTERN ROW FLATS | 每天 09:00–19:00 | `riverside_walkup` | 三層老公寓，外露鐵梯，窗戶小，一樓門口有信箱。最便宜、最溫馨的住處。**搬進去是規劃中** |
| `rowhouse_brick` | （填充） | 紅磚連棟屋 ×2 | ✗ | 164×180 | （無） | — | `apartment_mid`（西端）、`riverside_walkup`（東端） | 紅磚，白框窗，爬藤 |
| `arcade_arches` | （填充） | 拱廊 | ✗ | 200×160 | （無） | — | `retail_arcade` | 拱形騎樓下一排小店 |
| `clock_tower` | （填充） | 鐘樓 | ✗ | 90×320 | （無） | — | `civic_annex` | 老城地標，全區最高。鐘面沒有數字 |

尚未開放（**規劃中 P1–P3**，遊戲裡沒有）：

| 立面 id | 名稱 | 可進入 | 建議尺寸 | 招牌文字 | 視覺設定 |
|---------|------|--------|----------|----------|----------|
| `gallery_nine` | Gallery Nine | ✓ | 164×180 | GALLERY NINE | 白牆大窗的藝廊，裡面掛著幾幅色塊畫 |
| `ember_print` | Ember Print | ✓ | 130×140 | EMBER PRINT | 印刷行：門口堆著紙捲，櫥窗有海報樣張（無字） |
| `corner_workshop` | Corner Workshop | ✓ | 146×150 | （玩家店名） | 轉角工坊：捲門、工作台、工具牆 |

### Residential（P1）

| 立面 id | 名稱 | 可進入 | 建議尺寸 | 招牌文字 | 視覺設定 |
|---------|------|--------|----------|----------|----------|
| `maple_court` | Maple Court | ✓ | 200×260 | MAPLE COURT | 六層公寓，陽台有植物和晾衣，門口有楓樹 |
| `freshmart` | FreshMart | ✓ | 200×150 | FRESHMART | 超市：自動門、購物車排、蔬果看板（無字） |
| `community_center` | 社區中心 | ✓ | 182×170 | COMMUNITY CENTER | 低矮木構建築、公佈欄、兒童畫 |
| `apartment_balcony` | 陽台公寓 | ✗ | 182×240 | （無） | |
| `townhouse_row` | 連棟透天 | ✗ | 200×150 | （無） | 三戶，門口有腳踏車和盆栽 |
| `school_front` | 小學 | ✗ | 240×170 | （無） | 圍牆、校門、操場一角 |

### University（P1）

| 立面 id | 名稱 | 可進入 | 建議尺寸 | 招牌文字 | 視覺設定 |
|---------|------|--------|----------|----------|----------|
| `aurelia_institute` | Aurelia Institute of Technology | ✓ | 300×240 | AURELIA INSTITUTE | 紅磚古典主館：列柱、三角楣、中央大門、兩側長窗 |
| `innovation_lab` | Innovation Lab | ✓ | 220×230 | INNOVATION LAB | 玻璃立方體研究大樓，看得到實驗桌和螢幕 |
| `lecture_hall` | 講堂 | ✗ | 200×180 | （無） | |
| `library_front` | 圖書館 | ✗ | 220×200 | （無） | |
| `dorm_block` | 宿舍 | ✗ | 182×250 | （無） | 窗戶掛著旗子和毛巾 |

### 其他區域（P2–P3）

| 立面 id | 名稱 | 區域 | 優先 | 視覺設定 |
|---------|------|------|------|----------|
| `northlight_capital` | Northlight Capital | Financial | P1 | 低調的白色石材小樓，北極星浮雕，門口兩盆橄欖樹 |
| `launchpad_accelerator` | Launchpad | Startup Hub | P1 | 改建工廠：鋸齒屋頂、大鋼窗、火箭塗鴉（無字） |
| `quay_residences` | The Quay Residences | Riverside | P3 | 河岸玻璃高級公寓，每層有大陽台 |
| `terminal_international` | 國際航廈 | Airport | P2 | 大片曲面玻璃屋頂 |
| `cargo_terminal` | 貨運站 | Airport | P2 | 巨大機棚、貨盤 |
| `private_aviation` | 私人航空 | Airport | P3 | 小巧、低調、黑色玻璃 |
| `skyline_penthouse` | 頂樓豪宅大樓 | Luxury Heights | P3 | 細長玻璃塔，頂樓有泳池發光 |
| `hillside_villa` | 山坡別墅 | Luxury Heights | P3 | 白色平頂、木格柵、樹 |
| `meridian_club` | Meridian Club | Luxury Heights | P3 | 深綠石材、黃銅門、門僮 |
| `crown_motors` | Crown Motors | Luxury Heights | P3 | 玻璃展示間，裡面有兩台車 |
| `aurum_dining` | Aurum | Luxury Heights | P3 | 黑金色系、窗內燭光 |
| `factory_unit` | 廠房 | Industrial | P3 | 鋸齒屋頂、裝卸口、白色蒸氣 |
| `solaris_energy` | Solaris Energy | Industrial | P3 | 屋頂和牆面都是太陽能板 |
| `materials_yard` | 原料場 | Industrial | P3 | 圍籬、砂石堆、鋼材 |
| `venture_tower` | VENTURE TOWER（玩家的大樓） | Financial | P3 | 房地產業的終點：玩家自己的摩天樓，招牌是玩家公司名 |

## 立面的品質要求

朋友測試版入口以 building 的 `status`／`enterable` 與街區的 status 決定，不刪除室內。
`popup_unit`、`old_town_studio`、`harbor_point_fitness`、`customs_house` 為 planned 景觀。
可用互動或實際排程 NPC 出現時才顯示公眾入口；Crestline 依 Daniel／Victor 的劇情條件與
排程自動顯示。未租咖啡店面先由 Okafor 簽約，租下後才顯示入口。旧存檔站在關閉室內時
讀檔會移到原立面門口；資料啟用後無需修改 UI 清單。城市指南、捷運、地圖只列 active 街區。

- 門必須一眼看得出是門（深色開口加門框加門燈），不要被植物擋住。
- 招牌區留**素面**底板，程式會畫字。底板顏色要讓白字或金字看得清楚。
- 側牆（`depth`）比正面暗 15–25%，保持光源在左上。
- `_lights` 疊圖只畫發光的東西：窗戶（大約 60% 亮、40% 暗，不要全亮）、招牌燈條、門燈、屋頂燈。
- 同一區的建築高度要有高低變化，天際線才不會像一排牙齒。

## B2 港區立面 · 美術已交 2026-09-30

`pier7_warehouse` 280×190、`dockside_motors` 240×150、`harbor_point_fitness` 182×173、`customs_house` 240×220、`warehouse_shed` 220×150、`cold_store` 200×170、`container_stack` 180×120。每張附 `_lights` 及 4×；入口和空白招牌位置已寫入 buildings_meta.json，runtime 字串由資料提供。海關是否開放仍由 Claude 線決定。
