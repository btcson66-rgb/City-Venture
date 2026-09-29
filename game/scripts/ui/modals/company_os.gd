class_name CompanyOS
extends Modal
## Company OS (Handoff §52–53, kickoff §15). The former "dashboard", demoted to a tool you use at a
## terminal: apartment laptop, co-work hot desk, cafe table, or your office desk.

const TABS := [["overview", "Overview", "company"], ["finance", "Finance", "finance"], ["sales", "Sales", "orders"],
	["operations", "Operations", "parcel"], ["inventory", "Inventory", "inventory"], ["people", "People", "people"],
	["contracts", "Contracts", "contracts"], ["freelance", "Freelance", "tasks"], ["saas", "SaaS", "laptop"]]
const PLANNED := [["Property", "home"], ["International", "world"], ["Reports", "tasks"]]

var terminal := "laptop"
var tab := "overview"
var content: VBoxContainer
var sel_contract := ""
var counter_price := 0.0
var counter_terms := 30
var counter_up := 0.0
var buy_qty := {}
var new_price := {}
var deliver_to := ""


## Order / contract status chips (ids stay English in data; shown translated).
const STATUS_TEXT := {
	"placed": "PLACED", "packed": "PACKED", "awaiting_pickup": "AWAITING PICKUP", "carried": "CARRIED",
	"shipped": "SHIPPED", "in_transit": "IN TRANSIT", "delivered": "DELIVERED", "return_requested": "RETURN REQUESTED",
	"refunded": "REFUNDED", "replaced": "REPLACED", "partial_refund": "PARTIAL REFUND", "refused": "REFUSED",
	"disputed": "DISPUTED", "offered": "OFFERED", "countered": "COUNTERED", "active": "ACTIVE", "paid": "PAID",
	"rejected": "REJECTED", "expired": "EXPIRED", "withdrawn": "WITHDRAWN", "overdue": "OVERDUE", "declined": "DECLINED",
	"late": "LATE", "called": "CALLED", "defaulted": "DEFAULTED", "closed": "CLOSED", "written_off": "WRITTEN OFF",
	"invoiced": "INVOICED", "cancelled": "CANCELLED",
}


static func status_text(s: String) -> String:
	return I18n.t(STATUS_TEXT.get(s, s.replace("_", " ").to_upper()))


func _init(term: String) -> void:
	terminal = term
	panel_size = Vector2(624, 344)
	title_text = "COMPANY OS"
	icon_name = "laptop"
	help_key = "os_overview"


func _ready() -> void:
	super._ready()
	GameState.set_flag("company_os_opened")
	if GameState.company_id() != "":
		GameState.set_flag("company_os_opened_as_company")
	if terminal == "office":
		GameState.set_flag("used_office_desk")


func build() -> void:
	var where: String = {"home_laptop": "Laptop · Riverside Tower 7C", "cowork": "Hot desk · Nexus Co-work", "office": "Desk · Suite 2B",
		"cafe": "Laptop · café table"}.get(terminal, terminal)
	var top := UIK.hbox(6)
	body.add_child(top)
	top.add_child(UIK.title(GameState.business_display_name(), 11, Art.C_GOLD))
	top.add_child(UIK.label(where, 7, Art.C_DIM))
	top.add_child(UIK.expand())
	top.add_child(UIK.label(Clock.fmt_datetime(), 7, Art.C_MUTED, true))
	var row := UIK.hbox(6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var nav := UIK.vbox(2)
	nav.custom_minimum_size = Vector2(96, 0)
	row.add_child(nav)
	for t in TABS:
		var b := UIK.button(t[1], _set_tab.bind(t[0]), "tab_active" if tab == t[0] else "tab")
		b.icon = Art.icon(t[2])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Tab_" + t[0]
		if t[0] == "contracts" and _open_offers() > 0:
			b.text = I18n.t(b.text) + " ●"
		nav.add_child(b)
	nav.add_child(UIK.sep())
	var planned: Array = []
	for p in PLANNED:
		planned.append(I18n.t(p[0]))
	nav.add_child(UIK.wrap(I18n.t("Planned: %s") % " · ".join(planned), 6, Art.C_DIM, 94))
	content = UIK.vbox(3)
	var sc := UIK.scroll(content, Vector2(500, 272))
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sc)
	call("_tab_" + tab)


func _set_tab(t: String) -> void:
	tab = t
	help_key = "os_" + t   # the ? button explains the tab you're on
	rebuild()
	Help.show_once.call_deferred(help_key)


func _open_offers() -> int:
	return GameState.data["contracts"].values().filter(func(c): return c["status"] == "offered").size()


func _section(t: String) -> void:
	content.add_child(UIK.label(I18n.t(t).to_upper(), 7, Art.C_DIM, true))


func _kpi(grid: GridContainer, label: String, value: String, col := Art.C_WHITE, sub := "") -> void:
	var p := UIK.panel("ui/card", 4)
	p.custom_minimum_size = Vector2(118, 36)
	var v := UIK.vbox(0)
	p.add_child(v)
	v.add_child(UIK.label(label, 6, Art.C_MUTED, true))
	v.add_child(UIK.title(value, 11, col))
	if sub != "":
		v.add_child(UIK.label(sub, 6, Art.C_DIM))
	grid.add_child(p)


# ============================================================== OVERVIEW
func _tab_overview() -> void:
	var be := GameState.business_entity()
	var cur := MonthClose.current(be)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	content.add_child(g)
	_kpi(g, "MONTHLY REVENUE", Fmt.money0(cur["net_revenue"]), Art.C_WHITE, "month to date")
	_kpi(g, "MONTHLY PROFIT", Fmt.money0(cur["business_profit"]), UIK.money_color(cur["business_profit"]), "business only")
	_kpi(g, "CASH", Fmt.money0(Ledger.cash(be)), UIK.money_color(Ledger.cash(be)), "in the bank")
	var ar := Ledger.balance(be, "marketplace_balance") + Ledger.balance(be, "accounts_receivable")
	_kpi(g, "RECEIVABLE", Fmt.money0(ar), Art.C_GOLD, "ShopLane + invoices")
	_kpi(g, "PAYABLE", Fmt.money0(-Ledger.balance(be, "accounts_payable")), Art.C_GOLD, "to suppliers")
	_kpi(g, "EMPLOYEES", "1", Art.C_WHITE, "you")
	_kpi(g, "COMPANY VALUE", Fmt.money0(Company.company_value()), Art.C_SKY, "book value")
	_kpi(g, "STAGE", "0 · Solo", Art.C_WHITE, "no buffs, just scale")
	_section("Needs attention")
	var alerts: Array = []
	var to_pack := Ecommerce.orders_with(["placed"]).size()
	if to_pack > 0:
		alerts.append(["warning", I18n.t("%d order%s waiting to be packed — packing table (home or office).") % [to_pack, I18n.pl(to_pack)]])
	for l in GameState.data["ecommerce"]["listings"].values():
		var a := Ecommerce.available_anywhere(l["product"])
		if a <= 5 and l["active"]:
			alerts.append(["inventory", I18n.t("%s: only %d left. Restock in Operations.") % [I18n.t(DataDB.product(l["product"])["name"]), a]])
	if Ecommerce.is_capped():
		alerts.append(["lock", "ShopLane personal seller cap reached — register a company at City Hall."])
	elif Ecommerce.is_personal() and Ecommerce.month_gmv() > 0:
		alerts.append(["info", I18n.t("Personal seller cap: %s of %s used this month.") % [Fmt.money0(Ecommerce.month_gmv()), Fmt.money0(Ecommerce.seller_cap())]])
	if _open_offers() > 0:
		alerts.append(["contracts", "A contract offer is waiting in Contracts."])
	if not EventEngine.pending().is_empty():
		alerts.append(["warning", I18n.t("Decision pending: %s") % I18n.t(DataDB.events[EventEngine.next_pending()["id"]]["presentation"].get("title", ""))])
	var dom := int(Clock.date()["day"])
	if dom < 14 and dom >= 9:
		alerts.append(["home", I18n.t("Home rent %s due on the 14th.") % Fmt.money0(1250)])
	if GameState.data["ecommerce"]["listings"].is_empty():
		alerts.append(["objective", "No listings yet. Buy stock (Operations), then list it (Sales)."])
	if alerts.is_empty():
		alerts.append(["check", "All quiet. Go outside."])
	for a2 in alerts:
		var h := UIK.hbox(4)
		h.add_child(UIK.icon(a2[0], 12))
		h.add_child(UIK.wrap(a2[1], 8, Art.C_WHITE, 460))
		content.add_child(h)
	if "ch3_workspace" in GameState.data["story"]["active"] and not GameState.flag("workspace_chosen"):
		content.add_child(UIK.sep())
		content.add_child(UIK.wrap(I18n.t("Where does %s work from? A co-work desk ($350/mo) or Suite 2B ($1,600/mo) in Startup Hub — or right here, for free.") % GameState.entity_name(GameState.company_id()), 8, Art.C_SKY, 480))
		var b := UIK.button("Run it from home for now", func():
			GameState.set_flag("workspace_chosen")
			GameState.timeline("Decided to run the company from home for now.", "business")
			rebuild())
		b.name = "HomeWorkspace"
		content.add_child(b)
	content.add_child(UIK.sep())
	content.add_child(UIK.label(I18n.t("Registration: ") + (("%s · %s" % [GameState.entity_name(GameState.company_id()), GameState.data["entities"][GameState.company_id()]["registration_no"]]) if GameState.company_id() != "" else "not registered (personal seller)"), 7, Art.C_MUTED))


