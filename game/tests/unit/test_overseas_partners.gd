extends RefCounted
## Actual collateral, exports, warehouse stock and alternatives; no simulated income is awarded by story flags.

var runner


func _setup() -> String:
	var f = load("res://tests/unit/test_global.gd").new()
	var ent: String = f._setup()
	GlobalMarket.open_store("auroria")
	GlobalMarket.set_price("auroria", str(Ecommerce.listing_for("wireless_earbuds")["id"]), 60)
	GameState.set_flag("met_omar")
	# Forwards hedge only booked foreign money: hold a real wallet balance carried at its historical value.
	var book := snappedf(500.0 * FX.rate("AUR"), 0.01)
	Ledger.post(ent, "QA booked foreign receipts", [{"acct": "fx_wallet:AUR", "dr": book}, {"acct": "equity", "cr": book}], {"type": "test_fixture"})
	GlobalMarket.balance(ent, "AUR")["wallet"] = 500.0
	return ent


func _contract() -> Dictionary:
	var r := OverseasPartners.distributor_offer()
	runner.check(r["ok"], "real distributor offer")
	Contracts.accept(str(r["id"]))
	return Contracts.C()[r["id"]]


func _deliver(c: Dictionary) -> void:
	var r := Contracts.deliver(str(c["id"]))
	runner.check(r["ok"], "dispatch accepted")
	GameState.data["clock"]["minutes"] = int(c["eta"])
	Contracts.handle("con.partner_arrive", {"id": c["id"]})


func _warehouse() -> void:
	runner.check(OverseasPartners.open_warehouse()["ok"], "warehouse opened")
	runner.check(OverseasPartners.transfer("wireless_earbuds", 10)["ok"], "real sea batch")
	var t: Dictionary = OverseasPartners.company()["transfers"][0]
	GameState.data["clock"]["minutes"] = int(t["eta"])
	OverseasPartners.handle("partners.arrive", {"entity": GameState.company_id(), "index": 0})


func test_forward_depreciation_gain_and_appreciation_loss_are_real_and_once() -> void:
	var ent := _setup()
	var quote := FXForward.quote("AUR", 100, 30)
	var initial := Ledger.cash(ent)
	var r := FXForward.open("AUR", 100, 30)
	runner.check(r["ok"], "receipts can be hedged")
	var f: Dictionary = FXForward.S()["items"][r["id"]]
	runner.eq(Ledger.cash(ent), snappedf(initial - float(quote["fee"]) - float(quote["collateral"]), 0.01), "fee and collateral actually deducted")
	FX.S()["rates"]["AUR"] = float(f["rate"]) * 0.8
	GameState.data["clock"]["minutes"] = int(f["due"])
	runner.eq(FXForward.settle(str(f["id"]))["gain_loss"], 17, "selling at locked 0.85 versus 0.68 gives 17 home dollars")
	var after := Ledger.cash(ent)
	runner.check(not FXForward.settle(str(f["id"]))["ok"], "settlement idempotent")
	runner.eq(Ledger.cash(ent), after, "no double payout")
	var second := FXForward.open("AUR", 100, 60)
	var f2: Dictionary = FXForward.S()["items"][second["id"]]
	FX.S()["rates"]["AUR"] = float(f2["rate"]) * 1.2
	GameState.data["clock"]["minutes"] = int(f2["due"])
	runner.eq(FXForward.settle(str(f2["id"]))["gain_loss"], -13.6, "stronger currency causes hedge loss")
	runner.eq(Ledger.balance(ent, "deposits"), 0, "all collateral released")
	runner.check(Ledger.check_balanced(), "both directions balance")


