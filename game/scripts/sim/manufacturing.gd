class_name Manufacturing
extends RefCounted
## OEM production uses Jobs for receivables, Assets for machines and physical material lots for cost.

static func cfg() -> Dictionary: return DataDB.economy.get("manufacturing", {})
static func S() -> Dictionary:
	if not GameState.data.has("manufacturing"):
		GameState.data["manufacturing"] = {"active":false, "entity":"", "machines":[], "lots":[], "pos":{}, "rfqs":{}, "orders":{}, "slots":[], "seq":1, "last_week":-1, "price_mult":1.0, "shortage_until":0, "stage":1, "inspection":0.5, "quality":[], "recalls":{}, "last_rfqs":-1}
	return GameState.data["manufacturing"]
static func segment_tag() -> String: return "manufacturing"
static func is_running() -> bool: return GameState.has_game() and bool(GameState.data.get("manufacturing", {}).get("active", false))  # read-only: asking must not create the state
static func source(id := "") -> Dictionary: return {"type":"manufacturing", "segment":"manufacturing", "id":id}
static func entity() -> String: return str(S()["entity"])
static func _error(text: String) -> Dictionary: return {"ok":false, "error":I18n.t(text)}
static func valid() -> bool: return is_running() and Assets._valid_entity(entity()) and Living.has_lease("unit12_factory")

static func setup_block() -> String:
	if GameState.company_id() == "": return "Register a company first."
	if Acquisition.sold(): return "Start a new company before opening another industry."
	if not GameState.flag("business_account_opened"): return "Open the business bank account first."
	if not Living.has_lease("unit12_factory"): return "Lease Unit 12 in Industrial first."
	return ""

static func start() -> Dictionary:
	var why := setup_block()
	if why != "": return _error(why)
	if is_running(): return _error("The factory is already open.")
	# Terminal state belongs to its original entity; a replacement company gets a clean operation.
	if S()["entity"] != "" and S()["entity"] != GameState.company_id(): GameState.data.erase("manufacturing")
	S()["entity"] = GameState.company_id()
	S()["active"] = true
	GameState.set_flag("manufacturing_active")
	GameState.timeline(I18n.t("Opened the Unit 12 factory."), "milestone")
	refresh_rfqs()
	return {"ok":true}

static func hire_tomas() -> Dictionary:
	if not valid(): return _error("Open the factory first.")
	if Staff.S()["people"].has("TOMAS"): return _error("Tomas already works here.")
	var why := Staff.hire_block("technician")
	if why != "": return _error(why)
	# Do not clear another recruitment campaign when this named applicant is hired.
	if not Staff.S()["posting"].is_empty() or not Staff.S()["applicants"].is_empty(): return _error("Finish the current recruitment first.")
	Staff.S()["applicants"].append({"id":"TOMAS", "name":"Tomas Varga", "role":"technician", "skill":4, "salary_week":float(cfg()["technician_salary_week"]), "trait":"", "appearance":GameState.default_appearance(), "outfit":"logistics_site", "morale":70})
	return Staff.hire("TOMAS")

static func acquire_machine(rented := true, automated := false) -> Dictionary:
	if not valid(): return _error("Open the factory first.")
	if automated and Bank.loans(entity()).is_empty(): return _error("Arrange a business loan before automation.")
	if automated and int(S()["stage"]) >= 2: return _error("Automation is already installed.")
	if S()["machines"].size() >= int(cfg()["machine_limit"]): return _error("No free machine bay.")
	var spec := {"entity":entity(), "segment":"manufacturing", "price":float(cfg()["cnc_price"] if automated else cfg()["machine_rent_month"] if rented else cfg()["machine_price"]), "life_days":int(cfg()["machine_life_days"]), "rent_days":30, "maintenance_days":int(cfg()["maintenance_days"]), "maintenance_cost":float(cfg()["maintenance_cost"]), "failure_chance":float(cfg()["failure_chance"]), "capacity":float(cfg()["capacity_hour"])*(float(cfg()["automation_mult"]) if automated else 1.0), "automated":automated}
	var result := Assets.rent(spec) if rented and not automated else Assets.buy(spec)
	if result["ok"]:
		S()["machines"].append(result["id"])
		if automated: S()["stage"] = 2
	return result

