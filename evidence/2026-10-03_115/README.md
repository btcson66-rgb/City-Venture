# #115 Traffic safety self-review

Implemented: actual-speed collision grades and swept body contact; existing braking plus protected green marked crosswalks; clock-backed signal discs and HUD guidance. Minor injury temporarily slows movement and can be treated with purchased medicine; major injuries use the persistent ambulance router and an enterable Civic Center clinic with Dr. Lin. Admission advances 1–3 real simulation days, preserving existing scheduled collections and living/business ticks. All new tunable gameplay coefficients live in `traffic_safety.json`.

Personal health policies cost $90 per 30 days and cover 85% of incurred medical costs only when already active at impact. Medical provider bills, claims, cash payments, emergency payables and counterparty reimbursements use balanced journal entries with accident IDs. Counterparty fault excludes red crosswalks. The player can accept 75% of the uninsured bill or file for full reimbursement after seven days. Neither choice duplicates health coverage. Missing cash expires automatic renewal; medicine requires its out-of-pocket cash. Past debts and claims remain addressable after another collision. A later glancing contact cannot hide an earlier injury. New help card and glossary explain the policy.

## Validation
- Full unit gate: 523/523 tests passed in 146.1s (`unit-tests.log`); 16 new traffic tests plus existing suite. The sole stderr warning is the existing test that deliberately dispatches unknown `eco.missing`.
- Rendered Chinese short tour: 0 failures, 3.8 seconds; 8 screenshots; 0 English audit entries. Existing car geometry/speed is positioned explicitly for deterministic contact; this is a real world collision and real UI flow, not natural traffic-frequency measurement.
- `traffic_balance_120.json`: 9 runs, 120 decision days per strategy/seed; hospitalization adds actual elapsed time recorded per run. Actual existing consulting work generates all operating income. No money injection or free daily revenue. Scripted exposure is a test scenario, not a measured accident rate. Conservative/normal/aggressive mean net profit: $4,231.73 / $8,411.67 / -$22,697.00, respectively; every strategy has losing days; 0 ledger/balance failures.
- `legacy-played-save-result.json` and receipt: the genuinely played #114 full-story save loads through SaveSystem. Ledger unchanged; default injury absent; balanced. Source compressed save remains in #114 evidence; SHA identifies the unmodified decompressed input.
- Translation extraction missing 0; wiki coverage OK; beta audit 0; diff whitespace clean.
- Final screenshot size: about 0.90 MB of JPG at quality 85, below 20 MB.

## Self-review fixes
- Ambulance coroutine moved to the persistent router so freeing the originating modal cannot cancel admission.
- Accident IDs keep the active injury separate from later glancing contacts and expose historical debts/claims.
- No retroactive policy purchase, duplicate treatment, duplicate settlement, pre-expense compensation, or missing-cash medicine.
- Emergency care preserves unpaid balances instead of forgiving a bill or preventing treatment.
- Cars stop while clock/UI is paused; swept body geometry covers contacts beyond only the vehicle front.
- New clinic actions registered to existing civic/bank icons; no art changed. Screen has one useful primary, explanatory ✓/✗ states, help and glossary.

## Explicit boundaries
#94 and #96 remain unmerged. `driver_quote` is the requested pure driver-liability/coverage hook; actual driving and accident journaling belong to #94. The seven-day claim is an independent administrative workflow, not an assertion that #96's legal system exists. Hospital interior deliberately reuses the existing civic facade/interior assets; no custom hospital art is included. Personal bills belong to the player after company closure. No release, merge or production action was performed. #116 remains dependency-blocked while #95 is OPEN.
