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
var content_width := 132.0
var chrome: HBoxContainer
var selected_notification := ""
var list_scroll := 0
var refresh_queued := false


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
	chrome = UIK.hbox(4)
	chrome.name = "PhoneChrome"
	screen.add_child(chrome)
	chrome.minimum_size_changed.connect(_layout_content)
	content = UIK.vbox(6)
	content.size = screen.size
	content.custom_minimum_size = Vector2(132, 0)
	var sc := UIK.scroll(content, Vector2(132, 214))
	sc.size = Vector2(132, 214)
	sc.custom_minimum_size = Vector2.ZERO
	screen.add_child(sc)
	get_viewport().size_changed.connect(func():
		if is_open:_fit_phone())
	EventBus.messages_changed.connect(_messages_changed)
	Clock.minute_tick.connect(_relative_times)


func open() -> void:
	is_open = true
	visible = true
	_fit_phone()
	var holder := get_child(0) as Control
	var available := get_viewport_rect().size
	app = "home"
	_player_pose("phone")
	GameState.set_flag("phone_opened")
	_render()
	var h: Control = get_child(0)
	h.position.y = get_viewport_rect().size.y
	create_tween().tween_property(h, "position:y", maxf(8.0, minf(56.0, available.y - holder.size.y - 8)), 0.18)


func _scroll() -> ScrollContainer:return content.get_parent() as ScrollContainer

func _fit_phone() -> void:
	var holder := get_child(0) as Control
	var available := get_viewport_rect().size
	var touch := InputAccess.touch_mode
	holder.size = Vector2(minf(620, available.x - 16), available.y - 16) if touch else Vector2(260, 330).min(available - Vector2(16, 16))
	holder.position.x = maxf(8.0, available.x - holder.size.x - 12.0)
	holder.position.y = maxf(8.0, minf(56.0, available.y - holder.size.y - 8))
	var frame_scale := holder.size / Vector2(150, 250)
	screen.position = Vector2(9, 18) * frame_scale
	screen.size = Vector2(132, 214) * frame_scale
	content_width = screen.size.x - 14.0
	frame.scale = holder.size / Vector2(150, 250)
	var background := holder.get_child(0) as ColorRect
	background.position = Vector2(7, 16) * frame_scale
	background.size = Vector2(136, 218) * frame_scale
	content.custom_minimum_size.x = content_width
	content.size.x = content_width
	var scroll := _scroll()
	scroll.custom_minimum_size = Vector2.ZERO
	_layout_content()

func _layout_content() -> void:
	if not is_instance_valid(chrome) or not is_instance_valid(content):return
	var height := maxf(44 if InputAccess.touch_mode else 24, chrome.get_combined_minimum_size().y)
	chrome.size = Vector2(screen.size.x, height)
	var scroll := _scroll()
	scroll.position = Vector2(0, height + 4)
	scroll.size = Vector2(screen.size.x, maxf(40, screen.size.y - height - 4))
	content.custom_minimum_size.x = maxf(40, content_width)



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
		if app == "message_detail":
			_notifications_back()
		elif app == "home":
			close()
		else:
			_go("home")


func _go(a: String) -> void:
	app = a
	selected_notification = ""
	_scroll().scroll_vertical = 0
	_render()


func _header(t: String, back := true) -> void:
	var h := UIK.hbox(4)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if back:
		var button := UIK.button("‹", _notifications_back if app == "message_detail" else _go.bind("home"))
		button.name = "NotificationsBack" if app == "message_detail" else "PhoneHomeBack"
		button.tooltip_text = I18n.t("Back to notifications") if app == "message_detail" else I18n.t("Back")
		button.custom_minimum_size = Vector2(24, 24)
		h.add_child(button)
	var title := UIK.title(t, 10)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(title)
	if app in ["messages", "message_detail"]:
		var help := UIK.button("?", func():Help.open("phone_messages"))
		help.name = "PhoneMessagesHelp"
		help.custom_minimum_size = Vector2(24, 24)
		h.add_child(help)
	chrome.add_child(h)


