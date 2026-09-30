# 09 交通工具

## 車輛的圖層規格

每台車每個方向有兩張同尺寸的圖：

| 圖層 | 檔名 | 內容 | 染色 |
|------|------|------|------|
| 車身 | `vehicles/<type>_<dir>_body.png` | 車殼（灰階） | **程式隨機染色** |
| 細節 | `vehicles/<type>_<dir>_detail.png` | 玻璃、輪胎、車燈、保險桿、後照鏡 | 不染 |

方向：`side`（向右，向左時翻轉）、`front`（朝下開）、`back`（朝上開）。

### 程式怎麼用（`scripts/world/car.gd`）

- 街上的車只開**側面**，兩條車道分別往左、往右，遇到行人會煞車。
- 車種抽選比例：sedan ×2、compact ×2、taxi、van、bus。
- 一般車的車身色從 8 色裡挑：白、深灰、紅、藍、銀、黑、香檳、墨綠。計程車固定黃色 `#F0C446`，公車固定白色，貨車是白色或橘色。
- `front` / `back` 圖目前**沒有被用到**，保留給 P1 的停車場和玩家座駕。

## 現有車輛

| 車種 | 方向與尺寸 | 用在 | 美術 | 視覺設定 |
|------|-----------|------|------|----------|
| `sedan` 轎車 | side 64×28 · front 32×40 · back 32×40 | 街上車流 | GEN · `重繪` | Board A「Modern Sedan」：低矮、流線、四門 |
| `compact` 小型車 | side 52×26 · front 30×36 · back 30×36 | 街上車流 | GEN · `重繪` | 圓潤的兩廂車 |
| `taxi` 計程車 | side 64×28 | 街上車流 | GEN · `重繪` | 轎車加車頂燈箱（燈箱不寫字） |
| `van` 貨車 | side 72×36 | 街上車流 | GEN · `重繪` | 廂型貨車，側面空白（可以貼公司色帶） |
| `bus` 公車 | side 112×44 | 街上車流 | GEN · `重繪` | 低底盤市區公車，大窗看得到乘客剪影 |
| `metro_train` 捷運列車 | 124×40（單張，不分圖層） | 開場抵達動畫 | GEN · `重繪` | 銀色車身加 M1 紅色腰帶，車窗亮燈 |

現有檔案（19 張）：`bus_side_body` / `bus_side_detail` · `compact_back_body` / `compact_back_detail` · `compact_front_body` / `compact_front_detail` · `compact_side_body` / `compact_side_detail` · `sedan_back_body` / `sedan_back_detail` · `sedan_front_body` / `sedan_front_detail` · `sedan_side_body` / `sedan_side_detail` · `taxi_side_body` / `taxi_side_detail` · `van_side_body` / `van_side_detail` · `metro_train`

---

## 規劃中的車輛

### 玩家座駕（P1，企劃書 §34）

**車不只是收藏**：有車之後，城市裡移動的時間會變短，但要付油錢、停車費、保險。

| 車種 id | 階級 | 視覺設定 | 需要的方向 |
|---------|------|----------|-----------|
| `compact`（沿用） | Used Compact 二手小車 | 現有小型車加一點舊化：保險桿刮痕、輪框不一樣 → 用 `compact_used_detail` 細節圖 | side、front、back |
| `sedan`（沿用） | Sedan 轎車 | 現有轎車 | side、front、back |
| `suv` | SUV | 高底盤、方正 | side 68×34、front 34×44、back 34×44 |
| `sports` | Sports Car 跑車 | 很低、很寬、雙門 | side 68×24、front 34×32、back 34×32 |
| `luxury` | Luxury Car 豪華車 | 加長、鍍鉻水箱罩（Board D） | side 76×28、front 34×42、back 34×42 |

每台玩家座駕還需要：

- `<type>_parked.png`：停在路邊的 3/4 視角（大約 64×36），給 Crown Motors 展示轉盤和住家車庫用
- 目錄縮圖 `cards/car_<type>.png`（192×108），給購車畫面用

### 物流車輛（P1–P3）

**玩家的第一台貨車已實作（2026-09-30）**：港區 Dockside Motors 的 Sam Okoro 賣一台二手廂型貨車 **$9,800**（從公司帳戶付，記 `exp:vehicle`），保險每月 **$165**（`exp:insurance`），油耗每 100 公里 14 公升、每公里油資約 $0.29（`exp:fuel`），一趟載 40 件包裹。玩法見 `13_core_loop_and_work.md`。目前貨車**還不會出現在街上或停車場**，只出現在購買畫面（`VanDealModal` 用街上的 `van_side_body` + `van_side_detail` 暫代；`van_player_side_*` 交件後畫面自動換圖）。詳細美術規格在 `90_codex_art_backlog.md` B2。

| 車種 id | 用途 | 尺寸建議 | 備註 |
|---------|------|---------|------|
| `van_owned` | 物流業起點：「一台二手貨車」（已實作為 `van_player_side_body` / `_detail`，美術待交） | side 72×36 | 側面有程式畫的公司名 |
| `box_truck` | 物流擴張 | side 96×44 | |
| `container_truck` | 港區車流 | side 128×48 | 車斗上的貨櫃用 `container_*` 顏色 |
| `forklift` | 港區、倉庫 | side 40×36 | 也當靜態物件 |
| `delivery_scooter` | 外送（咖啡店業） | side 32×28 | |

### 大眾運輸（P1）

| id | 用途 | 規格 |
|----|------|------|
| `metro_train_m1`–`m5` | 月台畫面的列車，每條線一個腰帶色（紅、藍、綠、金、紫） | 124×40，或 body 灰階加程式染腰帶 |
| `metro_interior` | 搭車過場：車廂內部 | 640×360 背景 |
| `tram` | 老城路面電車（選配） | side 128×44 |

### 飛機與船（P2–P3）

| id | 用途 | 規格 |
|----|------|------|
| `plane_icon` | 世界地圖上沿航線飛 | 16×16，8 個方向 |
| `ship_icon` | 世界地圖上沿海運線走 | 16×16，8 個方向 |
| `airliner` | 機場停機坪背景 | 160×60 |
| `cargo_ship` | 港區背景的貨輪 | 320×80（剪影加燈） |
| `private_jet` | 私人飛機（P3，改變出國時間，要付真實成本） | 112×40 |
| `yacht` | Luxury Heights 碼頭（選配） | 96×40 |

### 腳踏車與其他

- `props/bike` 是停著的腳踏車，已有。
- 規劃：騎腳踏車的路人（大學區），需要**騎車姿勢**的角色圖層，優先度低。
