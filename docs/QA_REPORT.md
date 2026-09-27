# CITY VENTURE — QA Report · CITY-VENTURE-VERTICAL-SLICE-001

Build: `0.1.0-vs001` · Engine: Godot 4.5.1 (Compatibility renderer) · Branch: `claude/exciting-bardeen-y71ixv`

This report follows the kickoff rules. Something is **PASS** only when a player really does it in the build and there is evidence.
**PARTIAL** means it works but falls short of the bar. **FAIL** means it does not work. Implementation status uses
Implemented / Mocked / Placeholder / Planned / Blocked. "Mostly done" is never PASS.

Evidence lives in [`evidence/vs001/`](../evidence/vs001/):

| Folder | Contents |
|--------|----------|
| `test-reports/` | `unit.xml` (JUnit) and `unit_console.txt` |
| `screenshots/walkthrough/` | Rendered 1280×720 frames. The walkthrough bot captured them while playing the slice with real input events |
| `screenshots/tour/` | Scenery tour: every district, every interior, dusk/night, City Map, World Map |
| `logs/` | Walkthrough logs (headless run and rendered run), every step and assertion with in-game time |
| `videos/` | `vs001_gameplay_uncut.mp4`: one uncut take from New Game through Company OS, recorded by Godot Movie Maker |

## How the slice was verified

1. **Automated tests.** `godot --headless --path game res://tests/test_runner.tscn` runs 25 tests over the economy,
   ledger, events, story, save/load, failure state and data validation. Result: **26/26 PASS**.
2. **Walkthrough through real input.** `tests/walkthrough/bot.gd` plays the whole slice the way a person would. It
   presses movement actions to walk. It finds its way around with the same navigation grid the NPCs use. It opens doors
   by walking into them and presses **E** at interactables. It clicks buttons with mouse events at their on-screen
   positions and types the company name into the text field. It never calls game logic directly to skip a step. It
   asserts outcomes along the way: stock arrived, first order, cash moved, company registered, save/load restored.
   Result: see the table below.
3. **Uncut video.** The walkthrough was recorded end-to-end. Nothing is cut or edited, so any error on screen stays in the file.

| Run | Result |
|-----|--------|
| Unit tests | 26/26 PASS at evidence time. 30/30 after localization (+4 i18n tests) |
| Walkthrough, headless (full slice + month close + save/load) | **0 failures**, 707 s. In-game Jun 1 → Jul 1 (month close ran). 297 orders delivered. Save → reload restored cash, time and location. Ledger balanced |
| Walkthrough, rendered at 1280×720 with screenshots | **0 failures**, 769 s, 88 screenshots in `screenshots/walkthrough/` |
| Scenery tour | 28 screenshots in `screenshots/tour/` (menu, creator, arrival, every district and interior, City/World Map, dusk, night) |
| Video | **8 min 01 s**, 1280×720 H.264 30 fps, one uncut take, 0 failures in its run |
| Exported Linux build | Ran 600 frames under Xvfb, exit 0 (`logs/export_linux_smoke.txt`) |

All evidence above was produced from commit `f0f70a1` by `tools/collect_evidence.sh --video`.

**Not done: a 30-minute playtest by a human.** Every play-through here was the bot. That is a real limitation. A bot can't
judge game feel, pacing, or whether a first-time player understands what to do. **Status: Blocked (needs a person).**

---

## Vertical Slice checklist (kickoff §6–§29)