# ============================================================== FINANCE
func _tab_finance() -> void:
	var be := GameState.business_entity()
	var cur := MonthClose.current(be)
	var cols := UIK.hbox(10)
	content.add_child(cols)
	var pl := UIK.vbox(1)
	pl.custom_minimum_size = Vector2(240, 0)
	cols.add_child(pl)
	pl.add_child(UIK.label(I18n.t("THIS MONTH (P&L) · ") + GameState.entity_name(be).to_upper(), 7, Art.C_DIM, true))
	pl.add_child(UIK.kv("Revenue", Fmt.money(cur["revenue"])))
	pl.add_child(UIK.kv("Refunds", Fmt.money(-cur["refunds"]), Art.C_RED))
	pl.add_child(UIK.kv("Cost of goods sold", Fmt.money(-cur["cogs"]), Art.C_RED))
	pl.add_child(UIK.kv("Gross profit", Fmt.money(cur["gross_profit"]), UIK.money_color(cur["gross_profit"]), 8, true))
	for k in cur["opex"]:
		pl.add_child(UIK.kv("  " + str(k).replace("_", " ").capitalize(), Fmt.money(-float(cur["opex"][k])), Art.C_RED, 7))
	pl.add_child(UIK.kv("Business profit", Fmt.money(cur["business_profit"]), UIK.money_color(cur["business_profit"]), 9, true))
	if be == "player":
		if float(cur.get("wages", 0.0)) > 0.0:
			pl.add_child(UIK.kv("Wages from your job", Fmt.money(cur["wages"]), Art.C_GREEN, 7))
		pl.add_child(UIK.kv("Home rent + living", Fmt.money(-cur["personal_total"]), Art.C_RED, 7))
	var cp := UIK.vbox(1)
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(cp)
	cp.add_child(UIK.label("CASH POSITION", 7, Art.C_DIM, true))
	cp.add_child(UIK.kv("Cash in bank", Fmt.money(Ledger.cash(be)), UIK.money_color(Ledger.cash(be)), 9, true))
	cp.add_child(UIK.kv("ShopLane balance (paid Mondays)", Fmt.money(Ledger.balance(be, "marketplace_balance")), Art.C_GOLD))
	cp.add_child(UIK.kv("  of which on hold (<2 days)", Fmt.money(Ecommerce.held_amount(be)), Art.C_DIM, 7))
	cp.add_child(UIK.kv("Invoices receivable", Fmt.money(Ledger.balance(be, "accounts_receivable")), Art.C_GOLD))
	cp.add_child(UIK.kv("Supplier bills payable", Fmt.money(-Ledger.balance(be, "accounts_payable")), Art.C_GOLD))
	cp.add_child(UIK.kv("Stock (at cost)", Fmt.money(Ledger.balance(be, "inventory")), Art.C_SKY))
	cp.add_child(UIK.kv("Stock on the way", Fmt.money(Ledger.balance(be, "inventory_in_transit")), Art.C_SKY))
	cp.add_child(UIK.kv("Parcels out for delivery", Fmt.money(Ledger.balance(be, "goods_out")), Art.C_SKY))
	cp.add_child(UIK.kv("Deposits", Fmt.money(Ledger.balance(be, "deposits")), Art.C_SKY))
	if Bank.debt(be) > 0.0:
		cp.add_child(UIK.kv("Bank loans", Fmt.money(-Bank.debt(be)), Art.C_RED))
	if Staff.wages_owed() > 0.0 and be == Staff.entity():
		cp.add_child(UIK.kv("Wages owed to staff", Fmt.money(-Staff.wages_owed()), Art.C_RED))
	cp.add_child(UIK.kv("Credit score", "%d · %s" % [Bank.credit(), I18n.t(Bank.credit_band())], Art.C_SKY, 7))
	var reps: Array = GameState.data["reports"]["month_closes"]
	if not reps.is_empty():
		cp.add_child(UIK.button(I18n.t("Open last month close (%s)") % MonthClose.label_of(reps[-1]), func(): UIRoot.open_modal(MonthCloseModal.new(reps[-1]))))
	_forecast(be)
	_section("Recent transactions")
	for e in Ledger.entries(be, 14):
		var row := UIK.hbox(4)
		row.add_child(UIK.label(Clock.fmt_short(int(e["t"])), 6, Art.C_DIM))
		var m := UIK.label(str(e["memo"]).left(58), 7, Art.C_WHITE)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(m)
		var c := Ledger.entry_cash(e)
		row.add_child(UIK.label(Fmt.money(c, true) if absf(c) > 0.001 else "non-cash", 7, UIK.money_color(c) if absf(c) > 0.001 else Art.C_DIM, true))
		content.add_child(row)


