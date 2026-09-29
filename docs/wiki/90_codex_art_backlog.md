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
| **B3** | 老城 | 5 棟可進入建築和 3 棟填充建築；石板地磚；壁畫、鑄鐵路燈；老城天際線；老城套房和 Okafor 租屋行室內；Mr. Okafor | [03](03_districts.md#old-town-老城區--old_town--p1) |
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

**請依這個順序**：**R8 → B1 續**。之後開始 B2（港區）。

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

## 程式接線清單

以下是**光交圖不夠**、需要改程式才會出現在遊戲裡的項目。Claude 線負責。✅ 表示已接好：檔案放進去就會出現。

| # | 項目 | 程式改動 | 對應美術 | 狀態 |
|---|------|---------|---------|------|
| 1 | 頭像眼鏡 | `Art.portrait_layers` 讀 `portraits/acc_<配件>` | A5 | ✅ 已接好 |
| 2 | 專屬 NPC 圖 | 有 `characters/npc_<id>`、`portraits/npc_<id>` 時取代分層組合 | B10 | ✅ 已接好 |
| 3 | 更多表情 | 表情長條從 4 格改成 10 格，對話資料加表情標記 | 表情 P1 | 規劃中 |
| 4 | 角色姿勢 | `CharacterRig.set_pose()`：sit、idle、phone、interact、carry；NPC、員工、客人、玩家手機都已套用 | B8 / R3 | ✅ 已接好 |
| 5 | 新服裝和配件 | `options.json` → `outfits_shop`、`Wardrobe`、Threadline 購買和試衣間；美術到前用 `stand_in` 暫代；配件有 `acc_<id>` 就畫 | B1 | ✅ 服裝已接好；配件的選項和販售規劃中 |
| 6 | 新區域 | 區域和建築資料、`gen_districts.py` 排版、捷運站開放 | B1–B6 | ✅ 購物街；其他區規劃中 |
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
