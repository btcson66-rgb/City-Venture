# CITY VENTURE — Art Asset Manifest

Style: **NEO-CIVIC PIXEL REALISM** (Handoff §37–§50, §83–§85; concept boards in `docs/reference/concept_boards/`).
Grid: 16 px environment tiles. Characters are 32×48 frames. Nearest-neighbor scaling at 2×/3× (base 640×360).
Palette anchors: see `CITY_VENTURE_SPEC_READBACK.md` §F. Placeholders come from `tools/art/gen_placeholders.py` into `game/assets/`, one file per row below, so final art replaces them 1:1 by path.

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
