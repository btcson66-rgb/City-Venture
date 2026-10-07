extends RefCounted
## Shared acceptance fixtures; actions still go through the real minigame controls.
static func games() -> Array:
	Company.register("練習小舖", "automotive", "Gateway")
	Company.open_business_account(25000)
	Automotive.start()
	Automotive.refresh()
	var lot: Dictionary = Automotive.open_lots()[0]
	Fundraising.deals()["practice"] = {"id": "practice", "investor": "marlow_tan"}
	PopupStore.S()["active"] = {"prices": {"water_bottle": 12.0}, "units": 0}
	var order := {"id": "T-149", "product": "phone_stand", "qty": 2, "customer": "Rin Tanaka", "district": "Riverside"}
	return [BaristaGame.new(), ParcelSortGame.new(), ClerkFormsGame.new(), CoworkHostGame.new(),
		TellerCashGame.new(), PackGame.new([order]), PhotoShootGame.new(), TypingGame.new(),
		ConsultingGame.new("market"), ConsultingGame.new("finance"), ConsultingGame.new("operations"), ConsultingGame.new("brand"),
		CreativePitch.new({"id": "practice", "client": "Local client", "audience": 0, "preferences": [0, 1, 2]}),
		PopupCheckoutGame.new(), PersonalRequestGame.new(PersonalLife.stories()["maya"]["steps"][0]),
		RouteGame.new(), PitchGame.new("practice"), AuctionGame.new(str(lot["id"]))]

static func special_input(g: MiniGame) -> bool:
	if g is TypingGame:
		var line: String = g.call("_cur")
		while g.round_i == 0 and g.col < line.length():
			var event := InputEventKey.new()
			event.pressed = true
			event.unicode = line.unicode_at(g.col)
			g._input(event)
		return true
	if is_instance_valid(g.practice_target) and g.practice_target.name == "PhotoFrame":
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		g.practice_target.gui_input.emit(down)
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.relative = Vector2(10, 10)
		g.practice_target.gui_input.emit(move)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		g.practice_target.gui_input.emit(up)
		return true
	return false
