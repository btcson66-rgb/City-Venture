extends RefCounted
var runner
func setup() -> void:
	Company.register("Trade Test","international_trade","Meridian");Company.open_business_account(20000)
	Ledger.post(GameState.company_id(),"QA trade capital",[{"acct":"cash","dr":100000},{"acct":"equity","cr":100000}])
	runner.check(TradeIndustry.register()["ok"],"actual registration fee")
	runner.check(Living.lease("meridian_trade_office")["ok"],"paid office lease")
	runner.check(TradeIndustry.start()["ok"],"registered office starts")
func quote(payment: String="lc") -> Dictionary:return TradeQuote.sheet("aurelia","northridge","wireless_earbuds",50,"CIF","sea",payment,true,.3)
func depart(d: Dictionary) -> void:
	GameState.data["clock"]["minutes"]=d["depart"]
	TradeIndustry.handle("trade.depart",{"id":d["id"]})
	if d["status"]=="delayed":
		GameState.data["clock"]["minutes"]=d["resume"]
		TradeIndustry.handle("trade.resume",{"id":d["id"]})
func test_registration_signs_actual_shared_job_and_paid_cargo() -> void:
	setup();var before:=Ledger.cash(GameState.company_id());var r:=TradeIndustry.sign(quote())
	runner.check(r["ok"],"competitive actual quote")
	if not r["ok"]:return
	var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	runner.eq(Jobs.get_job(d["job"])["status"],"active","shared job active")
	runner.eq(d["supplier_receipt"]["units"],50,"real regional supplier units")
	runner.check(Ledger.cash(GameState.company_id())<before,"supplier paid")
	runner.eq(Ledger.balance(GameState.company_id(),"revenue"),0.0,"no signature revenue")
	runner.check(Ledger.check_balanced(),"actual purchase balanced")
func test_missing_documents_hold_charge_rent_and_withdraw_without_income() -> void:
	setup();var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	TradeIndustry.set_document(d["id"],"packing_list",false);depart(d)
	runner.eq(d["status"],"customs_hold","document hold")
	runner.check(not TradeIndustry.clear(d["id"])["ok"],"cannot clear incomplete papers")
	var before:=Ledger.cash(GameState.company_id());TradeIndustry.on_hour(Clock.now(),0)
	runner.check(Ledger.cash(GameState.company_id())<before,"actual storage expense")
	var after:=Ledger.cash(GameState.company_id());TradeIndustry.on_hour(Clock.now(),0)
	runner.eq(Ledger.cash(GameState.company_id()),after,"same day rent idempotent")
	runner.check(TradeIndustry.withdraw(d["id"])["ok"],"paid cargo supplier return")
	runner.check(not TradeIndustry.withdraw(d["id"])["ok"],"cannot refund twice")
	runner.eq(Ledger.balance(GameState.company_id(),"goods_out"),0.0,"cargo derecognized")
	runner.eq(Ledger.balance(GameState.company_id(),"revenue"),0.0,"return not income")
	runner.check(Ledger.check_balanced(),"withdrawal balanced")
func test_letter_of_credit_requires_documents_and_payment_follows_delivery() -> void:
	setup();var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	TradeIndustry.set_document(d["id"],"invoice",false)
	runner.check(not TradeIndustry.bank_documents(d["id"])["ok"],"bank refuses incomplete documents")
	TradeIndustry.set_document(d["id"],"invoice",true)
	runner.check(TradeIndustry.bank_documents(d["id"])["ok"],"bank accepts actual papers")
	runner.check(not TradeIndustry.bank_documents(d["id"])["ok"],"bank receipt once")
	depart(d)
	if d["status"]=="lost":
		runner.check(Ledger.check_balanced(),"actual supplier failure is allowed");return
	GameState.data["clock"]["minutes"]=d["eta"];TradeIndustry.handle("trade.arrive",{"id":d["id"]})
	runner.eq(d["status"],"receivable","LC seven day settlement wait")
	runner.eq(d["delivered"]["units"],50,"actual buyer delivery receipt")
	GameState.data["clock"]["minutes"]=d["due"];TradeIndustry.collect(d)
	runner.eq(d["status"],"paid","bank-backed collected once")
	var cash:=Ledger.cash(GameState.company_id());TradeIndustry.collect(d)
	runner.eq(Ledger.cash(GameState.company_id()),cash,"already paid callback no-op")
	runner.check(Ledger.check_balanced(),"FX settlement balanced")
