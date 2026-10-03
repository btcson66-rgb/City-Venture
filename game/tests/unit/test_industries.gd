extends RefCounted
var runner

func _near(actual: float, expected: float, tolerance: float, label: String) -> void:
	runner.check(absf(actual-expected) <= tolerance, "%s (%.4f expected %.4f)" % [label, actual, expected])

func _company() -> String:
	Company.register("Framework test", "ecommerce", "22 Founders Lane")
	Company.open_business_account(25000)
	return GameState.company_id()

func test_registry_contract_dispatch_and_active_tabs() -> void:
	runner.check(Industries.all().size() >= 5, "five existing industries preserved")
	runner.check(not Industries.register({"id":"cafe", "sim_class":Cafe}), "duplicate rejected")
	for entry in Industries.all():
		var script: GDScript = entry["sim_class"]
		for method in ["on_hour", "handle", "is_running", "on_company_closed", "os_tab", "board_detail", "segment_tag"]:
			runner.check(script.has_method(method), "contract %s.%s" % [entry["id"], method])
	runner.check(Industries.dispatch("eco.missing", {}), "prefix dispatch")
	runner.check(not Industries.dispatch("unregistered.event", {}), "unknown rejected")
	runner.check(not Industries.tabs().any(func(t): return t["id"] in ["saas", "cafe", "logistics"]), "inactive industry tabs hidden")
	Careers.start_freelance()
	runner.check(Industries.tabs().any(func(t): return t["id"] == "freelance"), "running tab visible")

func test_segments_allocate_exact_cents_and_equal_month_close() -> void:
	var entity := _company()
	for sale in [["cafe", 10.01], ["ecommerce", 20.02], ["saas", 30.03]]:
		Ledger.post(entity, "sale", [{"acct":"cash", "dr":sale[1]}, {"acct":"revenue", "cr":sale[1]}], {"segment":sale[0]})
	Ledger.expense(entity, "rent_office", 10.0, "office", {"segment":"shared"})
	Ledger.expense(entity, "payroll", 0.01, "rounding", {"segment":"shared"})
	Ledger.post(entity, "returns", [{"acct":"refunds", "dr":1.01}, {"acct":"cash", "cr":1.01}], {"segment":"cafe"})
	var report := MonthClose.current(entity)
	var segments: Dictionary = report["segments"]
	_near(float(segments["totals"]["operating_profit"]), report["business_profit"], 0.001, "profit total exact")
	_near(float(segments["totals"]["opex"]), report["opex_total"], 0.001, "expenses total exact")
	_near(float(segments["totals"]["net_revenue"]), report["net_revenue"], 0.001, "revenue total exact")
	var allocated := 0.0
	for row in segments["rows"].values(): allocated += float(row["allocated"])
	_near(allocated, 10.01, 0.001, "allocation does not lose cents")
	for entry in GameState.data["ledger"]["journal"]: runner.check(entry["source"].has("segment"), "every entry tagged")
	runner.check(Ledger.check_balanced(), "balanced")

func test_zero_revenue_shared_cost_and_old_untagged_journal() -> void:
	var entity := _company()
	var entry := Ledger.expense(entity, "rent_office", 9.99, "shared")
	entry["source"].erase("segment")
	var report := Segments.compute(entity, 0, Clock.now()+1)
	_near(report["rows"]["shared"]["opex"], 9.99, 0.001, "no division by zero")
	_near(report["totals"]["operating_profit"], -9.99, 0.001, "old journal works")

func test_jobs_deposit_work_delivery_net_terms_and_no_double_payment() -> void:
	var entity := _company()
	for terms in [0,30,60]:
		var id := Jobs.offer({"client":"client", "scope":"installation", "price":100, "work":2.0, "terms":terms, "deposit":0.3, "segment":"consulting", "entity":entity})
		runner.check(Jobs.accept(id)["ok"], "accept")
		runner.check(not Jobs.invoice(id)["ok"], "no premature invoice")
		runner.check(not Jobs.deliver(id)["ok"], "scope required")
		runner.check(not Jobs.progress(id, -1)["ok"], "negative work rejected")
		Jobs.progress(id, 2)
		runner.check(Jobs.deliver(id)["ok"], "delivered")
		runner.check(Jobs.invoice(id)["ok"], "invoiced")
		runner.check(not Jobs.invoice(id)["ok"], "no duplicate invoice")
		Clock.advance(terms*Clock.DAY)
		runner.eq(Jobs.get_job(id)["status"], "paid", "Net %d paid" % terms)
		var cash := Ledger.cash(entity)
		Jobs.handle("job.pay", {"id":id})
		runner.eq(Ledger.cash(entity), cash, "no double pay")
	runner.check(Ledger.check_balanced(), "jobs balanced")

func test_late_job_penalty_and_company_closure_block_collection() -> void:
	var entity := _company()
	var id := Jobs.offer({"client":"client", "scope":"work", "price":100, "terms":30, "deposit":0.8, "penalty_rate":0.5, "due":Clock.now()+1, "entity":entity})
	Jobs.accept(id)
	Jobs.progress(id, 1)
	Clock.advance(2)
	Jobs.deliver(id)
	Jobs.invoice(id)
	_near(Jobs.get_job(id)["receivable"], 0.0, 0.001, "penalty cannot produce negative AR")
	Jobs.on_company_closed(entity)
	var cash := Ledger.cash(entity)
	Jobs.handle("job.pay", {"id":id})
	runner.eq(Ledger.cash(entity), cash, "closed cannot collect")
	runner.check(Ledger.check_balanced(), "penalty balanced")

