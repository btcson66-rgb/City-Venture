extends RefCounted
var runner
func _company() -> String:
	Company.register("Risk test","ecommerce","22 Founders Lane")
	Company.open_business_account(20000)
	return GameState.company_id()
func _sale(entity: String,amount: float,id := "sale") -> Dictionary:
	return Ledger.post(entity,"Actual customer sale",[{"acct":"cash","dr":amount},{"acct":"revenue","cr":amount}],{"type":"sale","id":id,"segment":"ecommerce"})
func _jump(year: int,month: int,day := 1) -> void:
	var target := {"year":year,"month":month,"day":day,"hour":0,"minute":0,"second":0}
	GameState.data["clock"]["minutes"]=int((Time.get_unix_time_from_datetime_dict(target)-Time.get_unix_time_from_datetime_dict(Clock.date_at(0)))/60)
func _job(entity: String,segment := "consulting") -> String:
	var id := Jobs.offer({"entity":entity,"client":"Actual customer","scope":"Agreed work","segment":segment,"price":1050.0,"terms":30,"payment_risk":0.0})
	Jobs.accept(id);Jobs.progress(id,1);Jobs.deliver(id);Jobs.invoice(id)
	return id
func _primaries(node: Node) -> int:
	var result := 1 if node.get_meta("primary_action",false) else 0
	for child in node.get_children():result+=_primaries(child)
	return result

func test_vat_prices_refund_caps_and_no_tax_on_capital_internal_or_wages() -> void:
	var entity := _company()
	_sale(entity,1050)
	runner.eq(-Ledger.balance(entity,"revenue"),1000.0,"inclusive sale splits net revenue")
	runner.eq(-Ledger.balance(entity,"tax_payable"),50.0,"actual collected VAT")
	Ledger.post(entity,"Capital",[{"acct":"cash","dr":1000},{"acct":"equity","cr":1000}],{"type":"capital"})
	Ledger.post("player","Wages",[{"acct":"cash","dr":100},{"acct":"wages","cr":100}],{"type":"wages"})
	Ledger.post(entity,"Internal trade",[{"acct":"ic_cost","dr":200},{"acct":"ic_revenue","cr":200}],{"type":"internal","internal":true})
	runner.eq(-Ledger.balance(entity,"tax_payable"),50.0,"capital and group transfers are not customer sales")
	Ledger.post(entity,"Customer refund",[{"acct":"refunds","dr":525},{"acct":"cash","cr":525}],{"type":"refund","id":"sale","segment":"ecommerce"})
	runner.eq(Ledger.balance(entity,"refunds"),500.0,"net refund")
	runner.eq(-Ledger.balance(entity,"tax_payable"),25.0,"refund reverses collected VAT")
	Ledger.post(entity,"Remaining refund",[{"acct":"refunds","dr":1050},{"acct":"cash","cr":1050}],{"type":"refund","id":"sale","segment":"ecommerce"})
	runner.eq(-Ledger.balance(entity,"tax_payable"),0.0,"no credit beyond actual collected tax")
	runner.check(Ledger.check_balanced(),"every split and refund balanced")

func test_personal_seller_vat_transfers_with_actual_business_without_double_credit() -> void:
	_sale("player",1050,"original")
	runner.eq(-Ledger.balance("player","tax_payable"),50.0,"personal customer sales also collect VAT")
	var entity := _company()
	runner.eq(-Ledger.balance("player","tax_payable"),0.0,"unfiled seller obligation transferred")
	runner.eq(-Ledger.balance(entity,"tax_payable"),50.0,"company assumes same obligation")
	Ledger.post(entity,"Return inherited order",[{"acct":"refunds","dr":1050},{"acct":"cash","cr":1050}],{"type":"refund","id":"original","segment":"ecommerce"})
	runner.eq(-Ledger.balance(entity,"tax_payable"),0.0,"refund rights follow actual orders")
	runner.eq(float(Tax.E("player")["sales"].get("ecommerce:original",0)),0.0,"old entity cannot claim again")
	runner.check(Ledger.check_balanced(),"transferred liability changes equity, not income")

