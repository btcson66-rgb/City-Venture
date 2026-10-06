# #98 — 10-year native stress run (integration build)

Run: `godot --headless --path game -- --bot=stress --days=3653 --save_every=30 --textures=1 --out=/tmp/full3`
(interrupted by a container restart at day 3,151; continued with the new `--resume=3150`, which reloads the
last snapshot and keeps the earlier samples). Coverage measured, not hard-coded: 8 industries (manufacturing,
real estate, media, hotel, automotive, energy, international trade, ecommerce), 2 companies, 50 staff,
5,000 orders/day. `completed: true`, no errors, ledger balanced on every day.

| Budget | Limit | Before (#98 PR, day 7) | 10-year result |
|---|---|---|---|
| Minute tick, mean over the run | ≤ 8 ms | 637 ms (whole day measured) | 2.11 ms |
| Worst per-day p99 frame | ≤ 30 ms | 671 ms | 25.1 ms |
| Compressed save at year 10 | ≤ 5 MB | 30 MB JSON by day 7 | 1.94 MB |
| Load at year 10 | ≤ 2,000 ms | 1,843 ms by day 7 | 942 ms in-run; idle re-measure 1,128–1,820 ms (5 loads) |
| Texture memory (soak, 1,901 textures) | ≤ 1.2 GB | not measured | 0.86 GB held (0.94 GB budget) |
| Process memory | — | 580 MB by day 7, +80 MB/day | 582 MB peak over 10 years, flat |

`perf_check --native` reports one failure: a single snapshot (day 2,880) loaded in 2,036 ms while three other
agents were using the 4-core VM. All other 121 snapshot loads were under 2 s, and the year-10 save loads in
1.1–1.8 s on an idle machine. The Web frame-rate budget still needs a browser capture (not possible headless).

Also fixed after this run: the background free of a replaced game (load optimisation) was not joined at quit,
which crashed the engine on exit; `SaveSystem` now waits for those tasks in `_exit_tree`.
