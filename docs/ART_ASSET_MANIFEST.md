# CITY VENTURE — Art Asset Manifest

Style: **NEO-CIVIC PIXEL REALISM** (Handoff §37–§50, §83–§85; concept boards in `docs/reference/concept_boards/`).
Grid: 16 px environment tiles. Characters are 32×48 frames. Nearest-neighbor scaling at 2×/3× (base 640×360).
Palette anchors: see `CITY_VENTURE_SPEC_READBACK.md` §F. Placeholders come from `tools/art/gen_placeholders.py` into `game/assets/`, one file per row below, so final art replaces them 1:1 by path.

### Codex visual art pass (2026-09-28)

The current playable screens received new menu and arrival illustrations, refined layered character and portrait art, and a shared UI skin pass. The asset interface and game design remain unchanged. Source images, conversion commands, rendered screenshots, QA results, and remaining art limits are recorded in [`evidence/visual_art_pass_2026_09_28/README.md`](../evidence/visual_art_pass_2026_09_28/README.md). The v3 status table below continues to describe the other converted world assets.

### A1 walking character art (2026-09-28)

All 128 `game/assets/characters/*.png` sheets were reviewed and regenerated on the
original 128×144 canvas. Body presentations have distinct shoulder and waist
profiles, eight hair shapes have different front/side/back silhouettes, the
nine outfits retain their tintable layers, and the four side-walk frames now
exchange the leading foot. The generated interior outlines were removed from
the separate layers; Godot's existing composite outline shader still defines
the assembled character. This softens the boxed look without changing game
design, character data, frame dimensions, names, or nearest-neighbor display.
The A1 comparison, 12-NPC lineup, and QA record are in
[`evidence/2026-09-28_a1_characters/README.md`](../evidence/2026-09-28_a1_characters/README.md).
Portraits remain in A5. Elena's data-driven appearance difference is Claude
program-wiring item #18.

### R1 dyeable outfit layers (2026-09-28)

`business_suit` and `courier` now separate grayscale top and bottom fabric
from full-colour top details for all three presentations. Each also has a
grayscale portrait collar with an untinted `outfit_<id>_detail` overlay.
The six new walking detail sheets and two new portrait detail images retain
the existing dimensions and art paths. Four suit colours and PostPoint red
are reviewed in [`evidence/2026-09-28_r1_outfit_details/README.md`](../evidence/2026-09-28_r1_outfit_details/README.md).

### A2 interior art (2026-09-28)

The 68 existing furnishings retain their dimensions and placement contract.
Seven key objects were redrawn: bank and civic counters, menu board, laptop
desk, packing table, wardrobe and stock box. Five existing floor panoramas
receive gentle colour smoothing; three new 512×320 floor panoramas cover white
tile, checker and navy carpet. Seven wall tiles retain their atlas coordinates.
See [`evidence/2026-09-28_a2_interiors/README.md`](../evidence/2026-09-28_a2_interiors/README.md)
for the eight room comparisons and remaining visual limits.

### R3 layered character poses (2026-09-28)

The 128 A1 walk layers and six R1 outfit detail layers each have five new
128×144 pose sheets: `sit`, `idle`, `phone`, `interact`, and `carry` (670 PNGs).
The first four poses use a two-frame cycle; carrying retains four frames.
All sheets keep the original 32×48 frame alignment and three directions,
and every new PNG has a Godot `.png.import` companion. The art script is
`tools/art/r3_poses.py`. Composite comparisons and QA details are in
[`evidence/2026-09-28_r3_poses/README.md`](../evidence/2026-09-28_r3_poses/README.md).
The existing game test expecting missing sit art now requires an update on
Claude's gameplay track.

### Status after Art Pass v3 (feedback: "still not good enough — match the boards' style, content and quality")

