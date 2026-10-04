extends RefCounted
var runner


func test_employer_action_uses_the_same_entity_as_the_simulation() -> void:
	Company.register("Permit Test", "ecommerce", "22 Founders Lane")
	runner.eq(GameState.business_entity(), "player", "registered founder without business account uses personal books")
	var modal := PermitsModal.new()
	UIRoot.open_modal(modal)
	var button := modal.find_child("RegisterEmployer", true, false) as Button
	runner.check(button != null and not button.disabled, "affordable employer registration remains usable before opening account")
	modal.close()
	Ledger.expense("player", "living", Ledger.cash("player"), "Test cash boundary")
	modal = PermitsModal.new()
	UIRoot.open_modal(modal)
	button = modal.find_child("RegisterEmployer", true, false) as Button
	runner.check(button != null and button.disabled, "unaffordable employer registration stays secondary and disabled")
	modal.close()


func test_scenery_keeps_data_but_has_no_public_destination() -> void:
	var listed := []
	for g in BuildingInfo.guide_groups():
		listed.append_array(g["buildings"])
	for bid in ["popup_unit", "old_town_studio", "harbor_point_fitness", "customs_house"]:
		runner.check(not BuildingInfo.building_enterable(bid), bid + " is scenery")
		runner.check(not bid in listed, bid + " is absent from guide")
		runner.check(DataDB.building(bid).has("interior"), bid + " retains interior data")
		runner.check(not SceneRouter.building_open(bid)["open"], bid + " cannot be entered")


func test_status_activation_is_data_driven_and_explicit_switch_wins() -> void:
	DataDB.districts["beta_future"] = {"id": "beta_future", "name": "Future", "status": "planned"}
	DataDB.buildings["beta_future_shop"] = {"id": "beta_future_shop", "name": "Shop", "district": "beta_future", "status": "planned", "interior": {"interactables": [{"action": "buy_item", "label": "Buy"}]}}
	DataDB.districts["beta_future"]["status"] = "active"
	DataDB.buildings["beta_future_shop"]["status"] = "active"
	BuildingInfo.invalidate_availability()
	runner.check(BuildingInfo.building_available("beta_future_shop"), "status activation makes working shop available automatically")
	DataDB.buildings["beta_future_shop"]["enterable"] = false
	BuildingInfo.invalidate_availability()
	runner.check(not BuildingInfo.building_available("beta_future_shop"), "explicit nonenterable scenery stays hidden")
	DataDB.buildings.erase("beta_future_shop")
	DataDB.districts.erase("beta_future")


func test_old_hidden_room_save_returns_to_same_street_door() -> void:
	var old = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/contracts_before_closure_pre36.json"))
	GameState.data = SaveSystem._migrate(old["data"])
	GameState.data["player"]["location"] = {"kind": "interior", "id": "old_town_studio", "x": 30, "y": 50, "facing": "up"}
	var books: Dictionary = GameState.data["ledger"].duplicate(true)
	runner.check(SaveSystem.save(4) and SaveSystem.load_data(4), "old interior save round trips")
	var loc := BuildingInfo.safe_location(GameState.data["player"]["location"])
	runner.eq(loc["kind"], "district", "back outside")
	runner.eq(loc["id"], "old_town", "same district")
	runner.eq(loc["spawn"], "door_old_town_studio", "same facade's entrance")
	runner.eq(GameState.data["ledger"], books, "load/relocation does not change books")
	SceneRouter._enter("interior", "old_town_studio", "door", "up")
	runner.eq(SceneRouter.world_scene().kind, "district", "actual scene refuses closed room")
	runner.eq(SceneRouter.world_scene().player.global_position, SceneRouter.world_scene().spawns["door_old_town_studio"], "actual player is at door")
	runner.check(Ledger.check_balanced(), "old save remains balanced")


func test_npc_only_room_tracks_real_schedule_and_story_conditions() -> void:
	GameState.data["clock"]["minutes"] = Clock.at_day_time(6, 14 * 60)
	runner.check(not BuildingInfo.building_available("crestline_flagship"), "empty pre-contract room has no public entrance")
	GameState.set_flag("big_contract_offered")
	runner.check(BuildingInfo.building_available("crestline_flagship"), "scheduled Daniel restores entrance")
	runner.eq(BuildingInfo.guide_tags("crestline_flagship"), "Services", "scheduled negotiation is not advertised as sightseeing")
	GameState.data["clock"]["minutes"] = Clock.at_day_time(0, 19 * 60)
	runner.check(not BuildingInfo.building_available("crestline_flagship"), "entrance hides after Daniel leaves")
