extends RefCounted
var runner
func accepted_gig() -> Dictionary:
	Careers.start_freelance()
	var offer: Dictionary = Careers.F()["offers"][0]
	var result := Careers.accept(offer["id"])
	var g: Dictionary = result["gig"]
	g["hours"] = 2.0
	g["due"] = Clock.now() + 10 * Clock.DAY
	g["scope_draw"] = 0.0
	return g
func prepare(g: Dictionary, questions := 3, revisions := 1) -> void:
	for topic in ["goal", "audience", "budget"].slice(0, questions): FreelanceWorkflow.ask(g["id"], topic)
	FreelanceWorkflow.prepare_proposal(g["id"])
	runner.check(FreelanceWorkflow.propose(g["id"], 1.0, revisions)["ok"], "proposal accepted")
func complete_work(g: Dictionary, quality := 1.0) -> void:
	var guard := 0
	while FreelanceWorkflow.stage(g) in ["work", "revision_work", "scope"] and guard < 30:
		guard += 1
		if FreelanceWorkflow.stage(g) == "scope": FreelanceWorkflow.scope(g["id"], true)
		else:
			var result := FreelanceWorkflow.work(g["id"], 2.0, quality)
			if not result["ok"]: Clock.advance(Clock.DAY)
func test_every_stage_invoice_only_after_client_acceptance() -> void:
	var g := accepted_gig()
	runner.check(not FreelanceWorkflow.deliver(g["id"])["ok"], "no early delivery")
	prepare(g)
	var original_fee := float(g["fee"])
	complete_work(g)
	runner.eq(g["workflow"]["scope_choice"], "charge", "negotiated additional work")
	runner.eq(g["fee"], original_fee * 1.25, "fee follows scope")
	runner.eq(Ledger.balance("player", "revenue"), 0.0, "no revenue for execution")
	FreelanceWorkflow.deliver(g["id"])
	FreelanceWorkflow.revise(g["id"], false)
	complete_work(g)
	FreelanceWorkflow.deliver(g["id"])
	runner.eq(FreelanceWorkflow.stage(g), "acceptance", "client review after revision")
	var result := FreelanceWorkflow.accept_delivery(g["id"])
	runner.check(result["ok"], "acceptance invoices")
	runner.eq(-Ledger.balance("player", "revenue"), result["fee"], "invoice is actual service revenue")
	runner.check(not FreelanceWorkflow.accept_delivery(g["id"])["ok"], "exactly once")
	Clock.advance((int(g["terms"]) + 1) * Clock.DAY)
	runner.eq(g["status"], "paid", "real scheduled payment")
	runner.eq(Ledger.balance("player", "accounts_receivable"), 0.0, "invoice collected")
	runner.check(Ledger.check_balanced(), "balanced")
func test_scope_absorb_changes_hours_without_adding_fee() -> void:
	var g := accepted_gig()
	prepare(g)
	var fee := float(g["fee"])
	FreelanceWorkflow.work(g["id"], 1.0, 1.0)
	runner.eq(FreelanceWorkflow.stage(g), "scope", "scope interrupts actual work")
	var hours := float(g["hours"])
	FreelanceWorkflow.scope(g["id"], false)
	runner.eq(g["fee"], fee, "absorb retains fee")
	runner.check(float(g["hours"]) > hours, "extra effort still required")
func test_revision_limit_failed_acceptance_and_discount_recovery() -> void:
	var g := accepted_gig()
	g["scope_draw"] = 1.0
	prepare(g, 0, 0)
	complete_work(g, 0.4)
	FreelanceWorkflow.deliver(g["id"])
	runner.check(not FreelanceWorkflow.revise(g["id"], false)["ok"], "no free revision past allowance")
	runner.check(FreelanceWorkflow.revise(g["id"], true)["ok"], "paid revision agreed")
	complete_work(g, 0.4)
	FreelanceWorkflow.deliver(g["id"])
	runner.check(not FreelanceWorkflow.accept_delivery(g["id"])["ok"], "poor quality fails acceptance")
	runner.eq(Ledger.balance("player", "revenue"), 0.0, "failed acceptance has no invoice")
	var fee := float(g["fee"])
	var result := FreelanceWorkflow.accept_delivery(g["id"], true)
	runner.check(result["ok"], "discount exits failure without softlock")
	runner.eq(result["fee"], fee * 0.65, "actual reduced service invoice")