Art Pass v3 turns the approved concept boards themselves into game-ready assets, as Handoff §83 requires for AI concept
art ("must be converted into consistent game-ready sprites"). The conversion is code, not hand edits:
`tools/art/concepts.py` crops each asset from `docs/reference/concept_boards/`, keys out the board background
(border-connected flood region + de-fringe), downsamples in premultiplied alpha onto the game's pixel grid, snaps to a
per-asset palette, and darkens the silhouette edge. Where the converted art is bigger than the old footprint, the overhang
is written to `game/assets/sprite_meta.json` so placement data and collisions keep working. Everything regenerates with
`python3 tools/art/gen_placeholders.py` (needs `pip install -r tools/requirements.txt`).

| Area | Source board(s) | What is in the game now | Status |
|------|-----------------|--------------------------|--------|
| Street props: lamps, banner lamps, trees (3), planters, flower boxes, bins, digital kiosk, Metro pylon, A-frame, cone, bollard, bench | C "Props & Environment", G "Architectural details", A "Pixel style" | Converted sprites replace the procedural ones 1:1 by name | CONV |
| Interior furniture: desks, office/leather chairs, monitor desks, whiteboard, bookshelf, plants, exec desk, sofas, bed, coffee table, TV, kitchen, ATM, brochure stand, queue barrier, waiting sofa, café tables/chairs/armchair, display case, pendant lights, filing cabinet, lockers, phone booth, lounge sofa, community table, server rack, ticket machine, info kiosk; bank/civic/café counters (composites) | H prop strips, A | Converted sprites | CONV |
| Interior windows (day/night, normal/wide) | G day skyline banner, D dusk skyline banner | Window frames show the board skyline | CONV + GEN frame |
| Interior floors (wood warm/dark/café, marble, concrete) | Board H palette | Continuous 512×320 non-repeating floors | GEN v3 |
| Building facades | G skyline (glass reflections), H/C interiors (storefront + office glass), C/G plants (roof edges) | Procedural volumes from v2, now textured with board content | GEN v3 + CONV textures |
| District sky | G day banner, D dusk banner | Parallax skyline behind every block, day→dusk→night cross-fade | CONV |
| Main menu backdrop | C "Mixed-use Neighborhood (Day)" | Full-bleed, slow pan | CONV |
| Arrival backdrop | D skyline banner | Dusk skyline + generated river reflection; train/bridge drawn in-game | CONV + GEN |
| City Map screen | F "Main City Map (Isometric)" | Board map; district labels redrawn as live in-game buttons over the board's label spots | CONV |
| City Map district images | F district marker tiles, C/F/G/H panels | Info-panel pictures | CONV |
| World Map screen | E "World Map" | Board map; region labels redrawn in-game; Aurelia pin added | CONV |
| Region previews | E "Region Preview" | Thumbnails in labels and the info strip | CONV |
| Location cards (first visit) | C, F, G, H panels | Riverside, Financial, Startup Hub, Civic Center, City Hall, Nexus Bank, Riverside Tower, Bloom Coffee, Bean & Byte, Nexus Co-work, Suite 2B | CONV (City Hall sign re-lettered "AURELIA") |
| Character sprites | — | Procedural rig from v1/v2; v3 adds a whole-silhouette outline shader (`shaders/char_outline.gdshader`) | GEN v2 + outline |
| Portraits | — | v3 adds form shading, head outline, anime-style iris gradient + sparkle, cheek blush | GEN v3 |

Legend addition: **CONV** means the asset is converted from the approved concept boards by `concepts.py`. It has a consistent
grid and palette, but it is **not final hand-finished art**. The boards are AI concept images, and a pixel artist should
repaint the final assets. Board text that clashed with game data was fixed: the cafe is now "Bean & Byte" (Board H) and City
Hall's "Riverdale" sign now reads "Aurelia". Characters are still the weakest area compared with the boards.

### Status after Art Pass v2 (feedback: "too simple — needs design sense, use the boards")

