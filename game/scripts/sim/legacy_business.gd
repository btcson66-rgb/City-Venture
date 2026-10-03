class_name LegacyBusiness
extends RefCounted
## Bound market receipts and endings survive reloads; story never manufactures trade revenue.

static func cfg() -> Dictionary:
	return DataDB.economy.get("legacy", {})

static func S() -> Dictionary:
	if not GameState.data.has("legacy_story"):
		GameState.data["legacy_story"] = {"market": {}, "ending": "", "cards": [], "viewed": 0, "manager": {}}
	return GameState.data["legacy_story"]

static func market() -> Dictionary:
	return S()["market"]

static func begin(chapter: String) -> void:
	if chapter == "ch18_legacy":
		if not GameState.flag("legacy_invited"):
			GameState.set_flag("legacy_invited")
			GameState.add_message("maya", "Meet me at Bloom Coffee. We can also talk by phone. Your next chapter does not need a profitable company.")
		return
	if not market().is_empty():
		reconcile()
		return
	var ent := GameState.company_id()
	var region := "home"
	var listing := ""
	for l in Ecommerce.E()["listings"].values():
		if l.get("active", false):
			listing = str(l["id"])
			for r in GlobalMarket.company()["stores"]:
				if GlobalMarket.order_allowed(str(r), listing):
					region = str(r)
					break
			break
	var branch := "counter" if GameState.flag("company_sold") and GameState.flag("offer_countered") else ("sold" if GameState.flag("company_sold") else "independent")
	var price := 0.0
	var stock := 0
	var prior: Dictionary = GameState.data.get("acquisition_receipt", {})
	var known: bool = prior.get("entity", "") == ent and float(prior.get("price", 0)) > 0
	var reference := float(prior["price"]) if known else float(Acquisition.quote()["price"])
	if listing != "":
		var l: Dictionary = Ecommerce.E()["listings"][listing]
		price = float(l["price"]) if region == "home" else float(GlobalMarket.company()["stores"][region]["prices"][listing])
		stock = Ecommerce.total_units_at_any(str(l["product"]))
	S()["market"] = {"entity": ent, "region": region, "listing": listing, "branch": branch, "started": Clock.now(),
		"price": price, "stock": stock, "strategy": "", "responded": -1, "ad": false,
		"previous_offer": reference, "previous_offer_known": known, "second_offer": snappedf(reference * float(cfg()["second_offer_factor"]), 0.01)}
	GameState.set_flag("consolidation_started")
	if branch == "independent":
		if known:
			GameState.add_message("victor", I18n.t("Hale Group is cutting prices. My second offer is %s, below the earlier %s. You can still build your own position.") % [Fmt.money0(market()["second_offer"]), Fmt.money0(market()["previous_offer"])])
		else:
			GameState.add_message("victor", I18n.t("My repeat offer is %s, below today's valuation of %s. This older save did not record the first offer, so I cannot compare its exact amount.") % [Fmt.money0(market()["second_offer"]), Fmt.money0(reference)])
	else:
		GameState.add_message("victor", "Your Hale Group division faces Vesper Brands. Review the revenue goal, but completing this chapter does not require revenue growth.")
	if GlobalMarket.live(ent) and listing != "":
		EventEngine.trigger("rival_undercut", {"rival": rival(), "market": region_name()})
	reconcile()

static func rival() -> String:
	return "Hale Group" if market().get("branch", "") == "independent" else "Vesper Brands"

static func region_name() -> String:
	var r := str(market().get("region", "home"))
	return I18n.t("local market") if r == "home" else I18n.t(str(DataDB.regions.get(r, {}).get("name", r)))

static func choose(strategy: String) -> Dictionary:
	if strategy == "review":
		review_unavailable()
		return {"ok": true}
	if market().is_empty() or not strategy in ["niche", "scale"] or not GlobalMarket.live(str(market()["entity"])):
		return {"ok": false, "error": "This market is no longer available. Review the closure and continue."}
	if int(market()["responded"]) >= 0:
		return {"ok": false, "error": "The operating response is already committed. Continue with the market review."}
	market()["strategy"] = strategy
	return {"ok": true}

