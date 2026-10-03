extends RefCounted
var bot
func _init(b) -> void: bot = b
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	MiniGames.auto = -1.0
	GameState.new_game({"name": "Alex Chen", "seed": 113})
	Clock.world_active = false
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	SceneRouter._enter("interior", "riverside_studio", "entry", "up")
	UIRoot.set_hud_visible(true)
	var orders: Array = [{"id": "M1", "product": "phone_stand", "qty": 2, "unit_price": 15.0, "items": [{"product": "phone_stand", "qty": 2, "unit_price": 15.0}, {"product": "desk_lamp", "qty": 1, "unit_price": 29.0}]}, {"id": "M2", "product": "desk_monitor", "qty": 1, "unit_price": 150.0}]
	for o in orders:
		o.merge({"customer": "Alex Chen", "entity": "player", "listing": "", "location": "riverside_studio", "status": "placed", "placed": Clock.now()})
		for item in Packing.items(o):
			Ecommerce._add_stock("riverside_studio", item["product"], int(item["qty"]), 5.0, 0.0)
			Ledger.post("player", "Tour opening stock", [{"acct": "inventory", "dr": 5.0 * int(item["qty"])}, {"acct": "cash", "cr": 5.0 * int(item["qty"])}], {"segment": "ecommerce"})
		Ecommerce.E()["orders"][o["id"]] = o
	var game := PackGame.new(orders)
	MiniGames.play(game, func(result): Ecommerce.pack_orders("riverside_studio", -1, result.get("quality", {})) if not result.get("aborted", false) else 0)
	await bot.wait(0.3)
	await bot.shot("packing_instructions")
	await bot.click_named("StartGame")
	for o in orders:
		var box := Packing.smallest(o)
		await bot.click_named("Box_" + box)
		for place in Packing.plan(o, box):
			await bot.click_named("PackItem_%d" % int(place["item"]))
			if place["rotated"]: await bot.click_named("RotateItem")
			await bot.click_named("Grid_%d_%d" % [int(place["x"]), int(place["y"])])
			if place["rotated"]: await bot.click_named("RotateItem")
		bot.expect(game.placements.size() == Packing.pieces(o).size(), "every item placed through real grid input")
		for n in 4: await bot.click_named("Pad")
		for n in 3: await bot.click_named("Seam_%d" % n)
		for n in game.labels.size():
			if game.labels[n]["ok"]: await bot.click_named("Label_%d" % n)
		await bot.shot("packing_" + box + "_ready")
		await bot.click_named("Seal")
		await bot.wait(0.2)
	await bot.shot("packing_result")
	await bot.click_named("FinishGame")
	await bot.wait(0.3)
	bot.expect(Ecommerce.orders_with(["packed"], "riverside_studio").size() == 2, "basket and bulky stock packed atomically")
	bot.expect(Ledger.check_balanced(), "pack ledger balanced")
	UIRoot.open_modal(PackShipModal.new("riverside_studio"))
	await bot.wait(0.3)
	await bot.shot("packing_postage_quote")
