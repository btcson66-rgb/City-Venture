extends RefCounted
var runner

func test_release_browser_probe_parses() -> void:
	# This opt-in script is loaded only in Web releases; editor import alone does not compile it.
	var script: GDScript = load("res://scripts/qa/web_smoke_probe.gd")
	runner.check(script.can_instantiate(), "release-only browser probe compiles")
	if script.can_instantiate():
		var probe: Node = script.new()
		probe.free()

func test_interior_decoration_does_not_swallow_touch_navigation() -> void:
	GameState.new_game({"name": "Touch regression", "seed": 167})
	var room := Interior.new()
	room.build("riverside_apartment")
	_check_decoration(room)
	room.free()

func _check_decoration(node: Node) -> void:
	if node is ColorRect:
		runner.eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "world decoration passes touch to navigation")
	for child in node.get_children():
		_check_decoration(child)
func test_touch_enters_home_using_normal_physics_and_door_trigger() -> void:
	UIRoot.close_all()
	UIRoot._pending_reports.clear() # Simulation suites can queue month-close screens across fresh games.
	UIRoot.dialogue.active = false
	UIRoot.dialogue_queue.clear()
	SceneRouter.transitioning = false
	Help.auto = false
	UIRoot.tutorial.st()["off"] = true
	Clock.clear_pauses()
	SceneRouter._enter("district", "riverside", "door_riverside_apartment", "down")
	for i in 3: await runner.get_tree().process_frame
	var world := SceneRouter.world_scene()
	var before := Ledger.cash("player")
	InputAccess._walk_touch(world.player, world.spawns["door_riverside_apartment"] - Vector2(0, 20))
	runner.check(not world.player.click_route.is_empty(), "touch creates a physical walking route")
	await runner.get_tree().create_timer(2.0).timeout
	runner.eq(SceneRouter.world_scene().scene_id, "riverside_apartment", "touch reaches the doorway trigger")
	runner.eq(Ledger.cash("player"), before, "navigation does not change cash")
	SceneRouter._set_scene(Node.new())
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
func test_locked_web_audio_does_not_start_an_empty_layer_tween() -> void:
	var old_headless := Sound._headless
	var old_unlocked := Sound._audio_unlocked
	var old_context := Sound._context_kind
	var old_intensity := Sound._intensity
	Sound._headless = false
	Sound._audio_unlocked = false
	Sound._context_kind = ""
	Sound._intensity = -1
	Sound._process(2.0)
	runner.check(not is_instance_valid(Sound._layer_tween), "no empty tween while browser audio awaits a gesture")
	Sound._headless = old_headless
	Sound._audio_unlocked = old_unlocked
	Sound._context_kind = old_context
	Sound._intensity = old_intensity
func test_touch_notification_summary_and_full_detail_fit_the_painted_screen() -> void:
	var old_touch := InputAccess.touch_mode
	InputAccess.touch_mode = true
	Bank.book_appointment()
	UIRoot.phone.open()
	UIRoot.phone._go("messages")
	for i in 8: await runner.get_tree().process_frame
	var message: Dictionary = GameState.data["messages"].back()
	var label := UIRoot.phone.find_child("NotificationText_" + str(message["id"]), true, false) as Label
	runner.check(label != null, "appointment text exists")
	if label != null:
		runner.eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "card summary stays one line")
		runner.check(label.size.x <= UIRoot.phone.screen.size.x + 1, "text width %s fits inside screen %s" % [label.size.x, UIRoot.phone.screen.size.x])
	UIRoot.phone.open_notification(str(message["id"]))
	for i in 8:await runner.get_tree().process_frame
	var full := UIRoot.phone.find_child("NotificationFullText_" + str(message["id"]), true, false) as Label
	runner.check(full != null, "selected message has complete detail")
	if full != null:
		runner.eq(full.text, message["text"], "full appointment preserves all text")
		runner.check(full.get_line_count() > 1 and full.size.x <= UIRoot.phone.screen.size.x + 1, "full text wraps inside painted screen")
	runner.eq(UIRoot.phone.screen.position, Vector2(9,18) * UIRoot.phone.frame.scale, "frame and content use the same inset")
	UIRoot.phone.close()
	InputAccess.touch_mode = old_touch

func test_phone_arrival_reduced_motion_cancels_owned_tween() -> void:
	var prior: bool = Preferences.values.get("reduce_motion", false)
	UIRoot.set_hud_visible(true)
	Preferences.values["reduce_motion"] = false
	UIRoot.hud.pulse_phone()
	var first: Tween = UIRoot.hud.phone_pulse
	UIRoot.hud.pulse_phone(true)
	runner.check(not first.is_running(), "new arrival replaces prior animation")
	Preferences.values["reduce_motion"] = true
	UIRoot.hud.pulse_phone()
	runner.check(UIRoot.hud.phone_pulse == null, "reduced motion has no animation")
	runner.eq(UIRoot.hud.phone_btn.scale, Vector2.ONE, "reduced motion restores original size")
	Preferences.values["reduce_motion"] = prior
	UIRoot.set_hud_visible(false)

func test_notification_back_keeps_filter_scroll_and_missing_id_recovers() -> void:
	UIRoot.phone.close()
	for i in 20:GameState.add_message("maya", "Full informational message %d" % i)
	var id: String = GameState.data["messages"].back()["id"]
	var journal: Variant = GameState.data["ledger"].duplicate(true)
	UIRoot.phone.open()
	UIRoot.phone._go("messages")
	UIRoot.phone._set_filter("life")
	for i in 8:await runner.get_tree().process_frame
	UIRoot.phone._scroll().scroll_vertical = 100
	var saved_scroll: int = UIRoot.phone._scroll().scroll_vertical
	UIRoot.phone.open_notification(id)
	for i in 4:await runner.get_tree().process_frame
	runner.check(UIRoot.phone.find_child("NotificationGo_"+id, true, false) == null, "informational detail has no forced action")
	UIRoot.phone._notifications_back()
	for i in 8:await runner.get_tree().process_frame
	runner.eq(UIRoot.phone.notification_filter, "life", "back keeps selected category")
	runner.eq(UIRoot.phone._scroll().scroll_vertical, saved_scroll, "back restores actual scroll")
	UIRoot.phone.open_notification("removed-old-id")
	for i in 4:await runner.get_tree().process_frame
	runner.check(UIRoot.phone.find_child("NotificationsBack", true, false) != null, "removed message has recovery back")
	UIRoot.phone._notifications_back()
	runner.eq(GameState.data["ledger"], journal, "details and recovery never change journal")
	UIRoot.phone.close()

func test_open_merged_card_refreshes_content_read_state_and_badge() -> void:
	UIRoot.phone.close()
	GameState.add_message("shoplane", "First actual order", {"merge":"open-card-test", "target":{"kind":"company", "tab":"operations"}})
	var id: String = GameState.data["messages"].back()["id"]
	UIRoot.phone.open()
	UIRoot.phone._go("messages")
	UIRoot.phone.open_notification(id)
	GameState.add_message("shoplane", "Second actual order", {"merge":"open-card-test", "target":{"kind":"company", "tab":"operations"}})
	for i in 8:await runner.get_tree().process_frame
	var full := UIRoot.phone.find_child("NotificationFullText_"+id, true, false) as Label
	runner.eq(full.text, PhoneMessages.get_message(id)["text"], "open detail shows actual merged content")
	runner.check(PhoneMessages.get_message(id)["read"], "visible merged content is read")
	runner.check(not UIRoot.hud.phone_hint.visible, "badge refresh follows visible read state")
	UIRoot.phone.close()
