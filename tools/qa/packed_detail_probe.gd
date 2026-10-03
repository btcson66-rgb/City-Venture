extends SceneTree
## Run with --main-pack build/web/index.pck: prove optional detail paths survive export remapping.

const GROUPS := ["backdrops", "cards", "city_map", "world_map", "ui", "minigames", "events", "logos", "products", "effects"]
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	await process_frame
	var art := root.get_node("Art")
	for group in GROUPS:
		var files := ResourceLoader.list_directory("res://assets/world_detail/" + group)
		var count := probe(group, files, art)
		if count == 0:
			failures += 1
		print("PACKED DETAIL: %s %d imported images available" % [group, count])
	print("PACKED DETAIL FINISHED: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func probe(group: String, files: PackedStringArray, art: Node) -> int:
	var count := 0
	for file in files:
		if file.ends_with("/"):
			var sub := group + "/" + file.trim_suffix("/")
			count += probe(sub, ResourceLoader.list_directory("res://assets/world_detail/" + sub), art)
		elif file.ends_with(".png"):
			var key := group + "/" + file.get_basename()
			var texture: Texture2D = art.tex(key)
			if texture == null or not texture.has_meta("detail_path"):
				failures += 1
				push_error("Packed detail missing " + key)
			art._cache.erase(key)
			art._large_cache.erase(key)
			count += 1
	return count
