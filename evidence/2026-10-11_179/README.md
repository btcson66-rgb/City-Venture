# District completion #179

Stack: #184 → #179; parent `adbd7fcc`, source `8cb2234c6c238495119f57d3d689c4344a05e9b7`, Claude base `4bfff0a43ddeec00bd761084c40be459c4099e4a`.

Godot 4.5.1, Compatibility OpenGL, 1280×720, zh_TW, default text, seed 179. Separate bot output/settings/save directory; camera fixture disables player collision/input while framing. Ambient cars/pedestrians use their actual movement code. Before: #178 with capture helper only; after: final #179 source. No image mocks.

**Validation:** 1012/1012 tests passed in 407.1s; 40 directed walking links, 0 rendered failures; English audit 0. Targeted scenery tests 2/2; empty-lot regression 3/3; map-checker regression 9/9. Class cache rebuilt before edits and after art import. i18n 8324/8324 (0 missing), wiki 3925 assets/343 ids, beta 0 hits. `bash tools/package_release.sh` exit 0; package suite 1012/1012 in 443.6s. Windows ZIP 147.758 MB ≤165 MB; Web PCK 127.227 MB ≤145 MB; exact bytes and SHA256 in [delivery.json](delivery.json).

Before 158 unhandled lots; after 0. 96×96 pixel threshold. Trees/planters alone do not count. Upper facade gaps require complete declared landscaping plus actual props in every sampled segment; bare paving is still inspected below. Coordinates and every intentional retained area: [before](empty-before.json), [after](empty-after.json). This is an authored-map audit, not a claim that an aerial satellite view is fully occupied.

180 review JPGs, 14.055 MB. Native captures are 1280×720; review JPGs are 800×450 at quality 85. Matching camera sections cover both frontage and lower court in every district. Numeric suffix is camera x in design pixels. [Manifest](capture_manifest.json).

## Every district before / after

### airport

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/airport_frontage_240.jpg) [720](gallery/before/airport_frontage_720.jpg) [1200](gallery/before/airport_frontage_1200.jpg) [1680](gallery/before/airport_frontage_1680.jpg) | [240](gallery/after/airport_frontage_240.jpg) [720](gallery/after/airport_frontage_720.jpg) [1200](gallery/after/airport_frontage_1200.jpg) [1680](gallery/after/airport_frontage_1680.jpg) |
| park | [240](gallery/before/airport_park_240.jpg) [720](gallery/before/airport_park_720.jpg) [1200](gallery/before/airport_park_1200.jpg) [1680](gallery/before/airport_park_1680.jpg) | [240](gallery/after/airport_park_240.jpg) [720](gallery/after/airport_park_720.jpg) [1200](gallery/after/airport_park_1200.jpg) [1680](gallery/after/airport_park_1680.jpg) |

Real movement in one second: 14 actors across 4 sections; 4 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1920, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1984, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1920, 0, 64, 736]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1920, 96]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### civic_center

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/civic_center_frontage_240.jpg) [720](gallery/before/civic_center_frontage_720.jpg) [1200](gallery/before/civic_center_frontage_1200.jpg) | [240](gallery/after/civic_center_frontage_240.jpg) [720](gallery/after/civic_center_frontage_720.jpg) [1200](gallery/after/civic_center_frontage_1200.jpg) |
| park | [240](gallery/before/civic_center_park_240.jpg) [720](gallery/before/civic_center_park_720.jpg) [1200](gallery/before/civic_center_park_1200.jpg) | [240](gallery/after/civic_center_park_240.jpg) [720](gallery/after/civic_center_park_720.jpg) [1200](gallery/after/civic_center_park_1200.jpg) |

Real movement in one second: 15 actors across 3 sections; 4 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1280, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1344, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1280, 0, 64, 704]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1280, 64]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### financial

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/financial_frontage_240.jpg) [720](gallery/before/financial_frontage_720.jpg) [1200](gallery/before/financial_frontage_1200.jpg) | [240](gallery/after/financial_frontage_240.jpg) [720](gallery/after/financial_frontage_720.jpg) [1200](gallery/after/financial_frontage_1200.jpg) |
| park | [240](gallery/before/financial_park_240.jpg) [720](gallery/before/financial_park_720.jpg) [1200](gallery/before/financial_park_1200.jpg) | [240](gallery/after/financial_park_240.jpg) [720](gallery/after/financial_park_720.jpg) [1200](gallery/after/financial_park_1200.jpg) |

