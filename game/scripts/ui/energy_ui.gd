class_name EnergyUI
extends Modal
## Energy console: roof leads, Roof Survey (panel grid), installs and warranty, City Hall subsidy desk, charging network map.
var page := "leads"
var selected := ""
var district := "riverside"
var has_primary := false

func _init() -> void:
	calm_profile = "energy"
	title_text = "Energy Console"
	help_key = "energy"
	icon_name = "sun"
	panel_size = Vector2(610, 345)

static func open(start_page := "leads") -> void:
	var m := EnergyUI.new()
	m.page = start_page
	UIRoot.open_modal(m)
static func render(owner: Node) -> void:
	owner.content.add_child(UIK.label_tip("Energy", "energy", 10))
	owner.content.add_child(UIK.wrap("Survey roofs, quote solar and storage, then build a charging network.", 8, Art.C_WHITE, 460))
	var go := UIK.button("Open Energy Console", open, "primary")
	go.name = "OpenEnergyConsole"
	owner.content.add_child(go)
static func board(det: Control, _board: Node) -> void:
	det.add_child(UIK.wrap("Lease the Helio warehouse office in Industrial, then survey real roofs and quote systems. Subsidies come from City Hall.", 8, Art.C_WHITE, 300))
	var go := UIK.button("Open Energy Console", open, "primary")
	go.name = "OpenEnergyConsole"
	det.add_child(go)

func act(callback: Callable) -> void:
	var result: Dictionary = callback.call()
	if not result.get("ok", false): EventBus.notify.emit(str(result.get("error", "")), "bad", "sun")
	elif result.has("accepted") and not result["accepted"]: EventBus.notify.emit(I18n.t("The client declined this quote. Improve payback or the price."), "info", "sun")
	elif result.has("signed") and not result["signed"]: EventBus.notify.emit(I18n.t("The landlord declined. Try again tomorrow."), "info", "sun")
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
func goto_page(next: String) -> Dictionary:
	switch(next)
	return {"ok":true}
func pick(id: String) -> Dictionary:
	selected = id
	page = "survey"
	reset_scroll = true
	return {"ok":true}
func note(content: Control, text: String, color := Art.C_WHITE) -> void: content.add_child(UIK.wrap(text, 8, color, 550))
func check(content: Control, ok: bool, text: String) -> void: note(content, ("✓ " if ok else "✗ ") + I18n.t(text), Art.C_WHITE if ok else Art.C_SKY)

func build() -> void:
	has_primary = false
	var nav := UIK.hbox(4)
	body.add_child(nav)
	for tab in [["leads", "Roof leads"], ["survey", "Roof Survey"], ["installs", "Installs & warranty"], ["subsidy", "Subsidy desk"], ["charging", "Charging network"]]:
		var choice := UIK.button(tab[1], switch.bind(tab[0]), "tab_active" if page == tab[0] else "tab")
		choice.name = "EnergyTab_" + tab[0]
		nav.add_child(choice)
	var content := UIK.vbox(4)
	body.add_child(UIK.scroll(content, Vector2(580, 270)))
	if not Energy.is_running():
		prerequisites(content)
		return
	content.add_child(UIK.label(I18n.t("%s · reputation %d%% · cash %s · weather %s · crew %.1f crew-days/day") % [Energy.stage_text(), roundi(float(Energy.S()["reputation"]) * 100), Fmt.money0(Ledger.cash(Energy.entity())), Energy.weather_text(), Energy.crew_capacity()], 8))
	match page:
		"leads": leads(content)
		"survey": survey(content)
		"installs": installs(content)
		"subsidy": subsidy(content)
		"charging": charging(content)

func prerequisites(content: Control) -> void:
	var rows := [[GameState.company_id() != "" and GameState.flag("business_account_opened"), "Register a company and open its bank account first."], [Living.has_lease(str(Energy.cfg()["warehouse"]["property"])), "Lease the Helio warehouse office in Industrial first."]]
	for row in rows: check(content, row[0], row[1])
	if rows.all(func(r): return r[0]):
		button(content, I18n.t("Open the solar business"), "OpenEnergy", Energy.start, true)
	else:
		var target := "civic_center" if GameState.company_id() == "" else "financial" if not GameState.flag("business_account_opened") else "industrial"
		button(content, I18n.t(DataDB.districts[target]["name"]), "RouteEnergyPrerequisite", func():
			close()
			var map := CityMapModal.new(false)
			map.sel = target
			UIRoot.open_modal(map)
			return {"ok":true}, true)

