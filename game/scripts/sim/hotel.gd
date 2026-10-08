class_name Hotel
extends RefCounted
## Hotel / Tourism (#67). Rooms sell through three channels: direct guests pay cash, the OTA settles a weekly statement
## through Jobs (commission is deducted from that receivable) and travel-agency group blocks are Jobs that lock rooms in advance.
## A night audit (23:00) turns the Rate Board settings, housekeeping capacity and city calendar into occupancy, walks,
## reviews and money. Equipment is Assets; every crisis modifier expires. State: GameState.data["hotel"].
const TYPES := ["standard", "deluxe", "suite"]

static func cfg() -> Dictionary:return DataDB.economy.get("hotel",{})
static func S() -> Dictionary:
	if not GameState.data.has("hotel"):
		GameState.data["hotel"]={"active":false,"entity":"","mode":"","stage":1,"rooms":{},"channels":{"ota_open":true,"ota_tier":"standard","ota_allot":0.6},
			"overbook":0.0,"breakfast":"standard","peak":0.0,"temp":false,"events":[],"events_until":0,"blocks":{},"reviews":[],"mods":[],
			"ota":{"gross":0.0,"commission":0.0,"nights":0,"since":0},"history":[],"last_audit":0,"last_occupied":0,"week":-1,"since":0,"stage_since":0,
			"vera":{},"trend":{},"stats":{"walks":0,"walk_cost":0.0,"sold":0,"visits":0},"restaurant":"","completed_blocks":0}
	return GameState.data["hotel"]
static func entity() -> String:return str(S()["entity"])
static func segment_tag() -> String:return "hotel"
static func source(id := "") -> Dictionary:return {"type":"hotel","id":id,"segment":"hotel"}
static func error(text: String) -> Dictionary:return {"ok":false,"error":I18n.t(text)}
static func is_running() -> bool:return GameState.has_game() and bool(GameState.data.get("hotel", {}).get("active", false))  # read-only: asking must not create the state
static func valid() -> bool:return is_running() and Assets._valid_entity(entity()) and (S()["mode"] == "own" or Living.has_lease(str(cfg()["lease_property"])))
static func stage() -> int:return int(S()["stage"])
static func rooms_of(type: String) -> int:return int(S()["rooms"].get(type,{}).get("n",0))
static func total_rooms() -> int:
	var total := 0
	for type in TYPES:total+=rooms_of(type)
	return total
static func _pay_from(amount: float) -> String:return "cash" if Ledger.cash(entity())>=amount else "accounts_payable"
static func _sr(value: float) -> int:return maxi(0,floori(value+GameState.rng.randf()))
static func type_name(type: String) -> String:return I18n.t(cfg()["types"][type]["name"])

# ---------------------------------------------------------------- opening and growth
static func takeover_price() -> float:return float(cfg()["takeover_price"])
static func lease_cost() -> float:
	var total := float(DataDB.properties[cfg()["lease_property"]]["monthly_rent"])
	for type in TYPES:total+=float(cfg()["types"][type]["fit_rent_room"])*int(cfg()["start_rooms"][type])
	return total
static func open_block() -> String:
	if GameState.company_id()=="" or not GameState.flag("business_account_opened") or Acquisition.sold():return "Register a company and open its bank account first."
	if is_running():return "The hotel is already open."
	if not GameState.visited("the_aster"):return "Visit The Aster in Luxury Heights and meet Henri Dubois first."
	return ""
static func start(mode := "own") -> Dictionary:
	var why := open_block()
	if why!="":return error(why)
	if mode not in ["own","lease"]:return error("Choose to take over or lease the Aster Inn.")
	var ent := GameState.company_id()
	if mode=="own" and Ledger.cash(ent)<takeover_price():return error("Save the takeover price first.")
	if mode=="lease" and Ledger.cash(ent)<lease_cost():return error("Save the first month of rent and equipment first.")
	if entity()!="" and entity()!=ent:GameState.data.erase("hotel")
	var state := S()
	state["entity"]=ent
	state["mode"]=mode
	state["rooms"]={}
	if mode=="lease":
		var leased := Living.lease(str(cfg()["lease_property"]))
		if not leased["ok"]:return error(str(leased["error"]))
	for type in TYPES:
		var count := int(cfg()["start_rooms"][type])
		var result := _fit(type,count,mode=="lease",true)
		if not result["ok"]:return result
		state["rooms"][type]={"n":count,"price":float(cfg()["types"][type]["ref_price"]),"cond":float(cfg()["condition_start"]),"assets":[result["id"]],"reno_until":0}
	state["active"]=true
	state["stage"]=1
	state["since"]=Clock.now()
	state["stage_since"]=Clock.now()
	state["last_audit"]=Clock.day_index()-1
	state["reviews"]=[{"day":Clock.day_index(),"kind":"prior","w":float(cfg()["review"]["start_weight"]),"score":float(cfg()["review"]["start_rating"])}]
	GameState.set_flag("hotel_active")
	_ensure_events()
	refresh()
	GameState.timeline(I18n.t("Took over the Aster Inn."),"milestone")
	return {"ok":true}
static func _fit(type: String,count: int,rented: bool,initial := false) -> Dictionary:
	var t: Dictionary=cfg()["types"][type]
	var spec := {"entity":entity(),"name":"%s rooms"%t["name"],"life_days":cfg()["asset_life_days"],"maintenance_cost":count*float(t["maintenance_room"]),
		"maintenance_days":cfg()["asset_maintenance_days"],"failure_chance":cfg()["asset_failure_chance"],"segment":"hotel"}
	if rented:
		spec["price"]=count*float(t["fit_rent_room"])
		spec["rent_days"]=30
		return Assets.rent(spec)
	spec["price"]=count*float(t["fit_unit" if initial else "fit_unit_expand"])
	return Assets.buy(spec)
