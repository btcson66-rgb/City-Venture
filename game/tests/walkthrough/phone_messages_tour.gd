extends RefCounted
var bot
func _init(b) -> void:bot = b
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name":"Alex Chen","seed":112})
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	# Explicit date fixtures to render all three groups; no simulation income is fabricated.
	GameState.data["clock"]["minutes"] += 2 * Clock.DAY
	SceneRouter._enter("district", "riverside", "door_home", "up")
	UIRoot.set_hud_visible(true)
	GameState.add_message("maya", "So you actually quit?")
	var maya: Dictionary = GameState.data["messages"].back()
	maya["t"] -= Clock.DAY
	GameState.add_message("city", "City news")
	GameState.data["messages"].back()["t"] -= 2 * Clock.DAY
	Bank.book_appointment()
	var message: Dictionary = GameState.data["messages"].back()
	UIRoot.phone.open()
	await bot.wait(.4)
	await bot.click_named("App_messages")
	await bot.wait(.2)
	bot.expect(UIRoot.toast_box.get_children().all(func(c):return not c.visible), "duplicate arrival toasts do not cover notification cards")
	bot.expect(GameState.flag("notifications_read"), "chapter one continues without replies")
	await bot.shot("notifications_cards_all")
	bot.expect(bot.button_named("NotificationGo_" + str(message["id"])) == null, "Go only appears after reading full detail")
	await bot.click_named("NotificationFilter_life")
	await bot.shot("notifications_cards_life")
	await bot.click_named("Notification_" + str(maya["id"]))
	await bot.wait(.2)
	await bot.shot("notification_information_full_detail")
	bot.expect(maya["read"] and UIRoot.phone.app == "message_detail", "informational card opens detail and becomes read")
	bot.expect(bot.button_named("NotificationGo_" + str(maya["id"])) == null, "information needs no forced action")
	await bot.click_named("NotificationsBack")
	await bot.wait(.2)
	bot.expect(UIRoot.phone.notification_filter == "life", "Back retains selected filter")
	await bot.click_named("NotificationFilter_work")
	await bot.shot("notifications_cards_work")
	await bot.click_named("Notification_" + str(message["id"]))
	await bot.wait(.2)
	await bot.shot("notification_full_appointment_detail")
	var full := UIRoot.phone.find_child("NotificationFullText_" + str(message["id"]), true, false) as Label
	bot.expect(full != null and full.text == message["text"], "full message retains all appointment dates and directions")
	bot.expect(message["read"], "opening reads the exact selected message")
	await bot.click_named("PhoneMessagesHelp")
	bot.expect(UIRoot.top_modal() is InfoModal, "notification help available")
	await bot.shot("notification_help")
	await bot.click_named("CloseInfo")
	await bot.wait(.3)
	await bot.click_named("NotificationsBack")
	await bot.wait(.2)
	await bot.click_named("NotificationsReadAll")
	await bot.wait(.2)
	bot.expect(GameState.unread_messages() == 0, "read-all clears actionable badge")
	await bot.shot("notifications_cards_read")
	await bot.click_named("Notification_" + str(message["id"]))
	await bot.wait(.2)
	await bot.click_named("NotificationGo_" + str(message["id"]))
	bot.expect(UIRoot.top_modal() is CityMapModal, "detail Go opens map without confirmation")
	await bot.shot("notification_destination")
	UIRoot.close_all()
	# Separate empty-inbox fixture; not presented as deleting a player's actual messages.
	GameState.data["messages"] = []
	UIRoot.phone.open()
	await bot.wait(.3)
	await bot.click_named("App_messages")
	await bot.shot("notifications_friendly_empty")
	bot.expect(bot.button_named("PhoneClose") != null, "close remains reachable without scrolling")
	bot.expect(Ledger.check_balanced(), "reading, sorting and navigation keep actual books balanced")
	UIRoot.phone.close()
