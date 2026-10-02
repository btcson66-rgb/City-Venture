extends RefCounted
var runner

func test_tile_atlas_uses_physical_native_regions() -> void:
	var atlas := WorldScene.tileset().get_source(0) as TileSetAtlasSource
	var native := load("res://assets/tiles/atlas.png") as Texture2D
	runner.eq(atlas.texture.get_image().get_size(), native.get_image().get_size(), "atlas cell coordinates address native pixels")
	var coords: Array = DataDB.tiles["tiles"]["sidewalk"]
	var region := Rect2i(Vector2i(int(coords[0])*16, int(coords[1])*16), Vector2i(16,16))
	runner.eq(atlas.texture.get_image().get_region(region).get_data(), native.get_image().get_region(region).get_data(), "industrial sidewalk samples the correct tile")

func setup_factory() -> String:
	Company.register("OEM Test", "manufacturing", "Unit 12")
	Company.open_business_account(25000)
	runner.check(Living.lease("unit12_factory")["ok"], "factory leased")
	runner.check(Manufacturing.start()["ok"], "factory opened")
	runner.check(Manufacturing.acquire_machine()["ok"], "machine rented")
	Staff.register_employer()
	runner.check(Manufacturing.hire_tomas()["ok"], "named technician hired through Staff")
	return GameState.company_id()

func next_monday() -> int:
	var day := 1
	while Clock.weekday(Clock.at_day_time(day, 9*60)) != 1: day += 1
	return Clock.at_day_time(day, 9*60)

func test_opening_gates_world_and_registry() -> void:
	runner.check(not Manufacturing.start()["ok"], "company gate")
	Company.register("OEM Test", "manufacturing", "Unit 12")
	runner.check(not Manufacturing.start()["ok"], "bank gate")
	Company.open_business_account(25000)
	runner.check(not Manufacturing.start()["ok"], "factory gate")
	Living.lease("unit12_factory")
	runner.check(Manufacturing.start()["ok"], "lease unlocks")
	runner.eq(DataDB.district_def_in_city("industrial")["status"], "active", "district active")
	runner.check(DataDB.districts["industrial"]["buildings"].size() >= 4, "manufacturing locations (energy adds more)")
	runner.check(Industries.tabs().any(func(tab): return tab["id"] == "manufacturing"), "registered tab")
	runner.check(not Manufacturing.acquire_machine(false, true)["ok"], "automation requires genuine lending")
	runner.check(not Manufacturing.order_material(1)["ok"], "MOQ enforced")
	runner.check(not Manufacturing.order_material(99999)["ok"], "storage including pending orders bounded")
	runner.check(not Manufacturing.set_inspection(NAN)["ok"], "finite inspection")

func test_slot_conflicts_changeover_and_yield_formula() -> void:
	setup_factory()
	var rfq: Dictionary = Manufacturing.S()["rfqs"].values()[0]
	var job := str(Manufacturing.quote(rfq["id"], float(rfq["min_price"]))["id"])
	var machine := str(Manufacturing.S()["machines"][0])
	var t := next_monday()
	runner.check(Manufacturing.plan(job, machine, t, 4)["ok"], "first slot")
	runner.check(not Manufacturing.plan(job, machine, t+3*60, 2)["ok"], "overlap rejected")
	runner.check(not Manufacturing.plan(job, machine, t+4*60, 2)["ok"], "changeover reserved")
	runner.check(Manufacturing.plan(job, machine, t+5*60, 2)["ok"], "adjacent with changeover")
	runner.check(not Manufacturing.plan(job, machine, t+12*60, 2)["ok"], "normal slot excludes evening")
	runner.check(Manufacturing.plan(job, machine, t+12*60, 2, true)["ok"], "overtime evening available")
	var defect := Manufacturing.defect_rate(1, 4, 1)
	runner.eq(defect, 0.045*0.76, "multiplicative yield")
	runner.check(Manufacturing.defect_rate(2, 1, 1.2) > defect, "wear, low skill and poor material increase defects")
	runner.check(absf(Manufacturing.defect_rate(1, 4, 1, true)-defect-0.02) < 0.0001, "overtime yield down exactly two points")

