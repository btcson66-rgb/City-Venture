class_name DecisionModal
extends Modal
## A dynamic event decision: short lines, choices with visible trade-offs, then the outcome.

var inst: Dictionary
var def: Dictionary
var outcome := ""


func _init(i: Dictionary) -> void:
	pauses_time = true
	inst = i
	def = DataDB.events.get(i["id"], {})
	var pres: Dictionary = def.get("presentation", {})
	title_text = pres.get("title", "Decision")
	icon_name = pres.get("icon", "warning")
	help_key = "decision"
	panel_size = Vector2(400, 230)
	closable = false


## The panel may not grow past the screen: everything above the buttons scrolls when a decision runs long.
const MAX_CONTENT_H := 262.0


func build() -> void:
	var sc := ScrollContainer.new()
	sc.name = "DecisionScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var col := UIK.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	_fit.call_deferred(sc, col)
	var pres: Dictionary = def.get("presentation", {})
	var who: String = pres.get("speaker", "")
	# event illustration (events/<id>.png, 160x90) once the art exists
	var art := Art.opt_tex("events/" + str(inst["id"]))
	if art != null and outcome == "":
		var pic := TextureRect.new()
		pic.name = "EventArt"
		pic.texture = art
		pic.custom_minimum_size = Vector2(160, 90) if def.get("choices", []).size() < 3 else Vector2(124, 70)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		col.add_child(pic)
	var h := UIK.hbox(8)
	col.add_child(h)
	if who != "" and DataDB.npc(who).has("appearance"):
		var pv := PortraitView.new()
		pv.custom_minimum_size = Vector2(56, 56)
		pv.size = Vector2(56, 56)
		var d := DataDB.npc(who)
		var tints := {}
		for k in d.get("outfit_tints", {}):
			tints[k] = Color(d["outfit_tints"][k])
		pv.setup_character(d["appearance"], d.get("outfit", "casual_tee"), tints, who)
		pv.set_expr("thinking")
		h.add_child(pv)
	var v := UIK.vbox(2)
	h.add_child(v)
	if who != "":
		v.add_child(UIK.label(DataDB.npc(who).get("name", who.capitalize()), 8, Art.C_GOLD, true))
	for line in pres.get("lines", []):
		v.add_child(UIK.wrap(EventEngine.fill(str(line), inst["ctx"]), 8, Art.C_WHITE, 310))
	# new ideas in this decision get a "!" badge with a plain-language card (data/help/glossary.json)
	if outcome == "":
		for tid in pres.get("tips", []):
			v.add_child(UIK.label_tip(I18n.t(str(InfoTip.entry(str(tid)).get("title", tid))), str(tid), 7, Art.C_SKY))
	col.add_child(UIK.sep())
	if outcome != "":
		col.add_child(UIK.wrap(outcome, 9, Art.C_SKY, 380))
		var ok := UIK.button("OK", close, "primary", 70)
		ok.name = "DecisionOK"
		footer.add_child(ok)
		return
	var recommended := ""
	for c in def.get("choices", []):
		if c.get("recommended", false) and EventEngine.choice_available(c, inst["ctx"]):
			recommended = str(c["id"])
			break
	for c in def.get("choices", []):
		var avail := EventEngine.choice_available(c, inst["ctx"])
		var row := UIK.vbox(0)
		var b := UIK.button(EventEngine.fill(c["label"], inst["ctx"]), _pick.bind(c["id"]), "primary" if recommended == str(c["id"]) else "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not avail
		b.name = "Choice_" + str(c["id"])
		row.add_child(b)
		if c.has("tip"):
			row.add_child(UIK.label_tip(str(InfoTip.entry(str(c["tip"])).get("title", "")), str(c["tip"]), 7, Art.C_SKY))
		if c.has("detail"):
			var suffix := "" if avail else I18n.t("  (not possible now)")
			if def.get("id", "") == "customs_hold" and not avail:
				suffix = I18n.t(" ✗ Transfer company cash or choose withdrawal.")
			var dl := UIK.wrap(EventEngine.fill(c["detail"], inst["ctx"]) + suffix, 7, Art.C_MUTED, 370)
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", 10)
			pad.add_child(dl)
			row.add_child(pad)
		col.add_child(row)


## Size the scroll to its content (at most MAX_CONTENT_H) and shrink the panel back after a rebuild, so the buttons
## at the bottom are always on screen.
func _fit(sc: ScrollContainer, col: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(sc) or not is_instance_valid(col):
		return
	sc.custom_minimum_size = Vector2(384, minf(col.get_combined_minimum_size().y, MAX_CONTENT_H))
	panel.size = Vector2(panel_size.x, 0)
	panel.reset_size()
	panel.position = Vector2((640.0 - panel.size.x) / 2.0, maxf(4.0, (360.0 - panel.size.y) / 2.0))


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
