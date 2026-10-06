class_name CityFuture
extends RefCounted
## Third-season civic contracts. Purchases buy services; civic outcomes never create sales income.
static func cfg() -> Dictionary:return DataDB.economy.get("city_future",{})
static func mods() -> Dictionary:return DataDB.year_def(11 if World.year()<12 else 12).get("city_modifiers",{})
static func S() -> Dictionary:
	if not GameState.data.has("city_future"):GameState.data["city_future"]={}
	var state: Dictionary=GameState.data["city_future"]
	var defaults: Dictionary={"current":0,"chapters":{},"expo_awarded":false,"harbor_quality":0.0,"transition":"","candidate":"","elected":"","brand":0.0,"peak":{},"crises":{},"options":[],"cards":[],"viewed":0}
	for key in defaults:
		if not state.has(key):state[key]=defaults[key]
	return state
static func definition(number: int) -> Dictionary:return cfg().get("chapters",{}).get(str(number),{})
static func chapter(number := 0) -> Dictionary:return S()["chapters"].get(str(int(S()["current"]) if number==0 else number),{})
static func error(text: String) -> Dictionary:return {"ok":false,"error":I18n.t(text)}
static func eligible() -> bool:return "ch18_legacy" in StoryEngine.St()["chapters_done"] or GameState.flag("legacy_cards_viewed")
static func available() -> bool:return eligible() or int(S()["current"])>0
static func start() -> Dictionary:
	if not eligible():return error("Finish the second-season epilogue before joining the city proposal.")
	if int(S()["current"])==0:StoryEngine.start_chapter(definition(19)["id"])
	return {"ok":true}
static func begin(number: int) -> void:
	if definition(number).is_empty():return
	if not S()["chapters"].has(str(number)):
		S()["chapters"][str(number)]={"number":number,"entity":GameState.company_id(),"started":Clock.now(),"deadline":Clock.now()+int(definition(number)["deadline_days"])*Clock.DAY,"contracts":[],"mode":"","tier":"","decision":"","quality":0.0,"status":"active","review_at":0,"result":{}}
	S()["current"]=number
	if number==20 and not S()["crises"].has("harbor_storm"):
		S()["crises"]["harbor_storm"]={"from":Clock.now(),"until":Clock.now()+int(mods()["storm_days"])*Clock.DAY,"mult":float(mods()["storm_mult"])}
	GameState.add_message(str(definition(number)["npc"]),I18n.t(str(definition(number)["title"])))
static func read_brief() -> Dictionary:
	var c:=chapter()
	if c.is_empty():return error("Join the city proposal first.")
	GameState.set_flag("city%d_read"%int(c["number"]))
	StoryEngine.check();return {"ok":true}
static func sponsor() -> String:
	var id: String="city_future_budget"
	if not GameState.data["entities"].has(id):
		GameState.data["entities"][id]={"id":id,"name":I18n.t("Aurelia Civic Partnership Board"),"kind":"municipal","bank_account":false,"registered":Clock.now()}
		Ledger.post(id,I18n.t("Council-authorized civic appropriation"),[{"acct":"cash","dr":float(cfg()["municipal_budget"])},{"acct":"equity","cr":float(cfg()["municipal_budget"])}],{"type":"civic_budget"})
	return id
static func private_payer(c: Dictionary) -> String:
	# The chapter keeps the company chosen when it began; a closed owner returns "" so nothing silently falls back to personal cash.
	var ent: String=str(c.get("entity",""))
	if ent=="":return "player"
	return ent if GlobalMarket.live(ent) else ""
static func _in_owner(c: Dictionary,fn: Callable) -> Variant:return CompanyPortfolio.run_in(str(c.get("entity","")),fn)
static func contract_cost(number: int,premium: bool) -> float:
	var total:=0.0
	for service in definition(number).get("services",[]):total+=int(service["units"])*float(service["unit_cost"])
	return snappedf(total*(float(cfg()["premium_cost_factor"]) if premium else 1.0),.01)
static func procure(mode: String,premium := false) -> Dictionary:
	var c:=chapter()
	if c.is_empty():return error("Join the city proposal first.")
	return _in_owner(c,func():return _procure(c,mode,premium))
