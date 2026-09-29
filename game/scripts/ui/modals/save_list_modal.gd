class_name SaveListModal
extends Modal
## Saved games. "load": pick one to continue (title screen, pause menu). "replace": every slot is taken, so pick
## the one the new game takes over; the old save is moved to saves/replaced/, not deleted.

var mode := "load"
var confirm := -1          # the slot waiting for "Replace" to be confirmed


func _init(m := "load") -> void:
	mode = m
	title_text = "Load a game" if m == "load" else "Start a new game"
	icon_name = "save"
	panel_size = Vector2(420, 262)


func build() -> void:
	if mode == "replace":
		body.add_child(UIK.wrap("All save slots are in use. Choose one for the new game. The old save is moved to a backup folder, not deleted.", 7, Art.C_GOLD, 396))
	var list := UIK.vbox(3)
	body.add_child(UIK.scroll(list, Vector2(400, 176 if mode == "load" else 156)))
	var rows := SaveSystem.save_list()
	if rows.is_empty():
		list.add_child(UIK.label("No saved games yet.", 8, Art.C_MUTED))
	for r in rows:
		list.add_child(_row(int(r["slot"]), r["summary"]))
	if confirm >= 0:
		var sm := SaveSystem.summary(confirm)
		var q := UIK.label(I18n.t("Replace %s (day %d)?") % [str(sm.get("name", "")), int(sm.get("day", 0))], 8, Art.C_GOLD, true)
		q.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		footer.add_child(q)
		footer.add_child(UIK.expand())
		var yes := UIK.button("Replace", _replace.bind(confirm), "primary")
		yes.name = "ConfirmReplace"
		footer.add_child(yes)
		footer.add_child(UIK.button("Cancel", func(): confirm = -1; rebuild()))
	else:
		footer.add_child(UIK.button("Close", close))


func _row(slot: int, sm: Dictionary) -> Control:
	var h := UIK.hbox(6)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var who := str(sm.get("name", ""))
	var co := str(sm.get("company", ""))
	if co != "" and not co.begins_with(who):   # a personal seller's "company" is just their own name
		who += "  ·  " + co
	var top := UIK.label(who, 8, Art.C_WHITE, true)
	top.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(top)
	var here := slot == SaveSystem.current_slot() and GameState.has_game() and SceneRouter.world_scene() != null
	var line := I18n.t("Day %d · personal %s") % [int(sm.get("day", 0)), Fmt.money0(float(sm.get("cash", 0)))]
	if here:
		line += "  ·  " + I18n.t("this game")
	v.add_child(UIK.label(line, 7, Art.C_GOLD if here else Art.C_MUTED))
	v.add_child(UIK.label((I18n.t("Saved %s") % _when(float(sm.get("saved_unix", 0)))) + "  ·  " + (I18n.t("slot %d") % slot), 6, Art.C_DIM))
	var b: Button
	if mode == "load":
		b = UIK.button("Load", _load.bind(slot), "primary", 64)
		b.name = "Load_%d" % slot
	else:
		b = UIK.button("Replace", func(): confirm = slot; rebuild(), "", 64)
		b.name = "Replace_%d" % slot
	h.add_child(b)
	return UIK.card(h)


## Real-world time of a save, in the player's time zone: "2026-09-29 14:05".
static func _when(unix: float) -> String:
	if unix <= 0.0:
		return "—"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)
	return "%04d-%02d-%02d %02d:%02d" % [d["year"], d["month"], d["day"], d["hour"], d["minute"]]


func _load(slot: int) -> void:
	close()
	SaveSystem.load_and_enter(slot)


func _replace(slot: int) -> void:
	SaveSystem.next_slot = slot
	close()
	SceneRouter.go_creator()
