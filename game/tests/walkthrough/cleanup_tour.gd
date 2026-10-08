extends RefCounted
## Matching rendered states for #165; --cleanup-before records the inherited behavior.
var bot
var metrics := {}
func _init(b) -> void: bot = b

func capture(tag: String, steps: int) -> void:
	await bot.wait(0.25)
	await bot.shot(tag)
	var text := ""
	var modal := UIRoot.top_modal()
	for control in modal.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree(): continue
		if control is Label or control is Button:
			text += control.atr(control.text) + "\n"
	metrics[tag] = {"steps":steps,"characters":text.replace("\n", "").length(),"numbers":RegEx.create_from_string("[0-9]+(?:[.,][0-9]+)*").search_all(text).size(),"text":text}

func run() -> void:
	UIRoot.close_all()
	UIRoot._suppress_decisions = true
	Help.auto = false
	MiniGames.auto = -1.0
	if "--cleanup-large" in OS.get_cmdline_user_args():
		InputAccess.touch_mode = true
		Preferences.values["font_size"] = 3
		Preferences.apply()
	GameState.new_game({"name":"新手","seed":165})
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	Clock.world_active = false
	SceneRouter._enter("interior", Living.home_building(), "entry", "up")
	GameState.data.erase("minigame_practice_version")
	GameState.data = SaveSystem._migrate(GameState.data)
	MiniGame.backfill_tutorials_seen()
	var packing := PackGame.new([{"id":"QA165","product":"phone_stand","qty":2,"customer":"Rin Tanaka","district":"Riverside"}])
	UIRoot.open_modal(packing)
	await capture("legacy_packing_start", 2 if "--cleanup-before" in OS.get_cmdline_user_args() else 1)
	if "--cleanup-before" not in OS.get_cmdline_user_args():
		bot.expect(UIRoot.top_modal() == packing, "old save never forces uncertain packing practice")
	UIRoot.close_all()
	await bot.wait(0.2)
	var parcel := ParcelSortGame.new()
	parcel.practice_only = true
	UIRoot.open_modal(parcel)
	await bot.click_named("StartGame")
	await capture("parcel_highlight", 1)
	var target := parcel.practice_target
	var index := 1
	for bin in ParcelSortGame.BINS:
		if "Bin_" + str(bin[0]) == str(target.name): break
		index += 1
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1 + index - 1
	key.physical_keycode = key.keycode
	Input.parse_input_event(key)
	await bot.wait(0.3)
	await capture("parcel_after_number_key", 1)
	if "--cleanup-before" not in OS.get_cmdline_user_args(): bot.expect(parcel.practice_step > 0, "highlighted number key advances practice")
	UIRoot.close_all()
	GameState.set_flag("debug_feature_gates_all")
	UIRoot.open_modal(CompanyOS.new("home_laptop"))
	await bot.click_named("Tab_finance")
	await capture("weekly_forecast", 1)
	bot.expect(Ledger.check_balanced(), "capture keeps ledger balanced")
	var file := FileAccess.open(bot.out_dir + "/comparison.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
