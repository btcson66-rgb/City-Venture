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
