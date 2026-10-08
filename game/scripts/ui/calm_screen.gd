class_name CalmScreen
extends RefCounted
## Opt-in disclosure for #164. Original controls and callbacks survive inside a named detail area.
## It never selects a deal, changes a price, posts money or supplies an answer on the player's behalf.
static var _profiles := {}
static func profiles() -> Dictionary:
	if _profiles.is_empty(): _profiles = DataDB._read("res://data/help/calm_screens.json")
	return _profiles

static func apply_modal(owner: Modal) -> void:
	if owner.calm_profile != "":apply(owner, owner.body, owner.calm_profile)
	var industry := owner.industry_intro if owner.industry_intro != "" else str(profiles().get(owner.calm_profile, {}).get("industry", ""))
	if industry != "":
		var id := "industry_" + industry
		if id not in FeatureGate.state()["guided"]:
			FeatureIntroModal.show_in.call_deferred(owner, id)
		if owner.header.find_child("IndustryGuideReplay", true, false) == null:
			var replay := UIK.button("?", func(): FeatureIntroModal.show_in(owner, id))
			replay.name = "IndustryGuideReplay"
			replay.tooltip_text = I18n.t("First-use guide")
			replay.custom_minimum_size = Vector2(24, 24)
			owner.header.add_child(replay)

static func apply(owner: Modal, column: Control, id: String) -> void:
	if not profiles().has(id): return
	var profile: Dictionary = profiles()[id]
	var key := id
	for property in owner.get_property_list():
		if property["name"] in ["page", "tab"]: key += ":" + str(owner.get(property["name"]))
	var originals := column.get_children()
	var details := UIK.vbox(4)
	details.name = "CalmDetails"
	var primary: Button
	for button in column.find_children("*", "Button", true, false):
		if not button.disabled and button.get_meta("primary_action", false) and primary == null:
			primary = button
		elif button.get_meta("primary_action", false):
			_demote(button)
	if column == owner.body:
		for button in owner.footer.find_children("*", "Button", true, false):
			if not button.disabled and button.get_meta("primary_action", false) and primary == null: primary = button
			elif button.get_meta("primary_action", false): _demote(button)
	# Page navigation remains directly available; long reports and alternative controls are optional.
	for child in originals:
		var navigation := child is HBoxContainer and child.get_children().any(func(c): return c is Button and (str(c.name).contains("Tab_") or str(c.name).begins_with("FactoryTab_")))
		if navigation: continue
		_move(child, details)
	if column == owner.body:
		for button in owner.footer.find_children("*", "Button", true, false):
			if _requires_review(button):button.reparent(details)
	column.add_child(details)
	var summary := UIK.panel("ui/card", 5)
	summary.name = "CalmSummary"
	var box := UIK.vbox(3)
	summary.add_child(box)
	box.add_child(UIK.label(str(profile["label"]), 10, Art.C_WHITE, true))
	box.add_child(UIK.wrap(str(profile["hint"]), 8, Art.C_MUTED, 460))
	for figure in figures(id, owner): box.add_child(UIK.kv(str(figure[0]), str(figure[1]), Art.C_SKY, 8))
	column.add_child(summary)
	column.move_child(summary, mini(1, column.get_child_count()-1) if originals.size() > 0 and originals[0].get_parent() == column else 0)
	if primary != null:
		# A term sheet must be read before committing: keep the signing button with all its actual terms.
		if _requires_review(primary):
			_demote(primary)
			primary = null
	if primary != null:
		primary.reparent(box)
		primary.set_meta("calm_primary", true)
		primary.set_meta("primary_action", true)
	# The roof is the game board, not an administrative report. Keep it playable, move its numeric legends to hover.
	if id == "energy" and owner.get("page") == "survey":
		for grid in details.find_children("*", "GridContainer", true, false):
			if grid.find_children("Cell_*", "Button", true, false).is_empty(): continue
			grid.reparent(box)
			for cell in grid.get_children():
				cell.tooltip_text = cell.text
				var sunshine := str(cell.text).to_int()
				cell.text = "■" if cell.text.begins_with("■") else ("☀" if sunshine >= 80 else "◐" if sunshine >= 50 else "☁")
			break
	var advanced := UIK.button("Advanced" if primary != null else str(profile.get("text", "Review choices")), func():
		owner.calm_expanded[key] = not bool(owner.calm_expanded.get(key, false))
		details.visible = bool(owner.calm_expanded[key]), "" if primary != null else "primary")
	advanced.name = "CalmAdvanced"
	advanced.set_meta("calm_primary", primary == null)
	column.add_child(advanced)
	column.move_child(advanced, column.get_child_count()-2)
	details.visible = bool(owner.calm_expanded.get(key, false))
	# Ensure future assistant and guidance controls have the same stable names, even when details are closed.
	var chores: Array = profile.get("chores", [])
	for chore in chores: AssistantPolicy.toggle(box, str(chore))

