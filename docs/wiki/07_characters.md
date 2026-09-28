# 07 角色

## 角色系統怎麼組成

所有角色，包括主角、NPC、員工和路人，都是**同一套分層骨架**組出來的：把十幾張透明圖層疊在一起，再個別染色。所以一張「短髮」圖就能變成 8 種髮色，一套「西裝」可以給 3 種體型穿。

### 走路圖（`game/assets/characters/`）

- 每一個圖層是一張 **128×144** 的圖，切成 **32×48** 的格子：**4 個走路影格 × 3 列方向**。
  ```
  列 0：朝下（正面）   [影格0][影格1][影格2][影格3]
  列 1：朝側（向右）   [影格0][影格1][影格2][影格3]   ← 向左由程式水平翻轉
  列 2：朝上（背面）   [影格0][影格1][影格2][影格3]
  ```
- 原點在**腳底中央**。同一格的所有圖層必須完全對齊。
- 1 px 深色外框由 shader 加（`shaders/char_outline.gdshader`），**圖層不要自己畫外框**。
- 圖層由下到上的順序（`autoload/art.gd` → `character_layers`）：

| 順序 | 圖層 | 檔名 | 染色 |
|------|------|------|------|
| 1 | 後髮 | `hair_<style>_back` | 髮色 |
| 2 | 身體 | `body_<presentation>_<face>` | 膚色 |
| 3 | 褲裙 | `outfit_<outfit>_<presentation>_bottom` | NPC 可指定色（`outfit_tints.bottom`） |
| 4 | 鞋 | `outfit_<outfit>_<presentation>_shoes` | 不染 |
| 5 | 上衣 | `outfit_<outfit>_<presentation>_top` | NPC 可指定色（`outfit_tints.top`） |
| 6 | 眼白 | `eyes_<shape>` | 不染 |
| 7 | 虹膜 | `iris_<shape>` | 瞳色 |
| 8 | 眉毛 | `brows_<style>` | 髮色 |
| 9 | 嘴 | `mouth_<style>` | 不染 |
| 10 | 前髮 | `hair_<style>_front` | 髮色 |
| 11 | 配件 | `acc_<accessory>` | 不染 |

**要染色的圖層畫成灰階**（亮部接近白），顏色由程式乘上去。不染色的圖層（鞋、眼白、嘴、配件）直接畫全彩。

### 對話頭像（`game/assets/portraits/`）

- 單張圖層 64×64；**表情圖層是 256×64 的長條，4 格 64×64**，依序為：
  `neutral` 平靜 · `happy` 開心 · `thinking` 思考 · `surprised` 驚訝。
- 圖層順序（`portrait_layers`）：後髮 → 頭 `head_<face>` → 衣領 `outfit_<outfit>` → 眼白 → 虹膜 → 眉毛 → 嘴 → 前髮。
- **頭像的配件層**：程式已接好，放進 `portraits/acc_glasses_round`、`acc_glasses_square`（64×64）就會出現。目前還沒有圖，所以 Ana、Daniel、Priya 走路時戴眼鏡，對話頭像上卻沒有（等 A5）。
- **頭像衣領細節**：`portraits/outfit_<o>_detail.png`（64×64，不染色），畫在染色衣領上面，程式已接好。
- 沒有外觀的聯絡人（銀行、ShopLane、房東、客人）顯示成**圖示頭像**：深藍底加一個 16×16 圖示（`bank`、`orders`、`home`、`people`，其他用 `info`）。

### 角色卡（捏臉畫面）

捏臉畫面的背景是 `backdrops/wardrobe.png`（200×250，Board H 的更衣室），前面並排顯示正面、側面、背面三張全身圖和一張頭像。

---

## 主角：捏臉選項（`data/character/options.json`）

所有選項都**只影響外觀**。沒有職業、沒有數值差異。

