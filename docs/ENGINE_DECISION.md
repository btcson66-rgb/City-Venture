# 引擎選擇評估：CITY VENTURE 長期要用 Godot、Unity 還是其他？

狀態：**建議繼續使用 Godot 4.x**。目前鎖定版本為 4.5.1。
撰寫依據：專案現況（Vertical Slice 001 已可玩，26 個單元測試加整段自動試玩通過）、ROADMAP P0–P4、未來販售，以及上架 App Store / Google Play / Steam 的目標。

> 授權條款與價格以 2025 年公開資訊為準。簽約或付費前，請再到官方頁面確認最新條款。

---

## 1. 這款遊戲對引擎的真正需求

| 需求 | 說明 | 重要度 |
|------|------|--------|
| 2D 高解析像素美術 | 640×360 像素畫布放大、pixel snap、大量 sprite 與 y-sort、日夜光影 | 高 |
| 大量管理介面 | Company OS、財報、合約、手機 UI，文字密度高 | 高 |
| 模擬規模 | 帳本、訂單、NPC 排程、事件。P2–P4 會變成多城市、多產業、多公司 | 高（會成長） |
| 資料驅動 | 產品、事件、劇情、建築都放在 JSON，不寫死在場景 | 高 |
| 多語系 | 中文（繁／簡）與英文，可即時切換，CJK 字型 | 高 |
| 平台 | Windows 優先，再上 Steam、iOS App Store、Google Play。主機是加分項 | 高 |
| 商店整合 | Steam 成就／雲端存檔、Apple／Google 內購、Game Center | 中 |
| P4 Enterprise Network | 公司對公司的合約網路，本質是後端服務加客戶端 | 中（遠期） |
| 成本 | 小團隊，希望不要有抽成或每席高額年費 | 高 |

## 2. 候選方案比較

| | **Godot 4.x（現況）** | **Unity 6** | GameMaker | Defold | Unreal 5 |
|---|---|---|---|---|---|
| 2D 像素表現 | 很好（原生 2D 引擎、pixel snap、TileMapLayer） | 好（需設定 Pixel Perfect Camera） | 很好 | 很好 | 普通（為 3D 設計） |
| 大量 UI | 好（Control/Container 系統，本專案已大量使用） | 好（UI Toolkit／uGUI） | 普通 | 普通 | 普通 |
| 模擬效能 | GDScript 中等。熱點可改 C# 或 C++ GDExtension | 好（C#，DOTS 可做超大量模擬） | 普通 | 好（Lua 加原生擴充） | 很好（C++） |
| 多語系 | 內建 TranslationServer、gettext PO/CSV、字型 fallback | 內建 Localization 套件 | 需自製 | 需自製 | 內建 |
| iOS／Android | 支援。iOS 需在 macOS 加 Xcode 打包 | 最成熟 | 支援（付費方案） | 很成熟 | 支援，但包體大 |
| 內購／Game Center／Steam | 官方或社群外掛（StoreKit、Google Play Billing、GodotSteam） | 官方套件最齊全 | 有 | 有 | 有 |
| 主機（Switch／PS／Xbox） | 需第三方移植商（如 W4 Games） | 官方支援（需主機開發者資格） | 付費方案支援 | 部分支援 | 官方支援 |
| 授權／費用 | **MIT，免費、無抽成、可改原始碼** | Personal：年營收或募資 20 萬美元以下免費。超過需 Pro 每席年費（約 2,200 美元／年） | 商業與主機需付費方案 | 免費 | 營收超過 100 萬美元後抽 5% |
| 換引擎成本 | 0（已完成 Vertical Slice） | **整個重寫**：程式、場景、UI、工具、測試 | 整個重寫 | 整個重寫 | 整個重寫 |

## 3. 結論與理由

**建議：繼續使用 Godot 4.x，不換 Unity。**

