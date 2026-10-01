# CITY VENTURE — Architecture

> Engine: **Godot 4.5.1**, GDScript, `gl_compatibility` renderer, 2D, Windows Desktop first.
> Status vocabulary used across all docs: **Implemented · Mocked · Placeholder · Planned · Blocked**.

## 1. Guiding constraints (from the Master Handoff)

| Constraint | Architectural consequence |
|------------|---------------------------|
| The city is the game (§0, §3) | The main loop runs in `District` / `Interior` scenes. No Dashboard scene exists at the top level. |
| Company OS only via a terminal (§52) | `CompanyOS` is a modal UI that can only be opened by an `Interactable` whose action is `open_company_os`. |
| Every dollar has a source (§2.3) | All money moves through a double-entry **Ledger**. No system may write to a cash balance directly. |
| Data-driven (§73) | Content lives in `game/data/**.json` and is loaded by `DataDB`. Scene scripts only read ids. |
| No stat buffs (§2.1) | The Player record holds appearance and identity only. The sim never reads player attributes. |
| Future multiplayer (§70) | Contracts are between `CompanyEntity` ids, never "player vs npc". The player's company is one entity among others. |
| Crypto is late-game simulation (§2.6, kickoff §24) | Settlement rails are data (`settlement_methods`). The slice has no rail beyond bank/marketplace. No external wallet/chain code exists anywhere. |

## 2. Repository layout

```
/docs                      Specs, readback, audit, architecture, roadmap, schema, manifests, QA
/docs/reference            Master Handoff + concept boards (source of truth)
/tools
  /art/gen_placeholders.py Deterministic Neo-Civic placeholder pixel-art generator
  run_tests.sh             Headless unit + integration tests → evidence/test-reports
  capture.sh               Xvfb + Movie Maker walkthrough capture → evidence/videos, screenshots
  build_windows.sh         Windows Desktop export
/game                      Godot project root (project.godot)
  /autoload                Singletons (see §4)
  /data                    JSON content (see GAME_DATA_SCHEMA.md)
  /assets                  PNG sprites (generated placeholders now, final art later) + fonts
  /scenes                  Minimal .tscn wrappers; most node trees are built by scripts from data
  /scripts
    /sim                   Pure simulation (no Node dependency beyond RefCounted) — unit-testable
    /world                 Player, NPC, vehicles, district/interior builders, interactables
    /ui                    HUD, phone, dialogue, Company OS, creator, city/world map, modals
  /tests                   Headless test runner, unit tests, scripted walkthrough bot
/evidence                  screenshots/ videos/ logs/ test-reports/ (per milestone)
```

## 3. Scene hierarchy

```
Boot (autoload init, DataDB load, settings)
 └─ MainMenu ──────────── New Game / Continue / Quit
     └─ CharacterCreator  (appearance + outfit + name; cosmetic only)
         └─ Arrival       (train cutscene → phone: balance / rent)
             └─ WORLD LOOP ─────────────────────────────────────────────┐
                 ├─ District(id)   Riverside / Startup Hub / Civic Center / Financial District
                 │    ├─ Ground TileMapLayer (built from district JSON)
                 │    ├─ YSort world: buildings, props, player, NPCs, vehicles
                 │    ├─ Doors → Interior(id)   Exits → District(id)   Metro → CityMap
                 │    └─ Day/Night modulate + light overlays
                 ├─ Interior(id)   Apartment / Bloom Coffee / Co-work / Small Office / Bank / City Hall …
                 │    ├─ Room (floor, walls, windows w/ skyline), furniture w/ collision
                 │    ├─ Interactables → contextual UI (Company OS, Bank counter, Registration, Wardrobe…)
                 │    └─ Scheduled NPCs
                 ├─ CityMap        (Metro / map app; district labels, travel times)
                 └─ WorldMap       (Aurelia + 7 markets; overseas travel = Planned P2)
UIRoot (CanvasLayer autoload, above everything)
 ├─ HUD            money · date/time · objective · minimap · interaction prompt
 ├─ Dialogue box   portrait + short lines + choices
 ├─ Phone          Messages · Bank · Objectives · Map · Seller app notifications · Save
 ├─ Modal stack    Company OS, event decisions, month close, warnings, registration forms
 └─ Toasts         notifications (order received, payout, rent due)
```

`SceneRouter.go_to(kind, id, spawn)` performs fade → free old scene → build new scene from data → place player at the named spawn → fade in. The current `{kind, id, position, facing}` is stored in `GameState` so a save can restore the exact spot.

## 4. Autoload singletons