func test_bimonth_return_payment_late_fine_credit_and_no_duplicate() -> void:
	var entity := _company();_sale(entity,1050)
	_jump(2031,7);Tax.on_hour()
	var r: Dictionary=Tax.returns(entity)[0]
	runner.eq(r["amount"],50.0,"closed May-June VAT")
	var credit := Bank.credit()
	_jump(2031,7,17);Tax.on_hour()
	runner.eq(r["fine"],25.0,"one late-filing fine")
	Tax.on_hour();runner.eq(-Ledger.balance(entity,"tax_payable"),75.0,"hourly checks cannot repeat fine")
	runner.eq(Bank.credit(),credit-12,"late filing credit consequence once")
	runner.check(Tax.file(entity,str(r["id"]),"accountant")["ok"],"paid accurate filing")
	runner.eq(r["status"],"filed","automatic scheduled completion")
	runner.eq(-Ledger.balance(entity,"tax_payable"),0.0,"payment settles actual liability")
	runner.eq(Ledger.balance(entity,"exp:tax_service"),120.0,"real accountant fee")
	runner.check(not Tax.file(entity,str(r["id"]),"diy")["ok"],"no duplicate filing")
	runner.check(Ledger.check_balanced(),"fine, fee and tax balanced")

func test_annual_pretax_loss_carry_and_tax_never_treats_its_own_expense_as_deduction() -> void:
	var entity := _company();_sale(entity,1050)
	Ledger.expense(entity,"other",1200,"Actual costs")
	_jump(2032,1);Tax.close_period(entity)
	runner.eq(Tax.E(entity)["loss"],200.0,"real operating loss carried")
	_sale(entity,1050,"nextyear")
	_jump(2033,1);Tax.close_period(entity)
	var annual: Array=Tax.returns(entity).filter(func(r):return r["kind"]=="income")
	runner.eq(annual[1]["loss_used"],200.0,"loss offsets later profit")
	runner.eq(annual[1]["amount"],160.0,"20% of 800 pretax AUD")
	_sale(entity,1050,"thirdyear")
	_jump(2034,1);Tax.close_period(entity)
	annual=Tax.returns(entity).filter(func(r):return r["kind"]=="income")
	runner.eq(annual[2]["pretax_profit"],1000.0,"previous income tax added back for pretax calculation")
	runner.eq(annual[2]["amount"],200.0,"no self-deducting tax loop")
	var count := Tax.returns(entity).size();Tax.close_period(entity)
	runner.eq(Tax.returns(entity).size(),count,"annual accrual only once")
	runner.check(Ledger.check_balanced(),"annual entries balance")

func test_paid_refund_is_credit_carry_not_free_cash_and_old_refund_has_no_fake_credit() -> void:
	var entity := _company();_sale(entity,1050)
	_jump(2031,7);Tax.close_period(entity)
	Tax.file(entity,str(Tax.returns(entity)[0]["id"]),"accountant")
	var before := Ledger.cash(entity)
	Ledger.post(entity,"Full refund",[{"acct":"refunds","dr":1050},{"acct":"cash","cr":1050}],{"type":"refund","id":"sale","segment":"ecommerce"})
	runner.eq(Ledger.cash(entity),before-1050,"customer really receives gross refund")
	runner.eq(Ledger.balance(entity,"tax_payable"),50.0,"paid tax credit carried, not paid as income")
	Ledger.post(entity,"Legacy refund",[{"acct":"refunds","dr":105},{"acct":"cash","cr":105}],{"type":"refund","id":"old_untaxed","segment":"ecommerce"})
	runner.eq(Ledger.balance(entity,"tax_payable"),50.0,"unproven old tax cannot create credit")
	_sale(entity,525,"small")
	_jump(2031,9);Tax.close_period(entity)
	runner.eq(float(Tax.E(entity)["pending"]),-25.0,"negative credit survives next period")
	runner.check(Ledger.check_balanced(),"cross-period credits balance")

func test_diy_correction_has_two_real_routes_and_timeout_finishes() -> void:
	var entity := _company();_sale(entity,1050)
	_jump(2031,7);Tax.close_period(entity)
	var chance: float=Tax.cfg()["diy_error_chance"];Tax.cfg()["diy_error_chance"]=1.0
	var r: Dictionary=Tax.returns(entity)[0]
	Tax.file(entity,str(r["id"]),"diy");Tax.cfg()["diy_error_chance"]=chance
	runner.eq(r["status"],"correction","actual timed DIY filing can need documents")
	var panel := TaxFilingModal.new(entity);UIRoot.open_modal(panel)
	await runner.get_tree().process_frame
	runner.check(panel.find_child("CorrectTax_"+str(r["id"])+"_diy",true,false)!=null,"time route")
	runner.check(panel.find_child("CorrectTax_"+str(r["id"])+"_accountant",true,false)!=null,"paid assistance route")
	runner.eq(_primaries(panel),1,"one sensible next action")
	UIRoot.close_all()
	Clock.advance(8*Clock.DAY)
	runner.eq(r["status"],"filed","ignored correction automatically finishes")
	runner.eq(Ledger.balance(entity,"exp:tax_service"),35.0,"timeout costs real money")
	runner.check(Ledger.check_balanced(),"corrected filing remains balanced")

