class_name PhoneUI
extends Control
## The player's phone: messages, bank balances, tasks, maps, seller notifications, timeline, save.
## Management actions are NOT here — Company OS needs a terminal (Handoff §52).

var is_open := false
var frame: TextureRect
var screen: Control
var content: VBoxContainer
var app := "home"
var notification_filter := "all"
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


func open() -> void:
	is_open = true
	visible = true
	var holder := get_child(0) as Control
	holder.position.x = maxf(8.0, get_viewport_rect().size.x - 162.0)
	screen.size.y = maxf(80.0, minf(214.0, get_viewport_rect().size.y - 54.0))
	var scroll := screen.get_child(0) as ScrollContainer
	scroll.custom_minimum_size.y = screen.size.y
	scroll.size.y = screen.size.y
	app = "home"
	_player_pose("phone")
	GameState.set_flag("phone_opened")
	_render()
	var h: Control = get_child(0)
	h.position.y = get_viewport_rect().size.y
	create_tween().tween_property(h, "position:y", maxf(8.0, minf(56.0, get_viewport_rect().size.y - 250.0)), 0.18)


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
	if is_open and (event.is_action_pressed("pause") or event.is_action_pressed("cancel")):
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
		b.custom_minimum_size = Vector2(24, 24)
		h.add_child(b)
	h.add_child(UIK.title(t, 10))
	content.add_child(h)
	if app == "messages":
		var tools := UIK.hbox(3)
		tools.add_child(UIK.tip("notifications"))
		var help := UIK.button("?", func(): Help.open("phone_messages"))
		help.name = "PhoneMessagesHelp"
		help.custom_minimum_size = Vector2(24, 24)
		tools.add_child(help)
		content.add_child(tools)



func _render() -> void:
	UIK.clear(content)
	match app:
		"home":
			_home()
		"messages":
			_messages()
		"bank":
			_bank()
		"tasks":
			_tasks()
		"legacy":
			UIRoot.open_modal(LegacyModal.new())
			_go("home")
		"opportunities":
			_opportunities()
		"shoplane":
			_shoplane()
		"timeline":
			_timeline()
		"news":
			_news()
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
	var apps := [["messages", "mail", I18n.t("Notifications") + (" %d" % unread if unread > 0 else "")], ["bank", "bank", "Bank"], ["tasks", "tasks", "Tasks"],
		["map", "map", "City"], ["shoplane", "orders", "ShopLane"], ["timeline", "calendar", "Timeline"],
		["leases", "home", "Leases"], ["relationships", "people", "Relationships"], ["tax_filing", "finance", "Tax Filing"], ["news", "mail", "City news"], ["guide", "info", "City Guide"], ["opportunities", "tasks", "Opportunities"], ["save", "save", "Save"], ["close", "close", "Close"]]
	if GameState.flag("consolidation_started") or GameState.flag("legacy_invited"):
		apps.insert(apps.size() - 1, ["legacy", "company", "Legacy"])
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
		"relationships":
			close()
			UIRoot.open_modal(ContactsModal.new())
		"tax_filing":
			close()
			Industries.run_action("tax_filing",{},self)
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


func _opportunities() -> void:
	_header("Opportunities")
	content.add_child(UIK.label_tip("Side stories", "side_stories"))
	var help := UIK.button("?", func(): Help.open("phone_opportunities"))
	help.name = "OpportunitiesHelp"
	content.add_child(help)
	var available := StoryEngine.available_side_stories()
	if available.is_empty():
		content.add_child(UIK.wrap("No new opportunities right now. Check again after your company grows.", 7, Art.C_MUTED, 128))
	for i in available.size():
		var d: Dictionary = available[i]
		content.add_child(UIK.wrap(str(d.get("title", "")), 8, Art.C_WHITE, 128))
		content.add_child(UIK.wrap(str(d.get("text", "")), 7, Art.C_MUTED, 128))
		var id := str(d["id"])
		var b := UIK.button("Accept opportunity", func():
			StoryEngine.start_side_story(id)
			_render(), "primary" if i == 0 else "")
		b.name = "AcceptOpportunity_" + id
		content.add_child(b)


func _set_filter(value: String) -> void:
	notification_filter = value
	_render()