static func listing() -> Dictionary:
	return Ecommerce.E()["listings"].get(str(market().get("listing", "")), {})

static func response_block() -> String:
	var m := market()
	var l := listing()
	if m.is_empty() or l.is_empty() or not GlobalMarket.live(str(m.get("entity", ""))) or not l.get("active", false):
		return "This market is no longer available. Review the closure and continue."
	if int(m["responded"]) >= 0:
		return "The operating response is already committed. Continue with the market review."
	if not str(m["strategy"]) in ["niche", "scale"]:
		return "Choose a market strategy first."
	if m["strategy"] == "niche" and not quality_ready() and Ledger.cash(str(m["entity"])) < float(cfg()["brand_ad_fee"]):
		return "Collect enough good reviews or retain company cash for the brand campaign."
	return ""

static func quality_ready() -> bool:
	var l := listing()
	return not l.is_empty() and int(l.get("rating_n", 0)) >= int(cfg()["good_reviews"]) and Ecommerce.rating(l) >= float(cfg()["good_rating"])

static func respond() -> Dictionary:
	var why := response_block()
	if why != "":
		return {"ok": false, "error": why}
	var m := market()
	var l := listing()
	var niche: bool = m["strategy"] == "niche"
	var product := DataDB.product(str(l["product"]))
	var quote := 1.0 if m["region"] == "home" else FX.rate(GlobalMarket.currency(str(m["region"])))
	var price := clampf(float(m["price"]) * float(cfg()["niche_price_factor"] if niche else cfg()["scale_price_factor"]), float(product["price_min"]) / quote, float(product["price_max"]) / quote)
	if is_equal_approx(price, float(m["price"])):
		return {"ok": false, "error": "The price is already at its allowed limit. Choose the other strategy or review this unavailable route."}
	if not niche:
		var needed := int(m["stock"]) + int(cfg()["scale_extra_units"])
		if Ecommerce.total_units_at_any(str(l["product"])) < needed:
			var offer := Ecommerce.offer("tradelink_wholesale", str(l["product"]))
			if offer.is_empty():
				return {"ok": false, "error": "The scale supplier does not carry this product. Choose niche or restock from Operations."}
			var purchase := Ecommerce.buy("tradelink_wholesale", str(l["product"]), maxi(int(offer["moq"]), needed - Ecommerce.total_units_at_any(str(l["product"]))))
			if not purchase["ok"]:
				return purchase
			m["purchase"] = purchase["po_id"]
	if niche and not quality_ready():
		var fee := float(cfg()["brand_ad_fee"])
		Ledger.expense(str(m["entity"]), "advertising", fee, I18n.t("Brand campaign: %s") % Fmt.money(fee), {"segment": "ecommerce", "type": "brand_campaign"})
		Ecommerce.E()["demand_mods"].append({"product": l["product"], "mult": float(cfg()["brand_ad_multiplier"]), "until": Clock.now() + int(cfg()["brand_ad_days"]) * Clock.DAY})
		m["ad"] = true
	if m["region"] == "home":
		Ecommerce.set_price(str(l["id"]), price)
	else:
		var result := GlobalMarket.set_price(str(m["region"]), str(l["id"]), price)
		if not result["ok"]:
			return result
	m["responded"] = Clock.now()
	GameState.set_flag("consolidation_response")
	GameState.timeline(I18n.t("Market response: %s, price %s per unit.") % [I18n.t("Niche" if niche else "Scale"), Fmt.money(price)], "business")
	StoryEngine.check()
	return {"ok": true}

static func affected(l: Dictionary, region: String) -> bool:
	return not market().is_empty() and GameState.company_id() == market()["entity"] and GlobalMarket.live(str(market()["entity"])) and region == market()["region"] and str(l.get("id", "")) == market()["listing"]

static func elasticity(l: Dictionary, region: String, normal: float) -> float:
	if not affected(l, region) or int(market()["responded"]) < 0:
		return normal
	return float(cfg()["niche_elasticity"] if market()["strategy"] == "niche" else cfg()["scale_elasticity"])