func test_unpaid_invoice_all_three_routes_settle_ar_once_and_keep_downside() -> void:
	for route in ["settle","letter","court"]:
		runner._fresh_game()
		var entity := _company();var job := _job(entity)
		var id := Legal.unpaid(job)
		runner.check(id!="" and Jobs.get_job(job)["dispute_pause"],"actual AR paused")
		var c := Legal.get_case(id)
		runner.check(Legal.choose(id,route)["ok"],"real route "+route)
		c["terms"]["win"]=1.0
		var revenue := Ledger.balance(entity,"revenue")
		Clock.advance(int(c["terms"]["days"])*Clock.DAY)
		runner.eq(c["status"],"resolved","scheduled result")
		runner.eq(Ledger.balance(entity,"accounts_receivable"),0.0,"existing receivable settled")
		runner.eq(c["recovered"],snappedf(1050*float(c["terms"]["recovery"]),.01),"agreed recovery")
		runner.eq(Ledger.balance(entity,"revenue"),revenue,"no second sale")
		var cash := Ledger.cash(entity);Legal.handle("gov.legal_result",{"id":id,"entity":entity})
		runner.eq(Ledger.cash(entity),cash,"no second settlement")
		runner.check(float(c["terms"]["win"])>float(Legal.options()[route]["win"]),"production still has downside risk")
		runner.check(Ledger.check_balanced(),"each legal branch balances")

func test_court_loss_timeout_and_customer_risk_resume_without_soft_lock() -> void:
	var entity := _company();var job := _job(entity)
	var id := Legal.unpaid(job)
	Legal.choose(id,"court");Legal.get_case(id)["terms"]["win"]=0.0
	Clock.advance(21*Clock.DAY)
	runner.eq(Legal.get_case(id)["recovered"],0.0,"lost court collects nothing")
	runner.eq(Ledger.balance(entity,"exp:bad_debt"),1050.0,"actual invoice written off")
	runner.check(not Jobs.get_job(job)["dispute_pause"],"case pause ends")
	var next := _job(entity);var next_id := Legal.unpaid(next)
	Clock.advance(17*Clock.DAY)
	runner.eq(Legal.get_case(next_id)["status"],"resolved","ignored case auto-selects settlement then completes")
	runner.check(Ledger.check_balanced(),"loss remains balanced")

func test_supplier_breach_keeps_paid_construction_and_resumes_work() -> void:
	var entity := _company()
	var job := Jobs.offer({"entity":entity,"client":"Actual builder","scope":"Construction","segment":"real_estate","price":1000,"work":2,"direction":"purchase","due":Clock.now()+1})
	Jobs.accept_purchase(job);Jobs.purchase_milestone(job,500,1,"construction_in_progress")
	runner.eq(Legal.supplier_breach(job),"","not a breach before contractual due time")
	Clock.advance(2)
	var id := Legal.supplier_breach(job);Legal.choose(id,"letter");Legal.get_case(id)["terms"]["win"]=1.0
	runner.check(not Jobs.purchase_milestone(job,500,1,"construction_in_progress")["ok"],"paused while awaiting a response")
	Clock.advance(5*Clock.DAY)
	runner.eq(Legal.supplier_breach(job),"","same breach cannot create repeated compensation")
	runner.eq(Ledger.balance(entity,"construction_in_progress"),500.0,"paid asset never erased")
	runner.eq(Jobs.get_job(job)["paid_cost"],500.0,"no phantom unpaid milestone")
	runner.check(Jobs.purchase_milestone(job,500,1,"construction_in_progress")["ok"],"work resumes after case")
	runner.check(Ledger.check_balanced(),"compensation and real construction balance")