| Area | Generator | What changed vs v1 | Status |
|------|-----------|--------------------|--------|
| Building facades | `tools/art/facades.py` | Oblique 3/4 volume (side wall + roof plane), rooftop greenery/equipment/terraces, glass with lit interiors + sky reflections, floor slabs, canopies with downlights, awnings, sign bands, brand pylons/banners, wall lamps, night light overlays | Placeholder (GEN v2) |
| Street layer | `tools/art/street.py`, `tools/gen_districts.py` | Stone pavers, granite curbs, textured asphalt, 64×92 clustered trees with grates, banner lamps, curb bollards, planters, café terraces, bus shelter, wayfinding, hedges, river railing; facade contact shadows | Placeholder (GEN v2) |
| Interiors | `tools/art/interiors2.py` + `interior.gd` | Detailed furniture, wainscoting, crown moulding, floor AO, window light spill, furniture contact shadows, framed art, sconces | Placeholder (GEN v2) |
| Portraits | `tools/art/chars.py` | Lock-based hair with glossy highlight ring | Placeholder (GEN v2) |
| Character sprites | `tools/art/chars.py` | Unchanged since v1 besides hair spikes — next art task | Placeholder (GEN v1) |
| UI kit | `tools/art/ui.py` | Board A gradient panels, lit borders, gradient buttons/tabs | Placeholder (GEN v2) |

None of these are final art. They are deliberately built on the final grid, scale and palette so a
pixel artist can replace each PNG 1:1.

Placeholder column legend:
- **GEN** — generated placeholder is in the build. It follows the grid, scale and palette, but it is not final art.
- **—** — no placeholder yet (not needed by the P0 slice).

Phase column: the milestone that first needs the asset (P0 = Vertical Slice).

---

## characters/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| `body_<presentation>_<face>` (skin layer, grayscale ramp → tinted) | P0 | 32×48 / frame, sheet 4×3 | idle + 4-frame walk | down, side (flip for L/R), up | GEN (3 presentations × 4 face shapes) | Hand-drawn base bodies, anime-grounded proportions, clean 1 px outline, 3-tone skin ramp |
| `eyes_<shape>` (+ eye colour tint layer) | P0 | 32×48 | blink (P1) | down, side | GEN (4 shapes) | Readable at 1×; blink frames |
| `brows_<style>` | P0 | 32×48 | — | down, side | GEN (4 styles) | — |
| `mouth_<style>` | P0 | 32×48 | talk (P1) | down, side | GEN (4 styles) | — |
| `hair_<style>_back` / `_front` (grayscale → tinted) | P0 | 32×48 | walk bob | down, side, up | GEN (8 styles) | Distinct silhouettes; hair must read at 1× |
| `outfit_startup_casual_<presentation>` | P0 | 32×48 | walk | all | GEN | Blazer + tee + jeans + sneakers (Board A "Default") |
| `outfit_office_professional_<presentation>` | P0 | 32×48 | walk | all | GEN | Shirt, lanyard, slacks/skirt (Board A "Office") |
| `outfit_home_<presentation>` | P0 | 32×48 | walk | all | GEN | Hoodie/lounge wear |
| `outfit_<npc_role>` (barista apron, business suit, civic staff, courier, casual variants) | P0 | 32×48 | walk | all | GEN | For NPC variety using the same rig |
| `outfit_executive`, `outfit_logistics_site`, `outfit_luxury_citywear`, `outfit_travel`, `outfit_formal_evening` | P1 | 32×48 | walk | all | — | Board A Executive / Casual City looks |
| Accessories: glasses, hats, bags, backpack, lanyard, jewelry, watches | P1 (glasses, backpack P0) | 32×48 | walk | all | GEN (glasses ×2, backpack) | — |
| Sit / interact / carry-box / phone poses | P1 | 32×48 | 2–4 frames | down, side | — | Needed for desk use and parcel carry |

## portraits/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| Player portrait layers (face shape, eyes, brows, mouth, hair back/front, collar per outfit) | P0 | 64×64 | expression swap | front ¾ | GEN | Board A Facial Expressions quality |
| Expressions: Neutral, Happy, Thinking, Surprised | P0 | 64×64 | — | front | GEN | — |
| Expressions: Confident, Determined, Cheerful, Excited, Relaxed, Serious | P1 | 64×64 | — | front | — | — |
| Named NPC portraits (Maya, Jun barista, Priya co-work, Ken supplier, Clerk Ana, Banker Sofia, Marcus Reed, Leasing agent Tom, Customer avatars) | P0 | 64×64 | 2 expressions | front | GEN (composed from the same layers) | Unique hand-drawn portraits |
| Daniel Wong, Elena Park, Lina Zhao, Omar Haddad, Victor Hale | P1–P2 | 64×64 | 4 expressions | front | — | — |

