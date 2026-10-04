# #41 Weekend pop-up evidence

- Unit suite: **614/614**, 212.8 seconds; 11 new popup tests.
- i18n: **6232/6232**, missing **0**. `wiki_check`: **OK**, 290 data IDs. `beta_audit`: **0 hits**.
- Rendered Traditional Chinese short tour: **0 failures**, 43 steps, 11 screenshots, 32.2 seconds. English audit retains language selector, beta version and player-created company name only.
- All images are JPG; evidence folder approximately 1.7 MB. No asset files changed.
- Self-review fixes: preserve original storage return capacity; pause home moves until goods return; forbid shared café/retail premises leases; staff cannot work two jobs simultaneously; reserve van occupancy before transport; isolate per-company schedule/state; idempotent hour/closing callback; old save lazy defaults; finite price and nonnegative stock guards; removed café controls during retail tenancy; repaired UTF-8 text and translated unit labels.
- Balance sensitivity: actual checkout/COGS/fees, nine seeded weekends. Owner averages $537.11; employee $249.11; expensive-price $925.13. Each strategy loses in controlled low-footfall case (2/hour versus configured 45/hour). These are fixture sensitivities, not a calibrated 120-day economy simulation; no owner opportunity cost is charged.
- `sales_revenue` in the report aliases canonical `Ledger.revenue`. Estimated ShopLane margin is never posted. All transactions balance.

## Open verification

Full rendered walkthrough `.qa-full41` was launched for the fifteenth Session B ticket, with daily traces and watchdog output. Its result is **PENDING**, not PASS. Earlier full #93 failed 58 checks; full #94 ended without a result and its exit cause remains unverified. These remain acceptance work before the final Session B closeout.

The dedicated art is recorded in the backlog; current interior uses existing shelf/box and cash-register/desk fallback plus a scheduled shopper. Short tour capital, purchased stock, controlled date jumps and automatic minigame quality are disclosed in the adjacent fixture capture note.

## Integrated follow-up

626/626 unit tests passed after merging #86. Industry introduction native tour: 41.8s, zero failures. Full rendered walkthrough completed in 7398.1s with 174 failures, 344 screenshots and 3175 steps; see full_result.json. First cascade: the pop-up fixture left the player in the shop while the following café chapter tried to sleep at home. Fixed by actual door exit, Metro and home entrance; rendered popup short tour 56.8s, zero failures, explicitly asserts the home handoff. Full acceptance remains FAILED until a corrected integrated run finishes.

## Trade integration and walkthrough regression review

Merged the completed #70 execution branch, retaining pop-up, overseas, company and crisis behavior. Integrated unit suite: **639/639**, 212.7 seconds; i18n **6430/6430**, missing 0; wiki 297 IDs; beta audit 0. Previous next-generation test failures were caused by persistent test slots; #92 tests now clear only their asserted `user://test_saves` game slots before each case, preserving the explicit full-slot test.

Rendered regression tours: bank exit **0 failures / 23.2 seconds**; chapters 13–14 **0 failures / 148.7 seconds**; chapters 15–16 **0 failures / 57.0 seconds**. A bank exit now walks around the existing queue barrier. Depleted inventory is replenished through actual wholesale purchases and courier delivery; wrong-code customs checks assert a new order and an actual hold before choosing documents. These are tour fixes, not fabricated inventory or chapter flags. Fresh integrated full walkthrough is RUNNING; prior full result remains FAILED until the new run finishes. Four regression JPGs bring this issue evidence to approximately 2.43 MB. English audit hits in these short tours are proper names, identifiers, language choice and the beta label.

## Home-invoice rejection follow-up

The second full run was stopped after a real buyer declined the home-currency quote. It recorded 74 failures and 32 script errors after the absent contract was polled; full-integrated-rerun-aborted.json preserves the failure. The tour now waits through the actual next-day cooldown and requests fresh quotes, with bounded retries and an explicit failed stop before touching absent contract controls. Dedicated adverse native seed 4 triggers the real rejection: **0 failures / 107.4 seconds**, including a successful fresh-day contract and actual shipment/payment. A new unit test proves no phantom contract/cash and no same-day reroll. Third full run is RUNNING. It is not a PASS.

## Queued crisis handoff review

Third full run reached the bridge crisis with eight native assertions/input failures and no script errors: the purchase handoff left a management layer open, so the queued crisis was delayed and the tour read its result too early. Raw failure log remains preserved. The tour now drains visible management screens through actual Close input before waiting for the queued crisis, and reuses an already-open Company OS rather than attempting blocked world movement.

A byte-for-byte automatic backup from the genuine full run is being replayed with load_and_enter, without fabricated company, cash, stock, clock or story flags. Chapters 10–12 replay has passed the actual bridge reroute and payment; later chapters and industry fixtures remain RUNNING. The earlier full result remains FAILED until final acceptance evidence is complete. Checkpoint identity and replay outcomes will be recorded after completion.
