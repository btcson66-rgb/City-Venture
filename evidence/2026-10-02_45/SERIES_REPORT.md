# Friends beta series — delivered Draft PRs

All rows passed unit, English/Traditional Chinese full walkthrough, i18n missing 0, wiki and four-platform package gates. Simplified Chinese testing was dropped at the user's request. No PR was merged and itch was not uploaded. Current #45 finishes this session; city-venture automation was deleted at the user's request to stop after current work.

| Issue | PR | Unit tests | Self-review fixes | Remaining concerns |
|---|---|---|---|---|
| #39 | https://github.com/btcson66-rgb/City-Venture/pull/75 | 273/273 | Data-driven building/service guide, lock/fade handling, guide reopening; completed full English supplement | Future active content depends on its building/interactable data |
| #44 | https://github.com/btcson66-rgb/City-Venture/pull/77 | 278/278 | Planned content and NPC schedules follow status; old hidden locations recover safely; removed recursive lookup | New active content still needs working services |
| #29 | https://github.com/btcson66-rgb/City-Venture/pull/79 | 280/280 | Balanced only five active businesses in economy JSON; real 18-month goal distributions and censored samples | Casual never-reprice scenario cannot complete price goal; reported explicitly |
| #22 | https://github.com/btcson66-rgb/City-Venture/pull/80 | 286/286 | Strict save validation, atomic recovery/backups, safe new-game slots; four real historical save fixtures | Browser storage can be cleared; export backups first |
| #23 | https://github.com/btcson66-rgb/City-Venture/pull/81 | 289/289 | Version filtering and update acknowledgment persistence; autosave failure restoration; popup timing race | Public upload belongs to Claude; publish script unchanged |
| #25 | https://github.com/btcson66-rgb/City-Venture/pull/83 | 294/294 | Help badges, historical memo translation, unit/primary-action gates; walkthrough restock respects disabled buy | Does not invent funds to make an unaffordable action available |
| #45 | https://github.com/btcson66-rgb/City-Venture/pull/84 | 296/296 | Release notes, whole-dollar display including old history, genuine beta fixture, legitimate tutorial order/pack transition | Sequential merges and public itch upload remain external gates; Linux/macOS packages not physically launched |
