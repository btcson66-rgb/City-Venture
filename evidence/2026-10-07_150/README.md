# #150 relaxed work, optional challenge tips

Stack parent: #149 / 623cb610. Godot 4.5.1 console, Windows OpenGL, 1280x720. QA APPDATA is
`D:/City-Venture-fun-first-qa`; saves are under each bot output, separate from player saves. JPG quality 85.

Before game-feel-review: coffee starts a live queue immediately after the new safe lesson; guests expire while the
player reads or prepares another drink. `before` preserves two matched screens and the baseline result's one failure
(waiting ends the shift). That failure is evidence of the old behavior, not an acceptance pass.

After game-feel-review: the default is relaxed. Read, choose, serve, deliver and clean at any pace. A real 65-second
wait plus a very large simulated frame preserves all three guests, zero completed rounds and zero score. The player
intentionally prepares a wrong espresso amount, receives a quiet instruction, fixes the same cup and completes six
orders. Normal wages/tips are posted through the existing Careers Ledger entry; game time advances by the scheduled
shift, not the wall-clock test duration. A recovered cup keeps full quality and costs only one small tip reduction.

## Pressure inventory (all 15 MiniGame classes)

| Game | Before | After |
|---|---|---|
| Barista | Every queued guest ages, leaves after patience; fast/slow tips; timeout loses a round | Guests never leave; accuracy score; normal tip $2/cup, retry at most $0.25; challenge 60s window adds $0.50 only |
| Parcel sort | Shrinking 6..3.2s deadline, lost parcels, speed-weighted score; guide disappears | No default clock; guide remains; accuracy score; optional clock expires only bonus |
| Teller cash | 32s deadline, timeout awards zero | Untimed default; expiry keeps current task/quality; extra challenge tips only |
| Cowork host | 22s deadline, timeout awards zero | Same relaxed/bonus behavior |
| Personal request | Configured deadline and fatigue multiplier shorten response window | No default clock; optional expiry keeps choices; fatigue never accelerates it |
| Creative pitch | Configured 15s clock, inherited zero-point timeout | No default clock; optional clock leaves choices and score intact |
| Pop-up checkout | 20s clock, inherited zero-point timeout | No default clock; optional clock cannot discard sale or reduce quality |
| Typing | CPM/140 speed multiplier; fatigue acceleration; red wrong-key flash | Accuracy only, gentle sky hint; no typing stopwatch |
| Photo shoot | Oscillating focus needle affects listing quality | No default needle display; framing/light determine quality; optional needle never lowers listing quality |
| Auction | Automatic poll steps can settle while reading | Relaxed steps only when player requests another bidder response; opt-in challenge retains automatic polling |
| Clerk forms | No deadline | Untimed; no added pressure |
| Pack | No deadline | Untimed; no added pressure |
| Route | No deadline | Untimed; no added pressure |
| Fundraising pitch | No deadline | Untimed; no added pressure |
| Consulting (four kinds) | No deadline | Untimed; no added pressure |

No combo-reset mechanics were found in these classes. Money is not fabricated for non-wage minigames: the shared
bonus applies only to paid job shifts. Clock-only choices for other games do not change their quality/rewards.
Obsolete coffee patience/fast/slow tip values were removed from workflows.json; mode tunings live in work_modes.json.
Help/glossary describe waiting and accuracy, without promising income from speed. Existing real game schedules remain.

## F1–F8

| Principle | Before -> after / evidence |
|---|---|
| F1 | PASS -> PASS: first safe lesson, 18 lesson fixtures, replay/skip/save tests inherited and repeated |
| F2 | FAIL -> PASS: actual slow coffee shift; arbitrary-wait test for every class; optional saved default |
| F3 | N/A: no unlock/tab redesign |
| F4 | PASS: one primary next action; secondary mode selection on compact start card |
| F5 | N/A: no management automation |
| F6 | PASS within scope: short start card and quiet mode row; no new long prose panels |
| F7 | PARTIAL -> PASS within work: retry same cup/destination, no guest expiry, old preferences default relaxed, Ledger balanced |
| F8 | PASS: sky retry hint, low-volume success sound, small rising feedback; reduce-motion skips movement |

Novice: takes a coffee job from a new game; the manager invites one guided order. The highlighted steps teach the
sequence. Reading and waiting do not lose customers. A wrong cup explains which ingredient to change. Six completed
orders give normal wages and count as a successful shift.

Experienced: seen lessons open the compact card, ? can replay, skip returns to active work. The device default is saved
in existing settings.cfg; a start-card switch changes only that session. Tests preserve legacy missing keys and save/load
lesson state. Protected phone files and Company OS tabs are untouched. Shared MiniGame and Preferences changes are
limited to this behavior; no economy or management redesign.

## Validation

Full unit suite: **936/936**, 379.2s; no script errors. Two existing packed-save decompression diagnostics remain while
their tests pass (also present in #148–#149). New work-mode tests cover indefinite waits, equal base wages/reviews/normal
tips, challenge tips only, recovered wrong cup/destination, expired challenge and saved default. Fatigue's old acceleration
assertion was replaced with the fun-first invariant. Existing formal timeout tests now require a playable same task.

i18n: **8189 translated, zh_TW missing 0**. wiki_check: OK (3913 assets,343 ids). beta_audit: 0 hits.
Rendered en and zh_TW touch/large tours complete without flow failures; slow default and touch tours complete the actual
coffee shift. Final slow desktop: 0 failures, 76 captures, English audit 0, actual payout $79.75 ($68 wages + $12 normal
tips - $0.25 single retry reduction). Scheduled work is 240 game minutes; the normal world clock resumes during the
result fade and adds one minute. EN: 0 failures; touch/large zh_TW: 0 failures, English audit 0. Final accepted results,
audits and payout evidence are alongside the captures. Challenge/touch also verifies a correct cup gives $2 normal
tips plus $0.50 optional bonus, and expired bonuses keep remaining guests. Self-review keeps only the latest transient
feedback to avoid overlapping text. Shared ui_root.gd changes one wage-toast formatting line to retain cents.
Physical phone hardware is not tested. The final new-game main-story walkthrough is NOT a passing gate: chapters
1–24 completed but the manual logistics bot confused practice with formal work, causing cascading tour failures.
The bot now completes first-use lessons before formal inputs (route, creative pitch, personal requests). A corrected
Harbor rerun is recorded separately. The earlier customer-return decision and later fixture movement also failed;
these remain explicit full-tour gaps rather than being called no-soft-lock evidence.

Commands: `godot --headless --path game res://tests/test_runner.tscn`;
`godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=work_modes --lang=zh_TW --slow-work --out=<QA>`;
repeat with `--practice-large` for emulated touch/extra-large font, or `--lang=en`;
`python tools/i18n_extract.py --check`, `python tools/wiki_check.py`, `python tools/beta_audit.py`.
Windows uses the installed console executable; `python` is used because the local python3 command is a launcher stub.
