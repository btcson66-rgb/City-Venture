# #181 Maya hiring evidence

Stack: #182 / Draft PR #183; target `claude/exciting-bardeen-y71ixv`.

Godot **4.5.1 f62fdbde1**, native OpenGL, QA saves/preferences isolated in each output folder. Before: existing assistant tour 0 failures / 3.2 seconds. After: `--bot=assistant`, seed154, explicit paid-stock / customer-order fixture plus real UI packing, courier pickup, hiring, expansion, selected automation, dismissal, retainer pause/resume and genuine played predecessor save load. These screenshots are rendered game output, not design mocks.

| Gate | Result |
|---|---|
| Entire unit suite | 1026/1026, 466.4 seconds; no script/parse errors |
| Assistant lifecycle / existing assistant targeted tests | 37/37, 54.9 seconds |
| zh_TW translation | 8359/8359, 0 missing |
| wiki / beta / whitespace | OK / 0 hits / pass |
| Final desktop zh_TW / English | Each 0 failures, 1280×720 |
| Final portrait large zh_TW / English | Each 0 failures, actual rendered 390×844, font3, touch layout |
| Full story 1–24 + independent industries | RUNNING; no completion claimed |

Commands: `Godot_v4.5.1-stable_win64_console.exe --path game --resolution 1280x720 -- --bot=assistant --lang=zh_TW --out=<isolated output> --quit`; portrait adds `--resolution 390x844 --qa-touch --qa-font=3`. The QA touch entry selects the same expand aspect as Web touch initialization. Native tours still use mouse input; real Web/device touch is not established here.

Compare `before/01_assistant_settings_new_game.jpg` (already enabled without hire) against `after/desktop-zh/04_maya_hiring_profile.jpg`, `05_maya_joins_happy.jpg`, `06_maya_player_selected_chores.jpg`, and `07_maya_next_parcel_automated.jpg`. Pause and genuine old-save states are shots09–11. Review both `game-feel-before.md` and `game-feel-after.md` for per-principle findings and inherited HUD limits.

R4: only actual paid inventory/customer orders produce revenue. Joining, expansion and weekly fees post personal payroll expense; no numerical business bonus. Saved explicit dismissal is authoritative. Existing enabled predecessor choices/tier are adopted without moving cash and with seven days grace. No art/district/building/exit-area source is changed.
