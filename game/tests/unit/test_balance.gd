extends RefCounted
var runner

func test_cautious_six_months_reaches_a_genuinely_profitable_chapter_seven() -> void:
	var result := EconomySim.new().run("cautious", 101, 6)
	runner.check(result["balanced"], "six-month player policy keeps double-entry balanced")
	runner.check(result["ch7_profit"] != null and float(result["ch7_profit"]) > 0.0, "chapter seven closes with positive actual ledger profit")
	runner.check(not GameState.flag("ch7_survived_losses"), "profit gate is not the two-loss fallback")
	runner.check("ch7_supply_shock" in result["chapter_days"], "chapter seven is completed within six calendar months")

func test_balance_overlay_only_changes_existing_numeric_fields() -> void:
	for group in DataDB.economy.get("balance", {}).get("definitions", {}):
		runner.check(group == "products", "friends beta overlay only tunes live ecommerce products")
		for id in DataDB.economy["balance"]["definitions"][group]:
			runner.check(DataDB.product(id).has("base_daily_demand"), "real live product: " + id)
			runner.check(float(DataDB.product(id)["base_daily_demand"]) > 0, "positive daily demand")
