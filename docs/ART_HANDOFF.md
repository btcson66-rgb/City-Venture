# Art handoff: replacing CITY VENTURE's visuals

This page is for whoever takes over the visuals: Codex, another agent, or a pixel artist. It explains how to swap
art without touching game code. Gameplay, content and systems stay with the Claude Code track, and the game already
reads every image by file path. You can change the pictures and the game keeps working.

**Start with the game wiki: [`docs/wiki/`](wiki/README.md).** It lists every asset with its size, use and status, plans
the planned districts, buildings, interiors, characters and items, and gives the prioritized art backlog in
[`docs/wiki/90_codex_art_backlog.md`](wiki/90_codex_art_backlog.md). This page stays as the short technical summary.

## Ground rules

1. **Committed PNGs are the source of truth.** `tools/build.sh` no longer regenerates art. The procedural generator
   (`tools/art/gen_placeholders.py`) runs only with `REGEN_ART=1 tools/build.sh`. If you run it by hand, it
   **overwrites** `game/assets/`.
2. **Keep file names and folders.** The code loads `Art.tex("interiors/menu_board")` →
   `game/assets/interiors/menu_board.png`. You can add new files. Renaming a file breaks the lookup.
3. **Size changes need the matching metadata.** Buildings use `game/assets/buildings/buildings_meta.json`. Furniture and
   street props that overhang their footprint use `game/assets/sprite_meta.json`. Tiles use
   `game/assets/tiles/atlas.json`. After changing a building size or its door, run `python3 tools/gen_districts.py`.
4. **No baked-in words where the game draws text.** Shop signs, NPC names, prompts, map labels and prices are drawn
   by code, so they can be translated and stay crisp. Signs are drawn in the `sign` rect of `buildings_meta.json`.
   If a sprite must carry text, like the café menu board, use glyphs at least 5 px tall with a 1 px gap between
   rows. The old menu board fused its lines together, and players reported it as garbled text.
5. **Pixel rules:** nearest-neighbour filtering. The base canvas is 640×360, so 1 art pixel is 2 screen pixels at
   1280×720. Sprites should have no semi-transparent edge halos. Characters get a 1 px dark outline from a shader
   (`shaders/char_outline.gdshader`), so don't draw one into character layers.
6. After replacing files, run `godot --headless --path game --import`, then the unit tests and
   `-- --bot=shots --out=/tmp/shots` for a screenshot tour of every district and interior.

## What exists today (sizes in art pixels)

| Folder | What | Format the code expects |
|--------|------|-------------------------|
| `characters/` | Layered player/NPC sprites: body (per presentation × skin), eyes, iris, brows, mouth, hair, outfit, accessory | Each layer is a **128×144 sheet of 32×48 frames: 4 walk frames × 3 rows (down, side, up)**. Left = side flipped. Origin at the feet. All layers of one frame must line up |
| `portraits/` | Dialogue portraits, layered the same way | 256×64 strips (see `portrait_view.gd`) |
| `buildings/` | Street facades plus `_lights` night overlays (same size) | Any size. `buildings_meta.json`: `size`, `front_w`, `depth`, `door` [x,y,w,h], `sign` [x,y,w,h], `sign_text` |
| `interiors/` | Furniture, counters, wall decor, floors (`floor_*.png` are large seamless images) | Any size. Footprint and overhang in `sprite_meta.json` (`dw`, `dh`, `left`) |
| `props/` | Street furniture, trees, product sprites (`product_*.png`) | Any size. The district data's `x, y` is the footprint's top-left; draw order uses the bottom edge |
| `tiles/` | 16×16 ground/wall tiles | `atlas.png` + `atlas.json` (name → cell) |
| `vehicles/` | Cars/bus: `_body` (tinted) + `_detail` layers, per direction | Same size per pair |
| `backdrops/` | Menu (752×360, slow pan), arrival (640×360), skyline strips (1300×320) | — |
| `cards/` | First-visit location cards | 192×108 |
| `city_map/`, `world_map/` | Map boards and region thumbnails | Label and pin coordinates live in `data/city/aurelia.json` and `data/regions/*.json` (`board`) |
| `ui/` | 9-slice panels, buttons, tabs, bars, icons (`ui/icons/*.png`, 16×16), app icon (256 and 1024) | 9-slice margins are set in `scripts/ui/uik.gd` (`tex_box`) |
| `effects/` | Glows (additive), shadow | — |

The concept boards the product owner approved are in `docs/reference/concept_boards/`. Their style (warm, detailed,
lived-in city; top-down 3/4 interiors; readable UI) is the target. `docs/ART_ASSET_MANIFEST.md` lists which assets
were converted from the boards and which were generated.

## Things the art must support (gameplay needs them)

- **Doors and exits must read as exits.** The game adds a pulsing "EXIT" marker on each room's door mat and arrow
  signs at street edges. Your doorways should still be visible without them.
- **Day and night.** Buildings have `_lights` overlays and interiors use window sprites `window_day` / `window_night`.
- **Walkable floor.** Interiors are 16 px tiles wide/high (`data/buildings/*.json` → `interior.size`). The top 3
  rows are wall. Furniture positions are data, so move them in JSON, not in the art.

## Changes made on the gameplay track that touch art (so nothing is lost)

- `interiors/menu_board.png`: redrawn at 66×34 with spaced rows (garbled-text fix). The Bloom Coffee layout moved
  the board to x=18 and the first pendant lamp to x=90 (`data/buildings/bloom_coffee.json`).
