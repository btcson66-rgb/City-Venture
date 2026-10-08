# 第二輪遊戲體驗稽核（#164）

從一個安靜的入口做經營決定；原本的價格、風險、合約與手動操作仍可在「進階」查閱。新增 13 產業首次引導、略過與重看；五項日常助理使用現有費用、資產、員工與真實完成的工作。助理不買產業、不接新案、不最佳化、不創造免費人力或收入。

## 比較方法

34 個匹配樣本：31 頁籤／對話框，加 3 個已營運的媒體、車隊、充電站。固定 seed 與原生 setup API；已營運充電站的認證／階段是明示測試資格 fixture，租地、建造、資產與保養走原生交易。這些 fixture 不代替主線驗收。

字數為主內容所有可见 Label/Button 的 Unicode 字元（不含換行）；數字為數值群組，不含 HUD、標題與頁尾。展開的原始內容計入，隱藏的進階區不計入。這不是英文單字計數，也不是只算螢幕裁切範圍。合計字元 12,642 → 2,784（−78.0%），數字 954 → 102（−89.3%）。少數空狀態增加必要的三項事實，不宣稱每頁都變短。

步驟欄為到主要入口的一次點擊，不含旅行、頁籤導航與捲動；不是整筆交易的步驟。14 個樣本將簽約／購買保留在完整條款旁，手動確認比原本多一次展開（1 → 2），避免只看摘要就花錢。

| Screen | Characters before → after | Numbers before → after | Primary entrance clicks | Review required |
|---|---:|---:|---|---|
| AutomotiveUI_auction | 716 → 81 | 45 → 3 | 1 → 1 | no |
| AutomotiveUI_fleet | 113 → 78 | 5 → 3 | 1 → 1 | no |
| EnergyUI_charging | 164 → 97 | 8 → 3 | 1 → 1 | no |
| EnergyUI_leads | 434 → 98 | 23 → 3 | 1 → 1 | no |
| EnergyUI_survey | 286 → 105 | 27 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| Fundraising_cap | 111 → 82 | 3 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| Fundraising_investors | 518 → 75 | 18 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| Fundraising_terms | 310 → 82 | 14 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| HotelUI_board | 966 → 95 | 133 → 3 | 1 → 1 | no |
| HotelUI_groups | 277 → 91 | 21 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| HotelUI_ops | 549 → 91 | 34 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| Lease | 119 → 61 | 5 → 3 | 1 → 1 | no |
| LeaseEnd | 134 → 64 | 2 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| ManufacturingUI_orders | 330 → 94 | 29 → 3 | 1 → 1 | no |
| ManufacturingUI_planner | 139 → 88 | 10 → 3 | 1 → 1 | no |
| ManufacturingUI_quality | 117 → 87 | 9 → 3 | 1 → 1 | no |
| MediaUI_briefs | 220 → 101 | 12 → 3 | 1 → 1 | no |
| MediaUI_mixer | 98 → 113 | 4 → 3 | 1 → 1 | no |
| MediaUI_reports | 155 → 99 | 10 → 3 | 1 → 1 | no |
| OS_contracts | 116 → 55 | 5 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| OS_finance | 847 → 87 | 117 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| OS_governance | 378 → 79 | 17 → 3 | 1 → 1 | no |
| OS_group | 538 → 67 | 38 → 3 | 1 → 1 | no |
| OS_market | 32 → 61 | 0 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| OS_people | 1100 → 66 | 56 → 3 | 1 → 1 | no |
| OS_segments | 1313 → 62 | 142 → 3 | 1 → 1 | no |
| RealEstateUI_matches | 335 → 60 | 21 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| RealEstateUI_properties | 447 → 60 | 33 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| Tax | 75 → 71 | 2 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| TradeDesk | 45 → 68 | 2 → 3 | 1 → 1 | no |
| TradeQuote | 518 → 86 | 19 → 3 | 1 → 1 | yes: +1 disclosure click for original paid action |
| ActiveCharging | 322 → 97 | 28 → 3 | 1 → 1 | no |
| ActiveFleet | 378 → 84 | 31 → 3 | 1 → 1 | no |
| ActiveMediaMixer | 442 → 99 | 31 → 3 | 1 → 1 | no |

