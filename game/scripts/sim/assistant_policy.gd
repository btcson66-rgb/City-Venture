class_name AssistantPolicy
extends RefCounted
## Delegates existing transactions, never generates a sale or accepts new investments.
const TASKS := {"restock":"Restocking","packing":"Packing and shipping","cafe_supplies":"Cafe supplies","roster":"Staff schedules","hygiene":"Cafe cleaning","tax":"Tax filing","maintenance":"Asset maintenance","customs":"Customs documents","fx":"Foreign payouts","bills":"Recurring bills","renewals":"Insurance renewals","returns":"Routine returns","hotel_daily":"Hotel daily care","fleet_care":"Fleet servicing","charging_care":"Charging station care","media_delivery":"Completed media deliveries","month_close":"Monthly report summaries"}
static var testing := false
static var _busy := false
static func cfg() -> Dictionary:return DataDB.economy["assistant"]
static func S() -> Dictionary:
	if not GameState.data.has("assistant"):
		# A brand-new game starts with the assistant on; loaded saves get "default": false from the migration.
		GameState.data["assistant"] = {"tasks":{},"last":{},"notices":{},"default":true}
	var state: Dictionary = GameState.data["assistant"]
	for field in ["tasks","last","notices"]:
		if not state.has(field):state[field] = {}
	var fallback := bool(state.get("default", true))
	if not state["tasks"].is_empty() and state["tasks"].values().all(func(value):return not bool(value)):fallback = false
	# An assistant-era save already chose its chores: a new chore with no predecessor starts off.
	var era_default := fallback if state["tasks"].is_empty() else false
	for id in TASKS:
		if not state["tasks"].has(id):
			var predecessor: String = {"fleet_care":"maintenance","charging_care":"maintenance","media_delivery":"packing","hotel_daily":"roster"}.get(id, "")
			state["tasks"][id] = bool(state["tasks"].get(predecessor,era_default)) if predecessor != "" else era_default
	return state
## Saves made before the assistant existed keep every chore manual, so no veteran's cash moves unasked.
static func migrate(data: Dictionary) -> void:
	if data.has("assistant"):return
	var tasks := {}
	for id in TASKS:tasks[id] = false
	data["assistant"] = {"tasks":tasks,"last":{},"notices":{},"default":false,"intro_pending":true}
## One calm explanation, posted once after such a save loads.
static func after_load() -> void:
	if not GameState.has_game() or not GameState.data.has("assistant"):return
	var state: Dictionary = GameState.data["assistant"]
	if not state.get("intro_pending", false):return
	state.erase("intro_pending")
	GameState.add_message("assistant",I18n.t("Meet your assistant: it can restock, pay bills and file taxes for you. Everything stays as you left it. To turn chores on, open Settings, then the Assistant page."),{"category":"work"})
static func enabled(id: String) -> bool:
	if testing and not GameState.flag("test_assistant_run"):return false
	return bool(S()["tasks"].get(id, false))
static func set_task(id: String, value: bool) -> void:
	if TASKS.has(id):S()["tasks"][id] = value
	if id == "fx" and GlobalMarket.live(GameState.company_id()):GlobalMarket.company()["auto_fx"] = value
## `listed_only` flips just the chores the player can currently see (the Assistant page list).
static func set_all(value: bool, listed_only := false) -> void:
	for id in TASKS:
		if listed_only and not available(str(id)):continue
		set_task(id,value)
static func toggle(parent: Node, id: String) -> void:
	var button := CheckBox.new()
	button.name = "Assistant_"+id
	button.text = I18n.t("Let the assistant handle it") + " · " + I18n.t(str(TASKS[id]))
	button.button_pressed = bool(S()["tasks"][id])
	button.toggled.connect(func(on):
		set_task(id,on)
		var modal = UIRoot.top_modal()
		if modal != null:modal.rebuild())
	parent.add_child(button)
