extends Node
var out := ""
func _ready() -> void: call_deferred("run")
func capture(name: String) -> void:
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out+"/"+name+".jpg", .85)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	I18n.init()
	I18n.set_locale("zh_TW")
	GameState.new_game({"name":"工廠驗收", "seed":64001})
	Company.register("工廠驗收", "manufacturing", "Unit 12")
	Company.open_business_account(25000)
	GameState.data["tutorial"] = {"off":true, "seen":{}, "step":99, "v":99}
	Clock.advance_to(Clock.at_day_time(1, 10*60))
	for building in ["ferro_supply", "kessler_precision", "shift_diner"]:
		SceneRouter._enter("interior", building, "door", "")
		Clock.world_active = false
		await capture(building)
	SceneRouter._enter("district", "industrial", "metro", "", Vector2(640,352))
	Clock.world_active = false
	await capture("industrial_facades_day")
	Clock.advance_to(Clock.at_day_time(0, 21*60))
	await capture("industrial_facades_night")
	SceneRouter._enter("interior", "unit12_factory", "door", "")
	Clock.world_active = false
	Living.lease("unit12_factory")
	Manufacturing.start()
	var modal := ManufacturingUI.new()
	UIRoot.open_modal(modal)
	await get_tree().create_timer(.2).timeout
	if UIRoot.top_modal() != modal: UIRoot.top_modal().close()
	await capture("factory_setup")
	modal.close()
	var os := CompanyOS.new("home_laptop")
	os.tab="manufacturing"
	UIRoot.open_modal(os)
	await get_tree().create_timer(.2).timeout
	if UIRoot.top_modal() != os: UIRoot.top_modal().close()
	await capture("company_os_manufacturing")
	print("MANUFACTURING GALLERY: 7 JPG")
	get_tree().quit()