func _messages() -> void:
	_header(I18n.t("Notifications"))
	GameState.set_flag("notifications_read")
	var filters := GridContainer.new()
	filters.columns = 2
	for option in [["all", "All"], ["work", "Work"], ["life", "Life"], ["city", "City"]]:
		var button := UIK.button(I18n.t(option[1]), _set_filter.bind(option[0]), "tab_active" if notification_filter == option[0] else "normal")
		button.name = "NotificationFilter_" + option[0]
		button.custom_minimum_size.y = 24
		filters.add_child(button)
	content.add_child(filters)
	var all_read := UIK.button(I18n.t("Mark all read"), func():PhoneMessages.read_all();_render())
	all_read.name = "NotificationsReadAll"
	all_read.custom_minimum_size.y = 24
	content.add_child(all_read)
	PhoneMessages.S()
	var rows: Array = GameState.data["messages"].duplicate()
	rows.reverse()
	for message in rows:
		if notification_filter != "all" and PhoneMessages.category(message) != notification_filter:continue
		var row := UIK.vbox(2)
		row.name = "Notification_" + str(message["id"])
		var heading := UIK.hbox(3)
		heading.add_child(UIK.icon(str(message.get("icon", "mail")), 10))
		heading.add_child(UIK.label(PhoneMessages.contact_name(str(message["from"])), 7, Art.C_SKY))
		row.add_child(heading)
		var line := UIK.label(I18n.t(str(message["text"])).replace("\n", " "), 7, Art.C_WHITE)
		line.custom_minimum_size.x = 118
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.tooltip_text = I18n.t(str(message["text"]))
		row.add_child(line)
		row.add_child(UIK.label(Clock.fmt_short(int(message["t"])), 6, Art.C_DIM))
		if PhoneMessages.actionable(message):
			var go := UIK.button(I18n.t("Go"), PhoneMessages.go.bind(str(message["id"])))
			go.name = "NotificationGo_" + str(message["id"])
			go.custom_minimum_size.y = 24
			row.add_child(go)
		content.add_child(row)
		content.add_child(UIK.sep())


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
var timeline_filter := "all"
var timeline_year := -1


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
	var filters := UIK.vbox(1)
	content.add_child(filters)
	var picker := OptionButton.new()
	picker.name = "TimelineCategory"
	var categories := ["all", "company", "life", "people", "crisis", "milestones"]
	var labels := ["All events", "Company", "Life", "Contacts", "Crises", "Milestones"]
	for label in labels: picker.add_item(I18n.t(label))
	picker.select(categories.find(timeline_filter))
	picker.item_selected.connect(func(index): timeline_filter = categories[index]; _render())
	filters.add_child(picker)
	var years := [-1]
	for entry in GameState.data["timeline"]:
		var year := int(Clock.date_at(int(entry["t"]))["year"])
		if not year in years: years.append(year)
	var year_picker := OptionButton.new()
	year_picker.name = "TimelineYear"
	for year in years: year_picker.add_item(I18n.t("All years") if year == -1 else I18n.t("Year %d") % year)
	year_picker.select(maxi(0, years.find(timeline_year)))
	year_picker.item_selected.connect(func(index): timeline_year = years[index]; _render())
	filters.add_child(year_picker)
	var tl: Array = LifeLegacy.events(timeline_filter, timeline_year)
	var shown_year := -1
	for i in tl.size():
		var year := int(Clock.date_at(int(tl[i]["t"]))["year"])
		if year != shown_year:
			content.add_child(UIK.label(I18n.t("Year %d") % year, 8, Art.C_GOLD, true))
			shown_year = year
		var e: Dictionary = tl[i]
		var milestone: bool = str(e.get("kind", "")) == "milestone"
		var art := str(e.get("art", ""))
		if art != "" and Art.has_tex(art):
			var thumb := TextureRect.new()
			thumb.texture = Art.opt_tex(art)
			thumb.custom_minimum_size = Vector2(112, 48)
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			content.add_child(thumb)
		content.add_child(UIK.label(("★ " if milestone else "") + Clock.fmt_short(int(e["t"])), 6, Art.C_GOLD))
		content.add_child(UIK.wrap(str(e["text"]), 7, Art.C_GOLD if milestone else Art.C_WHITE, 124))


## Five milestones per industry (data/milestones.json): unlocked ones with their date, locked ones with progress.
func _achievements() -> void:
	var story := UIK.button("Main-story achievements", func(): UIRoot.open_modal(GrowthModal.new("achievements")))
	story.name = "OpenStoryAchievements"
	content.add_child(story)
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


func _news() -> void:
	_header("City news")
	content.add_child(UIK.label_tip("Market conditions", "macro_cycle", 7))
	var items: Array = CityNews.S()["items"]
	for index in range(items.size() - 1, -1, -1):
		content.add_child(UIK.label(Clock.fmt_short(int(items[index]["t"])), 6, Art.C_GOLD))
		content.add_child(UIK.wrap(str(items[index]["text"]), 7, Art.C_WHITE, 124))