static func material_units() -> int:
	var n := 0
	for lot in S()["lots"]: n += int(lot["qty"])
	return n
static func material_price() -> float:
	var shortage := float(cfg()["shortage_price_mult"]) if Clock.now() < int(S()["shortage_until"]) else 1.0
	return snappedf(float(cfg()["material_price"])*float(S()["price_mult"])*shortage, 0.01)
static func order_material(qty: int) -> Dictionary:
	if not valid(): return _error("Open the factory first.")
	if qty < int(cfg()["moq"]): return _error("Meet Ferro's minimum order quantity.")
	var pending := 0
	for po in S()["pos"].values():
		if po["status"] == "transit": pending += int(po["qty"])
	var finished := Ecommerce.stock("unit12_factory", "phone_stand")
	if material_units()+pending+finished+qty > int(cfg()["material_capacity"]): return _error("Not enough factory storage capacity.")
	var cost := snappedf(qty*material_price(), 0.01)
	if Ledger.cash(entity()) < cost: return _error("Not enough cash for this purchase.")
	var id := "MAT-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"])+1
	var due := Clock.now()+int(cfg()["material_lead_days"])*Clock.DAY
	if Clock.now() < int(S()["shortage_until"]): due = maxi(due, int(S()["shortage_until"]))
	S()["pos"][id] = {"id":id, "qty":qty, "cost":cost, "unit":material_price(), "quality":GameState.rng.randf_range(0.85, 1.15), "due":due, "status":"transit"}
	Ledger.post(entity(), I18n.t("Ferro material purchase"), [{"acct":"inventory_in_transit", "dr":cost}, {"acct":"cash", "cr":cost}], source(id))
	Sim.schedule(due, "mfg.arrival", {"id":id})
	return {"ok":true, "id":id}

static func refresh_rfqs() -> void:
	if not valid(): return
	for rfq in S()["rfqs"].values():
		if rfq["status"] == "open" and Clock.now() > int(rfq["due"]): rfq["status"] = "expired"
	if int(S()["last_rfqs"]) == Clock.day_index(): return
	S()["last_rfqs"] = Clock.day_index()
	for i in range(maxi(1, roundi(ceili(float(cfg()["rfqs_per_week"])*CityFuture.demand_factor("manufacturing")) * Industries.market_demand("manufacturing")))):
		var id := "RFQ-%d" % int(S()["seq"])
		S()["seq"] = int(S()["seq"])+1
		var qty := GameState.rng.randi_range(int(cfg()["rfq_qty_min"]), int(cfg()["rfq_qty_max"]))
		S()["rfqs"][id] = {"id":id, "client":"Lena Park" if i == 0 else "Kessler Precision", "product":"phone_stand", "qty":qty, "min_price":float(cfg()["quote_min"]), "max_price":float(cfg()["quote_max"]), "due":Clock.now()+int(cfg()["rfq_due_days"])*Clock.DAY, "max_defect":float(cfg()["max_defect"]), "status":"open", "competitors":Rivals.competitors("manufacturing")}

## Win probability for a quote: 100% at the client's floor price, falling linearly to `win_at_max` at their ceiling, 0 above it.
static func win_chance(rfq: Dictionary, price: float) -> float:
	var lo := float(rfq["min_price"])
	var hi := float(rfq["max_price"])
	if price > hi: return 0.0
	if price <= lo or hi <= lo: return 1.0
	return lerpf(1.0, float(cfg()["win_at_max"]), (price-lo)/(hi-lo))

