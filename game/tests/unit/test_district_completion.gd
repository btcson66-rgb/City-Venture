extends RefCounted
var runner
func test_public_gardens_keep_ground_and_existing_routes() -> void:
	for id in DataDB.districts:
		var district := District.new()
		district.build(id)
		runner.check(not district.def.get("public_spaces", []).is_empty(), "themed spaces present: " + id)
		for space in district.def.get("public_spaces", []):
			if space["purpose"] != "frontage_garden": continue
			var r: Array = space["rect"]
			var cell := Vector2i(int(r[0] + r[2] / 2) / 16, 18)
			runner.check(district.ground.get_cell_source_id(cell) >= 0, "skyline retains landscaped ground: " + id)
		runner.check(district.cars.size() >= 2, "through traffic remains distributed: " + id)
		runner.check(district.peds.size() >= 2, "ambient pedestrians remain present: " + id)
		district.free()
		runner.check(Ledger.check_balanced(), "district decoration cannot move money")
func test_new_scenery_keeps_native_and_fourfold_detail_geometry() -> void:
	for sprite in ["pocket_fountain", "reading_pavilion", "flower_market", "workshop_garden", "leaf_pergola", "cycle_shelter"]:
		var native := Art.tex("props/" + sprite)
		var detail := Art.tex("world_detail/props/" + sprite)
		runner.check(native != null and detail != null, "both resolutions exist: " + sprite)
		runner.eq(detail.get_size(), native.get_size() * 4, "render detail preserves design footprint")
