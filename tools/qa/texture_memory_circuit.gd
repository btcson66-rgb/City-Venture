extends SceneTree
## Identical rendered district circuit before and after cache changes. Never use headless for GPU memory.
var samples: Array = []
var out := ""
func _initialize() -> void:
	call_deferred("run")
func sample(label: String) -> void:
	var art = root.get_node("Art")
	var large := 0
	for key in art._cache:
		var path := str(key).trim_prefix("world_detail/")
		if path.get_slice("/", 0) in ["backdrops", "cards", "events", "city_map", "world_map"]:
			large += 1
	if "_large_cache" in art:
		large += art._large_cache.size()
	var bytes := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	samples.append({"label": label, "texture_bytes": bytes, "large_cached": large})
	print("MEMORY %s: %d bytes; %d large cached" % [label, bytes, large])
func settle() -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	await process_frame
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	await process_frame
	var state = root.get_node("GameState")
	var router = root.get_node("SceneRouter")
	var clock = root.get_node("Clock")
	state.new_game({"name":"Memory review", "appearance":state.default_appearance()})
	state.data["clock"]["minutes"] = 12 * 60
	await settle()
	sample("start")
	for district in root.get_node("DataDB").city["districts"]:
		if not root.get_node("DataDB").districts.has(str(district["id"])):
			continue
		var id := str(district["id"])
		router._enter("district", id, "", "down")
		clock.world_active = false
		await settle()
		# Visit three player positions in the actual renderer, allowing physics/camera updates.
		for point in [Vector2(160, 380), Vector2(400, 380), Vector2(600, 380)]:
			router.current.player.position = point
			await settle()
		for card in get_nodes_in_group("location_card"):
			card.queue_free()
		await settle()
		sample(id)
	# No scene teardown: endpoint includes the last district and permanent small art in both runs.
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	sample("end")
	# Separate long-play stress sample: sequential reads, without a list retaining texture references.
	var keys: Array = []
	for file in DirAccess.open("res://assets/world_detail/backdrops").get_files():
		if file.ends_with(".png"):
			keys.append("backdrops/" + file.get_basename())
	keys.sort()
	assert(keys.size() >= 20)
	for i in range(20):
		root.get_node("Art").tex(keys[i])
		await settle()
	sample("after_twenty_backgrounds")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(), "method":RenderingServer.get_current_rendering_method(), "samples":samples}, "\t") + "\n")
	f.close()
	quit()
