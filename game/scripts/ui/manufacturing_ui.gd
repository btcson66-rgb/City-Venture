class_name ManufacturingUI
extends Modal
## Scheduling and inspection are separate decisions; all controls retain stable bot names.
var page := "orders"
var selected_job := ""
var machine_index := 0
var days_ahead := 1
var hour := 9
var hours := 8
var overtime := false
var outsource := false
var quotes := {}
var material_qty := 1000
var has_primary := false

func _init() -> void:
	title_text = "Line Planner"
	icon_name = "company"
	panel_size = Vector2(600, 340)
	help_key = "manufacturing"

static func open() -> void: UIRoot.open_modal(ManufacturingUI.new())
static func display_id(id: String) -> String:
	return (I18n.t("Machine")+" "+id.get_slice("-", 1)) if id.begins_with("ASSET-") else (I18n.t("Order")+" "+id.get_slice("-", 1)) if id.begins_with("JOB-") else id
static func render(owner: Node) -> void:
	owner.content.add_child(UIK.label_tip("Manufacturing", "manufacturing", 10))
	owner.content.add_child(UIK.wrap("Quote OEM orders, buy raw materials, schedule machines and inspect each batch.", 8, Art.C_WHITE, 460))
	var go := UIK.button("Open Line Planner", open, "primary")
	go.name = "OpenLinePlanner"
	owner.content.add_child(go)
static func board(det: Control, _board: Node) -> void:
	det.add_child(UIK.wrap("Lease Unit 12 in Industrial. Rent a machine, register as an employer and hire Tomas. OEM clients pay deposits and settle invoices on Net 30 terms.", 8, Art.C_WHITE, 300))
	det.add_child(UIK.tip("net_terms"))
	var go := UIK.button("Open Line Planner", open, "primary")
	go.name = "OpenLinePlanner"
	det.add_child(go)

func act(callback: Callable) -> void:
	var result: Dictionary = callback.call()
	if not result.get("ok", false): EventBus.notify.emit(str(result.get("error", "")), "bad", "company")
	rebuild()
func button(parent: Control, label: String, id: String, callback: Callable, primary := false) -> Button:
	var main := primary and not has_primary
	if main: has_primary = true
	var b := UIK.button(label, act.bind(callback), "primary" if main else "button")
	b.name = id
	parent.add_child(b)
	return b
func switch(next: String) -> void:
	page = next
	reset_scroll = true
	rebuild()
func _default_quote(id: String) -> float:
	var rfq: Dictionary = Manufacturing.S()["rfqs"].get(id, {})
	return snappedf((float(rfq.get("min_price", Manufacturing.cfg()["quote_min"]))+float(rfq.get("max_price", Manufacturing.cfg()["quote_max"])))/2.0, 0.01)
func change_quote(id: String, amount: float) -> Dictionary:
	quotes[id] = snappedf(maxf(0.1, float(quotes.get(id, _default_quote(id)))+amount), 0.01)
	return {"ok":true}
func change_slot(key: String, delta: int) -> Dictionary:
	match key:
		"day": days_ahead = clampi(days_ahead+delta, 0, 6)
		"hour": hour = clampi(hour+delta, 0, 23)
		"hours": hours = clampi(hours+delta, 1, 16)
	return {"ok":true}
func toggle(key: String) -> Dictionary:
	if key == "overtime": overtime = not overtime
	else: outsource = not outsource
	return {"ok":true}
func build() -> void:
	has_primary = false
	var tabs := UIK.hbox(6)
	body.add_child(tabs)
	for entry in [["orders", "OEM orders"], ["planner", "Line Planner"], ["quality", "Quality results"]]:
		var b := UIK.button(entry[1], switch.bind(entry[0]), "tab_active" if page == entry[0] else "tab")
		b.name = "FactoryTab_"+entry[0]
		tabs.add_child(b)
	var content := UIK.vbox(4)
	body.add_child(UIK.scroll(content, Vector2(570, 264)))
	if not Manufacturing.is_running():
		var why := Manufacturing.setup_block()
		content.add_child(UIK.wrap("Quote OEM orders, buy raw materials, schedule machines and inspect each batch.", 8, Art.C_WHITE, 540))
		if why != "": content.add_child(UIK.wrap("✗ "+I18n.t(why), 9, Art.C_SKY, 540))
		else: button(content, "Open the factory", "OpenFactory", Manufacturing.start, true)
		return
	content.add_child(UIK.label(I18n.t("Factory cash: %s · materials: %d units") % [Fmt.money(Ledger.cash(Manufacturing.entity())), Manufacturing.material_units()], 8))
	if page == "orders": orders(content)
	elif page == "planner": planner(content)
	else: quality(content)

