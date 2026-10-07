# #154 — less paperwork, real transactions

Audit was committed and pushed first (`1e8b542`), before implementation. All three PRs remain Draft;
the issue's audit-merged criterion is not satisfied by a Draft. No merge was requested.

## Before / after game-feel-review

Before: first parcel requires repeated packing/shipping; administrative details compete with decisions.
After: twelve saved switches default ON, settings master and context controls; actual chosen businesses,
accepted orders, employees and assets only. No new borrowing, investment, equity or imaginary revenue.
Reasonable supplies/packing/accountant/bank choices keep their real costs rather than optimal bonuses.

Actual first-three-chapter log counts: **92 → 75** use/click/choose entries (**17 fewer, 18.5%**).
Packing/courier buttons **12 → 0**. Method excludes movement, waiting and minigame internal drag events
on both sides; see `steps.json` and retained log prefixes through the actual Chapter 3 receipt.
Both prefixes have zero failures. The baseline complete run has three subsequent office-exit harness
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
Full main-story result is tracked separately below; do not infer global no-soft-lock from isolated tests.
F8 PARTIAL: neutral new controls; inherited bright gold `info_tip` remains #152's protected scope.

Newbie observation: choose a product and price, see a real first sale without mandatory repeated packing,
then register and choose workspace. Initial travel, story decisions and first customer complaint remain.
Experienced player: disable individual chores, keep manual mechanics, reuse saved choices and existing assets.
No physical mobile or large-text-device verification. Screens are native rendered 1280x720 zh_TW/en and
640x360 zh_TW. UI tour fixtures are display evidence; `played_*` shots come from actual new-game play.
The zh_TW audit's single English item is the player-chosen company name `QUIET TRADING`, not new UI text.

## Validation

Full suite: **935/935 passed (383.1 s)**, no SCRIPT ERROR. Afterwards a cash-warning conditional was corrected;
all **16/16 assistant tests (48.9 s)** pass with explicit funded-no-warning and warning-once assertions.
Legacy manual fixtures disable assistant callbacks; assistant tests explicitly enable all switches.
Fixtures fund operating capital as equity, never revenue. 90-day fixtures cover commerce, coffee, tax,
insurance, contracts, manufacturing, maintenance, returns and FX/trade. They do not promise every strategy profits.

i18n: 8083 zh_TW translations, **0 missing**. Wiki OK (3913 assets / 343 IDs), beta 0 hits,
map adjacency OK (12 districts / 20 links), whitespace clean. Desktop/compact/English UI tours: 0 failures each.
Corrupt-save decompression tests and headless renderer shutdown leak messages are inherited diagnostics.

Main 1–24 with all switches ON: **RUNNING, not yet verified**. Actual new game completed 1–3 without replies;
continuation loads the exact played checkpoint (SHA256 in `steps.json`) after a harness-only optional SaaS
skip/exit correction. Full failed-attempt logs are retained outside Git; no flags or ledger were fabricated
to advance the continuation. Final chapter receipts, all-switch assertions and balance must pass before completion.

## Scope / remaining work

No minigame directory or info_tip edits. Small shared fixes: FeatureGate checks Staff's real `people` collection,
PhoneMessages localizes the new assistant sender. Tax/Cafe APIs accept background processing without
recursive Clock.advance while retaining manual time cost. No Company OS tab restructuring in #154.
No needless economic rules deleted: remaining universal F4/F6/card simplification is explicitly incomplete.
