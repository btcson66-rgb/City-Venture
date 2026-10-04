class_name NewRunModal
extends Modal
## One new-game decision page. Weekly challenges lock standard rules and sandbox for comparable local attempts.

var callback: Callable
var difficulty := "standard"
var scenario := ""
var story := true
var seed_value := ""
var custom := {}
var challenge := false
var weekly_setup := {}
var page := "setup"
var field: LineEdit


func _init(on_start := Callable()) -> void:
	callback = on_start
	title_text = "New game setup"
	icon_name = "settings"
	panel_size = Vector2(550, 330)
	pauses_time = true
	help_key = "new_run"
	seed_value = str(Time.get_ticks_usec() % 2147483647)
	custom = Replay.rules("standard")


func _ready() -> void:
	super._ready()
	# Keep the single next action visible while options scroll independently.
	footer.reparent(self)
	_pin_footer()


func _process(delta: float) -> void:
	super._process(delta)
	_pin_footer()


func _pin_footer() -> void:
	if not is_instance_valid(footer) or not is_instance_valid(panel):
		return
	footer.size = footer.get_combined_minimum_size()
	footer.position = panel.position + panel.size - footer.size - Vector2(10, 10)
	var current := panel.get_theme_stylebox("panel")
	if not is_equal_approx(current.content_margin_bottom, footer.size.y + 18):
		var style := current.duplicate() as StyleBox
		style.content_margin_bottom = footer.size.y + 18
		panel.add_theme_stylebox_override("panel", style)