func test_employee_earned_wages_and_ip_defence_never_create_fake_income() -> void:
	var entity := _company()
	Ledger.post(entity,"Earned wages",[{"acct":"exp:payroll","dr":600},{"acct":"wages_payable","cr":600}],{"type":"payroll"})
	var id := Legal.employee_dispute(entity);Legal.choose(id,"court");Legal.get_case(id)["terms"]["win"]=1.0
	Clock.advance(21*Clock.DAY)
	runner.eq(Ledger.balance(entity,"wages_payable"),0.0,"winning defence still pays earned wages")
	var job := _job(entity,"media");Jobs.handle("job.pay",{"id":job})
	var ip := Legal.ip_dispute(job);Legal.choose(ip,"letter");Legal.get_case(ip)["terms"]["win"]=1.0
	var income := Ledger.balance(entity,"other_income")
	Clock.advance(5*Clock.DAY)
	runner.eq(Ledger.balance(entity,"other_income"),income,"successful IP defence creates no cash income")
	runner.eq(Legal.ip_dispute(job),"","same completed job cannot generate repeat claims")
	runner.check(Ledger.check_balanced(),"wages and licence outcomes balance")

func test_insurance_actual_loss_waiting_duplicate_limit_and_cash_collection() -> void:
	var entity := _company();Insurance.buy(entity,"property")
	var early := Ledger.expense(entity,"maintenance",1000,"Actual early damage",Insurance.loss_source({"type":"crisis","segment":"hotel"},"property"))
	runner.eq(Insurance.S()["claims"].size(),0,"waiting period is real")
	Clock.advance(7*Clock.DAY)
	runner.eq(Insurance.claim(entity,"property",int(early["n"])),0.0,"cannot retrospectively insure a prior loss")
	var cash := Ledger.cash(entity)
	var loss := Ledger.expense(entity,"maintenance",1000,"Actual storm repair",Insurance.loss_source({"type":"crisis","segment":"hotel"},"property"))
	runner.eq(Ledger.cash(entity),cash-1000,"repair paid first")
	runner.eq(Ledger.balance(entity,"insurance_receivable"),650.0,"80% less actual 150 AUD deductible")
	runner.eq(Insurance.claim(entity,"property",int(loss["n"])),0.0,"no duplicate claim")
	var fine := Ledger.expense(entity,"penalties",500,"Actual fine",Insurance.loss_source({"type":"crisis"},"property"))
	runner.eq(Insurance.claim(entity,"property",int(fine["n"])),0.0,"fines excluded")
	var ordinary := Ledger.expense(entity,"maintenance",200,"Routine care")
	runner.eq(Insurance.claim(entity,"property",int(ordinary["n"])),0.0,"routine costs are not crises")
	Clock.advance(2*Clock.DAY)
	runner.eq(Ledger.balance(entity,"insurance_receivable"),0.0,"insurer pays the approved receivable")
	runner.check(Insurance.S()["claims"].values()[0]["status"]=="paid","actual payout state")
	runner.check(Ledger.check_balanced(),"approval and collection are separate balanced entries")

func test_brand_components_news_decay_and_actual_recruit_bid_apr_effects() -> void:
	var entity := _company()
	runner.eq(Brand.score(entity),50.0,"neutral company")
	Brand.record(entity,"news",20);Brand.record(entity,"crises",20);Brand.record(entity,"payments",20);Brand.record(entity,"employees",20)
	var parts := Brand.components(entity);var expected := 0.0
	for key in parts:expected+=float(parts[key])*float(Brand.cfg()["brand_weights"][key])
	runner.eq(Brand.score(entity),snappedf(expected,.1),"five components weighted once")
	runner.check(Brand.apr_adjustment()<0,"good brand lowers offered APR")
	runner.check(Rivals.bid_chance(.5,[])>.5,"brand changes actual B2B willingness")
	runner.check(Brand.applicant_count(3)>3,"recruitment pool changes")
	_jump(2031,10)
	runner.eq(Brand.components(entity)["news"],50.0,"event reputation fades")
	for i in range(100):Brand.record(entity,"news",1)
	runner.eq(Brand.E(entity)["events"].size(),64,"bounded event history")

