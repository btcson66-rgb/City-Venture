extends SceneTree
## Exercise the existing scene renderer without modifying gameplay scripts.
var out := ""
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	var clock = root.get_node("Clock")
	state.new_game({"name":"Art review","appearance":state.default_appearance()})
	var points := {"riverside":"postpoint_riverside","startup_hub":"nexus_cowork","civic_center":"city_hall","shopping_street":"threadline_apparel","financial":"nexus_bank"}
	for district in points:
		state.data["clock"]["minutes"] = 22 * 60
		router._enter("district",district,"","down")
		clock.world_active = false
		root.get_node("UIRoot").set_hud_visible(false)
		root.get_node("UIRoot").close_all()
		var scene = router.current
		scene.player.position = scene.spawns.get("door_"+points[district],scene.player.position)
		scene.update_lighting()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/"+district+"_night.png")
	print("city_frontage_capture: 5 actual district night screenshots")
	quit()

