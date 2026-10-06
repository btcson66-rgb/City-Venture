extends Node
## Game time. `minutes` = minutes since the start date at 00:00 (2031-06-01, a Sunday).
## Real-time ticking only runs while the player is in the world and nothing pauses it.
## Actions that take time call `advance()` explicitly (management is never free).

signal minute_tick(t: int)
signal hour_tick(t: int, hour: int)
signal day_started(day_index: int)
signal month_ended(year: int, month: int)
signal time_changed()

const DAY := 1440
const WEEKDAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var speed := 1.5            ## game minutes per real second (≈ 11 real minutes per waking day)
## Fast-forward is held, never latched, and still respects every pause reason.
var world_active := false   ## set by SceneRouter when a world scene is live
var _pauses := {}
var _acc := 0.0
var _base_unix := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_unix = int(Time.get_unix_time_from_datetime_dict({"year": 2031, "month": 6, "day": 1, "hour": 0, "minute": 0, "second": 0}))


func now() -> int:
	if not GameState.has_game():
		return 0
	return int(GameState.data["clock"]["minutes"])


func push_pause(reason: String) -> void:
	_pauses[reason] = true


func pop_pause(reason: String) -> void:
	_pauses.erase(reason)


func clear_pauses() -> void:
	_pauses.clear()


func is_paused() -> bool:
	return not _pauses.is_empty() or not world_active


func pause_reasons() -> Array:
	return _pauses.keys()


func _process(delta: float) -> void:
	if not GameState.has_game():
		return
	GameState.data["meta"]["playtime_s"] = float(GameState.data["meta"].get("playtime_s", 0.0)) + delta
	if is_paused():
		_acc = 0.0
		return
	_acc += delta * speed * (2.0 if Input.is_action_pressed("fast_forward") else 1.0)
	var steps := int(_acc)
	if steps > 0:
		_acc -= steps
		for i in steps:
			_tick()
		time_changed.emit()


## Advance game time by `minutes`, running every simulation tick on the way.
func advance(minutes: int) -> void:
	for i in maxi(0, minutes):
		_tick()
	time_changed.emit()


## Advance until the given absolute minute (no-op if already past).
func advance_to(t: int) -> void:
	advance(t - now())


func _tick() -> void:
	var before := now()
	var after := before + 1
	GameState.data["clock"]["minutes"] = after
	var d0 := date_at(before)
	var d1 := date_at(after)
	if d1["day"] != d0["day"]:
		if d1["month"] != d0["month"]:
			month_ended.emit(int(d0["year"]), int(d0["month"]))
		day_started.emit(day_index_at(after))
	if after % 60 == 0:
		hour_tick.emit(after, int((after % DAY) / 60))
	minute_tick.emit(after)


# ------------------------------------------------------------------ calendar
func date_at(t: int) -> Dictionary:
	var d := Time.get_datetime_dict_from_unix_time(_base_unix + t * 60)
	return d


func date() -> Dictionary:
	return date_at(now())


func day_index_at(t: int) -> int:
	return int(t / DAY) + 1


func day_index() -> int:
	return day_index_at(now())


func minute_of_day(t := -1) -> int:
	if t < 0:
		t = now()
	return t % DAY


func hour() -> int:
	return int(minute_of_day() / 60)


func weekday(t := -1) -> int:
	if t < 0:
		t = now()
	return int(date_at(t)["weekday"])


func day_part(t := -1) -> String:
	if t < 0:
		t = now()
	var h := int((t % DAY) / 60)
	if h >= 5 and h < 12:
		return "morning"
	if h >= 12 and h < 17:
		return "afternoon"
	if h >= 17 and h < 21:
		return "evening"
	return "night"


const WEEKDAYS_ZH := ["日", "一", "二", "三", "四", "五", "六"]


func fmt_time(t := -1) -> String:
	if t < 0:
		t = now()
	var m := t % DAY
	var h := int(m / 60)
	var mm := m % 60
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	if I18n.is_zh():
		return "%s %d:%02d" % ["上午" if h < 12 else "下午", h12, mm]
	return "%d:%02d %s" % [h12, mm, "AM" if h < 12 else "PM"]


func month_name(m: int) -> String:
	return ("%d月" % m) if I18n.is_zh() else MONTHS[m - 1]


func fmt_month(y: int, m: int) -> String:
	return ("%d年%d月" % [y, m]) if I18n.is_zh() else "%s %d" % [MONTHS[m - 1], y]


func fmt_date(t := -1) -> String:
	if t < 0:
		t = now()
	var d := date_at(t)
	if I18n.is_zh():
		return "%d月%d日（週%s）" % [int(d["month"]), int(d["day"]), WEEKDAYS_ZH[int(d["weekday"])]]
	return "%s, %s %d" % [WEEKDAYS[int(d["weekday"])], MONTHS[int(d["month"]) - 1], int(d["day"])]


func fmt_datetime(t := -1) -> String:
	return fmt_date(t) + " " + fmt_time(t)


func fmt_short(t: int) -> String:
	var d := date_at(t)
	if I18n.is_zh():
		return "%d月%d日 %s" % [int(d["month"]), int(d["day"]), fmt_time(t)]
	return "%s %d %s" % [MONTHS[int(d["month"]) - 1], int(d["day"]), fmt_time(t)]


## Absolute minute of the next occurrence of `hh:mm` (today if still ahead, else tomorrow).
func next_time_of_day(minute_of_day_v: int) -> int:
	var t := now()
	var start := t - (t % DAY)
	var cand := start + minute_of_day_v
	if cand <= t:
		cand += DAY
	return cand


## Absolute minute of `hh:mm` on the day `days_from_today` ahead.
func at_day_time(days_from_today: int, minute_of_day_v: int) -> int:
	var t := now()
	return t - (t % DAY) + days_from_today * DAY + minute_of_day_v


static func parse_hm(s: String) -> int:
	var p := s.split(":")
	return int(p[0]) * 60 + (int(p[1]) if p.size() > 1 else 0)


func month_start(t := -1) -> int:
	if t < 0:
		t = now()
	var d := date_at(t)
	return t - (int(d["day"]) - 1) * DAY - (t % DAY)


func month_key(t := -1) -> String:
	var d := date_at(now() if t < 0 else t)
	return "%04d-%02d" % [int(d["year"]), int(d["month"])]


## Night factor 0..1 for lighting.
func night_factor(t := -1) -> float:
	if t < 0:
		t = now()
	var m := float(t % DAY) / 60.0
	if m >= 7.0 and m <= 17.5:
		return 0.0
	if m > 17.5 and m < 20.5:
		return (m - 17.5) / 3.0
	if m >= 20.5 or m < 5.0:
		return 1.0
	return 1.0 - (m - 5.0) / 2.0
