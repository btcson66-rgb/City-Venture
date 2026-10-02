class_name CompanyOS
extends Modal
## Company OS (Handoff §52–53, kickoff §15). The former "dashboard", demoted to a tool you use at a
## terminal: apartment laptop, co-work hot desk, cafe table, or your office desk.

const TABS := [["overview", "Overview", "company"], ["finance", "Finance", "finance"],
	["operations", "Operations", "parcel"], ["inventory", "Inventory", "inventory"], ["people", "People", "people"],
	["contracts", "Contracts", "contracts"], ["segments", "Segments", "finance"], ["group", "Group", "company"]]

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
var _primary_chosen := false


## Order / contract status chips (ids stay English in data; shown translated).
const STATUS_TEXT := {
	"placed": "PLACED", "packed": "PACKED", "awaiting_pickup": "AWAITING PICKUP", "carried": "CARRIED",
	"shipped": "SHIPPED", "in_transit": "IN TRANSIT", "delivered": "DELIVERED", "return_requested": "RETURN REQUESTED",
	"refunded": "REFUNDED", "replaced": "REPLACED", "partial_refund": "PARTIAL REFUND", "refused": "REFUSED",
	"disputed": "DISPUTED", "offered": "OFFERED", "countered": "COUNTERED", "active": "ACTIVE", "paid": "PAID",
	"rejected": "REJECTED", "expired": "EXPIRED", "withdrawn": "WITHDRAWN", "overdue": "OVERDUE", "declined": "DECLINED",
	"late": "LATE", "called": "CALLED", "defaulted": "DEFAULTED", "closed": "CLOSED", "written_off": "WRITTEN OFF",
	"invoiced": "INVOICED", "cancelled": "CANCELLED",
	"terminated": "TERMINATED", "sold_to_collector": "SOLD TO COLLECTOR",
}


static func status_text(s: String) -> String:
	return I18n.t(STATUS_TEXT.get(s, s.replace("_", " ").to_upper()))


func _init(term: String) -> void:
	terminal = term
	panel_size = Vector2(624, 344)
	title_text = "COMPANY OS"
	icon_name = "laptop"
	help_key = "os_overview"
	if term == "cafe_till":
		tab = "cafe"
		help_key = "os_cafe"


var _clock_label: Label


func _ready() -> void:
	super._ready()
	# time keeps running while you work at the computer: keep the header clock live
	Clock.time_changed.connect(_tick_clock)
	GameState.set_flag("company_os_opened")
	if GameState.company_id() != "":
		GameState.set_flag("company_os_opened_as_company")
	if terminal == "office":
		GameState.set_flag("used_office_desk")


func _tick_clock() -> void:
	if is_instance_valid(_clock_label):
		_clock_label.text = Clock.fmt_datetime()


func build() -> void:
	_primary_chosen = false
	var where: String = {"home_laptop": "Laptop · Riverside Tower 7C", "cowork": "Hot desk · Nexus Co-work", "office": "Desk · Suite 2B",
		"cafe": "Laptop · café table", "cafe_till": "Till · your café", "pier7": "Desk · Pier 7 yard office"}.get(terminal, terminal)
	var top := UIK.hbox(6)
	body.add_child(top)
	top.add_child(UIK.title(GameState.business_display_name(), 11, Art.C_GOLD))
	top.add_child(UIK.label(where, 7, Art.C_DIM))
	top.add_child(UIK.expand())
	_clock_label = UIK.label(Clock.fmt_datetime(), 7, Art.C_MUTED, true)
	top.add_child(_clock_label)
	var row := UIK.hbox(6)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var nav := UIK.vbox(2)
	nav.custom_minimum_size = Vector2(96, 0)
	# Industry launchers can outgrow the window; keep the content and every navigation action reachable.
	var nav_scroll := UIK.scroll(nav, Vector2(108, 272))
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(nav_scroll)
	var shown: Array = TABS.duplicate(true)
	for descriptor in Industries.tabs():
		if descriptor.has("nav_index"):
			shown.insert(mini(int(descriptor["nav_index"]), shown.size()), [descriptor["id"], descriptor["label"], descriptor["icon"]])
		else:
			shown.append([descriptor["id"], descriptor["label"], descriptor["icon"]])
	# the café tab appears once you lease the corner unit, the logistics tab once you own a van; with all eleven the
	# buttons get a little tighter so the column still fits the window
	var compact := shown.size() > 10
	for t in shown:
		var b := UIK.button(t[1], _set_tab.bind(t[0]), "tab_active" if tab == t[0] else "tab")
		b.icon = Art.icon(t[2])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Tab_" + t[0]
		if compact:
			var st := UIK.tex_box("ui/tab_active" if tab == t[0] else "ui/tab", 4, 2)
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("hover", st)
			b.add_theme_constant_override("icon_max_width", 12)
		if t[0] == "contracts" and _open_offers() > 0:
			b.text = I18n.t(b.text) + " ●"
		nav.add_child(b)
	for descriptor in Industries.launchers():
		var start := UIK.button(descriptor["start_label"], _set_tab.bind(descriptor["id"]))
		# Preserve stable bot entry names while these are setup actions, not running-business tabs.
		start.name = "Tab_" + str(descriptor["id"])
		nav.add_child(start)
	nav.add_child(UIK.sep())
	content = UIK.vbox(3)
	var sc := UIK.scroll(content, Vector2(500, 272))
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sc)
	if not Industries.render_tab(tab, self):
		call("_tab_" + tab)


func _set_tab(t: String) -> void:
	tab = t
	reset_scroll = true   # a new tab starts at the top
	help_key = "os_" + t   # the ? button explains the tab you're on
	rebuild()
	Help.show_once.call_deferred(help_key)


func _open_offers() -> int:
	return GameState.data["contracts"].values().filter(func(c): return c["status"] == "offered").size()


func _section(t: String) -> void:
	content.add_child(UIK.label(I18n.t(t).to_upper(), 7, Art.C_DIM, true))


func _next_style(ready: bool) -> String:
	if ready and not _primary_chosen:
		_primary_chosen = true
		return "primary"
	return ""


## Mirror the existing buy preconditions without posting money or reserving stock.
func _buy_possible(supplier: String, product: String, qty: int, loc: String) -> bool:
	var offer := Ecommerce.offer(supplier, product)
	if offer.is_empty() or qty < int(offer["moq"]) or not World.supplier_available(supplier): return false
	if Ecommerce.space_block(loc, qty) != "" or Compliance.import_block(supplier) != "": return false
	var cash := Ledger.cash(GameState.business_entity())
	var total := snappedf(Ecommerce.unit_cost(supplier, product) * qty, 0.01)
	if not Ecommerce.needs_settlement(supplier): return cash >= total
	var kyc_fee := float(Compliance.kyc(total).get("fee", 0.0))
	for method in DataDB.economy.get("settlement_methods", {}).get("methods", []):
		var id := str(method["id"])
		if Ecommerce.settlement_block(id) == "" and cash >= total + Ecommerce.settlement_fee(id, total) + kyc_fee:
			return true
	return false


## A section header with a "!" badge explaining the idea behind it.
func _section_tip(t: String, tip_id: String) -> void:
	content.add_child(UIK.label_tip(I18n.t(t).to_upper(), tip_id, 7, Art.C_DIM, true))


func _kpi(grid: GridContainer, label: String, value: String, col := Art.C_WHITE, sub := "", tip_id := "") -> void:
	var p := UIK.panel("ui/card", 4)
	p.custom_minimum_size = Vector2(118, 36)
	var v := UIK.vbox(0)
	p.add_child(v)
	v.add_child(UIK.label_tip(label, tip_id, 6, Art.C_MUTED, true) if tip_id != "" else UIK.label(label, 6, Art.C_MUTED, true))
	v.add_child(UIK.title(value, 11, col))
	if sub != "":
		v.add_child(UIK.label(sub, 6, Art.C_DIM))
	grid.add_child(p)