| # | Requirement | Result | Status | Evidence / notes |
|---|-------------|--------|--------|------------------|
| 6 | New Game | **PASS** | Implemented | Menu → New Game → Creator (`walkthrough/01–04`) |
| 6 | Character Creator: Name, Face Shape (4), Hairstyle (8), Hair Color (8), Skin Tone (6), Eye Shape (4), Eye Color (6), Eyebrows (4), Mouth (4); Masculine/Feminine/Neutral; outfits Startup Casual / Office Professional / Home | **PASS** | Implemented | Bot changes hair, face, eyes and presentation, types a name, and asserts the look changed. `test_character_options_are_cosmetic_only` checks there are no stat effects. Front/side/back preview plus a portrait with 4 expressions |
| 7 | Arrival → Riverside Apartment; $30,000, rent $1,250, Laptop + Phone, Maya messages, "Earn Your First Dollar" | **PASS** | Implemented | Train arrival sequence, bank balance/rent card, Chapter 1 card, Maya texts (`05–08`) |
| 8 | Riverside explorable: walk, move between locations, enter Apartment / Cafe / Co-working, go outside, NPCs, traffic | **PASS** | Implemented | Walkable district, 3 enterable buildings. Co-working is in Startup Hub; you reach it on foot through the east exit or by Metro. Named NPCs follow schedules, pedestrians walk paths, cars and buses drive in lanes |
| 9 | Startup Hub: street, co-working, small office, cafe, NPCs, Business Board | **PASS** | Implemented | `walkthrough/12–15`, `tour/07–10` |
| 10 | Interiors: Apartment, Cafe, Co-working, Small Office, Bank, City Hall. You walk to a spot to use each function | **PASS** | Implemented | 8 interiors, all walkable. Functions open at interactables (desk, counter, teller, packing table) |
| 11 | Ecommerce: Product, Supplier, Wholesale Cost, MOQ, Inventory, Listing, Price, Customer Order, Shipping, Return, Review, Advertising, Revenue, Expenses, Cash | **PASS** | Implemented | Buy from supplier (MOQ, lead time, capacity, Net terms) → stock arrives at a location → list with a price → demand sim creates orders → pack at the table → courier or drop-off → delivery → payout (Monday, 2-day hold) → reviews/returns/refunds → ads spend. All postings go through the double-entry ledger |
| 12 | Products from data; extensible | **PASS** | Implemented | `game/data/products/*.json` (4). `DataDB.validate()` |
| 13 | Month Close: Revenue, COGS, OpEx, Rent, Advertising, Shipping, Refunds, Profit, Cash; Profit ≠ Cash; AR/AP | **PASS** | Implemented | `walkthrough/…month_close_report`. Profit and cash differ because of the payout hold, stock on hand, deposits and parcels in transit. AR is used by B2B contract invoices (Net terms), AP by supplier Net terms |
| 14 | Business Registration at Civic Center; company name in Company OS, Contracts, Office Sign, Timeline | **PASS** | Implemented | City Hall form → name typed by the bot → Company OS header, contract parties, Suite 2B sign in the world and the interior, phone timeline |
| 15 | Company OS opened only at a desk: Overview, Finance, Sales, Operations, Inventory, People, Contracts | **PASS** (People minimal) | Implemented. People: founder + contacts; hiring **Planned (P1)** | Only opens at a work spot: the apartment laptop, a co-work desk, a café table, or the Suite 2B desk. Property / International / Reports are shown disabled as Planned |
| 16 | Chapters 1–3 (first income → first customer problem → company registered) | **PASS** | Implemented | Log: chapters done `ch1_arrival, ch2_first_customer, ch3_open_for_business` |
| 17 | ≥3 dynamic events that change money / inventory / decisions | **PASS** | Implemented | 7 data-driven events. Seen in the final walkthrough: first customer return, 12 customer returns, supplier price increase, unexpected large order (B2B contract), viral mention, low cash warning. Each choice has ledger or stock effects. Ad cost spike is defined but did not fire in these runs |
| 18 | Failure state: Warning / Sell Inventory / Reduce Spending / Continue, no game over | **PASS** | Implemented | `low_cash_warning` event and `test_low_cash_warning_is_not_game_over`. Bankruptcy is **Planned** |
| 19 | Save/Load: character, appearance, date, time, cash, position, inventory, orders, company, story | **PASS** | Implemented | Walkthrough saves, reloads, and asserts cash, time and location. `test_save_load_round_trip` covers the full state |
| 20 | Time: day flows; Morning/Afternoon/Evening/Night; shops Open/Closed | **PASS** | Implemented | Continuous clock with day parts and the day/night lighting. Opening hours block doors (e.g. City Hall weekdays 9–17) |
| 21 | Pixel art: grid, scale, Neo-Civic palette, character size, building scale, UI theme | **PARTIAL** | Placeholder / converted concept art | Art Pass v3 converts the approved concept boards into game sprites and backdrops (see Art Manifest). It is consistent, but it is not final hand-made art. Characters are the weakest match to the boards |
| 22 | Light HUD: money, time, objective, minimap, prompt | **PASS** | Implemented | Management UI only opens from interactions |
| 23 | No multiplayer; keep the CompanyEntity ↔ CompanyEntity boundary | **PASS** | Implemented boundary; network **Planned (P4)** | Contracts are between entity ids (player company ↔ NPC company) |
| 24 | No real crypto, wallets or money | **PASS** | — | Stablecoin settlement exists only as data marked `planned`. Nothing connects to any network |
| 26 | Automated tests + human-style walkthrough | **PARTIAL** | — | Tests and a bot walkthrough with real input: done. Walkthrough by a human: **not done** |
| 27 | Evidence folders + QA report | **PASS** | — | This file and `evidence/vs001/` |
| 29 | 5–10 min uncut gameplay video from New Game through Company OS | **PASS** | — | `evidence/vs001/videos/vs001_gameplay_uncut.mp4`, 8:01. New Game → Creator → Arrival → Apartment → Riverside → Bloom Coffee → Startup Hub → Nexus Co-work → Business Board → buy stock → list → first order → pack/ship → first dollar → customer return → City Hall registration → Nexus Bank → Suite 2B → Company OS → a working day → save/reload |
| — | Windows build | **PARTIAL** | Exported | `tools/build.sh` exports `build/windows/CityVenture.exe` (embedded pck). It was **not run on Windows**: there is no Windows machine in this environment. The Linux export of the same project was smoke-tested |

