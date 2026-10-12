class_name FunLoop
extends RefCounted
## Short goals and bounded event skipping read existing receipts; no synthetic income.

static func cfg() -> Dictionary:
	return DataDB.economy.get("fun_loop", {})

static func progress() -> Dictionary:
	var objective := StoryEngine.main_objective()
	if objective.is_empty(): return {}
	if str(objective.get("id", "")) == "goal_month":
		var listed := mini(2, maxi(int(GameState.stat("listings_active")), int(GameState.stat("listings_created"))))
		return {"value":listed, "max":2, "text":I18n.t("Products listed: %d / 2") % listed}
	var chapter := StoryEngine.chapter_def(str(StoryEngine.St().get("chapter", "")))
	var objectives: Array = chapter.get("objectives", [])
	var done := 0
	for item in objectives:
		if item["id"] in StoryEngine.St()["done"]: done += 1
	return {"value":done, "max":maxi(1, objectives.size()), "text":I18n.t("Small steps: %d / %d") % [done, objectives.size()]}

## Only current waiting steps expose time travel. Query again at activation.
static func next_event() -> int:
	if not GameState.has_game(): return -1
	var objective := StoryEngine.main_objective()
	var id := str(objective.get("id", ""))
	var kinds: Array = {"ch2_stock":["eco.po_arrive"], "ch2_order":["eco.order_place"], "ch2_ship":["eco.pickup"], "ch2_first_dollar":["eco.deliver"], "ch2_issue":["eco.return_request"], "ch4_hire":["stf.applicants"], "ch5_stock":["eco.po_arrive"], "ch5_deliver":["eco.po_arrive"]}.get(id, [])
	if id == "ch4_hire" and not Staff.S()["applicants"].is_empty(): kinds = []
	var next := -1
	for event in GameState.data["schedule"]:
		if str(event["kind"]) in kinds and int(event["t"]) > Clock.now():
			var context := str(event.get("p", {}).get("company_context", GameState.company_id()))
			if context != GameState.company_id(): continue
			if next < 0 or int(event["t"]) < next: next = int(event["t"])
	if id == "ch2_order" and next < 0 and GameState.stat("listings_active") > 0:
		next = Clock.now() - Clock.minute_of_day() % 60 + 60
	if id == "ch4_payroll" and Staff.count() > 0:
		var payroll := Clock.now() - Clock.minute_of_day() + int(Staff.cfg().get("payroll_hour", 17)) * 60
		while payroll <= Clock.now() or Clock.weekday(payroll) != int(Staff.cfg().get("payroll_weekday", 5)): payroll += Clock.DAY
		next = payroll
	var target := DestinationHours.target(objective)
	if target.has("building"):
		var opening := DestinationHours.status(str(target["building"]), str(target.get("npc", "")))
		if not opening["open"] and int(opening["next"]) > Clock.now():
			if next < 0 or int(opening["next"]) < next: next = int(opening["next"])
	return next

const SKIP_MAX_DAYS := 3

## Earliest real deadline after now that a skip must not run past: an unpaid bill coming due, a loan payment or the
## monthly rent day. -1 when none falls inside the window.
static func obligation_deadline(window_end: int) -> int:
	var best := -1
	var t := Clock.now()
	for index in AssistantPolicy.unpaid():
		var due := int(AssistantPolicy.S()["bills"][index].get("due", -1))
		if due > t and due <= window_end and (best < 0 or due < best): best = due
	for loan in Bank.loans():
		var next := int(loan.get("next", -1))
		if next > t and next <= window_end and (best < 0 or next < best): best = next
	if Living.home_rent() > 0.0:
		for d in range(0, SKIP_MAX_DAYS + 1):
			var rent_at := t - Clock.minute_of_day() + d * Clock.DAY + 9 * 60
			if rent_at > t and rent_at <= window_end and int(Clock.date_at(rent_at)["day"]) == int(Living.cfg().get("rent_due_day_of_month", 14)):
				if best < 0 or rent_at < best: best = rent_at
				break
	return best


## What the player must still be able to cover soon: waiting personal bills.
static func personal_obligation() -> float:
	var total := 0.0
	for index in AssistantPolicy.unpaid("player"):
		total += float(AssistantPolicy.S()["bills"][index]["amount"])
	return total


## Advance in small batches, at most three days. Stop for a real decision, new accident, insolvency, a bill, loan or
## rent deadline, or personal cash dropping below what is already owed; all scheduler ticks still run.
static func skip_next() -> bool:
	var next := next_event()
	if next <= Clock.now() or not EventEngine.pending().is_empty() or Insolvency.active(): return false
	# An existing medical bill must not prevent time passing toward recovery or real payouts.
	var accidents: int = TrafficSafety.S()["accidents"].size()
	var window := Clock.now() + mini(int(cfg().get("skip_limit_days", SKIP_MAX_DAYS)), SKIP_MAX_DAYS) * Clock.DAY
	var stop := mini(next, window)
	var deadline := obligation_deadline(stop)
	if deadline > Clock.now(): stop = deadline
	if stop <= Clock.now(): return false
	var covered := Ledger.cash("player") >= personal_obligation()
	while Clock.now() < stop:
		Clock.advance(mini(30, stop - Clock.now()))
		StoryEngine.check()
		if not EventEngine.pending().is_empty() or TrafficSafety.S()["accidents"].size() > accidents or Insolvency.active(): break
		if covered and Ledger.cash("player") < personal_obligation(): break
	return true
