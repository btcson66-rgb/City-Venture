extends RefCounted
var runner
func company(name: String,kind := "retail_online") -> String:
	runner.check(Company.register(name,kind,"Riverside")["ok"],"register distinct entity")
	runner.check(Company.open_business_account(3000)["ok"],"fund independent book")
	return GameState.company_id()
func group() -> Array:
	var a := company("Goods First")
	var parent := company("Family Holding","holding")
	var b := company("Goods Second")
	runner.check(HoldingGroups.hold(parent,a)["ok"],"hold first")
	runner.check(HoldingGroups.hold(parent,b)["ok"],"hold second")
	return [parent,a,b]
func test_company_contexts_stock_staff_flags_credit_and_accounts_are_separate() -> void:
	var a := company("First Independent")
	Ecommerce._add_stock("riverside_studio","phone_stand",4,5,0)
	Staff.S()["people"]["qa"]={"name":"First Employee"}
	GameState.set_flag("food_permit")
	Bank.B()["credit"]=590
	GameState.data["living"]["leases"]["suite_2b"]={"entity":a}
	var b := company("Second Independent")
	runner.eq(Ecommerce.stock("riverside_studio","phone_stand"),0,"no cloned stock")
	runner.check(not Ecommerce.stock_locations().has("suite_2b"),"another company office is not free storage")
	runner.check(not Staff.S()["people"].has("qa"),"no cloned staff")
	runner.check(not GameState.flag("food_permit"),"licence separate")
	runner.eq(Bank.credit(),680,"independent new credit")
	CompanyPortfolio.switch(a)
	runner.eq(Ecommerce.stock("riverside_studio","phone_stand"),4,"first stock restored")
	runner.check(Staff.S()["people"].has("qa"),"first staff restored")
	runner.eq(Bank.credit(),590,"first credit restored")
	runner.check(Ecommerce.stock_locations().has("suite_2b"),"owned office remains accessible")
	runner.eq(Ledger.cash(a),3000,"first separate bank")
	runner.eq(Ledger.cash(b),3000,"second separate bank")
func test_old_single_company_schedule_migration_and_save_reload_preserve_views() -> void:
	var a := company("Old Single")
	GameState.data["company"]=a
	GameState.data.erase("active_company")
	GameState.data["schedule"].append({"t":Clock.now()+60,"kind":"eco.qa","p":{}})
	CompanyPortfolio.migrate(GameState.data)
	runner.eq(GameState.data["schedule"][-1]["p"]["company_context"],a,"old scheduled owner bound")
	Ecommerce._add_stock("riverside_studio","phone_stand",3,5,0)
	var b := company("New Other")
	runner.check(SaveSystem.save(5),"portfolio serializes")
	GameState.new_game({"name":"Other"})
	runner.check(SaveSystem.load_data(5),"portfolio validates and reloads")
	runner.eq(GameState.company_id(),b,"active view loaded")
	CompanyPortfolio.switch(a)
	runner.eq(Ecommerce.stock("riverside_studio","phone_stand"),3,"inactive view persisted")
func test_hold_release_already_done_impossible_and_owner_fund_guards() -> void:
	var g := group()
	runner.check(not HoldingGroups.hold(g[0],g[1])["ok"],"already held cannot mint equity")
	runner.check(not HoldingGroups.hold(g[1],g[0])["ok"],"cycle/operating parent blocked")
	runner.check(not Company.transfer(g[1],"player",100)["ok"],"subsidiary cannot pay founder directly")
	runner.check(not Insolvency.close_company()["ok"] or GameState.company_id()!=g[0],"active subsidiary isolated")
	CompanyPortfolio.switch(g[0])
	runner.check(not Insolvency.close_company()["ok"],"parent must resolve subsidiaries")
	for child in g.slice(1):
		if GlobalMarket.live(child): runner.check(HoldingGroups.release(g[0],child)["ok"],"release escape")
	runner.check(not HoldingGroups.release(g[0],g[1])["ok"],"already released safe")
	runner.check(Insolvency.close_company()["ok"],"parent can close after release")
