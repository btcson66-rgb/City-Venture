extends Node
var out := ""
var checks := []
var frames: Array = []
var sampling := false
var last_usec := 0
func _process(_delta):
	var now := Time.get_ticks_usec()
	if sampling and last_usec > 0: frames.append((now - last_usec) / 1000.0)
	last_usec = now
func _ready():
	call_deferred("run")
func settle():
	while SceneRouter.transitioning: await get_tree().process_frame
	for i in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
func shot(key):
	await settle()
	get_viewport().get_texture().get_image().save_png(out.path_join(key + ".png"))
	print("SHOT ", key)
func run():
	out = ProjectSettings.globalize_path("res://../evidence/2026-10-06_visual_repair/before")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.DIR = out.path_join("saves")
	SaveSystem.autosave_enabled = false
	Help.auto = false
	I18n.init()
	GameState.new_game({"name":"Art Review", "seed":12345})
	if "--frontage-only" in OS.get_cmdline_user_args():
		UIRoot._suppress_decisions = true
		GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
		for id in DataDB.districts:
			var width := int(DataDB.districts[id]["size_tiles"][0]) * 16
			for segment in int(ceil(width / 640.0)):
				SceneRouter._enter("district", id, "metro", "down", Vector2(mini(320+segment*640,width-320),220))
				Clock.world_active = false
				# Freeze review fixtures before a frontage camera lands in a north exit.
				SceneRouter.current.player.set_physics_process(false)
				SceneRouter.current.player.visible = false
				for exit in SceneRouter.current.get_children():
					if exit is ExitArea: exit.set_deferred("monitoring", false)
				await settle()
				UIRoot.close_all()
				UIRoot.set_hud_visible(false)
				for card in get_tree().get_nodes_in_group("location_card"): card.free()
				await shot("frontage_%s_%d" % [id,segment])
		get_tree().quit()
		return
	if "--followup" in OS.get_cmdline_user_args():
		await followup()
		write_checks()
		get_tree().quit()
		return
	if "--perf-only" in OS.get_cmdline_user_args():
		await measure_frames()
		write_checks()
		get_tree().quit()
		return
	SceneRouter.go_creator()
	await shot("creator")
	SceneRouter._enter("district", "riverside", "metro", "down", Vector2(1900,350))
	Clock.world_active = false
	await shot("riverside_east")
	SceneRouter._enter("district", "startup_hub", "metro", "down", Vector2(40,350))
	Clock.world_active = false
	await shot("startup_west")
	var d = UIRoot.dialogue
	d.visible = true
	d.active = true
	d.name_label.text = "Maya"
	d.portrait.setup_character(GameState.default_appearance(), "startup_casual")
	d.text_label.text = "這是一段較長的對話，用來檢查文字換行後，對話與下方選項是否仍能完整顯示。請確認人物肖像、對話內容、選項與提示都在螢幕安全範圍內。"
	for i in 5: d.choice_box.add_child(UIK.button("選項 %d：查看下一步與詳細說明" % i))
	await shot("dialogue_choices")
	checks.append({"key":"dialogue_bounds", "ok":get_viewport().get_visible_rect().encloses(d.panel.get_global_rect()), "rect":str(d.panel.get_global_rect())})
	d.active = false
	d.visible = false
	var os = CompanyOS.new("home_laptop")
	UIRoot.open_modal(os)
	await shot("company_os")
	checks.append({"key":"os_bounds", "ok":get_viewport().get_visible_rect().encloses(os.panel.get_global_rect()), "rect":str(os.panel.get_global_rect())})
	UIRoot.close_all()
	for id in DataDB.districts:
		SceneRouter._enter("district", id, "metro", "down")
		Clock.world_active = false
		await shot("district_" + id)
	# Exercise every base Company OS tab and all localized navigation after a rebuild.
	for locale in ["en", "zh_TW"]:
		TranslationServer.set_locale(locale)
		var m = CompanyOS.new("home_laptop")
		UIRoot.open_modal(m)
		for t in CompanyOS.TABS:
			m._set_tab(t[0])
			await shot("os_" + locale + "_" + t[0])
			checks.append({"key":"os_"+locale+"_"+t[0], "ok":get_viewport().get_visible_rect().encloses(m.panel.get_global_rect())})
		UIRoot.close_all()
	var saved_preferences = Preferences.values.duplicate(true)
	Preferences.values["font_size"] = 3
	Preferences.values["ui_scale"] = 1.5
	Preferences.apply()
	var zoomed = CompanyOS.new("home_laptop")
	UIRoot.open_modal(zoomed)
	await shot("os_large_text")
	checks.append({"key":"os_large_text_bounds", "ok":get_viewport().get_visible_rect().encloses(zoomed.panel.get_global_rect()) and get_viewport().get_visible_rect().encloses(zoomed.find_child("Close", true, false).get_global_rect())})
	UIRoot.close_all()
	d.visible = true
	d.active = true
	await shot("dialogue_large_text")
	checks.append({"key":"dialogue_large_text_bounds", "ok":get_viewport().get_visible_rect().encloses(d.panel.get_global_rect())})
	d.active = false
	d.visible = false
	Preferences.values = saved_preferences
	Preferences.apply()
	await measure_frames()
	write_checks()
	get_tree().quit()