func test_forward_rejects_speculation_nonfinite_short_cash_and_early_payment() -> void:
	var ent := _setup()
	for amount in [NAN, INF, 0, 0.01, 10000000]:
		runner.check(not FXForward.open("AUR", amount, 30)["ok"], "notional bounded to positive real exposure")
	runner.check(not FXForward.open("AUD", 100, 30)["ok"], "home currency is not a foreign hedge")
	runner.check(not FXForward.open("AUR", 100, 1)["ok"], "unsupported maturity rejected")
	var r := FXForward.open("AUR", 100, 30)
	runner.check(not FXForward.settle(str(r["id"]))["ok"], "cannot cash out before maturity")
	Company.transfer(ent, "player", Ledger.cash(ent))
	runner.check(not FXForward.open("AUR", 100, 60)["ok"], "cash must fund fee and collateral")


func test_forward_json_restore_and_company_closure_release_collateral_once() -> void:
	var ent := _setup()
	var r := FXForward.open("AUR", 100, 30)
	GameState.data["fx_forwards"] = JSON.parse_string(JSON.stringify(FXForward.S()))
	OverseasPartners.close_for_entity(ent)
	var cash := Ledger.cash(ent)
	OverseasPartners.close_for_entity(ent)
	runner.eq(Ledger.cash(ent), cash, "closure settlement is once after save round trip")
	runner.eq(FXForward.S()["items"][r["id"]]["status"], "settled", "closure does not strand collateral")
	runner.check(Ledger.check_balanced(), "closure balances")


func test_fx_shock_is_once_and_temporary_and_repricing_must_change_price() -> void:
	_setup()
	var before := FX.rate("AUR")
	OverseasPartners.begin("ch15_currency_swing")
	runner.eq(FX.rate("AUR"), snappedf(before * 0.88, 0.000001), "actual twelve-percent drop")
	OverseasPartners.begin("ch15_currency_swing")
	runner.eq(FX.rate("AUR"), snappedf(before * 0.88, 0.000001), "no repeated drop on old-save begin")
	GlobalMarket.set_price("auroria", str(Ecommerce.listing_for("wireless_earbuds")["id"]), 60)
	runner.check(not GameState.flag("fx_response_reprice"), "saving an unchanged price is not a response")
	GlobalMarket.set_price("auroria", str(Ecommerce.listing_for("wireless_earbuds")["id"]), 65)
	runner.check(GameState.flag("fx_response_reprice"), "actual repricing counted")
	FX.on_day(Clock.day_index() + 8)
	runner.check(FX.S()["shocks"].is_empty(), "crisis volatility expires")


func test_distributor_cycle_books_no_revenue_before_arrival_and_real_fx_payment() -> void:
	var ent := _setup()
	var c := _contract()
	runner.eq(c["invoice_currency"], GlobalMarket.currency("lumina"), "default overseas invoice currency")
	Contracts.deliver(str(c["id"]))
	runner.eq(c["status"], "shipped", "international goods travel first")
	runner.eq(Ledger.balance(ent, "accounts_receivable"), 0, "no fictitious immediate invoice")
	runner.eq(Ledger.balance(ent, "revenue"), 0, "not delivered yet")
	GameState.data["clock"]["minutes"] = int(c["eta"])
	Contracts.handle("con.partner_arrive", {"id": c["id"]})
	var book := float(c["receivable"])
	runner.check(book > 0, "arrival earns actual invoice")
	FX.S()["rates"][c["invoice_currency"]] *= 0.9
	GameState.data["clock"]["minutes"] = int(c["pay_due"])
	Contracts.handle("con.pay", {"id": c["id"]})
	OverseasPartners.reconcile()
	runner.eq(c["status"], "paid", "actual invoice collected")
	runner.check(GameState.flag("lumina_channel_income"), "income receipt follows payment")
	runner.check(Ledger.balance(ent, "fx_gain_loss") > 0, "currency drop books a realized loss")
	var cash := Ledger.cash(ent)
	Contracts.handle("con.pay", {"id": c["id"]})
	runner.eq(Ledger.cash(ent), cash, "no double collection")
	runner.check(Ledger.check_balanced(), "distributor FX cycle balances")