static func quote(id: String, price: float) -> Dictionary:
	var rfq: Dictionary = S()["rfqs"].get(id, {})
	if not valid() or rfq.is_empty() or rfq["status"] != "open" or Clock.now() >= int(rfq["due"]): return _error("This RFQ has expired.")
	if not is_finite(price) or price <= 0: return _error("Enter a positive unit price.")
	var chance := Rivals.bid_chance(win_chance(rfq, price), rfq.get("competitors", []))
	# The active market snapshot supplies real competing firms; legacy quotes keep their original odds.
	if chance <= 0.0 or (chance < 1.0 and GameState.rng.randf() >= chance):
		rfq["status"] = "rejected"
		return {"ok":false, "error":I18n.t("%s chose a rival quote. Review your price and try another RFQ.") % I18n.t(str(rfq["client"]))}
	var job := Jobs.offer({"entity":entity(), "client":rfq["client"], "scope":I18n.t("OEM phone stands"), "price":snappedf(price*int(rfq["qty"]), 0.01), "work":int(rfq["qty"]), "due":rfq["due"], "terms":int(cfg()["payment_terms"]), "deposit":float(cfg()["deposit_rate"]), "penalty_rate":float(cfg()["late_penalty"]), "segment":"manufacturing", "competitors":rfq.get("competitors", [])})
	if job == "": return _error("Invalid order terms.")
	var accepted := Jobs.accept(job)
	if not accepted["ok"]: return accepted
	var order := rfq.duplicate(true)
	order.merge({"job":job, "unit_price":price, "status":"active", "produced":0, "escaped":0.0, "cost":0.0, "refund":0.0}, true)
	S()["orders"][job] = order
	rfq["status"] = "accepted"
	return {"ok":true, "id":job}

## Formula is multiplicative; wear, skill and material quality are independent physical inputs.
static func defect_rate(machine_condition: float, skill: float, batch_quality: float, overtime := false) -> float:
	return clampf(float(cfg()["base_defect"])*clampf(machine_condition, 1, 5)*clampf(1.4-skill*0.16, 0.4, 1.4)*clampf(batch_quality, 0.5, 2)+(float(cfg()["overtime_yield_loss"]) if overtime else 0.0), 0, 0.5)

static func plan(job: String, machine: String, start_time: int, hours: int, overtime := false, outsource := false) -> Dictionary:
	var order: Dictionary = S()["orders"].get(job, {})
	if not valid() or order.is_empty() or order["status"] != "active": return _error("Choose an active OEM order.")
	if hours < 1 or hours > int(cfg()["max_slot_hours"]) or start_time < Clock.now() or start_time%60 != 0 or start_time > Clock.now()+7*Clock.DAY: return _error("Choose an hourly slot within the coming week.")
	if not outsource and machine not in S()["machines"]: return _error("Choose a factory machine.")
	if not outsource and Staff.count("technician") == 0 and int(S()["stage"]) < 2: return _error("Hire a technician first.")
	if not outsource:
		for slot in S()["slots"]:
			if slot["machine"] == machine and slot["status"] == "scheduled" and start_time < int(slot["end"])+int(cfg()["changeover_hours"])*60 and start_time+hours*60+int(cfg()["changeover_hours"])*60 > int(slot["start"]): return _error("This slot overlaps production or changeover.")
		for hour in range(hours):
			var h := int((start_time+hour*60)%Clock.DAY)/60
			if not overtime and (h < 9 or h >= 17 or Clock.weekday(start_time+hour*60) not in [1,2,3,4,5]): return _error("Enable overtime outside weekday working hours.")
	var id := "SLOT-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"])+1
	var slot := {"id":id, "job":job, "machine":machine, "start":start_time, "end":start_time+hours*60, "overtime":overtime, "outsource":outsource, "status":"scheduled", "worked":0}
	S()["slots"].append(slot)
	if outsource: Sim.schedule(int(slot["end"]), "mfg.outsource", {"id":id})
	return {"ok":true, "id":id}

