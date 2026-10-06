extends RefCounted
var runner
func test_desktop_buttons_do_not_inherit_touch_minimum():
	var b := UIK.button("Close")
	runner.check(b.custom_minimum_size.y < InputAccess.TARGET.y, "desktop buttons stay compact")
	b.free()
func test_long_dialogue_stays_above_screen_bottom():
	var d := DialogueBox.new()
	d.theme = UIK.theme()
	runner.get_tree().root.add_child(d)
	d.visible = true
	d.text_label.text = "A long explanation of the next task. ".repeat(40)
	for i in 12: d.choice_box.add_child(UIK.button("Choice %d" % i))
	for i in 8: await runner.get_tree().process_frame
	d._fit_dialogue()
	for i in 3: await runner.get_tree().process_frame
	runner.check(d.get_viewport_rect().encloses(d.panel.get_global_rect()), "long text and twelve choices cannot push panel offscreen")
	runner.check(d.content_scroll.get_v_scroll_bar().max_value > d.content_scroll.size.y, "overflow choices remain scrollable")
	d.free()
func test_company_os_uses_available_height():
	var m := CompanyOS.new("home_laptop")
	m.theme = UIK.theme()
	Help.auto = false
	runner.get_tree().root.add_child(m)
	for i in 8: await runner.get_tree().process_frame
	runner.check(m.get_viewport_rect().encloses(m.panel.get_global_rect()), "Company OS fits viewport")
	var sc := m.content.get_parent() as ScrollContainer
	runner.check(sc.size.y > 200, "content uses remaining height instead of stopping at 160")
	runner.check(sc.size.x > 400, "content keeps usable desktop width")
	m.free()
func test_all_district_corridors_have_painted_ground_and_sky_coverage():
	for id in DataDB.districts:
		var scene := District.new()
		scene.build(id)
		for corridor in scene.def.get("walk_corridors", []):
			var x := int(corridor[0] / 16) + 2
			for y in range(int(corridor[1] / 16), int((corridor[1] + corridor[3]) / 16)):
				runner.check(scene.ground.get_cell_source_id(Vector2i(x, y)) >= 0, "%s corridor row %d has ground" % [id, y])
		if scene.sky_day.texture != null:
			runner.check(scene.sky_day.region_rect.size.x >= scene.size_px.x + 640, "%s skyline covers full district" % id)
		scene.free()
func test_preview_outline_does_not_change_world_outline():
	var parent := Node2D.new()
	parent.scale = Vector2(2, 2)
	runner.get_tree().root.add_child(parent)
	var preview := CharacterRig.new()
	parent.add_child(preview)
	var world := CharacterRig.new()
	runner.get_tree().root.add_child(world)
	preview.setup(GameState.default_appearance(), "startup_casual")
	world.setup(GameState.default_appearance(), "startup_casual")
	runner.check(preview._outline_material() != world._outline_material(), "preview and world do not mutate one shared outline uniform")
	world.free()
	parent.free()

func test_enlarged_text_keeps_modal_close_button_visible():
	var saved := Preferences.values.duplicate(true)
	Preferences.values["ui_scale"] = 1.5
	Preferences.values["font_size"] = 3
	Preferences.apply()
	var m := CompanyOS.new("home_laptop")
	m.theme = UIK.theme()
	Help.auto = false
	runner.get_tree().root.add_child(m)
	for i in 8: await runner.get_tree().process_frame
	var close_button := m.find_child("Close", true, false) as Button
	runner.check(m.get_viewport_rect().encloses(close_button.get_global_rect()), "close stays pinned at maximum UI/font size")
	runner.check(m.get_viewport_rect().encloses(m.panel.get_global_rect()), "zoomed modal remains inside viewport")
	m.free()
	Preferences.values = saved
	Preferences.apply()

func test_closed_hours_uses_compiled_chinese_daily_translation():
	I18n.init()
	I18n.set_locale("zh_TW", false)
	Clock.advance(9 * 60)
	var status := SceneRouter.building_open("meridian_trade_desk")
	runner.check(not status["open"], "night fixture exercises closed-hours text")
	runner.check(not str(status["reason"]).contains("daily"), "compiled Chinese catalog covers daily in runtime text")
	I18n.set_locale("en", false)
