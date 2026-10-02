class_name SettingsModal
extends Modal
## Changes apply immediately. A rejected key leaves the previous assignment intact.

const PAGES := ["Audio", "Display", "Controls", "Accessibility", "Game"]
const ACTION_NAMES := {"move_left": "Move left", "move_right": "Move right", "move_up": "Move up", "move_down": "Move down",
	"run": "Run", "interact": "Interact", "phone": "Phone", "map": "Map", "company_os_hint": "Company OS",
	"pause": "Pause", "fast_forward": "Fast-forward", "confirm": "Confirm", "cancel": "Cancel", "bug_report": "Report a problem"}
var page := 0
var capture := ""
var status: Label


func _init() -> void:
	title_text = "Settings"
	panel_size = Vector2(570, 320)
	pauses_time = true
	help_key = "settings"


func build() -> void:
	var tabs := UIK.hbox(3)
	body.add_child(tabs)
	for index in PAGES.size():
		var button := UIK.button(PAGES[index], func(): capture = ""; page = index; reset_scroll = true; rebuild(), "tab_active" if index == page else "tab")
		button.name = "SettingsPage_%d" % index
		tabs.add_child(button)
	match page:
		0:
			for row in [["master", "Master volume"], ["music", "Music"], ["sfx", "Sound effects"], ["ambience", "Ambience"]]:
				_slider(row[0], row[1], 0, 100, 1, "%", 100)
		1:
			if not OS.has_feature("web"):
				_options("window_mode", "Window mode", ["Windowed", "Fullscreen", "Borderless"])
			_slider("ui_scale", "UI scale", 80, 150, 5, "%", 100)
			_options("font_size", "Text size", ["Small", "Medium", "Large", "Extra large"])
		2:
			status = UIK.wrap("Select an action, then press a key. Esc cancels key capture.", 8, Art.C_MUTED, 360)
			status.name = "BindingStatus"
			body.add_child(status)
			for action in Preferences.BINDINGS:
				var row := UIK.hbox(4)
				row.add_child(UIK.label(action_name(action)))
				row.add_child(UIK.expand())
				var keys: Array = Preferences.bindings[action].map(func(key): return OS.get_keycode_string(key))
				var button := UIK.button(" / ".join(keys), func(): capture = action; status.text = I18n.t("Press a key. Esc cancels key capture."))
				button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				button.name = "Binding_" + action
				row.add_child(button)
				body.add_child(row)
			var reset := UIK.button("Restore default keys", func(): _result(Preferences.reset_bindings()); rebuild())
			reset.name = "ResetBindings"
			body.add_child(reset)
		3:
			_options("color_mode", "Color assistance", ["Off", "Red-green", "Blue-yellow", "High contrast"])
			_toggle("reduce_motion", "Reduce motion")
			_slider("subtitle_seconds", "Subtitle advance delay (0 = manual)", 0, 30, 1, "s")
			_slider("notification_seconds", "Notification duration", 2, 30, 1, "s")
			body.add_child(UIK.wrap("Choices always wait for you. Profit and loss use text and signed amounts as well as color.", 8, Art.C_MUTED, 360))
		4:
			_slider("autosave_seconds", "Autosave interval", 5, 120, 5, "s")
			_slider("default_speed", "Default game speed", 0.5, 3, 0.5, "min/s")
			_toggle("tutorial_hints", "Tutorial hints")
			body.add_child(UIK.wrap("Default speed applies at launch. Hold Fast-forward for twice the current speed; release to resume.", 8, Art.C_MUTED, 360))
	var done := UIK.button("Done", close, "primary")
	done.name = "SettingsDone"
	footer.add_child(done)


func _result(error: Error) -> void:
	if error != OK:
		UIRoot.toast("Settings could not be saved. Check available storage and try again.", "warn", "save")


func _slider(key: String, caption: String, low: float, high: float, step_size: float, unit: String, multiplier := 1.0) -> void:
	var row := UIK.hbox(4)
	row.add_child(UIK.label(caption))
	var slider := HSlider.new()
	slider.name = "Setting_" + key
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.value = float(Preferences.values[key]) * multiplier
	slider.custom_minimum_size.x = 100
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value := UIK.label(str(slider.value) + " " + unit)
	value.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(value)
	slider.value_changed.connect(func(number):
		value.text = str(number) + " " + unit
		_result(Preferences.set_value(key, number / multiplier)))
	body.add_child(row)


func _options(key: String, caption: String, choices: Array) -> void:
	var row := UIK.hbox(4)
	row.add_child(UIK.label(caption))
	var option := OptionButton.new()
	option.name = "Setting_" + key
	for choice in choices:
		option.add_item(I18n.t(choice))
	option.select(int(Preferences.values[key]))
	option.item_selected.connect(func(index): _result(Preferences.set_value(key, index)))
	row.add_child(option)
	body.add_child(row)


func _toggle(key: String, caption: String) -> void:
	var row := UIK.hbox(4)
	row.add_child(UIK.label(caption))
	var button := UIK.button("✓ Turn off" if bool(Preferences.values[key]) else "✗ Turn on", func(): _result(Preferences.set_value(key, not bool(Preferences.values[key]))); rebuild())
	button.name = "Setting_" + key
	row.add_child(button)
	body.add_child(row)


func _input(event: InputEvent) -> void:
	if capture.is_empty() or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key := int(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if key == KEY_ESCAPE:
		capture = ""
		status.text = I18n.t("Select an action, then press a key. Esc cancels key capture.")
		return
	var other: String = Preferences.conflict(capture, key)
	if not other.is_empty():
		status.text = I18n.t("✗ Used by %s. Choose another key.") % action_name(other)
		return
	_result(Preferences.rebind(capture, key))
	capture = ""
	rebuild()


static func action_name(action: String) -> String:
	if action.begins_with("pick_"):
		return I18n.t("Choice %d") % int(action.trim_prefix("pick_"))
	if action == "undo":
		return I18n.t("Undo")
	return I18n.t(ACTION_NAMES[action])
