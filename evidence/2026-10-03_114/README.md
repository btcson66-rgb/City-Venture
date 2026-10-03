# #114 — work stations and client consulting

Implementation: complete service stations at Bloom Coffee; change/return review, meeting-room conflicts, damaged-parcel quarantine and complaint handling at the other four jobs. New consulting projects have interviews, proposals, scope changes, execution, revisions, acceptance, rating and real invoice/payment scheduling. Four different task interactions use the paused minigame framework.

## Verified gates
- Godot 4.5.1 full unit suite: **506/506 in 152.3s**. Workflows: **10/10 in 3.8s**.
- Actual-input short rendered tour: **0 failures in 17.2s; 0 untranslated texts**, 16 JPG screenshots, approximately 1.01 MB. The fixture deliberately sets one project to two hours, Net 0 and a guaranteed scope event to reach all stages; every action, score, time jump, invoice and payment uses the real flow. Other task games use their actual data and click inputs.
- `i18n_extract.py --check`: 5240/5240, missing 0. `wiki_check.py`: OK. `beta_audit.py`: 0 hits.
- Played pre-change #111 story-complete save loads: one historical gig stays legacy, the ledger is unchanged and balanced. The only normalized comparison field is existing `ledger.seq` JSON float-to-int migration. Source gzip is already committed under #111; `legacy-save-receipt.json` records the uncompressed hash. No synthetic save is described as a played fixture.
- Nine matched-seed simulations × 120 actual game days: conservative mean profit AUD$3,722.40, normal AUD$9,680.00, aggressive -AUD$5,886.59. Each strategy has losing days. Ledger and consulting/shared totals agree; receivables remain separate from cash. Simulation uses actual offer generation, service work, revisions, acceptance, collection and personal living costs; no operating income is injected.
- Final rendered chapter 1–12 walkthrough: **PENDING**, executing from a new game in `full-final-units`. Do not open the next ticket until the result is verified.

## Self-review repairs
- Only client acceptance or agreed discounted settlement permits a service invoice; duplicate acceptance cannot invoice again.
- Daily consulting hours aggregate across projects, including lazy migration from saved per-project usage.
- Dirty tables can be cleaned from another customer's ticket without double-counting cleanup.
- Scope changes add actual work; uncovered revisions require agreed paid work or discounted settlement. Failed acceptance has a recovery choice.
- Closed entities cannot reopen projects after a clock jump. Existing unfinished projects and earned promotions retain their legacy path.
- Consulting answer buttons have shuffled visual positions; task choices are not arbitrarily marked primary. New monetary amounts use `Fmt.money`.

## Limits
#95 is OPEN/unmerged: energy integration is **Blocked**. Actual shift/session hours and the existing early-rest rule are used; no parallel fatigue state is added. The four execution interactions are data-based three-round tasks, not arbitrary document editors. Extra part-time service stages determine employer shift pay; they do not book the customer's cash as player income. All PRs stay Draft; no merge/deploy or asset edits.
