# City frontage originals

Three six-building generated atlases, one individual metro entrance and one corrected slender finance tower are preserved with exact prompts. References: docs/reference/concept_boards/G_building_exteriors_hi.png and the existing polished Horizon Labs detail sprite.

city_frontage_extract.py extracts reviewed objects using atlas_layout.json, with a separate finance revision and metro source. city_frontage_pack.py proportionally fits alpha-trimmed originals within unchanged native dimensions, updates door/sign rectangles through that exact transform, and extracts warm luminous pixels only inside reviewed window/lamp regions. Sign faces are excluded from emission. Emission uses nearest sampling to prevent cool ringing fringes; bodies use Lanczos reduction. Nothing is painted by these packing scripts.

19 buildings, each with native and exactly 4x body and independent emission mask: 76 PNG/import. All existing native filenames and sizes preserved. manifest.json has output hashes; transforms.json records packing geometry. body_preview.png and lights_preview.png are contact sheets, not actual gameplay screenshots.

Night runtime review found full-alpha additive light clipped window details. Final masks retain 40% source alpha, validated with five actual district night captures; QA caps mask alpha at 103. Bright interior furnishings remain visible without white clipping.

Status: this batch validated; complete whole-game optimization remains PARTIAL. Native district assets load now; 4x building lookup/scaling remains a Claude handoff. Other art Drafts are not merged into this isolated branch.
