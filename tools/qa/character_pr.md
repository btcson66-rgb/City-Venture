Changing the creator's skin tone previously replaced the polished default character with the old low-resolution layered model. This change gives every existing custom appearance the same complete layered art, with native and 4× PNG/import pairs, matching portraits, all five poses, and independent four-expression face layers.

Started from `claude/exciting-bardeen-y71ixv` at `e6accdb` in a fresh worktree and pulled before implementation. Includes generated material originals, editable SVG sources, prompts, crop manifests, SHA-256 inventory, and actual before/after creator captures. Six skin tones preserve all selected geometry; three presentations, four faces, eight hairstyles and nine existing outfit families are covered. Existing five shop outfits retain their data-defined stand-ins. Named NPC overrides remain intact.

Necessary cosmetic wiring is included in `Art.tex`, `CharacterRig` and the creator expression preview. No gameplay decisions, game/data or game/tests change. Expression frames are independent of walking frames; feet, collisions, save keys and logical sizes remain unchanged. This current creator repair therefore has three display-code changes; the first item of the old pure-art checklist is intentionally not checked.

Validation:
- Godot 4.5.1 headless import: exit 0, no errors.
- `227/227 tests passed in 15.1s`.
- Custom appearance regression: `8094 combinations; 1040 texture/pose checks; 0 failures`.
- `BOT FINISHED — 0 failure(s)`; 53 screenshots, 63 steps.
- `wiki_check: OK (2802 assets, 191 data ids)`.
- `pose_check: OK`; `map_label_check: OK` (maps unchanged).
- 1040 native + 1040 detail PNG/import pairs; 891 existing PNG logical dimensions unchanged.

Evidence: `evidence/20261001_character_customization/README.md`; compare `comparison_s2.png` and `comparison_s6.png`. There are six actual creator captures, 26 actual game-render option/expression/pose matrices and five custom-avatar captures in the real apartment. The apartment harness checks JSON appearance round trip; it does not claim a new disk-save playthrough. Visual review complements the checks; this PR does not claim every building or planned outfit is finished.

Integration handoff: none for this creator repair. The five shop stand-in choices and unimplemented future accessories remain under the existing Claude gameplay/data design. Draft only; do not merge automatically.

交件檢查表（原 backlog）：
- [ ] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests） — 本次修復包含上述必要顯示接線；沒有改 data / tests / 玩法。
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json — 原尺寸逐檔確認未改，三者無須變更。
- [x] godot --import 無錯誤
- [x] 單元測試全部通過（貼最後一行）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過 — 未動地圖，仍通過檢查。
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