## Compact glossary links stay beside their titles, even in empty/locked tabs.
func _concepts(ids: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	content.add_child(grid)
	for id in ids:
		grid.add_child(UIK.label_tip(str(InfoTip.entry(id)["title"]), id, 7, Art.C_SKY))
	content.add_child(UIK.sep())


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
	_kpi(g, "MONTHLY PROFIT", Fmt.money0(cur["business_profit"]), UIK.money_color(cur["business_profit"]), "business only", "cash_vs_profit")
	_kpi(g, "CASH", Fmt.money0(Ledger.cash(be)), UIK.money_color(Ledger.cash(be)), "in the bank", "cash_vs_profit")
	var ar := Ledger.balance(be, "marketplace_balance") + Ledger.balance(be, "accounts_receivable")
	_kpi(g, "RECEIVABLE", Fmt.money0(ar), Art.C_GOLD, "ShopLane + invoices", "accounts_receivable")
	_kpi(g, "PAYABLE", Fmt.money0(-Ledger.balance(be, "accounts_payable")), Art.C_GOLD, "to suppliers")
	var staff := Staff.count()
	_kpi(g, "PEOPLE", I18n.t("%d people") % (1 + staff), Art.C_WHITE, (I18n.t("you + %d staff") % staff) if staff > 0 else I18n.t("just you"))
	_kpi(g, "COMPANY VALUE", Fmt.money0(Company.company_value()), Art.C_SKY, "book value")
	_kpi(g, "ORDERS DELIVERED", I18n.t("%d orders") % int(GameState.stat("orders_delivered")), Art.C_WHITE, "all time")
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
	content.add_child(UIK.label(I18n.t("Registration: ") + (("%s · %s" % [GameState.entity_name(GameState.company_id()), GameState.data["entities"][GameState.company_id()]["registration_no"]]) if GameState.company_id() != "" else I18n.t("not registered (personal seller)")), 7, Art.C_MUTED))


# ============================================================== FINANCE
func _tab_finance() -> void:
	_concepts(["gross_margin", "opex", "credit_history"])
	var be := GameState.business_entity()
	var cur := MonthClose.current(be)
	var cols := UIK.hbox(10)
	content.add_child(cols)
	var pl := UIK.vbox(1)
	pl.custom_minimum_size = Vector2(240, 0)
	cols.add_child(pl)
	pl.add_child(UIK.label(I18n.t("THIS MONTH (P&L) · ") + GameState.entity_name(be).to_upper(), 7, Art.C_DIM, true))
	pl.add_child(UIK.kv("Revenue", Fmt.money0(cur["revenue"])))
	pl.add_child(UIK.kv("Refunds", Fmt.money0(-cur["refunds"]), Art.C_RED))
	pl.add_child(UIK.kv("Cost of goods sold", Fmt.money0(-cur["cogs"]), Art.C_RED))
	pl.add_child(UIK.kv("Gross profit", Fmt.money0(cur["gross_profit"]), UIK.money_color(cur["gross_profit"]), 8, true))
	for k in cur["opex"]:
		var orow := UIK.kv("  " + Ledger.category_name(str(k)), Fmt.money0(-float(cur["opex"][k])), Art.C_RED, 7)
		if str(k) == "compliance":
			orow.add_child(UIK.tip("compliance_cost"))
		pl.add_child(orow)
	pl.add_child(UIK.kv("Business profit", Fmt.money0(cur["business_profit"]), UIK.money_color(cur["business_profit"]), 9, true))
	if be == "player":
		if float(cur.get("wages", 0.0)) > 0.0:
			pl.add_child(UIK.kv("Wages from your job", Fmt.money0(cur["wages"]), Art.C_GREEN, 7))
		pl.add_child(UIK.kv("Home rent + living", Fmt.money0(-cur["personal_total"]), Art.C_RED, 7))
	var cp := UIK.vbox(1)
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(cp)
	cp.add_child(UIK.label("CASH POSITION", 7, Art.C_DIM, true))
	cp.add_child(UIK.kv("Cash in bank", Fmt.money0(Ledger.cash(be)), UIK.money_color(Ledger.cash(be)), 9, true))
	cp.add_child(UIK.kv("ShopLane balance (paid Mondays)", Fmt.money0(Ledger.balance(be, "marketplace_balance")), Art.C_GOLD))
	cp.add_child(UIK.kv("  of which on hold (<2 days)", Fmt.money0(Ecommerce.held_amount(be)), Art.C_DIM, 7))
	cp.add_child(UIK.kv("Invoices receivable", Fmt.money0(Ledger.balance(be, "accounts_receivable")), Art.C_GOLD))
	cp.add_child(UIK.kv("Supplier bills payable", Fmt.money0(-Ledger.balance(be, "accounts_payable")), Art.C_GOLD))
	cp.add_child(UIK.kv("Stock (at cost)", Fmt.money0(Ledger.balance(be, "inventory")), Art.C_SKY))
	cp.add_child(UIK.kv("Stock on the way", Fmt.money0(Ledger.balance(be, "inventory_in_transit")), Art.C_SKY))
	if absf(Ledger.balance(be, "escrow_held")) > 0.005:
		var erow := UIK.kv("Held in escrow", Fmt.money0(Ledger.balance(be, "escrow_held")), Art.C_SKY)
		erow.add_child(UIK.tip("escrow"))
		cp.add_child(erow)
	if absf(Ledger.balance(be, "frozen_funds")) > 0.005:
		var frow := UIK.kv("Frozen on the bridge", Fmt.money0(Ledger.balance(be, "frozen_funds")), Art.C_RED)
		frow.add_child(UIK.tip("frozen_funds"))
		cp.add_child(frow)
	cp.add_child(UIK.kv("Parcels out for delivery", Fmt.money0(Ledger.balance(be, "goods_out")), Art.C_SKY))
	cp.add_child(UIK.kv("Deposits", Fmt.money0(Ledger.balance(be, "deposits")), Art.C_SKY))
	if Bank.debt(be) > 0.0:
		cp.add_child(UIK.kv("Bank loans", Fmt.money0(-Bank.debt(be)), Art.C_RED))
	if Staff.wages_owed() > 0.0 and be == Staff.entity():
		cp.add_child(UIK.kv("Wages owed to staff", Fmt.money0(-Staff.wages_owed()), Art.C_RED))
	cp.add_child(UIK.kv("Credit score", I18n.t("%d points · %s") % [Bank.credit(), I18n.t(Bank.credit_band())], Art.C_SKY, 7))
	var reps: Array = GameState.data["reports"]["month_closes"]
	if not reps.is_empty():
		cp.add_child(UIK.button(I18n.t("Open last month close (%s)") % MonthClose.label_of(reps[-1]), func(): UIRoot.open_modal(MonthCloseModal.new(reps[-1]))))
	_forecast(be)
	_section("Recent transactions")
	for e in Ledger.entries(be, 14):
		var row := UIK.hbox(4)
		row.add_child(UIK.label(Clock.fmt_short(int(e["t"])), 6, Art.C_DIM))
		var m := UIK.label(SavedText.display(str(e["memo"])).left(58), 7, Art.C_WHITE)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(m)
		var c := Ledger.entry_cash(e)
		row.add_child(UIK.label(Fmt.money0(c, true) if absf(c) > 0.001 else I18n.t("Non-cash"), 7, UIK.money_color(c) if absf(c) > 0.001 else Art.C_DIM, true))
		content.add_child(row)


## Week-by-week cash forecast: revenue isn't cash until it lands, and payroll comes every Friday.
func _forecast(be: String) -> void:
	GameState.set_flag("cash_forecast_viewed")
	if StoryEngine.St().get("chapter", "") == "ch6_cash_is_oxygen":
		GameState.set_flag("forecast_checked_ch6")
	var fc := Forecast.weekly(be)
	_section_tip("Cash forecast · next 9 weeks", "cash_forecast")
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
	_concepts(["marketplace_fee", "payout_schedule", "ads_cpc", "price_elasticity", "product_photo"])
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
			ic.texture = Art.tex(DataDB.product_icon(str(p.get("id", ""))))
		h1.add_child(ic)
		h1.add_child(UIK.label(p["name"], 9, Art.C_WHITE, true))
		h1.add_child(UIK.chip("LIVE" if l["active"] else ("PAUSED · CAP" if l.get("paused_reason", "") == "seller_cap" else "PAUSED"), Art.C_GREEN if l["active"] else Art.C_GOLD))
		h1.add_child(UIK.expand())
		h1.add_child(UIK.label(I18n.t("%s (%d reviews)") % [Fmt.stars(Ecommerce.rating(l)), int(l["rating_n"])], 8, Art.C_GOLD))
		v.add_child(h1)
		var h2 := UIK.hbox(4)
		h2.add_child(UIK.label_tip("Price", "price_elasticity", 7, Art.C_MUTED))
		var pdn := UIK.button("−", func(): Ecommerce.set_price(l["id"], float(l["price"]) - 1.0); rebuild())
		pdn.name = "PriceDown_" + l["product"]
		h2.add_child(pdn)
		h2.add_child(UIK.label(Fmt.money(l["price"]), 9, Art.C_WHITE, true))
		var pup := UIK.button("+", func(): Ecommerce.set_price(l["id"], float(l["price"]) + 1.0); rebuild())
		pup.name = "PriceUp_" + l["product"]
		h2.add_child(pup)
		h2.add_child(UIK.label_tip("Ads/day", "ads_cpc", 7, Art.C_MUTED))
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
			Fmt.money(float(p["ref_price"])), Ecommerce.lambda_day(l), int(l["views"]), int(l["orders"]), Ecommerce.available_anywhere(l["product"]), Fmt.money(margin)], 7, Art.C_MUTED))
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
			h.add_child(UIK.label(I18n.t("market ~%s") % Fmt.money(float(p2["ref_price"])), 7, Art.C_MUTED))
			h.add_child(UIK.expand())
			h.add_child(UIK.button("−", func(): new_price[pid] = maxf(float(p2["price_min"]), float(new_price[pid]) - 1.0); rebuild()))
			h.add_child(UIK.label(Fmt.money(new_price[pid]), 9, Art.C_WHITE, true))
			h.add_child(UIK.button("+", func(): new_price[pid] = minf(float(p2["price_max"]), float(new_price[pid]) + 1.0); rebuild()))
			v2.add_child(h)
			var h3 := UIK.hbox(4)
			var b1 := UIK.button("Shoot photos myself & list (1 h 20 min)", _list.bind(pid, "self"), _next_style(true))
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
	UIRoot.toast(I18n.t("Listed %s at %s. Took %s.") % [I18n.t(DataDB.product(pid)["name"]), Fmt.money0(new_price[pid]), Fmt.duration_min(mins)], "good", "orders")
	if is_inside_tree():
		rebuild()


