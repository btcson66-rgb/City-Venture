# 10 介面與圖示

2026-09-29：`panel`、`panel_glass`、`button`、`button_hover`、`button_primary`、`button_primary_hover`、`card` 已更新為低飽和深藍框架與城市藍主操作。保留原有尺寸及 9-slice 邊距，綠色仍用於現金流／成功圖示。重建由 `python tools/art/renewal_pack.py` 選擇性輸出這 7 張，不會覆蓋其他 UI。

## 介面風格

- **深海軍藍的面板、白字、藍色強調**（Board A「Game UI sample」）。
- 顏色有意義：綠色是賺錢，紅色是風險，金色是目標或高級，紫色是奢華。色碼見 [01 美術方向](01_art_direction.md)。
- HUD 只放必要的：時間日期、現金、目前目標、小地圖、互動提示。
- 字型：標題 Pixelify Sans，內文 Inter，中文 Noto Sans TC / SC（子集）。字型在 `game/assets/fonts/`，都是 OFL 授權。**換字型是程式的事**，美術不用畫字。

## 9-slice 面板與按鈕（`game/assets/ui/`）

9-slice 的意思是：四個角保持原樣，四條邊和中間拉伸。邊界寬度（margin）寫在 `scripts/ui/uik.gd` 的 `tex_box`。

| 檔案 | 尺寸 | 邊界 | 用在 | 美術 |
|------|------|------|------|------|
| `panel` | 24×24 | 6 | 所有視窗和面板 | CODEX |
| `panel_glass` | 24×24 | 6 | 半透明面板（HUD 各區塊、捏臉預覽、地點卡） | CODEX |
| `card` | 16×16 | 6 | 清單卡片（工作、商品、員工） | CODEX |
| `card_gold` | 16×16 | 6 | 重點卡片（目前目標、玩家自己的東西） | CODEX |
| `button` | 16×16 | 4 | 一般按鈕 | CODEX |
| `button_hover` | 16×16 | 4 | 滑過 | CODEX |
| `button_pressed` | 16×16 | 4 | 按下 | CODEX |
| `button_disabled` | 16×16 | 4 | 不能按 | CODEX |
| `button_primary` | 16×16 | 4 | 主要動作（藍） | CODEX |
| `button_primary_hover` | 16×16 | 4 | 主要動作滑過 | CODEX |
| `button_danger` | 16×16 | 4 | 危險動作（關閉公司、解雇） | CODEX |
| `tab` / `tab_active` | 16×16 | 4 | 分頁 | CODEX |
| `field` | 16×16 | 4 | 輸入框（名字、公司名、價格） | CODEX |
| `tooltip` | 16×16 | 4 | 提示框 | CODEX |
| `bar_bg` / `bar_fill` | 8×8 | 2 | 進度條（開發進度、士氣） | CODEX |
| `bar_fill_green` | 8×8 | 2 | 綠色進度條（保留，程式目前沒用到） | CODEX |
| `header` / `inset` | 16×16 | — | 保留，程式目前沒用到 | CODEX |

## 其他 UI 圖

| 檔案 | 尺寸 | 用在 | 美術 |
|------|------|------|------|
| `phone_frame` | 150×250 | 手機外框（按 Tab 打開） | CODEX |
| `portrait_frame` | 72×72 | 頭像外框（保留，程式目前用程式畫的框） | CODEX |
| `prompt_key` | 12×12 | 互動提示的按鍵帽（「E」字由程式畫） | CODEX |
| `icons_atlas` | 128×96 | 圖示總表（保留，程式讀的是 `icons/` 的單張） | GEN |
| `app_icon` | 256×256 | 遊戲視窗和執行檔圖示 | GEN · `重繪` |
| `app_icon_1024` | 1024×1024 | 商店頁面、App Store | GEN · `重繪` |

## 圖示（`game/assets/ui/icons/`，43 個，16×16）

程式用 `Art.icon("<名稱>")` 讀取。風格：**2 px 粗線條、圓角、單色為主加一個強調色**，在深藍底上要清楚。全部 CODEX / GEN，定稿時統一重繪。

