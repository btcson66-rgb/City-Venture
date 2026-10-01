# Street utilities, structures and market props

Three production atlases preserve nine utility objects, nine civic structures and four market props. Original atlas images, the supplied geometry guides and exact generation prompts are archived here. Style follows the reference boards: upper-left light, navy edges, rich metal/wood surfaces, cool glass and warm practical lights. Every destination/advertisement/menu panel, flag and card is blank.

`street_utilities_pack.py` does only inspected atlas slicing, alpha-bound cropping, proportional packing to existing native footprints and emission extraction. Hand-checked crop rectangles avoid neighboring objects crossing generated grid boundaries. It does not generate or paint illustration. `crops.json` and `manifest.json` record exact source rectangles, output dimensions and hashes. All existing dimensions and metadata remain unchanged. No tile atlas cell moved.

Run pack, Godot import, `street_utilities_check.py`, actual screenshot tours, `street_utilities_document.py`, and wiki_check. Existing WorldScene selects 4× props automatically. digital_sign and string_lights have separate matching emission masks, used by the existing prop light path.

Runtime text and the metro identifier on blank sign panels require Claude's overlay hookup; this batch intentionally contains no gameplay scripts/data/tests. It does not replace the separate metro entrance building sprite. Whole-game visual optimization remains in progress.
