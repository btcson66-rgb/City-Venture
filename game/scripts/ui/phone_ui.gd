class_name PhoneUI
extends Control
## The player's phone: messages, bank balances, tasks, maps, seller notifications, timeline, save.
## Management actions are NOT here — Company OS needs a terminal (Handoff §52).

var is_open := false
var frame: TextureRect
var screen: Control
var content: VBoxContainer
var app := "home"
var thread_with := ""
var displayed_minute := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var holder := Control.new()
	holder.position = Vector2(470, 56)
	holder.size = Vector2(150, 250)
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)
	var bg := ColorRect.new()
	bg.color = Color8(16, 26, 44)
	bg.position = Vector2(7, 16)
	bg.size = Vector2(136, 218)
	holder.add_child(bg)
	screen = Control.new()
	screen.position = Vector2(9, 18)
	screen.size = Vector2(132, 214)
	screen.clip_contents = true
	holder.add_child(screen)
	frame = TextureRect.new()
	frame.texture = Art.tex("ui/phone_frame")
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	content = UIK.vbox(3)
	content.size = screen.size
	content.custom_minimum_size = Vector2(132, 0)
	var sc := UIK.scroll(content, Vector2(132, 214))
	sc.size = Vector2(132, 214)
	screen.add_child(sc)


func _process(_delta: float) -> void:
	if not is_open or not GameState.has_game() or displayed_minute == Clock.now(): return
	displayed_minute = Clock.now()
	for label in content.find_children("ReplyDeadline", "Label", true, false):
		var deadline := int(label.get_meta("deadline"))
		label.text = I18n.t("Reply by %s · %d minutes remaining") % [Clock.fmt_datetime(deadline), maxi(0, deadline - Clock.now())]


func open() -> void:
	is_open = true
	visible = true
	app = "home"
	_player_pose("phone")
	GameState.set_flag("phone_opened")
	_render()
	var h: Control = get_child(0)
	h.position.y = 360
	create_tween().tween_property(h, "position:y", 56.0, 0.18)


func close() -> void:
	is_open = false
	visible = false
	_player_pose("")


## The player looks at their phone while it's open (once the pose art exists).
func _player_pose(p: String) -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.get("rig") is CharacterRig:
		(pl.rig as CharacterRig).set_pose(p)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if app == "home":
			close()
		else:
			_go("home")


func _go(a: String) -> void:
	app = a
	_render()


func _header(t: String, back := true) -> void:
	var h := UIK.hbox(3)
	if back:
		var b := UIK.button("‹", _go.bind("home"))
		b.custom_minimum_size = Vector2(14, 12)
		h.add_child(b)
	h.add_child(UIK.title(t, 10))
	content.add_child(h)


func _render() -> void:
	UIK.clear(content)
	match app:
		"home":
			_home()
		"messages":
			_messages()
		"thread":
			_thread()
		"contacts":
			_contacts()
		"agenda":
			_agenda()
		"bank":
			_bank()
		"tasks":
			_tasks()
		"shoplane":
			_shoplane()
		"timeline":
			_timeline()
		"save":
			_save()


func _home() -> void:
	var top := UIK.hbox(2)
	top.add_child(UIK.label(Clock.fmt_time(), 7, Art.C_MUTED, true))
	top.add_child(UIK.expand())
	top.add_child(UIK.label(Clock.fmt_date(), 7, Art.C_MUTED))
	content.add_child(top)
	content.add_child(UIK.title(GameState.data["player"]["name"], 11))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var unread := GameState.unread_messages()
	var apps := [["messages", "mail", I18n.t("Messages") + (" %d" % unread if unread > 0 else "")], ["bank", "bank", "Bank"], ["tasks", "tasks", "Tasks"],
		["contacts", "mail", "Contacts"], ["agenda", "calendar", "Agenda"], ["map", "map", "City"], ["shoplane", "orders", "ShopLane"], ["timeline", "calendar", "Timeline"],
		["leases", "home", "Leases"], ["guide", "info", "City Guide"], ["save", "save", "Save"], ["close", "close", "Close"]]
	if BuildingInfo.world_travel_available():
		apps.insert(apps.size() - 1, ["world", "world", "World"])
	for a in apps:
		var b := Button.new()
		b.custom_minimum_size = Vector2(40, 40)
		b.icon = Art.icon(a[1])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.text = a[2]
		b.add_theme_font_size_override("font_size", 6)
		b.focus_mode = Control.FOCUS_NONE
		b.name = "App_" + a[0]
		b.pressed.connect(_open_app.bind(a[0]))
		grid.add_child(b)
	content.add_child(grid)
	var pend := EventEngine.pending()
	if not pend.is_empty():
		content.add_child(UIK.sep())
		var t := UIK.wrap(I18n.t("◆ %s needs a decision") % I18n.t(DataDB.events[pend[0]["id"]].get("presentation", {}).get("title", "Something")), 7, Art.C_GOLD, 128)
		content.add_child(t)
		content.add_child(UIK.button("Respond", func(): close(); UIRoot.show_decision(EventEngine.next_pending()), "primary"))


