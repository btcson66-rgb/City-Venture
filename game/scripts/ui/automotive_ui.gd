class_name AutomotiveUI
extends Modal
## One desk for the three stages: the weekly auction and your lot, the airport rental fleet and the dealership.

var page := "auction"
var has_primary := false
var ratios: Dictionary = {}
var order_qty := 2

func _init() -> void:
	title_text = "Auto Desk"
	help_key = "automotive"
	icon_name = "metro"
	panel_size = Vector2(610, 345)

static func open(initial := "auction") -> void:
	var modal := AutomotiveUI.new()
	modal.page = initial
	UIRoot.open_modal(modal)

static func render(owner: Node) -> void:
	owner.content.add_child(UIK.label_tip("Automotive", "automotive", 10))
	owner.content.add_child(UIK.wrap("Flip auction cars, run an airport rental fleet and sign a dealership franchise.", 8, Art.C_WHITE, 460))
	var go := UIK.button("Open Auto Desk", open, "primary")
	go.name = "OpenAutoDesk"
	owner.content.add_child(go)

static func board(det: Control, _board: Node) -> void:
	det.add_child(UIK.wrap("Win cars at the Wednesday auction, then rent them out at the airport or sell them on.", 8, Art.C_WHITE, 300))
	var go := UIK.button("Open Auto Desk", open, "primary")
	go.name = "OpenAutoDesk"
	det.add_child(go)

func act(callback: Callable) -> void:
	var result: Dictionary = callback.call()
	if not result.get("ok", false):
		EventBus.notify.emit(result.get("error", ""), "bad", "metro")
	rebuild()

func button(parent: Control, label: String, id: String, callback: Callable, primary := false) -> void:
	var main := primary and not has_primary
	if main: has_primary = true
	var action := UIK.button(label, act.bind(callback), "primary" if main else "button")
	action.name = id
	parent.add_child(action)

func switch(next: String) -> void:
	page = next
	reset_scroll = true
	rebuild()

func go_to(next: String) -> Dictionary:
	switch(next)
	return {"ok":true}

func route(destination: String) -> Dictionary:
	close()
	var map := CityMapModal.new(false)
	map.sel = destination
	UIRoot.open_modal(map)
	return {"ok":true}

func check(content: Control, ok: bool, text: String) -> void:
	content.add_child(UIK.wrap(("✓ " if ok else "✗ ") + text, 8, Art.C_WHITE if ok else Art.C_GOLD, 550))

func build() -> void:
	has_primary = false
	var nav := UIK.hbox(4)
	body.add_child(nav)
	for tab in [["auction", "Auction"], ["stock", "My lot"], ["fleet", "Rental fleet"], ["dealer", "Dealership"], ["airport", "Airport"]]:
		var choice := UIK.button(tab[1], switch.bind(tab[0]), "tab_active" if page == tab[0] else "tab")
		choice.name = "AutoTab_" + tab[0]
		nav.add_child(choice)
	var content := UIK.vbox(4)
	body.add_child(UIK.scroll(content, Vector2(580, 270)))
	if not Automotive.is_running():
		not_open(content)
		return
	Automotive.refresh()
	content.add_child(UIK.label(I18n.t("%s · lot %d/%d cars · fleet %d · cash %s") % [I18n.t(Automotive.stage_name()), Automotive.stock_count(), Automotive.slots(), Automotive.fleet_cars().size(), Fmt.money0(Ledger.cash(Automotive.entity()))], 8))
	match page:
		"auction": auction_page(content)
		"stock": stock_page(content)
		"fleet": fleet_page(content)
		"dealer": dealer_page(content)
		"airport": airport_page(content)

func not_open(content: Control) -> void:
	var company := GameState.company_id() != ""
	var account := GameState.flag("business_account_opened")
	var cash := company and Ledger.cash(GameState.company_id()) >= float(Automotive.cfg()["license_fee"])
	content.add_child(UIK.label_tip("Automotive", "automotive", 9))
	check(content, company, "Register a company first.")
	check(content, account, "Open a business bank account.")
	check(content, cash, "Keep the dealer licence fee in the business account.")
	if company and account and cash:
		button(content, I18n.t("Open the auto desk · licence %s") % Fmt.money0(Automotive.cfg()["license_fee"]), "OpenAutoDesk", Automotive.start, true)
	else:
		var destination := "civic_center" if not company else "financial"
		button(content, I18n.t(DataDB.districts[destination]["name"]), "RouteAutoPrerequisite", route.bind(destination), true)

