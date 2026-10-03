extends RefCounted
## Detail images must keep native layout, atlas cells and nine-slice source margins.

var runner

const GROUPS := ["backdrops", "cards", "city_map", "world_map", "ui", "minigames", "events", "logos", "products", "effects"]


func test_every_detail_category_preserves_logical_geometry() -> void:
	for group in GROUPS:
		var count := _check_directory(group)
		runner.check(count > 0, group + " has detail images checked")


func _check_directory(relative: String) -> int:
	var dir := DirAccess.open("res://assets/world_detail/" + relative)
	var count := 0
	for sub in dir.get_directories():
		count += _check_directory(relative + "/" + sub)
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var key := relative + "/" + file.get_basename()
		var native_path := "res://assets/" + key + ".png"
		var detail_path := "res://assets/world_detail/" + key + ".png"
		var native: Texture2D = load(native_path) if ResourceLoader.exists(native_path) else null
		var source: Texture2D = load(detail_path)
		var logical := native.get_size() if native != null else source.get_size() / 4.0
		runner.check(Art.has_tex(key), key + " is available")
		var texture := Art.tex(key)
		runner.eq(texture.get_size(), logical, key + " keeps native dimensions")
		runner.eq(texture.get_meta("detail_path", ""), detail_path, key + " reads detail")
		runner.eq(texture.get_image().get_size(), Vector2i(source.get_size()), key + " retains detail pixels")
		runner.check(Art.tex(key) == texture, key + " is cached")
		# Release the test's image before loading the next large background.
		Art._cache.erase(key)
		Art._large_cache.erase(key)
		count += 1
	return count


func test_nine_slice_and_animation_stay_in_native_pixels() -> void:
	var box := UIK.tex_box("ui/panel", 6, 6)
	runner.eq(box.texture.get_size(), (load("res://assets/ui/panel.png") as Texture2D).get_size(), "panel size")
	runner.eq(box.texture_margin_left, 6.0, "source slice unchanged")
	runner.eq(box.content_margin_left, 6.0, "layout margin unchanged")
	var sprite := Sprite2D.new()
	sprite.texture = Art.tex("effects/water_sparkle")
	sprite.hframes = 4
	runner.eq(sprite.get_rect().size, Vector2(16, 8), "sparkle frame unchanged")
	sprite.free()


func test_direct_detail_and_missing_optional_paths() -> void:
	var raw := Art.tex("world_detail/ui/panel")
	runner.eq(raw.get_size(), (load("res://assets/world_detail/ui/panel.png") as Texture2D).get_size(), "explicit detail stays physical")
	runner.check(not Art.has_tex("ui/nonexistent_detail_test"), "missing optional image")
	runner.eq(Art.opt_tex("ui/nonexistent_detail_test"), null, "optional returns null")
	var native := Art.tex("tiles/atlas")
	runner.eq(native.get_size(), (load("res://assets/tiles/atlas.png") as Texture2D).get_size(), "native-only image unchanged")


func test_world_collision_keeps_native_alpha_mask() -> void:
	var scene := WorldScene.new()
	for key in ["props/tree_round", "interiors/plant_big", "props/bollard"]:
		runner.check(Art.tex(key).has_meta("detail_path"), key + " exercises detail collision")
		var native: Texture2D = load("res://assets/" + key + ".png")
		var width := native.get_width()
		WorldScene._foot_cache.clear()
		var expected := scene._footprint(key, native, 0, width, 8)
		WorldScene._foot_cache.clear()
		var actual := scene._footprint(key, Art.tex(key), 0, width, 8)
		runner.eq(actual, expected, key + " collision mask unchanged")
	scene.free()


func _background_keys() -> Array:
	var keys: Array = []
	for file in DirAccess.open("res://assets/world_detail/backdrops").get_files():
		if file.ends_with(".png"):
			keys.append("backdrops/" + file.get_basename())
	keys.sort()
	return keys


func test_twenty_backgrounds_keep_only_eight_and_release_evicted() -> void:
	var art = load("res://autoload/art.gd").new()
	var keys := _background_keys()
	runner.check(keys.size() >= 20, "twenty distinct real backgrounds available")
	var first: Texture2D = art.tex(keys[0])
	var weak: WeakRef = weakref(first)
	first = null
	for i in range(1, 20):
		art.tex(keys[i])
		runner.check(art._large_cache.size() <= 8, "bounded after background %d" % i)
	runner.eq(art._large_cache.keys(), keys.slice(12, 20), "only eight latest backgrounds remain")
	runner.check(art._cache.is_empty(), "large art never enters permanent cache")
	runner.eq(weak.get_ref(), null, "evicted texture has no retained cache reference")
	art.free()


func test_large_cache_hit_refreshes_recency_and_small_art_stays_pinned() -> void:
	var art = load("res://autoload/art.gd").new()
	var keys := _background_keys()
	var icon: Texture2D = art.tex("ui/panel")
	var active: Texture2D = art.tex(keys[0])
	for i in range(1, 8):
		art.tex(keys[i])
	runner.check(art.has_tex(keys[1]), "availability probe")
	runner.check(art.tex(keys[0]) == active, "cache hit reuses active texture")
	art.tex(keys[8])
	runner.check(art._large_cache.has(keys[0]), "recently read background survives")
	runner.check(not art._large_cache.has(keys[1]), "availability probe does not pin oldest")
	for i in range(9, 20):
		art.tex(keys[i])
	runner.check(not art._large_cache.has(keys[0]), "active scene does not pin cache entry")
	runner.check(active.get_width() > 0, "eviction leaves active scene texture usable")
	runner.check(art.tex("ui/panel") == icon, "small art permanently cached")
	art.free()


func test_all_five_large_groups_share_one_limit_including_explicit_detail() -> void:
	var art = load("res://autoload/art.gd").new()
	for group in ["backdrops", "cards", "events", "city_map", "world_map"]:
		for prefix in ["", "world_detail/"]:
			var files := DirAccess.open("res://assets/world_detail/" + group).get_files()
			for file in files:
				if file.ends_with(".png"):
					var key: String = prefix + group + "/" + file.get_basename()
					runner.check(art.tex(key) != null, "large image loads " + key)
					runner.check(art._large_cache.size() <= 8, "shared limit " + key)
					runner.check(not art._cache.has(key), "no permanent large entry " + key)
					break
	art.free()