static func gate(target: int) -> Array:
	var c: Dictionary=cfg()["stages"].get(str(target),{})
	if c.is_empty() or not valid():return []
	var info := stats(30)
	var days := int((Clock.now()-int(S()["stage_since"]))/Clock.DAY)
	return [
		[stage()==target-1,"Complete the previous growth stage."],
		[days>=int(c["min_days"]),I18n.t("Operate for %d days at this stage (%d so far).")%[int(c["min_days"]),days]],
		[float(info["occupancy"])>=float(c["min_occupancy"]),I18n.t("30-day occupancy at least %d%% (now %d%%).")%[roundi(float(c["min_occupancy"])*100),roundi(float(info["occupancy"])*100)]],
		[rating()>=float(c["min_rating"]),I18n.t("Guest rating at least %.1f (now %.1f).")%[float(c["min_rating"]),rating()]],
		[review_count()>=int(c["min_reviews"]),I18n.t("At least %d guest reviews (now %d).")%[int(c["min_reviews"]),review_count()]],
		[Staff.people().filter(func(p):return p["role"] in ["housekeeper","front_desk"]).size()>=int(c["min_staff"]),I18n.t("Hire at least %d hotel staff (now %d).")%[int(c["min_staff"]),Staff.people().filter(func(p):return p["role"] in ["housekeeper","front_desk"]).size()]]]
static func upgrade_price(target: int) -> float:
	var c: Dictionary=cfg()["stages"][str(target)]
	var total := float(c["extra_asset"]["price"])
	for type in TYPES:total+=int(c["add"][type])*float(cfg()["types"][type]["fit_unit_expand"])
	return total
static func upgrade() -> Dictionary:
	if not valid() or stage()>=3:return error("The hotel is already at its largest size.")
	var target := stage()+1
	for row in gate(target):
		if not row[0]:return error("Meet every growth condition first.")
	if Ledger.cash(entity())<upgrade_price(target):return error("Save the expansion price first.")
	var c: Dictionary=cfg()["stages"][str(target)]
	for type in TYPES:
		var count := int(c["add"][type])
		var result := _fit(type,count,false)
		if not result["ok"]:return result
		S()["rooms"][type]["n"]=rooms_of(type)+count
		S()["rooms"][type]["assets"].append(result["id"])
	var extra := Assets.buy({"entity":entity(),"name":c["extra_asset"]["name"],"price":c["extra_asset"]["price"],"life_days":cfg()["asset_life_days"],"maintenance_cost":c["extra_asset"]["maintenance_cost"],
		"maintenance_days":cfg()["asset_maintenance_days"],"failure_chance":cfg()["asset_failure_chance"],"segment":"hotel"})
	if not extra["ok"]:return extra
	if target==2:S()["restaurant"]=extra["id"]
	else:S()["resort_asset"]=extra["id"]
	S()["stage"]=target
	S()["stage_since"]=Clock.now()
	GameState.timeline(I18n.t("Opened %s.")%I18n.t(c["name"]),"milestone")
	return {"ok":true}
static func restaurant_working() -> bool:
	var asset: Dictionary=Assets.S()["items"].get(str(S().get("restaurant","")),{})
	return stage()>=2 and asset.get("status","")=="working"

# ---------------------------------------------------------------- Rate Board settings
## `by_player` marks the room type as a deliberate player choice, which the assistant never overrides.
static func set_price(type: String,price: float,by_player := true) -> Dictionary:
	if not valid() or not S()["rooms"].has(type) or not is_finite(price):return error("Choose a room type and a price.")
	var t: Dictionary=cfg()["types"][type]
	if price<float(t["min_price"]) or price>float(t["max_price"]):return error("That price is outside the allowed range.")
	S()["rooms"][type]["price"]=snappedf(price,.01)
	if by_player:S()["rooms"][type]["player_set"]=true
	return {"ok":true}
static func set_channels(ota_open: bool,tier: String,allot: float) -> Dictionary:
	if not valid() or not cfg()["ota_tiers"].has(tier) or not is_finite(allot) or allot<0 or allot>1:return error("Choose a valid channel mix.")
	S()["channels"]={"ota_open":ota_open,"ota_tier":tier,"ota_allot":snappedf(allot,.01)}
	return {"ok":true}
static func set_overbook(share: float) -> Dictionary:
	if not valid() or not is_finite(share) or share<0 or share>float(cfg()["overbook_max"])+.0001:return error("Overbooking must stay between 0% and 10%.")
	S()["overbook"]=snappedf(share,.01)
	return {"ok":true}
static func set_peak(share: float) -> Dictionary:
	if not valid() or not is_finite(share) or share<0 or share>float(cfg()["peak_max"])+.0001:return error("Choose a peak-day surcharge between 0% and 40%.")
	S()["peak"]=snappedf(share,.01)
	return {"ok":true}
static func set_breakfast(mode: String) -> Dictionary:
	if not valid() or not cfg()["breakfast"].has(mode):return error("Choose a breakfast option.")
	if mode=="own_cafe" and not Cafe.leased():return error("Lease your corner cafe before using its kitchen for breakfast.")
	S()["breakfast"]=mode
	return {"ok":true}
static func set_temp(on: bool) -> Dictionary:
	if not valid():return error("Open the hotel first.")
	S()["temp"]=on
	return {"ok":true}
static func rack_price(type: String) -> float:return float(S()["rooms"][type]["price"])
static func price_at(type: String,day: int) -> float:
	var surcharge := float(S()["peak"]) if demand_index(day)>=float(cfg()["peak_threshold"]) else 0.0
	return snappedf(rack_price(type)*(1+surcharge),.01)

# ---------------------------------------------------------------- demand calendar
static func demand_index(day: int) -> float:
	var date := Clock.date_at((day-1)*Clock.DAY+12*60)
	return float(cfg()["dow"][int(date["weekday"])])*float(cfg()["season"][int(date["month"])-1])*event_mult(day)*float(S()["trend"].get(_month_of(day),1.0))*CityFuture.demand_factor("hotel")
static func _month_of(day: int) -> String:
	var date := Clock.date_at((day-1)*Clock.DAY+12*60)
	return "%d-%02d"%[int(date["year"]),int(date["month"])]