| 圖示 | 意思 | 圖示 | 意思 | 圖示 | 意思 |
|------|------|------|------|------|------|
| `arrow_right` | 下一步、前往 | `home` | 家、住宅 | `river` | Riverside 區 |
| `bank` | 銀行、貸款 | `info` | 資訊（預設頭像） | `save` | 存檔 |
| `calendar` | 日期、人生時間線 | `inventory` | 庫存 | `settings` | 設定 |
| `cash` | 現金、收入 | `laptop` | 筆電、Company OS | `shirt` | 換衣服、衣櫃 |
| `check` | 完成 | `lock` | 鎖住、未開放 | `shop` | 商店、購物街 |
| `civic` | 市政廳、法規 | `mail` | 訊息 | `sleep` | 睡覺 |
| `clock` | 時間 | `map` | 城市地圖 | `star` | 次要目標、評價 |
| `close` | 關閉 | `metro` | 捷運 | `startup` | Startup Hub 區 |
| `coffee` | 咖啡店 | `minus` | 減少 | `sun` | 白天 |
| `company` | 公司 | `moon` | 夜晚 | `tasks` | 任務、Business Board |
| `contracts` | 合約 | `objective` | 主線目標 | `walk` | 走路 |
| `dollar` | 價格 | `orders` | 訂單、ShopLane | `warning` | 警告、風險 |
| `finance` | 財務報表 | `parcel` | 包裹、出貨 | `world` | 世界地圖 |
| `financial` | 金融區 | `people` | 人、員工、客人 | | |
| `phone` | 手機 | `plus` | 增加 | | |

### 規劃新增的圖示（16×16）

| 圖示 | 意思 | 給哪個系統 | 優先 |
|------|------|-----------|------|
| `truck` | 物流、送貨 | 物流業、出貨 | P1 |
| `warehouse` | 倉庫 | Pier 7 | P1 |
| `car` | 自己的車 | 車輛系統 | P1 |
| `hanger` | 服飾店 | Threadline | P1 |
| `code` | 開發 | SaaS | P1 |
| `server` | 伺服器成本 | SaaS | P1 |
| `headset` | 客服 | 員工 | P1 |
| `megaphone` | 行銷、廣告 | 員工、廣告 | P1 |
| `chart_up` / `chart_down` | 成長、衰退 | 報表、新聞 | P1 |
| `receipt` | 發票 | 顧問案 | P1 |
| `percent` | 利率 | 貸款 | P1 |
| `credit` | 信用分數 | 銀行 | P1 |
| `handshake` | 談判、B2B | 合約談判 | P1 |
| `graduation` | 大學、人才 | University | P1 |
| `gym` | 健身 | Harbor Point | P1 |
| `palette` | 藝術、收藏 | Gallery Nine、裝潢 | P1 |
| `ship` | 海運 | 世界地圖 | P2 |
| `plane` | 航班 | 機場、世界地圖 | P2 |
| `passport` | 出國 | 機場 | P2 |
| `customs` | 報關 | 海關 | P2 |
| `fx` | 匯率 | 海外 | P2 |
| `rail` | 結算方式 | 第 9–10 章（**中性圖形，不能用 Bitcoin 或任何真實加密貨幣的標誌**） | P2 |
| `factory` | 製造 | 工業區 | P3 |
| `energy` | 能源 | 綠色轉型 | P3 |
| `hotel` | 飯店 | 飯店業 | P3 |
| `media` | 媒體 | 媒體業 | P3 |
| `trophy` | 里程碑 | 人生回顧 | P3 |

## 手機

按 Tab 打開。外框 `phone_frame`（150×250）。主畫面是 3×3 的 App 格子，每格 40×40，上面放圖示、下面放名字：

| App | 圖示 | 內容 |
|-----|------|------|
| Messages | `mail` | 訊息（未讀數字由程式畫） |
| Bank | `bank` | 帳戶、貸款 |
| Tasks | `tasks` | 主線和支線目標 |
| City | `map` | 城市地圖 |
| ShopLane | `orders` | 網店後台 |
| Timeline | `calendar` | 人生時間線 |
| World | `world` | 世界地圖 |
| Save | `save` | 存檔 |
| Close | `close` | 關閉 |

