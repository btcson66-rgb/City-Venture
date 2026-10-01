# #39 互動探索與城市指南

開工日：2026-10-01；驗證續於 2026-10-02。分支 `codex/39-discoverability`，基底
`a2a8bdb2`（已合併 #73）。開工前與實作後均 fetch 並 merge 最新
`origin/claude/exciting-bardeen-y71ixv`，使用 merge，不使用 rebase。
開 PR 前再合入 `a9124264`（ROADMAP 文件更新），merge commit `63eb6545`，無衝突。

## 實作

- 每個 enabled 互動點使用既有動作圖示，遠處淡顯、64 px 內顯示翻譯名稱；E 提示保持原樣。
  look 圖示較小較淡，鎖定點灰顯加鎖頭。相鄰點僅錯開繪圖，不移動互動座標或改變原動作。
- 前兩次進門的 4 秒卡片從實際互動點與在場 NPC 產生，含店名、營業時間與開門狀態；可點掉。
  按 I 或 HUD「這裡能做什麼？」再開。純 look 房間明示只能參觀。
- 門口類型讀取 building.category；城市指南從 buildings、districts 及 metro 資料產生。
  街區 status 優先讀取 district，缺省讀取 city 定義；planned 街區無可導航建築。
  未來新增 active 街區及建築會自動列入。尊重建築的 status／enterable，測試涵蓋狀態切換。
- 「帶我去」共用 Tutorial._resolve、既有路線與金色箭頭；抵達後恢復教學／主線目標。
  關門時仍可導航到門口並查看開門時間，沒有繞過開門規則。
- 互動標記設定預設開啟，寫入 settings.cfg，與遊戲存檔分開。
  building_visits 在舊存檔首次進門時才建立，不改舊 visited、帳本或合約欄位。
- 最新基底已有非咖啡商品分類流程；本次保留餐點讀取 params.category，提示名稱與金額使用
  Fmt.money0，咖啡保留原句。餐點不增加 coffee 統計、不記入咖啡費用。
- 沒有修改 game/assets/ 或 tools/art/，也沒有實作 #62–#71 的新產業內容。

## 已完成驗證

- 合入最新基底後，Godot 4.5.1：`273/273 tests passed in 20.1s`；unit.log、unit.xml。
  新增全建築圖示涵蓋、進門說明／look 分類、實際在場 NPC、未來街區自動加入、
  舊版真實存檔遷移與計數存讀檔、$22 餐點提示及 dining 帳本驗證。
- 繁中探索 walkthrough tour：`0 failure(s) · 54.9s real`；tour-zh_TW.log、結果 JSON。
- 簡中探索 walkthrough tour：`0 failure(s) · 54.9s real`；tour-zh_CN.log、結果 JSON。
- 兩個探索 tour 的 english_audit 均僅有既有語言選項 `English`，本工單新增漏譯 0。
- i18n_extract --check：`3089 msgids · zh_TW translated 3089 · missing 0 · unused 122`。
- wiki_check：`OK (3830 assets, 191 data ids)`。
- 繁中完整主線 walkthrough：`0 failure(s) · 2591.5s real`，1716 步、236 張實機截圖。
  保留 full-zh_TW.log、結果 JSON 與英文稽核；稽核 23 筆均為既有人名／品牌、
  AUR 登記字號與 English 語言選項，沒有本工單新增文字。
- 簡中完整主線 walkthrough：`0 failure(s) · 2402.9s real`，1665 步；採 headless，
  不產生截圖。簡中畫面另由前述實際渲染探索 tour 驗證。保留 full-zh_CN.log、結果 JSON
  與英文稽核；18 筆均為既有人名／品牌、登記字號與語言選項，新增漏譯 0。
  初次簡中完整 run 曾漏點 Pack；bot 現在確認實際 packed 訂單後才點快遞，最多重試
  三次實際輸入。本次完整重跑沒有失敗，也沒有直接補寫訂單或經濟狀態。

探索 tour 的時間、位置使用隔離 fixture，UI 操作、標記設定、導航與餐點購買使用實際輸入。
它不取代完整主線 walkthrough，也不是經濟平衡驗收。

## 截圖

## 連續作業模式補驗（2026-10-02）

- 英文實際渲染探索 walkthrough：`0 failure(s) · 54.7s real`；英文 JPG 與結果 JSON 已附。
- `bash tools/package_release.sh` 成功；內建單元 `273/273 tests passed in 19.6s`。
  Windows、Linux、macOS、Web ZIP 均產出，package.log 與 SHA256SUMS 保留。
- 自審逐條對照 #39，重讀世界互動、指南、存檔計數與餐點 diff；確認舊檔計數懶建立、
  灰色鎖定僅影響呈現、導航沒有繞過營業時間。之前自審修復 HUD 初始語系未刷新與 bot 打包漏點。
- 英文／繁中新畫面已看圖檢查；沒有文字溢出或新漏譯。依使用者最新指示，後續不再跑簡中。
- 打包重新 import 的美術 .import 行尾變化已復原，不混入美術變更。

所有截圖皆由實機 tour 產生，JPG 品質 85；本工單證據限制 20 MB。

| 截圖 | 驗證 |
|---|---|
| 08、10、12、14_discoverability_<店名>.jpg | Threadline、Crestline、Lantern Bistro、Byte & Bean 的進門卡 |
| 09、11、13、15_discoverability_markers_<店名>.jpg | 四家店的互動標記與近距離翻譯名稱 |
| 16_discoverability_settings.jpg | 標記開關，預設開啟 |
| 17_discoverability_locked_marker.jpg | 未租辦公室的灰色鎖定終端 |
| 18、19_discoverability_city_guide*.jpg | 指南街區、類型、營業時間、捷運與導航按鈕 |
| 20_discoverability_gold_arrow.jpg | 既有金色箭頭導航到餐廳門口 |
| 21_discoverability_closed_door.jpg | 打烊時的 11:00 開門提示 |
| 22_discoverability_meal.jpg | 商品名稱與金額提示 |
| 23_discoverability_sightseeing.jpg | 純參觀房間明示不能辦事 |
| zh_CN_*city_guide*.jpg | 簡中城市指南 |
