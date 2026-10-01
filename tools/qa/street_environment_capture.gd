extends SceneTree
## Capture the existing district renderer in day/night, without modifying gameplay code.
var out := ""
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	var clock = root.get_node("Clock")
	state.new_game({"name": "Art review", "appearance": state.default_appearance()})
	for district in ["riverside", "startup_hub", "financial"]:
		for hour in [14, 22]:
			state.data["clock"]["minutes"] = hour * 60
			router._enter("district", district, "", "down")
			clock.world_active = false
			root.get_node("UIRoot").set_hud_visible(false)
			root.get_node("UIRoot").close_all()
			var scene = router.current
			if district == "riverside":
				scene.player.position = scene.spawns.get("door_riverside_apartment", scene.player.position)
			elif district == "startup_hub":
				scene.player.position = scene.spawns.get("door_small_office", scene.player.position)
			else:
				scene.player.position = scene.spawns.get("door_nexus_bank", scene.player.position)
			scene.update_lighting()
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out + "/" + district + "_" + str(hour) + ".png")
	print("street_environment_capture: 6 actual district day/night screenshots")
	quit()