func test_expired_quote_and_closed_company_cannot_resurrect_trade() -> void:
	setup();var q:=quote();GameState.data["clock"]["minutes"]=q["valid_until"]
	runner.check(not TradeIndustry.sign(q)["ok"],"expired quote unavailable")
	var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	GameState.data["entities"][GameState.company_id()]["closed"]=Clock.now();TradeIndustry.on_company_closed(GameState.company_id())
	var before:=Ledger.cash(GameState.company_id());TradeIndustry.handle("trade.arrive",{"id":d["id"]})
	runner.eq(d["status"],"closed","closed company terminal")
	runner.eq(Ledger.cash(GameState.company_id()),before,"no closed-company payment")
	runner.check(not TradeIndustry.withdraw(d["id"])["ok"],"no closed-company salvage")
func test_capacity_old_save_and_roundtrip() -> void:
	setup();GameState.data.erase("trade");var s:=TradeIndustry.S()
	runner.eq(s["completed"],0,"old save lazy defaults")
	runner.check(not TradeIndustry.start()["ok"],"old save does not grant registration")
	TradeIndustry.register();TradeIndustry.start()
	for i in 3:runner.check(TradeIndustry.sign(quote())["ok"],"within capacity")
	runner.check(not TradeIndustry.sign(quote())["ok"],"cannot sell unlimited regional supply")
	runner.check(SaveSystem.save(7) and SaveSystem.load_data(7),"active physical trade save roundtrip")
	runner.eq(TradeIndustry.S()["deals"].size(),3,"retains actual projects")

func paid_trades() -> String:
	GameState.rng.seed=12346
	var last: String=""
	for i in 3:
		var r:=TradeIndustry.sign(quote());runner.check(r["ok"],"paid trade signed")
		if not r["ok"]:return ""
		var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
		TradeIndustry.bank_documents(d["id"]);depart(d)
		runner.eq(d["status"],"in_transit","paid fixture actual shipment")
		if d["status"]!="in_transit":return ""
		GameState.data["clock"]["minutes"]=d["eta"];TradeIndustry.handle("trade.arrive",{"id":d["id"]})
		GameState.data["clock"]["minutes"]=d["due"];TradeIndustry.collect(d)
		runner.eq(d["status"],"paid","real delivered invoice collected")
		last=d["id"]
	return last

func test_repeat_contract_has_paid_jobs_and_done_impossible_choices() -> void:
	setup();var id:=paid_trades()
	if id=="":return
	runner.check(TradeIndustry.sign_repeat(id)["ok"],"negotiate after actual collection")
	runner.check(not TradeIndustry.sign_repeat(id)["ok"],"already done cannot duplicate repeat")
	var c: Dictionary=TradeIndustry.S()["contracts"][id]
	TradeIndustry.pause_repeat(id,true);GameState.data["clock"]["minutes"]=c["next"]
	TradeIndustry.on_hour(Clock.now(),0);runner.eq(c["jobs"].size(),0,"paused contract never fabricates jobs")
	TradeIndustry.pause_repeat(id,false);TradeIndustry.on_hour(Clock.now(),0)
	runner.eq(c["jobs"].size(),1,"repeat signs actual fresh Jobs contract")
	TradeIndustry.end_repeat(id)
	runner.check(not TradeIndustry.pause_repeat(id,false)["ok"],"ended contract cannot revive")
	runner.check(not TradeIndustry.end_repeat(id)["ok"],"already ended safe")
	runner.check(Ledger.check_balanced(),"repeat real costs balanced")