## Week-by-week cash forecast: revenue isn't cash until it lands, and payroll comes every Friday.
func _forecast(be: String) -> void:
	GameState.set_flag("cash_forecast_viewed")
	if StoryEngine.St().get("chapter", "") == "ch6_cash_is_oxygen":
		GameState.set_flag("forecast_checked_ch6")
	var fc := Forecast.weekly(be)
	_section("Cash forecast · next 9 weeks")
	var fn := int(fc["first_negative"])
	var msg := I18n.t("Cash stays positive for the next 9 weeks (lowest %s).") % Fmt.money0(float(fc["low"])) if fn < 0 else \
		I18n.t("Cash runs out in week %d (lowest %s). Borrow, raise, cut costs or get paid sooner.") % [fn + 1, Fmt.money0(float(fc["low"]))]
	content.add_child(UIK.wrap(msg, 8, Art.C_GREEN if fn < 0 else Art.C_RED, 480))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	content.add_child(grid)
	for h in ["Week of", "Money in", "Money out", "Cash at end", "Biggest item"]:
		grid.add_child(UIK.label(h, 6, Art.C_DIM, true))
	for r in fc["rows"]:
		grid.add_child(UIK.label(Clock.fmt_short(int(r["start"])), 7, Art.C_MUTED))
		grid.add_child(UIK.label(Fmt.money0(float(r["in"])), 7, Art.C_GREEN))
		grid.add_child(UIK.label(Fmt.money0(-float(r["out"])), 7, Art.C_RED))
		grid.add_child(UIK.label(Fmt.money0(float(r["end"])), 7, UIK.money_color(float(r["end"])), true))
		var big := ""
		var bv := 0.0
		for k in r["items"]:
			if absf(float(r["items"][k])) > absf(bv):
				bv = float(r["items"][k])
				big = str(k)
		grid.add_child(UIK.label((I18n.t(big) + " " + Fmt.money0(bv)) if big != "" else "", 6, Art.C_MUTED))
	content.add_child(UIK.label(I18n.t("Includes payroll, rent, loans, supplier bills, invoices due and estimated ShopLane sales (%s/day). Excludes restocking.") % Fmt.money0(float(fc["run_rate"])), 6, Art.C_DIM))
	if not GameState.flag("costs_cut"):
		var cb := UIK.button("Cut costs: pause ads, cheaper living", func():
			Ecommerce.pause_all_ads()
			GameState.data["living"]["reduced"] = true
			GameState.set_flag("costs_cut")
			UIRoot.toast("Ads paused and living costs cut. Growth slows; cash lasts longer.", "info", "cash")
			rebuild())
		cb.name = "CutCosts"
		content.add_child(cb)


# ============================================================== SALES
func _tab_sales() -> void:
	if Ecommerce.is_personal():
		var capbar := ProgressBar.new()
		capbar.max_value = Ecommerce.seller_cap()
		capbar.value = minf(Ecommerce.month_gmv(), Ecommerce.seller_cap())
		capbar.show_percentage = false
		capbar.custom_minimum_size = Vector2(480, 6)
		content.add_child(UIK.kv("ShopLane personal seller cap", "%s / %s" % [Fmt.money0(Ecommerce.month_gmv()), Fmt.money0(Ecommerce.seller_cap())], Art.C_GOLD, 7))
		content.add_child(capbar)
	_section("Listings on ShopLane (10% fee · weekly payout)")
	var listings: Array = GameState.data["ecommerce"]["listings"].values()
	if listings.is_empty():
		content.add_child(UIK.label("No listings yet.", 8, Art.C_MUTED))
	for l in listings:
		var p := DataDB.product(l["product"])
		var card := UIK.panel("ui/card", 4)
		var v := UIK.vbox(2)
		card.add_child(v)
		var h1 := UIK.hbox(6)
		var ic := TextureRect.new()
		# the listing's photo (products/<id>_photo = Studio Lumen, _photo_raw = your own) once the art exists
		var shot := Art.opt_tex("products/%s_%s" % [str(l["product"]), "photo" if l.get("photo", "") == "studio" else "photo_raw"])
		if shot != null:
			ic.texture = shot
			ic.custom_minimum_size = Vector2(32, 32)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			ic.texture = Art.tex(str(p.get("icon", "props/product_parcel")))
		h1.add_child(ic)
		h1.add_child(UIK.label(p["name"], 9, Art.C_WHITE, true))
		h1.add_child(UIK.chip("LIVE" if l["active"] else ("PAUSED · CAP" if l.get("paused_reason", "") == "seller_cap" else "PAUSED"), Art.C_GREEN if l["active"] else Art.C_GOLD))
		h1.add_child(UIK.expand())
		h1.add_child(UIK.label("%s (%d)" % [Fmt.stars(Ecommerce.rating(l)), int(l["rating_n"])], 8, Art.C_GOLD))
		v.add_child(h1)
		var h2 := UIK.hbox(4)
		h2.add_child(UIK.label("Price", 7, Art.C_MUTED))
		h2.add_child(UIK.button("−", func(): Ecommerce.set_price(l["id"], float(l["price"]) - 1.0); rebuild()))
		h2.add_child(UIK.label(Fmt.money(l["price"]), 9, Art.C_WHITE, true))
		h2.add_child(UIK.button("+", func(): Ecommerce.set_price(l["id"], float(l["price"]) + 1.0); rebuild()))
		h2.add_child(UIK.label("  Ads/day", 7, Art.C_MUTED))
		h2.add_child(UIK.button("−", func(): Ecommerce.set_ad_budget(l["id"], float(l["ad_budget"]) - 5.0); rebuild()))
		h2.add_child(UIK.label(Fmt.money0(l["ad_budget"]), 9, Art.C_WHITE, true))
		var plus := UIK.button("+", func(): Ecommerce.set_ad_budget(l["id"], float(l["ad_budget"]) + 5.0); rebuild())
		plus.name = "AdPlus_" + l["product"]
		h2.add_child(plus)
		h2.add_child(UIK.expand())
		h2.add_child(UIK.button("Pause" if l["active"] else "Resume", func(): Ecommerce.set_active(l["id"], not l["active"]); rebuild()))
		v.add_child(h2)
		var margin := float(l["price"]) * 0.9 - Ecommerce.avg_cost(Ecommerce.best_location(l["product"]) if Ecommerce.best_location(l["product"]) != "" else "riverside_studio", l["product"]) - Ecommerce.ship_cost({"product": l["product"]}, "economy")
		v.add_child(UIK.label(I18n.t("Market ~%s · expect ~%.1f orders/day · %d views · %d orders · in stock %d · unit margin after fee+shipping ≈ %s") % [
			Fmt.money0(float(p["ref_price"])), Ecommerce.lambda_day(l), int(l["views"]), int(l["orders"]), Ecommerce.available_anywhere(l["product"]), Fmt.money(margin)], 7, Art.C_MUTED))
		content.add_child(card)
	# new listings
	var unlisted: Array = []
	for pid in DataDB.products:
		if Ecommerce.listing_for(pid).is_empty() and Ecommerce.total_units_at_any(pid) > 0:
			unlisted.append(pid)
	if not unlisted.is_empty():
		_section("Ready to list (you have these in hand)")
		for pid in unlisted:
			var p2 := DataDB.product(pid)
			if not new_price.has(pid):
				new_price[pid] = snappedf(float(p2["ref_price"]) * 0.93, 1.0) - 0.01
			var card2 := UIK.panel("ui/card_gold", 4)
			var v2 := UIK.vbox(2)
			card2.add_child(v2)
			var h := UIK.hbox(4)
			h.add_child(UIK.label(p2["name"], 9, Art.C_WHITE, true))
			h.add_child(UIK.label(I18n.t("market ~%s") % Fmt.money0(float(p2["ref_price"])), 7, Art.C_MUTED))
			h.add_child(UIK.expand())
			h.add_child(UIK.button("−", func(): new_price[pid] = maxf(float(p2["price_min"]), float(new_price[pid]) - 1.0); rebuild()))
			h.add_child(UIK.label(Fmt.money(new_price[pid]), 9, Art.C_WHITE, true))
			h.add_child(UIK.button("+", func(): new_price[pid] = minf(float(p2["price_max"]), float(new_price[pid]) + 1.0); rebuild()))
			v2.add_child(h)
			var h3 := UIK.hbox(4)
			var b1 := UIK.button("Shoot photos myself & list (1 h 20 min)", _list.bind(pid, "self"), "primary")
			b1.name = "ListSelf_" + pid
			h3.add_child(b1)
			var b2 := UIK.button("Studio Lumen photos ($120) & list", _list.bind(pid, "studio"))
			b2.name = "ListStudio_" + pid
			h3.add_child(b2)
			v2.add_child(h3)
			content.add_child(card2)
	_section("Recent orders")
	var orders: Array = GameState.data["ecommerce"]["orders"].values()
	orders.sort_custom(func(a, b): return int(a["placed"]) > int(b["placed"]))
	for o in orders.slice(0, 10):
		var row := UIK.hbox(4)
		row.add_child(UIK.label(o["id"], 7, Art.C_DIM))
		var t := UIK.label("%s · %s" % [I18n.t(DataDB.product(o["product"])["name"]), o["customer"]], 7, Art.C_WHITE)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		row.add_child(UIK.label(Fmt.money(o["unit_price"]), 7, Art.C_WHITE))
		row.add_child(UIK.chip(status_text(str(o["status"])), _status_col(o["status"])))
		if o.has("review"):
			row.add_child(UIK.label("★".repeat(int(o["review"]["stars"])), 7, Art.C_GOLD))
		content.add_child(row)