static func _procure(c: Dictionary,mode: String,premium: bool) -> Dictionary:
	if c.is_empty() or c["status"]!="active" or c["mode"]!="" or Clock.now()>int(c["deadline"]):return error("This service plan is already arranged or its deadline has passed.")
	if mode not in ["fund","partner"]:return error("Choose funded delivery or the civic partnership.")
	var payer: String=private_payer(c) if mode=="fund" else sponsor()
	if payer=="":return error("The company that owns this proposal is closed. Join the civic partnership instead.")
	var cost:=contract_cost(int(c["number"]),premium)
	if Ledger.cash(payer)<cost:return error("Keep the service budget or join the civic partnership instead.")
	c["mode"]=mode;c["tier"]="premium" if premium else "basic"
	for service in definition(int(c["number"]))["services"]:
		var price: float=snappedf(float(service["unit_cost"])*int(service["units"])*(float(cfg()["premium_cost_factor"]) if premium else 1.0),.01)
		var job: String=Jobs.offer({"entity":payer,"client":I18n.t("Civic supplier")+" · "+str(service["industry"]),"scope":I18n.t(str(service["scope"])),"price":price,"work":int(service["units"]),"terms":0,"direction":"purchase","due":Clock.now()+int(service["days"])*Clock.DAY,"segment":service["industry"]})
		Jobs.accept_purchase(job);Jobs.purchase_milestone(job,price,0,"exp:other")
		var receipt: Dictionary={"job":job,"payer":payer,"service":service.duplicate(true),"eta":Clock.now()+int(service["days"])*Clock.DAY,"status":"paid","quality":0.0}
		c["contracts"].append(receipt)
	GameState.timeline(I18n.t("Civic services ordered: %s home dollars.")%Fmt.money(cost),"business",{"category":"city"})
	return {"ok":true}
static func _settle(c: Dictionary,receipt: Dictionary) -> void:
	if receipt["status"]!="paid" or Clock.now()<int(receipt["eta"]):return
	_in_owner(c,func():_settle_here(c,receipt))
## Jobs live in the company that procured them, so settlement always runs inside that company.
static func _settle_here(c: Dictionary,receipt: Dictionary) -> void:
	var job:=Jobs.get_job(receipt["job"])
	if not Assets._valid_entity(receipt["payer"]):receipt["status"]="closed";return
	var premium: bool=c["tier"]=="premium"
	var fail: bool=GameState.randf()<float(cfg()["contract_failure_premium"] if premium else cfg()["contract_failure_basic"])
	if fail:receipt["status"]="failed";job["status"]="closed";return
	Jobs.progress(receipt["job"],float(receipt["service"]["units"]));Jobs.deliver(receipt["job"])
	receipt["status"]="delivered";receipt["delivered_at"]=Clock.now();receipt["delivered_units"]=receipt["service"]["units"]
	receipt["quality"]=float(cfg()["premium_quality"] if premium else cfg()["basic_quality"])
static func choice_block(choice: String) -> String:
	var c:=chapter()
	if c.is_empty() or c["decision"]!="":return "This civic decision is already recorded. Review its result."
	if c["status"]!="active" or Clock.now()>int(c["deadline"]):return "The submission deadline passed. Review the failed proposal and continue."
	if not choice in definition(int(c["number"]))["choices"]:return "Choose an available civic decision."
	if not GameState.flag("city%d_plan"%int(c["number"])):return "Wait for paid suppliers to deliver, or review their failure at the deadline."
	if int(c["number"])==22 and choice in ["salary","options"]:
		if private_payer(c) in ["player",""] or Staff.people().is_empty():return "No owned team is available. Choose the culture partnership instead."
		if choice=="options" and float(GameState.data.get("cap_table",{}).get("founder",0))<=.5:return "The board will not authorize options. Choose wages or culture instead."
	return ""
static func _expense(c: Dictionary,amount: float,memo: String) -> bool:
	var payer: String=sponsor() if c["mode"]=="partner" else private_payer(c)
	if payer=="" or Ledger.cash(payer)<amount:return false
	Ledger.expense(payer,"other",amount,I18n.t(memo),{"type":"civic_choice","chapter":c["number"]})
	return true
static func choose(choice: String) -> Dictionary:
	reconcile()
	var owner:=chapter()
	if owner.is_empty():return error("Join the city proposal first.")
	return _in_owner(owner,func():return _choose(choice))
