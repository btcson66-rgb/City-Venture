extends RefCounted
## Company, contracts, events, solvency, story, save/load, product rules.

var runner


func _advance_until(pred: Callable, max_hours := 24 * 10) -> bool:
	for i in max_hours:
		if pred.call():
			return true
		Clock.advance(60)
	return pred.call()


func _deep_eq(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return absf(float(a) - float(b)) < 0.0001
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _deep_eq(a[k], b[k]):
				return false
		return true
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _deep_eq(a[i], b[i]):
				return false
		return true
	return a == b


func _register_and_bank(capital := 10000.0) -> String:
	var r := Company.register("Horizon Goods", "retail_online", "Riverside Tower 7C")
	runner.check(r["ok"], "register: " + str(r))
	var b := Company.open_business_account(capital)
	runner.check(b["ok"], "bank: " + str(b))
	return GameState.company_id()


func test_registration_creates_company_and_moves_books() -> void:
	Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)
	_advance_until(func(): return Ecommerce.stock("riverside_studio", "water_bottle") >= 60)
	var cid := _register_and_bank(8000.0)
	runner.eq(GameState.business_entity(), cid, "business now runs on company books")
	runner.eq(Ledger.cash(cid), 8000.0, "company capital")
	runner.eq(Ledger.balance(cid, "inventory"), 60 * 6.8, "inventory moved in kind")
	runner.eq(Ledger.balance("player", "inventory"), 0.0, "personal inventory cleared")
	runner.eq(Ledger.cash("player"), 30000.0 - 408.0 - 300.0 - 8000.0 - Ledger.balance("player", "exp:living"), "personal cash after purchase, fee, capital, living")
	runner.check(GameState.business_display_name() == "Horizon Goods", "company name everywhere")
	runner.check(Ledger.check_balanced(), "balanced")
	var tl: Array = GameState.data["timeline"]
	runner.check(tl.any(func(e): return str(e["text"]).contains("Founded Horizon Goods")), "timeline entry")


func test_invalid_company_names() -> void:
	runner.check(Company.validate_name("ab") != "", "too short")
	runner.check(Company.validate_name("Harbor Point Fitness") != "", "existing name")
	runner.check(Company.validate_name("Riverlight Supply") == "", "ok name")


func test_contract_counter_deliver_and_net30() -> void:
	var cid := _register_and_bank(10000.0)
	Ecommerce.buy("tradelink_wholesale", "water_bottle", 180)
	_advance_until(func(): return Ecommerce.stock("riverside_studio", "water_bottle") >= 180)
	var k := Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 120, "unit_price": 21.0,
		"delivery_days": 7, "payment_terms_days": 30})
	runner.eq(GameState.data["contracts"][k]["buyer"], "harbor_point_fitness", "buyer is an entity id")
	var c := Contracts.counter(k, 30.0, 15, 0.5)
	runner.check(c["result"] in ["countered", "withdrawn"], "greedy counter is not accepted outright")
	if c["result"] == "withdrawn":
		return
	var c2 := Contracts.counter(k, 21.5, 30, 0.3)
	runner.eq(c2["result"], "agreed", "reasonable counter agreed")
	var a := Contracts.accept(k)
	runner.check(a["ok"], "accepted")
	var cash_after_accept := Ledger.cash(cid)
	runner.check(cash_after_accept > 10000.0 - 1224.0, "deposit received upfront")
	var d := Contracts.deliver(k)
	runner.check(d["ok"], "delivered")
	runner.check(Ledger.balance(cid, "accounts_receivable") > 1000.0, "invoice sits in AR")
	var rev := -Ledger.balance(cid, "revenue")
	runner.check(absf(rev-(120*21.5-Tax.vat(120*21.5)))<.011, "net revenue booked on delivery; VAT remains payable")
	_advance_until(func(): return GameState.data["contracts"][k]["status"] == "paid", 24 * 32)
	runner.eq(GameState.data["contracts"][k]["status"], "paid", "paid at Net 30")
	runner.eq(Ledger.balance(cid, "accounts_receivable"), 0.0, "AR cleared")
	runner.check(Ledger.check_balanced(), "balanced")