func _status_col(s: String) -> Color:
	match s:
		"placed":
			return Art.C_GOLD
		"delivered", "replaced":
			return Art.C_GREEN
		"refunded", "refused", "disputed", "return_requested":
			return Art.C_RED
	return Art.C_BLUE


func _list(pid: String, photo: String) -> void:
	if photo == "self":
		# you shoot the photos yourself: set up the table, frame it, press the shutter
		MiniGames.play(PhotoShootGame.new(pid), func(res: Dictionary):
			if not res.get("aborted", false):
				_do_list(pid, "self", float(res.get("score", 0.6))))
		return
	_do_list(pid, photo, -1.0)


func _do_list(pid: String, photo: String, photo_q: float) -> void:
	var r := Ecommerce.create_listing(pid, float(new_price.get(pid, 20.0)), photo, photo_q)
	if not r["ok"]:
		UIRoot.toast(r["error"], "bad", "warning")
		return
	var mins := int(DataDB.marketplace().get("listing_minutes", 20)) + (int(DataDB.marketplace().get("self_photo_minutes", 60)) if photo == "self" else 0)
	Clock.advance(mins)
	UIRoot.toast(I18n.t("Listed %s at %s. Took %s.") % [I18n.t(DataDB.product(pid)["name"]), Fmt.money(new_price[pid]), Fmt.duration_min(mins)], "good", "orders")
	if is_inside_tree():
		rebuild()


# ============================================================== OPERATIONS
func _tab_operations() -> void:
	_section("Fulfilment pipeline")
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 4)
	content.add_child(g)
	for st in [["placed", "To pack"], ["packed", "Packed"], ["awaiting_pickup", "Awaiting courier"], ["carried", "You're carrying"], ["shipped", "In transit"]]:
		var p := UIK.panel("ui/card", 3)
		p.custom_minimum_size = Vector2(92, 28)
		var v := UIK.vbox(0)
		p.add_child(v)
		v.add_child(UIK.label(st[1], 6, Art.C_MUTED, true))
		v.add_child(UIK.title(str(Ecommerce.orders_with([st[0]]).size()), 11))
		g.add_child(p)
	content.add_child(UIK.label("Packing happens at a packing table where the stock is. Ship by courier (fee, no walk) or carry to PostPoint.", 7, Art.C_DIM))
	_section("Suppliers")
	if deliver_to == "" or not deliver_to in Ecommerce.stock_locations():
		deliver_to = Ecommerce.default_stock_location()
	var loc := deliver_to
	var capu := Ecommerce.location_capacity(loc)
	var dh := UIK.hbox(4)
	dh.add_child(UIK.label("Deliver to:", 7, Art.C_MUTED, true))
	for l2 in Ecommerce.stock_locations():
		var tb := UIK.button(Ecommerce.location_name(l2).left(22), func(): deliver_to = l2; rebuild(), "tab_active" if l2 == loc else "tab")
		tb.name = "DeliverTo_" + l2
		dh.add_child(tb)
	dh.add_child(UIK.label(I18n.t("%d/%d units incl. incoming") % [Ecommerce.total_units_at(loc) + Ecommerce.incoming_units(loc), capu], 7, Art.C_DIM))
	content.add_child(dh)
	for sid in DataDB.suppliers:
		var s := DataDB.supplier(sid)
		var card := UIK.panel("ui/card", 4)
		var v2 := UIK.vbox(1)
		card.add_child(v2)
		var hh := UIK.hbox(4)
		hh.add_child(UIK.label(s["name"], 9, Art.C_WHITE, true))
		hh.add_child(UIK.label(s.get("blurb", ""), 7, Art.C_MUTED))
		v2.add_child(hh)
		for o in s["offers"]:
			var pid: String = o["product"]
			var key: String = sid + ":" + pid
			if not buy_qty.has(key):
				buy_qty[key] = int(o["moq"])
			var uc := Ecommerce.unit_cost(sid, pid)
			var mult := Ecommerce.cost_multiplier(sid, pid)
			var row := UIK.hbox(4)
			var nl := UIK.label(I18n.t(DataDB.product(pid)["name"]), 8, Art.C_WHITE)
			nl.custom_minimum_size = Vector2(118, 0)
			row.add_child(nl)
			row.add_child(UIK.label("%s/u%s" % [Fmt.money(uc), " (+%d%%)" % int(round((mult - 1.0) * 100)) if mult > 1.001 else ""], 8, Art.C_RED if mult > 1.001 else Art.C_WHITE, true))
			row.add_child(UIK.label(I18n.t("MOQ %d · %dd · %s duds") % [int(o["moq"]), int(o["lead_days"]), Fmt.pct(float(o["defect_rate"]), 0) if float(o["defect_rate"]) >= 0.01 else "<1%"], 7, Art.C_MUTED))
			row.add_child(UIK.expand())
			row.add_child(UIK.button("−", func(): buy_qty[key] = maxi(int(o["moq"]), int(buy_qty[key]) - int(o["moq"])); rebuild()))
			row.add_child(UIK.label(str(buy_qty[key]), 8, Art.C_WHITE, true))
			row.add_child(UIK.button("+", func(): buy_qty[key] = int(buy_qty[key]) + int(o["moq"]); rebuild()))
			var bb := UIK.button(I18n.t("Buy %s") % Fmt.money0(uc * int(buy_qty[key])), _buy.bind(sid, pid, key, false), "primary")
			bb.name = "Buy_%s_%s" % [sid, pid]
			row.add_child(bb)
			if Ecommerce.can_use_net_terms(sid):
				row.add_child(UIK.button(I18n.t("Net %d") % int(s["net_terms_for_companies"]["days"]), _buy.bind(sid, pid, key, true)))
			v2.add_child(row)
		content.add_child(card)
	_section("Purchase orders")
	var pos: Array = GameState.data["ecommerce"]["purchase_orders"].values()
	pos.sort_custom(func(a, b): return int(a["placed"]) > int(b["placed"]))
	for po in pos.slice(0, 8):
		var row2 := UIK.hbox(4)
		row2.add_child(UIK.label(po["id"], 7, Art.C_DIM))
		var t := UIK.label("%d × %s · %s" % [int(po["qty"]), I18n.t(DataDB.product(po["product"])["name"]), I18n.t(DataDB.supplier(po["supplier"])["name"])], 7, Art.C_WHITE)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(t)
		row2.add_child(UIK.label(Fmt.money(po["total"]) + (" · Net" if po["terms"] == "net" else ""), 7, Art.C_WHITE))
		row2.add_child(UIK.chip(I18n.t("ARRIVES ") + Clock.fmt_short(int(po["eta"])).to_upper() if po["status"] == "in_transit" else "DELIVERED", Art.C_GOLD if po["status"] == "in_transit" else Art.C_GREEN))
		content.add_child(row2)


