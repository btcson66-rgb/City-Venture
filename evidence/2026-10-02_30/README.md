# Issue 30 — overseas systems (Draft)

Stacked on PR #102 (issue 86 infrastructure). Base fetched: a9124264, unchanged. No merge/rebase, no assets changed.

- Unit suite: 285/285, 16.4 s (10 new overseas tests); unit.xml and unit.log.
- i18n: 3140 messages, missing 0; wiki_check: OK (3830 assets, 191 data ids).
- Rendered zh_TW short tour: 53 steps, 13 source screenshots, 0 failures; six JPG feature views at quality 85. Banking, storefront, pricing, packing, courier and conversion use real buttons; company/stock/customer/time are fixtures. Full walkthrough is due on the third ticket (#31), and final merge checks remain deferred as requested.
- English audit: new text clean. Two existing hits: language-selector English, uppercase SHOPLANE brand.
- beta_audit is not in the base branch. Borrowed read-only unmerged issue44 tool reports 15 existing unfinished-text hits. Gate NOT PASSED; retained in beta-audit.log.

Self review fixes: sorted currency iteration makes JSON save/load preserve FX path; restored RNG seed with saved state; 1-day volatility shocks apply before expiring; paid refunds cannot spend another order's unpaid receipt; overseas parcels cannot use a same-day van or tutorial delivery shortcut; opening-account callback handles failures; locked markets do not route to irrelevant banking; empty product lists route to domestic listing; one primary button in new sales/finance/packing flows; international account fee, memos and quotes preserve decimals. Closure converts receipts once and cancels future returns/disputes.

Acceptance mapping: FX daily bounded mean-reverting quotes, 1.5% spread, era multipliers and expiring shocks; foreign-unit weekly wallets and explicit realized FX ledger; seven regional store/price/demand configurations; shared ecommerce stock and packing with international economy/express cost/time; currency/freight/industry/revenue regional facts and unlock reasons; five glossary badges/help; schema/Ledger/wiki/art requests. Systems only; Chapter 13 unlock/story follows in issue31. Overseas travel remains outside scope.

Remaining concerns: full rendered chapter walkthrough and final integration gates are pending; initial regional balance parameters are tested for a rational profitable margin and a reachable FX-loss margin, not long-horizon economy calibration. Domestic forecast currently estimates domestic ShopLane cash, so foreign wallets must be considered separately. Issue86's unmerged industry dependencies remain explicitly partial in PR102.