# ------------------------------------------------------------------ leads
func leads(content: Control) -> void:
	content.add_child(UIK.label_tip("Roof leads", "energy_roof", 9))
	var list: Array = Energy.open_leads()
	if list.is_empty(): note(content, "✗ No roof leads this week. New leads arrive every Monday.", Art.C_SKY)
	for lead in list:
		var spec: Dictionary = Energy.cfg()["roof_kinds"][lead["kind"]]
		var days := "" if lead["kind"] == "own" else I18n.t(" · %d days left") % maxi(0, ceili((int(lead["expires"]) - Clock.now()) / float(Clock.DAY)))
		note(content, I18n.t("%s · %s · %s · faces %s · %d×%d cells · load limit %d kg · uses %s kWh/year%s") % [I18n.t(lead["client"]), I18n.t(spec["label"]), I18n.t(DataDB.districts[lead["district"]]["name"]), _facing(lead["roof"]["orientation"]), int(lead["roof"]["w"]), int(lead["roof"]["h"]), int(lead["roof"]["load_kg"]), "-" if lead["kind"] == "own" else Fmt.money0(lead["kwh_year"]).substr(1), days])
		button(content, I18n.t("Survey this roof"), "Survey_" + lead["id"], pick.bind(lead["id"]), true)
	if not Energy.S()["arrays"].is_empty():
		for arr in Energy.S()["arrays"].values():
			note(content, I18n.t("Own array %s: %.1f kW · %d kWh sold · %s earned") % [I18n.t(arr["client"]), float(arr["kw"]), roundi(arr["kwh"]), Fmt.money0(arr["revenue"])], Art.C_SKY)

