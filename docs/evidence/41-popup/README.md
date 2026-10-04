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

## Actual insolvency recovery follow-up

Third fresh full run was stopped after its earlier eight bridge failures and a later insolvency modal cascade: the tour treated an open rescue/restructure/close choice as a completed company closure and repeatedly sought the absent StartOver button. Raw log and counted failures are preserved in full-third-aborted.json/log. This is FAILED, not a completed full pass. The real saved player had $38,366.98 personal cash; actual rescue used $11,717.52 existing funds. Native replay of that unmodified insolvent save: **0 failures, 3.1 seconds**, real Rescue button, live company, capital ledger and balanced books; no invented cash or gameplay changes.

The genuine chapter10 checkpoint replay reached chapter17 with zero observed failures or script errors and actual chapters10–16 complete. It was deliberately restarted at an unmodified automatic save after fixing the known later insolvency harness issue; checkpoint-prefix.log preserves the unfinished prefix rather than calling it a complete tour. The next continuation loads that exact chapter17 save, keeps the existing recorded niche response, and renders the remaining real operating days, epilogue and industry fixtures. Final continuation is RUNNING. The full fresh-single-run gate remains unresolved; segmented evidence will be labelled explicitly.

## Completed genuine continuation (not a fresh single full pass)

Source 9667176e completed resume_ch17 from the exact automatic save: **0 failures / 545 steps / 74 screenshots / 727.3 seconds**, no SCRIPT ERROR. The same continuous company history passed actual savings-funded rescue, chapters17–18, Maya conversation, all five epilogue cards, Growth, save/load and every story objective. Subsequent independent capitalized industry fixtures passed actual purchases, production, completed invoices, recalls, contracts and save/load. Those independent fixtures remain explicitly disclosed; they do not claim the story company ran all industries.

The earlier chapter10–16 replay is an unfinished, deliberately restarted prefix with zero observed assertion/script failures. genuine-checkpoints.zip contains both original byte-preserved automatic saves; source/hash/clock identity and the final continuation result are in genuine-checkpoints-source.json. This proves segmented rendered coverage, not a fresh single-run full result. A new source70a0bdd5 walkthrough covering chapters1–24 is running on the #99 tail; final full gate remains pending.

English audit has 30 hits. Proper names, brands, language selection and kg/kWh units are retained; three actual automotive prerequisite sentence leaks and roof compass directions were found, and a display-only repair is being rendered on original #86 branch. Do not call the entire English audit clean before that follow-up passes.

## Final stack review update

The genuine chapter17–18 continuation completed 0 failures / 727.3 seconds. Fresh #99-tail New Game chapters1–24 source70a0bdd5 subsequently completed 2 failures / 8021.9 seconds, no SCRIPT ERROR. Both are actual chapter-seven profit assertions (-$826.09); all other functional assertions passed, including the prior crisis handoff/rescue regressions. This is still FAILED. The original raw result/save is preserved on #99. Actual-price strategy correction is being rerun from New Game; no profit assertion or loss fallback has been removed.

Original #86 display follow-up passed 471/471 and native industries 0 failures / 357.9 seconds. It repairs automotive prerequisite sentences and all roof compass labels and has been merged here, regenerating both translation catalogues with 6439 missing0. Latest full unit suite passed 640/640 (230.5 seconds), no SCRIPT ERROR; the known unknown-dispatch warning is asserted by test_registry.

上游合併複驗（840fdf24）：全套單元645/645（308.7秒），相關短版0失敗／50步／12張原始擷取；兩者無SCRIPT ERROR。i18n missing0、wiki OK、beta0。保留兩邊新增內容與功能；整合新存檔完整第1–24章在f3618370已完成0失敗／3588步／8041.8秒；後續跨公司修正另以各分支全套單元與相關短版複驗，不宣稱完整流程跑在此新提交。
