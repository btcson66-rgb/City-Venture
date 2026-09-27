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


## Schedule `kind` at absolute minute `t`. Kinds are "<module>.<handler>".
func schedule(t: int, kind: String, payload := {}) -> void:
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
		if s[i]["kind"] == kind and s[i]["p"].get(key) == value:
			s.remove_at(i)


func pending(kind: String) -> Array:
	return GameState.data["schedule"].filter(func(x): return x["kind"] == kind)


func _on_minute(t: int) -> void:
	var s: Array = GameState.data["schedule"]
	var guard := 0
	while not s.is_empty() and int(s[0]["t"]) <= t and guard < 500:
		guard += 1
		var it: Dictionary = s.pop_front()
		_dispatch(it["kind"], it["p"])


func _dispatch(kind: String, p: Dictionary) -> void:
	var mod := kind.get_slice(".", 0)
	match mod:
		"eco":
			Ecommerce.handle(kind, p)
		"con":
			Contracts.handle(kind, p)
		"evt":
			EventEngine.handle(kind, p)
		"liv":
			Living.handle(kind, p)
		"story":
			StoryEngine.handle(kind, p)
		"car":
			Careers.handle(kind, p)
		"stf":
			Staff.handle(kind, p)
		"bank":
			Bank.handle(kind, p)
		_:
			push_warning("Sim: unknown scheduled kind " + kind)


func _on_hour(t: int, h: int) -> void:
	Ecommerce.on_hour(t, h)
	Contracts.on_hour(t, h)
	Living.on_hour(t, h)
	EventEngine.on_hour(t, h)
	Careers.on_hour(t, h)
	Staff.on_hour(t, h)
	Saas.on_hour(t, h)
	_request_story_check()


func _on_month_end(year: int, month: int) -> void:
	var rep := MonthClose.run(year, month)
	EventBus.month_closed.emit(rep)
