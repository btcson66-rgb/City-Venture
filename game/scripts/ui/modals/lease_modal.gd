class_name LeaseModal
extends Modal

var pid := ""


func _init(property_id: String) -> void:
	pid = property_id
	var p: Dictionary = DataDB.properties.get(pid, {})
	title_text = I18n.t("Lease — ") + I18n.t(str(p.get("name", pid)))
	icon_name = "company"
	help_key = "lease"
	panel_size = Vector2(380, 268 if str(p.get("kind", "")) == "warehouse" else 210)


func build() -> void:
	var p: Dictionary = DataDB.properties.get(pid, {})
	if Living.has_lease(pid):
		var manage := UIK.button("Manage lease", func(): close(); UIRoot.open_modal(LeaseEndModal.new(pid)), "primary")
		manage.name = "ManageLease_" + pid
		footer.add_child(manage)
		body.add_child(UIK.wrap(I18n.t(str(p.get("agent_line", "Tom: \"It's all yours. Sign's up out front.\""))), 9, Art.C_WHITE, 360))
		footer.add_child(UIK.button("Close", close))
		return
	body.add_child(UIK.kv("Monthly rent", Fmt.money(float(p["monthly_rent"])), Art.C_SKY, 9, true))
	var dep := UIK.kv("Deposit", Fmt.money(float(p["monthly_rent"]) * float(p.get("deposit_months", 0))))
	dep.add_child(UIK.tip("deposit"))
	body.add_child(dep)
	if int(p.get("capacity", {}).get("inventory_units", 0)) > 0:
		var sto := UIK.kv("Storage", I18n.t("%d units") % int(p.get("capacity", {}).get("inventory_units", 0)))
		if p.get("kind", "") == "warehouse":
			sto.add_child(UIK.tip("stock_location"))   # a second place to keep stock
		body.add_child(sto)
	if p.get("kind", "") == "office":
		body.add_child(UIK.kv("Desks", "%d" % int(p.get("capacity", {}).get("staff", 0))))
	if p.has("blurb"):
		body.add_child(UIK.wrap(I18n.t(str(p["blurb"])), 8, Art.C_MUTED, 360))
	else:
		body.add_child(UIK.wrap(I18n.t("A real office: your company name on the door and the sign, a proper desk for Company OS, and a stockroom so boxes stop living in your apartment. It's also %s every month whether you sell anything or not.") % Fmt.money(float(p["monthly_rent"])), 8, Art.C_MUTED, 360))
	if p.get("kind", "") == "warehouse":
		body.add_child(UIK.wrap(I18n.t("In plain words: you pay %s every month for the space, full or empty. Lease it once you have stock to put in it.") % Fmt.money(float(p["monthly_rent"])), 7, Art.C_SKY, 360))
	var can_sign := GameState.company_id() != "" and Ledger.cash(GameState.business_entity()) >= float(p["monthly_rent"]) * (1.0 + float(p.get("deposit_months", 0)))
	var lb := UIK.button("Sign the lease", _sign, "primary" if can_sign else "")
	lb.disabled = not can_sign
	if GameState.company_id() == "":
		lb.disabled = true
		body.add_child(UIK.label("Leases must be in a registered company's name.", 8, Art.C_RED))
	lb.name = "SignLease" if pid == "suite_2b" else "SignLease_" + pid
	footer.add_child(UIK.button("Not now", close))
	footer.add_child(lb)


func _sign() -> void:
	var r := Living.lease(pid)
	if not r["ok"]:
		UIRoot.toast(r["error"], "bad", "warning")
		return
	GameState.set_flag("leased_" + pid)
	if pid == "suite_2b":
		GameState.set_flag("workspace_chosen")
		GameState.set_flag("office_leased")
		UIRoot.toast("Lease signed. Welcome to Suite 2B.", "good", "company")
	else:
		UIRoot.toast(I18n.t("Lease signed: %s.") % I18n.t(str(DataDB.properties.get(pid, {}).get("name", pid))), "good", "company")
	rebuild()
