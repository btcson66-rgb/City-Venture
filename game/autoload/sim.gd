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


## Deterministic cap per minute tick; surplus due events run on the next tick (only a saturated company ever reaches it).
const MAX_EVENTS_PER_MINUTE := 120


func _on_minute(t: int) -> void:
	PhoneMessages.on_minute(t)
	var s: Array = GameState.data["schedule"]
	var guard := 0
	while not s.is_empty() and int(s[0]["t"]) <= t and guard < MAX_EVENTS_PER_MINUTE:
		guard += 1
		var it: Dictionary = s.pop_front()
		var t0 := Time.get_ticks_usec() if Prof.enabled else 0
		_dispatch(it["kind"], it["p"])
		if Prof.enabled: Prof.add("ev:" + str(it["kind"]), Time.get_ticks_usec() - t0)


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
	if h == 0:
		var t0 := Time.get_ticks_usec() if Prof.enabled else 0
		Ledger.compact_old(t)
		if Prof.enabled: Prof.add("ledger_compact", Time.get_ticks_usec() - t0)
	phase = "hour:macro"
	Macro.on_hour(t, h)
	if CompanyPortfolio.is_multi():
		for id in CompanyPortfolio.ids(): CompanyPortfolio.run_in(str(id),func():_company_hour(t,h))
	else:
		_single_company_hour(t,h)
		HoldingGroups.on_hour()
		return
	HoldingGroups.on_hour()
	Industries.on_hour_global(t,h)
	Living.on_hour(t,h)
	EventEngine.on_hour(t,h)
	Industries.on_hour(t,h,"careers")
	Milestones.on_hour(t,h)
	Replay.on_hour(t, h)
	Growth.check()
	_request_story_check()
	phase=""

func _single_company_hour(t: int, h: int) -> void:
	if h == 0:
		_archive_orders(t)
	OverseasPartners.on_hour()
	LegacyBusiness.on_hour()
	CapitalMarket.on_hour()
	Growth.check()
	phase = "hour:compliance"
	Compliance.on_hour(t, h)
	phase = "hour:ecommerce"
	Industries.on_hour(t, h, "sales")
	phase = "hour:contracts"
	Contracts.on_hour(t, h)
	phase = "hour:living"
	Living.on_hour(t, h)
	TrafficSafety.on_hour(t, h)
	phase = "hour:events"
	EventEngine.on_hour(t, h)
	phase = "hour:careers"
	Industries.on_hour(t, h, "careers")
	phase = "hour:staff"
	Staff.on_hour(t, h)
	phase = "hour:saas"
	Industries.on_hour(t, h, "business")
	Assets.on_hour(t, h)
	Jobs.on_hour(t, h)
	phase = "hour:group"
	InternalSupply.on_hour(t, h)
	GroupJobs.on_hour(t, h)
	Milestones.on_hour(t, h)
	phase = "hour:scenario"
	Replay.on_hour(t, h)
	phase = "hour:story"
	_request_story_check()
	phase = ""


func _archive_orders(t: int) -> void:
	var t0 := Time.get_ticks_usec() if Prof.enabled else 0
	Ecommerce.archive_settled(t)
	if Prof.enabled: Prof.add("order_archive", Time.get_ticks_usec() - t0)


func _company_hour(t: int,h: int) -> void:
	if h == 0:
		_archive_orders(t)
	OverseasPartners.on_hour()
	LegacyBusiness.on_hour()
	CapitalMarket.on_hour()
	Compliance.on_hour(t,h)
	Industries.on_hour(t,h,"sales")
	Contracts.on_hour(t,h)
	Staff.on_hour(t,h)
	Industries.on_hour(t,h,"business",true)
	Assets.on_hour(t,h)
	Jobs.on_hour(t,h)
	InternalSupply.on_hour(t,h)
	GroupJobs.on_hour(t,h)


func _on_month_end(year: int, month: int) -> void:
	var rep := MonthClose.run(year, month)
	EventBus.month_closed.emit(rep)
