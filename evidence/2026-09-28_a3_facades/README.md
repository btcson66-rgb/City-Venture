# A3 — building facades and night overlays (2026-09-28)

## Art delivered

All 18 existing facades were regenerated with their `_lights` overlays from `tools/art/facades.py`. The revision improves door depth and jamb contrast, adjusts the receding side wall to a softer ~20% shadow, keeps live sign text on plain background, moves the sign glow to the lower edge, and uses a seeded 60% lit probability for upper windows. Ground-floor shops and lobbies can stay active at night.

`game/assets/buildings/buildings_meta.json` is byte-identical to the regenerated metadata. Every PNG retains its original dimensions, door rectangle and sign rectangle. No district placements, collision data, scripts or gameplay records changed. The Metro entrance is included in the generator; its pixels remain valid at the existing 88×70 dimensions.

## Before / after

- `before_building_contact_sheet.png` / `after_building_contact_sheet.png`: all 18 facade pairs, day and night, at their native pixel density.
- `before_<district>_{day,night}.png` / `after_<district>_{day,night}.png`: playable screenshots from Riverside, Startup Hub, Civic Center, and Financial District.
- The standard bot takes 28 screenshots but only visits Riverside and Startup Hub at night. For the four-district night evidence, a temporary copy of the game was used with two extra capture calls after the standard tour. No capture script change was committed. The same temporary copy was run against both original and updated facade PNGs for matched comparisons.

## Verification

- Godot 4.5.1 import: completed.
- Unit suite: **67/67 passed**.
- Standard bot: **28 screenshots, 0 failures**.
- Extended four-district capture: **30 screenshots, 0 failures** for both before and after.
- `python tools/wiki_check.py`: **OK, 1,187 assets and 156 data ids**.
- Facade dimensions and `buildings_meta.json`: unchanged across all 18 building IDs.

The current 16 px world grid and nearest-neighbor display are gameplay/rendering contracts. A3 improves the facades within that contract; it does not change screen resolution or camera behavior.
