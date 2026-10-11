# #178 rendered evidence

Baseline: `4bfff0a43ddeec00bd761084c40be459c4099e4a`. Implementation: `2b26a47a (game code unchanged at 59728d98)` on `codex/178-world-visual-fixes`. Godot 4.5.1, OpenGL compatibility. QA save directories are isolated from player saves.

Desktop capture: 1280x720, zh_TW, default font. Mobile layout capture: requested 390x844 window, English, font factor 1.5; the game keeps its 16:9 content aspect and the native captured game canvas is 390x219. This is a desktop viewport fixture, not a physical phone test. JPG review copies are downsampled to 800px width at quality 85; original capture dimensions and hashes are in capture_manifest.json.

Commands (Godot executable path may vary):

```sh
godot --headless --path game --editor --quit
godot --headless --path game res://tests/test_runner.tscn
python tools/i18n_extract.py --check
python tools/wiki_check.py
python tools/beta_audit.py
python tools/qa/map_adjacency_check.py
python tools/qa/test_map_adjacency_check.py
python tools/qa/vehicle_component_check.py
godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=world_visual --lang=zh_TW --out=<isolated-output>
godot --path game --rendering-driver opengl3 --resolution 1280x720 -- --bot=map_adjacency --lang=zh_TW --out=<isolated-output>
bash tools/package_release.sh
```

## Results

- Final package and map results are recorded in delivery.json after completion; superseded failing development runs are not acceptance evidence.
- i18n: 8312/8312 translated, zh_TW missing 0. wiki: 3913 assets/343 data ids. beta: 0 hits.
- Component audit: 26 complete vehicle silhouettes; baseline has 2 faulty train images; after has 0 failures.
- Building audit: 44 buildings, 126 configured interactables; registered industry desks follow existing gates, public/lease/NPC routes remain available.
- Rendering fixture: 100 baseline / 94 after screenshots, 40 exit views on each side, all 12 districts. After English audit: 0.

## District sections

### airport

| Before | After |
|---|---|
| [1200](gallery/before/airport_frontage_1200.jpg) [1680](gallery/before/airport_frontage_1680.jpg) [2160](gallery/before/airport_frontage_2160.jpg) [240](gallery/before/airport_frontage_240.jpg) [720](gallery/before/airport_frontage_720.jpg) | [1200](gallery/after/airport_frontage_1200.jpg) [1680](gallery/after/airport_frontage_1680.jpg) [240](gallery/after/airport_frontage_240.jpg) [720](gallery/after/airport_frontage_720.jpg) |

Exit views: [civic_center](gallery/after/airport_exit_civic_center.jpg) [university](gallery/after/airport_exit_university.jpg)

### civic_center

| Before | After |
|---|---|
| [1200](gallery/before/civic_center_frontage_1200.jpg) [240](gallery/before/civic_center_frontage_240.jpg) [720](gallery/before/civic_center_frontage_720.jpg) | [1200](gallery/after/civic_center_frontage_1200.jpg) [240](gallery/after/civic_center_frontage_240.jpg) [720](gallery/after/civic_center_frontage_720.jpg) |

Exit views: [airport](gallery/after/civic_center_exit_airport.jpg) [financial](gallery/after/civic_center_exit_financial.jpg) [luxury_heights](gallery/after/civic_center_exit_luxury_heights.jpg) [riverside](gallery/after/civic_center_exit_riverside.jpg) [startup_hub](gallery/after/civic_center_exit_startup_hub.jpg)

### financial

| Before | After |
|---|---|
| [1200](gallery/before/financial_frontage_1200.jpg) [240](gallery/before/financial_frontage_240.jpg) [720](gallery/before/financial_frontage_720.jpg) | [1200](gallery/after/financial_frontage_1200.jpg) [240](gallery/after/financial_frontage_240.jpg) [720](gallery/after/financial_frontage_720.jpg) |

Exit views: [civic_center](gallery/after/financial_exit_civic_center.jpg) [harbor](gallery/after/financial_exit_harbor.jpg) [luxury_heights](gallery/after/financial_exit_luxury_heights.jpg) [old_town](gallery/after/financial_exit_old_town.jpg) [riverside](gallery/after/financial_exit_riverside.jpg)

### harbor

