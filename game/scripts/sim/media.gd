class_name Media
extends RefCounted
## Client-funded, measured campaigns settle through Jobs; intra-group media has no service markup.
static func cfg() -> Dictionary:return DataDB.economy.get("media",{})
static func S() -> Dictionary:
	if not GameState.data.has("media"):
		GameState.data["media"]={"active":false,"entity":"","stage":1,"reputation":float(cfg()["reputation_start"]),"briefs":{},"campaigns":{},"week":-1,"completed":0,"price_mult":1.0,"radio":{},"boosts":{}}
	return GameState.data["media"]
static func entity() -> String:return str(S()["entity"])
static func segment_tag() -> String:return "media"
static func source(id := "",internal := false) -> Dictionary:return {"type":"campaign","id":id,"segment":"media","internal":internal}
static func error(text: String) -> Dictionary:return {"ok":false,"error":I18n.t(text)}
static func is_running() -> bool:return GameState.has_game() and bool(S()["active"])
static func valid() -> bool:return is_running() and Assets._valid_entity(entity()) and Living.has_lease("loft_office")
static func start() -> Dictionary:
	if GameState.company_id()=="" or not GameState.flag("business_account_opened") or Acquisition.sold():return error("Register a company and open its bank account first.")
	if not Living.has_lease("loft_office"):return error("Lease The Loft in University before opening the agency.")
	if is_running():return error("The agency is already open.")
	if entity()!="" and entity()!=GameState.company_id():GameState.data.erase("media")
	S()["active"]=true
	S()["entity"]=GameState.company_id()
	GameState.set_flag("media_active")
	refresh()
	GameState.timeline(I18n.t("Opened a campaign studio at The Loft."),"milestone")
	return {"ok":true}
static func stage() -> int:
	if not S()["radio"].is_empty():return 3
	if int(S()["completed"])>=int(cfg()["agency_completed"]) and Staff.count("media_designer")>0 and Staff.count("media_buyer")>0:return 2
	return 1
static func capacity() -> int:return int(cfg()["capacity_agency"] if stage()>=2 else cfg()["capacity_solo"])
static func running() -> Array:return S()["campaigns"].values().filter(func(c):return c["status"]=="running")
## A channel price shock fades: it lasts `crisis_price_days`, then CPMs return to normal. A save from before the
## expiry existed starts the countdown the first time it is read.
static func price_mult() -> float:
	var m := float(S()["price_mult"])
	if m==1.0:return 1.0
	if not S().has("price_until"):S()["price_until"]=Clock.now()+int(cfg()["crisis_price_days"])*Clock.DAY
	if Clock.now()>=int(S()["price_until"]):
		S()["price_mult"]=1.0
		S().erase("price_until")
		return 1.0
	return m
static func _set_price_shock(mult: float) -> void:
	S()["price_mult"]=mult
	S()["price_until"]=Clock.now()+int(cfg()["crisis_price_days"])*Clock.DAY
static func occupied() -> Array:return S()["campaigns"].values().filter(func(c):return c["status"] in ["running","paused"])
static func refresh() -> void:
	if not valid():return
	var week := Clock.day_index()/7
	if int(S()["week"])==week:return
	S()["week"]=week
	for brief in S()["briefs"].values():
		if brief["status"]=="open":brief["status"]="expired"
	var count := maxi(int(cfg()["brief_min"]),ceili(float(cfg()["weekly_briefs"])*float(S()["reputation"])))
	for n in count:
		var audience := GameState.rng.randi_range(0,3)
		var goal := "awareness" if GameState.rng.randf()<.5 else "conversions"
		var budget := snappedf(GameState.rng.randf_range(float(cfg()["budget_min"]),lerpf(float(cfg()["budget_min"]),float(cfg()["budget_max"]),float(S()["reputation"]))),.01)
		var client: String=cfg()["client_names"][GameState.rng.randi_range(0,cfg()["client_names"].size()-1)]
		var price := budget+float(cfg()["service_fee"])
		var id := Jobs.offer({"entity":entity(),"client":client,"scope":"Measured media campaign","price":price,"work":cfg()["campaign_days"],"due":Clock.now()+int(cfg()["brief_deadline_days"])*Clock.DAY,"terms":30,"deposit":budget*float(cfg()["client_deposit"])/price,"segment":"media"})
		S()["briefs"][id]={"id":id,"client":client,"budget":budget,"goal":goal,"audience":audience,"deadline":Jobs.get_job(id)["due"],"kpi":budget*float(cfg()["kpi_reach_per_budget"] if goal=="awareness" else cfg()["kpi_conversion_per_budget"]),"status":"open","quality":0.0,"preferences":_roll_preferences()}
	if not S()["radio"].is_empty():_radio_offer()