Real movement in one second: 17 actors across 3 sections; 6 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1280, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1440, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1280, 0, 160, 704]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1280, 64]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### harbor

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/harbor_frontage_240.jpg) [720](gallery/before/harbor_frontage_720.jpg) [1200](gallery/before/harbor_frontage_1200.jpg) [1680](gallery/before/harbor_frontage_1680.jpg) | [240](gallery/after/harbor_frontage_240.jpg) [720](gallery/after/harbor_frontage_720.jpg) [1200](gallery/after/harbor_frontage_1200.jpg) [1680](gallery/after/harbor_frontage_1680.jpg) |
| park | [240](gallery/before/harbor_park_240.jpg) [720](gallery/before/harbor_park_720.jpg) [1200](gallery/before/harbor_park_1200.jpg) [1680](gallery/before/harbor_park_1680.jpg) | [240](gallery/after/harbor_park_240.jpg) [720](gallery/after/harbor_park_720.jpg) [1200](gallery/after/harbor_park_1200.jpg) [1680](gallery/after/harbor_park_1680.jpg) |

Real movement in one second: 15 actors across 4 sections; 4 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1728, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1792, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1728, 0, 64, 736]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1728, 96]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.
- `[0, 672, 1728, 64]`: Waterfront water remains open; preserve shoreline and animated water.

### industrial

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/industrial_frontage_240.jpg) [720](gallery/before/industrial_frontage_720.jpg) [1200](gallery/before/industrial_frontage_1200.jpg) [1680](gallery/before/industrial_frontage_1680.jpg) | [240](gallery/after/industrial_frontage_240.jpg) [720](gallery/after/industrial_frontage_720.jpg) [1200](gallery/after/industrial_frontage_1200.jpg) [1680](gallery/after/industrial_frontage_1680.jpg) |
| park | [240](gallery/before/industrial_park_240.jpg) [720](gallery/before/industrial_park_720.jpg) [1200](gallery/before/industrial_park_1200.jpg) [1680](gallery/before/industrial_park_1680.jpg) | [240](gallery/after/industrial_park_240.jpg) [720](gallery/after/industrial_park_720.jpg) [1200](gallery/after/industrial_park_1200.jpg) [1680](gallery/after/industrial_park_1680.jpg) |

Real movement in one second: 16 actors across 4 sections; 4 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1728, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1792, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1728, 0, 64, 736]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1728, 96]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### luxury_heights

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/luxury_heights_frontage_240.jpg) [720](gallery/before/luxury_heights_frontage_720.jpg) [1200](gallery/before/luxury_heights_frontage_1200.jpg) [1680](gallery/before/luxury_heights_frontage_1680.jpg) | [240](gallery/after/luxury_heights_frontage_240.jpg) [720](gallery/after/luxury_heights_frontage_720.jpg) [1200](gallery/after/luxury_heights_frontage_1200.jpg) [1680](gallery/after/luxury_heights_frontage_1680.jpg) |
| park | [240](gallery/before/luxury_heights_park_240.jpg) [720](gallery/before/luxury_heights_park_720.jpg) [1200](gallery/before/luxury_heights_park_1200.jpg) [1680](gallery/before/luxury_heights_park_1680.jpg) | [240](gallery/after/luxury_heights_park_240.jpg) [720](gallery/after/luxury_heights_park_720.jpg) [1200](gallery/after/luxury_heights_park_1200.jpg) [1680](gallery/after/luxury_heights_park_1680.jpg) |

Real movement in one second: 15 actors across 4 sections; 4 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1920, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 2080, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1920, 0, 160, 736]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1920, 96]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### old_town

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/old_town_frontage_240.jpg) [720](gallery/before/old_town_frontage_720.jpg) [1200](gallery/before/old_town_frontage_1200.jpg) | [240](gallery/after/old_town_frontage_240.jpg) [720](gallery/after/old_town_frontage_720.jpg) [1200](gallery/after/old_town_frontage_1200.jpg) |
| park | [240](gallery/before/old_town_park_240.jpg) [720](gallery/before/old_town_park_720.jpg) [1200](gallery/before/old_town_park_1200.jpg) | [240](gallery/after/old_town_park_240.jpg) [720](gallery/after/old_town_park_720.jpg) [1200](gallery/after/old_town_park_1200.jpg) |