# ------------------------------------------------------------------ Roof Survey
func survey(content: Control) -> void:
	var lead: Dictionary = Energy.S()["leads"].get(selected, {})
	if lead.is_empty() or lead["status"] != "open":
		note(content, "✗ Choose a roof lead to survey first.", Art.C_SKY)
		button(content, I18n.t("Roof leads"), "SurveyNeedsLead", goto_page.bind("leads"), true)
		return
	var roof: Dictionary = lead["roof"]
	content.add_child(UIK.label_tip(I18n.t("Roof Survey: %s") % I18n.t(lead["client"]), "energy_roof", 9))
	note(content, I18n.t("Roof faces %s (%d%% of south-facing yield) · load limit %d kg = %d panels max · each cell shows the sun it keeps after building and tree shade.") % [_facing(roof["orientation"]), roundi(float(Energy.cfg()["orientation_factor"][roof["orientation"]]) * 100), int(roof["load_kg"]), Energy.max_panels(roof)], Art.C_SKY)
	var grid := GridContainer.new()
	grid.columns = int(roof["w"])
	content.add_child(grid)
	var occupied := {}
	for c in lead["layout"]: occupied[Vector2i(int(c[0]), int(c[1]))] = true
	for y in int(roof["h"]):
		for x in int(roof["w"]):
			var kept := roundi((1.0 - float(roof["shade"][y][x])) * 100)
			var cell := UIK.button(("■ " if occupied.has(Vector2i(x, y)) else "") + "%d%%" % kept, act.bind(Energy.toggle_cell.bind(lead["id"], x, y)), "tab_active" if occupied.has(Vector2i(x, y)) else "button")
			cell.name = "Cell_%d_%d" % [x, y]
			cell.custom_minimum_size = Vector2(54, 24)
			grid.add_child(cell)
	var row := UIK.hbox(4)
	content.add_child(row)
	button(row, I18n.t("Place best panels"), "AutoLayout", Energy.auto_layout.bind(lead["id"]))
	if lead["kind"] != "own":
		for size in Energy.cfg()["battery_sizes"]:
			if float(size) > 0 and not bool(Energy.S()["storage_cert"]): continue
			button(row, (I18n.t("No battery") if float(size) == 0 else I18n.t("Battery %d kWh") % int(size)), "Battery_%d" % int(size), Energy.set_options.bind(lead["id"], float(size), float(lead["margin"]), bool(lead["subsidy"])))
		var margins := UIK.hbox(4)
		content.add_child(margins)
		for i in Energy.cfg()["margins"].size():
			var margin := float(Energy.cfg()["margins"][i])
			button(margins, I18n.t("Margin %d%%") % roundi(margin * 100), "Margin_%d" % i, Energy.set_options.bind(lead["id"], float(lead["battery"]), margin, bool(lead["subsidy"])))
		button(margins, I18n.t("Subsidy requested: yes") if lead["subsidy"] else I18n.t("Subsidy requested: no"), "ToggleSubsidy", Energy.set_options.bind(lead["id"], float(lead["battery"]), float(lead["margin"]), not bool(lead["subsidy"])))
	var ev := Energy.lead_eval(lead["id"])
	if not ev["ok"]:
		note(content, "✗ Place at least one panel on the roof.", Art.C_SKY)
		return
	note(content, I18n.t("%d panels · %.1f kW · %s kWh/year · average shading loss %d%% · load %d of %d kg") % [int(ev["panels"]), float(ev["kw"]), str(roundi(ev["annual_kwh"])), roundi(float(ev["shade_loss"]) * 100), roundi(ev["load_used"]), roundi(ev["load_cap"])])
	if lead["kind"] == "own":
		note(content, I18n.t("Grid export pays %s/kWh: about %s/year; payback %.1f years. Materials %s.") % [Fmt.money(Energy.cfg()["tariff"]["feed_in_price"]), Fmt.money0(ev["saving_year"]), float(ev["payback"]), Fmt.money0(ev["materials"])])
		button(content, I18n.t("Build on your own roof · %s") % Fmt.money0(ev["materials"]), "SendQuote", Energy.quote.bind(lead["id"]), true)
		return
	note(content, I18n.t("Client saves %s/year (solar %s, battery %s) · payback %.1f years · client acceptance %d%%") % [Fmt.money0(ev["saving_year"]), Fmt.money0(ev["solar_saving"]), Fmt.money0(ev["battery_saving"]), float(ev["payback_net"]), roundi(float(ev["accept"]) * 100)], Art.C_SKY)
	var sub_text := ""
	if lead["subsidy"]:
		sub_text = I18n.t(" · with subsidy %s pending a %d-day City Hall decision, client pays %s") % [Fmt.money0(ev["grant"]), int(Energy.cfg()["subsidy"]["decision_days"]), Fmt.money0(ev["price_net"])]
	note(content, I18n.t("Price %s without subsidy · materials %s · margin %d%% · %.1f crew-days (about %d days)%s") % [Fmt.money0(ev["price"]), Fmt.money0(ev["materials"]), roundi(float(ev["gross_margin"]) * 100), float(ev["work_days"]), Energy.duration_days(float(ev["work_days"])), sub_text])
	button(content, I18n.t("Send quote · %s") % Fmt.money0(ev["price_net"]), "SendQuote", Energy.quote.bind(lead["id"]), true)