## Every brief wants its own slogan / visual / tone mix; it is not fixed by the audience.
static func _roll_preferences() -> Array:
	return [GameState.rng.randi_range(0,3),GameState.rng.randi_range(0,3),GameState.rng.randi_range(0,3)]
static func creative_score(brief: Dictionary,cards: Array) -> float:
	if cards.size()!=3:return 0
	var score := 0.0
	for i in 3:
		if int(cards[i])==int(brief["preferences"][i]):score+=1.0/3
	return score
static func prepare(id: String,score: float) -> Dictionary:
	var brief: Dictionary=S()["briefs"].get(id,{})
	if not valid() or brief.get("status","")!="open" or not is_finite(score):return error("Choose an open client brief.")
	if Ledger.cash(entity())<float(cfg()["creative_cost"]):return error("Save the creative production cost first.")
	Ledger.expense(entity(),"other",float(cfg()["creative_cost"]),I18n.t("Creative pitch production"),source(id))
	Clock.advance(maxi(int(cfg()["creative_minutes_min"]),int(cfg()["creative_minutes"])-Staff.count("media_designer")*int(cfg()["designer_minutes_saved"])-Staff.count("media_intern")*int(cfg()["intern_minutes_saved"])))
	if not valid() or Clock.now()>int(brief["deadline"]):return error("This client brief expired during production.")
	var bonus := 0.0
	for person in Staff.people():
		if person["role"] in ["media_designer","media_intern"]:bonus+=float(person["skill"])*float(cfg()["designer_quality_per_skill"] if person["role"]=="media_designer" else cfg()["intern_quality_per_skill"])
	brief["quality"]=clampf(score+bonus,0,1)
	return {"ok":true}
static func propose(id: String) -> Dictionary:
	var brief: Dictionary=S()["briefs"].get(id,{})
	if not valid() or brief.get("status","")!="open" or occupied().size()>=capacity():return error("Choose an open brief with a free campaign slot.")
	if Ledger.cash(entity())<float(cfg()["pitch_cost"]):return error("Save the proposal cost first.")
	Ledger.expense(entity(),"other",float(cfg()["pitch_cost"]),I18n.t("Agency proposal"),source(id))
	Clock.advance(int(cfg()["pitch_minutes"]))
	if not valid() or Clock.now()>int(brief["deadline"]):brief["status"]="expired";return error("This client brief expired during production.")
	var chance := float(cfg()["proposal_base"])*float(brief["quality"])+float(cfg()["proposal_quality"])+float(cfg()["proposal_rep"])*float(S()["reputation"])
	if GameState.rng.randf()>clampf(chance,float(cfg()["proposal_min"]),float(cfg()["proposal_max"])):brief["status"]="lost";return {"ok":true,"won":false}
	if not Jobs.accept(id)["ok"]:return error("This job is no longer available.")
	brief["status"]="won"
	S()["campaigns"][id]=_campaign(id,brief,"")
	Sim.schedule(Clock.now()+Clock.DAY,"media.day",{"id":id})
	GameState.timeline(I18n.t("Campaign proposal won: %s.")%brief["client"],"business")
	return {"ok":true,"won":true}
