extends RefCounted
## SaaS: build the MVP with dev hours, launch, subscribers/MRR/churn/servers, features, pricing.

var runner


func test_build_launch_and_grow() -> void:
	runner.check(Saas.start("freelancer_invoicing")["ok"], "started")
	runner.check(not Saas.launch()["ok"], "can't launch before the MVP is built")
	var t0 := Clock.now()
	Saas.add_dev(2.0, true)
	runner.eq(Clock.now() - t0, 120, "a founder session takes two hours")
	Saas.add_dev(Saas.dev_needed(), false)
	runner.check(Saas.launch()["ok"], "launched")
	var cash0 := Ledger.cash("player")
	Clock.advance(30 * Clock.DAY)
	var s := Saas.S()
	runner.check(int(s["subs"]) > 10, "subscribers after a month (%d)" % int(s["subs"]))
	runner.check(-Ledger.balance("player", "revenue") > 0.0, "subscription revenue booked")
	runner.check(Ledger.balance("player", "exp:servers") > 0.0, "server costs booked")
	runner.check(Ledger.balance("player", "exp:platform_fees") > 0.0, "card processor fees booked")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	var _u := cash0


func test_price_moves_signups_and_features_cut_churn() -> void:
	Saas.start("salon_booking")
	Saas.add_dev(Saas.dev_needed(), false)
	Saas.launch()
	Saas.set_price(19.0)
	var cheap := Saas.signup_rate()
	Saas.set_price(49.0)
	var dear := Saas.signup_rate()
	runner.check(cheap > dear, "cheaper → more signups (%.2f vs %.2f)" % [cheap, dear])
	var c0 := Saas.monthly_churn()
	var r := Saas.add_dev(float(Saas.cfg()["feature_hours"]), false)
	runner.check(str(r.get("shipped", "")) != "", "a feature shipped")
	runner.check(Saas.monthly_churn() < c0, "features reduce churn")


func test_developers_build_while_you_sleep() -> void:
	Company.register("Code Co", "saas", "22 Founders Lane")
	Company.open_business_account(20000.0)
	Staff.register_employer()
	Staff.post_job("developer")
	Clock.advance(19 * 60)
	Staff.hire(Staff.S()["applicants"][0]["id"])
	Saas.start("shop_inventory")
	Clock.advance(7 * Clock.DAY)
	runner.check(float(Saas.S()["dev_done"]) > 10.0, "developer added dev hours (%.1f)" % float(Saas.S()["dev_done"]))
