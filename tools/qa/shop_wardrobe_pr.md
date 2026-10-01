Five purchasable outfits previously reused recolored stand-ins. This adds distinct executive, long-coat, travel, evening and logistics garment materials on all three presentations, with five poses, walking sheets and matching collars. Tintable fabric and fixed-color details are separate; each of 370 logical keys has native and 4× PNG/import pairs.

Fresh branch from `claude/exciting-bardeen-y71ixv` at `9145015`, pulled before implementation. Includes transparent source originals, prompts, crop/fabric manifests, archived compatibility alpha masks, editable SVGs, rebuild tools, SHA-256 inventory and before/after evidence. No game scripts, data, tests or autoload changes.

Validation: import exit 0 with no errors; pose_check OK; wiki_check OK (2353 assets, 191 data ids). `BOT FINISHED — 0 failure(s) · 50.8s real`; 53 screenshots, 63 steps, English audit 0. 33 actual rig/portrait matrix pages cover six skins and three presentations, plus five retail captures. Art-palette previews and the candidate PR #46 composite previews are explicitly separate from current runtime evidence.

**Acceptance remains PARTIAL: `250/251 tests passed`.** The only failure is the obsolete `test_shop_outfits_draw_as_stand_ins_until_their_art_exists`, which unconditionally requires stand-in assets before testing formal overrides. Tests were not modified. The current player also loses the stand-in default tint when formal art exists, so default game screenshots remain gray.

Claude handoff: apply `assets/outfit_palette.json` defaults in the formal-art branch of `_resolve_outfit`, with explicit NPC/pedestrian tint overrides; keep shoe/detail modulation white. Update the obsolete test to cover both missing-art fallback and formal-art replacement. High-resolution custom-layer selection and independent expressions depend on PR #46. Full story walkthrough not run; retain Draft, do not merge.

交件檢查表：

- [x] 只動了美術檔和美術 metadata（沒有動 scripts / data / tests）
- [x] 沒有改舊檔名；新檔名照 wiki 命名規則
- [x] 尺寸變了的都更新了 buildings_meta / sprite_meta / atlas.json（N/A：logical size 不變）
- [x] godot --import 無錯誤
- [ ] 單元測試全部通過（250/251，舊暫代測試失敗，見上方）
- [x] --bot=shots 截圖巡禮 0 失敗
- [x] python3 tools/wiki_check.py 通過
- [x] 有動角色圖時：python3 tools/qa/pose_check.py 通過
- [x] 有動地圖時：python3 tools/qa/map_label_check.py 通過（N/A：未改地圖）
- [x] evidence/<日期>_<批次>/ 有改前/改後對比和 README
- [x] wiki 對應條目的「美術」狀態已更新
- [x] 需要程式接線的項目已列在 PR 說明