static func demand_factor(l: Dictionary, region: String) -> float:
	if not affected(l, region):
		return 1.0
	var elapsed := maxf(0, float(Clock.now() - int(market()["started"])) / Clock.DAY)
	var shock := 1.0 - float(cfg()["rival_share"]) * maxf(0, 1.0 - elapsed / float(cfg()["rival_days"]))
	if int(market()["responded"]) < 0:
		return shock
	return shock * float(cfg()["niche_demand_factor"] if market()["strategy"] == "niche" else cfg()["scale_demand_factor"])

static func reconcile() -> void:
	var m := market()
	if m.is_empty():
		return
	if not GlobalMarket.live(str(m["entity"])) or listing().is_empty() or not listing().get("active", false):
		GameState.set_flag("consolidation_unavailable")
		return
	if m["region"] != "home" and not GlobalMarket.order_allowed(str(m["region"]), str(m["listing"])):
		m["region"] = "home"
		if int(m["responded"]) < 0:
			m["price"] = float(listing()["price"])
	if int(m["responded"]) >= 0 and Clock.now() - int(m["responded"]) >= int(cfg()["survival_days"]) * Clock.DAY:
		GameState.set_flag("consolidation_survived")

static func review_unavailable() -> void:
	GameState.set_flag("consolidation_unavailable")
	GameState.timeline("Reviewed a market response that cannot proceed. No survival or sales are claimed.", "story")
	StoryEngine.check()

static func report() -> Dictionary:
	var units := 0
	var revenue := 0.0
	var m := market()
	for o in Ecommerce.E()["orders"].values():
		if o.get("entity", "") == m.get("entity", "") and o.get("region", "home") == m.get("region", "home") and o.has("delivered") and int(o["delivered"]) >= int(m.get("started", 0)) and not o.get("status", "") in ["refunded", "refused"]:
			units += int(o["qty"])
			revenue += float(o["unit_price"]) * int(o["qty"])
	var l := listing()
	var own := 0.0 if l.is_empty() else Ecommerce.lambda_day(l, str(m.get("region", "home")))
	return {"units": units, "revenue": revenue, "rating": 0.0 if l.is_empty() else Ecommerce.rating(l),
		"reviews": int(l.get("rating_n", 0)), "share_estimate": own / maxf(0.01, own + float(cfg()["rival_daily_units"]))}

static func interview() -> Dictionary:
	if not GameState.flag("consolidation_survived"):
		return {"ok": false, "error": "Complete the 60-day operating period before the interview."}
	if not GameState.flag("kai_interviewed"):
		var r := report()
		GameState.add_message("kai", I18n.t("%s chose %s in %s. Recorded revenue: %s home dollars from %d delivered units. Model-estimated market share: %s; rating %.1f/5 from %d reviews. The share is an estimate, not a competitor sales report.") % [GameState.entity_name(str(market()["entity"])), I18n.t("Niche" if market()["strategy"] == "niche" else "Scale"), region_name(), Fmt.money(r["revenue"]), r["units"], Fmt.pct(r["share_estimate"]), r["rating"], r["reviews"]])
		GameState.set_flag("kai_interviewed")
	StoryEngine.check()
	return {"ok": true}

static func ending_block(choice: String) -> String:
	if S()["ending"] != "":
		return "An ending is already recorded. Reopen its cards or continue free play."
	if not GameState.flag("legacy_met_maya"):
		return "Speak with Maya first, at Bloom Coffee or by phone."
	if not choice in ["independent", "sale", "employees", "mentor"]:
		return "Choose an available ending."
	if choice == "employees" and CapitalMarket.S()["route"]=="public" and not CapitalMarket.board_grant_approve():
		return "The board rejected dilution for the team grant. Choose another legacy route."
	if choice == "employees" and (not GlobalMarket.live(GameState.company_id()) or Staff.count() < 1):
		return "Hire at least one employee in a live company before sharing ownership."
	return ""

