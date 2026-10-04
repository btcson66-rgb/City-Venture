class_name Customs
extends RefCounted
## Company-bound export declarations and chapter receipts. Held parcels have a finite withdrawal deadline.


static func cfg() -> Dictionary:
	return DataDB.economy.get("duties", {})


static func S() -> Dictionary:
	if not GameState.data.has("customs"):
		GameState.data["customs"] = {"companies": {}, "chapters": {}}
	return GameState.data["customs"]


static func prefs(entity: String) -> Dictionary:
	if not S()["companies"].has(entity):
		S()["companies"][entity] = {}
	return S()["companies"][entity]


static func code_for(product: String) -> String:
	var category := str(DataDB.product(product).get("category", ""))
	return str(cfg().get("categories", {}).get(category, "general"))


static func set_declaration(region: String, listing: String, policy: String, code: String) -> Dictionary:
	if not GlobalMarket.order_allowed(region, listing):
		return {"ok": false, "error": "Open this storefront and save its local price first."}
	if not policy in ["ddp", "ddu"] or not cfg().get("codes", {}).has(code):
		return {"ok": false, "error": "Choose a delivery-duty policy and a supported tariff code."}
	prefs(GameState.company_id())[region + ":" + listing] = {"policy": policy, "code": code}
	GameState.set_flag("customs_active")
	StoryEngine.check()
	return {"ok": true}


static func annotate(o: Dictionary) -> void:
	if not GameState.flag("customs_active"):
		return
	var p: Dictionary = prefs(str(o["entity"])).get(str(o["region"]) + ":" + str(o["listing"]), {"policy": "ddu", "code": "general"})
	o["customs"] = p.duplicate()
	o["customs"]["expected"] = code_for(str(o["product"]))
	o["customs"]["duty_paid"] = 0.0


static func duty(o: Dictionary) -> float:
	var rates: Dictionary = cfg().get("regions", {}).get(o["region"], {})
	return snappedf(float(o["foreign_price"]) * int(o["qty"]) * FX.rate(str(o["currency"])) * float(rates.get(code_for(str(o["product"])), 0.0)), 0.01)


static func prepare(o: Dictionary) -> bool:
	if not o.has("customs") or o["customs"].get("cleared", false):
		return true
	var d: Dictionary = o["customs"]
	if d["code"] != d["expected"]:
		o["status"] = "customs_hold"
		d["held_at"] = Clock.now()
		var tax := duty(o)
		var fine := float(cfg().get("misclassification_fine", 25))
		EventEngine.trigger("customs_hold", {"order": o["id"], "entity": o["entity"], "full_cost": tax + fine,
			"document_cost": tax + fine * float(cfg().get("document_fine_factor", 0.5)), "tax": Fmt.money(tax), "fine": Fmt.money(fine)})
		return false
	if d["policy"] == "ddp":
		var cost := duty(o)
		if Ledger.cash(str(o["entity"])) < cost:
			o["status"] = "customs_hold"
			d["held_at"] = Clock.now()
			EventEngine.trigger("customs_hold", {"order": o["id"], "entity": o["entity"], "full_cost": cost,
				"document_cost": cost, "tax": Fmt.money(cost), "fine": Fmt.money(0)})
			return false
		pay(o, cost, 0)
	d["cleared"] = true
	return true


static func pay(o: Dictionary, tax: float, fine: float) -> void:
	var ent := str(o["entity"])
	if tax > 0:
		Ledger.expense(ent, "compliance", tax, I18n.t("Export duty %s: %s") % [o["id"], Fmt.money(tax)], {"type": "export_duty", "order": o["id"]})
	if fine > 0:
		Ledger.expense(ent, "penalties", fine, I18n.t("Tariff correction penalty %s: %s") % [o["id"], Fmt.money(fine)], {"type": "customs_penalty", "order": o["id"]})
	o["customs"]["duty_paid"] = float(o["customs"].get("duty_paid", 0)) + tax
	if tax > 0:
		o["customs"]["policy"] = "ddp"   # the seller has now covered arrival duty
	o["customs"]["penalty"] = fine


static func resolve(order: String, choice: String) -> Dictionary:
	var o: Dictionary = Ecommerce.E()["orders"].get(order, {})
	if o.is_empty() or o["status"] != "customs_hold" or not GlobalMarket.live(str(o["entity"])):
		return {"ok": false, "error": "This customs hold is no longer active."}
	if choice == "withdraw":
		withdraw(o)
		return {"ok": true}
	if not choice in ["documents", "pay"]:
		return {"ok": false, "error": "Unknown choice."}
	var tax := duty(o)
	var fine := float(cfg().get("misclassification_fine", 25)) if o["customs"]["code"] != o["customs"]["expected"] else 0.0
	if choice == "documents":
		fine *= float(cfg().get("document_fine_factor", 0.5))
	if Ledger.cash(str(o["entity"])) < tax + fine:
		return {"ok": false, "error": "Not enough company cash; withdraw the parcel or transfer cash first."}
	pay(o, tax, fine)
	o["customs"]["code"] = o["customs"]["expected"]
	o["customs"]["cleared"] = true
	Ecommerce._ship(o)
	if choice == "documents":
		o["ship"]["eta"] += int(cfg().get("document_delay_days", 2)) * Clock.DAY
		Sim.cancel("eco.deliver", "order", o["id"])
		Sim.schedule(int(o["ship"]["eta"]), "eco.deliver", {"order": o["id"]})
	return {"ok": true}


