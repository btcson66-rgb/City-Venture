extends RefCounted
var bot
func _init(b) -> void: bot = b
func open_game(game: MiniGame) -> void:
	MiniGames.play(game, func(_res): pass)
	await bot.wait(0.2)
	await bot.click_named("StartGame")
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	MiniGames.auto = -1.0
	GameState.new_game({"name":"Alex Chen","seed":114})
	Clock.world_active = false
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	SceneRouter._enter("interior", "bloom_coffee", "entry", "up")
	UIRoot.set_hud_visible(true)
	Careers.hire("barista")
	var cash_before_shift := Ledger.cash("player")
	var barista := BaristaGame.new()
	MiniGames.play(barista, func(result): Careers.work_shift("barista", float(result.get("score", 0.0)), float(result.get("tips", 0.0))) if not result.get("aborted", false) else {})
	await bot.wait(0.2)
	await bot.click_named("StartGame")
	await bot.shot("barista_queue")
	for n in 6:
		await bot.click_named("Guest_0")
		await bot.click_named("ConfirmOrder")
		for pair in [["Size",barista.want["size"]],["Drink",barista.want["drink"]],["Milk",barista.want["milk"]],["Shots",barista.want["shots"]]]:
			await bot.click_named("%s_%s" % pair)
		await bot.click_named("Serve")
		if n == 1: await bot.shot("barista_delivery")
		await bot.click_named("Deliver_%d" % int(barista.want["destination"]))
		if n == 1: await bot.shot("barista_dirty_table")
		await bot.click_named("CleanTable")
	bot.expect(barista.points == 6.0, "six orders confirmed, made, delivered and cleaned")
	await bot.shot("barista_review")
	await bot.click_named("FinishGame")
	bot.expect(Ledger.cash("player") - cash_before_shift == 80.0, "four-hour shift plus twelve real service tips paid")
	var host := CoworkHostGame.new()
	await open_game(host)
	await bot.click_named("Desk_" + str(host.visitors[0]["answer"]))
	await bot.shot("meeting_conflict")
	await bot.click_named("Room_A_9")
	bot.expect(host.round_i == 0, "conflicting booking does not double book")
	await bot.click_named("Room_A_10")
	bot.expect(host.points == 1.0, "free slot resolves booking")
	host.close()
	await bot.wait(0.2)
	var parcel := ParcelSortGame.new()
	await open_game(parcel)
	await bot.click_named("Bin_" + str(parcel.parcel["bin"]))
	await bot.shot("damaged_parcel")
	await bot.click_named("Damage_quarantine")
	bot.expect(parcel.points > 1.5, "damaged parcel recorded and quarantined")
	parcel.close()
	await bot.wait(0.2)
	var clerk := ClerkFormsGame.new()
	await open_game(clerk)
	if clerk.form["bad"] == "": await bot.click_named("Approve")
	else:
		await bot.click_named("Field_" + str(clerk.form["bad"]))
		await bot.click_named("Reject")
	await bot.shot("complaint_call")
	await bot.click_named("Complaint_verify")
	bot.expect(clerk.points == 1.0, "form plus complaint handled")
	clerk.close()
	await bot.wait(0.2)
	var teller := TellerCashGame.new()
	await open_game(teller)
	var left := teller.amount
	for note in TellerCashGame.NOTES:
		while left >= note:
			await bot.click_named("Note_%d" % note)
			left -= note
	await bot.click_named("HandOver")
	await bot.shot("return_policy")
	await bot.click_named("Refund_yes")
	bot.expect(teller.points == 1.0, "counted cash and checked refund receipt")
	await bot.shot("change_counting")
	teller.close()
	await bot.wait(0.2)
	Careers.start_freelance()
	var offer: Dictionary = Careers.F()["offers"][0]
	Careers.accept(offer["id"])
	var g: Dictionary = Careers.F()["gigs"][offer["id"]]
	# Isolated two-hour client fixture; every stage/time/payment is subsequently played through the real UI.
	g["hours"] = 2.0
	g["due"] = Clock.now() + 10 * Clock.DAY
	g["scope_draw"] = 0.0
	g["terms"] = 0
	g["workflow"]["type"] = "market"
	UIRoot.open_modal(FreelanceModal.new(g["id"]))
	await bot.wait(0.2)
	await bot.shot("client_interview")
	for topic in ["goal","audience","budget"]: await bot.click_named("Interview_" + topic)
	await bot.click_named("Proposal")
	await bot.shot("client_proposal")
	await bot.click_named("AgreeProposal")
	for guard in 20:
		match FreelanceWorkflow.stage(g):
			"work", "revision_work":
				await bot.click_named("Session_2")
				await bot.click_named("StartGame")
				var game: ConsultingGame = UIRoot.top_modal()
				for round_index in 3:
					var task: Dictionary = FreelanceWorkflow.cfg()["cases"][game.kind][round_index]
					await bot.click_named("ConsultChoice_%d" % int(task["answer"]))
				await bot.click_named("FinishGame")
			"scope":
				await bot.shot("scope_growth")
				await bot.click_named("Scope_charge")
			"delivery": await bot.click_named("DeliverGig")
			"revision":
				await bot.shot("client_revision")
				await bot.click_named("ReviseGig")
			"acceptance": await bot.click_named("AcceptDelivery")
			"accepted": break
		await bot.wait(0.15)
	bot.expect(g["status"] == "invoiced", "client accepts before actual revenue invoice")
	UIRoot.top_modal().close()
	Clock.advance(2)
	bot.expect(g["status"] == "paid", "client pays actual invoice")
	bot.expect(Ledger.check_balanced(), "consulting journal balanced")
	# Guard each distinct execution interaction through real input.
	for kind in ["finance", "operations", "brand"]:
		var game := ConsultingGame.new(kind)
		await open_game(game)
		await bot.shot("consulting_" + kind)
		for round_index in 3:
			var task: Dictionary = FreelanceWorkflow.cfg()["cases"][kind][round_index]
			if kind == "operations":
				for step in task["answer"]: await bot.click_named("ConsultChoice_%d" % task["options"].find(step))
			else:
				await bot.click_named("ConsultChoice_%d" % int(task["answer"]))
				if kind == "brand": await bot.click_named("ConfirmFit")
		bot.expect(game.points == 3.0, "distinct " + kind + " tasks score actual answers")
		await bot.click_named("FinishGame")
