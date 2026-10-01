# Interior completion quality — 2026-10-01

Base: 9145015, freshly pulled claude/exciting-bardeen-y71ixv.
Branch: codex/art-interior-completion-quality.

Before and after are actual Godot screenshot tours, 53 screenshots and 63 steps per tour. Comparisons use the same named locations; animation and NPC positions can differ. The contact sheet in docs/art_sources is an asset preview, not runtime acceptance.

Delivered 25 interior fixtures and eight floor pairs, plus isolated server indicator lights, all with native and exactly 4x PNG/import. The prior seven 768x768 detail floors did not match 512x320 native files; repeating the archived generated tiles produces 2048x1280 pairs without altering the existing visual period. All native footprints remain unchanged.

Validation:
- Baseline import and final new-art import: exit 0, no errors.
- test_runner: 251/251 tests passed in 16.4s.
- First after tour: BOT FINISHED — 0 failure(s) · 51.0s real; English audit 0.
- Final neutral mannequin revision: separate final-shots.log and after/walkthrough_result.json.
- interior_art_check: 68 PNG/import, native footprints unchanged, exact 4x, neutral mannequin and isolated indicator emission: OK.
- wiki_check: OK (1641 assets, 191 data ids).
- Character pose and map label checks: N/A, this batch changes neither character sheets nor maps.

Handoffs: program text on six blank interior identity plaques; high-resolution stock-box stacks use a separate Art.tex path and need Claude wiring. Existing add_prop and continuous-floor paths already load detail fixtures/floors. No full 40–60 minute story walkthrough was run; PR stays Draft. This batch does not establish complete whole-game visual quality or integrated acceptance of other unmerged art PRs.

