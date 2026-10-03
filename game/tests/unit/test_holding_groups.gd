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