func _render() -> void:
	displayed_minute = Clock.now()
	UIK.clear(content)
	UIK.clear(chrome)
	match app:
		"home":
			_home()
		"messages":
			_messages()
		"message_detail":
			_notification_detail()
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
	var close_button := UIK.button("×", close)
	close_button.name = "PhoneClose"
	close_button.tooltip_text = I18n.t("Close")
	close_button.custom_minimum_size = Vector2(24, 24)
	chrome.add_child(close_button)
	_layout_content.call_deferred()


func _home() -> void:
	FeatureGate.refresh()
	var top := UIK.hbox(2)
	top.add_child(UIK.label(Clock.fmt_time(), 7, Art.C_MUTED, true))
	top.add_child(UIK.expand())
	top.add_child(UIK.label(Clock.fmt_date(), 7, Art.C_MUTED))
	content.add_child(top)
	content.add_child(UIK.title(GameState.data["player"]["name"], 11))
	var grid := GridContainer.new()
	grid.columns = (1 if int(Preferences.values["font_size"]) >= 2 else 2) if InputAccess.touch_mode else 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var unread := GameState.unread_messages()
	var apps := [["messages", "mail", I18n.t("Notifications") + (" %d" % unread if unread > 0 else "")], ["bank", "bank", "Bank"], ["tasks", "tasks", "Tasks"],
		["map", "map", "City"], ["shoplane", "orders", "ShopLane"], ["timeline", "calendar", "Timeline"],
		["leases", "home", "Leases"], ["relationships", "people", "Relationships"], ["tax_filing", "finance", "Tax Filing"], ["news", "mail", "City news"], ["guide", "info", "City Guide"], ["opportunities", "tasks", "Opportunities"], ["save", "save", "Save"], ["close", "close", "Close"]]
	apps.insert(apps.size() - 2, ["assistant", "people", "Assistant"])
	if GameState.flag("consolidation_started") or GameState.flag("legacy_invited"):
		apps.insert(apps.size() - 1, ["legacy", "company", "Legacy"])
	if BuildingInfo.world_travel_available():
		apps.insert(apps.size() - 1, ["world", "world", "World"])
	for a in apps:
		if not FeatureGate.unlocked("app_"+str(a[0])):continue
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
	var next := FeatureGate.preview(apps.map(func(a):return "app_"+str(a[0])))
	if next != "":
		var item := FeatureGate.definition(next)
		var preview := UIK.button("🔒 " + I18n.t(str(item["label"])))
		preview.name = "AppPreview"
		preview.disabled = true
		content.add_child(preview)
		content.add_child(UIK.wrap(I18n.t(str(item["hint"])),7,Art.C_DIM,128))
	content.add_child(grid)
	var pend := EventEngine.pending()
	if not pend.is_empty():
		content.add_child(UIK.sep())
		var t := UIK.wrap(I18n.t("◆ %s needs a decision") % I18n.t(DataDB.events[pend[0]["id"]].get("presentation", {}).get("title", "Something")), 7, Art.C_GOLD, 128)
		content.add_child(t)
		content.add_child(UIK.button("Respond", func(): close(); UIRoot.show_decision(EventEngine.next_pending()), "primary"))


func _open_app(a: String) -> void:
	if not FeatureGate.unlocked("app_"+a):return
	FeatureGate.viewed("app_"+a)
	match a:
		"assistant":
			close()
			UIRoot.open_modal(AssistantModal.new())
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


## Daily merged orders change the row without replaying arrival sounds for every order.
func _messages_changed() -> void:
	if not is_open or app not in ["messages", "message_detail"] or refresh_queued:return
	refresh_queued = true
	_refresh_messages.call_deferred()

