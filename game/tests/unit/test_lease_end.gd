extends RefCounted
var runner


func _company() -> String:
	Company.register("Lease Tests", "ecommerce", "22 Founders Lane")
	var ent := GameState.company_id()
	Ledger.post(ent, "Test capital", [{"acct": "cash", "dr": 2000000.0}, {"acct": "equity", "cr": 2000000.0}])
	GameState.set_flag("business_account_opened")
	return ent


func test_each_rentable_property_can_end_without_duplicate_deposit() -> void:
	var ent := _company()
	for pid in DataDB.properties:
		var prop: Dictionary = DataDB.properties[pid]
		if not prop.has("monthly_rent") or prop.get("kind", "") in ["home", "investment_home", "land"]: continue
		var sign := Living.lease(pid)
		runner.check(sign["ok"], "rent " + pid)
		if not sign["ok"]: continue
		var before := Ledger.cash(ent)
		var q := LeaseEnd.quote(pid, "immediate")
		runner.check(q["ok"], "quote " + pid)
		var result := Living.end_lease(pid, "immediate")
		runner.check(result["ok"], "end " + pid)
		runner.check(not Living.has_lease(pid), "removed " + pid)
		runner.eq(Ledger.cash(ent) - before, float(q["refund"]) - float(q["notice_rent"]) - float(q["early_fee"]), "cash matches " + pid)
		runner.check(not Living.end_lease(pid, "immediate")["ok"], "no repeat refund " + pid)
	runner.check(Ledger.check_balanced(), "all kinds balance")


func test_notice_survives_round_trip_and_settles_once() -> void:
	_company()
	Living.lease("suite_2b")
	var result := Living.end_lease("suite_2b", "notice")
	runner.check(result["ok"] and Living.has_lease("suite_2b"), "notice keeps access")
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.data))
	GameState.data = SaveSystem._migrate(data)
	runner.eq(Living.D()["leases"]["suite_2b"]["ending"]["due"], result["due"], "notice date survives")
	GameState.data["clock"]["minutes"] = int(result["due"])
	LeaseEnd.on_hour()
	runner.check(not Living.has_lease("suite_2b"), "ends at due date")
	var cash := Ledger.cash(GameState.company_id())
	LeaseEnd.on_hour()
	runner.eq(Ledger.cash(GameState.company_id()), cash, "second sweep has no effect")
	runner.check(Ledger.check_balanced(), "notice books balanced")


func test_data_terms_damage_and_early_exit() -> void:
	_company()
	Living.lease("suite_2b")
	var prop: Dictionary = DataDB.properties["suite_2b"]
	var old := prop.duplicate(true)
	prop["notice_days"] = 15
	prop["min_term_months"] = 6
	prop["early_exit_fee_months"] = 2
	Living.D()["leases"]["suite_2b"]["damage"] = 120.0
	var q := LeaseEnd.quote("suite_2b", "immediate")
	runner.eq(q["notice_rent"], 800.0, "15-day notice pro rata")
	runner.eq(q["early_fee"], 3200.0, "two-month early fee")
	runner.eq(q["refund"], 1480.0, "damage deducted from deposit")
	runner.check(Living.end_lease("suite_2b", "immediate")["ok"], "fees paid")
	DataDB.properties["suite_2b"] = old
	runner.check(Ledger.check_balanced(), "fees/damage balances")


func test_reserved_stock_must_follow_the_order() -> void:
	var ent := _company()
	Living.lease("suite_2b")
	Ecommerce._add_stock("suite_2b", "phone_stand", 10, 2.0, 0.0)
	Ledger.post(ent, "Test stock", [{"acct": "inventory", "dr": 20.0}, {"acct": "cash", "cr": 20.0}])
	Ecommerce.E()["orders"]["X"] = {"id": "X", "status": "placed", "location": "suite_2b", "product": "phone_stand", "qty": 2}
	runner.check(not LeaseEnd.quote("suite_2b", "immediate", {"stock": "liquidate", "destination": "riverside_studio"})["ok"], "reserved stock cannot be liquidated")
	var result := Living.end_lease("suite_2b", "immediate", {"stock": "move", "destination": "riverside_studio"})
	runner.check(result["ok"], "stock and order move")
	runner.eq(Ecommerce.stock("riverside_studio", "phone_stand"), 10, "all units preserved")
	runner.eq(Ecommerce.E()["orders"]["X"]["location"], "riverside_studio", "reservation follows")
	runner.check(Ledger.check_balanced(), "moving expense balances")


