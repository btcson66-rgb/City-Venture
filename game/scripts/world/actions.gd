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
		return "not your office (yet)" if req == "lease:suite_2b" else "not yours (yet)"
	match action:
		"cafe_counter":
			return Cafe.counter_block()
		"register_company":
			if not npc_present("ana"):
				return "counter unattended"
		"bank_counter":
			if not npc_present("sofia"):
				return "teller closed"
		"clothing_shop":
			if params.has("npc") and not npc_present(str(params["npc"])):
				return "no one at the till"
		"dropoff_parcels":
			if Ecommerce.carried_count() == 0:
				return "nothing to drop off"
		"work_shift":
			var jid := str(params.get("job", ""))
			if Careers.current_job() != jid:
				return "hiring — ask about the job"
			return Careers.shift_block(jid)
	return ""


static func run(action: String, params: Dictionary, source: Node = null) -> void:
	var req: String = params.get("requires", "")
	if req == "desk_access" and not Living.has_desk_access():
		UIRoot.toast("You need a day pass or a desk plan. Ask at reception.", "warn", "lock")
		return
	if req.begins_with("lease:") and not Living.has_lease(req.substr(6)):
		if req == "lease:corner_cafe":
			UIRoot.toast("This till comes with the lease. Mr. Okafor at Okafor Lettings handles it.", "warn", "lock")
		elif req == "lease:pier7_warehouse":
			UIRoot.toast("This is Bay 3's kit. Lease the warehouse at the lettings desk by the door first.", "warn", "lock")
		else:
			UIRoot.toast("This is Suite 2B's desk. Talk to Tom about leasing it.", "warn", "lock")
		return
	match action:
		"cafe_counter":
			_cafe_counter()
		"open_company_os":
			UIRoot.open_modal(CompanyOS.new(params.get("terminal", "laptop")))
		"sleep":
			UIRoot.open_modal(SleepModal.new())
		"change_outfit":
			UIRoot.open_modal(WardrobeModal.new())
		"clothing_shop":
			_clothing_shop(params)
		"look":
			_look(params)
		"buy_item":
			if str(params.get("item", "coffee")) == "coffee":
				_buy_item(params)
			else:
				_buy_meal(params)
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
				UIRoot.toast(I18n.t("%s is already registered (%s).") % [e["name"], e.get("registration_no", "")], "info", "civic")
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
			UIRoot.open_modal(LoanModal.new(false))
		"lease_office":
			UIRoot.open_modal(LeaseModal.new("suite_2b"))
		"lease_property":
			UIRoot.open_modal(LeaseModal.new(str(params.get("property", ""))))
		"cowork_desk":
			UIRoot.open_modal(CoworkDeskModal.new())
		"whiteboard":
			UIRoot.open_modal(InfoModal.whiteboard())
		"take_number":
			var n := GameState.randi_range(12, 40)
			UIRoot.toast(I18n.t("Ticket A-%d. Now serving A-%d.") % [n, n - GameState.randi_range(0, 3)], "info", "civic")
		"permits_info":
			UIRoot.open_modal(PermitsModal.new())
		"metro":
			UIRoot.open_modal(MetroModal.new(str(params.get("station", ""))))
		"work_shift":
			UIRoot.open_modal(JobModal.new(str(params.get("job", ""))))
		"talk_staff":
			_talk_staff(str(params.get("staff", "")))
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
		var price := 0.0 if _staff_coffee(params) else float(params.get("price", 4.5))
		Ledger.expense("player", "coffee", price, "%s — %s" % [str(params.get("item", "coffee")).capitalize(), DataDB.building(params.get("building", "")).get("name", "")], {"type": "purchase"})
		Clock.advance(int(params.get("minutes", 10)))
		if params.has("flag"):
			GameState.set_flag(params["flag"])
		GameState.inc_stat("coffees")
		UIRoot.toast(I18n.t("Coffee — %s. Tastes like possibility.") % (Fmt.money(price) if price > 0 else I18n.t("on the house (staff)")), "info", "coffee")
	if first_conv != "":
		UIRoot.play_dialogue(first_conv, buy)
	else:
		buy.call()


## A store's rails: the clerk (`npc`) says hello the first time, then the shop opens.
static func _clothing_shop(params: Dictionary) -> void:
	var npc := str(params.get("npc", ""))
	var store := str(params.get("building", "threadline_apparel"))
	if npc != "" and not npc_present(npc):
		UIRoot.toast("No one's at the till.", "warn", "lock")
		return
	var open_shop := func(): UIRoot.open_modal(ClothingShopModal.new(store))
	var first := str(params.get("first", ""))
	if first != "" and not GameState.flag("met_" + npc):
		UIRoot.play_dialogue(first, open_shop)
	else:
		open_shop.call()