**規劃（P1）**：每個 App 有自己的彩色 App 圖示 `ui/apps/<app>.png`（24×24，圓角方形，像真的手機）。`需接線`

## Company OS

在筆電或辦公桌上打開的公司作業系統。分頁：Overview、Finance、Sales、Operations、Inventory、People、Contracts，還有 Freelance、SaaS。目前完全用 9-slice 和圖示組成。

**規劃（P1）**：

- 視窗外框做成「筆電螢幕」：`ui/os_frame.png`（9-slice，上緣有一條 OS 標題列）。`需接線`
- 每個分頁一個 16×16 圖示，沿用上表。
- 桌面背景：玩家公司的顏色（程式染）加低調的格線圖案 `ui/os_wallpaper.png`（64×64，可平鋪）。

## 其他 HUD 元素

| 元素 | 現在 | 規劃 |
|------|------|------|
| 小地圖 | 程式依街區資料畫 | 外框 `ui/minimap_frame.png`（9-slice） |
| 目標引導箭頭 | 程式畫的金色箭頭 | `effects/guide_arrow.png` 16×16，4 格脈動動畫 |
| 出口標記 | 程式畫的「EXIT」脈動框 | 維持（文字要能翻譯） |
| 對話框 | 9-slice `panel` 加頭像 | 維持 |
| 通知（toast） | 9-slice 加圖示 | 維持 |

## 美術品質更新 · 2026-10-01

43 圖示的SVG語意延續既有A7，並補直接輸出的4×。23表面／外框整理為統一海軍藍漸層與城市藍操作色；危險、停用、滑過、按下、選中狀態分開。sleep改成床，圖檔不寫字。原尺寸與atlas格位不變，已由既有renderer自動替換；高解析UI載入和9-slice的physical／logical邊界由Claude接線。美術來源與21實機狀態、全巡禮證據見ui_quality_20261001。


### Device settings (#87)

The title and pause menus open five settings pages (audio, display, controls, accessibility and game). UI scaling
and extra-large text use scrollable panels. Color assistance retains textual labels and signed money; toggles show
✓/✗ and the next available action. Settings remain outside company saves. See [settings](../SETTINGS.md).

## Touch and controllers (#88)

Ground taps follow walkable routes; nearby objects show a touch interaction button. Buttons are at least 44 logical pixels. D-pad focuses the next action first; enlarged lists scroll to keep controls reachable. Portrait devices request landscape. See [input support](../INPUT_ACCESS.md) and the explicit device validation limits there.

## Replay setup and cards (#89)

New Game offers Easy/Standard/Hard/Custom rules, a seed and story/sandbox selection, then character creation. Scenario cards show objective, current/required quantities, deadline and a single next action. The six openings are `inherited_cafe`, `fresh_restart`, `venture_fund`, `harbor_cargo`, `family_property`, `part_time_start`. Weekly challenges use fixed standard rules; local history has no online ranking. See [replay rules](../REPLAY.md). Maple Court is a financial scenario asset; a physical property scene remains planned outside this ticket.


### Market and City news (#90)

The Company OS Market tab (`MarketView`) shows seeded cycle/base rate/inflation and normalized shares, rivals and bounded daily headlines. Its navigation scrolls to preserve minimum button targets. The phone City news app shows 1–3 items per day. Poaching offers have salary-match and departure choices and expire after three days. `macro_cycle` and `market_competition` explanation badges and `os_market`/`poach` help cards explain the costs.

Rival data IDs: `automotive_1`, `automotive_2`, `cafe_1`, `cafe_2`, `consulting_1`, `consulting_2`, `ecommerce_1`, `ecommerce_2`, `energy_1`, `energy_2`, `hotel_1`, `hotel_2`, `international_trade_1`, `international_trade_2`, `logistics_1`, `logistics_2`, `manufacturing_1`, `manufacturing_2`, `media_1`, `media_2`, `real_estate_1`, `real_estate_2`, `saas_1`, `saas_2`. These cover declared industries; the old PR target does not make every industry playable.