static func master(parent: Node) -> void:
	var all := CheckBox.new()
	all.name = "AssistantAll"
	all.text = I18n.t("Let the assistant handle all chores")
	all.button_pressed = TASKS.keys().all(func(id):return not available(str(id)) or bool(S()["tasks"][id]))
	all.toggled.connect(func(on):
		set_all(on,true)
		var modal = UIRoot.top_modal()
		if modal != null:modal.rebuild())
	parent.add_child(all)
static func overview(parent: Node) -> void:
	master(parent)
	for id in TASKS:
		if available(str(id)):toggle(parent,id)
	bills_ui(parent)
static func available(id: String) -> bool:
	match id:
		"restock","packing","bills","returns":return true
		"cafe_supplies","hygiene":return Cafe.leased()
		"roster":return FeatureGate.unlocked("os_people")
		"tax":return FeatureGate.unlocked("app_tax_filing")
		"hotel_daily":return Hotel.is_running()
		"fleet_care":return Automotive.is_running()
		"charging_care":return Energy.is_running()
		"media_delivery":return Media.is_running()
		"month_close":return FeatureGate.unlocked("finance_details")
		"renewals":return FeatureGate.unlocked("os_governance")
		"maintenance":return not Assets.S()["items"].is_empty() or Logistics.has_van()
		"customs","fx":return FeatureGate.unlocked("overseas") or TradeIndustry.is_running()
	return false
## Owned entities whose bills the player can see and pay.
static func owners() -> Array:
	return ["player"] + CompanyPortfolio.ids()
## Records a real bill. Returns true when it was paid straight away; otherwise it waits (with a due date) as a payable.
static func bill(entity: String, category: String, amount: float, narrative: String, source: Dictionary) -> bool:
	if bool(S()["tasks"]["bills"]) and Ledger.cash(entity) >= amount:
		Ledger.expense(entity,category,amount,narrative,source)
		return true
	var bills: Array = S().get("bills",[])
	S()["bills"] = bills
	Ledger.post(entity,narrative,[{"acct":"exp:"+category,"dr":amount},{"acct":"accounts_payable","cr":amount}],source)
	var due := Clock.now()+int(cfg().get("bill_due_days",7))*Clock.DAY
	bills.append({"entity":entity,"amount":amount,"narrative":narrative,"source":source.duplicate(true),"paid":false,"due":due})
	if bool(S()["tasks"]["bills"]):_short_notice(entity)
	return false
## Exactly one notification while an entity's auto-paid bills wait for cash.
static func _short_notice(entity: String) -> void:
	var notices: Dictionary = S().get("bill_notices",{})
	S()["bill_notices"] = notices
	if notices.has(entity):return
	notices[entity] = true
	var who := I18n.t("Your personal account") if entity == "player" else GameState.entity_name(entity)
	GameState.add_message("assistant",I18n.t("%s does not have enough cash to pay a bill. It is waiting in Finance; add funds or pay it when you can.") % who,{"category":"work","target":{"kind":"company","tab":"finance"}})
static func unpaid(entity := "") -> Array:
	var result := []
	for index in S().get("bills",[]).size():
		var item: Dictionary = S()["bills"][index]
		if not item["paid"] and (entity == "" or item["entity"] == entity):result.append(index)
	return result
static func pay_bill(index: int) -> bool:
	var bills: Array = S().get("bills",[])
	if index < 0 or index >= bills.size():return false
	var item: Dictionary = bills[index]
	if item["paid"] or Ledger.cash(str(item["entity"])) < float(item["amount"]):return false
	Ledger.post(item["entity"],item["narrative"],[{"acct":"accounts_payable","dr":item["amount"]},{"acct":"cash","cr":item["amount"]}],{"type":"assistant_bill"})
	item["paid"] = true
	if S().get("bill_notices",{}).has(item["entity"]) and unpaid(str(item["entity"])).is_empty():S()["bill_notices"].erase(item["entity"])
	if item.get("source",{}).get("type","")=="rent":
		GameState.inc_stat("rent_paid")
		for entry in Living.D()["rent_history"]:
			if not entry.get("paid",true) and float(entry["amount"])==float(item["amount"]):
				entry["paid"] = true
				break
	return true
