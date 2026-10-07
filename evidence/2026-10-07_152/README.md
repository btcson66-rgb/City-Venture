# #152 calm information

Game-feel-review before: gold unread help competes with next actions; a newcomer can read several explanations as urgent tasks. An experienced player sees repeated emphasis for information already understood.
After: help is a 10px neutral circle/i with a 24px input area, unread dot and subtle hover/focus; clicking/hover still reads the same glossary. Novice can focus on the main action; experienced player retains keyboard/touch help access.

| F | Before -> after (ticket scope) |
|---|---|
| F1 | PARTIAL -> PARTIAL; minigame practice is #149. |
| F2 | FAIL -> FAIL for inherited timed work; #150. |
| F3 | N/A; OS tab structure retained. |
| F4 | PASS; same next actions, no extra decision added. |
| F5 | N/A; no management mechanics changed. |
| F6 | PASS; explanations remain behind help. |
| F7 | PASS; read-state/click and balanced ledger regression tests; no saved key renamed. |
| F8 | FAIL -> PASS for information emphasis; current recovery/action emphasis retained. |

ui-calm-polish: desktop 1280×720 and emulated touch layout with extra-large text, en and zh_TW. Paired captures show OS overview, decision, HUD and actual major-injury accident. Panel bounds and reading/ledger checks pass. This is a Windows-rendered mobile layout, not a physical-phone test.

Full game C_GOLD search: 265 references inventoried in gold_inventory.json. Information/decoration changed to C_SKY; current action/recovery retained; palette constants, world art, tests and shared theme retained. Protected phone UI/messages are explicitly deferred to #153. Company OS changes are only colour substitutions; no tab changes. No gold artwork/assets rewritten. Other edits only substitute information colours, without simplifying systems.

Target tour: 0 failures, 16 screenshots per before/after run. Mixed-language audit includes English frames intentionally requested by this matrix; it is not a clean zh_TW-only audit. Extractor verifies every new string translated. Full regression and remaining gates are recorded below.

Validation: Godot 4.5.1 full suite 927/927 passed (448.2 seconds); no script errors. The log contains two decompression diagnostics in existing packed-save stress tests; both tests pass. i18n: 8078 translated, zh_TW missing 0. wiki_check: OK (3913 assets, 343 data ids). beta_audit: 0 hits. git diff --check: clean.
