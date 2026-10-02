extends RefCounted
## Industry synergies and group goals (#71): internal supply with transfer pricing and consolidation, multi-industry
## group jobs (full, partial, subcontracted), industry milestones, Business Board gates, saves.
var runner


func _company(extra := 600000.0) -> String:
	Company.register("Group Test", "ecommerce", "22 Founders Lane")
	Company.open_business_account(25000)
	var cid := GameState.company_id()
	if extra > 0:
		Ledger.post(cid, "QA group equity", [{"acct": "cash", "dr": extra}, {"acct": "equity", "cr": extra}])
	return cid


func _open_media() -> void:
	runner.check(Living.lease("loft_office")["ok"], "studio lease")
	runner.check(Media.start()["ok"], "agency opens")


func _open_cafe() -> void:
	runner.check(Living.lease("corner_cafe")["ok"], "cafe lease")


func _open_hotel() -> void:
	GameState.mark_visited("the_aster")
	runner.check(Hotel.start("own")["ok"], "hotel opens")


func _open_factory() -> void:
	runner.check(Living.lease("unit12_factory")["ok"], "factory leased")
	runner.check(Manufacturing.start()["ok"], "factory opened")


func _profit(entity: String) -> float:
	return float(Segments.compute(entity, 0, Clock.now() + 1)["totals"]["operating_profit"])


func _keys() -> Array:
	return InternalSupply.pairs().map(func(p): return p["key"])


# ------------------------------------------------------------------ data
func test_data_is_complete_and_wellformed() -> void:
	runner.eq(DataDB.milestones.size(), 55, "five milestones for each of eleven industries")
	for entry in Industries.all():
		runner.eq(Milestones.list(entry["id"]).size(), 5, "five milestones: " + str(entry["id"]))
	for m in DataDB.milestones.values():
		runner.check(str(m["metric"]).get_slice(":", 0) in ["stat", "data", "count", "fn"] and str(m["name"]) != "" and str(m["desc"]) != "", "milestone shape " + str(m["id"]))
	runner.check(DataDB.quests.size() >= 4, "at least four multi-industry jobs")
	for def in DataDB.quests.values():
		var industries := {}
		var shares := 0.0
		for part in def["parts"]:
			industries[part["industry"]] = true
			shares += float(part["share"])
			runner.check(DataDB.businesses.has(part["industry"]) and float(part["subcontract"]) > 0 and float(part["target"]) > 0, "part valid " + str(part["id"]))
		runner.check(industries.size() >= 2, "needs two or more industries: " + str(def["id"]))
		runner.check(absf(shares - 1.0) < 0.0001, "shares total one: " + str(def["id"]))
		runner.check(float(def["reward"]) > 0 and int(def["deadline_days"]) > 0, "reward and deadline: " + str(def["id"]))
	for l in InternalSupply.links():
		runner.check(Industries.find(str(l["seller"])).size() > 0 and l["buyers"].size() > 0, "link industries exist " + str(l["id"]))
		runner.check(InternalSupply.market_price(l) >= InternalSupply.unit_cost(l), "market covers cost " + str(l["id"]))
	for id in DataDB.businesses:
		if DataDB.businesses[id].get("status", "") == "active":
			runner.check(DataDB.synergies["gates"].has(id), "gate text for " + str(id))


# ------------------------------------------------------------------ pricing and feasibility
func test_transfer_price_policies() -> void:
	_company()
	_open_media()
	_open_cafe()
	var k := InternalSupply.key("media_ads", "cafe")
	runner.eq(InternalSupply.price(k), 1.0, "default transfer price is cost")
	runner.check(InternalSupply.set_policy(k, "plus", 0.2)["ok"], "cost plus set")
	runner.eq(InternalSupply.price(k), 1.2, "cost plus 20 percent")
	runner.check(InternalSupply.set_policy(k, "market")["ok"], "market set")
	runner.eq(InternalSupply.price(k), 1.18, "market price")
	runner.check(not InternalSupply.set_policy(k, "free")["ok"], "unknown mode rejected")
	runner.check(not InternalSupply.set_policy(k, "plus", NAN)["ok"], "non-finite markup rejected")
	runner.check(not InternalSupply.set_policy(k, "plus", 5.0)["ok"], "absurd markup rejected")
	runner.check(not InternalSupply.set_policy("media_ads:hotel_x", "cost")["ok"], "unlisted pair rejected")
	runner.check(not InternalSupply.set_paused(k, true)["ok"], "native supply cannot be paused")