| 部位 | 選項（id） | 圖層檔案 | 美術 |
|------|-----------|----------|------|
| 外型 Presentation | `masculine` 陽剛 · `feminine` 陰柔 · `neutral` 中性 | 決定 body 和 outfit 的體型版本 | A1 走路圖已更新 |
| 臉型 | `round` 圓 · `oval` 橢圓 · `square` 方 · `heart` 心形 | `body_<pres>_<face>`（12 張）· `portraits/head_<face>`（4 張） | A1 走路圖已更新；頭像 A5 待辦 |
| 髮型 | `messy` 亂髮 · `short_neat` 短俐落 · `buzz` 平頭 · `side_part` 旁分 · `bob` 鮑伯 · `long` 長髮 · `ponytail` 馬尾 · `bun` 包頭 | `hair_<style>_back/_front`（16 張，走路和頭像各一套） | A1 走路圖已更新；頭像 A5 待辦 |
| 髮色 | black · dark_brown · brown · auburn · blonde · silver · navy（染）· rose（染） | 染色，色碼見 [01 美術方向](01_art_direction.md) | — |
| 膚色 | s1 Porcelain · s2 Light · s3 Warm · s4 Tan · s5 Brown · s6 Deep | 染色 | — |
| 眼型 | `round` · `almond` 杏眼 · `narrow` 細長 · `wide` 大眼 | `eyes_<shape>` + `iris_<shape>`（走路 8 張、頭像 8 張） | A1 走路圖已檢查；頭像 A5 待辦 |
| 瞳色 | brown · dark · hazel · green · blue · gray | 染色 | — |
| 眉毛 | `straight` 平 · `arched` 挑 · `thick` 濃 · `soft` 柔 | `brows_<style>` | A1 走路圖已檢查；頭像 A5 待辦 |
| 嘴 | `smile` 微笑 · `neutral` 平 · `grin` 露齒笑 · `small` 小嘴 | `mouth_<style>` | A1 走路圖已檢查；頭像 A5 待辦 |
| 服裝 | `startup_casual` · `office_professional` · `home` | 見下方服裝表 | A1 走路圖已更新；頭像 A5 待辦 |
| 配件 | `none` · `glasses_round` 圓框眼鏡 · `glasses_square` 方框眼鏡 · `backpack` 後背包 | `acc_<id>` | A1 走路圖已檢查 |

規劃中（捏臉畫面已經寫明「之後在衣櫃和服飾店開放」）：

- 服裝：EXECUTIVE、LOGISTICS / SITE、LUXURY CITYWEAR、TRAVEL、FORMAL EVENING
- 配件分頁：帽子、包包、首飾、手錶、識別證

### 服裝

每套服裝要交 **3 種體型 × 3 件（top、bottom、shoes）= 9 張走路圖**，加 **1 張頭像衣領**（64×64）。

| id | 名稱 | 誰穿 | 視覺設定 | 狀態 |
|----|------|------|----------|------|
| `startup_casual` | Startup Casual | 主角預設、員工（打包、行銷） | 休閒西裝外套、素 T、牛仔褲、白球鞋（Board A「Default」） | 已實作 · CODEX |
| `office_professional` | Office Professional | 主角、Priya、Elena、員工（客服、工程師） | 襯衫、識別證掛繩、西褲或及膝裙、皮鞋（Board A「Office」） | 已實作 · CODEX |
| `home` | Home | 主角 | 帽 T 或居家服、棉褲、拖鞋 | 已實作 · CODEX |
| `business_suit` | 西裝 | Daniel、Marcus、Sofia、Tom、路人 | 深色套裝、領帶或絲巾 | 已實作 · CODEX |
| `barista` | 咖啡師 | Jun、Lee | 襯衫加圍裙 | 已實作 · CODEX |
| `civic_staff` | 市政職員 | Ana | 開襟衫、名牌 | 已實作 · CODEX |
| `courier` | 快遞 | Dara、Ken | Polo 衫、工作褲、腰包 | 已實作 · CODEX |
| `casual_jacket` | 休閒外套 | Maya、路人 | 短夾克（可染色） | 已實作 · CODEX |
| `casual_tee` | 休閒 T 恤 | 路人、客人 | T 恤（可染色）、休閒褲 | 已實作 · CODEX |
| `executive` | Executive 主管 | 主角（衣櫃） | 剪裁俐落的三件式、口袋巾、手錶 | 規劃中 P1 · `新增` |
| `logistics_site` | Logistics / Site 現場 | 主角、倉管、工人 | 反光背心、工作靴、安全帽（配件） | 規劃中 P1 · `新增` |
| `luxury_citywear` | Luxury Citywear 城市精品 | 主角 | 長版大衣、高領毛衣、皮靴（Board A「Casual City」高級版） | 規劃中 P1 · `新增` |
| `travel` | Travel 旅行 | 主角（出國） | 輕羽絨、斜背包、休閒鞋 | 規劃中 P2 · `新增` |
| `formal_evening` | Formal Evening 晚宴 | 主角 | 燕尾服或晚禮服 | 規劃中 P1 · `新增` |
| `student` | 學生 | 大學區路人 | 帽 T、後背包、帆布鞋 | 規劃中 P1 · `新增` |
| `athleisure` | 運動休閒 | 健身房、慢跑路人、Rosa | 運動外套、緊身褲、跑鞋 | 規劃中 P1 · `新增` |
| `chef_waiter` | 餐飲制服 | 餐廳員工 | 白色廚師服或黑背心 | 規劃中 P1 · `新增` |
| `lab_coat` | 實驗袍 | Prof. Hana Sato、研究員 | 白色實驗袍 | 規劃中 P1 · `新增` |
| `uniform_officer` | 制服 | 海關、門僮 | 海軍藍制服、帽子 | 規劃中 P2 · `新增` |

