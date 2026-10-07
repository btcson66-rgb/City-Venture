# #154 — less paperwork, real transactions

Audit was committed and pushed first (`1e8b542`), before implementation. All three PRs remain Draft;
the issue's audit-merged criterion is not satisfied by a Draft. No merge was requested.

## Before / after game-feel-review

Before: first parcel requires repeated packing/shipping; administrative details compete with decisions.
After: twelve saved switches default ON, settings master and context controls; actual chosen businesses,
accepted orders, employees and assets only. No new borrowing, investment, equity or imaginary revenue.
Reasonable supplies/packing/accountant/bank choices keep their real costs rather than optimal bonuses.

Final first-three-chapter log counts: **92 → 76** use/click/choose entries (**16 fewer, 17.4%**).
Packing/courier buttons **12 → 0**. Method excludes movement, waiting and minigame internal drag events
on both sides; see `steps.json` and retained log prefixes through the actual Chapter 3 receipt.
Both prefixes have zero failures. Final new-game replay: **0 failures, 328.2 s**, including a real business-loop
graduation card. Assistant packing guidance fits two lines; after a real first sale it does not force a side job.
The original 75-action intermediate replay gained one completion-card click in final polish.
The baseline complete run has three subsequent office-exit harness
failures; fixing nested feature-intro closure resolves exit in the new-game after run.

| Repeated chore | Before → after | Evidence / limit |
|---|---|---|
| Packing/shipping in played first 3 chapters | 12 → 0 clicks | actual paired logs |
| Restock a previously listed product | select supplier/product/order → 0 | actual buy API, funded 90-day tests; source count |
| Due tax filing | inspect/select/pay/confirm → 0 | actual tax liability + accountant fee + processing delay |
| Trade documents | three documents + HS code → one prepare button / 0 delegated | existing paid shipment/LC API |
| Coffee supplies, cleaning, schedule | daily supplies/clean/weekday shifts → 0 | owned branch, employed baristas, paid materials/work |
| Maintenance | choose due asset/service → 0 | operating owned assets; real car-return constraint and service downtime |
| Routine return | inspect/refund confirmation → 0 | actual refund + postage; first unhappy customer remains a decision |
| Bills / policy renewal / FX | repeated payments → 0 | true liabilities, premiums and bank spread; existing signed obligations remain |

Source-based rows describe changed flow requirements, not measured clicks or universal savings.

F1 PARTIAL: inherited mechanic teaching belongs to #149; existing safe feature practice retained.
F2 PARTIAL: no assistant countdown; inherited minigame timers/deadlines are not changed (#150).
F3 PASS for new-game controls: currently useful details, early OS three core tabs, at most three phone objectives.
F4 PARTIAL: merged administrative actions; all mature industry cards have not been universally redesigned.
F5 PASS for twelve listed chores: default ON, real costs, saved opt-out and cash recovery notification.
F6 PARTIAL: early finance and default tax show three useful numbers; brand details in tooltip; other cards inherited.
F7 targeted PASS: no credit creation, old played pre-assistant save, balanced funded 90-day fixtures and idempotent bills.
Full main-story PASS below: actual 24 chapter receipts, all objectives, all switches and save/load assertions.
F8 PARTIAL: neutral new controls; inherited bright gold `info_tip` remains #152's protected scope.

Newbie observation: choose a product and price, see a real first sale without mandatory repeated packing,
then register and choose workspace. Initial travel, story decisions and first customer complaint remain.
Experienced player: disable individual chores, keep manual mechanics, reuse saved choices and existing assets.
No physical mobile or large-text-device verification. Screens are native rendered 1280x720 zh_TW/en and
640x360 zh_TW. UI tour fixtures are display evidence; `played_*` shots come from actual new-game play.
UI tour audits contain the player-chosen company name `Quiet Trading` in two case/layout variants.
Novice audit contains the ShopLane brand and beta release label. Main audit's seven strings are proper names
(Haddad Distribution, Tess Ferreira, ShopLane, a clipped Hale Group label). No new assistant text is missing;
the existing clipped company-history label remains a mature-screen limitation.

## Validation

Full suite: **935/935 passed (383.1 s)**, no SCRIPT ERROR. Afterwards a cash-warning conditional was corrected;
all **16/16 assistant tests (48.9 s)** pass with explicit funded-no-warning and warning-once assertions.
The corrected implementation subsequently passed the full suite again: **935/935 (386.6 s)**.
Self-review also synchronized the existing finance FX checkbox with the saved assistant policy;
an actual checkbox-toggle regression, hourly callback and **16/16 (48.1 s)** assistant tests pass.
Global lifecycle tests **10/10 (6.1 s)** pass; final updated full suite **935/935 (385.4 s)**, no SCRIPT ERROR.
Final onboarding polish adds a meaningful regression: focused **4/4 (6.6 s)**, including the visible guide text,
and updated full suite **936/936 (377.0 s)**, no SCRIPT ERROR. UI text shortening was subsequently checked
in the three final native-render tours (six captures each, 0 failures) and localization check.
Legacy manual fixtures disable assistant callbacks; assistant tests explicitly enable all switches.
Fixtures fund operating capital as equity, never revenue. 90-day fixtures cover commerce, coffee, tax,
insurance, contracts, manufacturing, maintenance, returns and FX/trade. They do not promise every strategy profits.

i18n: 8086 zh_TW translations, **0 missing** (including assistant help/guide). Wiki OK (3913 assets / 343 IDs), beta 0 hits,
map adjacency OK (12 districts / 20 links), whitespace clean. Desktop/compact/English UI tours: 0 failures each.
Corrupt-save decompression tests and headless renderer shutdown leak messages are inherited diagnostics.

Main 1–24 with all switches ON: **PASS**, genuine checkpoint chain, no phone reply input.
Actual new game completed 1–3; 4–12 continuation loaded that played checkpoint (SHA256 in `steps.json`);
13–24 resumed its real autosave after harness corrections. Each retained segment has 0 failures.
Final segment: **0 failures, 1496.0 s**, all 24 chapter receipts/all objectives verified, all twelve switches ON,
ledger balanced; save/load preserves cash, time and location. Final cash $116,452.92 company / $151,884.53 personal,
6975 real deliveries. `main_manifest.json`, the three `chain_*.log` files, final native result and played save
retain the evidence. This is a resumed chain, not a claim of one uninterrupted run. Failed/interrupted attempts
remain outside Git. No story/ledger staging; final onboarding UI polish has the separate fresh-game 1–3 replay.
Harness fixes accept actual automatic FX conversion instead of waiting for a now-empty wallet, use
Contracts' real `shipped` state and close management modals before sleeping for assistant dispatch.

## Scope / remaining work

No minigame directory or info_tip edits. Small shared fixes: FeatureGate checks Staff's real `people` collection,
PhoneMessages localizes the new assistant sender. Tax/Cafe APIs accept background processing without
recursive Clock.advance while retaining manual time cost. No Company OS tab restructuring in #154.
Small tutorial.gd change uses real sale progress to make the side job optional and changes assistant-on packing
guidance; no minigame mechanics or first-use practice framework changed. Existing finance FX checkbox now
updates the same saved policy, so a manual choice is not silently reset on the next hourly callback.
No needless economic rules deleted: remaining universal F4/F6/card simplification is explicitly incomplete.
