extends RefCounted
var runner

func test_reply_exactly_once_and_old_save_migration() -> void:
	GameState.add_message("maya", "Hello", {"replies": [{"id": "yes", "label": "Okay, thanks.", "effects": [{"op": "set_flag", "flag": "phone_test"}]}]})
	var m: Dictionary = GameState.data["messages"].back()
	var cash := Ledger.cash("player")
	runner.check(PhoneMessages.reply(m["id"], "yes")["ok"], "reply works")
	runner.check(GameState.flag("phone_test"), "real effect")
	runner.check(not PhoneMessages.reply(m["id"], "yes")["ok"], "no duplicate")
	GameState.data = SaveSystem._migrate(JSON.parse_string(JSON.stringify(GameState.data)))
	runner.eq(PhoneMessages.get_message(m["id"])["answered"], "yes", "answered survives load")
	runner.eq(Ledger.cash("player"), cash, "no invented income")
	var old := {"t": 0, "from": "maya", "text": "Old notification", "read": false}
	GameState.data["messages"].append(old)
	PhoneMessages.prepare(old)
	runner.eq(PhoneMessages.choices(old)[0]["id"], "ack", "old notification has acknowledgement")

func test_expired_default_and_unavailable_effect_do_not_stall() -> void:
	GameState.add_message("maya", "Choose", {"expires": Clock.now() + 1, "default_reply": "later", "replies": [{"id": "later", "label": "Later", "effects": [{"op": "set_flag", "flag": "phone_timeout"}]}]})
	var m: Dictionary = GameState.data["messages"].back()
	Clock.advance(2)
	runner.check(m["expired"] and GameState.flag("phone_timeout"), "default executes")
	runner.check(not PhoneMessages.reply(m["id"], "later")["ok"], "expired cannot replay")
	GameState.add_message("marcus", "Meet", {"expires": Clock.now(), "default_reply": "meet", "replies": [{"id": "meet", "effects": [{"op": "phone_meeting", "npc": "missing"}]}]})
	var failed: Dictionary = GameState.data["messages"].back()
	PhoneMessages.on_minute(Clock.now())
	runner.check(failed.has("answered") and failed["expired"], "failed default ends with actionable notice")

func test_conditions_contacts_cooldown_and_saved_agenda() -> void:
	runner.check(not PhoneMessages.send("marcus", "coffee")["ok"], "unknown contact blocked")
	GameState.add_message("marcus", "Hello")
	var result := PhoneMessages.send("marcus", "coffee")
	runner.check(result["ok"], "known contact can book")
	runner.check(not PhoneMessages.send("marcus", "coffee")["ok"], "cooldown")
	var meeting: Dictionary = result["meeting"]
	runner.check(Bank.marcus_on_duty(int(meeting["at"])) and Bank.marcus_on_duty(int(meeting["until"]) - 1), "whole meeting is during duty")
	GameState.data = SaveSystem._migrate(JSON.parse_string(JSON.stringify(GameState.data)))
	runner.eq(PhoneMessages.S()["agenda"][0]["id"], meeting["id"], "saved agenda")
	GameState.data["clock"]["minutes"] = int(meeting["at"])
	runner.check(not PhoneMessages.meet(meeting["id"])["ok"], "wrong location cannot meet")
	GameState.data["player"]["location"] = {"kind": "interior", "id": "nexus_bank"}
	runner.check(PhoneMessages.meet(meeting["id"])["ok"], "arrival completes")
	runner.check(not PhoneMessages.meet(meeting["id"])["ok"], "meeting once")
	runner.eq(PhoneMessages.S()["social"]["marcus"], 1, "social receipt without dependency95")

func test_missed_meeting_can_rebook_without_softlock() -> void:
	GameState.add_message("marcus", "Hello")
	var result := PhoneMessages.book("marcus")
	GameState.data["clock"]["minutes"] = int(result["meeting"]["until"]) + 1
	PhoneMessages.on_minute(Clock.now())
	runner.eq(result["meeting"]["status"], "missed", "missed recorded")
	runner.check(PhoneMessages.book("marcus")["ok"], "can rebook")