func test_contract_needs_registered_company() -> void:
	var k := Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 120, "unit_price": 21.0})
	var a := Contracts.accept(k)
	runner.check(not a["ok"], "personal seller cannot sign B2B")


func test_supplier_price_increase_event() -> void:
	Ecommerce.buy("tradelink_wholesale", "wireless_earbuds", 50)
	_advance_until(func(): return Ecommerce.stock("riverside_studio", "wireless_earbuds") >= 50)
	Ecommerce.create_listing("wireless_earbuds", 39.0, "self")
	var ctx := EventEngine.bind(DataDB.events["supplier_price_increase"])
	runner.eq(ctx.get("supplier_id", ""), "tradelink_wholesale", "binds most-used supplier")
	var inst := EventEngine.trigger("supplier_price_increase", ctx)
	var pos0: int = GameState.data["ecommerce"]["purchase_orders"].size()
	var r := EventEngine.choose(inst["iid"], "stock_up")
	runner.check(r["ok"], "stock up ok")
	runner.eq(GameState.data["ecommerce"]["purchase_orders"].size(), pos0 + 1, "purchase made at today's price")
	runner.eq(Ecommerce.unit_cost("tradelink_wholesale", "wireless_earbuds"), 18.0, "old price today")
	Clock.advance(Clock.DAY + 10)
	runner.eq(Ecommerce.unit_cost("tradelink_wholesale", "wireless_earbuds"), 20.7, "+15% from tomorrow")


func test_every_event_changes_something() -> void:
	runner.check(DataDB.validate().filter(func(e): return str(e).begins_with("event")).is_empty(), "no pure-dialogue events")


func test_low_cash_warning_is_not_game_over() -> void:
	Ecommerce.buy("tradelink_wholesale", "wireless_earbuds", 50)
	_advance_until(func(): return Ecommerce.stock("riverside_studio", "wireless_earbuds") >= 50)
	Ledger.expense("player", "other", Ledger.cash("player") - 300.0, "Test: drain cash")
	Clock.advance(60 * 3)
	var q := EventEngine.pending().filter(func(x): return x["id"] == "low_cash_warning")
	runner.eq(q.size(), 1, "warning raised")
	var r := EventEngine.choose(q[0]["iid"], "liquidate")
	runner.check(r["ok"], "liquidation ok")
	runner.eq(Ledger.cash("player"), 300.0 + 50 * 18.0 * 0.4, "cash raised at 40% of cost")
	runner.eq(Ecommerce.total_units(), 0, "stock gone")
	# overdraft continues the game with fees instead of ending it
	Ledger.expense("player", "other", 1000.0, "Test: overspend")
	var fees0 := Ledger.balance("player", "exp:bank_fees")
	_advance_until(func(): return Ledger.balance("player", "exp:bank_fees") > fees0, 30)
	runner.check(Ledger.balance("player", "exp:bank_fees") > fees0, "overdraft fee charged, game continues")


func test_reduce_spending_option() -> void:
	var inst := EventEngine.trigger("low_cash_warning", {"entity": "player", "entity_name": "You", "cash": "$1", "upcoming": "$0"})
	EventEngine.choose(inst["iid"], "reduce")
	runner.eq(Living.daily_living(), 18.0, "cheaper living")


func test_story_chapter_one_progression() -> void:
	StoryEngine.start_chapter("ch1_arrival")
	runner.eq(StoryEngine.main_objective().get("id", ""), "ch1_phone", "starts at phone")
	GameState.set_flag("maya_intro_done")
	StoryEngine.check()
	runner.eq(StoryEngine.main_objective().get("id", ""), "ch1_outside", "next: go outside")
	GameState.mark_visited("riverside")
	StoryEngine.check()
	GameState.set_flag("bought_coffee_bloom_coffee")
	StoryEngine.check()
	GameState.mark_visited("nexus_cowork")
	StoryEngine.check()
	GameState.set_flag("business_chosen")
	StoryEngine.check()
	runner.check("ch1_arrival" in GameState.data["story"]["chapters_done"], "chapter 1 complete")
	runner.eq(GameState.data["story"]["chapter"], "ch2_first_customer", "chapter 2 started")
	runner.eq(StoryEngine.main_objective().get("id", ""), "ch2_supplier", "first Ch2 objective")


