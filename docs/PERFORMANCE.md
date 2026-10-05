# Performance and stability (#98)

Status: **budgets met on a native ten-year stress run; the browser frame rate is not certified.**
The ten-year (3,653-day) run with 5,000 orders a day, 50 employees, seven new industries and two playable
companies passes every numeric budget (see the table below). Native timings are a proxy for the Web build: only a
browser capture can certify 60 FPS there, and `tools/qa/perf_check.py` says so unless `--native` is given.

## Reproduce

Use Godot 4.5.1. Import once, then use a dedicated output directory (never a player save folder; the probe rejects
the player data root/save tree):

```text
godot --headless --path game --import
# short CI probe (3 days)
godot --headless --path game -- --bot=stress --days=3 --out=<absolute QA directory> --wall_seconds=120
python tools/qa/perf_check.py <QA directory>/stress_result.json --short
# full ten years, saving and reloading every 30th day, plus the accounted texture soak (about 6 hours)
godot --headless --path game -- --bot=stress --days=3653 --save_every=30 --textures=1 --wall_seconds=90000 --out=<absolute QA directory>
python tools/qa/perf_check.py <QA directory>/stress_result.json --native
python tools/qa/summarize_stress.py <QA directory>/stress_result.json
python -m unittest discover -s tools/qa -p test_perf_check.py -v
# phase timings of loading one large save
godot --headless --path game -- --bot=loadprobe --file=<slot json>
```

`--profile=1` prints the per-day cost of every hourly module, scheduled-event kind and archive pass
(`Prof`, only collected while profiling) and names any tick over 100 ms.

## What is measured

The workload is a saturation fixture, not a winning strategy: one company runs ecommerce, manufacturing, media, real
estate and hotel; a second runs automotive, energy and international trade. Coverage is **measured** from
`Industries.is_running()` and the company list after setup, never hard-coded. 50 employees (above the normal hiring
limit; every tenth is a support agent who settles returns) are on the books. Each game day places 5,000 one-unit
orders spread over the 24 hours, packs and books the courier, and the real scheduled aftersales (delivery, returns,
reviews) run. Stock is supplied with matching equity entries, never free cash.

* **Simulation cost** (`simulation_ms`, budget mean <= 8 ms): the cost of one minute tick, i.e. one 60 FPS frame at
  1x speed, averaged over the run. `frame_p99_ms` (budget <= 30 ms) is the per-day p99 of that cost plus the
  `time_changed` observers a rendered frame also pays; `perf_check` uses the worst day. Hourly and midnight work is
  inside these ticks.
* **Per-order batch cost** (`order_ms_per_order`): placement, packing and booking the courier are player/staff
  actions, reported per order instead of being averaged into a frame.
* **Save size** (`gzip_bytes`, <= 5,000,000) is the file size of the shipped save; **load** (`load_ms`, <= 2,000 ms) is
  `SaveSystem.load_data` including validation and the post-load hooks.
* **Texture memory** (<= 1.2 GB) is *accounted* by `Art` (RGBA8 plus a third for mipmaps) while the soak walks all
  1,901 detail textures twice; it is not a GPU read-out and the report labels it `texture_source: "accounted"`.

## What changed

Profile first: the dominant costs were full scans of data that only grows (orders, journal, schedule) from hourly
and per-post code, a registry rebuilt on every ledger post, and unbounded state in saves.

| Area | Change |
|---|---|
| Orders | A derived per-company index (`Ecommerce._index`) holds the open orders, the shelf (placed/packed) orders, the overseas orders and the stock reservations, so fulfilment scans cost O(open orders) instead of O(every order ever placed). Settled home orders with no scheduled follow-up are folded into `ecommerce.order_archive` monthly totals once a company holds 2,000+ orders (ordinary play never reaches it). |
| Ledger | Order-driven entries (`order`, `return`, `ship`) of a busy entity-day (100+) fold into one summary entry per day, type and segment (`Ledger.compact_old`). Account balances, month windows, segment and earned-revenue totals are unchanged because every line is summed per account and day boundaries are kept. Ordinary play keeps every line. |
| Hot paths | `Industries.all()` and the optional `prepare_journal`/`on_ledger` hooks are resolved once instead of per ledger post; the 30-day internal-supply scan and the supplier-breach lookup walk the journal newest first; `CompanyPortfolio.migrate` scans the schedule once per array instead of on every company switch; Growth's overseas metrics use the overseas index. |
| Frame spikes | At most 120 scheduled events run per minute tick (the surplus runs on the next tick); a courier pickup hands over 250 parcels per event. Only a saturated company ever reaches either limit. |
| Saves | The active company is written once (its context view used to repeat every state object); big collections (orders, journal, schedule of 2,000+ entries) are stored as one packed Variant blob, which loads several times faster than JSON text; files above 256 KB are gzip. Older plain-JSON saves load unchanged (`test_old_saves`, historical fixtures). Damaged or tampered blobs fail the same validation as plain JSON. |
| Textures | `Art` keeps detail textures under a 900 MB accounted byte budget (least recently used first, the texture just requested is never evicted; large artwork keeps its 8-entry limit and counts toward the budget). |
| Tax memo | Per-order VAT memos are dropped with the archived order. |
| Gates | `perf_check` takes the worst per-day frame p99, allows `--save_every` runs (the last day must be measured), and has `--native` for a full native run. `tools/qa/summarize_stress.py` prints a per-year table. |

## Limits and known costs

* A saturated company folds its history once a day at midnight; that tick costs several hundred milliseconds
  (reported as `tick_max_ms`) and is outside the p99 by construction.
* Open and recently delivered orders are not folded: a week of 5,000-order days keeps about 20,000 orders in memory
  and in the save. The stress process stays near 300 MB.
* Calendar conversion has an independent micro-profile (`calendar_1440_calls_ms`).
* The seven new industries are exercised by their real `start()` functions; their balance is owned by their tickets.

## CI

`Game quality` runs on each PR and pushes to ticket branches. Its regression job installs Godot 4.5.1 and runs all
game and evidence-validator unit tests. Its acceptance job runs translation, wiki, beta audit and the short
performance gate; independent checks continue after a failure and preserve their reports as artifacts.

Repository administrators must make both named jobs required checks in the target branch rules to enforce a merge
block. A workflow file alone cannot establish branch protection. No main/target branch push or merge is authorized by
this change.
