extends Node
## Actual café transactions for 120 days, three policies and three disclosed footfall scenarios.
var rows: Array=[]
func _ready() -> void:call_deferred("run")
func run() -> void:
	for strategy in ["conservative","normal","aggressive"]:
		for scenario in ["baseline","mild","stress"]:simulate(strategy,scenario)
	var grouped: Dictionary={}
	for strategy in ["conservative","normal","aggressive"]:
		var sum:=0.0;var losses:=0
		for row in rows:
			if row["strategy"]==strategy:sum+=float(row["profit"]);losses+=1 if float(row["profit"])<0 else 0
		grouped[strategy]={"mean_profit_dollars":snappedf(sum/3,.01),"losses":losses}
	var out: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var f:=FileAccess.open(out.path_join("cafe_balance_120.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"days":120,"scenarios":"baseline 240, mild 220, stress 100 passers/day; randomized customer arrivals; no artificial receipts","strategies":grouped,"runs":rows},"\t"))
	print("CAFE BALANCE ",grouped)
	get_tree().quit()
func simulate(strategy: String,scenario: String) -> void:
	Clock.clear_pauses();Clock.world_active=false
	GameState.new_game({"name":"Café balance","seed":33001 if scenario=="baseline" else 33002 if scenario=="mild" else 33003})
	DataDB.economy["cafe"]["footfall_day"]=240 if scenario=="baseline" else 220 if scenario=="mild" else 100
	Company.register("Café balance","retail_online","Lantern Row");Company.open_business_account(20000)
	var entity:=GameState.company_id()
	Ledger.post(entity,"QA equity",[{"acct":"cash","dr":40000},{"acct":"equity","cr":40000}],{"type":"qa_fixture"})
	var start:=Clock.now()
	Living.lease("corner_cafe");Cafe.fit_out();Cafe.apply_permit();Cafe.set_pastry_order(8 if strategy=="conservative" else 15 if strategy=="normal" else 35)
	Cafe.set_price("coffee",5.0)
	if strategy!="conservative":
		Staff.register_employer();Staff.post_job("barista");Clock.advance(19*60)
		if not Staff.S()["applicants"].is_empty():Staff.hire(Staff.S()["applicants"][0]["id"])
	if strategy=="aggressive":
		Living.lease("popup_cafe");Cafe.in_shop("popup_cafe",func():Cafe.fit_out();Cafe.apply_permit();Cafe.set_pastry_order(35))
		Staff.post_job("barista");Clock.advance(19*60)
		if not Staff.S()["applicants"].is_empty():
			Staff.hire(Staff.S()["applicants"][0]["id"])
			var worker: Dictionary=Staff.people()[-1]
			Cafe.in_shop("popup_cafe",func():
				CafeDepth.roster()[worker["id"]]={}
				for d in range(1,7):CafeDepth.assign(worker["id"],d,"early"))
	while Clock.now()<start+120*Clock.DAY:
		for property in ["corner_cafe","popup_cafe"]:
			Cafe.in_shop(property,func():
				if not Cafe.leased():return
				if int(Cafe.S()["supplies"])+int(Cafe.S()["incoming"])<150:Cafe.order_supplies("large")
				for material in ["milk","tea","food"]:
					if int(Cafe.S()["materials"].get(material,0))+int(Cafe.S()["material_incoming"].get(material,0))<40:CafeDepth.order(material)
				if Cafe.S()["inspection_pending"]:EventEngine.choose(Cafe.S()["inspection_iid"],"prepare")
				if Cafe.ready_to_open() and Clock.hour()==17:CafeDepth.clean())
		var before:=Clock.now()
		if Cafe.ready_to_open() and Clock.hour()>=7 and Clock.hour()<16 and Cafe.open_day(Clock.now()) and (strategy=="conservative" or Clock.hour()>=12):Cafe.owner_shift(.9)
		else:Clock.advance(60)
		if Clock.now()==before:Clock.advance(60)
	var revenue:= -Ledger.balance(entity,"revenue")
	var profit:=Ledger.lifetime_gross_profit(entity)
	for account in GameState.data["ledger"]["balances"].get(entity,{}):
		if str(account).begins_with("exp:"):profit-=Ledger.balance(entity,account)
	print("Completed ",strategy," ",scenario," profit ",profit)
	rows.append({"strategy":strategy,"scenario":scenario,"profit":snappedf(float(profit),.01),"revenue_dollars":revenue,"balanced":Ledger.check_balanced(),"customers":Cafe.last_days(60,"served")})
