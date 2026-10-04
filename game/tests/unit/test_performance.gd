extends RefCounted
## Reservation index must preserve stock/contract accounting across old saves.

var runner


func _setup_listing() -> Dictionary:
	# Reservations are counted per unit; these fixtures need one-unit orders, not random baskets (#113).
	# The guided first venture only generates one-unit orders.
	GameState.data["tutorial"] = {"v": Tutorial.VERSION, "off": false, "step": 0, "seen": {}}
	Ecommerce._add_stock("riverside_studio", "phone_stand", 100, 5.0, 0.0)
	Ledger.post("player", "Fixture stock", [{"acct": "inventory", "dr": 500.0}, {"acct": "equity", "cr": 500.0}])
	var result := Ecommerce.create_listing("phone_stand", 16.0, "self")
	runner.check(result.get("ok", false), "listing created")
	return Ecommerce.E()["listings"][result["listing_id"]]


func test_order_reservations_release_only_when_packed() -> void:
	var listing := _setup_listing()
	Ecommerce.reserved("riverside_studio", "phone_stand")
	for i in 7:
		Ecommerce._h_order_place({"listing": listing["id"]})
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 7, "all placed units reserved")
	runner.eq(Ecommerce.pack_orders("riverside_studio", 3), 3, "partial packing")
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 4, "remaining reservations")
	runner.eq(Ecommerce.available("riverside_studio", "phone_stand"), 93, "packing cannot expose oversold stock")
	Ecommerce.pack_orders("riverside_studio")
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 0, "all packed")
	runner.check(Ledger.check_balanced(), "pack ledger balanced")


func test_active_contracts_are_read_live() -> void:
	_setup_listing()
	Ecommerce.reserved("riverside_studio", "phone_stand")
	GameState.data["contracts"]["fixture"] = {"status": "active", "location": "riverside_studio", "product": "phone_stand", "qty": 20}
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 20, "new contract reservation")
	GameState.data["contracts"]["fixture"]["status"] = "closed"
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 0, "closed contract releases stock")


func test_new_and_loaded_saves_rebuild_derived_index() -> void:
	var listing := _setup_listing()
	Ecommerce._h_order_place({"listing": listing["id"]})
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 1, "one placed before save")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.data))
	GameState.data = SaveSystem._migrate(saved)
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 1, "old JSON save rebuilds, no index required")
	GameState.new_game({"name": "Other", "seed": 123})
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 0, "no reservation leaks to a new game")


func test_fixture_insert_and_explicit_invalidation() -> void:
	_setup_listing()
	Ecommerce.reserved("riverside_studio", "phone_stand")
	Ecommerce.E()["orders"]["fixture"] = {"status": "placed", "location": "riverside_studio", "product": "phone_stand", "qty": 10}
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 10, "external insertion detected")
	Ecommerce.E()["orders"]["fixture"]["status"] = "packed"
	Ecommerce.invalidate_reservations()
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 0, "bulk mutation invalidation")


func test_location_product_boundaries_and_no_overselling() -> void:
	var listing := _setup_listing()
	for i in 105:
		Ecommerce._h_order_place({"listing": listing["id"]})
	runner.eq(Ecommerce.E()["orders"].size(), 100, "stock cannot be oversold")
	runner.eq(Ecommerce.reserved("pier7_warehouse", "phone_stand"), 0, "other location distinct")
	runner.eq(Ecommerce.reserved("riverside_studio", "wireless_earbuds"), 0, "other product distinct")
	runner.eq(Ecommerce.pack_orders("riverside_studio", 0), 0, "zero packing limit")
	runner.eq(Ecommerce.reserved("riverside_studio", "phone_stand"), 100, "zero packing preserves reservations")


func test_stress_output_cannot_claim_player_slots() -> void:
	var stress_script: GDScript = load("res://tests/walkthrough/stress.gd")
	runner.check(not stress_script.safe_output_directory("user://"), "player data root rejected")
	runner.check(not stress_script.safe_output_directory("user://saves"), "player saves rejected")
	runner.check(not stress_script.safe_output_directory("user://saves/qa"), "nested player saves rejected")
	runner.check(not stress_script.safe_output_directory("user://qa/.."), "traversal to player root rejected")
	runner.check(not stress_script.safe_output_directory(""), "empty output rejected")
	runner.check(stress_script.safe_output_directory("user://stress"), "isolated QA output allowed")
