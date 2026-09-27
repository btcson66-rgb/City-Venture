class_name BusinessBoard
extends Modal
## Chapter 1: discover and pick a first business. No class/job, no buffs — you pick a business model.

var selected := "ecommerce"


func _init() -> void:
	title_text = "Business Board — Nexus Co-work"
	icon_name = "tasks"
	panel_size = Vector2(500, 290)


func build() -> void:
	var cols := UIK.hbox(8)
	body.add_child(cols)
	var list := UIK.vbox(2)
	list.custom_minimum_size = Vector2(170, 0)
	cols.add_child(list)
	list.add_child(UIK.label("FIRST BUSINESS (P0)", 7, Art.C_DIM, true))
	var bs: Array = DataDB.businesses.values()
	bs.sort_custom(func(a, b): return (0 if a["tier"] == "p0" else 1) * 10 + (0 if a["status"] == "active" else 1) < (0 if b["tier"] == "p0" else 1) * 10 + (0 if b["status"] == "active" else 1))
	var shown_future := false
	for b in bs:
		if b["tier"] != "p0" and not shown_future:
			shown_future = true
			list.add_child(UIK.label("LATER", 7, Art.C_DIM, true))
		var btn := UIK.button(("● " if b["status"] == "active" else "○ ") + b["name"], func(): selected = b["id"]; rebuild(), "tab_active" if selected == b["id"] else "tab")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.name = "Biz_" + b["id"]
		list.add_child(btn)
	var d: Dictionary = DataDB.businesses[selected]
	var det := UIK.vbox(4)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(det)
	det.add_child(UIK.title(d["name"], 13, Art.C_WHITE))
	det.add_child(UIK.wrap(d["pitch"], 9, Art.C_SKY, 290))
	det.add_child(UIK.kv("Minimum starting capital", Fmt.money0(float(d["starting_capital_min"]))))
	det.add_child(UIK.kv("Money comes from", ", ".join(d["revenue_models"]).replace("_", " ")))
	det.add_child(UIK.kv("Main costs", ", ".join(d["cost_types"]).replace("_", " ")))
	det.add_child(UIK.kv("Can grow into", ", ".join(d["growth_paths"]).replace("_", " ")))
	if selected == "ecommerce":
		det.add_child(UIK.sep())
		det.add_child(UIK.wrap("Posted by Ken (TradeLink Wholesale): \"Earbuds $18, lamps $11.50, bottles $6.80, phone stands $3.40. MOQs apply. Order via laptop.\"", 8, Art.C_WHITE, 290))
		det.add_child(UIK.wrap("ShopLane marketplace: 10% fee, weekly payouts, personal sellers capped at $2,500/month.", 8, Art.C_MUTED, 290))
		if GameState.flag("business_chosen"):
			det.add_child(UIK.label("✓ You're running this.", 9, Art.C_GREEN, true))
		else:
			var go := UIK.button("Start an ecommerce side business", _choose, "primary")
			go.name = "StartEcommerce"
			det.add_child(go)
	else:
		det.add_child(UIK.sep())
		det.add_child(UIK.wrap("Not in this build. %s is planned for %s — it will play differently, not just a new icon." % [d["name"], "P1–P3" if d["tier"] == "p0" else "a later expansion"], 8, Art.C_GOLD, 290))
	footer.add_child(UIK.button("Close", close))


func _choose() -> void:
	GameState.set_flag("business_ecommerce")
	GameState.set_flag("business_chosen")
	GameState.timeline("Chose a first business: ecommerce.", "business")
	UIRoot.toast("Ecommerce it is. Order stock from a laptop or a desk.", "good", "check")
	rebuild()