## Pays every bill the owning entity can afford, in order. Returns how many were paid.
static func pay_all() -> int:
	var paid := 0
	for index in unpaid():
		if pay_bill(index):paid += 1
	return paid
## Overdue bills collect one modest, flat late fee each (never compounding, never paid into a spiral).
static func overdue(t: int) -> void:
	var fee := float(cfg().get("bill_late_fee",10))
	var charged := 0
	for index in unpaid():
		var item: Dictionary = S()["bills"][index]
		if not item.has("due"):
			item["due"] = t+int(cfg().get("bill_due_days",7))*Clock.DAY
			continue
		if item.get("late",false) or t <= int(item["due"]):continue
		item["late"] = true
		var entity := str(item["entity"])
		if entity != "player" and not Tax.valid(entity):continue
		Ledger.expense(entity,"late_fees",fee,I18n.t("Late bill fee"),{"type":"fee"},"cash" if Ledger.cash(entity) >= fee else "accounts_payable")
		charged += 1
	if charged > 0:
		GameState.add_message("assistant",I18n.t("A bill is past its due date. A small late fee was added; pay it from Finance when you can."),{"category":"work","target":{"kind":"company","tab":"finance"}})
static func bills_ui(parent: Node) -> void:
	var bills: Array = S().get("bills",[])
	var owned := owners()
	var shown := []
	for index in bills.size():
		var item: Dictionary = bills[index]
		if not item["paid"] and item["entity"] in owned:shown.append(index)
	if shown.size() > 1:
		var total := 0.0
		for index in shown:total += float(bills[index]["amount"])
		var all := UIK.button(I18n.t("Pay all bills · %s") % Fmt.money(total),func():pay_all();UIRoot.top_modal().rebuild())
		all.name = "AssistantPayAll"
		all.disabled = shown.all(func(i):return Ledger.cash(str(bills[i]["entity"])) < float(bills[i]["amount"]))
		parent.add_child(all)
	for index in shown:
		var item: Dictionary = bills[index]
		var text := I18n.t("Pay bill · %s") % Fmt.money(float(item["amount"]))
		if item.has("due"):text += " · " + I18n.t("due %s") % Clock.fmt_short(int(item["due"]))
		if item["entity"] != "player":text += " · " + GameState.entity_name(str(item["entity"]))
		var button := UIK.button(text,func():pay_bill(index);UIRoot.top_modal().rebuild())
		button.name = "AssistantBill_"+str(index)
		button.disabled = Ledger.cash(str(item["entity"])) < float(item["amount"])
		button.tooltip_text = I18n.t(str(item["narrative"]))
		parent.add_child(button)
static func affordable(entity: String, cost: float) -> bool:
	# Keep a small buffer; optional chores cannot buy the company into an overdraft.
	var ready := cost >= 0 and is_finite(cost) and Ledger.cash(entity) >= cost+float(cfg()["cash_buffer"])
	if ready and S()["notices"].has(entity) and Ledger.cash(entity)>=float(S()["notices"][entity])+float(cfg()["cash_buffer"]):S()["notices"].erase(entity)
	elif not ready and entity == GameState.company_id() and entity != "" and not S()["notices"].has(entity):
		S()["notices"][entity] = cost
		GameState.add_message("assistant",I18n.t("Your assistant needs more cash for the next chore. Fund the company or handle it yourself."),{"category":"work","target":{"kind":"company","tab":"finance"}})
	return ready
