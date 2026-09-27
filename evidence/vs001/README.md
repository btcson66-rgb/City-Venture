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

The bot drives the game only through input. It uses movement actions, `E` at interactables, mouse clicks at a button's
on-screen position, and key events to type into text fields. If a key event doesn't register headless, it sets the text directly and
logs `(typed via fallback)`. It navigates with the game's own navigation grid. It asserts
outcomes and logs `FAIL` lines. It only reads game state to decide what to do next; it never calls game logic to skip gameplay.
The one exception is the final save → reload check. It calls `SaveSystem.save(1)` / `load_and_enter(1)` directly, the same
functions the phone's Save button and the menu's Continue use.
