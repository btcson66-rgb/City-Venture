extends Node
var rows: Array = []
func _ready() -> void: call_deferred("run")
func profit() -> float:
	var value := Ledger.lifetime_gross_profit("player")
	for category in Ledger.EXPENSE_CATEGORIES: value -= Ledger.balance("player", "exp:" + category)
	return value
func run() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	for strategy in ["manual", "novice", "skilled"]:
		for seed_value in [11301, 11302, 11303]: simulate(strategy, seed_value)
	var failures: Array = []
	for strategy in ["manual", "novice", "skilled"]:
		var matching := rows.filter(func(row): return row["strategy"] == strategy)
		var mean := 0.0
		var losses := 0
		for row in matching: mean += float(row["profit"]) / matching.size(); losses += int(row["losing_days"])
		if mean <= 0.0: failures.append(strategy + " unprofitable on average")
		if losses == 0: failures.append(strategy + " has no observed downside")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("packing_balance_120.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"days": 120, "seeds": [11301,11302,11303], "scope": "Matched alternating baskets/monitors. Actual stock costs, packaging, postage, platform fees, delivery and stochastic refunds. Parcel contribution before wages, rent, ads and demand; not a whole-company profitability forecast.", "runs": rows, "failures": failures}, "\t"))
	print("PACKING BALANCE: %d runs x 120 days, %d failures" % [rows.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func simulate(strategy: String, seed_value: int) -> void:
	GameState.new_game({"name": "Packing QA", "seed": seed_value})
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	var losses := 0
	var refunded := 0
	var damaged := 0
	var daily: Array = []
	for day in 120:
		GameState.data["clock"]["minutes"] = day * Clock.DAY
		GameState.rng.seed = seed_value * 1000 + day
		var before := profit()
		var lines: Array = [{"product": "phone_stand", "qty": 2, "unit_price": 15.0}, {"product": "desk_lamp", "qty": 1, "unit_price": 29.0}] if day % 2 == 0 else [{"product": "desk_monitor", "qty": 1, "unit_price": 150.0}]
		var o := {"id": str(day), "product": lines[0]["product"], "qty": lines[0]["qty"], "unit_price": lines[0]["unit_price"], "items": lines, "entity": "player", "location": "riverside_studio", "status": "placed", "listing": "", "customer": "Matched buyer", "placed": Clock.now()}
		for item in lines:
			var supplier := "harbor_home_goods" if item["product"] != "phone_stand" else "tradelink_wholesale"
			var cost := Ecommerce.unit_cost(supplier, item["product"])
			Ecommerce._add_stock("riverside_studio", item["product"], int(item["qty"]), cost, 0.0)
			var total := cost * int(item["qty"])
			Ledger.post("player", "QA landed stock purchase", [{"acct": "inventory", "dr": total}, {"acct": "cash", "cr": total}], {"segment": "ecommerce"})
		Ecommerce.E()["orders"][o["id"]] = o
		var policy := Packing.auto_pack(o, 1 if strategy == "novice" else 5)
		if strategy == "manual": policy["padding"] = 0.6
		Ecommerce.pack_orders("riverside_studio", 1, {o["id"]: policy})
		var shipping := Ecommerce.ship_cost(o, "economy")
		Ledger.expense("player", "shipping", shipping, "QA actual parcel postage", {"segment": "ecommerce"})
		o["ship"] = {"method": "economy"}
		o["status"] = "shipped"
		# Same supplier-defect draw for each strategy; transit damage remains a real packing-dependent draw.
		o["defective"] = GameState.randf() < 0.04
		Ecommerce.handle("eco.deliver", {"order": o["id"]})
		if o.get("damaged", false): damaged += 1
		if GameState.randf() < (0.8 if o.get("defective", false) else Ecommerce.return_probability(o)):
			o["status"] = "return_requested"
			Ecommerce.resolve_return(o["id"], "refund")
			refunded += 1
		var contribution := profit() - before
		if contribution < 0: losses += 1
		daily.append(snappedf(contribution, 0.01))
	rows.append({"strategy": strategy, "seed": seed_value, "profit": snappedf(profit(), 0.01), "materials": Ledger.balance("player", "exp:packaging"), "shipping_including_returns": Ledger.balance("player", "exp:shipping"), "damaged": damaged, "refunded": refunded, "losing_days": losses, "daily_min": daily.min(), "daily_max": daily.max(), "ledger_balanced": Ledger.check_balanced()})
