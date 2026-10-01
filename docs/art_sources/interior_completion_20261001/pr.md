Threadline and several civic/home interiors still mixed polished furniture with flat placeholder racks, fitting rooms, lockers, mirrors, notice boards and framed art. This batch replaces 25 fixtures and eight floor pairs with consistent cream/oak/navy/brass art, including neutral dye-ready mannequins and paired day/night skyline windows. Actual before/after Godot screenshots show the retail changes.

68 native/detail PNG plus import files; all existing logical sizes preserved. Seven original generated floor tiles are repeated to exact 4x dimensions while preserving the current pattern scale. Adds server indicator emission separately. Only assets, art packing/QA, wiki and evidence changed. No scripts/data/tests edits.

Validation:
- Godot headless import: exit 0, no errors.
- Last test line: `251/251 tests passed in 16.4s`.
- Screenshot tour: 53 screenshots / 63 steps / 0 failures; English audit 0. Final post-correction tour recorded in evidence.
- `interior_art_check`: 68 PNG/import, footprints and exact 4x, neutral tint and isolated emission: OK.
- `wiki_check: OK (1641 assets, 191 data ids)`.
- Pose/map checks N/A: no character sheet or map edits.
- Evidence: evidence/20261001_interior_completion/README.md, before/after screenshots, comparisons and logs.
- Full story walkthrough not run; remains Draft.

Claude handoff:
- Overlay localized location text within the six blank interior identity plaques: logo_bloom, logo_bytebean, logo_city_hall, logo_cowork, logo_nexus_bank, logo_postpoint. Art contains no baked text.
- Stock box stack rendering in Interior.refresh_stock still loads the native box through Art.tex; connect detail with logical scaling.
- Other character/traffic/street Draft PRs are not integrated here. This batch does not claim all-game visual acceptance.

交件檢查表：
- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（原尺寸未變；高解析修正到 4x）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（251/251 tests passed in 16.4s）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（N/A）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過（N/A）
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明

