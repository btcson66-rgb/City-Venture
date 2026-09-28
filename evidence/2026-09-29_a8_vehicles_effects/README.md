# A8 車輛與特效（2026-09-29）

重畫 19 張既有車輛圖，保留側／前／後尺寸與 body/detail 分層。車身維持純灰階供 Godot 染色；玻璃、輪框、車燈、計程車燈箱和公車乘客剪影留在不染色細節層。捷運列車保留銀色車身與紅色腰帶。

重畫五張既有特效，光暈、影子皆以透明漸層淡出；新增 `effects/water_sparkle.png`（64×8，四格各 16×8）及 Godot import metadata。新特效目前是供 Claude 線接入河面與港區的美術素材，未改遊戲腳本。

`vehicles_before_after.png` 顯示九種分層組合前後對照，`effects_dark_preview.png` 是深色背景預覽；`screenshots/` 留下五張實機車流與夜間畫面。

驗收：Godot 匯入成功，67/67 單元測試，28 張截圖巡禮 0 failure，`wiki_check: OK`；19 張車輛數量、灰階 body 與 `water_sparkle` 尺寸另有靜態核對。執行紀錄見 `import.txt`、`tests.txt`、`shots.txt`。

剩餘事項：`water_sparkle` 的隨機散佈與動畫播放由 Claude 線按既有水面系統接線。
