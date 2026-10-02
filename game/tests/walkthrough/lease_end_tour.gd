extends RefCounted
var bot

func _init(b) -> void:
	bot = b

func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name": "Alex Chen", "seed": 110})
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	SceneRouter._enter("district", "riverside", "door_home", "up")
	UIRoot.set_hud_visible(true)
	Company.register("Riverlight Goods", "ecommerce", "22 Founders Lane")
	var ent := GameState.company_id()
	Ledger.post(ent, "Tour capital", [{"acct": "cash", "dr": 60000.0}, {"acct": "equity", "cr": 60000.0}])
	GameState.set_flag("business_account_opened")
	Living.lease("suite_2b")
	Living.lease("nexus_cowork_desk")
	LeaseEnd.record_damage("suite_2b", 75.0)
	bot.step("Phone lease list")
	UIRoot.phone.open()
	await bot.wait(0.5)
	await bot.click_named("App_leases")
	await bot.wait(0.5)
	await bot.shot("leases_list")
	await bot.click_named("ReviewLease_suite_2b")
	await bot.wait(0.5)
	await bot.shot("lease_notice_review")
	await bot.click_named("LeaseMode_immediate")
	await bot.wait(0.5)
	var confirm := UIRoot.top_modal().find_child("ConfirmLeaseEnd", true, false)
	var sc := confirm.get_parent().get_parent() as ScrollContainer
	if sc != null: sc.ensure_control_visible(confirm)
	await bot.wait(0.5)
	await bot.shot("lease_exit_costs_confirmation")
	await bot.click_named("ConfirmLeaseEnd")
	await bot.wait(0.5)
	bot.expect(not Living.has_lease("suite_2b"), "office no longer leased")
	await bot.shot("lease_ended")
	UIRoot.close_all()
	UIRoot.open_modal(LeaseEndModal.new())
	await bot.wait(0.5)
	await bot.shot("remaining_leases")
	bot.expect(Ledger.check_balanced(), "termination preserves double entry")
	UIRoot.close_all()
