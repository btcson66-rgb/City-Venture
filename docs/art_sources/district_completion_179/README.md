# District garden sprites (#179)

Generated with the environment image tool using the existing brick_shops building as the style reference. The exact raw prompt and transparency cleanup prompt are stored beside this file. Source hashes, reference hash, cell crops and final native/detail dimensions are in source.json. reference.png is the single compact atlas reference; large intermediate masters remain outside the repository.

Each cell is extracted by its alpha bounds and resized to 88 design pixels, with an exact 4x world_detail version. No vectors or painted replacements were introduced. Transparent atlas gaps are alpha zero; RGB color in transparent pixels is not opaque haze. The native texture defines placement and collision geometry. No gameplay function or brand is implied by the scenery.