1. **遊戲型態與 Godot 最擅長的完全重疊。** 這是 2D 像素、UI 密集、資料驅動的模擬 RPG，不需要 3D、不需要大型物理，也不需要高階渲染。
2. **換引擎是純成本。** Unity 的強項（主機、成熟的行動廣告與分析套件、DOTS）對這款遊戲不是瓶頸。改用 Unity 等於花數個月重寫一個已經能玩的遊戲，換不到玩家看得到的品質。
3. **販售與上架沒有障礙。** Godot 可以匯出 Windows、macOS、Linux、iOS、Android。內購、Game Center、Steam 都有外掛。MIT 授權沒有抽成，也沒有依營收或安裝數收費的風險。Unity 2023 年的 Runtime Fee 風波（2024 年 9 月已取消）說明了商業引擎條款可能變動。
4. **成長上限有退路，而且不用換引擎。** 如果 P2–P4 模擬規模變大，GDScript 太慢時：
   - 先做 profiling，再改用 typed GDScript 與資料結構優化；
   - 把熱點（帳本結算、訂單需求模擬、NPC 排程）改寫成 **C#** 或 **C++ GDExtension**。GDExtension 可以編譯到所有平台，包含 iOS。
   - 目前的模擬核心（`scripts/sim/*`）是純邏輯的靜態模組，不依賴場景，本來就適合被替換。
5. **多人／Enterprise Network（P4）靠的是後端，不是引擎。** 公司對公司的合約網路需要伺服器（帳號、撮合、權威結算、防作弊）。任何引擎的客戶端都是透過 HTTPS／WebSocket 連線，引擎選擇不影響這一塊。

### 什麼情況下要重新評估

- 發行商或平台合作**硬性要求** Unity。
- 決定**主機首發**，而且移植商的報價與時程不可接受。
- Profiling 證明即使改用 C# 或 GDExtension，模擬仍達不到目標規模（例如 P3 同時經營 20 家公司、每日上萬筆訂單）。

## 4. 為了「可以賣、可以上架」接下來要做的事（引擎無關）

| 項目 | 內容 | 階段 |
|------|------|------|
| 多語系 | 繁體中文、簡體中文、英文，可即時切換（**本次開始實作**，見下節） | P0 |
| 效能基準 | 模擬壓力測試，例如 1 年、10 家公司、每日 5,000 筆訂單，納入自動測試 | P1 |
| 觸控操作 | 點地移動、觸控互動鍵、手機可讀的 UI 字級、iPhone 19.5:9 與 iPad 4:3 版面 | 上行動版前 |
| 存檔 | 版本遷移（已有 `_migrate`）、雲端存檔（Steam Cloud／iCloud） | P1 |
| 商店整合 | Steam：GodotSteam（成就、雲端）。iOS：StoreKit 內購、Game Center。Android：Google Play Billing | 上架前 |
| iOS 打包 | 需要 **Apple Developer Program（99 美元／年）** 和一台 **macOS + Xcode**，用來簽章與上傳 | 上架前 |
| 審查與合規 | 隱私權標示、年齡分級（遊戲內模擬加密貨幣，沒有真實金流）、App Store 審查指南 | 上架前 |
| 中國大陸 App Store | 手機遊戲需**版號（ISBN）**，門檻高，建議先上台灣、香港、海外區 | 商業決策 |
| 收費模式 | 建議買斷制，或免費試玩加一次性解鎖。外觀全屬 cosmetic 的設計原則要維持，避免 pay-to-win | 商業決策（需您決定） |
| 音樂音效 | 目前沒有，需補上（授權要可商用） | P1 |
| 美術 | 目前是由概念圖轉換的遊戲素材，販售版建議由像素畫師重繪或精修（見 ART_ASSET_MANIFEST） | P1–P2 |

## 5. 多語系實作方針（已開始）

- 引擎：Godot 內建 `TranslationServer`。翻譯檔在 `game/i18n/*.po`（gettext 格式，譯者工具可直接編輯）。
- 語言：`en`（原文）、`zh_TW`（繁體中文，主要中文版）、`zh_CN`（簡體中文，由繁體以 OpenCC 轉換後再校對）。
- 切換：主選單與暫停選單可即時切換，設定會保存在 `user://settings.cfg`。
- 字型：Noto Sans TC／SC（SIL OFL 1.1，可商用、可隨遊戲散佈）作為 Inter／Pixelify 的 fallback 字型。
- 內容：所有 UI 字串、對話、事件、劇情目標、產品、地點都走翻譯表。品牌名（Bloom Coffee、Nexus Bank 等）保留英文。
- 流程：`tools/i18n_extract.py` 從程式與資料抽出字串產生 `.pot`，並保留既有翻譯；遇到缺翻譯的字串會在測試中報出來。
