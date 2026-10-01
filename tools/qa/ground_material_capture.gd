extends SceneTree
## Real world renderer; no high-resolution atlas override or gameplay modifications.
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
	for district in ["riverside","startup_hub","civic_center","shopping_street","financial","old_town","harbor"]:
		for hour in [12,22]:
			state.data["clock"]["minutes"] = hour * 60
			router._enter("district",district,"","down")
			clock.world_active = false
			root.get_node("UIRoot").set_hud_visible(false)
			root.get_node("UIRoot").close_all()
			var scene = router.current
			scene.player.position = Vector2(450,650 if district in ["riverside","harbor"] else 510)
			scene.update_lighting()
			await create_timer(.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+district+("_day" if hour==12 else "_night")+".png")
	print("ground_material_capture: 14 actual district day/night screenshots")
	quit()