func test_save_load_round_trip() -> void:
	Ecommerce.buy("tradelink_wholesale", "desk_lamp", 40)
	Clock.advance(60 * 30)
	Ecommerce.create_listing("desk_lamp", 27.0, "studio")
	Clock.advance(60 * 20)
	GameState.data["player"]["location"] = {"kind": "district", "id": "riverside", "x": 512.0, "y": 360.0, "facing": "left"}
	var cash := Ledger.cash("player")
	var t := Clock.now()
	runner.check(SaveSystem.save(3), "saved")
	var before := JSON.stringify(GameState.data)
	GameState.new_game({"name": "Someone Else", "seed": 1})
	runner.check(SaveSystem.load_data(3), "loaded")
	runner.eq(Clock.now(), t, "time restored")
	runner.eq(Ledger.cash("player"), cash, "cash restored")
	runner.eq(GameState.data["player"]["name"], "Test Founder", "character restored")
	runner.eq(GameState.data["player"]["location"]["id"], "riverside", "position restored")
	runner.eq(GameState.data["player"]["appearance"]["hair"], GameState.default_appearance()["hair"], "appearance restored")
	runner.eq(SaveSystem.current_slot(), 3, "a loaded game keeps saving to the slot it came from")
	var expect: Dictionary = JSON.parse_string(before)
	expect["meta"]["slot"] = 3
	runner.check(_deep_eq(expect, GameState.data), "state identical after round trip")
	# the simulation keeps running after a load
	Clock.advance(60 * 48)
	runner.check(Ledger.check_balanced(), "balanced after continuing")


func test_character_options_are_cosmetic_only() -> void:
	var errs := DataDB.validate().filter(func(e): return str(e).contains("forbidden gameplay key"))
	runner.check(errs.is_empty(), "no gameplay keys on character options")
	var p: Dictionary = GameState.data["player"]
	for k in p.keys():
		runner.check(not k in ["stats", "skills", "attributes", "bonus"], "player has no stat block: " + k)


func test_crypto_not_available_in_year_one() -> void:
	# the story rule: crypto never appears before the Year 5 Clearing Crisis
	for m in DataDB.economy["settlement_methods"]["methods"]:
		if str(m["id"]).begins_with("stablecoin"):
			runner.check(int(m.get("from_year", 99)) >= 5, "the stablecoin rail belongs to Year 5 or later")
			runner.check(not Ecommerce.settlement_open(str(m["id"])), "and is not on offer in year 1")
	runner.check(not World.cross_border_delay(), "no clearing crisis in year 1")


func test_a_new_game_never_overwrites_another_save() -> void:
	var first := SaveSystem.current_slot()
	runner.check(first in SaveSystem.GAME_SLOTS, "a new game gets a game slot (%d)" % first)
	runner.check(SaveSystem.save(first), "first game saved")
	var name1 := str(GameState.data["player"]["name"])
	GameState.new_game({"name": "Second Founder", "seed": 2})
	var second := SaveSystem.current_slot()
	runner.check(second != first, "the second game gets its own slot (%d vs %d)" % [second, first])
	runner.check(SaveSystem.save(second), "second game saved")
	runner.eq(str(SaveSystem.summary(first).get("name", "")), name1, "the first game is still there")
	runner.check(SaveSystem.save_list().size() >= 2, "both games are listed")
	# replacing a save keeps a backup copy
	SaveSystem.next_slot = first
	GameState.new_game({"name": "Third Founder", "seed": 3})
	runner.eq(SaveSystem.current_slot(), first, "the chosen slot is reused")
	runner.eq(str(SaveSystem.summary(first).get("name", "")), name1, "old primary remains until new save is fully written")
	runner.check(DirAccess.get_files_at(SaveSystem.DIR + "/replaced").size() >= 1, "and into saves/replaced/")
	runner.check(SaveSystem.save(first), "replacement written atomically")
	runner.eq(str(SaveSystem.summary(first).get("name", "")), "Third Founder", "chosen slot now contains completed new save")
	for s in [first, second]:
		DirAccess.remove_absolute(SaveSystem._path(s))
