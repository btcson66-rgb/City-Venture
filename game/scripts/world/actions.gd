class_name Actions
extends RefCounted
## The closed vocabulary of in-world actions (GAME_DATA_SCHEMA §1.8). Interactables call run().
## Every management function is reached by walking to a place and using something there.


static func _scene() -> WorldScene:
	return SceneRouter.world_scene()


static func npc_present(npc_id: String) -> bool:
	var ws := _scene()
	return ws != null and ws.named_npcs.has(npc_id) and is_instance_valid(ws.named_npcs[npc_id])


## Short reason shown next to the prompt when an action isn't available right now.
static func lock_reason(action: String, params: Dictionary) -> String:
	var req: String = params.get("requires", "")
	if req == "desk_access" and not Living.has_desk_access():
		return "needs a desk pass"
	if req.begins_with("lease:") and not Living.has_lease(req.substr(6)):
		return "not your office (yet)"
	match action:
		"register_company":
			if not npc_present("ana"):
				return "counter unattended"
		"bank_counter":
			if not npc_present("sofia"):
				return "teller closed"
		"dropoff_parcels":
			if Ecommerce.carried_count() == 0:
				return "nothing to drop off"
	return ""


static func run(action: String, params: Dictionary, source: Node = null) -> void:
	var req: String = params.get("requires", "")
	if req == "desk_access" and not Living.has_desk_access():
		UIRoot.toast("You need a day pass or a desk plan. Ask at reception.", "warn", "lock")
		return
	if req.begins_with("lease:") and not Living.has_lease(req.substr(6)):
		UIRoot.toast("This is Suite 2B's desk. Talk to Tom about leasing it.", "warn", "lock")
		return
	match action:
		"open_company_os":
			UIRoot.open_modal(CompanyOS.new(params.get("terminal", "laptop")))
		"sleep":
			UIRoot.open_modal(SleepModal.new())
		"change_outfit":
			UIRoot.open_modal(WardrobeModal.new())
		"buy_item":
			_buy_item(params)
		"talk":
			_talk(str(params.get("npc", "")))
		"read_news":
			UIRoot.open_modal(InfoModal.news())
		"business_board":
			UIRoot.open_modal(BusinessBoard.new())
		"pack_orders":
			UIRoot.open_modal(PackShipModal.new(str(params.get("location", "riverside_studio"))))
		"dropoff_parcels":
			if Ecommerce.carried_count() == 0:
				UIRoot.toast("Nothing to drop off. Pack orders at your packing table and choose 'Carry to PostPoint'.", "info", "parcel")
			else:
				UIRoot.open_modal(DropoffModal.new())
		"register_company":
			if GameState.company_id() != "":
				var e: Dictionary = GameState.data["entities"][GameState.company_id()]
				UIRoot.toast("%s is already registered (%s)." % [e["name"], e.get("registration_no", "")], "info", "civic")
			elif not npc_present("ana"):
				UIRoot.toast("Nobody at the counter. Registration: Mon–Fri 9:00–17:00.", "warn", "lock")
			else:
				UIRoot.play_dialogue("ana_register", func(): UIRoot.open_modal(RegistrationModal.new()))
		"bank_counter":
			if not npc_present("sofia"):
				UIRoot.toast("The teller window is closed.", "warn", "lock")
			else:
				UIRoot.open_modal(BankModal.new())
		"atm":
			UIRoot.open_modal(BankModal.new(true))
		"loans_info":
			UIRoot.open_modal(InfoModal.loans())
		"lease_office":
			UIRoot.open_modal(LeaseModal.new("suite_2b"))
		"cowork_desk":
			UIRoot.open_modal(CoworkDeskModal.new())
		"whiteboard":
			UIRoot.open_modal(InfoModal.whiteboard())
		"take_number":
			var n := GameState.randi_range(12, 40)
			UIRoot.toast("Ticket A-%d. Now serving A-%d." % [n, n - GameState.randi_range(0, 3)], "info", "civic")
		"permits_info":
			UIRoot.open_modal(InfoModal.permits())
		"metro":
			UIRoot.open_modal(MetroModal.new(str(params.get("station", ""))))
		_:
			push_warning("Actions: unknown action " + action)
	var _u := source


static func _buy_item(params: Dictionary) -> void:
	var npc: String = params.get("npc", "")
	if npc != "" and not npc_present(npc):
		UIRoot.toast("No one's behind the counter.", "warn", "lock")
		return
	var first_conv := ""
	if npc != "":
		for d in DataDB.npc(npc).get("dialogue", []):
			if d.get("action", "") == "coffee" and Cond.all(d.get("when", [])) and d.get("when", []).size() > 0:
				first_conv = d["conversation"]
				break
	var buy := func():
		var price := float(params.get("price", 4.5))
		Ledger.expense("player", "coffee", price, "%s — %s" % [str(params.get("item", "coffee")).capitalize(), DataDB.building(params.get("building", "")).get("name", "")], {"type": "purchase"})
		Clock.advance(int(params.get("minutes", 10)))
		if params.has("flag"):
			GameState.set_flag(params["flag"])
		GameState.inc_stat("coffees")
		UIRoot.toast("Coffee — %s. Tastes like possibility." % Fmt.money(price), "info", "coffee")
	if first_conv != "":
		UIRoot.play_dialogue(first_conv, buy)
	else:
		buy.call()


static func _talk(npc_id: String) -> void:
	var def := DataDB.npc(npc_id)
	for d in def.get("dialogue", []):
		if Cond.all(d.get("when", [])):
			var follow := Callable()
			match d.get("action", ""):
				"coffee":
					var ws := _scene()
					if ws != null:
						for n in ws.get_children():
							if n is Interactable and n.action == "buy_item":
								var p: Dictionary = n.params
								follow = func(): _buy_after_talk(p)
				"register_company":
					follow = func(): run("register_company", {})
				"bank_counter":
					follow = func(): UIRoot.open_modal(BankModal.new())
				"lease_office":
					follow = func(): UIRoot.open_modal(LeaseModal.new("suite_2b"))
				"dropoff_parcels":
					follow = func(): run("dropoff_parcels", {})
			if d.get("action", "") == "register_company":
				run("register_company", {})
				return
			UIRoot.play_dialogue(d["conversation"], follow)
			GameState.data["npcs"][npc_id] = {"met": true}
			return
	UIRoot.toast("%s is busy." % def.get("name", npc_id), "info", "people")


static func _buy_after_talk(p: Dictionary) -> void:
	var price := float(p.get("price", 4.5))
	Ledger.expense("player", "coffee", price, "Coffee", {"type": "purchase"})
	Clock.advance(int(p.get("minutes", 10)))
	if p.has("flag"):
		GameState.set_flag(p["flag"])
	UIRoot.toast("Coffee — %s." % Fmt.money(price), "info", "coffee")