static func _choose(choice: String) -> Dictionary:
	var why:=choice_block(choice)
	if why!="":return error(why)
	var c:=chapter();var num: int=c["number"]
	match num:
		19:
			if choice=="premium" and not _expense(c,float(cfg()["assurance_fee"]),"Independent expo assurance fee"):return error("Fund the assurance fee or submit the balanced bid.")
			var quality: float=clampf(float(c["quality"])+(float(cfg()["assurance_quality_bonus"]) if choice=="premium" else 0.0)+Partnerships.expo_quality_bonus(),0,1)
			S()["expo_awarded"]=choice!="withdraw" and GameState.randf()<clampf(float(cfg()["expo_probability_base"])+float(cfg()["expo_probability_quality"])*quality,float(cfg()["expo_probability_base"]),float(cfg()["expo_probability_max"]))
			c["result"]={"quality":quality,"approved":S()["expo_awarded"]}
		20:
			var rival_quality: float=GameState.rng.randf_range(float(cfg()["rival_quality_min"]),float(cfg()["rival_quality_max"]))
			var quality: float=clampf(float(c["quality"])-(float(cfg()["low_bid_quality_penalty"]) if choice=="low_bid" else 0.0),0,1)
			if choice=="favor":
				quality=0;_favor_consequences(c)
			if choice=="low_bid":
				for receipt in c["contracts"]:
					if receipt["service"]["industry"]!="manufacturing" or receipt["status"]!="delivered" or not Assets._valid_entity(receipt["payer"]):continue
					var job:=Jobs.get_job(receipt["job"])
					var returned: int=floori(int(receipt["delivered_units"])*float(cfg()["material_return_fraction"]))
					var refund: float=snappedf(float(job["paid_cost"])*returned/maxf(1,float(receipt["delivered_units"])),.01)
					if refund>0:Ledger.post(receipt["payer"],I18n.t("Unused reconstruction materials returned to the supplier"),[{"acct":"cash","dr":refund},{"acct":"exp:other","cr":refund}],{"type":"civic_return","job":receipt["job"]})
					receipt["returned_units"]=returned;receipt["delivered_units"]=int(receipt["delivered_units"])-returned;job["paid_cost"]=float(job["paid_cost"])-refund
			S()["harbor_quality"]=maxf(0,quality);c["result"]={"quality":quality,"rival_quality":rival_quality,"won":quality>rival_quality and choice!="favor"}
		21:
			var cost: float=float(cfg()["transition_costs"][choice])
			if choice=="delay":
				if not _expense(c,cost,"Public vehicle transition consultation"):return error("Keep the consultation budget or join the city partnership.")
			else:
				var payer: String=sponsor() if c["mode"]=="partner" else private_payer(c)
				if payer=="":return error("The company that owns this proposal is closed. Join the civic partnership instead.")
				var asset:=Assets.buy({"entity":payer,"name":"Civic charging network","price":cost,"life_days":int(cfg()["charging_life_days"]),"maintenance_cost":float(cfg()["charging_maintenance_cost"]),"maintenance_days":int(cfg()["charging_maintenance_days"]),"failure_chance":float(cfg()["charging_failure_chance"]),"segment":"energy"})
				if not asset["ok"]:return asset
				c["network_asset"]=asset["id"]
			S()["transition"]=choice;c["result"]={"cost":cost,"transition":choice}
		22:
			var affected: Array=[]
			if choice=="salary":
				for person in Staff.people():Staff.give_raise(person["id"]);affected.append(person["id"])
			elif choice=="options":
				if not CapitalMarket.board_grant_approve():return error("The board will not authorize options. Choose wages or culture instead.")
				for person in Staff.people():affected.append(person["id"])
				S()["options"].append({"entity":c["entity"],"people":affected,"share":float(cfg()["option_share"]),"vest_at":Clock.now()+int(cfg()["vesting_days"])*Clock.DAY,"status":"pending"})
			elif choice=="volunteer":
				Clock.advance(int(cfg()["volunteer_minutes"]))
			else:
				if c["mode"]!="partner" and not _expense(c,float(cfg()["workshop_fee"]),"Paid workplace culture workshop"):return error("Fund the workshop or continue the civic volunteer program.")
				Clock.advance(int(cfg()["workshop_minutes"]))
				if not private_payer(c) in ["player",""]:
					for person in Staff.people():person["morale"]=mini(100,int(person["morale"])+int(cfg()["culture_morale_bonus"]));affected.append(person["id"])
			S()["brand"]=float(S()["brand"])+float(cfg()["culture_brand_gain"] if choice=="culture" else cfg()["volunteer_brand_gain"] if choice=="volunteer" else cfg()["other_talent_brand_gain"])
			c["result"]={"people":affected,"policy":choice,"retention_until":Clock.now()+int(cfg()["retention_days"])*Clock.DAY}
		23:
			# Campaign participation takes actual personal time, never municipal campaign money.
			if choice!="neutral":Clock.advance(int(cfg()["campaign_minutes"]))
			S()["candidate"]=choice
			for npc in ["mayor_green","mayor_enterprise"]:
				if not GameState.data["npcs"].has(npc):GameState.data["npcs"][npc]={"met":false}
				GameState.data["npcs"][npc]["civic_support"]=1 if choice==npc.trim_prefix("mayor_") else 0
			var probability: float=clampf(float(cfg()["election_base"])+(float(cfg()["campaign_probability_change"]) if choice=="green" else -float(cfg()["campaign_probability_change"]) if choice=="enterprise" else 0)+float(S()["brand"])*float(cfg()["brand_probability_weight"]),float(cfg()["election_probability_min"]),float(cfg()["election_probability_max"]))
			S()["elected"]="green" if GameState.randf()<probability else "enterprise"
			c["result"]={"support":choice,"green_probability":probability,"winner":S()["elected"]}
		24:
			if choice=="resilient" and not _expense(c,float(cfg()["standby_fee"]),"Paid standby crew for the city event"):return error("Fund the standby crew or choose the economy event.")
			var mult: float=1.0 if choice=="cancel" else float(mods()["event_peak_mult"] if S()["expo_awarded"] else mods()["local_event_mult"])
			S()["peak"]={"from":Clock.now(),"until":Clock.now()+int(cfg()["peak_days"])*Clock.DAY,"mult":mult}
			if choice!="cancel":
				for industry in ["energy","logistics","hotel"]:S()["crises"][industry]={"from":Clock.now(),"until":Clock.now()+int(mods()["event_crisis_days"])*Clock.DAY,"mult":clampf(float(mods()["resilient_crisis_mult"] if choice=="resilient" else mods()["economy_crisis_mult"])+float(S()["harbor_quality"])*float(mods()["harbor_quality_crisis_weight"]),.5,.95)}
			c["result"]={"expo":S()["expo_awarded"],"harbor_quality":S()["harbor_quality"],"mayor":S()["elected"],"event":choice}
	c["decision"]=choice;c["review_at"]=Clock.now()+int(cfg()["review_days"])*Clock.DAY
	GameState.set_flag("city%d_choice"%num);StoryEngine.check();return {"ok":true}
