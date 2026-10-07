extends Node
## Headless test runner. Usage:
##   godot --headless --path game res://tests/test_runner.tscn -- [--junit=path] [--filter=name]
## Loads every tests/unit/test_*.gd, runs each test_* method on a fresh new game, writes a report.

var results: Array = []
var current_failures: Array = []


func _ready() -> void:
	AssistantPolicy.testing = true
	call_deferred("_run")


func _args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			out[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	return out


func _run() -> void:
	SaveSystem.DIR = "user://test_saves_%d" % OS.get_process_id()
	var args := _args()
	var filter: String = args.get("filter", "")
	var files: Array = []
	var d := DirAccess.open("res://tests/unit")
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append("res://tests/unit/" + f)
	files.sort()
	var t_start := Time.get_ticks_msec()
	for path in files:
		var script: GDScript = load(path)
		var inst = script.new()
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (path.get_file() + "::" + name).contains(filter):
				continue
			_fresh_game()
			current_failures = []
			inst.set("runner", self)
			var t0 := Time.get_ticks_msec()
			await inst.call(name)
			var dt := Time.get_ticks_msec() - t0
			results.append({"suite": path.get_file().get_basename(), "name": name, "ok": current_failures.is_empty(),
				"failures": current_failures.duplicate(), "ms": dt})
			print(("  PASS " if current_failures.is_empty() else "  FAIL ") + path.get_file() + "::" + name + " (%d ms)" % dt)
			for f in current_failures:
				print("       - " + str(f))
	var passed := results.filter(func(r): return r["ok"]).size()
	print("\n%d/%d tests passed in %.1fs" % [passed, results.size(), (Time.get_ticks_msec() - t_start) / 1000.0])
	if args.has("junit"):
		_write_junit(args["junit"])
	get_tree().quit(0 if passed == results.size() else 1)


func _fresh_game() -> void:
	# Concurrent sessions share user://; never delete or overwrite another runner's saves.
	SaveSystem.DIR = "user://test_saves_%d" % OS.get_process_id()
	# tests assert on English text; a Chinese OS locale (or test_i18n restoring it) must not leak in
	TranslationServer.set_locale("en")
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.new_game({"name": "Test Founder", "seed": 12345})
	GameState.set_flag("debug_feature_gates_all") # UI fixtures exercise business rules; gate tests opt back in.


func check(cond: bool, msg: String) -> void:
	if not cond:
		current_failures.append(msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
		if absf(float(a) - float(b)) > 0.011:
			current_failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])
	elif a != b:
		current_failures.append("%s (got %s, expected %s)" % [msg, str(a), str(b)])


func _write_junit(path: String) -> void:
	var by_suite := {}
	for r in results:
		if not by_suite.has(r["suite"]):
			by_suite[r["suite"]] = []
		by_suite[r["suite"]].append(r)
	var x := '<?xml version="1.0" encoding="UTF-8"?>\n<testsuites>\n'
	for s in by_suite:
		var fails: int = by_suite[s].filter(func(r): return not r["ok"]).size()
		x += '  <testsuite name="%s" tests="%d" failures="%d">\n' % [s, by_suite[s].size(), fails]
		for r in by_suite[s]:
			x += '    <testcase classname="%s" name="%s" time="%.3f">' % [s, r["name"], r["ms"] / 1000.0]
			for f in r["failures"]:
				x += '<failure message="%s"/>' % str(f).xml_escape()
			x += '</testcase>\n'
		x += '  </testsuite>\n'
	x += '</testsuites>\n'
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(x)
		f.close()
		print("JUnit report: " + path)
