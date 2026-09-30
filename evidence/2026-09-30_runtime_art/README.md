# Runtime art integration · 2026-09-30

Actual renderer update, following feedback that concept art quality did not reach gameplay.

- 100 new runtime PNGs in `game/assets/world_detail`, packed from 19 generated originals.
- Original images and full built-in imagegen prompts: `docs/art_sources/runtime_20260930/sources.json`.
- Detailed sprites retain original logical footprints, feet anchors, sorting, collisions and interaction locations.
- Eight interiors use new furniture, floors, larger window glazing and wall surfaces. Living/office textile zones added.
- Default founder walk sheet and portrait; 12 named NPCs with front/profile/back and four expressions. Dialogue updates standing world sprites as well as portraits and resets on close.
- Five scheduled named NPC seated sheets and six anonymous seated guests. Seated expressions remain neutral.
- Custom player appearance and changed outfits deliberately retain the layered rig to preserve user choices.

Validation: `review/result.json` contains 249 checks, zero failures. Covers all rooms' real movement, NPC expression frames, logical anchors, customisation fallback and live dialogue expression sync. `unit_tests.log`: 67/67. `pose_check` and `map_label_check`: pass. `wiki_check`: 1377 assets and 156 data ids documented.

Screenshots in `review/` are actual engine captures; tutorial and discovery cards are hidden by the review harness. They are not concept illustrations. Reproduce with `godot --path game --script ../tools/art/review_runtime.gd`. The harness uses `user://runtime_art_review` for saves.

Remaining scope: customised protagonist variants, additional clothing, street pedestrians, employees, some small decoration, exterior facades, and fully animated expressive seated poses still need matching artwork. This integration is a material improvement, not a claim that the whole game now matches the reference boards.

No merge, push, deployment or release build performed. Source project loads these assets directly.