## No payment to an official is ever possible: the approach is reported, disqualified and investigated (red line, see wiki 35).
static func _favor_consequences(c: Dictionary) -> void:
	GameState.set_flag("city_disqualified");S()["brand"]=float(S()["brand"])-float(cfg()["secret_favor_brand_loss"])
	var owner:=private_payer(c)
	if owner=="player":owner=""
	if owner!="":
		Brand.record(owner,"news",-float(cfg()["favor_news_brand_hit"]))
		Legal.open_integrity_probe(owner,float(cfg()["favor_fine"]),I18n.t("Anti-corruption office"))
	else:
		# A private citizen has no company books: the fine and legal cost are paid from personal cash.
		var total:=float(cfg()["favor_fine"])+float(Legal.options()[Legal.cfg()["integrity_option"]]["fee"])
		Ledger.expense("player","legal",total,I18n.t("Anti-corruption fine and legal cost"),{"type":"integrity_fine","chapter":c["number"]},"cash" if Ledger.cash("player")>=total else "accounts_payable")
	PersonalLife.change(str(definition(19).get("npc","expo_officer")),-float(cfg()["favor_relationship_loss"]))
	GameState.timeline(I18n.t("The secret-favor approach was reported to the anti-corruption office. No payment was made; the bid was disqualified, a fine and legal costs follow, and the expo office trusts you less."),"crisis",{"category":"city"})
static func review() -> Dictionary:
	reconcile();var c:=chapter()
	if c.is_empty():return error("Join the city proposal first.")
	if c["status"]=="reviewed":return {"ok":true}
	if c["decision"]=="" or Clock.now()<int(c["review_at"]):return error("Wait for the civic result before reviewing this chapter.")
	var num: int=c["number"];c["status"]="reviewed"
	if num==24:
		S()["cards"]=[] # Do not rewrite the prior business ending.
		for n in range(19,25):S()["cards"].append({"title":definition(n)["title"],"result":chapter(n).get("result",{}).duplicate(true)})
	GameState.timeline(I18n.t("Civic chapter %d reviewed from recorded deliveries and decisions.")%num,"story")
	GameState.set_flag("city%d_review"%num);StoryEngine.check();return {"ok":true}
