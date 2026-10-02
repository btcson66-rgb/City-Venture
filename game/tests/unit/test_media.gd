extends RefCounted
var runner
func setup(extra := 0.0) -> String:
	Company.register("Agency Test","media","The Loft")
	Company.open_business_account(25000)
	if extra>0:Ledger.post(GameState.company_id(),"QA agency equity",[{"acct":"cash","dr":extra},{"acct":"equity","cr":extra}])
	runner.check(Living.lease("loft_office")["ok"],"actual studio lease")
	runner.check(Media.start()["ok"],"agency opens")
	return GameState.company_id()
func won() -> String:
	for attempt in 20:
		for brief in Media.S()["briefs"].values().duplicate():
			if brief["status"]!="open":continue
			Media.prepare(brief["id"],1)
			if Media.propose(brief["id"]).get("won",false):return brief["id"]
		Clock.advance(7*Clock.DAY)
	runner.check(false,"observed won campaign")
	return ""
func test_opening_gates_and_actual_university_world() -> void:
	runner.check(not Media.start()["ok"],"company gate")
	setup()
	runner.eq(DataDB.district_def_in_city("university")["status"],"active","metro district active")
	runner.eq(Media.stage(),1,"solo studio first")
	runner.eq(Media.capacity(),1,"solo concurrency limit")
	runner.check(Media.S()["briefs"].size()>0,"actual Jobs briefs")
	runner.check(Industries.tabs().any(func(t):return t["id"]=="media"),"OS registry tab")
func test_saturation_fit_creative_and_mix_bounds() -> void:
	setup()
	var channel: Dictionary=Media.cfg()["channels"]["radio"]
	var first := Media.impressions(channel,1000,0)
	var later := Media.impressions(channel,1000,10000)
	runner.check(first>later and later>0,"saturation decreases marginal reach")
	runner.check(Media.impressions(channel,1000,0,1.3)<first,"CPM shock lowers impressions")
	var brief: Dictionary=Media.S()["briefs"].values()[0]
	runner.eq(Media.creative_score(brief,brief["preferences"]),1.0,"three actual preference cards")
	var id := won()
	runner.check(not Media.adjust(id,{"radio":100})["ok"],"missing shares rejected")
	var mix: Dictionary=Media.cfg()["initial_mix"].duplicate()
	mix["radio"]=NAN
	runner.check(not Media.adjust(id,mix)["ok"],"finite allocation")
	runner.check(Media.adjust(id,Media.cfg()["initial_mix"])["ok"],"valid 100 percent mix")
func test_complete_campaign_kpi_invoice_daily_metrics_and_segments() -> void:
	var entity := setup()
	var id := won()
	runner.eq(-Ledger.balance(entity,"revenue"),0.0,"advance is not revenue")
	runner.check(float(Bank.lending_basis()["contracts"])>0,"Jobs receivable in bank basis")
	var campaign: Dictionary=Media.S()["campaigns"][id]
	campaign["kpi"]=1.0
	Clock.advance(int(Media.cfg()["campaign_days"])*Clock.DAY)
	runner.eq(campaign["status"],"completed","paid daily media finishes")
	runner.check(float(campaign["bonus"])>0,"actual KPI bonus")
	runner.eq(campaign["report"].size(),int(Media.cfg()["campaign_days"]),"daily measured reports")
	runner.eq(Jobs.get_job(id)["status"],"invoiced","Net 30 receivable")
	var invoice := Ledger.balance(entity,"accounts_receivable")
	runner.check(invoice>0,"real invoice AR")
	Clock.advance(30*Clock.DAY)
	runner.eq(Jobs.get_job(id)["status"],"paid","scheduled collection")
	var before := Ledger.cash(entity)
	Media.handle("media.day",{"id":id})
	runner.eq(Ledger.cash(entity),before,"no duplicate campaign money")
	runner.check(Ledger.check_balanced(),"campaign balanced")
	var company := MonthClose.compute(entity,0,Clock.now()+1)
	runner.check(absf(float(Segments.compute(entity,0,Clock.now()+1)["totals"]["operating_profit"])-float(company["business_profit"]))<.011,"segment total equals company")