func test_registry_save_old_schema_closed_company_and_single_primary() -> void:
	var entity := _company();_sale(entity,1050)
	_jump(2031,7);Tax.close_period(entity)
	var panel := TaxFilingModal.new(entity);Help.auto=false;UIRoot.open_modal(panel)
	await runner.get_tree().process_frame
	runner.eq(_primaries(panel),1,"one tax next action")
	UIRoot.close_all();Help.auto=true
	runner.check(Industries.find("governance")["service"],"service is registered")
	runner.check(not Industries.all().any(func(e):return e["id"]=="governance"),"not a fabricated sales segment")
	Insurance.buy(entity,"property");Brand.record(entity,"news",4)
	SaveSystem.save(96);runner.check(SaveSystem.load_data(96),"normal service save loads")
	runner.eq(Tax.returns(entity)[0]["amount"],50.0,"tax return persisted")
	runner.check(Insurance.policies(entity)["property"]["active"],"cover persisted")
	var old := GameState.data.duplicate(true)
	for key in ["tax_service","legal_service","insurance_service","brand_service"]:old.erase(key)
	var journal: Array=old["ledger"]["journal"].duplicate(true)
	GameState.data=SaveSystem._migrate(old)
	Tax.E(entity);Legal.S();Insurance.S();Brand.E(entity)
	runner.eq(GameState.data["ledger"]["journal"],journal,"old schema load does not rewrite historical money")
	Governance.on_company_closed(entity)
	GameState.data["entities"][entity]["closed"]=Clock.now()
	runner.check(not Tax.file(entity,"TAX-1","diy")["ok"],"closed tax entity cannot charge a replacement")
	runner.check(not Insurance.buy(entity,"property")["ok"],"closed entity cannot buy cover")
	runner.check(Ledger.check_balanced(),"migration and closed guards balance")


func test_legal_client_terms_are_real_and_expire() -> void:
	var entity := _company();var job := _job(entity)
	var id := Legal.unpaid(job);Legal.choose(id,"court");Legal.get_case(id)["terms"]["win"]=0.0
	Clock.advance(21*Clock.DAY)
	var next := Jobs.offer({"entity":entity,"client":"Actual customer","scope":"Next work","price":1000,"deposit":.5})
	runner.eq(Jobs.get_job(next)["deposit"],.3,"court reduces this client's actual advance from 50% to 30%")
	Jobs.accept(next);runner.eq(Jobs.get_job(next)["deposit_paid"],300.0,"real cash deposit follows negotiated terms")
	Clock.advance(31*Clock.DAY)
	runner.eq(Legal.client_relationship(entity,"Actual customer"),50,"client consequence expires")
	runner.eq(Legal.client_relationship(entity,"Different customer"),50,"unrelated parties unaffected")
	runner.check(Ledger.check_balanced(),"changed advance is not invented income")

func test_insurance_limit_lapse_renewal_and_liquidation() -> void:
	var entity := _company();Insurance.buy(entity,"property")
	Clock.advance(7*Clock.DAY)
	Ledger.expense(entity,"maintenance",8000,"Actual storm",Insurance.loss_source({"type":"crisis","segment":"real_estate"},"property"))
	runner.eq(Ledger.balance(entity,"insurance_receivable"),5000.0,"actual policy limit")
	Ledger.expense(entity,"maintenance",1000,"Further storm",Insurance.loss_source({"type":"crisis","segment":"real_estate"},"property"))
	runner.eq(Ledger.balance(entity,"insurance_receivable"),5000.0,"period cap across losses")
	Insurance.on_company_closed(entity)
	runner.eq(Ledger.balance(entity,"insurance_receivable"),0.0,"liquidation handles pending claims")
	runner.eq(Ledger.balance(entity,"accounts_receivable"),5000.0,"existing collector can recover insurer debt")
	Clock.advance(2*Clock.DAY)
	runner.eq(Ledger.balance(entity,"accounts_receivable"),5000.0,"cancelled insurer schedule cannot pay twice")
	runner._fresh_game();entity=_company();Insurance.buy(entity,"property")
	var p: Dictionary=Insurance.policies(entity)["property"]
	Ledger.expense(entity,"other",Ledger.cash(entity),"Actual running costs")
	GameState.data["clock"]["minutes"]=int(p["until"]);Insurance.on_hour()
	runner.check(not p["active"],"unfunded renewal lapses")
	Clock.advance(2*Clock.DAY)
	Company.transfer("player",entity,1000)
	Insurance.on_hour()
	runner.check(p["active"] and not Insurance.covered(entity,"property"),"funded renewal resumes with a new waiting period")
	Clock.advance(7*Clock.DAY)
	runner.check(Insurance.covered(entity,"property"),"renewed cover becomes usable")
	runner.check(Ledger.check_balanced(),"renewals and closure balance")