func _buy(sid: String, pid: String, key: String, terms: bool) -> void:
	var r := Ecommerce.buy(sid, pid, int(buy_qty[key]), deliver_to, terms)
	if not r["ok"]:
		UIRoot.toast(r["error"], "bad", "warning")
		return
	Clock.advance(10)
	UIRoot.toast(I18n.t("Ordered %d × %s — %s. Arrives %s.") % [int(buy_qty[key]), I18n.t(DataDB.product(pid)["name"]), Fmt.money(r["total"]), Clock.fmt_short(int(r["eta"]))], "good", "parcel")
	rebuild()


# ============================================================== INVENTORY
func _tab_inventory() -> void:
	for loc in Ecommerce.stock_locations():
		_section(Ecommerce.location_name(loc))
		var cap := Ecommerce.location_capacity(loc)
		var used := Ecommerce.total_units_at(loc)
		var bar := ProgressBar.new()
		bar.max_value = cap
		bar.value = used
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(480, 6)
		content.add_child(UIK.kv("Space", I18n.t("%d / %d units") % [used, cap], Art.C_MUTED, 7))
		content.add_child(bar)
		var hdr := UIK.hbox(4)
		for c in [["Product", 150], ["On hand", 60], ["Reserved", 60], ["Avg cost", 70], ["Value", 70], ["Incoming", 60]]:
			var l := UIK.label(c[0], 7, Art.C_DIM, true)
			l.custom_minimum_size = Vector2(c[1], 0)
			hdr.add_child(l)
		content.add_child(hdr)
		for pid in DataDB.products:
			var q := Ecommerce.stock(loc, pid)
			var inc := 0
			for po in GameState.data["ecommerce"]["purchase_orders"].values():
				if po["status"] == "in_transit" and po["location"] == loc and po["product"] == pid:
					inc += int(po["qty"])
			if q == 0 and inc == 0:
				continue
			var row := UIK.hbox(4)
			for c2 in [[I18n.t(DataDB.product(pid)["name"]), 150], [str(q), 60], [str(Ecommerce.reserved(loc, pid)), 60], [Fmt.money(Ecommerce.avg_cost(loc, pid)), 70],
					[Fmt.money(q * Ecommerce.avg_cost(loc, pid)), 70], [str(inc), 60]]:
				var l2 := UIK.label(c2[0], 8, Art.C_WHITE)
				l2.custom_minimum_size = Vector2(c2[1], 0)
				row.add_child(l2)
			content.add_child(row)
	content.add_child(UIK.sep())
	content.add_child(UIK.kv("Total stock value (books)", Fmt.money(Ledger.balance(GameState.business_entity(), "inventory")), Art.C_SKY, 8, true))
	content.add_child(UIK.wrap("Inventory is cash you can't spend. The ledger values it at average cost; a liquidator pays about 40% of that.", 7, Art.C_DIM, 480))


# ============================================================== PEOPLE
func _tab_people() -> void:
	var p: Dictionary = GameState.data["player"]
	var card := UIK.panel("ui/card", 5)
	var h := UIK.hbox(8)
	card.add_child(h)
	var pv := PortraitView.new()
	pv.custom_minimum_size = Vector2(40, 40)
	pv.size = Vector2(40, 40)
	pv.setup_character(p["appearance"], p.get("outfit", "startup_casual"))
	pv.set_expr("happy")
	h.add_child(pv)
	var v := UIK.vbox(1)
	h.add_child(v)
	var nm := UIK.label(p["name"], 10, Art.C_WHITE, true)
	nm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(nm)
	v.add_child(UIK.label("Founder · does everything nobody else does", 8, Art.C_MUTED))
	var ws := Staff.weekly_payroll()
	v.add_child(UIK.label(I18n.t("Team: %d · payroll %s / week (Fridays 17:00)") % [Staff.count(), Fmt.money0(ws)], 7, Art.C_SKY, true))
	if Staff.wages_owed() > 0.0:
		v.add_child(UIK.label(I18n.t("Wages owed to your team: %s") % Fmt.money(Staff.wages_owed()), 7, Art.C_RED, true))
	content.add_child(card)
	# team
	_section("Team")
	if Staff.people().is_empty():
		content.add_child(UIK.label("No employees yet. Every order is packed by you, which is why time matters.", 7, Art.C_DIM))
	for e in Staff.people():
		var row := UIK.panel("ui/card", 4)
		content.add_child(row)
		var rh := UIK.hbox(6)
		row.add_child(rh)
		var epv := PortraitView.new()
		epv.custom_minimum_size = Vector2(28, 28)
		epv.size = Vector2(28, 28)
		epv.setup_character(e["appearance"], e.get("outfit", "startup_casual"))
		rh.add_child(epv)
		var ev := UIK.vbox(0)
		ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(ev)
		var en := UIK.label("%s · %s" % [e["name"], I18n.t(str(Staff.role_def(e["role"]).get("name", e["role"])))], 8, Art.C_WHITE, true)
		en.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ev.add_child(en)
		var started: bool = Clock.now() >= int(e.get("start", 0))
		ev.add_child(UIK.label(I18n.t("Skill %d/5 · %s/week · %s") % [int(e["skill"]), Fmt.money0(float(e["salary_week"])),
			I18n.t(_trait_text(str(e.get("trait", "")))) if started else I18n.t("starts tomorrow 9:00")], 7, Art.C_MUTED))
		var mo := int(e["morale"])
		ev.add_child(UIK.label(I18n.t("Morale %d") % mo + "  " + "■".repeat(int(mo / 10.0)) + "□".repeat(10 - int(mo / 10.0)), 7,
			Art.C_GREEN if mo >= 60 else (Art.C_GOLD if mo >= 35 else Art.C_RED), true))
		var eid: String = e["id"]
		var rb := UIK.button(I18n.t("Raise +8%"), func(): Staff.give_raise(eid); rebuild())
		rb.name = "Raise_" + eid
		rh.add_child(rb)
		var lb := UIK.button("Let go", func():
			var r := Staff.let_go(eid)
			if r["ok"]:
				UIRoot.toast(I18n.t("Severance paid: %s.") % Fmt.money(r["severance"]), "info", "people")
			rebuild())
		lb.name = "LetGo_" + eid
		rh.add_child(lb)
	# hiring
	_section("Hiring")
	var why := Staff.hire_block()
	var st := Staff.S()
	if why != "":
		content.add_child(UIK.label(I18n.t("Can't hire yet: %s.") % I18n.t(why), 8, Art.C_GOLD, true))
	elif not st["applicants"].is_empty():
		content.add_child(UIK.label(I18n.t("Applicants for %s:") % I18n.t(str(Staff.role_def(st["applicants"][0]["role"])["name"])), 8, Art.C_WHITE, true))
		for a in st["applicants"]:
			var ar := UIK.hbox(6)
			content.add_child(ar)
			var apv := PortraitView.new()
			apv.custom_minimum_size = Vector2(24, 24)
			apv.size = Vector2(24, 24)
			apv.setup_character(a["appearance"], a.get("outfit", "startup_casual"))
			ar.add_child(apv)
			var al := UIK.vbox(0)
			al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ar.add_child(al)
			var an := UIK.label(str(a["name"]), 8, Art.C_WHITE, true)
			an.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			al.add_child(an)
			al.add_child(UIK.label(I18n.t("Skill %d/5 · asks %s/week · %s") % [int(a["skill"]), Fmt.money0(float(a["salary_week"])), I18n.t(_trait_text(str(a.get("trait", ""))))], 7, Art.C_MUTED))
			var aid: String = a["id"]
			var hb := UIK.button("Hire", func():
				var r := Staff.hire(aid)
				if not r["ok"]:
					UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
				else:
					UIRoot.toast(I18n.t("%s joins tomorrow at 9:00.") % r["person"]["name"], "good", "people")
				rebuild(), "primary")
			hb.name = "Hire_" + aid
			ar.add_child(hb)
	elif not st["posting"].is_empty():
		content.add_child(UIK.label(I18n.t("Job ad for %s is live. Applicants usually reply within a day.") % I18n.t(str(Staff.role_def(st["posting"]["role"])["name"])), 8, Art.C_SKY))
	else:
		content.add_child(UIK.label(I18n.t("Post a job ad (%s). Applicants arrive within a day.") % Fmt.money0(float(Staff.cfg().get("job_ad_fee", 40))), 7, Art.C_MUTED))
		var roles: Dictionary = Staff.cfg().get("roles", {})
		for rid in roles:
			var rr := UIK.hbox(6)
			content.add_child(rr)
			var rd: Dictionary = roles[rid]
			var rv := UIK.vbox(0)
			rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rr.add_child(rv)
			var sal: Array = rd["salary_week"]
			rv.add_child(UIK.label(I18n.t(str(rd["name"])) + "  ·  " + I18n.t("%s–%s/week") % [Fmt.money0(float(sal[0])), Fmt.money0(float(sal[1]))], 8, Art.C_WHITE, true))
			rv.add_child(UIK.wrap(I18n.t(str(rd["desc"])), 7, Art.C_MUTED, 360))
			var rwhy := Staff.hire_block(rid)
			var pb := UIK.button("Post job", func():
				var r := Staff.post_job(rid)
				if not r["ok"]:
					UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
				rebuild(), "primary" if rwhy == "" else "")
			pb.name = "Post_" + str(rid)
			pb.disabled = rwhy != ""
			pb.tooltip_text = I18n.t(rwhy)
			rr.add_child(pb)
	_section("Contacts")
	for nid in DataDB.npcs:
		var n := DataDB.npc(nid)
		if n.get("phone_only", false):
			continue
		var met: bool = GameState.data["npcs"].has(nid) or GameState.flag("met_" + nid)
		if not met:
			continue
		content.add_child(UIK.kv(n["name"], n.get("role", ""), Art.C_WHITE, 8))
	if not GameState.data["npcs"].has("maya"):
		content.add_child(UIK.kv("Maya", "friend (phone)", Art.C_WHITE, 8))