func test_transfer_markup_eliminated_until_external_delivery_and_refund() -> void:
	var g := group()
	CompanyPortfolio.switch(g[1])
	Ecommerce._add_stock("riverside_studio","wireless_earbuds",10,18,0)
	Ledger.post(g[1],"Paid stock",[{"acct":"inventory","dr":180},{"acct":"cash","cr":180}])
	var t0 := Clock.now()
	runner.check(HoldingGroups.goods(g[1],g[2],"wireless_earbuds",4,30)["ok"],"actual sibling trade")
	var report := HoldingGroups.consolidated(g[0],t0,Clock.now()+1)
	runner.eq(report["revenue"],0,"no external sale invented")
	runner.eq(report["profit"],0,"unsold markup removed")
	runner.eq(report["unrealized_margin"],48,"four actual units markup")
	runner.eq(report["investment_elimination"],6000,"subsidiary investment eliminated")
	CompanyPortfolio.switch(g[2])
	Ecommerce.create_listing("wireless_earbuds",60,"self",.9)
	var listing := Ecommerce.listing_for("wireless_earbuds")
	Ecommerce._h_order_place({"listing":listing["id"]})
	var order: Dictionary = Ecommerce.E()["orders"]["#%d"%int(Ecommerce.E()["counters"]["order"])]
	Ecommerce.pack_orders("riverside_studio")
	runner.eq(HoldingGroups.margin_at(g,Clock.now()+1),48,"packed unsold stock still eliminated")
	Ecommerce.courier_pickup("riverside_studio","economy")
	Ecommerce._h_pickup({"ids":[order["id"]]})
	GameState.data["clock"]["minutes"]=order["ship"]["eta"]
	Ecommerce._h_deliver({"order":order["id"]})
	runner.eq(HoldingGroups.margin_at(g,Clock.now()+1),48-float(order["qty"])*12,"real delivery releases only sold units")
	HoldingGroups.return_margin(order)
	HoldingGroups.return_margin(order)
	runner.eq(HoldingGroups.margin_at(g,Clock.now()+1),48,"returned stock markup restored once")
	runner.check(Ledger.check_balanced(),"both company books balance")
func test_group_loans_interest_management_consolidation_and_nonfinite_edges() -> void:
	var g := group()
	var loan := HoldingGroups.loan(g[0],g[1],500)
	runner.check(loan["ok"],"actual group funding")
	runner.check(not HoldingGroups.loan(g[0],g[1],INF)["ok"],"infinite amount blocked")
	GameState.data["clock"]["minutes"]+=30*Clock.DAY
	HoldingGroups.on_hour()
	runner.eq(Ledger.cash(g[0]),2502.5,"actual monthly interest received")
	var report := HoldingGroups.consolidated(g[0],0,Clock.now()+1)
	runner.eq(report["loan_elimination"],500,"reciprocal principal eliminated")
	runner.eq(report["profit"],0,"interest canceled within group")
	runner.check(HoldingGroups.repay(loan["id"],500)["ok"],"repayment")
	runner.check(not HoldingGroups.repay(loan["id"],1)["ok"],"already paid no second repayment")
	var before := Clock.now()
	runner.check(HoldingGroups.management(g[0],g[1],20.25)["ok"],"real management hour")
	runner.check(Clock.now()>=before+60,"management actually consumes hour")
	runner.eq(HoldingGroups.consolidated(g[0],Clock.now()-1,Clock.now()+1)["profit"],0,"management revenue and expense cancel")
func test_subsidiary_bankruptcy_leaves_sibling_state_and_investment_intact() -> void:
	var g := group()
	CompanyPortfolio.switch(g[1])
	var personal := Ledger.balance("player","investments")
	var sibling := Ledger.cash(g[2])
	runner.check(Insolvency.close_company()["ok"],"subsidiary liquidated")
	runner.eq(Ledger.cash(g[2]),sibling,"sibling bank intact")
	runner.eq(Ledger.balance("player","investments"),personal,"personal portfolio not wiped")
	runner.eq(Ledger.balance(g[0],"investment_in_subsidiary:"+g[1]),0,"only closed child carrying value cleared")
	runner.check(GlobalMarket.live(g[0]) and GlobalMarket.live(g[2]),"other companies survive")
	runner.check(not CompanyPortfolio.switch(g[1])["ok"],"closed company cannot reopen")
	runner.check(CompanyPortfolio.switch(g[2])["ok"],"available company escape")