# ------------------------------------------------------------------ installs and warranty
func installs(content: Control) -> void:
	content.add_child(UIK.label_tip("Installs", "energy_warranty", 9))
	var any := false
	for inst in Energy.S()["installs"].values():
		if inst["status"] == "cancelled": continue
		any = true
		var job := Jobs.get_job(inst["id"])
		var status_text := I18n.t("Ready to order materials") if inst["status"] == "contracted" else I18n.t("Installing") if inst["status"] == "installing" else I18n.t("Delivered")
		if inst["subsidy"] == "pending": status_text = I18n.t("Waiting for subsidy decision")
		var line := I18n.t("%s · %.1f kW · %s · crew-days %.1f of %.1f") % [I18n.t(inst["client"]), float(inst["kw"]), status_text, float(inst["done"]), float(inst["work"])]
		if not job.is_empty() and inst["status"] != "delivered":
			var left := ceili((int(job["due"]) - Clock.now()) / float(Clock.DAY))
			line += I18n.t(" · due in %d days") % left if left >= 0 else I18n.t(" · %d days late") % -left
		note(content, line)
		if inst["status"] == "contracted":
			button(content, I18n.t("Order materials and start · %s") % Fmt.money0(inst["materials"]), "StartInstall_" + inst["id"], Energy.start_install.bind(inst["id"]), inst["subsidy"] != "pending")
		elif inst["status"] == "delivered" and job.get("status", "") != "":
			note(content, I18n.t("Invoice %s · %s · warranty to %s") % [Fmt.money0(job["price"]), I18n.t(str(CompanyOS.STATUS_TEXT.get(job["status"], str(job["status"]).capitalize()))), Clock.fmt_date(int(inst["warranty_until"]))], Art.C_SKY)
	if not any: note(content, "✗ No installs yet. Survey a roof and send a quote.", Art.C_SKY)
	for claim in Energy.claims_open():
		note(content, I18n.t("Warranty claim from %s: %s, repair cost %s, decide within %d days") % [I18n.t(claim["client"]), I18n.t(claim["reason"]), Fmt.money0(claim["cost"]), maxi(0, ceili((int(claim["due"]) - Clock.now()) / float(Clock.DAY)))], Art.C_GOLD)
		var row := UIK.hbox(4)
		content.add_child(row)
		button(row, I18n.t("Repair under warranty · %s") % Fmt.money0(claim["cost"]), "ClaimRepair_" + claim["id"], Energy.resolve_claim.bind(claim["id"], true), true)
		button(row, I18n.t("Dispute the claim"), "ClaimDispute_" + claim["id"], Energy.resolve_claim.bind(claim["id"], false))
	note(content, I18n.t("Warranty exposure: about %s a year in expected repairs on installed systems.") % Fmt.money0(Energy.warranty_exposure()), Art.C_MUTED)
	button(content, I18n.t("Recruit electrician · %s a week") % Fmt.money0(Staff.role_def("electrician").get("salary_week", [1050])[0]), "Recruit_electrician", recruit)
	if not bool(Energy.S()["storage_cert"]):
		var fee := float(Energy.cfg()["materials"]["storage_cert_fee"])
		var done := int(Energy.S()["completed"])
		var need := int(Energy.cfg()["storage_min_completed"])
		check(content, done >= need, "Complete two solar installs before the battery course.")
		button(content, I18n.t("Take the battery course · %s") % Fmt.money0(fee), "CertifyStorage", Energy.certify_storage, done >= need and not any_ready())
func recruit() -> Dictionary:
	if not Staff.employer_registered():
		close()
		var map := CityMapModal.new(false)
		map.sel = "civic_center"
		UIRoot.open_modal(map)
		return {"ok":true}
	var result := Staff.post_job("electrician")
	if result.get("ok", false):
		close()
		var os := CompanyOS.new("home_laptop")
		os.tab = "people"
		UIRoot.open_modal(os)
	return result
func any_ready() -> bool: return not Energy.installs_in("contracted").is_empty() or not Energy.claims_open().is_empty()