# ------------------------------------------------------------------ auction
func lot_line(lot: Dictionary) -> String:
	var car: Dictionary = lot["car"]
	var inspected := bool(lot["inspected"])
	return I18n.t("%s · %d years · %s km · body %s · mechanics %s · market %s · opens %s") % [I18n.t(car["name"]), int(car["age"]), Fmt._group(int(car["km"])), Automotive.grade_text(float(car["ext"])), Automotive.grade_text(float(car["mech"])), Fmt.money0(Automotive.true_value(car) if inspected else Automotive.visible_value(car)), Fmt.money0(lot["open"])]

func auction_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Wednesday auction", "auction", 9))
	var live := Automotive.auction_open_now()
	if live:
		check(content, true, I18n.t("The auction is live until %02d:00. Bid in the Auction game; the buyer fee is %d%%.") % [int(Automotive.auction()["close_hour"]), roundi(float(Automotive.auction()["buyer_fee"]) * 100)])
	else:
		check(content, false, I18n.t("The auction runs Wednesdays 09:00–17:00. Next one in %d days: inspect lots now, bid then.") % Automotive.days_to_auction())
	for lot in Automotive.open_lots():
		content.add_child(UIK.wrap(lot_line(lot), 8, Art.C_WHITE, 550))
		var car: Dictionary = lot["car"]
		if bool(lot["inspected"]):
			if str(car["defect"]) == "":
				check(content, true, "Jun Ito: no hidden defect found.")
			else:
				check(content, false, I18n.t("Jun Ito found %s: true value %s.") % [I18n.t(Automotive.cfg()["defects"][car["defect"]]["name"]), Fmt.money0(Automotive.true_value(car))])
		else:
			content.add_child(UIK.label(I18n.t("Hidden defects unknown. Paid inspection: %s.") % Fmt.money0(Automotive.auction()["inspection_cost"]), 7, Art.C_MUTED))
		var row := UIK.hbox(4)
		content.add_child(row)
		if not bool(lot["inspected"]):
			button(row, I18n.t("Inspect with Jun · %s") % Fmt.money0(Automotive.auction()["inspection_cost"]), "Inspect_" + lot["id"], Automotive.inspect.bind(lot["id"]))
		if live:
			button(row, I18n.t("Enter bidding · next %s") % Fmt.money0(Automotive.next_bid(lot)), "EnterAuction_" + lot["id"], enter_auction.bind(lot["id"]), true)
	if not has_primary:
		button(content, "Review my lot", "AuctionNextLot", go_to.bind("stock"), true)

func enter_auction(lot_id: String) -> Dictionary:
	var lot: Dictionary = Automotive.S()["lots"].get(lot_id, {})
	if lot.is_empty() or lot["status"] != "open": return {"ok":false, "error":I18n.t("Choose an open auction lot.")}
	if not Automotive.auction_open_now(): return {"ok":false, "error":I18n.t("Bidding runs on auction day, Wednesdays 09:00-17:00.")}
	MiniGames.play(AuctionGame.new(lot_id), func(result):
		var open_lot: Dictionary = Automotive.S()["lots"].get(lot_id, {})
		if not open_lot.is_empty() and open_lot["status"] == "open":
			if MiniGames.auto >= 0.0 and not result.get("aborted", false):
				Automotive.auction_auto(lot_id, Automotive.visible_value(open_lot["car"]) * MiniGames.auto)
			elif result.get("aborted", false) and str(open_lot["leader"]) != "player":
				Automotive.auction_hammer(lot_id)
		if is_instance_valid(self): rebuild())
	return {"ok":true}

# ------------------------------------------------------------------ the lot
func ratio_of(id: String) -> float:
	return float(ratios.get(id, 1.0))

func nudge(id: String, delta: float) -> Dictionary:
	ratios[id] = clampf(snappedf(ratio_of(id) + delta, 0.05), float(Automotive.cfg()["sale"]["ratio_min"]), float(Automotive.cfg()["sale"]["ratio_max"]))
	return {"ok":true}

func list_at(id: String) -> Dictionary:
	return Automotive.list_car(id, Automotive.market_value(Automotive.S()["stock"][id]) * ratio_of(id))