func test_zero_tax_period_cannot_fine_an_inactive_person_or_lossmaking_company() -> void:
	var entity := _company();Tax.E("player")
	_jump(2032,1);Tax.on_hour()
	var credit := Bank.credit()
	_jump(2032,2);Tax.on_hour()
	for ent in [entity,"player"]:
		for r in Tax.returns(ent):runner.eq(r["status"],"filed","zero liability closes automatically")
		runner.eq(-Ledger.balance(ent,"tax_payable"),0.0,"no fine manufactured from a zero return")
	runner.eq(Bank.credit(),credit,"inactive personal seller not punished")

func test_brand_uses_actual_hotel_review_array_and_wages() -> void:
	var entity := _company()
	Hotel.S()["entity"]=entity;Hotel.S()["active"]=true
	Hotel.S()["reviews"]=[{"score":4.0,"w":2.0},{"score":2.0,"w":1.0}]
	runner.eq(Brand.components(entity)["reviews"],float(10)/3*20,"hotel review weights included")
	Ledger.post(entity,"Actual earned wages",[{"acct":"exp:payroll","dr":200},{"acct":"wages_payable","cr":200}],{"type":"payroll"})
	runner.check(Brand.components(entity)["employees"]<50,"unpaid actual wages reduce employee standing")
	runner.check(Ledger.check_balanced(),"brand observations do not invent money")

func test_legal_routes_each_win_for_some_dispute_size_and_none_is_recommended() -> void:
	var options: Dictionary = Legal.options()
	var best := {}
	for amount in [100.0, 600.0, 2000.0, 6000.0]:
		var top := ""
		var top_ev := -INF
		for route in options:
			var terms: Dictionary = options[route]
			runner.check(not terms.has("recommended"), "no recommended legal route: " + route)
			var ev := float(amount) * float(terms["win"]) * float(terms["recovery"]) - float(terms["fee"])
			if ev > top_ev:
				top_ev = ev
				top = route
		best[top] = true
	runner.eq(best.size(), 3, "settle, letter and court each have the best expected value somewhere")

func test_input_vat_credit_reduces_the_return_and_offsets_cost_not_income() -> void:
	var entity := _company()
	_sale(entity, 2100)
	Ledger.post(entity, "Stock purchase", [{"acct": "inventory_in_transit", "dr": 1050}, {"acct": "cash", "cr": 1050}], {"type": "po", "id": "PO-X", "segment": "ecommerce"})
	var income_before := Ledger.balance(entity, "other_income")
	_jump(2031, 7)
	Tax.close_period(entity)
	var r: Dictionary = Tax.returns(entity)[0]
	runner.eq(float(r["amount"]), 50.0, "100 output VAT less 50 recoverable input VAT")
	runner.eq(Ledger.balance(entity, "other_income"), income_before, "credit is not income")
	runner.eq(Ledger.balance(entity, "cogs"), -50.0, "credit offsets the cost of goods")
	runner.check(Ledger.check_balanced(), "balanced")

func test_written_off_invoice_recovers_its_vat_against_bad_debt() -> void:
	var entity := _company()
	var job := _job(entity)
	var id := Legal.unpaid(job)
	Legal.choose(id, "letter")
	Legal.get_case(id)["terms"]["win"] = 0.0
	var vat_before := -Ledger.balance(entity, "tax_payable")
	Legal.handle("gov.legal_result", {"id": id, "entity": entity})
	runner.check(-Ledger.balance(entity, "tax_payable") < vat_before - 40.0, "output VAT on the lost invoice is recovered")
	runner.check(Ledger.check_balanced(), "balanced")

func test_late_return_accrues_interest_per_period_and_nil_returns_send_no_reminder() -> void:
	var entity := _company()
	_sale(entity, 1050)
	_jump(2031, 7)
	Tax.close_period(entity)
	var r: Dictionary = Tax.returns(entity)[0]
	GameState.data["clock"]["minutes"] = int(r["due"]) + 1
	Tax.on_hour()
	var fine := float(r["fine"])
	GameState.data["clock"]["minutes"] = int(r["due"]) + 65 * Clock.DAY
	Tax.on_hour()
	runner.check(float(r["fine"]) > fine, "interest accrues for each further period")
	var again := float(r["fine"])
	Tax.on_hour()
	runner.eq(float(r["fine"]), again, "same period never repeats")
	var messages := GameState.data["messages"].size()
	var nil_entity := _company()
	_jump(2033, 7)
	Tax.close_period(nil_entity)
	runner.eq(GameState.data["messages"].size(), messages, "a nil return creates no reminder")
