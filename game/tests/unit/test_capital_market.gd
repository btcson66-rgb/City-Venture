extends RefCounted
var runner
func setup() -> String:
	GameState.new_game({"name":"Market Founder","seed":93001})
	var ent: String = load("res://tests/unit/test_global.gd").new()._setup()
	CapitalMarket.begin()
	return ent
## Two annual batches are paid inventory and actual packed/courier/delivered retail trades, never a synthetic income entry.
func eligible() -> String:
	var ent := setup()
	var fixture = load("res://tests/unit/test_global.gd").new()
	for year in 2:
		GameState.data["clock"]["minutes"] = (year*365+120)*Clock.DAY
		var n := 250
		Ecommerce._add_stock("riverside_studio","wireless_earbuds",n,18,0)
		Ledger.post(ent,"QA paid stock batch",[{"acct":"inventory","dr":n*18},{"acct":"cash","cr":n*18}],{"type":"test_fixture"})
		var orders: Array = []
		for i in n: orders.append(fixture._order())
		Ecommerce.pack_orders("riverside_studio")
		Ecommerce.courier_pickup("riverside_studio","economy")
		for order in orders: Ecommerce._h_pickup({"ids":[order["id"]]})
		var eta := 0
		for order in orders: eta=maxi(eta,int(order["ship"]["eta"]))
		GameState.data["clock"]["minutes"]=eta
		for order in orders: Ecommerce._h_deliver({"order":order["id"]})
		GameState.data["clock"]["minutes"]+=3*Clock.DAY
		GlobalMarket.payout(ent)
		GlobalMarket.convert_currency(ent,"NRD")
	GameState.data["clock"]["minutes"]=740*Clock.DAY
	return ent
func audit() -> void:
	CapitalMarket.start_audit("nexus")
	GameState.data["clock"]["minutes"]=CapitalMarket.S()["ipo"]["ready"]
	CapitalMarket.progress_audit()
func listing() -> void:
	audit()
	for i in 3: CapitalMarket.answer(i,true)
	CapitalMarket.list_company()
func test_capital_valuation_bounds_and_growth_formula() -> void:
	setup()
	runner.eq(CapitalMarket.valuation(10000,10000),6000,"revenue multiple")
	runner.eq(CapitalMarket.valuation(13000,10000),10140,"capped growth premium")
	runner.eq(CapitalMarket.valuation(-100,10000),0,"no negative valuation")
	runner.eq(CapitalMarket.valuation(INF,0),0,"nonfinite blocked")
func test_multiple_offers_due_diligence_expiry_decline_and_actual_owner_payout() -> void:
	setup()
	runner.eq(CapitalMarket.S()["offers"].size(),3,"multiple independent offers")
	runner.check(not CapitalMarket.sell("vesper")["ok"],"due diligence cannot be skipped")
	GameState.data["clock"]["minutes"]=CapitalMarket.S()["offers"][1]["ready"]
	var before := Ledger.cash("player")
	var amount := float(CapitalMarket.S()["offers"][1]["price"])
	runner.check(CapitalMarket.sell("vesper")["ok"],"real founder sale")
	runner.eq(Ledger.cash("player"),before+amount,"founder cash paid")
	runner.eq(CapitalMarket.S()["buyer"],"Vesper Brands","chosen buyer recorded accurately")
	runner.check(not CapitalMarket.sell("hale")["ok"],"already sold cannot pay twice")
	runner.check(Ledger.check_balanced(),"ownership books balanced")
func test_offer_no_longer_possible_and_private_already_done_are_not_soft_locks() -> void:
	setup()
	GameState.data["clock"]["minutes"]+=31*Clock.DAY
	runner.check(not CapitalMarket.sell("hale")["ok"],"expired offer no payout")
	runner.check(CapitalMarket.private_route()["ok"],"private escape")
	var count: int = GameState.data["timeline"].size()
	CapitalMarket.private_route()
	runner.eq(GameState.data["timeline"].size(),count,"private receipt idempotent")
	Insolvency.close_company()
	runner.check(not CapitalMarket.start_audit("nexus")["ok"],"closed company cannot audit")
	runner.check(CapitalMarket.private_route()["ok"],"closed company still continues")
