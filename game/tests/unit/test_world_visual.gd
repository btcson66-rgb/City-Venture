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