| Autoload | Responsibility |
|----------|----------------|
| `DataDB` | Loads every JSON file under `res://data/` into typed dictionaries by id. Validates ids and references at boot (fails loudly in tests). |
| `EventBus` | Global signals (`order_placed`, `order_delivered`, `cash_changed`, `location_entered`, `interacted`, `day_started`, `month_closed`, `flag_set`, …). |
| `GameState` | The single source of truth: one JSON-serialisable `Dictionary` (`GameState.data`). Owns the RNG seed/state. |
| `Clock` | Game time (minutes since epoch), day parts, pause stack, time scale, sleep/advance. Emits `minute_tick`, `hour_tick`, `day_started`, `month_ended`. |
| `Sim` | Owns the simulation services and routes clock ticks to them: `Ledger`, `EcommerceSim`, `ContractSystem`, `EventEngine`, `StoryEngine`, `NPCDirector`, `Timeline`, `LivingCosts`, `SolvencyMonitor`. |
| `SaveSystem` | Save/load slots (`user://saves/slot_N.json`), autosave on sleep, versioned migration hook. |
| `SceneRouter` | Scene transitions and spawn points. |
| `UIRoot` | Screen-space UI (§3). |
| `Art` | Texture cache, character-layer composition, palette constants. |

## 5. State management

- `GameState.data` holds **everything that must survive a save**. Nodes never keep authoritative state: they read from `GameState` and write through sim services.
- Sim services are `RefCounted` classes that take `data` (and `DataDB`) as input. They are deterministic given the RNG state, which lives inside `data.rng` so a reload continues the same random stream.
- Scene nodes subscribe to `EventBus` to refresh visuals, for example inventory boxes in the apartment scale with stock.
- Pause model: `Clock.push_pause(reason)` / `pop_pause(reason)`. Dialogue, Company OS, menus and decisions pause the world clock. Actions that take time (packing, photographing, travelling) call `Clock.advance(minutes)` explicitly, so management can never happen "for free" in zero time.

Top-level shape of `GameState.data`, detailed in GAME_DATA_SCHEMA.md §2:

```
meta{version, created, playtime_s}
player{name, appearance{...}, outfit, home_id, location{kind,id,x,y,facing}, flags{}}
clock{minutes, speed}
entities{ "player":{...personal}, "co_<id>":{company}, npc companies... }
ledger{journal[], seq}
ecommerce{listings{}, orders{}, purchase_orders{}, inventory{loc:{product:{qty,avg_cost,defective}}}, marketplace{...}, supplier_mods[]}
contracts{}
events{active[], history[], cooldowns{}}
story{chapter, objectives{}, flags{}, completed[]}
npcs{ id:{relationship, dialogue_state, met} }
timeline[]
reports{month_closes[]}
world{year, market_modifiers{}, macro{interest_rate}}
rng{seed, state}
```

## 6. Economy engine — the Ledger

A small double-entry bookkeeping engine (`scripts/sim/ledger.gd`).

- **Entities**: `player` (personal finances plus the sole-proprietor business before registration) and `co_<slug>` (a registered company). NPC companies are also entities, so contracts are symmetric.
- **Accounts per entity**: `cash`, `marketplace_balance` (receivable from the platform), `accounts_receivable`, `inventory`, `accounts_payable`, `equity`, `revenue`, `refunds` (contra-revenue), `cogs`, and `expense:<category>` for `advertising`, `shipping`, `platform_fees`, `packaging`, `photography`, `rent_home`, `rent_office`, `coworking`, `living`, `registration`, `inventory_writeoff`, `bank_fees` and `late_fees`.
- `post(entity, date, memo, lines[], source)` must balance (Σdebit = Σcredit), or it asserts.
- **Profit ≠ Cash is structural.** A delivered order posts `Dr marketplace_balance / Cr revenue` and `Dr cogs / Cr inventory`. Cash only moves at the weekly payout (`Dr cash / Cr marketplace_balance`, less fees). A B2B contract invoice posts to `accounts_receivable`, collected at Net N. Supplier net terms post to `accounts_payable`.
- **Month Close** (`month_close.gd`): for each entity, aggregates the period's journal lines into Revenue, Refunds, COGS, Gross Profit, operating expenses by category, Rent, Profit, opening/closing Cash, AR, AP and Inventory. The result is stored in `reports.month_closes` and shown in a modal and in Company OS → Finance.

## 7. Business engine

`BusinessEngine` dispatches to one module per industry, keyed by `data/businesses/<id>.json → "module"`. The Vertical Slice implements `ecommerce`. The other five P0 industries have definitions marked `"status": "planned"` and are shown on the Business Board as unavailable in this build. They are never stubbed as fake income.