func measure_frames():
	# Native GPU frame timings after warm-up; keep simulation active, walk real input in a populated scene.
	SceneRouter._enter("district", "startup_hub", "metro", "down")
	UIRoot.close_all()
	Clock.world_active = true
	for i in 60: await get_tree().process_frame
	sampling = true
	Input.action_press("move_right")
	for i in 240: await get_tree().process_frame
	Input.action_release("move_right")
	sampling = false
	frames.sort()
	checks.append({"key":"native_gpu_frames", "samples":frames.size(), "p50_ms":frames[frames.size()/2], "p95_ms":frames[int(frames.size()*.95)], "max_ms":frames[-1], "texture_cache_bytes":Art.texture_bytes(), "render_objects":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)})

func write_checks():
	var f = FileAccess.open(out.path_join("checks.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(checks, "  "))

func followup():
	SceneRouter.go_menu()
	await shot("main_menu_static")
	SceneRouter.go_creator()
	await shot("creator_reference")
	UIRoot._suppress_decisions = true
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	for fixture in [["riverside",Vector2(2070,440)], ["startup_hub",Vector2(1950,440)], ["financial",Vector2(1050,350)], ["luxury_heights",Vector2(1430,350)]]:
		SceneRouter._enter("district",fixture[0],"metro","down",fixture[1])
		Clock.world_active = false
		for i in 20: await get_tree().process_frame
		UIRoot.close_all()
		for card in get_tree().get_nodes_in_group("location_card"): card.free()
		await shot("street_"+fixture[0])
	# Actual movement down the road, not a teleport into an exit trigger.
	SceneRouter._enter("district","riverside","metro","right",Vector2(2110,440))
	Clock.world_active = false
	await settle()
	Input.action_press("move_right")
	for i in 180:
		await get_tree().physics_frame
		if SceneRouter.world_scene().scene_id == "startup_hub": break
	Input.action_release("move_right")
	for i in 60: await get_tree().process_frame
	checks.append({"key":"road_end_actual_transition", "ok":SceneRouter.world_scene().scene_id == "startup_hub"})
	await shot("road_end_after_transition")
	UIRoot.close_all()
	var order = {"id":"VISUAL", "product":"phone_stand", "qty":2, "customer":"Alex Chen", "district":"Riverside", "status":"placed", "location":"riverside_studio", "unit_price":20.0}
	var pack = PackGame.new([order])
	UIRoot.open_modal(pack)
	await shot("packing_intro")
	pack.start()
	await shot("packing_play")
	checks.append({"key":"packing_stage_height", "ok":pack.stage.size.y >= pack.stage.find_child("PackingColumns",true,false).get_combined_minimum_size().y})
	pack._box("medium")
	await shot("packing_box")
	UIRoot.close_all()
	# Shared rig contact sheet: every sold/base outfit and every player presentation.
	SceneRouter._enter("district","shopping_street","metro","down")
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
	var gallery = Control.new()
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background = ColorRect.new()
	background.color = Color(0.04,0.07,0.12)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.add_child(background)
	UIRoot.add_child(gallery)
	var outfit_ids = ["startup_casual","office_professional","home","business_suit","courier","barista","civic_staff","casual_tee","casual_jacket","executive","luxury_citywear","travel","formal_evening","logistics_site"]
	for presentation in ["masculine","feminine","neutral"]:
		var rigs = []
		for index in outfit_ids.size():
			for row in 3:
				var rig = CharacterRig.new()
				var app = GameState.default_appearance().duplicate(true)
				app["presentation"] = presentation
				gallery.add_child(rig)
				var tint = {}
				rig.setup(app,outfit_ids[index], tint)
				rig.set_dir(["down","right","up"][row])
				rig.position = Vector2(24+index*43,90+row*91)
				rig.scale = Vector2(1.5,1.5)
				rigs.append(rig)
		await shot("outfits_"+presentation)
		for rig in rigs: rig.free()
	for index in DataDB.character["skin_tones"].size():
		var app = GameState.default_appearance().duplicate(true)
		app["skin"] = DataDB.character["skin_tones"][index]["id"]
		var portrait = PortraitView.new()
		portrait.position = Vector2(10+index*104,24)
		portrait.size = Vector2(100,100)
		gallery.add_child(portrait)
		portrait.setup_character(app,"executive")
		var rig = CharacterRig.new()
		gallery.add_child(rig)
		rig.setup(app,"executive")
		rig.scale = Vector2(3,3)
		rig.position = Vector2(60+index*104,300)
	await shot("skin_identity")
	gallery.free()
	UIRoot.set_hud_visible(true)