func test_group_campaigns_change_actual_cafe_and_ecommerce_demand() -> void:
	var entity := setup(20000)
	Living.lease("corner_cafe")
	var before := Cafe.ads_factor()
	var result := Media.group_campaign("cafe",5000)
	runner.check(result["ok"],"internal cost-price campaign")
	Clock.advance(Clock.DAY)
	runner.check(Cafe.ads_factor()>before,"actual cafe ads demand responds")
	runner.check(Ledger.balance(entity,"ic_cost")>0 and Ledger.balance(entity,"cogs")>0,"internal media cost is a segment transfer backed by actual cash cost")
	runner.eq(-Ledger.balance(entity,"revenue"),0.0,"no invented internal agency revenue")
	runner.check(float(Segments.compute(entity,0,Clock.now()+1)["rows"]["cafe"]["internal_cost"])>0,"internal cost explicitly labeled in segment report")
	Clock.advance(int(Media.cfg()["campaign_days"])*Clock.DAY)
	var ecommerce := Media.group_campaign("ecommerce",5000)
	var baseline := Ecommerce.demand_mult("water_bottle")
	Clock.advance(Clock.DAY)
	runner.check(ecommerce["ok"] and Ecommerce.demand_mult("water_bottle")>baseline,"actual ecommerce demand responds")
	runner.check(Ledger.check_balanced(),"internal costs balanced")
func test_crisis_pause_cancel_save_old_save_and_closure() -> void:
	setup()
	var id := won()
	var event := EventEngine.trigger("media_price")
	runner.check(EventEngine.choose(event["iid"],"respond")["ok"],"registry crisis effect")
	runner.check(float(Media.S()["price_mult"])>1,"actual CPM shock")
	var campaign: Dictionary=Media.S()["campaigns"][id]
	var quality := float(campaign["quality"])
	Media.crisis("pr_ignore")
	runner.check(float(campaign["quality"])<quality,"poor PR response lowers quality")
	runner.check(SaveSystem.save(96),"campaign save")
	GameState.data.erase("media")
	runner.check(SaveSystem.load_data(96),"actual campaign load")
	Media.crisis("client")
	runner.eq(Media.S()["campaigns"][id]["status"],"cancelled","client departure stops spend")
	runner.check(Ledger.check_balanced(),"unused advance refund balanced")
	Insolvency.close_company()
	runner.check(not Media.is_running() and Sim.pending("media.day").is_empty(),"closed company cancels all media callbacks")
	runner.check(Ledger.check_balanced(),"agency closure balanced")
	GameState.data.erase("media")
	runner.check(SaveSystem.save(97),"legacy save without media state")
	runner.check(SaveSystem.load_data(97),"actual legacy save load")
	runner.eq(Media.S()["stage"],1,"old save lazy defaults")

func test_paused_campaign_capacity_and_funding_are_not_bypassable() -> void:
	var entity := setup()
	var id := won()
	Ledger.expense(entity,"other",Ledger.cash(entity),"QA drain working cash")
	Clock.advance(Clock.DAY)
	runner.eq(Media.S()["campaigns"][id]["status"],"paused","actual lack of funds pauses")
	runner.eq(Media.occupied().size(),1,"paused job still reserves capacity")
	runner.check(not Media.group_campaign("ecommerce",5000)["ok"],"pause cannot open extra slot")
	runner.check(not Media.resume(id)["ok"],"unfunded resume rejected")
	runner.eq(Media.impressions(Media.cfg()["channels"]["radio"],1000,0,NAN),0.0,"NaN CPM rejected")
	runner.check(Ledger.check_balanced(),"pause leaves balanced journals")
