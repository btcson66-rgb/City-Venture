extends RefCounted
## Saves from older builds keep working: missing sections are filled from today's template, and a story step can't
## stay stuck on a contract offer that already ended.

var runner


func test_old_save_gets_new_sections() -> void:
	var old: Dictionary = GameState.data.duplicate(true)
	old.erase("world")                      # a section a later build added
	old["living"].erase("leases")          # and a field inside an existing section
	var d := SaveSystem._migrate(old)
	runner.check(d.has("world") and int(d["world"]["year"]) == 1, "missing section filled from the template")
	runner.check(d["living"].has("leases"), "missing field filled")
	runner.eq(str(d["player"]["name"]), str(GameState.data["player"]["name"]), "existing values untouched")


func test_walked_away_offer_settles_the_story_step() -> void:
	Company.register("Compat Co", "ecommerce", "22 Founders Lane")
	var c := {"id": "C-900", "tag": "big_contract", "status": "withdrawn", "buyer": "crestline"}
	GameState.data["contracts"]["C-900"] = c
	runner.check(not GameState.flag("big_contract_decided"), "an older build left the step waiting")
	Contracts.reconcile_tags()
	runner.check(GameState.flag("big_contract_decided") and GameState.flag("big_contract_declined"), "repaired on load")
