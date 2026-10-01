Outdoor ground previously used coarse flat/noisy tiles. This replaces 28 outdoor atlas cells with restrained asphalt, limestone paving, grass and water materials plus editable marking, curb, wood-board, cobble and quay geometry. Native ground replacements load immediately in the existing renderer; the 4× atlas is supplied separately.

Fresh branch from latest `claude/exciting-bardeen-y71ixv` at `9145015`, pulled before production. All 43 coordinates and atlas dimensions are unchanged; 15 interior cells and five unused cells retain identical pixels at both resolutions. No game scripts, data, tests, autoload or gameplay changes. Sources, prompts, SVGs, hashes and repeat reviews included.

Validation: headless import exit 0/no errors; `251/251 tests passed in 15.6s`; `BOT FINISHED — 0 failure(s) · 50.8s real` (53 screenshots, 63 steps); English audit 0; wiki_check OK (1613 assets, 191 data ids); map_label_check OK. Atlas QA verifies coordinates, unaffected pixels, opacity and bounded low-contrast material-edge deltas. Includes seven districts × day/night real captures and tour before/after comparisons. Pose QA N/A: no character edits.

Claude handoff: WorldScene.tileset still reads native atlas with 16px regions. Integrate the 4× atlas using the same 16×16 logical footprint and navigation/collision coordinates; simply swapping texture without projection changes would read the wrong cells. Ground material repeat review is a source review, not proof of high-resolution in-game integration. Full zh_TW story walkthrough not run; keep Draft, do not merge. Whole-game art optimization remains pending integration and remaining asset categories.

交件檢查表：

- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（N/A：尺寸／格位不變）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（251/251 tests passed in 15.6s）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（N/A）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
