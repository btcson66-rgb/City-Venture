extends RefCounted
var runner


func test_detail_sprites_keep_native_geometry_and_tint() -> void:
	var original := Art.detail_enabled
	for enabled in [false, true]:
		Art.set_detail_enabled(enabled)
		for key in ["buildings/metro_entrance", "buildings/pier7_warehouse", "vehicles/van_player_side_body"]:
			var design := Art.tex(key)
			var sprite := Sprite2D.new()
			sprite.modulate = Color.RED
			var offset := Vector2(0, -design.get_height())
			Art.fit_world_sprite(sprite, key, offset)
			runner.eq(sprite.texture.get_size() * sprite.scale, design.get_size(), "logical footprint " + key)
			runner.eq(sprite.offset * sprite.scale, offset, "logical offset " + key)
			runner.eq(sprite.modulate, Color.RED, "tint preserved " + key)
			sprite.free()
	Art.set_detail_enabled(original)


func test_tileset_toggle_keeps_cell_coordinates_and_native_navigation() -> void:
	var original := Art.detail_enabled
	for enabled in [true, false, true]:
		Art.set_detail_enabled(enabled)
		var world := WorldScene.new()
		world._init_layers()
		world.size_px = Vector2i(160, 160)
		world.init_nav()
		world.paint("road", [2, 3, 1, 1])
		runner.eq(world.ground.get_cell_atlas_coords(Vector2i(2, 3)), WorldScene._tile_index["road"], "atlas coordinates unchanged")
		runner.eq(Vector2(world.ground.tile_set.tile_size) * world.ground.scale, Vector2(16, 16), "logical tile stays 16px")
		runner.eq(world.nav.cell_size, Vector2(8, 8), "navigation independent of art scale")
		world.free()
	Art.set_detail_enabled(original)


func test_detail_setting_is_device_only_and_defaults_on() -> void:
	runner.eq(Preferences.DEFAULTS["high_detail_art"], true, "default on")
	runner.eq(Preferences.validated("high_detail_art", "bad"), true, "bad setting defaults on")
	runner.check(not GameState.data.has("high_detail_art"), "no company save preference")
	runner.check(not Preferences.validated("high_detail_art", false), "off is accepted")
