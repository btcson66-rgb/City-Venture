# District completion (#179, Implemented)

Every district retains its existing buildings and businesses. Previously bare frontage
and street-side lots now have themed gardens or rest courts, stone paths, seats and lamps.
They add no business, timed challenge, upgrade bonus or saved-state key.

New native 1x props and matching 4x world_detail props:
`pocket_fountain`, `reading_pavilion`, `flower_market`, `workshop_garden`,
`leaf_pergola`, `cycle_shelter`. Water, brick, planting and warm lamps use the existing
upper-left light direction and material palette. Market produce and shelter bicycles
are static scenery; existing pedestrians and through traffic provide actual motion.

| District | Purpose |
|---|---|
| airport | Travel garden with cycle parking and shelter |
| civic_center | Civic court with water and reading pavilion |
| financial | Lunch court with shade and cycles |
| harbor | Dockside market and fenced workshop gardens |
| industrial | Workshop gardens and cycle shelters |
| luxury_heights | Terrace gardens with fountains and pergolas |
| old_town | Old Town market and reading gardens |
| residential | Neighbourhood reading and shaded gardens |
| riverside | Riverside fountains and flower markets |
| shopping_street | Market rest courts and cycle parking |
| startup_hub | Maker courts and planted pergolas |
| university | Campus reading gardens and cycle shelters |

`public_spaces` describe presentation coverage in district pixels, with `name`, `rect`
and `purpose`. Frontage gardens stay behind the existing building boundary; they are
viewed from the public pavement. Lower rest courts have an accessible surrounding path,
with the normal eight-pixel prop foot collision. Names are capitalized translation keys.
Lamps use existing day/night lighting. Ambient morning/afternoon crowds remain cosmetic.

Sky, water, clear road/pavement travel lanes and the narrow planted exit connector are
intentional retained open areas, with coordinates in the empty-lot report. No new exit
or public entrance is added. The reading pavilion is scenery, not an undisclosed library
business. All existing building entrances, metro and 40 directional links stay usable.
