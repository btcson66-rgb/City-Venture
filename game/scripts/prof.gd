class_name Prof
extends RefCounted
## Opt-in hotspot accumulator (microseconds per key); only fills when enabled by the stress probe.
static var enabled := false
static var d := {}
static func add(k: String, us: int) -> void:
	if enabled:
		d[k] = d.get(k, 0) + us