# ------------------------------------------------------------------ subsidy desk
func subsidy(content: Control) -> void:
	content.add_child(UIK.label_tip("City Hall energy subsidy desk (Ms. Okoro)", "energy_subsidy", 9))
	var s: Dictionary = Energy.cfg()["subsidy"]
	var why := Energy.subsidy_block("install")
	check(content, int(Clock.date()["month"]) <= int(s["season_last_month"]), "Applications are open this year.")
	check(content, Energy.quota_left("install") > 0, "Install grant quota remains.")
	note(content, I18n.t("Install grants: %d%% of the quote up to %s per system. Quota left %s of %s. Charger grants: %d%% up to %s, quota left %s. Filing fee %s, decision in about %d days; some applications are rejected.") % [roundi(float(s["rate"]) * Energy.mod("subsidy") * 100), Fmt.money0(s["cap"]), Fmt.money0(Energy.quota_left("install")), Fmt.money0(Energy.quota_total("install")), roundi(float(s["charger_rate"]) * Energy.mod("subsidy") * 100), Fmt.money0(s["charger_cap"]), Fmt.money0(Energy.quota_left("charger")), Fmt.money0(s["fee"]), int(s["decision_days"])])
	if Energy.mod("subsidy") < 1.0: note(content, "✗ A policy cut is reducing grants; the rate recovers over time.", Art.C_SKY)
	for inst in Energy.S()["installs"].values():
		if inst["status"] in ["contracted", "installing"] and inst["subsidy"] == "none" and inst["kind"] != "own":
			button(content, I18n.t("Apply for %s · fee %s") % [I18n.t(inst["client"]), Fmt.money0(s["fee"])], "ApplySubsidy_" + inst["id"], Energy.apply_subsidy.bind("install", inst["id"]), why == "")
	for app in Energy.applications():
		var text: String = {"pending":I18n.t("pending"), "approved":I18n.t("approved"), "rejected":I18n.t("rejected"), "paid":I18n.t("paid"), "cancelled":I18n.t("cancelled")}.get(app["status"], str(app["status"]))
		note(content, ("✓ " if app["status"] in ["approved", "paid"] else "✗ " if app["status"] == "rejected" else "") + I18n.t("%s: grant %s, %s") % [str(app["ref"]), Fmt.money0(app["grant"]), text])
	if why != "": note(content, "✗ " + I18n.t(why), Art.C_SKY)
	if not has_primary:
		button(content, I18n.t("Roof leads"), "SubsidyNextLeads", goto_page.bind("leads"), true)

# ------------------------------------------------------------------ charging network
func charging(content: Control) -> void:
	content.add_child(UIK.label_tip("Charging network", "energy_charging", 9))
	var ev: Dictionary = Energy.cfg()["ev"]
	note(content, I18n.t("City EV adoption %s (+%s a year) · %d of %d stations open · grid electricity %s/kWh") % [Fmt.pct(Energy.adoption(), 1), Fmt.pct(ev["adoption_growth_year"], 1), Energy.open_stations().size(), int(Energy.cfg()["charging"]["network_stage"]), Fmt.money(Energy.grid_cost())], Art.C_SKY)
	if Energy.stage() < int(Energy.cfg()["charging"]["min_stage"]):
		check(content, bool(Energy.S()["storage_cert"]), "Take the battery course first.")
		check(content, int(Energy.S()["completed"]) >= int(Energy.cfg()["storage_min_completed"]), "Complete two solar installs before the battery course.")
		button(content, I18n.t("Installs & warranty"), "ChargingNextInstalls", goto_page.bind("installs"), true)
		return
	var map := Control.new()
	map.custom_minimum_size = Vector2(560, 150)
	content.add_child(map)
	for id in DataDB.districts:
		if Energy.spots_in(id).is_empty(): continue
		var def: Dictionary = DataDB.district_def_in_city(id)
		var pos: Array = def.get("map_pos", [0, 0])
		var b := UIK.button("%s %d/%d" % [I18n.t(DataDB.districts[id]["name"]), Energy.free_spots(id), Energy.spots_in(id).size()], act.bind(func():
			district = id
			return {"ok":true}), "tab_active" if id == district else "tab")
		b.name = "District_" + id
		b.position = Vector2((float(pos[0]) - 30.0) * 0.92, (float(pos[1]) - 50.0) * 0.5)
		map.add_child(b)
	note(content, "Pick a district on the map. Free spots are limited; landlords want a fee or a share, your own property needs none.", Art.C_MUTED)
	for spot in Energy.spots_in(district):
		spot_row(content, spot)