## A meal or anything that isn't coffee: pay, spend the time, done. Params: item, price, minutes, category, flag.
static func _buy_meal(params: Dictionary) -> void:
	var price := float(params.get("price", 20.0))
	var what := I18n.t(str(params.get("name", str(params.get("item", "meal")).capitalize())))
	var where := I18n.t(str(DataDB.building(str(params.get("building", ""))).get("name", "")))
	Ledger.expense("player", str(params.get("category", "dining")), price, "%s — %s" % [what, where], {"type": "purchase"})
	Clock.advance(int(params.get("minutes", 45)))
	if params.has("flag"):
		GameState.set_flag(params["flag"])
	GameState.inc_stat("meals")
	UIRoot.toast(I18n.t("%s at %s — %s.") % [what, where, Fmt.money(price)], "info", "coffee")


## Read a sign or look at something. Params: text, and optional alt: [{if, text}] (first match wins).
static func _look(params: Dictionary) -> void:
	var text := str(params.get("text", ""))
	for a in params.get("alt", []):
		if Cond.all([str(a["if"])]):
			text = str(a["text"])
			break
	UIRoot.toast(StoryEngine.fill(I18n.t(text)), "msg", str(params.get("icon", "info")))


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
				"lease_cafe":
					follow = func(): UIRoot.open_modal(LeaseModal.new("corner_cafe"))
				"buy_van":
					follow = func(): UIRoot.open_modal(VanDealModal.new())
				"loan_office":
					GameState.set_flag("wants_loan_offer", false)
					follow = func():
						if GameState.flag("wants_loan_offer"):
							GameState.set_flag("wants_loan_offer", false)
							UIRoot.open_modal(LoanModal.new(true))
				"dropoff_parcels":
					follow = func(): run("dropoff_parcels", {})
				"clothing_shop":
					var store := _scene().scene_id if _scene() != null else "threadline_apparel"
					follow = func(): UIRoot.open_modal(ClothingShopModal.new(store))
			if d.get("action", "") == "register_company":
				run("register_company", {})
				return
			UIRoot.play_dialogue(d["conversation"], follow)
			GameState.data["npcs"][npc_id] = {"met": true}
			return
	UIRoot.toast(I18n.t("%s is busy.") % def.get("name", npc_id), "info", "people")


## Baristas drink free at their own café (job perk).
static func _staff_coffee(p: Dictionary) -> bool:
	return Careers.has_perk("free_coffee") and str(p.get("building", "")) == str(Careers.job_def(Careers.current_job()).get("building", ""))


static func _buy_after_talk(p: Dictionary) -> void:
	var price := 0.0 if _staff_coffee(p) else float(p.get("price", 4.5))
	if price > 0:
		Ledger.expense("player", "coffee", price, "Coffee", {"type": "purchase"})
	Clock.advance(int(p.get("minutes", 10)))
	if p.has("flag"):
		GameState.set_flag(p["flag"])
	UIRoot.toast(I18n.t("Coffee — %s.") % Fmt.money(price), "info", "coffee")


## Your own café: work the counter for a couple of hours (the barista minigame), then the café's till takes over.
static func _cafe_counter() -> void:
	var why := Cafe.counter_block()
	if why != "":
		UIRoot.toast(I18n.t("Can't work the counter: %s.") % I18n.t(why), "warn", "lock")
		return
	var g := BaristaGame.new()
	g.own_counter = true
	g.title_text = I18n.t("Your counter — %s") % Cafe.display_name()
	MiniGames.play(g, func(res: Dictionary):
		if res.get("aborted", false):
			return
		var r := Cafe.owner_shift(float(res.get("score", 0.5)))
		if r["ok"]:
			UIRoot.toast(I18n.t("Two hours behind your own counter: %d customers served.") % int(r["served"]), "good", "coffee")
		else:
			UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock"))


static func _talk_staff(sid: String) -> void:
	var p: Dictionary = Staff.S()["people"].get(sid, {})
	if p.is_empty():
		return
	var mo := int(p["morale"])
	var line := "Busy day. All good." if mo >= 60 else ("Could use a bit more support around here." if mo >= 35 else "Honestly? I'm looking at other jobs.")
	if Staff.wages_owed() > 0.0:
		line = "When are we getting paid? Rent's due."
	match str(p["role"]):
		"packer":
			var q := Ecommerce.orders_with(["placed"], "suite_2b").size()
			if mo >= 35 and Staff.wages_owed() <= 0.0:
				line = I18n.t("%d orders waiting to be packed. I'm on it.") % q if q > 0 else I18n.t("All packed. The courier comes at 16:00.")
	UIRoot.toast("%s: %s" % [str(p["name"]).get_slice(" ", 0), I18n.t(line)], "msg", "people")
