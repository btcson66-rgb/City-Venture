extends Node
## Simulation hub: a persistent time-ordered scheduler plus clock routing to the
## pure-logic modules (Ecommerce, Contracts, EventEngine, StoryEngine, Living, MonthClose).
## Scheduled items live in GameState.data.schedule so they survive save/load.

var _story_check_pending := false


func _ready() -> void:
	Clock.minute_tick.connect(_on_minute)
	Clock.hour_tick.connect(_on_hour)
	Clock.month_ended.connect(_on_month_end)
	EventBus.flag_set.connect(func(_a): _request_story_check())
	EventBus.location_entered.connect(func(_a, _b): _request_story_check())
	EventBus.order_placed.connect(func(_a): _request_story_check())
	EventBus.order_shipped.connect(func(_a): _request_story_check())
	EventBus.order_delivered.connect(func(_a): _request_story_check())
	EventBus.po_placed.connect(func(_a): _request_story_check())
	EventBus.po_arrived.connect(func(_a): _request_story_check())
	EventBus.listing_changed.connect(func(_a): _request_story_check())
	EventBus.company_registered.connect(func(_a): _request_story_check())
	EventBus.dialogue_finished.connect(func(_a): _request_story_check())
	EventBus.interacted.connect(func(_a, _b): _request_story_check())
	EventBus.contract_changed.connect(func(_a): _request_story_check())


func _request_story_check() -> void:
	if _story_check_pending:
		return
	_story_check_pending = true
	call_deferred("_do_story_check")


func _do_story_check() -> void:
	_story_check_pending = false
	if GameState.has_game():
		StoryEngine.check()
		Growth.check()


## Schedule `kind` at absolute minute `t`. Kinds are "<module>.<handler>".
func schedule(t: int, kind: String, payload := {}) -> void:
	payload=payload.duplicate(true)
	if kind.get_slice(".",0) in CompanyPortfolio.cfg()["business_prefixes"] and kind!="bank.appointment": payload["company_context"]=GameState.company_id()
	var s: Array = GameState.data["schedule"]
	var item := {"t": t, "kind": kind, "p": payload}
	var lo := 0
	var hi := s.size()
	while lo < hi:
		var mid := (lo + hi) / 2
		if int(s[mid]["t"]) <= t:
			lo = mid + 1
		else:
			hi = mid
	s.insert(lo, item)


func cancel(kind: String, key: String, value: Variant) -> void:
	var s: Array = GameState.data["schedule"]
	for i in range(s.size() - 1, -1, -1):
		if s[i]["kind"] == kind and s[i]["p"].get(key) == value and str(s[i]["p"].get("company_context",GameState.company_id()))==GameState.company_id():
			s.remove_at(i)


func pending(kind: String) -> Array:
	return GameState.data["schedule"].filter(func(x): return x["kind"] == kind)


func _on_minute(t: int) -> void:
	var _t0 := Time.get_ticks_usec()
	PhoneMessages.on_minute(t)
	Prof.add("minute:phone", Time.get_ticks_usec() - _t0)
	_t0 = Time.get_ticks_usec()
	var s: Array = GameState.data["schedule"]
	var guard := 0
	while not s.is_empty() and int(s[0]["t"]) <= t and guard < 500:
		guard += 1
		var it: Dictionary = s.pop_front()
		_dispatch(it["kind"], it["p"])
	Prof.add("minute:sched", Time.get_ticks_usec() - _t0)


## What the simulation is doing right now (read by the bots' watchdog when the game stops responding).
var phase := ""


func _dispatch(kind: String, p: Dictionary) -> void:
	var owner := str(p.get("company_context",GameState.company_id()))
	if owner!=GameState.company_id():
		CompanyPortfolio.run_in(owner,func():_dispatch_owned(kind,p))
	else: _dispatch_owned(kind,p)

func _dispatch_owned(kind: String,p: Dictionary) -> void:
	phase = kind
	if Industries.dispatch(kind, p):
		return
	var mod := kind.get_slice(".", 0)
	match mod:
		"partners":
			OverseasPartners.handle(kind, p)
		"rail":
			Rails.handle(kind, p)
		"cmp":
			Compliance.handle(kind, p)
		"acq":
			Acquisition.handle(kind, p)
		"job":
			Jobs.handle(kind, p)
		"con":
			Contracts.handle(kind, p)
		"evt":
			EventEngine.handle(kind, p)
		"liv":
			Living.handle(kind, p)
		"story":
			StoryEngine.handle(kind, p)
		"stf":
			Staff.handle(kind, p)
		"bank":
			Bank.handle(kind, p)
		_:
			push_warning("Sim: unknown scheduled kind " + kind)


