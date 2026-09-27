class_name BusinessBoard
extends Modal
## Nexus Co-work's Business Board: pick how you make a living. No class, no buffs: businesses you
## run (ecommerce drives the story; freelance consulting runs alongside) and part-time jobs with real
## wages, promotions and one perk each. Planned businesses say so honestly.

var selected := "ecommerce"
var page := "business"


func _init() -> void:
	title_text = "Business Board — Nexus Co-work"
	icon_name = "tasks"
	panel_size = Vector2(520, 300)


func build() -> void:
	var tabs := UIK.hbox(4)
	body.add_child(tabs)
	for t in [["business", "Businesses"], ["jobs", "Part-time jobs"]]:
		var b := UIK.button(t[1], func(): page = t[0]; rebuild(), "tab_active" if page == t[0] else "tab")
		b.name = "Page_" + t[0]
		tabs.add_child(b)
	tabs.add_child(UIK.expand())
	tabs.add_child(UIK.label("Mix and match: run a business and keep a job.", 7, Art.C_MUTED))
	if page == "jobs":
		_jobs()
	else:
		_businesses()
	footer.add_child(UIK.button("Close", close))


func _businesses() -> void:
	var cols := UIK.hbox(8)
	body.add_child(cols)
	var list := UIK.vbox(2)
	list.custom_minimum_size = Vector2(170, 0)
	cols.add_child(list)
	list.add_child(UIK.label("START NOW", 7, Art.C_DIM, true))
	var bs: Array = DataDB.businesses.values()
	bs.sort_custom(func(a, b): return _order(a) < _order(b))
	var shown_future := false
	for b in bs:
		if b["status"] != "active" and not shown_future:
			shown_future = true
			list.add_child(UIK.label("LATER", 7, Art.C_DIM, true))
		var btn := UIK.button(("● " if b["status"] == "active" else "○ ") + I18n.t(b["name"]), func(): selected = b["id"]; rebuild(), "tab_active" if selected == b["id"] else "tab")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.name = "Biz_" + b["id"]
		list.add_child(btn)
	var d: Dictionary = DataDB.businesses[selected]
	var det := UIK.vbox(4)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(det)
	det.add_child(UIK.title(d["name"], 13, Art.C_WHITE))
	det.add_child(UIK.wrap(d["pitch"], 9, Art.C_SKY, 300))
	det.add_child(UIK.kv("Minimum starting capital", Fmt.money0(float(d["starting_capital_min"]))))
	det.add_child(UIK.kv("Money comes from", I18n.join(d["revenue_models"], true)))
	det.add_child(UIK.kv("Main costs", I18n.join(d["cost_types"], true)))
	det.add_child(UIK.kv("Can grow into", I18n.join(d["growth_paths"], true)))
	det.add_child(UIK.sep())
	match selected:
		"ecommerce":
			det.add_child(UIK.wrap("Posted by Ken (TradeLink Wholesale): \"Earbuds $18, lamps $11.50, bottles $6.80, phone stands $3.40. MOQs apply. Order via laptop.\"", 8, Art.C_WHITE, 300))
			det.add_child(UIK.wrap("ShopLane marketplace: 10% fee, weekly payouts, personal sellers capped at $2,500/month.", 8, Art.C_MUTED, 300))
			if GameState.flag("business_chosen"):
				det.add_child(UIK.label("✓ You're running this.", 9, Art.C_GREEN, true))
			else:
				var go := UIK.button("Start an ecommerce side business", _choose, "primary")
				go.name = "StartEcommerce"
				det.add_child(go)
		"consulting":
			det.add_child(UIK.wrap("Clients post small projects every morning. Accept one, put the hours in at any laptop (Company OS → Freelance), deliver before the deadline and get paid on the client's terms. On-time work raises your stars and your rate.", 8, Art.C_WHITE, 300))
			if Careers.freelance_active():
				det.add_child(UIK.label("✓ You're freelancing. Find gigs in Company OS.", 9, Art.C_GREEN, true))
			else:
				var go2 := UIK.button("Start freelancing", _start_freelance, "primary")
				go2.name = "StartFreelance"
				det.add_child(go2)
		_:
			det.add_child(UIK.wrap(I18n.t("Not in this build. %s is planned for %s — it will play differently, not just a new icon.") % [I18n.t(d["name"]), "P1–P3" if d["tier"] == "p0" else "a later expansion"], 8, Art.C_GOLD, 300))


func _order(b: Dictionary) -> int:
	return (0 if b["status"] == "active" else 10) + (0 if b["id"] == "ecommerce" else 1)


func _jobs() -> void:
	var cur := Careers.current_job()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	body.add_child(grid)
	var ids: Array = DataDB.jobs.keys()
	ids.sort()
	for id in ids:
		var j: Dictionary = DataDB.jobs[id]
		var mine: bool = cur == id
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIK.flat(Color(0.06, 0.1, 0.18, 0.92), Art.C_GOLD if mine else Color(0.4, 0.5, 0.7, 0.5), 1, 3))
		card.custom_minimum_size = Vector2(248, 0)
		grid.add_child(card)
		var v := UIK.vbox(1)
		card.add_child(v)
		var hr := UIK.hbox(4)
		v.add_child(hr)
		hr.add_child(UIK.label(I18n.t(str(Careers.rank(id)["title"])), 8, Art.C_GOLD if mine else Art.C_WHITE, true))
		hr.add_child(UIK.label("· " + I18n.t(str(j["employer"])), 7, Art.C_MUTED))
		hr.add_child(UIK.expand())
		hr.add_child(UIK.label(I18n.t("$%d/h") % int(Careers.wage(id)), 8, Art.C_GREEN, true))
		v.add_child(UIK.wrap(I18n.t(str(j.get("perk", {}).get("desc", ""))), 7, Art.C_SKY, 236))
		var b := UIK.button(I18n.t("Your job · details") if mine else I18n.t("Details / apply"), func():
			var m := JobModal.new(id)
			m.closed.connect(rebuild)
			UIRoot.open_modal(m), "primary" if not mine else "")
		b.name = "Job_" + str(id)
		v.add_child(b)
	body.add_child(UIK.label("Work shifts on site: walk to the workplace's staff door and press E.", 7, Art.C_MUTED))


func _choose() -> void:
	GameState.set_flag("business_ecommerce")
	GameState.set_flag("business_chosen")
	GameState.timeline("Chose a first business: ecommerce.", "business")
	UIRoot.toast("Ecommerce it is. Order stock from a laptop or a desk.", "good", "check")
	rebuild()


func _start_freelance() -> void:
	Careers.start_freelance()
	UIRoot.toast("You're a freelance consultant now. Today's gigs are in Company OS → Freelance.", "good", "check")
	rebuild()
