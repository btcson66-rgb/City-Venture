extends RefCounted
## Chapters 10–12 at the logic level: Digital Rails (escrow on delivery, Year 6), The Other Side of Trust (the bridge
## exploit freezes the digital-dollar rail, Year 7) and Regulation & Scale (KYC, an import licence, compliance costs
## and Hale Group's acquisition offer, Year 8), then free play.

var runner


func _check() -> void:
	StoryEngine.check()


func _active(id: String) -> bool:
	return id in StoryEngine.St()["active"]


func _done(id: String) -> bool:
	return id in StoryEngine.St()["done"]


func _setup(cash := 28000.0) -> String:
	Company.register("Endgame Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(cash)
	GameState.set_flag("business_account_opened")
	return GameState.company_id()


func _cash() -> float:
	return Ledger.cash(GameState.business_entity())


func _po(id: String) -> Dictionary:
	return Ecommerce.E()["purchase_orders"][id]


func _bal(acct: String) -> float:
	return Ledger.balance(GameState.business_entity(), acct)


## Advance the clock until pred() or `max_days` pass.
func _advance_until(pred: Callable, max_days := 40) -> bool:
	var n := 0
	while not pred.call() and n < max_days * 24:
		Clock.advance(60)
		n += 1
	return pred.call()


func _pending(id: String) -> Dictionary:
	for q in EventEngine.pending():
		if q["id"] == id:
			return q
	return {}


# ------------------------------------------------------------------ data
func test_years_6_to_8_have_eras_and_headlines() -> void:
	for y in [6, 7, 8]:
		var d := DataDB.year_def(y)
		runner.eq(str(d.get("status", "")), "active", "year %d is live" % y)
		runner.check(d.get("headlines", []).size() >= 3 and d.get("headlines", []).size() <= 4, "year %d has 3–4 headlines" % y)
	runner.check(DataDB.year_def(7).has("headlines_incident") and DataDB.year_def(7).has("headlines_after"), "year 7 has news for the freeze and after it")
	World.set_year(6)
	runner.eq(World.wire_clear_mult(), 0.6, "wires recover in Year 6")
	runner.check(not World.compliance(), "no compliance rules yet")
	World.set_year(8)
	runner.check(World.compliance(), "Year 8 is the regulation wave")


func test_new_story_text_has_no_real_crypto_names() -> void:
	var banned := ["bitcoin", "btc", "ethereum", "tether", "usdt", "usdc", "binance", "coinbase", "solana", "dogecoin", "nft", "blockchain"]
	var texts: Array = []
	for y in [6, 7, 8]:
		texts.append(JSON.stringify(DataDB.year_def(y)))
	for id in ["ch10_digital_rails", "ch11_other_side_of_trust", "ch12_regulation_scale"]:
		texts.append(JSON.stringify(StoryEngine.chapter_def(id)))
	for id in ["escrow_offer", "rail_frozen", "acquisition_offer", "shipment_lost"]:
		texts.append(JSON.stringify(DataDB.events[id]))
	for id in ["lina_rails", "lina_rails_again", "lina_bridge", "lina_reopened", "victor_offer", "victor_sold", "victor_earnout", "victor_declined", "victor_chat"]:
		texts.append(JSON.stringify(DataDB.dialogue[id]))
	for id in ["rail_reliability", "frozen_funds", "bridge_loan", "kyc", "import_licence", "compliance_cost", "valuation", "earn_out"]:
		texts.append(JSON.stringify(DataDB.glossary[id]))
	for t in texts:
		for b in banned:
			runner.check(not str(t).to_lower().contains(b), "no '%s' in the new story text" % b)


func test_data_validates_and_texts_match_the_numbers() -> void:
	runner.eq(DataDB.validate(), [], "data validates")
	var licence := StoryEngine.chapter_def("ch12_regulation_scale")["objectives"][0]["on_start"][2]["text"] as String
	runner.check(licence.contains(Fmt.money0(Compliance.licence_fee())), "Ana's message quotes the licence fee")
	var kyc_text := str(StoryEngine.objective_def("ch12_kyc")["text"])
	runner.check(kyc_text.contains(Fmt.money0(Compliance.kyc_threshold())), "the KYC objective quotes the threshold")
	runner.check(str(DataDB.year_def(8)["headlines"][0]).contains(Fmt.money0(Compliance.kyc_threshold())), "so does the Year 8 headline")
	runner.check(not str(StoryEngine.objective_def("goal_growth")["text"]).contains("coming"), "free play no longer says chapters are coming")


# ------------------------------------------------------------------ Chapter 10: escrow
func test_escrow_needs_year_6_and_an_account() -> void:
	_setup()
	World.set_year(5)
	runner.check(Ecommerce.settlement_block("escrow") != "", "no escrow in Year 5")
	World.set_year(6)
	runner.check(Ecommerce.settlement_block("escrow") != "", "an escrow account is needed")
	var inst := EventEngine.trigger("escrow_offer")
	var r := EventEngine.choose(inst["iid"], "try")
	runner.check(r["ok"], "opened the account at Lina's offer")
	runner.check(GameState.flag("escrow_open") and GameState.flag("ch10_decided"), "flags set")
	runner.eq(Ecommerce.settlement_block("escrow"), "", "escrow is a payment option now")
	runner.check(Ecommerce.settlement_options().any(func(m): return m["id"] == "escrow"), "and it is listed")


func test_declining_escrow_is_final_but_never_forced() -> void:
	_setup()
	World.set_year(6)
	var inst := EventEngine.trigger("escrow_offer")
	runner.check(EventEngine.choose(inst["iid"], "decline")["ok"], "declined")
	runner.check(GameState.flag("escrow_declined") and GameState.flag("ch10_decided") and not GameState.flag("escrow_open"), "decided without an account")
	runner.check(Ecommerce.settlement_block("escrow") != "", "escrow stays off")
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400)
	runner.check(r["ok"], "imports still work by wire (%s)" % str(r.get("error", "")))
	runner.eq(str(_po(r["po_id"]).get("escrow", "")), "", "and are not in escrow")