func test_only_feasible_pairs_are_listed() -> void:
	runner.check(InternalSupply.pairs().is_empty(), "no company, no pairs")
	_company()
	runner.check(InternalSupply.pairs().is_empty(), "a lone starting business has no partner")
	runner.check(InternalSupply.next_step() != "", "empty list names a next step")
	_open_media()
	var keys := _keys()
	runner.check("media_ads:ecommerce" in keys, "media supplies ecommerce")
	runner.check("media_ads:cafe" not in keys, "cafe is not running yet")
	runner.check("cafe_breakfast:hotel" not in keys and "energy_power_hotel:hotel" not in keys, "unopened sellers absent")
	_open_cafe()
	runner.check("media_ads:cafe" in _keys(), "cafe pair appears once both run")
	_open_hotel()
	keys = _keys()
	runner.check("media_ads:hotel" in keys and "cafe_breakfast:hotel" in keys, "hotel pairs appear")
	runner.check("energy_power_hotel:hotel" not in keys, "energy still closed")
	runner.check("factory_goods:ecommerce" not in keys, "factory still closed")
	for p in InternalSupply.pairs():
		runner.eq(InternalSupply.why_not(p["link"], p["buyer"]), "", "listed pairs are feasible")


func test_pairs_need_the_same_books() -> void:
	_company()
	_open_media()
	var k := InternalSupply.key("media_ads", "ecommerce")
	runner.check(InternalSupply.feasible(k), "same company books")
	Media.S()["entity"] = "player"
	runner.check(not InternalSupply.feasible(k), "different books are not a group pair")


# ------------------------------------------------------------------ consolidation
func test_internal_trade_is_eliminated_in_the_group_total() -> void:
	var cid := _company()
	_open_media()
	_open_cafe()
	var k := InternalSupply.key("media_ads", "cafe")
	var base := _profit(cid)
	var revenue_before := -Ledger.balance(cid, "revenue")
	var deltas: Array = []
	for mode in ["cost", "plus", "market"]:
		InternalSupply.set_policy(k, mode, 0.35)
		var before := _profit(cid)
		var trade := InternalSupply.trade(k, 1000.0)
		runner.check(trade["ok"], "trade at " + mode)
		deltas.append(snappedf(_profit(cid) - before, 0.01))
	runner.eq(deltas[0], deltas[1], "group profit does not depend on cost-plus")
	runner.eq(deltas[0], deltas[2], "group profit does not depend on market price")
	runner.eq(deltas[0], -1000.0, "group only bears the real cost of the supply")
	var report := Segments.compute(cid, 0, Clock.now() + 1)
	var media_row: Dictionary = report["rows"]["media"]
	var cafe_row: Dictionary = report["rows"]["cafe"]
	runner.check(float(media_row["internal_revenue"]) > 3000.0, "seller books the internal sale")
	runner.check(float(cafe_row["internal_charge"]) > 3000.0, "buyer books the internal purchase")
	runner.eq(report["totals"]["internal_revenue"], report["totals"]["internal_charge"], "internal sales equal purchases")
	runner.eq(-Ledger.balance(cid, "revenue"), revenue_before, "no invented revenue")
	runner.eq(Ledger.balance(cid, "ic_clearing"), 0.0, "clearing nets to zero")
	runner.eq(snappedf(Ledger.balance(cid, "ic_revenue") + Ledger.balance(cid, "ic_cost"), 0.01), 0.0, "ledger: internal revenue and cost cancel")
	var group := InternalSupply.group_report(cid, 0, Clock.now() + 1)
	runner.check(group["balanced"] and float(group["eliminated"]) > 3000.0, "group report eliminates it")
	runner.eq(snappedf(float(group["segments_sum_revenue"]) - float(group["eliminated"]), 0.01), snappedf(float(group["net_revenue"]), 0.01), "segment sales minus eliminations equals group revenue")
	var company := MonthClose.compute(cid, 0, Clock.now() + 1)
	runner.check(absf(float(group["operating_profit"]) - float(company["business_profit"])) < 0.011, "group profit equals the company report")
	runner.check(absf(_profit(cid) - base + 3000.0) < 0.011, "three trades cost the group only their real cost")
	runner.check(Ledger.check_balanced(), "books balance")