### 配件

| id | 名稱 | 狀態 | 備註 |
|----|------|------|------|
| `glasses_round` | 圓框眼鏡 | 已實作 · CODEX | 頭像缺，`需接線` |
| `glasses_square` | 方框眼鏡 | 已實作 · CODEX | 頭像缺，`需接線` |
| `backpack` | 後背包 | 已實作 · CODEX | 背面要看得到整個包 |
| `hat_cap` / `hat_beanie` / `hard_hat` | 帽子 | 規劃中 P1 | 帽子會蓋住前髮，**需要每個髮型的「戴帽」版本**，或帽子畫成遮住頭頂的形狀 |
| `bag_tote` / `bag_briefcase` / `bag_crossbody` | 包包 | 規劃中 P1 | 側面要看得出是手提或斜背 |
| `watch` / `jewelry_earrings` / `jewelry_necklace` | 手錶、首飾 | 規劃中 P1 | 32×48 裡只有 1–2 px，**主要畫在頭像上** |
| `lanyard` | 識別證 | 規劃中 P1 | |
| `headset` | 耳麥 | 規劃中 P1 | 客服員工專用 |

### 姿勢與動畫

| 動作 | 影格 | 方向 | 用在 | 狀態 |
|------|------|------|------|------|
| 走路 | 4 | 下、側、上 | 所有角色 | 已實作 |
| 站立呼吸 `idle` | 2 | 下、側、上 | 櫃台後的 NPC | 程式已接好，等美術 |
| 坐 `sit` | 2 | 下、側、上 | 員工坐辦公桌、咖啡店和共享辦公的客人、坐沙發的 NPC | 程式已接好，等美術 |
| 搬箱 `carry` | 4 | 下、側、上 | 打包出貨、倉管 | 程式已接好，等美術 |
| 講電話 `phone` | 2 | 下、側、上 | 主角打開手機時 | 程式已接好，等美術 |
| 伸手互動 `interact` | 2 | 下、側、上 | 打包桌的出貨員工 | 程式已接好，等美術 |
| 睡覺 | 1 | — | 床上 | 規劃中 P2 |

姿勢圖的格式（`scripts/world/character_rig.gd`）：

- **檔名**：每個圖層各一張 `<圖層名>_<姿勢>.png`，例如 `body_feminine_oval_sit.png`。
- **尺寸**：和走路圖同樣是 128×144 格式。
- **切換規則**：這個角色的**每一個圖層都有**該姿勢的圖，才會切換；缺一張就維持走路圖。
- **NPC 資料**：排程裡的 `pose` 欄位決定 NPC 的姿勢（預設 `idle`）。