func _refresh_messages() -> void:
	refresh_queued = false
	if not is_open:return
	if app == "messages":
		list_scroll = _scroll().scroll_vertical
		_render()
		_restore_list_scroll.call_deferred()
	elif app == "message_detail":
		var message := PhoneMessages.read(selected_notification)
		var label := content.find_child("NotificationFullText_" + selected_notification, true, false) as Label
		if label != null:label.text = I18n.t(str(message.get("text", "")))

func _relative_times(t: int) -> void:
	if not is_open or app != "messages":return
	if Clock.day_index_at(t) != Clock.day_index_at(displayed_minute):
		_messages_changed()
		return
	for message in GameState.data.get("messages", []):
		var label := content.find_child("NotificationTime_" + str(message.get("id", "")), true, false) as Label
		if label != null:label.text = PhoneMessages.relative_time(int(message.get("t", 0)))
	displayed_minute = t

func _set_filter(value: String) -> void:
	notification_filter = value
	list_scroll = 0
	_scroll().scroll_vertical = 0
	_render()


## Every notification has a detail page, including information with no Go destination.
func open_notification(id: String) -> void:
	list_scroll = _scroll().scroll_vertical
	selected_notification = id
	PhoneMessages.read(id)
	app = "message_detail"
	_scroll().scroll_vertical = 0
	_render()
	UIRoot.hud.refresh()


func _notifications_back() -> void:
	selected_notification = ""
	app = "messages"
	_render()
	_restore_list_scroll.call_deferred()


func _restore_list_scroll() -> void:
	await get_tree().process_frame
	if app == "messages":_scroll().scroll_vertical = list_scroll


func _avatar(message: Dictionary, extent := 32.0) -> PortraitView:
	var avatar := PortraitView.new()
	avatar.custom_minimum_size = Vector2(extent, extent)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var sender := str(message.get("from", ""))
	var person := DataDB.npc("maya" if sender == "assistant" else sender)
	if not person.is_empty() and person.has("appearance"):
		var tints := {}
		for key in person.get("outfit_tints", {}):tints[key] = Color(person["outfit_tints"][key])
		avatar.setup_character(person["appearance"], person.get("outfit", "casual_tee"), tints, "maya" if sender == "assistant" else sender)
	else:avatar.setup_icon(str(message.get("icon", "mail")))
	UIK.ignore_mouse(avatar)
	return avatar


func _messages() -> void:
	_header(I18n.t("Notifications"))
	GameState.set_flag("notifications_read")
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 4)
	filters.add_theme_constant_override("v_separation", 4)
	for option in [["all", "All"], ["work", "Work"], ["life", "Life"], ["city", "City"]]:
		var active: bool = notification_filter == option[0]
		var button := UIK.button(I18n.t(option[1]), _set_filter.bind(option[0]))
		button.name = "NotificationFilter_" + option[0]
		button.custom_minimum_size.y = 24
		button.add_theme_stylebox_override("normal", UIK.flat(Art.C_BLUE_DARK if active else Art.C_NAVY_700, Art.C_SKY if active else Art.C_NAVY_500, 1, 12))
		button.add_theme_stylebox_override("hover", UIK.flat(Art.C_NAVY_500, Art.C_SKY, 1, 12))
		button.add_theme_stylebox_override("pressed", UIK.flat(Art.C_BLUE_DARK, Art.C_SKY, 1, 12))
		filters.add_child(button)
	content.add_child(filters)
	var all_read := UIK.button(I18n.t("Mark all read"), func():PhoneMessages.read_all();_render();UIRoot.hud.refresh())
	all_read.name = "NotificationsReadAll"
	all_read.custom_minimum_size.y = 24
	content.add_child(all_read)
	PhoneMessages.S()
	var rows: Array = GameState.data["messages"].filter(func(m):return notification_filter == "all" or PhoneMessages.category(m) == notification_filter)
	rows.sort_custom(func(a, b):return int(a.get("t", 0)) > int(b.get("t", 0)))
	if rows.is_empty():
		content.add_child(UIK.icon("mail", 24))
		content.add_child(UIK.wrap("No news right now. Go enjoy the city!", 8, Art.C_MUTED, 0))
		return
	var previous := -1
	for message in rows:
		var day := Clock.day_index_at(maxi(0, int(message.get("t", 0))))
		if day != previous:
			content.add_child(UIK.label(PhoneMessages.group_label(int(message.get("t", 0))), 7, Art.C_SKY, true))
			previous = day
		content.add_child(_notification_card(message))


