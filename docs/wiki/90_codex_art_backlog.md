# 90 Codex 美術工單

這一頁是**給 Codex（或任何接手美術的人）的施工單**：先做什麼、後做什麼、每一批交哪些檔案、怎樣算做完。

規格細節在前面各頁，這裡只列工作項目和驗收標準。

## 目前畫面的狀態（2026-09-28）

Codex 第一輪（`codex/visual-art-pass-01`，已合併）的效果，在同一條截圖路線上比對過：

| 區域 | 變化 | 結論 |
|------|------|------|
| 主選單背景 `menu` | 重畫：街景更乾淨，旗幟改用符號 | ✅ 明顯變好 |
| 抵達背景 `arrival` | 重畫：河岸天際線、橋、倒影 | ✅ 明顯變好 |
| 角色走路圖 | 第一輪只修細節；**A1（已合併）**重畫了輪廓、體型、鞋子和走路 4 格 | ✅ A1 明顯變好 |
| 西裝、快遞服 | **R1（已合併）**：布料可染色，領帶和襯衫另外一層 | ✅ 四位穿西裝的 NPC 分得出來 |
| 室內 | **A2（已合併）**：家具色階統一；銀行、市政櫃台分開；菜單板改成圖示；新增 3 款地板、7 款牆 | ✅ 明顯變好 |
| 角色姿勢 | **R3（已合併）**：坐、站、講電話、伸手、搬箱，134 層 × 5 姿勢 | ⚠️ 坐姿可以用；其他姿勢有瑕疵，見 [R3 修正](#r3-修正--優先) |
| 角色頭像 | 細部修整 | ⚠️ 等 A5 |
| UI 面板和按鈕 | 小幅修整 | ⚠️ 小幅進步 |
| 街景、建築、地圖 | 沒動（仍是 v3 從概念板轉換的版本） | ❌ 下一輪的重點 |

**結論**：背景、角色和室內都到位了。剩下玩家常看到的是**街道和建築**（A3、A4），以及地圖（A6）。

## 工作方式

1. **每一批開一個分支**，例如 `codex/art-batch-a1-characters`。一批一個 PR，不要混批。
2. **只動美術檔和美術 metadata**：
   - 可以動：`game/assets/**`、`game/assets/buildings/buildings_meta.json`、`game/assets/sprite_meta.json`、`game/assets/tiles/atlas.json`、`tools/art/**`、`docs/art_sources/**`、`evidence/**`
   - 可以更新：這份 wiki 裡「美術」欄的狀態、`docs/ART_ASSET_MANIFEST.md`
   - **不要動**：`game/scripts/**`、`game/autoload/**`、`game/data/**`（遊戲資料）、`game/tests/**`。需要改程式的，寫進 PR 說明，由 Claude 線接手（見下方[程式接線清單](#程式接線清單)）。
3. **不改檔名**。新東西用新檔名，命名照 [README](README.md#命名規則)。
4. **不要跑 `tools/art/gen_placeholders.py`**，它會覆寫整個 `game/assets/`。
5. 每一批交件前都要跑：
   ```bash
   godot --headless --path game --import
   godot --headless --path game res://tests/test_runner.tscn        # 全部通過
   godot --path game -- --bot=shots --out=/tmp/shots                 # 截圖巡禮，0 失敗
   python3 tools/wiki_check.py                                        # wiki 和檔案一致
   python3 tools/qa/pose_check.py                                     # 有動角色圖時：姿勢圖沒有斷線、碎片、露膚
   ```
6. 把**改前 / 改後**的對比截圖放進 `evidence/<日期>_<批次>/`，附一份 README：改了哪些檔、為什麼、還剩什麼問題。

---

## A 批：提升現有畫面（P0）

依照「玩家看到的時間 × 目前落差」排序。

### A1 角色走路圖 ★ 最優先

**為什麼**：角色是整個遊戲最常出現在畫面中央的東西，也是 v3 以來公認最弱的一塊。第一輪的修整在 1× 下看不出來，這一輪要改**輪廓和比例**，不是細節。

| 交付 | 檔案 | 數量 |
|------|------|------|
| 身體 | `characters/body_<masculine|feminine|neutral>_<round|oval|square|heart>.png` | 12 |
| 頭髮 | `characters/hair_<8 款>_back.png`、`_front.png` | 16 |
| 臉部 | `characters/eyes_*`、`iris_*`、`brows_*`、`mouth_*` | 16 |
| 服裝 | `characters/outfit_<9 套>_<3 體型>_<top|bottom|shoes>.png` | 81 |
| 配件 | `characters/acc_glasses_round`、`acc_glasses_square`、`acc_backpack` | 3 |

**規格**：[07 角色](07_characters.md#走路圖gameassetscharacters)。128×144 的圖，32×48 格，4 格 × 3 方向。要染色的圖層畫灰階。不要畫外框。

**驗收**：

- [x] 在 640×360 原尺寸下，8 種髮型的**剪影**各不相同（把角色填成單色也分得出來）
- [x] 3 種體型在 1× 分得出來（肩寬、腰線、髮量）
- [x] 9 套服裝在 1× 分得出來：咖啡師的圍裙、快遞的腰包、西裝的領口、市政職員的名牌
- [x] 走路 4 格有明顯的腳步起落和手臂擺動；側面走路不會「滑步」
- [x] 12 位具名 NPC（外型見 [07](07_characters.md#具名-npc已實作-12-位)）站在一起時，每個人都認得出來。特別是 Maya 和 Elena
- [x] 所有圖層在每一格都對齊（用 `tools/art/preview_chars.py` 組合檢查）

A1 圖層與實機對照見 [`evidence/2026-09-28_a1_characters/README.md`](../../evidence/2026-09-28_a1_characters/README.md)。Maya 與 Elena 目前依服裝區分；若要再更換 Elena 的資料搭配，仍屬下方程式接線 #18。

### A2 室內家具與地板

**為什麼**：玩家大部分時間在室內（家、咖啡店、共享辦公、2B）。

**美術交件（A2）**：68 張現有室內物件、五張既有地板、三張新增地板與七款牆磚已在 `codex/art-batch-a2-interiors` 更新；實機八場景及日夜窗戶證據在 `evidence/2026-09-28_a2_interiors/`。物件尺寸及碰撞 metadata 沒有變動。

| 交付 | 檔案 | 數量 |
|------|------|------|
| 家具、牆面裝飾、招牌、窗 | `interiors/*.png`（除了地板） | 68 |
| 地板大圖 | `interiors/floor_*.png`（512×320） | 5 |
| 新增地板大圖 | `interiors/floor_tile_white.png`、`floor_checker.png`、`floor_carpet_navy.png` | 3 |
| 牆面地磚 | `tiles/atlas.png` 的 `wall_*`（7 種） | 7 格 |

**必修問題**：

- `bank_counter` 和 `civic_counter` **目前是同一張圖**，要分開：銀行版木頭加金色加玻璃隔板；市政版白色石材加號碼燈。
- `menu_board` 目前有英文字和價格。改成咖啡杯圖示加色塊，或保留字但字高要有 5 px 以上。
- 三個**功能點**（`desk_laptop`、`packing_table`、`wardrobe`）要一眼看得出「這裡可以用」：筆電螢幕發亮、打包桌上有膠帶和紙箱、衣櫃門半開。
- `box`（庫存紙箱）會疊到 4 層，要疊起來好看。

**驗收**：

- [ ] 8 個室內的截圖（`--bot=shots`）看起來是同一個美術風格：同樣的光源、外框顏色和飽和度
- [ ] 家具的碰撞範圍沒有變。尺寸變了的話，`sprite_meta.json` 要一起改，玩家不會卡在空氣裡，也不會穿過桌子
- [ ] 日夜兩種窗戶都要交，白天和晚上各截一張

### A3 建築立面與夜燈

**美術交件（2026-09-28）**：18 棟現有立面與對應夜燈更新，保留原尺寸、門與招牌座標，`buildings_meta.json` 無差異；白天及夜間四個街區的改前／改後實機截圖見 `evidence/2026-09-28_a3_facades/`。夜窗以固定種子約 60% 亮燈機率產生，門框加強層次，招牌中間保持素底供程式文字疊加。

| 交付 | 檔案 | 數量 |
|------|------|------|
| 可進入建築 | 8 棟 × 本體加 `_lights` | 16 |
| 填充建築和捷運入口 | 10 棟 × 本體加 `_lights` | 20 |

**規格**：[04 建築外觀](04_buildings.md)。尺寸變了要改 `buildings_meta.json`，然後跑 `python3 tools/gen_districts.py`。

**驗收**：

- [ ] 招牌區是素底，程式畫的招牌字清楚可讀
- [ ] 門一眼看得出是門
- [ ] 夜燈大約 60% 的窗亮、40% 暗，不要整棟全亮
- [ ] 四個街區各截白天和晚上各一張

### A4 街道物件與地磚

| 交付 | 檔案 | 數量 |
|------|------|------|
| 街道物件 | `props/*.png`（商品圖示除外） | 28 |
| 地面地磚 | `tiles/atlas.png` 的草地、人行道、馬路、水 | 23 格 |

**驗收**：

- [ ] 護柱、樹籬這類大量重複的物件要低調，不能搶戲
- [ ] 河面和馬路的地磚平鋪時看不到接縫和重複感
- [ ] 路燈的光暈位置對準燈頭

### A5 頭像

| 交付 | 檔案 | 數量 |
|------|------|------|
| 頭像圖層 | `portraits/*.png` | 45 |
| 新增：頭像眼鏡 | `portraits/acc_glasses_round.png`、`acc_glasses_square.png`（64×64） | 2（`需接線`） |

**驗收**：

- [ ] 4 個表情（平靜、開心、思考、驚訝）差別明顯
- [ ] 12 位具名 NPC 的頭像並排時，每個人都認得出來

### A6 地圖與地點卡

| 交付 | 檔案 | 數量 |
|------|------|------|
| 城市地圖 | `city_map/board.png`、`aurelia_map.png`、`i_*.png` | 15 |
| 世界地圖 | `world_map/board.png`、`r_*.png` | 9 |
| 地點卡 | `cards/*.png` | 11 |
| 新增：PostPoint 地點卡 | `cards/postpoint_riverside.png` | 1 |

**驗收**：標籤位置（`aurelia.json`、`regions/*.json` 的 `board`）留素底；構圖改了就一起改座標；地點卡上沒有文字。

### A7 UI 圖示與 App 圖示

| 交付 | 檔案 | 數量 |
|------|------|------|
| 圖示 | `ui/icons/*.png`（16×16） | 43 |
| App 圖示 | `ui/app_icon.png`（256）、`app_icon_1024.png` | 2 |

**驗收**：43 個圖示同一種線條粗細和圓角；深藍底上 1× 清楚；App 圖示縮到 32×32 還認得出來。

### A8 車輛與特效

| 交付 | 檔案 | 數量 |
|------|------|------|
| 車輛 | `vehicles/*.png` | 19 |
| 特效 | `effects/*.png`，加新的 `water_sparkle` | 6 |

---

## B 批：下一波內容的美術（P1）

這一批可以**先畫**。圖到位後，Claude 線負責接資料和程式。建議順序：

| 批 | 內容 | 主要交付 | 詳細規格 |
|----|------|---------|---------|
| **B1** | 購物街加衣櫃系統 | Threadline 等 4 棟可進入建築和 3 棟填充建築（含 `_lights`）；Threadline 室內；5 套新服裝（Executive、Logistics/Site、Luxury Citywear、Travel、Formal Evening，每套 9 張走路圖加 1 張頭像）；配件（帽子、包包、手錶、識別證、耳麥）；Nina | [03](03_districts.md#shopping-street-購物街--shopping_street--p1)、[04](04_buildings.md#shopping-streetp1)、[05](05_interiors.md#shopping-streetp1)、[07](07_characters.md#服裝) |
| **B2** | 港區 | Pier 7、海關、Haddad Trading、Harbor Point Fitness 四棟和填充建築；貨櫃、棧板、繫船柱等街道物件；碼頭地磚；港區天際線；Pier 7 和健身房室內；Rosa、Omar | [03](03_districts.md#harbor-港區--harbor--p1) |
| **B3** | 老城 | 5 棟可進入建築和 3 棟填充建築；石板地磚；壁畫、鑄鐵路燈；老城天際線；老城套房和 Okafor 租屋行室內；Mr. Okafor | [03](03_districts.md#old-town-老城區--old_town--p1) |
| **B4** | 住宅區 | Maple Court、FreshMart、社區中心；遊樂場物件；Maple Court 公寓室內（住宅第 2 階家具組） | [03](03_districts.md#residential-住宅區--residential--p1) |
| **B5** | 大學區 | AIT 主館、創新實驗室；學生服裝；Prof. Hana Sato | [03](03_districts.md#university-大學區--university--p1) |
| **B6** | 現有區域加蓋 | Northlight Capital（外觀和室內）、Launchpad、Horizon Labs 3F 室內、捷運月台 | [03](03_districts.md#現有區域的規劃中建築) |
| **B7** | 氣氛插圖 | 章節標題卡 1–6、`skyline_dusk`、公司結束後的 `insolvency` 畫面 | [11](11_backdrops_maps.md) |
| **B8** | 角色姿勢 | 坐、搬箱、講電話、伸手互動、站立呼吸（每個姿勢要涵蓋 A1 的全部圖層） | [07](07_characters.md#姿勢與動畫) |
| **B9** | 品牌與商品 | 13 個公司標誌、3 個 SaaS logo、4 張商品照（手機隨手拍版和專業攝影版） | [08](08_items.md) |
| **B10** | 專屬 NPC | `characters/npc_<id>.png` 和 `portraits/npc_<id>.png`：Maya、Marcus、Daniel、Elena、Priya、Jun | [07](07_characters.md#專屬-npc-美術程式已接好) |

每一批的驗收標準和 A 批一樣，另外還要：

- [ ] 新區域的所有建築、物件、地磚都放在同一張對比截圖裡，確認風格一致
- [ ] 新服裝在 3 種體型下都要截圖（正面、側面、背面）

## C 批：之後（P2–P3）

機場、工業區、豪宅區、車輛階梯（SUV、跑車、豪華車）、飛機和貨輪、事件插圖、文件插圖、章節標題卡 7–12、收藏品、住宅第 3–5 階和辦公第 3–4 階的家具組。規格都在前面各頁，等 B 批完成後再排。

---

## A1 驗收後的新需求（2026-09-28，Claude 線）

A1 已合併（`codex/art-batch-a1-characters` → `claude/exciting-bardeen-y71ixv`）。驗收結果：

- 單元測試 58/58
- 截圖巡禮 28 張，0 失敗
- `wiki_check` 通過
- 12 位 NPC 並排都認得出來，體型、鞋子、走路格明顯進步 ✅

Claude 線同時做完了下方[程式接線清單](#程式接線清單)的大部分項目。**這些檔名現在只要放進 `game/assets/` 就會自動出現在遊戲裡**，不用再等程式。

下一批請依這個順序：**R1 → A2 → R2（併入 A6）→ R3**。

### R1 服裝拆成「可染色布料＋不染色細節」★ 優先

**為什麼**：`business_suit`（西裝）和 `courier`（快遞）現在是**全彩**，程式的染色只能讓它們變暗，沒辦法換顏色。所以：

- Daniel、Marcus、Sofia、Tom 四個人穿一模一樣的藍西裝紅領帶
- 路人的西裝被隨機染成奇怪的深色

**做法**：布料畫成灰階（可染色）；襯衫、領帶、名牌、腰包、鈕扣、掛繩放到另一個圖層（全彩，不染色）。程式已經接好，有檔案就會畫在布料上面。

| 檔案 | 內容 |
|------|------|
| `characters/outfit_<o>_<pres>_top.png` | 改成灰階布料（外套、襯衫本體） |
| `characters/outfit_<o>_<pres>_top_detail.png` | **新增**：領帶、襯衫領、名牌、鈕扣、腰包背帶（全彩） |
| `characters/outfit_<o>_<pres>_bottom.png` | 改成灰階布料 |
| `characters/outfit_<o>_<pres>_bottom_detail.png` | **新增**（有需要才做）：皮帶、口袋、腰包 |
| `portraits/outfit_<o>_detail.png` | **新增**：頭像衣領的細節（64×64，全彩） |

**範圍**：先做 `business_suit` 和 `courier`，各 3 種體型。有餘力再做 `barista`（圍裙）和 `civic_staff`（名牌）。

**驗收**：用下面四種顏色染西裝，四個人要一眼分得出來，而且領帶、襯衫的顏色不能被染到。圖交了之後，Claude 線會把這些顏色寫進 NPC 資料：

| NPC | 西裝顏色 | NPC | 西裝顏色 |
|-----|---------|-----|---------|
| Marcus | 炭灰 `#3a3d44` | Tom | 淺灰 `#b8bcc4` |
| Daniel | 海軍藍 `#2c3e66` | Sofia | 酒紅 `#6e2e3a` |

  快遞服要用 PostPoint 紅 `#d0503c` 染 Dara。

  **美術交件（R1）**：西裝與快遞的 3 種體型已拆出灰階 `top`／`bottom` 和全彩 `top_detail`，頭像衣領也分為灰階與全彩；褲裝沒有額外全彩細節，因此不建立空白 `bottom_detail`。四色西裝和 PostPoint 紅的組合驗收見 `evidence/2026-09-28_r1_outfit_details/`。NPC 染色資料由 Claude 線接手。

### R2 地點卡不能有文字（併入 A6）

`cards/riverside.png` 河岸步道的旗幟上有英文標語「CLEANER CITIES BRIGHTER LIVES」，翻譯不了。請在 A6 重繪時，一起檢查其他 10 張地點卡：

- 標語、海報、路牌上的字全部改成符號或色塊
- 品牌招牌（例如 Nexus 的 logo 牆）可以保留

### R3 姿勢圖（程式已接好，B8 的正式規格）

程式規則：每個圖層各自有一張姿勢圖，**全部圖層都到齊才會切換**；缺一張就維持走路圖，所以不會出現半套。

- **檔名**：`<圖層名>_<姿勢>.png`
  - 例如 `body_feminine_oval_sit.png`、`hair_bob_front_sit.png`、`outfit_barista_neutral_top_sit.png`
  - 細節層也要有，例如 `outfit_business_suit_masculine_top_detail_sit.png`
- **尺寸**：和走路圖一樣是 **128×144**，32×48 格，3 列方向（下、側、上）
- **影格數**：

| 姿勢 | 用到的影格 | 速度 | 遊戲裡誰會用 |
|------|-----------|------|-------------|
| `sit` 坐 | 前 2 格（打字或呼吸） | 慢 | 咖啡店和共享辦公的客人、辦公桌的員工，以及 Maya、Ken、Elena、Daniel、Marcus |
| `idle` 站立呼吸 | 前 2 格 | 慢 | 櫃台後的 NPC（Jun、Lee、Priya、Ana、Sofia、Dara、Tom） |
| `phone` 講電話 | 前 2 格 | 慢 | 玩家打開手機時 |
| `interact` 伸手 | 前 2 格 | 快 | 打包桌的出貨員工 |
| `carry` 搬箱 | 4 格（取代走路） | 同走路 | 預留給搬貨 |

**優先順序**：`sit` 最優先，它在畫面上出現最多次。然後依序是 `idle`、`phone`、`interact`、`carry`。

**數量**：一個姿勢要 128 張（全部圖層，加上 R1 的細節層）。建議用 `tools/art/chars.py` 產生，不要手畫每一張。

**R3 美術交件（2026-09-28）**：原有 128 個走路圖層與 R1 的 6 個細節圖層，每層製作 `sit`、`idle`、`phone`、`interact`、`carry`，共 670 張 128×144 PNG；所有新增圖都有 Godot `.png.import`。玩家／NPC 的排程和動作切換仍由 Claude 線維護。檔名規則見上方；`tools/wiki_check.py` 會把 `<圖層>_<姿勢>` 算在它的圖層底下，不必逐一列出。

### R4 新 PNG 要連同 `.png.import` 一起提交

專案有把 `*.png.import` 納入版本控制。新增圖檔後請先跑 `godot --headless --path game --import`，再把產生的 `.import` 一起 commit。不然別台電腦第一次開啟時會找不到圖。

### R5 現在放進去就會出現的檔案

| 檔案 | 在遊戲哪裡出現 | 規格 |
|------|---------------|------|
| `characters/npc_<id>.png`（加上 `_<姿勢>`） | 該 NPC 的走路圖，取代分層組合 | 128×144 |
| `portraits/npc_<id>.png` | 該 NPC 的對話頭像 | 256×64（4 表情） |
| `portraits/acc_glasses_round.png`、`acc_glasses_square.png` | 戴眼鏡角色的頭像 | 64×64 |
| `logos/<id>.png` | 手機訊息和對話裡無臉聯絡人的頭像：`nexus`、`shoplane`、`client_generic`、`aurelia_jobs`、`studio_lumen`、`harbor_point_fitness` | 32×32 |
| `logos/saas_<idea>.png` | Company OS → SaaS：選產品清單和營運儀表板 | 32×32 |
| `products/<id>_photo.png` / `_photo_raw.png` | ShopLane 上架卡的商品照（攝影棚版 / 自己拍版） | 64×64 |
| `events/<event_id>.png` | 事件決策視窗的上方插圖 | 160×90 |
| `backdrops/chapter_<1–6>.png` | 章節開始的全螢幕標題卡背景 | 640×360 |
| `backdrops/insolvency.png` | 公司結束後按「重新開始」的畫面 | 640×360 |
| `backdrops/skyline_dusk.png` | 街區黃昏的天際線（白天和夜晚之間） | 1300×320 |
| `backdrops/skyline_<district>_<day/dusk/night>.png` | 某一區專屬的天際線（例如港區） | 1300×320 |
| `effects/guide_arrow.png` | 取代程式畫的金色目標箭頭 | 64×16（4 格 16×16） |

---

## R1、A2、R3 驗收後的新需求（2026-09-28，Claude 線，第二輪）

R1、A2、R3 三批（PR #3、#4、#5）都已合併到 `claude/exciting-bardeen-y71ixv`。驗收結果：

| 批次 | 結果 |
|------|------|
| R1 | ✅ Marcus 炭灰、Daniel 海軍藍、Sofia 酒紅、Tom 淺灰、Dara PostPoint 紅，已寫入 NPC 資料。路人的西裝也改成隨機西裝色，上下身同色 |
| A2 | ✅ 八個室內都明顯變好。銀行和市政廳的櫃台終於不一樣了；菜單板沒有字了 |
| R3 | ⚠️ `sit` 可以直接用，已在遊戲裡上線。`idle`、`phone`、`interact`、`carry` 有瑕疵，見下方 R3 修正 |

R3 的舊測試已改寫，現在 67/67 通過。

Claude 線同時修好了「坐在哪裡」的問題：客人以前坐在椅子左邊、被椅子蓋住，而且會在椅子上轉來轉去。現在會坐在椅子正中間、面向桌子；沙發和長椅面向前方。經理座位（桌子後面、面向大廳的椅子）留給員工和 NPC。

**請依這個順序**：**R3 修正 → A3 建築立面 → A4 街道和地磚 → A6 地圖與地點卡（含 R2）→ A5 頭像**。

### R3 修正 ★ 優先

我寫了一個檢查工具，用和遊戲**完全相同**的方式疊圖，把每套服裝 × 3 體型 × 5 姿勢 × 3 方向 × 每一格都檢查一遍：

```bash
python3 tools/qa/pose_check.py           # 摘要，有問題時結束碼為 1
python3 tools/qa/pose_check.py --list    # 列出每一筆
```

目前結果：

```
gap         81  idle down f2 ×27, idle side f2 ×27, idle up f2 ×27
float      105  idle 各方向 f2 ×81, phone side ×12, interact side ×12
skin        54  interact side f1 ×27, interact side f2 ×27
hole       247  idle f2 ×120, carry down f3 / side f2 / up f3 ×27, phone f2（身體 24 層、頭髮 8 層）
```

| # | 問題 | 在哪裡 | 看起來像 |
|---|------|--------|---------|
| F1 | `idle` 第 2 格在 y=30 整排透明 | 全部 120 個身體、服裝、配件圖層，3 個方向 | 呼吸的那一格，人從腰部斷成上下兩截 |
| F2 | `phone` 第 2 格有 1 px 透明縫 | 24 個身體圖層和 8 個頭髮圖層（例如 `hair_long_*_phone`） | 長髮上橫過一條細線，舉手的手臂變成 1 px 的線 |
| F3 | `interact` 側面，上衣沒蓋住軀幹 | 27 套服裝 × 體型的 `_top_interact` 第 2 列 | 側面伸手時看起來沒穿上衣 |
| F4 | `phone`、`interact` 側面，細節層脫離身體 | `business_suit`、`courier` 的 `_top_detail_phone` / `_interact` 第 2 列 | 領帶或腰包的 3–4 px 碎片飄在身體外面 |
| F5 | `carry` 側面，手臂往上翹 | 全部 `_top_carry` 第 2 列 | 手臂像 V 字形的角，豎在箱子上方；應該是兩手扶著箱子兩側 |
| F6 | `carry` 背面仍看得到整個箱子 | `_shoes_carry` 第 3 列 | 從背後看，箱子應該被身體擋住，只露出兩側邊緣 |

  **驗收**：`python3 tools/qa/pose_check.py` 回報 `pose_check: OK`，或只剩你在 PR 說明逐項解釋過、確定是誤報的項目。

  **美術修正交件（2026-09-28）**：五種姿勢的圖層重新產生並消除斷層、透明縫、側面露膚及飄離碎片。`pose_check: OK`；Godot 匯入、67/67 單元測試、28 張截圖巡禮 0 失敗。圖層與組合預覽見 `evidence/2026-09-28_r3_pose_fixes/`。`idle`／`phone` 恢復兩格播放和出貨員工恢復 `interact` 仍屬下方 Claude 線程式接線 #22。

**修正後 Claude 線會做的事**：`idle` 和 `phone` 恢復成 2 格動畫（現在暫時只播第 1 格，免得畫面閃出斷線）；出貨員工改回 `interact`（現在暫時用 `idle`）。

### R6 其他小事（有空再做，不擋進度）

- **A2**：銀行和市政廳大理石地板的紋路很大、對比很低，看起來像地圖上的雲。可以縮小紋路、提高一點對比。
- **R1 延伸**：`barista` 圍裙和 `civic_staff` 名牌也拆成「可染色布料＋細節」。之後 Jun 和 Lee 可以穿不同顏色的圍裙。
- **wiki**：姿勢圖不必逐一列在 wiki 裡。`wiki_check` 已經把 `<圖層>_<姿勢>` 算在圖層底下，我把那張 64 列的清單拿掉了。

---

## 程式接線清單

以下是**光交圖不夠**、需要改程式才會出現在遊戲裡的項目。Claude 線負責。✅ 表示已接好：檔案放進去就會出現。

| # | 項目 | 程式改動 | 對應美術 | 狀態 |
|---|------|---------|---------|------|
| 1 | 頭像眼鏡 | `Art.portrait_layers` 讀 `portraits/acc_<配件>` | A5 | ✅ 已接好 |
| 2 | 專屬 NPC 圖 | 有 `characters/npc_<id>`、`portraits/npc_<id>` 時取代分層組合 | B10 | ✅ 已接好 |
| 3 | 更多表情 | 表情長條從 4 格改成 10 格，對話資料加表情標記 | 表情 P1 | 規劃中 |
| 4 | 角色姿勢 | `CharacterRig.set_pose()`：sit、idle、phone、interact、carry；NPC、員工、客人、玩家手機都已套用 | B8 / R3 | ✅ 已接好 |
| 5 | 新服裝和配件 | `options.json` 加選項，衣櫃和 Threadline 購買流程 | B1 | 規劃中 |
| 6 | 新區域 | 區域和建築資料、`gen_districts.py` 排版、捷運站開放 | B2–B6 | 規劃中 |
| 7 | 黃昏天際線 | 街區天空改成日、黃昏、夜三段交叉，也支援各區專屬天際線 | B7 | ✅ 已接好 |
| 8 | 章節標題卡 | `backdrops/chapter_<n>` 當標題卡背景 | B7 | ✅ 已接好 |
| 9 | 公司結束畫面 | 按「重新開始」後顯示 `backdrops/insolvency` 加「重新出發」標題 | B7 | ✅ 已接好 |
| 10 | 公司標誌 | 對話和手機的無臉聯絡人已改用 `logos/`（NPC 資料的 `logo` 欄位） | B9 | ✅ 對話頭像已接好；合約、供應商清單規劃中 |
| 11 | SaaS logo | Company OS SaaS 分頁 | B9 | ✅ 已接好 |
| 12 | 商品照 | 上架卡依 Studio Lumen 或自己拍，顯示 `_photo` 或 `_photo_raw` | B9 | ✅ 已接好 |
| 13 | 事件插圖 | 決策視窗上方顯示 `events/<id>` | C | ✅ 已接好 |
| 14 | 文件插圖 | 登記、租約、合約、貸款完成時顯示 | C | 規劃中 |
| 15 | 手機 App 圖示、Company OS 外框 | `phone_ui.gd`、`company_os.gd` 換皮 | A7 之後 | 規劃中 |
| 16 | 目標引導箭頭 | tutorial 有 `effects/guide_arrow` 就改畫圖 | A8 | ✅ 已接好 |
| 17 | 天氣 | 下雨系統：雨、水窪反光、雨聲 | P1 特效 | 規劃中 |
| 18 | Elena 外型 | Elena 改成心形臉、旁分髮、細長眼、平眉，白外套配深色褲 | A1 | ✅ 已完成 |
| 19 | 服裝細節層 | `outfit_*_top_detail` / `_bottom_detail`、`portraits/outfit_*_detail` 畫在染色布料上 | R1 | ✅ 已完成：四位 NPC 的西裝和 Dara 的快遞服已上色；路人西裝用西裝色 |
| 20 | NPC 辨識度 | Ken 改穿 TradeLink 藍外套（不再和 Dara 撞衫）；Maya 外套改成暖芥末色；Priya 蜜桃色襯衫 | A1 | ✅ 已完成 |
| 21 | 座位 | `Interior.seats()`：坐在椅子正中間、面向最近的桌子；沙發面向前方；經理座位不給客人坐；坐著的 NPC 和員工會對齊到最近的座位 | R3 | ✅ 已完成 |
| 22 | 姿勢暫時退回 | `idle` 和 `phone` 只播第 1 格；出貨員工用 `idle` 代替 `interact` | R3 修正 | ⏳ 等 R3 修正後恢復 |

## 交件檢查表（每個 PR 都貼一份）

```
- [ ] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [ ] 沒有改舊檔名；新檔名照 wiki 命名規則
- [ ] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json
- [ ] godot --import 無錯誤
- [ ] 單元測試全部通過（貼最後一行）
- [ ] --bot=shots 截圖巡禮 0 失敗
- [ ] python3 tools/wiki_check.py 通過
- [ ] 有動角色圖時：python3 tools/qa/pose_check.py 通過
- [ ] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [ ] wiki 對應條目的「美術」狀態已更新
- [ ] 需要程式接線的項目已列在 PR 說明
```
