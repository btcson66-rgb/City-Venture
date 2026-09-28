# R3 — layered character poses (2026-09-28)

## Art delivered

- Generated `sit`, `idle`, `phone`, `interact`, and `carry` for all 134 current walking layers: 128 A1 layers plus six R1 untinted top detail layers. Total: 670 new 128×144 PNGs and 670 Godot `.png.import` companions.
- Kept four 32×48 frames in each of three directions. `sit`, `idle`, `phone`, and `interact` use the first two frames. `carry` uses all four.
- Source: `tools/art/r3_poses.py`. Rebuild with `python tools/art/r3_poses.py game/assets/characters game/assets/characters`; assemble a named character with `python tools/art/preview_r3.py game evidence/2026-09-28_r3_poses`.
- All outfit fabric remains dyeable. The R1 suit detail stays in its own untinted pose layer; the carried carton stays in the untinted shoes layer.

## Visual evidence

| Before | After | What to check |
|---|---|---|
| `before_daniel_walk_only.png` | `after_daniel_all_poses.png` | Assembled three-direction, four-frame Daniel walk versus sit / idle / phone / interact / carry. The sit lap, raised phone hand, extended interaction hand and carton remain aligned with the body. |
| `before_19_cafe_walk.png` | `after_19_cafe_poses.png` | Cafe customers can switch to their seated art without missing layers. |
| `before_22_cowork_walk.png` | `after_22_cowork_poses.png` | Workers at desks switch to seated art; R1 detail and clothing tints remain separated. |

The art remains on the game's 32×48 character grid and its existing rendering scale. The poses improve silhouettes and action readability within that grid; larger or subpixel character rendering would require a separate gameplay/rendering change.

## Verification

- Godot 4.5.1 `--headless --path game --import`: completed. Every one of the 670 new PNGs has its import metadata.
- Asset scan: 134 base layers × five poses; no missing pose files or import files, and all images are 128×144.
- `python tools/wiki_check.py`: **OK, 1,187 assets and 156 data ids**.
- Godot `--path game -- --bot=shots`: **28 screenshots, 0 failures**.
- Godot unit suite: **63/64 passed**. The sole failure is `test_art_hooks.gd::test_pose_needs_every_layer`, which asserts `no sit art yet` and expects a fallback to walking sheets. R3 deliberately supplies every sit layer, so that old assertion is obsolete. Claude's gameplay track owns the test update; no game script, data, or test was changed in this art batch.

## Handoff

Review the new sitting silhouettes at native game scale, especially side-facing workers behind desks. Claude can update the stale sit-art test expectation and any NPC pose assignments on the gameplay track. R2 remains for A6 as scoped in the backlog.
