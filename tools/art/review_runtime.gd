extends SceneTree
## Exercises real world scenes, movement, atlas anchors and dialogue expressions.
const OUT = "D:/City-Venture/evidence/2026-09-30_runtime_art/review"
var failures: Array = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func snap(label_: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + "/" + label_ + ".png") == OK, "Save " + label_)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var state = root.get_node("GameState")
	var art = root.get_node("Art")
	var db = root.get_node("DataDB")
	var router = root.get_node("SceneRouter")
	var ui = root.get_node("UIRoot")
	var clock = root.get_node("Clock")
	root.get_node("SaveSystem").DIR = "user://runtime_art_review"
	state.new_game({"name": "Art Review", "seed": 3})
	ui.tutorial.process_mode = Node.PROCESS_MODE_DISABLED
	ui.tutorial.hide()
	var app: Dictionary = state.default_appearance()
	check(art.character_layers(app, "startup_casual")[0].name == "founder_detail", "Default founder uses detailed walk atlas")
	var custom := app.duplicate()
	custom["skin"] = "s5"
	check(art.character_layers(custom, "startup_casual").size() > 1, "Custom skin stays on customisable rig")
	check(art.character_layers(app, "business_suit").size() > 1, "Outfit selection stays intact")
	var rig_script = load("res://scripts/world/character_rig.gd")
	for id in ["maya", "jun", "ana", "elena", "daniel", "dara", "ken", "lee", "marcus", "priya", "sofia", "tom"]:
		var n: Dictionary = db.npcs[id]
		var rig = rig_script.new()
		root.add_child(rig)
		rig.setup(n.appearance, n.outfit, {}, id)
		check(rig._layers.size() == 1 and rig._layers[0].name == "npc_detail", "Detailed NPC " + id)
		var sprite: Sprite2D = rig._layers[0]
		check((sprite.offset * sprite.scale).is_equal_approx(Vector2(-16,-46)), "Feet anchor " + id)
		for dir in ["down", "right", "up", "left"]:
			rig.set_dir(dir)
			for e in range(4):
				rig.set_expression(["neutral", "happy", "thinking", "surprised"][e])
				check(sprite.frame % 4 == e, "Expression " + id + "/" + dir + "/" + str(e))
		if id in ["maya", "elena", "daniel", "ken", "marcus"]:
			check(rig.set_pose("sit"), "Scheduled seated pose " + id)
		rig.queue_free()
	for id in db.buildings:
		state.mark_visited(id)
		router._enter("interior", id, "door", "down")
		clock.world_active = false
		await create_timer(0.2).timeout
		var scene = router.current
		var before: Vector2 = scene.player.position
		Input.action_press("move_up")
		await create_timer(0.22).timeout
		Input.action_release("move_up")
		check(scene.player.position.distance_to(before) > 3, "Real movement in " + id)
		scene.player.face("down")
		for child in ui.card_layer.get_children(): child.queue_free()
		await snap("interior_" + id)
	# Real dialogue widget + real named character, no concept image overlay.
	router._enter("interior", "bloom_coffee", "door", "down")
	clock.world_active = false
	await create_timer(0.2).timeout
	ui.play_dialogue("jun_chat", Callable())
	await create_timer(0.2).timeout
	for e in ["neutral", "happy", "thinking", "surprised"]:
		ui.dialogue._set_speaker("jun", e)
		ui.dialogue.text_label.visible_characters = -1
		if router.current.named_npcs.has("jun"):
			check(router.current.named_npcs.jun.rig.expression == e, "World dialogue sync " + e)
		else:
			check(false, "Jun present during expression review")
		await snap("dialogue_" + e)
	ui.dialogue._end()
	clock.advance(10 * 60)
	router._enter("interior", "riverside_apartment", "door", "down")
	clock.world_active = false
	await snap("apartment_night")
	var report = FileAccess.open(OUT + "/result.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks, "failures":failures}, "  "))
	print("RUNTIME ART REVIEW: ", checks, " checks; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