func test_saving_versus_outside_is_independent_of_the_price() -> void:
	var cid := _company()
	_open_factory()
	var k := InternalSupply.key("factory_goods", "ecommerce")
	runner.check(InternalSupply.feasible(k), "factory supplies ecommerce")
	var gains: Array = []
	for mode in ["cost", "market"]:
		InternalSupply.set_policy(k, mode)
		var before := _profit(cid)
		var result := InternalSupply.trade(k, 100.0)
		gains.append(snappedf(_profit(cid) - before, 0.01))
		runner.eq(result["saving"], 500.0, "100 units save market minus cost")
	runner.eq(gains[0], gains[1], "same group gain whatever the transfer price")
	runner.eq(gains[0], 500.0, "group gains market minus real cost per unit")
	runner.check(Ledger.check_balanced(), "books balance")


func test_segments_report_both_sides() -> void:
	var cid := _company()
	_open_media()
	_open_cafe()
	var k := InternalSupply.key("media_ads", "cafe")
	InternalSupply.set_policy(k, "plus", 0.2)
	var before: Dictionary = Segments.compute(cid, 0, Clock.now() + 1)["rows"]
	InternalSupply.trade(k, 500.0)
	var rows: Dictionary = Segments.compute(cid, 0, Clock.now() + 1)["rows"]
	runner.eq(rows["media"]["internal_revenue"], 600.0, "media sells 500 media dollars at cost plus 20 percent")
	runner.eq(rows["cafe"]["internal_charge"], 600.0, "cafe pays the transfer price")
	runner.eq(snappedf(float(rows["media"]["operating_profit"]) - float(before["media"]["operating_profit"]), 0.01), 100.0, "seller margin is the markup")
	runner.eq(snappedf(float(rows["cafe"]["operating_profit"]) - float(before["cafe"]["operating_profit"]), 0.01), -600.0, "buyer carries the transfer price")


# ------------------------------------------------------------------ settlement and native hooks
func test_factory_goods_settle_by_orders_delivered() -> void:
	_company()
	_open_factory()
	var k := InternalSupply.key("factory_goods", "ecommerce")
	runner.eq(InternalSupply.settle_all(), 0, "first pass only sets the baseline")
	GameState.inc_stat("orders_delivered", 12)
	runner.eq(InternalSupply.settle_all(), 1, "a day with deliveries trades")
	runner.eq(InternalSupply.state(k)["qty"], 12.0, "one unit per delivered order")
	runner.eq(InternalSupply.settle_all(), 0, "once a day")
	InternalSupply.set_paused(k, true)
	Clock.advance(Clock.DAY)
	GameState.inc_stat("orders_delivered", 5)
	Clock.advance(Clock.DAY)
	runner.eq(InternalSupply.state(k)["qty"], 12.0, "paused pair does not trade")
	InternalSupply.set_paused(k, false)
	GameState.inc_stat("orders_delivered", 4)
	Clock.advance(Clock.DAY)
	runner.check(float(InternalSupply.state(k)["qty"]) > 12.0, "resumed pair trades again")


func test_monthly_van_service_and_hotel_referrals() -> void:
	var cid := _company()
	runner.check(Automotive.start()["ok"], "auto desk opens")
	runner.check(Logistics.buy_van()["ok"], "van bought")
	var van := InternalSupply.key("auto_van_service", "logistics")
	runner.check(InternalSupply.feasible(van), "automotive services the logistics van")
	Clock.advance(31 * Clock.DAY)
	runner.check(int(InternalSupply.state(van)["trades"]) >= 1, "monthly service trade settled")
	runner.check(float(InternalSupply.state(van)["saving"]) > 0, "service saves versus outside")
	_open_hotel()
	var ref := InternalSupply.key("hotel_referrals", "automotive")
	runner.check(InternalSupply.feasible(ref), "hotel refers guests to rental")
	Hotel.S()["history"].append({"day": Clock.day_index(), "occupied": 50, "rooms": 60, "room_revenue": 5000.0, "walks": 0, "dirty": 0})
	InternalSupply.settle_all()
	runner.eq(InternalSupply.state(ref)["qty"], 6.0, "twelve percent of 50 guests")
	runner.check(Ledger.check_balanced(), "books balance")
	var _e := cid