func test_npc_subsidiary_sale_is_parent_proceeds_and_cannot_pay_twice() -> void:
	var g := group()
	var personal := Ledger.cash("player")
	var before := Ledger.cash(g[0])
	var sold := HoldingGroups.sell_subsidiary(g[0],g[1],"vesper")
	runner.check(sold["ok"],"real subsidiary sale")
	runner.check(float(sold.get("paid",0))<3000,"new company sale cannot mint risk-free profit")
	runner.eq(Ledger.cash(g[0]),before+float(sold.get("paid",0)),"parent receives price")
	runner.eq(Ledger.cash("player"),personal,"no duplicate founder proceeds")
	runner.check(not HoldingGroups.sell_subsidiary(g[0],g[1],"hale")["ok"],"already sold cannot pay twice")
	CompanyPortfolio.switch(g[1])
	Insolvency.close_company()
	runner.eq(Ledger.cash("player"),personal,"outside owner liquidation not founder windfall")
	runner.check(Ledger.check_balanced(),"sale and liquidation balanced")

func test_parent_guarantee_exposes_only_guaranteeing_parent_and_settles_once() -> void:
	var g:=group()
	CompanyPortfolio.switch(g[1])
	# A bank-originated liability fixture, never revenue. The borrower spends all available cash.
	Bank.B()["loans"]["QA-G"]={"id":"QA-G","entity":g[1],"status":"active","balance":2000,"next":Clock.now()+30*Clock.DAY,"apr":.1,"months":12,"payment":200}
	Ledger.post(g[1],"Approved loan fixture",[{"acct":"cash","dr":2000},{"acct":"loan_payable","cr":2000}])
	Ledger.expense(g[1],"supplies",Ledger.cash(g[1]),"Actual consumed supplies fixture")
	var sibling:=Ledger.cash(g[2])
	var parent:=Ledger.cash(g[0])
	runner.check(HoldingGroups.guarantee(g[0],"QA-G")["ok"],"parent explicitly guarantees")
	runner.check(HoldingGroups.guarantee(g[0],"QA-G")["ok"],"already guaranteed idempotent")
	runner.check(Insolvency.close_company()["ok"],"child closes")
	runner.eq(Ledger.cash(g[0]),parent-2000,"only guarantor pays unpaid bank debt")
	runner.eq(Ledger.cash(g[2]),sibling,"sibling isolated")
	runner.eq(HoldingGroups.cover_guarantees(g[1],2000),0,"no duplicate claim")
	runner.check(Ledger.check_balanced(),"guarantee books balance")
func test_scheduled_work_runs_owner_context_and_restores_current_view() -> void:
	var a:=company("Scheduled First")
	Ecommerce._add_stock("riverside_studio","wireless_earbuds",3,18,0)
	Ecommerce.create_listing("wireless_earbuds",60,"self",.9)
	var listing:=Ecommerce.listing_for("wireless_earbuds")
	Sim.schedule(Clock.now()+20,"eco.order_place",{"listing":listing["id"]})
	var b:=company("Scheduled Second")
	Sim._dispatch("eco.order_place",{"listing":listing["id"],"company_context":a})
	runner.eq(GameState.company_id(),b,"viewer restored")
	runner.eq(Ecommerce.E()["orders"].size(),0,"no foreign company order in current view")
	CompanyPortfolio.switch(a)
	runner.check(Ecommerce.E()["orders"].size()>0,"owner order created")
func test_group_company_selector_and_registration_are_reachable() -> void:
	var g:=group()
	CompanyPortfolio.switch(g[0])
	var os:=CompanyOS.new("home_laptop")
	os.tab="group"
	runner.get_tree().root.add_child(os)
	await runner.get_tree().process_frame
	runner.check(os.find_child("CompanySelector",true,false)!=null,"all company views reachable")
	runner.check(os.find_child("HoldingLoan_"+g[1],true,false)!=null,"real financing control")
	runner.check(os.find_child("HoldingGoods",true,false)!=null,"actual stock transfer controls")
	os.queue_free()
	await runner.get_tree().process_frame

func test_corrupt_portfolio_import_rejects_invalid_ids_and_context_shapes() -> void:
	var ent:=company("Validated Save")
	CompanyPortfolio.capture()
	var original:=GameState.data.duplicate(true)
	for kind in ["id","active","duplicate","context"]:
		var data:=original.duplicate(true)
		match kind:
			"id":data["company"]=[123]
			"active":data["active_company"]="missing_company"
			"duplicate":data["company"].append(ent)
			"context":data["company_contexts"][ent]["states"]["ecommerce"]="corrupt"
		var payload:={"format":GameState.SAVE_FORMAT,"summary":{},"data":data}
		runner.check(not SaveCodec.decode(JSON.stringify(payload))["ok"],"reject malformed portfolio: "+kind)
	runner.eq(GameState.company_id(),ent,"failed imports leave live company intact")