func test_npc_merger_and_player_integration_move_assets_not_income() -> void:
	var ent := setup()
	var before := float(MonthClose.current(ent)["net_revenue"])
	var buy := CapitalMarket.acquire("vesper")
	runner.check(buy["ok"],"company purchase")
	if not buy["ok"]: return
	runner.check(Ledger.balance(ent,"investments")>0,"owned company asset")
	runner.eq(MonthClose.current(ent)["net_revenue"],before,"ownership never fabricated sales")
	runner.check(not CapitalMarket.acquire("vesper")["ok"],"already bought blocked")
	GameState.data["clock"]["minutes"]+=15*Clock.DAY
	CapitalMarket.on_hour()
	runner.eq(CapitalMarket.S()["targets"]["meridian"]["owner"],"hale","NPC-to-NPC merger")
	runner.check(CapitalMarket.S()["integrations"][0]["done"],"integration completes")
	runner.check(int(CapitalMarket.S()["targets"]["vesper"]["staff"])<3,"acquired staff attrition")
	runner.check(Ledger.check_balanced(),"investment and systems fee balance")
func test_ipo_actual_two_year_trades_underwriter_fee_time_and_dilution() -> void:
	var ent := eligible()
	runner.eq(CapitalMarket.ipo_block(),"","actual two profitable annual batches")
	var before := Ledger.cash(ent)
	runner.check(CapitalMarket.start_audit("nexus")["ok"],"paid audit starts")
	runner.eq(Ledger.cash(ent),before-500,"audit cost actual")
	runner.check(not CapitalMarket.start_audit("harbor")["ok"],"audit already running")
	runner.check(not CapitalMarket.progress_audit()["ok"],"audit time cannot skip")
	GameState.data["clock"]["minutes"]=CapitalMarket.S()["ipo"]["ready"]
	runner.check(CapitalMarket.progress_audit()["ok"],"audit completed")
	for i in 3: runner.check(CapitalMarket.answer(i,true)["ok"],"real investor answer")
	runner.check(not CapitalMarket.answer(2,true)["ok"],"answer receipt cannot repeat")
	var revenue := float(MonthClose.current(ent)["net_revenue"])
	var result := CapitalMarket.list_company()
	runner.check(result["ok"],"listing actual equity subscription")
	runner.eq(GameState.data["cap_table"]["founder"],.8,"founder diluted")
	runner.eq(GameState.data["cap_table"]["public"],.2,"public ownership")
	runner.eq(MonthClose.current(ent)["net_revenue"],revenue,"capital not income")
	runner.check(not CapitalMarket.list_company()["ok"],"already listed cannot reissue")
	runner.check(Ledger.check_balanced(),"listing fees and cash balance")
func test_audit_failure_and_unsupported_roadshow_leave_private_path_available() -> void:
	var ent := eligible()
	CapitalMarket.start_audit("harbor")
	Ledger.expense(ent,"penalties",1,"QA compliance fine")
	GameState.data["clock"]["minutes"]=CapitalMarket.S()["ipo"]["ready"]
	runner.check(not CapitalMarket.progress_audit()["ok"],"failed audit retains fee")
	runner.eq(CapitalMarket.S()["ipo"]["stage"],"failed","auditor failure receipt")
	runner.check(CapitalMarket.private_route()["ok"],"failed audit escape")
	eligible()
	audit()
	for i in 3: CapitalMarket.answer(i,false)
	runner.eq(CapitalMarket.S()["ipo"]["stage"],"failed","unsupported promises rejected")
	runner.check(not CapitalMarket.list_company()["ok"],"failure cannot list")
	runner.check(CapitalMarket.private_route()["ok"],"roadshow failure escape")
func test_quarterly_actual_shortfall_price_reputation_morale_decay_and_board_votes() -> void:
	eligible()
	listing()
	Staff.S()["people"]["QA"]={"id":"QA","morale":70}
	var ipo: Dictionary = CapitalMarket.S()["ipo"]
	var before := float(ipo["price"])
	GameState.data["clock"]["minutes"]=ipo["next_quarter"]
	CapitalMarket.on_hour()
	runner.check(float(ipo["price"])<before,"actual zero sales quarter drops price")
	runner.eq(Staff.people()[0]["morale"],62,"actual team morale hit")
	runner.check(CapitalMarket.demand_factor()<1,"reputation affects actual demand")
	runner.eq(CapitalMarket.S()["quarter_reports"].size(),1,"quarter once")
	CapitalMarket.on_hour()
	runner.eq(CapitalMarket.S()["quarter_reports"].size(),1,"no duplicate reporting")
	GameState.data["cap_table"]={"founder":.3,"public":.7}
	runner.check(not CapitalMarket.board_approve(Ledger.cash(GameState.company_id())),"majority rejects excessive commitment")
	runner.check(CapitalMarket.board_approve(1),"majority supports measured commitment")
	GameState.data["clock"]["minutes"]=CapitalMarket.S()["pressure"]["until"]
	CapitalMarket.on_hour()
	runner.eq(Staff.people()[0]["morale"],70,"temporary crisis hit actually recovers")
	runner.eq(CapitalMarket.demand_factor(),1,"reputation pressure expires")
