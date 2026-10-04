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


# ------------------------------------------------------------------ archiving (#98)
func _post_order_day(day: int, n: int) -> void:
	GameState.data["clock"]["minutes"] = day * Clock.DAY + 600
	for i in n:
		Ledger.post("player", "fixture", [{"acct": "marketplace_balance", "dr": 16.0}, {"acct": "revenue", "cr": 16.0},
			{"acct": "cogs", "dr": 5.0}, {"acct": "inventory", "cr": 5.0}], {"segment": "ecommerce", "type": "order", "id": "#%d_%d" % [day, i]})
	Ledger.post("player", "Lunch", [{"acct": "exp:dining", "dr": 9.0}, {"acct": "cash", "cr": 9.0}], {"segment": "shared", "type": "living"})


func _books() -> Dictionary:
	var now := Clock.now()
	return {"bal": GameState.data["ledger"]["balances"]["player"].duplicate(), "mv": _cents(Ledger.movements("player", 3 * Clock.DAY, 7 * Clock.DAY)),
		"mv2": _cents(Ledger.movements("player", 12 * Clock.DAY, 16 * Clock.DAY)), "at": Ledger.balance_at("player", "revenue", 10 * Clock.DAY),
		"cash_at": Ledger.balance_at("player", "cash", 14 * Clock.DAY), "seg": _cents(Segments.compute("player", 0, now + 1)["totals"]),
		"year": snappedf(MonthClose.compute("player", 0, now + 1)["net_revenue"], 0.01)}