func test_registration_prompt_is_read_only_and_requires_the_clerk() -> void:
	company("Prompt Owner")
	var before:=UIRoot.top_modal()
	var seq:=int(GameState.data["ledger"]["seq"])
	for i in 3:runner.eq(Actions.lock_reason("register_company",{}),"Nobody at the counter. Registration: Mon–Fri 9:00–17:00.","missing clerk explains next opening")
	runner.eq(UIRoot.top_modal(),before,"reading prompt cannot open registration")
	runner.eq(GameState.data["ledger"]["seq"],seq,"reading prompt cannot spend")

func test_actual_trade_contract_schedule_and_save_are_isolated_when_switching_company() -> void:
	var fixture=load("res://tests/unit/test_trade_execution.gd").new();fixture.runner=runner;fixture.setup()
	var owner:=GameState.company_id()
	var signed: Dictionary=TradeIndustry.sign(fixture.quote())
	runner.check(signed["ok"],"real owner signs paid supplier cargo")
	if not signed["ok"]:return
	var deal_id: String=signed["id"]
	var deal: Dictionary=TradeIndustry.S()["deals"][deal_id]
	var pending: Array=GameState.data["schedule"].filter(func(item):return item["kind"]=="trade.depart" and item["p"].get("id","")==deal_id)
	runner.check(not pending.is_empty(),"actual cargo departure scheduled")
	if pending.is_empty():return
	var scheduled: Dictionary=pending[0].duplicate(true)
	runner.eq(scheduled["p"].get("company_context",""),owner,"actual departure belongs to cargo owner")
	var other:=company("Other without brokerage")
	runner.check(not TradeIndustry.is_running(),"second company has no inherited brokerage")
	runner.eq(TradeIndustry.entity(),"","second company does not operate owner cargo")
	runner.check(TradeIndustry.S()["deals"].is_empty(),"no cloned trade cargo")
	runner.check(not GameState.flag("trade_active"),"trade licence flag follows selected company")
	var other_cash:=Ledger.cash(other)
	GameState.data["clock"]["minutes"]=int(deal["depart"])
	Sim._dispatch(scheduled["kind"],scheduled["p"])
	runner.eq(GameState.company_id(),other,"scheduled cargo restores the viewer")
	runner.check(TradeIndustry.S()["deals"].is_empty(),"scheduled owner does not leak cargo into viewer")
	runner.eq(Ledger.cash(other),other_cash,"another company's departure never charges viewer")
	CompanyPortfolio.switch(owner)
	runner.eq(TradeIndustry.entity(),owner,"real brokerage owner restored")
	runner.check(GameState.flag("trade_active"),"owner trade licence restored")
	runner.check(TradeIndustry.S()["deals"][deal_id]["status"]!="booked","actual owner cargo departure was processed")
	runner.check(SaveSystem.save(5),"real multi-company cargo serializes")
	runner.check(SaveSystem.load_data(5),"real multi-company cargo loads")
	CompanyPortfolio.switch(other)
	runner.check(TradeIndustry.S()["deals"].is_empty(),"loaded viewer has no other-company cargo")
	CompanyPortfolio.switch(owner)
	runner.check(TradeIndustry.S()["deals"].has(deal_id),"loaded owner retains actual contract")
	runner.check(Insolvency.close_company()["ok"],"cargo owner closes through actual insolvency action")
	runner.eq(GameState.company_id(),other,"remaining company becomes available after closure")
	runner.check(not GameState.flag("trade_active") and TradeIndustry.S()["deals"].is_empty(),"closed brokerage cannot contaminate survivor")
	runner.check(Ledger.check_balanced(),"all actual supplier and closure postings balance")

func test_old_single_company_trade_departure_acquires_owner_before_switch() -> void:
	var fixture=load("res://tests/unit/test_trade_execution.gd").new();fixture.runner=runner;fixture.setup()
	var owner:=GameState.company_id()
	var signed: Dictionary=TradeIndustry.sign(fixture.quote())
	runner.check(signed["ok"],"actual old-format cargo purchase")
	if not signed["ok"]:return
	var pending: Array=GameState.data["schedule"].filter(func(item):return item["kind"]=="trade.depart" and item["p"].get("id","")==signed["id"])
	runner.check(not pending.is_empty(),"legacy cargo schedule exists")
	if pending.is_empty():return
	pending[0]["p"].erase("company_context")
	GameState.data["company"]=owner;GameState.data.erase("active_company")
	CompanyPortfolio.migrate(GameState.data)
	runner.eq(pending[0]["p"].get("company_context",""),owner,"legacy trade schedule migrated to real owner")
	company("Legacy viewer")
	runner.check(TradeIndustry.S()["deals"].is_empty(),"legacy owner cargo is not cloned on registration")
	CompanyPortfolio.switch(owner)
	runner.check(TradeIndustry.S()["deals"].has(signed["id"]),"migrated owner retains real paid cargo")

