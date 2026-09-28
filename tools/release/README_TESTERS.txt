CITY VENTURE — 測試版 {VERSION}（{DATE}）
============================================================

謝謝你幫忙測試！這是一款在現代城市裡創業、經營公司的像素風模擬 RPG。
目前可以完整玩到第一章到第六章（開始電商、賺到第一塊錢、登記公司、月結、聘員工、大合約、現金危機）。

0.1.3 新增：第四～六章（聘員工與發薪、Crestline 大合約、現金危機）、員工系統、
  銀行貸款與信用分數、破產與重新開始、SaaS 軟體事業、背景音樂與音效（暫停選單可調音量）、
  Company OS「財務」裡的每週現金預測。

0.1.2 新增（依第一輪測試回饋）：
  ・新手教學：左上角有一步一步的教學卡片，金色箭頭會指向下一個目標。
    每個房間的出口都有發光的「出口」地墊，街道邊緣有「→ 區名」標示。
  ・自動存檔：換場景、每 15 秒、切換分頁或關閉視窗時都會自動存。網頁版重新整理後按「繼續」即可。
  ・更多職涯：5 種兼職工作（咖啡師、包裹分揀員、社群接待、市政廳辦事員、實習櫃員），
    可升職、每份工作都有實用福利；另外可以「自由接案」當顧問接案子賺錢。
  ・修正亂碼：NPC 名字被翻成月份（Jun→6月）、看不清楚的名牌、咖啡店菜單字擠在一起、
    網頁版缺字變成方框（✕ ⚑ ▸ 和表情符號）。

------------------------------------------------------------
一、怎麼開始
------------------------------------------------------------
【Windows 10／11（64 位元）】
  1. 先把整個 zip 解壓縮（右鍵 →「全部解壓縮」），不要直接在壓縮檔裡執行。
  2. 雙擊 CityVenture.exe。
  3. 如果出現藍色視窗「Windows 已保護您的電腦」：
     按「其他資訊」→「仍要執行」。（測試版還沒有數位簽章，這是正常的。）

【Mac（macOS 11 以上，Intel 與 Apple 晶片都可以）】
  1. 解壓縮，把「CITY VENTURE.app」拖到「應用程式」資料夾。
  2. 第一次開啟：在 App 上按右鍵（或 Control＋點一下）→「打開」→ 再按「打開」。
  3. 如果顯示「無法打開」或「已損毀」：
     到「系統設定 → 隱私權與安全性」，拉到最下面按「強制打開／仍要打開」。
     還是不行的話，打開「終端機」貼上這行後按 Enter，再開一次：
       xattr -dr com.apple.quarantine "/Applications/CITY VENTURE.app"
  ※ Mac 版還沒在實體 Mac 上測過，打不開請直接告訴我們。

【Linux】 解壓縮後執行 ./CityVenture.x86_64（需要時先 chmod +x）。

【網頁版】 由主辦人提供網址，用電腦版 Chrome／Edge／Firefox 開啟即可（手機還不支援）。

電腦需求：近 10 年內的一般電腦即可（顯示卡支援 OpenGL 3.3）。遊戲目前沒有音樂音效。

------------------------------------------------------------
二、操作
------------------------------------------------------------
  移動            WASD 或 方向鍵（按住 Shift 跑步）
  互動／對話       E 或 空白鍵（走到東西旁邊會出現提示，也可以直接點提示）
  手機            Tab（或點右上角「手機」按鈕）
  城市地圖         M（或點右上角「地圖」按鈕）
  暫停／關閉視窗    Esc（暫停選單可以存檔、讀檔、調整一天長度、切換語言）
  快轉時間         在城市裡按住 T
  回報問題         F12（網頁版請用 Esc →「回報問題」）

  語言：主選單右下角可以切換 English／繁體中文／简体中文，遊戲中也能在暫停選單切換。

------------------------------------------------------------
三、建議怎麼玩（約 30–60 分鐘）
------------------------------------------------------------
  跟著左上角的「目標」走就可以。大致流程：
  建立角色 → 看手機 → 出門到 Bloom Coffee 買咖啡 → 往東走到「新創園區」的 Nexus 共享辦公室
  → 看「創業佈告欄」選電商 → 用筆電（或辦公桌）打開 Company OS 進貨 → 睡覺等貨到
  → 拍照上架 → 等訂單 → 到打包桌打包出貨 → 賺到第一塊錢 → 處理客人退貨
  → 搭捷運到「市政中心」登記公司 → 到「金融區」Nexus 銀行開公司帳戶
  → 決定在哪裡辦公 → 一路經營到 6 月底，看「月結」報表。
  想換個玩法：到 Nexus 共享辦公室的「創業佈告欄」→「兼職工作」應徵，
  再到工作地點的「員工通道」按 E 上班；或在 Company OS →「接案」開始自由接案。
  教學可以按「略過」，之後在暫停選單（Esc）可以重新播放，也可以關掉金色箭頭。

