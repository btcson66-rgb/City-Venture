# Issue 31 — Chapters 13–14 (Draft)

Stacked on PR #103. Base fetched: a9124264, unchanged. No rebase, no assets changed.

- Unit suite: 295/295, 16.8 s; 10 new customs tests and updated season-one ending / Customs House expectations.
- i18n: missing 0; wiki_check: OK. Logs and JUnit are included.
- Rendered zh_TW short tour: 86 steps, 18 source screenshots, 0 failures, 81.5 s. Eleven feature JPGs at quality 85, below 20 MB. Real UI banking, local pricing, packing, shipping, conversion, Ines, tariff selection and document correction. Company, stock, customer orders and time are fixtures; payments use actual handlers and Ledger.
- English audit: only existing language selector English and SHOPLANE brand. New text clean.
- Third-ticket full rendered walkthrough started in the background. PENDING: its result must be reviewed before leaving Draft or merging.
- beta_audit tool is absent from base. Borrowed read-only issue44 tool reports 13 existing unfinished-text hits. NOT PASSED; beta-audit.log records each hit.

Acceptance: Chapter 13 year-nine news, Maya, Marcus and international account, Northridge price / actual shipment / receipt conversion, honest income card. Chapter 14 weekday 09:00–16:00 Ines with permanent guide alternative, DDP/DDU with category tariff codes, real duties and held parcels, document correction versus full fine versus withdrawal. Ten-unit trial, returns below 15%, three-day return observation, two-week nudge / five-unit fallback / explicit pause review. Closure skips without invented income; earlier actions reconcile and old season-one ending saves advance. Glossary, help, schema, wiki, story implementation and art backlog updated.

Self-review fixes: company closure skips both chapters immediately; banking / pricing / conversion update objectives immediately; pause retains receipt containers for accepted orders; return observations wait three days; correction tax is paid once and changes buyer-paid policy to seller-paid; holds expire after seven days with stock restoration; fallback NPC pose uses supported idle; effect is registered with data validation; international opening fee and receipt components preserve decimals; pickup fee is allocated; short-tour weekday calculation uses relative days. Existing season-one ending tests retain their original endings while asserting the new continuation.

Remaining concerns: full walkthrough and final integration checks are pending; beta audit remains blocked by existing unfinished text. Short tour exercises real payment input with fixtures, not a long-horizon economy calibration. The income card allocates a currency conversion quote across the latest matching paid order; its displayed net explicitly excludes stock, packing, duties and refunds. Prior issue86 industry work remains partial until its separate prerequisites merge.