func test_distributor_wholesale_margin_and_home_currency_tradeoff() -> void:
	_setup()
	var first := OverseasPartners.distributor_offer()
	var foreign: Dictionary = Contracts.C()[first["id"]]
	runner.eq(foreign["unit_price"], 33, "55 percent of actual 60 retail price")
	Contracts.reject(str(foreign["id"]))
	OverseasPartners.choose_home_invoices()
	var offer := {}
	for i in 10:
		offer = OverseasPartners.distributor_offer()
		if offer["ok"]:
			break
		GameState.data["clock"]["minutes"] += Clock.DAY
	runner.check(offer["ok"], "reasonable home-currency quote remains obtainable")
	var home: Dictionary = Contracts.C()[offer["id"]]
	runner.eq(home["invoice_currency"], "AUD", "only future contract changes currency")
	runner.eq(foreign["invoice_currency"], GlobalMarket.currency("lumina"), "earlier foreign invoice unchanged")
	runner.check(home["unit_price"] < foreign["unit_price"], "buyer risk costs a price concession")
	runner.check(float(OverseasPartners.cfg()["home_invoice_acceptance"]) < 1, "acceptance is lower")
	Contracts.accept(str(home["id"]))
	_deliver(home)
	Contracts.handle("con.pay", {"id": home["id"]})
	runner.check(-Ledger.balance(GameState.company_id(), "revenue") - Ledger.balance(GameState.company_id(), "cogs") - Ledger.balance(GameState.company_id(), "exp:shipping") - Ledger.balance(GameState.company_id(), "exp:compliance") > 0, "reasonable wholesale strategy can earn a margin")


func test_warehouse_batch_ledger_monthly_rent_and_capacity() -> void:
	var ent := _setup()
	_warehouse()
	var loc := OverseasPartners.warehouse_location()
	runner.eq(Ecommerce.stock(loc, "wireless_earbuds"), 10, "stock physically arrives overseas")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 10, "domestic stock not duplicated")
	runner.eq(Ledger.balance(ent, "inventory_in_transit"), 0, "arrival clears transit asset")
	var before := Ledger.balance(ent, "exp:rent_warehouse")
	OverseasPartners.company()["warehouse"]["last_month"] = "old"
	OverseasPartners.on_hour()
	runner.eq(Ledger.balance(ent, "exp:rent_warehouse") - before, 6.5, "monthly rent is ten units times 0.65")
	OverseasPartners.on_hour()
	runner.eq(Ledger.balance(ent, "exp:rent_warehouse") - before, 6.5, "no duplicate monthly charge")
	runner.check(not OverseasPartners.transfer("wireless_earbuds", 1000)["ok"], "capacity and stock bounds enforced")
	runner.check(Ledger.check_balanced(), "warehouse movement balances")


func test_warehouse_orders_use_local_stock_and_real_shipping_not_domestic_inventory() -> void:
	_setup()
	_warehouse()
	var l := Ecommerce.listing_for("wireless_earbuds")
	runner.check(GlobalMarket.set_price("lumina", str(l["id"]), 60 / FX.rate(GlobalMarket.currency("lumina")))["ok"], "valid local-unit price")
	Ecommerce._h_order_place({"listing": l["id"], "region": "lumina"})
	var o: Dictionary = Ecommerce.E()["orders"]["#%d" % int(Ecommerce.E()["counters"]["order"])]
	runner.eq(o["location"], OverseasPartners.warehouse_location(), "Lumina orders use Lumina stock")
	runner.eq(o["status"], "shipped", "3PL actually packs and ships")
	runner.eq(int(o["ship"]["eta"]) - Clock.now(), 2 * Clock.DAY, "local delivery uses two days")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 10, "domestic stock remains available to domestic buyers")
	runner.eq(Ecommerce.best_location("wireless_earbuds"), "riverside_studio", "domestic orders do not pull overseas stock")
	runner.check(Ledger.check_balanced(), "auto fulfilment balances")