## buildings/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| Riverside apartment tower (player home), retail podium | P0 | ~176×224 | night lights overlay | front (¾ top-down) | GEN | Board G "Apartment Tower": balconies, warm interiors, rooftop greenery |
| Mixed-use block with Bloom Coffee | P0 | ~160×160 | lights overlay | front | GEN | Board G "Mixed-use Shopfront Block" |
| PostPoint parcel shop / convenience | P0 | ~112×112 | lights | front | GEN | — |
| Metro station entrance (Riverside, Startup Hub, Civic, Financial) | P0 | ~80×72 | — | front | GEN | Board F Metro Station |
| Nexus Co-work building | P0 | ~176×192 | lights | front | GEN | Board H Co-working "NEXUS – Work · Meet · Create" |
| Startup Office building (Horizon Labs, neighbour) | P0 | ~176×208 | lights | front | GEN | Board G Startup Office: glass, terraces, plants |
| Small office building (player-leasable Suite 2B), sign shows player company | P0 | ~144×176 | lights + dynamic sign | front | GEN + runtime sign text | — |
| Byte & Bean cafe (Startup Hub) | P0 | ~128×128 | lights | front | GEN | — |
| Nexus Bank | P0 | ~192×208 | lights | front | GEN | Board G Bank: stone + glass, institutional |
| Aurelia City Hall | P0 | ~240×208 | flags (P1 anim) | front | GEN | Board G City Hall: stone, glass, flags, plaza |
| Filler: glass tower, brick shops, residential walk-up, office slab | P0 | various | lights | front | GEN | Modular kit |
| Harbor warehouse, Luxury condo, Car dealership, Airport terminal | P1–P2 | large | — | front | — | Board G |
| Facade material swatches: glass, concrete, brick, metal, stone, wood | P0 (kit) | 16×16 tiles | — | — | GEN (inside the building generator) | §47 |

## interiors/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| Floors: warm wood, tile, carpet, stone lobby, concrete | P0 | 16×16 tiles | — | — | GEN | — |
| Walls + skyline windows (day / night view) | P0 | 16×48 modules | day/night swap | — | GEN | Board H windows with city view |
| Apartment set: bed, desk + laptop, chair, sofa, coffee table, bookshelf, TV, kitchenette, fridge, wardrobe, plant, rug, moving boxes (stock-scaled) | P0 | 16–64 px | laptop screen glow | front | GEN | Board H Apartment / Home |
| Cafe set: counter, espresso machine, menu board, display case, tables ×2 styles, chairs, hanging lights, plants | P0 | 16–96 px | — | front | GEN | Board H Cafe "Bean & Byte" |
| Co-working set: hot desks + monitors, meeting room glass, phone booth, sofa lounge, printer, lockers, business board | P0 | 16–96 px | — | front | GEN | Board H Co-working |
| Small/startup office set: desks, office chair, monitors, whiteboard (IDEAS/PEOPLE/PRODUCT/GROWTH), shelf, plant, company wall sign | P0 | 16–96 px | — | front | GEN | Board H Startup Office |
| Bank set: reception/teller counter, waiting sofa, ATM, brochure stand, queue barrier, floor sign, logo wall | P0 | 16–96 px | — | front | GEN | Board H Bank Lobby |
| City Hall set: service counters, ticket machine, benches, flags, info kiosk, seal wall | P0 | 16–96 px | — | front | GEN | Board G/H civic |
| PostPoint counter, parcel shelves | P0 | 16–64 px | — | front | GEN | — |
| Executive office, logistics control room, clothing store, wardrobe room | P1–P3 | — | — | — | — | Board H |

