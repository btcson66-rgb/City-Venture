# 07 角色

### 2026-09-29 原創對話頭像更新

12 位具名 NPC 已接入原創四表情頭像：`npc_ana`、`npc_daniel`、`npc_dara`、`npc_elena`、`npc_jun`、`npc_ken`、`npc_lee`、`npc_marcus`、`npc_maya`、`npc_priya`、`npc_sofia`、`npc_tom`，均位於 `game/assets/portraits/`。每張 256×64，順序維持 neutral / happy / thinking / surprised。狀態：**CODEX 原創更新，已接入既有 NPC 頭像覆寫接點**。

玩家與路人的分層頭像仍沿用既有系統；本次未替換分層走路或姿勢圖。原畫與 prompt：`docs/art_sources/renewal_20260929/`；引擎 48 表情檢視：`evidence/2026-09-29_art_renewal/review/portraits_1.png`、`portraits_2.png`。

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
- **頭像的配件層**：`portraits/acc_glasses_round`、`acc_glasses_square`（64×64）已由 A5 補齊；Ana、Daniel、Priya 的對話頭像現在和走路圖一樣戴眼鏡。
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
| 臉型 | `round` 圓 · `oval` 橢圓 · `square` 方 · `heart` 心形 | `body_<pres>_<face>`（12 張）· `portraits/head_<face>`（4 張） | A1 走路圖、A5 頭像已更新 |
| 髮型 | `messy` 亂髮 · `short_neat` 短俐落 · `buzz` 平頭 · `side_part` 旁分 · `bob` 鮑伯 · `long` 長髮 · `ponytail` 馬尾 · `bun` 包頭 | `hair_<style>_back/_front`（16 張，走路和頭像各一套） | A1 走路圖、A5 頭像已更新 |
| 髮色 | black · dark_brown · brown · auburn · blonde · silver · navy（染）· rose（染） | 染色，色碼見 [01 美術方向](01_art_direction.md) | — |
| 膚色 | s1 Porcelain · s2 Light · s3 Warm · s4 Tan · s5 Brown · s6 Deep | 染色 | — |
| 眼型 | `round` · `almond` 杏眼 · `narrow` 細長 · `wide` 大眼 | `eyes_<shape>` + `iris_<shape>`（走路 8 張、頭像 8 張） | A1 走路圖、A5 頭像已檢查 |
| 瞳色 | brown · dark · hazel · green · blue · gray | 染色 | — |
| 眉毛 | `straight` 平 · `arched` 挑 · `thick` 濃 · `soft` 柔 | `brows_<style>` | A1 走路圖、A5 頭像已檢查 |
| 嘴 | `smile` 微笑 · `neutral` 平 · `grin` 露齒笑 · `small` 小嘴 | `mouth_<style>` | A1 走路圖、A5 頭像已檢查 |
| 服裝 | `startup_casual` · `office_professional` · `home` | 見下方服裝表 | A1 走路圖、A5 頭像已更新 |
| 配件 | `none` · `glasses_round` 圓框眼鏡 · `glasses_square` 方框眼鏡 · `backpack` 後背包 | `acc_<id>` | A1 走路圖已檢查 |

**衣櫃系統（2026-09-29 已實作）**：捏臉只給三套起始服裝。其他服裝在購物街的 Threadline 買（`options.json` → `outfits_shop`），買了放進衣櫃（`player.wardrobe`），在家的衣櫃或 Threadline 試衣間換上。只影響外觀，不改任何數值。美術還沒到的服裝用 `stand_in`（現有服裝加顏色）暫代；`characters/outfit_<id>_<體型>_top.png` 一出現就自動換成正式圖，頭像看 `portraits/outfit_<id>.png`。

仍在規劃中：

- 服裝的正式美術（B1）：Executive、Logistics / Site、Luxury Citywear、Travel、Formal Evening
- 配件分頁：帽子、包包、首飾、手錶、識別證

### 服裝

每套服裝要交 **3 種體型 × 3 件（top、bottom、shoes）= 9 張走路圖**，加 **1 張頭像衣領**（64×64）。

