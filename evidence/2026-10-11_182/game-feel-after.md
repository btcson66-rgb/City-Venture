# #182 修改後 game-feel-review

Godot 4.5.1，實際 native 渲染。完整新遊戲路線另列結果；本檔的 focused old-save tour 使用修改前 bot 實際玩出的 chapter3.json，而非填入章節／現金旗標。MiniGames.auto 的固定品質不能證明新手操作感。

新手代理路線：上架與首單都有進度收據；接下來看得到章節的完成格。等庫存、交付、客訴、應徵者、發薪以及 NPC 開門可主動跳時間；費用與排程照跑。第三章已有兩個真實商品時直接開始第四章，不再要求等月底。原 bot 仍知道所有路線，盲測首次玩家尚未驗證。

熟手代理路線：修改前的真實第三章存檔讀入後保留已有商品、現金與 Ledger，goal_month 收據完成並進入第四章；工作頁能看見下一個頭銜與班次進度。八個 focused tests 覆蓋真實採購、兩班工資、已完成舊收據與應徵者／發薪排程。這不是十小時人類玩家的主觀樂趣驗收。

| 原則 | 結果、证據與限制 |
|---|---|
| F1 | PARTIAL：保留既有安全練習、重播與跳過；bot 固定品質未驗證首次手動學習。 |
| F2 | PARTIAL（全體）；PASS（新增範圍）：接續班是可選按鈕；沒有強制接班、倒數或新增工資速度獎勵。 |
| F3 | PASS（範圍內）：等待按鈕只在目前目標有真實未來事件時顯示；不列未解鎖產業。 |
| F4 | PARTIAL：HUD 保留目前一個主線；工作頁仍有完整階梯與原有次要操作。 |
| F5 | PARTIAL：既有助理仍可處理重複雜事；未聘用就代辦是 #181 的待修問題。 |
| F6 | PARTIAL：新短目標有進度格／說明入口；844×390 觸控大字工作頁仍需水平／垂直捲動閱讀既有長文字，沒有宣稱全系統卡片通過。 |
| F7 | PASS（範圍內）：舊等待存檔繼續；已完成收據不重複；無相關事件不跳時間；Ledger 平衡。完整主線结果另列；真實舊檔 pr182-pre-fun-ch3.json 也納入單元回歸。 |
| F8 | PASS（新增回饋）：短暫 sky/green 彩帶，不攔輸入；reduce_motion 停止粒子；重要章節卡先播放，短慶祝等卡關閉。 |
| F9 | PASS（此新遊戲 bot 路線）：前 30 分鐘 59 個真實進展收據，最長間隔 263.3 秒，超過 300 秒為 0。人類新手找路與閱讀速度尚未盲測。 |
| F10 | PASS（範圍內）：取消月結门檻；主動跳到排程事件；所有真實義務及款項保留。 |

畫面矩陣：1280×720 zh_TW/en 的舊檔＋工作路線，以及 844×390 en/extra-large/touch 都實际執行。原生小視窗受作業系統尺寸限制，截圖實際像素見檔案；沒有把 native 渲染稱作 exported Web／真實手機。#180 另外測最終 Web。

自我複查修正：章節卡會蓋住慶祝；增加待播訊息，等卡關閉才播放。刪除月底等待後 bot 沒回家就睡覺；改成真實行走回家。新增應徵者與週五發薪的等待跳轉，仍以真實排程與曜日計算。

已知限制：既有 SHOPLANE/beta 和少數品牌英文被 audit 列出；新增字串的 zh_TW missing 0。沒有測量生理多巴胺、留存或宣稱每位玩家必然感到好玩。全系統 F1/F4/F6 與人類盲測仍須獨立驗證。

最後 focused 舊檔＋兩班升遷：0 失敗，41.2 秒；慶祝文字移到寄件提示下方，可清楚閱讀。feedback-english-audit.json 的三個項目均為既有公司品牌名稱。全章巡覽使用相同經濟／進度邏輯；最後這個文字位置與 focused QA 入口調整另由此跑程覆蓋。

最終新遊戲 rendered walkthrough：1–24 章＋全部產業、步行連接、個人系統與存讀檔，0 failures / 5969.4 秒 / 356 張截圖。前30分鐘59個進展時刻，最長空窗263.3秒。

後續 #180 真實 Web 診斷發現既有職場卡片在很晚到店時可能過時，結算時因不足營業時數沒有薪資；隔日可重試。已修正：開班重查真實資格，結算淡出期間以 work_payout 暫停背景時鐘；合法兩小時工資不會因渲染延遲消失，且不發補償金。營業時段仍保留，故全體 F2 為 PARTIAL。


2026-10-12 final acceptance: Final-source rendered walkthrough:0 failures, 7206.9 real seconds, 361 screenshots, 2957 steps. New-game chapters1–24, industry/adjacency/personal/save coverage; see full-result.json and full-walkthrough-log.txt. Bot proxy, not human delight or physical-device acceptance.

最終完整驗證：完整新遊戲第1–24章＋產業、步行鄰接、個人生活與存读檔：**0 failures，7206.9秒，361張截圖**。full-result.json與full-walkthrough-log.txt為最終來源結果。