Real movement in one second: 15 actors across 3 sections; 4 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1408, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1472, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1408, 0, 64, 704]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1408, 64]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### residential

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/residential_frontage_240.jpg) [720](gallery/before/residential_frontage_720.jpg) [1200](gallery/before/residential_frontage_1200.jpg) [1680](gallery/before/residential_frontage_1680.jpg) [2160](gallery/before/residential_frontage_2160.jpg) | [240](gallery/after/residential_frontage_240.jpg) [720](gallery/after/residential_frontage_720.jpg) [1200](gallery/after/residential_frontage_1200.jpg) [1680](gallery/after/residential_frontage_1680.jpg) [2160](gallery/after/residential_frontage_2160.jpg) |
| park | [240](gallery/before/residential_park_240.jpg) [720](gallery/before/residential_park_720.jpg) [1200](gallery/before/residential_park_1200.jpg) [1680](gallery/before/residential_park_1680.jpg) [2160](gallery/before/residential_park_2160.jpg) | [240](gallery/after/residential_park_240.jpg) [720](gallery/after/residential_park_720.jpg) [1200](gallery/after/residential_park_1200.jpg) [1680](gallery/after/residential_park_1680.jpg) [2160](gallery/after/residential_park_2160.jpg) |

Real movement in one second: 17 actors across 4 sections; 6 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 2400, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 2464, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[2400, 0, 64, 736]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 2400, 96]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### riverside

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/riverside_frontage_240.jpg) [720](gallery/before/riverside_frontage_720.jpg) [1200](gallery/before/riverside_frontage_1200.jpg) [1680](gallery/before/riverside_frontage_1680.jpg) | [240](gallery/after/riverside_frontage_240.jpg) [720](gallery/after/riverside_frontage_720.jpg) [1200](gallery/after/riverside_frontage_1200.jpg) [1680](gallery/after/riverside_frontage_1680.jpg) |
| park | [240](gallery/before/riverside_park_240.jpg) [720](gallery/before/riverside_park_720.jpg) [1200](gallery/before/riverside_park_1200.jpg) [1680](gallery/before/riverside_park_1680.jpg) | [240](gallery/after/riverside_park_240.jpg) [720](gallery/after/riverside_park_720.jpg) [1200](gallery/after/riverside_park_1200.jpg) [1680](gallery/after/riverside_park_1680.jpg) |

Real movement in one second: 20 actors across 4 sections; 8 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1920, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 2080, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1920, 0, 160, 768]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1920, 128]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.
- `[0, 656, 1920, 16]`: Waterfront water remains open; preserve shoreline and animated water.
- `[0, 672, 1920, 96]`: Waterfront water remains open; preserve shoreline and animated water.
- `[0, 704, 1920, 16]`: Waterfront water remains open; preserve shoreline and animated water.

### shopping_street

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/shopping_street_frontage_240.jpg) [720](gallery/before/shopping_street_frontage_720.jpg) [1200](gallery/before/shopping_street_frontage_1200.jpg) | [240](gallery/after/shopping_street_frontage_240.jpg) [720](gallery/after/shopping_street_frontage_720.jpg) [1200](gallery/after/shopping_street_frontage_1200.jpg) |
| park | [240](gallery/before/shopping_street_park_240.jpg) [720](gallery/before/shopping_street_park_720.jpg) [1200](gallery/before/shopping_street_park_1200.jpg) | [240](gallery/after/shopping_street_park_240.jpg) [720](gallery/after/shopping_street_park_720.jpg) [1200](gallery/after/shopping_street_park_1200.jpg) |