func test_hotel_breakfast_and_power_run_through_internal_supply() -> void:
	var cid := _company()
	_open_cafe()
	_open_hotel()
	runner.check(Hotel.set_breakfast("own_cafe")["ok"], "own cafe kitchen chosen")
	runner.check(InternalSupply.feasible(InternalSupply.key("cafe_breakfast", "hotel")), "breakfast pair listed")
	Living.lease("helio_warehouse")
	runner.check(Energy.start()["ok"], "energy opens")
	runner.check(InternalSupply.feasible(InternalSupply.key("energy_power_hotel", "hotel")), "power pair listed")
	var cogs_before := Ledger.balance(cid, "cogs")
	Clock.advance(3 * Clock.DAY)
	var bf := InternalSupply.state(InternalSupply.key("cafe_breakfast", "hotel"))
	var pw := InternalSupply.state(InternalSupply.key("energy_power_hotel", "hotel"))
	runner.check(int(pw["trades"]) >= 2 and float(pw["qty"]) > 0, "nightly electricity bought from your energy business")
	runner.check(int(bf["trades"]) >= 1 or int(Hotel.S()["history"].size()) > 0, "breakfast routed when guests stayed")
	var rows: Dictionary = Segments.compute(cid, 0, Clock.now() + 1)["rows"]
	runner.check(float(rows["energy"]["internal_revenue"]) > 0 and float(rows["hotel"]["internal_charge"]) > 0, "both segments record the power trade")
	runner.check(float(rows["energy"]["cogs"]) > 0, "the supplier carries the real cost")
	runner.check(Ledger.balance(cid, "cogs") >= cogs_before, "costs recorded")
	runner.eq(Ledger.balance(cid, "ic_clearing"), 0.0, "clearing nets to zero")
	runner.check(Ledger.check_balanced(), "books balance")
	var totals: Dictionary = Segments.compute(cid, 0, Clock.now() + 1)["totals"]
	runner.eq(totals["internal_revenue"], totals["internal_charge"], "eliminated in the group total")


func test_media_group_campaign_goes_through_internal_supply() -> void:
	var cid := _company()
	_open_media()
	_open_cafe()
	runner.check(Media.group_campaign("cafe", 5000.0)["ok"], "internal campaign")
	Clock.advance(int(Media.cfg()["campaign_days"]) * Clock.DAY)
	var st := InternalSupply.state(InternalSupply.key("media_ads", "cafe"))
	runner.check(float(st["qty"]) > 0 and int(st["trades"]) >= 1, "daily media cost is an internal trade")
	runner.eq(-Ledger.balance(cid, "revenue"), 0.0, "no invented agency revenue")
	var row: Dictionary = Segments.compute(cid, 0, Clock.now() + 1)["rows"]["cafe"]
	runner.check(float(row["internal_charge"]) > 0 and float(row["internal_cost"]) > 0, "cafe segment shows the internal purchase")
	runner.check(Cafe.ads_factor() >= 1.0, "demand effect untouched")


# ------------------------------------------------------------------ group jobs
## Touching a module's S() first makes it create its full default state, as the game does.
func _init_module(name: String) -> void:
	match name:
		"hotel": Hotel.S()
		"media": Media.S()
		"manufacturing": Manufacturing.S()
		"real_estate": RealEstate.S()
		"saas": Saas.S()


func _set_path(path: String, value: float) -> void:
	var node: Dictionary = GameState.data
	var parts := path.split(".")
	_init_module(parts[0])
	for i in range(parts.size() - 1):
		if not node.has(parts[i]):
			node[parts[i]] = {}
		node = node[parts[i]]
	node[parts[-1]] = value


## Makes one job part measurably done, whatever kind of metric it reads.
func _satisfy(part: Dictionary) -> void:
	var src := str(part["metric"])
	var arg := src.substr(src.get_slice(":", 0).length() + 1)
	match src.get_slice(":", 0):
		"stat":
			GameState.inc_stat(arg, float(part["target"]))
		"data":
			_set_path(arg, SynergyMetrics.value(src) + float(part["target"]))
		"count":
			var path := arg.get_slice("|", 0)
			var parts := path.split(".")
			_init_module(parts[0])
			var bucket: Dictionary = GameState.data.get(parts[0], {})
			GameState.data[parts[0]] = bucket
			if not bucket.has(parts[1]):
				bucket[parts[1]] = {}
			for i in int(part["target"]):
				bucket[parts[1]]["QA-%d-%d" % [Clock.now(), bucket[parts[1]].size()]] = {"status": arg.get_slice("|", 1).get_slice("=", 1)}


