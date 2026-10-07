# Reference character sources

Generated with the built-in imagegen tool from the user supplied City Venture concept boards. `prompt_calls.js` preserves the three exact submitted tool calls and their reference roles. These are archived provenance, not a build script.

- heads.png: four front and four side grayscale skin/head components.
- hair.png: eight customizable hairstyles, each front/side/back.
- clothing.png: nine base outfits, each front/side/back.
- crop_manifest.json: alpha crop coordinates, tint normalization, connected alpha silhouette selection and target component names. Hair crops use overlapping bands and retain the main connected silhouette, excluding adjacent row fragments.

`node tools/art/reference_character_extract.cjs` slices generated atlases and normalizes tintable layers. It does not paint replacement imagery. Outputs live in custom_character_20261001/components. Rebuild shared sprites with custom_character_vectors.py and render_custom_character.cjs. Shopping Street's five existing garments use shop_wardrobe_vectors.py and render_shop_wardrobe.cjs, with synchronized gait and no legacy sleeve mask.

All skin tones tint the same head/body sources. Player presentation, facial options, hair and clothing IDs remain independent; no per-skin generated character replaces another identity. Native and 4x output atlas sizes are unchanged.
