class_name ReplayPolicy
extends RefCounted
## Economy acceptance uses normal APIs and normal time costs; no fixture cash, stock or forced demand.

static func start(id: String, seed_value: int, difficulty := "standard") -> void:
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.new_game({"name": "Scenario QA", "seed": seed_value, "run": {"difficulty": difficulty, "scenario": id, "story": false}})
	GameState.data["living"]["reduced"] = true
	Careers.hire("bank_teller")
	if id == "venture_fund":
		Living.lease("suite_2b")


static func work(day: int, idle := false) -> void:
	var until := Clock.now() + Clock.DAY
	Clock.advance(Clock.next_time_of_day(9 * 60) - Clock.now())
	if not idle:
		var id: String = Replay.S().get("scenario", {}).get("id", "")
		if id == "inherited_cafe":
			if int(Cafe.S()["supplies"]) < 250 and int(Cafe.S()["incoming"]) == 0:
				Cafe.order_supplies("large")
			Cafe.owner_shift(0.85)
		elif id == "harbor_cargo":
			var runs: Array = Logistics.active_jobs() + Logistics.open_jobs()
			var drove := 0
			for job in runs:
				if drove >= 2:
					break
				if job["status"] == "open":
					Logistics.accept(str(job["id"]))
				var order: Array = Logistics.best_order(job["stops"])["order"]
				var result := Logistics.drive(str(job["id"]), order)
				drove += int(result.get("ok", false))
		elif id == "venture_fund":
			_ecommerce()
		var skill := RandomNumberGenerator.new()
		skill.seed = int(Replay.S()["seed"]) ^ ("work" + str(day)).hash()
		Careers.work_shift("bank_teller", skill.randf_range(0.65, 1.0))
		if GameState.company_id() != "" and Ledger.cash("player") < 2000 and Ledger.cash(GameState.company_id()) > 4000:
			Company.transfer(GameState.company_id(), "player", 2000)
		resolve_events()
	if Clock.now() < until:
		Clock.advance(until - Clock.now())
	resolve_events()
	Replay.evaluate()


static func _ecommerce() -> void:
	for product in ["phone_stand", "water_bottle", "wireless_earbuds", "desk_lamp"]:
		var offer := Ecommerce.offer("tradelink_wholesale", product)
		var pending := 0
		for po in GameState.data["ecommerce"]["purchase_orders"].values():
			if po["product"] == product and po["status"] in ["in_transit", "awaiting_payment"]:
				pending += int(po["qty"])
		if Ecommerce.total_units_at_any(product) + pending < int(offer["moq"]) / 2:
			Ecommerce.buy("tradelink_wholesale", product, int(offer["moq"]), "suite_2b")
		if Ecommerce.total_units_at_any(product) > 0 and Ecommerce.listing_for(product).is_empty():
			var result := Ecommerce.create_listing(product, float(DataDB.product(product)["ref_price"]), "studio")
			if result.get("ok", false):
				Ecommerce.set_ad_budget(str(result["listing_id"]), 5.0)
				Clock.advance(int(DataDB.marketplace().get("studio_photo_minutes", 90)))
	var packed := Ecommerce.pack_orders("suite_2b")
	if packed > 0:
		Clock.advance(int(DataDB.shipping().get("pack_minutes_per_order", 8)) * packed)
		Ecommerce.courier_pickup("suite_2b", "economy")


static func resolve_events() -> void:
	for instance in EventEngine.pending().duplicate(true):
		for choice in DataDB.events[instance["id"]].get("choices", []):
			if EventEngine.choice_available(choice, instance["ctx"]):
				if EventEngine.choose(str(instance["iid"]), str(choice["id"])).get("ok", false):
					break