func test_closed_company_invalid_mode_home_and_cash_guards() -> void:
	var ent := _company()
	Living.lease("suite_2b")
	runner.check(not Living.end_lease("suite_2b", "invalid")["ok"], "invalid mode rejected")
	GameState.data["entities"][ent]["closed"] = true
	runner.check(not Living.end_lease("suite_2b", "immediate")["ok"], "closed company rejected")
	GameState.data["entities"][ent].erase("closed")
	Ledger.expense(ent, "other", Ledger.cash(ent), "Drain cash")
	runner.check(not Living.end_lease("suite_2b", "immediate")["ok"], "deposit cannot fund upfront fee")
	Living.D()["leases"]["riverside_studio"] = {"entity": "player", "rent": 1250.0, "since": 0}
	runner.check(not Living.end_lease("riverside_studio", "immediate")["ok"], "new home required")


func test_missing_hotel_lease_pauses_new_bookings_but_owned_hotel_is_valid() -> void:
	var ent := _company()
	Hotel.S()["active"] = true
	Hotel.S()["entity"] = ent
	Hotel.S()["mode"] = "lease"
	runner.check(not Hotel.valid(), "no rented premises, no hotel operations")
	Hotel.S()["mode"] = "own"
	runner.check(Hotel.valid(), "owned hotel still works")


func test_notice_does_not_double_charge_monthly_rent() -> void:
	var ent := _company()
	Living.lease("suite_2b")
	var q := Living.end_lease("suite_2b", "notice")
	var before := Ledger.balance(ent, "exp:rent_office")
	var t := int(q["due"]) - 60
	GameState.data["clock"]["minutes"] = t
	Living.D()["leases"]["suite_2b"]["day"] = int(Clock.date()["day"])
	Living.on_hour(t, 9)
	runner.eq(Ledger.balance(ent, "exp:rent_office"), before, "paid notice rent is not charged again")


func test_industry_cancellation_refunds_deposit_pays_penalty_and_pauses_factory() -> void:
	var ent := _company()
	Living.lease("unit12_factory")
	Manufacturing.start()
	var id := Jobs.offer({"entity": ent, "client": "OEM", "scope": "Units", "price": 1000.0, "deposit": 0.3, "penalty_rate": 0.1, "terms": 30, "segment": "manufacturing"})
	Jobs.accept(id)
	Manufacturing.S()["orders"][id] = {"job": id, "status": "active"}
	runner.check(not LeaseEnd.quote("unit12_factory", "immediate")["ok"], "unfinished jobs need a choice")
	var before := Ledger.cash(ent)
	var q := LeaseEnd.quote("unit12_factory", "immediate", {"jobs": "cancel"})
	runner.check(Living.end_lease("unit12_factory", "immediate", {"jobs": "cancel"})["ok"], "cancel and end")
	runner.eq(Jobs.get_job(id)["status"], "closed", "job closed")
	runner.eq(Manufacturing.S()["orders"][id]["status"], "cancelled", "factory order cancelled")
	runner.check(not Manufacturing.valid(), "factory cannot produce without premises")
	runner.eq(Ledger.cash(ent) - before, float(q["refund"]) - float(q["total"]), "refund, penalty and rent match quote")
	runner.check(Ledger.check_balanced(), "job refund/penalty balances")