static func event_at(day: int) -> Dictionary:
	var best := {}
	for e in S()["events"]:
		if int(e["start"])<=day and day<=int(e["end"]) and (best.is_empty() or float(e["mult"])>float(best["mult"])):best=e
	return best
static func event_mult(day: int) -> float:return float(event_at(day).get("mult",1.0))
static func mod_mult(kind: String) -> float:
	var value := 1.0
	for m in S()["mods"]:
		if m["kind"]==kind and Clock.now()<int(m["until"]):value*=float(m["mult"])
	return value
static func _ensure_events() -> void:
	var today := Clock.day_index()
	var horizon := today+int(cfg()["event_horizon_days"])
	var state := S()
	state["events"]=state["events"].filter(func(e):return int(e["end"])>=today-7)
	var from := maxi(int(state["events_until"]),today)
	while from<horizon:
		if GameState.rng.randf()<float(cfg()["event_week_chance"]):
			var def: Dictionary=cfg()["city_events"][GameState.rng.randi_range(0,cfg()["city_events"].size()-1)]
			var start := from+GameState.rng.randi_range(0,maxi(0,7-int(def["days"])))
			state["events"].append({"id":def["id"],"name":def["name"],"start":start,"end":start+int(def["days"])-1,"mult":float(def["mult"])})
		from+=7
	state["events_until"]=from
	for ahead in [0,31,62]:
		var key := _month_of(today+ahead)
		if not state["trend"].has(key):
			var span: Array=cfg()["trend_range"]
			state["trend"][key]=snappedf(GameState.rng.randf_range(float(span[0]),float(span[1])),.01)
	GameState.set_flag("hotel_event_upcoming",state["events"].any(func(e):return int(e["start"])>today))
static func _blocked(type: String,day: int) -> int:
	var total := 0
	for b in S()["blocks"].values():
		if b["status"]=="locked" and b["type"]==type and int(b["start"])<=day and day<=int(b["end"]):total+=int(b["rooms"])
	return total
static func out_of_order(type: String) -> bool:
	var r: Dictionary=S()["rooms"].get(type,{})
	if r.is_empty():return true
	if Clock.now()<int(r["reno_until"]):return true
	for m in S()["mods"]:
		if m["kind"]=="ooo" and m.get("type","")==type and Clock.now()<int(m["until"]):return true
	return type_issues(type)["broken"]
static func type_issues(type: String) -> Dictionary:
	var result := {"broken":false,"due":false}
	for id in S()["rooms"].get(type,{}).get("assets",[]):
		var item: Dictionary=Assets.S()["items"].get(id,{})
		if item.get("status","")=="broken":result["broken"]=true
		if item.get("maintenance_due",false):result["due"]=true
	return result
static func demand(type: String,day: int,rating_value := -1.0) -> Dictionary:
	if rating_value<0:rating_value=rating()
	var c: Dictionary=cfg()
	var tier: Dictionary=c["ota_tiers"][S()["channels"]["ota_tier"]]
	var price := price_at(type,day)
	var ref := float(c["types"][type]["ref_price"])
	var pf := clampf(pow(price/ref,-float(c["price_elasticity"])),.15,2.4)
	var boost := mod_mult("demand")*Media.demand_boost("hotel")*(float(c["stages"]["3"]["tourism_boost"]) if stage()>=3 else 1.0)
	var pull := clampf(1+float(c["market_pull"])*(rating_value-3.5),.45,1.5)
	var base := rooms_of(type)*float(c["base_demand_per_room"])*demand_index(day)*pf*boost*pull*Industries.market_demand("hotel")
	var share := clampf(float(c["direct_base"])+float(c["direct_rating_slope"])*(rating_value-3),.12,.6)
	var rank := clampf(.7+float(c["rank_slope"])*(rating_value-3),.5,1.35)
	var ota := base*float(c["ota_volume"])*float(tier["visibility"])*rank if bool(S()["channels"]["ota_open"]) else 0.0
	return {"direct":base*share,"ota":ota,"price":price}
## Pure expected value, so the 30-day calendar never consumes random numbers.
static func forecast(day: int) -> Dictionary:
	var sold := 0.0
	var blocked := 0
	var total := total_rooms()
	var revenue := 0.0
	var wanted := 0.0
	for type in TYPES:
		var avail := 0 if out_of_order(type) else rooms_of(type)
		var blk := mini(avail,_blocked(type,day))
		var free := avail-blk
		var d := demand(type,day)
		var allot := free*float(S()["channels"]["ota_allot"])*(1+float(S()["overbook"]))
		var shown := minf(float(free),minf(float(d["direct"])*(1-float(cfg()["no_show"]["direct"])),float(free))+minf(float(d["ota"]),allot)*(1-float(cfg()["no_show"]["ota"])))
		sold+=shown
		blocked+=blk
		wanted+=float(d["direct"])+float(d["ota"])
		revenue+=shown*float(d["price"])
	var event := event_at(day)
	return {"day":day,"index":demand_index(day),"event":str(event.get("name","")),"demand":wanted,"blocked":blocked,"occupancy":(sold+blocked)/maxf(1,total),"revenue":revenue,"weekday":int(Clock.date_at((day-1)*Clock.DAY+12*60)["weekday"])}
static func calendar(days := 30) -> Array:
	var rows: Array=[]
	for i in days:rows.append(forecast(Clock.day_index()+i))
	return rows

# ---------------------------------------------------------------- staff and housekeeping
static func _staff(role: String) -> Array:return Staff.people().filter(func(p):return p["role"]==role and Clock.now()>=int(p.get("start",0)))
static func hk_capacity() -> float:
	var capacity := float(cfg()["owner_clean"])
	for p in _staff("housekeeper"):capacity+=float(cfg()["rooms_per_housekeeper"])*Staff.output(p)
	return capacity*mod_mult("capacity")
static func desk_coverage() -> float:
	var need := ceilf(total_rooms()/float(cfg()["desk_rooms_per_staff"]))
	var effective := float(cfg()["desk_owner"])
	for p in _staff("front_desk"):effective+=Staff.output(p)/1.2
	return clampf(effective/maxf(1,need),0,1)
