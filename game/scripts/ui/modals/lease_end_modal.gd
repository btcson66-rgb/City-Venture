class_name LeaseEndModal
extends Modal
var pid := ""
var mode := "notice"
var stock := "move"
var staff := "transfer"
var jobs := "finish"
var destination := ""


func _init(property_id := "") -> void:
	pid = property_id
	title_text = "Leases"
	help_key = "lease_end"
	icon_name = "home"
	panel_size = Vector2(520, 328)
	pauses_time = true


func build() -> void:
	var list := UIK.vbox(4)
	body.add_child(UIK.scroll(list, Vector2(492, 254)))
	if pid == "":
		for property_id in Living.D()["leases"]:
			var lease: Dictionary = Living.D()["leases"][property_id]
			var title := I18n.t(str(DataDB.properties.get(property_id, {}).get("name", property_id)))
			list.add_child(UIK.label(title, 9, Art.C_GOLD, true))
			list.add_child(UIK.label(I18n.t("Monthly rent: %s") % Fmt.money(float(lease["rent"])), 8))
			if lease.has("ending"): list.add_child(UIK.label(I18n.t("Notice ends %s") % Clock.fmt_short(int(lease["ending"]["due"])), 8, Art.C_SKY))
			var view := UIK.button("Review lease", func(): pid = property_id; rebuild())
			view.name = "ReviewLease_" + property_id
			list.add_child(view)
		list.add_child(UIK.wrap("Your current home lease ends through the Home move sign: book a replacement home and the old lease closes on moving day.", 8, Art.C_MUTED, 468))
	else:
		_detail(list)
	var done := UIK.button("Close", close)
	done.name = "CloseLeases"
	footer.add_child(done)


func _detail(list: Control) -> void:
	var lease: Dictionary = Living.D()["leases"].get(pid, {})
	if lease.is_empty():
		list.add_child(UIK.label("This lease has ended.", 9, Art.C_GREEN))
		return
	list.add_child(UIK.label(I18n.t(str(LeaseEnd.policy(pid)["name"])), 10, Art.C_GOLD, true))
	list.add_child(UIK.wrap("A premises-dependent business pauses when its lease ends. Finish its jobs first, or settle cancellations. Existing delivered invoices remain collectible.", 8, Art.C_MUTED, 468))
	_select(list, [["notice", "Give notice"], ["immediate", "Leave immediately"]], mode, func(v): mode = v; rebuild(), "LeaseMode_")
	_select(list, [["move", "Move stock"], ["liquidate", "Liquidate stock"]], stock, func(v): stock = v; rebuild(), "LeaseStock_")
	_select(list, [["transfer", "Transfer staff"], ["dismiss", "Dismiss staff"]], staff, func(v): staff = v; rebuild(), "LeaseStaff_")
	_select(list, [["finish", "Finish jobs first"], ["cancel", "Cancel jobs with penalty"]], jobs, func(v): jobs = v; rebuild(), "LeaseJobs_")
	list.add_child(UIK.label("Destination for stock, orders and staff", 8, Art.C_SKY))
	for dest in Ecommerce.stock_locations():
		if dest == pid: continue
		var pick := UIK.button(Ecommerce.location_name(dest), func(): destination = dest; rebuild(), "tab_active" if destination == dest else "tab")
		pick.name = "LeaseDestination_" + dest
		list.add_child(pick)
	var plan := {"stock": stock, "staff": staff, "jobs": jobs, "destination": destination}
	var quote := LeaseEnd.quote(pid, mode, plan)
	if lease.has("ending"):
		var pending_quote: Dictionary = lease["ending"]
		quote = LeaseEnd.quote(pid, str(pending_quote["mode"]), plan, true)
		quote["due"] = pending_quote["due"]
		if quote["ok"]:
			quote["notice_rent"] = 0.0
			quote["early_fee"] = 0.0
			quote["total"] = float(quote["moving"]) + float(quote["severance"]) + float(quote["penalties"]) + float(quote["job_refunds"])
		list.add_child(UIK.label(I18n.t("Notice ends %s") % Clock.fmt_short(int(quote["due"])), 8, Art.C_GOLD))
		if quote.has("blocked"): list.add_child(UIK.wrap("✗ " + str(quote["blocked"]), 8, Art.C_RED, 468))
	if quote["ok"]:
		for row in [["Notice rent", "notice_rent"], ["Early exit fee", "early_fee"], ["Moving cost", "moving"], ["Staff severance", "severance"], ["Job penalties", "penalties"], ["Job deposit refunds", "job_refunds"], ["Material liquidation proceeds", "materials"], ["Deposit held", "deposit"], ["Damage deduction", "damage"], ["Deposit returned on exit", "refund"]]:
			list.add_child(UIK.kv(row[0], Fmt.money(float(quote[row[1]])), Art.C_WHITE, 8))
		list.add_child(UIK.kv("Exit date", Clock.fmt_short(int(quote["due"]))))
		list.add_child(UIK.kv("Cash needed before refund", Fmt.money(float(quote["total"])), Art.C_GOLD))
	else:
		list.add_child(UIK.wrap("✗ " + str(quote["error"]), 8, Art.C_GOLD, 468))
	var pending: bool = lease.has("ending")
	var ready: bool = quote["ok"] and (not pending or Clock.now() >= int(quote["due"]))
	var confirm := UIK.button("Resolve pending exit" if pending else "Confirm termination", _confirm.bind(plan), "primary" if ready else "button")
	confirm.name = "ConfirmLeaseEnd"
	confirm.disabled = not ready
	list.add_child(confirm)


func _select(parent: Control, options: Array, value: String, callback: Callable, prefix: String) -> void:
	var row := UIK.hbox(4)
	parent.add_child(row)
	for option in options:
		var button := UIK.button(option[1], callback.bind(str(option[0])), "tab_active" if option[0] == value else "tab")
		button.name = prefix + str(option[0])
		row.add_child(button)


func _confirm(plan: Dictionary) -> void:
	var lease: Dictionary = Living.D()["leases"].get(pid, {})
	var result: Dictionary
	if lease.has("ending"):
		lease["ending"]["plan"] = plan.duplicate(true)
		lease["ending"].erase("blocked")
		result = LeaseEnd._finish(pid)
	else:
		result = Living.end_lease(pid, mode, plan)
	if not result["ok"]: UIRoot.toast(result["error"], "bad", "warning")
	rebuild()