static func set_inspection(ratio: float) -> Dictionary:
	if not is_finite(ratio) or ratio < 0 or ratio > 1: return _error("Inspection must be between 0% and 100%.")
	S()["inspection"] = ratio
	return {"ok":true}

static func _consume(qty: int) -> Dictionary:
	var cost := 0.0
	var quality := 0.0
	var left := qty
	for lot in S()["lots"]:
		var n := mini(left, int(lot["qty"]))
		cost += n*float(lot["unit"])
		quality += n*float(lot["quality"])
		lot["qty"] = int(lot["qty"])-n
		left -= n
		if left == 0: break
	S()["lots"] = S()["lots"].filter(func(l): return int(l["qty"]) > 0)
	return {"cost":snappedf(cost, 0.01), "quality":quality/maxi(1, qty)}

static func _produce(slot: Dictionary, t: int) -> void:
	var order: Dictionary = S()["orders"].get(slot["job"], {})
	if order.is_empty() or order["status"] != "active": slot["status"] = "cancelled"; return
	var asset: Dictionary = Assets.S()["items"].get(slot["machine"], {})
	if asset.is_empty() or asset["status"] != "working": return
	var skill := 0.0
	var workers := 0
	var overtime_now := bool(slot["overtime"]) and (Clock.weekday(t) not in [1,2,3,4,5] or int(t%Clock.DAY)/60 < 9 or int(t%Clock.DAY)/60 >= 17)
	for person in Staff.people():
		if person["role"] == "technician" and t >= int(person.get("start", 0)) and (overtime_now or Staff.is_working(person, t)):
			skill = maxf(skill, float(person["skill"]))
			workers += 1
	if workers == 0 and not asset.get("automated", false): return
	if asset.get("automated", false): skill = maxf(skill, float(cfg()["automation_skill"]))
	var ratio := float(S()["inspection"])
	var capacity := float(asset["capacity"])/(1+ratio*float(cfg()["inspection_time"]))
	var n := mini(mini(int(capacity), material_units()), int(order["qty"])-int(order["produced"]))
	if n <= 0: return
	var wage := snappedf(float(cfg()["technician_salary_week"])/40*float(cfg()["overtime_wage_mult"]), 0.01) if overtime_now and workers > 0 else 0.0
	if wage > Ledger.cash(entity()): return
	var used := _consume(n)
	var condition := 1+maxf(0, Clock.day_index()-int(asset["maintenance_day"]))/float(cfg()["maintenance_days"])
	var defects := defect_rate(condition, skill, float(used["quality"]), overtime_now)
	# Inspected defects are reworked at a cost, rather than magically vanishing.
	var rework := snappedf(n*defects*ratio*float(cfg()["rework_unit_cost"]), 0.01)
	Ledger.post(entity(), I18n.t("OEM material consumed"), [{"acct":"cogs", "dr":used["cost"]}, {"acct":"inventory", "cr":used["cost"]}], source(order["job"]))
	if wage > 0: Ledger.expense(entity(), "payroll", wage, I18n.t("Factory overtime"), source(order["job"]))
	if rework > 0: Ledger.expense(entity(), "other", rework, I18n.t("Quality rework"), source(order["job"]), "cash" if Ledger.cash(entity()) >= rework else "accounts_payable")
	order["produced"] = int(order["produced"])+n
	order["escaped"] = float(order["escaped"])+n*defects*(1-ratio)
	order["cost"] = snappedf(float(order["cost"])+float(used["cost"])+wage+rework, 0.01)
	Jobs.progress(order["job"], n)
	slot["worked"] = int(slot["worked"])+1
	S()["quality"].append({"job":order["job"], "t":t, "qty":n, "defect":defects, "sample":ratio, "escaped":n*defects*(1-ratio)})
	if S()["quality"].size() > 80: S()["quality"].pop_front()

