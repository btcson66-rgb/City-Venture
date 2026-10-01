# CITY VENTURE — Roadmap

## Now (from 0.1.8): tickets on GitHub

Claude plans and reviews, Codex implements: each item below is a GitHub issue written as a complete spec, labelled
`codex`, done on its own branch and Draft PR against `claude/exciting-bardeen-y71ixv`, and merged after review.
The working agreement is `docs/CODEX_GUIDE.md`. Status of the game today: Chapters 1–12 Implemented; businesses
ecommerce, freelance, SaaS, café (Old Town) and logistics (Harbor) Implemented; districts Riverside, Startup Hub,
Civic Center, Financial, Shopping Street, Old Town, Harbor Implemented.

| Priority | Issue | What |
|---|---|---|
| P0 | [#21](https://github.com/btcson66-rgb/City-Venture/issues/21) | Purchase cancellations and returns (fix a wrong stock order) |
| P0 | [#22](https://github.com/btcson66-rgb/City-Venture/issues/22) | Save export/import; old-version save fixtures as regression tests |
| P0 | [#23](https://github.com/btcson66-rgb/City-Venture/issues/23) | itch.io web publishing (butler) and an in-game "what's new" card |
| P0 | [#24](https://github.com/btcson66-rgb/City-Venture/issues/24) | No soft-locks: every chapter step and tutorial step handles "already done" and "no longer possible" (Implemented, merged in #37) |
| P0 | [#36](https://github.com/btcson66-rgb/City-Venture/issues/36) | Closing a company ends its B2B contracts; a sold receivable is never collected twice |
| P0 | [#39](https://github.com/btcson66-rgb/City-Venture/issues/39) | See where you can do things: interaction markers, a "what you can do here" card, a City Guide phone app |
| P1 | [#25](https://github.com/btcson66-rgb/City-Venture/issues/25) | "!" explanation badges on every existing screen |
| P1 | [#26](https://github.com/btcson66-rgb/City-Venture/issues/26) | 4× detail art for buildings, ground tiles and vehicles |
| P1 | [#27](https://github.com/btcson66-rgb/City-Venture/issues/27) | Era street dressing: port cranes (Year 3), solar roofs and EV chargers (Year 4) |
| P1 | [#28](https://github.com/btcson66-rgb/City-Venture/issues/28) | Player van colour and lettering, route map alignment, seated expressions |
| P1 | [#29](https://github.com/btcson66-rgb/City-Venture/issues/29) | Economy balance so every chapter goal is reachable with sensible play |
| P1 | [#40](https://github.com/btcson66-rgb/City-Venture/issues/40) | Look-only shops get something to do: Crestline market research, Harbor Point gym membership and networking |
| P2 | [#30](https://github.com/btcson66-rgb/City-Venture/issues/30) | Season 2 systems: World Map, regional storefronts, currencies and FX |
| P2 | [#31](https://github.com/btcson66-rgb/City-Venture/issues/31) | Season 2 Chapters 13–14: first order abroad, customs (DDP/DDU) |
| P2 | [#32](https://github.com/btcson66-rgb/City-Venture/issues/32) | Moving house (Old Town Studio 1A and other homes) |
| P2 | [#33](https://github.com/btcson66-rgb/City-Venture/issues/33) | Café depth: seasonal menu, shifts, health inspection, a second café |
| P2 | [#34](https://github.com/btcson66-rgb/City-Venture/issues/34) | Logistics depth: route contracts, a second van, breakdowns and maintenance |
| P2 | [#41](https://github.com/btcson66-rgb/City-Venture/issues/41) | Pop-up Unit 5: a weekend pop-up shop on Shopping Street (physical retail channel) |
| P2 | [#42](https://github.com/btcson66-rgb/City-Venture/issues/42) | Season 2 Chapters 15–16: the currency swing (forward contracts), a partner overseas (distributor vs 3PL) |
| P2 | [#43](https://github.com/btcson66-rgb/City-Venture/issues/43) | Season 2 Chapters 17–18: consolidation (niche or scale), legacy (endings and epilogue) |
| P3 | [#35](https://github.com/btcson66-rgb/City-Venture/issues/35) | Free play after the story: growth goals and achievements |

**Work order for Codex** (one ticket at a time; start the next from the latest `claude/exciting-bardeen-y71ixv` once
the previous PR is merged): #21 → #36 → #39 → #22 → #23 → #25 → #29 → #40 → #28 → #26 → #27 → #30 → #31 → #42 → #43 →
#41 → #32 → #33 → #34 → #35. A ticket whose dependency is not merged yet waits; take the next one instead.

Next in line (tickets written when the above land): new districts (Residential, University, Luxury Heights, Airport,
Industrial), each with one business.

---

## Original milestone plan

> Priority order for every milestone (kickoff §30): **Game Feel → Core Loop → World Navigation → Business Depth → Story Integration → Visual Cohesion → Stability → Additional Content.**
> Every milestone ships a **playable build**, automated tests, a scripted gameplay walkthrough and an evidence folder. A human playtest is required before a milestone is called done.
> Status per item: Implemented · Mocked · Placeholder · Planned · Blocked.

---

## P0 — Vertical Slice (`CITY-VENTURE-VERTICAL-SLICE-001`)

### Scope

| Area | Content |
|------|---------|
| Flow | Boot → Main Menu → New Game → Character Creator → Arrival sequence → Riverside Apartment |
| Character | Name; Face Shape, Hairstyle, Hair Color, Skin Tone, Eye Shape, Eye Color, Eyebrows, Mouth; Presentation Masculine / Feminine / Neutral; outfits Startup Casual, Office Professional, Home. All cosmetic. |
| World | Aurelia: **Riverside** and **Startup Hub** (full walkable districts), **Civic Center** and **Financial District** (compact walkable blocks). Walking exits between districts, Metro stub, City Map screen, World Map screen (overseas locked, P2). |
| Interiors | Apartment, Bloom Coffee (Riverside), Nexus Co-work (Startup Hub), Small Office (Startup Hub), Nexus Bank (Financial), City Hall (Civic), PostPoint parcel shop (Riverside) |
| Living city | Ambient pedestrians on schedules, traffic lanes, named NPCs with schedules and dialogue, shop hours, day/night |
| Business | Ecommerce end to end: suppliers, wholesale cost, MOQ, purchase orders, lead time, inventory by location, photography, listing, pricing, ads, demand model, orders, packing, courier vs drop-off shipping, delivery, reviews, returns, refunds, weekly marketplace payouts |
| Finance | Double-entry ledger, AR/AP, personal vs company entities, rent, living costs, Month Close report |
| Company | Registration at City Hall (name, type, address, fee), business bank account + capital injection at Nexus Bank, Small Office lease, company name on Company OS, contracts, office sign and Timeline |
| Company OS | Opened only from Apartment laptop, Co-work desk or Small Office desk. Tabs: Overview, Finance, Sales, Operations, Inventory, People, Contracts |
| Story | Chapter 1 Arrival, Chapter 2 First Customer, Chapter 3 Open for Business |
| Events | Customer Return, Supplier Price Increase, Unexpected Large Order (B2B contract, Net terms), Ad Cost Spike, Viral Mention |
| Failure | Low-cash warning → Sell inventory to liquidator / Reduce spending / Continue. Overdraft and late fees, never game over. |
| Save | Manual and autosave. Character, appearance, date and time, cash and ledger, position, inventory, orders, company, contracts, story, NPC state, timeline |
| Time | Continuous clock, day parts, sleep, hold-to-fast-forward, open/closed hours |
| Art | Generated Neo-Civic placeholder pixel art for all of the above |

### Dependencies
Godot 4.5.1 · export templates · placeholder generator · no external services.

### Acceptance criteria
Handoff §93 Definition of Done, all 18 items, plus kickoff §6–§29. In particular:
1. A new player can go New Game → Creator → Apartment → walk outside → Cafe → Co-work → pick Ecommerce → buy inventory → list → first sale → register company → Company OS without dev tools.
2. Each of the 6 required interiors is entered by walking through a door, and each function is used by walking to an interactable.
3. First revenue comes from a specific order (units × price), and the payout arrives later as cash.
4. Month Close shows Revenue, COGS, OpEx, Rent, Advertising, Shipping, Refunds, Profit and Cash, and Profit differs from Δcash when AR/AP exist.
5. At least 3 dynamic events change money, inventory or options.
6. Cash near 0 triggers a warning with recovery options. No game over.
7. Save → quit → load restores the exact state and position.
8. Every UI/visual element uses the pixel palette and theme. No default gray Godot UI.

### Tests
Headless unit tests (sim), integration tests (scenes), walkthrough bot (full flow), save round trip, 30-day soak (simulate a month with the bot's policy and assert invariants: ledger balances, no negative inventory, month close reconciles).

### Evidence
`evidence/vs001/`: screenshots of every scene and state, a 5–10 minute uncut walkthrough video from New Game, test logs and reports, the Windows build, and `docs/QA_REPORT.md` with PASS / PARTIAL / FAIL per criterion.

---

## P1 — Aurelia Expansion

### Scope
- Districts: Shopping Street, Harbor, Old Town, Residential, University (walkable). Metro becomes a real network (5 lines, timed rides, stations).
- Second industry: **SaaS** (client contract → build → deliver → subscription MRR/churn/servers). It reuses Contract, Payment, Office and Hiring with different logic (§90).
- **People**: hiring, salaries, payroll day, staff capacity (packing, support), resignation events.
- **Bank**: loans (Marcus Reed), credit history, interest, covenant-like conditions.
- Vehicles: used compact/sedan purchase, driving changes travel time, parking, running costs.
- Chapters 4–6 (Growing Pains, The Big Contract with Daniel Wong $420k Net 60, Cash Is Oxygen), and Elena Park (VC) offers.
- Event library expansion (staff, finance, market categories §32).
- Formal bankruptcy flow (§2.7): company closure → liquidation → downgrade home → credit damage → restart.
- Wardrobe/customization room, clothing store, more outfits (Executive, Luxury Citywear, Travel, Formal).
- Audio pass (§86–87).

### Dependencies
P0 ledger/contracts/events stable; art manifest P1 rows.

### Status (build 0.1.3)
- **Implemented:** SaaS (build → launch → subscriptions, churn, servers, features); People (hiring, weekly payroll,
  capacity, morale, resignations); Bank (loans from the books, credit score, missed payments, called loans);
  Chapters 4–6 with Elena Park's offer; formal bankruptcy flow (rescue / restructure / close → restart); also part-time
  jobs and freelance consulting.
- **Still planned:** new districts (they need art from the visuals track), Metro network expansion, vehicles,
  wardrobe store, audio pass, event library expansion.

### Acceptance criteria
SaaS plays differently from Ecommerce (no shared income formula). Payroll can be missed and has consequences. A loan changes cash and creates debt service. Ch4–6 are playable. Bankruptcy recovery loop is playable.

### Tests / Evidence
As P0, plus a 3-month soak and a bankruptcy scenario test.

---

## P2 — World / Overseas

### Scope
- **World Map** becomes playable: 7 markets, Airport interior, commercial flights (schedules, time cost), Harbor shipping routes.
- FX, customs, import duties, overseas suppliers (Lumina, Zenkai), international trade basics, overseas branch.
- Settlement methods: Bank Wire, Payment Processor, Letter of Credit, Escrow. **Year 5 Clearing Crisis**, and only then the simulated stablecoin rail with full risk modelling (Ch9–Ch10). Bridge Exploit (Ch11), Regulation Wave.
- Lina Zhao, Omar Haddad.

### Dependencies
P1 bank/loans, contract currency and settlement fields (already in schema).

### Acceptance criteria
Crypto never appears before the Clearing Crisis trigger. Every rail shows its trade-offs. The bridge exploit can hurt a player who chose that rail. No real-world wallet, chain or money integration.

---

## P3 — More Industries / Holdings

### Scope
Food/Cafe, Logistics, Manufacturing, Real Estate (player buildings appear on the city map, e.g. VENTURE TOWER), then Consulting, International Trade, Media, Hotel, Automotive, Energy. Second company, holding group, internal contracts and transfer pricing. Property purchase, housing ladder to Penthouse/Villa, decoration, luxury cars, private jet (travel time plus real costs). Life Timeline and Legacy screen.

### Acceptance criteria
Each industry passes the "really different gameplay" check (§91). Holdings consolidate correctly in the ledger.

---

## P4 — Enterprise Network (multiplayer expansion)

### Scope
Player company ↔ player company contracts (quotes, counters, OEM, logistics, franchise, licence, JV), built on the entity-symmetric contract system. No pay-to-win: paid content = new gameplay only.

### Dependencies
Single-player economy complete and stable (§70). **Not started before P3 ships.**

---

## Commercial release track (runs alongside P1–P2)

The product owner wants to sell the game and ship it on the App Store. This track is independent of the content
milestones. The engine choice is in [`ENGINE_DECISION.md`](ENGINE_DECISION.md): stay on Godot 4.x.

| Item | Status | Acceptance |
|------|--------|-----------|
| Localization: English · 繁體中文 · 简体中文, switchable in game | **Implemented** (VS001+) | `tools/i18n_extract.py --check` reports 0 missing. Full walkthrough passes in zh_TW. Native-speaker proofread still **Planned** |
| Final art (pixel artist repaints the converted/generated assets) | Planned | Every row in ART_ASSET_MANIFEST marked Final |
| Audio (music + SFX, commercially licensed) | Planned | Menu, city ambience per district and day part, UI and interaction SFX |
| Touch controls + mobile UI scale | Planned | Tap-to-walk, on-screen interact button, 44 pt touch targets, safe areas, iPhone and iPad layouts |
| Performance budget | Planned | 60 fps on a 2020-class iPhone. Simulation stress test (10 companies, 5k orders/day) in CI |
| Steam build (GodotSteam: achievements, cloud saves) | Planned | Steamworks review passed |
| iOS build (StoreKit, Game Center, iCloud saves) | **Blocked** (needs macOS + Xcode + Apple Developer account) | TestFlight build |
| Android build (Play Billing) | Planned | Internal testing track |
| Store compliance (privacy labels, age rating, simulated crypto disclosure) | Planned | App Review guidelines checklist signed off |
| Onboarding tutorial + goal guidance | **Implemented** (0.1.2-test2) | Tutorial card, gold guide arrow, EXIT mats and edge signs. Needs confirming with first-time players |
| Continuous autosave (incl. web refresh) | **Implemented** (0.1.2-test2) | Chromium reload test passes; at most about 15 s of play lost |
| Careers beyond ecommerce | **Implemented** (0.1.2-test2): 5 part-time jobs + freelance consulting | Unit tests + walkthrough. SaaS (P1) is still the next full business |
| Human playtests (onboarding, balance) | **In progress** (round 1: product owner) | 5+ first-time players, 30-minute sessions, notes filed |
