# #67 Hotel / Tourism and Luxury Heights

## What is covered
Hotel module (`game/scripts/sim/hotel.gd`, Rate Board `game/scripts/ui/hotel_ui.gd`), the Luxury Heights district (M5), three buildings with interiors (`the_aster`, `skyline_grand`, `observation_deck`), NPCs Henri Dubois, Priya Nair, Owen Blake and Vera Stone with dialogue, six events (five crises plus the Vera Stone visit, each with at least two choices), staff roles `housekeeper` and `front_desk`, help/glossary cards, zh_TW (missing 0) and wiki (`docs/wiki/22_hotel.md`, wiki_check OK).

## Tests
`361/361` unit tests pass (`junit.xml`), including 19 in `game/tests/unit/test_hotel.gd`: opening gates and the data-driven district/guide/metro, lease route, full operating cycle with a balanced ledger and segment total, demand calendar, overbooking walk settlement, OTA commission accounting through Jobs, group blocks, review formula and the Vera Stone x5 weight, housekeeping capacity limit, equipment assets and renovation, all crises with decay, cancelled-event refunds, growth tiers, Media demand boost, own-cafe breakfast, save/load, old save without hotel state, company close, and single-primary-button checks on every Rate Board page.
The full rendered walkthrough was not run; an append-only `_hotel()` segment was added at the end of `game/tests/walkthrough/walkthrough.gd`.

## 120-day balance (`hotel_balance_120.json`, `hotel_balance_120.csv`)
Nine unfiltered runs: conservative (lease), normal (take over, dynamic prices, renovation, 4% overbooking) and aggressive (take over, +22% prices, direct-first, 10% overbooking, minimal staff, $395k equity to expand), seeds 67001-67003. Capital is QA equity, never income. Real takeover/lease, hiring, payroll, night audits, OTA statements, group blocks, Net 30 collection and naturally triggered crises. Every tenth day checks double-entry balance and segment totals against MonthClose.

| Strategy | Mean profit | Min | Max | Losing seeds | Worst 30-day window | Occupancy | Rating |
|---|---|---|---|---|---|---|---|
| Conservative | $12,495 | $10,254 | $14,365 | 0 of 3 | -$15,425 | 74% | 3.79 |
| Normal | $15,629 | $11,086 | $22,658 | 0 of 3 | -$4,730 | 62% | 3.83 |
| Aggressive | $5,415 | -$23,583 | $20,688 | 1 of 3 | -$12,512 | 33% | 3.11 |

Conservative and normal are profitable on average but every strategy shows a negative 30-day window, and the aggressive pricing gamble can lose (one seed collapsed to 20% occupancy after review and demand damage). Nobody reached stage 2 in 120 days: the expansion needs about $160,000 plus 30 operating days, 55% occupancy and 3.6 rating, so growth is a mid-term goal that needs reinvestment or a loan. This is a tuning note, not proof of long-term balance.

## Screenshots (`shots/`, zh_TW, JPG)
Luxury Heights day/night and facades, the three interiors, closed-state prerequisites with check marks, open choice, Rate Board (30-day calendar, prices, channels, overbooking) before and after 24 days, daily operations, groups and OTA, guest reviews, growth stages and the Company OS tab. Captured with `xvfb-run -a godot --path game --script res://../tools/qa/hotel_gallery.gd -- --out=<dir>`.
