extends RefCounted
var bot
func _init(b) -> void: bot = b
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name": "Alex Chen", "seed": 112})
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	SceneRouter._enter("district", "riverside", "door_home", "up")
	UIRoot.set_hud_visible(true)
	GameState.add_message("maya", "So you actually quit?")
	UIRoot.phone.open()
	await bot.wait(0.3)
	await bot.click_named("App_messages")
	await bot.click_named("Thread_maya")
	await bot.talk_through_dialogue()
	bot.expect(GameState.flag("maya_intro_done"), "Maya phone conversation unlocks the first chapter")
	bot.expect(GameState.flag("phone_call_maya_intro"), "completed call has a saved receipt")
	Bank.book_appointment()
	var message: Dictionary = GameState.data["messages"].back()
	UIRoot.phone.open()
	await bot.wait(0.5)
	await bot.click_named("App_messages")
	await bot.shot("message_threads")
	await bot.click_named("Thread_marcus")
	await bot.shot("quick_replies")
	await bot.click_named("PhoneMessagesHelp")
	bot.expect(UIRoot.top_modal() is InfoModal, "phone help card is available")
	await bot.shot("phone_help")
	await bot.click_named("CloseInfo")

	await bot.click_named("Reply_" + str(message["id"]) + "_confirm")
	bot.expect(PhoneMessages.S()["agenda"].size() == 1, "reply creates real agenda")
	await bot.shot("reply_history")
	UIRoot.phone._go("agenda")
	await bot.wait(0.3)
	await bot.shot("meeting_agenda")
	UIRoot.phone._go("contacts")
	await bot.wait(0.3)
	await bot.shot("proactive_templates")
	# Finish the booked task through the actual arrival handler, then permit a fresh invitation.
	var meeting: Dictionary = PhoneMessages.S()["agenda"][0]
	UIRoot.phone.close()
	GameState.data["clock"]["minutes"] = int(meeting["at"])
	SceneRouter._enter("interior", "nexus_bank", "entry", "up")
	await bot.wait(0.6)
	bot.expect(meeting["status"] == "met", "arrival starts appointment conversation")
	UIRoot.close_all()
	if UIRoot.dialogue.active: UIRoot.dialogue._end()
	UIRoot.phone.open()
	UIRoot.phone._go("contacts")
	await bot.wait(0.3)
	await bot.click_named("Send_marcus_coffee")
	bot.expect(PhoneMessages.S()["agenda"].size() == 2, "proactive invitation creates next meeting")
	await bot.wait(0.2)
	var latest: Control = UIRoot.phone.content.get_child(UIRoot.phone.content.get_child_count() - 1)
	var scroll := UIRoot.phone.content.get_parent() as ScrollContainer
	bot.expect(latest.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1, "latest outgoing reply is visible without losing history")
	await bot.shot("proactive_result")
	UIRoot.phone.close()
