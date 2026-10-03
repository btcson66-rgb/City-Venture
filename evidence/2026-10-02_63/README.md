# #63 industry framework acceptance

Stacked on #74; no new industry added. Base a9124264 merged before work and final validation.

- 284/284 unit tests passed (24.6s), including real registration/dispatch/hour/closure, segment rounding and old untagged journals, Jobs Net 0/30/60, deposits/late penalties/closed-company collection, Assets buy/rent/depreciation/maintenance/failure/auction, fixed-asset lending and actual save/load.
- Full zh_TW walkthrough, same seed 63001 and `--fixed-fps 60` on both revisions. 0 failures before and after. 188 daily snapshots (including final endpoint), exact equality of day, journal account balances, stats and RNG state, **0 differences**. `daily_diff.json` and both complete traces are attached. This uses the real input-driven walkthrough with all chapters; fixed FPS removes machine-time drift, not steps or economic ticks.
- Before source: 5865b48d with only identical QA seed/trace instrumentation applied. After source: this branch. Daily snapshots intentionally exclude additive segment metadata and wall-clock/render state.
- i18n missing 0; wiki OK. Screens: 3 JPG from actual Company OS, 0 English flags. All three images inspected: no missing art, horizontal text overflow or untranslated new text; dollar units everywhere; primary action returns to Overview's next action.
- Four-platform package_release.sh succeeds. Web index.pck 150,690,792 bytes (150.69 MB); Windows zip 173,740,921 bytes (173.74 MB). Both required limits pass; SHA256SUMS attached.
- Raw walkthrough flags: 23 existing brand/client/staff names, language self-name and registration identifiers. No new English text versus baseline; item review attached. The new Segments screen independently has 0 flags.
- GUI report screenshots use seeded journal fixtures (two sales and shared rent), not claimed as a player-earned revenue cycle. Last month is zero because the fixture starts June 1.

## Self-review findings repaired

1. Hiding inactive consulting/SaaS tabs initially removed their startup routes. Added separate launch actions with stable existing button names; same-seed full walkthrough is again identical.
2. Daily depreciation of a non-divisible price could leave a cent past its lifetime. Final-day remainder is now cleared; 100/3-day regression added.
3. Added asset collateral shifted Bank.offer's positional debt filter. Changed to nonzero signed components so original five-component reasons, debt and cap remain intact.
4. New tests initially called an unsupported `runner.near`; the runner's summary alone did not detect the resulting script errors. Replaced with real tolerance assertions, reran, and scanned raw logs for SCRIPT ERROR/ERROR in addition to the pass count. Only the deliberate unknown-event warning in the prefix fixture remains.
5. Closure callbacks stop software development and café owner shifts; operating assets/jobs cannot re-collect after closure. Ecommerce's ad/listing shutdown and existing Contracts terminal/AR cleanup moved behind its registry callback, retaining the other work line's changes.
6. Added guards for non-finite job/asset values, negative maintenance cost and invalid rental periods; tests cover real legacy save loading and round-trip.

## Compatibility / limits

Legacy logistics vans were purchased through exp:vehicle, not capitalized. Assets adopts them as `legacy_expensed`, preserving original purchase/insurance/upkeep/auction amounts and avoiding double depreciation. Generic new assets capitalize to fixed_assets and depreciate normally. Existing contract fields, queues and story receipts remain unchanged; financial line builders are shared with Jobs. New state sections are lazy.

#63 does not add an industry or balance a new industry. 120-day strategy reports are mandatory for each subsequent industry ticket under the added New industry checklist.

## Commands

```text
godot --headless --path game res://tests/test_runner.tscn
godot --headless --fixed-fps 60 --path game -- --bot=walkthrough --lang=zh_TW --seed=63001 --daily-trace --out=<out>
python3 tools/qa/daily_compare.py <before>/daily_results.json <after>/daily_results.json --out=<diff.json>
python3 tools/i18n_extract.py --check
python3 tools/wiki_check.py
bash tools/package_release.sh
godot --path game --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --script ../tools/qa/segments_gallery.gd -- --out=<screens>
```