func stock_page(content: Control) -> void:
	content.add_child(UIK.label_tip("My lot", "auction", 9))
	var cars: Array = Automotive.S()["stock"].values().filter(func(c): return not bool(c["new"]))
	if cars.is_empty():
		check(content, false, "No used cars on your lot. Win one at the Wednesday auction.")
	for car in cars:
		var value := Automotive.market_value(car)
		content.add_child(UIK.wrap(I18n.t("%s · paid %s (incl. repairs %s) · market %s · %s") % [I18n.t(car["name"]), Fmt.money0(car["cost"]), Fmt.money0(car["recon"]), Fmt.money0(value), I18n.t({"lot":"On the lot", "listed":"Listed", "shop":"In the workshop"}[car["status"]])], 8, Art.C_WHITE, 550))
		if str(car["defect"]) != "":
			if bool(car["known"]): check(content, false, I18n.t("Known defect: %s (remaining value loss %d%%).") % [I18n.t(Automotive.cfg()["defects"][car["defect"]]["name"]), roundi(Automotive.defect_hit(car) * 100)])
			else: content.add_child(UIK.label(I18n.t("Unknown condition: a hidden defect may cost a warranty claim after the sale."), 7, Art.C_MUTED))
		if car["status"] == "shop":
			content.add_child(UIK.label(I18n.t("Ready on day %d.") % int(car["ready"]), 7, Art.C_MUTED))
		var row := UIK.hbox(4)
		content.add_child(row)
		if car["status"] != "shop":
			button(row, I18n.t("Detail · %s") % Fmt.money0(Automotive.recon_cost(car, "detail")), "ReconDetail_" + car["id"], Automotive.recon.bind(car["id"], "detail"))
			button(row, I18n.t("Service · %s") % Fmt.money0(Automotive.recon_cost(car, "service")), "ReconService_" + car["id"], Automotive.recon.bind(car["id"], "service"))
			if str(car["defect"]) != "" and bool(car["known"]) and float(Automotive.cfg()["defects"][car["defect"]]["fix"]) > float(car["fixed"]):
				button(row, I18n.t("Repair · %s") % Fmt.money0(Automotive.recon_cost(car, "repair")), "ReconRepair_" + car["id"], Automotive.recon.bind(car["id"], "repair"))
			var price_row := UIK.hbox(4)
			content.add_child(price_row)
			var ratio := ratio_of(car["id"])
			button(price_row, "−5%", "PriceLess_" + car["id"], nudge.bind(car["id"], -0.05))
			price_row.add_child(UIK.label(I18n.t("%s = %d%% of market · about %d days to sell") % [Fmt.money0(value * ratio), roundi(ratio * 100), Automotive.expected_days(ratio)], 8))
			button(price_row, "+5%", "PriceMore_" + car["id"], nudge.bind(car["id"], 0.05))
			if car["status"] == "listed":
				button(price_row, I18n.t("Update listing"), "List_" + car["id"], list_at.bind(car["id"]))
			else:
				button(price_row, I18n.t("List for sale"), "List_" + car["id"], list_at.bind(car["id"]), true)
			button(price_row, I18n.t("Dockside Motors · %s now") % Fmt.money0(Automotive.true_value(car) * float(Automotive.cfg()["sale"]["wholesale"])), "Wholesale_" + car["id"], Automotive.sell_wholesale.bind(car["id"]))
	content.add_child(UIK.label(I18n.t("Sold %d cars · profit so far %s") % [int(Automotive.S()["sold_count"]), Fmt.money0(Automotive.S()["flip_profit"], true)], 8, Art.C_SKY))
	if not has_primary:
		button(content, "Go to the auction", "StockNextAuction", go_to.bind("auction"), true)