func test_complete_material_production_invoice_payment_cycle() -> void:
	var entity := setup_factory()
	Manufacturing.set_inspection(1)
	var po := Manufacturing.order_material(2000)
	runner.check(po["ok"], "paid material PO")
	runner.eq(Manufacturing.material_units(), 0, "no material before lead time")
	Clock.advance(2*Clock.DAY)
	runner.eq(Manufacturing.material_units(), 2000, "materials physically received")
	var rfq: Dictionary = Manufacturing.S()["rfqs"].values()[0]
	var job := str(Manufacturing.quote(rfq["id"], float(rfq["min_price"]))["id"])
	var machine := str(Manufacturing.S()["machines"][0])
	var t := Clock.at_day_time(1, 9*60)
	runner.check(Manufacturing.plan(job, machine, t, 16, true)["ok"], "scheduled production")
	Clock.advance_to(t+16*60)
	if int(Manufacturing.S()["orders"][job]["produced"]) < int(rfq["qty"]):
		Manufacturing.plan(job, machine, t+Clock.DAY, 16, true)
		Clock.advance_to(t+Clock.DAY+16*60)
	runner.eq(Manufacturing.S()["orders"][job]["produced"], rfq["qty"], "actual hourly capacity completes order")
	runner.check(Manufacturing.deliver(job)["ok"], "deliver and invoice")
	runner.check(Ledger.balance(entity, "accounts_receivable") > 0, "Net30 receivable")
	var before := Ledger.cash(entity)
	Clock.advance(30*Clock.DAY)
	runner.eq(Jobs.get_job(job)["status"], "paid", "Net30 settlement")
	runner.check(Ledger.balance(entity, "cogs") > 0, "material consumption booked as cost")
	runner.check(Ledger.check_balanced(), "all material, labour, rent and invoices balanced")
	var report := MonthClose.current(entity)
	runner.eq(report["segments"]["totals"]["operating_profit"], report["business_profit"], "segment sums equal whole")
	runner.check(is_finite(before), "finite cash")

func test_bad_quote_quality_refund_and_no_double_refund() -> void:
	var entity := setup_factory()
	var rfqs: Array = Manufacturing.S()["rfqs"].values()
	runner.check(not Manufacturing.quote(rfqs[0]["id"], 99)["ok"], "overpriced bid lost to Kessler")
	var job := str(Manufacturing.quote(rfqs[1]["id"], 2.2)["id"])
	Manufacturing.plan(job, "", Clock.at_day_time(1, 9*60), 1, false, true)
	Clock.advance_to(Clock.at_day_time(1, 10*60))
	runner.check(Manufacturing.deliver(job)["ok"], "subcontract fulfilled")
	var credit := Bank.credit()
	var result := Manufacturing.customer_return(job, 100, true)
	runner.check(result["ok"], "defect returns issued")
	runner.eq(float(result["refund"]), 220, "refund at invoiced selling price")
	runner.check(Bank.credit() < credit, "customer defects reduce credit")
	runner.check(Ledger.balance(entity, "refunds") >= 220, "contra revenue")
	runner.check(Ledger.balance(entity, "exp:penalties") > 0, "quality penalty")
	Manufacturing.customer_return(job, 999999, false)
	runner.check(not Manufacturing.customer_return(job, 1)["ok"], "refund capped at actual sale")
	runner.check(Jobs.get_job(job)["receivable"] >= 0, "no negative receivable")
	runner.check(Ledger.check_balanced(), "return ledger balanced")

func test_crises_cancellation_deposit_and_close_cleanup() -> void:
	var entity := setup_factory()
	var po := Manufacturing.order_material(200)
	var original := int(Manufacturing.S()["pos"][po["id"]]["due"])
	Manufacturing.crisis("shortage")
	runner.check(int(Manufacturing.S()["pos"][po["id"]]["due"]) > original, "shortage delays booked PO")
	runner.check(Manufacturing.material_price() > 1.65, "shortage changes actual cost")
	var rfq: Dictionary = Manufacturing.S()["rfqs"].values()[0]
	var job := str(Manufacturing.quote(rfq["id"], float(rfq["min_price"]))["id"])
	var cash := Ledger.cash(entity)
	var deposit := float(Jobs.get_job(job)["deposit_paid"])
	Manufacturing.crisis("cancel")
	runner.eq(Ledger.cash(entity), cash-deposit, "unworked order cannot retain deposit")
	runner.eq(Ledger.balance(entity, "deferred_revenue"), 0, "deposit liability cleared")
	runner.eq(Jobs.get_job(job)["status"], "closed", "cancelled job closed")
	Manufacturing.on_company_closed(entity)
	runner.eq(Ledger.balance(entity, "inventory_in_transit"), 0, "transit material liquidated")
	runner.check(not Manufacturing.is_running(), "operation closed")
	runner.check(Sim.pending("mfg.arrival").is_empty(), "no stale delivery")
	runner.eq(Manufacturing.material_units(), 0, "closed company cannot reuse materials")
	runner.check(not Manufacturing.order_material(200)["ok"], "closed operation rejects spend")
	runner.check(Ledger.check_balanced(), "crisis and closure balanced")

