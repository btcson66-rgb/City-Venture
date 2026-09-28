# R3 pose repair — 2026-09-28

## Scope

Updated `tools/art/r3_poses.py` and regenerated the affected 128×144 layered pose PNGs. The original walking sheets, scene placement, character data, scripts, and tests are unchanged. All names and Godot import paths stay stable.

The second frame of `idle` now changes a chest highlight without shifting only half the torso. `phone` and `interact` keep the joined base silhouette while their arms and hands show the action. The R1 suit and courier detail layers remain fixed to the body. `carry` retains all four walking frames, supports the carton from its sides, and shows only narrow carton edges from behind. Single-pixel transparency seams are closed only where a pose layer exceeds the corresponding walk layer's seam count.

## Before / after

- `before_r3_defects.png`: Claude's R3 acceptance screenshot showing the original gaps, detachment, and carry faults.
- `after_daniel_all_poses.png`: assembled Daniel, with suit tint and untinted tie, in all three directions across walk and five poses.
- `before_22_cowork.png` / `after_22_cowork.png`: same playable co-working room before and after the pose repair. The rig currently holds the first idle frame until Claude updates the gameplay track.

## Checks

- `python tools/qa/pose_check.py` → **pose_check: OK** (all outfits × presentations × poses × directions × played frames).
- Godot 4.5.1 import → completed.
- Unit runner → **67/67 passed**.
- Bot walkthrough → **28 screenshots, 0 failures**.
- `python tools/wiki_check.py` → **OK, 1,187 assets and 156 data ids**.

Claude's gameplay track can now restore two-frame `idle`/`phone` and the packer's `interact` assignment. These are outside this art batch.