# ------------------------------------------------------------------ fleet
func fleet_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Rental fleet", "fleet_util", 9))
	var leased := Living.has_lease("gateway_counter")
	check(content, leased, "Gateway Car Rental counter leased.")
	if not leased:
		content.add_child(UIK.wrap(I18n.t("The counter costs %s per month. Lease it at Gateway Car Rental in the Airport district.") % Fmt.money0(DataDB.properties["gateway_counter"]["monthly_rent"]), 8, Art.C_MUTED, 550))
		button(content, I18n.t(DataDB.districts["airport"]["name"]), "RouteGateway", route.bind("airport"), true)
		return
	var fleet := Automotive.fleet_cars()
	content.add_child(UIK.wrap(I18n.t("%d/%d cars · utilisation %d%% (14 days) · rating %.1f of 5 · lost requests %d · service due %d") % [fleet.size(), int(Automotive.rental()["fleet_max"]), roundi(Automotive.utilization() * 100), Automotive.rating(), int(Automotive.S()["lost"]), Automotive.service_due().size()], 8, Art.C_WHITE, 550))
	var due := Automotive.service_due()
	if not due.is_empty():
		var total := 0.0
		for id in due: total += Automotive.service_cost(id)
		check(content, false, I18n.t("%d cars are due for service; skipping it risks a breakdown during a rental.") % due.size())
		button(content, I18n.t("Service due cars · %s") % Fmt.money0(total), "ServiceDue", Automotive.service_all_due, true)
	var policy: Dictionary = Automotive.policy()
	var rate_row := UIK.hbox(4)
	content.add_child(rate_row)
	rate_row.add_child(UIK.label(I18n.t("Day rate %d%% · week rate %d%% of standard") % [roundi(float(policy["daily"]) * 100), roundi(float(policy["weekly"]) * 100)], 8))
	for pair in [["daily", -0.05, "−"], ["daily", 0.05, "+"], ["weekly", -0.05, "−"], ["weekly", 0.05, "+"]]:
		button(rate_row, I18n.t("%s %s") % [I18n.t("Day" if pair[0] == "daily" else "Week"), pair[2]], "Rate_%s_%s" % [pair[0], "up" if pair[1] > 0 else "down"], func(): return Automotive.set_policy(pair[0], float(policy[pair[0]]) + float(pair[1])))
	var cover_row := UIK.hbox(4)
	content.add_child(cover_row)
	cover_row.add_child(UIK.label(I18n.t("Insurance"), 8))
	for cover in Automotive.rental()["insurance"]:
		var def: Dictionary = Automotive.rental()["insurance"][cover]
		var choice := UIK.button(I18n.t("%s · %s/car/mo") % [I18n.t(def["name"]), Fmt.money0(def["premium"])], act.bind(func(): return Automotive.set_policy("insurance", cover)), "tab_active" if policy["insurance"] == cover else "tab")
		choice.name = "Insurance_" + cover
		cover_row.add_child(choice)
	var service_row := UIK.hbox(4)
	content.add_child(service_row)
	service_row.add_child(UIK.label(I18n.t("Service every"), 8))
	for days in Automotive.rental()["service_days"]:
		var choice := UIK.button(I18n.t("%d days") % int(days), act.bind(func(): return Automotive.set_policy("service_days", days)), "tab_active" if int(policy["service_days"]) == int(days) else "tab")
		choice.name = "ServiceEvery_%d" % int(days)
		service_row.add_child(choice)
	button(service_row, I18n.t("Auto-service on return: ") + (I18n.t("on") if policy["auto_service"] else I18n.t("off")), "AutoService", func(): return Automotive.set_policy("auto_service", not bool(policy["auto_service"])))
	var buy_row := UIK.hbox(4)
	content.add_child(buy_row)
	for cls in Automotive.rental()["classes"]:
		var def: Dictionary = Automotive.rental()["classes"][cls]
		button(buy_row, I18n.t("Buy %s · %s · %s/day") % [I18n.t(def["name"]), Fmt.money0(def["price"]), Fmt.money0(Automotive.daily_rate(cls))], "BuyFleet_" + cls, Automotive.buy_fleet.bind(cls), fleet.is_empty() and cls == "economy")
	for id in fleet.slice(0, 12):
		var car: Dictionary = Automotive.S()["fleet"][id]
		var state := Automotive.car_state(id)
		var item := Automotive.fleet_item(id)
		var text := I18n.t("%s · %s · rentals %d · revenue %s") % [car["plate"], I18n.t(Automotive.class_def(car["class"])["name"]), int(car["rentals"]), Fmt.money0(car["revenue"])]
		var mark := "✓ " if state in ["ready", "rented"] and not bool(item.get("maintenance_due", false)) else "✗ "
		content.add_child(UIK.wrap(mark + text + " · " + I18n.t({"ready":"Ready", "rented":"On rent", "shop":"In the workshop", "broken":"Broken down", "sold":"Sold"}[state]) + (" · " + I18n.t("service due") if bool(item.get("maintenance_due", false)) else ""), 8, Art.C_WHITE, 550))
	if not has_primary:
		button(content, "Check the airport flow", "FleetNextAirport", go_to.bind("airport"), true)