func test_old_save_lazy_state_and_roundtrip_with_slots() -> void:
	GameState.data.erase("manufacturing")
	runner.check(not Manufacturing.is_running(), "old save lazily initialized")
	setup_factory()
	Manufacturing.set_inspection(0.75)
	var job := str(Manufacturing.quote(Manufacturing.S()["rfqs"].values()[0]["id"], Manufacturing.cfg()["quote_min"])["id"])
	Manufacturing.plan(job, Manufacturing.S()["machines"][0], next_monday(), 8)
	runner.check(SaveSystem.save(97), "saved actual state")
	GameState.data.erase("manufacturing")
	runner.check(SaveSystem.load_data(97), "loaded actual save")
	runner.eq(Manufacturing.S()["inspection"], 0.75, "inspection persists")
	runner.eq(Manufacturing.S()["slots"].size(), 1, "schedule persists")
	runner.check(Ledger.check_balanced(), "roundtrip ledger")

func test_growth_loan_automation_brand_and_equipment_closure() -> void:
	var entity := setup_factory()
	Ledger.post(entity, "QA additional equity", [{"acct":"cash", "dr":100000}, {"acct":"equity", "cr":100000}])
	Manufacturing.acquire_machine(false)
	Manufacturing.order_material(2000)
	Clock.advance(2*Clock.DAY)
	var job := str(Manufacturing.quote(Manufacturing.S()["rfqs"].values()[0]["id"], Manufacturing.cfg()["quote_min"])["id"])
	runner.check(Bank.take_loan(2000, 24)["ok"], "eligible signed job and machine finance real loan")
	runner.check(Manufacturing.acquire_machine(false, true)["ok"], "CNC requires and uses Assets with active loan")
	runner.eq(Manufacturing.S()["stage"], 2, "automation growth")
	var cnc: Dictionary = Assets.S()["items"][Manufacturing.S()["machines"][-1]]
	runner.eq(cnc["capacity"], Manufacturing.cfg()["capacity_hour"]*2.5, "capacity 2.5 times")
	runner.check(Manufacturing.own_brand()["ok"], "paid mould unlocks third stage")
	runner.check(Manufacturing.brand_batch(100)["ok"], "reserve brand production")
	runner.eq(Ecommerce.stock("unit12_factory", "phone_stand"), 0, "no instant production")
	Clock.advance(120)
	runner.eq(Ecommerce.stock("unit12_factory", "phone_stand"), 100, "actual timed brand stock interoperates with ecommerce")
	runner.check(absf(Ecommerce.avg_cost("unit12_factory", "phone_stand")-3.4*0.55) < 0.01, "55 percent target under normal material price")
	runner.check(not Manufacturing.own_brand()["ok"], "no duplicate mould spend")
	Industries.on_company_closed(entity)
	runner.check(not Manufacturing.is_running(), "closure routed through registry")
	for id in Manufacturing.S()["machines"]: runner.eq(Assets.S()["items"][id]["status"], "sold", "all machines auctioned or returned")
	runner.eq(Jobs.get_job(job)["status"], "closed", "signed job closed")
	runner.check(Ledger.check_balanced(), "growth and liquidation ledger balanced")

func test_actual_recall_event_and_positive_work_cost_cancellation() -> void:
	var entity := setup_factory()
	var rfq: Dictionary = Manufacturing.S()["rfqs"].values()[0]
	var job := str(Manufacturing.quote(rfq["id"], float(rfq["min_price"]))["id"])
	Manufacturing.plan(job, "", Clock.at_day_time(1, 9*60), 1, false, true)
	Clock.advance_to(Clock.at_day_time(1, 10*60))
	Manufacturing.deliver(job)
	var event := EventEngine.trigger("manufacturing_recall")
	runner.check(EventEngine.choose(event["iid"], "recall")["ok"], "data-driven crisis effect actual route")
	runner.check(Ledger.balance(entity, "refunds") > 0, "recall changes ledger")
	runner.check(Ledger.check_balanced(), "event balanced")

func test_actual_company_close_clears_raw_and_finished_inventory_once() -> void:
	var entity := setup_factory()
	Manufacturing.order_material(500)
	Clock.advance(2*Clock.DAY)
	Manufacturing.order_material(200)
	var before := Ledger.cash(entity)
	var raw := Ledger.balance(entity, "inventory")+Ledger.balance(entity, "inventory_in_transit")
	Manufacturing.on_company_closed(entity)
	runner.eq(Ledger.cash(entity), before+snappedf(raw*Insolvency.LIQUIDATION_RATE, 0.01), "raw assets recover auction value")
	runner.eq(Ledger.balance(entity, "inventory"), 0, "raw balance zero")
	runner.eq(Ledger.balance(entity, "inventory_in_transit"), 0, "transit balance zero")
	var once := Ledger.cash(entity)
	Manufacturing.on_company_closed(entity)
	runner.eq(Ledger.cash(entity), once, "idempotent closure cannot recover material twice")
	runner.check(Ledger.check_balanced(), "raw liquidation balanced")