func test_bank_appointment_reply_creates_agenda_and_decline_cancels() -> void:
	Bank.book_appointment()
	var m: Dictionary = GameState.data["messages"].back()
	runner.check(PhoneMessages.reply(m["id"], "confirm")["ok"], "bank confirmation")
	runner.eq(PhoneMessages.S()["agenda"].size(), 1, "bank has agenda")
	PhoneMessages.S()["agenda"][0]["status"] = "missed"
	Bank.book_appointment()
	m = GameState.data["messages"].back()
	runner.check(PhoneMessages.reply(m["id"], "later")["ok"], "cancel appointment")
	runner.eq(Bank.B()["appointment"], -1, "cancelled bank slot")

func test_contract_details_accept_decline_and_closed_guard() -> void:
	Company.register("Phone contracts", "ecommerce", "22 Founders Lane")
	var cid := Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 10, "unit_price": 20.0})
	var message: Dictionary = GameState.data["messages"].back()
	var money := Ledger.cash(GameState.company_id())
	runner.check(PhoneMessages.reply(message["id"], "details")["ok"], "real detail response")
	runner.check(not message.has("answered"), "detail does not close decision")
	runner.check(PhoneMessages.reply(message["id"], "accept")["ok"], "accept contract")
	runner.eq(Contracts.C()[cid]["status"], "active", "actual contract active")
	runner.eq(Ledger.cash(GameState.company_id()), money, "no revenue without delivery")
	cid = Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 10, "unit_price": 20.0})
	message = GameState.data["messages"].back()
	GameState.data["clock"]["minutes"] = int(message["expires"])
	PhoneMessages.on_minute(Clock.now())
	runner.eq(Contracts.C()[cid]["status"], "expired", "default decline retains expiry lifecycle")
	cid = Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 10, "unit_price": 20.0})
	message = GameState.data["messages"].back()
	GameState.data["entities"][GameState.company_id()]["closed"] = Clock.now()
	runner.check(not PhoneMessages.reply(message["id"], "accept")["ok"], "closed entity cannot accept")

func test_payment_extension_reschedules_once_without_debt_forgiveness() -> void:
	Company.register("Phone debt", "ecommerce", "22 Founders Lane")
	var entity := GameState.company_id()
	Bank.B()["loans"]["PHONE"] = {"id": "PHONE", "entity": entity, "status": "late", "balance": 1000.0}
	Sim.schedule(Clock.now() + 3 * Clock.DAY, "bank.payment", {"id": "PHONE"})
	var cash := Ledger.cash(entity)
	runner.check(Bank.request_payment_extension("PHONE")["ok"], "one extension")
	runner.eq(Bank.B()["loans"]["PHONE"]["retry_at"], Clock.now() + 6 * Clock.DAY, "actual new retry")
	runner.check(not Bank.request_payment_extension("PHONE")["ok"], "not repeatable")
	runner.eq(Bank.B()["loans"]["PHONE"]["balance"], 1000.0, "debt remains")
	runner.eq(Ledger.cash(entity), cash, "no invented savings")
	var count := 0
	for event in GameState.data["schedule"]:
		if event["kind"] == "bank.payment" and event["p"].get("id", "") == "PHONE": count += 1
	runner.eq(count, 1, "only one scheduled retry")