# ------------------------------------------------------------------ dealership
func dealer_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Dealership franchise", "franchise", 9))
	var d := Automotive.dealer()
	if not Automotive.dealership_active():
		var ready := true
		for item in Automotive.franchise_checks():
			var text := I18n.t(item["label"]) % item["arg"] if item.has("arg") else I18n.t(item["label"])
			check(content, item["ok"], text + ("" if item["ok"] else " — " + I18n.t(item["hint"])))
			ready = ready and item["ok"]
		content.add_child(UIK.wrap(I18n.t("Deposit %s, minimum stock %d new cars, minimum order %d cars. Margins are thin (about 5–7%%) but sales are steady and service tickets follow every car you sell.") % [Fmt.money0(d["deposit"]), int(d["min_stock"]), int(d["min_order"])], 8, Art.C_SKY, 550))
		for brand in d["brands"]:
			var def: Dictionary = d["brands"][brand]
			button(content, I18n.t("Sign %s%s · deposit %s") % [I18n.t(def["name"]), I18n.t(" (EV)") if def["ev"] else "", Fmt.money0(d["deposit"])], "SignFranchise_" + brand, Automotive.sign_franchise.bind(brand), ready and brand == "meridian")
		if not ready: button(content, "Go to the rental fleet", "DealerNextFleet", go_to.bind("fleet"), true)
		return
	var brand_def := Automotive.brand_def()
	var franchise := Automotive.franchise()
	check(content, Automotive.new_stock().size() + Automotive.incoming_count() >= int(d["min_stock"]), I18n.t("Franchise minimum: keep %d new cars in stock or on order. Missing cars cost %s each at month end.") % [int(d["min_stock"]), Fmt.money0(d["shortfall_fee"])])
	content.add_child(UIK.wrap(I18n.t("%s · sold %d · service visits %d · in stock %d · on order %d · discount %d%%") % [I18n.t(brand_def["name"]), int(franchise["sold"]), int(franchise["visits"]), Automotive.new_stock().size(), Automotive.incoming_count(), roundi(float(Automotive.policy()["discount"]) * 100)], 8, Art.C_WHITE, 550))
	for model in brand_def["models"]:
		var row := UIK.hbox(4)
		content.add_child(row)
		button(row, I18n.t("Order %d × %s · %s") % [order_qty, I18n.t(model["name"]), Fmt.money0(Automotive.unit_cost(model) * order_qty)], "Order_" + model["id"], Automotive.order_new.bind(model["id"], order_qty), Automotive.new_stock().size() + Automotive.incoming_count() < int(d["min_stock"]) and model == brand_def["models"][0])
		row.add_child(UIK.label(I18n.t("sells at %s · stock %d") % [Fmt.money0(Automotive.new_car_price(model["msrp"])), Automotive.new_stock(model["id"]).size()], 8))
	var row := UIK.hbox(4)
	content.add_child(row)
	row.add_child(UIK.label(I18n.t("Showroom discount"), 8))
	button(row, "−1%", "DiscountLess", func(): return Automotive.set_policy("discount", float(Automotive.policy()["discount"]) - 0.01))
	button(row, "+1%", "DiscountMore", func(): return Automotive.set_policy("discount", float(Automotive.policy()["discount"]) + 0.01))
	button(row, "Order +1", "OrderMore", func(): order_qty = mini(8, order_qty + 1); return {"ok":true})
	button(row, "Order −1", "OrderLess", func(): order_qty = maxi(int(d["min_order"]), order_qty - 1); return {"ok":true})
	button(content, "End the franchise", "EndFranchise", func(): return Automotive.terminate(false))
	if not has_primary: button(content, "Check the airport flow", "DealerNextAirport", go_to.bind("airport"), true)

# ------------------------------------------------------------------ airport
func airport_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Passenger flow", "fleet_util", 9))
	var airport: Dictionary = Automotive.cfg()["airport"]
	content.add_child(UIK.wrap(I18n.t("Today %d passengers · season factor %.2f · about %.1f rental requests a day at your prices.") % [roundi(Automotive.passengers()), float(airport["season"][int(Clock.date()["month"]) - 1]), Automotive.rental_requests()], 8, Art.C_WHITE, 550))
	content.add_child(UIK.wrap(I18n.t("Business travellers %d%%, tourists %d%%. A fuel-price scare, a bad rating or high rates cut requests; the fleet size limits how many you can serve.") % [roundi(float(airport["business_share"]) * 100), roundi((1.0 - float(airport["business_share"])) * 100)], 8, Art.C_MUTED, 550))
	for offset in range(1, 8):
		var t := Clock.now() + offset * Clock.DAY
		content.add_child(UIK.label(I18n.t("%s: %d passengers/day") % [I18n.t(Clock.WEEKDAYS[Clock.weekday(t)]), roundi(Automotive.passengers(t))], 7, Art.C_MUTED))
	if Automotive.hotel_guests() > 0:
		content.add_child(UIK.label(I18n.t("Hotel guests add %d rental requests a day.") % roundi(Automotive.hotel_guests() * float(Automotive.cfg()["hooks"]["hotel_guest_rentals"]) * float(Automotive.rental()["request_rate"]) * float(Automotive.rental()["capture"]) * 1000), 8, Art.C_SKY))
	button(content, "Open the rental fleet", "AirportNextFleet", go_to.bind("fleet"), true)