func test_brand_retry_keeps_machine_reserved_and_company_close_cancels_it() -> void:
	var entity := setup_factory()
	Manufacturing.order_material(500)
	Clock.advance(2*Clock.DAY)
	Manufacturing.S()["stage"] = 3
	runner.check(Manufacturing.brand_batch(100)["ok"], "brand slot booked")
	var slot: Dictionary = Manufacturing.S()["slots"][-1]
	Assets.S()["items"][slot["machine"]]["status"] = "broken"
	Clock.advance_to(int(slot["end"]))
	runner.check(int(slot["end"]) > Clock.now(), "repair delay keeps bay reserved")
	var job := str(Manufacturing.quote(Manufacturing.S()["rfqs"].values()[0]["id"], Manufacturing.cfg()["quote_min"])["id"])
	runner.check(not Manufacturing.plan(job, slot["machine"], Clock.now(), 1, true)["ok"], "delayed brand batch cannot overlap OEM work")
	runner.check(Insolvency.close_company()["ok"], "actual company closure")
	runner.check(not Manufacturing.is_running(), "manufacturing closed")
	runner.eq(Ledger.balance(entity, "inventory"), 0, "raw inventory settled by closure")
	runner.eq(Ledger.balance(entity, "inventory_in_transit"), 0, "transit cleared")
	Clock.advance(Clock.DAY)
	runner.eq(Ecommerce.stock("unit12_factory", "phone_stand"), 0, "cancelled production never creates post-closure goods")
	runner.check(Ledger.check_balanced(), "full closure ledger balanced")



func test_rfq_win_chance_falls_with_price_and_names_the_client() -> void:
	setup_factory()
	var rfq := {"min_price": 2.0, "max_price": 3.0}
	runner.eq(Manufacturing.win_chance(rfq, 1.5), 1.0, "below the floor always wins")
	runner.eq(Manufacturing.win_chance(rfq, 2.0), 1.0, "the floor always wins")
	runner.check(Manufacturing.win_chance(rfq, 2.5) < 1.0 and Manufacturing.win_chance(rfq, 2.5) > Manufacturing.win_chance(rfq, 2.9), "dearer quotes win less often")
	runner.eq(Manufacturing.win_chance(rfq, 3.0), float(Manufacturing.cfg()["win_at_max"]), "the ceiling wins at the configured rate")
	runner.eq(Manufacturing.win_chance(rfq, 3.01), 0.0, "above the ceiling never wins")
	var wins := 0
	var trials := 60
	for i in trials:
		var id := "RFQ-T%d" % i
		Manufacturing.S()["rfqs"][id] = {"id": id, "client": "Lena Park", "product": "phone_stand", "qty": 100, "min_price": 2.0, "max_price": 3.0, "due": Clock.now() + 5 * Clock.DAY, "max_defect": 0.02, "status": "open"}
		if Manufacturing.quote(id, 3.0)["ok"]: wins += 1
	runner.check(wins > trials * 0.2 and wins < trials * 0.8, "quoting the ceiling is a gamble (%d/%d won)" % [wins, trials])
	var lost: Array = Manufacturing.S()["rfqs"].values().filter(func(r): return r["status"] == "rejected")
	runner.check(lost.size() > 0, "lost RFQs are marked rejected")
	Manufacturing.S()["rfqs"]["RFQ-NAMED"] = {"id": "RFQ-NAMED", "client": "Lena Park", "product": "phone_stand", "qty": 100, "min_price": 2.0, "max_price": 3.0, "due": Clock.now() + 5 * Clock.DAY, "max_defect": 0.02, "status": "open"}
	var refused := Manufacturing.quote("RFQ-NAMED", 99.0)
	runner.check(not refused["ok"] and "Lena Park" in str(refused["error"]), "the rejection names the actual client")

func test_cancel_crisis_without_a_deposit_posts_no_empty_entry() -> void:
	var entity := setup_factory()
	var rfq: Dictionary = Manufacturing.S()["rfqs"].values()[0]
	var job := str(Manufacturing.quote(rfq["id"], float(rfq["min_price"]))["id"])
	Jobs.get_job(job)["deposit_paid"] = 0.0
	var entries := Ledger.entries(entity, 5000).size()
	runner.check(Manufacturing.crisis("cancel")["ok"], "cancellation runs")
	runner.eq(Ledger.entries(entity, 5000).size(), entries, "a zero deposit leaves the journal alone")
	runner.eq(Jobs.get_job(job)["status"], "closed", "job still closed")