func _exercise(def_id: String) -> void:
	var cid := _company()
	var def: Dictionary = DataDB.quests[def_id]
	var reward := float(def["reward"])
	# --- offer and acceptance
	var id := GroupJobs.offer(def_id)
	runner.check(id != "", "offered " + def_id)
	runner.eq(GroupJobs.offer(def_id), "", "no duplicate offer")
	runner.check(not GroupJobs.subcontract(id, def["parts"][0]["id"])["ok"], "cannot subcontract before accepting")
	runner.check(GroupJobs.accept(id)["ok"], "accepted")
	runner.check(not GroupJobs.accept(id)["ok"], "accepted once")
	runner.check(not GroupJobs.all_done(GroupJobs.get_job(id)), "nothing done at the start")
	# --- full completion
	for part in def["parts"]:
		_satisfy(part)
	var cash := Ledger.cash(cid)
	runner.eq(GroupJobs.check_all(), 1, "finished job settles on the next check")
	var job := GroupJobs.get_job(id)
	runner.eq(job["status"], "completed", "full completion")
	runner.eq(Ledger.cash(cid) - cash, reward, "full reward paid")
	var rows: Dictionary = Segments.compute(cid, 0, Clock.now() + 1)["rows"]
	for part in def["parts"]:
		runner.check(absf(float(rows[part["industry"]]["revenue"]) - reward * float(part["share"])) < 0.02, "paid into " + str(part["industry"]) + " segment")
	runner.check(Ledger.check_balanced(), "balanced after full pay")
	# --- partial completion: only the first part by the deadline
	var id2 := GroupJobs.offer(def_id)
	runner.check(GroupJobs.accept(id2)["ok"], "second run accepted")
	_satisfy(def["parts"][0])
	cash = Ledger.cash(cid)
	runner.eq(GroupJobs.check_all(), 0, "not due yet")
	var expected := snappedf(reward * float(def["parts"][0]["share"]), 0.01)
	runner.eq(GroupJobs.earned(GroupJobs.get_job(id2)), expected, "shows what it would pay now")
	Clock.advance(int(def["deadline_days"]) * Clock.DAY + 120)
	var j2 := GroupJobs.get_job(id2)
	runner.eq(j2["status"], "partial", "deadline settles a part-done job")
	runner.eq(Ledger.cash(cid) - cash, expected, "partial pay equals the finished share")
	# --- nothing done: fails, pays nothing
	var id3 := GroupJobs.offer(def_id)
	GroupJobs.accept(id3)
	cash = Ledger.cash(cid)
	Clock.advance(int(def["deadline_days"]) * Clock.DAY + 120)
	runner.eq(GroupJobs.get_job(id3)["status"], "failed", "untouched job fails")
	runner.eq(Ledger.cash(cid), cash, "no reward and no penalty")
	# --- subcontract every part: nobody is soft-locked
	var id4 := GroupJobs.offer(def_id)
	GroupJobs.accept(id4)
	cash = Ledger.cash(cid)
	var fees := 0.0
	for part in def["parts"]:
		var r := GroupJobs.subcontract(id4, part["id"])
		runner.check(r["ok"], "subcontract " + str(part["id"]))
		fees += float(part["subcontract"])
	var j4 := GroupJobs.get_job(id4)
	runner.eq(j4["status"], "completed", "all parts subcontracted completes the job")
	runner.eq(snappedf(Ledger.cash(cid) - cash, 0.01), snappedf(reward - fees, 0.01), "net of subcontract fees")
	runner.check(reward > fees, "subcontracting everything still pays")
	runner.check(Ledger.check_balanced(), "balanced after subcontracting")


func test_job_trade_fair_week() -> void: _exercise("trade_fair_week")
func test_job_new_neighbourhood_opening() -> void: _exercise("new_neighbourhood_opening")
func test_job_city_fleet_refresh() -> void: _exercise("city_fleet_refresh")
func test_job_green_showroom_launch() -> void: _exercise("green_showroom_launch")
func test_job_private_label_launch() -> void: _exercise("private_label_launch")


