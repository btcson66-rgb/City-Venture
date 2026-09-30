class_name PermitsModal
extends Modal
## City Hall permits kiosk. Regulations are operating conditions: each has a cost, a process and a
## reason. Company and employer registration can be done here; the rest say honestly when they arrive.


func _init() -> void:
	title_text = "City Hall — Permits"
	icon_name = "civic"
	help_key = "permits"
	panel_size = Vector2(420, 316)


func build() -> void:
	body.add_child(UIK.label("PERMITS & REGISTRATIONS (AURELIA)", 7, Art.C_DIM, true))
	var reg := GameState.company_id() != ""
	_row("Company registration", I18n.t("Done") if reg else I18n.t("Registration counter · %s") % Fmt.money0(Company.registration_fee()),
		Art.C_GREEN if reg else Art.C_WHITE)
	var emp := Staff.employer_registered()
	var fee := float(Staff.cfg().get("employer_registration_fee", 150))
	var r := UIK.hbox(6)
	body.add_child(r)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label("Employer registration & payroll", 8, Art.C_WHITE, true))
	v.add_child(UIK.wrap("Needed before you hire anyone. Payroll runs every Friday at 17:00 from the company account.", 7, Art.C_MUTED, 300))
	if emp:
		r.add_child(UIK.chip(I18n.t("REGISTERED"), Art.C_GREEN))
	else:
		var b := UIK.button(I18n.t("Register (%s)") % Fmt.money0(fee), _register, "primary")
		b.name = "RegisterEmployer"
		b.disabled = not reg
		r.add_child(b)
		if not reg:
			v.add_child(UIK.label("Register the company first.", 7, Art.C_GOLD, true))
	if World.year() >= 4:
		_green_grant()
	_row("Import permits & customs", I18n.t("Planned (P2)"), Art.C_DIM)
	_food_licence()
	_row("Data protection registration", I18n.t("Planned (P1)"), Art.C_DIM)
	body.add_child(UIK.sep())
	body.add_child(UIK.wrap("Regulations here are operating conditions, not quizzes: each one has a cost, a process, and a reason.", 7, Art.C_SKY, 400))
	footer.add_child(UIK.button("Close", close, "", 70))


## Year 4: the Green Business Grant, with what's still missing spelled out.
func _green_grant() -> void:
	var r := UIK.hbox(6)
	body.add_child(r)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label(I18n.t("Green Business Grant (%s)") % Fmt.money0(Company.GREEN_GRANT), 8, Art.C_WHITE, true))
	v.add_child(UIK.wrap("For registered companies with recycled packaging and a green product on sale.", 7, Art.C_MUTED, 300))
	if GameState.flag("green_grant"):
		r.add_child(UIK.chip(I18n.t("GRANTED"), Art.C_GREEN))
		return
	var why := Company.green_grant_block()
	if why != "":
		v.add_child(UIK.label(I18n.t(why), 7, Art.C_GOLD, true))
	var b := UIK.button("Apply", _apply_grant, "primary")
	b.name = "ApplyGreenGrant"
	b.disabled = why != ""
	r.add_child(b)


## The café's food handling licence: needs the premises; City Hall takes two days.
func _food_licence() -> void:
	var r := UIK.hbox(6)
	body.add_child(r)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label(I18n.t("Food handling licence (%s)") % Fmt.money0(float(Cafe.cfg().get("permit_fee", 280))), 8, Art.C_WHITE, true))
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
	var b := UIK.button("Apply", _apply_food, "primary" if why == "" else "")
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


func _row(k: String, v: String, col: Color) -> void:
	body.add_child(UIK.kv(k, v, col, 8))


func _register() -> void:
	var r := Staff.register_employer()
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
		return
	Clock.advance(20)
	UIRoot.toast(I18n.t("Registered as an employer (%s). You can post jobs in Company OS → People.") % Fmt.money(r["fee"]), "good", "civic")
	rebuild()
