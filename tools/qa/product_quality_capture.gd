extends SceneTree
var out := ""
func _initialize() -> void:
	call_deferred("capture")
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/"+name+".png")
func capture() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var state = root.get_node("GameState")
	state.data = state.template({},123)
	var router = root.get_node("SceneRouter")
	var clock = root.get_node("Clock")
	var lang = load("res://scripts/ui/i18n.gd")
	lang.init()
	lang.set_locale("zh_TW",false)
	for district in ["riverside","startup_hub","civic_center","shopping_street","financial","old_town","harbor"]:
		for hour in [12,22]:
			state.data["clock"]["minutes"] = hour*60
			router._enter("district",district,"","down")
			clock.world_active = false
			root.get_node("UIRoot").set_hud_visible(false)
			var scene = router.current
			scene.player.position = Vector2(450,650 if district in ["riverside","harbor"] else 510)
			scene.update_lighting()
			await create_timer(0.45).timeout
			for card in get_nodes_in_group("location_card"):card.queue_free()
			await process_frame
			await shot(district+("_day" if hour==12 else "_night"))
	router._enter("interior","riverside_apartment","","down")
	clock.world_active = false
	var scene = router.current
	scene.player.position = Vector2(320,210)
	root.get_node("UIRoot").set_hud_visible(false)
	root.get_node("UIRoot").tutorial.visible = false
	root.get_node("UIRoot").coach_layer.visible = false
	for i in 6:
		var id = ["coffee","desk_lamp","earbuds","parcel","phone_stand","water_bottle"][i]
		var p = scene.add_prop({"sprite":"product_"+id,"x":80+i*35,"y":210})
		assert(p != null)
		var sprite = p.get_child(p.get_child_count()-1)
		assert(sprite.texture.get_size()==Vector2(64,64))
		assert(sprite.scale==Vector2(0.25,0.25))
	await create_timer(0.45).timeout
	for card in get_nodes_in_group("location_card"):card.queue_free()
	await process_frame
	await shot("qa_product_placements")
	print("product_quality_capture: 14 actual district day/night views; 6 QA product placements through existing add_prop at16x16 logical size")
	quit()
