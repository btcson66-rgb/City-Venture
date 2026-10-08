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

func test_menu_background_remains_static():
	var backdrop := Backdrop.make("backdrops/menu", 0.0)
	runner.get_tree().root.add_child(backdrop)
	var before := backdrop._img.position
	backdrop._process(30.0)
	runner.check(not backdrop.is_processing() and backdrop._img.position == before, "menu backdrop has no pan or per-frame update")
	backdrop.free()

func test_roads_reach_the_exit_strip():
	for id in DataDB.districts:
		var district := District.new()
		district.build(id)
		for corridor in district.def.get("walk_corridors", []):
			var edge := Vector2i(int(corridor[0]) / 16, 4)
			runner.check(district.ground.get_cell_atlas_coords(edge) == district._tile_index["grass"], id + " north connector has garden terrain")
		for g in district.def.get("ground", []):
			if str(g["type"]) != "road": continue
			var row := int(g["rect"][1]) + 1
			var x := district.size_px.x / 16 - 2
			runner.check(district.ground.get_cell_atlas_coords(Vector2i(x,row)) == district._tile_index["road"], id + " asphalt continues to the edge")
		for ex in district.def.get("exits", []):
			if str(ex.get("direction","")) in ["E","W"] and int(ex["rect"][1]) == 324:
				runner.check(int(ex["rect"][1])+int(ex["rect"][3]) > 480, id + " exit includes the road, not just upper pavement")
		district.free()

func test_facade_fallbacks_do_not_overlap():
	for id in DataDB.districts:
		var d: Dictionary = DataDB.districts[id]
		var facades: Array = d.get("fillers", []).duplicate()
		for bid in d.get("buildings", []): facades.append(DataDB.buildings[bid]["exterior"])
		facades.sort_custom(func(a,b): return float(a["x"]) < float(b["x"]))
		var end := 0.0
		for ex in facades:
			var texture := Art.tex("buildings/" + District.facade(ex))
			if texture == null: continue
			runner.check(float(ex["x"]) >= end, id + " facade including fallback does not cover its neighbor")
			end = float(ex["x"]) + texture.get_width()

func test_skin_change_preserves_character_and_clothing_identity():
	var original := GameState.default_appearance()
	var source := Art.character_layers(original, "executive")
	var portrait := Art.portrait_layers(original, "executive")
	for skin in DataDB.character["skin_tones"]:
		var changed := original.duplicate(true)
		changed["skin"] = skin["id"]
		var actual := Art.character_layers(changed, "executive")
		var actual_portrait := Art.portrait_layers(changed, "executive")
		for i in source.size():
			runner.check(actual[i]["tex"] == source[i]["tex"], "skin cannot select another character's layer")
			if source[i]["name"] != "body": runner.check(actual[i]["tint"] == source[i]["tint"], "skin cannot dye hair, eyes or clothing")
		for i in portrait.size(): runner.check(actual_portrait[i]["tex"] == portrait[i]["tex"], "portrait identity is also independent of skin")

func test_packing_stage_reports_full_content_height():
	Help.auto = false
	# This fixture measures formal-work layout, not the separate first-use lesson.
	GameState.data["minigame_tutorials_seen"] = {"pack_game":true}
	var order := {"id":"LAYOUT", "product":"phone_stand", "qty":2, "customer":"Alex Chen", "district":"Riverside", "status":"placed", "location":"riverside_studio", "price":20.0}
	var packing := PackGame.new([order])
	packing.theme = UIK.theme()
	# This fixture checks the formal packing layout; first-use practice has separate tests.
	packing.mark_tutorial_seen()
	runner.get_tree().root.add_child(packing)
	packing.start()
	for i in 8: await runner.get_tree().process_frame
	var columns := packing.stage.find_child("PackingColumns",true,false) as Control
	runner.check(packing.stage is VBoxContainer, "packing children contribute their actual size to outer scroll")
	runner.check(packing.stage.size.y >= columns.get_combined_minimum_size().y, "last packing controls are not clipped by a fixed 236px stage")
	runner.check(packing.get_viewport_rect().encloses(packing.panel.get_global_rect()), "packing window remains bounded")
	var seal := packing.find_child("Seal",true,false) as Button
	runner.check(packing.get_viewport_rect().encloses(seal.get_global_rect()), "seal button remains directly visible at default desktop size")
	packing.free()

func test_shop_palette_survives_finished_art_and_arrow_fits_board():
	var style := DataDB.character_option("outfits_shop","executive")
	var resolved := Art._resolve_outfit("executive","characters/outfit_%s_masculine_top",{})
	runner.check(resolved[1]["top"] == Color(style["stand_in"]["tints"]["top"]), "finished executive suit retains midnight color, not uncolored white atlas")
	var marker := ExitMarker.new()
	marker.setup(Rect2(2032,324,16,220),Vector2.RIGHT,"A very long localized district name")
	runner.get_tree().root.add_child(marker)
	for i in 3: await runner.get_tree().process_frame
	runner.check(marker.board.encloses(Rect2(marker._label.position,marker._label.size)), "direction label stays in its own bounded slot")
	runner.check(marker._label.get_theme_font_size("font_size") <= 6, "text is smaller than the twelve-pixel vector arrow")
	marker.free()
	var north_a := ExitMarker.new()
	var north_b := ExitMarker.new()
	north_a.setup(Rect2(1944,0,32,12),Vector2.UP,"市政中心")
	north_b.setup(Rect2(2008,0,32,12),Vector2.UP,"金融區")
	runner.check(not north_a.board.intersects(north_b.board), "adjacent north destination boards do not cover each other")
	north_a.free()
	north_b.free()
