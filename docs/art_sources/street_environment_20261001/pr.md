玩家常見的立面仍有平貼式窗框，街道公共物件缺少高解析細節。本批精修 7 種立面和 13 種街道物件：公寓、银行、玻璃辦公室、咖啡店、背景大樓，以及三種樹、兩種路燈、座椅、戶外桌椅、花槽、自行車和綠籬。維持左上光源、藍灰玻璃和暖色材質，招牌／旗幟無文字與品牌。

從最新 Claude `a57c87a9` pull 開獨立分支；只修改美術、metadata、工具、wiki、證據。交 58 個原尺寸／4× PNG及 import，包含獨立暖色光罩。原 PNG 尺寸保持；門位、空白招牌與路燈 glow metadata 已對齊新圖。沒有改 scripts / data / tests，沒有移動地磚。

實機對比在 `evidence/20261001_street_environment/`：before/after 各 53 張、63 步，三街區日夜另有 6 張現有渲染器實拍。隨機行人與車流位置可能不同。素材預覽不是實機證據。

驗證：Godot 4.5.1 import exit 0；`228/228 tests passed in 17.0s`；`BOT FINISHED — 0 failure(s) · 51.6s real`；英文審核0；`wiki_check: OK (1644 assets, 191 data ids)`；`map_label_check: OK`；`street_environment_check: 20 originals; 58 PNG/import pairs; 4x, footprints, door/sign bounds and emission-only checks: OK`。角色未修改，pose_check不適用。首次乾淨匯入在字型階段提早結束，重試成功，保留全部原始輸出。

Claude 接線：District與主選單建築仍用原尺寸；4×立面已交，接線需保持原邏輯寬高、門、招牌、光罩和影子，不得將高解析像素當碰撞尺寸。原尺寸替換已在實機顯示；props由現有WorldScene自動讀4×。本批不混入角色PR #46或車流PR #49。

全遊戲美術優化仍進行中，剩餘街道工具、立面、地材、室內、角色與UI逐項驗收，沒有宣稱全部完成。完整故事walkthrough未執行，保持Draft。

交件檢查表：
- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）；附美術工具、wiki與證據
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（原尺寸保持；door/sign/glow metadata已同步）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（最後一行如上）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（不適用）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過（未改地圖，額外執行通過）
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