# ============================================================== OPERATIONS
func _tab_operations() -> void:
	_concepts(["moq", "lead_time", "supplier_terms", "net_terms", "accounts_payable", "packaging_levy", "shipping_index", "settlement_wire", "letter_of_credit", "digital_dollars"])
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
		v.add_child(UIK.title(I18n.t("%d orders") % Ecommerce.orders_with([st[0]]).size(), 11))
		g.add_child(p)
	content.add_child(UIK.label("Packing happens at a packing table where the stock is. Ship by courier (fee, no walk) or carry to PostPoint.", 7, Art.C_DIM))
	# packaging: bubble wrap, or recycled paper (Year 4's Clean Packaging Act puts a levy on plastic)
	var ph := UIK.hbox(4)
	ph.add_child(UIK.label("Packaging:", 7, Art.C_MUTED, true))
	for pk in [["standard", "Bubble wrap"], ["recycled", "Recycled paper"]]:
		var pb := UIK.button(pk[1], func(): Ecommerce.set_packaging(pk[0]); rebuild(), "tab_active" if Ecommerce.packaging() == pk[0] else "tab")
		pb.name = "Packaging_" + pk[0]
		ph.add_child(pb)
	var levy := World.packaging_levy()
	var note := I18n.t("Recycled costs %s more per 100 parcels.") % Fmt.money0(float(DataDB.marketplace().get("recycled_packaging_extra", 0.25)) * 100.0)
	if levy > 0.0:
		note += "  " + I18n.t("Plastic pays a %s levy per 100 parcels; buyers like plastic-free.") % Fmt.money0(levy * 100.0)
	content.add_child(UIK.wrap(note, 7, Art.C_DIM, 480))
	content.add_child(ph)
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
		if not World.supplier_available(sid):
			continue
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
			var mult := Ecommerce.cost_multiplier(sid, pid) * World.cost_mult(sid)   # price mods and the era
			var row := UIK.hbox(4)
			var nl := UIK.label(I18n.t(DataDB.product(pid)["name"]), 8, Art.C_WHITE)
			nl.custom_minimum_size = Vector2(118, 0)
			row.add_child(nl)
			row.add_child(UIK.label(I18n.t("%s per unit") % Fmt.money(uc) + (" (+%d%%)" % int(round((mult - 1.0) * 100)) if mult > 1.001 else ""), 8, Art.C_RED if mult > 1.001 else Art.C_WHITE, true))
			var lead := int(ceil(float(o["lead_days"]) * World.lead_mult(sid)))
			v2.add_child(UIK.label(I18n.t("MOQ %d units · %d days · %s duds") % [int(o["moq"]), lead, Fmt.pct(float(o["defect_rate"]), 0) if float(o["defect_rate"]) >= 0.01 else "<1%"], 7, Art.C_RED if lead > int(o["lead_days"]) else Art.C_MUTED))
			row.add_child(UIK.expand())
			row.add_child(UIK.button("−", func(): buy_qty[key] = maxi(int(o["moq"]), int(buy_qty[key]) - int(o["moq"])); rebuild()))
			row.add_child(UIK.label(I18n.t("%d units") % int(buy_qty[key]), 8, Art.C_WHITE, true))
			row.add_child(UIK.button("+", func(): buy_qty[key] = int(buy_qty[key]) + int(o["moq"]); rebuild()))
			var ready := _buy_possible(sid, pid, int(buy_qty[key]), loc)
			var bb := UIK.button(I18n.t("Buy %s") % Fmt.money(uc * int(buy_qty[key])), _buy.bind(sid, pid, key, false), _next_style(ready))
			bb.disabled = not ready
			bb.name = "Buy_%s_%s" % [sid, pid]
			row.add_child(bb)
			if Ecommerce.can_use_net_terms(sid):
				var terms := UIK.button(I18n.t("Net %d days") % int(s["net_terms_for_companies"]["days"]), _buy.bind(sid, pid, key, true))
				terms.disabled = Ecommerce.space_block(loc, int(buy_qty[key])) != "" or Compliance.import_block(sid) != ""
				row.add_child(terms)
				row.add_child(UIK.tip("net_terms"))
			v2.add_child(row)
		content.add_child(card)
	_section("Purchase orders")
	var pos: Array = GameState.data["ecommerce"]["purchase_orders"].values()
	pos.sort_custom(func(a, b): return int(a["placed"]) > int(b["placed"]))
	# the latest few, plus any older order that can still be cancelled or returned or waits on a refund: a long game has
	# over a hundred orders, and this tab rebuilds on every +/−
	var listed := 0
	var older := 0
	for po in pos:
		if listed >= RECENT_POS and not _po_actionable(po):
			older += 1
			continue
		listed += 1
		var row2 := UIK.hbox(4)
		row2.add_child(UIK.label(po["id"], 7, Art.C_DIM))
		var t := UIK.label("%d × %s · %s" % [int(po["qty"]), I18n.t(DataDB.product(po["product"])["name"]), I18n.t(DataDB.supplier(po["supplier"])["name"])], 7, Art.C_WHITE)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(t)
		row2.add_child(UIK.label(Fmt.money0(po["total"]) + (" · Net" if po["terms"] == "net" else ""), 7, Art.C_WHITE))
		row2.add_child(UIK.tip("net_terms"))
		if po["status"] == "awaiting_payment" and Rails.is_frozen_po(po):
			row2.add_child(UIK.chip(I18n.t("FROZEN · BACK ") + Clock.fmt_short(Rails.frozen_until()).to_upper(), Art.C_RED))
			row2.add_child(UIK.tip("frozen_funds"))
			var rb := UIK.button("Reroute", func(): UIRoot.open_modal(SettlementModal.for_pending(str(po["id"]))))
			rb.name = "Reroute_" + str(po["id"])
			row2.add_child(rb)
		elif po["status"] == "awaiting_payment":
			row2.add_child(UIK.chip(I18n.t("PAYMENT PENDING · LANDS ") + Clock.fmt_short(int(po["settlement"]["clears"])).to_upper(), Art.C_RED))
			var sb := UIK.button("Speed up", func(): UIRoot.open_modal(SettlementModal.for_pending(str(po["id"]))))
			sb.name = "SpeedUp_" + str(po["id"])
			row2.add_child(sb)
		elif po["status"] == "in_transit" and str(po.get("escrow", "")) == "held":
			row2.add_child(UIK.chip(I18n.t("IN ESCROW · ARRIVES ") + Clock.fmt_short(int(po["eta"])).to_upper(), Art.C_SKY))
			row2.add_child(UIK.tip("escrow"))
		else:
			row2.add_child(UIK.chip(I18n.t("ARRIVES ") + Clock.fmt_short(int(po["eta"])).to_upper() if po["status"] == "in_transit" else ("CANCELLED" if po["status"] == "cancelled" else "DELIVERED"), Art.C_GOLD if po["status"] == "in_transit" else (Art.C_MUTED if po["status"] == "cancelled" else Art.C_GREEN)))
		content.add_child(row2)
		var cancelling: bool = po["status"] in ["in_transit", "awaiting_payment"]
		if cancelling or po["status"] == "delivered":
			var why := Ecommerce.cancel_block(str(po["id"])) if cancelling else Ecommerce.return_block(str(po["id"]))
			var actions := UIK.hbox(4)
			var action := UIK.button("Cancel purchase" if cancelling else "Return stock", _purchase_return.bind(str(po["id"]), cancelling))
			action.name = ("CancelPO_" if cancelling else "ReturnPO_") + str(po["id"])
			action.disabled = why != ""
			actions.add_child(action)
			actions.add_child(UIK.tip("purchase_cancel" if cancelling else "purchase_return"))
			if why != "":
				actions.add_child(UIK.wrap(why, 7, Art.C_MUTED, 365))
			content.add_child(actions)
		for r in po.get("returns", []):
			var sold: bool = r["status"] == "sold_to_collector" or (r["status"] == "in_transit" and GameState.data["entities"].get(r["entity"], {}).has("closed"))
			var refund_status := I18n.t("Refund sold in liquidation") if sold else (I18n.t("Refund received") if r["status"] == "refunded" else I18n.t("Refund due %s") % Clock.fmt_short(int(r["due"])))
			content.add_child(UIK.label(I18n.t("Returned %d units · %s · %s") % [int(r["qty"]), Fmt.money0(float(r["refund"])), refund_status], 7, Art.C_GREEN if r["status"] == "refunded" else Art.C_GOLD))
	if older > 0:
		content.add_child(UIK.label(I18n.t("%d older purchase orders are done: nothing left to cancel or return.") % older, 7, Art.C_DIM))


