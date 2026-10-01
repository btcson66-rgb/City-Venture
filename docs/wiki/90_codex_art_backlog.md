# 90 Codex 美術工單

這一頁是**給 Codex（或任何接手美術的人）的施工單**：先做什麼、後做什麼、每一批交哪些檔案、怎樣算做完。

規格細節在前面各頁，這裡只列工作項目和驗收標準。

## 目前畫面的狀態（2026-09-29）

Codex 第一輪（`codex/visual-art-pass-01`，已合併）的效果，在同一條截圖路線上比對過：

| 區域 | 變化 | 結論 |
|------|------|------|
| 主選單背景 `menu` | 重畫：街景更乾淨，旗幟改用符號 | ✅ 明顯變好 |
| 抵達背景 `arrival` | 重畫：河岸天際線、橋、倒影 | ✅ 明顯變好 |
| 角色走路圖 | 第一輪只修細節；**A1（已合併）**重畫了輪廓、體型、鞋子和走路 4 格 | ✅ A1 明顯變好 |
| 西裝、快遞服 | **R1（已合併）**：布料可染色，領帶和襯衫另外一層 | ✅ 四位穿西裝的 NPC 分得出來 |
| 室內 | **A2（已合併）**：家具色階統一；銀行、市政櫃台分開；菜單板改成圖示；新增 3 款地板、7 款牆 | ✅ 明顯變好 |
| 角色姿勢 | **R3 ＋ R3 修正（已合併）**：坐、站、講電話、伸手、搬箱，`pose_check: OK`，全部上線 | ✅ |
| 角色頭像 | **A5（已合併）**：表情更清楚，Priya、Ana、Daniel 的頭像有眼鏡了 | ✅ |
| 建築立面 | **A3、R7（已合併）**：門更深、側牆陰影更柔，夜燈約六成亮；招牌板加寬，無名建築改成雨遮或門牌 | ✅ |
| 街道、地磚 | **A4（已合併）**：人行道、柏油、河面不再有格子感 | ✅ |
| 地圖、地點卡 | **A6、R7（已合併）**：地點卡沒有標語；`map_label_check: OK` | ✅（還有三張卡的補丁太平，見 R8） |
| UI 圖示、App 圖示 | **A7（已合併）**：43 個圖示統一成圓角線條 | ✅（三個圖示不好認，見 R8） |
| 車輛、特效 | **A8（已合併）**：19 張車輛、5 個特效重畫，新增 `water_sparkle`（已接到河面） | ✅（小車和轎車輪廓太像，見 R8） |
| 購物街 | **B1 起步（已合併）**：七棟立面、街道物件、Threadline 家具，已接進遊戲 | ✅ 可以玩（服裝、Crestline 和 Bistro 家具待交，見 B1 續） |

**結論**：A 批全部完成。購物街已經可以玩，剩下的 B1 美術（服裝、兩間店的家具、地點卡）到了會自動換上。

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
   python3 tools/qa/map_label_check.py                                # 有動地圖時：底圖補丁和遊戲標籤對齊
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

**美術交件（2026-09-28）**：28 張現有街道物件在原尺寸與透明輪廓內調整色階及材質，護柱、樹籬等高頻重複物件降彩度與對比；`tiles/atlas.png` 的 23 格地面地磚重整人行道石板、柏油與河水紋理，格位及其他室內地磚不變。兩款路燈燈頭亮部中心與 `sprite_meta.json` 光暈座標一致。平鋪預覽與四街區實機對照見 `evidence/2026-09-28_a4_streets/`。

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
| 頭像圖層 | `portraits/*.png` | 45 基礎層＋R1 新增的 2 個衣領細節層 |
| 新增：頭像眼鏡 | `portraits/acc_glasses_round.png`、`acc_glasses_square.png`（64×64） | 2（程式已接好） |

**驗收**：

- [x] 4 個表情（平靜、開心、思考、驚訝）差別明顯
- [x] 12 位具名 NPC 的頭像並排時，每個人都認得出來

**A5 美術交件（2026-09-28）**：重製既有 45 張基礎頭像圖層及 R1 的 2 張衣領細節圖層，另新增圓框／方框眼鏡兩張 64×64 圖與 `.png.import`。表情眼神、眉形、嘴形和輪廓邊緣已細修；`tools/art/a5_preview.py` 依遊戲圖層順序與 NPC 染色渲染 12 位具名角色和四表情，驗收圖見 `evidence/2026-09-28_a5_portraits/`。未改角色資料或對話邏輯。

### A6 地圖與地點卡

| 交付 | 檔案 | 數量 |
|------|------|------|
| 城市地圖 | `city_map/board.png`、`aurelia_map.png`、`i_*.png` | 15 |
| 世界地圖 | `world_map/board.png`、`r_*.png` | 9 |
| 地點卡 | `cards/*.png` | 11 |
| 新增：PostPoint 地點卡 | `cards/postpoint_riverside.png` | 1 |

**驗收**：標籤位置（`aurelia.json`、`regions/*.json` 的 `board`）留素底；構圖改了就一起改座標；地點卡上沒有文字。

