# #113 Multi-item packing self-review

- Implemented actual multi-SKU demand, reservation, packing consumption, delivery income, full-basket refunds and atomic replacement checks.
- Product footprint/height, kg weight and fragility; three box grids/material costs/dimensions; rotatable cell placement; saved padding drives transit damage; postage uses greater of kg and dimensional kg.
- `desk_monitor` is available from Harbor Home Goods and requires a large box. Existing monitor-desk illustration is reused; no assets were edited. B2B bulk contract freight remains its separate existing flow.
- Manual score rewards the smallest fitting box. Skill-1 staff oversize and under-pad; skill-5 staff use a fitting box and safe padding. Beyond five manually played orders use the explicitly labelled skilled automatic policy.
- Focused tests: 9/9, 3.1s. Full tests: see unit.log. Includes existing genuine historical-save/journal regressions and new legacy-order/placement round trip.
- Rendered real-input tour: 0 failures, 6.6s, English audit empty. Every item placed through stable grid buttons; medium multi-item and large bulky parcel sealed, applied to inventory/ledger, then real postage quote inspected. Five JPGs, quality85.
- 120-day cost study: 3 seeds each for manual/novice/skilled. Mean parcel contributions $4299.47/$3131.05/$4294.67; every strategy has losing days, all journals balance. Identical per-day supplier-defect seeds. This excludes wages/rent/ads/demand and does not claim whole-company profitability.
- Self-review fixes: historical sale memo gettext pattern retained; all-line defect/reservation/return total; missing-SKU pack/replacement atomicity; zero quantities, duplicate quantities and negative padding rejected; viewport size/right scroll; white explanation text on light slip fixed; postage moved into visible area; honest automatic-batch description.
- i18n missing0; wiki OK; beta0; no asset diffs. No human playtest, merge or release. Packing uses a deterministic greedy fitting plan (valid fits, not a proof of globally optimal arrangement).