func test_job_mixed_subcontract_and_own_work() -> void:
	var cid := _company()
	var def: Dictionary = DataDB.quests["trade_fair_week"]
	var id := GroupJobs.offer("trade_fair_week")
	GroupJobs.accept(id)
	_satisfy(def["parts"][0])
	var part1: Dictionary = def["parts"][1]
	runner.check(GroupJobs.subcontract(id, part1["id"])["ok"], "subcontract one part")
	runner.check(not GroupJobs.subcontract(id, def["parts"][0]["id"])["ok"], "a part already done cannot be subcontracted")
	runner.eq(GroupJobs.get_job(id)["status"], "active", "still waiting for the last part")
	var cash := Ledger.cash(cid)
	_satisfy(def["parts"][2])
	GroupJobs.check_all()
	runner.eq(GroupJobs.get_job(id)["status"], "completed", "own work plus subcontract completes")
	runner.eq(Ledger.cash(cid) - cash, float(def["reward"]), "reward paid on completion")
	runner.check(GroupJobs.next_step(GroupJobs.get_job(id)) != "", "next step text")


func test_subcontract_needs_cash_and_offers_lapse() -> void:
	var cid := _company(0.0)
	var def: Dictionary = DataDB.quests["trade_fair_week"]
	var id := GroupJobs.offer("trade_fair_week")
	GroupJobs.accept(id)
	Ledger.post(cid, "QA drain", [{"acct": "equity", "dr": Ledger.cash(cid)}, {"acct": "cash", "cr": Ledger.cash(cid)}])
	var r := GroupJobs.subcontract(id, def["parts"][0]["id"])
	runner.check(not r["ok"], "cannot subcontract without cash")
	runner.eq(GroupJobs.get_job(id)["status"], "active", "still active")
	var late := GroupJobs.offer("new_neighbourhood_opening")
	Clock.advance((int(DataDB.quests["new_neighbourhood_opening"]["offer_days"]) + 1) * Clock.DAY)
	runner.eq(GroupJobs.get_job(late)["status"], "expired", "unanswered offers lapse")
	runner.check(not GroupJobs.accept(late)["ok"], "an expired offer cannot be accepted")


func test_offers_need_two_running_industries_and_a_company() -> void:
	runner.eq(GroupJobs.offer("trade_fair_week"), "", "no company, no offer")
	_company()
	var def: Dictionary = DataDB.quests["trade_fair_week"]
	runner.eq(GroupJobs.running_parts(def), 0, "no part industry running")
	_open_media()
	_open_cafe()
	runner.eq(GroupJobs.running_parts(def), 2, "media and cafe run")
	var total := 0
	for i in 400:
		GroupJobs.S()["last_offer"].clear()
		Clock.advance_to(Clock.at_day_time(maxi(0, int(def["earliest_day"]) - Clock.day_index() + 1) + (i % 2), 9 * 60))
		total += GroupJobs.offered().size()
		if total > 0:
			break
	runner.check(total > 0, "the daily roll eventually posts an offer once two industries run")


# ------------------------------------------------------------------ milestones
func test_milestones_unlock_from_real_counters() -> void:
	_company()
	runner.check(not Milestones.unlocked("eco_first"), "locked at the start")
	GameState.inc_stat("orders_delivered", 1)
	var fresh := Milestones.check_all()
	runner.check("eco_first" in fresh, "first order unlocks it")
	runner.check(Milestones.unlocked("eco_first") and GameState.flag("milestone_eco_first"), "flag and state")
	runner.check(GameState.data["timeline"].any(func(e): return e["kind"] == "milestone" and str(e["text"]).contains("First parcel out")), "timeline entry")
	runner.eq(Milestones.check_all().size(), 0, "unlocks once")
	GameState.inc_stat("orders_delivered", 99)
	runner.check("eco_100" in Milestones.check_all(), "hundredth order")
	runner.eq(Milestones.count("ecommerce")[0], 2, "two of five for ecommerce")
	_open_hotel()
	Hotel.S()["completed_blocks"] = 1
	runner.check("hotel_block" in Milestones.check_all(), "hotel block via save data")
	var rows: Array = []
	for i in 30:
		rows.append({"day": i, "occupied": 57, "rooms": 60, "room_revenue": 1.0, "walks": 0, "dirty": 0})
	Hotel.S()["history"] = rows
	runner.check("hotel_90" in Milestones.check_all(), "ninety percent occupancy over 30 nights")
	var m: Dictionary = DataDB.milestones["eco_1000"]
	runner.eq(Milestones.progress(m)["have"], 100.0, "progress reads the counter")


func test_milestones_follow_the_game_clock() -> void:
	_company()
	GameState.inc_stat("cafe_customers", 100)
	Clock.advance(60)
	runner.check(Milestones.unlocked("cafe_100"), "the hourly tick unlocks without being asked")