R1 已交：`business_suit_top_detail`、`courier_top_detail`（三體型各一張）將全彩襯衫、領帶、腰包等放到灰階布料上方；頭像使用 `business_suit_detail`、`courier_detail`。褲裝沒有全彩細節，因此不建立空白的 `bottom_detail`。四色西裝與 PostPoint 紅的驗收圖在 `evidence/2026-09-28_r1_outfit_details/`；NPC 染色值待 Claude 線寫入資料。

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
| `executive` | Executive 主管 | 主角（Threadline $640） | 剪裁俐落的三件式、口袋巾、手錶 | 已實作 · **美術暫代**（`business_suit` 午夜藍 `#23263A`）· 等 B1 |
| `logistics_site` | Logistics / Site 現場 | 主角（Threadline $120）、倉管、工人 | 反光背心、工作靴、安全帽（配件） | 已實作 · **美術暫代**（`courier` 橘 `#E8742A`）· 等 B1 |
| `luxury_citywear` | Luxury Citywear 城市精品 | 主角（Threadline $520）、Nina、購物街路人 | 長版大衣、高領毛衣、皮靴（Board A「Casual City」高級版） | 已實作 · **美術暫代**（`casual_jacket` 駝色 `#9C6A44`；路人大衣 5 色）· 等 B1 |
| `travel` | Travel 旅行 | 主角（Threadline $240；出國） | 輕羽絨、斜背包、休閒鞋 | 已實作 · **美術暫代**（`casual_jacket` 橄欖綠 `#5F6E44`）· 等 B1 |
| `formal_evening` | Formal Evening 晚宴 | 主角（Threadline $780） | 燕尾服或晚禮服 | 已實作 · **美術暫代**（`business_suit` 黑 `#15161C`）· 等 B1 |
| `student` | 學生 | 大學區路人 | 帽 T、後背包、帆布鞋 | 規劃中 P1 · `新增` |
| `athleisure` | 運動休閒 | 健身房、慢跑路人、Rosa | 運動外套、緊身褲、跑鞋 | 規劃中 P1 · `新增` |
| `chef_waiter` | 餐飲制服 | 餐廳員工 | 白色廚師服或黑背心 | 規劃中 P1 · `新增` |
| `lab_coat` | 實驗袍 | Prof. Hana Sato、研究員 | 白色實驗袍 | 規劃中 P1 · `新增` |
| `uniform_officer` | 制服 | 海關、門僮 | 海軍藍制服、帽子 | 規劃中 P2 · `新增` |

### 配件

| id | 名稱 | 狀態 | 備註 |
|----|------|------|------|
| `glasses_round` | 圓框眼鏡 | 已實作 · CODEX A5 | 走路圖和頭像均有，程式已接好 |
| `glasses_square` | 方框眼鏡 | 已實作 · CODEX A5 | 走路圖和頭像均有，程式已接好 |
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
| 站立呼吸 `idle` | 2 | 下、側、上 | 櫃台後的 NPC | ✅ 已上線，2 格動畫 |
| 坐 `sit` | 2 | 下、側、上 | 員工坐辦公桌、咖啡店和共享辦公的客人、坐沙發的 NPC | ✅ 已上線（R3） |
| 搬箱 `carry` | 4 | 下、側、上 | 打包出貨、倉管 | ✅ 美術完成；遊戲裡還沒有搬貨的動作會用到 |
| 講電話 `phone` | 2 | 下、側、上 | 主角打開手機時 | ✅ 已上線，2 格動畫 |
| 伸手互動 `interact` | 2 | 下、側、上 | 打包桌的出貨員工 | ✅ 已上線（出貨員工） |
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

A5 已重製四種現有表情並補上眼鏡；12 位具名 NPC 的頭像和四表情組合預覽見 `evidence/2026-09-28_a5_portraits/`。此批維持 64×64 單格與 256×64 四格格式。

---

## 具名 NPC（已實作 14 位）

外觀全部用上面的選項組出來。資料在 `game/data/npcs/<id>.json`。「定稿需求」是做專屬頭像和走路圖時的特徵重點。

