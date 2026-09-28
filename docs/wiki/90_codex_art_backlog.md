# 90 Codex 美術工單

這一頁是**給 Codex（或任何接手美術的人）的施工單**：先做什麼、後做什麼、每一批交哪些檔案、怎樣算做完。

規格細節在前面各頁，這裡只列工作項目和驗收標準。

## 目前畫面的狀態（2026-09-28）

Codex 第一輪（`codex/visual-art-pass-01`，已合併）的效果，在同一條截圖路線上比對過：

| 區域 | 變化 | 結論 |
|------|------|------|
| 主選單背景 `menu` | 重畫：街景更乾淨，旗幟改用符號 | ✅ 明顯變好 |
| 抵達背景 `arrival` | 重畫：河岸天際線、橋、倒影 | ✅ 明顯變好 |
| 角色走路圖、頭像 | 細部修整：衣褶、縫線、陰影 | ⚠️ 遊戲裡 1× 幾乎看不出差別 |
| UI 面板和按鈕 | 小幅修整 | ⚠️ 小幅進步 |
| 街景、建築、室內、地圖 | 沒動（仍是 v3 從概念板轉換的版本） | ❌ 下一輪的重點 |

**結論**：背景圖已經到位。玩家實際花最多時間看的是**角色、室內和街道**，這三塊還是轉換品質。第二輪的重心要放在那裡。

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

- [ ] 在 640×360 原尺寸下，8 種髮型的**剪影**各不相同（把角色填成單色也分得出來）
- [ ] 3 種體型在 1× 分得出來（肩寬、腰線、髮量）
- [ ] 9 套服裝在 1× 分得出來：咖啡師的圍裙、快遞的腰包、西裝的領口、市政職員的名牌
- [ ] 走路 4 格有明顯的腳步起落和手臂擺動；側面走路不會「滑步」
- [ ] 12 位具名 NPC（外型見 [07](07_characters.md#具名-npc已實作-12-位)）站在一起時，每個人都認得出來。特別是 Maya 和 Elena
- [ ] 所有圖層在每一格都對齊（用 `tools/art/preview_chars.py` 組合檢查）

### A2 室內家具與地板

**為什麼**：玩家大部分時間在室內（家、咖啡店、共享辦公、2B）。

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
| **B10** | 專屬 NPC | `characters/npc_<id>.png` 和 `portraits/npc_<id>.png`：Maya、Marcus、Daniel、Elena、Priya、Jun | [07](07_characters.md#專屬-npc-美術規劃--需接線) |

每一批的驗收標準和 A 批一樣，另外還要：

- [ ] 新區域的所有建築、物件、地磚都放在同一張對比截圖裡，確認風格一致
- [ ] 新服裝在 3 種體型下都要截圖（正面、側面、背面）

## C 批：之後（P2–P3）

機場、工業區、豪宅區、車輛階梯（SUV、跑車、豪華車）、飛機和貨輪、事件插圖、文件插圖、章節標題卡 7–12、收藏品、住宅第 3–5 階和辦公第 3–4 階的家具組。規格都在前面各頁，等 B 批完成後再排。

---

## 程式接線清單

以下是**光交圖不夠**、需要改程式才會出現在遊戲裡的項目。Claude 線負責，狀態全部是「規劃中」。Codex 交了圖之後，在 PR 說明裡列出對應的項目即可。

| # | 項目 | 需要的程式改動 | 對應美術 |
|---|------|---------------|---------|
| 1 | 頭像眼鏡 | `Art.portrait_layers` 加配件層 | A5 |
| 2 | 專屬 NPC 圖 | 有 `npc_<id>.png` 時取代分層組合 | B10 |
| 3 | 更多表情 | 表情長條從 4 格改成 10 格，對話資料加表情標記 | 表情 P1 |
| 4 | 角色姿勢 | `CharacterRig` 支援 sit、carry、phone、interact、idle | B8 |
| 5 | 新服裝和配件 | `options.json` 加選項，衣櫃和 Threadline 購買流程 | B1 |
| 6 | 新區域 | 區域和建築資料、`gen_districts.py` 排版、捷運站開放 | B2–B6 |
| 7 | 黃昏天際線 | 街區天空改成三段交叉 | B7 |
| 8 | 章節標題卡 | 章節開始時顯示全螢幕插圖 | B7 |
| 9 | 公司結束畫面 | 破產流程的最後一步顯示插圖 | B7 |
| 10 | 公司標誌 | 手機訊息、合約、供應商清單改用 `logos/` | B9 |
| 11 | SaaS logo | Company OS SaaS 分頁 | B9 |
| 12 | 商品照 | 上架頁顯示；Studio Lumen 拍照前後切換 | B9 |
| 13 | 事件插圖 | 決策視窗加插圖欄位 | C |
| 14 | 文件插圖 | 登記、租約、合約、貸款完成時顯示 | C |
| 15 | 手機 App 圖示、Company OS 外框 | `phone_ui.gd`、`company_os.gd` 換皮 | A7 之後 |
| 16 | 目標引導箭頭 | tutorial 改用 `effects/guide_arrow` | A8 |
| 17 | 天氣 | 下雨系統：雨、水窪反光、雨聲 | P1 特效 |
| 18 | Elena 外型 | 改 `data/npcs/elena.json`，拉開和 Maya 的差異 | A1 |

## 交件檢查表（每個 PR 都貼一份）

```
- [ ] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [ ] 沒有改舊檔名；新檔名照 wiki 命名規則
- [ ] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json
- [ ] godot --import 無錯誤
- [ ] 單元測試全部通過（貼最後一行）
- [ ] --bot=shots 截圖巡禮 0 失敗
- [ ] python3 tools/wiki_check.py 通過
- [ ] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [ ] wiki 對應條目的「美術」狀態已更新
- [ ] 需要程式接線的項目已列在 PR 說明
```