func test_daily_hours_quote_guard_save_and_closed_company() -> void:
	var g := accepted_gig()
	g["hours"] = 30.0
	g["scope_draw"] = 1.0
	FreelanceWorkflow.prepare_proposal(g["id"])
	runner.check(not FreelanceWorkflow.propose(g["id"], 1.2, 1)["ok"], "reputation caps quote")
	FreelanceWorkflow.propose(g["id"], 1.0, 1)
	for n in 3: FreelanceWorkflow.work(g["id"], 2.0, 1.0)
	runner.check(not FreelanceWorkflow.work(g["id"], 2.0, 1.0)["ok"], "daily capacity cannot be bypassed")
	GameState.data = SaveSystem._migrate(JSON.parse_string(JSON.stringify(GameState.data)))
	runner.eq(FreelanceWorkflow.stage(FreelanceWorkflow.gig(g["id"])), "work", "stage saved")
	GameState.data["entities"]["player"]["closed"] = Clock.now()
	runner.check(not FreelanceWorkflow.work(g["id"], 2.0, 1.0)["ok"], "closed entity blocked")
func test_barista_stations_tables_and_priority() -> void:
	var game := BaristaGame.new()
	UIRoot.open_modal(game)
	await runner.get_tree().process_frame
	game.start()
	runner.eq(game.queue.size(), 3, "three simultaneous customers")
	game._select_customer(1)
	game._confirm()
	game.got.merge({"size":game.want["size"],"drink":game.want["drink"],"milk":game.want["milk"],"shots":game.want["shots"]}, true)
	game._serve()
	runner.eq(game.points, 0.0, "preparation alone not paid as completed service")
	game._deliver(int(game.want["destination"]))
	runner.eq(game.tables[1], "dirty", "dirty table blocks new guest")
	game._clean()
	runner.eq(game.points, 1.0, "all four stations score")
	runner.eq(game.tables[1], "", "cleaning frees table")
	runner.eq(game.completed_stations["clean"], 1, "cleanup counted")
	game.close()
	await runner.get_tree().process_frame
func test_promotion_requires_manager_quality_and_more_shifts() -> void:
	Careers.hire("barista")
	Careers.C()["shifts"]["barista"] = 5
	Careers.C()["manager_ratings"] = {"barista":{"sum":2.0,"count":5}}
	runner.eq(Careers.rank_index("barista"), 0, "poor performance cannot earn promotion")
	Careers.C()["manager_ratings"]["barista"]["sum"] = 4.0
	runner.eq(Careers.rank_index("barista"), 1, "high review unlocks higher wage")
	runner.eq(Careers.rank("barista")["shifts_per_day"], 2, "promotion permits extra shifts")

func test_player_daily_capacity_shared_between_projects() -> void:
	var first := accepted_gig()
	first["hours"] = 40.0
	prepare(first)
	for n in 3: FreelanceWorkflow.work(first["id"], 2.0, 1.0)
	var second := accepted_gig()
	prepare(second)
	runner.check(not FreelanceWorkflow.work(second["id"], 2.0, 1.0)["ok"], "switching projects retains daily allowance")
	Careers.C().erase("daily_freelance_hours")
	runner.check(not FreelanceWorkflow.work(second["id"], 2.0, 1.0)["ok"], "old per-project hours migrate into player limit")
	Clock.advance(Clock.DAY)
	runner.check(FreelanceWorkflow.work(second["id"], 2.0, 1.0)["ok"], "rest restores daily hours")