static func _campaign(id: String,brief: Dictionary,target: String) -> Dictionary:
	return {"id":id,"client":brief["client"],"budget":brief["budget"],"goal":brief["goal"],"audience":brief["audience"],"kpi":brief["kpi"],"quality":brief["quality"],"mix":cfg()["initial_mix"].duplicate(),"channel_spend":{},"spent":0.0,"cost":0.0,"impressions":0.0,"reach":0.0,"clicks":0.0,"conversions":0.0,"days":0,"status":"running","target":target,"report":[],"bonus":0.0}
## Marginal impressions integrate an exponential audience saturation curve.
static func impressions(channel: Dictionary,spend: float,prior: float,price_mult := 1.0) -> float:
	if spend<=0 or not is_finite(spend) or prior<0 or not is_finite(prior) or price_mult<=0 or not is_finite(price_mult):return 0
	var half := float(channel["saturation"])
	return half/(float(channel["cpm"])*price_mult)*1000*(exp(-prior/half)-exp(-(prior+spend)/half))
static func adjust(id: String,mix: Dictionary) -> Dictionary:
	var campaign: Dictionary=S()["campaigns"].get(id,{})
	if not valid() or campaign.get("status","")!="running":return error("Choose a running campaign.")
	var sum := 0.0
	for channel in cfg()["channels"]:
		var amount := float(mix.get(channel,-1))
		if not is_finite(amount) or amount<0 or amount>100:return error("Channel shares must total 100 percent.")
		sum+=amount
	if absf(sum-100)>.001:return error("Channel shares must total 100 percent.")
	campaign["mix"]=mix.duplicate(true)
	return {"ok":true}
static func _day(campaign: Dictionary) -> void:
	if campaign["status"]!="running":return
	var gross := snappedf(minf(float(campaign["budget"])-float(campaign["spent"]),float(campaign["budget"])/int(cfg()["campaign_days"])),.01)
	if int(campaign["days"])==int(cfg()["campaign_days"])-1:gross=snappedf(float(campaign["budget"])-float(campaign["spent"]),.01)
	var internal: bool=campaign["target"]!=""
	var rebate := 0.0 if internal else float(cfg()["buyer_rebate"] if Staff.count("media_buyer")>0 else cfg()["media_rebate"])
	var cost := snappedf(gross*(1-rebate),.01)
	if Ledger.cash(entity())<cost:
		campaign["status"]="paused"
		campaign["paused_at"]=Clock.now()
		return
	if internal:
		InternalSupply.trade(InternalSupply.key("media_ads",campaign["target"]),cost,{"entity":entity()})
	else:Ledger.post(entity(),I18n.t("Campaign media purchase after rebate"),[{"acct":"cogs","dr":cost},{"acct":"cash","cr":cost}],source(campaign["id"]))
	var raw := 0.0
	var reach := 0.0
	for cid in cfg()["channels"]:
		var channel: Dictionary=cfg()["channels"][cid]
		var share := gross*float(campaign["mix"][cid])/100
		var prior := float(campaign["channel_spend"].get(cid,0))
		var views := impressions(channel,share,prior,price_mult())
		campaign["channel_spend"][cid]=prior+share
		raw+=views
		reach+=views*float(channel["audience"][int(campaign["audience"])])
	var clicks := reach*(float(cfg()["ctr_base"])+float(cfg()["ctr_quality"])*float(campaign["quality"]))
	var conversions := clicks*float(cfg()["conversion_rate"])*GameState.rng.randf_range(float(cfg()["performance_noise"][0]),float(cfg()["performance_noise"][1]))
	campaign["spent"]=snappedf(float(campaign["spent"])+gross,.01)
	campaign["cost"]=snappedf(float(campaign["cost"])+cost,.01)
	for pair in [["impressions",raw],["reach",reach],["clicks",clicks],["conversions",conversions]]:campaign[pair[0]]=float(campaign[pair[0]])+float(pair[1])
	campaign["days"]=int(campaign["days"])+1
	campaign["report"].append({"day":Clock.day_index(),"impressions":raw,"reach":reach,"clicks":clicks,"conversions":conversions,"media_cost":cost})
	if internal:S()["boosts"][campaign["target"]]={"until":Clock.now()+int(cfg()["group_boost_days"])*Clock.DAY,"value":minf(float(cfg()["group_boost_max"]),conversions/float(cfg()["group_conversion_scale"])),"id":campaign["id"]}
	else:Jobs.progress(campaign["id"],1)
	if int(campaign["days"])>=int(cfg()["campaign_days"]):_settle(campaign)
	else:Sim.schedule(Clock.now()+Clock.DAY,"media.day",{"id":campaign["id"]})