const RECENT_POS := 8


static func _po_actionable(po: Dictionary) -> bool:
	if po["status"] in ["in_transit", "awaiting_payment"]:
		return true
	if po.get("returns", []).any(func(r): return r["status"] == "in_transit"):
		return true
	return po["status"] == "delivered" and Ecommerce.return_block(str(po["id"])) == ""


func _purchase_return(id: String, cancelling: bool) -> void:
	var modal := PurchaseReturnModal.new(id, cancelling)
	modal.closed.connect(rebuild)
	UIRoot.open_modal(modal)


func _buy(sid: String, pid: String, key: String, terms: bool) -> void:
	var full := Ecommerce.space_block(deliver_to, int(buy_qty[key]))
	if full != "":
		UIRoot.toast(full, "bad", "warning")   # before asking how to pay for something that won't fit
		return
	if Ecommerce.needs_settlement(sid) and not terms:
		# Clearing Crisis: choose how the money crosses the border first
		var sm := SettlementModal.for_purchase(sid, pid, int(buy_qty[key]), deliver_to)
		sm.closed.connect(rebuild)
		UIRoot.open_modal(sm)
		return
	var r := Ecommerce.buy(sid, pid, int(buy_qty[key]), deliver_to, terms)
	if not r["ok"]:
		UIRoot.toast(r["error"], "bad", "warning")
		return
	Clock.advance(10)
	UIRoot.toast(I18n.t("Ordered %d × %s — %s. Arrives %s.") % [int(buy_qty[key]), I18n.t(DataDB.product(pid)["name"]), Fmt.money0(r["total"]), Clock.fmt_short(int(r["eta"]))], "good", "parcel")
	rebuild()


# ============================================================== INVENTORY
func _tab_inventory() -> void:
	_concepts(["avg_cost", "defect_rate"])
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
				if po["status"] in ["in_transit", "awaiting_payment"] and po["location"] == loc and po["product"] == pid:
					inc += int(po["qty"])
			if q == 0 and inc == 0:
				continue
			var row := UIK.hbox(4)
			for c2 in [[I18n.t(DataDB.product(pid)["name"]), 150], [I18n.t("%d units") % q, 60], [I18n.t("%d units") % Ecommerce.reserved(loc, pid), 60], [Fmt.money0(Ecommerce.avg_cost(loc, pid)), 70],
					[Fmt.money0(q * Ecommerce.avg_cost(loc, pid)), 70], [I18n.t("%d units") % inc, 60]]:
				var l2 := UIK.label(c2[0], 8, Art.C_WHITE)
				l2.custom_minimum_size = Vector2(c2[1], 0)
				row.add_child(l2)
			content.add_child(row)
	content.add_child(UIK.sep())
	content.add_child(UIK.kv("Total stock value (books)", Fmt.money0(Ledger.balance(GameState.business_entity(), "inventory")), Art.C_SKY, 8, true))
	content.add_child(UIK.wrap("Inventory is cash you can't spend. The ledger values it at average cost; a liquidator pays about 40% of that.", 7, Art.C_DIM, 480))


# ============================================================== PEOPLE
func _tab_people() -> void:
	_concepts(["payroll", "morale", "employer_registration"])
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
	v.add_child(UIK.label(I18n.t("Team: %d people · payroll %s / week (Fridays 17:00)") % [Staff.count(), Fmt.money0(ws)], 7, Art.C_SKY, true))
	if Staff.wages_owed() > 0.0:
		v.add_child(UIK.label(I18n.t("Wages owed to your team: %s") % Fmt.money0(Staff.wages_owed()), 7, Art.C_RED, true))
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
		ev.add_child(UIK.label(I18n.t("Morale %d points") % mo + "  " + "■".repeat(int(mo / 10.0)) + "□".repeat(10 - int(mo / 10.0)), 7,
			Art.C_GREEN if mo >= 60 else (Art.C_GOLD if mo >= 35 else Art.C_RED), true))
		var eid: String = e["id"]
		var rb := UIK.button(I18n.t("Raise +8%"), func(): Staff.give_raise(eid); rebuild())
		rb.name = "Raise_" + eid
		rh.add_child(rb)
		var lb := UIK.button("Let go", func():
			var r := Staff.let_go(eid)
			if r["ok"]:
				UIRoot.toast(I18n.t("Severance paid: %s.") % Fmt.money0(r["severance"]), "info", "people")
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
				rebuild(), _next_style(true))
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
				rebuild(), _next_style(rwhy == ""))
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
		content.add_child(UIK.kv(n["name"], I18n.t(str(n.get("role", ""))), Art.C_WHITE, 8))
	if not GameState.data["npcs"].has("maya"):
		content.add_child(UIK.kv("Maya", "friend (phone)", Art.C_WHITE, 8))


