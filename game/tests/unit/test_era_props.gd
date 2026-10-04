extends RefCounted
var runner

func _props(node: Node, sprite: String) -> Array:
	var found: Array = []
	for child in node.get_children():
		if str(child.get_meta("prop_sprite", "")) == sprite:
			found.append(child)
		found.append_array(_props(child, sprite))
	return found

func test_year_gated_city_props_and_roofs_keep_collision() -> void:
	var counts := {}
	var solids := {}
	for year in [2, 3, 4]:
		World.set_year(year)
		counts[year] = {"crane":0, "solar":0, "ev":0}
		for district in ["riverside", "shopping_street", "financial"]:
			var world := District.new()
			world.build(district)
			counts[year]["crane"] += _props(world, "port_cranes_far").size()
			counts[year]["solar"] += _props(world, "solar_roof_small").size() + _props(world, "solar_roof_large").size()
			counts[year]["ev"] += _props(world, "ev_charger").size()
			if year == 2:
				solids[district] = world.solids.duplicate()
			else:
				runner.eq(world.solids, solids[district], "decorations never block doors/navigation " + district)
			for crane in _props(world, "port_cranes_far"):
				runner.check(crane.get_parent() == world.back_layer and crane.position.y > 652, "cranes across water in back layer")
			world.free()
	runner.eq(counts[2], {"crane":0, "solar":0, "ev":0}, "year two has no new props")
	runner.eq(counts[3], {"crane":1, "solar":0, "ev":0}, "year three adds distant port")
	runner.eq(counts[4], {"crane":1, "solar":4, "ev":4}, "year four adds four roofs and four chargers")
	runner.check(Ledger.check_balanced(), "decorations do not create income")

func test_roof_offsets_are_facade_design_coordinates() -> void:
	World.set_year(4)
	var world := District.new()
	world.build("financial")
	var building: Node2D = world.building_nodes["nexus_bank"]
	var roof: Node2D = _props(building, "solar_roof_large")[0]
	var design := Art.tex("buildings/nexus_bank")
	runner.eq(roof.position, Vector2(66, -12 - design.get_height() + 2), "roof relative to logical facade top-left")
	var charges := _props(world, "ev_charger")
	runner.eq(charges.size(), 2, "two decorative public chargers, independent of Energy owned charging sites")
	world.free()


func test_live_era_refresh_preserves_player_feet() -> void:
	World.set_year(2)
	var pos := Vector2(1140, 624)
	SceneRouter._enter("district", "riverside", "", "left", pos)
	await runner.get_tree().process_frame
	World.set_year(3)
	for frame in range(4):
		await runner.get_tree().process_frame
	var world := SceneRouter.world_scene()
	runner.eq(world.player.position, pos, "era refresh preserves feet")
	runner.eq(world.player.facing, "left", "era refresh preserves facing")
	runner.eq(_props(world, "port_cranes_far").size(), 1, "cranes appear without leaving district")
	UIRoot.close_all()
	SceneRouter._set_scene(Control.new())
	Clock.world_active = false
