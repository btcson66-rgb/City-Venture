class_name ShopLife
extends RefCounted
## Saved shop research and personal gym transactions; opportunities use Contracts and EventEngine.

static func cfg() -> Dictionary:
	return DataDB.economy["shop_life"]

static func S() -> Dictionary:
	if not GameState.data.has("shop_life"):
		GameState.data["shop_life"] = {"research":{}, "membership":false, "paid_until":0, "single":false, "classes":{}, "network":{}, "shipping_until":0}
	return GameState.data["shop_life"]

static func products() -> Array:
	var result: Array = []
	for id in DataDB.products:
		if Ecommerce.total_units_at_any(id)>0 or not Ecommerce.listing_for(id).is_empty(): result.append(id)
	return result

static func research(id: String) -> Dictionary:
	if not id in products(): return error("Own or list a product before researching it.")
	var old: Dictionary = S()["research"].get(id,{})
	if not old.is_empty() and Clock.now()<int(old["until"]): return {"ok":true,"card":old,"cached":true}
	var random := RandomNumberGenerator.new()
	random.seed = int(GameState.data["rng"]["seed"]) ^ id.hash() ^ Clock.day_index()
	var price := snappedf(float(DataDB.product(id)["ref_price"])*Macro.costs()*random.randf_range(float(cfg()["premium_min"]),minf(float(cfg()["premium_max"]),float(cfg()["expensive_ratio"]))),0.01)
	Clock.advance(int(cfg()["research_minutes"]))
	var card := {"product":id,"price":price,"at":Clock.now(),"until":Clock.now()+int(cfg()["research_days"])*Clock.DAY}
	S()["research"][id] = card
	return {"ok":true,"card":card,"cached":false}

static func tier(id: String) -> String:
	var listing := Ecommerce.listing_for(id)
	if listing.is_empty(): return "No selling price yet — create a listing."
	var ratio := float(listing["price"])/float(DataDB.product(id)["ref_price"])
	return "Cheap" if ratio<float(cfg()["cheap_ratio"]) else ("Expensive" if ratio>float(cfg()["expensive_ratio"]) else "Typical")

static func next_renewal(t: int) -> int:
	var original := Clock.date_at(t)
	var next := t+Clock.DAY
	# Anniversary day clamped to the last day of a short month.
	for day in 62:
		var date := Clock.date_at(next)
		var following := Clock.date_at(next+Clock.DAY)
		if date["month"]!=original["month"] and (int(date["day"])==int(original["day"]) or following["month"]!=date["month"]): return next
		next += Clock.DAY
	return next

static func buy(monthly: bool) -> Dictionary:
	if monthly and bool(S()["membership"]): return error("Membership already renews — choose a class.")
	if not monthly and bool(S()["single"]): return error("A single-class pass is ready — choose a class.")
	if monthly and Clock.now()<int(S()["paid_until"]):
		S()["membership"]=true
		return {"ok":true}
	var cost := float(cfg()["monthly_fee"] if monthly else cfg()["single_fee"])
	if Ledger.cash("player")<cost: return error("Insufficient personal cash — return after earning money.")
	Ledger.expense("player","personal_fitness",cost,I18n.t("Harbor Point Fitness: %s")%Fmt.money(cost),{"type":"fitness"})
	if monthly:
		S()["membership"]=true
		S()["paid_until"]=next_renewal(Clock.now())
	else: S()["single"]=true
	return {"ok":true}

static func cancel() -> void:
	S()["membership"]=false

static func on_hour(t: int) -> void:
	if not GameState.data.has("shop_life"): return
	while bool(S()["membership"]) and t>=int(S()["paid_until"]):
		var cost := float(cfg()["monthly_fee"])
		if Ledger.cash("player")<cost:
			S()["membership"]=false
			EventBus.notify.emit("Fitness renewal stopped — insufficient personal cash.","warn","people")
			return
		Ledger.expense("player","personal_fitness",cost,I18n.t("Fitness monthly renewal: %s")%Fmt.money(cost),{"type":"fitness"})
		S()["paid_until"]=next_renewal(int(S()["paid_until"]))

static func has_pass() -> bool:
	return bool(S()["single"]) or Clock.now()<int(S()["paid_until"])