## 日常步驟

| 已具備資格的重複工作 | 手動 → 助理開啟 | 限制 |
|---|---|---|
| 歸還後車隊保養 | 1 → 0 | 實際費用與一天停用；出租中等待 |
| 充電站保養 | 1 → 0 | 實際保養費；現金不足不代辦 |
| 已完成舊式媒體工作交付、開票 | 2 → 0 | 未完工不交付；原生 campaign 的原有自動結算仍為 0 → 0 |
| 每月強制報告 Continue | 1 → 0 | 第一份真實報告仍顯示；之後可在財務閱讀 |
| 旅館每日調價與臨時清潔 | 重複編輯 → 0 | 參考價非最佳價；現有人力與付費臨時清潔，沒有免費僱員 |

開關設定一次需 1 點擊；上述 0 只指後續日常操作。舊存檔的手動選擇保留，相關新增開關沿用原保養／包裝／排班設定。

## Game-feel-review：修改前與修改後

| 原則 | 前 | 後與證據 |
|---|---|---|
| F1 | PARTIAL：中後期缺產業入口引導 | PASS scope：13 registry 產業全覆蓋；真實可見目標、1–3 步、略過與重看、不花錢不走時鐘；12 專項測試與 guides 截圖 |
| F2 | PARTIAL：既有經營期限 | PARTIAL：引導不限時、助理減少日常壓力；原有經營期限未全系統改寫 |
| F3 | PASS：已解鎖才顯示 | PASS：保留 registry／進度 gate，早期財務不增加中後期摘要；新遊戲前 3 章與完整主線 |
| F4 | FAIL：多個同級決定 | PASS scope：31+3 摘要保留一個主要入口，風險條款展開；原手動深層畫面仍有複雜選擇 |
| F5 | PARTIAL：中後期仍重複操作 | PASS scope：5 新助理；實際付费保養、人工、完成媒體工作；可關閉，沒有新增收入來源 |
| F6 | FAIL：資訊與數字密集 | PASS scope：預設摘要 2 行說明、3 數字；詳情與長說明留進階／? |
| F7 | PASS baseline | PASS：舊存檔與部分手動設定、取消／重看、現金不足與出租中等待；主線真實 FX 收據不因月報自動關閉而卡關；Ledger/R4 專項與全主線 |
| F8 | PARTIAL：同時強調太多 | PASS scope：中英文桌面／640×360 大字體触控布局；單一主行動，引導 Next 使用低調樣式；實體手機 NOT VERIFIED |

新手（修改前）：中後期先看大量比率、成本與選項，很難辨認現在要做什麼。
新手（修改後）：先看到下一個入口與三項目前事實，選擇自己想玩的產業；簽約先展開條款。新遊戲前 3 章保留原有循序導入；完整 1–24 章實際完成，沒有手機回覆門檻。
熟手（修改前）：資訊齊全，但每天開票、保養與月報打斷經營節奏。
熟手（修改後）：進階仍可調整、引導可略過／重看；保養／交付用原生交易且可切回手動，旧存檔不強迫改設定。

## 驗證與限制

完整 rendered 新遊戲 1–24 章＋產業巡覽：344 截圖，0 失敗；真實第 24 章存檔驗證 17 助理全開。主程序在最終引導／條款按鈕／機器人布局修正前啟動，最終提交另外重跑全部單元與全部產業；記錄分開，不冒稱同一程序載入後續程式。

初次產業診斷曾有 2 次能源按鈕展開後機器人太早點擊；修正為真實點擊並等布局，能源重跑 0 失敗。最終全產業結果見 evidence checks。既有英文審計的姓名、公司名與 beta token 保留逐項記錄；i18n zh_TW 0 missing。

原始測試保存於隔離 QA user 路徑。截圖和前後每頁比較見 [gallery](../evidence/2026-10-08_164/GALLERY.md)。沒有實體手機、Web／低階裝置效能驗收；Session G 的打包、匯入與 CI 設定不在此工單範圍。

最終 implementation 3e44260d：單元 1000/1000（458.9s）；全部產業 rendered 重跑 78 張、0 失敗（529.1s）。部分既有產業劇情教學會先覆蓋入口，關閉後接續新的 inline 導引。