func _cents(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[k] = snappedf(float(d[k]), 0.01)
	return out


func test_ledger_compaction_keeps_every_total() -> void:
	for day in range(1, 21):
		_post_order_day(day, 30)
	var before := _books()
	var size_before: int = GameState.data["ledger"]["journal"].size()
	var seq: int = GameState.data["ledger"]["seq"]
	var removed := Ledger.compact_old(Clock.now(), 10, 5)
	runner.check(removed > 400, "old order entries folded (%d)" % removed)
	runner.eq(GameState.data["ledger"]["journal"].size(), size_before - removed, "journal shrank by what was removed")
	var after := _books()
	for key in before:
		runner.eq(JSON.stringify(after[key]), JSON.stringify(before[key]), "unchanged after compaction: " + key)
	runner.eq(GameState.data["ledger"]["seq"], seq, "sequence untouched")
	runner.check(Ledger.check_balanced(), "still balanced")
	runner.eq(Ledger.compact_old(Clock.now(), 10, 5), 0, "second pass finds nothing new")
	var lunches := 0
	for e in GameState.data["ledger"]["journal"]:
		if e["source"].get("type", "") == "living":
			lunches += 1
	runner.eq(lunches, 20, "low-volume entries are never folded")
	var recent := Ledger.entries("player", 5)
	runner.check(not recent[0]["source"].get("archived", false), "recent entries stay line by line")


func test_ledger_compaction_waits_for_real_volume() -> void:
	for day in range(1, 21):
		_post_order_day(day, 3)
	runner.eq(Ledger.compact_old(Clock.now()), 0, "ordinary play keeps every journal line")


func test_settled_orders_are_archived_into_monthly_totals() -> void:
	var now := 40 * Clock.DAY
	GameState.data["clock"]["minutes"] = now
	var orders: Dictionary = Ecommerce.E()["orders"]
	for i in 30:
		orders["#o%d" % i] = {"id": "#o%d" % i, "product": "phone_stand", "qty": 2, "unit_price": 16.0, "entity": "player", "status": "delivered",
			"placed": 5 * Clock.DAY, "delivered": 8 * Clock.DAY, "location": "riverside_studio"}
	orders["#recent"] = {"id": "#recent", "product": "phone_stand", "qty": 1, "unit_price": 16.0, "entity": "player", "status": "delivered",
		"placed": now - Clock.DAY, "delivered": now - 100, "location": "riverside_studio"}
	orders["#open"] = {"id": "#open", "product": "phone_stand", "qty": 1, "unit_price": 16.0, "entity": "player", "status": "shipped",
		"placed": 5 * Clock.DAY, "location": "riverside_studio"}
	orders["#abroad"] = {"id": "#abroad", "product": "phone_stand", "qty": 1, "unit_price": 16.0, "entity": "player", "status": "delivered", "region": "northridge",
		"placed": 5 * Clock.DAY, "delivered": 8 * Clock.DAY, "location": "riverside_studio"}
	orders["#late_review"] = {"id": "#late_review", "product": "phone_stand", "qty": 1, "unit_price": 16.0, "entity": "player", "status": "delivered",
		"placed": 5 * Clock.DAY, "delivered": 8 * Clock.DAY, "review": {"t": now - 100}, "location": "riverside_studio"}
	for id in ["#recent", "#late_review"]:   # a return or review still scheduled keeps its order on the books
		Sim.schedule(now + 60, "eco.review", {"order": id})
	runner.eq(Ecommerce.archive_settled(now, 100), 0, "below the volume threshold nothing is archived")
	runner.eq(Ecommerce.archive_settled(now, 10), 30, "only old settled home orders go")
	runner.check(orders.has("#recent") and orders.has("#open") and orders.has("#abroad") and orders.has("#late_review"), "recent, open, overseas and still-active orders stay")
	runner.eq(Ecommerce.foreign_orders().size(), 1, "overseas index intact")
	var total := 0
	for row in Ecommerce.E()["order_archive"].values():
		total += int(row["orders"])
		runner.eq(int(row["units"]), int(row["orders"]) * 2, "units kept in the monthly total")
	runner.eq(total, 30, "every archived order is counted once")
	runner.eq(Ecommerce.orders_with(["shipped"]).size(), 1, "open order index survives archiving")


func test_big_saves_are_gzip_and_the_active_company_is_written_once() -> void:
	Company.register("Perf Co", "llc", "riverside_studio")
	var orders: Dictionary = Ecommerce.E()["orders"]
	for i in 700:
		orders["#p%d" % i] = {"id": "#p%d" % i, "product": "phone_stand", "qty": 1, "unit_price": 16.0, "entity": GameState.company_id(),
			"status": "delivered", "placed": i, "delivered": i + 10, "customer": "Pat Perf", "location": "riverside_studio", "note": "x".repeat(300),
			"items": [{"product": "phone_stand", "qty": 1, "unit_price": 16.0}]}
	runner.check(SaveSystem.save(4, true), "saved")
	var bytes := FileAccess.get_file_as_bytes(SaveSystem._path(4))
	runner.check(bytes.size() > 2 and bytes[0] == 0x1f and bytes[1] == 0x8b, "large save is gzip")
	var text := SaveSystem.read_text(SaveSystem._path(4))
	var parsed: Dictionary = JSON.parse_string(text)
	runner.eq(text.count("Pat Perf"), 700, "the active company's orders are serialized once, not twice")
	runner.check(parsed["data"]["company_contexts"][GameState.company_id()].get("lean", false), "context view marked lean")
	var seq: int = GameState.data["ledger"]["seq"]
	runner.check(SaveSystem.load_data(4), "gzip save loads")
	runner.eq(GameState.data["ledger"]["seq"], seq, "state restored")
	runner.eq(Ecommerce.E()["orders"].size(), 700, "orders restored")
	var view: Dictionary = GameState.data["company_contexts"][GameState.company_id()]
	runner.check(not view.has("lean") and is_same(view["states"]["ecommerce"], GameState.data["ecommerce"]), "active view shares the live state again")
	runner.check(CompanyPortfolio.switch(GameState.company_id()).get("ok", false), "switching still works")
	runner.eq(Ecommerce.E()["orders"].size(), 700, "nothing reset by a switch")
	var plain := SaveSystem.read_text("res://tests/fixtures/saves/industry_intro.json")
	runner.check(plain.begins_with("{"), "plain JSON saves still read")
