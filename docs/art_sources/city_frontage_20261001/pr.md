19 city buildings still used old facades beside the renewed art. This batch supplies consistent warm limestone/terracotta/oak, navy glazing, foliage and blank program-lettered storefronts for the remaining river, civic, office, retail and transit buildings. Actual Godot before/after screenshots show Threadline, bistro, coworking and city hall improvements.

76 native/detail body/light PNG with import files. Native dimensions and district placements preserved; door/sign metadata aligned to new art. Independent masks use only inspected lit window/lamp regions, exclude sign panels and avoid cool resampling fringes. The financial tower was separately revised to restore its slender silhouette.

Only assets/metadata, art packing/QA, wiki and evidence changed; no game scripts/data/tests edits. Other pending art PRs are not integrated here.

Five targeted actual district night captures exposed additive window clipping; final masks use 40% alpha and QA caps alpha at 103 to retain warm interior detail.

Validation:
- Godot imports: exit 0, no errors.
- Last unit line: `251/251 tests passed in 17.3s`.
- Screenshot tour: 53 screenshots / 63 steps / 0 failures, English audit 0. Final emission correction is retested and preserved in evidence.
- `city_frontage_check`: 19 originals / 76 PNG/import, exact 4x, footprints, door/sign bounds and emission OK.
- `wiki_check: OK (1649 assets, 191 data ids)`.
- `map_label_check: OK`; pose check N/A.
- evidence/20261001_city_frontage/README.md has actual comparisons and logs.
- Full 40–60 minute story walkthrough not run; remains Draft.

Claude handoff:
- District and main-menu building rendering currently selects native textures. Add world_detail body and corresponding light lookup, rendered at logical 0.25 scale; preserve metadata, positions, collisions, y-sorting and doors.
- Add a program overlaid metro identifier on the blank panel if the metro renderer bypasses building sign metadata.
- No claim of complete all-game optimization or combined runtime acceptance of separate unmerged art Drafts.

交件檢查表：
- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（原尺寸不變；door/sign 位置已更新）
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（251/251 tests passed in 17.3s）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過（N/A）
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