func _trait_text(tid: String) -> String:
	for t in Staff.cfg().get("traits", []):
		if t["id"] == tid:
			return str(t["desc"])
	return ""


# ============================================================== CONTRACTS
func _tab_contracts() -> void:
	_concepts(["net_terms", "upfront", "late_penalty", "early_payment"])
	var list := Contracts.open_list()
	if list.is_empty():
		content.add_child(UIK.wrap("No contracts yet. B2B customers want invoices from a registered company — and they usually pay later (Net 30).", 8, Art.C_MUTED, 480))
		return
	if sel_contract == "" or not GameState.data["contracts"].has(sel_contract):
		sel_contract = list[0]["id"]
	var h := UIK.hbox(4)
	for c in list:
		var cb := UIK.button("%s · %s" % [c["id"], status_text(str(c["status"]))], func(): sel_contract = c["id"]; counter_price = 0.0; rebuild(), "tab_active" if sel_contract == c["id"] else "tab")
		cb.name = "Contract_" + str(c["id"])
		h.add_child(cb)
	content.add_child(h)
	var k: Dictionary = GameState.data["contracts"][sel_contract]
	var cols := UIK.hbox(10)
	content.add_child(cols)
	var v := UIK.vbox(1)
	v.custom_minimum_size = Vector2(250, 0)
	cols.add_child(v)
	var seller_name := GameState.entity_name(k["seller"]) if k["seller"] != "player" else GameState.business_display_name()
	for row in [["Buyer", GameState.entity_name(k["buyer"])], ["Seller", seller_name], ["Product", I18n.t(DataDB.product(k["product"])["name"])],
			["Quantity", I18n.t("%d units") % int(k["qty"])], ["Unit price", Fmt.money(k["unit_price"])], ["Total", Fmt.money(k["total"])],
			["Delivery", (I18n.t("due ") + Clock.fmt_short(int(k["due"]))) if k.has("due") else I18n.t("%d days after signing") % int(k["delivery_days"])],
			["Payment terms", I18n.t("Net %d days%s") % [int(k["payment_terms_days"]), (I18n.t(" · %d%% upfront") % int(float(k["upfront_rate"]) * 100)) if float(k["upfront_rate"]) > 0 else ""]],
			["Late penalty", Fmt.pct(float(k["penalty_rate"]))], ["Quality", Fmt.pct(float(k["quality_req"]))], ["Currency", "AUD (Aurelia dollar)"], ["Settlement", "Bank transfer"]]:
		v.add_child(UIK.kv(row[0], row[1], Art.C_WHITE, 7))
		if row[0] == "Payment terms": v.add_child(UIK.tip("net_terms"))
	var right := UIK.vbox(2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIK.label("NEGOTIATION", 7, Art.C_DIM, true))
	for hh in k["history"]:
		right.add_child(UIK.wrap("%s: %s" % [GameState.entity_name(hh["by"]) if hh["by"] != "player" else GameState.business_display_name(), SavedText.display(str(hh["text"]))], 7, Art.C_WHITE, 220))
	var cost := Ecommerce.avg_cost(Ecommerce.default_stock_location(), k["product"])
	if cost <= 0:
		var o := Ecommerce.offer("tradelink_wholesale", k["product"])
		cost = float(o.get("unit_cost", 0))
	right.add_child(UIK.label(I18n.t("Your unit cost ≈ %s → gross margin %s") % [Fmt.money(cost), Fmt.money((float(k["unit_price"]) - cost) * int(k["qty"]))], 7, Art.C_SKY))
	if Contracts.seller_closed(k):
		right.add_child(UIK.label_tip("This is a contract of a closed company.", "contract_closure", 8, Art.C_RED))
		var blocked := UIK.button("Delivery unavailable", func(): pass)
		blocked.name = "DeliverContract"
		blocked.disabled = true
		right.add_child(blocked)
		return
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
			rebuild(), _next_style(true))
		acc.name = "AcceptContract"
		ab.add_child(acc)
		ab.add_child(UIK.button("Decline", func(): Contracts.reject(k["id"]); rebuild(), "danger"))
		right.add_child(ab)
		right.add_child(UIK.label("COUNTER-OFFER", 7, Art.C_DIM, true))
		var c1 := UIK.hbox(3)
		c1.add_child(UIK.button("−", func(): counter_price = maxf(1.0, counter_price - 0.5); rebuild()))
		c1.add_child(UIK.label(I18n.t("%s per unit") % Fmt.money(counter_price), 8, Art.C_WHITE, true))
		c1.add_child(UIK.button("+", func(): counter_price += 0.5; rebuild()))
		right.add_child(c1)
		var c2 := UIK.hbox(3)
		for t in [15, 30, 45]:
			c2.add_child(UIK.button(I18n.t("Net %d days") % t, func(): counter_terms = t; rebuild(), "tab_active" if counter_terms == t else "tab"))
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
		right.add_child(UIK.label(I18n.t("In stock (all locations): %d / %d units needed") % [have, int(k["qty"])], 8, Art.C_GREEN if have >= int(k["qty"]) else Art.C_RED, true))
		var coming := Ecommerce.incoming_units_of(k["product"])
		if coming > 0 and have < int(k["qty"]):
			right.add_child(UIK.label(I18n.t("On the way from suppliers: %d units") % coming, 7, Art.C_SKY, true))
		right.add_child(UIK.label(I18n.t("Due %s") % Clock.fmt_datetime(int(k["due"])), 7, Art.C_GOLD if Clock.now() < int(k["due"]) else Art.C_RED))
		var db := UIK.button(I18n.t("Pack & deliver %d units (B2B freight $40)") % int(k["qty"]), func():
			var r := Contracts.deliver(k["id"])
			if not r["ok"]:
				UIRoot.toast(r["error"], "bad", "warning")
			else:
				Clock.advance(90)
				UIRoot.toast(I18n.t("Delivered. Invoice %s due in %d days.") % [Fmt.money0(r["receivable"]), int(k["payment_terms_days"])], "good", "contracts")
			rebuild(), _next_style(Contracts.can_deliver(str(k["id"]))))
		db.name = "DeliverContract"
		db.disabled = not Contracts.can_deliver(str(k["id"]))
		right.add_child(db)
		var why := Contracts.delivery_block(str(k["id"]))
		if why != "":
			right.add_child(UIK.wrap(why, 7, Art.C_RED, 220))
		if str(k["seller"]) != GameState.company_id():
			return
		var plan := Contracts.restock_plan(k)
		if not plan.is_empty():
			if plan.has("error"):
				right.add_child(UIK.wrap(I18n.t(str(plan["error"])), 7, Art.C_RED, 220))
			else:
				var fb := UIK.button(I18n.t("Order %d more from %s (%s)") % [int(plan["qty"]), I18n.t(str(DataDB.supplier(plan["supplier"]).get("name", ""))), Fmt.money0(float(plan["cost"]))], func():
					_fill(k, false), _next_style(_buy_possible(str(plan["supplier"]), str(k["product"]), int(plan["qty"]), str(k["location"]))))
				fb.name = "FillContract"
				fb.disabled = not _buy_possible(str(plan["supplier"]), str(k["product"]), int(plan["qty"]), str(k["location"]))
				right.add_child(fb)
				if Ecommerce.can_use_net_terms(plan["supplier"]):
					var ft := UIK.button("…or on supplier credit terms", func(): _fill(k, true))
					ft.name = "FillContractTerms"
					right.add_child(ft)
	elif k["status"] == "delivered":
		right.add_child(UIK.label(I18n.t("Invoice %s · due %s") % [Fmt.money0(k["receivable"]), Clock.fmt_short(int(k["pay_due"]))], 8, Art.C_GOLD, true))
		right.add_child(UIK.wrap("Revenue is booked. The cash isn't here yet.", 7, Art.C_SKY, 220))
		if int(k["payment_terms_days"]) >= 30:
			var ep := UIK.button(I18n.t("Ask for early payment (−3%%: %s now)") % Fmt.money0(float(k["receivable"]) * 0.97), func():
				var r := Contracts.early_payment(k["id"])
				if r["ok"]:
					UIRoot.toast(I18n.t("%s paid early: %s in the bank.") % [GameState.entity_name(k["buyer"]), Fmt.money0(r["cash"])], "good", "cash")
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
	_concepts(["net_terms", "accounts_receivable"])
	if not Careers.freelance_active():
		_section("Freelance consulting")
		content.add_child(UIK.wrap("Sell your time: clients post small projects every morning. Accept a gig, work it here in 2-hour sessions, deliver before the deadline and invoice. Payment follows the client's terms. On-time work earns stars; stars raise your rate.", 8, Art.C_WHITE, 480))
		var go := UIK.button("Start freelancing", func():
			Careers.start_freelance()
			rebuild(), _next_style(true))
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
		var wb := UIK.button(I18n.t("Work 2 h"), func(): _work_gig(gid), _next_style(true))
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
		row.add_child(UIK.tip("net_terms"))
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
		content.add_child(UIK.kv("Invoiced, not yet paid", Fmt.money0(owed), Art.C_GOLD))


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
		UIRoot.toast(I18n.t("Delivered and invoiced: %s.") % Fmt.money0(r["fee"]) + (I18n.t(" (late: -20%)") if r["late"] else ""), "good" if not r["late"] else "warn", "check")
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
	_concepts(["mrr", "churn", "server_costs"])
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
				rebuild(), _next_style(true))
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
		var cb := UIK.button(I18n.t("Code for %d hours") % int(Saas.cfg().get("founder_session_hours", 2)), _code_session, _next_style(float(s["dev_done"]) < Saas.dev_needed()))
		cb.name = "SaasCode"
		row.add_child(cb)
		var lb := UIK.button(I18n.t("Launch at %s/month") % Fmt.money(float(s["price"])), func():
			var r := Saas.launch()
			if not r["ok"]:
				UIRoot.toast(I18n.t(str(r["error"])), "warn", "laptop")
			else:
				UIRoot.show_chapter_card(I18n.t("%s IS LIVE") % str(i["name"]).to_upper(), I18n.t("Now the real work starts: keep them subscribed."))
			rebuild(), _next_style(float(s["dev_done"]) >= Saas.dev_needed()))
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
	_kpi(g, I18n.t("SUBSCRIBERS"), I18n.t("%d people") % int(s["subs"]), Art.C_WHITE, I18n.t("+%d / −%d last 7 days") % [Saas.last_days(7, "new"), Saas.last_days(7, "lost")])
	_kpi(g, "MRR", Fmt.money0(Saas.mrr()), Art.C_GREEN, I18n.t("%s/month each") % Fmt.money0(float(s["price"])), "mrr")
	_kpi(g, I18n.t("CHURN"), Fmt.pct(Saas.monthly_churn(), 1), Art.C_GOLD, I18n.t("per month"), "churn")
	var srv := float(Saas.cfg().get("server_base_month", 40)) + float(Saas.cfg().get("server_per_user_month", 0.35)) * int(s["subs"])
	_kpi(g, I18n.t("SERVERS"), Fmt.money0(srv), Art.C_RED, I18n.t("per month"), "server_costs")
	content.add_child(UIK.label(I18n.t("Expected signups: %.1f/day · features shipped: %d · next feature %d / %d h") % [Saas.signup_rate(), int(s["features"]),
		int(s["feature_progress"]), int(Saas.cfg().get("feature_hours", 80))], 7, Art.C_MUTED, true))
	var pr := UIK.hbox(4)
	content.add_child(pr)
	pr.add_child(UIK.label("Price", 8, Art.C_MUTED))
	var pm := UIK.button("−$5", func(): Saas.set_price(float(s["price"]) - 5.0); rebuild())
	pm.name = "SaasPriceDown"
	pr.add_child(pm)
	pr.add_child(UIK.label(Fmt.money(float(s["price"])), 9, Art.C_WHITE, true))
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



