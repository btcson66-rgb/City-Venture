extends RefCounted
## Quote previews are risk scenarios, not accepted jobs or fabricated profit.

var runner


func _quote(term := "CIF", mode := "sea", payment := "lc", insured := true) -> Dictionary:
	return TradeQuote.sheet("aurelia", "northridge", "wireless_earbuds", 50, term, mode, payment, insured)


func test_cost_matrix_and_risk_transfer_are_distinct() -> void:
	var exw := _quote("EXW")
	var fob := _quote("FOB")
	var cif := _quote("CIF")
	var ddp := _quote("DDP")
	runner.check(exw["ok"] and fob["ok"] and cif["ok"] and ddp["ok"], "all sea terms supported")
	runner.check(exw["costs"] < fob["costs"] and fob["costs"] < cif["costs"] and cif["costs"] < ddp["costs"], "seller cost matrix")
	runner.eq(exw["risk_transfer"], "Supplier collection", "EXW collection risk")
	runner.eq(fob["risk_transfer"], "Vessel loading", "FOB onboard risk")
	runner.eq(cif["risk_transfer"], fob["risk_transfer"], "CIF insurance cost does not postpone risk transfer")
	runner.eq(ddp["risk_transfer"], "Buyer delivery", "DDP retains risk")
	for q in [exw, fob, cif, ddp]:
		var sum := float(q["purchase"]) + float(q["fee"]) + float(q["spread"])
		for segment in q["segments"]:
			if segment["payer"] == "seller":
				sum += float(segment["cost"])
		runner.eq(q["costs"], snappedf(sum, 0.01), "all seller costs accounted for exactly once")


func test_profitable_competitive_strategy_can_still_lose() -> void:
	var q := _quote()
	runner.check(float(q["margin"]) > 0 and q["competitive"], "reasonable sea CIF quote has positive margin within buyer ceiling")
	runner.check(float(q["stress_margin"]) < 0, "FX and cargo stress can erase margin")
	runner.check(float(q["default_risk"]) > 0 and float(q["cargo_risk"]) > 0, "neither bank nor insured transport guarantees success")


func test_insurance_and_credit_choices_have_cost_and_risk() -> void:
	var bare := _quote("DDP", "sea", "open_account", false)
	var insured := _quote("DDP", "sea", "open_account", true)
	var safe := _quote("DDP", "sea", "lc", true)
	runner.check(insured["costs"] > bare["costs"] and insured["stress_margin"] > bare["stress_margin"], "insurance costs money and reduces exposed cargo loss")
	runner.check(safe["fee"] > insured["fee"] and safe["default_risk"] < insured["default_risk"], "LC fee buys lower credit exposure")
	runner.check(_quote("CIF", "sea", "lc", false)["insured"], "CIF requires insurance even if optional cover is off")
	runner.eq(_quote("DDP", "sea", "tt_prepaid")["default_risk"], 0, "prepaid removes unpaid invoice exposure, not cargo exposure")


func test_air_is_faster_more_expensive_and_sea_terms_are_rejected() -> void:
	var sea := _quote("DDP")
	var air := _quote("DDP", "air")
	runner.check(air["transit_days"] < sea["transit_days"] and air["costs"] > sea["costs"], "air has a real speed/cost choice")
	runner.eq(air["wait_days"], 0, "air has no weekly sea sailing wait")
	runner.check(not _quote("CIF", "air")["ok"] and not _quote("FOB", "air")["ok"], "sea-only terms reject air instead of misrepresenting risk")


func test_invalid_routes_quantities_and_nonfinite_inputs() -> void:
	for qty in [0, -1, 100000]:
		runner.check(not TradeQuote.sheet("aurelia", "northridge", "wireless_earbuds", qty, "DDP", "sea", "lc", true)["ok"], "bounded supply and demand")
	runner.check(not TradeQuote.sheet("aurelia", "aurelia", "wireless_earbuds", 1, "DDP", "sea", "lc", true)["ok"], "different endpoints required")
	runner.check(not TradeQuote.sheet("missing", "northridge", "wireless_earbuds", 1, "DDP", "sea", "lc", true)["ok"], "unknown endpoint safe")
	runner.check(not TradeQuote.sheet("aurelia", "northridge", "wireless_earbuds", 1, "DDP", "sea", "lc", true, NAN)["ok"], "NaN rejected")


func test_eight_regions_quotes_expire_and_follow_spot_fx() -> void:
	for region in DataDB.regions:
		var source := "zenkai" if region == "aurelia" else "aurelia"
		runner.check(TradeQuote.sheet(source, region, "wireless_earbuds", 1, "DDP", "sea", "lc", true)["ok"], "each region has supply/demand")
	var home := TradeQuote.sheet("zenkai", "aurelia", "wireless_earbuds", 1, "DDP", "sea", "lc", true)
	runner.check(home["segments"][3]["cost"] > 0, "home-region imports still carry a tariff")
	runner.eq(home["spread"], 0, "home-currency receipts need no bank spread")
	var q := _quote()
	runner.check(TradeQuote.valid(q), "new RFQ valid")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(q))
	runner.eq(restored["sales"], q["sales"], "quote round-trips without mutable state")
	FX.S()["rates"]["NRD"] *= 0.85
	var changed := _quote()
	runner.check(changed["buyer_quote"] > q["buyer_quote"], "local buyer quote responds to currency depreciation")
	GameState.data["clock"]["minutes"] = int(q["valid_until"])
	runner.check(not TradeQuote.valid(q), "expiry boundary is exclusive")


func test_read_only_quote_needs_no_stock_company_or_new_saved_state() -> void:
	var before := JSON.stringify(GameState.data["ledger"])
	_quote()
	_quote()
	runner.eq(JSON.stringify(GameState.data["ledger"]), before, "repeated RFQ never fabricates cash or revenue")
	runner.check(not GameState.data.has("trade"), "old saves need no new state or migration")
	runner.check(Ledger.check_balanced(), "preview ledger remains balanced")