func test_bad_kpi_reputation_and_owned_inventory_asset_lifecycle() -> void:
	var entity := setup(100000)
	var id := won()
	var campaign: Dictionary=Media.S()["campaigns"][id]
	campaign["kpi"]=1e12
	var reputation := float(Media.S()["reputation"])
	Clock.advance(int(Media.cfg()["campaign_days"])*Clock.DAY)
	runner.check(not campaign["kpi_met"] and float(Media.S()["reputation"])<reputation,"missed target damages reputation")
	runner.eq(campaign["bonus"],0.0,"miss earns no KPI bonus")
	Staff.register_employer()
	for role in ["media_designer","media_buyer"]:
		runner.check(Staff.post_job(role)["ok"],"standard recruiting")
		Clock.advance(18*60)
		runner.check(Staff.hire(Staff.S()["applicants"][0]["id"])["ok"],"hire actual applicant")
	id=won()
	Clock.advance(int(Media.cfg()["campaign_days"])*Clock.DAY)
	runner.eq(Media.stage(),2,"two completed jobs plus actual staff")
	runner.eq(Media.capacity(),3,"agency concurrency")
	runner.check(Media.buy_radio()["ok"],"owned media actual asset")
	runner.eq(Media.stage(),3,"owned stage")
	runner.check(Ledger.balance(entity,"fixed_assets")>0 and float(Bank.lending_basis()["parts"][4][1])>0,"owned radio collateral")
	var radio: Dictionary=Media.S()["radio"]
	var offer: Dictionary=radio["offers"].values()[-1]
	var inventory := float(radio["inventory"])
	runner.check(Media.sell_slot(offer["id"])["ok"],"finite Jobs advertising sale")
	runner.eq(radio["inventory"],inventory-float(offer["impressions"]),"inventory consumed")
	runner.check(not Media.sell_slot(offer["id"])["ok"],"sold inventory cannot earn twice")
	Assets.S()["items"][radio["asset"]]["status"]="broken"
	runner.check(Assets.maintain(radio["asset"])["ok"],"actual maintenance repairs radio")
	Clock.advance(Clock.DAY)
	runner.check(float(Assets.S()["items"][radio["asset"]]["book"])<float(Media.cfg()["agency_asset_price"]),"asset depreciation")
	Insolvency.close_company()
	runner.eq(Assets.S()["items"][radio["asset"]]["status"],"sold","closure auctions radio")
	runner.check(Ledger.check_balanced(),"radio closure balanced")


func test_creative_cards_have_distinct_clickable_positions() -> void:
	setup()
	var brief: Dictionary=Media.S()["briefs"].values()[0]
	var game := CreativePitch.new(brief)
	UIRoot.open_modal(game)
	await UIRoot.get_tree().process_frame
	game.start()
	await UIRoot.get_tree().process_frame
	await UIRoot.get_tree().process_frame
	var cards: Array=[]
	for i in 4:cards.append(game.find_child("CreativeCard_slogan_"+str(i),true,false))
	var rects: Array=[]
	for i in 4:
		runner.check(cards[i]!=null,"actual named card")
		rects.append(cards[i].get_global_rect())
	rects.sort_custom(func(a,b):return a.position.y<b.position.y)
	for i in range(1,4):runner.check(rects[i].position.y>=rects[i-1].end.y,"cards do not overlap")
	for i in 3:game.choose(int(brief["preferences"][i]))
	runner.eq(game.score(),1.0,"three actual card rounds")
	game.close()
func test_preferences_are_random_per_brief_not_per_audience() -> void:
	setup()
	var seen := {}
	for week in 8:
		Clock.advance(7*Clock.DAY)
		for brief in Media.S()["briefs"].values():seen[str(brief["preferences"])]=true
	runner.check(seen.size()>4,"preference mixes vary between briefs (%d distinct)"%seen.size())
	runner.check(Media.S()["briefs"].values().all(func(b):return b["preferences"].size()==3),"three preferences each")
func test_price_shock_expires_and_rate_lock_halves_it() -> void:
	var entity := setup(20000)
	Media.crisis("price")
	runner.eq(Media.price_mult(),float(Media.cfg()["crisis_price_mult"]),"shock applies")
	Clock.advance((int(Media.cfg()["crisis_price_days"])+1)*Clock.DAY)
	runner.eq(Media.price_mult(),1.0,"CPMs return to normal after the shock window")
	var cash := Ledger.cash(entity)
	runner.check(Media.crisis("price_lock")["ok"],"rate lock accepted")
	runner.eq(Ledger.cash(entity),cash-float(Media.cfg()["crisis_price_lock_cost"]),"the lock costs its fee")
	var half := 1.0+(float(Media.cfg()["crisis_price_mult"])-1.0)*float(Media.cfg()["crisis_price_lock_share"])
	runner.eq(Media.price_mult(),half,"locked increase is smaller")
	Media.S()["price_mult"]=1.3
	Media.S().erase("price_until")
	runner.eq(Media.price_mult(),1.3,"an older save's shock starts its countdown on first read")
	Clock.advance((int(Media.cfg()["crisis_price_days"])+1)*Clock.DAY)
	runner.eq(Media.price_mult(),1.0,"and then expires too")
	runner.check(Ledger.check_balanced(),"balanced")
