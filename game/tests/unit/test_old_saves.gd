extends RefCounted
var runner

func test_real_historical_chapter_three_saves_continue_for_three_days() -> void:
	for name in ["0.1.5-test5", "0.1.6-test6", "0.1.7-test7", "0.1.8-test8.1"]:
		var path: String = "res://tests/fixtures/saves/" + name + ".cvsave"
		var text := FileAccess.get_file_as_string(path)
		var decoded := SaveSystem.validate_text(text)
		runner.check(decoded["ok"], name + " validates")
		if not decoded["ok"]: continue
		runner.eq(decoded["payload"]["data"]["meta"]["version"], name, "genuine historical version")
		runner.check(SaveSystem._atomic_write(SaveSystem._path(6), text), "fixture written")
		runner.check(SaveSystem.load_data(6), "historical load_data succeeds")
		StoryEngine.check()
		Clock.advance(3 * Clock.DAY)
		runner.check(Ledger.check_balanced(), name + " balanced after three days")
		var os := CompanyOS.new("home_laptop")
		runner.get_tree().root.add_child(os)
		for item in CompanyOS.TABS:
			os._set_tab(item[0])
			runner.check(os.content != null, name + " OS " + item[0])
		os.free()
