extends RefCounted
var runner
const LOC := "riverside_studio"

func basket() -> Dictionary:
	return {"id": "M1", "product": "phone_stand", "qty": 2, "unit_price": 15.0, "items": [{"product": "phone_stand", "qty": 2, "unit_price": 15.0}, {"product": "desk_lamp", "qty": 1, "unit_price": 29.0}], "customer": "Alex", "listing": "", "location": LOC, "entity": "player", "status": "placed", "placed": Clock.now()}

func seed_order(o: Dictionary) -> void:
	for item in Packing.items(o):
		Ecommerce._add_stock(LOC, item["product"], int(item["qty"]) + 5, 5.0, 0.0)
		Ledger.post("player", "Packing fixture stock", [{"acct": "inventory", "dr": (int(item["qty"]) + 5) * 5.0}, {"acct": "cash", "cr": (int(item["qty"]) + 5) * 5.0}], {"segment": "ecommerce"})
	Ecommerce.E()["orders"][o["id"]] = o

func test_basket_checkout_refund_all_lines_and_ledger() -> void:
	var o := basket()
	seed_order(o)
	runner.eq(Packing.total(o), 59.0, "all quantities priced")
	runner.eq(Ecommerce.reserved(LOC, "phone_stand"), 2, "primary reservation")
	runner.eq(Ecommerce.reserved(LOC, "desk_lamp"), 1, "secondary reservation")
	runner.eq(Ecommerce.pack_orders(LOC), 1, "pack once")
	runner.eq(Ecommerce.stock(LOC, "phone_stand"), 5, "consume all units")
	runner.eq(Ecommerce.stock(LOC, "desk_lamp"), 5, "consume second SKU")
	o["status"] = "shipped"
	o["ship"] = {"method": "economy"}
	Ecommerce.handle("eco.deliver", {"order": o["id"]})
	runner.eq(-Ledger.balance("player", "revenue"), 59.0, "income only on delivery")
	o["defective"] = false
	o["status"] = "return_requested"
	runner.check(Ecommerce.resolve_return(o["id"], "refund")["ok"], "whole basket refunded")
	runner.eq(Ledger.balance("player", "refunds"), 59.0, "full basket refund")
	runner.eq(Ecommerce.stock(LOC, "phone_stand"), 7, "all first units returned")
	runner.eq(Ecommerce.stock(LOC, "desk_lamp"), 6, "second SKU returned")
	runner.eq(Ledger.balance("player", "cogs"), 0.0, "COGS reversed")
	runner.check(Ledger.check_balanced(), "balanced")

func test_failed_pack_and_replacement_are_atomic() -> void:
	var o := basket()
	seed_order(o)
	Ecommerce.inv(LOC)["desk_lamp"]["qty"] = 0
	var before := Ecommerce.stock(LOC, "phone_stand")
	runner.eq(Ecommerce.pack_orders(LOC), 0, "missing secondary item blocked")
	runner.eq(Ecommerce.stock(LOC, "phone_stand"), before, "first stock untouched")
	o["status"] = "return_requested"
	runner.check(not Ecommerce.resolve_return(o["id"], "replace")["ok"], "replacement blocked")
	runner.eq(Ecommerce.stock(LOC, "phone_stand"), before, "replacement atomic")

func test_rotation_overlap_bounds_and_small_box() -> void:
	var o := basket()
	runner.eq(Packing.smallest(o), "medium", "lamp height requires medium")
	runner.check(Packing.plan(o, "small").is_empty(), "small rejects tall lamp")
	var plan := Packing.plan(o, "medium")
	runner.check(Packing.placement_ok(o, "medium", plan), "multi item grid fits")
	plan[1]["x"] = plan[0]["x"]
	plan[1]["y"] = plan[0]["y"]
	runner.check(not Packing.placement_ok(o, "medium", plan), "overlap blocked")
	var old: Array = DataDB.products["phone_stand"]["size"]
	DataDB.products["phone_stand"]["size"] = [1, 4, 1]
	var single := {"product": "phone_stand", "qty": 1}
	runner.check(not Packing.placement_ok(single, "small", [{"item": 0, "x": 0, "y": 0, "rotated": false}]), "unrotated outside grid")
	runner.check(Packing.placement_ok(single, "small", [{"item": 0, "x": 0, "y": 0, "rotated": true}]), "rotated fits")
	DataDB.products["phone_stand"]["size"] = old