static func deliver(job: String) -> Dictionary:
	var order: Dictionary = S()["orders"].get(job, {})
	if not valid() or order.is_empty() or order["status"] != "active": return _error("Choose an active OEM order.")
	var result := Jobs.deliver(job)
	if not result["ok"]: return result
	result = Jobs.invoice(job)
	if not result["ok"]: return result
	order["status"] = "delivered"
	var rate := float(order["escaped"])/maxi(1, int(order["qty"]))
	if rate > float(order["max_defect"]): customer_return(job, mini(int(order["qty"]), ceili(float(order["escaped"]))), true)
	GameState.inc_stat("manufacturing_deliveries")
	return result

## Returns reduce remaining AR first; an already collected payment is refunded from cash.
static func customer_return(job: String, qty: int, penalty := false) -> Dictionary:
	var order: Dictionary = S()["orders"].get(job, {})
	if not valid() or order.is_empty() or order["status"] != "delivered" or qty <= 0: return _error("No delivered batch to recall.")
	var value := minf(snappedf(qty*float(order["unit_price"]), 0.01), snappedf(float(Jobs.get_job(job)["price"])-float(order["refund"]), 0.01))
	if value <= 0: return _error("This order was already fully refunded.")
	var j := Jobs.get_job(job)
	var ar := minf(value, float(j.get("receivable", 0))) if j["status"] == "invoiced" else 0.0
	Ledger.post(entity(), I18n.t("OEM defect refund"), [{"acct":"refunds", "dr":value}, {"acct":"accounts_receivable", "cr":ar}, {"acct":"cash", "cr":value-ar}], source(job))
	if j["status"] == "invoiced": j["receivable"] = snappedf(float(j["receivable"])-ar, 0.01)
	order["refund"] = snappedf(float(order["refund"])+value, 0.01)
	if penalty: Ledger.expense(entity(), "penalties", snappedf(value*float(cfg()["defect_penalty"]), 0.01), I18n.t("OEM quality penalty"), source(job))
	Bank.adjust_credit(-int(cfg()["quality_credit_loss"]), "OEM defects")
	return {"ok":true, "refund":value}

static func crisis(kind: String, retain := true) -> Dictionary:
	if not valid(): return _error("Open the factory first.")
	match kind:
		"story_outsource":return IndustryGuidance.recovery_plan(true)
		"story_overtime":return IndustryGuidance.recovery_plan(false)
		"shortage":
			S()["shortage_until"] = Clock.now()+int(cfg()["shortage_days"])*Clock.DAY
			for po in S()["pos"].values():
				if po["status"] == "transit":
					po["due"] = maxi(int(po["due"]), int(S()["shortage_until"]))
					Sim.cancel("mfg.arrival", "id", po["id"])
					Sim.schedule(int(po["due"]), "mfg.arrival", {"id":po["id"]})
		"cancel":
			for order in S()["orders"].values():
				if order["status"] != "active": continue
				var job := Jobs.get_job(order["job"])
				var deposit := float(job["deposit_paid"])
				var kept := minf(deposit, float(order["cost"])) if retain else 0.0
				var lines := [{"acct":"deferred_revenue", "dr":deposit}]
				if kept > 0: lines.append({"acct":"other_income", "cr":kept})
				if deposit-kept > 0: lines.append({"acct":"cash", "cr":deposit-kept})
				if deposit > 0: Ledger.post(entity(), I18n.t("OEM client cancellation"), lines, source(order["job"]))
				job["deposit_paid"] = 0.0
				job["status"] = "closed"
				order["status"] = "cancelled"
				for slot in S()["slots"]:
					if slot["job"] == order["job"]: slot["status"] = "cancelled"
				return {"ok":true, "retained":kept}
		"recall":
			for order in S()["orders"].values():
				if order["status"] == "delivered" and not S()["recalls"].has(order["job"]):
					var result := customer_return(order["job"], maxi(1, ceili(int(order["qty"])*float(cfg()["recall_fraction"]))), true)
					if result["ok"]: S()["recalls"][order["job"]] = true
					return result
		_: return _error("Unknown factory crisis.")
	return {"ok":true}