func test_owned_context_old_save_reload_and_next_company_do_not_inherit_public_obligations() -> void:
	setup()
	CapitalMarket.private_route()
	SaveSystem.save(93)
	SaveSystem.load_data(93)
	runner.eq(CapitalMarket.S()["route"],"private","ownership receipt save/load")
	GameState.data.erase("capital_market")
	runner.eq(CapitalMarket.S()["route"],"","old save lazy default")
	CapitalMarket.begin()
	Insolvency.close_company()
	runner.check(not CapitalMarket.acquire("vesper")["ok"],"closed company no stale acquisitions")
	Company.register("Fresh Market","retail_online","22 Founders Lane")
	Company.open_business_account(1000)
	CapitalMarket.begin()
	runner.eq(CapitalMarket.S()["route"],"","new company clean ownership route")
func test_legacy_route_changes_have_distinct_scores_and_epilogues() -> void:
	setup()
	for route in ["public","acquired","private"]:
		CapitalMarket.S()["route"]=route
		var scores := LifeLegacy.scores({})
		runner.eq(scores[0]["id"],{"public":"builder","acquired":"quiet_owner","private":"innovator"}[route],"route shifts transmission formula")
		runner.check(CapitalMarket.route_text()!="","route tradeoffs recorded")

func test_renewed_offer_round_keeps_acquired_targets_and_prior_sales_truthful() -> void:
	setup()
	CapitalMarket.acquire("vesper")
	GameState.data["clock"]["minutes"]+=31*Clock.DAY
	CapitalMarket.begin()
	runner.check(CapitalMarket.S()["targets"]["vesper"].has("owner"),"renewal cannot restore bought company for second purchase")
	runner.check(int(CapitalMarket.S()["offers"][0]["expires"])>Clock.now(),"new live proposal round")
	GameState.set_flag("company_sold")
	CapitalMarket.begin()
	runner.eq(CapitalMarket.S()["route"],"acquired","old share sale never labelled privately owned")

func test_public_board_grant_vote_and_roadshow_both_choices_visible() -> void:
	eligible()
	audit()
	var modal := CapitalMarketModal.new()
	modal.body=UIK.vbox()
	modal.add_child(modal.body)
	modal.build()
	runner.check(modal.find_child("RoadshowTransparent",true,false)!=null and modal.find_child("RoadshowPromise",true,false)!=null,"two distinct investor choices")
	modal.free()
	for i in 3: CapitalMarket.answer(i,true)
	CapitalMarket.list_company()
	GameState.data["cap_table"]={"founder":.3,"public":.7}
	GameState.set_flag("legacy_met_maya")
	runner.check(LegacyBusiness.ending_block("employees")!="","minority founder cannot force public dilution")
	GameState.data["cap_table"]={"founder":.8,"public":.2}
	runner.check(CapitalMarket.board_grant_approve(),"majority founder can approve grant")

func test_audit_and_roadshow_can_be_withdrawn_without_refunding_paid_fees() -> void:
	var ent := eligible()
	CapitalMarket.start_audit("nexus")
	var cash := Ledger.cash(ent)
	CapitalMarket.private_route()
	runner.eq(CapitalMarket.S()["ipo"]["stage"],"withdrawn","audit voluntary withdrawal")
	runner.eq(Ledger.cash(ent),cash,"paid work is not refunded")
	runner.check(not CapitalMarket.progress_audit()["ok"],"withdrawn audit cannot unexpectedly complete")
	CapitalMarket.start_audit("harbor")
	GameState.data["clock"]["minutes"]=CapitalMarket.S()["ipo"]["ready"]
	CapitalMarket.progress_audit()
	CapitalMarket.private_route()
	runner.eq(CapitalMarket.S()["ipo"]["stage"],"withdrawn","roadshow voluntary withdrawal")
	runner.check(not CapitalMarket.answer(0,true)["ok"],"withdrawn question no soft lock")

func test_withdrawals_after_quote_cannot_mint_sale_or_ipo_windfalls() -> void:
	var ent := setup()
	var offer: Dictionary = CapitalMarket.S()["offers"][0]
	var before := float(offer["price"])
	Company.transfer(ent,"player",5000)
	GameState.data["clock"]["minutes"]=offer["ready"]
	runner.check(CapitalMarket.final_offer_price(offer)<before,"post-quote withdrawal reduces actual consideration")
	eligible()
	audit()
	for i in 3: CapitalMarket.answer(i,true)
	ent=GameState.company_id()
	Company.transfer(ent,"player",5000)
	runner.check(not CapitalMarket.list_company()["ok"],"stale IPO valuation cannot issue capital")
	runner.eq(CapitalMarket.S()["ipo"]["stage"],"failed","failed pricing restores private/reapply choices")
	runner.check(CapitalMarket.private_route()["ok"],"stale pricing never traps the company")
