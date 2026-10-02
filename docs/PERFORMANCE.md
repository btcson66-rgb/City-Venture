# Performance and stability (#98)

Status: **Partial / Blocked**. The probe and gates are implemented. The requested
ten-year, seven-new-industry, multi-company Web acceptance is not established.

## Reproduce

Use Godot 4.5.1. Import once, then use a dedicated output directory (never a
player save folder; the probe rejects the player data root/save tree):

```text
godot --headless --path game --import
godot --headless --path game -- --bot=stress --days=3 --orders=5000 --staff=50 --seed=98001 --out=<absolute QA directory> --wall_seconds=120
python tools/qa/perf_check.py <QA directory>/stress_result.json --short
python -m unittest discover -s tools/qa -p test_perf_check.py -v
```

The default duration is 3,653 days (June 2031 to June 2041 includes three leap
days). `--days` selects a shorter CI probe. The wall
limit defaults to 120 seconds and the allocation safety limit is 512 MB; neither
truncation counts as completion. Each completed day writes metrics, even if a
later day fails. Profiling can use `--probe`; it still enforces numeric budgets,
and its success must never be presented as full acceptance.

The fixture registers one company, funds it through balanced opening entries,
adds 50 employees (above the normal hiring limit), supplies inventory with matching
equity entries, and invokes the real ecommerce placement, packing, shipping,
scheduled aftersales, minute/hour/month ticks, JSON save and migrated JSON load.
It forces 5,000 orders per day rather than claiming that organic demand can reach
that number. Presentation notification observers are disconnected for this
simulation-only headless probe. No player slot is used or replaced.

## Report and limits

`tools/qa/perf_budget.json` defines units and thresholds: average simulation 8 ms,
nearest-rank p99 30 ms, texture memory 1,200,000,000 bytes, gzip snapshot 5,000,000
bytes, and JSON load 2,000 ms. Full coverage requires 3,653 contiguous daily
observations, 50 employees, 5,000 orders daily, seven new industries and multiple
playable companies. The short gate reduces duration only; it keeps the workload,
coverage and timing requirements.

`stress_result.json` records engine/platform/renderer, exact options, coverage,
incomplete-run errors and per-day simulation/order-placement/packing/courier/tick
times, static allocation bytes, JSON/gzip bytes, save/load times, journal count
and load/balance results. Calendar conversion has an independent micro-profile.
`texture_bytes: null` is UNKNOWN, never zero. Native data cannot certify Web
performance. Gzip is a companion-size measurement, not a shipped compressed-save
format; no save format or journal history is discarded by this change.

The current base has all seven required new industries marked planned, allows
only one owned company, and has no `tools/beta_audit.py`. Their implementation is
owned by other tickets; this branch does not replace those features with fake
businesses or duplicate the beta audit from an unmerged PR. CI fails visibly
until the prerequisites and performance budgets are satisfied.

## Measured optimization

The initial profile found order placement dominant: 7,854 ms then 19,943 ms for
the first two 5,000-order days. Each order rescanned the full history to reserve
stock. A derived order-reservation index now counts placed units by stock location
and product. Actual placement increments it; successful packing releases units.
Active contracts remain read live. New games, loaded saves, replacement order
dictionaries or fixture insertions invalidate/rebuild it. It is not saved. Bulk
tools that mutate an existing order's status directly must call
`Ecommerce.invalidate_reservations()`; normal gameplay uses the service functions.

The same two-day workload took 671 ms then 603 ms after indexing, but still fails
the 8 ms/30 ms budgets. The complete gameplay state and all 10,011 ledger entries
match before/after (ignoring creation timestamp and real playtime). The long-run
attempt stopped at seven days on the allocation safety limit; it did not complete
ten years. Do not extrapolate two days into acceptance.

## CI

`Game quality` runs on each PR and pushes to ticket branches. Its regression job
installs Godot 4.5.1 and runs all game and evidence-validator unit tests. Its
acceptance job runs translation, wiki, beta audit and the short performance gate;
independent checks continue after a failure and preserve their reports as
artifacts. The acceptance job is currently expected to fail on missing upstream
content/beta tool and exceeded budgets.

Repository administrators must make both named jobs required checks in the
target branch rules to enforce a merge block. A workflow file alone cannot
establish branch protection. No main/target branch push or merge is authorized
by this change. See the ticket evidence README for actual CI run links.
