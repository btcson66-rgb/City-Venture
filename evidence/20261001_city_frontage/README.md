# City frontage quality — 2026-10-01

Base: 9145015, freshly pulled claude/exciting-bardeen-y71ixv.
Branch: codex/art-city-frontage-completion.

19 remaining legacy city buildings replaced: river walkup/shops, parcel office, coworking, office suite, cafe, city hall/annex, brick shops, financial tower, Threadline/Crestline, bistro/popup/arcade/awning row/cinema/corner cafe, metro entrance.

Before and after are actual Godot tours with 53 screenshots and 63 steps, 0 failures. Comparisons use matching named locations; animation/NPC positions can differ. High-resolution contact sheets are asset previews, not wired gameplay evidence.

76 PNG/import, native and exactly 4x body/light pairs. Native dimensions and district logical placements unchanged; entrance and blank sign metadata updated to the actual generated artwork. Source originals, exact prompts, inspected crop/emission regions, transforms and hashes are archived.

Validation:
- Godot baseline/after/final imports: exit 0, no errors.
- test_runner last line: 251/251 tests passed in 17.3s.
- First after tour: BOT FINISHED — 0 failure(s) · 50.8s real; English audit 0.
- Final emission correction: final-shots.log and after/walkthrough_result.json.
- Five additional actual district night screenshots in night/: reviewed for additive clipping. Masks attenuated to 40% alpha; QA caps alpha at 103.
- city_frontage_check: 19 originals / 76 PNG/import; exact 4x, original sizes, door/sign bounds and emission checks OK.
- wiki_check: OK (1649 assets, 191 data ids).
- map_label_check: OK. pose_check N/A, no character edits.

Claude handoff: District building and main-menu rendering still uses native textures. Connect world_detail buildings and corresponding masks at 0.25 logical scale, preserving native metadata, layout, sorting, doors and interaction. Metro sign is deliberately blank and needs program overlaid transit identifier where that renderer bypasses building metadata.

Full story walkthrough not run; stays Draft. This batch does not claim integrated acceptance of unmerged character/traffic/street art or complete all-game quality.