func test_damage_event_and_usage_remain_capped_and_saveable() -> void:
	_company()
	Living.lease("suite_2b")
	runner.check(Effects.apply({"op": "lease_damage", "property": "suite_2b", "amount": 80.0}, {})["ok"], "event records damage")
	runner.eq(LeaseEnd.quote("suite_2b", "immediate")["damage"], 80.0, "damage retained")
	LeaseEnd.record_damage("suite_2b", 999999)
	runner.eq(LeaseEnd.quote("suite_2b", "immediate")["refund"], 0.0, "damage cannot exceed deposit")
	runner.check(not LeaseEnd.record_damage("suite_2b", -1)["ok"], "negative damage rejected")
	runner.check(Ledger.check_balanced(), "damage is not prematurely booked")


func test_staff_choice_dismissal_and_severance() -> void:
	_company()
	Living.lease("suite_2b")
	Staff.S()["people"]["A"] = {"id": "A", "name": "Alex", "role": "packer", "salary_week": 600.0, "morale": 70}
	runner.check(not LeaseEnd.quote("suite_2b", "immediate")["ok"], "staff choice required")
	var q := LeaseEnd.quote("suite_2b", "immediate", {"staff": "dismiss"})
	runner.eq(q["severance"], 600.0, "severance quoted")
	runner.check(Living.end_lease("suite_2b", "immediate", {"staff": "dismiss"})["ok"], "dismiss before exit")
	runner.eq(Staff.people().size(), 0, "no staff stranded")
	runner.check(Ledger.check_balanced(), "severance balances")


func test_notice_revalidates_changed_stock_and_can_resume() -> void:
	_company()
	Living.lease("suite_2b")
	var q := Living.end_lease("suite_2b", "notice")
	runner.check(not LeaseEnd._finish("suite_2b")["ok"], "notice cannot settle before its deadline")
	Ecommerce._add_stock("suite_2b", "phone_stand", 2, 0.0, 0.0)
	GameState.data["clock"]["minutes"] = q["due"]
	LeaseEnd.on_hour()
	runner.check(Living.has_lease("suite_2b"), "changed stock retains premises")
	runner.check(Living.D()["leases"]["suite_2b"]["ending"].has("blocked"), "player receives actionable blocker")
	Living.D()["leases"]["suite_2b"]["ending"]["plan"] = {"stock": "liquidate"}
	runner.check(LeaseEnd._finish("suite_2b")["ok"], "chosen liquidation resumes exit")
	runner.check(Ledger.check_balanced(), "resumed settlement balances")


func test_factory_raw_materials_and_transit_liquidated_once() -> void:
	var ent := _company()
	Living.lease("unit12_factory")
	Manufacturing.start()
	var order := Manufacturing.order_material(int(Manufacturing.cfg()["moq"]))
	runner.check(order["ok"], "actual prepaid material purchase")
	runner.check(not LeaseEnd.quote("unit12_factory", "immediate")["ok"], "raw materials require explicit liquidation")
	runner.check(Living.end_lease("unit12_factory", "immediate", {"stock": "liquidate"})["ok"], "cancel prepaid delivery")
	runner.eq(Ledger.balance(ent, "inventory_in_transit"), 0.0, "transit realized")
	runner.eq(Sim.pending("mfg.arrival").size(), 0, "no phantom arrival")
	runner.check(Ledger.check_balanced(), "actual liquidation balances")


func test_brokerage_and_new_vehicle_trade_pause_without_premises() -> void:
	var ent := _company()
	RealEstate.S()["active"] = true
	RealEstate.S()["entity"] = ent
	RealEstate.refresh()
	runner.eq(RealEstate.S()["mandates"].size(), 0, "no new mandates without office")
	Automotive.S()["active"] = true
	Automotive.S()["entity"] = ent
	Automotive._rental_day()
	runner.eq(Automotive.S()["rentals"].size(), 0, "no new rentals without counter")
	runner.check(Ledger.check_balanced(), "paused businesses do not invent trades")
