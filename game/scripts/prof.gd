class_name Prof
extends RefCounted
static var d := {}
static func add(k: String, us: int) -> void:
	d[k] = d.get(k, 0) + us
