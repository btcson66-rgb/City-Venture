extends RefCounted
## Generic story sequencing, including valid company save roundtrips.

var runner
var original: Dictionary


func _fixture() -> void:
	original = DataDB.story
	DataDB.story = original.duplicate(true)
	var objectives: Array = []
	for i in 3:
		objectives.append({"id": "test_side_%d" % i, "_side_story": "test_side", "text": "Test step",
			"complete_when": ["flag:test_side_%d" % i], "skip_when": ["flag:test_side_impossible"],
			"skip_text": "This opportunity is no longer available.",
			"on_complete": [{"do": "set_flag", "flag": "test_side_action_%d" % i}]})
	DataDB.story["side_stories"] = {"test_side": {"id": "test_side", "business": "ecommerce",
		"title": "Test opportunity", "trigger": ["world_year>=2"], "objectives": objectives,
		"on_complete": [{"do": "timeline", "text": "Test side story complete.", "kind": "side_story"},
			{"do": "set_flag", "flag": "test_side_reward"}],
		"on_unavailable": [{"do": "set_flag", "flag": "test_side_unavailable"}]}}
	DataDB.story["side"].append_array(objectives)
	Company.register("Side Test", "ecommerce", "Riverside")
	GameState.data["world"]["year"] = 2


func _restore() -> void:
	DataDB.story = original


func test_trigger_requires_company_and_timing() -> void:
	_fixture()
	runner.check(StoryEngine.side_available("test_side"), "company and timing qualify")
	GameState.data["company"] = ""
	runner.check(not StoryEngine.side_available("test_side"), "no company blocks acceptance")
	GameState.data["company"] = "co_side_test"
	GameState.data["world"]["year"] = 1
	runner.check(not StoryEngine.side_available("test_side"), "too early blocks acceptance")
	_restore()


func test_missing_business_and_unknown_story_are_unavailable() -> void:
	_fixture()
	DataDB.story["side_stories"]["test_side"]["business"] = "not_implemented"
	runner.check(not StoryEngine.side_available("test_side"), "unimplemented industry has no live opportunity")
	runner.check(not StoryEngine.start_side_story("unknown"), "unknown id fails safely")
	_restore()


func test_sequence_completes_without_changing_main_chapter() -> void:
	_fixture()
	var chapter := str(StoryEngine.St()["chapter"])
	var cash := Ledger.cash("player")
	runner.check(StoryEngine.start_side_story("test_side"), "accept opportunity")
	for i in 3:
		runner.check("test_side_%d" % i in StoryEngine.St()["active"], "next step is active")
		GameState.set_flag("test_side_%d" % i)
		StoryEngine.check()
	runner.eq(StoryEngine.side_progress()["test_side"]["status"], "completed", "story completes")
	runner.check(GameState.flag("test_side_reward"), "non-cash reward issued")
	runner.eq(Ledger.cash("player"), cash, "story does not manufacture cash")
	runner.check(Ledger.check_balanced(), "ledger stays balanced")
	runner.eq(StoryEngine.St()["chapter"], chapter, "main chapter unchanged")
	_restore()


func test_every_step_already_done_drains_immediately() -> void:
	_fixture()
	for i in 3:
		GameState.set_flag("test_side_%d" % i)
	StoryEngine.start_side_story("test_side")
	runner.eq(StoryEngine.side_progress()["test_side"]["status"], "completed", "no new tick required")
	runner.eq(StoryEngine.St()["active"].filter(func(id): return str(id).begins_with("test_side_")).size(), 0, "no stranded objective")
	StoryEngine.check()
	runner.eq(GameState.data["timeline"].filter(func(t): return t["kind"] == "side_story").size(), 1, "completion timeline only once")
	runner.check(not StoryEngine.start_side_story("test_side"), "cannot replay completed reward")
	_restore()


func test_every_step_impossible_drains_without_rewards() -> void:
	_fixture()
	GameState.set_flag("test_side_impossible")
	StoryEngine.start_side_story("test_side")
	runner.eq(StoryEngine.side_progress()["test_side"]["status"], "unavailable", "all unavailable steps drain")
	runner.check(not GameState.flag("test_side_reward"), "no completion reward for unavailable branch")
	for i in 3:
		runner.check(not GameState.flag("test_side_action_%d" % i), "skipped step does not run success action")
	runner.check(GameState.flag("test_side_unavailable"), "fallback runs")
	_restore()


func test_company_closure_removes_active_side_objective() -> void:
	_fixture()
	StoryEngine.start_side_story("test_side")
	GameState.data["entities"]["co_side_test"]["closed"] = Clock.now()
	StoryEngine.check()
	runner.eq(StoryEngine.side_progress()["test_side"]["status"], "unavailable", "closed owner cancels story")
	runner.check(not "test_side_0" in StoryEngine.St()["active"], "no dangling step")
	runner.check(not GameState.flag("test_side_reward"), "no reward on closure")
	_restore()


func test_save_roundtrip_resumes_and_old_save_initializes() -> void:
	_fixture()
	StoryEngine.start_side_story("test_side")
	GameState.set_flag("test_side_0")
	StoryEngine.check()
	runner.check(SaveSystem.save(97), "save active side story")
	GameState.data["story"].erase("side_stories")
	runner.check(SaveSystem.load_data(97), "load side story")
	runner.eq(StoryEngine.side_progress()["test_side"]["status"], "active", "receipt survives")
	runner.check("test_side_1" in StoryEngine.St()["active"], "next step survives")
	var old: Dictionary = GameState.data.duplicate(true)
	old["story"].erase("side_stories")
	GameState.data = SaveSystem._migrate(old)
	runner.check(StoryEngine.side_progress().is_empty(), "old save initializes additive state")
	DirAccess.remove_absolute(SaveSystem._path(97))
	_restore()


func test_phone_opportunities_empty_state_and_acceptance() -> void:
	_fixture()
	UIRoot.phone._go("opportunities")
	runner.check(UIRoot.phone.find_child("OpportunitiesHelp", true, false) is Button, "new screen has named help entry")
	runner.check(Help.has("phone_opportunities"), "help card exists")
	var accept := UIRoot.phone.find_child("AcceptOpportunity_test_side", true, false)
	runner.check(accept is Button, "stable acceptance button")
	if accept is Button:
		accept.pressed.emit()
	runner.eq(StoryEngine.side_progress()["test_side"]["status"], "active", "phone starts real story")
	runner.check(StoryEngine.available_side_stories().is_empty(), "accepted opportunity is removed")
	_restore()
	UIRoot.phone._go("home")