func test_escrow_happy_path_holds_then_releases_on_arrival() -> void:
	var cid := _setup()
	World.set_year(6)
	GameState.set_flag("escrow_open")
	runner.eq(Ecommerce.settlement_fee("escrow", 864.0), 15.0, "small orders pay the $15 minimum")
	runner.eq(Ecommerce.settlement_fee("escrow", 10000.0), 60.0, "larger ones 0.6%")
	var cash0 := _cash()
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400, "", false, -1, 1.0, "escrow")
	runner.check(r["ok"], "escrow order placed (%s)" % str(r.get("error", "")))
	if not r["ok"]:
		return
	var po := _po(r["po_id"])
	var total := float(po["total"])
	runner.eq(str(po["escrow"]), "held", "the money is in escrow")
	runner.eq(str(po["status"]), "awaiting_payment", "locking the contract takes a moment")
	runner.eq(_bal("escrow_held"), total, "escrow_held carries the order")
	runner.eq(_bal("inventory_in_transit"), 0.0, "and nothing is booked as stock yet")
	runner.eq(_cash(), cash0 - total - 15.0, "cash left: the order plus the fee")
	runner.eq(Ecommerce.incoming_units_of("phone_stand"), 400, "counted as on the way")
	runner.check(int(po["settlement"]["clears"]) - Clock.now() <= 120, "no wire delay: the contract locks within two hours")
	Clock.advance(130)
	runner.eq(str(po["status"]), "in_transit", "the supplier ships once it sees the money locked")
	runner.eq(int(GameState.stat("escrow_orders")), 1, "one escrow order")
	runner.check(Rails.reliability("escrow") > 0.99, "a clean landing nudges the rail's record up")
	runner.eq(_bal("escrow_held"), total, "still held until the goods land")
	runner.check(_advance_until(func(): return str(po["status"]) == "delivered"), "goods arrive")
	runner.eq(_bal("escrow_held"), 0.0, "released to the supplier on arrival")
	runner.eq(_bal("inventory"), total, "and booked as stock")
	runner.eq(str(po["escrow"]), "released", "escrow state: released")
	runner.eq(int(GameState.stat("escrow_released")), 1, "counted")
	runner.eq(int(GameState.stat("import_received_y6")), 1, "an import received in Year 6")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	var _u := cid


func test_escrow_refunds_when_the_supplier_fails() -> void:
	_setup()
	World.set_year(6)
	GameState.set_flag("escrow_open")
	var cash0 := _cash()
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400, "", false, -1, 1.0, "escrow")
	var po := _po(r["po_id"])
	Clock.advance(130)
	runner.check(not Rails.refund_escrow("PO-nope")["ok"], "no such order")
	var ref := Rails.refund_escrow(r["po_id"])
	runner.check(ref["ok"], "the contract returns the money")
	runner.eq(_cash(), cash0 - 15.0, "cash is back except the fee")
	runner.eq(_bal("escrow_held"), 0.0, "nothing left in escrow")
	runner.eq(str(po["status"]), "cancelled", "the order is cancelled")
	runner.eq(Ecommerce.incoming_units_of("phone_stand"), 0, "no longer on the way")
	runner.check(not Rails.refund_escrow(r["po_id"])["ok"], "only once")
	Clock.advance(20 * Clock.DAY)
	runner.eq(_bal("inventory"), 0.0, "and nothing arrives later")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	# a wire order cannot be refunded
	var w := Ecommerce.buy("lumina_direct", "phone_stand", 400)
	Clock.advance(6 * Clock.DAY)
	runner.check(not Rails.refund_escrow(w["po_id"])["ok"], "paid by wire: no refund")


func test_lost_shipment_event_refunds_escrow_and_only_delays_others() -> void:
	_setup()
	World.set_year(6)
	GameState.set_flag("escrow_open")
	var e := Ecommerce.buy("lumina_direct", "phone_stand", 400, "", false, -1, 1.0, "escrow")
	Clock.advance(130)
	var inst := EventEngine.trigger("shipment_lost")
	runner.eq(str(inst["ctx"].get("po_id", "")), str(e["po_id"]), "the lost shipment is the import on the way")
	runner.check(EventEngine.choice_available(DataDB.events["shipment_lost"]["choices"][1], inst["ctx"]), "an escrow order can take the refund")
	runner.check(EventEngine.choose(inst["iid"], "refund")["ok"], "refund taken")
	runner.eq(str(_po(e["po_id"])["status"]), "cancelled", "order cancelled")
	# a wire order: only a re-ship
	var w := Ecommerce.buy("lumina_direct", "phone_stand", 400)
	Clock.advance(6 * Clock.DAY)
	var eta0 := int(_po(w["po_id"])["eta"])
	var inst2 := EventEngine.trigger("shipment_lost")
	runner.check(not EventEngine.choice_available(DataDB.events["shipment_lost"]["choices"][1], inst2["ctx"]), "no refund without escrow")
	EventEngine.choose(inst2["iid"], "reship")
	runner.eq(int(_po(w["po_id"])["eta"]), eta0 + 10 * Clock.DAY, "the arrival moves back ten days")
	runner.check(_advance_until(func(): return str(_po(w["po_id"])["status"]) == "delivered", 50), "and it does arrive")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_rail_record_and_regular_importer_rate() -> void:
	_setup()
	World.set_year(6)
	GameState.set_flag("escrow_open")
	runner.eq(Rails.reliability("letter_of_credit"), 0.995, "the published record")
	runner.check(Rails.reliability("international_wire") < Rails.reliability("letter_of_credit"), "wires are less reliable than letters of credit")
	runner.check(not Rails.regular(), "not a regular yet")
	for i in 2:
		var r := Ecommerce.buy("lumina_direct", "wireless_earbuds", 200, "", false, -1, 1.0, "escrow")
		Clock.advance(130)
		runner.eq(str(_po(r["po_id"])["status"]), "in_transit", "order %d locked" % (i + 1))
	runner.check(Rails.regular(), "two settled payments make a regular")
	runner.eq(Ecommerce.settlement_fee("escrow", 864.0), 9.75, "a regular pays a lower fee")
	runner.eq(Ecommerce.settlement_fee("international_wire", 864.0), 25.0 + 8.64, "wires keep their price")
	runner.eq(Ecommerce.settlement_fee("escrow", 10000.0), 39.0, "0.6% × 65% on a big order")


