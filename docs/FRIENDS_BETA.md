# Friends Beta 0.2.0 — scope and rules

The first build we hand to friends. They play it in the browser on itch.io (https://benson-lai.itch.io/cityventure),
with no one standing next to them to explain. The bar is simple: **nothing they can see is unfinished**. Every button,
door, menu entry and story step either works from start to end, or is not there.

Status words follow `docs/CODEX_GUIDE.md` (Implemented / Mocked / Placeholder / Planned / Blocked). This page is the
contract for the beta. Work order: #21 → #36 → #39 → #44 → #29 → #22 → #23 → #25, then the release ticket #45.

## 1. What is in the beta

| Area | In the beta |
|---|---|
| Story | Chapters 1–12, then free play with the growth goal. Season 2 (Chapters 13–18) is not visible. |
| Businesses | E-commerce, freelance consulting, SaaS, the Old Town café, Harbor logistics, manufacturing (#64), real estate (#65), media (#66). |
| Districts | Riverside, Startup Hub, Civic Center, Financial, Shopping Street, Old Town, Harbor, Industrial (#64), Residential (#65), University (#66). |
| Systems | Company, bank, loans, staff, contracts, month close, forecast, settlement rails, compliance, insolvency, wardrobe, minigames, tutorial, "!" badges, help cards, autosave, save slots, F12 problem report. |
| New for the beta | Purchase cancel/returns (#21), safe company closure (#36), interaction markers + City Guide (#39), economy balance (#29), save export/import (#22), "what's new" card and itch.io publishing (#23), "!" badges everywhere (#25). |

> Release note: the industry framework and new industries (#62 art wiring, #63 registry, #64 manufacturing, #65 real estate, #66 media) are merged into 0.2.0-beta. Their districts and businesses are `active`, so the "planned stays hidden" rules above keep covering the rest.

## 2. The "nothing unfinished" rules

1. **No "planned" words in front of players.** No "Planned", "P1", "not in this build", "arrives in a later build",
   "coming soon" anywhere a player can read it (UI, data text, help cards, messages). Docs and code comments may keep them.
2. **Hidden, not teased.** A business, district, region, station, permit row or menu entry that does not work is not
   listed. Lists show only what works (Business Board, Company OS nav, Metro, City Map, World Map, Permits).
3. **A door means something to do.** Every enterable building has at least one interaction that does something real
   (buy, work, talk, lease, a service). A building with nothing to do is scenery: no door prompt, no interior.
4. **Closed places are closed in the story's words.** If a place must stay shut, the reason is part of the world
   ("Customs is open to licensed brokers only"), never a build note. Prefer making it scenery.
5. **Every started thing can finish.** No story step, contract, lease or purchase can be left waiting on something the
   player cannot do (#24 rules, `docs/STORY_IMPLEMENTATION.md` §11).
6. **Money is always explained.** A refused action says why and what to do next (cash, space, hours, licence).

## 3. The audit: what has to change (ticket #44)

| Where | Today | Beta |
|---|---|---|
| Business Board (`business_board.gd` ~line 100, `data/businesses/*.json`) | 7 planned businesses with "Not in this build" | Show only `status: active` |
| Company OS nav (`company_os.gd` ~line 107) | "Planned: Real estate · International · Reports" | Remove the line |
| City Map (`city_map_modal.gd` ~60–72, `data/city/aurelia.json`) | Legend "Planned (P1+)", planned districts labelled | Planned districts drawn as plain city blocks without labels; no "Planned" legend |
| Metro (`metro_modal.gd` ~61) | "Planned stations (P1): …" | Remove |
| World Map (`world_map_modal.gd`) | Overseas regions "Planned (P2)" | Not reachable in the beta (hide the entry), or shows Aurelia only |
| Permits (`permits_modal.gd` ~41) | "Data protection registration — Planned (P1)" | Remove the row |
| Pop-up Unit 5 (`popup_unit`) | Lease notice "(planned)" | Scenery: no door (the pop-up shop is #41, after the beta) |
| Studio 1A (`old_town_studio`) + Okafor's notice | "Moving house arrives in a later build" | Scenery, and Okafor's notice lists only the café unit (moving house is #32, after the beta) |
| Harbor Point Fitness | "memberships are not sold in this build" | Scenery, or keep the timetable with no build note (membership is #40, after the beta) |
| Customs House | "not part of this build yet" | Scenery (opens in Season 2, #31) |
| Help cards (`data/help/help.json` 72, 145) | "planned ones say so", "Planned ones arrive in later updates" | Rewrite for what is there |
| Character creator (`character_creator.gd` 148) | Mentions outfits sold at Threadline | Keep only if every outfit named is really for sale |
| Any other data text | — | `tools/beta_audit.py` (new) fails the build on the banned words in player-facing keys |

## 4. How we know it is ready (release checklist)

Local acceptance completed for #45 on 2026-10-02. See `evidence/2026-10-02_45/README.md` for the exact results,
logs, reviewed JPG frames, archive checks and remaining external gates. The user authorized stacked Draft PRs;
dependency merges and itch publication are intentionally recorded separately.

- [ ] Every beta ticket merged: #21 and #36 are closed; Draft PRs #75, #77, #79, #80, #81, #83 must merge in order.
- [x] `python3 tools/beta_audit.py`: 0 hits.
- [x] Unit tests 296/296; `python3 tools/i18n_extract.py --check` missing 0; `python3 tools/wiki_check.py` OK.
- [x] Full English and Traditional Chinese walkthroughs from New Game: 0 failures; audit candidates checked as names, brands, IDs and locale/version labels.
- [x] Real Chromium tutorial: 0 failures, 20 reviewed frames without glyph boxes; refresh preserves the save.
- [x] English and Traditional Chinese `beta_tour`: 0 failures; every enterable building in all active districts checked; 39 reviewed frames per locale.
- [x] English and Traditional Chinese screen tour: 0 failures; 40 reviewed frames per locale, including loans, permits, company tabs, closure, save slots and badges.
- [x] Version `0.2.0-beta`, nine bilingual patch-note lines, tester instructions updated.
- [x] Genuine 0.1.8 browser save imports and continues in 0.2.0; update card acknowledgment survives refresh.
- [x] `bash tools/package_release.sh`: Windows, Linux, macOS and Web archives produced; SHA-256 manifest recorded.
- [ ] Published to itch.io. Claude performs this after sequential review/merge with `bash tools/package_release.sh && bash tools/release/publish_itch.sh`.

Web check recipe (what Claude used for 0.1.8-test8.1): export the Web preset with `exclude_filter=""` to a scratch
folder (do not commit that change), set `"args":["--","--bot=tutorial","--lang=zh_TW"]` in the scratch `index.html`,
serve it with `python3 -m http.server`, and open it with Playwright's Chromium using
`--use-angle=swiftshader --enable-unsafe-swiftshader`; the bot's log is the browser console.

## 5. After the beta (not in it)

Season 2 (#30, #31, #42, #43), the pop-up shop (#41), shop content (#40), moving house (#32), café and logistics depth
(#33, #34), art wiring (#26, #27, #28), free-play achievements (#35). Each one becomes visible only when it is complete.