func test_old_multi_company_trade_capture_loads_without_giving_viewer_the_cargo() -> void:
	var fixture=load("res://tests/unit/test_trade_execution.gd").new();fixture.runner=runner;fixture.setup()
	var owner:=GameState.company_id()
	var signed: Dictionary=TradeIndustry.sign(fixture.quote())
	runner.check(signed["ok"],"actual historical brokerage signs cargo")
	if not signed["ok"]:return
	var legacy_trade:=TradeIndustry.S().duplicate(true)
	var other:=company("Historical viewer")
	CompanyPortfolio.capture()
	var legacy: Dictionary=GameState.data.duplicate(true)
	for view in legacy["company_contexts"].values():
		view["states"].erase("trade");view["flags"].erase("trade_active")
	legacy["trade"]=legacy_trade;legacy["flags"]["trade_active"]=true
	for item in legacy["schedule"]:
		if str(item["kind"]).begins_with("trade."):item["p"].erase("company_context")
	var journals: int=legacy["ledger"]["journal"].size()
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var file:=FileAccess.open(SaveSystem.DIR.path_join("slot_5.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":GameState.SAVE_FORMAT,"summary":{},"data":legacy}));file.close()
	runner.check(SaveSystem.load_data(5),"pre-registry multi-company save loads through normal validation: "+SaveSystem.last_error)
	runner.eq(GameState.company_id(),other,"historical viewer stays selected")
	runner.check(not TradeIndustry.is_running() and TradeIndustry.S()["deals"].is_empty(),"migration does not give viewer old owner's brokerage")
	runner.check(not GameState.flag("trade_active"),"viewer does not inherit owner's licence")
	CompanyPortfolio.switch(owner)
	runner.check(TradeIndustry.S()["deals"].has(signed["id"]),"real paid cargo restored to recorded owner")
	runner.check(GameState.flag("trade_active"),"owner licence recovered")
	for item in GameState.data["schedule"]:
		if str(item["kind"]).begins_with("trade."):runner.eq(item["p"].get("company_context",""),owner,"legacy trade schedule bound to recorded owner")
	runner.eq(GameState.data["ledger"]["journal"].size(),journals,"migration creates no money or extra purchase")
	runner.check(Ledger.check_balanced(),"loaded historical cargo books balanced")
	# Preserve an intermediate portfolio save: viewer selected, owner parked, decision not yet priced.
	var deal: Dictionary=TradeIndustry.S()["deals"][signed["id"]]
	var probe:=RandomNumberGenerator.new()
	for value in 10000:
		probe.seed=value
		if probe.randf()<float(TradeIndustry.cfg().get("port_disruption_risk",.08)):GameState.rng.seed=value;break
	GameState.data["clock"]["minutes"]=int(deal["depart"])
	TradeIndustry.handle("trade.depart",{"id":signed["id"]})
	runner.eq(deal["status"],"delayed","real parked cargo awaits a port decision")
	CompanyPortfolio.switch(other);CompanyPortfolio.capture()
	var parked: Dictionary=GameState.data.duplicate(true)
	var port: Array=parked["events"]["queue"].filter(func(q):return q["id"]=="trade_port_strike" and q["ctx"].get("trade_entity","")==owner)
	runner.check(not port.is_empty(),"parked actual port decision exists")
	if port.is_empty():return
	var iid: String=port[0]["iid"];port[0]["ctx"].erase("reroute_fee");port[0]["ctx"].erase("company")
	file=FileAccess.open(SaveSystem.DIR.path_join("slot_5.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":GameState.SAVE_FORMAT,"summary":{},"data":parked}));file.close()
	runner.check(SaveSystem.load_data(5),"old parked-owner port decision loads normally")
	var loaded_port: Array=EventEngine.pending().filter(func(q):return q["iid"]==iid)
	runner.check(not loaded_port.is_empty() and loaded_port[0]["ctx"].has("reroute_fee"),"actual owner fee recovered from parked cargo")
	if loaded_port.is_empty() or not loaded_port[0]["ctx"].has("reroute_fee"):return
	var cash:=Ledger.cash(owner)
	runner.check(EventEngine.choose(iid,"air")["ok"],"loaded owner rerouting executes")
	runner.eq(Fmt.money(cash-Ledger.cash(owner)),loaded_port[0]["ctx"]["reroute_fee"],"loaded fee equals actual original-owner payment")
	runner.eq(GameState.company_id(),other,"loaded decision restores historical viewer")
	runner.check(Ledger.check_balanced(),"loaded actual rerouting books balance")