# ------------------------------------------------------------------ Chapter 11: the bridge
func _exposed_escrow_order() -> String:
	World.set_year(7)
	GameState.set_flag("escrow_open")
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400, "", false, -1, 1.0, "escrow")
	return str(r["po_id"])


func test_bridge_exploit_freezes_money_in_flight_then_recovers_most_of_it() -> void:
	_setup()
	var id := _exposed_escrow_order()
	var po := _po(id)
	var total := float(po["total"])
	var cash_paid := _cash()
	var x := Rails.exploit()
	runner.check(x["ok"] and Rails.frozen(), "the bridge is exploited")
	runner.eq(Rails.frozen_amount(), total, "the money in flight is frozen")
	runner.eq(_bal("frozen_funds"), total, "it sits in frozen_funds")
	runner.eq(_bal("escrow_held"), 0.0, "no longer in escrow")
	runner.check(Rails.is_frozen_po(po), "the order is on hold")
	runner.check(Ecommerce.settlement_block("escrow") != "" and Ecommerce.settlement_block("stablecoin_settlement") != "", "digital rails are closed")
	runner.eq(Ecommerce.settlement_block("international_wire"), "", "wires still work")
	runner.check(Rails.reliability("escrow") < 0.8, "the rail's record takes a hit")
	var inst := _pending("rail_frozen")
	runner.check(not inst.is_empty(), "a decision is asked")
	runner.check(str(inst["ctx"]["ratio"]) == "90%" and int(inst["ctx"]["count"]) == 1, "the decision says how much comes back")
	runner.check(EventEngine.choose(inst["iid"], "wait")["ok"], "wait it out")
	Clock.advance(3 * Clock.DAY)
	runner.eq(str(po["status"]), "awaiting_payment", "the payment stays stuck while frozen")
	runner.eq(_cash(), cash_paid, "and nothing else moves")
	Clock.advance(3 * Clock.DAY + 60)
	runner.check(Rails.state() == "recovered" and GameState.flag("rail_recovered"), "the bridge reopens after six days")
	runner.eq(_bal("frozen_funds"), 0.0, "frozen funds are settled")
	runner.eq(str(po["status"]), "in_transit", "the supplier ships now")
	runner.eq(_bal("escrow_held"), total, "the payment is back in escrow, in full")
	runner.eq(_cash(), cash_paid - total * 0.1, "the buyer covered the 10% gap")
	runner.eq(_bal("exp:other"), total * 0.1, "and that is the real loss")
	var msgs: Array = GameState.data["messages"].filter(func(m): return m["from"] == "lina" and str(m["text"]).contains("90 cents"))
	runner.check(not msgs.is_empty(), "Lina says honestly what came back and why")
	runner.check(_advance_until(func(): return str(po["status"]) == "delivered"), "the goods arrive")
	runner.eq(_bal("escrow_held"), 0.0, "escrow released")
	runner.eq(_bal("inventory"), total, "stock booked at its full price")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	runner.check(Ecommerce.settlement_block("escrow") == "", "the rail reopened")


