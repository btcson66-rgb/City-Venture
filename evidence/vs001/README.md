# Evidence · CITY-VENTURE-VERTICAL-SLICE-001

Everything in this folder is produced by `tools/collect_evidence.sh --video` from the committed build. Nothing is edited
by hand. Read the results in [`docs/QA_REPORT.md`](../../docs/QA_REPORT.md).

| Path | What | Produced by |
|------|------|-------------|
| `test-reports/unit.xml` | JUnit results of the unit tests | `res://tests/test_runner.tscn -- --junit=…` |
| `test-reports/unit_console.txt` | Console output of the test run | same |
| `logs/walkthrough_headless.txt` | Full slice played by the bot with real input, headless: New Game → … → month close → save/load | `--bot=walkthrough` |
| `logs/walkthrough_rendered.txt` | The same walkthrough, rendered at 1280×720 (the one the screenshots come from) | `--bot=walkthrough` under Xvfb |
| `logs/walkthrough_video.txt` | The walkthrough that was recorded for the video (Chapter 1–3 + a working day, no month close) | `--bot=walkthrough --video` |
| `logs/export_linux_smoke.txt` | Exported Linux build run for 600 frames under Xvfb | `build/linux/CityVenture.x86_64 --quit-after 600` |
| `screenshots/walkthrough/` | Numbered frames taken along the walkthrough (creator, arrival, districts, interiors, Company OS, decisions, month close, after load) | rendered walkthrough |
| `screenshots/tour/` | Menu, creator, arrival, every district and interior, City/World Map, dusk and night | `--bot=shots` |
| `videos/vs001_gameplay_uncut.mp4` | One uncut take, recorded frame by frame by Godot Movie Maker at 30 fps | `--write-movie … --fixed-fps 30` |
| `logs/walkthrough_0.1.2-test2_{en,zh_TW}.txt` | Build 0.1.2-test2 regression runs, rendered: the full slice plus the Careers steps (job shift, freelance gig). 0 failures in both languages | `--bot=walkthrough --lang=…` |
| `screenshots/test2_en/`, `screenshots/test2_zh_TW/` | Tutorial card, gold guide arrow, EXIT mat, Business Board jobs, job modal, freelance tab, fixed café interior | same runs, and `--bot=shots` |
| `screenshots/web/` | Chromium test of the web build: new game → walk outside → **reload page** → Continue resumes in the same place. `refresh_test.playwright.js` is the script | Playwright + Chromium |
| `logs/walkthrough_0.1.3-test3_{en,zh_TW}.txt` | Build 0.1.3-test3: the full slice, careers and SaaS, then Chapters 4–6 with real input (employer registration, hire, payroll, forecast, Crestline, Marcus's loan, delivery, early payment, August close). 0 failures in both languages | `--bot=walkthrough` |
| `screenshots/test3_en/`, `screenshots/test3_zh_TW/`, `screenshots/test3_screens/` | New 0.1.3 screens: permits kiosk, People tab and applicants, cash forecast, Crestline decision, loan desk, contract restock and delivery, early payment, SaaS, staff at their desks, insolvency and the closing statement, pause menu with audio | walkthroughs, `--bot=screens` |
| `../../docs/media/trailer_{zh,en}.mp4` | 33 s trailer / first-play tutorial (2.4 MB each), recorded by the trailer bot | `--bot=trailer`, `tools/media/make_trailer.sh` |

The bot drives the game only through input. It uses movement actions, `E` at interactables, mouse clicks at a button's
on-screen position, and key events to type into text fields. If a key event doesn't register headless, it sets the text directly and
logs `(typed via fallback)`. It navigates with the game's own navigation grid. It asserts
outcomes and logs `FAIL` lines. It only reads game state to decide what to do next; it never calls game logic to skip gameplay.
The one exception is the final save → reload check. It calls `SaveSystem.save(1)` / `load_and_enter(1)` directly, the same
functions the phone's Save button and the menu's Continue use.