func test_warehouse_slow_stock_clearance_is_real_contract_and_closure_cancels_transit() -> void:
	var ent := _setup()
	_warehouse()
	runner.check(not OverseasPartners.distributor_offer("wireless_earbuds", true)["ok"], "clearance waits for slow-stock review")
	GameState.data["clock"]["minutes"] += 45 * Clock.DAY
	var offer := OverseasPartners.distributor_offer("wireless_earbuds", true)
	runner.check(offer["ok"], "remaining warehouse goods can be sold to Omar")
	Contracts.accept(str(offer["id"]))
	var c: Dictionary = Contracts.C()[offer["id"]]
	_deliver(c)
	runner.eq(Ecommerce.stock(OverseasPartners.warehouse_location(), "wireless_earbuds"), 0, "clearance consumes overseas goods")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 10, "clearance cannot replace goods with domestic stock")
	OverseasPartners.transfer("wireless_earbuds", 5)
	OverseasPartners.close_for_entity(ent)
	GameState.data["entities"][ent]["closed"] = Clock.now()
	var t: Dictionary = OverseasPartners.company(ent)["transfers"][-1]
	GameState.data["clock"]["minutes"] = int(t["eta"])
	OverseasPartners.handle("partners.arrive", {"entity": ent, "index": t["index"]})
	runner.eq(t["status"], "cancelled", "closed company has no later arrival")
	runner.eq(Ecommerce.stock(OverseasPartners.warehouse_location(ent), "wireless_earbuds"), 0, "no resurrection of liquidated goods")


func test_flight_charges_each_way_and_video_is_free_alternative() -> void:
	var ent := _setup()
	var cash := Ledger.cash(ent)
	var time := Clock.now()
	runner.check(OverseasPartners.travel(ent)["ok"], "actual paid outbound trip")
	runner.eq(Clock.now() - time, Clock.DAY, "journey advances a full business day")
	runner.check(not OverseasPartners.travel(ent)["ok"], "no duplicate outbound trip")
	runner.check(OverseasPartners.travel(ent, true)["ok"], "actual return trip")
	runner.check(Ledger.balance(ent, "exp:transport") >= 840, "both tickets charged")
	Company.transfer(ent, "player", Ledger.cash(ent))
	runner.check(not OverseasPartners.travel(ent)["ok"], "unaffordable travel rejected")
	OverseasPartners.contact_omar()
	runner.check(GameState.flag("met_omar"), "free video contact still possible")
	runner.check(Ledger.check_balanced(), "flight books balance")
	var _unused := cash


func test_both_chapters_early_receipts_drain_and_closed_company_has_no_fake_income() -> void:
	var ent := _setup()
	for flag in ["fx_news_read", "met_marcus_fx", "fx_response_home", "fx_month_viewed"]:
		GameState.set_flag(str(flag))
	StoryEngine.start_chapter("ch15_currency_swing")
	StoryEngine.check()
	runner.check("ch15_currency_swing" in StoryEngine.St()["chapters_done"], "all early chapter15 receipts drain")
	GameState.data["entities"][ent]["closed"] = Clock.now()
	StoryEngine.check()
	runner.check("ch16_partner_overseas" in StoryEngine.St()["chapters_done"], "chapter16 impossible transactions skip")
	runner.check(not GameState.flag("lumina_channel_income"), "closure does not forge partner income")


func test_chapter16_already_paid_receipt_completes_and_unsuccessful_review_is_honest() -> void:
	_setup()
	var c := _contract()
	_deliver(c)
	Contracts.handle("con.pay", {"id": c["id"]})
	StoryEngine.start_chapter("ch16_partner_overseas")
	StoryEngine.check()
	runner.check("ch16_partner_overseas" in StoryEngine.St()["chapters_done"], "earlier real paid contract recognized")
	GameState.set_flag("lumina_channel_income", false)
	OverseasPartners.S()["chapters"]["ch16_partner_overseas"]["started"] = Clock.now() - 45 * Clock.DAY
	OverseasPartners.review()
	runner.check(GameState.flag("ch16_reviewed"), "unsuccessful expansion can be reviewed")
	var ent := GameState.company_id()
	GameState.data["entities"][ent]["closed"] = Clock.now()
	OverseasPartners.begin("ch15_currency_swing")
	OverseasPartners.reconcile()
	runner.check(GameState.flag("ch15_currency_swing_unavailable"), "chapter15 impossible after closure")