static func withdraw(o: Dictionary) -> void:
	var cost := float(o.get("cogs", 0))
	Ecommerce._add_stock(str(o["location"]), str(o["product"]), int(o["qty"]), cost / maxi(1, int(o["qty"])), 0)
	if cost > 0:
		Ledger.post(str(o["entity"]), I18n.t("Held export %s withdrawn; freight remains paid") % o["id"], [{"acct": "inventory", "dr": cost}, {"acct": "goods_out", "cr": cost}], {"type": "customs_withdrawal"})
	o["status"] = "cancelled"
	remove_decisions(str(o["id"]))


static func remove_decisions(order: String) -> void:
	for q in EventEngine.S()["queue"].duplicate():
		if q["id"] == "customs_hold" and q["ctx"].get("order", "") == order:
			EventEngine.S()["queue"].erase(q)


static func refusal_chance(o: Dictionary) -> float:
	return float(cfg().get("refusal_rates", {}).get(o.get("customs", {}).get("policy", "ddu"), 0)) if o.has("customs") else 0.0


static func begin(chapter: String) -> void:
	if not S()["chapters"].has(chapter):
		S()["chapters"][chapter] = {"entity": GameState.company_id(), "started": Clock.now()}
	if not GlobalMarket.live(str(S()["chapters"][chapter]["entity"])):
		GameState.set_flag(chapter + "_unavailable")
	StoryEngine.St()["active"].erase("goal_growth")
	if chapter == "ch14_customs":
		GameState.set_flag("customs_active")


static func reconcile() -> void:
	for o in Ecommerce.foreign_orders():
		if o["status"] == "customs_hold":
			if not GlobalMarket.live(str(o["entity"])):
				remove_decisions(str(o["id"]))
			elif Clock.now() - int(o["customs"]["held_at"]) >= int(cfg().get("hold_timeout_days", 7)) * Clock.DAY:
				withdraw(o)
	for id in S()["chapters"]:
		var st: Dictionary = S()["chapters"][id]
		if not GlobalMarket.live(str(st["entity"])):
			GameState.set_flag(str(id) + "_unavailable")
	if S()["chapters"].is_empty() and not GameState.flag("customs_active"):
		return   # season-one story checks need no export-history scan
	var ent := GameState.company_id()
	if not GlobalMarket.live(ent):
		return
	GameState.set_flag("global_bank_ready", bool(GlobalMarket.company()["bank"]))
	var store: Dictionary = GlobalMarket.company()["stores"].get("northridge", {})
	GameState.set_flag("northridge_listing_ready", not store.get("prices", {}).is_empty())
	for o in Ecommerce.foreign_orders():
		if o.get("entity", "") == ent and o.get("region", "") == "northridge" and o.get("ship", {}).has("shipped"):
			GameState.set_flag("first_export_shipped")
	if not GameState.flag("first_export_converted"):
		for e in Ledger.entries(ent, 100000):
			if e.get("source", {}).get("type", "") == "fx_conversion":
				GameState.set_flag("first_export_converted")
				break
	for key in prefs(ent):
		GameState.set_flag("export_policy_chosen")
		var listing := str(key).get_slice(":", 1)
		var l: Dictionary = Ecommerce.E()["listings"].get(listing, {})
		if not l.is_empty() and prefs(ent)[key]["code"] == code_for(str(l["product"])):
			GameState.set_flag("export_code_correct")
	var results := trial_results(ent)
	GameState.set_flag("customs_trial_passed", int(results["count"]) >= int(results["target"]) and float(results["return_rate"]) < float(cfg().get("target_return_rate", 0.15)))
	var st14: Dictionary = S()["chapters"].get("ch14_customs", {})
	if not st14.is_empty() and Clock.now() - int(st14["started"]) >= int(cfg().get("review_after_days", 14)) * Clock.DAY and not GameState.flag("customs_nudge_sent"):
		GameState.set_flag("customs_nudge_sent")
		GameState.add_message("maya", "Two weeks abroad: try a lower local price or more ads. The trial now needs 5 delivered units; check returns and your actual cash. You can also review the results and pause expansion.")


static func trial_results(entity: String) -> Dictionary:
	var orders: Array = []
	for o in Ecommerce.foreign_orders():
		if o.get("entity", "") == entity and o.has("delivery_rate") and o.get("customs", {}).get("cleared", false) and Clock.now() - int(o["delivered"]) >= int(cfg().get("return_observation_days", 3)) * Clock.DAY:
			orders.append(o)
	orders.sort_custom(func(a,b): return int(a["delivered"]) > int(b["delivered"]))
	var target := int(cfg().get("target_units", 10))
	var st: Dictionary = S()["chapters"].get("ch14_customs", {})
	if not st.is_empty() and Clock.now() - int(st["started"]) >= int(cfg().get("review_after_days", 14)) * Clock.DAY:
		target = int(cfg().get("fallback_units", 5))
	var count := 0
	var returns := 0
	for o in orders.slice(0, target):
		count += int(o["qty"])
		if o.get("customs_refused", false) or o["status"] in ["return_requested", "refunded", "partial_refund", "refused", "disputed", "replaced"]:
			returns += int(o["qty"])
	return {"count": count, "target": target, "return_rate": float(returns) / maxi(1,count)}


static func review_available() -> bool:
	var st: Dictionary = S()["chapters"].get("ch14_customs", {})
	return not st.is_empty() and Clock.now() - int(st["started"]) >= int(cfg().get("review_after_days", 14)) * Clock.DAY


static func pause_expansion() -> bool:
	if not review_available():
		return false
	for store in GlobalMarket.company()["stores"].values():
		store["prices"].clear()   # keep revenue/receipt containers for already accepted parcels
	GameState.set_flag("customs_trial_reviewed")
	StoryEngine.check()
	return true
