# S3 events and street props — 2026-09-30

Base: `b524d2e` from `claude/exciting-bardeen-y71ixv` after `git pull`. This batch adds two 160×90 event illustrations and four street props, each with a 4× `world_detail` image and import descriptor. The palette and upper-left light match the previous art round. All invoice and device surfaces are blank or pictographic.

`before_supply_shock_modal.png` / `after_supply_shock_modal.png` are captures from the actual DecisionModal before and after the illustration was added. `before_payment_modal.png` / `after_payment_modal.png` are captures from the actual SettlementModal. The before captures used the previous art baseline (`dad9361`); the after captures use this branch. The UI still uses the existing code path to discover event art.

`before_street_props.png`, `after_street_props.png` and `street_props_comparison.png` are art contact sheets, **not in-game captures**. Claude's game line must place `port_cranes_far` in the Riverside distance from year 3, and `solar_roof_small`, `solar_roof_large`, and `ev_charger` on appropriate buildings/curbs from year 4. These props are not yet visible in gameplay.

Validation: Godot 4.5.1 headless import exited 0; test runner: `101/101 tests passed in 7.3s`; screenshot bot: `BOT FINISHED — 0 failure(s) · 42.9s real` (44 shots); `wiki_check: OK (1389 assets, 176 data ids)`. Pose and map-label checks do not apply because no character or map art changed.