func test_legacy_gig_retains_delivery_and_old_promotions() -> void:
	var g := accepted_gig()
	g.erase("workflow")
	g.erase("workflow_version")
	g.erase("scope_draw")
	g.erase("work_type")
	GameState.data = SaveSystem._migrate(JSON.parse_string(JSON.stringify(GameState.data)))
	var result := Careers.work_on(g["id"])
	runner.check(result["ok"] and result["delivered"], "legacy unfinished project still delivers")
	runner.eq(Careers.F()["gigs"][g["id"]]["status"], "invoiced", "legacy actual invoice")
	runner.check(not Careers.work_on(g["id"])["ok"], "already delivered legacy project cannot invoice twice")
	Careers.C()["shifts"]["barista"] = 5
	Careers.C().erase("manager_ratings")
	runner.eq(Careers.rank_index("barista"), 1, "previously earned promotion retained")
	runner.check(Ledger.check_balanced(), "legacy delivery balances")

func test_dirty_table_can_be_cleaned_from_another_ticket() -> void:
	var game := BaristaGame.new()
	UIRoot.open_modal(game)
	await runner.get_tree().process_frame
	game.start()
	game._select_customer(1)
	game._confirm()
	game.got.merge({"size":game.want["size"],"drink":game.want["drink"],"milk":game.want["milk"],"shots":game.want["shots"]}, true)
	game._serve()
	game._deliver(1)
	game._select_customer(0)
	# A waiting ticket for a dirty table must route to cleanup, not an unusable confirmation.
	game.want["destination"] = 1
	game._layout()
	var confirm := game.stage.find_child("ConfirmOrder", true, false) as Button
	runner.check(confirm.disabled, "dirty table blocks confirmation button")
	var primaries := 0
	var primary_name := ""
	for button in game.stage.find_children("*", "Button", true, false):
		var box = button.get_theme_stylebox("normal")
		if box is StyleBoxTexture and box.texture == Art.tex("ui/button_primary"):
			primaries += 1
			primary_name = button.name
	runner.eq(primaries, 1, "one useful primary while table dirty")
	runner.eq(primary_name, "CleanDirtyTable_1", "cleanup is the next sensible step")
	game._clean_dirty_table(1)
	runner.eq(game.tables[1], "", "another guest can release dirty table")
	runner.eq(game.completed_stations["clean"], 1, "cleaned once")
	game._select_customer(1)
	game._clean()
	runner.eq(game.completed_stations["clean"], 1, "finishing original ticket does not count cleanup twice")
	game.close()
	await runner.get_tree().process_frame

func test_additional_job_stages_preserve_scores_and_conflicts() -> void:
	var teller := TellerCashGame.new()
	UIRoot.open_modal(teller)
	await runner.get_tree().process_frame
	teller.start()
	teller.tray = [teller.amount]
	teller._hand()
	runner.eq(teller.points, 0.0, "counting cash alone cannot complete return service")
	teller._refund(not teller.receipt_valid)
	runner.eq(teller.points, 0.6, "invalid refund decision loses service portion")
	teller.close()
	await runner.get_tree().process_frame
	var host := CoworkHostGame.new()
	UIRoot.open_modal(host)
	await runner.get_tree().process_frame
	host.start()
	host._answer(host.visitors[0]["answer"])
	host._room("A_9")
	runner.eq(host.round_i, 0, "occupied room requires another choice")
	host._room("A_10")
	runner.eq(host.points, 1.0, "free alternative completes service")
	host.close()
	await runner.get_tree().process_frame
	var parcel := ParcelSortGame.new()
	UIRoot.open_modal(parcel)
	await runner.get_tree().process_frame
	parcel.start()
	parcel.round_i = 1
	parcel.build_round()
	parcel._drop(parcel.parcel["bin"])
	runner.eq(parcel.points, 0.0, "damage cannot bypass inspection")
	parcel._damage(true)
	runner.eq(parcel.points, 1.0, "recording and quarantining completes damaged parcel")
	parcel.close()
	await runner.get_tree().process_frame
	var clerk := ClerkFormsGame.new()
	UIRoot.open_modal(clerk)
	await runner.get_tree().process_frame
	clerk.start()
	clerk.marked = str(clerk.form["bad"])
	clerk._decide(clerk.marked == "")
	runner.eq(clerk.points, 0.0, "form alone does not resolve caller")
	clerk._call(false)
	runner.eq(clerk.points, 0.6, "bad complaint handling loses service portion")
	clerk.close()
	await runner.get_tree().process_frame
