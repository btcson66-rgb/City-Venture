extends RefCounted
## Regression tests for the review of the Chain A (#39-#45) and Chain B (#62-#66) merge.
var runner

func _temp_saves(tag: String) -> void:
	SaveSystem.DIR = "user://review_%s_%d" % [tag, Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)

func _restore_saves() -> void:
	SaveSystem.DIR = "user://test_saves"

# ------------------------------------------------------------------ money
func test_unit_prices_and_shop_labels_keep_cents() -> void:
	runner.check("$4.50" in SavedText.display("Latte for $4.50"), "memo text keeps cents")
	runner.check("$1,200" in SavedText.display("Rent $1,200"), "whole-dollar totals stay compact")
	runner.eq(BuildingInfo.action_label("Buy for $4", "buy_item", {"price": 4.5}), "Buy for $4.50", "shop label quotes the real unit price")
	runner.eq(BuildingInfo.action_label("Buy for $4", "buy_item", {"price": 4.0}), "Buy for $4", "whole price unchanged")

# ------------------------------------------------------------------ saves
func test_autosave_does_not_rotate_backups_every_time() -> void:
	_temp_saves("bak")
	SaveSystem._last_rotate.clear()
	GameState.data["meta"]["slot"] = 1
	runner.check(SaveSystem.save(1), "first manual save")
	GameState.data["player"]["name"] = "Second"
	runner.check(SaveSystem.save(1), "second manual save rotates")
	var base: String = SaveSystem._path(1).trim_suffix(".json")
	runner.check(FileAccess.file_exists(base + ".bak1"), "manual save keeps a backup")
	var bak1 := FileAccess.get_file_as_string(base + ".bak1")
	for i in 5:
		GameState.data["player"]["name"] = "Auto %d" % i
		SaveSystem.autosave()
	runner.eq(FileAccess.get_file_as_string(base + ".bak1"), bak1, "autosaves leave the last good backup alone")
	runner.check(not FileAccess.file_exists(base + ".bak2"), "autosaves do not push history along")
	SaveSystem._last_rotate[1] = 0.0
	SaveSystem.autosave()
	runner.check(FileAccess.file_exists(base + ".bak2"), "an autosave rotates once the interval has passed")
	_restore_saves()

func test_save_list_only_looks_for_backups_of_corrupt_slots() -> void:
	_temp_saves("list")
	runner.check(SaveSystem.save(1) and SaveSystem.save(1), "healthy slot with a backup")
	runner.check(SaveSystem.save(2) and SaveSystem.save(2), "second slot")
	var f := FileAccess.open(SaveSystem._path(2), FileAccess.WRITE)
	f.store_string("not a save")
	f.close()
	SaveSystem._summary_cache.clear()
	var list := SaveSystem.save_list()
	var healthy: Dictionary = list.filter(func(e): return e["slot"] == 1)[0]
	var broken: Dictionary = list.filter(func(e): return e["slot"] == 2)[0]
	runner.check(not healthy["corrupt"] and int(healthy["backup"]) == -1, "healthy slot needs no recovery lookup")
	runner.check(broken["corrupt"] and int(broken["backup"]) >= 1, "corrupt slot offers its backup")
	var again: Dictionary = SaveSystem.summary(1)
	runner.check(not again.is_empty() and SaveSystem._summary_cache.has(1), "decoded summary is cached")
	GameState.data["player"]["name"] = "Changed"
	SaveSystem.save(1)
	runner.check(not SaveSystem._summary_cache.has(1), "a write invalidates the cache")
	runner.eq(SaveSystem.summary(1)["name"], "Changed", "fresh summary after write")
	_restore_saves()