func test_large_box_dimensions_weight_and_padding_risk() -> void:
	var bulky := {"product": "desk_monitor", "qty": 1, "unit_price": 150.0}
	runner.eq(Packing.smallest(bulky), "large", "monitor needs large")
	var light := {"product": "phone_stand", "qty": 1}
	runner.check(Packing.postage(light, "large", "economy") > Packing.postage(light, "small", "economy"), "dimensional weight costs more")
	var old := float(DataDB.products["phone_stand"]["weight"])
	DataDB.products["phone_stand"]["weight"] = 10.0
	runner.check(Packing.postage(light, "small", "economy") > Packing.postage(bulky, "large", "economy"), "actual weight controls charge")
	DataDB.products["phone_stand"]["weight"] = old
	runner.check(Packing.damage(bulky, 0.0) > Packing.damage(bulky, 0.3), "padding lowers damage")
	runner.eq(Packing.damage(bulky, 0.6), 0.0, "safe padding")
	runner.eq(Packing.damage(light, 0.0), 0.0, "not fragile")

func test_skill_controls_cost_and_damage() -> void:
	var o := basket()
	var low := Packing.auto_pack(o, 1)
	var high := Packing.auto_pack(o, 5)
	runner.eq(low["box"], "large", "novice oversizes")
	runner.eq(high["box"], "medium", "skilled chooses fitting box")
	runner.check(Packing.material(o, low["box"], low["padding"]) + Packing.postage(o, low["box"], "economy") > Packing.material(o, high["box"], high["padding"]) + Packing.postage(o, high["box"], "economy"), "novice wastes materials/postage")
	runner.check(Packing.damage(o, low["padding"]) > Packing.damage(o, high["padding"]), "skill reduces damage")

func test_generated_baskets_use_available_stock_and_combo_config() -> void:
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	Ecommerce._add_stock(LOC, "phone_stand", 20, 5.0, 0.0)
	Ecommerce._add_stock(LOC, "desk_lamp", 20, 10.0, 0.0)
	var first := Ecommerce.create_listing("phone_stand", 15.0, "self")
	Ecommerce.create_listing("desk_lamp", 29.0, "self")
	var saved := Packing.cfg().duplicate(true)
	DataDB.economy["ecommerce"]["basket_chance"] = 1.0
	DataDB.economy["ecommerce"]["quantity_chance"] = 1.0
	Ecommerce.handle("eco.order_place", {"listing": first["listing_id"]})
	DataDB.economy["ecommerce"] = saved
	var o: Dictionary = Ecommerce.E()["orders"].values().back()
	runner.eq(o["items"].size(), 2, "actual demand creates configured combo")
	runner.check(o["qty"] >= 2, "multiple quantity")
	runner.eq(o["total"], Packing.total(o), "basket total stored")
	runner.check(Ecommerce.available(LOC, "desk_lamp") >= 0, "secondary reserved without oversell")

func test_old_order_save_and_new_placement_roundtrip() -> void:
	var old := {"id": "OLD", "product": "water_bottle", "qty": 2, "unit_price": 19.0, "entity": "player", "status": "placed", "location": LOC}
	seed_order(old)
	runner.eq(Packing.total(old), 38.0, "legacy total")
	runner.eq(Ecommerce.pack_orders(LOC), 1, "legacy packs")
	GameState.data = SaveSystem._migrate(JSON.parse_string(JSON.stringify(GameState.data)))
	var saved: Dictionary = Ecommerce.E()["orders"]["OLD"]
	runner.check(Packing.placement_ok(saved, saved["pack"]["box"], saved["pack"]["placements"]), "placements survive save")
	runner.check(Ledger.check_balanced(), "legacy balanced")

func test_closed_company_cannot_pack() -> void:
	var o := basket()
	seed_order(o)
	GameState.data["entities"]["player"]["closed"] = Clock.now()
	runner.eq(Ecommerce.pack_orders(LOC), 0, "closed entity cannot consume stock or pay materials")

func test_invalid_quantities_duplicate_stock_and_negative_padding() -> void:
	var o := basket()
	seed_order(o)
	o["items"][0]["qty"] = 0
	runner.check(not Ecommerce.can_pack(o, LOC), "zero quantity rejected")
	o["items"][0]["qty"] = 5
	o["items"].append({"product": "phone_stand", "qty": 5, "unit_price": 15.0})
	runner.check(not Ecommerce.can_pack(o, LOC), "duplicate quantities aggregated")
	o["items"].pop_back()
	o["items"][0]["qty"] = 2
	var policy := Packing.auto_pack(o)
	policy["padding"] = -1.0
	var before := Ledger.cash("player")
	runner.eq(Ecommerce.pack_orders(LOC, -1, {o["id"]: policy}), 0, "negative material input rejected")
	runner.eq(Ledger.cash("player"), before, "no negative material credit")