func test_media_events_offer_a_real_second_choice() -> void:
	for id in ["media_price","media_client"]:
		runner.check(DataDB.events[id]["choices"].size()>=2,id+" has two choices")
	var entity := setup(20000)
	won()
	var cash := Ledger.cash(entity)
	var event := EventEngine.trigger("media_client")
	runner.check(EventEngine.choose(event["iid"],"keep")["ok"],"retention discount")
	runner.eq(Ledger.cash(entity),cash-float(Media.cfg()["crisis_keep_cost"]),"discount paid")
	runner.eq(Media.running().size(),1,"the client campaign keeps running")
func test_client_crisis_picks_a_client_campaign_and_cancel_is_not_completed() -> void:
	setup(30000)
	var id := won()
	var group_id := "GROUP-X"
	var rebuilt := {group_id:Media._campaign(group_id,{"client":"Group business","budget":5000.0,"goal":"conversions","audience":1,"kpi":1.0,"quality":.8},"cafe")}
	rebuilt[id]=Media.S()["campaigns"][id]
	Media.S()["campaigns"]=rebuilt
	var before := GameState.stat("media_completed")
	runner.check(Media.crisis("client")["ok"],"client leaves")
	runner.eq(rebuilt[id]["status"],"cancelled","the paying client's campaign is the one cancelled")
	runner.eq(rebuilt[group_id]["status"],"running","the internal group campaign is untouched")
	runner.eq(GameState.stat("media_completed"),before,"a cancelled campaign is not counted as completed")
func test_paused_campaign_resumes_when_funded_or_times_out() -> void:
	var entity := setup()
	var id := won()
	var campaign: Dictionary=Media.S()["campaigns"][id]
	Ledger.expense(entity,"other",Ledger.cash(entity),"QA drain working cash")
	Clock.advance(Clock.DAY)
	runner.eq(campaign["status"],"paused","unfunded buying pauses the campaign")
	Ledger.post(entity,"QA funding",[{"acct":"cash","dr":20000.0},{"acct":"equity","cr":20000.0}])
	Clock.advance(Clock.DAY)
	runner.eq(campaign["status"],"running","a funded paused campaign restarts without a click")
	Ledger.expense(entity,"other",Ledger.cash(entity),"QA drain again")
	Clock.advance(Clock.DAY)
	runner.eq(campaign["status"],"paused","paused again")
	var reputation := float(Media.S()["reputation"])
	Clock.advance((int(Media.cfg()["paused_timeout_days"])+2)*Clock.DAY)
	runner.eq(campaign["status"],"cancelled","left unfunded too long it is closed")
	runner.check(float(Media.S()["reputation"])<reputation,"closing it costs reputation")
	runner.check(Ledger.check_balanced(),"timeout settlement balanced")
func test_creative_pitch_is_timed_shows_preferences_and_has_no_default_primary() -> void:
	setup()
	var brief: Dictionary=Media.S()["briefs"].values()[0]
	var game := CreativePitch.new(brief)
	runner.check(game.round_time>0.0,"each round has a timer")
	UIRoot.open_modal(game)
	await UIRoot.get_tree().process_frame
	game.start()
	await UIRoot.get_tree().process_frame
	await UIRoot.get_tree().process_frame
	var cards := game.find_children("CreativeCard_slogan_*","Button",true,false)
	runner.eq(cards.size(),4,"four cards")
	runner.check(cards.all(func(c):return not c.has_theme_stylebox_override("normal")),"no card is pre-highlighted")
	var shown := false
	for label in game.find_children("*","Label",true,false):
		if "Client preferences" in label.text or "客戶偏好" in label.text:shown=true
	runner.check(shown,"the client's preferences are visible inside the minigame")
	game.round_timeout()
	runner.eq(game.points,0.0,"running out the clock scores nothing")
	game.close()