func test_distributor_counter_preserves_quote_and_cannot_accelerate_fx_invoice() -> void:
	_setup()
	var offer := OverseasPartners.distributor_offer()
	var c: Dictionary = Contracts.C()[offer["id"]]
	var r := Contracts.counter(str(c["id"]), 33, 7, 0)
	runner.check(r["ok"], "valid counter evaluated")
	runner.eq(c["foreign_total"], snappedf(float(c["total"]) / FX.rate(str(c["invoice_currency"])), 0.01), "agreed counter keeps foreign invoice consistent")
	runner.check(not Contracts.counter(str(c["id"]), 33, 7, 0.3)["ok"], "advance cannot bypass overseas delivery accounting")
	Contracts.accept(str(c["id"]))
	Contracts.deliver(str(c["id"]))
	runner.eq(OverseasPartners.distributor_offer()["id"], c["id"], "in-transit contract cannot be duplicated")
	runner.check(not Contracts.early_payment(str(c["id"]))["ok"], "foreign invoice not cashed through domestic early-payment route")
	runner.check(Ledger.check_balanced(), "counter and dispatch balance")


func test_actual_company_closure_clears_overseas_inventory_transit_and_forwards() -> void:
	var ent := _setup()
	_warehouse()
	var c := _contract()
	Contracts.deliver(str(c["id"]))
	FXForward.open("AUR", 100, 30)
	# No domestic stock remains after dispatch; add an explicit paid test batch.
	Ecommerce._add_stock("riverside_studio", "wireless_earbuds", 5, 18, 0)
	Ledger.post(ent, "Test replacement stock", [{"acct": "inventory", "dr": 90}, {"acct": "cash", "cr": 90}])
	OverseasPartners.transfer("wireless_earbuds", 5)
	Insolvency.state()["entity"] = ent
	runner.check(Insolvency.close_company()["ok"], "actual liquidation")
	for account in ["inventory", "inventory_in_transit", "goods_out", "deposits"]:
		runner.eq(Ledger.balance(ent, account), 0, "closure clears " + account)
	runner.eq(Ecommerce.stock(OverseasPartners.warehouse_location(ent), "wireless_earbuds"), 0, "warehouse liquidated")
	var cash := Ledger.cash(ent)
	OverseasPartners.close_for_entity(ent)
	runner.eq(Ledger.cash(ent), cash, "no second closure settlement")
	runner.check(Ledger.check_balanced(), "actual closure balanced")


func test_both_chapters_no_longer_possible_without_company_and_old_save_initialization() -> void:
	GameState.new_game({"name": "Closure", "seed": 42})
	GameState.data.erase("fx_forwards")
	GameState.data.erase("overseas_partners")
	GameState.data = SaveSystem._migrate(GameState.data)
	runner.check(FXForward.S().has("items") and OverseasPartners.S().has("chapters"), "lazy keys after old-save migration")
	StoryEngine.start_chapter("ch15_currency_swing")
	StoryEngine.check()
	runner.check("ch15_currency_swing" in StoryEngine.St()["chapters_done"] and "ch16_partner_overseas" in StoryEngine.St()["chapters_done"], "all objectives unavailable without bound company")
	runner.check(not GameState.flag("lumina_channel_income"), "no fake income on unavailable branch")