static func end_story(choice: String) -> Dictionary:
	var why := ending_block(choice)
	if why != "":
		return {"ok": false, "error": why}
	var ent := GameState.company_id()
	if choice == "sale" and GlobalMarket.live(ent) and not GameState.flag("company_sold") and float(Acquisition.quote()["price"]) > 0:
		var result := Acquisition.decide("accept", Acquisition.context())
		if not result["ok"]:
			return result
	if choice == "employees":
		var shares: Dictionary = GameState.data.get("cap_table", {"founder": 1.0}).duplicate()
		var grant := float(cfg()["employee_share"])
		var founder_grant := float(shares.get("founder", 0)) * grant
		for owner in shares:
			shares[owner] = float(shares[owner]) * (1.0 - grant)
		shares["employees"] = float(shares.get("employees", 0)) + grant
		GameState.data["cap_table"] = shares
		var book := snappedf(maxf(0, -Ledger.balance(ent, "equity")) * grant, 0.01)
		if book > 0:
			Ledger.post(ent, I18n.t("Board-approved employee ownership: %s") % Fmt.pct(grant), [{"acct": "equity", "dr": book}, {"acct": "equity:employees", "cr": book}], {"type": "ownership"})
		var carrying := snappedf(maxf(0, Ledger.balance("player", "investments")) * founder_grant / maxf(0.01, float(shares.get("founder", 0)) / (1.0 - grant)), 0.01)
		if carrying > 0:
			Ledger.post("player", "Founder shares granted to the team", [{"acct": "exp:other", "dr": carrying}, {"acct": "investments", "cr": carrying}], {"type": "ownership"})
	if choice == "mentor" and GlobalMarket.live(ent):
		S()["manager"] = {"entity": ent, "next_fee": Clock.now(), "last_day": -1, "unpaid": 0.0}
	S()["ending"] = choice
	S()["cards"] = cards(choice, ent)
	GameState.set_flag("legacy_chosen")
	GameState.timeline(I18n.t("Legacy choice: %s.") % I18n.t(ending_title(choice)), "milestone")
	StoryEngine.check()
	return {"ok": true}

static func ending_title(choice: String) -> String:
	return {"independent": "Keep building", "sale": "A change of ownership", "employees": "Built with the team", "mentor": "Make room for new founders"}.get(choice, "Legacy")

static func cards(choice: String, ent: String) -> Array:
	var employees := 0
	for entry in GameState.data["timeline"]:
		if entry["kind"] == "business" and (str(entry["text"]).begins_with(I18n.t("Hired %s as %s.").split("%s")[0]) or str(entry["text"]).begins_with("Hired %s as %s.".split("%s")[0])):
			employees += 1
	var regions := []
	for o in Ecommerce.E()["orders"].values():
		if o.has("delivered") and o.has("region") and not o["region"] in regions:
			regions.append(o["region"])
	var npcs := 0
	for id in DataDB.npcs:
		if GameState.flag("met_" + str(id)):
			npcs += 1
	var timeline: Array = GameState.data["timeline"]
	var history := ""
	for item in timeline.slice(maxi(0, timeline.size() - 5)):
		history += "• " + str(item["text"]) + "\n"
	var name := GameState.entity_name(ent) if ent != "" else I18n.t("Your founder journey")
	return [
		{"title": ending_title(choice), "lines": [I18n.t("Aurelia is still moving. Your ending opens free play; it does not manufacture a final profit."), CapitalMarket.route_text()]},
		{"title": "People along the way", "lines": [I18n.t("You met %d contacts and hired %d employees across your journey.") % [npcs, employees]]},
		{"title": "Your company", "lines": [name, I18n.t("Recorded deliveries reached %d overseas regions. Company cash now: %s home dollars.") % [regions.size(), Fmt.money(Ledger.cash(ent) if ent != "" else 0)], I18n.t({"independent": "You continue operating under the existing ownership. Previous investors and sales stay on the books.", "sale": "The ownership record is retained. A completed prior sale pays nothing again; without a live company there is no new sale.", "employees": "The board-approved team grant transfers existing shares. It creates no revenue or personal payout.", "mentor": "You mentor at Nexus Co-work. A live company uses a contract manager with monthly fees; after closure, there is no company to hand over."}[choice])]},
		{"title": "Your timeline", "lines": [history if history != "" else I18n.t("A new start is still a story.")]},
		{"title": "The next chapter is yours", "lines": [I18n.t("Return to free play and keep building from the actual books. Growth goals continue.")]}
	]