static func turnover_work() -> float:
	var previous := int(S()["last_occupied"])
	var checkouts := ceilf(previous*float(cfg()["turnover"]))
	return checkouts+(previous-checkouts)*float(cfg()["stayover_clean"])

# ---------------------------------------------------------------- reviews
static func rating() -> float:
	var weight := 0.0
	var total := 0.0
	for r in S()["reviews"]:
		weight+=float(r["w"])
		total+=float(r["w"])*float(r["score"])
	return snappedf(total/weight,.01) if weight>0 else float(cfg()["review"]["start_rating"])
static func review_count() -> int:
	var count := 0
	for r in S()["reviews"]:
		if r["kind"]!="prior":count+=int(r["w"])
	return count
static func review_parts() -> Dictionary:
	var weight := 0.0
	var parts := {"cleanliness":0.0,"service":0.0,"value":0.0}
	for r in S()["reviews"]:
		if not r.has("c"):continue
		weight+=float(r["w"])
		parts["cleanliness"]+=float(r["w"])*float(r["c"])
		parts["service"]+=float(r["w"])*float(r["s"])
		parts["value"]+=float(r["w"])*float(r["v"])
	for key in parts:parts[key]=snappedf(parts[key]/weight,.01) if weight>0 else 0.0
	return parts
static func review_score(c: float,s: float,v: float) -> float:
	var w: Dictionary=cfg()["review"]["weights"]
	return clampf(float(w["cleanliness"])*c+float(w["service"])*s+float(w["value"])*v,1,5)
static func avg_condition() -> float:
	var weight := 0.0
	var total := 0.0
	for type in TYPES:
		weight+=rooms_of(type)
		total+=rooms_of(type)*float(S()["rooms"][type]["cond"])
	return total/maxf(1,weight)
static func _any_due() -> bool:
	for type in TYPES:
		if type_issues(type)["due"]:return true
	return false
static func _push_review(entry: Dictionary) -> void:
	S()["reviews"].append(entry)
static func _prune_reviews() -> void:
	var cutoff := Clock.day_index()-int(cfg()["review"]["window_days"])
	S()["reviews"]=S()["reviews"].filter(func(r):return int(r["day"])>=cutoff)

# ---------------------------------------------------------------- the night audit
static func on_hour(_t: int,h: int) -> void:
	if not valid():return
	if h==9:
		_ensure_events()
		refresh()
	if h==23:audit()