# ============================================================== CAFÉ
func _tab_cafe() -> void:
	var s := Cafe.S()
	var head := UIK.hbox(6)
	content.add_child(head)
	head.add_child(UIK.title(Cafe.display_name(), 11, Art.C_GOLD))
	head.add_child(UIK.label(I18n.t("Lantern Row, Old Town · open Mon–Sat 7:00–17:00"), 7, Art.C_DIM))
	var why := Cafe.open_block()
	if why != "":
		_section("Before the first customer")
		_cafe_step("Lease the corner unit", Cafe.leased(), "")
		if Cafe.fitted():
			_cafe_step("Fit out: espresso machine, counter, tables", true, "")
		elif Cafe.fitting():
			_cafe_step("Fit out: espresso machine, counter, tables", false, I18n.t("Fitters at work until %s") % Clock.fmt_short(int(s["fit_ready"])))
		else:
			var fb := _cafe_step("Fit out: espresso machine, counter, tables", false, "")
			fb.add_child(UIK.tip("fitout"))
			var fit_ready := Cafe.leased() and Ledger.cash(Cafe.entity()) >= float(Cafe.cfg().get("fitout_cost", 5800))
			var b := UIK.button(I18n.t("Fit out (%s)") % Fmt.money0(float(Cafe.cfg().get("fitout_cost", 5800))), func():
				var r := Cafe.fit_out()
				if not r["ok"]:
					UIRoot.toast(I18n.t(str(r["error"])), "warn", "coffee")
				else:
					UIRoot.toast(I18n.t("The fitters start tonight. Ready %s.") % Clock.fmt_short(int(r["ready"])), "good", "coffee")
				rebuild(), _next_style(fit_ready))
			b.disabled = not fit_ready
			b.name = "CafeFitOut"
			fb.add_child(b)
		var ptxt := ""
		if Cafe.permit_pending():
			ptxt = I18n.t("City Hall is processing it (ready %s)") % Clock.fmt_short(int(s["permit_ready"]))
		elif not Cafe.permitted():
			ptxt = I18n.t("Apply at City Hall → Permits (%s)") % Fmt.money0(float(Cafe.cfg().get("permit_fee", 280)))
		_cafe_step("Food handling licence", Cafe.permitted(), ptxt)
	else:
		var g := GridContainer.new()
		g.columns = 4
		g.add_theme_constant_override("h_separation", 4)
		content.add_child(g)
		var td: Dictionary = s["today"] if int(s["today"].get("d", -1)) == Clock.day_index() else {}
		_kpi(g, I18n.t("CUSTOMERS TODAY"), str(int(td.get("served", 0))), Art.C_WHITE, I18n.t("%d last 7 days") % int(Cafe.last_days(7, "served")))
		_kpi(g, I18n.t("TILL TODAY"), Fmt.money0(float(td.get("rev", 0.0))), Art.C_GREEN, I18n.t("%s last 7 days") % Fmt.money0(Cafe.last_days(7, "rev")))
		_kpi(g, I18n.t("RATING"), "★ %.1f" % float(s["rating"]), Art.C_GOLD, I18n.t("out of 5"))
		_kpi(g, I18n.t("SUPPLIES"), I18n.t("%d cups") % int(s["supplies"]), Art.C_WHITE if int(s["supplies"]) > 60 else Art.C_RED,
			I18n.t("+%d arriving") % int(s["incoming"]) if int(s["incoming"]) > 0 else "")
		var nb := Cafe.baristas_at(Clock.now()).size()
		var state := I18n.t("Open now") if Cafe.is_open_now() else I18n.t("Closed now")
		content.add_child(UIK.label(state + "  ·  " + I18n.t("behind the counter: %d barista(s)") % nb, 7, Art.C_SKY, true))
		var est := UIK.label_tip(I18n.t("At these prices: about %d customers on a weekday. Each barista makes ~%d cups an hour.") % [int(round(Cafe.expected_day_demand())),
			int(Cafe.cfg().get("barista_cups_hour", 14))], "foot_traffic", 7, Art.C_MUTED)
		content.add_child(est)
		content.add_child(UIK.label_tip(I18n.t("Rating ★ %.1f: queues, running out and high prices pull it down.") % float(s["rating"]), "cafe_rating", 7, Art.C_MUTED))
	# counter staff
	if Staff.count("barista") == 0:
		content.add_child(UIK.wrap("Nobody's on staff behind the counter: the café only opens while you work it yourself (the counter, inside the café). Hire a Barista in the People tab to open every day.", 7, Art.C_GOLD, 480))
	_section_tip("Menu", "gross_margin")
	for id in ["coffee", "pastry"]:
		var it := Cafe.item(id)
		var r := UIK.hbox(4)
		content.add_child(r)
		var nm := UIK.label(I18n.t(str(it.get("name", id))), 8, Art.C_WHITE, true)
		nm.custom_minimum_size = Vector2(70, 0)
		r.add_child(nm)
		var dn := UIK.button("−", func(): Cafe.set_price(id, Cafe.price(id) - 0.25); rebuild())
		dn.name = "CafePriceDown_" + id
		r.add_child(dn)
		r.add_child(UIK.label(Fmt.money(Cafe.price(id)), 9, Art.C_WHITE, true))
		var up := UIK.button("+", func(): Cafe.set_price(id, Cafe.price(id) + 0.25); rebuild())
		up.name = "CafePriceUp_" + id
		r.add_child(up)
		r.add_child(UIK.label(I18n.t("street price %s · costs you %s") % [Fmt.money(float(it.get("ref_price", 4.0))), Fmt.money(float(it.get("unit_cost", 1.0)))], 7, Art.C_DIM))
	_section_tip("Supplies and the bakery", "food_waste")
	var sr := UIK.hbox(4)
	content.add_child(sr)
	sr.add_child(UIK.label(I18n.t("Coffee, milk and cups: %d cups in stock") % int(s["supplies"]), 8, Art.C_WHITE))
	sr.add_child(UIK.expand())
	for pk in Cafe.cfg().get("supply_packs", []):
		var pid := str(pk["id"])
		var pb := UIK.button(I18n.t("%d cups · %s") % [int(pk["cups"]), Fmt.money(Cafe.pack_cost(pid))], func():
			var r := Cafe.order_supplies(pid)
			if not r["ok"]:
				UIRoot.toast(I18n.t(str(r["error"])), "warn", "coffee")
			else:
				UIRoot.toast(I18n.t("Ordered. Old Town Roasters delivers %s.") % Clock.fmt_short(int(r["eta"])), "good", "coffee")
			rebuild())
		pb.name = "CafeSupplies_" + pid
		sr.add_child(pb)
	var br := UIK.hbox(4)
	content.add_child(br)
	br.add_child(UIK.label(I18n.t("Pastries from the bakery each morning:"), 8, Art.C_WHITE))
	var pm := UIK.button("−5", func(): Cafe.set_pastry_order(int(s["pastry_order"]) - 5); rebuild())
	pm.name = "CafePastryDown"
	br.add_child(pm)
	br.add_child(UIK.label(str(int(s["pastry_order"])), 9, Art.C_WHITE, true))
	var pp := UIK.button("+5", func(): Cafe.set_pastry_order(int(s["pastry_order"]) + 5); rebuild())
	pp.name = "CafePastryUp"
	br.add_child(pp)
	br.add_child(UIK.label(I18n.t("unsold ones are binned at closing"), 7, Art.C_DIM))
	var ar := UIK.hbox(4)
	content.add_child(ar)
	ar.add_child(UIK.label(I18n.t("Flyers and a street board, per day:"), 8, Art.C_WHITE))
	for a in Cafe.cfg().get("ads", [0, 15, 40]):
		var av := float(a)
		var ab := UIK.button(Fmt.money0(av), func(): Cafe.set_ads(av); rebuild(), "tab_active" if is_equal_approx(float(s["ads"]), av) else "tab")
		ab.name = "CafeAds_%d" % int(av)
		ar.add_child(ab)
	var days: Array = s["days"]
	if not days.is_empty():
		_section("Last days")
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 12)
		content.add_child(grid)
		for h in ["Day", "Customers", "Till", "Walked out", "Ran out", "Binned"]:
			grid.add_child(UIK.label(I18n.t(h), 7, Art.C_DIM, true))
		for i in range(days.size() - 1, maxi(-1, days.size() - 8), -1):
			var d: Dictionary = days[i]
			grid.add_child(UIK.label(Clock.fmt_date(int(d["d"]) * Clock.DAY), 7, Art.C_MUTED))
			grid.add_child(UIK.label(str(int(d["served"])), 7, Art.C_WHITE))
			grid.add_child(UIK.label(Fmt.money0(float(d["rev"])), 7, Art.C_GREEN))
			grid.add_child(UIK.label(str(int(d["queue_lost"])), 7, Art.C_RED if int(d["queue_lost"]) > 0 else Art.C_DIM))
			grid.add_child(UIK.label(str(int(d["stock_lost"])), 7, Art.C_RED if int(d["stock_lost"]) > 0 else Art.C_DIM))
			grid.add_child(UIK.label(str(int(d["waste"])), 7, Art.C_GOLD if int(d["waste"]) > 0 else Art.C_DIM))
	_section("Name over the door")
	var nr := UIK.hbox(4)
	content.add_child(nr)
	var ed := LineEdit.new()
	ed.text = Cafe.display_name()
	ed.max_length = 28
	ed.custom_minimum_size = Vector2(200, 0)
	ed.name = "CafeName"
	nr.add_child(ed)
	var rn := UIK.button("Rename", func():
		Cafe.set_name(ed.text)
		rebuild())
	rn.name = "CafeRename"
	nr.add_child(rn)


