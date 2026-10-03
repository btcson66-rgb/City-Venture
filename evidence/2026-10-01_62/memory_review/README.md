# #74 review: large texture cache lifetime

Before: `8f8297bd` (permanent cache). After: five large categories share an eight-entry LRU.

Measured with Godot 4.5.1, OpenGL 3.3 Compatibility, Quadro RTX 4000, 1280×720; separate fresh processes and isolated APPDATA directories. `Performance.RENDER_TEXTURE_MEM_USED` is read from a real rendered process, not headless. Same QA script, seed/default appearance, noon time, route, settling delays and live endpoint in both runs.

The route enters every implemented district through the real SceneRouter: riverside → startup_hub → civic_center → financial → shopping_street → harbor → old_town. It positions the player at three points per district, lets physics/camera/render frames run, then removes transient location cards before sampling. The other five city-map districts have no implemented District definition and are not falsely counted as visited. This is a controlled renderer circuit, not a manual input walkthrough.

| Sample | Before: bytes | After: bytes | Large cache entries |
|---|---:|---:|---:|
| start | 11,049,491 | 11,049,491 | 0 → 0 |
| riverside | 346,143,611 | 346,143,611 | 4 → 4 |
| startup_hub | 396,586,995 | 396,586,995 | 5 → 5 |
| civic_center | 425,792,379 | 425,792,379 | 6 → 6 |
| financial | 455,162,675 | 455,162,675 | 7 → 7 |
| shopping_street | 520,470,627 | 520,470,627 | 7 → 7 |
| harbor | 664,091,063 | 660,552,327 | 10 → 8 |
| old_town | 705,795,943 | 700,487,839 | 11 → 8 |
| end | 705,795,943 | 700,487,839 | 11 → 8 |
| after_twenty_backgrounds | 974,655,313 | 859,182,632 | 26 → 8 |

One full seven-district circuit: **705,795,943 → 700,487,839 bytes** (705.80 → 700.49 decimal MB; decrease 5,308,104 bytes). This circuit loads only 11 distinct large textures, mostly small location cards, so its savings are modest. Remaining texture memory includes permanently cached small art and the last live scene.

Separate long-play stress, after the circuit: sequentially read 20 distinct real detail backgrounds without retaining their textures in the script. **974,655,313 → 859,182,632 bytes** (974.66 → 859.18 MB; decrease 115,472,681 bytes). Before retains 26 large entries including earlier cards; after retains 8 total. The current district still holds its visible skyline even when its cache entry is evicted.

These are local native OpenGL measurements; they do not claim to reproduce the reviewer's 2.2–2.9 GB browser run or establish browser crash immunity. The unit regression also uses WeakRef to confirm an evicted, otherwise unused ImageTexture is actually released, and confirms still-visible textures remain usable.

Validation: 274/274 unit tests passed; 40 real geometry/click/render comparison captures, 0 failures; i18n missing 0; wiki_check OK. Original full zh_TW walkthrough evidence remains in the parent folder; the 43-minute story walkthrough was not rerun for this cache-only review fix.

Reproduce on either source revision (before is `8f8297bd`) using this QA script:

```text
godot --path game --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1280x720 --script ../tools/qa/texture_memory_circuit.gd -- --out=<output.json>
```

`before.json` / `after.json` retain exact bytes at every stop; logs retain renderer identity. No screenshot added for a numeric memory measurement.

Release rebuild also passed all four platform exports and 274/274 tests (24.0s). New Web index.pck: 150,660,248 bytes; Windows zip: 173,718,706 bytes. Actual newly exported Web PCK detail probe: 150 textures, 0 failures. SHA256SUMS are attached. Latest base merged before push: a9124264 (ROADMAP documentation only).