| id | 名字 | 身分 | 外型 | 服裝 | 出沒 | 定稿需求（專屬特徵） |
|----|------|------|------|------|------|----------------------|
| `maya` | Maya | 主角的老朋友 | 陰柔 · 橢圓臉 · 黑色鮑伯 · s3 · 杏眼深瞳 · 挑眉 · 微笑 | `casual_jacket`（暖芥末色外套 `#C8843E`、深灰褲 `#3A3C48`） | Bloom Coffee 窗邊桌，週六日 10–16 | 開場第一個傳訊息的人，代表「生活」。溫暖、愛笑、帆布包、耳機掛脖子 |
| `jun` | Jun | Bloom Coffee 咖啡師 | 陽剛 · 方臉 · 黑短髮 · s4 · 細長眼 · 濃眉 · 平嘴 | `barista` | Bloom 櫃台，每天 7–20 | 話少但可靠。捲起袖子，手臂有咖啡漬，圍裙口袋插一支溫度計 |
| `lee` | Lee | Bean & Byte 咖啡師 | 中性 · 圓臉 · 藍染馬尾 · s2 · 圓眼灰瞳 · 柔眉 · 微笑 | `barista` | Bean & Byte 櫃台，每天 7–19 | 新創圈的八卦中心。耳朵有小耳環，圍裙上有程式碼圖案（色塊） |
| `priya` | Priya | Nexus Co-work 社群經理 | 陰柔 · 心形臉 · 深棕長髮 · s5 · 大眼 · 挑眉 · 露齒笑 · 圓框眼鏡 | `office_professional`（青綠色襯衫 `#3F9E96`；原本的蜜桃色太像膚色，看起來像沒穿衣服） | Co-work 櫃台，每天 8–20 | 熱情、什麼人都認識。平板夾在手臂下，識別證繩是橘色 |
| `ken` | Ken | TradeLink 業務 | 陽剛 · 圓臉 · 黑平頭 · s3 · 圓眼 · 平眉 · 露齒笑 | `casual_jacket`（TradeLink 藍 `#3F6FB5`；原本穿 `courier`，和 Dara 撞衫） | Co-work 休息區，週二、四 10–15 | 爽朗的批發商。手上永遠拿著型錄和樣品盒 |
| `ana` | Ana | 市政廳登記員 | 陰柔 · 圓臉 · 棕色包頭 · s2 · 圓眼榛瞳 · 柔眉 · 微笑 · 方框眼鏡 | `civic_staff` | 市政廳櫃台，週一到五 9–17 | 耐心、按規矩來。筆插在包頭上，開襟衫加名牌 |
| `sofia` | Sofia | Nexus Bank 客戶經理 | 陰柔 · 橢圓臉 · 赤褐馬尾 · s2 · 杏眼綠瞳 · 挑眉 · 平嘴 | `business_suit` | 銀行櫃台，週一到五 9–16 | 專業、清楚。珍珠耳環、金色 N 字胸針 |
| `marcus` | Marcus Reed | Nexus Bank 高階主管 | 陽剛 · 方臉 · 銀色旁分 · s5 · 細長眼 · 濃眉 · 平嘴 | `business_suit` | 銀行經理桌，週一到五 13–16 | 傳統金融的代表，**不是反派**。銀髮、手錶、三件式、沉穩 |
| `tom` | Tom | 租賃仲介 | 陽剛 · 橢圓臉 · 金色短髮 · s1 · 圓眼藍瞳 · 平眉 · 微笑 | `business_suit` | 22 Founders Lane，週一到六 9–18 | 業務笑容，手上一串鑰匙，西裝有點太亮 |
| `dara` | Dara | PostPoint 店員 | 中性 · 心形臉 · 玫瑰色亂髮 · s4 · 大眼 · 柔眉 · 小嘴 | `courier` | PostPoint 櫃台，每天 8–21 | 手腳很快。耳後夾一支筆，手上掃描槍 |
| `daniel` | Daniel Wong | Crestline 採購 | 陽剛 · 橢圓臉 · 黑色旁分 · s3 · 杏眼 · 平眉 · 平嘴 · 方框眼鏡 | `business_suit` | Co-work 休息區，週四 17–20；接洽大訂單後，週六日 11–16 也在 Crestline 旗艦店 | 第 5 章大訂單的人。精明、有禮、拿著皮革資料夾。大訂單也可能拖垮現金流 |
| `nina` | Nina | Threadline 造型師 | 中性 · 橢圓臉 · 金色包頭 · s2 · 大眼藍瞳 · 挑眉 · 微笑 | `luxury_citywear`（炭灰大衣 `#3A3A42`；服裝美術到位前以 `casual_jacket` 暫代） | Threadline 櫃台，每天 10–21 | 衣櫃系統的導覽員。脖子掛皮尺，手上別針墊。第一次逛衣架時打招呼（`nina_first`） |
| `okafor` | Mr. Okafor | Okafor Lettings 房東（Old Town） | 陽剛 · 圓臉 · 灰白平頭（`buzz`、`silver`）· s6 · 圓眼深瞳 · 濃眉 · 微笑 · 圓框眼鏡 | `office_professional`（棕色上衣 `#6b4a3a`、深灰褲 `#3a3a42`；定稿目標是開襟毛衣） | Okafor Lettings 桌後（坐姿），週一到六 9–18。第一次見面走 `okafor_intro`，租下咖啡店面後改 `okafor_tenant`，其他時候 `okafor_chat`。**B3 專屬美術已交**：`characters/npc_okafor` 三方向四表情、`npc_okafor_sit` 三方向坐姿、`portraits/npc_okafor` 四表情，均含原尺寸／4× 版；坐姿為靜態兩格重複 | 老城的老派房東：公正、嘮叨、記得每個房客的生日。老花眼鏡、滿頭銀白。租轉角咖啡店面（每月 $1,900、押金兩個月，只租給已登記的公司）的窗口 |
| `elena` | Elena Park | Northlight Capital 創投 | 陰柔 · 心形臉 · 黑色旁分 · s2 · 細長眼 · 平眉 · 小嘴 | `office_professional`（冷白外套 `#DFE6F0`、深色褲 `#2F3340`） | Co-work 休息區，週三 15–18 | 冷靜、快、條件不一定划算，玩家可以拒絕。白色西裝外套、極簡耳環 |