func _open_app(a: String) -> void:
	match a:
		"leases":
			close()
			UIRoot.open_modal(LeaseEndModal.new())
		"guide":
			close()
			UIRoot.open_modal(CityGuideModal.new())
		"map":
			close()
			UIRoot.open_modal(CityMapModal.new(false))
		"world":
			close()
			UIRoot.open_modal(WorldMapModal.new())
		"close":
			close()
		_:
			_go(a)


func _senders() -> Array:
	var latest := {}
	for m in GameState.data["messages"]:
		latest[m["from"]] = m
	var arr: Array = latest.values()
	arr.sort_custom(func(a, b): return int(a["t"]) > int(b["t"]))
	return arr


func _messages() -> void:
	_header("Messages")
	for m in _senders():
		var from: String = m["from"]
		var unread: int = GameState.data["messages"].filter(func(x): return x["from"] == from and not x.get("read", false)).size()
		var b := UIK.button("", _open_thread.bind(from))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s%s\n%s" % [I18n.t(DataDB.npc(from).get("name", from)), "  (%d)" % unread if unread > 0 else "", Clock.fmt_short(int(m["t"])) + "\n" + I18n.t(str(m["text"])).left(26)]
		b.add_theme_font_size_override("font_size", 7)
		b.custom_minimum_size = Vector2(126, 24)
		b.name = "Thread_" + from
		content.add_child(b)


func _open_thread(from: String) -> void:
	thread_with = from
	for m in GameState.data["messages"]:
		if m["from"] == from:
			m["read"] = true
	_go("thread")


func _thread() -> void:
	_header(I18n.t(DataDB.npc(thread_with).get("name", thread_with)))
	for m in GameState.data["messages"]:
		if m["from"] != thread_with:
			continue
		var p := UIK.panel("ui/card", 3)
		var v := UIK.vbox(0)
		p.add_child(v)
		PhoneMessages.prepare(m)
		v.add_child(UIK.label((I18n.t("You") + " · " if m.get("direction", "incoming") == "outgoing" else "") + Clock.fmt_short(int(m["t"])), 6, Art.C_DIM))
		v.add_child(UIK.wrap(I18n.t(str(m["text"])), 7, Art.C_WHITE, 118))
		if m.has("expires") and not m.has("answered"):
			var deadline := UIK.wrap(I18n.t("Reply by %s · %d minutes remaining") % [Clock.fmt_datetime(int(m["expires"])), maxi(0, int(m["expires"]) - Clock.now())], 6, Art.C_GOLD, 118)
			deadline.name = "ReplyDeadline"
			deadline.set_meta("deadline", int(m["expires"]))
			v.add_child(deadline)
		for c in PhoneMessages.choices(m):
			var available := EventEngine.choice_available(c, PhoneMessages.context(m))
			var label := EventEngine.fill(str(c.get("label", c.get("text", "Okay, thanks."))), PhoneMessages.context(m))
			var button := UIK.button(("✓ " if available else "✗ ") + I18n.t(label), _reply.bind(str(m["id"]), str(c["id"])), "primary" if c.get("recommended", false) else "normal")
			button.name = "Reply_" + str(m["id"]) + "_" + str(c["id"])
			button.add_theme_font_size_override("font_size", 6)
			button.disabled = not available
			v.add_child(button)
			if not available: v.add_child(UIK.wrap(EventEngine.fill(str(c.get("detail", "Register a company at City Hall first." if "company_registered" in c.get("requires", []) else "Complete the reply's requirements first.")), PhoneMessages.context(m)), 6, Art.C_MUTED, 118))
		content.add_child(p)


func _reply(id: String, choice: String) -> void:
	var result := PhoneMessages.reply(id, choice)
	_render()
	if not result["ok"]: content.add_child(UIK.wrap(str(result["error"]), 7, Art.C_RED, 122))