func test_factory_yield_streak() -> void:
	_company()
	_open_factory()
	var m: Dictionary = DataDB.milestones["mfg_yield"]
	for i in 30:
		GameState.data["manufacturing"]["quality"].append({"job": "J", "t": Clock.now(), "qty": 10, "defect": 0.02, "sample": 0.5, "escaped": 0.1})
		if i == 10:
			GameState.data["manufacturing"]["quality"].append({"job": "J", "t": Clock.now(), "qty": 10, "defect": 0.2, "sample": 0.5, "escaped": 1.0})
		Clock.advance(Clock.DAY)
		if i == 10:
			runner.eq(int(Milestones.S()["streak"].get("mfg_yield", 0)), 0, "a bad day resets the streak")
	runner.check(int(Milestones.S()["streak"]["mfg_yield"]) >= 19, "streak counts good production days")
	runner.check(not Milestones.unlocked("mfg_yield"), "not yet unlocked after a reset")
	for i in 12:
		GameState.data["manufacturing"]["quality"].append({"job": "J", "t": Clock.now(), "qty": 10, "defect": 0.02, "sample": 0.5, "escaped": 0.1})
		Clock.advance(Clock.DAY)
	runner.check(Milestones.unlocked("mfg_yield"), "thirty good days in a row unlock it")
	runner.check(Milestones.progress(m)["streak"], "progress is a streak")


func test_idle_days_do_not_break_a_streak() -> void:
	_company()
	_open_factory()
	GameState.data["manufacturing"]["quality"].append({"job": "J", "t": Clock.now(), "qty": 10, "defect": 0.01, "sample": 0.5, "escaped": 0.0})
	Clock.advance(Clock.DAY)
	var before := int(Milestones.S()["streak"].get("mfg_yield", 0))
	Clock.advance(2 * Clock.DAY)
	runner.eq(int(Milestones.S()["streak"].get("mfg_yield", 0)), before, "days without production leave it alone")


# ------------------------------------------------------------------ business board gates
func test_board_gates_and_suggestions() -> void:
	_company(0.0)
	for id in DataDB.businesses:
		if DataDB.businesses[id].get("status", "") != "active":
			continue
		var rows := Gates.rows(id)
		runner.eq(rows.size(), 3, "capital, licence, location for " + str(id))
		for row in rows:
			runner.check(typeof(row["ok"]) == TYPE_BOOL and str(row["text"]) != "", "gate row text " + str(id))
		if id != "ecommerce":
			runner.check(DataDB.synergies["gates"][id]["after"].size() <= 2, "short suggestion list " + str(id))
	runner.check(not Gates.rows("hotel")[0]["ok"], "capital gate fails without cash")
	runner.check(Gates.next_step("hotel") != "", "next step named")
	runner.check(not Gates.rows("cafe")[2]["ok"], "location gate fails before the lease")
	Ledger.post(GameState.company_id(), "QA equity", [{"acct": "cash", "dr": 200000.0}, {"acct": "equity", "cr": 200000.0}])
	runner.check(Gates.rows("hotel")[0]["ok"], "capital gate passes with cash")
	_open_cafe()
	runner.check(Gates.rows("cafe")[2]["ok"], "location gate passes with the lease")
	var after := Gates.suggested_after("hotel")
	runner.check(after.size() > 0 and str(after[0]["name"]) != "", "suggestions listed")
	runner.check(Gates.suggested_after("ecommerce").is_empty(), "ecommerce is the first stop")
	var board := BusinessBoard.new()
	UIRoot.open_modal(board)
	await runner.get_tree().process_frame
	board.selected = "hotel"
	board.rebuild()
	await runner.get_tree().process_frame
	var texts: Array = []
	for label in board.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	runner.check(texts.any(func(t): return str(t).begins_with("✗ ") or str(t).begins_with("✓ ")), "board shows tick or cross gates")
	runner.check(texts.any(func(t): return str(t).contains("Suggested after")), "board shows the suggested order")
	board.close()


# ------------------------------------------------------------------ UI
func _primaries(node: Node) -> int:
	var n := 0
	for b in node.find_children("*", "Button", true, false):
		var box := (b as Button).get_theme_stylebox("normal")
		if box is StyleBoxTexture and box.texture != null and box.texture == Art.tex("ui/button_primary"):
			n += 1
	return n