### EcommerceSim (`scripts/sim/ecommerce_sim.gd`)

```
Supplier offer (data) ──buy (≥MOQ, prepay | net terms)──▶ PurchaseOrder ──lead_days──▶ Inventory@location
Inventory ──photograph (time)──▶ Listing(price, photo_quality, ad_budget)
Listing ──hourly demand model──▶ Order(placed)
Order ──pack @ inventory location (time)──▶ packed ──courier pickup | PostPoint drop-off──▶ shipped
shipped ──transit days (method)──▶ delivered ──▶ revenue + COGS recognised; marketplace balance ↑
delivered ──return window──▶ return_requested ──▶ refund (+ restock | write-off)
delivered ──p(review)──▶ review (stars from quality, speed, value) ──▶ listing rating
Monday 09:00 payout: eligible marketplace balance − platform fees ──▶ cash
Daily 00:00: ad spend charged
```

Demand model (per active listing, per hour of the shopping curve):

```
λ_day = base_daily_demand
      × (ref_price / price) ^ elasticity          (clamped)
      × rating_factor(avg_stars, n_reviews)
      × photo_factor(photo_quality)
      × ad_factor(ad_budget)                       (diminishing returns)
      × world/event multipliers (data)
orders_this_hour ~ Poisson(λ_day × hourly_weight[h])      capped by available stock
```

Personal-seller accounts have a monthly sales cap (data: `marketplace.personal_seller_cap`). Crossing it pauses listings until the player registers a company. This is the real-world reason the story moves the player to City Hall.

### Other business modules (build 0.1.3)

| Module | Script | Loop | Money |
|--------|--------|------|-------|
| Freelance consulting | `sim/careers.gd` | Daily gig offers → 2 h work sessions at a laptop → deliver → invoice on 0/7/14-day terms. Reputation moves the rate | `accounts_receivable` → `cash`, `revenue` |
| Part-time jobs | `sim/careers.gd` | 4 h on-site shifts during opening hours, 3-rank promotions, one perk per job | `wages` (personal income) |
| SaaS | `sim/saas.gd` | Idea → MVP dev hours (founder sessions + developers) → launch → daily signups (price elasticity × quality × marketing × word of mouth × market room) and churn (features and support lower it) | Daily subscription `revenue` net of a 3% processor fee, `exp:servers`, `exp:advertising` |

### People, banking, insolvency (build 0.1.3)

- `sim/staff.gd`: employer registration, job ads, applicants, Friday payroll (`exp:payroll`; shortfalls go to
  `wages_payable`), morale and resignations. Roles do real work: the packer packs at Suite 2B and books the courier,
  support settles returns, the marketer multiplies demand, the developer adds SaaS dev hours. Staff appear at
  `staff_spots` in the office.
- `sim/bank.gd`: credit score (300–850). The loan offer comes from the books: 3 × trailing 30-day gross profit,
  70% of receivables, 60% of signed contracts and 50% of stock, minus existing debt. Loans amortise every 30 days
  (`exp:interest` + `loan_payable`). A missed payment costs a late fee and credit; two in a row call the loan; an
  unpaid call makes the company insolvent.
- `sim/insolvency.gd`: rescue with personal savings, restructure the loan, or close the company. Closing liquidates
  stock at 40%, sells receivables at 80%, ends leases, lets staff go, pays wages → bank → suppliers, writes off
  the rest, returns what's left to the founder, hits credit and pauses lending for 90 days. The founder can
  register a new company (new id; the old books are kept).
- `sim/forecast.gd`: 9-week cash forecast from scheduled and contracted flows plus a 14-day sales run rate.

## 8. Contract system

`scripts/sim/contract_system.gd`. A contract is always `{buyer_entity, seller_entity, lines[], unit_price, total, delivery_due, payment_terms_days, penalty_rate, quality_req, currency, settlement_method, status}`.
Lifecycle: `offered → (accept | reject | counter → offered′) → active → fulfilled → invoiced (AR) → paid | late → closed` with penalties posted through the Ledger. NPC counterparties decide counters with a data-driven acceptance function (`min_price`, `max_terms`, `patience`). Nothing assumes the counterparty is an NPC, which keeps the Enterprise Network boundary open (P4).

## 9. Event engine

`scripts/sim/event_engine.gd`. Events are JSON definitions (`data/events/*.json`):

- `trigger`: `{when: daily|hourly|on_signal, signal?, conditions[], chance, cooldown_days, once, earliest_day}`
- `bind`: selectors that pick context such as `order: latest_delivered`, `supplier: current_for_best_seller` and `product`.
- `presentation`: channel (`phone` | `in_person` | `email`), speaker npc, short lines.
- `choices[]`: `{label, requires[], effects[]}`.

