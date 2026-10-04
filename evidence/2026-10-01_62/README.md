# #62：4× 素材接線與打包大小

開工 2026-10-01，驗收 2026-10-02。資料夾以開工日命名。
分支 `codex/62-detail-art-wiring`。基底開工時 `cacf0b5f`，交件前已 merge 最新 `a2a8bdb26b20d57c811041ad153dc2c0fb0d8522`（含另一條線的 #73）；沒有 rebase。

`Art.tex()` / `Art.opt_tex()` 優先讀取同路徑 `world_detail/`，ImageTexture 保留完整像素並回報原圖邏輯尺寸。
背景平移、地圖座標、九宮格切邊、動畫格及點擊位置沿用原值。碰撞讀取原圖 alpha 遮罩。
直接指定 `world_detail/` 的既有程式仍取得實際尺寸。PNG 原稿未修改；4× 背景／地圖以品質 0.85 lossy WebP 匯入。
四平台 `exclude_filter` 僅剩 `tests/*`。

| 檢查 | 結果 | 證據 |
|---|---|---|
| Godot 4.5.1 完整單元測試 | 271/271 tests passed in 19.8s | `unit_tests.log` |
| 完整繁中 walkthrough，從新遊戲至 12 章結局、咖啡店、物流、存讀檔 | BOT FINISHED — 0 failure(s) · 2616.0s real | `verified_walkthrough.log`、`walkthrough/walkthrough_result.json` |
| 繁中翻譯 | missing 0，3053 msgids | `i18n.log` |
| Wiki | OK (3830 assets, 191 data ids) | `wiki.log` |
| 四平台 package_release.sh | exit 0 | `package_release.log`、`package_SHA256SUMS.txt`、`release_artifacts.json` |
| Web index.pck | 150659928 bytes / 150.66 MB ≤ 160 MB | `build_size.log` |
| Windows zip | 173718442 bytes / 173.72 MB ≤ 180 MB | `build_size.log` |
| 大小閘門邊界、缺檔、歧義測試 | 4/4，OK | `build_size_tests.log` |
| 直接讀取實際 Web pck | 10 類、150 張 detail 圖，0 failures | `packed_detail.log` |
| 原圖／4× 渲染比較 | 40 張 JPG，尺寸／點擊座標／真實滑鼠點擊 0 failures | `comparison/render_checks.json`、`render_review.log` |
| 實機 shots / screens / minigames | 53 / 10 / 28 張截圖，全數 0 failures | 各 log 與各目錄 result JSON |
| 英文稽核 | 新增玩家文字 0；新文字缺漏 0 | 原始 audit JSON、`english_audit_review.json` |

## 圖片

`comparison/` 每類各有原圖／4×，在 **1280×720** 和 **2560×1440** 兩種實際擷取尺寸下比較：
backdrops、cards、city_map（捷運底圖）、world_map、ui（面板／圖示／按鈕）、minigames、events、logos、products、effects。
這是透過遊戲 Art、UIK、Sprite2D 的受控渲染檢查；實際遊戲畫面另在 `runtime_shots/`、`screens/`、`minigames/`。
保留 10 張 1280×720 場景巡禮，以及各 4 張管理畫面／小遊戲。後兩類因原生視窗限制，實際擷取尺寸是 1886×1061，未放大成假 2560×1440。
完整 walkthrough 以 headless 執行，截圖數是 0；它的移動、互動、按鈕、存讀檔及 ledger 檢查仍完整執行。

## 英文稽核與存檔

保留原始稽核：walkthrough 23、screens 6、minigames 1、shots 0 筆標記。
逐項確認是既有人名／員工姓氏、品牌 Fresh+ Market、ShopLane、Glow Book、登記編號 AUR，以及語言自稱 English。
沒有新增玩家文字，也沒有把原始標記抹掉；逐項說明在 `english_audit_review.json`。
未修改存檔欄位、版本或遷移流程；完整單元測試包含既有舊檔遷移和 round-trip，bot 最後也成功存檔／讀回並確認帳本平衡。
所有新增 QA 按鈕有穩定名稱；產品沒有新增概念或畫面，glossary/help 卡無新增需求。

## 重跑

```text
godot --headless --path game --import
godot --headless --path game res://tests/test_runner.tscn
python3 tools/i18n_extract.py --check
python3 tools/wiki_check.py
python3 tools/qa/test_build_size_check.py
bash tools/package_release.sh
python3 tools/qa/build_size_check.py
godot --headless --main-pack build/web/index.pck --script tools/qa/packed_detail_probe.gd
godot --path game --script ../tools/qa/detail_art_review.gd -- --out=<output>
godot --headless --path game -- --bot=walkthrough --lang=zh_TW --out=<output>
```

Windows 實際使用已安裝的 Python 3.12.10、Godot 4.5.1 和 Git Bash；opencc-python-reimplemented 已安裝。
打包成品保留在此工作區的 ignored `build/`、`dist/`；repo 只保留雜湊、大小、JPG 與文字證據。
本張送 Draft PR，等待審閱／合併；#63 尚未開工。

## PR #74 記憶體審查修正

五類大圖共用最多 8 張的 LRU；其他小圖維持永久快取。新增三項回歸測試後為 274/274 全綠。
七個已實作街區巡禮的 RENDER_TEXTURE_MEM_USED：705,795,943 → 700,487,839 bytes。
巡禮後連讀 20 張背景：974,655,313 → 859,182,632 bytes；大圖快取 26 → 8 張。
完整量測方法、逐站數值與限制見 [memory_review/README.md](memory_review/README.md)。