> 已解決（2026-09-28）：Maya 和 Elena 原本外型幾乎一樣，現在 Elena 改成心形臉、黑色旁分、細長眼、平眉，穿冷白外套；Maya 維持鮑伯頭，換成暖芥末色外套。
>
> 已解決（R1）：西裝拆成可染色布料加不染色的領帶和襯衫。現在 Marcus 炭灰 `#3A3D44`、Daniel 海軍藍 `#2C3E66`、Sofia 酒紅 `#6E2E3A`、Tom 淺灰 `#B8BCC4`；Dara 的快遞服是 PostPoint 紅 `#D0503C`。

### 只在手機出現的聯絡人

| id | 名稱 | 現在的頭像 | 規劃 |
|----|------|-----------|------|
| `bank` | Nexus Bank | `bank` 圖示 | 改用 Nexus 標誌（32×32）`需接線` |
| `shoplane` | ShopLane | `orders` 圖示 | 改用 ShopLane 標誌 `需接線` |
| `landlord` | Mr. Okafor（房東） | `home` 圖示 | 逾期房租等訊息還是用這個手機聯絡人（`phone_only`）。本人已在 Old Town 現身，是另一個 NPC `okafor`（見上方具名 NPC 表） |
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
| `barista` | Barista 咖啡師（**已實作 · 2026-09-30**） | `startup_casual`（和 `packer`、`marketer` 一樣，由 `Staff._make_person` 指定；只有 `support` 和 `developer` 穿 `office_professional`） | 規劃：改穿 `barista` 服裝（襯衫加圍裙，Jun 和 Lee 現在穿的那套）。現在的店員看起來和其他員工一樣 | 站在轉角咖啡店的吧台後（週一到六 07–17），一小時約做 14 杯。這個職位的工作地點是咖啡店，不是 Suite 2B，而且要先租下轉角咖啡店面才能僱用 |
| `driver` | Van Driver 貨車司機 | `logistics_site`（橘色反光背心暫代） | 加安全帽、手上拿著手寫的路線單 | **已實作**：工作日 9–17 點站在 Pier 7 倉庫裝卸平台旁（要先租下倉庫才看得到人；他的工作是開你的貨車跑一趟外送，見 `13_core_loop_and_work.md`） |

## 路人（`scripts/world/ambient_person.gd`）

外型全部隨機，服裝從 `casual_tee`、`casual_jacket`、`business_suit`、`office_professional`、`startup_casual` 挑，上衣和褲子隨機染色。各區的密度依時段變化。

各區可以設定路人服裝（區域資料的 `ped_outfits`）：**購物街已實作**，多穿 `luxury_citywear`。

**港區已實作**：路人多穿 `logistics_site`（橘色反光背心，美術暫代）、`courier`、`casual_jacket`。

**規劃**：金融區多西裝；大學區多 `student`；購物街加提購物袋的路人；住宅區有推嬰兒車、遛狗的人（需要新的配件或道具）。

---

## 規劃中的具名 NPC

外型先用現有選項組，等專屬美術到位後再換。