------------------------------------------------------------
四、我們最想知道
------------------------------------------------------------
  ・哪裡卡住、不知道下一步要做什麼？新手教學和金色箭頭夠清楚嗎？
  ・哪裡覺得無聊、太慢、太難或太簡單？
  ・財務數字（利潤、現金、應收）看得懂嗎？「賺了錢但現金變少」有讓你理解為什麼嗎？
  ・翻譯哪裡怪怪的、字太小、字被切掉？
  ・任何 bug：畫面錯誤、卡住、當掉、數字不對。

------------------------------------------------------------
五、怎麼回報問題
------------------------------------------------------------
  1. 遇到問題的當下按 F12（網頁版：Esc →「回報問題」）。
  2. 遊戲會存下「截圖＋存檔＋紀錄檔」，並打開那個資料夾。
  3. 打開 info.txt，在最下面用幾句話寫：你正在做什麼、發生了什麼、你原本以為會怎樣。
  4. 把整個資料夾壓縮，傳給邀請你測試的人。
  一般心得直接用訊息傳就好。

------------------------------------------------------------
六、存檔在哪裡
------------------------------------------------------------
  Windows：%APPDATA%\CityVenture\saves（回報資料夾在 %APPDATA%\CityVenture\reports）
  Mac：    ~/Library/Application Support/CityVenture/
  Linux：  ~/.local/share/CityVenture/
  網頁版：  存在瀏覽器裡（清除瀏覽資料會一起刪掉）
  遊戲會自動存檔（換場景、每 15 秒、切換分頁或關閉視窗時），主選單按「繼續」接著玩。
  也可以在手機或暫停選單手動存到其他欄位。想重新開始：主選單按「新遊戲」。

------------------------------------------------------------
七、已知問題（不用回報）
------------------------------------------------------------
  ・音樂和音效是程式產生的暫代版本。
  ・角色和部分美術是暫代圖，之後會由美術重畫。
  ・手機、平板還不能玩（沒有觸控操作）。
  ・手機訊息和帳目紀錄會保留「當時」的語言，切換語言後舊紀錄不會跟著變。
  ・中文翻譯還沒經過編輯校稿；簡體中文是自動轉換的。
  ・遊戲裡的加密貨幣只是模擬，沒有連接任何真實錢包或金流。


============================================================
CITY VENTURE — Test build {VERSION} ({DATE})  ·  English
============================================================
Thanks for testing! This build plays Chapters 1–6: start an online shop, earn your first dollar, register a
company, close a month, hire staff, land Crestline's big contract and survive the cash crunch. Also playable:
part-time jobs, freelance consulting and a SaaS product.

NEW IN THIS BUILD: step-by-step tutorial card and a gold guide arrow to your goal · glowing EXIT mats and
street-edge signs · autosave on every scene change, every 15 s and when the tab/window closes (web: refresh,
then Continue) · 5 part-time jobs with promotions and perks (Business Board → Part-time jobs) and freelance
consulting gigs (Company OS → Freelance) · garbled-text fixes (NPC "Jun" shown as a month, tiny name tags,
the café menu board, missing glyphs on the web).

START
  Windows 10/11: unzip first, then run CityVenture.exe. If "Windows protected your PC" appears,
    click "More info" → "Run anyway" (the test build isn't code-signed yet).
  macOS 11+: unzip, move "CITY VENTURE.app" to Applications, right-click → Open → Open.
    If it says it can't be opened: System Settings → Privacy & Security → "Open Anyway".
    Last resort (Terminal): xattr -dr com.apple.quarantine "/Applications/CITY VENTURE.app"
    (The Mac build has not been tested on a real Mac yet.)
  Linux: ./CityVenture.x86_64 (chmod +x if needed).   Web: open the link you were given in desktop Chrome/Edge/Firefox.

CONTROLS
  WASD/arrows move (Shift runs) · E/Space interact (or click the prompt) · Tab phone · M map · Esc pause/close
  The Phone / Map / Menu buttons at the top right can be clicked too. Skip or replay the tutorial in the pause menu.
  Hold T to fast-forward · F12 report a problem (web: Esc → Report a problem)
  Language: bottom-right of the main menu, or in the pause menu.

REPORTING
  Press F12 when something goes wrong. The game saves a screenshot, your save and the log, and opens
  the folder. Write what happened at the bottom of info.txt, zip the folder and send it to whoever
  invited you. The game autosaves; Continue on the main menu picks up where you were. Saves: Windows %APPDATA%\CityVenture · macOS ~/Library/Application Support/CityVenture ·
  Linux ~/.local/share/CityVenture.

KNOWN ISSUES: placeholder (generated) music and sound · placeholder character art · no touch controls · old messages keep the
language they were written in · translations not yet proofread.