static func _settle(campaign: Dictionary,cancelled := false) -> void:
	if campaign["status"] in ["completed","cancelled"]:return
	var met: bool=not cancelled and float(campaign["reach"] if campaign["goal"]=="awareness" else campaign["conversions"])>=float(campaign["kpi"])
	if campaign["target"]=="":
		var job := Jobs.get_job(campaign["id"])
		var fee := float(cfg()["service_fee"])*minf(1,float(campaign["days"])/int(cfg()["campaign_days"]))
		campaign["bonus"]=snappedf(float(campaign["budget"])*float(cfg()["bonus_fraction"]),.01) if met else 0.0
		job["price"]=snappedf(float(campaign["spent"])+fee+float(campaign["bonus"]),.01)
		var refund := maxf(0,float(job["deposit_paid"])-float(job["price"]))
		if refund>0:
			Ledger.post(entity(),I18n.t("Unused campaign advance refunded"),[{"acct":"deferred_revenue","dr":refund},{"acct":"cash" if Ledger.cash(entity())>=refund else "accounts_payable","cr":refund}],source(campaign["id"]))
			job["deposit_paid"]=snappedf(float(job["deposit_paid"])-refund,.01)
		job["progress"]=job["work"]
		if job["price"]>0:Jobs.deliver(job["id"]);Jobs.invoice(job["id"])
		else:job["status"]="closed"
		S()["reputation"]=clampf(float(S()["reputation"])+(float(cfg()["reputation_win"]) if met else -float(cfg()["reputation_loss"])),float(cfg()["reputation_min"]),1)
		if not cancelled:
			S()["completed"]=int(S()["completed"])+1
			GameState.inc_stat("media_completed")
		if not S()["radio"].is_empty():S()["radio"]["audience"]=float(S()["radio"]["audience"])+float(campaign["reach"])*float(cfg()["radio_growth_per_reach"])
	campaign["kpi_met"]=met
	campaign["status"]="cancelled" if cancelled else "completed"
	Sim.cancel("media.day","id",campaign["id"])
	GameState.timeline(I18n.t("Campaign report completed: %s.")%campaign["client"],"business")
static func resume(id: String) -> Dictionary:
	var campaign: Dictionary=S()["campaigns"].get(id,{})
	if not valid() or campaign.get("status","")!="paused":return error("Choose a paused campaign and fund its next media purchase.")
	var gross := minf(float(campaign["budget"])-float(campaign["spent"]),float(campaign["budget"])/int(cfg()["campaign_days"]))
	var rebate := 0.0 if campaign["target"]!="" else float(cfg()["buyer_rebate"] if Staff.count("media_buyer")>0 else cfg()["media_rebate"])
	if Ledger.cash(entity())<snappedf(gross*(1-rebate),.01):return error("Choose a paused campaign and fund its next media purchase.")
	campaign["status"]="running"
	campaign.erase("paused_at")
	Sim.schedule(Clock.now()+Clock.DAY,"media.day",{"id":id})
	return {"ok":true}