func test_new_game_reports_a_slot_that_cannot_be_claimed() -> void:
	_temp_saves("claim")
	runner.check(SaveSystem.save(1), "occupied slot")
	var blocker := FileAccess.open(SaveSystem.DIR + "/replaced", FileAccess.WRITE)
	blocker.store_string("x")
	blocker.close()
	SaveSystem.next_slot = 1
	SaveSystem.last_error = ""
	var started := GameState.new_game({"name": "Blocked"})
	runner.check(not started, "new_game refuses to carry on")
	runner.check(not GameState.has_game(), "no unsavable game is left in memory")
	runner.check(SaveSystem.last_error != "", "the reason is available to show the player")
	runner.check(FileAccess.file_exists(SaveSystem._path(1)), "the existing save is untouched")
	SaveSystem.next_slot = -1
	_restore_saves()

func test_non_bool_flags_are_coerced_not_rejected() -> void:
	_temp_saves("flags")
	runner.check(SaveSystem.save(1), "source save")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem._path(1)))
	payload["data"]["flags"]["odd_one"] = 1
	payload["data"]["flags"]["odd_zero"] = 0
	payload["data"]["flags"]["odd_text"] = "yes"
	payload["data"]["flags"]["odd_empty"] = ""
	var result := SaveCodec.decode(JSON.stringify(payload))
	runner.check(result["ok"], "a save with non-bool flags still loads")
	var flags: Dictionary = result["payload"]["data"]["flags"]
	runner.check(flags["odd_one"] == true and flags["odd_text"] == true, "truthy values become true")
	runner.check(flags["odd_zero"] == false and flags["odd_empty"] == false, "falsy values become false")
	runner.check(flags.values().all(func(v): return v is bool), "every flag is a bool afterwards")
	_restore_saves()

# ------------------------------------------------------------------ guide and UI
func test_property_buildings_are_not_tagged_housing() -> void:
	runner.check(BuildingInfo.guide_tags("pier7_warehouse").find("Housing") == -1, "a warehouse is not housing")
	runner.check(BuildingInfo.guide_tags("pier7_warehouse").find("Property") != -1, "it is tagged as property")

func test_availability_is_remembered_per_minute() -> void:
	var bid := "nexus_bank"
	BuildingInfo.invalidate_availability()
	var first := BuildingInfo.building_available(bid)
	runner.check(BuildingInfo._avail_cache.has(bid), "answer remembered")
	runner.eq(BuildingInfo.building_available(bid), first, "same answer from the memory")
	Clock.advance(1)
	BuildingInfo.building_available("riverside_apartment")
	runner.check(not BuildingInfo._avail_cache.has(bid), "a new game minute starts a fresh memory")

func test_phone_destination_belongs_to_one_game() -> void:
	if UIRoot.tutorial == null: return
	UIRoot.tutorial.guide_to_building("nexus_bank")
	EventBus.state_loaded.emit()
	runner.eq(UIRoot.tutorial._destination, "", "loading a game clears the old destination")
	UIRoot.tutorial.guide_to_building("nexus_bank")
	UIRoot.tutorial.clear_destination()
	runner.eq(UIRoot.tutorial._destination, "", "explicit clear")

func test_markers_do_not_redraw_when_off() -> void:
	var it := Interactable.new()
	Interactable._settings_loaded = true
	var was := Interactable._markers_on
	Interactable._markers_on = false
	it._process(0.5)
	runner.eq(it._phase, 0.0, "markers off: no per-frame animation work")
	Interactable._markers_on = true
	it._process(0.5)
	runner.check(it._phase > 0.0, "markers on: animates")
	Interactable._markers_on = was
	it.free()

func _styled(b: Button) -> bool:
	return b.has_theme_stylebox_override("normal")

func test_decision_choices_are_not_nudged() -> void:
	var inst := EventEngine.trigger("low_cash_warning", {"entity": "player", "entity_name": "You", "cash": "$1", "upcoming": "$0"})
	var modal := DecisionModal.new(inst)
	UIRoot.open_modal(modal)
	await runner.get_tree().process_frame
	var buttons := modal.find_children("Choice_*", "Button", true, false)
	runner.check(buttons.size() >= 2, "decision has several choices")
	runner.check(buttons.all(func(b): return not _styled(b)), "no choice is primary unless the data recommends it")
	var choices: Array = modal.def["choices"]
	choices[0]["recommended"] = true
	modal.rebuild()
	await runner.get_tree().process_frame
	buttons = modal.find_children("Choice_*", "Button", true, false)
	runner.check(_styled(buttons[0]) and not _styled(buttons[1]), "a recommended choice is the single primary")
	choices[0].erase("recommended")
	modal.close()