static func on_hour(t: int, h: int) -> void:
	if _busy or not GameState.has_game() or (testing and not GameState.flag("test_assistant_run")):return
	_busy = true
	if enabled("bills"):
		for index in unpaid():pay_bill(index)
		# Still short of cash: one calm notice per entity, never an overdraft.
		for entity in owners():
			if not unpaid(str(entity)).is_empty():_short_notice(str(entity))
	if enabled("packing"):
		_fulfil()
		for contract in Contracts.C().values():
			if Contracts.can_deliver(str(contract["id"])):Contracts.deliver(str(contract["id"]))
		if Manufacturing.valid():
			for order in Manufacturing.S()["orders"].values():
				if order["status"] == "active" and int(order["produced"]) >= int(order["qty"]):Manufacturing.deliver(str(order["job"]))
	if h == int(cfg()["daily_hour"]):
		if enabled("restock"):_restock()
		if enabled("cafe_supplies") or enabled("roster") or enabled("hygiene"):_cafe(t)
		if enabled("maintenance") or enabled("fleet_care") or enabled("charging_care"):_maintain()
		if enabled("hotel_daily"):_hotel_daily()
		if enabled("restock") and Manufacturing.valid():
			var required := 0
			var counted := {}
			for slot in Manufacturing.S()["slots"]:
				if slot.get("status", "") != "scheduled":continue
				if counted.has(slot["job"]):continue
				counted[slot["job"]] = true
				var order: Dictionary = Manufacturing.S()["orders"].get(slot["job"],{})
				required += int(slot.get("brand_qty",int(order.get("qty",0))-int(order.get("produced",0))))
			for purchase in Manufacturing.S()["pos"].values():
				if purchase["status"] == "transit":required -= int(purchase["qty"])
			if required > Manufacturing.material_units():
				var amount := maxi(int(Manufacturing.cfg()["moq"]),required-Manufacturing.material_units())
				if affordable(Manufacturing.entity(),amount*Manufacturing.material_price()):Manufacturing.order_material(amount)
	if enabled("restock"):
		for contract in Contracts.C().values():
			if contract["status"] != "active" or contract["seller"] != GameState.company_id() or contract.get("type","") == "delivery_route":continue
			var plan := Contracts.restock_plan(contract)
			if plan.is_empty() or plan.has("error"):continue
			if affordable(str(contract["seller"]),float(plan["cost"])):Ecommerce.buy(str(plan["supplier"]),str(contract["product"]),int(plan["qty"]),str(plan["location"]))
	if enabled("roster") and Logistics.has_van():
		for person in Logistics.drivers_at(t):
			if Logistics.S()["assignments"].has(person["id"]):continue
			for vehicle in LogisticsDepth.vehicles():
				if LogisticsDepth.available(str(vehicle)) and vehicle not in Logistics.S()["assignments"].values():
					LogisticsDepth.assign(str(person["id"]),str(vehicle))
					break
	if enabled("customs") and TradeIndustry.valid():
		for deal in TradeIndustry.S()["deals"].values():
			if deal["status"] not in ["booked","in_transit","awaiting_bank","customs_hold"]:continue
			for key in deal["documents"]:
				if not deal["documents"][key]:TradeIndustry.set_document(str(deal["id"]),str(key),true)
			TradeIndustry.set_code(str(deal["id"]),str(TradeQuote.cfg()["goods"][deal["quote"]["product"]]["tariff_code"]))
			if deal["status"] == "customs_hold" and affordable(TradeIndustry.entity(),float(Customs.cfg().get("misclassification_fine",25))):TradeIndustry.clear(str(deal["id"]))
			if deal["lc"] == "issued":TradeIndustry.bank_documents(str(deal["id"]))
	if enabled("customs"):
		for order in Ecommerce.E()["orders"].values():
			if order["status"] != "customs_hold" or not GlobalMarket.live(str(order["entity"])):continue
			var cost := Customs.duty(order)+float(Customs.cfg().get("misclassification_fine",25))
			if affordable(str(order["entity"]),cost) and Customs.resolve(str(order["id"]),"documents").get("ok",false):Customs.remove_decisions(str(order["id"]))
	if enabled("tax"):
		var entities := ["player"]
		if GameState.company_id() != "":entities.append(GameState.company_id())
		for entity in entities:
			for filing in Tax.returns(str(entity)):
				if filing["status"] == "due" and affordable(str(entity),Tax.payable(filing)+float(Tax.cfg()["accountant_fee"])):
					Tax.file(str(entity),str(filing["id"]),"accountant",false)
	if enabled("media_delivery"):_media_deliveries()
	if enabled("fx") and GlobalMarket.live(GameState.company_id()):GlobalMarket.company()["auto_fx"] = true
	_busy = false