func test_event_reply_uses_existing_queue_and_resolved_elsewhere_is_readonly() -> void:
	DataDB.events["phone_qa"] = {"id": "phone_qa", "presentation": {"channel": "phone", "speaker": "maya", "lines": ["Hello"]}, "choices": [{"id": "yes", "label": "Okay, thanks.", "effects": [{"op": "set_flag", "flag": "phone_event_done"}]}, {"id": "no", "label": "Later", "effects": []}]}
	var event := EventEngine.trigger("phone_qa")
	var message: Dictionary = GameState.data["messages"].back()
	runner.check(PhoneMessages.reply(message["id"], "yes")["ok"], "event replied")
	runner.check(GameState.flag("phone_event_done"), "actual event effect")
	runner.check(not EventEngine.pending().any(func(p): return p["iid"] == event["iid"]), "same queue resolved")
	event = EventEngine.trigger("phone_qa")
	message = GameState.data["messages"].back()
	EventEngine.choose(event["iid"], "no")
	runner.check(PhoneMessages.choices(message).is_empty(), "resolved at modal cannot reply again")
	DataDB.events.erase("phone_qa")

func test_group_offer_reply_and_decline_are_actual_saved_decisions() -> void:
	Company.register("Phone group", "ecommerce", "22 Founders Lane")
	var definition: String = DataDB.quests.keys()[0]
	var id := GroupJobs.offer(definition)
	var message: Dictionary = GameState.data["messages"].back()
	runner.check(PhoneMessages.reply(message["id"], "details")["ok"], "details available")
	runner.check(PhoneMessages.reply(message["id"], "accept")["ok"], "accept through reply")
	runner.eq(GroupJobs.get_job(id)["status"], "active", "actual group job")
	GroupJobs.get_job(id)["status"] = "completed"
	id = GroupJobs.offer(definition)
	message = GameState.data["messages"].back()
	runner.check(PhoneMessages.reply(message["id"], "decline")["ok"], "decline through reply")
	runner.eq(GroupJobs.get_job(id)["status"], "declined", "no completion reward on decline")

func test_multi_effect_failure_restores_receipts_before_retry() -> void:
	GameState.add_message("maya", "Choose", {"replies": [{"id": "book", "label": "Confirm the meeting", "effects": [{"op": "set_flag", "flag": "partial_phone"}, {"op": "phone_meeting", "npc": "missing"}]}]})
	var id: String = GameState.data["messages"].back()["id"]
	runner.check(not PhoneMessages.reply(id, "book")["ok"], "failed chain rejected")
	runner.check(not GameState.flag("partial_phone"), "earlier effect rolled back")
	runner.check(not PhoneMessages.get_message(id).has("answered"), "no false receipt")
	runner.check(not PhoneMessages.reply(id, "book")["ok"], "retry remains harmless")
	runner.check(not GameState.flag("partial_phone"), "no side effect from repeated retry")

func test_failed_multi_effect_timeout_ends_in_current_saved_state() -> void:
	GameState.add_message("maya", "Choose", {"expires": Clock.now(), "default_reply": "book", "replies": [{"id": "book", "effects": [{"op": "set_flag", "flag": "partial_timeout"}, {"op": "phone_meeting", "npc": "missing"}]}]})
	var id: String = GameState.data["messages"].back()["id"]
	PhoneMessages.on_minute(Clock.now())
	runner.check(not GameState.flag("partial_timeout"), "rollback before timeout receipt")
	runner.eq(PhoneMessages.get_message(id)["answered"], "expired_unavailable", "timeout ends on current save")
	runner.check(not PhoneMessages.S()["expiry"].has(id), "no repeated expiry")

func test_thread_has_only_one_available_recommended_primary() -> void:
	for i in 2:
		GameState.add_message("marcus", "Hello", {"replies": [{"id": "ack", "label": "Okay, thanks.", "recommended": true, "effects": []}]})
	UIRoot.phone.thread_with = "marcus"
	UIRoot.phone._go("thread")
	var primary := 0
	for button in UIRoot.phone.content.find_children("Reply_*", "Button", true, false):
		if not button.is_queued_for_deletion() and button.has_theme_stylebox_override("normal"): primary += 1
	runner.eq(primary, 1, "one primary across the entire thread")
	UIRoot.phone.close()
