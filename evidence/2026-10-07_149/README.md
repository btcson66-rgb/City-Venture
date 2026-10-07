# #149 guided first work

Before game-feel-review (parent 24db3122): the first coffee job shows dense prose and immediately starts the live queue. There is no safe demonstration of confirmation, choices, serving, delivery or cleanup. The baseline workflows tour has 24 failures, including unreachable lower controls and impatience; its screenshots/result are preserved honestly, not treated as an acceptance pass.

After: a short manager greeting opens the practice card automatically. The player presses eight highlighted controls, while other task buttons are locked/dimmed. No timer/score/pay callback runs. The ready button starts the original formal shift directly. A separate work scroll fixes lower machine/packing controls extending beyond the scroll range. All 15 classes use the same MiniGame framework; four consulting kinds have separate seen keys.

| Principle | Before -> after |
|---|---|
| F1 | FAIL -> PASS: every minigame has data and completes actual controls; first/second/replay/skip tests. |
| F2 | FAIL -> PARTIAL: practice is untimed; formal timing remains #150. |
| F3 | N/A: no unlock/tab redesign. |
| F4 | PARTIAL -> PASS within practice: one active target, visible skip. |
| F5 | N/A: no management automation. |
| F6 | FAIL -> PASS for start cards: goal, short controls, quality; one sentence per practice step. |
| F7 | PARTIAL -> PASS in practice: independent copy, safe wrong typing, no pay/rating callback, saved skip/seen state, replay preserves active work; formal waiting still #150. |
| F8 | PASS: neutral sky guidance; inactive task buttons dimmed. |

Novice (five lines): starts a new game at the coffee workplace and takes the job through JobModal. The manager invites one order together. The highlight explains what to press without external instructions. Cleanup leads directly into six formal orders. The real shift pays and counts toward promotion; no practice earnings are fabricated.

Experienced: a previously seen game opens the compact card directly; ? offers replay, and skip returns to the original work. A unit test verifies the active ticket and frozen timer survive replay. Continued saves lacking the new key offer practice lazily; save/load preserves completed/skip state.

Capture: Godot 4.5.1, Windows OpenGL compatibility, 1280x720, isolated APPDATA D:/City-Venture-fun-first-qa; bot practice, zh_TW and en, plus --practice-large (emulated touch/extra-large font). Each tour starts a new game. Physical phone hardware was not tested. First coffee steps 0..7, formal start/results/payout and every minigame's card/first target/readiness are included. JPG quality 85; evidence stays below 20 MB.

Targeted tours: 0 failures for zh_TW, en and zh_TW large; zh_TW English audits 0. Main story walkthrough will be repeated on the final #150 stack. Protected phone files and Company OS tab structure are untouched. Test updates mark lessons seen in existing formal-mechanics tests; separate tests exercise first-use practice directly, without autoplay.

Self-review fixes: hidden original work during replay prevents duplicate active controls; practice keys distinguish consulting kinds; real auction bid/step/settlement are blocked in practice; deep-copy nested order/request inputs; fix work-area content height so lower actions remain clickable. Existing finance/ledger/story/save gates are verified by the full suite below.

Final gates: 931/931 full unit tests passed in 354.1s; no script errors. Two decompression diagnostics occur in existing packed-save stress cases, whose tests pass. i18n zh_TW 8179 translated, 0 missing; wiki_check OK (3913 assets,343 ids); beta_audit 0 hits. Accepted new-player and experienced-player tour: 0 failures, 70 shots, English audit 0.