## vehicles/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| Modern sedan (body tint + glass/tyre layer) | P0 (traffic) | 64×32 side, 32×48 front/back | wheel 2-frame | L/R/U/D | GEN | Board A Modern Sedan (4 colours, multiple angles) |
| Compact car, city bus, delivery van, taxi | P0 (traffic) | 56–96 px | wheel | L/R | GEN | — |
| SUV, sports car, luxury car | P1–P3 | — | — | — | — | §34 |
| Aircraft, cargo ship (world map) | P2 | 16–32 | move | — | GEN (world map icons) | Board E |

## props/ (street)

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| Tree (round, tall), planter, bench, street lamp (+glow), trash bin, bike rack + bike, metro sign, cafe A-board, umbrella table, bus stop, billboard, digital sign, parking meter, traffic cone, street direction sign, fire hydrant, business board kiosk | P0 | 16–64 px | lamp glow at night | front | GEN | §48 street objects; Board A/G architectural details |
| Product mini-sprites (earbuds, desk lamp, bottle, phone stand) + parcel box | P0 | 16×16 | — | — | GEN | — |

## ui/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| 9-slice panels: navy panel, inset, header bar, button (normal/hover/pressed/disabled), tab, tooltip | P0 | 16×16 / 24×24 | hover | — | GEN | Board A Game UI sample |
| Icons 16×16: cash, clock, calendar, sun/moon, objective, home, company, map, people, tasks, phone, inventory, orders, finance, contracts, bank, warning, check, lock, metro, parcel, star | P0 | 16×16 | — | — | GEN | Board F Mission/Activity icons style |
| Phone frame + app icons | P0 | 128×224 | open/close | — | GEN | — |
| Dialogue box + portrait frame | P0 | 9-slice | text reveal | — | GEN | — |
| Interaction prompt (key cap) | P0 | 16×16 | pulse | — | GEN | — |
| Minimap frame + markers | P0 | 96×72 | — | — | GEN (runtime-drawn from district data) | Board F Minimap |
| Fonts | P0 | — | — | — | Pixelify Sans (headings), Godot default sans (body) | Final brand typeface pairing |

## city_map/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| Aurelia city overview (angled / isometric, river, bay, districts) | P0 | 640×360 | water shimmer (P1) | — | GEN (stylised angled map) | Board F isometric main city map |
| District label cards + marker icons (Financial, Startup, Riverside, Harbor, Residential, Shopping, Civic, Luxury, Airport, Metro) | P0 | 16×16 icons + 9-slice card | — | — | GEN | Board F district marker icons |
| Metro map (M1–M5) | P0 | 256×160 | — | — | GEN (runtime-drawn from data) | Board F metro map |
| Neighborhood zoom renders | P1 | — | — | — | — | Board F neighborhood zoom |

## world_map/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| World map (continents, oceans, clouds) | P0 (screen), P2 (gameplay) | 640×360 | clouds drift | — | GEN (procedural pixel continents) | Board E world map |
| Region cards / thumbnails for Aurelia + 7 markets | P0 (info), P2 | 48×32 | — | — | GEN | Board E region preview |
| Air routes, shipping routes, plane, cargo ship, mission markers, legend icons | P2 | 8–16 px | route dash anim | — | GEN (icons) | Board E legend |
| Travel UI | P2 | — | — | — | — | Board E travel UI |

## effects/

| Asset | Phase | Size | Animation | Direction | Current placeholder | Final asset requirement |
|-------|-------|------|-----------|-----------|--------------------|------------------------|
| Lamp / window glow (additive) | P0 | 32–64 | flicker-free | — | GEN | — |
| Day/night grade | P0 | — | time-driven | — | CanvasModulate gradient (code) | Board C/D colour script |
| Water sparkle, footstep dust, interaction sparkle, money pop (+$/−$) | P0 | 8–16 | 4 frames | — | GEN | Avoid casino-style coin bursts (§87) |
| Rain / wet reflections | P1 | — | — | — | — | Board D wet reflection |
| Screen fade | P0 | — | tween | — | code | — |
