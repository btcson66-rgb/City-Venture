class_name IndustryViews
extends RefCounted
## Registered legacy business-board renderers.


static func ecommerce(det: Control, board: Node) -> void:
	det.add_child(UIK.wrap(_supplier_notice(), 8, Art.C_WHITE, 300))
	det.add_child(UIK.wrap(I18n.t("ShopLane marketplace: %d%% fee, weekly payouts, personal sellers capped at %s/month.") % [int(round(float(Ecommerce.mk()["fee_rate"]) * 100.0)), Fmt.money0(float(Ecommerce.mk()["personal_seller_cap"]))], 8, Art.C_MUTED, 300))
	if GameState.flag("business_chosen"):
		det.add_child(UIK.label("✓ You're running this.", 9, Art.C_GREEN, true))
	else:
		var go := UIK.button("Start an ecommerce side business", board._choose, "primary")
		go.name = "StartEcommerce"
		det.add_child(go)


static func _supplier_notice() -> String:
	var offers: Array[String] = []
	for offer in DataDB.suppliers["tradelink_wholesale"].get("offers", []):
		offers.append(I18n.t(str(DataDB.product(offer["product"])["name"])) + " " + Fmt.money(float(offer["unit_cost"])))
	return I18n.t("Posted by Ken (TradeLink Wholesale): %s. MOQs apply. Order via laptop.") % " · ".join(offers)


static func consulting(det: Control, board: Node) -> void:
	det.add_child(UIK.wrap("Clients post small projects every morning. Accept one, put the hours in at any laptop (Company OS → Freelance), deliver before the deadline and get paid on the client's terms. On-time work raises your stars and your rate.", 8, Art.C_WHITE, 300))
	if Careers.freelance_active():
		det.add_child(UIK.label("✓ You're freelancing. Find gigs in Company OS.", 9, Art.C_GREEN, true))
	else:
		var go2 := UIK.button("Start freelancing", board._start_freelance, "primary")
		go2.name = "StartFreelance"
		det.add_child(go2)


static func saas(det: Control, board: Node) -> void:
	det.add_child(UIK.wrap("Pick a product idea and build it in Company OS → SaaS: development hours first, subscribers after launch. Hire developers to build faster.", 8, Art.C_WHITE, 300))
	if Saas.active():
		det.add_child(UIK.label(I18n.t("✓ You're building %s.") % str(Saas.idea().get("name", "")), 9, Art.C_GREEN, true))
	else:
		var start := UIK.button("Start from any laptop: Company OS → SaaS.", func():
			var os := CompanyOS.new("home_laptop")
			os.tab = "saas"
			UIRoot.open_modal(os), "primary")
		start.name = "StartSaas"
		det.add_child(start)


static func cafe(det: Control, board: Node) -> void:
	det.add_child(UIK.wrap("Rent the corner unit in Old Town from Mr. Okafor (Okafor Lettings), fit it out, get the food licence at City Hall, and open. Set the menu, keep coffee in stock, order pastries, and put someone behind the counter: a barista, or you.", 8, Art.C_WHITE, 300))
	if Cafe.leased():
		det.add_child(UIK.label(I18n.t("✓ You run %s.") % Cafe.display_name(), 9, Art.C_GREEN, true))
	else:
		det.add_child(UIK.label("Old Town: metro (Loop Line), or walk west from Shopping Street.", 8, Art.C_SKY, true))


static func logistics(det: Control, board: Node) -> void:
	det.add_child(UIK.wrap("Buy a used van from Sam Okoro at Dockside Motors in the Harbor, and it works two ways: deliver your own ecommerce parcels for fuel instead of a courier fee, and take local delivery runs posted every morning (Company OS → Logistics), planning each route yourself. Rent a bay at Pier 7 for cheap stock space, and hire drivers.", 8, Art.C_WHITE, 300))
	if Logistics.has_van():
		det.add_child(UIK.label("✓ You run a van. Runs are in Company OS → Logistics.", 9, Art.C_GREEN, true))
	else:
		det.add_child(UIK.label("Harbor: metro Harbor Line (M3) from Riverside. Sam is at Dockside Motors, Mon–Sat.", 8, Art.C_SKY, true))
