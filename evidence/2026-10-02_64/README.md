# Issue 64 delivery evidence

Implemented manufacturing and Industrial, stacked on PR 76. Assets are existing fallbacks; named art requests are in wiki/90_codex_art_backlog.md. No art masters changed.

## Acceptance

- Industrial: M3 extends Riverside → Harbor → Industrial, 6-minute Harbor travel; active map destination, pedestrian routes, freight traffic, four buildings and explorable interiors. Rita, Lena and hireable Tomas have schedules and intro dialogues. Employee diner uses cafe tables/counter rather than warehouse furniture.
- Jobs RFQ → deposit → physical Ferro material purchase/arrival → machine production → inspection/rework → delivery/invoice → Net 30 collection. Quotes above the ceiling lose to Kessler; low quotes and outsourcing can lose money. All transactions retain job IDs and manufacturing segment sources.
- Line Planner: hourly capacity, one-hour changeover conflicts, working-hours gates, overtime ×1.5 wage/−2 percentage-point yield, and higher-cost reliable subcontracting. Inspection uses five ratios trading throughput against escaped defects, customer refunds/penalties and credit loss.
- Assets: rented/bought machinery, depreciation, maintenance/failure; genuine Bank loan unlocks 2.5× CNC capacity with reduced staff need. Paid mould unlocks timed own-brand batches stored at Unit 12 for ecommerce, targeting 55% of wholesale before adverse raw-material prices.
- Three active data-driven crises: shortage, customer cancellation with incurred-cost deposit retention, recall with bounded refund and credit penalty.
- Common acceptance: Company OS and Business Board registry descriptors, stable names, glossary badges/help cards, finite and capacity guards, old-save lazy initialization plus real save/load slots/inspection, employee payroll, traceable revenues, Timeline, real closed-company cleanup. Segment totals match company operating profit on every day in all 9 balance runs.

## Verification

- Unit suite: 295/295; 11 manufacturing tests, including physical atlas pixel-region regression, full company closure and delayed brand-slot reservation. Raw unit log has no SCRIPT ERROR or failed test.
- Full Chinese walkthrough, seed 63001: 0 failures, 1,694 steps. Includes all previous chapters/other-session flows followed by an independent factory founder fixture through first invoice and save/load. The dedicated native OpenGL manufacturing walkthrough also has 0 failures.
- i18n: 3,255 translated, missing 0. Wiki: OK, 3,830 assets / 203 data IDs. The full walkthrough has the same 23 English-audit keys as PR 76: retained names/brands/language/registration labels; no new manufacturing text.
- package_release.sh succeeds on Windows, Linux, macOS and Web, including build_size_check: Web PCK 150,788,608 bytes ≤160 MB; Windows ZIP 173,784,400 bytes ≤180 MB. Release SHA-256 hashes included.
- 120 days ×3 strategies ×3 seeds: 0 balance failures. Starting endowment $40,000 is explicitly experimental equity, never operating revenue. Daily cash/profit/receivables/credit retained in JSON. Conservative profit range −$36,111.39 to −$30,341.00; normal −$32,609.99 to −$29,333.80; aggressive −$40,854.44 to −$39,763.28. No strategy guarantees profit. OEM gross margin is near the target, but fixed costs/maintenance/credit losses make all sampled runs loss-making; this remains an economic tuning concern, not a claim of demonstrated viability.
- All retained JPGs inspected: no broken textures or new untranslated text; new UI numbers have units, boolean controls use ✓/✗ with an actionable step, and next-action buttons are primary. Screens cover four interiors, district day/night, setup, Company OS, planner and quality results.

## Self-review repairs

Corrected initial material-capacity omission for finished goods, duplicate/refund AR bounds, permanent compounding shortage prices, preceding-hour production timing, raw/transit closure liquidation, brand repair-delay reservations, multiple primary buttons, missing per-unit translation, mismatched diner furniture, and physical atlas sampling (logical 4× texture overrides cannot address TileSet regions). Full-story factory fixture runs after the original story to preserve its calendar/funding assumptions. No existing loan/returns/closure flows removed.

No unfinished ticket features. Remaining concerns: sampled economics are strongly loss-making; native tests do not establish browser GPU-memory behavior, already separately reported on PR 74. Named industrial art remains a supported existing-asset fallback as required by the guide.
