# 01 美術方向與規格

## 風格：NEO-CIVIC PIXEL REALISM

現代、乾淨、溫暖、看得懂的都市像素畫。玩家要覺得「這是可以住進去、開公司的城市」，不是懷舊遊戲，也不是賽博龐克。

**關鍵詞**：Modern · Pixel Art · Contemporary · Clean · Premium · Warm · Readable · Urban · Business · Life Simulation

**風格目標**：`docs/reference/concept_boards/` 的概念板。產品負責人明確認可的基準是 **Board A**（深海軍藍 UI、藍色城市、溫暖室內）。

| 概念板 | 檔案 | 用在 |
|--------|------|------|
| A | `A_baseline_character_world_ui.webp` | 角色比例、UI 質感、調色盤 |
| C | `C_day_city.png` | 白天街景、街道家具、主選單 |
| D | `D_night_luxury.png` | 夜景、豪華區、濕地反光 |
| E | `E_world_map_hi.png` | 世界地圖、區域卡 |
| F | `F_city_map_hi.png` | 城市地圖、區域標籤、捷運 |
| G | `G_building_exteriors_hi.png` | 建築外觀、市政廳、銀行、公寓 |
| H | `H_building_interiors.webp` | 室內：咖啡店、共享辦公、銀行大廳、住家 |

### 禁止

- 8-bit 懷舊、SNES 奇幻、賽博龐克、紫色加密貨幣霓虹、到處都是 Bitcoin logo
- 賭場美學：金幣噴發、Jackpot、老虎機音效
- 手遊抽卡感、低成本像素濾鏡
- 背景風格不一致的 AI 感拼貼；**沒經過轉換的 AI 生圖不能當定稿 sprite**
- 真實品牌、真實商標、真人肖像

## 畫布與比例

| 項目 | 規格 |
|------|------|
| 遊戲畫布 | **640×360** 美術像素，放大到 1280×720（2×）或 1920×1080（3×） |
| 縮放 | 最近鄰（nearest-neighbour），不做平滑 |
| 環境格子 | **16×16** 像素一格 |
| 角色 | **32×48** 一格動畫影格，頭身比略誇張但接地氣（約 3.5 頭身） |
| 室內 | 每格 16 px，**最上面 3 格是牆**，往下是可走的地板 |
| 街道 | 一條街約 48 格高，路面在 y≈424–478（兩條車道），人行道在建築門前 |

## 透視與光線

- **建築外觀**：正面平視加一點俯角。**側牆畫在右邊**，屋頂露出上緣（見 `buildings/nexus_bank.png`）。`front_w` 是正面寬，`depth` 是右側牆寬。
- **室內家具**：3/4 俯視，看得到桌面和正面。
- **角色**：正面、側面、背面三個方向；左邊由側面翻轉而來。
- **光源**：左上方。右側牆和物體右半邊較暗；影子往右下，用 `effects/shadow.png` 疊在腳下，不要畫進 sprite。
- **輪廓**：環境物件的外緣用比本色深 2 階的顏色，不要用純黑。角色的 1 px 深色外框由 shader（`shaders/char_outline.gdshader`）加上，**角色圖層不要自己畫外框**。
- **邊緣**：不要半透明光暈；alpha 只有 0 或 255。只有 `effects/` 裡的光暈是半透明。

## 調色盤

### UI 與程式用色（`autoload/art.gd`）

| Token | 色碼 | 用途 |
|-------|------|------|
| `C_NAVY_900` | `#0D1B2B` | 最深背景、面板底 |
| `C_NAVY_800` | `#121F31` | 面板 |
| `C_NAVY_700` | `#1B273F` | 面板亮面 |
| `C_NAVY_600` | `#263858` | 分隔、頭像底 |
| `C_NAVY_500` | `#32415E` | 邊框 |
| `C_BLUE` | `#4D8AD6` | 主要強調、連結 |
| `C_BLUE_DARK` | `#346AB0` | 按鈕 |
| `C_SKY` | `#B2D6F2` | 次要文字、提示 |
| `C_WHITE` | `#F4F6FA` | 主要文字 |
| `C_MUTED` | `#A0AAC0` | 說明文字 |
| `C_DIM` | `#6E7A94` | 標籤、停用 |
| `C_GREEN` | `#6FCF80` | **正向現金流**、完成 |
| `C_RED` | `#EA705C` | **風險、虧損**、警告 |
| `C_GOLD` | `#E2B452` | **高級、目標**、玩家名字 |
| `C_PURPLE` | `#AA82D6` | **奢華、特殊**（少用） |

顏色有意義：綠色代表賺錢，紅色代表風險，金色代表目標或高級，紫色代表奢華。美術不要拿這四個顏色當裝飾色大面積使用，免得和介面語意打架。

### 概念板取樣錨點（Board A 右下角色條）

Off-white `#FCFEFF` · Navy `#1B273F` / `#32415E` · Coral Red `#E06853` · Deep Teal `#344C56` · Forest `#3E5C57` ·
Warm Taupe `#94817C` · Leaf Green `#8FA663` · Slate `#334459` · Lavender Gray `#A8ADC7` · Slate Blue `#848EA6`

### 角色染色（`data/character/options.json`）