static func own_brand() -> Dictionary:
	if not valid() or int(S()["stage"]) < 2: return _error("Install automation before your own brand.")
	if int(S()["stage"]) >= 3: return _error("The mould is already paid for.")
	if Ledger.cash(entity()) < float(cfg()["mould_fee"]): return _error("Not enough cash for the mould fee.")
	Ledger.expense(entity(), "fitout", float(cfg()["mould_fee"]), I18n.t("Own-brand mould fee"), source())
	S()["stage"] = 3
	return {"ok":true}

static func brand_batch(qty: int) -> Dictionary:
	if not valid() or int(S()["stage"]) < 3 or qty <= 0 or qty > int(cfg()["brand_batch_max"]): return _error("Unlock your own brand and choose a valid batch.")
	var machine := ""
	for id in S()["machines"]:
		var busy := false
		for slot in S()["slots"]:
			if slot["machine"] == id and slot["status"] == "scheduled": busy = true
		if not busy and Assets.S()["items"].get(id, {}).get("status", "") == "working": machine = id; break
	if machine == "" or material_units() < qty: return _error("Prepare a working machine and enough materials.")
	var asset: Dictionary = Assets.S()["items"][machine]
	var duration := ceili(qty*(1+float(S()["inspection"])*float(cfg()["inspection_time"]))/float(asset["capacity"]))
	var id := "BRAND-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"])+1
	S()["slots"].append({"id":id, "job":id, "machine":machine, "start":Clock.now(), "end":Clock.now()+duration*60, "outsource":true, "status":"scheduled", "worked":0, "brand_qty":qty})
	Sim.schedule(Clock.now()+duration*60, "mfg.brand", {"id":id})
	return {"ok":true, "id":id}

static func _finish_brand(qty: int) -> Dictionary:
	if material_units() < qty: return _error("Prepare a working machine and enough materials.")
	var wholesale := Ecommerce.unit_cost("tradelink_wholesale", "phone_stand")
	var total := snappedf(qty*wholesale*float(cfg()["brand_cost_ratio"]), 0.01)
	var raw_cost := 0.0
	var left := qty
	for lot in S()["lots"]:
		var n := mini(left, int(lot["qty"]))
		raw_cost += n*float(lot["unit"])
		left -= n
		if left == 0: break
	var conversion := maxf(0, snappedf(total-raw_cost, 0.01))
	if Ledger.cash(entity()) < conversion: return _error("Not enough cash for conversion costs.")
	var used := _consume(qty)
	# Material stays in the inventory account, now as finished goods; only conversion adds value.
	if conversion > 0: Ledger.post(entity(), I18n.t("Own-brand conversion"), [{"acct":"inventory", "dr":conversion}, {"acct":"cash", "cr":conversion}], source())
	var cost := (float(used["cost"])+conversion)/qty
	Ecommerce._add_stock("unit12_factory", "phone_stand", qty, cost, float(cfg()["base_defect"])*(1-float(S()["inspection"])))
	return {"ok":true, "unit_cost":cost}