func test_pending_trade_port_decision_reroutes_the_owner_and_restores_another_viewer() -> void:
	var fixture=load("res://tests/unit/test_trade_execution.gd").new();fixture.runner=runner;fixture.setup()
	var owner:=GameState.company_id()
	var signed: Dictionary=TradeIndustry.sign(fixture.quote())
	runner.check(signed["ok"],"actual sea cargo purchased")
	if not signed["ok"]:return
	var deal: Dictionary=TradeIndustry.S()["deals"][signed["id"]]
	var probe:=RandomNumberGenerator.new()
	for value in 10000:
		probe.seed=value
		if probe.randf()<float(TradeIndustry.cfg().get("port_disruption_risk",.08)):GameState.rng.seed=value;break
	GameState.data["clock"]["minutes"]=int(deal["depart"])
	TradeIndustry.handle("trade.depart",{"id":signed["id"]})
	runner.eq(deal["status"],"delayed","real disruption generated by actual departure handler")
	var pending: Array=EventEngine.S()["queue"].filter(func(q):return q["id"]=="trade_port_strike" and q["ctx"].get("trade","")==signed["id"])
	runner.check(not pending.is_empty(),"actual owner cargo queued port choices")
	if pending.is_empty():return
	var inst: Dictionary=pending[0]
	runner.eq(inst["ctx"].get("trade_entity",""),owner,"queued decision identifies actual brokerage")
	var other:=company("Port decision viewer")
	var other_cash:=Ledger.cash(other);var owner_cash:=Ledger.cash(owner)
	runner.check(EventEngine.choose(inst["iid"],"air")["ok"],"real rerouting choice applies to original cargo")
	runner.eq(GameState.company_id(),other,"decision restores selected other company")
	runner.eq(Ledger.cash(other),other_cash,"viewer never pays another company's rerouting")
	runner.check(Ledger.cash(owner)<owner_cash,"original owner actually pays air freight")
	runner.eq(Fmt.money(owner_cash-Ledger.cash(owner)),inst["ctx"]["reroute_fee"],"displayed rerouting fee equals actual owner cash payment")
	CompanyPortfolio.switch(owner)
	runner.check(TradeIndustry.S()["deals"][signed["id"]].has("reroute_receipt"),"rerouting belongs to actual owner contract")
	EventEngine.trigger("trade_fx_volatility",{"trade":signed["id"],"trade_entity":owner,"company":GameState.business_display_name()})
	runner.check(Insolvency.close_company()["ok"],"real closure resolves queued brokerage decisions")
	runner.eq(GameState.company_id(),other,"closed trade owner leaves available viewer")
	runner.check(not EventEngine.S()["queue"].any(func(q):return q["id"] in ["trade_port_strike","trade_fx_volatility"] and str(q["ctx"].get("trade_entity",""))==owner),"closed cargo cannot block or charge a later company")
	runner.check(Ledger.check_balanced(),"actual event rerouting posts balance")

func test_another_company_cannot_open_trade_in_the_first_companys_paid_office() -> void:
	var fixture=load("res://tests/unit/test_trade_execution.gd").new();fixture.runner=runner;fixture.setup()
	var owner:=GameState.company_id()
	var other:=company("Office licence viewer","international_trade")
	runner.check(TradeIndustry.register()["ok"],"other firm pays its own trade registration")
	var cash:=Ledger.cash(other)
	runner.check(not TradeIndustry.start()["ok"],"other firm's paid office cannot satisfy this company's lease")
	runner.check(not TradeIndustry.is_running(),"unleased company remains inactive")
	runner.eq(Ledger.cash(other),cash,"failed opening invents no rent or income")
	CompanyPortfolio.switch(owner)
	runner.check(TradeIndustry.valid(),"real office owner remains running")