func orders(content: Control) -> void:
	if Manufacturing.S()["machines"].is_empty():
		button(content, "Rent machine · $1,400/month", "RentMachine", Manufacturing.acquire_machine.bind(true, false), true)
		button(content, "Buy machine · $28,000", "BuyMachine", Manufacturing.acquire_machine.bind(false, false))
	if not Staff.employer_registered(): button(content, "Register as an employer", "FactoryEmployer", Staff.register_employer, true)
	elif Staff.count("technician") == 0: button(content, "Hire Tomas · $1,100/week", "HireTomas", Manufacturing.hire_tomas, true)
	for asset_id in Manufacturing.S()["machines"]:
		var asset: Dictionary = Assets.S()["items"][asset_id]
		content.add_child(UIK.label(I18n.t("Machine %s · %d units/hour") % [asset_id.get_slice("-", 1), int(asset["capacity"])], 8))
		if asset["status"] == "broken" or asset.get("maintenance_due", false): button(content, "Service machine", "Service_"+asset_id, Assets.maintain.bind(asset_id), true)
	var row := UIK.hbox(4)
	content.add_child(row)
	button(row, "−100 units", "MaterialLess", func(): material_qty = maxi(int(Manufacturing.cfg()["moq"]), material_qty-100); return {"ok":true})
	row.add_child(UIK.label(I18n.t("%d units · %s/unit") % [material_qty, Fmt.money(Manufacturing.material_price())], 8))
	button(row, "+100 units", "MaterialMore", func(): material_qty = mini(int(Manufacturing.cfg()["material_capacity"]), material_qty+100); return {"ok":true})
	button(content, "Order Ferro materials", "BuyMaterials", Manufacturing.order_material.bind(material_qty), Manufacturing.material_units() == 0)
	for po in Manufacturing.S()["pos"].values():
		if po["status"] == "transit": content.add_child(UIK.label(I18n.t("%d units arrive in %d days") % [int(po["qty"]), ceili((int(po["due"])-Clock.now())/float(Clock.DAY))], 8, Art.C_MUTED))
	content.add_child(UIK.label_tip("OEM orders", "manufacturing_rfq", 9))
	for rfq in Manufacturing.S()["rfqs"].values():
		if rfq["status"] != "open" or int(rfq["due"]) <= Clock.now(): continue
		content.add_child(UIK.wrap(I18n.t("%s · %d units · %s–%s/unit · due in %d days · defects ≤%.1f%%") % [I18n.t(rfq["client"]), int(rfq["qty"]), Fmt.money(rfq["min_price"]), Fmt.money(rfq["max_price"]), ceili((int(rfq["due"])-Clock.now())/float(Clock.DAY)), float(rfq["max_defect"])*100], 8, Art.C_WHITE, 540))
		if not rfq.get("competitors", []).is_empty():
			content.add_child(UIK.wrap(Rivals.competing_text(rfq["competitors"]), 8, Art.C_SKY, 540))
		var price := float(quotes.get(rfq["id"], _default_quote(rfq["id"])))
		var quote_row := UIK.hbox(4)
		content.add_child(quote_row)
		button(quote_row, "−$0.25", "QuoteLess_"+rfq["id"], change_quote.bind(rfq["id"], -0.25))
		quote_row.add_child(UIK.label(I18n.t("%s per unit") % Fmt.money(price) + " · " + I18n.t("about %d%% chance to win") % roundi(Rivals.bid_chance(Manufacturing.win_chance(rfq, price), rfq.get("competitors", []))*100), 8))
		button(quote_row, "+$0.25", "QuoteMore_"+rfq["id"], change_quote.bind(rfq["id"], 0.25))
		button(quote_row, "Send quote", "Quote_"+rfq["id"], Manufacturing.quote.bind(rfq["id"], price), not Manufacturing.S()["machines"].is_empty() and Staff.count("technician") > 0 and not Manufacturing.S()["orders"].values().any(func(o): return o["status"] == "active"))
	for order in Manufacturing.S()["orders"].values():
		if order["status"] != "active": continue
		content.add_child(UIK.label(I18n.t("%s · %d/%d units complete") % [display_id(order["job"]), int(order["produced"]), int(order["qty"])], 8))
		if int(order["produced"]) >= int(order["qty"]): button(content, "Deliver and invoice", "Deliver_"+order["job"], Manufacturing.deliver.bind(order["job"]), true)
		else:
			var main := not has_primary
			if main: has_primary = true
			var b := UIK.button("Schedule this order", func(): selected_job = order["job"]; switch("planner"), "primary" if main else "button")
			b.name = "Select_"+order["job"]
			content.add_child(b)
	if int(Manufacturing.S()["stage"]) < 2: button(content, "Install CNC · business loan required", "FactoryAutomation", Manufacturing.acquire_machine.bind(false, true))
	elif int(Manufacturing.S()["stage"]) < 3: button(content, "Pay own-brand mould fee", "FactoryBrand", Manufacturing.own_brand)
	else: button(content, "Produce 100 own-brand units", "FactoryBrandBatch", Manufacturing.brand_batch.bind(100))