Effects are a closed vocabulary executed by `effects.gd`: `cash`, `refund_order`, `ship_replacement`, `inventory_delta`, `rating_delta`, `supplier_price_mod`, `create_contract_offer`, `set_flag`, `schedule_event`, `timeline`, `message` and so on.

Every event must change at least one of money, inventory or future options. Pure-dialogue events are rejected by the schema validator (kickoff §17).

## 10. Story engine

`scripts/sim/story_engine.gd`. Chapters → objectives, all from `data/story/chapters.json`.
Each objective has `complete_when` conditions (tiny condition DSL shared with events: `flag:x`, `visited:bloom_coffee`, `stat:orders_delivered>=1`, `company_registered`, `day>=14`) and `on_start` / `on_complete` action lists (`dialogue`, `message`, `set_flag`, `start_objective`, `timeline`, `unlock`). The HUD shows the active main objective. Dialogue lives in `data/dialogue/*.json` and is kept short, natural and modern (kickoff §31).

## 11. World state, NPC state

- **World state**: `world.year` (Year 1 = 2031, "The Opportunity"), macro variables (interest rate, shipping index) and active market modifiers. Year-based world events (Supply Shock, Clearing Crisis, …) are defined in data but only Year 1 content is active in the slice.
- **NPC state**: named NPCs (`data/npcs`) have `schedule[]` (time window → location + spot), `role`, `dialogue` entry points by story state, and `relationship` (a number that changes dialogue options, never a business buff). `NPCDirector` spawns named NPCs into the current scene when their schedule says they are there, plus ambient pedestrians and traffic whose density depends on district and time of day.
- **Buildings** have `hours` (open/closed). A closed door shows the hours and refuses entry, except the player's own home and office.

## 12. Save system

`SaveSystem.save(slot)` writes `{format: 1, saved_at, summary{name, company, date, cash, location}, data: GameState.data}` as JSON. Load validates the format version, runs migrations, replaces `GameState.data`, restores the clock and routes to the saved scene and position. Autosave happens on sleep. Tests verify the round trip (save → load → equal state) and continued simulation after a load.

## 13. Rendering and presentation

- Detail art resolution (`#62`): `Art.tex(path)` prefers `assets/world_detail/<path>.png`. Its cached ImageTexture retains
  the full imported image and overrides only the logical size to the native image's dimensions (or one quarter for
  detail-only files). Atlas regions, nine-slice margins, backdrop pan and UI hit targets remain in native pixels.
  `backdrops/`, `cards/`, `events/`, `city_map/` and `world_map/` share an eight-entry LRU cache, including
  explicit `world_detail/` paths. Texture reads refresh recency; existence probes do not. Eviction releases only
  the cache reference so active scenes remain valid. All other texture categories stay permanently cached.
  Explicit `world_detail/` keys retain physical dimensions for existing world/character fitting code. World collision
  continues reading the native alpha mask. Backgrounds and maps use lossy WebP import at quality 0.85; other art stays
  lossless. Release presets exclude only `tests/*`; packaging enforces decimal MB ceilings through
  `tools/qa/build_size_check.py`: Web `index.pck` <= 160 MB, Windows release zip <= 180 MB.

- Base resolution **640×360**, `canvas_items` stretch, `keep` aspect, nearest filtering, 2D transform snapping. Default window 1280×720 (2×), and 1920×1080 renders at 3×.
- Characters: layered 32×48 frames (body/skin, face details, hair back/front, outfit, accessories), three directions (down, side, up) × four walk frames. Hair, skin and eye colours use `modulate` on grayscale-ramp layers so a small number of sheets produces the whole creator space.
- Environment: 16 px tile grid. Buildings are pre-composed modular facades with a separate night-lights overlay.
- Day/Night: `CanvasModulate` gradient driven by `Clock`, window-light overlays, lamp glow sprites.
- UI: pixel 9-slice panels and 16 px icons on the Neo-Civic palette (Dark Navy / Blue / White / Muted Gray; Green = positive cash, Red = risk, Gold = premium, Purple = luxury).

## 13a. Localization (English · 繁體中文 · 简体中文)

- **Source language is English, and it is the only language in data and saves.** Game logic never compares
  translated text. That is why switching language mid-game can't break anything, and a save made in one
  language loads in any other.
- **Runtime**: Godot `TranslationServer` with gettext catalogues `game/i18n/zh_TW.po` and `zh_CN.po`.
  `I18n` (`scripts/ui/i18n.gd`) loads them at boot, picks the locale, and saves the choice to `user://settings.cfg`.
  The locale comes from `--lang=` if given, otherwise the saved setting, otherwise the OS locale. You can switch it
  from the main menu and from the pause menu.