角色的皮膚、頭髮、眼睛圖層是**灰階**，遊戲執行時再乘上下表顏色。所以這些圖層要畫成灰階明暗（亮部接近白），不要上色。

| 皮膚 | 色碼 | 髮色 | 色碼 | 瞳色 | 色碼 |
|------|------|------|------|------|------|
| s1 Porcelain | `#FFE4D0` | black | `#2A2224` | brown | `#7A5034` |
| s2 Light | `#F8D0B0` | dark_brown | `#4A3326` | dark | `#4A3428` |
| s3 Warm | `#EAB890` | brown | `#7A5236` | hazel | `#8A7A40` |
| s4 Tan | `#CC9468` | auburn | `#9A4630` | green | `#5A9A5A` |
| s5 Brown | `#A26C4A` | blonde | `#E0BC74` | blue | `#4A78B0` |
| s6 Deep | `#744A34` | silver | `#C4C2CC` | gray | `#8890A0` |
| | | navy（染） | `#3C4C80` | | |
| | | rose（染） | `#D08898` | | |

### 區域主色（`data/city/aurelia.json` 的 `board.accent`）

| 區域 | 主色 | 區域 | 主色 |
|------|------|------|------|
| Riverside | `#5EC46A` 綠 | Shopping Street | `#E2649A` 玫瑰 |
| Startup Hub | `#F08A3C` 橘 | Harbor | `#4A8CE8` 藍 |
| Civic Center | `#4A8CE8` 藍 | Residential | `#5EC46A` 綠 |
| Financial | `#4A8CE8` 藍 | Luxury Heights | `#B46BE0` 紫 |
| Old Town | `#D8A24A` 琥珀 | University | `#4AB8C8` 青 |
| Airport | `#4A8CE8` 藍 | Industrial | `#8A93A6` 灰 |

## 日夜

時間是連續的。畫面上的日夜由三件事組成：

1. **整體色調**：`CanvasModulate` 依時間漸變，由程式處理（白天 → 黃昏琥珀 → 夜晚靛藍）。
2. **建築夜燈**：每棟建築有一張 `<id>_lights.png`，和本體同尺寸，只畫亮起的窗、招牌、門燈，其他地方透明。晚上會疊加上去。
3. **室內窗景**：`window_day` / `window_night` 和 `window_wide_day` / `window_wide_night` 會依時間切換。

| 時段 | 感覺 | 顏色 |
|------|------|------|
| 白天 | 晴朗、乾淨、綠意、熱鬧、現代 | 天藍、白、海軍藍、綠、暖米色；不要霓虹 |
| 夜晚 | 更高級、更有電影感 | 海軍藍、靛藍、暖琥珀、淡紫；窗戶暖光、路燈、濕地反光 |

## 文字不畫進圖裡

招牌、NPC 名字、提示、地圖標籤、價格都由程式畫，這樣才能翻譯、才會清楚。

- 建築招牌畫在 `buildings_meta.json` 的 `sign` 區塊，那一區**留空白招牌底**就好。
- 地圖的區域名稱畫在 `aurelia.json` 的 `board.label` 區塊，底圖那一格留空。
- 如果圖案一定要有字（例如咖啡店菜單板），字高至少 5 px、行距至少 1 px。舊菜單板字擠在一起，玩家回報成「亂碼」。
- 裝飾性的字（海報、標語）用無意義的線條或符號代替，**不要寫英文或中文**，因為翻不了。

## 交圖流程

1. **不改檔名、不改資料夾**。新東西用新檔名。
2. **尺寸變了要改 metadata**：
   - 建築：`game/assets/buildings/buildings_meta.json`（`size`、`front_w`、`depth`、`door`、`sign`、`sign_text`）。改完跑 `python3 tools/gen_districts.py`。
   - 家具、街道物件比地面佔位大的：`game/assets/sprite_meta.json`（`dw`、`dh`、`left`）。
   - 地磚：`game/assets/tiles/atlas.json`（名稱 → 格子座標）。
3. **不要跑產生器蓋掉定稿**。`tools/art/gen_placeholders.py` 會覆寫 `game/assets/`。Codex 這一輪的說明寫在 `evidence/visual_art_pass_2026_09_28/README.md`：背景圖要用 `tools/art/finalize_backdrops.py` 重建。
4. 換圖後依序跑：
   ```bash
   godot --headless --path game --import
   godot --headless --path game res://tests/test_runner.tscn        # 單元測試，要全部通過
   godot --path game -- --bot=shots --out=/tmp/shots                 # 每個街區和室內的截圖巡禮
   ```
5. 截圖放進 `evidence/<日期>/`，附 README 說明改了什麼。
6. 在 `docs/ART_ASSET_MANIFEST.md` 記一筆，並把這份 wiki 對應條目的美術狀態改掉。

## 品質驗收（每張圖都要過）

- [ ] 在 1×（640×360）看得懂：髮型、外套、鞋、包、表情看得出差別
- [ ] 同一類物件的光源、外框顏色、飽和度一致
- [ ] 沒有半透明邊、沒有 JPEG 雜點、沒有抗鋸齒糊邊
- [ ] 沒有畫進去的字（除非有註明例外）
- [ ] 日夜兩種光線下都好看（有燈光疊圖的要一起交）
- [ ] 檔名、尺寸和這份 wiki 一致；尺寸變了的話 metadata 也要改