func planner(content: Control) -> void:
	content.add_child(UIK.label_tip("Machine schedule", "manufacturing_schedule", 9))
	var machines: Array = Manufacturing.S()["machines"]
	if machines.is_empty():
		content.add_child(UIK.wrap("✗ Rent a machine in OEM orders first.", 9, Art.C_SKY, 540))
		return
	if selected_job == "" or Manufacturing.S()["orders"].get(selected_job, {}).get("status", "") != "active":
		content.add_child(UIK.wrap("✗ Choose an order in OEM orders first.", 9, Art.C_SKY, 540))
		return
	machine_index = mini(machine_index, machines.size()-1)
	var machine := str(machines[machine_index])
	content.add_child(UIK.label(I18n.t("Order %s · machine %s") % [selected_job.get_slice("-", 1), machine.get_slice("-", 1)], 9))
	button(content, "Next machine", "NextMachine", func(): machine_index = (machine_index+1)%machines.size(); return {"ok":true})
	for entry in [["day", days_ahead, "Start in %d days"], ["hour", hour, "Start at %02d:00"], ["hours", hours, "Run for %d hours"]]:
		var row := UIK.hbox(5)
		content.add_child(row)
		button(row, "−", "Less_"+entry[0], change_slot.bind(entry[0], -1))
		row.add_child(UIK.label(I18n.t(entry[2]) % int(entry[1]), 9))
		button(row, "+", "More_"+entry[0], change_slot.bind(entry[0], 1))
	button(content, ("✓ " if overtime else "✗ ")+I18n.t("Overtime · wage ×1.5, yield −2%"), "FactoryOvertime", toggle.bind("overtime"))
	button(content, ("✓ " if outsource else "✗ ")+I18n.t("Outsource to Kessler · higher unit cost"), "FactoryOutsource", toggle.bind("outsource"))
	button(content, "Reserve production slot", "ReserveSlot", Manufacturing.plan.bind(selected_job, machine, Clock.at_day_time(days_ahead, hour*60), hours, overtime, outsource), true)
	for slot in Manufacturing.S()["slots"]:
		if slot["status"] == "cancelled": continue
		content.add_child(UIK.wrap(I18n.t("%s · %s · %d hours · %s") % [display_id(slot["job"]), display_id(slot["machine"]), (int(slot["end"])-int(slot["start"]))/60, I18n.t("Completed") if slot["status"] == "completed" else I18n.t("Scheduled")], 8, Art.C_MUTED, 540))

func quality(content: Control) -> void:
	var next := UIK.button("Review OEM orders", switch.bind("orders"), "primary")
	next.name = "QualityNextOrders"
	content.add_child(next)
	content.add_child(UIK.label_tip("Sampling inspection", "manufacturing_quality", 9))
	content.add_child(UIK.wrap("More inspection slows the line. Inspected defects cost rework; escaped defects cause refunds, penalties and lower credit.", 8, Art.C_WHITE, 540))
	var row := UIK.hbox(5)
	content.add_child(row)
	for ratio in [0.0, 0.25, 0.5, 0.75, 1.0]: button(row, ("✓ " if is_equal_approx(float(Manufacturing.S()["inspection"]), ratio) else "")+"%d%%" % int(ratio*100), "Inspection_%d" % int(ratio*100), Manufacturing.set_inspection.bind(ratio))
	content.add_child(UIK.label(I18n.t("Sampling: %.0f%% · credit: %d points") % [float(Manufacturing.S()["inspection"])*100, Bank.credit()], 9))
	var rows: Array = Manufacturing.S()["quality"].duplicate()
	rows.reverse()
	for batch in rows.slice(0, 15): content.add_child(UIK.wrap(I18n.t("%s · %d units · defects %.1f%% · sampled %.0f%% · escaped %.1f units") % [display_id(batch["job"]), int(batch["qty"]), float(batch["defect"])*100, float(batch["sample"])*100, float(batch["escaped"])], 8, Art.C_WHITE, 540))