static func attend(id: String) -> Dictionary:
	var selected: Dictionary = {}
	for item in cfg()["class_times"]:
		if item["id"]==id: selected=item
	if selected.is_empty() or Clock.minute_of_day()<int(selected["minute"]) or Clock.minute_of_day()>=int(selected["minute"])+int(cfg()["class_grace_minutes"]): return error("Class is not starting — check the timetable.")
	var key := "%d:%s"%[Clock.day_index(),id]
	if S()["classes"].has(key): return error("Already attended — choose another class.")
	if not has_pass(): return error("Buy a membership or single-class pass first.")
	for old in S()["classes"].keys():
		if Clock.now()-int(S()["classes"][old])>31*Clock.DAY:S()["classes"].erase(old)
	S()["classes"][key]=Clock.now()
	if Clock.now()>=int(S()["paid_until"]): S()["single"]=false
	Clock.advance(int(cfg()["class_minutes"]))
	PersonalLife.rest(0,float(PersonalLife.cfg()["gym_stress_relief"]))
	var event := network()
	return {"ok":true,"event":event}

static func network() -> String:
	if GameState.randf()>=float(cfg()["network_chance"]): return ""
	var candidates: Array = ["fitness_carrier"]
	if not products().is_empty(): candidates.append("fitness_press")
	if Ecommerce.total_units_at_any("water_bottle")>0 or not Ecommerce.listing_for("water_bottle").is_empty(): candidates.append("fitness_order")
	candidates=candidates.filter(func(id): return Clock.now()>=int(S()["network"].get(id,0)) and not EventEngine._queued(id))
	if candidates.is_empty(): return ""
	var id: String = GameState.pick(candidates)
	S()["network"][id]=Clock.now()+int(cfg()["network_cooldown_days"])*Clock.DAY
	EventEngine.trigger(id,{"entity":GameState.business_entity(), "product_id":str(products()[0]) if not products().is_empty() else "water_bottle", "press_fee":Fmt.money(float(cfg()["press_cost"])), "press_days":int(cfg()["press_days"]), "trial_days":int(cfg()["carrier_days"]), "trial_discount":Fmt.pct(1.0-float(cfg()["carrier_discount"])), "trial_fee":Fmt.money(float(cfg()["carrier_fee"]))})
	return id

static func network_choice(kind: String, ctx: Dictionary) -> Dictionary:
	# Persist the originating account so a queued opportunity never transfers after closure/restart.
	var entity := str(ctx.get("entity",GameState.business_entity()))
	if entity!=GameState.business_entity() or GameState.data["entities"].get(entity,{}).has("closed"):
		return error("Company closed — decline this opportunity.")
	if kind=="carrier":
		# The discount is a commitment: the sign-up fee is paid whether or not you ship enough to recover it.
		var fee := float(cfg()["carrier_fee"])
		if Ledger.cash(entity)<fee: return error("Insufficient cash for the sign-up fee — decline or earn money.")
		Ledger.expense(entity,"shipping",fee,I18n.t("Courier sign-up fee: %s")%Fmt.money(fee),{"type":"fitness","segment":"ecommerce"})
		S()["shipping_until"]=Clock.now()+int(cfg()["carrier_days"])*Clock.DAY
	elif kind=="order":
		Contracts.create_offer({"buyer":"harbor_point_fitness","product":"water_bottle","qty":cfg()["contract_qty"],"unit_price":snappedf(float(DataDB.product("water_bottle")["ref_price"])*float(cfg()["contract_price_factor"]),0.01),"delivery_days":7,"payment_terms_days":30,"tag":"fitness_order"})
	elif kind=="press":
		var cost := float(cfg()["press_cost"])
		if Ledger.cash(GameState.business_entity())<cost: return error("Insufficient cash for the sponsored report — decline or earn money.")
		Ledger.expense(GameState.business_entity(),"advertising",cost,I18n.t("Sponsored local report: %s")%Fmt.money(cost),{"type":"fitness","segment":"ecommerce"})
		Effects.apply({"op":"demand_mod","days":cfg()["press_days"],"mult":cfg()["press_demand"]},ctx)
	else: return error("This opportunity is no longer available — decline it.")
	return {"ok":true}

static func shipping_factor() -> float:
	return float(cfg()["carrier_discount"]) if GameState.data.has("shop_life") and Clock.now()<int(S()["shipping_until"]) else 1.0

static func error(message: String) -> Dictionary:
	return {"ok":false,"error":I18n.t(message)}