func build() -> void:
	var tabs := UIK.hbox(4)
	for pair in [["setup", "Run settings"], ["scenarios", "Scenarios"], ["history", "Local challenge history"]]:
		var button := UIK.button(pair[1], func(): _remember_seed(); page = pair[0]; rebuild())
		button.name = "RunPage_" + pair[0]
		tabs.add_child(button)
	body.add_child(tabs)
	if page == "history":
		var rows := Replay.history()
		rows.sort_custom(func(a, b): return float(a.get("result", {}).get("score", 0)) > float(b.get("result", {}).get("score", 0)))
		body.add_child(UIK.wrap("Local records only. No server or online ranking.", 8, Art.C_SKY, 480))
		if not Replay.history_error.is_empty():
			body.add_child(UIK.wrap("✗ " + I18n.t("Local history is unreadable — restore a backup before saving records."), 8, Art.C_RED, 480))
		elif rows.is_empty():
			body.add_child(UIK.label("No completed challenges yet."))
		for index in rows.size():
			var row: Dictionary = rows[index]
			body.add_child(UIK.wrap(I18n.t("Week %s · %s · %d points · %s") % [str(row.get("week", "")), str(row.get("name", "")), int(row.get("result", {}).get("score", 0)), I18n.t(str(DataDB.scenarios.get(str(row.get("scenario", "")), {}).get("name", "")))], 8, Art.C_WHITE, 480))
	elif page == "scenarios":
		body.add_child(UIK.wrap("Scenario funds override starting cash. Each opening has its own objective and deadline.", 8, Art.C_SKY, 480))
		var ids: Array = DataDB.scenarios.keys()
		ids.sort()
		var normal := UIK.button("Standard arrival", func(): scenario = ""; challenge = false; rebuild())
		normal.name = "Scenario_standard"
		body.add_child(normal)
		for id in ids:
			var definition: Dictionary = DataDB.scenarios[id]
			var button := UIK.button(str(definition["name"]), func(): scenario = id; story = false; challenge = false; rebuild(), "tab_active" if scenario == id else "")
			button.name = "Scenario_" + id
			body.add_child(button)
			body.add_child(UIK.wrap(str(definition["description"]), 8, Art.C_MUTED, 480))
	else:
		var modes := UIK.hbox(4)
		for id in ["easy", "standard", "hard", "custom"]:
			var label := "Custom" if id == "custom" else str(DataDB.difficulty["presets"][id]["name"])
			var button := UIK.button(label, func(): _remember_seed(); difficulty = id; challenge = false; rebuild(), "tab_active" if difficulty == id else "")
			button.name = "Difficulty_" + id
			modes.add_child(button)
		body.add_child(modes)
		var seed_row := UIK.hbox(4)
		seed_row.add_child(UIK.label("Seed (0–2147483647)", 8))
		field = LineEdit.new()
		field.name = "RunSeed"
		field.text = seed_value
		field.max_length = 10
		field.custom_minimum_size = Vector2(140, 44)
		field.editable = not challenge
		seed_row.add_child(field)
		var random := UIK.button("Random seed", func(): seed_value = str(Time.get_ticks_usec() % 2147483647); challenge = false; rebuild())
		random.name = "RandomRunSeed"
		seed_row.add_child(random)
		body.add_child(seed_row)
		var toggle := UIK.button(("✓ " + I18n.t("Story on — switch to sandbox")) if story else ("✗ " + I18n.t("Story off — enable story")), func(): _remember_seed(); story = not story; challenge = false; rebuild())
		toggle.name = "RunStory"
		body.add_child(toggle)
		var selected := Replay.rules(difficulty, custom)
		for key in DataDB.difficulty["fields"]:
			var definition: Dictionary = DataDB.difficulty["fields"][key]
			var value := float(selected[key])
			var row := UIK.hbox(6)
			var label := UIK.label(str(definition["name"]), 8)
			label.custom_minimum_size.x = 135
			row.add_child(label)
			var slider := HSlider.new()
			slider.name = "RunValue_" + key
			slider.min_value = float(definition["min"])
			slider.max_value = float(definition["max"])
			slider.step = float(definition["step"])
			slider.value = value
			slider.editable = difficulty == "custom" and not challenge and not (key == "initial_cash" and scenario != "")
			slider.custom_minimum_size.x = 150
			row.add_child(slider)
			var display := UIK.label(_unit(key, value), 8, Art.C_SKY)
			row.add_child(display)
			slider.value_changed.connect(func(v): custom[key] = v; display.text = _unit(key, v))
			body.add_child(row)
		var weekly := UIK.button("Play this week's challenge", func():
			var options := Replay.weekly()
			weekly_setup = options.duplicate(true)
			scenario = options["run"]["scenario"]
			difficulty = "standard"
			story = false
			seed_value = str(options["seed"])
			challenge = true
			rebuild())
		weekly.name = "WeeklyChallenge"
		body.add_child(weekly)
	if scenario != "":
		var definition: Dictionary = DataDB.scenarios[scenario]
		body.add_child(UIK.wrap(I18n.t("Selected: %s · %s") % [I18n.t(str(definition["name"])), Fmt.money0(float(definition["initial"]["cash"]))], 8, Art.C_GOLD, 480))
		body.add_child(UIK.wrap(str(definition["goal"]), 8, Art.C_SKY, 480))
	if challenge:
		body.add_child(UIK.wrap("Weekly challenge uses fixed standard rules, seed and sandbox. Changing any choice starts a regular run.", 8, Art.C_SKY, 480))
	var next := UIK.button("Create character", _start, "primary")
	next.name = "CreateRunCharacter"
	footer.add_child(next)


func _unit(key: String, value: float) -> String:
	match key:
		"initial_cash": return Fmt.money(value)
		"event_frequency", "debt_tolerance": return I18n.t("%.2f × standard") % value
	return Fmt.pct(value, 1)


func _remember_seed() -> void:
	if is_instance_valid(field):
		seed_value = field.text.strip_edges()


func _start() -> void:
	_remember_seed()
	if not seed_value.is_valid_int() or int(seed_value) < 0 or int(seed_value) > 2147483647:
		UIRoot.toast("Enter a seed from 0 to 2147483647.", "warn", "info")
		return
	var setup := {"seed": int(seed_value), "run": {"difficulty": difficulty, "custom": custom.duplicate(), "scenario": scenario, "story": story}}
	if challenge:
		setup = weekly_setup.duplicate(true)
		setup.erase("week")
	close()
	if callback.is_valid():
		callback.call(setup)