static func audit() -> Dictionary:
	var today := Clock.day_index()
	if not valid() or int(S()["last_audit"])>=today:return {}
	S()["last_audit"]=today
	var c: Dictionary=cfg()
	var state := S()
	_expire_mods()
	GameState.set_flag("hotel_staffed",not _staff("housekeeper").is_empty())
	# housekeeping: dirty checkout rooms that nobody cleaned cannot be sold tonight
	var work := turnover_work()
	var capacity := hk_capacity()
	var short := maxf(0,work-capacity)
	var temp_used := 0.0
	if short>0 and bool(state["temp"]):
		temp_used=minf(short,float(c["temp_capacity"]))
		short-=temp_used
	var previous := int(state["last_occupied"])
	var dirty := mini(ceili(short),ceili(previous*float(c["turnover"])))
	var free := {}
	var blocks_today := {}
	var guests_total := 0
	for type in TYPES:
		var avail := 0 if out_of_order(type) else rooms_of(type)
		blocks_today[type]=mini(avail,_blocked(type,today))
		free[type]=avail-int(blocks_today[type])
	for i in dirty:
		var pick := ""
		for type in TYPES:
			if int(free[type])>0 and (pick=="" or int(free[type])>int(free[pick])):pick=type
		if pick!="":free[pick]=int(free[pick])-1
	var direct_revenue := 0.0
	var ota_gross := 0.0
	var ota_commission := 0.0
	var walks := 0
	var walk_cost := 0.0
	var occupied := {}
	var sold_revenue := 0.0
	var sold_rooms := 0
	var ota_nights := 0
	var ref_total := 0.0
	var price_total := 0.0
	var tier: Dictionary=c["ota_tiers"][state["channels"]["ota_tier"]]
	var overbook := float(state["overbook"])
	for type in TYPES:
		var d := demand(type,today)
		var f := int(free[type])
		var extra := _sr(f*overbook)
		var cap := f+extra
		var allot := mini(cap,ceili(f*float(state["channels"]["ota_allot"]))+extra) if bool(state["channels"]["ota_open"]) else 0
		var direct_booked := mini(_sr(float(d["direct"])*GameState.rng.randf_range(.85,1.15)),cap)
		var ota_booked := mini(_sr(float(d["ota"])*GameState.rng.randf_range(.85,1.15)),mini(cap-direct_booked,allot))
		var direct_arrive := 0
		var ota_arrive := 0
		for i in direct_booked:
			if GameState.rng.randf()>=float(c["no_show"]["direct"]):direct_arrive+=1
		for i in ota_booked:
			if GameState.rng.randf()>=float(c["no_show"]["ota"]):ota_arrive+=1
		var over := maxi(0,direct_arrive+ota_arrive-f)
		var walked_ota := mini(over,ota_arrive)
		var walked_direct := over-walked_ota
		var seated_direct := direct_arrive-walked_direct
		var seated_ota := ota_arrive-walked_ota
		var price := float(d["price"])
		direct_revenue+=seated_direct*price
		ota_gross+=seated_ota*price
		ota_commission+=seated_ota*price*float(tier["commission"])
		ota_nights+=seated_ota
		walks+=over
		walk_cost+=over*(price*float(c["walk_price_mult"])+float(c["walk_relocation"]))
		occupied[type]=seated_direct+seated_ota+int(blocks_today[type])
		var guests := int(occupied[type])
		guests_total+=guests
		sold_rooms+=seated_direct+seated_ota
		sold_revenue+=seated_direct*price+seated_ota*price
		ref_total+=guests*float(c["types"][type]["ref_price"])
		price_total+=(seated_direct+seated_ota)*price+int(blocks_today[type])*_block_rate(type,today)
	# money
	var source_id := "audit-%d"%today
	if direct_revenue>0:Ledger.post(entity(),I18n.t("Direct room revenue"),[{"acct":"cash","dr":direct_revenue},{"acct":"revenue","cr":direct_revenue}],source(source_id))
	var supplies := guests_total*float(c["supplies_room"])
	var breakfast_mode: String=state["breakfast"] if state["breakfast"]!="own_cafe" or Cafe.leased() else "standard"
	# Own-cafe breakfast is an internal supply (#71): the cafe books the real cost and an internal sale, the hotel the purchase.
	if not (breakfast_mode=="own_cafe" and InternalSupply.hotel_breakfast(guests_total)):supplies+=guests_total*float(c["breakfast"][breakfast_mode]["cost"])
	if supplies>0:Ledger.post(entity(),I18n.t("Guest supplies, laundry and breakfast"),[{"acct":"cogs","dr":supplies},{"acct":_pay_from(supplies),"cr":supplies}],source(source_id))
	var utilities := total_rooms()*float(c["utilities_room_day"])
	if stage()>=3:utilities+=float(c["stages"]["3"]["site_cost_day"])
	utilities=InternalSupply.hotel_power(utilities)   # electricity from your own energy business (#71), if running on the same books
	if utilities>0:Ledger.expense(entity(),"other",utilities,I18n.t("Hotel utilities"),source(source_id),_pay_from(utilities))
	var overhead := total_rooms()*float(c["overhead_room_day"]) *(1.0 if state["mode"]=="own" else float(c["overhead_lease_share"]))   # a landlord carries property tax
	if overhead>0:Ledger.expense(entity(),"insurance",overhead,I18n.t("Hotel insurance, property tax and software"),source(source_id),_pay_from(overhead))
	if walk_cost>0:Ledger.expense(entity(),"penalties",walk_cost,I18n.t("Walk compensation for overbooked guests"),source(source_id),_pay_from(walk_cost))
	if temp_used>0:Ledger.expense(entity(),"other",temp_used*float(c["temp_cost_room"]),I18n.t("Temporary cleaners"),source(source_id),_pay_from(temp_used*float(c["temp_cost_room"])))
	if restaurant_working() and guests_total>0:
		var spend := guests_total*float(c["fb_spend"])*clampf(float(c["fb_capture"])+float(c["fb_capture_rating"])*(rating()-3),.2,.9)
		var cost := spend*float(c["fb_cogs"])
		Ledger.post(entity(),I18n.t("Restaurant and bar sales"),[{"acct":"cash","dr":spend},{"acct":"revenue","cr":spend}],source(source_id))
		Ledger.post(entity(),I18n.t("Restaurant ingredients"),[{"acct":"cogs","dr":cost},{"acct":_pay_from(cost),"cr":cost}],source(source_id))
	var ota: Dictionary=state["ota"]
	ota["gross"]=float(ota["gross"])+ota_gross
	ota["commission"]=float(ota["commission"])+ota_commission
	ota["nights"]=int(ota["nights"])+ota_nights
	if int(ota["since"])==0:ota["since"]=today
	if today-int(ota["since"])>=int(c["ota_settle_days"])-1:_ota_settle()
	_run_blocks(today)
	# reviews
	var parts := {}
	if guests_total>0:
		parts=_guest_review(today,guests_total,short,work,walks,price_total,ref_total,breakfast_mode)
	if walks>0:_push_review({"day":today,"kind":"walk","w":float(walks),"score":float(cfg()["review"]["walk_score"])})
	_resolve_vera(today,parts)
	_prune_reviews()
	# wear
	for type in TYPES:
		var r: Dictionary=state["rooms"][type]
		var share := float(occupied[type])/maxf(1,rooms_of(type))
		r["cond"]=maxf(0,float(r["cond"])-float(c["wear_base"])-float(c["wear_occupancy"])*share)
	state["last_occupied"]=guests_total
	state["stats"]["walks"]=int(state["stats"]["walks"])+walks
	state["stats"]["walk_cost"]=float(state["stats"]["walk_cost"])+walk_cost
	state["stats"]["sold"]=int(state["stats"]["sold"])+guests_total
	var block_revenue := 0.0
	for type in TYPES:block_revenue+=int(blocks_today[type])*_block_rate(type,today)
	state["history"].append({"day":today,"occupied":guests_total,"rooms":total_rooms(),"room_revenue":sold_revenue+block_revenue,"walks":walks,"dirty":dirty})
	if state["history"].size()>130:state["history"].pop_front()
	return {"occupied":guests_total,"walks":walks,"revenue":sold_revenue+block_revenue,"dirty":dirty}
static func _block_rate(type: String,day: int) -> float:
	for b in S()["blocks"].values():
		if b["status"]=="locked" and b["type"]==type and int(b["start"])<=day and day<=int(b["end"]):return float(b["rate"])
	return 0.0
static func _guest_review(today: int,guests: int,short: float,work: float,walks: int,price_total: float,ref_total: float,breakfast_mode: String) -> Dictionary:
	var rv: Dictionary=cfg()["review"]
	var skill := 3.0
	var housekeepers := _staff("housekeeper")
	if not housekeepers.is_empty():
		skill=0.0
		for p in housekeepers:skill+=float(p["skill"])
		skill/=housekeepers.size()
	var condition := avg_condition()
	var clean := clampf(float(rv["clean_base"])-float(rv["clean_shortfall"])*short/maxf(1,work)-float(rv["clean_condition"])*(1-condition/100)+float(rv["clean_skill"])*(skill-3),1,5)
	var service := clampf(float(rv["service_base"])+float(rv["service_desk"])*desk_coverage()+float(cfg()["breakfast"][breakfast_mode]["service"])+(float(rv["service_restaurant"]) if restaurant_working() else 0.0)-float(rv["service_walk"])*walks/maxf(1,guests),1,5)
	var equipment := clampf(1+4*condition/100-(float(cfg()["maintenance_due_penalty"]) if _any_due() else 0.0),1,5)
	var quality := .4*clean+.3*service+.3*equipment
	var fair := float(rv["fair_base"])+float(rv["fair_slope"])*(quality-1)
	var value := clampf(float(rv["value_base"])-float(rv["value_slope"])*(price_total/maxf(1,ref_total*fair)-1),1,5)
	var noise := float(rv["noise"])
	var parts := {"c":clean,"s":service,"v":value}
	var shown := {"c":clampf(clean+GameState.rng.randf_range(-noise,noise),1,5),"s":clampf(service+GameState.rng.randf_range(-noise,noise),1,5),"v":clampf(value+GameState.rng.randf_range(-noise,noise),1,5)}
	var weight := clampf(roundf(guests*float(rv["per_guest"])),1,float(rv["max_daily_weight"]))
	_push_review({"day":today,"kind":"guest","w":weight,"c":shown["c"],"s":shown["s"],"v":shown["v"],"score":review_score(shown["c"],shown["s"],shown["v"])})
	return parts