static func view_next() -> void:
	S()["viewed"] = mini(int(S()["cards"].size()), int(S()["viewed"]) + 1)
	if int(S()["viewed"]) == S()["cards"].size():
		GameState.set_flag("legacy_cards_viewed")
		GameState.set_flag("story_complete")
	StoryEngine.check()

static func comparison() -> InfoModal:
	var ls: Array = [I18n.t("90-day route comparison — explicit assumptions"), I18n.t("These are estimates from the current product cost and reference demand, not a second company or booked revenue. FX, duties, returns, rent and debt interest can reduce either result.")]
	var l := listing()
	if not l.is_empty():
		var p := DataDB.product(str(l["product"]))
		var loc := Ecommerce.best_location(str(l["product"]))
		var cost := Ecommerce.avg_cost(loc, str(l["product"])) if loc != "" else 0.0
		for route in ["niche", "scale"]:
			var price := clampf(float(l["price"]) * float(cfg()["niche_price_factor"] if route == "niche" else cfg()["scale_price_factor"]), float(p["price_min"]), float(p["price_max"]))
			var demand := float(p["base_daily_demand"]) * pow(float(p["ref_price"]) / price, float(cfg()["niche_elasticity"] if route == "niche" else cfg()["scale_elasticity"])) * float(cfg()["niche_demand_factor"] if route == "niche" else cfg()["scale_demand_factor"])
			var units := demand * int(cfg()["comparison_days"])
			var profit := units * (price * (1.0 - float(Ecommerce.mk().get("fee_rate", 0.1))) - cost - (float(p.get("packaging_cost", 0.5)) + Ecommerce.packaging_extra())) - (float(cfg()["brand_ad_fee"]) if route == "niche" else 0.0)
			ls.append([I18n.t("Niche" if route == "niche" else "Scale"), I18n.t("%.0f units · price %s home dollars/unit · estimated contribution %s home dollars before other costs") % [units, Fmt.money(price), Fmt.money(profit)]])
	return InfoModal.make("Compare consolidation routes", "company", ls, Vector2(480, 280))

static func on_hour() -> void:
	reconcile()
	var mgr: Dictionary = S()["manager"]
	if mgr.is_empty() or not GlobalMarket.live(str(mgr["entity"])):
		return
	if Clock.now() >= int(mgr["next_fee"]):
		var fee := float(cfg()["manager_monthly_fee"])
		Ledger.post(str(mgr["entity"]), I18n.t("Contract manager monthly fee: %s") % Fmt.money(fee), [{"acct": "exp:payroll", "dr": fee}, {"acct": "wages_payable", "cr": fee}], {"segment": "ecommerce", "type": "manager"})
		mgr["unpaid"] = float(mgr["unpaid"]) + fee
		mgr["next_fee"] = Clock.now() + int(cfg()["manager_fee_days"]) * Clock.DAY
	if float(mgr["unpaid"]) > 0 and Ledger.cash(str(mgr["entity"])) >= float(mgr["unpaid"]):
		Ledger.post(str(mgr["entity"]), "Contract manager fee paid", [{"acct": "wages_payable", "dr": mgr["unpaid"]}, {"acct": "cash", "cr": mgr["unpaid"]}], {"type": "manager"})
		mgr["unpaid"] = 0.0
	if float(mgr["unpaid"]) > 0 or int(mgr["last_day"]) == Clock.day_index() or Clock.hour() < 9:
		return
	mgr["last_day"] = Clock.day_index()
	var capacity := int(cfg()["manager_daily_parcels"])
	for loc in Ecommerce.stock_locations():
		for o in Ecommerce.orders_with(["placed"], str(loc)):
			var packing_cost := float(DataDB.product(str(o["product"])).get("packaging_cost", 0.5)) + Ecommerce.packaging_extra()
			if capacity <= 0 or Ledger.cash(str(mgr["entity"])) < packing_cost:
				break
			if Ecommerce.stock(str(loc), str(o["product"])) >= int(o["qty"]):
				capacity -= Ecommerce.pack_orders(str(loc), 1)
		if not Ecommerce.orders_with(["packed"], str(loc)).is_empty():
			Ecommerce.courier_pickup(str(loc), "economy")
