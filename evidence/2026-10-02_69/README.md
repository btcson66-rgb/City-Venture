# #69 Energy evidence (2026-10-02)

- `unit-tests.log` / `junit.xml`: full suite, 362/362 pass (20 in `test_energy.gd`: opening gates and world data, shading/orientation/load/yield math, quote-install-invoice with crew capacity and segment totals, weather and late penalty, subsidy flow/quota/rejection/policy decay/season, quota release on cancel, warranty claim accounting and dispute, storage certification, charger demand vs adoption/price/capacity and the optional dealership hook, network build/deals/ops/failure/street props, own-property and Helio lot deals, loan and grant financing, six two-choice crises with decaying effects, save/old save/company closure, own rooftop array, Roof Survey and map UI, new facades and street-scene chargers).
- `balance.log` / `energy_balance_120.json`: 120 days x 3 strategies x seeds 69001-69003, QA equity $60,000. Ledger balance and segment-vs-company totals are checked every day; no seed removed.

| Strategy | Mean profit | Min | Max | Losing seeds |
|---|---|---|---|---|
| Conservative (homes only, 30% margin, no staff) | $15,005 | $5,307 | $24,425 | 0/3 |
| Normal (one electrician, 24% margin, subsidies, batteries) | $1,630 | -$6,594 | $8,150 | 1/3 |
| Aggressive (two electricians, 18% margin, financed charging stations) | -$22,396 | -$41,154 | -$11,660 | 3/3 |

Conservative is the only profitable strategy on average and its worst seed earns a third of its best, driven by lead volume, typhoon claims and late-delivery penalties. Aggressive is a documented tuning concern: charging stations do not repay inside 120 days at 5-7% adoption.
No screenshots were captured (rendering skipped); the walkthrough `_energy` segment was added but not run rendered.