static func _resolve_vera(today: int,parts: Dictionary) -> void:
	var vera: Dictionary=S()["vera"]
	if vera.is_empty() or int(vera.get("day",0))>today or parts.is_empty():return
	var rv: Dictionary=cfg()["review"]
	var service := float(parts["s"])+(float(rv["vera_vip_service"]) if vera.get("vip",false) else 0.0)
	var c := float(parts["c"])
	var v := float(parts["v"])
	var score := clampf(review_score(c,service,v)+float(rv["vera_bias"]),1,5)
	_push_review({"day":today,"kind":"vera","w":float(rv["vera_weight"]),"c":c,"s":service,"v":v,"score":score})
	S()["stats"]["visits"]=int(S()["stats"]["visits"])+1
	S()["vera"]={}
	GameState.timeline(I18n.t("Critic Vera Stone published her review: %.1f stars.")%score,"business")
static func _expire_mods() -> void:
	S()["mods"]=S()["mods"].filter(func(m):return Clock.now()<int(m["until"]))
static func add_mod(kind: String,mult: float,days: float,extra := {}) -> void:
	var m := {"kind":kind,"mult":mult,"until":Clock.now()+int(days*Clock.DAY)}
	m.merge(extra)
	S()["mods"].append(m)

# ---------------------------------------------------------------- OTA statements and group blocks (Jobs)
static func _ota_settle() -> void:
	var ota: Dictionary=S()["ota"]
	var gross := snappedf(float(ota["gross"]),.01)
	var commission := snappedf(float(ota["commission"]),.01)
	ota["since"]=Clock.day_index()
	if gross<=0:return
	var id := Jobs.offer({"entity":entity(),"client":cfg()["ota_name"],"scope":"OTA room-night statement","price":gross,"work":1,"terms":int(cfg()["ota_terms"]),"segment":"hotel","due":Clock.now()+Clock.DAY})
	if id=="":return
	ota["gross"]=0.0
	ota["commission"]=0.0
	var nights := int(ota["nights"])
	ota["nights"]=0
	Jobs.accept(id)
	Jobs.progress(id,1)
	Jobs.deliver(id)
	Jobs.invoice(id)
	var job := Jobs.get_job(id)
	var taken := minf(commission,float(job["receivable"]))
	if taken>0:
		Ledger.post(entity(),I18n.t("OTA commission deducted from statement"),[{"acct":"exp:platform_fees","dr":taken},{"acct":"accounts_receivable","cr":taken}],{"type":"hotel","id":id,"segment":"hotel"})
		job["receivable"]=snappedf(float(job["receivable"])-taken,.01)
	job["nights"]=nights
	job["commission"]=taken
	S()["ota_statements"]=int(S().get("ota_statements",0))+1
static func ota_pending() -> Dictionary:return {"gross":float(S()["ota"]["gross"]),"commission":float(S()["ota"]["commission"])}
static func refresh() -> void:
	if not valid():return
	var week := Clock.day_index()/7
	if int(S()["week"])==week:return
	S()["week"]=week
	for b in S()["blocks"].values():
		if b["status"]=="offered":b["status"]="expired"
	var offers := int(cfg()["block"]["offers_per_week"][str(stage())])
	for n in offers:_block_offer()
static func _block_offer() -> void:
	var c: Dictionary=cfg()["block"]
	var weights := {"standard":.6,"deluxe":.3,"suite":.1}
	var roll := GameState.rng.randf()
	var type := "standard"
	var acc := 0.0
	for key in TYPES:
		acc+=float(weights[key])
		if roll<=acc:type=key;break
	var span: Array=c["rooms"][str(stage())]
	var rooms := mini(GameState.rng.randi_range(int(span[0]),int(span[1])),maxi(1,floori(rooms_of(type)*float(c["max_share"]))))
	var nights := GameState.rng.randi_range(int(c["nights"][0]),int(c["nights"][1]))
	var start := Clock.day_index()+GameState.rng.randi_range(int(c["start_ahead"][0]),int(c["start_ahead"][1]))
	var event_id := ""
	var upcoming: Array=S()["events"].filter(func(e):return int(e["start"])>Clock.day_index()+2)
	if not upcoming.is_empty() and GameState.rng.randf()<.5:
		var e: Dictionary=upcoming[GameState.rng.randi_range(0,upcoming.size()-1)]
		start=int(e["start"])
		event_id=str(e["id"])+"@"+str(e["start"])
		nights=mini(nights,int(e["end"])-int(e["start"])+1)
	var rate := snappedf(rack_price(type)*(1-float(c["discount"])),.01)
	var id := Jobs.offer({"entity":entity(),"client":c["client"],"scope":"Group room block","price":rate*rooms*nights,"work":nights,"terms":int(c["terms"]),"deposit":c["deposit"],"segment":"hotel","due":Clock.now()+int(c["accept_days"])*Clock.DAY})
	if id=="":return
	S()["blocks"][id]={"id":id,"type":type,"rooms":rooms,"nights":nights,"start":start,"end":start+nights-1,"rate":rate,"rack":rack_price(type),"status":"offered","done":0,"event":event_id}
