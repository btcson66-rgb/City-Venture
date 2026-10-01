# Street environment production art · 2026-10-01

Twenty isolated originals refine seven facades and thirteen street props. All originals use the existing sprite as geometry reference and the supplied City Venture concept board as style reference. The direction remains upper-left daylight, cool navy glazing and outlines, warm material highlights and layered urban greenery. Signs, lamp banners and roof ornaments contain no text or brand marks.

Buildings: riverside_tower, nexus_bank, horizon_labs, bloom_block, glass_tower, office_slab, apartment_mid. Props: tree_round, tree_round_b, tree_tall, lamp, lamp_banner, bench, umbrella_table, planter, flower_bed, bike, planter_small, planter_long, hedge.

`originals/` preserves the generated bitmap art. `layout.json` records source-space door/sign/emission regions. `street_environment_pack.py` only crops to meaningful alpha bounds, proportionally resizes, bottom-aligns to existing native footprints and extracts warm emission pixels inside inspected light regions. It does not draw replacement illustration. `transforms.json` and `manifest.json` record packing and hashes. All native PNG dimensions remain unchanged. Door/sign/glow metadata follows the new visible layout.

Reproduce: `python tools/art/street_environment_pack.py`; Godot import; `python tools/qa/street_environment_check.py`; run screenshots; `python tools/art/street_environment_document.py`; `python tools/wiki_check.py`.

Native facade replacement is visible immediately. Existing props automatically use world_detail. District and menu facades still use native sprites; 4× facade integration belongs to Claude's rendering track. No gameplay scripts, data, tests or tile atlas cells changed.

Whole-game optimization remains incomplete. This batch does not certify unreviewed interiors, every pedestrian variation, remaining facades, street utilities, UI, maps, terrain, effects or future content.
