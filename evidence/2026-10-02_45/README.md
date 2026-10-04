# #45 — 0.2.0-beta acceptance

Version is exactly `0.2.0-beta`. Nine player-facing updates have complete English and Traditional Chinese translations. Tester notes cover starting, controls, 12 chapters, 5 businesses, 7 districts, native save directories, export/import/backups and F12/Pause reporting.

| Check | Result | Evidence |
|---|---|---|
| Headless unit suite | 296/296 | cv45-unit-final.log / cv45-unit-final.xml |
| i18n extract --check | 3233 translated / missing 0 | cv45-package-final.log |
| Wiki | OK: 3830 assets / 191 data IDs | checks.txt |
| Beta audit | 0 hits | cv45-package-final.log |
| en walkthrough | 0 failures / 363.7 s | walkthrough_en_walkthrough_result.json |
| en beta | 0 failures / 8.8 s | beta_en_walkthrough_result.json |
| en screens | 0 failures / 12.4 s | screens_en_walkthrough_result.json |
| en notes | 0 failures / 4.3 s | notes_en_walkthrough_result.json |
| tw walkthrough | 0 failures / 381.8 s | walkthrough_tw_walkthrough_result.json |
| tw beta | 0 failures / 9.3 s | beta_tw_walkthrough_result.json |
| tw screens | 0 failures / 14.2 s | screens_tw_walkthrough_result.json |
| tw notes | 0 failures / 4.5 s | notes_tw_walkthrough_result.json |
| Chromium tutorial | 0 failures; 20 frames; no glyph boxes | tutorial.log / browser-result.json / web_tutorial_*.jpg |
| Chromium download/import | real browser file chooser and downloaded save; 0 failures | cv45-browser.log / web_web_export.jpg / web_web_import.jpg |
| Chromium refresh | progress persists; update acknowledgment persists | web_web_refresh.jpg / web_web_update_refresh.jpg |
| Chromium 0.1.8 fixture | loads and upgrades to 0.2.0-beta | web_web_legacy.jpg / web_web_updates.jpg |
| Package | Windows, Linux, macOS, Web all exported | cv45-package-final.log / SHA256SUMS.txt |
| Web archive | root index, nonthreaded preset, itch file/size limits | web_package.json |

## Self-review

Self-review repairs: whole-dollar money formatting in modals, arrival, notifications and old saved contract history (display only; ledger amounts remain precise); data-authored coffee and desk price labels use current data and Fmt.money0; disabled wardrobe/shift/lease actions lose primary styling; version-aware update tour includes the installed beta; tutorial permits the legitimate order-to-pack transition while still requiring shipping, payment and graduation.

Read every changed source hunk, including historical save/version tests. Five genuine saves (0.1.5, 0.1.6, 0.1.7, 0.1.8, 0.2.0-beta) load, advance three days and keep books balanced. The beta fixture was captured by real chapter-three input from commit 6ce75437; provenance and SHA-256 are included. The English formatting test and Traditional Chinese formatting test preserve the source history string.

Visually reviewed all 39 beta-tour and 40 screen-tour frames per locale, update cards (including the scrolled final nine beta lines), and all Chromium tutorial/download/import/reload frames. No missing glyph boxes, untranslated prose or overflowing text found. English audit candidates are the English language selector, beta version suffix, AUR IDs, brands and generated personal/business names; the browser audit lacks the repository glossary and therefore also reports intentionally retained names. Screenshots contain deliberate fixtures named Riverlight Goods, Balance Screens and CLOSURE FIXTURE. Transitional frames show normal chapter-card fades. Boolean loan prerequisites use check/cross and next steps; numeric thresholds retain units and money0.

## Reproduce

```
godot --headless --path game res://tests/test_runner.tscn
python3 tools/i18n_extract.py --check
python3 tools/wiki_check.py
python3 tools/beta_audit.py
godot --headless --fixed-fps 60 --path game -- --bot=walkthrough --lang=en --out=<isolated-directory>
godot --headless --fixed-fps 60 --path game -- --bot=walkthrough --lang=zh_TW --out=<isolated-directory>
godot --path game --fixed-fps 60 --disable-vsync --rendering-method gl_compatibility -- --bot=beta_tour --lang=zh_TW --out=<isolated-directory>
godot --path game --fixed-fps 60 --disable-vsync --rendering-method gl_compatibility -- --bot=screens --lang=zh_TW --out=<isolated-directory>
bash tools/package_release.sh
```

Repeat rendered tours in English. Each bot uses isolated user data; screenshots are JPG at original 1280x720. `browser_acceptance.cjs` records real Chromium file chooser/download/reload input; `web_export.ps1` temporarily includes tests in the scratch QA export and restores the shipping preset. QA resources are excluded from the final release archives. The final JPG evidence stays below 20,000,000 bytes.

## Handoff and remaining external gates

The user explicitly authorized stacked Draft PRs without waiting for merges. #21 and #36 are closed; #39/#44/#29/#22/#23/#25 await sequential merge. This is local release acceptance, not a published itch build. Claude must merge the stack in order and then execute:

`bash tools/package_release.sh && bash tools/release/publish_itch.sh`

The existing publish script is unchanged. No itch upload and no PR merge were performed. macOS/Linux exports were packaged but not launched on physical macOS/Linux machines; browser acceptance used Chromium on Windows. Private browsing or cleared origin storage still loses browser saves: tester notes instruct export first. Economy #29 records a censored casual strategy that never reprices and cannot complete the mandatory pricing objective; this is retained transparently in its report.
