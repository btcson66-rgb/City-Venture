extends Node
## Real ecommerce/clock/save load probe. QA fixtures exceed the hiring limit;
## they are not a winning strategy or evidence of unimplemented industries.

var options := {"days": 3653, "orders": 5000, "staff": 50, "seed": 98001, "out": "user://stress", "wall_seconds": 120, "save_every": 1, "profile": 0, "textures": 0, "resume": 0}
var report := {}
var samples: Array = []
var started := 0
var order_phases := {}
var worst_ms := 0.0
var worst_at := 0


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
	Prof.enabled = int(options["profile"]) > 0
	report = {"schema": 2, "engine": Engine.get_version_info()["string"], "platform": OS.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "options": options,
		"coverage": {"industries": [], "playable_companies": 0, "missing_industries": [],
			"notes": ["Forced orders and staff are saturation fixtures, not normal gameplay.",
				"Coverage is measured from Industries.is_running and the company list after fixture setup.",
				"simulation_ms is the mean cost of one minute tick (a frame at 1x); tick_p99_ms is the p99 of minute ticks incl. hourly/daily work.",
				"Order placement/packing/courier is a player-action batch reported per order (order_ms_per_order).",
				"Compressed bytes are the shipping (gzip) save size."]},
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
	# A 50-person shop has support agents who settle returns (otherwise every return waits for a modal that nobody answers).
	GameState.set_flag("first_issue_resolved")
	for i in int(options["staff"]):
		var id := "stress_%d" % i
		Staff.S()["people"][id] = {"id": id, "name": id, "role": "support" if i % 10 == 0 else "packer", "skill": 0.8,
			"morale": 80, "salary_week": 600.0, "start": Clock.now(), "hired": Clock.now(), "trait": "steady", "weeks": 0}
	_open_industries()
	_measure_coverage()
	if int(options["textures"]) > 0:
		_texture_soak()
	# Flat clock profile is independent of the load and identifies calendar overhead.
	var calendar_start := Time.get_ticks_usec()
	for i in 1440:
		Clock.date_at(i)
	report["calendar_1440_calls_ms"] = (Time.get_ticks_usec() - calendar_start) / 1000.0
	var first_day := 0
	if int(options["resume"]) > 0:
		# Continue an interrupted run from its last snapshot in the same --out (samples and the save stay there).
		var prev := FileAccess.get_file_as_string(str(options["out"]).path_join("stress_result.json"))
		var parsed = JSON.parse_string(prev) if prev != "" else null
		if parsed is Dictionary and SaveSystem.load_data(98):
			for old_sample in parsed.get("samples", []):
				if int(old_sample["day"]) <= int(options["resume"]):
					samples.append(old_sample)
			first_day = int(options["resume"])
			report["resumed_from_day"] = first_day
		else:
			report["errors"].append("Resume requested but the previous report or snapshot could not be loaded")
			_finish()
			return
	for day in range(first_day, int(options["days"])):
		if _expired():
			report["errors"].append("Wall time safety limit reached before all requested days")
			break
		var begin := Time.get_ticks_usec()
		var listing := _prepare_orders(int(options["orders"]))
		var fixture_ms := (Time.get_ticks_usec() - begin) / 1000.0
		var ticks := _run_day_ticks(listing, int(options["orders"]))
		var count: int = ticks["placed"]
		var order_ms: float = ticks["order_ms"]
		order_phases["fixture_ms"] = fixture_ms
		var tick_ms: float = ticks["total_ms"]
		var sample := {"day": day + 1, "orders": count, "staff": Staff.count(),
			"simulation_ms": ticks["mean"], "tick_p99_ms": ticks["p99"], "tick_max_ms": ticks["max"],
			"hour_tick_mean_ms": ticks["hour_mean"], "tick_max_at_minute": worst_at % Clock.DAY, "frame_mean_ms": ticks["frame_mean"], "frame_p99_ms": ticks["frame_p99"],
			"day_total_ms": tick_ms, "orders_ms": order_ms, "order_ms_per_order": order_ms / maxf(1.0, count),
			"order_phases_ms": order_phases.duplicate(),
			"memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
			"journal_entries": GameState.data["ledger"]["journal"].size(), "orders_held": Ecommerce.E()["orders"].size(),
			"balanced": Ledger.check_balanced()}
		var save_day: bool = day == 0 or (day + 1) % maxi(1, int(options["save_every"])) == 0 or day + 1 == int(options["days"])
		if save_day:
			begin = Time.get_ticks_usec()
			var path := SaveSystem.DIR.path_join("slot_98.json")
			if not SaveSystem.save_to(path, 98):
				report["errors"].append("Snapshot write failed")
				break
			sample["save_ms"] = (Time.get_ticks_usec() - begin) / 1000.0
			var bytes := FileAccess.get_file_as_bytes(path)
			sample["json_bytes"] = bytes.size()
			sample["gzip_bytes"] = bytes.compress(FileAccess.COMPRESSION_GZIP).size() if not (bytes.size() > 2 and bytes[0] == 0x1f and bytes[1] == 0x8b) else bytes.size()
			begin = Time.get_ticks_usec()
			sample["loaded"] = SaveSystem.load_data(98)
			sample["load_ms"] = (Time.get_ticks_usec() - begin) / 1000.0
			sample["balanced"] = Ledger.check_balanced()
			# A load replaces every state dictionary; release the previous generation now, not inside the next timed tick.
			for company in CompanyPortfolio.ids():
				CompanyPortfolio.run_in(str(company), func(): pass)
			if not sample["loaded"]:
				report["errors"].append("Load failed: " + str(SaveSystem.last_error))
		if int(options["profile"]) > 0:
			var keys := Prof.d.keys()
			keys.sort_custom(func(a, b): return Prof.d[a] > Prof.d[b])
			var line := ""
			for k in keys.slice(0, 22):
				line += "%s=%.0f " % [k, Prof.d[k] / 1000.0]
			print("PROF(ms/day) ", line)
			Prof.d.clear()
			var types := {}
			for je in GameState.data["ledger"]["journal"]:
				var key := "%s/%s" % [je.get("source", {}).get("type", "?"), je.get("source", {}).get("segment", "?")]
				types[key] = int(types.get(key, 0)) + 1
			print("JOURNAL types ", types)
		samples.append(sample)
		print("STRESS day %d: %d orders (%.3f ms/order), tick mean %.3f p99 %.3f max %.1f ms, frame p99 %.3f, %d MB, %s" % [day + 1, count, sample["order_ms_per_order"], sample["simulation_ms"], sample["tick_p99_ms"], sample["tick_max_ms"], sample["frame_p99_ms"], int(sample["memory_bytes"]) / 1048576, ("gzip %d load %.0f ms" % [sample["gzip_bytes"], sample["load_ms"]]) if save_day else "-"])
		if day % 10 == 0 or save_day:
			_write_report()
		if (save_day and not bool(sample["loaded"])) or not bool(sample["balanced"]) or count != int(options["orders"]):
			report["errors"].append("Incomplete workload, failed load or unbalanced ledger")
			break
		if int(sample["memory_bytes"]) > 2000000000:
			report["errors"].append("2 GB process allocation safety limit reached")
			break
		if day % 20 == 0:
			await get_tree().process_frame
	report["completed"] = samples.size() == int(options["days"]) and report["errors"].is_empty()
	_finish()


## One game day as 1,440 real minute ticks, each timed. A tick is one frame at 1x speed; the frame
## figure adds the time_changed observers a rendered frame also pays.
func _run_day_ticks(listing: Dictionary, n_orders: int) -> Dictionary:
	var times := PackedFloat64Array()
	var frames := PackedFloat64Array()
	var hours := PackedFloat64Array()
	var total := 0.0
	worst_ms = 0.0
	var placed := 0
	var order_ms := 0.0
	var wall0 := Time.get_ticks_usec()
	order_phases = {"place_ms": 0.0, "pack_ms": 0.0, "courier_ms": 0.0}
	for i in Clock.DAY:
		# Orders arrive through the day (a share each hour) and are packed and booked at once, like a busy shop.
		if i % 60 == 0 and not listing.is_empty():
			var hour := i / 60
			var share := n_orders / 24 + (1 if hour < n_orders % 24 else 0)
			var b := Time.get_ticks_usec()
			placed += _order_batch(listing, share)
			order_ms += (Time.get_ticks_usec() - b) / 1000.0
		var before: Dictionary = Prof.d.duplicate() if Prof.enabled else {}
		var t0 := Time.get_ticks_usec()
		Clock._tick()
		var t1 := Time.get_ticks_usec()
		Clock.time_changed.emit()
		var t2 := Time.get_ticks_usec()
		var ms := (t1 - t0) / 1000.0
		if Prof.enabled and ms > 100.0:
			var parts := ""
			for k in Prof.d:
				var delta: int = int(Prof.d[k]) - int(before.get(k, 0))
				if delta > 100:
					parts += "%s=%.0f " % [k, delta / 1000.0]
			print("SLOW TICK %.0f ms i=%d at minute %d: %s" % [ms, i, Clock.now() % Clock.DAY, parts])
		if ms > worst_ms:
			worst_ms = ms
			worst_at = Clock.now()
		times.append(ms)
		frames.append((t2 - t0) / 1000.0)
		if Clock.now() % 60 == 0:
			hours.append(ms)
		total += ms
	var sorted := times.duplicate()
	sorted.sort()
	var fsorted := frames.duplicate()
	fsorted.sort()
	var hour_sum := 0.0
	for h in hours:
		hour_sum += h
	var frame_sum := 0.0
	for f in frames:
		frame_sum += f
	var rank := int(ceil(times.size() * 0.99)) - 1
	return {"mean": total / times.size(), "p99": sorted[rank], "max": sorted[sorted.size() - 1],
		"hour_mean": hour_sum / maxf(1.0, hours.size()), "placed": placed, "order_ms": order_ms, "total_wall_ms": (Time.get_ticks_usec() - wall0) / 1000.0, "frame_mean": frame_sum / frames.size(), "frame_p99": fsorted[rank], "total_ms": total}


## A player who walks every district, NPC and outfit asks the art cache for every detail texture. The cache keeps
## its own byte accounting (RGBA8 plus mipmaps), so the peak it reports is what the renderer would have to hold.
## It is an accounted figure, not a GPU read-out; the report says so.
func _texture_soak() -> void:
	var begin := Time.get_ticks_usec()
	var paths: Array = []
	_collect_pngs("res://assets/world_detail", "world_detail", paths)
	paths.sort()
	Art.peak_texture_bytes = 0
	var asked := 0
	for path in paths:
		Art.tex(path)
		asked += 1
	# A second walk in reverse order proves eviction keeps the budget when textures are re-requested.
	for i in range(paths.size() - 1, -1, -1):
		Art.tex(paths[i])
	report["texture_bytes"] = Art.peak_texture_bytes
	var held := Art.texture_bytes()
	Art.clear_caches()   # the soak is over; the simulation timings below must not carry 900 MB of art
	report["texture_source"] = "accounted"
	report["texture_soak"] = {"textures_requested": asked, "budget_bytes": Art.TEXTURE_BUDGET_BYTES, "held_bytes": held,
		"ms": (Time.get_ticks_usec() - begin) / 1000.0}
	print("TEXTURES requested %d, peak accounted %d MB, held %d MB" % [asked, Art.peak_texture_bytes / 1048576, held / 1048576])


func _collect_pngs(dir_path: String, prefix: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect_pngs(dir_path.path_join(sub), prefix + "/" + sub, out)
	for file in dir.get_files():
		if file.ends_with(".png"):
			out.append(prefix + "/" + file.get_basename())


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
func _prepare_orders(n: int) -> Dictionary:
	var ent := GameState.business_entity()
	# The saturation fixture counts one-unit orders; random multi-unit baskets (#113) would exhaust the stock early.
	DataDB.economy["ecommerce"]["basket_chance"] = 0.0
	DataDB.economy["ecommerce"]["quantity_chance"] = 0.0
	# Support agents replace some returned parcels from stock, so the fixture restocks a little above the order count.
	var stock := n + n / 5
	Ecommerce._add_stock("riverside_studio", "phone_stand", stock, 5.0, 0.02)
	Ledger.post(ent, "Stress fixture stock", [{"acct": "inventory", "dr": stock * 5.0}, {"acct": "equity", "cr": stock * 5.0}], {"type": "opening"})
	var listing := Ecommerce.listing_for("phone_stand")
	if listing.is_empty():
		var result := Ecommerce.create_listing("phone_stand", 16.0, "self")
		if not result.get("ok", false):
			report["errors"].append("Fixture listing failed: " + str(result))
			return {}
		listing = Ecommerce.E()["listings"][result["listing_id"]]
	# No extra stochastic demand beyond the requested saturation workload.
	listing["active"] = false
	return listing


## Exercise the real order placement, packing, shipping and scheduled aftersales for one hour's share.
func _order_batch(listing: Dictionary, n: int) -> int:
	var before := int(GameState.stat("orders_placed"))
	var t := Time.get_ticks_usec()
	listing["active"] = true
	for i in n:
		Ecommerce._h_order_place({"listing": listing["id"]})
	listing["active"] = false
	order_phases["place_ms"] = float(order_phases["place_ms"]) + (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	Ecommerce.pack_orders("riverside_studio")
	order_phases["pack_ms"] = float(order_phases["pack_ms"]) + (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	Ecommerce.courier_pickup("riverside_studio", "economy")
	order_phases["courier_ms"] = float(order_phases["courier_ms"]) + (Time.get_ticks_usec() - t) / 1000.0
	return int(GameState.stat("orders_placed")) - before


func _give_cash(entity: String, amount: float) -> void:
	Ledger.post(entity, "Stress fixture capital", [{"acct": "cash", "dr": amount}, {"acct": "equity", "cr": amount}], {"type": "opening"})


func _must(result: Dictionary, label: String) -> void:
	if not result.get("ok", false):
		report["errors"].append("Fixture %s failed: %s" % [label, str(result.get("error", result))])


## Company one runs ecommerce + manufacturing + media + real estate + hotel; company two runs
## automotive + energy + international trade, so every required industry is genuinely live.
func _open_industries() -> void:
	var first := GameState.company_id()
	_give_cash("player", 5000000.0)
	GameState.mark_visited("the_aster")
	_must(Living.lease("unit12_factory"), "lease factory")
	_must(Manufacturing.start(), "manufacturing")
	_must(Living.lease("loft_office"), "lease loft")
	_must(Media.start(), "media")
	_must(Living.lease("realty_office"), "lease realty")
	Compliance.S()["permits"] = Compliance.S().get("permits", {})
	Compliance.S()["permits"]["brokerage"] = {"entity": first, "status": "granted"}
	_must(RealEstate.start(), "real estate")
	_must(Hotel.start("own"), "hotel")
	var second_result := Company.register("Stress Two", "llc", "riverside_studio")
	_must(second_result, "second company")
	_must(Company.open_business_account(10000), "second account")
	var second := GameState.company_id()
	_give_cash(second, 1000000000.0)
	_must(Automotive.start(), "automotive")
	_must(Living.lease("helio_warehouse"), "lease warehouse")
	_must(Energy.start(), "energy")
	_must(Living.lease("meridian_trade_office"), "lease trade desk")
	_must(TradeIndustry.register(), "trade registration")
	_must(TradeIndustry.start(), "trade brokerage")
	CompanyPortfolio.switch(first)


func _measure_coverage() -> void:
	var running: Array = []
	var missing: Array = []
	var cov: Dictionary = report["coverage"]
	var live := {}
	for company in CompanyPortfolio.ids():
		CompanyPortfolio.run_in(str(company), func():
			for entry in Industries.all():
				if entry.get("auxiliary", false):
					continue
				if entry["sim_class"].is_running():
					live[str(entry["id"])] = true)
	for id in ["manufacturing", "real_estate", "media", "hotel", "automotive", "energy", "international_trade"]:
		(running if live.has(id) else missing).append(id)
	if live.has("ecommerce") or Ecommerce.is_running():
		running.append("ecommerce")
	cov["industries"] = running
	cov["missing_industries"] = missing
	cov["playable_companies"] = CompanyPortfolio.ids().size()
	if not missing.is_empty():
		report["errors"].append("Industries not running: " + ", ".join(missing))


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
