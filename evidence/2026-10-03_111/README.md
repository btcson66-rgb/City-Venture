# #111 Walking geography review

473/473 tests passed in 121.3s. Checker: 12 districts, 20 undirected links, 40 exits and corresponding spawns, all reachable. Seven checker mutation tests pass. Actual rendered circuit walks all 40 directed links: 0 failures in 406.2s. English audit contains only the existing GATEWAY brand. Final rendered diagram/four-direction sign tour: 0 failures, 0 English audit hits; five JPGs visually inspected, about 1 MB total. i18n --check missing 0, wiki OK, beta audit 0. No assets edited.

Review fixes: dominant map direction and reciprocal spawns; unpainted district ground extensions; real Godot nav clearance; skyline preserving corridor ground; outer corridor walls; target exit approach avoids entering a different exit on the same edge; actual button click verification, diagram label fit and directional minimap arrows; missing facade door metadata fallback; isolated bot saves rather than overwriting player saves.

Full rendered walkthrough: first run failed (867 cascading failures), beginning with the obsolete direct Shopping Street → Civic Center assumption. The walkthrough now computes BFS hops through the canonical graph; a complete fresh replay is pending in full-final. Do not mark this acceptance gate passed until its result is verified.

Canonical map_pos and the illustrated board positions are distinct existing coordinates. The Walking routes view uses map_pos directly, with the illustration available via toggle. The initial graph is a Gabriel neighborhood, explicit and designer-editable. The dedicated map CI gate is added locally; upstream #98 CI is not yet merged.
