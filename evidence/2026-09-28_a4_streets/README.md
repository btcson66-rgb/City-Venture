# A4 — street props and ground tiles (2026-09-28)

## Art delivered

- Refined all **28** existing `props/*.png` street sprites, excluding six `product_*.png` icons. Organic forms receive gentle interior smoothing while retaining hard alpha silhouettes; high-frequency hedge, bollard, railing, cone and parking-meter props have lower saturation and contrast. Sizes and `sprite_meta.json` remain unchanged.
- Reworked **23** existing 16×16 ground cells in `tiles/atlas.png`. Sidewalk stones are larger and less grid-like; asphalt has quieter, lower-contrast speckles; river water uses a calm base without 16 px stripes or sparkle repetition. The vertical road-dash tile now shows its intended vertical dash.
- Every atlas index is unchanged. The eight interior floor cells and seven wall cells from A2 are pixel-identical to the input atlas; `atlas.json` is unchanged.
- Reproduction: run `python tools/art/a4_streets.py <clean-A3-game/assets> <output-dir>`, then copy the generated props and atlas PNG to `game/assets/`. This script takes a clean A3 source because it is a finishing pass on those source pixels.

## Before / after evidence

- `before_props_contact_sheet.png` / `after_props_contact_sheet.png`: all 28 props at native size.
- `before_tile_repeat.png` / `after_tile_repeat.png`: 40×8 repeated sidewalk, road and river cells to reveal seams and repetition.
- Five matched in-game pairs: Riverside, Startup Hub, Civic Center, Financial District by day, plus Riverside by night. These are `before_XX_*.png` and `after_XX_*.png`.
- `before_lamp_zoom.png` and `before_lamp_banner_zoom.png`: original lamp heads. The finished sprites' bright head centroids are (9.8, 7.4) and (9.9, 6.8) px respectively; the existing glow anchor is (10, 8) for both.

## Verification

- 28/28 non-product props changed, 0 dimension mismatches.
- Godot 4.5.1 import: completed.
- Unit runner: **67/67 passed**.
- Bot walkthrough: **28 screenshots, 0 failures**.
- `python tools/wiki_check.py`: **OK, 1,187 assets and 156 data ids**.

The game still uses nearest-neighbor scaling. Broader changes to rendering resolution or texture filtering belong to Claude's gameplay track.
