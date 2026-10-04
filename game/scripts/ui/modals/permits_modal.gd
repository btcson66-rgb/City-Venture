class_name PermitsModal
extends Modal
## City Hall permits kiosk. Regulations are operating conditions: each has a cost, a process and a
## reason. Company and employer registration can be done here; the rest say honestly when they arrive.

var _primary_chosen := false


func _init() -> void:
	title_text = "City Hall — Permits"
	icon_name = "civic"
	help_key = "permits"
	panel_size = Vector2(430, 338)


func build() -> void:
	_primary_chosen = false
	body.add_child(UIK.label("PERMITS & REGISTRATIONS (AURELIA)", 7, Art.C_DIM, true))
	var reg := GameState.company_id() != ""
	if not reg:
		var next := UIK.button("Go to the company registration counter", _registration_next, _action_style(true))
		next.name = "CompanyRegistrationNext"
		body.add_child(next)
	_row("Company registration", I18n.t("✓ Registered") if reg else I18n.t("✗ Registration counter · %s") % Fmt.money0(Company.registration_fee()),
		Art.C_GREEN if reg else Art.C_WHITE)
	var emp := Staff.employer_registered()
	var fee := float(Staff.cfg().get("employer_registration_fee", 150))
	var r := UIK.hbox(6)
	body.add_child(r)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label_tip("Employer registration & payroll", "employer_registration", 8, Art.C_WHITE, true))
	v.add_child(UIK.wrap("Needed before you hire anyone. Payroll runs every Friday at 17:00 from the company account.", 7, Art.C_MUTED, 300))
	if emp:
		r.add_child(UIK.chip("✓", Art.C_GREEN))
	else:
		var b := UIK.button(I18n.t("Register (%s)") % Fmt.money0(fee), _register, _action_style(reg and Ledger.cash(GameState.business_entity()) >= fee))
		b.name = "RegisterEmployer"
		b.disabled = not reg or Ledger.cash(GameState.business_entity()) < fee
		r.add_child(b)
		if not reg:
			v.add_child(UIK.label("Register the company first.", 7, Art.C_GOLD, true))
	if World.year() >= 4:
		_green_grant()
	if reg:
		var tax := UIK.button("Tax Filing",func():Industries.run_action("tax_filing",{},self))
		tax.name="TaxFiling"
		body.add_child(tax)
	_import_licence()
	_food_licence()
	body.add_child(UIK.sep())
	body.add_child(UIK.wrap("Regulations here are operating conditions, not quizzes: each one has a cost, a process, and a reason.", 7, Art.C_SKY, 400))
	footer.add_child(UIK.button("Close", close, "", 70))
	var property_permits := UIK.button("Property permits",func():RealEstateUI.open("permits"),"",110)
	property_permits.name="PropertyPermits"
	footer.add_child(property_permits)


## Year 4: the Green Business Grant, with what's still missing spelled out.
func _green_grant() -> void:
	var r := UIK.hbox(6)
	body.add_child(r)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label_tip(I18n.t("Green Business Grant (%s)") % Fmt.money0(Company.GREEN_GRANT), "green_grant", 8, Art.C_WHITE, true))
	v.add_child(UIK.wrap("For registered companies with recycled packaging and a green product on sale.", 7, Art.C_MUTED, 300))
	if GameState.flag("green_grant"):
		r.add_child(UIK.chip(I18n.t("GRANTED"), Art.C_GREEN))
		return
	var why := Company.green_grant_block()
	if why != "":
		v.add_child(UIK.label(I18n.t(why), 7, Art.C_GOLD, true))
	var b := UIK.button("Apply", _apply_grant, _action_style(why == ""))
	b.name = "ApplyGreenGrant"
	b.disabled = why != ""
	r.add_child(b)