## One line of the café's opening checklist; returns the row so a button can go on the end.
func _cafe_step(text: String, done: bool, note: String) -> HBoxContainer:
	var r := UIK.hbox(6)
	content.add_child(r)
	r.add_child(UIK.label("✓" if done else "✗", 9, Art.C_GREEN if done else Art.C_DIM, true))
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	v.add_child(UIK.label(I18n.t(text), 8, Art.C_WHITE if not done else Art.C_MUTED, true))
	if note != "":
		v.add_child(UIK.label(note, 7, Art.C_GOLD))
	return r


# ============================================================== LOGISTICS
func _tab_logistics() -> void:
	var s := Logistics.S()
	var head := UIK.hbox(6)
	content.add_child(head)
	head.add_child(UIK.title("Logistics", 11, Art.C_GOLD))
	head.add_child(UIK.label(I18n.t("Van kept at Pier 7 · insurance %s a month · %.0f km driven") % [Fmt.money0(float(Logistics.van_cfg().get("insurance_month", 165))),
		float(s["van"].get("km", 0.0))], 7, Art.C_DIM))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 4)
	content.add_child(g)
	var open := Logistics.open_jobs()
	var mine := Logistics.active_jobs()
	_kpi(g, I18n.t("RUNS ON THE BOARD"), str(open.size()), Art.C_WHITE, I18n.t("%d accepted") % mine.size())
	_kpi(g, I18n.t("RUNS PAID, 7 DAYS"), Fmt.money0(Logistics.history_sum(7, "pay")), Art.C_GREEN, I18n.t("%d runs") % Logistics.history_count(7))
	_kpi(g, I18n.t("FUEL, 7 DAYS"), Fmt.money0(Logistics.history_sum(7, "fuel")), Art.C_RED, I18n.t("%.1f L per 100 km") % (Logistics.fuel_l_per_km() * 100.0))
	_kpi(g, I18n.t("DRIVERS"), str(Staff.count("driver")), Art.C_WHITE, I18n.t("%d parcels a trip") % int(Logistics.van_cfg().get("capacity_parcels", 40)))
	_section_tip("Posted runs", "delivery_run")
	if open.is_empty():
		content.add_child(UIK.wrap("No runs on the board. Clients post new ones every morning at 7:00.", 7, Art.C_DIM, 470))
	for j in open:
		var jid := str(j["id"])
		var row := UIK.hbox(6)
		content.add_child(row)
		var col := UIK.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var top := UIK.hbox(4)
		col.add_child(top)
		var cl := UIK.label(I18n.t(str(j["client"])), 8, Art.C_WHITE, true)
		top.add_child(cl)
		top.add_child(UIK.chip(Logistics.kind_name(str(j["kind"])).to_upper(), Art.C_GOLD if str(j["kind"]) == "rush" else Art.C_SKY))
		var too_late := Clock.now() + int(j["est_min"]) > int(j["by"])   # leaving right now, the best route still arrives after the deadline
		col.add_child(UIK.label(I18n.t("%d stops · deliver by %s · about %s on the road") % [(j["stops"] as Array).size(), Clock.fmt_short(int(j["by"])),
			Fmt.duration_min(int(j["est_min"]))] + ("  ·  " + I18n.t("too late to make it if you leave now") if too_late else ""), 7, Art.C_RED if too_late else Art.C_MUTED))
		row.add_child(UIK.label(Fmt.money0(float(j["pay"])), 9, Art.C_GREEN, true))
		var ab := UIK.button("Accept", func():
			var r := Logistics.accept(jid)
			if not r["ok"]:
				UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
			rebuild(), _next_style(not too_late))
		ab.name = "Accept_" + jid
		row.add_child(ab)
	if not open.is_empty():
		content.add_child(UIK.wrap(I18n.t("In plain words: you get the fee if you finish by the deadline; a late run pays %d%% less, and one left undone for hours is cancelled.") % int(round(float(Logistics.runs_cfg().get("late_penalty", 0.4)) * 100.0)), 7, Art.C_SKY, 470))
	_section_tip("Your runs", "route_planning")
	if mine.is_empty():
		content.add_child(UIK.wrap("Accept a run above, then drive it: you plan the route on a map. Every kilometre saved is fuel and time kept.", 7, Art.C_DIM, 470))
	for j in mine:
		var jid2 := str(j["id"])
		var row2 := UIK.hbox(6)
		content.add_child(row2)
		var col2 := UIK.vbox(0)
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(col2)
		col2.add_child(UIK.label("%s · %s" % [jid2, I18n.t(str(j["client"]))], 8, Art.C_WHITE, true))
		var late: bool = Clock.now() > int(j["by"])
		col2.add_child(UIK.label((I18n.t("Past its deadline (%s): the pay is cut") if late else I18n.t("Deliver by %s")) % Clock.fmt_short(int(j["by"])), 7, Art.C_RED if late else Art.C_MUTED))
		row2.add_child(UIK.label(Fmt.money0(float(j["pay"])), 9, Art.C_GREEN, true))
		var db := UIK.button("Drive it", _drive_run.bind(jid2), _next_style(true))
		db.name = "Drive_" + jid2
		row2.add_child(db)
	_section_tip("Drivers", "driver_staff")
	var dwhy := Staff.hire_block("driver")
	if Staff.count("driver") > 0:
		content.add_child(UIK.wrap(I18n.t("%d driver(s) take one posted run each workday from 9:00 and bank the fee. They plan the route less well than you do.") % Staff.count("driver"), 7, Art.C_MUTED, 470))
	else:
		content.add_child(UIK.wrap("No driver yet. Hire a Van Driver in the People tab to have the van work while you do something else.", 7, Art.C_DIM, 470))
	if dwhy != "" and Staff.count("driver") == 0:
		content.add_child(UIK.label(I18n.t("Can't hire yet: %s.") % I18n.t(dwhy), 7, Art.C_GOLD))
	var hist := Logistics.history(5)
	if not hist.is_empty():
		_section("Recent runs")
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 12)
		content.add_child(grid)
		for h in ["Run", "Result", "Paid", "Route", "Score"]:
			grid.add_child(UIK.label(I18n.t(h), 7, Art.C_DIM, true))
		for r in hist:
			var ok := str(r["status"]) == "done"
			var failed := str(r["status"]) == "failed"
			grid.add_child(UIK.label("%s · %s" % [r["id"], I18n.t(str(r["client"]))], 7, Art.C_MUTED))
			grid.add_child(UIK.label(I18n.t("Cancelled") if failed else (I18n.t("On time") if ok else I18n.t("Late")), 7, Art.C_RED if failed else (Art.C_GREEN if ok else Art.C_GOLD), true))
			grid.add_child(UIK.label(Fmt.money0(float(r["pay"])), 7, Art.C_GREEN if not failed else Art.C_DIM))
			grid.add_child(UIK.label("%.1f km" % float(r["km"]) if not failed else "—", 7, Art.C_WHITE))
			grid.add_child(UIK.label("%d%%" % int(round(float(r["score"]) * 100.0)) if not failed else "—", 7, Art.C_WHITE))
	_section_tip("Your own parcels", "own_van_shipping")
	content.add_child(UIK.wrap("At any packing table the shipping options include \"Own van\": fuel instead of a courier fee, delivered the same day. The Pier 7 warehouse can hold your stock too.", 7, Art.C_MUTED, 470))