func spot_row(content: Control, spot: Dictionary) -> void:
	var id: String = spot["id"]
	var site := Energy.site_of(id)
	var owned := Energy.owned_deal(spot)
	if not site.is_empty() and site["status"] in ["building", "open"]:
		var item: Dictionary = Assets.S()["items"].get(str(site["asset"]), {})
		var state := I18n.t("building until %s") % Clock.fmt_date(int(site["due"])) if site["status"] == "building" else I18n.t("open") if Energy.station_ok(site) else I18n.t("out of service")
		note(content, I18n.t("%s · %s · %s · %d ports · price %s/kWh · demand about %d kWh/day · margin %s/kWh · %d kWh sold, %s revenue") % [I18n.t(spot["label"]), I18n.t(Energy.cfg()["charging"]["types"][site["type"]]["name"]), state, int(site["ports"]), Fmt.money(site["price"]), roundi(Energy.demand_kwh(site)), Fmt.money(Energy.margin_per_kwh(site)), roundi(site["kwh"]), Fmt.money0(site["revenue"])])
		if site["status"] == "open":
			var row := UIK.hbox(4)
			content.add_child(row)
			var c: Dictionary = Energy.cfg()["charging"]
			button(row, I18n.t("Price −%s") % Fmt.money(c["price_step"]), "PriceDown_" + id, Energy.set_price.bind(id, float(site["price"]) - float(c["price_step"])))
			button(row, I18n.t("Price +%s") % Fmt.money(c["price_step"]), "PriceUp_" + id, Energy.set_price.bind(id, float(site["price"]) + float(c["price_step"])))
			if item.get("status", "") != "working" or item.get("maintenance_due", false): button(row, I18n.t("Repair and service · %s") % Fmt.money0(item.get("maintenance_cost", 0)), "Maintain_" + id, Energy.maintain_station.bind(id), true)
		return
	var deal: Dictionary = Energy.S()["deals"].get(id, {})
	if deal.is_empty() or (deal["kind"] == "owned" and not owned):
		note(content, I18n.t("%s · %s") % [I18n.t(spot["label"]), I18n.t("your own property, no landlord fee") if owned else I18n.t("landlord wants %s/month or %d%% of revenue") % [Fmt.money0(spot["fee"]), roundi(float(Energy.cfg()["charging"]["share"]) * 100)]])
		if owned: button(content, I18n.t("Use your own property"), "Deal_" + id, Energy.site_deal.bind(id, "owned"), true)
		else:
			var row := UIK.hbox(4)
			content.add_child(row)
			button(row, I18n.t("Negotiate fixed fee"), "DealFee_" + id, Energy.site_deal.bind(id, "fee"), true)
			button(row, I18n.t("Negotiate revenue share"), "DealShare_" + id, Energy.site_deal.bind(id, "share"))
		return
	note(content, I18n.t("%s · terms agreed: %s") % [I18n.t(spot["label"]), I18n.t("own property") if deal["kind"] == "owned" else I18n.t("fixed fee %s/month") % Fmt.money0(deal["fee"]) if deal["kind"] == "fee" else I18n.t("%d%% revenue share") % roundi(float(deal["share"]) * 100)], Art.C_SKY)
	var build_row := UIK.hbox(4)
	content.add_child(build_row)
	var can_grant := Energy.subsidy_block("charger") == ""
	for type in Energy.cfg()["charging"]["types"]:
		var t: Dictionary = Energy.cfg()["charging"]["types"][type]
		var cost := Energy.station_cost(type)
		button(build_row, I18n.t("Build %s · %s") % [I18n.t(t["name"]), Fmt.money0(cost)], "Build_%s_%s" % [id, type], Energy.build_station.bind(id, type, false, false), type == "l2")
		if can_grant: button(build_row, I18n.t("with grant request"), "BuildGrant_%s_%s" % [id, type], Energy.build_station.bind(id, type, true, false))
		button(build_row, I18n.t("with bank loan"), "BuildLoan_%s_%s" % [id, type], Energy.build_station.bind(id, type, false, true))


## Compass points read in the player's language ("SW" → "Southwest").
static func _facing(code: String) -> String:
	var names := {"N": "North", "NE": "Northeast", "E": "East", "SE": "Southeast", "S": "South", "SW": "Southwest", "W": "West", "NW": "Northwest"}
	return I18n.t(names.get(code, code))
