This refines the existing navy UI surface system and makes its art editable at both native and 4× resolution. It includes 43 semantic SVG icons, 23 panel/button/tab/bar/frame SVGs and a fixed-slot icon atlas: 67 native + 67 detail PNG/import pairs. Dimensions, UI meaning, atlas order and content openings are preserved; sleep uses a bed pictogram rather than painted letters.

Fresh branch from latest `claude/exciting-bardeen-y71ixv` at `9145015`, pulled first. No game scripts, data, tests, autoload, fonts or app-identity icons changed. Includes direct SVG render tooling, hashes, original-size/atlas/alpha QA, actual 21-state UIK gallery and screenshot-tour before/after evidence.

Validation: import exit 0/no errors; `251/251 tests passed in 15.6s`; `BOT FINISHED — 0 failure(s) · 50.7s real` (53 screenshots, 63 steps); English audit 0; wiki_check OK (1680 assets, 191 data ids); ui_quality_check OK (134 PNG/import files, sizes, 43 atlas slots and transparent phone/portrait openings). Pose and map QA N/A: no character/map edits.

Claude handoff: integrate 4× icons using fixed logical rectangles; preserve phone/portrait dimensions. For high-resolution StyleBoxTextures, physical slice margins and logical border/content sizes must be handled together, rather than only replacing texture paths. Existing renderer immediately loads the new native assets; high-resolution source review is separate from actual game acceptance. Full zh_TW story walkthrough not run; retain Draft. Other art batches and remaining categories need integrated quality review.

交件檢查表：

- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（N/A：尺寸／格位不變）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（251/251 tests passed in 15.6s）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（N/A）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過（N/A）
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