**A6 美術交件（2026-09-28，含 R2）**：15 張城市地圖、9 張世界地圖、12 張地點卡已重製。主圖保留原參考圖與所有 `board.label`／`board.pin` 座標，清空預印標籤與英文地圖說明；Riverside 旗幟、辦公室口號、菜單及海報改成圖示或材質，保留 R2 允許的品牌招牌。新增 PostPoint 專屬卡與 `.png.import`。原尺寸不變，製作腳本 `tools/art/a6_maps_cards.py`，前後與遊戲截圖見 `evidence/2026-09-28_a6_maps_cards/`。

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
| **B3** | 老城 | 5 棟可進入建築和 3 棟填充建築；石板地磚；壁畫、鑄鐵路燈；老城天際線；老城套房和 Okafor 租屋行室內；Mr. Okafor | [03](03_districts.md#old-town-老城區--old_town) |
| **B4** | 住宅區 | Maple Court、FreshMart、社區中心；遊樂場物件；Maple Court 公寓室內（住宅第 2 階家具組） | [03](03_districts.md#residential-住宅區--residential--p1) |
| **B5** | 大學區 | AIT 主館、創新實驗室；學生服裝；Prof. Hana Sato | [03](03_districts.md#university-大學區--university--p1) |
| **B6** | 現有區域加蓋 | Northlight Capital（外觀和室內）、Launchpad、Horizon Labs 3F 室內、捷運月台 | [03](03_districts.md#現有區域的規劃中建築) |
| **B7** | 氣氛插圖 | 章節標題卡 1–6、`skyline_dusk`、公司結束後的 `insolvency` 畫面 | [11](11_backdrops_maps.md) |
| **B8** | 角色姿勢 | 坐、搬箱、講電話、伸手互動、站立呼吸（每個姿勢要涵蓋 A1 的全部圖層） | [07](07_characters.md#姿勢與動畫) |
| **B9** | 品牌與商品 | 13 個公司標誌、3 個 SaaS logo、4 張商品照（手機隨手拍版和專業攝影版） | [08](08_items.md) |
| **B10** | 專屬 NPC | `characters/npc_<id>.png` 和 `portraits/npc_<id>.png`：Maya、Marcus、Daniel、Elena、Priya、Jun | [07](07_characters.md#專屬-npc-美術程式已接好) |

**B1 美術起步（2026-09-29）**：已先交購物街七棟立面與夜燈、Threadline 六件室內家具、三色市集攤 `props/market_stall_rose.png`、`props/market_stall_sage.png`、`props/market_stall_cream.png`、`props/string_lights.png`（string lights 串燈及 `_lights`）、花攤、長花台、腳踏車架；尺寸與碰撞 metadata 同步。五套服裝、配件與 Nina 仍待 B1 後續交件；遊戲區域資料與互動接線由 Claude 線負責。對比圖與驗收記錄見 `evidence/2026-09-29_b1_shopping_street_start/`。

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

## R3 修正、A3、A4、A6、A5 驗收後的新需求（2026-09-28，Claude 線，第三輪）

五批（PR #6–#10）都已合併。驗收時我跑了以下檢查，全部通過：

| 檢查 | 結果 |
|------|------|
| `pose_check` | OK |
| 單元測試 | 67/67 |
| 截圖巡禮 | 28 張，0 失敗 |
| 完整遊玩第 1–6 章 | 通過 |
| `wiki_check` | 通過 |
| 翻譯 | 缺 0 |

| 批次 | 結論 | Claude 線做了什麼 |
|------|------|-------------------|
| R3 修正 | ✅ 六個瑕疵全部修好 | `idle`、`phone` 恢復 2 格動畫；出貨員工改回 `interact` |
| A3 建築 | ✅ | 修好招牌文字的位置：以前名字比招牌板寬時，字會往右滑出招牌板（例如 RIVERSIDE TOWER）。現在會縮小字體，並置中在招牌板上 |
| A4 街道 | ✅ | — |
| A6 地圖、地點卡 | ✅ R2 完成 | 修好地圖標籤被截斷的問題（University District、International Airport、Industrial Zone 等）。現在標籤卡會依文字長度變寬，並保持置中 |
| A5 頭像 | ✅ | Priya 的襯衫從蜜桃色改成青綠色，因為蜜桃色太接近膚色，走路圖和頭像都像沒穿衣服 |

**請依這個順序**：**R7 → A7 → A8**。之後開始 B1（購物街和衣櫃系統）。

### R7 小修正（半天以內的量）

**1. 招牌板太窄**。程式只能把字縮到 5 px，看得到但很小。請把招牌板加寬，同時改 `buildings_meta.json` 的 `sign` 寬度（高度維持 9–10），讓 7 px 字體放得下：

| 立面 | 現在 | 至少 | 招牌文字 |
|------|------|------|---------|
| `riverside_tower` | 46 | 90 | RIVERSIDE TOWER |
| `suite_building` | 46 | 96 | 22 FOUNDERS LANE（租下後是「公司名 · 2B」，可能更長） |
| `nexus_cowork` | 46 | 80 | NEXUS CO-WORK |
| `horizon_labs` | 46 | 74 | HORIZON LABS |
| `finance_tower` | 46 | 68 | ARC CAPITAL |
| `civic_annex` | 46 | 63 | TAX OFFICE |
| `city_hall` | 98 | 102 | AURELIA CITY HALL |

**2. 沒有名字的建築畫了空白招牌板**：`office_slab`、`glass_tower`、`riverside_walkup`。它們的 `sign_text` 是空的，所以程式不會寫字，畫面上就是一塊空黑板。請改成大廳雨遮或門牌，不要留深色空板。

**3. 地圖上的空白補丁**。新工具 `python3 tools/qa/map_label_check.py` 會比對底圖上的深色補丁和遊戲標籤的位置，目前回報兩處：

```
overhang  city_map 捷運站補丁比 Central Station 標籤左邊多出 34 px
orphan    world_map 左下角 (50,236)–(145,254) 有一塊補丁，上面沒有標籤
```

驗收：`map_label_check: OK`。

**4. 地點卡的去字補丁太平**：有字的地方被蓋成一塊平平的色塊，沒有透視和光影，看起來像貼上去的：

| 卡片 | 問題 | 建議 |
|------|------|------|
| `byte_and_bean` | 菜單板變成黑色方塊 | 比照室內菜單板，畫咖啡杯圖示加色塊 |
| `small_office` | 白板變成一塊平的米色板 | 畫出有透視的白板，上面有便利貼和手繪圖表 |
| `city_hall` | 大樓招牌變成空白米色板 | 品牌招牌屬於 R2 的例外，可以保留 AURELIA CITY HALL；或改成市徽 |
| `startup_hub` | 右邊旗幟變成米色貼紙 | 畫成有布料皺褶的旗幟，上面放圖示 |

**5. R6 的兩件小事也還在**：大理石地板紋路太大；咖啡師圍裙和市政職員名牌也拆成可染色布料加細節層。

---

## R7、A7、A8、B1 起步驗收後的新需求（2026-09-29，Claude 線，第四輪）

四批（PR #11–#14）都已合併。驗收結果：

| 檢查 | 結果 |
|------|------|
| `pose_check` | OK |
| `map_label_check` | OK |
| 單元測試 | 74/74（新增 7 個購物街測試） |
| 截圖巡禮 | 41 張，0 失敗（新增購物街、市集、Threadline 購買） |
| 完整遊玩第 1–6 章 | 通過 |
| `wiki_check` | 通過 |
| 翻譯 | 缺 0 |

| 批次 | 結論 | Claude 線做了什麼 |
|------|------|-------------------|
| R7 | ✅ 五項全部完成。招牌字不用再縮到 5 px | — |
| A7 圖示 | ✅ 風格統一。三個圖示不好認，見 R8 | — |
| A8 車輛、特效 | ✅ | `water_sparkle` 接到河面：每個光點閃過 4 格後休息，晚上變淡 |
| B1 起步 | ✅ 七棟立面、街道物件、Threadline 家具都和現有畫面一致 | **購物街接進遊戲**，見下方 |

**購物街（Claude 線已完成）**：

- 從 Civic Center 往西走 8 分鐘，或搭捷運 M5。城市地圖上標示為「Open」。
- 七棟立面照 `gen_districts.py` 排版。市集攤只在**週六、週日 09–18 點**擺出來，其他時間收起，也可以穿過去。串燈掛在路燈之間，畫在行人上方，晚上會亮。
- **Threadline**：逛衣架可以買五套新服裝（$120–$780，從個人現金付，計入「服裝」支出），在試衣間或家裡的衣櫃換上。店員 Nina 每天 10–21 點在，第一次逛衣架時會打招呼。假人用 `tint` 染成三種顏色。
- **Lantern Bistro**：點招牌套餐（$22，50 分鐘，計入「餐飲」支出），會有客人坐著用餐。
- **Crestline 旗艦店**：第 5 章交貨後，展示台上會出現玩家的 LED 檯燈。Daniel 接洽大訂單後，週末 11–16 點會在店裡。
- **Pop-up Unit 5**：空店面，可以看租約公告。承租是規劃中（P3）。
- 路人多穿 Luxury Citywear，大衣有 5 種顏色。
- **五套服裝的美術還沒到**，目前用現有服裝換色暫代：Executive 和 Formal Evening 用 `business_suit`，Luxury Citywear 和 Travel 用 `casual_jacket`，Logistics 用 `courier`。正式圖一放進 `characters/` 就會自動換上，不用改程式。
- 順便修了一個舊 bug：從街上進室內時，舊場景的牆會多留一幀，偶爾把玩家推出房間外（實測被推到門外 120 px）。現在換場景時會先把舊場景移出物理世界。

**請依這個順序**：**R8 → B1 續**。之後開始 B2（港區）。PR #11–#14 已經合併，請從 `claude/exciting-bardeen-y71ixv` 開新分支接著做。

### R8 小修正（半天以內的量）

| # | 項目 | 問題 | 建議 |
|---|------|------|------|
| 1 | 圖示 `company` | 看起來像手機或筆記本，不像公司 | 畫成一棟小辦公樓或公事包 |
| 2 | 圖示 `walk` | 沒有頭，看起來像「λ」 | 畫成走路的人（有頭、手腳） |
| 3 | 圖示 `civic` 和 `bank` | 兩個都是柱子加三角屋頂，幾乎一樣 | `civic` 改成圓頂或旗子，和銀行分開 |
| 4 | 車輛 `compact_side`（加 `_front`、`_back`） | 和 `sedan_side` 輪廓一樣，只是比較小 | 畫成掀背車：車尾短、車頂高 |
| 5 | 地點卡 `riverside` | 左邊的藍色旗幟是平的色塊 | 比照 R7 的做法：畫出布料皺褶，上面放圖示 |
| 6 | 地點卡 `financial` | 三面藍旗是平的色塊加白圓點 | 同上 |
| 7 | 地點卡 `byte_and_bean` | 店名下面有一條平的米色長條 | 補成牆面或畫出招牌的厚度 |

### B1 續（依優先順序）

**1. 五套服裝**（最重要，玩家已經買得到）：`executive`、`luxury_citywear`、`travel`、`formal_evening`、`logistics_site`。

- 每套都要：3 種體型 × `_top`、`_bottom`、`_shoes`；有全彩細節時加 `_top_detail`；頭像 `portraits/outfit_<id>`（加 `_detail`）。
- **每一張都要有五種姿勢圖**（`_sit`、`_idle`、`_phone`、`_interact`、`_carry`），不然穿這套時所有姿勢都會停用。
- 布料用灰階：路人的 Luxury Citywear 大衣會染成 5 種顏色（`options.json` 的 `npc_tops`），Nina 是炭灰 `#3A3A42`。
- 驗收：`pose_check: OK`（新服裝一放進 `characters/` 就會被檢查到）。

**2. Crestline 室內家具**（目前用鞋架、衣架和一張小茶几暫代）。室內資料已經寫好這些檔名，並指定暫代圖（`fallback`），**檔案放進 `interiors/` 就會自動換上**：

| id | 尺寸 | 說明 | 目前暫代 |
|----|------|------|---------|
| `retail_shelf` | 48×48 | 商品貨架，放盒裝商品 | `shoe_shelf` |
| `display_table` | 48×32 | 陳列桌 | `clothing_rack` |
| `lamp_display` | 48×48 | 燈具展示台，空的（第 5 章交貨前） | `coffee_table` |
| `lamp_display_stocked` | 48×48 | 同一個展示台，擺滿玩家的 LED 檯燈（交貨後）。有這張圖時，程式就不再另外疊 `product_desk_lamp` | `coffee_table` 加兩盞 `product_desk_lamp` |
| `escalator` | 64×64 | 手扶梯，放在背景（右上角） | 沒有圖時不畫 |

**3. Lantern Bistro 室內家具**（目前用咖啡店的桌椅暫代，同樣會自動換上）：`dining_table`（兩人桌，桌巾，暫代 `cafe_table`）、`bar_counter`（吧台，暫代 `cafe_counter`）、`kitchen_pass`（出餐口，80×40，暫代 `kitchen`）。名稱有 `table`、`counter` 的家具，客人會自動面向它坐。

**4. 地點卡**（192×108，和現有卡片一樣）：`cards/shopping_street`、`cards/threadline_apparel`、`cards/crestline_flagship`、`cards/lantern_bistro`。沒有卡的建築會改用區域的卡。

**5. 配件**：帽子、包包、手錶、識別證、耳麥。程式已經改好：`characters/acc_<id>.png` 存在就會畫出來（和眼鏡、背包一樣要附五種姿勢圖）。選項和 Threadline 販售由 Claude 線加。

**6. Nina 專屬圖（選做）**：`characters/npc_nina`、`portraits/npc_nina`，加上皮尺和別針墊。沒有也沒關係，現在用分層外型。

---

## 小遊戲美術（新，可以在 B1 續之後做）

2026-09-29 起，打工、拍照、打包、寫程式都改成玩家親手玩的小遊戲（見 [13](13_core_loop_and_work.md)）。目前畫面用色塊和現有素材拼出來，**能玩但很素**。可以替換的美術，放進去就會用：

| 檔案 | 尺寸 | 用在 | 說明 |
|------|------|------|------|
| `minigames/barista_counter.png` | 580×236 | 咖啡師 | 吧台近景：咖啡機、磨豆機、杯架，左邊留客人對話框的位置 |
| `minigames/cups.png` | 3 格 × 48×64 | 咖啡師 | 小、中、大三種空杯（程式會畫內容物） |
| `minigames/sorting_belt.png` | 580×120 | 分揀員 | 輸送帶和 5 個區域籃子（籃子上不寫字） |
| `minigames/front_desk.png` | 580×236 | 共享辦公室接待 | 櫃台和夾板 |
| `minigames/clerk_desk.png` | 580×236 | 市政廳辦事員 | 辦公桌、印章、便利貼 |
| `minigames/banknotes.png` | 6 格 × 48×24 | 銀行櫃員 | $100、50、20、10、5、1 紙鈔（Aurelia 貨幣，數字可以畫在鈔票上） |
| `minigames/photo_backdrops.png` | 4 格 × 300×196 | 拍商品照 | 白色無縫、木頭桌面、粉彩色卡、深色石板 |
| `minigames/photo_props.png` | 小盆栽、筆記本 | 拍商品照 | 陪襯道具，透明底 |
| `minigames/packing_bench.png` | 250×130 | 打包 | 俯視的打包桌面 |
| `minigames/boxes.png` | 3 格 | 打包 | 小、中、大紙箱（打開的樣子） |
| `minigames/route_map.png` | 580×236 | 物流排路線 | 已接好：放進去就取代程式畫的簡易地圖（`RouteGame`）。俯視的簡化城市地圖，河、主要道路、各區色塊，**不要有字**；資料裡地點、河和橋的座標要對著圖調（見 B2） |

程式端會在檔案存在時改用圖片；這一項目前是**規劃中**，沒有 Codex 的圖也能玩。

## 中文版的英文字（2026-09-29 第二次試玩，給 Codex 參考）

試玩者希望中文版裡看不到英文。程式能改的都改了，招牌也改成程式疊字、依語言翻譯。下面這些是**畫在圖裡**的英文，程式翻不了：

| 圖 | 英文 | 建議 |
|----|------|------|
| `interiors/` Nexus 共享辦公室牆上的標語板 | NEXUS WORK · MEET · CREATE | 改成不帶字的圖樣，或留空白讓程式疊字 |
| 建築立面上的門牌、看板小字 | 例如 RIVERSIDE TOWER 旁的小字 | 以後畫新立面時，文字盡量留給程式疊字（`sign` 欄位） |

優先度低，不擋任何功能。

## 第 7–9 章美術（2026-09-30，Claude 線，第五輪）

第 7–9 章的玩法已經做完，現在都用現有素材暫代。下面的圖交進來就會自動換上，程式不用改。高解析版照 [13 執行期美術](13_runtime_art.md) 的 `world_detail/` 規則放，原本尺寸的版本也要一份（沒有高解析版時用它）。

優先順序：**S1 > S2 > S3**。每一批可以獨立交。

### S1：章節卡和 Lina（玩家一定會看到）

| 檔案 | 尺寸 | 內容 | 目前 |
|------|------|------|------|
| `backdrops/chapter_7.png` | 640×360 | 供應衝擊：港外排隊的貨櫃船，前景是空了一半的貨架（無字） | ✅ S1 美術完成；原尺寸與 4× 已交 |
| `backdrops/chapter_8.png` | 640×360 | 綠色轉型：屋頂的太陽能板和城市天際線，樓下一台電動貨車在充電 | ✅ S1 美術完成；原尺寸與 4× 已交 |
| `backdrops/chapter_9.png` | 640×360 | 結算危機：銀行大廳排隊的人，牆上螢幕是「處理中」的沙漏圖示（無字） | ✅ S1 美術完成；原尺寸與 4× 已交 |
| `characters/npc_lina.png`（加 `_sit`） | 128×144（4×3 格） | Lina Zhao，外型照 [07 角色](07_characters.md) 的設定：心形臉、黑色長髮、黑色高領、城市精品外套 | ✅ S1 美術完成；三向站姿與坐姿 |
| `portraits/npc_lina.png` | 256×64（4 表情） | 同上。表情：平常、微笑、思考、驚訝 | ✅ S1 美術完成；四表情 |
| `world_detail/characters/npc_lina.png`、`world_detail/characters/npc_lina_sit.png` | 512×576 | 上面兩張的高解析版 | ✅ S1 美術完成 |
| `world_detail/portraits/npc_lina.png` | 高解析 4 格 | 同上 | ✅ S1 美術完成 |

Lina 坐在 Nexus Bank 右下角新加的辦公桌（`exec_desk` 在 x 330, y 190，椅子 x 354, y 170），平日 10–16 點，第 5 年起才出現。

### S2：新商品、新供應商

| 檔案 | 尺寸 | 內容 | 目前 |
|------|------|------|------|
| `props/product_solar_lamp.png` | 同 `props/product_desk_lamp` | 太陽能檯燈：燈座上有一小片太陽能板，暖白燈罩 | ✅ S2 美術完成；16×16 與 4× |
| `products/solar_lamp_photo.png`、`solar_lamp_photo_raw.png` | 同其他商品照 | 棚拍版和自己拍的版本 | ✅ S2 美術完成；64×64 與 4× |
| `logos/aurelia_makers.png` | 同其他 logo | 奧瑞莉亞職人合作社：暖橘配深灰，扳手和針線交叉成一顆星 | ✅ S2 美術完成；32×32 與 4× |
| `logos/verdant_supply.png` | 同其他 logo | Verdant Supply：草綠，一片葉子長出太陽光線 | ✅ S2 美術完成；32×32 與 4× |
| `minigames/recycled_padding.png` | 64×32 | 打包小遊戲用的回收紙緩衝（牛皮紙色，皺摺紋理） | ✅ S2 美術完成；64×32 與 4×；BoxView 待 Claude 線接圖 |

### S3：事件插圖和街景

| 檔案 | 尺寸 | 內容 |
|------|------|------|
| `events/supply_shock_plan.png` | 160×90 | 港外排隊的貨櫃船，前景一張被紅筆圈起來的運費單（無字） |
| `events/payment_pending.png` | 160×90 | 手機上的轉帳畫面，一個一直轉的處理中圖示（放進去就會出現在「付款給國外供應商」畫面上方） |
| `props/port_cranes_far.png` | 自訂 | 河濱區遠景的港口吊車剪影，第 3 年起出現（需接線） |
| `props/solar_roof_*.png` | 自訂 | 屋頂太陽能板，第 4 年起出現在部分建築頂上（需接線） |
| `props/ev_charger.png` | 同 `props/parking_meter` 比例 | 路邊電動車充電樁，第 4 年起出現（需接線） |

S3 的街景三項需要程式接線（依年代顯示），交圖後由 Claude 線接上。

**S3 美術交件（2026-09-30）**：`events/supply_shock_plan.png`、`events/payment_pending.png`、`props/port_cranes_far.png`、`props/solar_roof_small.png`、`props/solar_roof_large.png`、`props/ev_charger.png` 及對應 `world_detail/` 4× 版已完成，含 `.png.import`。事件圖由既有決策／結算 UI 動態讀取；三種街景物件仍待 Claude 線分別在第 3 年（吊車）和第 4 年（兩款太陽能屋頂、充電樁）接入適當街區。美術稿與縮圖在 `docs/art_sources/s3_20260930/`，證據在 `evidence/2026-09-30_s3_events_streets/`。

### 第 10–12 章（先看，還不用畫）

第 10 章 Digital Rails、第 11 章 The Other Side of Trust、第 12 章 Regulation & Scale 已經實作（程式和資料都在，見 [STORY_IMPLEMENTATION §9](../STORY_IMPLEMENTATION.md)），美術照第六輪的清單畫，程式會自動接上。需要：

- 章節卡 `chapter_10` 到 `chapter_12`，內容見 [11 背景](11_backdrops_maps.md)；
- Lina 辦公室的室內場景；
- 新聞快報畫面；
- 金融區總部的頂樓會議室。

規格會寫在這一節。**不要用任何真實加密貨幣的標誌或名稱**。

## 第六輪：老城區、港區、咖啡店與物流、第 10–12 章卡（2026-09-30，Claude 線）

Claude 線接下來要開放兩個街區和兩個新產業：

- **老城區**（`old_town`）：租金便宜，玩家可以在這裡開自己的咖啡店，也就是新產業「咖啡／餐飲」；
- **港區**（`harbor`）：第 7 章的港口、第 9 章的進口都在這裡。玩家可以租 Pier 7 倉庫當第二個庫存點，也可以買一台二手貨車，做新產業「物流」。

程式會照 [03 街區](03_districts.md) 的設定稿排版。所有圖都**照現有尺寸和 `world_detail/` 高解析規則**交；沒有圖的地方，程式會先用現有素材暫代。

優先順序：**S1–S3（上一節）→ B3 老城 → B2 港區 → C10**。

### B3 老城區（咖啡店產業）

**美術狀態（2026-09-30）**：必交項目已交原尺寸、4× 版及 `.png.import`：6 款立面與發光層、2 款石板地磚、5 款街道物件（老式路燈含發光層）、11 款室內家具、Okafor 專屬三方向四表情／坐姿／四表情頭像、4 張地點卡。地磚加入原 atlas 的空格 `(6,4)`、`(7,4)`，既有 38 格未移動。可選天際線未交。原稿與尺寸清單在 `docs/art_sources/b3_20260930/`；實機對照在 `evidence/2026-09-30_b3_old_town/`。`espresso_machine_pro` 尚待 Claude 線放入咖啡店資料；建築外觀與地面目前由既有程式讀原尺寸圖，4× 外觀／地磚的渲染接線另待 Claude。

| 類型 | 檔案 | 說明 |
|------|------|------|
| 可進入立面 + `_lights` | `buildings/corner_cafe_unit` | **玩家的咖啡店**。一樓小店面，大窗、遮陽棚、門口兩張小圓桌。招牌板留空，由程式疊玩家取的店名（和 Suite 2B 一樣） |
| | `buildings/old_town_studio` | 老城套房：三層紅磚樓，一樓門口有信箱。最便宜的住處 |
| | `buildings/okafor_lettings` | Okafor 租屋行：窄門面，櫥窗貼滿物件照片（無字） |
| 填充立面 + `_lights` | `buildings/rowhouse_brick`、`buildings/arcade_arches`、`buildings/clock_tower` | 紅磚連棟屋、拱廊、鐘樓（地標，最高） |
| 地磚 | `tiles/atlas.png` 加 `cobble_a`、`cobble_b` | 16×16 石板路，兩種變化 |
| 街道物件 | `props/mural_wall`、`props/ivy_trellis`、`props/old_lamp`（加 `_lights`）、`props/bookstall`、`props/cafe_chairs_bistro` | 壁畫牆不要有字 |
| 室內 | `corner_cafe`：`interiors/cafe_counter_small`、`interiors/espresso_machine_pro`、`interiors/pastry_case_small`、`interiors/menu_board_blank`（程式疊菜單字）、`interiors/cafe_table_round`、`interiors/cafe_stool` | 約 30×16 格的小店，吧台在後牆，4 張小桌 |
| | `old_town_studio`：`interiors/bed_single`、`interiors/kitchenette`、`interiors/radiator` | 比河濱大樓更小更舊 |
| | `okafor_lettings`：`interiors/listing_board`（貼滿照片的軟木板，無字）、`interiors/old_desk` | 一張桌子、一面牆的物件照片 |
| NPC | `characters/npc_okafor`、`portraits/npc_okafor`（加 `world_detail`） | Mr. Okafor：六十多歲的房東，灰白短髮、背心、老花眼鏡、很和善 |
| 地點卡 | `cards/old_town`、`cards/corner_cafe_unit`、`cards/old_town_studio`、`cards/okafor_lettings` | 192×108 |
| 天際線（選配） | `backdrops/skyline_old_town_day`、`_night` | 鐘樓和紅磚屋頂 |

### B2 港區（物流產業）

**程式已接好（2026-09-30）**：港區、Pier 7 倉庫、Dockside Motors、健身房、海關大樓（進不去）、Sam 和物流業都能玩，下表的檔案名稱資料裡都已經寫好，圖用現有素材暫代（暫代對照見 [03](03_districts.md)、[04](04_buildings.md)、[05](05_interiors.md)）。**交件後**：立面和地磚更新 `buildings_meta.json` / `atlas.json` 就會自動換上；新街道物件（貨櫃、堆高機、繩圈、救生圈、吊車）要在 `tools/gen_districts.py` 的 `harbor_quay()` 加進去再跑一次 `python3 tools/gen_districts.py harbor`；`loading_dock_door`、`forklift_parked` 已寫在 Pier 7 室內資料裡（沒有合理暫代，沒圖時不畫）；排路線小遊戲的底圖 `minigames/route_map.png` 放進去就會取代程式畫的簡易地圖，**但資料裡地點、河和橋的座標（`data/economy/logistics.json` 的 `places`、`map`）要對著圖調整**，河要沿著圖上的河、橋要在圖上的橋。

| 類型 | 檔案 | 說明 |
|------|------|------|
| 可進入立面 + `_lights` | `buildings/pier7_warehouse` | Pier 7 倉庫：大鐵捲門、裝卸平台、門口停棧板。可以租來放庫存 |
| | `buildings/dockside_motors` | Dockside Motors 二手貨車行：小辦公室加一片停車場，停兩台舊貨車。**玩家在這裡買第一台貨車** |
| | `buildings/harbor_point_fitness` | Rosa 的健身房（現在只在手機出現） |
| | `buildings/customs_house` | 海關大樓（第 9、12 章會用到，先不能進入） |
| 填充立面 + `_lights` | `buildings/warehouse_shed`、`buildings/cold_store`、`buildings/container_stack` | 倉庫棚、冷凍倉、貨櫃堆 |
| 背景 | `props/crane_gantry`（高，剪影）、`backdrops/skyline_harbor_day`、`_night` | 岸邊吊車和海面上的貨輪 |
| 地磚 | `tiles/atlas.png` 加 `quay_edge`、`quay_concrete`、`water_harbor` | 岸壁、碼頭水泥地、港區海水（比河面深） |
| 街道物件 | `props/container_red`、`_blue`、`_green`、`props/pallet_stack`、`props/crate`、`props/mooring_bollard`、`props/rope_coil`、`props/life_ring`、`props/forklift`、`props/harbor_lamp`（加 `_lights`） | |
| 室內 | `pier7_warehouse`：`interiors/pallet_rack`（高貨架，放紙箱）、`interiors/loading_dock_door`、`interiors/forklift_parked`、`interiors/packing_bench_large` | 約 36×18 格，貨架成排 |
| | `dockside_motors`：`interiors/sales_desk`、`interiors/key_board`（掛鑰匙的板子） | 小辦公室 |
| 車輛 | `vehicles/van_player_side_body`、`_detail`（加 `_front`、`_back`） | **玩家的貨車**：和現有 `van_side` 同尺寸，白色車身、側面留一塊空白讓程式疊公司名 |
| 小遊戲 | `minigames/route_map.png` | 580×236，俯視的簡化城市地圖（河、主要道路、各區色塊），給「排送貨路線」小遊戲當底圖。不要有字 |
| NPC | `characters/npc_rosa`、`npc_ines`、`npc_sam`（加頭像和 `world_detail`） | Rosa Lim（健身房老闆，運動外套）、Ines Duarte（海關，制服）、Sam Okoro（貨車行老闆，工作服、手上有機油） |
| 地點卡 | `cards/harbor`、`cards/pier7_warehouse`、`cards/dockside_motors` | 192×108 |

### C10 第 10–12 章卡

| 檔案 | 尺寸 | 內容 |
|------|------|------|
| `backdrops/chapter_10.png` | 640×360 | 數位軌道：抽象的光軌穿過夜晚的城市（**不用任何加密貨幣標誌**） |
| `backdrops/chapter_11.png` | 640×360 | 信任的另一面：一座斷掉的橋（比喻），前景一台手機跳出新聞快報 |
| `backdrops/chapter_12.png` | 640×360 | 監管與規模：金融區頂樓會議室，長桌、文件，窗外是世界地圖投影 |
| `events/rail_frozen.png` | 160×90 | 付款畫面上一個被鎖住的圖示（第 11 章） |
| `events/acquisition_offer.png` | 160×90 | 會議桌上的收購意向書和兩支筆（第 12 章） |

## 程式接線清單

以下是**光交圖不夠**、需要改程式才會出現在遊戲裡的項目。Claude 線負責。✅ 表示已接好：檔案放進去就會出現。

| # | 項目 | 程式改動 | 對應美術 | 狀態 |
|---|------|---------|---------|------|
| 1 | 頭像眼鏡 | `Art.portrait_layers` 讀 `portraits/acc_<配件>` | A5 | ✅ 已接好 |
| 2 | 專屬 NPC 圖 | 有 `characters/npc_<id>`、`portraits/npc_<id>` 時取代分層組合 | B10 | ✅ 已接好 |
| 3 | 更多表情 | 表情長條從 4 格改成 10 格，對話資料加表情標記 | 表情 P1 | 規劃中 |
| 4 | 角色姿勢 | `CharacterRig.set_pose()`：sit、idle、phone、interact、carry；NPC、員工、客人、玩家手機都已套用 | B8 / R3 | ✅ 已接好 |
| 5 | 新服裝和配件 | `options.json` → `outfits_shop`、`Wardrobe`、Threadline 購買和試衣間；美術到前用 `stand_in` 暫代；配件有 `acc_<id>` 就畫 | B1 | ✅ 服裝已接好；配件的選項和販售規劃中 |
| 6 | 新區域 | 區域和建築資料、`gen_districts.py` 排版、捷運站開放 | B1–B6 | ✅ 購物街、老城區、港區（暫代圖）；其他區規劃中 |
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
| 20 | NPC 辨識度 | Ken 改穿 TradeLink 藍外套（不再和 Dara 撞衫）；Maya 外套改成暖芥末色；Priya 青綠色襯衫 | A1 | ✅ 已完成 |
| 21 | 座位 | `Interior.seats()`：坐在椅子正中間、面向最近的桌子；沙發面向前方；經理座位不給客人坐；坐著的 NPC 和員工會對齊到最近的座位 | R3 | ✅ 已完成 |
| 22 | 姿勢恢復 | `idle`、`phone` 恢復 2 格動畫；出貨員工恢復 `interact` | R3 修正 | ✅ 已完成 |
| 23 | 招牌文字置中 | 招牌字放不下時縮小字體（最小 5 px），並置中在招牌板上 | A3 | ✅ 已完成；招牌板要加寬（R7） |
| 24 | 地圖標籤自動寬度 | 城市和世界地圖的標籤卡依文字變寬，並保持置中、留在地圖內 | A6 | ✅ 已完成 |
| 25 | 道具新欄位 | `show`（限時出現：市集攤）、`overhead`（畫在行人上方：串燈）、`tint`（染色：假人）、`if`（條件出現：Crestline 的檯燈）、`fallback`（美術還沒到時的暫代圖）、`unless_art`（正式圖到了就不畫暫代細節）；`<sprite>_lights.png` 晚上發光 | B1 | ✅ 已完成 |
| 26 | 水面波光 | 河面隨機散佈 `effects/water_sparkle`，各自閃爍，晚上變淡 | A8 | ✅ 已完成 |
| 27 | 區域路人服裝 | 區域資料的 `ped_outfits`；購物街多穿 Luxury Citywear | B1 | ✅ 已完成 |

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
- [ ] 有動地圖時：python3 tools/qa/map_label_check.py 通過
- [ ] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [ ] wiki 對應條目的「美術」狀態已更新
- [ ] 需要程式接線的項目已列在 PR 說明
```

## B2 本批交付狀態 · 2026-09-30

美術：B2 表格全部素材已交（另附港區平整水泥地材）。Godot 渲染預覽、前後對比及驗收記錄見 `evidence/2026-09-30_b2_harbor/README.md`。程式接線：港區仍未開放，需街區及室內資料、Rosa/Ines/Sam 排程、貨車分層與公司名、route_map 小遊戲和新地材；現有外觀/地磚渲染用原尺寸，高解析入口可由 Claude 線補。
## C10 本批交付狀態 · 2026-09-30

美術：三張章節卡、兩張事件插圖，原尺寸與 4× 均已交，附 .png.import。前後對比為現有章節卡和事件視窗使用新圖的實際 Godot 截圖，並非第 10–12 章完整遊玩驗收。資料接線由 Claude 線負責。證據：`evidence/2026-09-30_c10_chapter_cards/README.md`。

## 戶外地面美術品質更新 · 2026-10-01

美術狀態：28 個戶外地磚格重新製作，涵蓋七個已實作街區的道路、鋪面、草地、水面、木步道及老城／港區特色材質。`tiles/atlas.png` 128×96 和 `world_detail/tiles/atlas.png` 512×384，均附 import；atlas 的 43 個座標不動，15 格室內及 5 個空位像素保持原樣。原畫、提示詞、SVG 與逐格保全／接縫檢查在 `docs/art_sources/ground_materials_20261001/`。

原尺寸替換已由既有 TileMap 載入；4× atlas 仍需 Claude 保持 16×16 邏輯尺寸接入高解析投影。七街區日夜實拍和改前／改後在 `evidence/20261001_ground_materials/`。此狀態只涵蓋本批地面，其他獨立 Draft 的角色、車流與建築尚須整合驗收。