static func _restock() -> void:
	for listing in Ecommerce.E()["listings"].values():
		if not listing.get("active",false):continue
		var product: String = listing["product"]
		if Ecommerce.available_anywhere(product)+Ecommerce.incoming_units_of(product)>int(cfg()["restock_threshold"]):continue
		# A local supplier and one MOQ is reasonable, not the best possible price or forecast.
		for supplier in DataDB.suppliers:
			if DataDB.supplier(supplier).get("region","aurelia")!="aurelia":continue
			var offer := Ecommerce.offer(supplier,product)
			if offer.is_empty():continue
			var quantity := int(offer["moq"])
			if affordable(GameState.business_entity(),Ecommerce.unit_cost(supplier,product)*quantity):
				if Ecommerce.buy(supplier,product,quantity).get("ok",false):break
static func _fulfil() -> void:
	for loc in Ecommerce.stock_locations():
		var placed := Ecommerce.orders_with(["placed"],str(loc))
		for order in placed.slice(0,int(cfg()["packing_per_hour"])):
			var pack := Packing.auto_pack(order,int(cfg()["packing_skill"]))
			if pack.is_empty():continue
			if affordable(str(order["entity"]),Packing.material(order,str(pack["box"]),float(pack["padding"]))+Ecommerce.packaging_extra()):Ecommerce.pack_orders(str(loc),1,{},int(cfg()["packing_skill"]))
		var packed := Ecommerce.orders_with(["packed"],str(loc))
		if packed.is_empty():continue
		var cost := float(DataDB.shipping()["pickup"]["courier_fee_per_batch"])
		for order in packed:cost += Ecommerce.ship_cost(order,"economy")
		if affordable(str(packed[0]["entity"]),cost):Ecommerce.courier_pickup(str(loc),"economy")
static func _cafe(t: int) -> void:
	if not Cafe.is_running():return
	for property in Cafe.cfg()["locations"]:
		if not Living.has_lease(str(property)):continue
		Cafe.in_shop(str(property),func():
			if enabled("cafe_supplies"):
				if int(Cafe.S()["supplies"])+int(Cafe.S()["incoming"])<int(cfg()["coffee_target"]) and affordable(Cafe.entity(),Cafe.pack_cost("large")):Cafe.order_supplies("large")
				for pack in Cafe.cfg().get("material_packs",[]):
					var low := false
					for material in pack["materials"]:
						if int(Cafe.S()["materials"].get(material,0))+int(Cafe.S()["material_incoming"].get(material,0))<int(cfg()["ingredient_target"]):low=true
					if low and affordable(Cafe.entity(),float(pack["cost"])):CafeDepth.order(str(pack["id"]))
			if enabled("hygiene") and Cafe.ready_to_open():CafeDepth.clean(false)
			if enabled("hygiene") and Cafe.S()["inspection_pending"] and affordable(Cafe.entity(),float(Cafe.cfg()["inspection"]["fine"])):CafeDepth.inspect()
			if enabled("roster"):
				for person in Staff.S()["people"].values():
					if person.get("role","")!="barista" or not person.get("status","active") in ["active","employed"]:continue
					var roster := CafeDepth.roster()
					if not roster.has(person["id"]):roster[person["id"]]={}
					# Five reasonable opening days; no imaginary worker or full-week overtime.
					for weekday in cfg()["roster_weekdays"]:
						var day := int(weekday)
						for shift in ["early","late"]:
							var key: String = str(day)+":"+str(shift)
							if roster[person["id"]].get(key,"")=="":roster[person["id"]][key]=property
		)
