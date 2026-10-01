extends SceneTree
## Capture the actual creator, not a mockup. Uses the project's controls and renderer.
var destination := ""
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	destination = get_cmdline_destination()
	DirAccess.make_dir_recursive_absolute(destination)
	await process_frame
	var router = root.get_node("SceneRouter")
	var clock = root.get_node("Clock")
	clock.world_active = false
	root.get_node("UIRoot").set_hud_visible(false)
	var creator = load("res://scripts/frontend/character_creator.gd").new()
	router._set_scene(creator)
	for skin in ["s1", "s2", "s3", "s4", "s5", "s6"]:
		creator.app["skin"] = skin
		creator._refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(destination + "/creator_" + skin + ".png")
	print("creator_capture: 6 actual creator screenshots")
	quit()

func get_cmdline_destination() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			return arg.substr(6)
	return "D:/City-Venture-character-quality/evidence/20261001_character_customization/after"
