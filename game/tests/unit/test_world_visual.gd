extends RefCounted
var runner
func test_industry_desks_follow_gates_and_preserve_started_businesses() -> void:
	GameState.set_flag("debug_feature_gates_all", false)
	GameState.data["feature_gates"] = {"granted":[],"seen":[],"guided":[]}
	GameState.data["story"]["chapter"] = "ch1_arrival"
	for entry in Industries.all():
		for action in entry.get("actions", {}):
			var gate := "os_" + str(entry["id"])
			if FeatureGate.definition(gate).is_empty(): continue
			runner.eq(BuildingInfo.action_visible(action), entry["sim_class"].is_running() or FeatureGate.unlocked(gate), "world desk matches gate: " + action)
	runner.check(not BuildingInfo.action_visible("energy_open"), "new player cannot open a useless energy desk")
	FeatureGate.grant("os_energy")
	runner.check(BuildingInfo.action_visible("energy_open"), "eligible player can reach startup prerequisites")
	GameState.data["energy"] = {"active":true}
	GameState.data["feature_gates"]["granted"] = []
	runner.check(BuildingInfo.action_visible("energy_open"), "old operating energy save retains access")
	runner.check(BuildingInfo.action_visible("lease_property"), "leasing remains reachable before business startup")
	runner.check(Ledger.check_balanced(), "presentation gates do not move money")
func test_exit_arrow_and_name_are_bounded_in_all_directions() -> void:
	for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		var marker := ExitMarker.new()
		marker.setup(Rect2(500,324,16,48),direction,"Shopping Street")
		UIRoot.get_tree().root.add_child(marker)
		await runner.get_tree().process_frame
		runner.check(marker.board.encloses(Rect2(marker._label.position,marker._label.size)), "translated label stays on sign: %s %s %s" % [marker.board,marker._label.position,marker._label.size])
		marker.free()
func test_all_street_sign_boards_have_separate_slots() -> void:
	for id in DataDB.districts:
		var district := District.new()
		district.build(id)
		var boards: Array[Rect2] = []
		for area in district.get_children():
			if not area is ExitArea: continue
			for marker in area.get_children():
				if not marker is ExitMarker: continue
				for previous in boards: runner.check(not marker.board.intersects(previous), "distinct destination signs do not overlap: " + id)
				boards.append(marker.board)
		district.free()

func test_ns_exit_signs_stay_on_pavement_and_inside_the_district() -> void:
	for id in DataDB.districts:
		var def: Dictionary = DataDB.districts[id]
		var size_px := Vector2(float(def["size_tiles"][0]), float(def["size_tiles"][1])) * 16.0
		var bands: Array[Rect2] = []
		for g in def.get("ground", []):
			if str(g.get("type", "")) in ["road", "asphalt"]:
				bands.append(Rect2(float(g["rect"][0]) * 16.0, float(g["rect"][1]) * 16.0, float(g["rect"][2]) * 16.0, float(g["rect"][3]) * 16.0))
		for side in ["N", "S"]:
			var peers: Array = def.get("exits", []).filter(func(e): return e.get("direction", "") == side)
			for exit in peers:
				var r: Array = exit["rect"]
				var marker := ExitMarker.new()
				marker.setup(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), Vector2.DOWN if side == "S" else Vector2.UP, I18n.t(str(DataDB.districts.get(exit["to"], {}).get("name", exit["to"]))))
				var shift := ExitArea.sign_shift(side, peers.find(exit), marker.board, size_px)
				var board := Rect2(marker.board.position + shift, marker.board.size)
				var sign_rect := board.merge(Rect2(board.get_center().x - 1.0, board.end.y, 2.0, 14.0))
				runner.check(Rect2(Vector2.ZERO, size_px).encloses(sign_rect), "sign inside district bounds: %s -> %s" % [id, exit["to"]])
				for band in bands:
					runner.check(not band.intersects(sign_rect), "%s sign for %s stays off the road" % [side, exit["to"]] + " in " + str(id))
				marker.free()

func test_action_visibility_cache_follows_chapter_and_grants() -> void:
	GameState.set_flag("debug_feature_gates_all", false)
	GameState.data["feature_gates"] = {"granted":[],"seen":[],"guided":[]}
	GameState.data["story"]["chapter"] = "ch1_arrival"
	BuildingInfo.invalidate_availability()
	runner.check(not BuildingInfo.action_visible("energy_open"), "locked desk hidden")
	runner.check(not BuildingInfo.action_visible("energy_open"), "cached answer is stable")
	FeatureGate.grant("os_energy")
	runner.check(BuildingInfo.action_visible("energy_open"), "grant invalidates the cache at once")