| id | 名字 | 身分 | 登場 | 外型（現有選項） | 服裝 | 視覺設定 |
|----|------|------|------|-----------------|------|----------|
| `lina` | Lina Zhao | 跨境支付新創創辦人，在 Nexus Bank 駐點（平日 10–16 點，第 5 年起） | 第 9 章介紹三種結算方式；第 10 章推出貨到放款託管；第 11 章在跨鏈橋事件中解釋「我們解決了一個信任問題，卻又製造了另一個」（都已實作） | 陰柔 · 心形臉 · 黑色長髮 · s2 · 杏眼深瞳 · 平眉 · 小嘴 | `luxury_citywear` | 聰明、冷靜、講話很快。黑色高領、筆電貼紙（無 logo）、無線耳機。介紹新的結算方式，但不推銷、不炒作 |
| `omar` | Omar Haddad | 國際貿易商 | P2 | 陽剛 · 方臉 · 黑色旁分（夾灰）· s4 · 杏眼深瞳 · 濃眉 · 微笑 | `business_suit`（淺色亞麻） | 開啟海外供應鏈。短鬍子、亞麻西裝、舊皮箱，辦公室裡有茶具和世界地圖 |
| `victor` | Victor Hale | Hale Group 的大型企業家 | 第 12 章已實作（平日 11–16 點在 Crestline 旗艦店，或電話） | 陽剛 · 方臉 · 銀色短髮（`short_neat`）· s1 · 細長眼灰瞳 · 平眉 · 平嘴 | `business_suit`（近黑深色，`executive` 圖出來前暫代） | 可能是客戶、對手、收購者或夥伴，**不能固定成反派**；在第 12 章是收購者：開價、解釋怎麼算、尊重任何答案。高、瘦、訂製西裝、沒有多餘表情 |
| `rosa` | Rosa Lim | Harbor Point Fitness 老闆 | P1 | 陰柔 · 圓臉 · 黑色馬尾 · s3 · 圓眼深瞳 · 平眉 · 露齒笑 | `athleisure` | 精力旺盛、殺價很兇、很講信用。運動外套、毛巾掛脖子 |
| `ines` | Ines Duarte | 海關官員 | P2 | 陰柔 · 方臉 · 棕色包頭 · s4 · 細長眼 · 濃眉 · 平嘴 | `uniform_officer` | 公事公辦，但會提醒你漏了哪張文件 |
| `sam` | Sam Okoro | Dockside Motors 二手貨車行老闆（港區） | **已實作**（港區，週一到週六 08–18 點在展示間櫃台後面；找他說話可以買第一台貨車，見 `09_vehicles.md`）。外型用現有選項組、黑色捲髮暫用 `messy`，`npc_sam` 專屬圖等 B2 | 陽剛 · 方臉 · 黑色短捲髮 · s5 · 圓眼深瞳 · 濃眉 · 露齒笑 | 工作服（`courier` 暫代，深藍） | 爽朗、講實話，會直接告訴你哪台車的變速箱快不行了。手上有機油、耳朵夾一支筆 |
| `hana` | Prof. Hana Sato | 大學研究室主持人 | P1 | 陰柔 · 橢圓臉 · 銀色鮑伯 · s2 · 圓眼深瞳 · 柔眉 · 微笑 · 圓框眼鏡 | `lab_coat` | 研發合作、介紹實習生。實驗袍口袋插著三支筆 |
| `kai` | Kai Moreno | Aurelia Daily 記者 | P1 | 中性 · 心形臉 · 棕色亂髮 · s3 · 大眼榛瞳 · 平眉 · 露齒笑 | `casual_jacket` | 「Viral Mention」事件和新聞頭條的人。相機背帶、記者證 |

**Lina 美術（S1）**：`characters/npc_lina.png`、`characters/npc_lina_sit.png`、`portraits/npc_lina.png` 與各自的 `world_detail/` 4× 版已完成並自動套用。

### 專屬 NPC 美術（程式已接好）

分層骨架的好處是便宜，壞處是每個人看起來都像同一個模子。重要 NPC 要做**專屬圖**：

| 檔案 | 尺寸 | 內容 |
|------|------|------|
| `characters/npc_<id>.png` | 128×144 | 完整走路圖（已經疊好、上好色，不染色）。有這張就取代分層組合 |
| `portraits/npc_<id>.png` | 256×64 | 4 個表情的完整頭像。有這張就取代分層頭像 |

優先順序：Maya → Marcus → Daniel → Elena → Priya → Jun → 其他。

## B2 具名角色 · 美術已交 2026-09-30

Rosa Lim、Ines Duarte、Sam Okoro 均交 `characters/npc_<id>` 128×144（三方向 × 四表情）、`portraits/npc_<id>` 256×64 與 4×。外型依上表；表情順序平常、微笑、思考、驚訝。站姿各格保持腳底對齊，港區出生點、排程與服裝選項由 Claude 線接入。