## Preserve the actual terms beside actions that choose among offers or commit money.
## A quiet review entrance is preferable to inviting an uninformed acceptance of the first list item.
static func _requires_review(button: Button) -> bool:
	if RegEx.create_from_string("[0-9]").search(button.text) != null:return true
	var id := str(button.name)
	if button.name == "SignTerms" or button.name == "TradeSign" or button.name == "TradeProcure" or button.name == "ArrangeViewing" or button.name == "AcceptContract":return true
	return ["BuyProperty_", "Recruit_", "AcceptBlock_", "Quote_", "Accept_", "Mandate_", "Client_", "Develop_"].any(func(prefix):return id.begins_with(prefix))

static func _demote(button: Button) -> void:
	button.set_meta("primary_action", false)
	button.remove_theme_stylebox_override("normal")
	button.remove_theme_stylebox_override("hover")

static func _move(child: Node, parent: Node) -> void:
	child.get_parent().remove_child(child)
	parent.add_child(child)

## Three useful facts from actual state, ordered by the current screen's decision.
static func figures(id: String, owner: Modal) -> Array:
	var entity := GameState.business_entity()
	var cash := ["Cash in bank", Fmt.money(Ledger.cash(entity))]
	match id:
		"finance":
			return [cash, ["Business profit", Fmt.money(MonthClose.current(entity)["business_profit"])], ["Lowest projected cash", Fmt.money(Forecast.weekly(entity)["low"])]]
		"contracts": return [cash, ["Open offers", str(Contracts.open_list().filter(func(c): return c.get("status", "") == "offered").size())], ["Invoices receivable", Fmt.money(Ledger.balance(entity, "accounts_receivable"))]]
		"people": return [cash, ["Team members", str(Staff.people().size())], ["Weekly payroll", Fmt.money(Staff.weekly_payroll())]]
		"manufacturing": return [cash, ["Raw materials", I18n.t("%d units") % Manufacturing.material_units()], ["Active orders", str(Manufacturing.S()["orders"].values().filter(func(o): return o["status"] == "active").size())]]
		"real_estate": return [cash, ["Clients", str(RealEstate.S().get("clients", {}).size())], ["Owner mandates", str(RealEstate.S().get("mandates", {}).size())]]
		"media": return [cash, ["Active campaigns", str(Media.running().size())], ["Completed campaigns", str(Media.S()["completed"])]]
		"hotel": return [cash, ["Rooms", str(Hotel.total_rooms())], ["Guest rating", "%.1f" % Hotel.rating()]]
		"automotive": return [cash, ["Stock cars", str(Automotive.stock_count())], ["Fleet cars", str(Automotive.fleet_cars().size())]]
		"energy":
			if owner.get("page") == "survey":
				var lead: Dictionary = Energy.S()["leads"].get(str(owner.get("selected")), {})
				if not lead.is_empty():
					var evaluation := Energy.lead_eval(str(lead["id"]))
					return [["Panels",str(lead["layout"].size())],["Materials",Fmt.money(float(evaluation.get("materials",0)))],["Estimated annual savings",Fmt.money(float(evaluation.get("saving_year",0)))]]
			return [cash, ["Open stations", str(Energy.open_stations().size())], ["Completed installs", str(Energy.S()["completed"])]]
		"trade": return [cash, ["Delivered trades", str(TradeIndustry.S()["completed"])], ["Open deals", str(TradeIndustry.S()["deals"].size())]]
		"trade_quote":
			var quote: Dictionary = owner.get("quote")
			return [["Supply cost (home dollars)", Fmt.money(float(quote.get("purchase", 0)))], ["Estimated margin (home dollars)", Fmt.money(float(quote.get("margin", 0)))], ["Stress margin (home dollars)", Fmt.money(float(quote.get("stress_margin", 0)))]]
		"tax":
			entity = owner.get("entity")
			return [["Cash in bank", Fmt.money(Ledger.cash(entity))], ["VAT owed", Fmt.money(maxf(0, -Ledger.balance(entity, "tax_payable")))], ["Income tax owed", Fmt.money(maxf(0, -Ledger.balance(entity, "income_tax_payable")))]]
		"lease", "lease_end":
			var property: Dictionary = DataDB.properties.get(str(owner.get("pid")), {})
			var rent := float(property.get("monthly_rent", 0))
			return [["Monthly rent", Fmt.money(rent)], ["Deposit", Fmt.money(rent * float(property.get("deposit_months", 0)))], cash]
		"fundraising":
			var deal := Fundraising.open_deal_for(str(owner.get("selected")))
			if not deal.get("terms", {}).is_empty():
				var terms: Dictionary = deal["terms"]
				return [["Investment", Fmt.money(terms["amount"])], ["Equity sold", Fmt.pct(terms["stake"])], ["Legal and filing costs paid at signing", Fmt.money(float(terms.get("legal_fee", 0)))]]
			return [cash, ["Completed rounds", str(Fundraising.S()["rounds"].size())], ["Your share", Fmt.pct(float(GameState.data.get("cap_table", {}).get("founder", 1)))]]
		"governance": return [cash, ["Brand", "%.1f" % Brand.score(entity)], ["Open claims", str(Insurance.S()["claims"].values().filter(func(c): return c["entity"] == entity and c["status"] != "paid").size())]]
		_:
			return [cash, ["Revenue", Fmt.money(MonthClose.current(entity)["revenue"])], ["Business profit", Fmt.money(MonthClose.current(entity)["business_profit"])]]