func test_rerouting_by_wire_pays_twice_and_gets_the_frozen_money_back() -> void:
	_setup()
	var id := _exposed_escrow_order()
	var po := _po(id)
	var total := float(po["total"])
	var cash0 := _cash()
	Rails.exploit()
	var inst := _pending("rail_frozen")
	var fee := Ecommerce.settlement_fee("international_wire", total)
	runner.check(EventEngine.choice_available(DataDB.events["rail_frozen"]["choices"][1], inst["ctx"]), "reroute is affordable")
	runner.check(EventEngine.choose(inst["iid"], "reroute")["ok"], "paid again by wire")
	runner.eq(_cash(), cash0 - total - fee, "cash pays the order a second time, plus the wire fee")
	runner.eq(str(po["settlement"]["method"]), "international_wire", "now on the wire")
	runner.check(not Rails.is_frozen_po(po), "not stuck any more")
	runner.eq(_bal("frozen_funds"), total, "the first payment is still frozen")
	runner.check(_advance_until(func(): return str(po["status"]) == "in_transit", 7), "the wire lands in days and the supplier ships")
	runner.check(Rails.frozen(), "before the bridge even reopens")
	Clock.advance(7 * Clock.DAY)
	runner.eq(_bal("frozen_funds"), 0.0, "the bridge reopened")
	runner.eq(_cash(), cash0 - total - fee + total * 0.9, "90% of the frozen payment is back in cash")
	runner.eq(_bal("exp:other"), total * 0.1, "10% was lost")
	runner.check(_advance_until(func(): return str(po["status"]) == "delivered"), "the goods arrive")
	runner.eq(_bal("inventory"), total, "stock is booked once")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_bridge_loan_reuses_the_bank_to_fund_the_reroute() -> void:
	_setup()
	# history for Marcus: two weeks of statements and a month of gross profit
	Clock.advance(16 * Clock.DAY)
	Ledger.post(GameState.company_id(), "Sales", [{"acct": "cash", "dr": 10000.0}, {"acct": "revenue", "cr": 10000.0}])
	Clock.advance(5)
	var id := _exposed_escrow_order()
	var total := float(_po(id)["total"])
	Rails.exploit()
	var inst := _pending("rail_frozen")
	runner.check(EventEngine.choice_available(DataDB.events["rail_frozen"]["choices"][2], inst["ctx"]), "Nexus Bank would lend (%s)" % str(inst["ctx"].get("loan", "")))
	var debt0 := Bank.debt(GameState.business_entity())
	var r := EventEngine.choose(inst["iid"], "loan")
	runner.check(r["ok"], "took the bridge loan (%s)" % str(r.get("error", "")))
	runner.check(Bank.debt(GameState.business_entity()) > debt0 + 999.0, "a real Nexus Bank loan is on the books")
	runner.eq(Bank.loans(GameState.business_entity())[0]["months"], 3, "over three months")
	runner.eq(str(_po(id)["settlement"]["method"]), "international_wire", "and the order was rerouted by wire")
	Clock.advance(7 * Clock.DAY)
	runner.eq(_bal("frozen_funds"), 0.0, "the frozen money came back")
	var repaid := Bank.repay(Bank.loans(GameState.business_entity())[0]["id"], 100000.0)
	runner.check(repaid["ok"], "and the loan can be repaid early")
	runner.check(total > 0.0 and Ledger.check_balanced(), "ledger balanced")


func test_digital_dollars_in_flight_freeze_too() -> void:
	_setup()
	World.set_year(7)
	GameState.set_flag("exchange_account")
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400, "", false, -1, 1.0, "stablecoin_settlement")
	var po := _po(r["po_id"])
	var total := float(po["total"])
	runner.eq(_bal("inventory_in_transit"), total, "digital dollars are prepaid, not escrowed")
	Clock.advance(20)   # the payment is still crossing the bridge
	Rails.exploit()
	runner.eq(Rails.frozen_amount(), total, "the stablecoin payment in flight is frozen")
	runner.eq(_bal("inventory_in_transit"), 0.0, "it left the stock-in-transit line")
	runner.eq(_bal("frozen_funds"), total, "and sits in frozen_funds")
	var cash0 := _cash()
	EventEngine.choose(_pending("rail_frozen")["iid"], "wait")
	Clock.advance(6 * Clock.DAY + 60)
	runner.eq(str(po["status"]), "in_transit", "the supplier ships after the reopening")
	runner.eq(_bal("inventory_in_transit"), total, "booked as stock on the way again")
	runner.eq(_cash(), cash0 - total * 0.1, "for a 10% gap the buyer covers")
	runner.check(_advance_until(func(): return str(po["status"]) == "delivered"), "and it arrives")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_a_frozen_payment_can_be_rerouted_later_by_letter_of_credit() -> void:
	_setup()
	var id := _exposed_escrow_order()
	var po := _po(id)
	var total := float(po["total"])
	Rails.exploit()
	EventEngine.choose(_pending("rail_frozen")["iid"], "wait")
	runner.check(not Ecommerce.switch_settlement(id, "stablecoin_settlement")["ok"], "the frozen rail can't rescue its own payment")
	var cash0 := _cash()
	var sw := Ecommerce.switch_settlement(id, "letter_of_credit")   # the Speed-up / Reroute button in Company OS
	runner.check(sw["ok"], "rerouted by letter of credit (%s)" % str(sw.get("error", "")))
	runner.eq(_cash(), cash0 - total - Ecommerce.settlement_fee("letter_of_credit", total), "paid again, with the bank's fee")
	Clock.advance(3 * Clock.DAY)
	runner.eq(str(po["status"]), "in_transit", "the letter of credit lands in two days")
	Clock.advance(4 * Clock.DAY)
	runner.eq(_bal("frozen_funds"), 0.0, "the bridge reopened")
	runner.check(_advance_until(func(): return str(po["status"]) == "delivered"), "the goods arrive")
	runner.eq(_bal("inventory"), total, "stock is booked once")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_a_freeze_survives_saving_and_loading() -> void:
	_setup()
	var id := _exposed_escrow_order()
	var total := float(_po(id)["total"])
	Rails.exploit()
	runner.check(SaveSystem.save(1), "saved mid-freeze")
	runner.check(SaveSystem.load_data(1), "loaded")
	runner.check(Rails.frozen() and Rails.frozen_amount() == total, "still frozen, same amount")
	runner.check(Rails.is_frozen_po(_po(id)), "the order is still on hold")
	EventEngine.choose(_pending("rail_frozen")["iid"], "wait")
	Clock.advance(6 * Clock.DAY + 60)
	runner.check(Rails.state() == "recovered" and str(_po(id)["status"]) == "in_transit", "recovers after the reload")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_lighter_path_when_the_rail_was_never_used() -> void:
	_setup()
	World.set_year(7)
	GameState.set_flag("escrow_open")
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400)   # by wire, the traditional way
	var po := _po(r["po_id"])
	var cash0 := _cash()
	var x := Rails.exploit()
	runner.check(x["ok"] and Rails.frozen(), "the bridge is exploited")
	runner.eq(Rails.frozen_amount(), 0.0, "nothing of yours was crossing it")
	runner.check(_pending("rail_frozen").is_empty(), "no decision to make")
	runner.check(GameState.data["messages"].any(func(m): return m["from"] == "lina" and str(m["text"]).contains("wires only")), "Lina says the supplier is on wires for now")
	runner.check(Ecommerce.settlement_block("escrow") != "", "you adapt: the next order goes by wire")
	Clock.advance(7 * Clock.DAY)
	runner.check(Rails.state() == "recovered", "the freeze ends")
	runner.eq(str(po["status"]), "in_transit", "the wire order carried on")
	runner.eq(_cash(), cash0, "nothing lost")
	runner.eq(_bal("exp:other"), 0.0, "no shortfall")
	runner.check(not Rails.exploit()["ok"], "it only happens once")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_chapter_11_flow_arms_the_exploit_from_the_first_order() -> void:
	_setup()
	StoryEngine.start_chapter("ch11_other_side_of_trust")
	runner.eq(World.year(), 7, "Year 7")
	runner.check(Rails.state() == "none", "not hit yet")
	InfoModal.news().free()
	_check()
	runner.check(_active("ch11_order"), "news read → restock")
	GameState.set_flag("escrow_open")
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400, "", false, -1, 1.0, "escrow")
	_check()
	runner.check(_done("ch11_order") and _active("ch11_freeze"), "order placed → the freeze objective")
	Clock.advance(25)
	runner.check(Rails.frozen(), "the bridge is hit within the hour, while the payment is crossing")
	runner.check(not _pending("rail_frozen").is_empty(), "the decision arrives")
	EventEngine.choose(_pending("rail_frozen")["iid"], "wait")
	Clock.advance(6 * Clock.DAY + 60)
	_check()
	runner.check(_done("ch11_freeze") and _active("ch11_restock"), "freeze over → restock")
	runner.check(_advance_until(func(): return str(_po(r["po_id"])["status"]) == "delivered"), "goods arrive")
	_check()
	runner.check("ch11_other_side_of_trust" in StoryEngine.St()["chapters_done"], "chapter 11 complete")
	runner.check(_active("ch12_news") and World.year() == 8, "chapter 12 opens in Year 8")


