extends RefCounted
var bot
func _init(b) -> void: bot = b
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name":"Alex Chen","seed":112})
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	SceneRouter._enter("district", "riverside", "door_home", "up")
	UIRoot.set_hud_visible(true)
	GameState.add_message("maya", "So you actually quit?")
	GameState.add_message("city", "City news")
	Bank.book_appointment()
	var message: Dictionary = GameState.data["messages"].back()
	UIRoot.phone.open()
	await bot.wait(0.3)
	await bot.click_named("App_messages")
	bot.expect(GameState.flag("notifications_read"), "chapter one continues without replies")
	await bot.shot("notifications_all")
	await bot.click_named("NotificationFilter_life")
	await bot.shot("notifications_life")
	await bot.click_named("NotificationFilter_work")
	await bot.shot("notifications_work")
	await bot.click_named("PhoneMessagesHelp")
	bot.expect(UIRoot.top_modal() is InfoModal, "notification help available")
	await bot.shot("notification_help")
	await bot.click_named("CloseInfo")
	await bot.click_named("NotificationsReadAll")
	bot.expect(GameState.unread_messages() == 0, "read-all clears actionable badge")
	await bot.shot("notifications_read")
	await bot.click_named("NotificationGo_" + str(message["id"]))
	bot.expect(UIRoot.top_modal() is CityMapModal, "appointment opens map without confirmation")
	await bot.shot("notification_destination")
	bot.expect(Ledger.check_balanced(), "balanced")
	UIRoot.close_all()