## Drive an accepted run: plan the route in the minigame, then the clock runs and the client pays.
func _drive_run(id: String) -> void:
	var j := Logistics.job(id)
	if j.is_empty():
		return
	var g := RouteGame.new(j)
	g.title_text = I18n.t("Plan the route: run %s") % id
	MiniGames.play(g, func(res: Dictionary):
		if res.get("aborted", false):
			return
		var r := Logistics.drive(id, res.get("order", []))
		if not r["ok"]:
			UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
		else:
			UIRoot.toast(I18n.t("Run %s done: paid %s, fuel %s, %s on the road.") % [id, Fmt.money0(float(r["pay"])), Fmt.money0(float(r["fuel"])), Fmt.duration_min(int(r["minutes"]))],
				"warn" if r["late"] else "good", "parcel")
		if is_inside_tree():
			rebuild())


func _tab_group() -> void:
	GroupUI.render(self)


func _tab_segments() -> void:
	_section_tip("Segments", "segments")
	var next := UIK.button("Review next action", _set_tab.bind("overview"), "primary")
	next.name = "SegmentsNext"
	content.add_child(next)
	content.add_child(UIK.wrap("Shared costs are allocated by net revenue. With no revenue, they stay in Shared.", 8, Art.C_MUTED, 450))
	var entity := GameState.business_entity()
	var previous_end := Clock.month_start()
	var previous_start := Clock.month_start(previous_end-1) if previous_end > 0 else 0
	for period in [["This month", previous_end, Clock.now()+1], ["Last month", previous_start, previous_end]]:
		_section(period[0])
		var report := Segments.compute(entity, period[1], period[2])
		for row in report["rows"].values():
			var label := "Shared" if row["id"] == "shared" else str(DataDB.businesses.get(row["id"], {}).get("name", row["id"]))
			content.add_child(UIK.label(label, 9, Art.C_SKY, true))
			for field in [["Net revenue", "net_revenue"], ["Gross profit", "gross_profit"], ["Operating expenses", "opex"], ["Allocated", "allocated"], ["Operating profit", "operating_profit"]]:
				content.add_child(UIK.kv(field[0], Fmt.money(row[field[1]])))
			if float(row["internal_revenue"])>0:content.add_child(UIK.kv("Internal sales to the group",Fmt.money(row["internal_revenue"])))
			if float(row["internal_charge"])>0:content.add_child(UIK.kv("Internal purchases from the group",Fmt.money(row["internal_charge"])))
			if float(row["internal_cost"])-float(row["internal_charge"])>0.004:content.add_child(UIK.kv("Included internal media cost",Fmt.money(float(row["internal_cost"])-float(row["internal_charge"]))))
		if float(report["totals"]["internal_revenue"])>0:content.add_child(UIK.kv("Internal trade eliminated in group total",Fmt.money(report["totals"]["internal_revenue"])))
		content.add_child(UIK.kv("Total operating profit", Fmt.money(report["totals"]["operating_profit"])))