func test_the_bridge_is_hit_after_a_week_even_if_you_never_order() -> void:
	_setup()
	StoryEngine.start_chapter("ch11_other_side_of_trust")
	InfoModal.news().free()
	_check()
	Clock.advance(7 * Clock.DAY + 60)
	runner.check(Rails.state() != "none", "the world doesn't wait for you")
	runner.check(_pending("rail_frozen").is_empty(), "and with nothing in flight there is nothing to decide")


# ------------------------------------------------------------------ Chapter 12: compliance
func _year8_with_licence() -> void:
	World.set_year(8)
	var a := Compliance.apply_licence()
	runner.check(a["ok"], "licence applied for (%s)" % str(a.get("error", "")))
	Clock.advance(2 * Clock.DAY + 60)


func test_import_licence_is_an_annual_fee_and_gates_imports() -> void:
	_setup()
	runner.eq(Compliance.import_block("lumina_direct"), "", "no licence needed before Year 8")
	World.set_year(8)
	runner.check(Compliance.import_block("lumina_direct") != "", "imports are blocked without a licence")
	runner.eq(Compliance.import_block("tradelink_wholesale"), "", "local suppliers are not")
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400)
	runner.check(not r["ok"], "the purchase is refused")
	var cash0 := _cash()
	var a := Compliance.apply_licence()
	runner.check(a["ok"], "applied")
	runner.eq(_cash(), cash0 - 450.0, "the fee is $450")
	runner.eq(_bal("exp:registration"), 450.0, "booked as a registration fee")
	runner.check(Compliance.licence_pending() and Compliance.import_block("lumina_direct") != "", "processing takes two days")
	runner.check(not Compliance.apply_licence()["ok"], "no double application")
	Clock.advance(2 * Clock.DAY + 60)
	runner.check(Compliance.licence_valid() and GameState.flag("import_licence"), "granted")
	runner.eq(Compliance.import_block("lumina_direct"), "", "imports are open")
	runner.check(Ecommerce.buy("lumina_direct", "phone_stand", 400)["ok"], "and an import goes through")
	runner.check(not Compliance.apply_licence()["ok"], "no renewal while it has months left")
	# the last two months: renew for another year
	Compliance.S()["licence_until"] = Clock.now() + 50 * Clock.DAY
	var until0 := Compliance.licence_until()
	var rn := Compliance.apply_licence()
	runner.check(rn["ok"] and rn.get("renewed", false), "renewed in the window")
	runner.eq(Compliance.licence_until(), until0 + 365 * Clock.DAY, "for another year")
	runner.eq(_bal("exp:registration"), 900.0, "the annual fee again")
	# a lapsed licence closes imports again
	var lapse := Clock.now() + 3 * Clock.DAY
	Compliance.S()["licence_until"] = lapse
	Clock.advance(4 * Clock.DAY)
	Compliance.handle("cmp.expire", {"until": lapse})
	runner.check(not GameState.flag("import_licence") and Compliance.import_block("lumina_direct") != "", "expired: imports stop")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_kyc_on_large_payments_costs_a_fee_and_a_day() -> void:
	_setup()
	runner.eq(Compliance.kyc(20000.0), {}, "no KYC before Year 8")
	_year8_with_licence()
	runner.eq(Compliance.kyc(2000.0), {}, "small payments skip it")
	runner.eq(Compliance.kyc(2719.0)["fee"], 40.0, "the fee has a $40 floor")
	runner.eq(Compliance.kyc(20000.0)["fee"], 60.0, "and is 0.3% above that")
	runner.eq(int(Compliance.kyc(3000.0)["hours"]), 24, "a day's delay")
	# a big import by wire
	var cash0 := _cash()
	var r := Ecommerce.buy("lumina_direct", "wireless_earbuds", 200)
	runner.check(r["ok"], "large import placed (%s)" % str(r.get("error", "")))
	var po := _po(r["po_id"])
	var total := float(po["total"])
	runner.check(total >= Compliance.kyc_threshold(), "over the threshold ($%s)" % str(total))
	var wire_fee := float(po["settlement"]["fee"])
	runner.eq(_cash(), cash0 - total - wire_fee - 40.0, "cash: order, wire fee and the KYC fee")
	runner.eq(_bal("exp:compliance"), 40.0, "KYC is a compliance expense")
	runner.check(bool(po["settlement"]["kyc"]), "the order carries a KYC check")
	runner.check(int(po["settlement"]["clears"]) - Clock.now() >= 24 * 60 + 72 * 60, "a day more than the wire alone")
	runner.eq(int(GameState.stat("kyc_checks")), 1, "counted")
	runner.check(_advance_until(func(): return str(po["status"]) != "awaiting_payment", 10), "the check passes and the payment lands")
	runner.eq(int(GameState.stat("kyc_cleared")), 1, "KYC cleared")
	# a small one has neither
	var s := Ecommerce.buy("lumina_direct", "phone_stand", 400)
	runner.check(not bool(_po(s["po_id"])["settlement"].get("kyc", false)), "small order: no check")
	runner.eq(_bal("exp:compliance"), 40.0, "and no second fee")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_kyc_holds_even_when_the_payment_is_sped_up() -> void:
	_setup()
	_year8_with_licence()
	GameState.set_flag("exchange_account")
	var r := Ecommerce.buy("lumina_direct", "wireless_earbuds", 200)
	var po := _po(r["po_id"])
	var sw := Ecommerce.switch_settlement(r["po_id"], "letter_of_credit")
	runner.check(sw["ok"], "switched to a letter of credit")
	runner.check(int(po["settlement"]["clears"]) >= Clock.now() + (24 + 48) * 60 - 1, "the KYC day still comes before the letter of credit's two days")