func test_assets_straight_line_maintenance_failure_and_auction() -> void:
	var entity := _company()
	var result := Assets.buy({"entity":entity, "price":1000, "life_days":10, "segment":"logistics", "maintenance_days":1, "failure_chance":1, "maintenance_cost":10})
	runner.check(result["ok"], "bought")
	var id: String = result["id"]
	Clock.advance(Clock.DAY)
	Assets.on_hour(Clock.now(), 7)
	_near(Ledger.balance(entity, "exp:depreciation"), 100, 0.001, "one day depreciation")
	runner.eq(Assets.S()["items"][id]["status"], "broken", "deterministic fault")
	runner.check(Assets.maintain(id)["ok"], "maintained")
	runner.eq(Assets.S()["items"][id]["status"], "working", "repaired")
	var cash := Ledger.cash(entity)
	Assets.on_company_closed(entity)
	_near(Ledger.cash(entity)-cash, 500, 0.001, "50 percent auction")
	_near(Ledger.balance(entity, "fixed_assets"), 0, 0.001, "asset derecognised")
	Assets.on_company_closed(entity)
	_near(Ledger.cash(entity)-cash, 500, 0.001, "one auction only")
	runner.check(Ledger.check_balanced(), "asset balanced")

func test_rented_asset_deposit_return_and_lazy_old_save_state() -> void:
	var entity := _company()
	var result := Assets.rent({"entity":entity, "price":100, "deposit":200, "life_days":365, "rent_days":30})
	runner.check(result["ok"], "rented")
	Assets.on_company_closed(entity)
	_near(Ledger.balance(entity, "deposits"), 0, 0.001, "deposit returned")
	GameState.data.erase("operating_assets")
	GameState.data.erase("jobs_service")
	runner.check(Assets.S()["items"].is_empty(), "old asset section lazily created")
	runner.check(Jobs.S()["items"].is_empty(), "old job section lazily created")
	runner.check(Ledger.check_balanced(), "rental balanced")


func test_asset_rounding_finishes_at_end_of_life_and_lending_counts_assets() -> void:
	var entity := _company()
	var before := float(Bank.lending_basis()["raw"])
	var result := Assets.buy({"entity":entity, "price":100, "life_days":3, "failure_chance":0})
	runner.check(result["ok"], "purchased")
	_near(float(Bank.lending_basis()["raw"])-before, 50, 0.001, "fixed asset collateral")
	Clock.advance(3*Clock.DAY)
	_near(Ledger.balance(entity, "fixed_assets"), 0, 0.001, "rounding remainder cleared at life end")
	_near(Ledger.balance(entity, "exp:depreciation"), 100, 0.001, "exact full depreciation")
	runner.check(Ledger.check_balanced(), "balanced")

func test_old_save_load_preserves_jobs_assets_and_segment_reports() -> void:
	var entity := _company()
	Assets.buy({"entity":entity, "price":100, "life_days":30})
	var id := Jobs.offer({"entity":entity, "client":"client", "scope":"work", "price":100, "terms":30})
	Jobs.accept(id)
	SaveSystem.save(77)
	runner.check(SaveSystem.load_data(77), "round trip loads")
	runner.eq(Jobs.get_job(id)["status"], "active", "job preserved")
	runner.eq(Assets.S()["items"].size(), 1, "asset preserved")
	var old := GameState.data.duplicate(true)
	old.erase("operating_assets")
	old.erase("jobs_service")
	GameState.data = SaveSystem._migrate(old)
	runner.check(Assets.S()["items"].is_empty(), "genuine old schema accepts new lazy section")
	runner.check(Ledger.check_balanced(), "load never rewrites money")


class Extension extends RefCounted:
	static var calls := 0
	static func handle(_kind: String, _p: Dictionary) -> void: calls += 1
	static func on_hour(_t: int, _h: int) -> void: calls += 10
	static func is_running() -> bool: return true
	static func on_company_closed(_ent: String) -> void: calls += 100
	static func os_tab() -> Dictionary: return {"id":"extension", "label":"test", "icon":"tasks", "method":"_tab_overview"}
	static func board_detail() -> Callable: return render
	static func render(_details: Control, _board: Node) -> void: pass
	static func segment_tag() -> String: return "extension"

func test_extension_registers_routes_hours_dispatch_tabs_and_closure() -> void:
	var record := {"id":"extension", "sim_class":Extension, "prefixes":["ext"]}
	Extension.calls = 0
	runner.check(Industries.register(record), "extension registered")
	runner.check(Industries.dispatch("ext.complete", {}), "extension dispatched")
	Industries.on_hour(Clock.now(), 3, "business")
	runner.check(Industries.tabs().any(func(t): return t["id"] == "extension"), "extension tab visible")
	Industries.on_company_closed("test")
	runner.eq(Extension.calls, 111, "hooks reached")
	Industries._extra.erase(record)