func test_distributor_scenarios_average_profit_and_cost_stress_losses() -> void:
	var rows: Array = []
	for home in [false, true]:
		var total_profit := 0.0
		var losses := 0
		for index in 6:
			GameState.new_game({"name": "Balance", "seed": 4242 + index})
			var ent := _setup()
			var period_start := Clock.now() + 1
			GameState.data["clock"]["minutes"] += 1
			if home:
				OverseasPartners.choose_home_invoices()
			if index == 0:
				Ecommerce.inv("riverside_studio")["wireless_earbuds"]["avg_cost"] = 34
				Ledger.post(ent, "Cost stress fixture", [{"acct": "inventory", "dr": 320}, {"acct": "cash", "cr": 320}])
			var offer := {}
			for attempt in 10:
				offer = OverseasPartners.distributor_offer()
				if offer["ok"]:
					break
				GameState.data["clock"]["minutes"] += Clock.DAY
			runner.check(offer["ok"], "quote obtained after real retry")
			var c: Dictionary = Contracts.C()[offer["id"]]
			Contracts.accept(str(c["id"]))
			Contracts.deliver(str(c["id"]))
			FX.S()["rates"][GlobalMarket.currency("lumina")] *= [0.45, 0.8, 0.95, 1.0, 1.1, 1.2][index]
			GameState.data["clock"]["minutes"] = int(c["eta"])
			Contracts.handle("con.partner_arrive", {"id": c["id"]})
			GameState.data["clock"]["minutes"] = int(c["pay_due"])
			Contracts.handle("con.pay", {"id": c["id"]})
			var profit := float(MonthClose.compute(ent, period_start, Clock.now() + 1)["business_profit"])
			total_profit += profit
			if profit < 0:
				losses += 1
			rows.append({"home_invoice": home, "scenario": index, "profit_home_dollars": profit, "collected": c["status"] == "paid"})
			runner.check(Ledger.check_balanced(), "scenario accounting balanced")
		runner.check(total_profit / 6 > 0, "sensible distributor strategy profits on average")
		runner.check(losses > 0, "cost/FX stress can lose for either invoice strategy")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--balance-out="):
			var file := FileAccess.open(argument.trim_prefix("--balance-out="), FileAccess.WRITE)
			file.store_string(JSON.stringify({"scope": "12 controlled operating cycles after setup; excludes initial bank opening and is not a 120-day economy soak", "scenarios": rows}, "  "))


func test_industry_merge_reports_realized_fx_and_keeps_overseas_destinations() -> void:
	var ent := _setup()
	var r := FXForward.open("AUR", 100, 30)
	var f: Dictionary = FXForward.S()["items"][r["id"]]
	FX.S()["rates"]["AUR"] = float(f["rate"]) * 0.8
	GameState.data["clock"]["minutes"] = int(f["due"])
	FXForward.settle(str(f["id"]))
	var report := MonthClose.compute(ent, 0, Clock.now() + 1)
	runner.eq(report["segments"]["totals"]["operating_profit"], report["business_profit"], "realized FX is included exactly once in segment and company totals")
	runner.check(BuildingInfo.world_travel_available(), "global banking keeps overseas information accessible")
	runner.eq(BuildingInfo.icon_for("customs_guide"), "info", "customs guidance registers its existing icon")

func test_home_invoice_rejection_has_cooldown_and_fresh_offer_without_phantom_income() -> void:
	_setup()
	OverseasPartners.choose_home_invoices()
	var seed_value := 0
	for candidate in range(1, 100):
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if probe.randf() > float(OverseasPartners.cfg()["home_invoice_acceptance"]):
			seed_value = candidate
			break
	GameState.rng.seed = seed_value
	var cash := Ledger.cash(GameState.company_id())
	var contracts_before := Contracts.C().size()
	var rejected := OverseasPartners.distributor_offer()
	runner.check(not rejected["ok"], "actual buyer can reject home-currency exposure")
	runner.eq(Contracts.C().size(), contracts_before, "rejection creates no contract")
	runner.eq(Ledger.cash(GameState.company_id()), cash, "rejection creates no cash or revenue")
	runner.check(not OverseasPartners.distributor_offer()["ok"], "same-day retry cannot bypass cooldown")
	var accepted := false
	for retry in 20:
		GameState.data["clock"]["minutes"] = int(OverseasPartners.company()["next_offer"])
		var quote := OverseasPartners.distributor_offer()
		if quote["ok"]:
			accepted = true
			break
	runner.check(accepted, "actual fresh-day offer is obtainable after rejection")
	runner.check(Ledger.check_balanced(), "rejection and retry preserve real books")
	print("home-invoice rejection fixture seed: ", seed_value)