## Localization (added after the evidence run, at the product owner's request)

| Requirement | Result | Status | Evidence / notes |
|-------------|--------|--------|------------------|
| Chinese version | **PASS** | Implemented | 1,175 strings in Traditional Chinese (zh_TW), covering UI, dialogue, events, story, products, places and NPC roles. Simplified Chinese (zh_CN) is generated with OpenCC tw2sp. `tools/i18n_extract.py --check` reports 0 missing |
| Language switch | **PASS** | Implemented | Main menu and pause menu: English / 繁體中文 / 简体中文. Switches instantly, saved to `user://settings.cfg`, defaults to the OS locale |
| Full playthrough in Chinese | **PASS** | — | Rendered walkthrough with `--lang=zh_TW`: **0 failures** (Jun 1 → Jul 1, registration, contract, month close, save/load). `logs/walkthrough_rendered_zh_TW.txt`, `screenshots/zh_TW/` |
| Translation quality | **PARTIAL** | — | Written for natural, short Taiwanese Mandarin, but **not proofread by a native editor**. zh_CN is machine-converted and still needs a Mainland-Chinese pass before release |
| Chinese names | **PASS** | Implemented | Player and company names can be typed in Chinese (e.g. 「河光商行」), and the font falls back to Noto CJK in every language. Unit test `test_chinese_company_name_registers` |
| Layout with CJK fonts | **PASS** | Implemented | The CJK fallback makes lines taller. Negative font spacing gives the height back, so English keeps its original metrics. Month Close now scrolls instead of pushing its button off-screen. The regression was caught by the bot |
| Mixed-language records | Known limitation | — | Phone messages, timeline and ledger memos keep the language that was active when they were written |

## Tester build 0.1.1-test1 (for sharing with playtesters)

