# Genuine historical saves

These files were produced by the actual historical walkthrough, stopping after chapter 3 becomes active. Only the historical test harness was changed to call `SaveSystem.save_to` and finish at that checkpoint. No game data, balances, seed, or game logic was modified.

| Fixture | Historical source commit |
| --- | --- |
| 0.1.5-test5.cvsave | bbf26774a8b5c5e8a5c10a187f3882cd45a14bb6 |
| 0.1.6-test6.cvsave | a00bc77642fa4409a802fbb6771aadd38e384b75 |
| 0.1.7-test7.cvsave | 7155d39d29a748f877ff5995121204758c4148f0 |
| 0.1.8-test8.1.cvsave | ce186eb390146f706606e059711e7aae20c48928 |

Capture: Godot 4.5.1, `--headless --fixed-fps 60 --path game -- --bot=walkthrough --lang=en --out=<isolated directory> --quit`. Each capture used a separate user directory and completed with zero bot failures. Capture logs and hashes are recorded in `evidence/2026-10-02_22`.

`test_old_saves.gd` loads every unedited fixture, checks the story, advances three full days, verifies balanced books, and builds every Company OS tab. `home_laptop` is the current canonical laptop interaction ID.

On each release, capture another genuine save and extend this regression set. Never relabel a current save as a historical version.
