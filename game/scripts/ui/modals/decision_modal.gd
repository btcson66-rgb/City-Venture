class_name DecisionModal
extends Modal
## A dynamic event decision: short lines, choices with visible trade-offs, then the outcome.

var inst: Dictionary
var def: Dictionary
var outcome := ""


func _init(i: Dictionary) -> void:
	inst = i
	def = DataDB.events.get(i["id"], {})
	var pres: Dictionary = def.get("presentation", {})
	title_text = pres.get("title", "Decision")
	icon_name = pres.get("icon", "warning")
	panel_size = Vector2(400, 230)
	closable = false


func build() -> void:
	var pres: Dictionary = def.get("presentation", {})
	var who: String = pres.get("speaker", "")
	var h := UIK.hbox(8)
	body.add_child(h)
	if who != "" and DataDB.npc(who).has("appearance"):
		var pv := PortraitView.new()
		pv.custom_minimum_size = Vector2(56, 56)
		pv.size = Vector2(56, 56)
		var d := DataDB.npc(who)
		var tints := {}
		for k in d.get("outfit_tints", {}):
			tints[k] = Color(d["outfit_tints"][k])
		pv.setup_character(d["appearance"], d.get("outfit", "casual_tee"), tints)
		pv.set_expr("thinking")
		h.add_child(pv)
	var v := UIK.vbox(2)
	h.add_child(v)
	if who != "":
		v.add_child(UIK.label(DataDB.npc(who).get("name", who.capitalize()), 8, Art.C_GOLD, true))
	for line in pres.get("lines", []):
		v.add_child(UIK.wrap(EventEngine.fill(str(line), inst["ctx"]), 8, Art.C_WHITE, 310))
	body.add_child(UIK.sep())
	if outcome != "":
		body.add_child(UIK.wrap(outcome, 9, Art.C_SKY, 380))
		footer.add_child(UIK.button("OK", close, "primary", 70))
		return
	for c in def.get("choices", []):
		var avail := EventEngine.choice_available(c, inst["ctx"])
		var row := UIK.vbox(0)
		var b := UIK.button(EventEngine.fill(c["label"], inst["ctx"]), _pick.bind(c["id"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not avail
		b.name = "Choice_" + str(c["id"])
		row.add_child(b)
		if c.has("detail"):
			row.add_child(UIK.label("    " + EventEngine.fill(c["detail"], inst["ctx"]) + ("" if avail else I18n.t("  (not possible now)")), 7, Art.C_MUTED))
		body.add_child(row)


func _pick(cid: String) -> void:
	var r := EventEngine.choose(inst["iid"], cid)
	if not r.get("ok", false):
		UIRoot.toast(r.get("error", "Can't do that."), "bad", "warning")
		return
	outcome = r.get("outcome", "")
	if outcome == "":
		close()
		return
	rebuild()
