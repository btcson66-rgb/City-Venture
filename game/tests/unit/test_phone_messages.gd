extends RefCounted
var runner

func test_notifications_read_only_and_daily_merge() -> void:
	var cash := Ledger.cash("player")
	var before: int = GameState.data["messages"].size()
	var options := {"merge":"orders_test","target":{"kind":"company","tab":"operations"}}
	GameState.add_message("shoplane", "Order", options)
	GameState.add_message("shoplane", "Order", options)
	runner.eq(GameState.data["messages"].size(), before+1, "same-day events are one row")
	var m: Dictionary = GameState.data["messages"].back()
	runner.eq(m["count"], 2, "counts both real events")
	runner.check(m.has("id") and m.has("t") and m["category"] == "work", "stable notification format")
	runner.eq(GameState.unread_messages(), 1, "one actionable badge")
	PhoneMessages.read_all()
	runner.eq(GameState.unread_messages(), 0, "read-all clears badge")
	GameState.data["clock"]["minutes"] += Clock.DAY
	GameState.add_message("shoplane", "Order", options)
	runner.eq(GameState.data["messages"].size(), before+2, "new day is a new group")
	GameState.add_message("maya", "Hello", {"replies":[{"id":"yes","effects":[{"op":"cost","amount":500}]}],"expires":1})
	runner.check(not GameState.data["messages"].back().has("replies") and not GameState.data["messages"].back().has("expires"), "no reply or reply deadline")
	runner.eq(Ledger.cash("player"), cash, "reading and notifications never invent transactions")
	runner.check(Ledger.check_balanced(), "balanced")

func test_every_legacy_wait_node_without_saved_financial_effect() -> void:
	var data: Dictionary = GameState.data.duplicate(true)
	data.erase("phone_messages")
	data["messages"] = []
	var expected := {"phone_contract":"company","phone_group_job":"company","fund_board":"fundraising","fund_partner":"fundraising","phone_meeting":"map","phone_bank_later":"map","phone_payment_extension":"bank"}
	for op in expected:
		data["messages"].append({"t":0,"from":"marcus","text":"Legacy pending","read":false,"expires":1,"default_reply":"ack","replies":[{"id":"ack","effects":[{"op":op,"id":"X","deal":"X"},{"op":"set_flag","flag":"neutral_"+op},{"op":"cost","amount":9999}]}]})
	var ledger: Variant = data["ledger"].duplicate(true)
	PhoneMessages.migrate(data)
	for i in range(expected.size()):
		var op: String = expected.keys()[i]
		var m: Dictionary = data["messages"][i]
		runner.eq(m["target"]["kind"], expected[op], op+" formal destination")
		runner.check(m["read"] and not m.has("replies") and not m.has("expires"), "pending thread is read, without deadline")
		runner.check(data["flags"]["neutral_"+op], "neutral wait flag carried forward")
	runner.eq(data["ledger"], ledger, "migration never executes saved money effects")
	var copy := data.duplicate(true)
	PhoneMessages.migrate(data)
	runner.eq(data, copy, "idempotent migration")

func test_formal_destinations_and_stale_decisions() -> void:
	for target in [{"kind":"company","tab":"operations"},{"kind":"fundraising","tab":"partners","id":"X"},{"kind":"bank"},{"kind":"map","place":"nexus_bank"}]:
		var screen := PhoneMessages.destination({"target":target})
		runner.check(screen != null, "formal destination " + target["kind"])
		if screen != null:screen.free()
	runner.check(not PhoneMessages.actionable({"target":{"kind":"decision","id":"gone"}}), "resolved event does not badge")
	runner.check(not PhoneMessages.actionable({"target":{"kind":"company","tab":"contracts","id":"gone"}}), "closed contract does not badge")

func test_legacy_visit_miss_is_neutral() -> void:
	var cash := Ledger.cash("player")
	var flags: Dictionary = GameState.data["flags"].duplicate(true)
	PhoneMessages.S()["agenda"].append({"id":"old","npc":"maya","at":Clock.now(),"until":Clock.now()+1,"status":"planned","location":"interior:bloom_coffee","conversation":""})
	PhoneMessages.on_minute(Clock.now()+2)
	runner.eq(PhoneMessages.S()["agenda"][0]["status"], "missed", "optional visit lapses")
	runner.eq(GameState.data["flags"], flags, "no story or friendship penalty")
	runner.eq(Ledger.cash("player"), cash, "no missed-visit fee")

func test_notification_save_roundtrip() -> void:
	GameState.add_message("city", "News")
	var id: String = GameState.data["messages"].back()["id"]
	GameState.data = SaveSystem._migrate(JSON.parse_string(JSON.stringify(GameState.data)))
	runner.eq(PhoneMessages.get_message(id)["category"], "city", "saved city filter")
	runner.check(Ledger.check_balanced(), "roundtrip balanced")

func test_read_any_message_preserves_original_and_money() -> void:
	GameState.add_message("maya", "Hello — full original message, no action required.")
	var id: String = GameState.data["messages"].back()["id"]
	var journal: Variant = GameState.data["ledger"].duplicate(true)
	PhoneMessages.read(id)
	PhoneMessages.read(id)
	PhoneMessages.read("missing-old-id")
	runner.check(PhoneMessages.get_message(id)["read"], "non-actionable message can be read")
	runner.eq(PhoneMessages.get_message(id)["text"], "Hello — full original message, no action required.", "original preserved")
	runner.eq(GameState.data["ledger"], journal, "read is idempotent and never executes money effects")

func test_relative_time_calendar_boundary_and_future_timestamp() -> void:
	var midnight := 3 * Clock.DAY
	runner.eq(PhoneMessages.day_group(midnight-1, midnight+1), 1, "midnight is yesterday after two minutes")
	runner.eq(PhoneMessages.relative_time(midnight-1, midnight+1), I18n.t("Yesterday"), "calendar grouping agrees with time")
	runner.eq(PhoneMessages.relative_time(midnight+100, midnight), I18n.t("Just now"), "future save clock is never negative")
	runner.eq(PhoneMessages.relative_time(midnight+1, midnight+59), I18n.t("%d min ago") % 58, "actual game minutes")
	runner.eq(PhoneMessages.day_group(0, midnight), 3, "older calendar days retained")

func test_daily_merge_reopens_read_card_without_duplicate_arrival() -> void:
	GameState.add_message("shoplane", "First actual order", {"merge":"card-read-test"})
	var id: String = GameState.data["messages"].back()["id"]
	PhoneMessages.read(id)
	GameState.add_message("shoplane", "Second actual order", {"merge":"card-read-test"})
	var merged := PhoneMessages.get_message(id)
	runner.check(not merged["read"], "new real event reopens merged card")
	runner.eq(merged["count"], 2, "same stable card includes both events")
