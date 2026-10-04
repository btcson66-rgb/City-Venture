# 12 特效、動畫與音效

## 特效圖（`game/assets/effects/`）

| 檔案 | 尺寸 | 用在 | 疊加方式 | 美術 |
|------|------|------|---------|------|
| `shadow` | 24×8 | 每個角色和街道物件腳下的影子 | 一般（半透明黑） | GEN |
| `glow_small` | 32×32 | 室內燈具的光、車頭燈 | 加亮（additive） | GEN |
| `glow_warm` | 64×64 | 街上路燈的光 | 加亮 | GEN |
| `glow_wide` | 96×48 | 保留（規劃給招牌和櫥窗的光） | 加亮 | GEN |
| `sparkle` | 64×16 | 保留（規劃：4 格 16×16 的互動閃光） | 加亮 | GEN |

光暈是**唯一允許半透明漸層的圖**。邊緣要淡到完全透明，不能看到方框。

## 程式做的效果（不需要美術）

| 效果 | 做法 |
|------|------|
| 日夜色調 | `CanvasModulate` 依時間漸變 |
| 夜間燈光 | 建築的 `_lights` 疊圖加路燈的 glow |
| 場景切換 | 淡入淡出 |
| 角色外框 | shader `char_outline.gdshader` |
| 出口標記 | 金色脈動框加箭頭（`scripts/world/exit_marker.gd`） |
| 目標引導 | 金色圓圈加箭頭（`scripts/ui/tutorial.gd`） |
| 金額跳字 | HUD 右上角的「+$」「−$」文字往下飄並淡出，綠色是收入，紅色是支出（`scripts/ui/hud.gd`） |

## 規劃中的特效（P0–P2）

| id | 尺寸 | 影格 | 用在 | 優先 | 備註 |
|----|------|------|------|------|------|
| `water_sparkle` | 16×8 | 4 | Riverside 河面、港區海面 | P0 | 隨機散佈，慢慢閃 |
| `lamp_reflection` | 16×24 | 2 | 夜晚河面上的路燈倒影 | P1 | |
| `steam` | 8×12 | 4 | 咖啡杯、咖啡機、工廠煙囪（白色水蒸氣） | P1 | |
| `footstep_dust` | 8×4 | 3 | 跑步時 | P2 | |
| `interact_sparkle` | 16×16 | 4 | 可以互動的東西第一次出現時 | P1 | 用 `sparkle` 改 |
| `guide_arrow` | 64×16（4 格 16×16） | 4 | 取代程式畫的目標箭頭 | P1 | 程式已接好 |
| `rain` | 640×360（可平鋪） | 4 | 下雨（Board D） | P1 | `需接線`：天氣系統 |
| `puddle_reflection` | 32×8 | 2 | 雨天的地面反光 | P1 | |
| `leaves` | 8×8 | 4 | 秋天落葉 | P2 | |
| `flag_wave` | 旗子尺寸 | 2 | 市政廳旗桿 | P1 | |
| `fountain_spray` | 32×24 | 4 | 噴水池 | P1 | |
| `screen_glow` | 12×8 | 2 | 筆電、螢幕的微光 | P1 | |
| `gulls` | 16×8 | 4 | 港區海鷗 | P1 | |
| `confetti_soft` | 32×32 | 6 | 章節完成（**低調**，不是賭場風） | P2 | |

## 動畫總覽

| 對象 | 現在 | 規劃 |
|------|------|------|
| 角色走路 | 4 格 × 3 方向 | 站立呼吸、坐、搬箱、講電話、伸手互動（見 [07 角色](07_characters.md)） |
| 車輛 | 平移，沒有動畫 | 輪子 2 格（在 detail 圖層加一格） |
| 捷運列車 | 開場時平移 | 月台進站 |
| 路燈、招牌 | 夜間亮起 | 霓虹招牌輕微閃爍（克制） |
| 門 | 沒有動畫 | 自動門開關 2 格（P2） |
| 水 | 地磚 `water` / `water_alt` 交替 | 加 `water_sparkle` |

---

## 音效與音樂

原有五段循環及十二種音效保留作為舊版本的自製後備素材。#97 另有十六首自製配樂（三層 stem）、十二街區的日夜環境音、四種室內環境音與七種工作回饋音，來源及檔案清單見 `docs/AUDIO_CREDITS.md`。播放邏輯在 `autoload/sound.gd`，音量分成 Music 和 SFX 兩條，存在 `user://settings.cfg`。

### 音樂（`game/assets/audio/music/`，Ogg，循環）

| 檔案 | 什麼時候播 | 方向 |
|------|-----------|------|
| `menu` | 主選單、白天在家 | 溫暖、有希望的 lo-fi |
| `day` | 白天的街區 | 現代都市 lo-fi |
| `night` | 晚上的街區、晚上在家 | downtempo |
| `cafe` | 咖啡店裡 | 爵士鋼琴、杯盤聲 |
| `office` | 辦公室、銀行、市政廳、共享辦公 | 極簡電子 |

