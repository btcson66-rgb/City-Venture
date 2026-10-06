# #89 replay and scenarios

Implemented: new-game rules and seed, story/sandbox choice, six openings, Monday UTC weekly challenge, local scores and opening/result cards. #92 is unmerged, so the card uses the simple net-worth/time/rating version.

Validation on 2026-10-02: **289/289 unit tests, 18.0 seconds** (`unit.xml`); i18n **3184 translated, missing 0**; wiki_check **OK, 3830 assets / 197 data ids**. Related native Chinese replay tour: **24 samples, 0 failures**, including 18 normal-policy samples and six idle controls. Every opening has a winning normal sample. Normal outcomes: 15 won, one lost, two still running. All ledgers balanced. The venture deadline is 18 calendar months, beyond the 120-day sample. These examples demonstrate viable strategies and variability, not guaranteed profitability for every seed or strategy.

Four JPGs show setup, selection, opening and settlement. Screenshot/report/XML evidence totals below 1 MB. Bot policies use ordinary purchasing, shipping, job, café and delivery APIs with time costs; no forced orders or fixture income.

Self-review fixes: keep the sole primary action visible while setup scrolls; restore unread cards after loading; preserve/report corrupt leaderboard files; deduplicate earlier-save attempts; freeze weekly parameters during character creation; avoid invented rating when no work evidence exists; retain decimals in loan/cost ledger notes; continue property costs after success. Tests cover old saves without run state, seed/hash reproduction, nonfinite inputs, all openings, exact deadlines, company closure, immutable settlement and local-history corruption.

Pre-merge limits: full rendered walkthrough deferred under the user's latest instruction; beta_audit.py is absent in the target; inherited #98 performance/coverage gaps remain. Maple Court is a financial scenario asset, not a new explorable property scene. No real Safari/controller hardware acceptance is claimed. Story/content tickets owned by the other session are untouched.
