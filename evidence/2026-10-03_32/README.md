# #32 Moving house

Implemented: data-driven home/bed/storage/rent, real personal tenant deposits, 30-day notice or one month termination cost, free first physical stock move and subsequent paid service, all-company stock/PO/packed shipment locations move together without transferring company money. Okafor rental board, usable Studio 1A laptop/table/bed, dynamic wake/rent/default inventory locations. Opening deposit is an existing asset; legacy saves get no invented deposit.

Validation: 572/572 unit tests (213.9 seconds), 9 housing tests; targeted rendered tour 0 failures (46.5 seconds), screens 0 failures (31.9 seconds). i18n 5908/5908 missing 0; wiki_check OK (3830 assets/281 data ids); beta_audit 0. New text English audit clean; language selector/version strings are expected. 14 reviewed JPG images; evidence about 2.1 MB.

Self-review fixes: inactive Studio status caused street fallback; home-specific bed position; only current tenant can use home equipment; storage counts incoming PO and packed orders across all companies; old home no longer accepts new POs; notice expiration with insufficient cash/storage keeps old home, retries or refunds deposit; previews require current tenancy; readonly registration checks fixed separately on #91 PR130. Save round-trip and pre-feature fixture tested.

Limits: notice is extended if unable to move rather than forcing homelessness; no owner housing or personal vehicle until #94. Integrated full tour from #93 failed (58 failures/6875.4 seconds); chapter 7 profit policy and bank/navigation cascades remain under investigation. This ticket does not claim a full walkthrough PASS.