func test_monthly_compliance_cost_appears_on_the_report() -> void:
	_setup()
	runner.eq(Compliance.monthly_cost(), 60.0, "$60 a month with no staff")
	World.set_year(8)
	var m0 := int(Clock.date()["month"])
	var guard := 0
	while int(GameState.stat("compliance_charges")) < 1 and guard < 40:
		Clock.advance(Clock.DAY)
		guard += 1
	runner.eq(int(GameState.stat("compliance_charges")), 1, "charged on the 1st")
	runner.check(int(Clock.date()["month"]) != m0, "of the next month")
	runner.eq(_bal("exp:compliance"), 60.0, "as a compliance expense")
	var rep := MonthClose.compute(GameState.business_entity(), Clock.now() - 2 * Clock.DAY, Clock.now() + 1)
	runner.eq(float(rep["opex"].get("compliance", 0.0)), 60.0, "the report has a compliance line")
	runner.eq(Ledger.category_name("compliance"), "Compliance", "with its own name")
	runner.check(Ledger.check_balanced(), "ledger balanced")


# ------------------------------------------------------------------ the acquisition offer
## A company with real books: sales, costs, and cash.
func _books() -> String:
	var cid := _setup()
	Clock.advance(30 * Clock.DAY)
	Ledger.post(cid, "Sales", [{"acct": "cash", "dr": 12000.0}, {"acct": "revenue", "cr": 12000.0}])
	Ledger.post(cid, "Goods sold", [{"acct": "cogs", "dr": 5000.0}, {"acct": "cash", "cr": 5000.0}])
	Ledger.post(cid, "Ads", [{"acct": "exp:advertising", "dr": 2000.0}, {"acct": "cash", "cr": 2000.0}])
	return cid


func test_acquisition_price_comes_from_the_companys_numbers() -> void:
	var cid := _books()
	var q := Acquisition.quote()
	var k := 365.0 / 90.0
	var profit_year := (12000.0 - 5000.0 - 2000.0) * k
	runner.eq(float(q["profit_year"]), profit_year, "yearly profit is extrapolated from the last 90 days")
	runner.eq(str(q["basis"]), "profit", "priced on profit")
	var expected := snappedf(profit_year * 3.5 + Ledger.cash(cid), 1.0)
	runner.eq(float(q["price"]), expected, "3.5 × profit plus cash, less debts (none)")
	# more profit, higher price
	Ledger.post(cid, "More sales", [{"acct": "cash", "dr": 3000.0}, {"acct": "revenue", "cr": 3000.0}])
	runner.check(float(Acquisition.quote()["price"]) > float(q["price"]), "a better business is worth more")
	# borrowing changes nothing: cash up, debt up
	var p1 := float(Acquisition.quote()["price"])
	Ledger.post(cid, "Loan", [{"acct": "cash", "dr": 5000.0}, {"acct": "loan_payable", "cr": 5000.0}])
	runner.eq(float(Acquisition.quote()["price"]), p1, "the buyer nets debt against cash")
	# stock counts at 80% of cost
	Ledger.post(cid, "Stock", [{"acct": "inventory", "dr": 1000.0}, {"acct": "cash", "cr": 1000.0}])
	runner.eq(float(Acquisition.quote()["price"]), p1 - 1000.0 + 800.0, "stock is valued at 80% of cost")
	# investors take their share
	Effects.apply({"op": "equity_investment", "amount": 10000, "stake": 0.2, "investor": "elena"}, {})
	var q2 := Acquisition.quote()
	runner.eq(float(q2["founder_share"]), 0.8, "the founder holds 80% after Elena")
	runner.eq(float(q2["take"]), snappedf(float(q2["price"]) * 0.8, 0.01), "and takes 80% of the price")


