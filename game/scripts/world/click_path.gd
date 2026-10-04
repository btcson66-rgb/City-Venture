class_name ClickPath
extends RefCounted
## Uses the same clearance-inflated grid as pedestrians. Invalid/unreachable taps never bypass collisions.

static func plan(world: WorldScene, start: Vector2, target: Vector2) -> PackedVector2Array:
	if world == null or world.nav == null:
		return PackedVector2Array()
	var extent := Vector2(world.size_px)
	target = target.clamp(Vector2.ZERO, (extent - Vector2.ONE).max(Vector2.ZERO))
	var first := world._nearest_free(Vector2i(floori(start.x / world.NAV_CELL), floori(start.y / world.NAV_CELL)))
	var last := world._nearest_free(Vector2i(floori(target.x / world.NAV_CELL), floori(target.y / world.NAV_CELL)))
	if not world.nav.is_in_boundsv(first) or not world.nav.is_in_boundsv(last) or world.nav.is_point_solid(first) or world.nav.is_point_solid(last):
		return PackedVector2Array()
	var points := world.nav.get_point_path(first, last)
	var route := PackedVector2Array()
	for point in points:
		route.append(point + Vector2(world.NAV_CELL / 2.0, world.NAV_CELL / 2.0))
	var target_cell := Vector2i(floori(target.x / world.NAV_CELL), floori(target.y / world.NAV_CELL))
	if not route.is_empty() and target_cell == last:
		route.append(target)
	return route