完整規格見 [90 工單 R3](90_codex_art_backlog.md#r3-姿勢圖程式已接好b8-的正式規格)。

### 表情

| 表情 | 狀態 |
|------|------|
| Neutral 平靜 · Happy 開心 · Thinking 思考 · Surprised 驚訝 | 已實作（頭像長條的 4 格） |
| Confident 自信 · Determined 堅定 · Cheerful 愉快 · Excited 興奮 · Relaxed 放鬆 · Serious 嚴肅 | 規劃中 P1：長條加長到 10 格（640×64）· `需接線` |

---

## 具名 NPC（已實作 12 位）

外觀全部用上面的選項組出來。資料在 `game/data/npcs/<id>.json`。「定稿需求」是做專屬頭像和走路圖時的特徵重點。

| id | 名字 | 身分 | 外型 | 服裝 | 出沒 | 定稿需求（專屬特徵） |
|----|------|------|------|------|------|----------------------|
| `maya` | Maya | 主角的老朋友 | 陰柔 · 橢圓臉 · 黑色鮑伯 · s3 · 杏眼深瞳 · 挑眉 · 微笑 | `casual_jacket`（暖芥末色外套 `#C8843E`、深灰褲 `#3A3C48`） | Bloom Coffee 窗邊桌，週六日 10–16 | 開場第一個傳訊息的人，代表「生活」。溫暖、愛笑、帆布包、耳機掛脖子 |
| `jun` | Jun | Bloom Coffee 咖啡師 | 陽剛 · 方臉 · 黑短髮 · s4 · 細長眼 · 濃眉 · 平嘴 | `barista` | Bloom 櫃台，每天 7–20 | 話少但可靠。捲起袖子，手臂有咖啡漬，圍裙口袋插一支溫度計 |
| `lee` | Lee | Bean & Byte 咖啡師 | 中性 · 圓臉 · 藍染馬尾 · s2 · 圓眼灰瞳 · 柔眉 · 微笑 | `barista` | Bean & Byte 櫃台，每天 7–19 | 新創圈的八卦中心。耳朵有小耳環，圍裙上有程式碼圖案（色塊） |
| `priya` | Priya | Nexus Co-work 社群經理 | 陰柔 · 心形臉 · 深棕長髮 · s5 · 大眼 · 挑眉 · 露齒笑 · 圓框眼鏡 | `office_professional`（蜜桃色襯衫 `#F0BF96`） | Co-work 櫃台，每天 8–20 | 熱情、什麼人都認識。平板夾在手臂下，識別證繩是橘色 |
| `ken` | Ken | TradeLink 業務 | 陽剛 · 圓臉 · 黑平頭 · s3 · 圓眼 · 平眉 · 露齒笑 | `casual_jacket`（TradeLink 藍 `#3F6FB5`；原本穿 `courier`，和 Dara 撞衫） | Co-work 休息區，週二、四 10–15 | 爽朗的批發商。手上永遠拿著型錄和樣品盒 |
| `ana` | Ana | 市政廳登記員 | 陰柔 · 圓臉 · 棕色包頭 · s2 · 圓眼榛瞳 · 柔眉 · 微笑 · 方框眼鏡 | `civic_staff` | 市政廳櫃台，週一到五 9–17 | 耐心、按規矩來。筆插在包頭上，開襟衫加名牌 |
| `sofia` | Sofia | Nexus Bank 客戶經理 | 陰柔 · 橢圓臉 · 赤褐馬尾 · s2 · 杏眼綠瞳 · 挑眉 · 平嘴 | `business_suit` | 銀行櫃台，週一到五 9–16 | 專業、清楚。珍珠耳環、金色 N 字胸針 |
| `marcus` | Marcus Reed | Nexus Bank 高階主管 | 陽剛 · 方臉 · 銀色旁分 · s5 · 細長眼 · 濃眉 · 平嘴 | `business_suit` | 銀行經理桌，週一到五 13–16 | 傳統金融的代表，**不是反派**。銀髮、手錶、三件式、沉穩 |
| `tom` | Tom | 租賃仲介 | 陽剛 · 橢圓臉 · 金色短髮 · s1 · 圓眼藍瞳 · 平眉 · 微笑 | `business_suit` | 22 Founders Lane，週一到六 9–18 | 業務笑容，手上一串鑰匙，西裝有點太亮 |
| `dara` | Dara | PostPoint 店員 | 中性 · 心形臉 · 玫瑰色亂髮 · s4 · 大眼 · 柔眉 · 小嘴 | `courier` | PostPoint 櫃台，每天 8–21 | 手腳很快。耳後夾一支筆，手上掃描槍 |
| `daniel` | Daniel Wong | Crestline 採購 | 陽剛 · 橢圓臉 · 黑色旁分 · s3 · 杏眼 · 平眉 · 平嘴 · 方框眼鏡 | `business_suit` | Co-work 休息區，週四 17–20 | 第 5 章大訂單的人。精明、有禮、拿著皮革資料夾。大訂單也可能拖垮現金流 |
| `elena` | Elena Park | Northlight Capital 創投 | 陰柔 · 心形臉 · 黑色旁分 · s2 · 細長眼 · 平眉 · 小嘴 | `office_professional`（冷白外套 `#DFE6F0`、深色褲 `#2F3340`） | Co-work 休息區，週三 15–18 | 冷靜、快、條件不一定划算，玩家可以拒絕。白色西裝外套、極簡耳環 |

> 已解決（2026-09-28）：Maya 和 Elena 原本外型幾乎一樣，現在 Elena 改成心形臉、黑色旁分、細長眼、平眉，穿冷白外套；Maya 維持鮑伯頭，換成暖芥末色外套。
>
> 還沒解決：Daniel、Marcus、Sofia、Tom 都穿同一套藍西裝。要等 Codex 把西裝拆成可染色布料加細節層（[90 工單 R1](90_codex_art_backlog.md#r1-服裝拆成可染色布料不染色細節-優先)），之後再給每個人不同的西裝顏色。

### 只在手機出現的聯絡人

| id | 名稱 | 現在的頭像 | 規劃 |
|----|------|-----------|------|
| `bank` | Nexus Bank | `bank` 圖示 | 改用 Nexus 標誌（32×32）`需接線` |
| `shoplane` | ShopLane | `orders` 圖示 | 改用 ShopLane 標誌 `需接線` |
| `landlord` | Mr. Okafor（房東） | `home` 圖示 | P1 在 Old Town 現身，給他完整外型（見下方） |
| `customer` | 客人 | `people` 圖示 | 維持。每張訂單的客人由程式隨機組外型 |
| `client` | 顧問案客戶 | `info` 圖示 | 改用公司標誌 |
| `jobs_board` | Aurelia Jobs | `info` 圖示 | 改用 Aurelia Jobs 標誌 |
| `harbor_point` | Rosa · Harbor Point Fitness | `info` 圖示 | P1 在 Harbor 現身，給她完整外型 |
| `studio_lumen` | Studio Lumen | `info` 圖示 | 改用 Studio Lumen 標誌 |

---

## 員工（`data/economy/staff.json`）

員工由程式隨機產生（名字、外型全部隨機，25% 戴圓框眼鏡）。定稿不需要個別畫，但每個職位需要**辨識度**。

| 職位 id | 名稱 | 現在的服裝 | 規劃的辨識特徵 | 工作時看得到 |
|---------|------|-----------|---------------|-------------|
| `packer` | Fulfilment Assistant 出貨助理 | `startup_casual` | 改穿 `logistics_site` 輕量版（圍裙加手套） | 在 2B 的打包桌搬箱子（需要搬箱姿勢） |
| `support` | Customer Support 客服 | `office_professional` | 加 `headset` 耳麥 | 坐在辦公桌講電話 |
| `marketer` | Marketer 行銷 | `startup_casual` | 加 `bag_tote` 托特包 | 坐在辦公桌 |
| `developer` | Developer 工程師 | `office_professional` | 改穿帽 T（`student` 服裝的成人版）或加 `headset` | 坐在雙螢幕桌 |

## 路人（`scripts/world/ambient_person.gd`）

外型全部隨機，服裝從 `casual_tee`、`casual_jacket`、`business_suit`、`office_professional`、`startup_casual` 挑，上衣和褲子隨機染色。各區的密度依時段變化。

**規劃**：各區路人有傾向。金融區多西裝；大學區多 `student`；港區多 `logistics_site`；購物街多 `luxury_citywear` 和提購物袋的路人；住宅區有推嬰兒車、遛狗的人（需要新的配件或道具）。

---

## 規劃中的具名 NPC

外型先用現有選項組，等專屬美術到位後再換。

| id | 名字 | 身分 | 登場 | 外型（現有選項） | 服裝 | 視覺設定 |
|----|------|------|------|-----------------|------|----------|
| `lina` | Lina Zhao | 跨境支付新創創辦人 | 第 9–10 章（P2） | 陰柔 · 心形臉 · 黑色長髮 · s2 · 杏眼深瞳 · 平眉 · 小嘴 | `luxury_citywear` | 聰明、冷靜、講話很快。黑色高領、筆電貼紙（無 logo）、無線耳機。介紹新的結算方式，但不推銷、不炒作 |
| `omar` | Omar Haddad | 國際貿易商 | P2 | 陽剛 · 方臉 · 黑色旁分（夾灰）· s4 · 杏眼深瞳 · 濃眉 · 微笑 | `business_suit`（淺色亞麻） | 開啟海外供應鏈。短鬍子、亞麻西裝、舊皮箱，辦公室裡有茶具和世界地圖 |
| `victor` | Victor Hale | 大型企業家 | P2–P3 | 陽剛 · 方臉 · 銀色短髮 · s1 · 細長眼灰瞳 · 平眉 · 平嘴 | `executive` | 可能是客戶、對手、收購者或夥伴，**不能固定成反派**。高、瘦、訂製西裝、沒有多餘表情 |
| `rosa` | Rosa Lim | Harbor Point Fitness 老闆 | P1 | 陰柔 · 圓臉 · 黑色馬尾 · s3 · 圓眼深瞳 · 平眉 · 露齒笑 | `athleisure` | 精力旺盛、殺價很兇、很講信用。運動外套、毛巾掛脖子 |
| `okafor` | Mr. Okafor | 房東 | P1 | 陽剛 · 圓臉 · 灰白平頭 · s6 · 圓眼深瞳 · 濃眉 · 微笑 | 開襟毛衣（`civic_staff` 暫代） | 老城的老派房東：公正、嘮叨、記得每個房客的生日。老花眼鏡 |
| `nina` | Nina | Threadline 店員 | P1 | 中性 · 橢圓臉 · 金色包頭 · s2 · 大眼藍瞳 · 挑眉 · 微笑 | `luxury_citywear` | 衣櫃系統的導覽員。脖子掛皮尺，手上別針墊 |
| `ines` | Ines Duarte | 海關官員 | P2 | 陰柔 · 方臉 · 棕色包頭 · s4 · 細長眼 · 濃眉 · 平嘴 | `uniform_officer` | 公事公辦，但會提醒你漏了哪張文件 |
| `hana` | Prof. Hana Sato | 大學研究室主持人 | P1 | 陰柔 · 橢圓臉 · 銀色鮑伯 · s2 · 圓眼深瞳 · 柔眉 · 微笑 · 圓框眼鏡 | `lab_coat` | 研發合作、介紹實習生。實驗袍口袋插著三支筆 |
| `kai` | Kai Moreno | Aurelia Daily 記者 | P1 | 中性 · 心形臉 · 棕色亂髮 · s3 · 大眼榛瞳 · 平眉 · 露齒笑 | `casual_jacket` | 「Viral Mention」事件和新聞頭條的人。相機背帶、記者證 |

### 專屬 NPC 美術（程式已接好）

分層骨架的好處是便宜，壞處是每個人看起來都像同一個模子。重要 NPC 要做**專屬圖**：

| 檔案 | 尺寸 | 內容 |
|------|------|------|
| `characters/npc_<id>.png` | 128×144 | 完整走路圖（已經疊好、上好色，不染色）。有這張就取代分層組合 |
| `portraits/npc_<id>.png` | 256×64 | 4 個表情的完整頭像。有這張就取代分層頭像 |

優先順序：Maya → Marcus → Daniel → Elena → Priya → Jun → 其他。