## Year 8 (Regulation Wave): the import licence, with the year's other compliance rules spelled out.
func _import_licence() -> void:
	var r := UIK.hbox(6)
	body.add_child(r)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label_tip(I18n.t("Import licence (%s a year)") % Fmt.money0(Compliance.licence_fee()), "import_licence", 8, Art.C_WHITE, true))
	if not Compliance.active():
		v.add_child(UIK.wrap("Not needed yet. Commercial importers need one from the Regulation Wave (Year 8).", 7, Art.C_MUTED, 300))
		return
	v.add_child(UIK.wrap("Needed to import from abroad. Renew it in its last two months, or imports stop.", 7, Art.C_MUTED, 300))
	v.add_child(UIK.label_tip(I18n.t("KYC check on payments over %s: a fee and a day's delay.") % Fmt.money0(Compliance.kyc_threshold()), "kyc", 7, Art.C_MUTED))
	v.add_child(UIK.label_tip(I18n.t("Compliance cost: %s a month, more with staff.") % Fmt.money0(Compliance.monthly_cost()), "compliance_cost", 7, Art.C_MUTED))
	if Compliance.licence_valid():
		v.add_child(UIK.label(I18n.t("Valid until %s.") % Clock.fmt_date(Compliance.licence_until()), 7, Art.C_GREEN, true))
	if Compliance.licence_pending():
		r.add_child(UIK.chip(I18n.t("PROCESSING"), Art.C_GOLD))
		return
	var why := Compliance.licence_block()
	if Compliance.licence_valid() and Compliance.licence_days_left() > Compliance.renew_window():
		r.add_child(UIK.chip(I18n.t("LICENSED"), Art.C_GREEN))
		return
	if why != "":
		v.add_child(UIK.label(I18n.t(why), 7, Art.C_GOLD, true))
	var renew := Compliance.licence_valid()
	var b := UIK.button(I18n.t("Renew (%s)") % Fmt.money0(Compliance.licence_fee()) if renew else I18n.t("Apply (%s)") % Fmt.money0(Compliance.licence_fee()), _apply_licence, _action_style(why == ""))
	b.name = "RenewImportLicence" if renew else "ApplyImportLicence"
	b.disabled = why != ""
	r.add_child(b)


func _apply_licence() -> void:
	var res := Compliance.apply_licence()
	if not res["ok"]:
		UIRoot.toast(I18n.t(str(res["error"])), "warn", "lock")
		return
	Clock.advance(20)
	if res.get("renewed", false):
		UIRoot.toast(I18n.t("Licence renewed until %s.") % Clock.fmt_date(int(res["until"])), "good", "civic")
	else:
		UIRoot.toast(I18n.t("Application filed. The licence should be through %s.") % Clock.fmt_short(int(res["ready"])), "good", "civic")
	rebuild()


## The café's food handling licence: needs the premises; City Hall takes two days.
func _food_licence() -> void:
	var r := UIK.hbox(6)
	body.add_child(r)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label_tip(I18n.t("Food handling licence (%s)") % Fmt.money0(float(Cafe.cfg().get("permit_fee", 280))), "food_licence", 8, Art.C_WHITE, true))
	v.add_child(UIK.wrap("For serving food and drink from your own premises. An inspector checks the unit; it takes two days.", 7, Art.C_MUTED, 300))
	if Cafe.permitted():
		r.add_child(UIK.chip(I18n.t("GRANTED"), Art.C_GREEN))
		return
	if Cafe.permit_pending():
		r.add_child(UIK.chip(I18n.t("PROCESSING"), Art.C_GOLD))
		return
	var why := Cafe.permit_block()
	if why != "":
		v.add_child(UIK.label(I18n.t(why), 7, Art.C_GOLD, true))
	var b := UIK.button("Apply", _apply_food, _action_style(why == ""))
	b.name = "ApplyFoodLicence"
	b.disabled = why != ""
	r.add_child(b)


func _apply_food() -> void:
	var res := Cafe.apply_permit()
	if not res["ok"]:
		UIRoot.toast(I18n.t(str(res["error"])), "warn", "lock")
		return
	Clock.advance(20)
	UIRoot.toast(I18n.t("Application filed. The licence should be through %s.") % Clock.fmt_short(int(res["ready"])), "good", "civic")
	rebuild()


func _apply_grant() -> void:
	var res := Company.claim_green_grant()
	if not res["ok"]:
		UIRoot.toast(I18n.t(str(res["error"])), "warn", "lock")
		return
	Clock.advance(30)
	UIRoot.toast(I18n.t("Grant approved: %s is on its way to the company account.") % Fmt.money0(float(res["amount"])), "good", "civic")
	rebuild()


func _row(k: String, v: String, col: Color, tip := "company_registration") -> void:
	body.add_child(UIK.kv_tip(k, v, tip, col, 8))


func _action_style(ready: bool) -> String:
	if ready and not _primary_chosen:
		_primary_chosen = true
		return "primary"
	return ""


func _registration_next() -> void:
	close()
	if Actions.npc_present("ana"):
		UIRoot.open_modal(RegistrationModal.new())
	else:
		UIRoot.tutorial.guide_to_building("city_hall")


func _register() -> void:
	var r := Staff.register_employer()
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
		return
	Clock.advance(20)
	UIRoot.toast(I18n.t("Registered as an employer (%s). You can post jobs in Company OS → People.") % Fmt.money0(r["fee"]), "good", "civic")
	rebuild()
