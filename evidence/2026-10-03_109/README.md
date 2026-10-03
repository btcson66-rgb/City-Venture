# #109 — player feedback fixes

Status: Implemented; self-review PASS. Integration PR #108 is merged. The latest mandated base f097b906 was merged into this same branch, regenerating the conflicting gettext catalogs with both translation sidecars retained.

- Every generated barista order states Single shot or Double shot; flat white explicitly states Double shot. Rules state the default.
- Shared DestinationHours reads building hours and optional NPC schedules. Tutorial initial prompts, objective text, door/City Guide states and navigation show opening/closing times. Waiting uses normal Clock simulation; closing, overnight windows and weekend closures are handled.
- Closed tutorial and City Guide destinations offer an explicit wait option; the tutorial also offers other activities. NPC story targets for Daniel, Ken and Lina use schedule intersections.
- Net 0/30/60 glossary explains supplier/customer cash timing. Values in supplier cards, purchase history, contracts, freelance Jobs and industry screens have badges. Existing deposit/upfront, MOQ, lead time and AR explanations are reused; AP was added.
- No new save keys and no financial/business formulas changed. Old-save migration and normal-clock ledger checks are in the unit suite.

## Verification

Current-base validation: 458/458 tests passed in 136.9s; short rendered tour 0 failures in 7.6s. See unit-current-base.log and tour-current-base.log. The original implementation evidence remains available in unit.log.
Translation: missing 0. Wiki: OK (3830 assets, 269 data ids). Beta audit: 0 hits. git diff --check: clean.
Rendered Traditional Chinese ticket tour: 0 failures; see tour/walkthrough_result.json and tour.log. English audit contains only existing brand names Gateway / Helio Supply / Helio Warehouse Office; no new text.
Full walkthrough: not run for ticket 1, per Continuous mode (every third ticket).
Balance: existing full balance/industry tests pass; no new revenue or strategy mechanics.

## Self-review fixes

- Always show espresso count, including flat white.
- Find next real weekday opening instead of claiming tomorrow on Friday.
- Intersect NPC presence and building windows; no hard-coded institution hours.
- Query click-time availability before advancing; unknown/unavailable destinations cannot jump time.
- Use vertical tutorial choices and clamp the on-screen arrow caption.
- Refresh only objective hours during visible gameplay minutes, avoiding full HUD relabeling in long simulation tests.
- Restore all importer-generated asset metadata; no art changes.

Seven JPGs (under 2 MB total) were visually inspected for text, hours and layout. These are rendered state screenshots, not a human playtest.

Open doubts: Generic product-independent Jobs currently uses industry screens; the existing freelance Jobs board and all currently printed Net-term fields have been covered. #108 remains an unmerged integration dependency. Human playtest is not performed by automation.