- **What gets translated where**:
  - Plain `Label`/`Button` text is auto-translated by Godot on an exact match. This covers static UI and data names shown on their own.
  - Templates are translated *before* values are inserted: `I18n.t("Pack %d order%s (%s)") % […]`.
    `EventEngine.fill()` does the same for data templates like `{customer}: {reason}`.
  - Data names used inside sentences are wrapped: `I18n.t(DataDB.product(id)["name"])`. Lists go through `I18n.join()`.
  - English plurals go through `I18n.pl(n)`, which returns nothing in Chinese. Dates and times use `Clock.fmt_*`,
    which gives `6月1日（週日）`, `下午 2:00` and `2031年6月` in Chinese.
- **Fonts**: Noto Sans TC/SC (SIL OFL, subset to Big5 + GB2312) are set as fallbacks under Inter/Pixelify.
  The order changes with the locale so Traditional and Simplified glyph shapes stay correct.
- **Workflow**:
  - `python3 tools/i18n_extract.py` scans GDScript literals and the display keys in `data/**/*.json`. It writes
    `messages.pot`, then builds the `.po` files from `tools/i18n/zh_TW.json`. `zh_CN` is converted with OpenCC `tw2sp`,
    and `tools/i18n/zh_CN.json` can override single entries.
  - `--check` fails the build on any untranslated string.
  - `tests/unit/test_i18n.gd` checks that the catalogues load, that templates keep their placeholders, and that
    dates, plurals and switching language leave game data untouched.
- **Runtime records** (phone messages, the timeline, ledger memos) are written in the language active when they happen.

## 14. Testing strategy

| Layer | How |
|-------|-----|
| Data | `DataDB.validate()` checks ids, cross-references and required fields. Run at boot and in tests. |
| Sim unit tests | `tests/unit/*.gd` run headless with no scenes: ledger balancing, demand, PO/MOQ, pack/ship/deliver, payouts (Profit ≠ Cash), returns/refunds, reviews, month close, events, contracts, solvency, save round trip. |
| Integration | `tests/integration/*.gd` boots real scenes headless: router, doors, interactables, closed hours, Company OS gating. |
| Walkthrough bot | `tests/walkthrough/bot.gd` drives the real game with synthetic input events (movement actions and mouse clicks on UI) through New Game → Creator → Apartment → City → Cafe → Co-work → Business → First Sale → Registration → Company OS → Month Close. Run headless for PASS/FAIL, and under Xvfb + Movie Maker for the video. |
| Human playtest | Needs a human. Tracked in `QA_REPORT.md` and never marked PASS by the agent. |


## Industry framework (#63)

`Industries.all()` defines the five existing modules, event prefixes, legacy hour slots, and optional world action callbacks. Each sim module exposes `is_running`, `os_tab`, `board_detail`, `segment_tag`, and `on_company_closed` in addition to its hourly/event handlers. The sales → contracts → living → events → consulting → staff → SaaS → café → logistics order is preserved. Company OS renders registered running tabs and separately offers inactive consulting/software setup actions; the business board invokes module render callbacks in IndustryViews. New modules can provide a render Callable in their tab descriptor.

Every new journal entry gets source.segment. Existing untagged saves are attributed when reported without rewriting the journal. Segments reports this/last month and allocates shared operating expenses by positive net revenue, rounding cents and placing the remainder in the final recipient. With no revenue, expenses remain in Shared. The sum uses MonthClose's established business-profit convention, including other income.

Jobs provides product-independent offer/accept/progress/deliver/invoice and Net 0/30/60 settlement, deposit liability, penalties, terminal closure and collection guards. Contracts reuses the deposit/invoice line builders and retains negotiation, inventory, quantities, story receipts and closure handling. Old product-contract fields and schedule names are unchanged.

Assets manages capitalized purchases, rentals/deposits, straight-line daily depreciation (exp:depreciation), maintenance and faults, and auctions at 40–60% of purchase price. Book asset values and accepted Jobs join lending collateral. Legacy logistics vans are registered as already expensed assets: their original exp:vehicle purchase, insurance, upkeep and resale journals stay numerically identical; they are not depreciated a second time. Generic assets use fixed_assets and book depreciation. All new state is lazy and serializable.

QA `--bot=walkthrough --seed=<n> --daily-trace` and Godot `--fixed-fps 60` permit identical-clock migration comparisons. daily_results.json records day, ledger balances, statistics and RNG state; wall-clock/render metadata are excluded. Normal games continue using random seeds and real-time pacing.