func test_group_tab_renders_with_one_primary_step() -> void:
	_company()
	var os := CompanyOS.new("home_laptop")
	UIRoot.open_modal(os)
	await runner.get_tree().process_frame
	os._set_tab("group")
	await runner.get_tree().process_frame
	runner.eq(_primaries(os), 1, "empty Group tab has exactly one primary")
	runner.check(os.find_child("GroupNext", true, false) != null, "primary is the next review step")
	var texts: Array = []
	for label in os.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	runner.check(texts.any(func(t): return str(t).contains("Next step")), "empty state names the next step")
	_open_media()
	_open_cafe()
	GroupJobs.offer("trade_fair_week")
	os.rebuild()
	await runner.get_tree().process_frame
	runner.eq(_primaries(os), 1, "one primary with supply rows and an offer")
	runner.check(os.find_child("GroupAccept_GJ-1", true, false) != null, "accept is the primary step")
	runner.check(os.find_child("GroupMode_media_ads_cafe_plus", true, false) != null, "transfer price buttons")
	runner.check(os.find_child("GroupNext", true, false) == null, "the review step is not a second primary")
	var accept := os.find_child("GroupAccept_GJ-1", true, false) as Button
	accept.pressed.emit()
	await runner.get_tree().process_frame
	runner.eq(GroupJobs.get_job("GJ-1")["status"], "active", "button accepts the job")
	runner.check(os.find_child("GroupSub_GJ-1_rooms", true, false) != null, "subcontract offered per open part")
	runner.eq(_primaries(os), 0 if os.find_child("GroupNext", true, false) == null else 1, "no job on offer: single review primary or none")
	(os.find_child("GroupMode_media_ads_cafe_market", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	runner.eq(InternalSupply.state("media_ads:cafe")["mode"], "market", "policy button applies")
	os.close()


func test_phone_timeline_shows_achievements() -> void:
	_company()
	GameState.inc_stat("orders_delivered", 1)
	Milestones.check_all()
	var phone := PhoneUI.new()
	runner.get_tree().root.add_child(phone)
	await runner.get_tree().process_frame
	phone.app = "timeline"
	phone.timeline_page = "achievements"
	phone._render()
	await runner.get_tree().process_frame
	var texts: Array = []
	for label in phone.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	runner.check(texts.any(func(t): return str(t).contains("First parcel out") and str(t).begins_with("✓")), "unlocked milestone listed")
	runner.check(texts.any(func(t): return str(t).begins_with("✗")), "locked milestone listed with progress")
	phone.free()


# ------------------------------------------------------------------ saves
func test_state_survives_save_and_load_and_old_saves_lack_it() -> void:
	var cid := _company()
	_open_media()
	_open_cafe()
	var k := InternalSupply.key("media_ads", "cafe")
	InternalSupply.set_policy(k, "plus", 0.35)
	InternalSupply.trade(k, 200.0)
	var id := GroupJobs.offer("trade_fair_week")
	GroupJobs.accept(id)
	GameState.inc_stat("orders_delivered", 1)
	Milestones.check_all()
	runner.check(SaveSystem.save(4), "saved")
	GameState.data["synergy"]["pairs"][k]["mode"] = "cost"
	runner.check(SaveSystem.load_data(4), "loaded")
	runner.eq(InternalSupply.state(k)["mode"], "plus", "transfer policy restored")
	runner.eq(InternalSupply.price(k), 1.35, "price restored")
	runner.eq(GroupJobs.get_job(id)["status"], "active", "job restored")
	runner.check(Milestones.unlocked("eco_first"), "milestone restored")
	runner.eq(snappedf(float(InternalSupply.lifetime(k)["revenue"]), 0.01), 270.0, "lifetime trade restored")
	# an old save has none of it
	GameState.data.erase("synergy")
	runner.check(InternalSupply.pairs().size() >= 1, "pairs list without saved state")
	runner.eq(GroupJobs.offered().size(), 0, "no jobs")
	runner.eq(Milestones.count()[0], 0, "no milestones yet")
	Clock.advance(2 * Clock.DAY)
	runner.check(Milestones.unlocked("eco_first"), "a stat from the old save unlocks on the next tick")
	runner.check(Ledger.check_balanced(), "balanced")
	var _c := cid
	var os := CompanyOS.new("home_laptop")
	UIRoot.open_modal(os)
	await runner.get_tree().process_frame
	os._set_tab("group")
	await runner.get_tree().process_frame
	runner.check(os.content != null, "Group tab opens on an old save")
	os.close()
