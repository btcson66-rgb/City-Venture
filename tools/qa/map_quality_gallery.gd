extends SceneTree
var out := ""
func _initialize() -> void:
	call_deferred("capture")
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
func capture() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var i18n = load("res://scripts/ui/i18n.gd")
	i18n.init()
	i18n.set_locale("zh_TW",false)
	var ui = root.get_node("UIRoot")
	var state = root.get_node("GameState")
	state.data = state.template({},123)
	root.get_node("Clock").world_active = false
	ui.set_hud_visible(false)
	var city = load("res://scripts/ui/modals/city_map_modal.gd").new(false)
	ui.open_modal(city)
	await shot("city_default")
	var count := 0
	for district in root.get_node("DataDB").city["districts"]:
		var button = city.find_child("District_"+district["id"],true,false)
		assert(button != null)
		button.pressed.emit()
		await shot("city_"+district["id"])
		assert(city.sel == district["id"])
		count += 1
	city.close()
	await process_frame
	var world = load("res://scripts/ui/modals/world_map_modal.gd").new()
	ui.open_modal(world)
	await shot("world_default")
	for rid in root.get_node("DataDB").regions:
		var button = world.find_child("Region_"+rid,true,false)
		assert(button != null)
		button.pressed.emit()
		await shot("world_"+rid)
		assert(world.sel == rid)
		count += 1
	world.close()
	await process_frame
	var metro = load("res://scripts/ui/modals/metro_modal.gd").new("riverside")
	ui.open_modal(metro)
	await shot("metro")
	print("map_quality_gallery: "+str(count)+" actual label-button selections; city/world/metro native runtime")
	quit()
