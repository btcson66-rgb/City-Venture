# #98 Performance and stability — PARTIAL / BLOCKED

Base: `a9124264`, latest `claude/exciting-bardeen-y71ixv` after fetch on 2026-10-02.
This is the first ticket in the requested stack; it has no preceding ticket PR.

## Scope and validation

- Real saturation probe: ecommerce placement, stock reservation, packing, courier, scheduled aftersales, every minute/hour/month tick, JSON save and old-save migration/load. Fixtures force 5,000 orders and 50 employees; they are not a normal-play strategy.
- Profile before optimization: day 1 **8,235.570 ms**, day 2 **20,329.604 ms** simulation. Placement alone: **7,853.882 ms / 19,943.216 ms**.
- Profile after optimization: day 1 **670.731 ms**, day 2 **602.612 ms**. Placement alone: **251.236 ms / 209.970 ms**. Same seed/workload, Godot 4.5.1 Windows headless.
- Game tests: **273/273 tests passed in 16.3s**; six new tests cover reservation lifecycle, live contracts, loaded/new games, fixtures and overselling/location/product boundaries.
- Python performance validator: **12 tests passed**; missing/partial metrics, null texture memory, wrong coverage, malformed evidence, nonfinite numbers and exceeded thresholds fail.
- i18n: **3053 msgids, missing 0**. Wiki: **OK (3830 assets, 191 data ids)**.
- Complete gameplay state and 10,011 ledger entries match before/after, ignoring creation timestamp and real playtime; hashes are in `semantic-comparison.json`.
- Short stress is the ticket-related tour. No full rendered walkthrough was run: this is ticket 1, below the requested every-third-ticket cadence.
- JPG evidence only: `performance-comparison.jpg`. Raw QA saves stay local and are not staged. Committed evidence is below 20 MB.

## Self-review fixes

1. Profiling identified the full-history reservation scan; replaced it with a derived index, not a guessed optimization.
2. Index invalidation on loaded/new games avoids stale reservations and retaining an old loaded dictionary. Active contract reservations remain live.
3. Boolean/nonnumeric/NaN metrics and absent texture readings cannot become a success. Native short validation cannot stand in for Web acceptance.
4. Preserved line endings and restored Godot-generated asset import noise; no assets or art tools are part of the change.
5. Corrected the ten-year duration to 3,653 days: June 2031–June 2041 spans three leap days.
6. QA outputs cannot target the player data root/save tree; a regression checks traversal and nested paths.
7. All player money strings/actions/economic rules are unchanged; simulation state equality confirms this for the measured workload. No crisis or decision mechanics were added.

## Unmet gates — do not merge or start the next ticket

- Mean 8 ms / p99 30 ms budgets remain exceeded, even after the measured improvement.
- Long attempt terminated at seven days on the 512 MB allocation safety limit; **not** ten-year coverage.
- The seven required new industries are all still planned in this base. Multi-company gameplay is owned by #91 and absent. This branch does not implement another session's tickets or fake their coverage.
- `tools/beta_audit.py` does not exist in this base; invoking it fails visibly. Its source is in unmerged cleanup work, which has not been imported wholesale into this ticket.
- Web simulation timing, rendered texture memory and shipped compressed saves are **NOT VERIFIED**. Gzip numbers are companion-size measurements; shipping saves still use JSON.
- CI run links are below. A green regression job is distinct from the failing acceptance job; whole-workflow green is not established.
- Merge enforcement also needs repository required-check configuration; no branch protection/main/target branch was modified.
- Future tools that directly change an existing order status in place must explicitly invalidate reservations. Current gameplay's only placed-to-other transition is packing, covered by the index updates.

Remaining requested order: #87 → #88 → #89 → #90 → #40 → #28 → #26 → #27 → #96 → #97 → #95. All remain unstarted because #98 has not passed the user's advance gate. Excluded story/content tickets were not modified.

## CI evidence (actual PR runs)

- Original regression **success**: [run 36972942038](https://github.com/btcson66-rgb/City-Venture/actions/runs/36972942038/job/110730582305), head `218ac69f`: 272/272 game tests, 12 Python tests. Acceptance failed on missing beta tool and four performance/coverage failures. The Linux three-day workload averaged 358.428 ms, p99 405.461 ms.
- Intentional unit failure **confirmed**: [run 36973414137](https://github.com/btcson66-rgb/City-Venture/actions/runs/36973414137/job/110732013666), head `7974c7c7`: `test_ci_failure_probe` failed, 272/273 tests, exit code 1. Source excerpts and job metadata are in `ci-failure-proof.log` / `ci-failure.json`.
- The deliberate failure has been removed. A sixth regression test protects player save directories from QA outputs; final local game tests are 273/273. The restored-head cloud run will be linked in the PR body after completion. No complete green workflow is claimed while acceptance remains blocked.
- See `DELIVERY.md` for each requested ticket's PR/test/review/status row.