func test_city_guide_has_no_primary_on_every_card() -> void:
	var modal := CityGuideModal.new()
	UIRoot.open_modal(modal)
	await runner.get_tree().process_frame
	var routes := modal.find_children("GuideTo_*", "Button", true, false)
	runner.check(routes.size() > 0, "guide lists destinations")
	runner.check(routes.all(func(b): return not _styled(b)), "'Take me there' is a plain button")
	modal.close()

# ------------------------------------------------------------------ jobs
func test_unaccepted_offers_expire() -> void:
	Company.register("Jobs Test", "media", "The Loft")
	var id := Jobs.offer({"entity": GameState.company_id(), "client": "Nobody", "scope": "Test", "price": 100.0, "due": Clock.now() + 2 * Clock.DAY, "terms": 0})
	runner.eq(Jobs.get_job(id)["status"], "offered", "offered")
	Clock.advance(1 * Clock.DAY)
	runner.eq(Jobs.get_job(id)["status"], "offered", "still open before its time")
	Clock.advance(3 * Clock.DAY)
	runner.eq(Jobs.get_job(id)["status"], "expired", "swept after expiry")
	runner.check(not Jobs.accept(id)["ok"], "an expired offer cannot be accepted")
	var explicit := Jobs.offer({"entity": GameState.company_id(), "client": "Nobody", "scope": "Test", "price": 100.0, "due": Clock.now() + 30 * Clock.DAY, "expires_at": Clock.now() + Clock.DAY, "terms": 0})
	Clock.advance(3 * Clock.DAY)
	runner.eq(Jobs.get_job(explicit)["status"], "expired", "explicit expires_at wins over due")

func test_invoiced_job_leaves_receivable_for_the_collector_on_close() -> void:
	Company.register("Jobs Close", "media", "The Loft")
	Company.open_business_account(25000)
	var ent := GameState.company_id()
	var id := Jobs.offer({"entity": ent, "client": "Slow Payer", "scope": "Test", "price": 1000.0, "work": 1, "terms": 30})
	runner.check(Jobs.accept(id)["ok"], "accepted")
	Jobs.progress(id, 1)
	runner.check(Jobs.deliver(id)["ok"] and Jobs.invoice(id)["ok"], "delivered and invoiced")
	var owed := Ledger.balance(ent, "accounts_receivable")
	runner.check(owed > 0, "receivable on the books")
	var report := Insolvency.close_company()
	runner.eq(Jobs.get_job(id)["status"], "closed", "job closed with the company")
	runner.check(float(report["report"]["receivables"]) > 0.0, "the open invoice was sold to the collector")
	runner.eq(Ledger.balance(ent, "accounts_receivable"), 0.0, "receivable removed once")
	Clock.advance(31 * Clock.DAY)
	runner.eq(Ledger.balance(ent, "accounts_receivable"), 0.0, "no late collection after the sale")
	runner.check(Ledger.check_balanced(), "closure balanced")

func test_assets_skip_zero_depreciation_entries() -> void:
	Company.register("Dep Test", "media", "The Loft")
	Company.open_business_account(25000)
	var ent := GameState.company_id()
	var bought := Assets.buy({"entity": ent, "price": 1.0, "life_days": 100000, "segment": "media"})
	runner.check(bought["ok"], "tiny asset bought")
	var journal := func() -> int: return Ledger.entries(ent, 5000).filter(func(e): return str(e["memo"]).begins_with("Asset depreciation")).size()
	Clock.advance(3 * Clock.DAY)
	runner.eq(journal.call(), 0, "a daily charge that rounds to zero posts no empty entry")
	runner.check(Ledger.check_balanced(), "still balanced")