| Before | After |
|---|---|
| [1200](gallery/before/harbor_frontage_1200.jpg) [1680](gallery/before/harbor_frontage_1680.jpg) [240](gallery/before/harbor_frontage_240.jpg) [720](gallery/before/harbor_frontage_720.jpg) | [1200](gallery/after/harbor_frontage_1200.jpg) [1680](gallery/after/harbor_frontage_1680.jpg) [240](gallery/after/harbor_frontage_240.jpg) [720](gallery/after/harbor_frontage_720.jpg) |

Exit views: [financial](gallery/after/harbor_exit_financial.jpg) [riverside](gallery/after/harbor_exit_riverside.jpg) [shopping_street](gallery/after/harbor_exit_shopping_street.jpg)

### industrial

| Before | After |
|---|---|
| [1200](gallery/before/industrial_frontage_1200.jpg) [1680](gallery/before/industrial_frontage_1680.jpg) [240](gallery/before/industrial_frontage_240.jpg) [720](gallery/before/industrial_frontage_720.jpg) | [1200](gallery/after/industrial_frontage_1200.jpg) [1680](gallery/after/industrial_frontage_1680.jpg) [240](gallery/after/industrial_frontage_240.jpg) [720](gallery/after/industrial_frontage_720.jpg) |

Exit views: [residential](gallery/after/industrial_exit_residential.jpg) [shopping_street](gallery/after/industrial_exit_shopping_street.jpg)

### luxury_heights

| Before | After |
|---|---|
| [1200](gallery/before/luxury_heights_frontage_1200.jpg) [1680](gallery/before/luxury_heights_frontage_1680.jpg) [2160](gallery/before/luxury_heights_frontage_2160.jpg) [240](gallery/before/luxury_heights_frontage_240.jpg) [720](gallery/before/luxury_heights_frontage_720.jpg) | [1200](gallery/after/luxury_heights_frontage_1200.jpg) [1680](gallery/after/luxury_heights_frontage_1680.jpg) [240](gallery/after/luxury_heights_frontage_240.jpg) [720](gallery/after/luxury_heights_frontage_720.jpg) |

Exit views: [civic_center](gallery/after/luxury_heights_exit_civic_center.jpg) [financial](gallery/after/luxury_heights_exit_financial.jpg) [old_town](gallery/after/luxury_heights_exit_old_town.jpg)

### old_town

| Before | After |
|---|---|
| [1200](gallery/before/old_town_frontage_1200.jpg) [240](gallery/before/old_town_frontage_240.jpg) [720](gallery/before/old_town_frontage_720.jpg) | [1200](gallery/after/old_town_frontage_1200.jpg) [240](gallery/after/old_town_frontage_240.jpg) [720](gallery/after/old_town_frontage_720.jpg) |

Exit views: [financial](gallery/after/old_town_exit_financial.jpg) [luxury_heights](gallery/after/old_town_exit_luxury_heights.jpg) [residential](gallery/after/old_town_exit_residential.jpg) [shopping_street](gallery/after/old_town_exit_shopping_street.jpg)

### residential

| Before | After |
|---|---|
| [1200](gallery/before/residential_frontage_1200.jpg) [1680](gallery/before/residential_frontage_1680.jpg) [2160](gallery/before/residential_frontage_2160.jpg) [240](gallery/before/residential_frontage_240.jpg) [2640](gallery/before/residential_frontage_2640.jpg) [720](gallery/before/residential_frontage_720.jpg) | [1200](gallery/after/residential_frontage_1200.jpg) [1680](gallery/after/residential_frontage_1680.jpg) [2160](gallery/after/residential_frontage_2160.jpg) [240](gallery/after/residential_frontage_240.jpg) [720](gallery/after/residential_frontage_720.jpg) |

Exit views: [industrial](gallery/after/residential_exit_industrial.jpg) [old_town](gallery/after/residential_exit_old_town.jpg) [shopping_street](gallery/after/residential_exit_shopping_street.jpg)

### riverside

| Before | After |
|---|---|
| [1200](gallery/before/riverside_frontage_1200.jpg) [1680](gallery/before/riverside_frontage_1680.jpg) [2160](gallery/before/riverside_frontage_2160.jpg) [240](gallery/before/riverside_frontage_240.jpg) [720](gallery/before/riverside_frontage_720.jpg) | [1200](gallery/after/riverside_frontage_1200.jpg) [1680](gallery/after/riverside_frontage_1680.jpg) [240](gallery/after/riverside_frontage_240.jpg) [720](gallery/after/riverside_frontage_720.jpg) |