func _trait_text(tid: String) -> String:
	for t in Staff.cfg().get("traits", []):
		if t["id"] == tid:
			return str(t["desc"])
	return ""


# ============================================================== CONTRACTS
func _tab_contracts() -> void:
	var list := Contracts.open_list()
	if list.is_empty():
		content.add_child(UIK.wrap("No contracts yet. B2B customers want invoices from a registered company — and they usually pay later (Net 30).", 8, Art.C_MUTED, 480))
		return
	if sel_contract == "" or not GameState.data["contracts"].has(sel_contract):
		sel_contract = list[0]["id"]
	var h := UIK.hbox(4)
	for c in list:
		h.add_child(UIK.button("%s · %s" % [c["id"], status_text(str(c["status"]))], func(): sel_contract = c["id"]; counter_price = 0.0; rebuild(), "tab_active" if sel_contract == c["id"] else "tab"))
	content.add_child(h)
	var k: Dictionary = GameState.data["contracts"][sel_contract]
	var cols := UIK.hbox(10)
	content.add_child(cols)
	var v := UIK.vbox(1)
	v.custom_minimum_size = Vector2(250, 0)
	cols.add_child(v)
	var seller_name := GameState.entity_name(k["seller"]) if k["seller"] != "player" else GameState.business_display_name()
	for row in [["Buyer", GameState.entity_name(k["buyer"])], ["Seller", seller_name], ["Product", I18n.t(DataDB.product(k["product"])["name"])],
			["Quantity", str(int(k["qty"]))], ["Unit price", Fmt.money(k["unit_price"])], ["Total", Fmt.money(k["total"])],
			["Delivery", (I18n.t("due ") + Clock.fmt_short(int(k["due"]))) if k.has("due") else I18n.t("%d days after signing") % int(k["delivery_days"])],
			["Payment terms", I18n.t("Net %d%s") % [int(k["payment_terms_days"]), (I18n.t(" · %d%% upfront") % int(float(k["upfront_rate"]) * 100)) if float(k["upfront_rate"]) > 0 else ""]],
			["Late penalty", Fmt.pct(float(k["penalty_rate"]))], ["Quality", str(k["quality_req"])], ["Currency", "AUD (Aurelia dollar)"], ["Settlement", "Bank transfer"]]:
		v.add_child(UIK.kv(row[0], row[1], Art.C_WHITE, 7))
	var right := UIK.vbox(2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIK.label("NEGOTIATION", 7, Art.C_DIM, true))
	for hh in k["history"]:
		right.add_child(UIK.wrap("%s: %s" % [GameState.entity_name(hh["by"]) if hh["by"] != "player" else GameState.business_display_name(), hh["text"]], 7, Art.C_WHITE, 220))
	var cost := Ecommerce.avg_cost(Ecommerce.default_stock_location(), k["product"])
	if cost <= 0:
		var o := Ecommerce.offer("tradelink_wholesale", k["product"])
		cost = float(o.get("unit_cost", 0))
	right.add_child(UIK.label(I18n.t("Your unit cost ≈ %s → gross margin %s") % [Fmt.money(cost), Fmt.money((float(k["unit_price"]) - cost) * int(k["qty"]))], 7, Art.C_SKY))
	if k["status"] == "offered":
		if not Contracts.can_trade():
			right.add_child(UIK.label("Needs a registered company to sign.", 8, Art.C_RED))
			return
		if counter_price <= 0.0:
			counter_price = float(k["unit_price"]) + 1.0
			counter_terms = int(k["payment_terms_days"])
			counter_up = float(k["upfront_rate"])
		var ab := UIK.hbox(4)
		var acc := UIK.button("Accept", func():
			var r := Contracts.accept(k["id"])
			if not r["ok"]:
				UIRoot.toast(r["error"], "bad", "warning")
			rebuild(), "primary")
		acc.name = "AcceptContract"
		ab.add_child(acc)
		ab.add_child(UIK.button("Decline", func(): Contracts.reject(k["id"]); rebuild(), "danger"))
		right.add_child(ab)
		right.add_child(UIK.label("COUNTER-OFFER", 7, Art.C_DIM, true))
		var c1 := UIK.hbox(3)
		c1.add_child(UIK.button("−", func(): counter_price = maxf(1.0, counter_price - 0.5); rebuild()))
		c1.add_child(UIK.label(Fmt.money(counter_price) + "/u", 8, Art.C_WHITE, true))
		c1.add_child(UIK.button("+", func(): counter_price += 0.5; rebuild()))
		right.add_child(c1)
		var c2 := UIK.hbox(3)
		for t in [15, 30, 45]:
			c2.add_child(UIK.button(I18n.t("Net %d") % t, func(): counter_terms = t; rebuild(), "tab_active" if counter_terms == t else "tab"))
		right.add_child(c2)
		var c3 := UIK.hbox(3)
		for u in [0.0, 0.3, 0.5]:
			c3.add_child(UIK.button(I18n.t("%d%% upfront") % int(u * 100), func(): counter_up = u; rebuild(), "tab_active" if is_equal_approx(counter_up, u) else "tab"))
		right.add_child(c3)
		right.add_child(UIK.button("Send counter-offer", func():
			var r := Contracts.counter(k["id"], counter_price, counter_terms, counter_up)
			if r.get("result", "") == "agreed":
				UIRoot.toast("They agreed to your terms. Accept to sign.", "good", "contracts")
			elif r.get("result", "") == "withdrawn":
				UIRoot.toast("They walked away.", "bad", "contracts")
			counter_price = 0.0
			rebuild()))
	elif k["status"] == "active":
		var have := Contracts.stock_for(k)
		right.add_child(UIK.label(I18n.t("In stock (all locations): %d / %d needed") % [have, int(k["qty"])], 8, Art.C_GREEN if have >= int(k["qty"]) else Art.C_RED, true))
		var coming := Ecommerce.incoming_units_of(k["product"])
		if coming > 0 and have < int(k["qty"]):
			right.add_child(UIK.label(I18n.t("On the way from suppliers: %d") % coming, 7, Art.C_SKY, true))
		right.add_child(UIK.label(I18n.t("Due %s") % Clock.fmt_datetime(int(k["due"])), 7, Art.C_GOLD if Clock.now() < int(k["due"]) else Art.C_RED))
		var db := UIK.button(I18n.t("Pack & deliver %d units (B2B freight $40)") % int(k["qty"]), func():
			var r := Contracts.deliver(k["id"])
			if not r["ok"]:
				UIRoot.toast(r["error"], "bad", "warning")
			else:
				Clock.advance(90)
				UIRoot.toast(I18n.t("Delivered. Invoice %s due in %d days.") % [Fmt.money(r["receivable"]), int(k["payment_terms_days"])], "good", "contracts")
			rebuild(), "primary")
		db.name = "DeliverContract"
		db.disabled = have < int(k["qty"])
		right.add_child(db)
		var plan := Contracts.restock_plan(k)
		if not plan.is_empty():
			if plan.has("error"):
				right.add_child(UIK.wrap(I18n.t(str(plan["error"])), 7, Art.C_RED, 220))
			else:
				var fb := UIK.button(I18n.t("Order %d more from %s (%s)") % [int(plan["qty"]), I18n.t(str(DataDB.supplier(plan["supplier"]).get("name", ""))), Fmt.money0(float(plan["cost"]))], func():
					_fill(k, false), "primary")
				fb.name = "FillContract"
				right.add_child(fb)
				if Ecommerce.can_use_net_terms(plan["supplier"]):
					var ft := UIK.button("…or on supplier credit terms", func(): _fill(k, true))
					ft.name = "FillContractTerms"
					right.add_child(ft)
	elif k["status"] == "delivered":
		right.add_child(UIK.label(I18n.t("Invoice %s · due %s") % [Fmt.money(k["receivable"]), Clock.fmt_short(int(k["pay_due"]))], 8, Art.C_GOLD, true))
		right.add_child(UIK.wrap("Revenue is booked. The cash isn't here yet.", 7, Art.C_SKY, 220))
		if int(k["payment_terms_days"]) >= 30:
			var ep := UIK.button(I18n.t("Ask for early payment (−3%%: %s now)") % Fmt.money0(float(k["receivable"]) * 0.97), func():
				var r := Contracts.early_payment(k["id"])
				if r["ok"]:
					UIRoot.toast(I18n.t("%s paid early: %s in the bank.") % [GameState.entity_name(k["buyer"]), Fmt.money(r["cash"])], "good", "cash")
				rebuild())
			ep.name = "EarlyPayment"
			right.add_child(ep)


