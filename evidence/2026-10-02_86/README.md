# #86 industry introductions — refreshed acceptance evidence

Six real four-step stories now load from `game/data/story/side_stories/`. Phone Opportunities accepts them; Business Board names the actual mentor/workplace and selects that district on the city map with the mentor/workplace caption. Company OS opens optional saved guidance. Omar Haddad now has NPC data, a customs-house work spot, weekday schedule and an actual dialogue.

The native Traditional Chinese short tour accepts the manufacturing story through the phone, talks to Lena, leases and equips the factory, hires a technician, accepts an actual OEM order, buys materials, schedules production, encounters actual first-hour defects, chooses outsourcing, delivers the batch and reads its Timeline receipt. Ledger balance is checked. No story revenue is injected.

## Verification

See `unit.log` / `unit.xml` for the final complete suite; `tour-final.log` / `short-tour-result.json` for rendered tour counts. New industry tests include all six trigger/completion/previously-completed/closed-company paths, optional guide save compatibility, expiry, inactive-company ownership and both real recovery choices. Generic side-story tests cover every sequential step being already done or impossible.

Translations have zero missing entries; wiki_check passes; beta_audit has zero hits. The English audit's remaining entries are the language selector, player-entered company name, registration code and beta version label. Screenshot evidence is JPG, with the whole ticket directory below 20 MB.

## Disclosed fixtures and limits

The tour uses a controlled capital contribution of $200,000 and advances the calendar/material delivery time. The company name is First OEM. Those are setup/time controls; actual purchases, production, subcontract cost and invoice use existing industry APIs and Ledger. Unit tests use controlled completion/quality receipts to isolate no-replay and scheduler boundaries.

Existing industry systems supply the detailed license exam, client proposals, hotel group bookings, auction faults, grants and station operations. The hotel story currently accepts the first completed group booking, without requiring a peak-season calendar date. The energy introduction uses Okoro's existing subsidy conversation, without adding a separate seminar scene. Automotive defects are never fabricated for a healthy car; already sold cars skip that opportunity. Those narrative limitations remain visible in the PR.

The complete integrated walkthrough is still pending; the earlier #93 run failed 58 assertions and #94's exit was not established. No claim of complete stack acceptance is made here. Keep this PR Draft.

## Self-review fixes

- Replaced incomplete fake company save fixtures with real registration.
- Filled shared tutorial defaults without losing earlier coaching progress.
- Prevented another company's expiry from modifying selected-company flags.
- Moved guide button names off translation extraction lines, translated OEM invoice text and clarified subcontract costs.
- Added the guide help card, actual mentor map caption, played save and JPG evidence.