static func demand_boost(target: String) -> float:
	if not valid():return 1.0
	var boost: Dictionary=S()["boosts"].get(target,{})
	return 1+float(boost.get("value",0)) if Clock.now()<int(boost.get("until",0)) else 1.0
static func group_campaign(target: String,budget: float) -> Dictionary:
	if not valid() or target not in ["ecommerce","cafe","hotel"] or not is_finite(budget) or budget<float(cfg()["budget_min"]) or budget>float(cfg()["budget_max"]) or occupied().size()>=capacity():return error("Choose a running group business and a valid media budget.")
	if target=="cafe" and not Cafe.leased():return error("Open the group business before buying internal media.")
	if target=="hotel" and not GameState.flag("hotel_active"):return error("Open the group business before buying internal media.")
	var id := "GROUP-"+str(S()["campaigns"].size()+1)
	S()["campaigns"][id]=_campaign(id,{"client":"Group business","budget":budget,"goal":"conversions","audience":1,"kpi":budget*float(cfg()["kpi_conversion_per_budget"]),"quality":.8},target)
	Sim.schedule(Clock.now()+Clock.DAY,"media.day",{"id":id})
	return {"ok":true,"id":id}
static func buy_radio() -> Dictionary:
	if not valid() or stage()<2 or not S()["radio"].is_empty():return error("Complete two campaigns and hire a designer and media buyer before buying Campus Radio.")
	var asset := Assets.buy({"entity":entity(),"name":"Campus Radio","price":cfg()["agency_asset_price"],"life_days":cfg()["asset_life_days"],"maintenance_cost":cfg()["asset_maintenance_cost"],"maintenance_days":cfg()["asset_maintenance_days"],"failure_chance":cfg()["asset_failure_chance"],"segment":"media"})
	if not asset["ok"]:return asset
	S()["radio"]={"asset":asset["id"],"audience":cfg()["radio_audience_start"],"inventory":0,"day":-1,"offers":{}}
	_inventory()
	_radio_offer()
	GameState.timeline(I18n.t("Acquired Campus Radio and its finite advertising inventory."),"milestone")
	return {"ok":true}
static func _inventory() -> void:
	var radio: Dictionary=S()["radio"]
	if radio.is_empty() or int(radio["day"])==Clock.day_index():return
	radio["day"]=Clock.day_index()
	radio["inventory"]=floorf(float(radio["audience"])*float(cfg()["radio_inventory_per_listener"]))
static func _radio_offer() -> void:
	var impressions_value := float(cfg()["radio_ad_impressions"])
	var id := Jobs.offer({"entity":entity(),"client":"Campus advertiser","scope":"Campus Radio measured advertising slot","price":impressions_value/1000*float(cfg()["radio_cpm"]),"work":impressions_value,"terms":0,"segment":"media","due":Clock.now()+7*Clock.DAY})
	S()["radio"]["offers"][id]={"id":id,"impressions":impressions_value}
static func sell_slot(id: String) -> Dictionary:
	if not valid() or S()["radio"].is_empty():return error("Acquire Campus Radio before selling advertising inventory.")
	_inventory()
	var offer: Dictionary=S()["radio"]["offers"].get(id,{})
	var asset: Dictionary=Assets.S()["items"].get(S()["radio"]["asset"],{})
	if offer.is_empty() or asset.get("status","")!="working" or float(S()["radio"]["inventory"])<float(offer["impressions"]) or Jobs.get_job(id)["status"]!="offered":return error("This advertising slot is unavailable or inventory is exhausted.")
	if not Jobs.accept(id)["ok"]:return error("This job is no longer available.")
	S()["radio"]["inventory"]=float(S()["radio"]["inventory"])-float(offer["impressions"])
	Jobs.progress(id,float(offer["impressions"]))
	Jobs.deliver(id)
	Jobs.invoice(id)
	return {"ok":true}