func test_acquisition_falls_back_to_revenue_for_a_thin_profit_business() -> void:
	var cid := _setup()
	Clock.advance(30 * Clock.DAY)
	Ledger.post(cid, "Sales", [{"acct": "cash", "dr": 30000.0}, {"acct": "revenue", "cr": 30000.0}])
	Ledger.post(cid, "Goods sold", [{"acct": "cogs", "dr": 29000.0}, {"acct": "cash", "cr": 29000.0}])
	var q := Acquisition.quote()
	runner.eq(str(q["basis"]), "revenue", "profit is thin: priced on revenue")
	runner.check(float(q["price"]) >= float(Acquisition.cfg()["min_price"]), "never below the minimum offer")


func test_acquisition_of_a_loss_making_company_is_priced_on_its_assets() -> void:
	var cid := _setup()
	Clock.advance(30 * Clock.DAY)
	Ledger.post(cid, "Ads", [{"acct": "exp:advertising", "dr": 3000.0}, {"acct": "cash", "cr": 3000.0}])
	var q := Acquisition.quote()
	runner.eq(str(q["basis"]), "assets", "no earnings to price")
	runner.eq(float(q["price"]), Ledger.cash(cid), "the offer is what the company owns")
	var ctx := Acquisition.context()
	runner.check(str(ctx["basis"]).contains("nothing for earnings"), "and the decision says so plainly")


func test_acquisition_accept_pays_the_founder_and_hands_over_the_company() -> void:
	var cid := _books()
	var inst := EventEngine.trigger("acquisition_offer")   # fired with no context: the offer binds itself
	runner.check(float(inst["ctx"].get("price_v", 0.0)) > 0.0, "the decision carries the price")
	var take := float(inst["ctx"]["take_v"])
	var pers0 := Ledger.cash("player")
	var co0 := Ledger.cash(cid)
	var r := EventEngine.choose(inst["iid"], "accept")
	runner.check(r["ok"], "accepted")
	runner.eq(Ledger.cash("player"), pers0 + take, "the founder's share reaches personal cash")
	runner.eq(Ledger.cash(cid), co0, "the company keeps its own cash")
	runner.check(GameState.flag("company_sold") and GameState.flag("offer_accepted") and GameState.flag("offer_decided"), "flags")
	runner.check(Acquisition.sold(), "sold")
	runner.eq(GameState.data["cap_table"], {"hale_group": 1.0}, "Hale Group owns it")
	runner.check(not Company.transfer(cid, "player", 100.0)["ok"], "no owner withdrawals any more")
	runner.check(not Company.transfer("player", cid, 100.0)["ok"], "and no founder capital either")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_acquisition_counter_pays_part_now_and_an_earn_out_later() -> void:
	var cid := _books()
	var inst := EventEngine.trigger("acquisition_offer")
	var ctx: Dictionary = inst["ctx"]
	var price := float(ctx["price_v"])
	runner.eq(float(ctx["counter_price_v"]), snappedf(price * 1.2, 1.0), "20% more")
	runner.eq(float(ctx["counter_now_v"]), snappedf(float(ctx["counter_price_v"]) * 0.6, 1.0), "60% of it now")
	runner.check(float(ctx["counter_now_v"]) > price * 0.6 and float(ctx["counter_now_v"]) < price * 1.2, "a bigger headline, a smaller cheque today")
	var pers0 := Ledger.cash("player")
	runner.check(EventEngine.choose(inst["iid"], "counter")["ok"], "countered")
	runner.eq(Ledger.cash("player"), pers0 + float(ctx["counter_now_v"]), "the upfront part is paid")
	runner.check(GameState.flag("offer_countered") and GameState.flag("company_sold"), "flags")
	var pend: Array = Sim.pending("acq.earnout")
	runner.eq(pend.size(), 1, "an earn-out is scheduled")
	var due := float(pend[0]["p"]["amount"])
	runner.eq(due, snappedf((float(ctx["counter_price_v"]) - float(ctx["counter_now_v"])) * 1.0, 0.01), "for the rest of the price")
	runner.eq(int(pend[0]["t"]) - Clock.now(), 365 * Clock.DAY, "a year later")
	# revenue held: paid
	Acquisition.handle("acq.earnout", {"amount": due, "base": 0.0})
	runner.eq(Ledger.cash("player"), pers0 + float(ctx["counter_now_v"]) + due, "the earn-out pays when revenue holds")
	runner.check(GameState.flag("earnout_paid"), "flag")
	# revenue fell short: nothing
	var pers1 := Ledger.cash("player")
	Acquisition.handle("acq.earnout", {"amount": due, "base": 1000000.0})
	runner.eq(Ledger.cash("player"), pers1, "and nothing when it doesn't")
	runner.check(GameState.flag("earnout_missed"), "flag")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_acquisition_decline_keeps_the_company() -> void:
	var cid := _books()
	var inst := EventEngine.trigger("acquisition_offer")
	var pers0 := Ledger.cash("player")
	runner.check(EventEngine.choose(inst["iid"], "decline")["ok"], "declined")
	runner.eq(Ledger.cash("player"), pers0, "no money moves")
	runner.check(GameState.flag("offer_declined") and GameState.flag("offer_decided") and not Acquisition.sold(), "still independent")
	runner.check(Company.transfer(cid, "player", 100.0)["ok"], "the founder can still draw money")
	runner.check(Ledger.check_balanced(), "ledger balanced")


# ------------------------------------------------------------------ the whole arc
func test_old_saves_parked_after_chapter_9_carry_on_into_chapter_10() -> void:
	_setup()
	var st := StoryEngine.St()
	st["chapter"] = "ch9_clearing_crisis"
	st["chapters_done"] = ["ch9_clearing_crisis"]
	st["active"] = ["goal_growth"]
	_check()
	runner.check(_active("ch10_news") and not _active("goal_growth"), "the growth goal makes way for Chapter 10")
	runner.eq(World.year(), 6, "Year 6")


