# #66 Media / Advertising + University — 2026-10-02

Stacked from codex/65-real-estate-residential / PR #82; latest Claude base a9124264 merged before work and before PR. User stopped the remaining queue at #66. No #67/#68/#69/#71 work and no friend-beta issue changes.

## Validation
- Godot 4.5.1: 313/313 tests, 8 dedicated media cases; raw logs contain no SCRIPT ERROR / ERROR / failed tests. Runner now awaits async cases, so Creative Pitch card bounds and prior Company OS navigation are actually exercised.
- Full zh_TW walkthrough seed 63001: 1826 steps, 0 failures, 192.8 seconds. Includes all twelve story chapters, manufacturing, real estate and new media fixture through actual metro/lease/minigame cards/mix buttons/Jobs invoice/save-load. Story fixtures keep their separate documented opening capital.
- Latest media-only UI confirmation: 0 failures, 4.4 seconds; english audit contains only existing language selector English. Full audit retains existing generated names and brands outside this ticket; its new media text is clean. Campaign report status follows translated Company OS status labels.
- i18n: 3579 msgids, missing 0. wiki_check: OK, 3830 assets / 228 data IDs.
- Final bash tools/package_release.sh exit 0: Windows/Linux/macOS/Web all produced. build_size_check: Web index.pck 150,987,400 bytes <=160 MB; Windows ZIP 173,883,537 bytes <=180 MB. package-release.log and SHA256SUMS.txt attached. One preceding import attempt crashed inside Godot; a standalone import retry and the entire package script then succeeded. Native screenshots used Compatibility OpenGL; screenshots are not browser runtime certification.

## Actual 120-day balance
Fifteen unfiltered runs: three strategies, seeds 66001..66005. Starting $60,000 is QA equity (standard account $25,000 plus $35,000), never income. Actual leases, hiring, payroll, creative/proposal spending, campaigns, Net 30 collection and naturally triggered crises. Conservative hires an intern and limits budgets; normal hires designer/buyer; aggressive also buys owned radio when cash allows. Each recorded day checks double-entry balance and segment totals against MonthClose. All runs pass; no artificial crisis injection or removal of losing seeds.

| Strategy | Min operating profit ($) | Max operating profit ($) | Losing seeds |
|---|---:|---:|---:|
| aggressive | -16508.16 | -1351.65 | 5/5 |
| conservative | -3527.40 | 6867.12 | 2/5 |
| normal | -18263.08 | 15277.43 | 3/5 |

The initial 7-day campaign setting made all sampled strategies profitable and was rejected. The final 14-day scope exposes working-capital/payroll/failed-pitch risks without changing the specified $5k–80k budget, $1,800 rent, $950 designer salary or $350 intern salary. All five aggressive runs lose; this is an explicit tuning concern, not proof of balanced long-term profitability.

## Issue and #63 common acceptance
- University is active/reachable by M1. Aurelia University / The Loft / Campus Radio have actual furnished interiors, NPCs (Dr. Imani Cole, Kai Morgan, Nia Park), conversations, studio lease, campus client jobs and cheap intern recruitment. Decorative cafe/bookshop use existing art. Named facade requests are in art backlog; supported fallback metadata/doors are preserved. No art source changes.
- Jobs briefs carry budget/awareness-or-conversion goal/four audiences/deadline. Proposal and creative cost cash/time and can fail. Creative Pitch has distinct clickable slogan/visual/tone cards, preferences readable from brief/mentor; skill raises quality and designer assistance is faster than intern assistance.
- Seven CPM/audience/saturation channels; normalized allocations and daily impressions/clicks/conversions; players can change future mix. At least three real tradeoffs: audience/channel shares, creative fit, staffing/capacity, acquisition/upkeep.
- Traceable service fee + 12–15% rebate + earned KPI bonus. Deposits are liabilities until completed work is invoiced; Net 30 is an actual receivable, not free cash. Missing KPI reduces reputation and brief volume/budget. Cancellation invoices only performed work and refunds unused deposit.
- Internal cost-price campaigns change actual Cafe.ads_factor / Ecommerce.demand_mult, with source.internal and explicit included-internal-cost segment display. No internal service markup or rebate. Hotel currently has no implemented demand model in this stack: its entry is hidden and eligibility rejects inactive hotels; a saved hotel boost API remains for the hotel issue to consume. This cross-ticket dependency is not claimed implemented.
- Solo → agency (two completed jobs + actual designer/buyer, three slots) → owned radio (Assets, depreciation, maintenance, failures, finite inventory sold through Jobs). Loan basis includes receivables/signed jobs and radio book value through shared Bank. Jobs/inventory sale cannot be paid twice.
- Three registry crises: public relations, client departure, CPM increase. Timeline, standard Staff, OS/Board, glossary/help, stable button names, lazy old-save defaults and actual save/load. Company closure refunds/invoices once, auctions assets and cancels media callbacks.

## Self-review fixes
1. Paused jobs reserve capacity; insufficient next-purchase cash cannot resume or open extra slots.
2. Reject non-finite CPM/share input; final buying day consumes the exact remaining cents.
3. The Loft now exposes a real lease interactable. Recruitment routes employer registration to City Hall and successful postings to People; owned radio exposes repair and prerequisite next steps.
4. Creative cards originally overlapped because their parent was a plain Control: corrected to spaced VBox; regression checks all four actual button rectangles. Disabled timed expiration for this untimed preference puzzle.
5. Production errors notify instead of silently dropping results. Finished selection clears; running mixer has report next action. Raw English invoice status is translated.
6. Genuine async tests are awaited; old-save test saves and loads an actual file without media state. Closure, assets, canceled Jobs and duplicate callbacks all tested.

## Visual review
Personally inspected 19 native JPGs: all three interiors and facades, university day/night, prerequisite routing, client briefs, creative intro/cards/result, mixer/daily metrics/report, group campaigns, owned-media acquisition/inventory and Company OS. No missing textures, overflow or newly untranslated UI; money/percent/time/exposure units and prerequisite ✓/✗ plus next step are visible. English organization/person brands remain intentionally retained. Gallery equity $200,000 is an explicit test fixture to inspect owned media, not ordinary starting cash.

## Remaining limits
Hotel integration depends on the stopped hotel ticket. Native compatibility rendering was inspected; browser runtime play was not measured. Aggressive strategy lost in every sampled seed, so later balancing may improve its viability while retaining downside. Dedicated future University facade art remains requested; current fallbacks are fully usable.
