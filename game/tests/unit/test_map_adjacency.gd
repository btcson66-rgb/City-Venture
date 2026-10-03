extends RefCounted
var runner

func test_all_district_exit_spawns_have_actual_nav_clearance_and_paths() -> void:
	for did in DataDB.city["adjacency"]:
		var d := District.new()
		UIRoot.get_tree().root.add_child(d)
		d.build(did)
		var outside := Vector2(d.size_px.x - 80, -4)
		runner.check(d.solids.any(func(r): return r.has_point(outside)), did + " corridor cannot leave an unconnected map edge")
		var origin: Array = d.def["spawns"]["metro"]
		for ex in d.def["exits"]:
			var neighbor: Dictionary = DataDB.city["adjacency"][did]
			runner.eq(ex["direction"], neighbor[ex["to"]], "runtime direction matches graph")
			var r: Array = ex["rect"]
			var target := Vector2(float(r[0]) + float(r[2]) / 2, float(r[1]) + float(r[3]) / 2)
			runner.check(not d.find_path(Vector2(float(origin[0]), float(origin[1])), target).is_empty(), did + " has an actual path to " + str(ex["to"]))
			var spawn: Array = d.def["spawns"]["from_" + str(ex["to"])]
			var tile := Vector2i(int(float(spawn[0]) / WorldScene.T), int(float(spawn[1]) / WorldScene.T))
			runner.check(d.ground.get_cell_source_id(tile) >= 0, did + " arrival retains painted ground under sky")
			var cell := Vector2i(int(float(spawn[0]) / WorldScene.NAV_CELL), int(float(spawn[1]) / WorldScene.NAV_CELL))
			runner.check(d.nav.is_in_boundsv(cell) and not d.nav.is_point_solid(cell), did + " arrival is free")
		d.queue_free()
		await runner.get_tree().process_frame

func test_walking_diagram_builds_and_does_not_change_travel_or_save() -> void:
	var rides := GameState.stat("metro_rides")
	var map := CityMapModal.new(false)
	map.walking = true
	UIRoot.open_modal(map)
	await runner.get_tree().process_frame
	runner.check(map.find_child("WalkingConnections", true, false) != null, "diagram draws canonical links")
	for d in DataDB.city["districts"]: runner.check(map.find_child("District_" + str(d["id"]), true, false) != null, "every district is selectable")
	runner.eq(GameState.stat("metro_rides"), rides, "map inspection does not travel")
	runner.check(Ledger.check_balanced(), "read-only map does not book income")
	UIRoot.close_all()