Real movement in one second: 22 actors across 3 sections; 6 cars, 16 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1440, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1504, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1440, 0, 64, 704]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1440, 64]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### startup_hub

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/startup_hub_frontage_240.jpg) [720](gallery/before/startup_hub_frontage_720.jpg) [1200](gallery/before/startup_hub_frontage_1200.jpg) [1680](gallery/before/startup_hub_frontage_1680.jpg) | [240](gallery/after/startup_hub_frontage_240.jpg) [720](gallery/after/startup_hub_frontage_720.jpg) [1200](gallery/after/startup_hub_frontage_1200.jpg) [1680](gallery/after/startup_hub_frontage_1680.jpg) |
| park | [240](gallery/before/startup_hub_park_240.jpg) [720](gallery/before/startup_hub_park_720.jpg) [1200](gallery/before/startup_hub_park_1200.jpg) [1680](gallery/before/startup_hub_park_1680.jpg) | [240](gallery/after/startup_hub_park_240.jpg) [720](gallery/after/startup_hub_park_720.jpg) [1200](gallery/after/startup_hub_park_1200.jpg) [1680](gallery/after/startup_hub_park_1680.jpg) |

Real movement in one second: 20 actors across 4 sections; 8 cars, 14 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1792, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1856, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1792, 0, 64, 768]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1792, 128]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

### university

| Band | Before | After |
|---|---|---|
| frontage | [240](gallery/before/university_frontage_240.jpg) [720](gallery/before/university_frontage_720.jpg) [1200](gallery/before/university_frontage_1200.jpg) [1680](gallery/before/university_frontage_1680.jpg) | [240](gallery/after/university_frontage_240.jpg) [720](gallery/after/university_frontage_720.jpg) [1200](gallery/after/university_frontage_1200.jpg) [1680](gallery/after/university_frontage_1680.jpg) |
| park | [240](gallery/before/university_park_240.jpg) [720](gallery/before/university_park_720.jpg) [1200](gallery/before/university_park_1200.jpg) [1680](gallery/before/university_park_1680.jpg) | [240](gallery/after/university_park_240.jpg) [720](gallery/after/university_park_720.jpg) [1200](gallery/after/university_park_1200.jpg) [1680](gallery/after/university_park_1680.jpg) |

Real movement in one second: 16 actors across 3 sections; 4 cars, 12 pedestrians.

Retained open areas (design pixels):
- `[0, 0, 1920, 224]`: Distant skyline behind the building row; not a playable lot.
- `[0, 320, 1984, 224]`: Pavements, crossings and through-road remain clear for travel.
- `[1920, 0, 64, 736]`: Narrow planted exit connector; preserve the unobstructed portal and crossing.
- `[0, 640, 1920, 96]`: Clear promenade edge or waterfront behind the rest courts; not a building lot.

## F1–F8 / player perspectives

| Principle | Before → After |
|---|---|
| F1 | N/A: scenery adds no new mechanic; existing safe practice/replay retained. |
| F2 | PASS → PASS: no new timer, reward or pressure. |
| F3 | PASS → PASS: scenery does not advertise locked industries or playable buildings. |
| F4 | N/A: no new screen or decision. |
| F5 | N/A: no management task added; protected assistant/phone systems untouched. |
| F6 | PASS → PASS: no text wall or floating field of labels; space names remain translatable metadata. |
| F7 | PASS → PASS: existing doors/metro/exits and Ledger/old-save suites pass. |
| F8 | PARTIAL → PASS in inspected captures: plain lawns now have quiet themed shelter/seats/planting; no decorative gold emphasis. |

Novice fixture saw the arrival route and recognisable garden/market/shelter silhouettes, walked actual signed transitions, and could keep exploring without a new form or timer. It demonstrates reproducible presentation and navigation, not independent human discovery or subjective enjoyment.

Experienced-player fixture traversed every directed walking link after scenery changes; no entrance/return spawn was blocked, and walking preserved balanced Ledger entries. Existing old-save/unit fixtures pass. A blind human first-time playthrough, ten-hour human replay, physical-device test and subjective fun study are NOT VERIFIED.

Self-review: retained native footprints and exact 4x detail, prevented skyline erasing planted ground, replaced automatic tree rows instead of layering them over new courts, kept street/crossing geometry intact, included water/clear promenade/connector retention coordinates, and made empty-lot regression reject fake garden declarations and trees-only lots.

New art sources and exact original/cleanup prompts: [source record](../../docs/art_sources/district_completion_179/source.json). Existing trees, benches, lamps, metro, traffic and pedestrians are reused. New reading pavilions/markets are scenery, not new businesses or enterable shops. No gameplay, economy values or save keys changed; Session I protected files unchanged.
