extends RefCounted
var runner

func past_manual_shipment() -> void:
	# Controlled eligibility fixture; the rendered tour also performs the actual first packing/courier input.
	GameState.data["stats"]["orders_shipped"] = 1
	AssistantPolicy.offer_if_ready()

func join() -> void:
	past_manual_shipment()
	runner.check(AssistantPolicy.hire()["ok"], "actual paid hire succeeds")
	GameState.set_flag("test_assistant_run")

func domestic_order() -> Dictionary:
	var fixture = load("res://tests/unit/test_global.gd").new()
	fixture.runner = runner
	fixture._setup()
	var listing := Ecommerce.listing_for("wireless_earbuds")
	Ecommerce._h_order_place({"listing":listing["id"]})
	return Ecommerce.orders_with(["placed"])[0]

func test_new_game_cannot_delegate_before_hire_even_with_stale_switches() -> void:
	runner.check(not AssistantPolicy.hired(), "new player has no assistant")
	runner.check(AssistantPolicy.S()["tasks"].values().all(func(value):return not value), "all preferences initially off")
	AssistantPolicy.set_all(true)
	runner.check(AssistantPolicy.S()["tasks"].values().all(func(value):return not value), "unhired toggles cannot enable chores")
	var order := domestic_order()
	AssistantPolicy.S()["tasks"]["packing"] = true
	AssistantPolicy.S()["tasks"]["bills"] = true
	GameState.set_flag("test_assistant_run")
	var cash := Ledger.cash("player")
	AssistantPolicy.on_hour(Clock.now(), 6)
	runner.eq(order["status"], "placed", "stale preference cannot ship a parcel")
	runner.check(not AssistantPolicy.bill("player", "living", 10, "Actual bill", {"type":"living"}), "direct bill path requires hire")
	runner.eq(Ledger.cash("player"), cash, "bill waits without spending cash")
	runner.eq(Ledger.balance("player", "accounts_payable"), -10.0, "real liability remains")
	runner.check(Ledger.check_balanced(), "manual bill is balanced")

func test_actual_manual_pickup_offers_named_teammate_once() -> void:
	var order := domestic_order()
	runner.check(not AssistantPolicy.eligible(), "placed order is not a manual shipment")
	Ecommerce.pack_orders(Living.home())
	runner.check(Ecommerce.courier_pickup(Living.home(), "economy")["ok"], "real courier booked")
	Ecommerce._h_pickup({"ids":[order["id"]]})
	runner.eq(order["status"], "shipped", "actual inventory parcel shipped")
	runner.check(AssistantPolicy.eligible() and not AssistantPolicy.hired(), "offer does not hire automatically")
	var count: int = GameState.data["messages"].size()
	AssistantPolicy.offer_if_ready()
	runner.eq(GameState.data["messages"].size(), count, "offer is one-time")
	var note: Dictionary = GameState.data["messages"].back()
	runner.eq(note["target"]["kind"], "assistant", "offer opens actual hiring page")
	runner.check(PhoneMessages.actionable(note), "offer exposes its actual Go action")
	runner.eq(PhoneMessages.contact_name("assistant"), "Maya", "named sender")
	runner.check(Ledger.check_balanced(), "purchase, packing and courier balanced")

func test_hire_has_real_fee_and_no_automatic_task_selection() -> void:
	runner.check(not AssistantPolicy.hire()["ok"], "shipment required")
	past_manual_shipment()
	var cash := Ledger.cash("player")
	runner.check(AssistantPolicy.hire()["ok"], "player explicitly hires")
	runner.eq(Ledger.cash("player"), cash - float(AssistantPolicy.cfg()["hire_fee"]), "real joining fee paid")
	runner.check(AssistantPolicy.S()["tasks"].values().all(func(value):return not value), "player chooses chores")
	AssistantPolicy.set_task("packing", true)
	runner.check(AssistantPolicy.permitted("packing"), "chosen starter chore becomes available")
	runner.check(not AssistantPolicy.task_unlocked("tax"), "advanced service not granted early")
	runner.check(not AssistantPolicy.hire()["ok"], "no duplicate hire fee")
	runner.check(Ledger.check_balanced(), "hire fee has balanced expense")

func test_upgrade_unlocks_services_without_changing_work_or_adding_money() -> void:
	join()
	var cash := Ledger.cash("player")
	var career: Dictionary = Careers.C().duplicate(true)
	var tasks: Dictionary = AssistantPolicy.S()["tasks"].duplicate(true)
	runner.check(AssistantPolicy.upgrade()["ok"], "actual service upgrade")
	runner.eq(Ledger.cash("player"), cash - float(AssistantPolicy.cfg()["upgrade_fee"]), "real upgrade expense")
	runner.check(AssistantPolicy.task_unlocked("tax"), "new service unlocked")
	runner.eq(AssistantPolicy.S()["tasks"], tasks, "new chores wait for player choice")
	runner.eq(Careers.C(), career, "no work numerical buff")
	runner.check(not AssistantPolicy.upgrade()["ok"], "already upgraded safe")
	runner.check(Ledger.check_balanced(), "upgrade balances")