static func block_conflict(b: Dictionary) -> String:
	var type := str(b["type"])
	var cap := floori(rooms_of(type)*float(cfg()["block"]["max_share"]))
	for day in range(int(b["start"]),int(b["end"])+1):
		if _blocked(type,day)+int(b["rooms"])>cap:return "Too many rooms of this type are already locked for those nights."
	if int(S()["rooms"][type]["reno_until"])>(int(b["start"])-1)*Clock.DAY:return "That room type is being renovated during the stay."
	return ""
static func accept_block(id: String) -> Dictionary:
	var b: Dictionary=S()["blocks"].get(id,{})
	if not valid() or b.is_empty() or b["status"]!="offered":return error("Choose an open group block.")
	if int(b["start"])<=Clock.day_index():
		b["status"]="expired"
		return error("This group block has expired.")
	var why := block_conflict(b)
	if why!="":return error(why)
	if not Jobs.accept(id)["ok"]:
		b["status"]="expired"
		return error("This job is no longer available.")
	b["status"]="locked"
	GameState.timeline(I18n.t("Locked a group block of %d rooms for %s.")%[int(b["rooms"]),cfg()["block"]["client"]],"business")
	return {"ok":true}
static func _run_blocks(today: int) -> void:
	for b in S()["blocks"].values():
		if b["status"]!="locked" or int(b["start"])>today or today>int(b["end"]):continue
		var avail := 0 if out_of_order(b["type"]) else rooms_of(b["type"])
		var missing := maxi(0,int(b["rooms"])-avail)
		if missing>0:
			var cost := missing*(float(b["rate"])+float(cfg()["walk_relocation"]))
			Ledger.expense(entity(),"penalties",cost,I18n.t("Walk compensation for a group block"),source(b["id"]),_pay_from(cost))
		b["done"]=int(b["done"])+1
		Jobs.progress(b["id"],1)
		if int(b["done"])>=int(b["nights"]):
			Jobs.deliver(b["id"])
			Jobs.invoice(b["id"])
			b["status"]="stayed"
			S()["completed_blocks"]=int(S()["completed_blocks"])+1
static func cancel_block(id: String) -> void:
	var b: Dictionary=S()["blocks"].get(id,{})
	if b.is_empty() or b["status"]!="locked":return
	var job := Jobs.get_job(id)
	var refund := float(job.get("deposit_paid",0))
	if refund>0:
		Ledger.post(entity(),I18n.t("Group block deposit refunded"),[{"acct":"deferred_revenue","dr":refund},{"acct":_pay_from(refund),"cr":refund}],source(id))
		job["deposit_paid"]=0.0
	job["status"]="closed"
	b["status"]="cancelled"
static func open_blocks() -> Array:return S()["blocks"].values().filter(func(b):return b["status"]=="offered")
static func locked_blocks() -> Array:return S()["blocks"].values().filter(func(b):return b["status"]=="locked")

# ---------------------------------------------------------------- equipment and renovation
static func maintain_cost(type: String) -> float:
	var total := 0.0
	for id in S()["rooms"][type]["assets"]:
		var item: Dictionary=Assets.S()["items"].get(id,{})
		if item.get("status","")=="broken" or item.get("maintenance_due",false):total+=float(item.get("maintenance_cost",0))
	return total
static func maintain(type: String) -> Dictionary:
	if not valid() or not S()["rooms"].has(type):return error("Choose a room type.")
	var cost := maintain_cost(type)
	if cost<=0:return error("This equipment needs no service today.")
	if Ledger.cash(entity())<cost:return error("Save the equipment service cost first.")
	for id in S()["rooms"][type]["assets"]:
		var item: Dictionary=Assets.S()["items"].get(id,{})
		if item.get("status","")=="broken" or item.get("maintenance_due",false):
			var result := Assets.maintain(id)
			if not result["ok"]:return result
	return {"ok":true}
static func renovation_cost(type: String) -> float:return rooms_of(type)*float(cfg()["types"][type]["renovate_room"])
static func renovate(type: String) -> Dictionary:
	if not valid() or not S()["rooms"].has(type):return error("Choose a room type.")
	var r: Dictionary=S()["rooms"][type]
	if Clock.now()<int(r["reno_until"]):return error("This room type is already being renovated.")
	var days := int(cfg()["types"][type]["renovate_days"])
	for b in S()["blocks"].values():
		if b["type"]==type and b["status"]=="locked" and int(b["end"])>=Clock.day_index() and int(b["start"])<=Clock.day_index()+days:return error("A locked group block uses these rooms during the renovation.")
	var cost := renovation_cost(type)
	if Ledger.cash(entity())<cost:return error("Save the renovation cost first.")
	var asset := Assets.buy({"entity":entity(),"name":"%s renovation"%cfg()["types"][type]["name"],"price":cost,"life_days":cfg()["asset_life_days"],"maintenance_cost":rooms_of(type)*float(cfg()["types"][type]["maintenance_room"]),
		"maintenance_days":cfg()["asset_maintenance_days"],"failure_chance":cfg()["asset_failure_chance"],"segment":"hotel"})
	if not asset["ok"]:return asset
	r["assets"].append(asset["id"])
	r["reno_until"]=Clock.now()+days*Clock.DAY
	Sim.schedule(int(r["reno_until"]),"hotel.reno",{"type":type})
	GameState.timeline(I18n.t("Started renovating the %s rooms.")%type_name(type),"business")
	return {"ok":true}

# ---------------------------------------------------------------- statistics
static func stats(days := 30) -> Dictionary:
	var rows: Array=S()["history"].slice(maxi(0,S()["history"].size()-days))
	var occupied := 0.0
	var rooms := 0.0
	var revenue := 0.0
	for row in rows:
		occupied+=float(row["occupied"])
		rooms+=float(row["rooms"])
		revenue+=float(row["room_revenue"])
	return {"days":rows.size(),"occupancy":occupied/rooms if rooms>0 else 0.0,"adr":revenue/occupied if occupied>0 else 0.0,"revpar":revenue/rooms if rooms>0 else 0.0,"revenue":revenue}

