# Issue70 — trade RFQ / Deal Sheet foundation (PARTIAL Draft)

Stacked on PR #105. Required shared framework issue63 / PR76 remains unmerged. No parallel Jobs, Assets or industry ledger was created. Actual industry execution is BLOCKED, not completed.

- Full unit suite: 302/302, 16.9 s; seven new quote tests. Current quotes, trade terms, insurance, credit, invalid routes, capacity/demand, save round trip, expiry, home-import tariffs and no invented money are covered.
- i18n missing 0; wiki_check OK. Short rendered zh_TW tour: 41 steps, 0 failures, 25.0 s. Four JPGs at quality 85. World-map setup is a fixture; region entry, quote route, DDP, air transport and refresh use native controls.
- English audit contains only the existing language selector English; no new-text hits.
- beta audit: 13 existing hits; NOT PASSED. Full walkthrough running on issue31 as the every-three-ticket cadence. No second full run here. Final integration gates deferred as requested.

Implemented: eight regions with local-unit supply price / capacity / demand; existing spot FX and Customs tariffs; EXW/FOB/CIF/DDP cost ownership and distinct risk transfer; sea schedule and air speed/cost; optional insurance with mandatory CIF cover; four payment risk/fee estimates; seller margin versus buyer landed ceiling; finite RFQ lifetime, cargo/default percentages, daily hold warehouse-rent estimate. Preview accessible without owned goods/company. No execution, settlement or fake earned revenue.

Self-review fixes: FOB/CIF reject air; home-region imports have explicit tariffs and home-currency receipts avoid a fictitious currency drop/spread; CIF risk transfers at loading despite seller insurance costs; dynamic labels translated instead of showing service ids; native option inputs reset popup selection before choosing; repeated previews leave Ledger and saved business state unchanged. The stress scenario can lose money even when a competitive base quote has positive margin.

Not implemented / unresolved: RFQ acceptance, actual Jobs lifecycle, L/C documents and release, warehouse rent Ledger and Customs adapter, insured cargo crises, forward settlement (shared issue42), all three growth tiers, Meridian premises / NPCs, staff / lending / agency / factory integration, 120-day three-strategy balance, actual trading route and customs execution screenshots. Airport exterior depends on issue68. This PR must remain Draft until these issue70 acceptance items are completed; preview tests are not business acceptance.

前張#31正常merge複驗：511/511（147.5秒），native trade_execution 0 failures /29.9秒，無SCRIPT ERROR；i18n5434 missing0、wiki280 OK、beta0。保留海關兩位NPC與進出口動作、產業事件、海外帳目與所有關閉清理；重複customs_guide圖示鍵已移除，未動素材。翻譯/wikidata兩邊新增保留，沒有rebase。最後整合完整gate仍待#99尾端验证。

最後補入#31選品及季節性供應缺席檢查後（788cd29b），完整單元測試511/511（138.7秒）、國貿短版0失敗（29.2秒），皆無SCRIPT ERROR。誤用未定義的--from=trade所啟動流程已停止，不列驗收；正確短版為--from=trade_execution。