func test_weekly_retainer_paid_once_at_actual_boundary() -> void:
	join()
	var cash := Ledger.cash("player")
	var due := int(AssistantPolicy.S()["paid_until"])
	runner.check(AssistantPolicy.renew_due(due - 1), "first week covered")
	runner.eq(Ledger.cash("player"), cash, "no early fee")
	GameState.data["clock"]["minutes"] = due
	runner.check(AssistantPolicy.renew_due(due), "one actual next-week payment")
	runner.check(AssistantPolicy.renew_due(due), "same tick safe")
	runner.eq(Ledger.cash("player"), cash - float(AssistantPolicy.cfg()["weekly_fee"]), "exactly one fee")
	runner.check(Ledger.check_balanced(), "weekly service fee balanced")

func test_short_cash_pauses_without_debt_and_can_resume() -> void:
	join()
	AssistantPolicy.set_task("packing", true)
	Ledger.expense("player", "other", Ledger.cash("player") - 4, "Controlled cash fixture")
	GameState.data["clock"]["minutes"] = int(AssistantPolicy.S()["paid_until"])
	var messages: int = GameState.data["messages"].size()
	runner.check(not AssistantPolicy.renew_due(Clock.now()), "unfunded fee pauses")
	AssistantPolicy.renew_due(Clock.now() + Clock.DAY)
	runner.eq(GameState.data["messages"].size(), messages + 1, "one calm notice")
	runner.eq(Ledger.cash("player"), 4.0, "no overdraft")
	runner.eq(Ledger.balance("player", "accounts_payable"), 0.0, "no accumulating retainer debt")
	runner.check(not AssistantPolicy.permitted("packing"), "paused chores stop")
	Ledger.post("player", "Controlled owner capital", [{"acct":"cash", "dr":5}, {"acct":"equity", "cr":5}])
	runner.check(AssistantPolicy.renew_due(Clock.now()), "one funded week resumes")
	runner.check(AssistantPolicy.permitted("packing"), "saved packing choice restored")
	runner.check(Ledger.check_balanced(), "cash recovery balances")

func test_dismissed_save_does_not_readopt_enabled_preferences() -> void:
	join()
	AssistantPolicy.set_task("packing", true)
	AssistantPolicy.dismiss()
	runner.check(not AssistantPolicy.permitted("packing"), "dismiss stops actual permission")
	runner.check(AssistantPolicy.S()["tasks"]["packing"], "choice retained")
	runner.check(SaveSystem.save(21) and SaveSystem.load_data(21), "dismissed game reloads")
	runner.check(not AssistantPolicy.hired(), "explicit dismissal survives migration")
	runner.check(AssistantPolicy.hire()["ok"] and AssistantPolicy.permitted("packing"), "paid rehire restores preference")
	runner.check(Ledger.check_balanced(), "rehire balances")

func test_genuine_enabled_old_save_adopts_all_features_with_grace() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/pr182-pre-fun-ch3.json")
	var decoded := SaveSystem.validate_text(text)
	runner.check(decoded["ok"], "genuine prior-game save validates")
	var old: Dictionary = decoded["payload"]["data"]
	var choices: Dictionary = old["assistant"]["tasks"].duplicate(true)
	GameState.data = SaveSystem._migrate(old)
	var cash := Ledger.cash("player")
	AssistantPolicy.after_load()
	var messages: int = GameState.data["messages"].size()
	AssistantPolicy.after_load()
	runner.check(AssistantPolicy.hired() and int(AssistantPolicy.S()["level"]) == 2, "existing helper adopted with all services")
	runner.eq(AssistantPolicy.S()["tasks"], choices, "every old choice retained")
	runner.eq(GameState.data["messages"].size(), messages, "friendly introduction once")
	runner.check(int(AssistantPolicy.S()["paid_until"]) > Clock.now(), "first week covered")
	runner.eq(Ledger.cash("player"), cash, "adoption creates no surprise expense")
	runner.check(Ledger.check_balanced(), "old books balanced")

func test_all_off_and_missing_legacy_assistants_stay_manual() -> void:
	for previous in [{}, {"tasks":{"packing":false}, "default":true}]:
		var data: Dictionary = GameState.data.duplicate(true)
		data["assistant"] = previous
		GameState.data = SaveSystem._migrate(data)
		runner.check(not AssistantPolicy.hired(), "off legacy is not adopted")
		runner.check(AssistantPolicy.S()["tasks"].values().all(func(value):return not value), "unselected tasks stay off")

func test_unhired_foreign_wallet_does_not_auto_convert_despite_old_bank_flag() -> void:
	var fixture = load("res://tests/unit/test_global.gd").new()
	fixture.runner = runner
	var entity: String = fixture._setup()
	var order: Dictionary = fixture._order()
	fixture._deliver(order)
	GlobalMarket.company()["auto_fx"] = true
	AssistantPolicy.S()["tasks"]["fx"] = true
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	GlobalMarket.payout(entity)
	runner.check(float(GlobalMarket.balance(entity, "NRD")["wallet"]) > 0, "actual earned payout waits for manual conversion")
	runner.check(Ledger.check_balanced(), "foreign payout keeps real books")