func _on_hour(t: int, h: int) -> void:
	phase = "hour:macro"
	var _t0=Time.get_ticks_usec()
	Macro.on_hour(t, h)
	Prof.add("Macro.on_hour",Time.get_ticks_usec()-_t0)
	if CompanyPortfolio.is_multi():
		for id in CompanyPortfolio.ids(): CompanyPortfolio.run_in(str(id),func():_company_hour(t,h))
	else:
		_single_company_hour(t,h)
		HoldingGroups.on_hour()
		return
	var _t0=Time.get_ticks_usec()
	HoldingGroups.on_hour()
	Prof.add("HoldingGroups.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Industries.on_hour_global(t,h)
	Prof.add("Industries.on_hour_globalt,h)",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Living.on_hour(t,h)
	Prof.add("Living.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	EventEngine.on_hour(t,h)
	Prof.add("EventEngine.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Industries.on_hour(t,h,"careers")
	Prof.add("Industries.on_hourt,h,'careers')",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Milestones.on_hour(t,h)
	Prof.add("Milestones.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Replay.on_hour(t, h)
	Prof.add("Replay.on_hour",Time.get_ticks_usec()-_t0)
	Growth.check()
	_request_story_check()
	phase=""

func _single_company_hour(t: int, h: int) -> void:
	var _t0=Time.get_ticks_usec()
	OverseasPartners.on_hour()
	Prof.add("OverseasPartners.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	LegacyBusiness.on_hour()
	Prof.add("LegacyBusiness.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	CapitalMarket.on_hour()
	Prof.add("CapitalMarket.on_hour",Time.get_ticks_usec()-_t0)
	Growth.check()
	phase = "hour:compliance"
	var _t0=Time.get_ticks_usec()
	Compliance.on_hour(t, h)
	Prof.add("Compliance.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:ecommerce"
	var _t0=Time.get_ticks_usec()
	Industries.on_hour(t, h, "sales")
	Prof.add("Industries.on_hourt, h, 'sales')",Time.get_ticks_usec()-_t0)
	phase = "hour:contracts"
	var _t0=Time.get_ticks_usec()
	Contracts.on_hour(t, h)
	Prof.add("Contracts.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:living"
	var _t0=Time.get_ticks_usec()
	Living.on_hour(t, h)
	Prof.add("Living.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	TrafficSafety.on_hour(t, h)
	Prof.add("TrafficSafety.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:events"
	var _t0=Time.get_ticks_usec()
	EventEngine.on_hour(t, h)
	Prof.add("EventEngine.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:careers"
	var _t0=Time.get_ticks_usec()
	Industries.on_hour(t, h, "careers")
	Prof.add("Industries.on_hourt, h, 'careers')",Time.get_ticks_usec()-_t0)
	phase = "hour:staff"
	var _t0=Time.get_ticks_usec()
	Staff.on_hour(t, h)
	Prof.add("Staff.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:saas"
	var _t0=Time.get_ticks_usec()
	Industries.on_hour(t, h, "business")
	Prof.add("Industries.on_hourt, h, 'business')",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Assets.on_hour(t, h)
	Prof.add("Assets.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Jobs.on_hour(t, h)
	Prof.add("Jobs.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:group"
	var _t0=Time.get_ticks_usec()
	InternalSupply.on_hour(t, h)
	Prof.add("InternalSupply.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	GroupJobs.on_hour(t, h)
	Prof.add("GroupJobs.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Milestones.on_hour(t, h)
	Prof.add("Milestones.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:scenario"
	var _t0=Time.get_ticks_usec()
	Replay.on_hour(t, h)
	Prof.add("Replay.on_hour",Time.get_ticks_usec()-_t0)
	phase = "hour:story"
	_request_story_check()
	phase = ""


func _company_hour(t: int,h: int) -> void:
	var _t0=Time.get_ticks_usec()
	OverseasPartners.on_hour()
	Prof.add("OverseasPartners.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	LegacyBusiness.on_hour()
	Prof.add("LegacyBusiness.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	CapitalMarket.on_hour()
	Prof.add("CapitalMarket.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Compliance.on_hour(t,h)
	Prof.add("Compliance.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Industries.on_hour(t,h,"sales")
	Prof.add("Industries.on_hourt,h,'sales')",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Contracts.on_hour(t,h)
	Prof.add("Contracts.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Staff.on_hour(t,h)
	Prof.add("Staff.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Industries.on_hour(t,h,"business",true)
	Prof.add("Industries.on_hourt,h,'business',true)",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Assets.on_hour(t,h)
	Prof.add("Assets.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	Jobs.on_hour(t,h)
	Prof.add("Jobs.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	InternalSupply.on_hour(t,h)
	Prof.add("InternalSupply.on_hour",Time.get_ticks_usec()-_t0)
	var _t0=Time.get_ticks_usec()
	GroupJobs.on_hour(t,h)
	Prof.add("GroupJobs.on_hour",Time.get_ticks_usec()-_t0)


func _on_month_end(year: int, month: int) -> void:
	var _t0 := Time.get_ticks_usec()
	var rep := MonthClose.run(year, month)
	Prof.add("month_close", Time.get_ticks_usec() - _t0)
	EventBus.month_closed.emit(rep)
