extends RefCounted
var runner


func test_every_data_action_has_existing_icon() -> void:
	for bid in DataDB.buildings:
		for it in DataDB.buildings[bid].get("interior", {}).get("interactables", []):
			var icon := BuildingInfo.icon_for(str(it["action"]), it.get("params", {}))
			runner.check(icon != "" and Art.has_tex("ui/icons/" + icon), bid + ": " + str(it["action"]) + " has existing art")
	runner.eq(BuildingInfo.icon_for("unknown_action"), "", "unmapped future actions fail coverage")
	runner.eq(BuildingInfo.icon_for("buy_item", {"item": "coffee"}), "coffee", "coffee purchase uses coffee")


func test_every_building_has_summary_and_look_only_is_explicit() -> void:
	for bid in DataDB.buildings:
		var actionable := false
		for it in DataDB.buildings[bid].get("interior", {}).get("interactables", []):
			if str(it["action"]) != "look":
				actionable = true
		runner.check(BuildingInfo.welcome(bid) != "", bid + " produces introduction")
		runner.eq(BuildingInfo.welcome(bid).contains("sightseeing-only"), not actionable, bid + " accurately distinguishes sightseeing")
		runner.check(DataDB.buildings[bid].has("category"), bid + " has category")


func test_live_summary_includes_only_enabled_actions_and_present_npcs() -> void:
	var scene := WorldScene.new()
	scene.kind = "interior"
	scene.scene_id = "harbor_point_fitness"
	runner.get_tree().root.add_child(scene)
	scene.add_interactable(Vector2.ZERO, "Notice", "look")
	runner.check(BuildingInfo.welcome(scene.scene_id, scene).contains("sightseeing-only"), "only look is sightseeing")
	var talk := scene.add_interactable(Vector2.ZERO, "Talk to Nina", "talk", {"npc": "nina"})
	runner.check(BuildingInfo.welcome(scene.scene_id, scene).contains("Talk to Nina"), "present NPC creates activity")
	talk.enabled = false
	runner.check(BuildingInfo.welcome(scene.scene_id, scene).contains("sightseeing-only"), "disabled point never advertised")
	scene.free()


func test_guide_covers_current_and_future_active_data() -> void:
	var listed := []
	for g in BuildingInfo.guide_groups():
		listed.append_array(g["buildings"])
	for bid in DataDB.buildings:
		var b: Dictionary = DataDB.buildings[bid]
		if BuildingInfo.district_open(str(b["district"])):
			runner.check(bid in listed, "guide covers " + bid)
	DataDB.districts["future_test"] = {"id": "future_test", "name": "Future test", "status": "planned"}
	DataDB.buildings["future_shop_test"] = {"id": "future_shop_test", "name": "Future shop", "district": "future_test", "category": "Restaurant", "interior": {"interactables": [{"action": "buy_item", "label": "Order", "params": {"item": "meal"}}]}}
	var group: Dictionary = BuildingInfo.guide_groups().filter(func(g): return g["id"] == "future_test")[0]
	runner.check(not group["open"] and group["buildings"].is_empty(), "future district is unavailable")
	DataDB.districts["future_test"]["status"] = "active"
	group = BuildingInfo.guide_groups().filter(func(g): return g["id"] == "future_test")[0]
	runner.eq(group["buildings"], ["future_shop_test"], "status activation automatically adds future building")
	DataDB.buildings["future_shop_test"]["enterable"] = false
	group = BuildingInfo.guide_groups().filter(func(g): return g["id"] == "future_test")[0]
	runner.check(group["buildings"].is_empty(), "nonenterable scenery is excluded")
	DataDB.buildings.erase("future_shop_test")
	DataDB.districts.erase("future_test")


func test_old_save_counts_added_lazily_and_round_trip() -> void:
	var old = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/contracts_before_closure_pre36.json"))
	GameState.data = SaveSystem._migrate(old["data"])
	runner.check(not GameState.data.has("building_visits"), "older save is unchanged until entry")
	runner.eq(BuildingInfo.record_entry("lantern_bistro"), 1, "first entry")
	runner.eq(BuildingInfo.record_entry("lantern_bistro"), 2, "second entry")
	runner.eq(BuildingInfo.record_entry("lantern_bistro"), 3, "later visits do not trigger automatic card")
	runner.check(SaveSystem.save(3), "save succeeds")
	GameState.data.erase("building_visits")
	runner.check(SaveSystem.load_data(3), "load succeeds")
	runner.eq(int(GameState.data["building_visits"]["lantern_bistro"]), 3, "visit counts persist")
	runner.check(Ledger.check_balanced(), "migration and counts preserve ledger")


func test_meal_purchase_uses_dining_and_item_name() -> void:
	var params: Dictionary = DataDB.building("lantern_bistro")["interior"]["interactables"][0]["params"].duplicate()
	params["building"] = "lantern_bistro"
	var notices: Array[String] = []
	var receive := func(t: String, _k: String): notices.append(t)
	UIRoot.toasted.connect(receive)
	var cash := Ledger.cash("player")
	Actions.run("buy_item", params)
	UIRoot.toasted.disconnect(receive)
	runner.eq(Ledger.cash("player"), cash - 22, "real purchase charged")
	runner.eq(Ledger.balance("player", "exp:dining"), 22.0, "dining category from data")
	runner.eq(Ledger.balance("player", "exp:coffee"), 0.0, "meal is not coffee")
	runner.check("House special — $22" in notices, "toast names meal and unit")
	runner.check(Ledger.check_balanced(), "purchase balanced")
