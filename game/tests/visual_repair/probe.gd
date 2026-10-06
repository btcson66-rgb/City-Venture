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