static func _maintain() -> void:
	for item in Assets.S()["items"].values():
		if item.get("entity","")!=GameState.business_entity() or not (item.get("maintenance_due",false) or item.get("status","")=="broken"):continue
		if item.get("segment","") == "automotive" and Automotive.S()["fleet"].has(item["id"]):
			if not enabled("fleet_care"):continue
			# Servicing preserves the real car's return requirement and one-day downtime.
			if str(Automotive.S()["fleet"][item["id"]]["rental"]) == "" and affordable(str(item["entity"]),Automotive.service_cost(str(item["id"]))):Automotive.service(str(item["id"]))
			continue
		var charger := Energy.open_stations().any(func(site):return site.get("asset", "") == item["id"])
		if charger and not enabled("charging_care"):continue
		if not charger and not enabled("maintenance"):continue
		if affordable(str(item["entity"]),float(item.get("maintenance_cost",Assets.cfg().get("maintenance_cost",50)))):Assets.maintain(str(item["id"]))
	if enabled("maintenance") and Logistics.has_van():
		for id in LogisticsDepth.vehicles():
			var vehicle: Dictionary = LogisticsDepth.vehicles()[id]
			if float(vehicle["condition"])<float(cfg()["maintenance_condition"]) and LogisticsDepth.available(str(id)) and affordable(Logistics.entity(),float(LogisticsDepth.cfg()["service_cost"])):LogisticsDepth.service(str(id))

## First unhappy customer is a meaningful story decision; later identical forms can be delegated.
static func routine_event(inst: Dictionary) -> bool:
	if inst.get("id","") != "customer_return" or not enabled("returns"):return false
	var order: Dictionary = Ecommerce.E()["orders"].get(inst["ctx"].get("order",""),{})
	if order.is_empty() or not affordable(str(order["entity"]),Packing.total(order)+Ecommerce.ship_cost(order,"economy")):return false
	return EventEngine.choose(str(inst["iid"]),"refund").get("ok",false)

## Reference rates and existing paid housekeeping, never perfect demand prediction or a free worker.
static func _hotel_daily() -> void:
	if not Hotel.is_running():return
	var changed := false
	# Only rooms the player never priced; a deliberate price is never touched.
	for room in Hotel.S()["rooms"]:
		if bool(Hotel.S()["rooms"][room].get("player_set",false)):continue
		var reference := float(Hotel.cfg()["types"][room]["ref_price"])
		if not is_equal_approx(Hotel.rack_price(str(room)),reference) and Hotel.set_price(str(room),reference,false).get("ok",false):changed = true
	# Temporary cleaners are switched on only when turnover outruns the team and the cost is covered; never switched off.
	var cost := float(Hotel.cfg()["temp_capacity"])*float(Hotel.cfg()["temp_cost_room"])
	if not bool(Hotel.S()["temp"]) and Hotel.turnover_work() > Hotel.hk_capacity() and affordable(Hotel.entity(),cost):
		Hotel.set_temp(true)
		changed = true
	if changed:
		var day := Clock.day_index()
		if int(S().get("hotel_notice_day",-1)) != day:
			S()["hotel_notice_day"] = day
			GameState.add_message("assistant",I18n.t("Your assistant adjusted some hotel settings you had not chosen yourself."),{"category":"work","target":{"kind":"company","tab":"hotel"}})

## Only finish work that really exists and is complete. Campaign settlement keeps its native KPI pricing.
static func _media_deliveries() -> void:
	var campaigns: Dictionary = Media.S().get("campaigns",{})
	for job in Jobs.S()["items"].values():
		if job.get("segment", "") != "media" or job.get("entity", "") != GameState.business_entity():continue
		if campaigns.has(job["id"]) or job.get("direction", "") == "purchase":continue
		if job["status"] == "active" and float(job["progress"]) >= float(job["work"]):Jobs.deliver(str(job["id"]))
		if job["status"] == "delivered":Jobs.invoice(str(job["id"]))
