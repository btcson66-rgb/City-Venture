class_name Packing
extends RefCounted
## Pure grid packing and dimensional postage. Saved orders retain their own selected box and padding.

static func cfg() -> Dictionary: return DataDB.economy.get("ecommerce", {})
static func boxes() -> Dictionary: return cfg().get("boxes", {})
static func items(order: Dictionary) -> Array:
	if order.has("items"): return order["items"]
	return [{"product": order.get("product", "phone_stand"), "qty": order.get("qty", 1), "unit_price": order.get("unit_price", 0.0)}]
static func total(order: Dictionary) -> float:
	var sum := 0.0
	for item in items(order): sum += int(item["qty"]) * float(item["unit_price"])
	return snappedf(sum, 0.01)
static func summary(order: Dictionary) -> String:
	var parts: Array[String] = []
	for item in items(order): parts.append("%s ×%d" % [I18n.t(str(DataDB.product(item["product"])["name"])), int(item["qty"])])
	return " + ".join(parts)
static func pieces(order: Dictionary) -> Array:
	var out: Array = []
	for item in items(order):
		for n in int(item["qty"]):
			var p := DataDB.product(item["product"])
			out.append({"product": item["product"], "size": p.get("size", [2, 1, 1]), "fragile": p.get("fragile", false)})
	return out
static func valid(order: Dictionary) -> bool:
	if items(order).is_empty(): return false
	for item in items(order):
		if not DataDB.products.has(str(item.get("product", ""))) or int(item.get("qty", 0)) <= 0 or int(item["qty"]) > 54: return false
	return true

static func placement_ok(order: Dictionary, box: String, placements: Array) -> bool:
	if not valid(order): return false
	if not boxes().has(box): return false
	var spec: Dictionary = boxes()[box]
	var units := pieces(order)
	var occupied := {}
	var used := {}
	for place in placements:
		var index := int(place.get("item", -1))
		if index < 0 or index >= units.size() or used.has(index): return false
		used[index] = true
		var dim: Array = units[index]["size"]
		if int(dim[2]) > int(spec["height"]): return false
		var w := int(dim[1] if place.get("rotated", false) else dim[0])
		var h := int(dim[0] if place.get("rotated", false) else dim[1])
		var x := int(place["x"])
		var y := int(place["y"])
		if x < 0 or y < 0 or x + w > int(spec["grid"][0]) or y + h > int(spec["grid"][1]): return false
		for row in range(y, y + h):
			for col in range(x, x + w):
				var key := Vector2i(col, row)
				if occupied.has(key): return false
				occupied[key] = true
	return true
static func plan(order: Dictionary, box: String) -> Array:
	var placed: Array = []
	if not boxes().has(box): return []
	var grid: Array = boxes()[box]["grid"]
	for index in pieces(order).size():
		var found := false
		for rotated in [false, true]:
			if found: break
			for y in int(grid[1]):
				if found: break
				for x in int(grid[0]):
					var candidate := {"item": index, "x": x, "y": y, "rotated": rotated}
					if placement_ok(order, box, placed + [candidate]): placed.append(candidate); found = true; break
		if not found: return []
	return placed
static func smallest(order: Dictionary) -> String:
	for box in boxes():
		if plan(order, box).size() == pieces(order).size(): return box
	return ""
static func fragile(order: Dictionary) -> bool:
	return pieces(order).any(func(p): return p["fragile"])
static func damage(order: Dictionary, padding: float) -> float:
	return float(cfg()["padding"]["damage_max"]) * maxf(0.0, 1.0 - padding / float(cfg()["padding"]["safe"])) if fragile(order) else 0.0
static func material(order: Dictionary, box: String, padding: float) -> float:
	return snappedf(float(boxes()[box]["cost"]) + padding * float(cfg()["padding"]["unit_cost"]), 0.01)
static func postage(order: Dictionary, box: String, method: String) -> float:
	if not boxes().has(box): return 0.0
	var weight := 0.0
	for item in items(order): weight += float(DataDB.product(item["product"]).get("weight", 0.3)) * int(item["qty"])
	var dims: Array = boxes()[box]["dimensions_cm"]
	var billed := maxf(weight, float(dims[0]) * float(dims[1]) * float(dims[2]) / float(cfg()["shipping"]["dimensional_divisor"]))
	var tier: String = "small" if box == "small" else "medium"
	return snappedf((float(DataDB.ship_method(method)["cost"][tier]) + ceil(maxf(0.0, billed - float(cfg()["shipping"]["included_kg"]))) * float(cfg()["shipping"]["extra_kg"])) * World.shipping_index(), 0.01)
static func auto_pack(order: Dictionary, skill := 5) -> Dictionary:
	var box := smallest(order)
	if box == "": return {}
	var policy: Dictionary = cfg()["staff"]
	if skill < int(policy["oversize_below_skill"]):
		var keys: Array = boxes().keys()
		box = str(keys[mini(keys.size() - 1, keys.find(box) + 1)])
	var pad := minf(1.0, float(policy["padding_base"]) + clampi(skill, 1, 5) * float(policy["padding_per_skill"])) if fragile(order) else 0.0
	return {"box": box, "padding": pad, "placements": plan(order, box), "q": 0.85, "label_ok": true}
