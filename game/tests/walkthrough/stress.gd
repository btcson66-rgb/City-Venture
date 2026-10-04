extends Node
## Real ecommerce/clock/save load probe. QA fixtures exceed the hiring limit;
## they are not a winning strategy or evidence of unimplemented industries.

var options := {"days": 3653, "orders": 5000, "staff": 50, "seed": 98001, "out": "user://stress", "wall_seconds": 120}
var report := {}
var samples: Array = []
var started := 0
var order_phases := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		for key in options:
			var prefix := "--%s=" % key
			if arg.begins_with(prefix):
				options[key] = arg.substr(prefix.length()) if key == "out" else int(arg.substr(prefix.length()))
	call_deferred("_run")


func _run() -> void:
	if not safe_output_directory(str(options["out"])):
		push_error("Stress output must be isolated from player saves")
		get_tree().quit(1)
		return
	SaveSystem.autosave_enabled = false
	SaveSystem.DIR = str(options["out"]).path_join("saves")
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	started = Time.get_ticks_usec()
	report = {"schema": 1, "engine": Engine.get_version_info()["string"], "platform": OS.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "options": options,
		"coverage": {"industries": ["ecommerce"], "playable_companies": 1,
			"missing_industries": ["manufacturing", "real_estate", "media", "hotel", "automotive", "energy", "international_trade"],
			"notes": ["Forced orders and staff are saturation fixtures, not normal gameplay.",
				"Additional company/industry activation requires the upstream gameplay implementations.",
				"Compressed bytes measure a gzip copy; shipping saves still use JSON."]},
		"samples": samples, "errors": [], "completed": false, "texture_bytes": null}
	if int(options["days"]) < 1 or int(options["orders"]) < 0 or int(options["staff"]) < 0 or int(options["wall_seconds"]) < 1:
		report["errors"].append("Invalid nonpositive duration or negative workload")
		_finish()
		return
	# Exclude presentation observers from this simulation probe. The rendered Web
	# budget requires a separate browser capture; headless texture memory is UNKNOWN.
	for connection in EventBus.notify.get_connections():
		EventBus.notify.disconnect(connection["callable"])
	for connection in EventBus.message_received.get_connections():
		EventBus.message_received.disconnect(connection["callable"])
	UIRoot._suppress_decisions = true
	Help.auto = false
	Clock.world_active = false
	GameState.new_game({"name": "Stress Founder", "seed": options["seed"]})
	# Never replace a player's slot. All snapshots stay inside the explicit QA out.
	GameState.data["meta"]["slot"] = 98
	Company.register("Stress Company", "llc", "riverside_studio")
	Company.open_business_account(10000)
	var ent := GameState.business_entity()
	Ledger.post(ent, "Stress fixture capital", [{"acct": "cash", "dr": 1000000000.0}, {"acct": "equity", "cr": 1000000000.0}], {"type": "opening"})
	for i in int(options["staff"]):
		var id := "stress_%d" % i
		Staff.S()["people"][id] = {"id": id, "name": id, "role": "packer", "skill": 0.8,
			"morale": 80, "salary_week": 600.0, "start": Clock.now(), "hired": Clock.now(), "trait": "steady", "weeks": 0}
	# Flat clock profile is independent of the load and identifies calendar overhead.
	var calendar_start := Time.get_ticks_usec()
	for i in 1440:
		Clock.date_at(i)
	report["calendar_1440_calls_ms"] = (Time.get_ticks_usec() - calendar_start) / 1000.0
	for day in int(options["days"]):
		if _expired():
			report["errors"].append("Wall time safety limit reached before all requested days")
			break
		var begin := Time.get_ticks_usec()
		var count := _orders(int(options["orders"]))
		var order_ms := (Time.get_ticks_usec() - begin) / 1000.0
		begin = Time.get_ticks_usec()
		Clock.advance(Clock.DAY)
		var tick_ms := (Time.get_ticks_usec() - begin) / 1000.0
		begin = Time.get_ticks_usec()
		var path := SaveSystem.DIR.path_join("slot_98.json")
		if not SaveSystem.save_to(path, 98):
			report["errors"].append("Snapshot write failed")
			break
		var save_ms := (Time.get_ticks_usec() - begin) / 1000.0
		var bytes := FileAccess.get_file_as_bytes(path)
		var compressed := bytes.compress(FileAccess.COMPRESSION_GZIP)
		begin = Time.get_ticks_usec()
		var loaded := SaveSystem.load_data(98)
		var load_ms := (Time.get_ticks_usec() - begin) / 1000.0
		var sample := {"day": day + 1, "orders": count, "staff": Staff.count(),
			"simulation_ms": order_ms + tick_ms, "orders_ms": order_ms, "ticks_ms": tick_ms,
			"order_phases_ms": order_phases.duplicate(),
			"memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"json_bytes": bytes.size(), "gzip_bytes": compressed.size(), "save_ms": save_ms, "load_ms": load_ms,
			"loaded": loaded, "balanced": Ledger.check_balanced(), "journal_entries": GameState.data["ledger"]["journal"].size()}
		samples.append(sample)
		print("STRESS day %d: %d orders, %.3f ms sim, %d bytes gzip, %.3f ms load" % [day + 1, count, sample["simulation_ms"], compressed.size(), load_ms])
		_write_report()
		if not loaded or not bool(sample["balanced"]) or count != int(options["orders"]):
			report["errors"].append("Incomplete workload, failed load or unbalanced ledger")
			if not loaded: report["errors"].append("Load failed: " + str(SaveSystem.last_error))
			break
		if int(sample["memory_bytes"]) > 512000000:
			report["errors"].append("512 MB process allocation safety limit reached")
			break
		await get_tree().process_frame
	report["completed"] = samples.size() == int(options["days"]) and report["errors"].is_empty()
	_finish()


