extends RefCounted
## Chapters 4–6 played at the logic level: first hire and payroll, Crestline's big contract with
## Net 60, and bridging the cash gap until the invoice is paid.

var runner


func _check() -> void:
	StoryEngine.check()


func _active(id: String) -> bool:
	return id in StoryEngine.St()["active"]


func _done(id: String) -> bool:
	return id in StoryEngine.St()["done"]


func test_chapters_4_to_6() -> void:
	Company.register("Growth Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(25000.0)
	var cid := GameState.company_id()
	GameState.set_flag("cash_forecast_viewed")   # seen earlier: chapter 4 must retain the receipt
	StoryEngine.start_chapter("ch4_growing_pains")
	runner.check(_active("ch4_employer"), "chapter 4 starts with employer registration")
	Staff.register_employer()
	_check()
	runner.check(_done("ch4_employer") and _active("ch4_post"), "employer registered → post a job")
	Staff.post_job("support")
	_check()
	runner.check(_active("ch4_hire"), "job posted → hire")
	Clock.advance(19 * 60)
	Staff.hire(Staff.S()["applicants"][0]["id"])
	_check()
	runner.check(_active("ch4_payroll"), "hired → first payroll")
	while GameState.stat("payrolls_run") < 1.0:
		Clock.advance(60)
	_check()
	runner.check(_done("ch4_forecast"), "payroll → previously viewed forecast completes")
	runner.check(GameState.flag("cash_forecast_viewed"), "forecast receipt is retained")
	GameState.set_flag("cash_forecast_viewed")
	_check()
	runner.check("ch4_growing_pains" in StoryEngine.St()["chapters_done"], "chapter 4 complete")
	runner.check(_active("ch5_meet"), "chapter 5: meet Daniel")
	# Daniel's offer (the fallback arrives by phone after a few days)
	Clock.advance(6 * Clock.DAY + 60)
	var inst := {}
	for q in EventEngine.pending():
		if q["id"] == "crestline_big_offer":
			inst = q
	runner.check(not inst.is_empty(), "Crestline's offer arrives")
	EventEngine.choose(inst["iid"], "review")
	_check()
	var c := Contracts.by_tag("big_contract")
	runner.eq(str(c.get("status", "")), "offered", "tagged contract offered")
	runner.check(_active("ch5_decide"), "decide")
	runner.check(Contracts.accept(c["id"])["ok"], "accepted")
	_check()
	runner.check(_active("ch5_stock"), "now find the stock")
	# fund it with a loan and supplier stock
	var o := Bank.offer()
	runner.check(o["ok"], "bank will lend against the signed contract: %s" % str(o))
	Bank.take_loan(minf(12000.0, float(o["max"])), 12)
	runner.check(Living.lease("suite_2b")["ok"], "leased Suite 2B for the space")
	var r := Ecommerce.buy("tradelink_wholesale", "desk_lamp", 800, "suite_2b")
	runner.check(r["ok"], "ordered 800 lamps: %s" % str(r))
	_check()
	runner.check(_active("ch5_deliver"), "stock on the way → deliver")
	Clock.advance(4 * Clock.DAY)
	runner.check(Contracts.deliver(c["id"])["ok"], "delivered")
	_check()
	runner.check("ch5_big_contract" in StoryEngine.St()["chapters_done"], "chapter 5 complete")
	runner.check(_active("ch6_forecast"), "chapter 6: forecast")
	GameState.set_flag("forecast_checked_ch6")
	_check()
	runner.check(_done("ch6_bridge"), "loan already taken → gap bridged")
	runner.check(_active("ch6_collect"), "collect")
	runner.check(Contracts.early_payment(c["id"])["ok"], "early payment")
	_check()
	runner.check(_active("ch6_close"), "close a month in the black")
	while not GameState.flag("ch6_month_in_black"):
		Clock.advance(12 * 60)
		if Clock.day_index() > 120:
			break
	_check()
	runner.check("ch6_cash_is_oxygen" in StoryEngine.St()["chapters_done"], "chapter 6 complete")
	runner.check(_active("ch7_news"), "chapter 7 opens with the news")
	runner.eq(World.year(), 3, "the Supply Shock era begins")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	var _u := cid
