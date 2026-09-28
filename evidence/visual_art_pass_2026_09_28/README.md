# CITY VENTURE visual art pass — 2026-09-28

## Scope and art direction

The owner supplied seven concept boards. The visual target is their bright, lived-in city, indigo-and-coral dusk, layered 32×48 character silhouettes, and navy/cyan pixel UI. Gameplay, story, economy, controls, locations, and save data were not changed.

This pass updates the **current playable screens** through the existing asset contract:

| Surface | Delivered change |
| --- | --- |
| Main menu | New clean-sign street illustration; original concept composition retained; no baked-in words. |
| Arrival | New waterfront dusk panorama with bridge, skyline, and coherent river reflections. |
| Character creator and world NPCs | Rebuilt existing layered body, hair, and outfit sheets with tapered anatomy, directional locks, cloth folds, and shoe detail. Existing 32×48 frames, 4×3 layout, tint system, and file names remain. |
| Dialogue and character creator portraits | Updated tintable face planes and hair highlights; stable generation seed for repeatability. |
| Shared UI on every screen | Refined panel, glass panel, button, card, phone frame, and portrait frame pixels. The same controls and layout remain. |
| City map, world map, districts, buildings, interiors, props | Existing approved concept-board conversions retained. The screenshot tour below checks that these continue to render with the revised shared UI and character assets. |

The two source illustrations are in `docs/art_sources/`. `python tools/art/finalize_backdrops.py` recreates the game-size PNGs. `python tools/art/gen_placeholders.py <output-dir> chars` and `... ui` recreate the touched layered character and UI sheets in a separate output directory. Do **not** run the generator over `game/assets/`; it would replace other approved handoff art.

## Source illustration prompts

- **Menu:** Edit the existing menu street using the supplied daytime city board as style reference. Preserve the central shopping-street perspective, cafe terraces, leafy trees, sunlight, glass-and-stone storefronts and small people. Improve architectural coherence and pixel clusters. Remove all baked words, labels and UI; use only abstract symbols on signs. Leave calm darker space at upper left for live menu text.
- **Arrival:** Edit the existing arrival panorama using the supplied dusk/luxury board as style reference. Preserve the waterfront skyline and bridge. Add layered buildings, indigo-to-coral sky, warm windows and coherent water reflections. Keep open sky and no text or UI.

Both were generated with the built-in image tool, inspected, and converted to the exact pixel canvas size with a 192-color palette and no dithering. Fonts and all localized game text remain live.

## Verification

- Godot **4.5.1** (the project's target engine) and 4.7.2 both imported the revised art successfully.
- Rendered `--bot=shots` tour on Godot 4.5.1 completed with **28 screenshots and 0 bot failures**. Six representative 4.5.1 captures are in this directory: main menu, creator, arrival, city map, startup office, and night street. A separate 4.7.2 run also produced 28 screenshots and 0 bot failures.
- All **173** layered character/portrait PNGs have the required sheet sizes; the two backdrops are 752×360 and 640×360.
- Local unit suite under **both Godot 4.5.1 and 4.7.2: 57/58 passed**. `test_systems.gd::test_registration_creates_company_and_moves_books` failed at `timeline entry` on both. No simulation source, game data, or tests changed in this art branch; this failure was not investigated as an art issue.

## Review boundary

The concept boards are target art, not proof that every sprite has reached hand-finished quality. Current maps and architecture still use the project's v3 converted art, and named NPC portraits still share the procedural layered system. Review the six captures and the full game before calling the visual work final or publishing it.
