# itch.io 網頁測試版發佈

使用現有 `tools/release/publish_itch.sh`；此腳本已用於 0.1.9，請勿另寫替代腳本。下列操作由專案擁有者執行；開發 PR 不會自行上傳。

1. 在 itch.io 建立／開啟遊戲專案，選擇 HTML5，將可見性設為 Restricted（受限），以密碼或私密連結邀請測試者。先確認測試者能開啟頁面，再公開邀請連結。
2. 在帳號 Settings → API keys 建立 API key。只放在執行環境的 `BUTLER_API_KEY`，不要放進 repo、文件、截圖或終端輸出。先在自己的環境安全設定，再執行下列指令。
3. 在專案根目錄執行 `bash tools/package_release.sh`。確認單元測試與四平台包成功，`dist/CityVenture-<版本>-Web.zip` 的根目錄有 `index.html`；以 `dist/SHA256SUMS.txt` 記錄實際上傳檔案。
4. 執行 `bash tools/release/publish_itch.sh`。現有腳本從 `project.godot` 讀版本，以 butler 推送到 html5 channel，並以 `--userversion` 標記版本。需要 Windows 包時才加 `--windows`。腳本中的專案設定沿用既有設定，別在新文件複製任何帳號或金鑰。
5. 第一次推送 html5 channel 後，在遊戲 Edit 頁勾選「This file will be played in the browser」。移除被取代的手動上傳項目，之後持續更新同一個 html5 upload，不另建新遊戲頁面。
6. 在受限頁面試「新遊戲 → 存檔 → 重新整理 → 繼續」，並匯入上一版本的實際存檔、閱讀本次更新。確認無缺字、內容不溢出、可正常操作，再把私密連結／密碼交給受邀測試者。

現有腳本會在缺少 butler 時下載 Linux 版至使用者快取。Windows 使用者請先從官方 https://itch.io/docs/butler/ 安裝適用的 butler 並加入 PATH，或在 Linux／WSL 執行現有腳本。API key 未設定時腳本直接停止，不會推送。

Web preset 使用 `variant/thread_support=false`。不需要 SharedArrayBuffer，因此不要勾選 SharedArrayBuffer support；若未來改為多執行緒，必須重新驗證 itch.io iframe 的跨來源隔離設定。`package_release.sh` 已將 Web 檔案放在 ZIP 根目錄，沿用現有打包流程。

## 存檔與更新內容

網頁存檔存在同一台電腦、同一個瀏覽器及同一個網站來源的 IndexedDB。更新同一頁面通常會保留存檔；無痕模式、清除資料、換瀏覽器／電腦、或來源改變都可能失去該儲存空間。發版前與清除資料前，先用「匯出存檔」備份 `.cvsave` 到瀏覽器以外；需要時「匯入存檔」繼續。

讀取舊版存檔進入城市後會顯示「本次更新」，只列出存檔版本之後、目前版本以前的更新。關閉卡片才記錄目前版本並存檔，同一局下次不重複顯示；新遊戲不顯示。更新內容為 `game/data/help/patch_notes.json` 的英文資料及繁中翻譯。

官方參考：[HTML5 上傳格式與 ZIP 限制](https://itch.io/docs/creators/html5)、[受限專案與存取控制](https://itch.io/docs/creators/access-control)、[butler 使用方式](https://itch.io/docs/butler/)。