func _contacts() -> void:
	_header("Contacts")
	for npc in PhoneMessages.contacts():
		content.add_child(UIK.title(I18n.t(DataDB.npc(npc).get("name", npc)), 8))
		for key in PhoneMessages.cfg().get("templates", {}):
			var template: Dictionary = PhoneMessages.cfg()["templates"][key]
			var remaining := maxi(0, int(PhoneMessages.S()["cooldowns"].get(str(npc) + ":" + str(key), 0)) - Clock.now())
			var available := remaining == 0 and Cond.all(template.get("requires", []))
			var button := UIK.button(("✓ " if available else "✗ ") + I18n.t(str(template["label"])), _send.bind(str(npc), str(key)))
			button.name = "Send_" + str(npc) + "_" + str(key)
			button.add_theme_font_size_override("font_size", 6)
			button.disabled = not available
			content.add_child(button)
			if remaining > 0: content.add_child(UIK.wrap(I18n.t("Wait %d minutes before messaging again.") % remaining, 6, Art.C_MUTED, 122))
			elif not available: content.add_child(UIK.wrap("Register a company at City Hall first.", 6, Art.C_MUTED, 122))


func _send(npc: String, template: String) -> void:
	var result := PhoneMessages.send(npc, template)
	if result["ok"]: thread_with = npc; _go("thread")
	else: _render(); content.add_child(UIK.wrap(str(result["error"]), 7, Art.C_RED, 122))


func _meeting_status(status: String) -> String:
	match status:
		"planned":
			return I18n.t("Meeting scheduled")
		"met":
			return I18n.t("Meeting completed")
		"missed":
			return I18n.t("Meeting missed")
	return status


func _agenda() -> void:
	_header("Agenda")
	for meeting in PhoneMessages.S()["agenda"]:
		content.add_child(UIK.wrap(I18n.t(DataDB.npc(meeting["npc"]).get("name", meeting["npc"])) + " · " + Clock.fmt_datetime(int(meeting["at"])), 7, Art.C_GOLD, 122))
		content.add_child(UIK.wrap(I18n.t(str(DataDB.building(str(meeting["location"]).get_slice(":", 1)).get("name", str(meeting["location"])))) + " · " + _meeting_status(str(meeting["status"])), 7, Art.C_MUTED, 122))
		if meeting["status"] == "planned":
			content.add_child(UIK.wrap("Go to the meeting location during its time window. The conversation starts when you arrive.", 6, Art.C_WHITE, 122))
		else: content.add_child(UIK.wrap("Book a new time from Contacts if needed.", 6, Art.C_WHITE, 122))


func _bank() -> void:
	_header("Nexus Bank")
	content.add_child(UIK.kv("Personal", Fmt.money0(Ledger.cash("player")), UIK.money_color(Ledger.cash("player")), 7, true))
	var be := GameState.business_entity()
	if be != "player":
		content.add_child(UIK.kv(GameState.entity_name(be).left(16), Fmt.money0(Ledger.cash(be)), UIK.money_color(Ledger.cash(be)), 7, true))
	var mb := Ledger.balance(be, "marketplace_balance")
	content.add_child(UIK.kv("ShopLane pending", Fmt.money0(mb), Art.C_GOLD, 7))
	content.add_child(UIK.label("Rent $1,250 due the 14th", 6, Art.C_DIM))
	content.add_child(UIK.sep())
	for e in Ledger.entries("player", 10):
		var c := Ledger.entry_cash(e)
		if absf(c) < 0.01:
			continue
		content.add_child(UIK.kv(SavedText.display(str(e["memo"])).left(20), Fmt.money0(c, true), UIK.money_color(c), 6))


func _tasks() -> void:
	if Bank.appointment_hint() != "":
		content.add_child(UIK.wrap(Bank.appointment_hint(), 7, Art.C_SKY, 122))
	_header("Tasks")
	var ch := StoryEngine.chapter_def(GameState.data["story"].get("chapter", ""))
	if not ch.is_empty():
		content.add_child(UIK.label(str(ch["title"]), 7, Art.C_GOLD, true))
	for o in StoryEngine.active_objectives():
		var h := UIK.hbox(3)
		h.add_child(UIK.icon("objective" if o.get("main", false) else "star", 10))
		h.add_child(UIK.wrap(o["text"], 7, Art.C_WHITE, 112))
		content.add_child(h)
	content.add_child(UIK.sep())
	var done: Array = GameState.data["story"]["done"]
	for i in range(done.size() - 1, maxi(-1, done.size() - 6), -1):
		var d := StoryEngine.objective_def(done[i])
		var h2 := UIK.hbox(3)
		h2.add_child(UIK.icon("check", 10))
		h2.add_child(UIK.wrap(StoryEngine.fill(d.get("text", "")), 6, Art.C_DIM, 112))
		content.add_child(h2)