切換時交叉淡入淡出 1.2 秒。企劃要求：**不要以復古晶片音樂為主，不要賭場音效**。

### 音效（`game/assets/audio/sfx/`）

| 檔案 | 什麼時候 |
|------|---------|
| `click` | 按任何按鈕 |
| `open` / `close` | 打開和關閉視窗 |
| `notify` | 一般通知 |
| `success` | 好消息 |
| `error` | 壞消息、警告 |
| `cash` | 收到 $20 以上 |
| `spend` | 花掉 $20 以上 |
| `phone` | 收到訊息 |
| `fanfare` | 章節完成 |
| `door` | 進入室內 |
| `page` | 翻頁（保留） |

### 規劃中的聲音

| 類型 | 內容 | 優先 |
|------|------|------|
| 區域音樂 | 每個街區一首（資料已經有 `music` 欄位：`day_city`、`civic`、`financial`），規劃中的區域各一首 | P1 |
| 環境音 | 河水、車流、人聲、港口海鷗、咖啡機、鍵盤聲，依區域和時段疊加 | P1 |
| 動作音 | 腳步（依地面材質）、打包膠帶、紙箱放下、刷卡、印表機 | P1 |
| 天氣 | 雨聲、打雷 | P1 |


## 商品與特效美術品質批 · 2026-10-01

美術：六個16×16商品sprite已重新製作，附64×64透明高解析版本；六個程序光影／水面特效以SVG輸出原尺寸及4×，動畫格位不變；兩個app圖示識別不變，補4×輸出（4096圖為插值）。251/251測試、53張巡禮0失敗。七街區日夜實拍與商品add_prop渲染比例檢查已交；QA商品擺放不代表遊戲原本的擺設。高解析光罩及陰影載入仍待Claude保持logical尺寸接入。證據：`evidence/20261001_product_quality/README.md`。



### #97 原創配樂、環境音與工作回饋
`tools/media/compose_city_audio.py` 以各曲獨立的速度、和弦、旋律與編曲產生十六首原創曲目，沒有引用外部錄音。每首三層保持相同循環長度、同步播放；現金不足開啟節奏層，危機或路演開啟第三層，短暫情緒結束即回到場景配樂。主選單會清除世界音景。切換交叉淡入淡出 1.2 秒，快速切換會取消過期 tween，避免舊回呼停止新曲。

Music 管配樂及 stem；SFX 管操作；Ambient 環境音送入 SFX，沿用現有音量設定與 Web 手勢解鎖。原創音訊總量約 6.84 MB，上限 25 MB；Web PCK 上限另計 160 MB。工廠、旅館、辦公室與咖啡店各有環境音；街區各有日夜版本，機場以廣播提示鈴及機械背景呈現，沒有語音廣播。工作回饋接到 Line Planner、Matchmaker、Campaign Mixer、Creative Pitch、Rate Board、Auction、Roof Survey 的真實按鈕，僅改播放，不改分數、資金或產業功能。

| Audio file | Source |
|---|---|
| `ambient/airport_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/airport_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/cafe.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/civic_center_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/civic_center_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/factory.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/financial_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/financial_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/harbor_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/harbor_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/hotel.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/industrial_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/industrial_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/luxury_heights_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/luxury_heights_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/office.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/old_town_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/old_town_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/residential_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/residential_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/riverside_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/riverside_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/shopping_street_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/shopping_street_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/startup_hub_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/startup_hub_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/university_day.ogg` | 原創配樂或合成環境音／回饋音 |
| `ambient/university_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/auto_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/auto_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/auto_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/cafe_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/cafe_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/cafe_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/city_night.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/city_night_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/city_night_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/consulting.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/consulting_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/consulting_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/crisis.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/crisis_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/crisis_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/energy_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/energy_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/energy_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/factory_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/factory_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/factory_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/founders.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/founders_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/founders_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/hotel_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/hotel_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/hotel_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/logistics_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/logistics_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/logistics_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/media_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/media_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/media_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/property_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/property_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/property_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/roadshow.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/roadshow_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/roadshow_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/saas_work.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/saas_work_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/saas_work_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/season_festival.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/season_festival_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/season_festival_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/victory.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/victory_lift.ogg` | 原創配樂或合成環境音／回饋音 |
| `music/victory_pulse.ogg` | 原創配樂或合成環境音／回饋音 |
| `sfx/auction.ogg` | 原創配樂或合成環境音／回饋音 |
| `sfx/campaign_mixer.ogg` | 原創配樂或合成環境音／回饋音 |
| `sfx/creative_pitch.ogg` | 原創配樂或合成環境音／回饋音 |
| `sfx/line_planner.ogg` | 原創配樂或合成環境音／回饋音 |
| `sfx/matchmaker.ogg` | 原創配樂或合成環境音／回饋音 |
| `sfx/rate_board.ogg` | 原創配樂或合成環境音／回饋音 |
| `sfx/roof_survey.ogg` | 原創配樂或合成環境音／回饋音 |