static func reconcile() -> void:
	if not GameState.data.has("city_future"):return
	for option in S()["options"]:
		if option["status"]!="pending":continue
		if not GlobalMarket.live(option["entity"]):option["status"]="forfeited";continue
		if Clock.now()<int(option["vest_at"]):continue
		CompanyPortfolio.run_in(str(option["entity"]),func():_vest_option(option))
	var talent: Dictionary=chapter(22)
	if not talent.is_empty() and talent["decision"]!="" and not talent.get("poaching_resolved",false) and Clock.now()>=int(talent["review_at"])+int(cfg()["poaching_delay_days"])*Clock.DAY:
		var owner: String=talent.get("entity","")
		if owner!="" and GlobalMarket.live(owner):CompanyPortfolio.run_in(owner,func():_resolve_poaching(talent))
		else:talent["poaching_resolved"]=true;talent["result"]["departed"]=[]
	for c in S()["chapters"].values():
		if c["status"]=="reviewed":continue
		var num: int=c["number"]
		for receipt in c["contracts"]:_settle(c,receipt)
		if not c["contracts"].is_empty() and c["contracts"].all(func(r):return r["status"]!="paid"):
			var quality:=0.0
			for receipt in c["contracts"]:quality+=float(receipt["quality"])
			c["quality"]=quality/c["contracts"].size();GameState.set_flag("city%d_plan"%num)
		if Clock.now()>int(c["deadline"]) and c["decision"]=="":
			c["status"]="expired";c["result"]={"expired":true,"quality":c["quality"]}
			GameState.set_flag("city%d_unavailable"%num)
## Delayed ownership changes follow the issuing company, preserving the selected view.
static func _vest_option(option: Dictionary) -> void:
	var eligible_people: Array=Staff.people().filter(func(person):return person["id"] in option["people"])
	var shares: Dictionary=GameState.data.get("cap_table",{"founder":1.0})
	var founder_before: float=float(shares.get("founder",0))
	if eligible_people.is_empty() or founder_before<=0:option["status"]="forfeited";return
	var grant: float=minf(founder_before,float(option["share"])*eligible_people.size()/maxf(1,float(option["people"].size())))
	if grant<=0:option["status"]="forfeited";return
	shares["founder"]=founder_before-grant;shares["employees"]=float(shares.get("employees",0))+grant
	GameState.data["cap_table"]=shares
	var issuer: String=option["entity"]
	var carrying: float=snappedf(HoldingGroups.basis(issuer)*grant/founder_before,.01)
	if carrying>0:
		Ledger.post("player",I18n.t("Founder shares vested to the employee team"),[{"acct":"exp:other","dr":carrying},{"acct":"investments","cr":carrying}],{"type":"ownership","company":issuer})
		HoldingGroups.add_basis(issuer,-carrying)
	var book: float=snappedf(maxf(0,-Ledger.balance(issuer,"equity"))*grant,.01)
	if book>0:Ledger.post(issuer,I18n.t("Vested civic employee options"),[{"acct":"equity","dr":book},{"acct":"equity:employees","cr":book}],{"type":"ownership"})
	option["status"]="vested";option["vested_share"]=grant
static func _resolve_poaching(talent: Dictionary) -> void:
	var risks: Dictionary=cfg()["poaching_risks"]
	var departed: Array=[]
	for person in Staff.people().duplicate():
		if GameState.randf()<float(risks[talent["decision"]]):departed.append(person["id"]);Staff._quit(person)
	talent["result"]["departed"]=departed;talent["poaching_resolved"]=true
static func demand_factor(industry: String) -> float:
	if not GameState.data.has("city_future"):return 1.0
	var factor:=1.0;var peak: Dictionary=S()["peak"]
	if not peak.is_empty() and Clock.now()<int(peak["until"]):factor*=float(peak["mult"])
	var storm: Dictionary=S()["crises"].get("harbor_storm",{})
	if industry in ["logistics","manufacturing","energy"] and not storm.is_empty() and Clock.now()<int(storm["until"]):factor*=1+(float(storm["mult"])-1)*float(int(storm["until"])-Clock.now())/maxf(1,float(int(storm["until"])-int(storm["from"])))
	var crisis: Dictionary=S()["crises"].get(industry,{})
	if not crisis.is_empty() and Clock.now()<int(crisis["until"]):factor*=1+(float(crisis["mult"])-1)*float(int(crisis["until"])-Clock.now())/maxf(1,float(int(crisis["until"])-int(crisis["from"])))
	factor*=float(mods().get("transition",{}).get(S()["transition"],{}).get(industry,1.0))
	return factor
static func policy_factor(kind: String) -> float:
	if not GameState.data.has("city_future"):return 1.0
	if S()["elected"]=="":return 1.0
	return float(mods().get("mayors",{}).get(S()["elected"],{}).get(kind,1.0))