func test_agency_receives_paid_stock_without_invented_sales() -> void:
	setup();var id:=paid_trades()
	if id=="":return
	runner.check(TradeIndustry.lease_warehouse()["ok"],"warehouse real rent and deposit")
	runner.check(TradeIndustry.open_agency()["ok"],"agency real application fee")
	runner.check(not TradeIndustry.open_agency()["ok"],"already active agency cannot charge twice")
	var q:=TradeQuote.sheet("northridge","aurelia","wireless_earbuds",20,"DDP","air","tt_delivery",true,.3)
	var r:=TradeIndustry.procure(q);runner.check(r["ok"],"agency actual supplier purchase")
	if not r["ok"]:return
	var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	d["disruption_checked"]=true
	var before:=Ledger.balance(GameState.company_id(),"revenue")
	depart(d)
	if d["status"]=="lost":runner.check(Ledger.check_balanced(),"supplier failure is real loss");return
	GameState.data["clock"]["minutes"]=d["eta"];TradeIndustry.handle("trade.arrive",{"id":d["id"]})
	runner.eq(d["status"],"received","physical paid warehouse receipt")
	runner.eq(Ecommerce.stock("meridian_bonded_warehouse","wireless_earbuds"),20,"shared ecommerce inventory")
	runner.eq(Ledger.balance(GameState.company_id(),"revenue"),before,"internal stock receipt is not sales")
	TradeIndustry.handle("trade.arrive",{"id":d["id"]})
	runner.eq(Ecommerce.stock("meridian_bonded_warehouse","wireless_earbuds"),20,"already received no duplicate stock")
	runner.check(not TradeIndustry.withdraw(d["id"])["ok"],"already received cargo cannot be refunded")
	runner.check(Ledger.check_balanced(),"warehouse purchase balanced")

func test_port_delay_choices_resume_and_freight_effect_expires() -> void:
	setup();var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	var old: float=TradeIndustry.cfg().get("port_disruption_risk",.08)
	TradeIndustry.cfg()["port_disruption_risk"]=1.0
	GameState.data["clock"]["minutes"]=d["depart"];TradeIndustry.handle("trade.depart",{"id":d["id"]})
	TradeIndustry.cfg()["port_disruption_risk"]=old
	runner.eq(d["status"],"delayed","actual temporary port disruption")
	var peak:=quote();var cash:=Ledger.cash(GameState.company_id())
	runner.check(TradeIndustry.resolve_delay(d["id"],true)["ok"],"real paid air alternative")
	runner.check(Ledger.cash(GameState.company_id())<cash,"reroute has cost")
	runner.check(not TradeIndustry.resolve_delay(d["id"],false)["ok"],"already chosen cannot apply twice")
	GameState.data["clock"]["minutes"]=TradeIndustry.S()["freight_until"]+1
	var calm:=quote();runner.check(float(calm["costs"])<float(peak["costs"]),"freight shock expires")
	runner.check(Ledger.check_balanced(),"reroute actual fee balanced")

func test_shared_forward_hedges_only_contracted_receipts_and_can_lose() -> void:
	setup();runner.check(GlobalMarket.open_bank()["ok"],"actual international bank fee")
	runner.eq(FXForward.exposure(GameState.company_id(),TradeQuote.currency("northridge"),30),0.0,"no speculative trade exposure")
	var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	var cash:=Ledger.cash(GameState.company_id());var hedge:=TradeIndustry.hedge_receipt(d["id"])
	runner.check(hedge["ok"],"contract-backed shared forward")
	if not hedge["ok"]:return
	runner.check(Ledger.cash(GameState.company_id())<cash,"real fee and collateral paid")
	runner.check(not TradeIndustry.hedge_receipt(d["id"])["ok"],"already hedged exposure cannot be reused")
	var f: Dictionary=FXForward.S()["items"][hedge["id"]]
	FX.S()["rates"][f["currency"]]=float(f["rate"])*1.1
	GameState.data["clock"]["minutes"]=f["due"];FXForward.on_hour()
	runner.eq(f["status"],"settled","matured real hedge settles")
	runner.check(float(f["gain_loss"])<0,"strengthening foreign currency makes hedge lose")
	runner.check(not FXForward.settle(hedge["id"])["ok"],"already settled no double collateral refund")
	runner.check(Ledger.check_balanced(),"hedge exact accounting balances")
	var pnl:=MonthClose.compute(GameState.company_id(),0,Clock.now()+1)
	var segments:=Segments.compute(GameState.company_id(),0,Clock.now()+1)
	runner.eq(segments["totals"]["operating_profit"],pnl["business_profit"],"realized FX included in consolidated segment profit")