func _shoplane() -> void:
	_header("ShopLane Seller")
	content.add_child(UIK.label("Notifications only.\nManage at a desk: Company OS.", 6, Art.C_DIM))
	var placed := Ecommerce.orders_with(["placed"]).size()
	var packed := Ecommerce.orders_with(["packed"]).size()
	var shipped := Ecommerce.orders_with(["shipped", "awaiting_pickup"]).size()
	content.add_child(UIK.kv("To pack", str(placed), Art.C_GOLD if placed > 0 else Art.C_WHITE, 7, true))
	content.add_child(UIK.kv("Packed, not shipped", str(packed), Art.C_WHITE, 7))
	content.add_child(UIK.kv("In transit", str(shipped), Art.C_WHITE, 7))
	content.add_child(UIK.kv("Month sales", Fmt.money0(Ecommerce.month_gmv()), Art.C_WHITE, 7))
	if Ecommerce.is_personal():
		content.add_child(UIK.kv("Personal cap", Fmt.money0(Ecommerce.seller_cap()), Art.C_GOLD, 7))
	content.add_child(UIK.sep())
	for l in GameState.data["ecommerce"]["listings"].values():
		var st := "live" if l["active"] else ("paused: cap" if l.get("paused_reason", "") == "seller_cap" else "paused")
		content.add_child(UIK.wrap("%s · %s · %s · %s" % [I18n.t(DataDB.product(l["product"])["name"]), Fmt.money0(l["price"]), Fmt.stars(Ecommerce.rating(l)), st], 6, Art.C_WHITE, 124))


var timeline_page := "life"


func _timeline() -> void:
	_header("Life Timeline")
	var tabs := UIK.hbox(2)
	content.add_child(tabs)
	for t in [["life", "Timeline"], ["achievements", "Achievements"]]:
		var tb := UIK.button(t[1], func(): timeline_page = t[0]; _render(), "tab_active" if timeline_page == t[0] else "tab")
		tb.name = "TimelinePage_" + t[0]
		tb.add_theme_font_size_override("font_size", 6)
		tabs.add_child(tb)
	if timeline_page == "achievements":
		_achievements()
		return
	var tl: Array = GameState.data["timeline"]
	for i in range(tl.size() - 1, -1, -1):
		var e: Dictionary = tl[i]
		var milestone: bool = str(e.get("kind", "")) == "milestone"
		content.add_child(UIK.label(("★ " if milestone else "") + Clock.fmt_short(int(e["t"])), 6, Art.C_GOLD))
		content.add_child(UIK.wrap(str(e["text"]), 7, Art.C_GOLD if milestone else Art.C_WHITE, 124))


## Five milestones per industry (data/milestones.json): unlocked ones with their date, locked ones with progress.
func _achievements() -> void:
	var total := Milestones.count()
	content.add_child(UIK.label(I18n.t("%d of %d reached") % [total[0], total[1]], 7, Art.C_SKY, true))
	for entry in Industries.all():
		var n := Milestones.count(entry["id"])
		content.add_child(UIK.label("%s  %d/%d" % [InternalSupply.industry_name(entry["id"]), n[0], n[1]], 7, Art.C_GOLD, true))
		for m in Milestones.list(entry["id"]):
			if Milestones.unlocked(m["id"]):
				content.add_child(UIK.wrap("✓ %s · %s" % [I18n.t(str(m["name"])), Clock.fmt_short(int(Milestones.S()["done"][m["id"]]))], 6, Art.C_GREEN, 124))
			else:
				var pr := Milestones.progress(m)
				content.add_child(UIK.wrap("✗ %s · %s" % [I18n.t(str(m["name"])), _progress_text(m, pr)], 6, Art.C_MUTED, 124))
				content.add_child(UIK.wrap(I18n.t(str(m["desc"])), 6, Art.C_DIM, 124))


static func _progress_text(m: Dictionary, pr: Dictionary) -> String:
	if pr["streak"]:
		return I18n.t("%d of %d days") % [int(pr["have"]), int(pr["target"])]
	if m.get("money", false):
		return "%s / %s" % [Fmt.money0(float(pr["have"])), Fmt.money0(float(pr["target"]))]
	if m.get("pct", false):
		return "%s / %s" % [Fmt.pct(float(pr["have"])), Fmt.pct(float(pr["target"]))]
	return "%d / %d" % [int(pr["have"]), int(pr["target"])]


func _save() -> void:
	_header("Save game")
	var b := UIK.button("Save now", func():
		SaveSystem.autosave()
		UIRoot.toast(I18n.t("Saved (slot %d).") % SaveSystem.current_slot(), "good", "save")
		_render(), "primary")
	b.name = "SaveNow"
	b.add_theme_font_size_override("font_size", 7)
	content.add_child(b)
	content.add_child(UIK.wrap(I18n.t("This game autosaves to slot %d every few seconds. A new game gets its own slot; load other games from the title screen.") % SaveSystem.current_slot(), 6, Art.C_DIM, 124))
