# Replay rules and scenarios (#89)

Implemented: difficulty settings, explicit/random seeds, story/sandbox selection, six data-driven openings, fixed weekly challenges and local results. New Game opens the setup before the cosmetic character creator; its single next action stays visible while options scroll. Selecting a scenario defaults to sandbox; the player can deliberately enable story again.

## Rules and deterministic simulation

Difficulty tuning lives in `game/data/difficulty.json`: initial cash (dollars), daily demand fluctuation (fraction), event frequency (multiple of standard), APR surcharge (percentage points), and debt tolerance (multiple of the standard missed-payment/payroll threshold). Easy/Standard/Hard presets and bounded custom values are supported. Scenario-specific initial funds override the general starting-cash slider, as explained in the page.

The seed drives the existing simulation RNG for events and operations. A separate seeded population-preference mix and per-day market sample affect café/ecommerce demand without consuming that RNG when a preview is read. Identical seed, rules, game build and actions reproduce a 30-day ledger hash. Rendering/input timing and different player actions are not claimed deterministic. Cosmetic randomization is outside business rules.

No `run` section means original saved-game rules: story enabled, original demand, rates and debt thresholds. New saves carry a versioned optional `run` snapshot with rules, seed, scenario definition, initial net worth, deadline, status, immutable result, opening/result acknowledgements and an attempt id. Existing game keys are retained. Unread cards restore after loading; completed results never repeat financial settlement. Sandbox starts existing non-main side objectives without editing chapters, dialogue or the other session's story/content files.

## Openings

| ID | Initial position | Objective / deadline |
| --- | --- | --- |
| `inherited_cafe` | Café lease, ready fit-out/permit, one barista, $8,000 loan | $25,000 revenue and positive cash; 120 days |
| `fresh_restart` | $3,500; credit 520 points; 90-day lending ban | $5,000 savings after the ban; 120 days |
| `venture_fund` | $500,000; registered ecommerce company and $450,000 deposited | $40,000 revenue; 18 calendar months; board withdraws remaining backing after failure |
| `harbor_cargo` | Registered company, used van, two accepted delivery contracts | 45 runs and $8,000 revenue; 120 days |
| `family_property` | One Maple Court apartment valued at $200,000; $150,000 mortgage at 4.5% APR | $4,500 net-worth gain and positive cash; 120 days |
| `part_time_start` | $500; no company | $2,000 cash and 30 shifts; 120 days |

All monetary initializations use Ledger. Mortgage/loan payments use existing Bank schedules. Property rent can be vacant and repairs consume cash. Rental income/maintenance continue after settlement; a successful challenge does not freeze life costs or guarantee continued wealth. Closing the scenario company or loan default ends the attempt. The founder can continue in sandbox.

Maple Court is a scenario-owned financial asset with rent, maintenance and a mortgage, not a new explorable district/property scene. The broader unmerged real-estate industry remains outside this ticket. The opening/result card is a simple implementation because #92 is unmerged; its net worth/time/rating fields provide the later scoring handoff.

## Weekly/local results

A week begins Monday 00:00 UTC. Every player on this version gets the same standard-rules sandbox scenario/seed; the chosen week's parameters stay fixed while character creation is open. Any rule choice switches to a regular run. Results combine net worth, elapsed days and rating using JSON score weights and store up to 100 local attempts in `user://challenge_history.json`. Rating uses the operating café/freelance rating or the mean of completed work scores; absent evidence displays “No rating yet” and earns no rating bonus. No network/server ranking. Atomic temporary-file replacement and attempt-id deduplication prevent repeats after loading an earlier save. Invalid history is reported and preserved, not overwritten; reopening a result retries a recoverable write.

## Development evidence

Six replay unit tests include all scenario openings, 30-day hash equality, nonfinite/boundary custom values, calendar deadline, board withdrawal, closure, JSON save conversion, immutable settlement, unread-card restoration and corrupted local-history preservation. The related `--bot=replay --lang=zh_TW --out=<absolute QA directory>` tour renders setup/scenarios/opening/result and runs each opening for 120 days with three normal-policy seeds plus an idle control. It uses real purchasing/shipping/job/café/van APIs and normal time costs, not fixture money or forced orders. See evidence/2026-10-02_89 for counts and explicit limits. Full walkthrough, beta audit and inherited performance integration remain pre-merge gates under the user's latest instruction.