static func crisis(kind: String,_retain := true) -> Dictionary:
	if not valid():return error("Open the agency first.")
	match kind:
		"price":_set_price_shock(float(cfg()["crisis_price_mult"]))
		"price_lock":
			if Ledger.cash(entity())<float(cfg()["crisis_price_lock_cost"]):return error("Save the rate-lock fee first.")
			Ledger.expense(entity(),"other",float(cfg()["crisis_price_lock_cost"]),I18n.t("Channel rate lock"),source())
			_set_price_shock(1.0+(float(cfg()["crisis_price_mult"])-1.0)*float(cfg()["crisis_price_lock_share"]))
		"pr","pr_ignore":
			if kind=="pr":
				if Ledger.cash(entity())<float(cfg()["crisis_pr_cost"]):return error("Save the public-relations repair cost first.")
				Ledger.expense(entity(),"other",float(cfg()["crisis_pr_cost"]),I18n.t("Campaign public-relations repair"),source())
			else:
				for campaign in running():campaign["quality"]=maxf(0,float(campaign["quality"])-float(cfg()["crisis_pr_quality_loss"]))
		"client","client_keep":
			# Only a paying client can walk away; internal group campaigns are never the one that leaves.
			var clients := running().filter(func(c):return c["target"]=="")
			if not clients.is_empty():
				if kind=="client":_settle(clients[0],true)
				else:
					if Ledger.cash(entity())<float(cfg()["crisis_keep_cost"]):return error("Save the client retention discount first.")
					Ledger.expense(entity(),"other",float(cfg()["crisis_keep_cost"]),I18n.t("Client retention discount"),source(clients[0]["id"]))
		_:return error("Unknown agency crisis.")
	return {"ok":true}
static func on_hour(_t: int,h: int) -> void:
	if not valid() or h!=9:return
	refresh()
	_service_paused()
	if not S()["radio"].is_empty():
		_inventory()
		Ledger.expense(entity(),"maintenance",float(cfg()["owned_media_upkeep_day"]),I18n.t("Campus Radio upkeep"),source(),"cash" if Ledger.cash(entity())>=float(cfg()["owned_media_upkeep_day"]) else "accounts_payable")
## A paused campaign restarts by itself once the next media purchase is funded; one left unfunded for
## `paused_timeout_days` is closed like a cancelled brief (unused advance refunded, reputation penalty).
static func _service_paused() -> void:
	for campaign in S()["campaigns"].values():
		if campaign["status"]!="paused":continue
		if resume(campaign["id"]).get("ok",false):continue
		if Clock.now()-int(campaign.get("paused_at",Clock.now()))>=int(cfg()["paused_timeout_days"])*Clock.DAY:
			_settle(campaign,true)
			GameState.add_message("imani_cole",I18n.t("We closed the %s campaign: the media purchase went unfunded for too long. The unused advance was refunded.")%campaign["client"])
static func handle(kind: String,payload: Dictionary) -> void:
	if not valid():return
	if kind=="media.day":
		var campaign: Dictionary=S()["campaigns"].get(str(payload.get("id","")),{})
		if not campaign.is_empty():_day(campaign)
static func on_company_closed(closed: String) -> void:
	if not is_running() or entity()!=closed:return
	for campaign in S()["campaigns"].values():
		if campaign["status"] in ["running","paused"]:_settle(campaign,true)
	S()["active"]=false
	S()["boosts"]={}
	GameState.set_flag("media_active",false)
	Sim.cancel("media.day","",null)
static func os_tab() -> Dictionary:return {"id":"media","label":"Media / Advertising","icon":"star","order":7,"start_label":"Open Campaign Mixer","render":MediaUI.render}
static func board_detail() -> Callable:return MediaUI.board
static func open_action(_params: Dictionary,_source: Node) -> void:MediaUI.open()