func _expired() -> bool:
	return Time.get_ticks_usec() - started > int(options["wall_seconds"]) * 1000000


## An explicit QA output must never make new_game claim or back up a player's slot.
static func safe_output_directory(path: String) -> bool:
	if path.strip_edges().is_empty():
		return false
	var dir := ProjectSettings.globalize_path(path).simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	var home := ProjectSettings.globalize_path("user://").simplify_path().replace("\\", "/").trim_suffix("/").to_lower()
	var saves := home + "/saves"
	return dir != home and dir != saves and not dir.begins_with(saves + "/")


## Exercise the real order placement, packing, shipping and scheduled aftersales.
## Stock is fixture-supplied with matching inventory/equity entries, never free cash.
func _orders(n: int) -> int:
	var start := Time.get_ticks_usec()
	var ent := GameState.business_entity()
	# The saturation fixture counts one-unit orders; random multi-unit baskets (#113) would exhaust the stock early.
	DataDB.economy["ecommerce"]["basket_chance"] = 0.0
	DataDB.economy["ecommerce"]["quantity_chance"] = 0.0
	Ecommerce._add_stock("riverside_studio", "phone_stand", n, 5.0, 0.02)
	Ledger.post(ent, "Stress fixture stock", [{"acct": "inventory", "dr": n * 5.0}, {"acct": "equity", "cr": n * 5.0}], {"type": "opening"})
	var listing := Ecommerce.listing_for("phone_stand")
	if listing.is_empty():
		var result := Ecommerce.create_listing("phone_stand", 16.0, "self")
		if not result.get("ok", false):
			report["errors"].append("Fixture listing failed: " + str(result))
			return 0
		listing = Ecommerce.E()["listings"][result["listing_id"]]
	listing["active"] = true
	var before := int(GameState.stat("orders_placed"))
	order_phases = {"fixture_ms": (Time.get_ticks_usec() - start) / 1000.0}
	start = Time.get_ticks_usec()
	for i in n:
		Ecommerce._h_order_place({"listing": listing["id"]})
		if i % 100 == 0 and _expired():
			break
	var count := int(GameState.stat("orders_placed")) - before
	order_phases["place_ms"] = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	Ecommerce.pack_orders("riverside_studio")
	order_phases["pack_ms"] = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	Ecommerce.courier_pickup("riverside_studio", "economy")
	order_phases["courier_ms"] = (Time.get_ticks_usec() - start) / 1000.0
	# No extra stochastic demand beyond the requested saturation workload.
	listing["active"] = false
	return count


func _write_report() -> void:
	var file := FileAccess.open(str(options["out"]).path_join("stress_result.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write stress report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _finish() -> void:
	report["wall_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	_write_report()
	print("STRESS FINISHED: %d/%d days, completed=%s" % [samples.size(), int(options["days"]), str(report["completed"])])
	get_tree().quit(0 if report["completed"] else 1)
