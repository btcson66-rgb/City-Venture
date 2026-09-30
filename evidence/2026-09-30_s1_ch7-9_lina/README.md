# S1 visual evidence — chapter 7–9 cards and Lina

Base: `dad936178db9f25b7d6bca9b5602a2beb0ad8e52` from `claude/exciting-bardeen-y71ixv` after `git pull --ff-only`. These captures use Godot 4.5.1 and the game's real `UIRoot.show_chapter_card` and Nexus Bank interior. No game scripts, data or tests were changed.

- `before_chapter_7.png`: same chapter card UI with the old missing-illustration behavior.
- `after_chapter_7.png`, `after_chapter_8.png`, `after_chapter_9.png`: rendered 640×360 illustrations behind the game's actual title band.
- `chapter7_comparison.png`: before/after card captures side by side.
- `before_lina_bank.png`: base revision at Monday 11:00 in world year 5; Lina appears as the original layered stand-in.
- `after_lina_bank.png`: same seed, time, place and camera with Lina's new seated art.
- `lina_comparison.png`: enlarged, identically cropped bank captures side by side.

The normal `--bot=shots` route captured 41 screenshots and finished with `BOT FINISHED — 0 failure(s)`; its early-game route does not reach year 5 or chapters 7–9, so the targeted runtime captures above cover the new art. `godot --headless --path game --import` passed on the second fresh-worktree run; `92/92 tests passed in 7.0s`; `python tools/wiki_check.py` returned `wiki_check: OK (1389 assets, 170 data ids)`; `python tools/qa/pose_check.py` returned `pose_check: OK`. No map assets changed, so map label check does not apply.

The chapter cards and Lina files are already discovered by the existing asset lookup. There are no code-wiring requests in this batch. Full source art and packing notes are in `docs/art_sources/s1_20260930/`.