func test_coordinator_uses_paid_supplier_papers_and_ordinary_payroll() -> void:
	setup();GlobalMarket.open_bank();runner.check(Staff.register_employer()["ok"],"actual employer registration")
	runner.check(Staff.post_job("trade_coordinator")["ok"],"actual coordinator recruitment ad")
	Clock.advance(18*60+5)
	runner.check(not Staff.S()["applicants"].is_empty(),"real scheduled applicants")
	if Staff.S()["applicants"].is_empty():return
	runner.check(Staff.hire(Staff.S()["applicants"][0]["id"])["ok"],"actual hired coordinator")
	var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	TradeIndustry.set_document(d["id"],"invoice",false);depart(d)
	runner.eq(d["status"],"customs_hold","real missing supplier invoice hold")
	var worker: Dictionary=Staff.people()[0]
	var work_time: int=maxi(Clock.now(),int(worker["start"]))
	while Clock.weekday(work_time) not in [1,2,3,4,5]:work_time+=Clock.DAY
	work_time=(work_time/Clock.DAY)*Clock.DAY+10*60
	GameState.data["clock"]["minutes"]=work_time
	TradeIndustry.on_hour(work_time,10);TradeIndustry.on_hour(work_time+60,11)
	runner.eq(d["status"],"in_transit","working coordinator corrects actual cargo papers")
	runner.eq(d["lc"],"documents_accepted","working coordinator submits valid bank papers")
	var cash:=Ledger.cash(GameState.company_id());Staff.run_payroll()
	runner.check(Ledger.cash(GameState.company_id())<cash,"coordinator ordinary wages paid")
	runner.check(Ledger.check_balanced(),"coordinator fees and payroll balanced")

func test_crisis_decisions_already_ended_and_closed_company_never_soft_lock() -> void:
	setup();var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	var evt:=EventEngine.trigger("trade_port_strike",{"trade":d["id"]})
	runner.check(EventEngine.choose(evt["iid"],"wait")["ok"],"already ended delay decision dismisses safely")
	evt=EventEngine.trigger("trade_fx_volatility",{"trade":d["id"]})
	GameState.data["entities"][GameState.company_id()]["closed"]=Clock.now();TradeIndustry.on_company_closed(GameState.company_id())
	var cash:=Ledger.cash(GameState.company_id())
	var journals: int=GameState.data["ledger"]["journal"].size()
	runner.check(not EventEngine.pending().any(func(q):return q["iid"]==evt["iid"]),"impossible closed-company decision is removed from pending work")
	runner.check(not EventEngine.choose(evt["iid"],"spot")["ok"],"closed removed decision cannot be chosen again")
	runner.eq(Ledger.cash(GameState.company_id()),cash,"closed removed decision cannot pay or earn money")
	runner.eq(GameState.data["ledger"]["journal"].size(),journals,"removed choice creates no journal")
	runner.check(not EventEngine.choose(evt["iid"],"hedge")["ok"],"already dismissed decision cannot change cash")
	runner.check(Ledger.check_balanced(),"ended decisions preserve ledger")

func test_insured_letter_of_credit_does_not_insure_supplier_default() -> void:
	setup();var before:=Ledger.cash(GameState.company_id())
	var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	TradeIndustry.bank_documents(d["id"]);d["disruption_checked"]=true
	var old: float=TradeIndustry.cfg().get("supplier_failure_risk",.03)
	TradeIndustry.cfg()["supplier_failure_risk"]=1.0
	depart(d);TradeIndustry.cfg()["supplier_failure_risk"]=old
	runner.eq(d["status"],"lost","feasible adverse supplier failure")
	runner.eq(d["insurance_receipt"]["paid"],0.0,"cargo insurance never covers supplier insolvency")
	runner.check(Ledger.cash(GameState.company_id())<before,"insured bank-backed strategy still loses actual cash")
	runner.eq(Ledger.balance(GameState.company_id(),"revenue"),0.0,"bank guarantee cannot invent delivery")
	runner.check(Ledger.check_balanced(),"adverse loss balanced")

func test_documents_have_exactly_one_useful_primary() -> void:
	setup();var r:=TradeIndustry.sign(quote());var d: Dictionary=TradeIndustry.S()["deals"][r["id"]]
	TradeIndustry.set_document(d["id"],"packing_list",false);depart(d)
	var board:=TradeDeskUI.new();UIRoot.open_modal(board)
	await UIRoot.get_tree().process_frame
	var primary_count:=0
	var missing:=board.find_child("TradeDoc_"+d["id"]+"_packing_list",true,false)
	runner.check(missing!=null,"missing document is reachable")
	for node in board.find_children("*","Button",true,false):
		var style: StyleBox=(node as Button).get_theme_stylebox("normal")
		if style is StyleBoxTexture and style.texture==Art.tex("ui/button_primary"):
			primary_count+=1
			runner.eq(node,missing,"primary fills missing paper before clearing")
	runner.eq(primary_count,1,"one sensible primary despite multiple trade actions")
	board.close()