# ---------------------------------------------------------------- crises, events, closure
static func crisis(kind: String,_retain := true) -> Dictionary:
	if not valid():return error("Open the hotel first.")
	var c: Dictionary=cfg()["crisis"]
	match kind:
		"slump":
			_clear_slump()
			add_mod("demand",float(c["slump_mult"]),float(c["slump_days"]),{"label":"slump"})
		"slump_promo":
			if Ledger.cash(entity())<float(c["slump_promo_cost"]):return error("Save the promotion cost first.")
			Ledger.expense(entity(),"advertising",float(c["slump_promo_cost"]),I18n.t("Low-season promotion"),source())
			_clear_slump()
			add_mod("demand",float(c["slump_promo_mult"]),float(c["slump_promo_days"]),{"label":"slump"})
		"storm_respond":
			if Ledger.cash(entity())<float(c["storm_response_cost"]):return error("Save the guest recovery cost first.")
			Ledger.expense(entity(),"other",float(c["storm_response_cost"]),I18n.t("Guest recovery and public reply"),source())
			_push_review({"day":Clock.day_index(),"kind":"storm","w":float(c["storm_response_weight"]),"score":float(c["storm_response_score"])})
		"storm_ignore":_push_review({"day":Clock.day_index(),"kind":"storm","w":float(c["storm_ignore_weight"]),"score":float(c["storm_ignore_score"])})
		"breakdown_fast":
			if Ledger.cash(entity())<float(c["breakdown_fast_cost"]):return error("Save the emergency repair cost first.")
			Ledger.expense(entity(),"maintenance",float(c["breakdown_fast_cost"]),I18n.t("Emergency repair"),source())
			_wear_incident(false)
		"breakdown_slow":
			if Ledger.cash(entity())<float(c["breakdown_slow_cost"]):return error("Save the repair cost first.")
			Ledger.expense(entity(),"maintenance",float(c["breakdown_slow_cost"]),I18n.t("Scheduled repair"),source())
			_wear_incident(true)
		"cancel_promo","cancel_accept":
			if kind=="cancel_promo":
				if Ledger.cash(entity())<float(c["cancel_promo_cost"]):return error("Save the flash-sale cost first.")
				Ledger.expense(entity(),"advertising",float(c["cancel_promo_cost"]),I18n.t("Flash sale after cancellation"),source())
				add_mod("demand",float(c["cancel_promo_mult"]),float(c["cancel_promo_days"]))
			_cancel_next_event()
		"strike_raise":
			var bonus := float(c["strike_bonus"])*_staff("housekeeper").size()
			if bonus>0:
				if Ledger.cash(entity())<bonus:return error("Save the housekeeping bonus first.")
				Ledger.expense(entity(),"payroll",bonus,I18n.t("Housekeeping settlement bonus"),source())
		"strike_replace":add_mod("capacity",float(c["strike_replace_mult"]),float(c["strike_replace_days"]))
		"strike_hold":
			add_mod("capacity",float(c["strike_hold_mult"]),float(c["strike_hold_days"]))
			for p in _staff("housekeeper"):p["morale"]=maxi(0,int(p["morale"])-int(c["strike_morale"]))
		"vera_vip":
			var comp := rack_price("suite")
			if Ledger.cash(entity())<comp:return error("Save the VIP upgrade cost first.")
			Ledger.expense(entity(),"other",comp,I18n.t("VIP suite upgrade for a critic"),source())
			S()["vera"]={"day":Clock.day_index(),"vip":true}
		"vera_normal":S()["vera"]={"day":Clock.day_index(),"vip":false}
		_:return error("Unknown hotel crisis.")
	return {"ok":true}
static func _clear_slump() -> void:S()["mods"]=S()["mods"].filter(func(m):return m.get("label","")!="slump")
static func _wear_incident(slow: bool) -> void:
	var candidates := TYPES.filter(func(t):return rooms_of(t)>0)
	var type: String=candidates[GameState.rng.randi_range(0,candidates.size()-1)]
	S()["rooms"][type]["cond"]=maxf(0,float(S()["rooms"][type]["cond"])-float(cfg()["crisis"]["breakdown_condition"]))
	if slow:add_mod("ooo",1.0,float(cfg()["crisis"]["breakdown_slow_days"]),{"type":type})
static func _cancel_next_event() -> void:
	var upcoming: Array=S()["events"].filter(func(e):return int(e["start"])>Clock.day_index())
	if upcoming.is_empty():return
	var gone: Dictionary=upcoming[0]
	S()["events"].erase(gone)
	for b in S()["blocks"].values():
		if str(b["event"])==str(gone["id"])+"@"+str(gone["start"]) and b["status"] in ["locked","offered"]:
			if b["status"]=="locked":cancel_block(b["id"])
			else:b["status"]="expired"
	_ensure_events()
static func handle(kind: String,payload: Dictionary) -> void:
	if not valid():return
	if kind=="hotel.reno":
		var type := str(payload.get("type",""))
		var r: Dictionary=S()["rooms"].get(type,{})
		if r.is_empty() or Clock.now()<int(r["reno_until"]):return
		r["cond"]=100.0
		r["reno_until"]=0
		GameState.timeline(I18n.t("The renovated %s rooms are back on sale.")%type_name(type),"business")
		EventBus.notify.emit(I18n.t("The renovated %s rooms are back on sale.")%type_name(type),"good","sleep")
static func on_company_closed(closed: String) -> void:
	if not is_running() or entity()!=closed:return
	for b in S()["blocks"].values():
		if b["status"]=="locked":cancel_block(b["id"])
		elif b["status"]=="offered":b["status"]="expired"
	S()["active"]=false
	S()["mods"]=[]
	S()["vera"]={}
	GameState.set_flag("hotel_active",false)
	GameState.set_flag("hotel_event_upcoming",false)
	Sim.cancel("hotel.reno","",null)
static func os_tab() -> Dictionary:return {"id":"hotel","label":"Hotel / Tourism","icon":"sleep","order":8,"start_label":"Open Rate Board","render":HotelUI.render}
static func board_detail() -> Callable:return HotelUI.board
static func open_action(_params: Dictionary,_source: Node) -> void:HotelUI.open()
