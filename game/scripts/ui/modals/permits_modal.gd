class_name PermitsModal
extends Modal
## City Hall permits kiosk. Regulations are operating conditions: each has a cost, a process and a
## reason. Company and employer registration can be done here; the rest say honestly when they arrive.


func _init() -> void:
	title_text = "City Hall — Permits"
	icon_name = "civic"
	panel_size = Vector2(420, 250)


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
	_row("Import permits & customs", I18n.t("Planned (P2)"), Art.C_DIM)
	_row("Food handling licence", I18n.t("Planned (P3)"), Art.C_DIM)
	_row("Data protection registration", I18n.t("Planned (P1)"), Art.C_DIM)
	body.add_child(UIK.sep())
	body.add_child(UIK.wrap("Regulations here are operating conditions, not quizzes: each one has a cost, a process, and a reason.", 7, Art.C_SKY, 400))
	footer.add_child(UIK.button("Close", close, "", 70))


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