| Package | Size | Verified here | Status |
|---------|------|---------------|--------|
| Windows (`CityVenture.exe`, single file) | 45 MB zip | Runs under Wine 9 (Mesa llvmpipe OpenGL 4.5) and shows the main menu. **Not yet run on real Windows hardware** | PARTIAL |
| Web (single-threaded, needs no special server headers) | 20 MB zip | Headless Chromium (WebGL2): menu → 繁體中文 → character creator → apartment, player moves, no console errors. Firefox/Safari not tested | PASS (Chromium) |
| macOS (universal, ad-hoc signed `.app`) | 74 MB zip | Built and bundle structure checked (executable bit, signature, Info.plist). **Not run on a Mac** | Blocked (no Mac here) |
| Linux | 38 MB zip | Runs under Xvfb | PASS |

Each package includes a tester guide in Chinese and English (install steps including SmartScreen/Gatekeeper, controls,
suggested route, what to report, save paths, known issues). **F12 bug report** saves a screenshot, the current save, the
log and an info sheet, then opens the folder; the web build downloads these files instead. The shots tour checks that F12 writes the report.

## Playtest round 1 → build 0.1.2-test2

The product owner played the web build and reported five problems. Each one, and what was done about it:

| Feedback | Cause found | Fix | Status | Verified by |
|----------|-------------|-----|--------|-------------|
| "Not enough of a tutorial; I didn't know walking to the door takes you outside" | Hints were only the objective text and the prompt | **Tutorial card** (8 steps: move, phone, leave a room, follow the goal, use things, time, map, Company OS). Each step completes when the player does it. Progress is saved; Skip, and Replay in the pause menu. **Gold guide arrow** to the current objective, routed through room exits, street edges and the Metro. It shows as an edge pointer when the target is off screen and can be turned off in the pause menu. **Always-on exit markers**: a glowing EXIT mat in every room, "District →" chevrons at street edges, and "▲ Enter X / Closed" chips at doors. Phone / Map / Menu are clickable HUD buttons, and the interaction prompt can be clicked | Implemented | Walkthrough screenshots `07_apartment_arrival`, `09_riverside_outside_home` (en + zh). Chromium web run (`screenshots/web/`) |
| "Some text inside buildings is garbled" | ① The NPC name **Jun** was also the msgid for the month "Jun", so Chinese showed **6月** over his head. ② Name tags used the pixel title font at 5 px ("Maya" read as "Moyo"). ③ The café menu board had 3×5 glyphs with no gap between rows, cut to 9 letters. ④ The "[Tab] Phone" hint had no background and drew over walls and windows. ⑤ **✕ ⚑ ▸ and three emoji are in none of the bundled fonts.** Desktop borrows them from the OS; the web build has no system fonts, so they showed as boxes. ⑥ Window light beams spilled outside the room | ① "Jun" maps to itself; player, company and NPC names are never run through the catalogue. ② Name chips in bold Inter with a dark backing, shown only when the player is near (so they don't cover wall signs). ③ Board redrawn at 66×34 with spaced rows. ④ Replaced by the button bar. ⑤ Swapped for glyphs the fonts have (× › ◆), emoji removed. Titles now fall back to Inter before the CJK fonts. A script checks every character in code, data and translations against the fonts: 0 missing. ⑥ Beams clipped to the room | Implemented | zh_TW interior screenshots, font coverage scan |
| "Refreshing the page mid-game made me start over" | Autosave ran only when sleeping and when the world began | **Continuous autosave** to slot 0: every scene change, every 15 s of play when something changed, on window focus-out/close, and on web `visibilitychange` / `pagehide` / `beforeunload`. A "Saved" tick shows by the minimap | Implemented | **Chromium test:** new game → walk outside → reload the page → Continue is enabled ("Alex Chen · Day 1") → the game resumes on the Riverside street with the tutorial on the same step. At most about 15 s of play is lost |
| "Too few careers to choose from" | Only ecommerce was playable | **5 part-time jobs** (Barista, Parcel Sorter, Community Host, Records Clerk, Teller Trainee). Each has a 3-rank promotion ladder with wage raises, 4-hour shifts worked on site during opening hours (one per day), and one real perk (free coffee, 15% shipping discount, free hot desk, half-price registration, no overdraft fees). **Freelance consulting** is now an active business: gigs each morning, work at any laptop in 2-hour sessions, deliver, invoice (receivable), paid on 0/7/14-day terms. Reputation 0–5★ moves the rate and unlocks bigger gigs; late work costs 20% and stars, abandoned work is cancelled unpaid. Wages appear in Month Close and Company OS | Implemented | Unit tests `test_careers.gd` (7 tests: pay, opening hours, promotion, perks, gig invoice → payment, cancellation). Walkthrough "Careers" steps (hire, shift, gig) in both languages |
| "Still not happy with the visuals" | Art is procedural or converted from the concept boards (see Known issues) | Not changed on this track. The owner plans to hand visuals to Codex. [`docs/ART_HANDOFF.md`](ART_HANDOFF.md) gives the swap contract (paths, sizes, metadata, text rules), and `tools/build.sh` no longer regenerates art unless `REGEN_ART=1`, so hand-made art is not overwritten | Planned (art track) | — |

**Regression runs for 0.1.2-test2:** unit tests **41/41** (`test-reports/unit.xml`; new: `test_careers.gd` 7,
`test_onboarding.gd` 3). Full rendered walkthroughs from New Game to the July month close, now including the Careers
steps (hire at the Business Board, work a 4-hour shift for $72.00, accept a freelance gig and work 2 h), pass in both
languages: **English 0 failures (787 s)** and **繁體中文 0 failures (821 s)**. Logs: `logs/walkthrough_0.1.2-test2_*.txt`.
Screenshots: `screenshots/test2_en/`, `screenshots/test2_zh_TW/`, `screenshots/web/`.

Two bugs were caught by these runs before release. ① The job modal awaited a fade after closing itself; the
coroutine died with the modal, so no wages were paid and **the screen stayed black**. The shift now runs on the
persistent UI root. ② The trailer's interact shot targeted Jun's talk spot, which sits inside the counter; the shot
now walks to the counter front.

## Bugs found by the evidence runs (fixed before the final run)

| Bug | How it showed up | Fix | Guard |
|-----|------------------|-----|-------|
| A customer-return decision could get stuck open. The player was soft-locked because the decision can't be closed | Walkthrough looped on "Send a replacement" at Jun 14 07:00 | "Send a replacement" used to require stock of *any* product. It now requires unreserved stock of the returned product (`has_stock:{product_id}`) | Unit test `test_replacement_needs_stock_of_that_product`. The bot now reports a decision that stays open instead of retrying |
| Toasts could swallow clicks on the Company OS | Bot: `AdPlus_wireless_earbuds` not found (the earbuds listing click never landed) | Toasts, location cards and chapter cards are now fully mouse-transparent | Bot logs on-screen context when a button lookup fails |

## Known issues and gaps (honest list)

- **Characters vs the boards.** In-world sprites are procedural 32×48 layers with an outline shader. They read clearly,
  but they don't have the detail of the board close-ups. Portraits are closer, but they are still generated.
- **Art is converted, not final.** The boards are AI concept images. Handoff §83 says to convert them into game-ready
  sprites, and `tools/art/concepts.py` does that. A pixel artist should still produce the final assets. Two pieces of board
  text were changed to match game data: the cafe is now "Bean & Byte", and City Hall's "Riverdale" sign reads "Aurelia".
- **No audio.** There is no music or SFX in the slice yet.
- **One human playtest so far** (the product owner, web build, first chapter). Balance and game feel beyond Chapter 1
  have only been exercised by the bot.
- **Planned, not built:** hiring and payroll (P1), overseas play (P2), Property / International / Reports tabs,
  bankruptcy, and the stablecoin settlement layer (simulation only, when it arrives).
