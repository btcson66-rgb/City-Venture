# Issue 31 self-review follow-up — 2026-10-03

Still Draft, stacked on PR #103. Fetched and merged the designated base; it remains a9124264 and reports already up to date. Latest continuous-mode guidance was read from origin/claude/gifted-franklin-9hr8ju; those newer guidelines and industry dependencies are not yet in the designated base.

- Unit suite: 295/295, 17.5 seconds. Includes both chapters already completed, company closure making both chapters impossible, and an unsuccessful trial with an honest review exit. No runtime errors in the unit log.
- i18n: 3233/3233, missing 0. wiki_check: OK, 3830 assets and 195 data IDs.
- Rendered zh_TW short tour: 0 failures, 84.4 seconds. Five product rows explicitly exercise scrolling to the final active listing. Stock, companies, orders and elapsed days remain fixtures; banking, saved price, shipping, receipt conversion, customs declarations and document correction use real UI input and accounting handlers. English audit contains only the existing language selector and brand.
- JPG evidence only, below 20 MB including the earlier evidence directory.

Self-review corrections: export selection now requires the home packing table to be the product's actual fulfilment location and prefers the largest available stock there; native row input waits for scroll/layout and asserts that the selected listing's price was actually saved; packing defers new decision popups until the courier interaction finishes without deleting the queue; the trial stops waiting when its existing two-week review becomes available; decision primary styling now requires explicit choice-level recommended: true and never promotes an unmarked fallback.

NOT PASSED: the previous full third-ticket walkthrough has 63 failures and remains recorded in ../2026-10-02_31/full_walkthrough_result.json. The fixes above passed the short regression but a new full pass has not been established. The designated base lacks tools/beta_audit.py; the borrowed read-only audit still has 13 existing hits (see ../2026-10-02_31/beta-audit.log). Long-term average profitability is not established by this short input tour. The overseas screen's existing default primary-price selection can still point at an inactive listing; that upstream UI concern is not a successful review gate.

Under the latest request to pass every self-review gate before the next ticket, do not advance this stack. Existing issue 42 uncommitted work is preserved; no new issue 43 branch or PR is opened. Session A and Session C issues remain outside this work.