func _notification_card(message: Dictionary) -> Button:
	var id := str(message["id"])
	var card := UIK.button("", open_notification.bind(id))
	card.name = "Notification_" + id
	card.tooltip_text = I18n.t("Open message")
	card.custom_minimum_size = Vector2(0, 58)
	var unread: bool = not bool(message.get("read", false))
	card.add_theme_stylebox_override("normal", UIK.flat(Art.C_NAVY_700 if unread else Art.C_NAVY_800, Art.C_NAVY_500, 1, 5))
	card.add_theme_stylebox_override("hover", UIK.flat(Art.C_NAVY_600, Art.C_SKY, 1, 5))
	card.add_theme_stylebox_override("pressed", UIK.flat(Art.C_NAVY_500, Art.C_SKY, 1, 5))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:margin.add_theme_constant_override("margin_" + side, 6)
	card.add_child(margin)
	var row := UIK.hbox(6)
	margin.add_child(row)
	row.add_child(_avatar(message, 48 if InputAccess.touch_mode else 30))
	var words := UIK.vbox(3)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := UIK.hbox(3)
	var title := UIK.label(I18n.t(str(message.get("title", PhoneMessages.contact_name(str(message.get("from", "")))))), 8, Art.C_WHITE if unread else Art.C_MUTED, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.name = "NotificationTitle_" + id
	heading.add_child(title)
	var time := UIK.label(PhoneMessages.relative_time(int(message.get("t", 0))), 6, Art.C_MUTED)
	time.name = "NotificationTime_" + id
	heading.add_child(time)
	words.add_child(heading)
	var line := UIK.label(I18n.t(str(message.get("text", ""))).replace("\n", " "), 7, Art.C_WHITE if unread else Art.C_MUTED)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.clip_text = true
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.name = "NotificationText_" + id
	words.add_child(line)
	row.add_child(words)
	if unread:
		var dot := UIK.label("●", 6, Art.C_BLUE)
		dot.name = "NotificationUnread_" + id
		row.add_child(dot)
	UIK.ignore_mouse(margin)
	row.minimum_size_changed.connect(func():card.custom_minimum_size.y = maxf(58, row.get_combined_minimum_size().y + 12))
	return card


func _notification_detail() -> void:
	_header(I18n.t("Message"))
	var message := PhoneMessages.get_message(selected_notification)
	if message.is_empty():
		content.add_child(UIK.wrap("This message is no longer here. Go back to your notifications.", 8, Art.C_MUTED, 0))
		return
	var sender := UIK.hbox(6)
	sender.add_child(_avatar(message, 48))
	var name := UIK.wrap(PhoneMessages.contact_name(str(message.get("from", ""))), 9, Art.C_SKY, 0)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sender.add_child(name)
	content.add_child(sender)
	content.add_child(UIK.wrap(Clock.fmt_datetime(int(message.get("t", 0))), 7, Art.C_MUTED, 0))
	content.add_child(UIK.sep())
	var full := UIK.wrap(I18n.t(str(message.get("text", ""))), 9, Art.C_WHITE, 0)
	full.name = "NotificationFullText_" + selected_notification
	content.add_child(full)
	if PhoneMessages.actionable(message):
		var go := UIK.button(I18n.t("Go"), PhoneMessages.go.bind(selected_notification), "primary")
		go.name = "NotificationGo_" + selected_notification
		go.custom_minimum_size.y = 24
		content.add_child(go)


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
	for o in StoryEngine.active_objectives().slice(0,3):
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
