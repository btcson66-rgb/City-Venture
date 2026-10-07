# #153 notification center

Before game-feel-review: opening Maya's thread interrupts with phone dialogue; bank messages offer confirmation,
deadline, meeting agenda and proactive templates. Seven captures preserve the baseline; the original phone tour
has four failures, not an acceptance pass. A bank invitation requires phone → messages → thread → reply → agenda
(five actions), besides actually travelling. Notification → Go should reduce it to two, with decisions in real screens.

Before F1 PARTIAL (prose help); F2 FAIL (reply countdown); F3 FAIL (many always-visible apps, owned by #151);
F4 FAIL (multiple message reply/template decisions); F5 FAIL (acknowledgements/rebooking chores); F6 FAIL (long
threads); F7 PARTIAL (expiry defaults can fail, requiring migration coverage); F8 PARTIAL (gold informational text).

Novice: reads a buzz, is pulled into dialogue, then sees deadlines and contact templates before learning the city.
Experienced: old pending offers and planned meetings must survive conversion without financial side effects.
Baseline Godot 4.5.1, Windows OpenGL, 1280x720, zh_TW, isolated APPDATA D:/City-Venture-notifications-qa.

Waiting-node inventory: chapter1 Maya phone gate; contract details/accept/decline; GroupJobs details/accept/decline;
bank appointment confirm/later/keep; overdue-loan extension; partner sign/exclusive/decline; board plan/advisor/votes;
EventEngine phone decisions; generic acknowledgements; custom legacy flag-only reply state. Main-story other choices
remain NPC conversations or EventEngine formal modals. No automatic financial reply effects are allowed in migration.

After game-feel-review: notifications → Go takes two actions (five before, excluding travel).
Reading chapter-one messages requires phone → notification center, with no conversation, selection or reply.
Work/Life/City filters and read-all are optional; sender/body/time remain a quiet single-row update.
New-order notices merge by business/day; payout receipts go directly to the timeline. HUD counts actions only.
Rendered phone tour: 0 failures, 0 untranslated on-screen strings, six after captures.
F1 PARTIAL: first-phone tutorial and replayable help exist; full safe single-target practice is inherited work.
F2 PASS: response deadlines and reply expiry removed. Optional old visits may lapse without penalties.
F3 PARTIAL: notification categories are available; phone apps are still inherited until #151.
F4 PASS: each actionable update has only Go; meaningful choices stay on their official screens.
F5 PASS for notification chores: no acknowledgement, confirm/rebook, cooldown or social reply bookkeeping.
F6 PASS: one body line with full detail tooltip, sender and timestamp; help has two short entries.
F7 PASS for targeted states: migration is idempotent, carries neutral flags, preserves formal queues/visits, never spends.
F8 PARTIAL: new update rows are quiet; existing gold info_tip icons belong to the other session (#152).
Novice: reads an update, follows Go, knows where the choice belongs and returns to exploring.
Experienced: read-all and category filters work; saved contract/board/partner choices remain in their formal screen.
Mobile physical-device experience and the complete main-story tour are NOT YET VERIFIED here; final-stack coverage pending.
Protected minigames and info_tip.gd were not changed. Shared ui_root only suppresses nonactionable toasts;
GameState/SaveSystem only prepare/store/migrate notifications. Bank extension moved to the existing loan card.

Validation: 913/913 unit methods passed (328.3 s); zh_TW 0 missing; wiki/beta/map adjacency and diff whitespace pass.