static func handle(kind: String, payload: Dictionary) -> void:
	if not valid(): return
	if kind == "mfg.brand":
		for slot in S()["slots"]:
			if slot["id"] != payload.get("id", "") or slot["status"] != "scheduled": continue
			if Assets.S()["items"].get(slot["machine"], {}).get("status", "") != "working":
				slot["end"] = Clock.now()+60
				Sim.schedule(Clock.now()+60, "mfg.brand", payload)
				return
			var result := _finish_brand(int(slot["brand_qty"]))
			if result["ok"]:
				slot["status"] = "completed"
				GameState.timeline(I18n.t("Own-brand goods are ready for ecommerce."), "business")
			else:
				slot["end"] = Clock.now()+60
				Sim.schedule(Clock.now()+60, "mfg.brand", payload)
	elif kind == "mfg.arrival":
		var po: Dictionary = S()["pos"].get(str(payload.get("id", "")), {})
		if po.is_empty() or po["status"] != "transit" or Clock.now() < int(po["due"]): return
		Ledger.post(entity(), I18n.t("Ferro materials arrived"), [{"acct":"inventory", "dr":po["cost"]}, {"acct":"inventory_in_transit", "cr":po["cost"]}], source(po["id"]))
		S()["lots"].append({"qty":po["qty"], "unit":po["unit"], "quality":po["quality"]})
		po["status"] = "arrived"
	elif kind == "mfg.outsource":
		for slot in S()["slots"]:
			if slot["id"] != payload.get("id", "") or slot["status"] != "scheduled": continue
			var order: Dictionary = S()["orders"].get(slot["job"], {})
			if order.is_empty() or order["status"] != "active": slot["status"] = "cancelled"; return
			var n := int(order["qty"])-int(order["produced"])
			var cost := snappedf(n*float(cfg()["outsource_unit_price"]), 0.01)
			Ledger.post(entity(), I18n.t("Kessler subcontract production"), [{"acct":"cogs", "dr":cost}, {"acct":"cash" if Ledger.cash(entity()) >= cost else "accounts_payable", "cr":cost}], source(order["job"]))
			order["produced"] = int(order["qty"])
			order["cost"] = float(order["cost"])+cost
			Jobs.progress(order["job"], n)
			slot["status"] = "completed"

static func on_hour(t: int, h: int) -> void:
	if not valid(): return
	var week := Clock.day_index()/7
	if h == 8 and week != int(S()["last_week"]):
		S()["last_week"] = week
		S()["price_mult"] = GameState.rng.randf_range(float(cfg()["weekly_price_min"]), float(cfg()["weekly_price_max"]))
		refresh_rfqs()
	for slot in S()["slots"]:
		if slot["status"] != "scheduled" or slot["outsource"]: continue
		# Hour callbacks settle the preceding hour, including the final hour at slot.end.
		if t > int(slot["start"]) and t <= int(slot["end"]): _produce(slot, t-60)
		if t >= int(slot["end"]): slot["status"] = "completed"

static func on_company_closed(closed_entity: String) -> void:
	if S()["entity"] != closed_entity: return
	if not S()["active"]: return
	# Raw lots are absent from ecommerce's finished-goods stock. Liquidate these separately once.
	var raw := 0.0
	for lot in S()["lots"]: raw += int(lot["qty"])*float(lot["unit"])
	raw = snappedf(raw, 0.01)
	var transit := 0.0
	for po in S()["pos"].values():
		if po["status"] == "transit":
			transit += float(po["cost"])
			po["status"] = "closed"
	transit = snappedf(transit, 0.01)
	var raised := snappedf((raw+transit)*Insolvency.LIQUIDATION_RATE, 0.01)
	if raw+transit > 0:
		Ledger.post(entity(), I18n.t("Factory materials liquidated"), [{"acct":"cash", "dr":raised}, {"acct":"exp:inventory_writeoff", "dr":raw+transit-raised}, {"acct":"inventory", "cr":raw}, {"acct":"inventory_in_transit", "cr":transit}], source())
	S()["active"] = false
	GameState.set_flag("manufacturing_active", false)
	for slot in S()["slots"]: slot["status"] = "cancelled"
	for po in S()["pos"].values(): Sim.cancel("mfg.arrival", "id", po["id"])
	for slot in S()["slots"]: Sim.cancel("mfg.outsource", "id", slot["id"])
	for slot in S()["slots"]: Sim.cancel("mfg.brand", "id", slot["id"])
	# Finished goods are still handled by core ecommerce liquidation.
	S()["lots"] = []

static func os_tab() -> Dictionary:
	return {"id":"manufacturing", "label":"Manufacturing", "icon":"company", "order":5, "start_label":"Open Line Planner", "render":ManufacturingUI.render}
static func board_detail() -> Callable: return ManufacturingUI.board
static func open_action(_params: Dictionary, _source: Node) -> void: ManufacturingUI.open()
