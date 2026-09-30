extends SceneTree
## Read-only visual harness. Uses real PortraitView and chapter-card widgets.
## godot --path game --script ../tools/art/review_renewal.gd

const OUT = "D:/City-Venture/evidence/2026-09-29_art_renewal/review"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func snap(name_: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + "/" + name_ + ".png")
	if result != OK:
		failures += 1
	print("ART REVIEW screenshot: ", name_)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	var db = root.get_node("DataDB")
	var art = root.get_node("Art")
	var ui = root.get_node("UIRoot")
	var ids = ["ana", "daniel", "dara", "elena", "jun", "ken", "lee", "marcus", "maya", "priya", "sofia", "tom"]
	var portrait_script = load("res://scripts/ui/portrait_view.gd")
	for page in range(2):
		var screen := Control.new()
		screen.size = Vector2(640, 360)
		root.add_child(screen)
		var background := ColorRect.new()
		background.color = Color("0d1b2b")
		background.size = Vector2(640, 360)
		screen.add_child(background)
		for j in range(6):
			var id: String = ids[page * 6 + j]
			var n: Dictionary = db.npcs[id]
			var origin := Vector2(20 + (j % 2) * 312, 14 + (j / 2) * 112)
			var label := Label.new()
			label.text = str(n.name) + " / neutral - happy - thinking - surprised"
			label.position = origin
			label.add_theme_font_size_override("font_size", 9)
			screen.add_child(label)
			var tints := {}
			for key in n.get("outfit_tints", {}):
				tints[key] = Color(n.outfit_tints[key])
			var layers: Array = art.portrait_layers(n.appearance, n.outfit, tints, id)
			if layers.size() != 1 or layers[0].tex not in ["portraits/npc_" + id, "world_detail/portraits/npc_" + id]:
				push_error("Portrait override not active: " + id)
				failures += 1
			for f in range(4):
				var view = portrait_script.new()
				view.position = origin + Vector2(f * 68, 19)
				view.size = Vector2(64, 64)
				screen.add_child(view)
				view.setup_character(n.appearance, n.outfit, tints, id)
				view.set_expr(["neutral", "happy", "thinking", "surprised"][f])
		await snap("portraits_" + str(page + 1))
		screen.queue_free()
		await process_frame
	for chapter in range(1, 7):
		var path := "backdrops/chapter_" + str(chapter)
		if not art.has_tex(path):
			push_error("Missing chapter artwork: " + path)
			failures += 1
			continue
		ui.show_chapter_card("CHAPTER " + str(chapter), "CITY VENTURE", path)
		await create_timer(0.6).timeout
		await snap("chapter_" + str(chapter))
		for c in ui.card_layer.get_children():
			c.queue_free()
		await process_frame
	print("ART REVIEW FINISHED: ", failures, " failure(s); 12 NPCs x 4 expressions; 6 chapters")
	quit(1 if failures else 0)
