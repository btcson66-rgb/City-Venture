# S1 source illustrations · 2026-09-30

The six PNGs here are the full generated source art for the fifth-round S1 delivery. The paired runtime assets are in `game/assets/{backdrops,characters,portraits}` and `game/assets/world_detail/{backdrops,characters,portraits}`. Generated sources are preserved so subsequent paintovers can retain the palette and character identity.

Visual direction: premium modern-city painterly pixel art, blue glass and deep navy outlines, warm upper-left sunlight, amber highlights, restrained green. The chapter cards use the existing `renewal_20260929/financial.png` and `bank.png` as style references; Lina's sheet uses `runtime_20260930/npc_priya.png` as a layout reference. All scene and character content is new.

| Source | Subject | Final assets |
| --- | --- | --- |
| `chapter_7_source.png` | Queued cargo ships and half-empty store shelving | `backdrops/chapter_7.png` |
| `chapter_8_source.png` | Rooftop solar array, skyline and charging van | `backdrops/chapter_8.png` |
| `chapter_9_source.png` | Bank queue and an icon-only hourglass display | `backdrops/chapter_9.png` |
| `lina_stand_source.png` | Lina front, right profile and back, four cells each | `characters/npc_lina.png` |
| `lina_sit_source.png` | Lina seated in three directions | `characters/npc_lina_sit.png` |
| `lina_portrait_source.png` | Neutral, smile, thinking, surprised | `portraits/npc_lina.png` |

Packing notes: chapter cards are cropped to 16:9 then sampled to 2560×1440 and 640×360. Lina's standing source figures sit at x ranges 247–409, 511–674, 779–936, 1047–1210 (front); 240–389, 509–657, 781–927, 1053–1199 (side); and 253–409, 519–675, 788–945, 1056–1212 (back), with row ranges y 0–393, 394–730 and 731–1086. Each cell is trimmed, fitted inside 112×176 pixels and placed into a 128×192 world-detail cell. The seated source is split into three equal columns, fitted inside 112×132 and repeated across four frames per row. The portrait source is split into four panels and square-cropped from the top. Original-size sprites are quarter-scale resamples of those atlases. This avoids shifting the engine's logical sprite footprint.
