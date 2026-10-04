# Issue 96 self-review evidence

Implemented shared tax, legal, insurance and brand services through Industries, Segments and Jobs. All evidence uses the original account and actual ledger movements; isolated founder/damage fixtures are QA inputs, not a full-story commercial acceptance run.

- Governance tour: 71 steps, 18 screenshots, 0 failures, 43.8 seconds. Real phone and City Hall filing, actual Job receivable disputed through the UI, settlement schedule, UI insurance purchase, recorded repair and insurer payment, normal save/load. Screenshots are JPG, 2.17 MiB total.
- Seventeen governance regression tests cover VAT/refund bounds, personal-to-company liability transfer, annual pretax/loss carry, late fees and credit, DIY correction and timeout, three legal routes and loss/timeout, construction pause/resumption and duplicate prevention, wages/IP, coverage waiting/deductible/limit/renewal/closure, weighted brand inputs/decay, save migration and one primary. Entire suite: 521/521 in 134.5 seconds, no script errors; unit-tests.xml/log retain the result.
- 15 runs × 120 days: careful average AUD 7,933; normal AUD 23,386; reckless AUD -10,886 (five of five losses). Paid service Jobs require real subcontract work costs. Positive tested strategies still have explicit 2.5% default nonpayment probability; five profitable seeds do not prove guaranteed profit. This is a service-economy test, not proof of every possible multi-industry portfolio.
- Raw English audit: six findings are the proper name Elias, existing company registration code AUR, claim identifier INS and inherited beta label. No untranslated new UI prose remains. These findings are preserved rather than silently removed.

Review fixes: net VAT rather than gross revenue assertions; no retrospective or duplicate refund/insurance credits; contribution transfers; own income-tax expense added back; original company closure guards; preserve paid construction and resume work; finite counterpart effects change actual advance terms; actual vehicle premiums precede claims; no invented IP/wage income; zero returns close without fines; weighted hotel reviews; precise claim-paid translation; isolated unit save directories for concurrent sessions. One intermediate suite failed when another runner removed its shared save; it is not a passing gate and was replaced by an isolated rerun.

Limits inherited from earlier tickets remain in SESSION_A_DELIVERY.md. No Session B/C functionality or artwork was implemented.

Industries regression: 338 steps, 61 screenshots, 0 failures in 373.7 seconds. Actual industry bookkeeping and normal save/load pass; 13 raw English findings remain inherited. No retail car was sold in the automotive rendered fixture, so this is not proof of an automotive first retail sale.