## Chapter 9 → 10 → 11 → 12 → the ending → free play, played through the systems (no UI).
func test_chapters_9_to_12_chain_into_free_play() -> void:
	_setup(28000.0)
	var st := StoryEngine.St()
	# ---- chapter 9 (the wire in the Clearing Crisis)
	StoryEngine.start_chapter("ch9_clearing_crisis")
	InfoModal.news().free()
	_check()
	var r9 := Ecommerce.buy("lumina_direct", "wireless_earbuds", 200)
	GameState.set_flag("met_lina")
	_check()
	runner.check(_advance_until(func(): return str(_po(r9["po_id"])["status"]) == "delivered", 40), "the import lands")
	_check()
	runner.check("ch9_clearing_crisis" in st["chapters_done"], "chapter 9 done")
	runner.check(_active("ch10_news") and World.year() == 6, "→ chapter 10, Year 6")
	runner.check(not _active("goal_growth"), "the growth goal waits until the end")
	Ecommerce.liquidate_all(0.4)
	# ---- chapter 10: talk to Lina, use escrow, get it delivered
	InfoModal.news().free()
	_check()
	runner.check(_active("ch10_lina"), "news → Lina")
	var inst := EventEngine.trigger("escrow_offer")
	EventEngine.choose(inst["iid"], "try")
	_check()
	runner.check(_active("ch10_import"), "decided → import")
	var r10 := Ecommerce.buy("lumina_direct", "wireless_earbuds", 200, "", false, -1, 1.0, "escrow")
	_check()
	runner.check(_active("ch10_arrive"), "ordered → delivery")
	runner.check(_advance_until(func(): return str(_po(r10["po_id"])["status"]) == "delivered", 40), "the escrow order lands")
	_check()
	runner.check("ch10_digital_rails" in st["chapters_done"] and int(GameState.stat("escrow_released")) == 1, "chapter 10 done with an escrow release")
	runner.check(_active("ch11_news") and World.year() == 7, "→ chapter 11, Year 7")
	Ecommerce.liquidate_all(0.4)
	# ---- chapter 11: the bridge
	InfoModal.news().free()
	_check()
	var r11 := Ecommerce.buy("lumina_direct", "wireless_earbuds", 200, "", false, -1, 1.0, "escrow")
	_check()
	Clock.advance(25)
	runner.check(Rails.frozen() and not _pending("rail_frozen").is_empty(), "the bridge is hit")
	EventEngine.choose(_pending("rail_frozen")["iid"], "reroute")
	Clock.advance(7 * Clock.DAY)
	_check()
	runner.check(_done("ch11_freeze"), "through the freeze")
	runner.check(_advance_until(func(): return str(_po(r11["po_id"])["status"]) == "delivered", 40), "restocked")
	_check()
	runner.check("ch11_other_side_of_trust" in st["chapters_done"], "chapter 11 done")
	runner.check(_active("ch12_news") and World.year() == 8, "→ chapter 12, Year 8")
	Ecommerce.liquidate_all(0.4)
	# ---- chapter 12: licence, KYC, the offer
	InfoModal.news().free()
	_check()
	runner.check(_active("ch12_licence"), "news → licence")
	Compliance.apply_licence()
	Clock.advance(2 * Clock.DAY + 60)
	_check()
	runner.check(_active("ch12_kyc"), "licensed → a large import")
	var r12 := Ecommerce.buy("lumina_direct", "wireless_earbuds", 200)
	runner.check(r12["ok"], "a large import is placed (%s)" % str(r12.get("error", "")))
	runner.check(_advance_until(func(): return int(GameState.stat("kyc_cleared")) >= 1, 15), "KYC cleared")
	_check()
	runner.check(_active("ch12_offer"), "→ Victor's offer")
	Clock.advance(3 * Clock.DAY + 60)   # the fallback: he calls when you don't visit
	var offer := _pending("acquisition_offer")
	runner.check(not offer.is_empty(), "Victor calls after three days")
	runner.check(not st["chapters_done"].has("ch12_regulation_scale"), "not over until you answer")
	EventEngine.choose(offer["iid"], "decline")
	_check()
	runner.check("ch12_regulation_scale" in st["chapters_done"], "chapter 12 done")
	runner.check(GameState.flag("story_complete"), "the main story is complete")
	runner.check(_active("goal_growth"), "free play: the growth goal")
	runner.check(not GameState.data["timeline"].filter(func(t): return str(t["text"]).contains("The story so far ends here")).is_empty(), "the timeline says so")
	runner.check(Ledger.check_balanced(), "ledger balanced through the whole arc")


func test_each_ending_finishes_the_story() -> void:
	for choice in ["accept", "counter", "decline"]:
		GameState.new_game({"name": "Test Founder", "seed": 4242})
		_books()
		var st := StoryEngine.St()
		st["active"] = []
		StoryEngine.start_chapter("ch12_regulation_scale")
		for oid in ["ch12_news", "ch12_licence", "ch12_kyc"]:
			StoryEngine.complete_objective(oid)
		runner.check(_active("ch12_offer"), "%s: the offer objective is live" % choice)
		var inst := EventEngine.trigger("acquisition_offer")
		EventEngine.choose(inst["iid"], choice)
		_check()
		runner.check("ch12_regulation_scale" in st["chapters_done"] and GameState.flag("story_complete"), "%s: the story ends" % choice)
		runner.check(_active("goal_growth"), "%s: free play follows" % choice)
		runner.check(Ledger.check_balanced(), "%s: ledger balanced" % choice)
