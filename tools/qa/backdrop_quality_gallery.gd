extends SceneTree
var out := ""
func _initialize() -> void:
	call_deferred("capture")
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
func capture() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var lang = load("res://scripts/ui/i18n.gd")
	lang.init()
	lang.set_locale("zh_TW",false)
	var state = root.get_node("GameState")
	state.data = state.template({},123)
	var ui = root.get_node("UIRoot")
	root.get_node("Clock").world_active = false
	ui.set_hud_visible(false)
	var router = root.get_node("SceneRouter")
	router.go_menu()
	await shot("menu")
	var creator = load("res://scripts/frontend/character_creator.gd").new()
	router._set_scene(creator)
	await shot("creator_wardrobe")
	var backdrop = load("res://scripts/frontend/backdrop.gd")
	router._set_scene(backdrop.make("backdrops/arrival",1000000))
	await shot("arrival")
	for chapter in root.get_node("DataDB").story["chapters"]:
		var num = str(chapter["id"]).get_slice("_",0).trim_prefix("ch")
		if int(num)>6:continue
		ui.show_chapter_card(lang.t(chapter["title"]),lang.t(chapter.get("subtitle","")),"backdrops/chapter_"+num)
		await create_timer(0.65).timeout
		await shot("chapter_"+num)
		for card in ui.card_layer.get_children():card.queue_free()
		await process_frame
	ui.show_chapter_card(lang.t("A fresh start"),lang.t("A company can fail. You don't."),"backdrops/insolvency")
	await create_timer(0.65).timeout
	await shot("insolvency")
	for card in ui.card_layer.get_children():card.queue_free()
	await process_frame
	for id in ["riverside_apartment","bloom_coffee","nexus_bank","nexus_cowork","byte_and_bean","city_hall","postpoint_riverside","small_office"]:
		ui.show_location_card("interior",id)
		await create_timer(0.45).timeout
		await shot("location_"+id)
		for card in get_nodes_in_group("location_card"):card.queue_free()
		await process_frame
	print("backdrop_quality_gallery: menu, creator, arrival, 6 chapter presentations, insolvency, 8 location cards; zhTW")
	quit()

