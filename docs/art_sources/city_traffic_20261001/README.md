# Street traffic production art

Six separate originals: sedan, compact hatchback, taxi, delivery van, bus and metro train. Sedan and compact originals contain the same vehicle in side/front/back views. They continue the reference board's upper-left light, navy glass, white neutral paint and warm lamps. No real brand, plate lettering or destination text is painted into the art.

`traffic_pack.py` only crops, resizes without aspect distortion, separates neutral paint from fixed details and extracts emission pixels. It preserves all existing logical PNG dimensions. Its wheel masks keep silver rims fixed when the car is dyed. `crops.json` records the inspected crops. Original alpha is preserved; there is no painted background removal.

Reproduce: `python tools/art/traffic_pack.py`; import in Godot; `python tools/qa/traffic_art_check.py`; `python tools/art/runtime_art_inventory.py`; `python tools/art/traffic_document.py`.

The native replacements appear in the existing runtime immediately. Existing car, menu and arrival renderers have no 4× vehicle lookup or emission mask hookup. These remain explicit integration work for Claude. The complete game inventory deliberately keeps unreviewed visual quality and runtime binding as NOT_YET_EVALUATED.