func _fill(k: Dictionary, terms: bool) -> void:
	var plan := Contracts.restock_plan(k)
	if plan.is_empty() or plan.has("error"):
		return
	var r := Ecommerce.buy(plan["supplier"], k["product"], int(plan["qty"]), plan["location"], terms)
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "bad", "warning")
	else:
		Clock.advance(10)
		UIRoot.toast(I18n.t("Ordered %d × %s to %s. Arrives %s.") % [int(plan["qty"]), I18n.t(DataDB.product(k["product"])["name"]), Ecommerce.location_name(plan["location"]), Clock.fmt_short(int(r["eta"]))], "good", "parcel")
	rebuild()


# ============================================================== FREELANCE
func _tab_freelance() -> void:
	if not Careers.freelance_active():
		_section("Freelance consulting")
		content.add_child(UIK.wrap("Sell your time: clients post small projects every morning. Accept a gig, work it here in 2-hour sessions, deliver before the deadline and invoice. Payment follows the client's terms. On-time work earns stars; stars raise your rate.", 8, Art.C_WHITE, 480))
		var go := UIK.button("Start freelancing", func():
			Careers.start_freelance()
			rebuild(), "primary")
		go.name = "StartFreelance"
		content.add_child(go)
		return
	Careers.refresh_offers()
	var f := Careers.F()
	var head := UIK.hbox(8)
	content.add_child(head)
	var full := roundi(Careers.rep())
	var stars := "★".repeat(full) + "☆".repeat(5 - full)
	head.add_child(UIK.label(stars, 10, Art.C_GOLD, true))
	head.add_child(UIK.label(I18n.t("Reputation %.1f · rate about %s/h · %d delivered · %d late") % [Careers.rep(), Fmt.money0(Careers.hourly_rate()), int(f["done"]), int(f["late"])], 7, Art.C_MUTED, true))
	_section("In progress")
	var act := Careers.active_gigs()
	if act.is_empty():
		content.add_child(UIK.label("No gigs in progress. Pick one below.", 7, Art.C_DIM))
	for g in act:
		var p := UIK.panel("ui/card", 4)
		content.add_child(p)
		var v := UIK.vbox(1)
		p.add_child(v)
		var r1 := UIK.hbox(4)
		v.add_child(r1)
		var t := UIK.label(Careers.gig_title(g), 8, Art.C_WHITE, true)
		t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		r1.add_child(t)
		r1.add_child(UIK.expand())
		r1.add_child(UIK.chip(status_text(g["status"]), Art.C_RED if g["status"] == "late" else Art.C_SKY))
		var bar := ProgressBar.new()
		bar.max_value = float(g["hours"])
		bar.value = float(g["done"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(300, 5)
		v.add_child(bar)
		var r2 := UIK.hbox(6)
		v.add_child(r2)
		r2.add_child(UIK.label(I18n.t("%d / %d h · due %s · %s · pays %s") % [int(g["done"]), int(g["hours"]), Clock.fmt_datetime(int(g["due"])),
			Fmt.money0(float(g["fee"])), I18n.t("on delivery") if int(g["terms"]) == 0 else I18n.t("%d days after delivery") % int(g["terms"])], 7, Art.C_MUTED))
		r2.add_child(UIK.expand())
		var gid: String = g["id"]
		var wb := UIK.button(I18n.t("Work 2 h"), func(): _work_gig(gid), "primary")
		wb.name = "Work_" + gid
		r2.add_child(wb)
	_section("Today's offers")
	if f["offers"].is_empty():
		content.add_child(UIK.label("No new offers. More arrive every morning at 8:00.", 7, Art.C_DIM))
	for o in f["offers"]:
		var row := UIK.hbox(6)
		content.add_child(row)
		var ol := UIK.wrap(Careers.gig_title(o), 8, Art.C_WHITE, 250)
		ol.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.add_child(ol)
		row.add_child(UIK.label(I18n.t("%d h · %d days · %s") % [int(o["hours"]), int(o["days"]), I18n.t("paid on delivery") if int(o["terms"]) == 0 else I18n.t("net %d") % int(o["terms"])], 7, Art.C_MUTED))
		row.add_child(UIK.expand())
		row.add_child(UIK.label(Fmt.money0(float(o["fee"])), 9, Art.C_GREEN, true))
		var oid: String = o["id"]
		var ab := UIK.button("Accept", func():
			var r := Careers.accept(oid)
			if not r["ok"]:
				UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
			rebuild())
		ab.name = "Accept_" + oid
		row.add_child(ab)
	var owed := 0.0
	for g2 in f["gigs"].values():
		if g2["status"] == "invoiced":
			owed += float(g2["invoiced"])
	if owed > 0.0:
		content.add_child(UIK.sep())
		content.add_child(UIK.kv("Invoiced, not yet paid", Fmt.money(owed), Art.C_GOLD))


## You write the code yourself: a typing session (TypingGame) decides how much of the 2 hours got done.
func _code_session() -> void:
	var h := float(Saas.cfg().get("founder_session_hours", 2))
	var heading := I18n.t("Coding session — %s") % str(Saas.idea().get("name", ""))
	MiniGames.play(TypingGame.new("saas", str(Saas.S().get("idea", "")), h, heading), func(res: Dictionary):
		if res.get("aborted", false):
			return
		Saas.add_dev(float(res.get("hours", h)), true, h)
		UIRoot.toast(I18n.t("Coding session done: %.1f hours of work.") % float(res.get("hours", h)), "good", "laptop")
		if is_inside_tree():
			rebuild())


func _work_gig(gid: String) -> void:
	var g: Dictionary = Careers.F()["gigs"].get(gid, {})
	var h := float(Careers.session_hours())
	MiniGames.play(TypingGame.new("freelance", "", h, Careers.gig_title(g) if not g.is_empty() else "Client work"), func(res: Dictionary):
		if not res.get("aborted", false):
			_apply_gig(gid, float(res.get("hours", h))))


func _apply_gig(gid: String, progress: float) -> void:
	var r := Careers.work_on(gid, progress)
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
	elif r["delivered"]:
		UIRoot.toast(I18n.t("Delivered and invoiced: %s.") % Fmt.money(r["fee"]) + (I18n.t(" (late: -20%)") if r["late"] else ""), "good" if not r["late"] else "warn", "check")
	else:
		UIRoot.toast(I18n.t("Two focused hours: %.1f hours of the work done. %s") % [progress, Clock.fmt_time()], "info", "clock")
	if is_inside_tree():
		rebuild()


# ============================================================== SAAS
## The product's app icon (logos/saas_<idea>.png, 32x32) once the art exists.
func _saas_logo(parent: Control, idea_id: String) -> void:
	var t := Art.opt_tex("logos/saas_" + idea_id)
	if t == null:
		return
	var r := TextureRect.new()
	r.name = "SaasLogo"
	r.texture = t
	r.custom_minimum_size = Vector2(24, 24)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(r)


func _tab_saas() -> void:
	if not Saas.active():
		_section("Build a software product")
		content.add_child(UIK.wrap("Build it once, sell it every month. Development hours now (you at a laptop, plus developers you hire), subscribers later. Price, churn and servers decide whether it works.", 8, Art.C_WHITE, 480))
		for i in Saas.ideas():
			var p := UIK.panel("ui/card", 4)
			content.add_child(p)
			var h := UIK.hbox(6)
			p.add_child(h)
			_saas_logo(h, str(i["id"]))
			var v := UIK.vbox(0)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(UIK.label("%s · %s" % [str(i["name"]), I18n.t(str(i["pitch"]))], 8, Art.C_WHITE, true))
			v.add_child(UIK.label(I18n.t("MVP %d dev hours · typical price %s/month · market ~%d customers · churn ~%d%%/month") % [int(i["dev_hours"]), Fmt.money0(float(i["ref_price"])), int(i["market"]), int(float(i["base_churn"]) * 100)], 7, Art.C_MUTED))
			var iid: String = i["id"]
			var b := UIK.button("Build this", func():
				Saas.start(iid)
				rebuild(), "primary")
			b.name = "Saas_" + iid
			h.add_child(b)
		return
	var s := Saas.S()
	var i := Saas.idea()
	if not Saas.launched():
		_section(I18n.t("Building %s") % str(i["name"]))
		var bar := ProgressBar.new()
		bar.max_value = Saas.dev_needed()
		bar.value = float(s["dev_done"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(460, 8)
		content.add_child(bar)
		content.add_child(UIK.label(I18n.t("MVP: %d / %d dev hours · your team adds %.1f h per workday") % [int(s["dev_done"]), int(Saas.dev_needed()), Staff.dev_hours_per_day()], 8, Art.C_WHITE, true))
		var row := UIK.hbox(6)
		content.add_child(row)
		var cb := UIK.button(I18n.t("Code for %d hours") % int(Saas.cfg().get("founder_session_hours", 2)), _code_session, "primary")
		cb.name = "SaasCode"
		row.add_child(cb)
		var lb := UIK.button(I18n.t("Launch at %s/month") % Fmt.money0(float(s["price"])), func():
			var r := Saas.launch()
			if not r["ok"]:
				UIRoot.toast(I18n.t(str(r["error"])), "warn", "laptop")
			else:
				UIRoot.show_chapter_card(I18n.t("%s IS LIVE") % str(i["name"]).to_upper(), I18n.t("Now the real work starts: keep them subscribed."))
			rebuild(), "primary" if float(s["dev_done"]) >= Saas.dev_needed() else "")
		lb.name = "SaasLaunch"
		lb.disabled = float(s["dev_done"]) < Saas.dev_needed()
		row.add_child(lb)
		content.add_child(UIK.label("Hire a Software Developer (People tab) to build while you do other things.", 7, Art.C_MUTED))
		return
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	var top := UIK.hbox(6)
	content.add_child(top)
	_saas_logo(top, str(s["idea"]))
	top.add_child(g)
	_kpi(g, I18n.t("SUBSCRIBERS"), str(int(s["subs"])), Art.C_WHITE, I18n.t("+%d / −%d last 7 days") % [Saas.last_days(7, "new"), Saas.last_days(7, "lost")])
	_kpi(g, "MRR", Fmt.money0(Saas.mrr()), Art.C_GREEN, I18n.t("%s/month each") % Fmt.money0(float(s["price"])))
	_kpi(g, I18n.t("CHURN"), Fmt.pct(Saas.monthly_churn(), 1), Art.C_GOLD, I18n.t("per month"))
	var srv := float(Saas.cfg().get("server_base_month", 40)) + float(Saas.cfg().get("server_per_user_month", 0.35)) * int(s["subs"])
	_kpi(g, I18n.t("SERVERS"), Fmt.money0(srv), Art.C_RED, I18n.t("per month"))
	content.add_child(UIK.label(I18n.t("Expected signups: %.1f/day · features shipped: %d · next feature %d / %d h") % [Saas.signup_rate(), int(s["features"]),
		int(s["feature_progress"]), int(Saas.cfg().get("feature_hours", 80))], 7, Art.C_MUTED, true))
	var pr := UIK.hbox(4)
	content.add_child(pr)
	pr.add_child(UIK.label("Price", 8, Art.C_MUTED))
	var pm := UIK.button("−$5", func(): Saas.set_price(float(s["price"]) - 5.0); rebuild())
	pm.name = "SaasPriceDown"
	pr.add_child(pm)
	pr.add_child(UIK.label(Fmt.money0(float(s["price"])), 9, Art.C_WHITE, true))
	var pp := UIK.button("+$5", func(): Saas.set_price(float(s["price"]) + 5.0); rebuild())
	pp.name = "SaasPriceUp"
	pr.add_child(pp)
	pr.add_child(UIK.expand())
	pr.add_child(UIK.label("Ads/day", 8, Art.C_MUTED))
	for a in [0.0, 10.0, 25.0, 50.0]:
		var ab := UIK.button(Fmt.money0(a), func(): Saas.set_ads(a); rebuild(), "tab_active" if is_equal_approx(float(s["ads_per_day"]), a) else "tab")
		ab.name = "SaasAds_%d" % int(a)
		pr.add_child(ab)
	var cb2 := UIK.button(I18n.t("Code a feature for %d hours") % int(Saas.cfg().get("founder_session_hours", 2)), _code_session)
	cb2.name = "SaasCode"
	content.add_child(cb2)
	content.add_child(UIK.wrap("Cheaper brings more signups; features and support keep people subscribed. Servers cost more as you grow.", 7, Art.C_SKY, 480))