Exit views: [civic_center](gallery/after/riverside_exit_civic_center.jpg) [financial](gallery/after/riverside_exit_financial.jpg) [harbor](gallery/after/riverside_exit_harbor.jpg) [startup_hub](gallery/after/riverside_exit_startup_hub.jpg)

### shopping_street

| Before | After |
|---|---|
| [1200](gallery/before/shopping_street_frontage_1200.jpg) [1680](gallery/before/shopping_street_frontage_1680.jpg) [240](gallery/before/shopping_street_frontage_240.jpg) [720](gallery/before/shopping_street_frontage_720.jpg) | [1200](gallery/after/shopping_street_frontage_1200.jpg) [240](gallery/after/shopping_street_frontage_240.jpg) [720](gallery/after/shopping_street_frontage_720.jpg) |

Exit views: [harbor](gallery/after/shopping_street_exit_harbor.jpg) [industrial](gallery/after/shopping_street_exit_industrial.jpg) [old_town](gallery/after/shopping_street_exit_old_town.jpg) [residential](gallery/after/shopping_street_exit_residential.jpg)

### startup_hub

| Before | After |
|---|---|
| [1200](gallery/before/startup_hub_frontage_1200.jpg) [1680](gallery/before/startup_hub_frontage_1680.jpg) [240](gallery/before/startup_hub_frontage_240.jpg) [720](gallery/before/startup_hub_frontage_720.jpg) | [1200](gallery/after/startup_hub_frontage_1200.jpg) [1680](gallery/after/startup_hub_frontage_1680.jpg) [240](gallery/after/startup_hub_frontage_240.jpg) [720](gallery/after/startup_hub_frontage_720.jpg) |

Exit views: [civic_center](gallery/after/startup_hub_exit_civic_center.jpg) [riverside](gallery/after/startup_hub_exit_riverside.jpg) [university](gallery/after/startup_hub_exit_university.jpg)

### university

| Before | After |
|---|---|
| [1200](gallery/before/university_frontage_1200.jpg) [1680](gallery/before/university_frontage_1680.jpg) [2160](gallery/before/university_frontage_2160.jpg) [240](gallery/before/university_frontage_240.jpg) [720](gallery/before/university_frontage_720.jpg) | [1200](gallery/after/university_frontage_1200.jpg) [1680](gallery/after/university_frontage_1680.jpg) [240](gallery/after/university_frontage_240.jpg) [720](gallery/after/university_frontage_720.jpg) |

Exit views: [airport](gallery/after/university_exit_airport.jpg) [startup_hub](gallery/after/university_exit_startup_hub.jpg)

## F1-F8 review and player perspectives

| Principle | Before | After / evidence |
|---|---|---|
| F1 | Existing guide | Preserved; replay entry retained. Blind novice study NOT VERIFIED. |
| F2 | N/A | No timing or income rule changed. |
| F3 | FAIL: inaccessible industry consoles | PASS in new/unlocked/operating Helio fixtures; old running access retained. |
| F4 | PARTIAL: operating tabs before startup | Startup requirements and one next action stay visible. |
| F5 | N/A | Assistant policy and all Session I files untouched. |
| F6 | PARTIAL: small/damaged sign slots | Name and direction occupy bounded slots; startup requirements visible. |
| F7 | PARTIAL: ambiguous routes | Distinct triggers/return spawns; old-save and ledger suites cover existing state. |
| F8 | FAIL: duplicate arrow and all gold spokes | One quiet road sign; current destination ring only; minimap arrows stay cardinal. |

Novice fixture: the arrival shows a train without a floating sedan; street signs name the neighbouring district; a locked Helio desk is hidden; an eligible desk explains where to register/fund/lease; actual paid startup opens the operating console. These are reproducible automated views, not independent human discovery.

Experienced-player fixture: both real operating Helio entrances work; paid lease/startup preserve balanced entries; the full unit suite includes existing played-save fixtures and company closure. A human ten-hour replay and subjective enjoyment study remain unverified.

Self-review fixes: parallel exits originally collapsed together, south approach originally landed in traffic, font ascent exceeded board height, crossed asphalt was mistaken for absent road, inactive energy summaries hid startup prerequisites, and dynamic lease management lacked an icon. Final geometry/checker and capture fixtures cover these regressions.
