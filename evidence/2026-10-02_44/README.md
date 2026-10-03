# #44 — Friends beta content visibility

Stacked on PR #75. English and Traditional Chinese are the supported acceptance locales for this work, following the user's revised instructions.

## Specification review

1. Business Board lists only active businesses, with a safe selection fallback. Future active data appears automatically.
2. Company OS has no unfinished navigation rows.
3. City Map leaves inactive districts as scenery without labels, controls or a planned legend.
4. Metro destinations and the line diagram contain only active districts.
5. World travel entries appear only when more than one active region exists.
6. Permits excludes the unfinished data protection registration.
7. Four unfinished buildings use status=planned, keep their interior data, and expose no entrance/guide/minimap destination. Setting status=active restores working destinations. Okafor advertises the available cafe. NPC-only rooms appear only while real story conditions and schedules make them usable. Old saves inside hidden rooms return to the original street door without altering their books.
8. Help cards describe available activities.
9. Creator describes the outfits actually selectable today.
10. beta_audit checks player-facing JSON and script presentation text, including autoload and multiline calls. Inactive data is excluded; four exact exemptions describe delivery route planning and delayed shipments. Packaging runs this audit.
11. beta_tour visits the active districts and available rooms, verifies a real interaction/NPC, opens Board/Map/Metro/Permits/Guide/OS/Phone, checks the first company-registration action, and loads a genuine pre-closure save from a hidden room.

## Validation

- Godot 4.5.1: 278/278 unit tests passed, including five visibility/access/old-save tests.
- Full walkthrough: zh_TW 0 failures (2592.6 seconds, rendered); English 0 failures (2354.0 seconds, headless).
- Final rendered beta_tour: both locales 0 failures; separate English discoverability walkthrough 0 failures (54.8 seconds).
- i18n: 3078 message ids, missing 0. wiki_check: OK, 3830 assets and 191 data ids.
- beta_audit: 0 hits; Python audit tests: 5/5.
- Four-platform packaging and hashes: package.log and package_sha256.txt.
- New screens and all destination JPGs inspected. Chapter cards are allowed to finish before capturing destinations. Names, registration identifiers and the English language selector are intentional English, as recorded in the raw audits. No new untranslated prose found.
- Screenshot evidence uses JPG, under 20 MB for this ticket. Full-run PNGs and exported packages remain outside committed evidence.

## Self-review fixes

- Avoided recursion between building availability and simulation action blockers by checking structural access and real NPC schedules directly.
- Hid leased-only rooms before access is obtained; kept NPC negotiation rooms usable at their actual schedules and classified them as services.
- Preserved door spawns for hidden buildings so old saves return to the correct facade.
- Corrected relative-day scheduling and raw old-save loading in screenshot fixtures.
- Waited for the real chapter card to disappear before room screenshots.
- Made unavailable permit actions secondary, with one usable primary action. Employer registration uses the same business entity as the simulation, including registered founders who have not opened an account.
- Added people/order units, formatted visible HUD and supplier amounts with money0, and refreshed the persistent HUD personal label after a locale switch.
- Expanded the text audit to autoload and multiline presentation calls, with regression coverage.

No issue requirement was intentionally deferred. This PR retains its predecessor's changes because it is stacked; review #44's delta against codex/39-discoverability. Merge in order.
