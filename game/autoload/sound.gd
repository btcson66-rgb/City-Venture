extends Node
## Music and sound effects. Music follows the scene (menu, district day/night, café, office, home) with
## a crossfade; effects answer UI and game events (button clicks, modals, money in and out, messages,
## objectives, doors). Volumes live in user://settings.cfg (Music / SFX buses). Assets are
## Original compositions and synthesized foley are documented in docs/AUDIO_CREDITS.md.

const SETTINGS := "user://settings.cfg"
const SFX := ["click", "open", "close", "notify", "cash", "spend", "success", "fanfare", "error", "phone", "door", "page"]

var music_volume := 0.8
var sfx_volume := 0.8
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current := ""
var _pool: Array[AudioStreamPlayer] = []
var _cache := {}
var _last := {}
var _headless := false
var _audio_unlocked := not OS.has_feature("web")
var _pending_music := ""
var _ambient_pair: Array[AudioStreamPlayer]=[]
var _ambient_current := ""
var _ambient_front := 0
var _ambient_tween: Tween
var _music_tween: Tween
var _layer_tween: Tween
var _stems_a: Array[AudioStreamPlayer]=[]
var _stems_b: Array[AudioStreamPlayer]=[]
var _intensity := -1
var _context_kind := ""
var _context_id := ""
var _context_elapsed := 0.0
var _mood := ""
var _mood_until := 0
var _generation := 0
var _work_overrides: Dictionary={}
var trace: Array=[]
var tracing := false



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"   # tests and servers: stay silent
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Ambient")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Ambient"),"SFX")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambient"),float(cfg().get("ambience_db",-14)))
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	_apply_volumes()
	_a = _player("Music")
	_b = _player("Music")
	for i in 2:
		_stems_a.append(_player("Music"));_stems_b.append(_player("Music"))
		_ambient_pair.append(_player("Ambient"))
	for i in 8:
		_pool.append(_player("SFX"))
	get_tree().node_added.connect(_on_node_added)
	EventBus.notify.connect(_on_notify)
	EventBus.cash_changed.connect(_on_cash)
	EventBus.ledger_posted.connect(_on_ledger_audio)
	EventBus.message_received.connect(func(_f, _t): play("phone", -4.0))
	EventBus.chapter_completed.connect(func(_c): play("fanfare");set_mood("victory",10))
	EventBus.flag_set.connect(func(flag): if str(flag).contains("upgrade") or str(flag).begins_with("stage_"):play("fanfare",-8))
	EventBus.location_entered.connect(func(kind, _id): if kind == "interior": play("door", -6.0))


func _ensure_bus(n: String) -> void:
	if AudioServer.get_bus_index(n) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, n)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	# Web sample playback can disconnect dynamically created buses; stream uses the mixed output.
	if OS.has_feature("web"):
		p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(p)
	return p


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, music_volume)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), music_volume <= 0.001)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, sfx_volume)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), sfx_volume <= 0.001)


func set_volumes(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	_apply_volumes()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS)


func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		if not ResourceLoader.exists(path):
			return null
		_cache[path] = load(path)
	return _cache[path]


## One-shot effect. Rate-limited per name so bursts (ten toasts at once) don't stack up.
func play(name: String, db := 0.0) -> void:
	if _headless or not _audio_unlocked:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -1000)) < 70:
		return
	_last[name] = now
	var path := "res://assets/audio/sfx/%s.ogg" % name
	var s := _stream(path)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = db
			p.play()
			_trace(path,"SFX","effect:"+name)
			return


func cfg() -> Dictionary:return DataDB.economy.get("audio",{})

func _trace(path: String,bus: String,trigger: String) -> void:
	if tracing:trace.append({"elapsed_ms":Time.get_ticks_msec(),"file":path,"bus":bus,"trigger":trigger})

func _loop(path: String) -> AudioStream:
	var stream := _stream(path)
	if stream is AudioStreamOggVorbis:stream.loop=true
	return stream

## All three stems run together, including silent layers, to keep subsequent intensity changes in sync.
func music(track: String) -> void:
	if track=="menu":
		_context_kind="";_context_id="";_mood_until=0;_work_overrides.clear()
		ambient("")
	if not _audio_unlocked:_pending_music=track;return
	if track==_current or _headless:return
	if is_instance_valid(_music_tween):_music_tween.kill()
	if is_instance_valid(_layer_tween):_layer_tween.kill()
	_generation+=1
	_current=track
	var old := _a;_a=_b;_b=old
	var old_stems := _stems_a;_stems_a=_stems_b;_stems_b=old_stems
	var old_players: Array=[old]+old_stems
	var next_players: Array=[_a]+_stems_a
	var suffixes := ["","_pulse","_lift"]
	var duration := float(cfg().get("crossfade_seconds",1.2))
	_music_tween=create_tween().set_parallel(true)
	_intensity=intensity()
	for i in range(3):
		var player: AudioStreamPlayer=next_players[i]
		var path := "res://assets/audio/music/%s%s.ogg"%[track,suffixes[i]]
		var stream: AudioStream=null if track=="" else _loop(path)
		player.stop();player.stream=stream;player.volume_db=-60
		if stream!=null:
			player.play()
			_music_tween.tween_property(player,"volume_db",layer_db(i,_intensity),duration)
			_trace(path,"Music","track:"+track)
		if old_players[i].playing:_music_tween.tween_property(old_players[i],"volume_db",-60.0,duration)
	var generation := _generation
	_music_tween.chain().tween_callback(func():
		if generation==_generation:
			for player in old_players:player.stop())

func layer_db(layer: int,level: int) -> float:
	return float(cfg().get("music_db",-7)) if layer==0 or level>=layer else -60.0

func intensity() -> int:
	if not GameState.has_game():return 0
	if _mood in ["crisis","roadshow","victory"] and Time.get_ticks_msec()<_mood_until:return 2
	if crisis_active():return 2
	return 1 if Ledger.cash(GameState.business_entity())<float(cfg().get("cash_low_aud",1000)) else 0

func crisis_active() -> bool:
	if not GameState.has_game():return false
	for event in EventEngine.S().get("queue",[]):
		if str(DataDB.events.get(str(event.get("id","")),{}).get("category","")) in cfg().get("crisis_categories",[]):return true
	return false

## Presentation-only mood expires in real time, without saved economic modifiers.
func set_mood(mood: String,seconds: float) -> void:
	_mood=mood;_mood_until=Time.get_ticks_msec()+int(maxf(0,seconds)*1000)
	_refresh_context()

func track_for_scene(kind: String,id: String,night: bool) -> String:
	if Time.get_ticks_msec()<_mood_until and _mood in cfg().get("tracks",[]):return _mood
	if crisis_active():return "crisis"
	if not _work_overrides.is_empty():return str(_work_overrides.values().back())
	if kind=="district":
		if night:return "city_night"
		if GameState.has_game() and int(Clock.date()["month"]) in cfg().get("festival_months",[]):return "season_festival"
		return "founders"
	var type := str(DataDB.building(id).get("type","office"))
	if type=="home":return "city_night" if night else "founders"
	if cfg().get("building_track_ids",{}).has(id):return str(cfg()["building_track_ids"][id])
	if cfg().get("building_tracks",{}).has(type):return str(cfg()["building_tracks"][type])
	var entity: Dictionary=GameState.data.get("entities",{}).get(GameState.company_id(),{}) if GameState.has_game() else {}
	return str(cfg().get("work_tracks",{}).get(str(entity.get("type","consulting")),"consulting"))

func ambient_for_scene(kind: String,id: String,night: bool) -> String:
	if kind=="district":return str(cfg().get("districts",{}).get(id,{}).get("night" if night else "day",""))
	var type := str(DataDB.building(id).get("type","office"))
	return str(cfg().get("room_ids",{}).get(id,cfg().get("room_types",{}).get(type,"office")))

func ambient(track: String) -> void:
	if _headless or not _audio_unlocked or track==_ambient_current:return
	_ambient_current=track
	if is_instance_valid(_ambient_tween):_ambient_tween.kill()
	var old: AudioStreamPlayer=_ambient_pair[_ambient_front]
	_ambient_front=1-_ambient_front
	var next: AudioStreamPlayer=_ambient_pair[_ambient_front]
	next.stop();next.volume_db=-60
	var path := "res://assets/audio/ambient/%s.ogg"%track
	next.stream=null if track=="" else _loop(path)
	_ambient_tween=create_tween().set_parallel(true)
	var duration := float(cfg().get("crossfade_seconds",1.2))
	if next.stream!=null:
		next.play();_ambient_tween.tween_property(next,"volume_db",0.0,duration)
		_trace(path,"Ambient","ambience:"+track)
	if old.playing:_ambient_tween.tween_property(old,"volume_db",-60.0,duration)
	_ambient_tween.chain().tween_callback(func():if old!=_ambient_pair[_ambient_front]:old.stop())

func music_for_scene(kind: String,id: String) -> void:
	_work_overrides.clear()
	_context_kind=kind;_context_id=id
	_refresh_context()

func _refresh_context() -> void:
	if _context_kind=="":return
	var night := GameState.has_game() and Clock.night_factor()>.6
	music(track_for_scene(_context_kind,_context_id,night))
	ambient(ambient_for_scene(_context_kind,_context_id,night))

func _process(delta: float) -> void:
	_context_elapsed+=delta
	if _context_elapsed<float(cfg().get("context_check_seconds",1)):return
	_context_elapsed=0
	_refresh_context()
	var level := intensity()
	if level==_intensity or _headless:return
	_intensity=level
	if is_instance_valid(_layer_tween):_layer_tween.kill()
	_layer_tween=create_tween().set_parallel(true)
	for i in range(2):
		if _stems_a[i].playing:
			_layer_tween.tween_property(_stems_a[i],"volume_db",layer_db(i+1,level),float(cfg().get("layer_fade_seconds",.8)))
			_trace(_stems_a[i].stream.resource_path,"Music","intensity:"+str(level))

## A named work screen gets its own tactile cue; no score or economic state is changed.
func feedback_for(node: Node) -> String:
	var current: Node=node
	while current!=null:
		if current.get_script()!=null:
			var key: String=current.get_script().resource_path.get_file().get_basename()
			if cfg().get("feedback",{}).has(key):return str(cfg()["feedback"][key])
		current=current.get_parent()
	return ""

func _on_node_added(n: Node) -> void:
	if n is Button:
		(n as Button).pressed.connect(func():
			if str(n.name).begins_with("Tab_"):
				var modal := _ancestor_modal(n)
				if modal!=null:
					var id := modal.get_instance_id()
					var industry := str(n.name).trim_prefix("Tab_")
					if cfg().get("work_tracks",{}).has(industry):_work_overrides[id]=str(cfg()["work_tracks"][industry])
					else:_work_overrides.erase(id)
					_refresh_context()
			var cue := feedback_for(n)
			play(cue if cue!="" else "close" if str(n.name) in ["Close","Back","Cancel"] else "success" if n.get_meta("primary_action",false) else "click",-8.0))
	elif n is Modal:
		play("open", -8.0)
		var id := n.get_instance_id()
		var work := str(cfg().get("work_tracks",{}).get(_industry_for_ui(n),""))
		if work!="":_work_overrides[id]=work;_refresh_context()
		(n as Modal).closed.connect(func():
			play("close", -10.0);_work_overrides.erase(id);_refresh_context())
		if str(n.get_script().resource_path).contains("ipo") or str(n.get("title_text")).to_lower().contains("roadshow"):set_mood("roadshow",30)


func _on_notify(_text: String, kind: String, _icon: String) -> void:
	match kind:
		"good":
			play("success", -6.0)
		"bad":
			play("error", -6.0)
		"warn":
			play("error", -10.0)
		"msg":
			pass
		_:
			play("notify", -10.0)


func _on_cash(entity: String, delta: float) -> void:
	if not UIRoot.hud.visible:
		return
	if entity != "player" and entity != GameState.business_entity():
		return
	if delta > 0.0:
		play("cash", -6.0)
	elif delta < 0.0:
		play("spend", -10.0)


func _exit_tree() -> void:
	for p in [_a, _b] + _pool + _ambient_pair + _stems_a + _stems_b:
		if p != null:
			p.stop()
			p.stream = null
	_cache.clear()


func _input(event: InputEvent) -> void:
	if _audio_unlocked:
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_audio_unlocked = true
		music(_pending_music)
		_refresh_context()

## Equipment purchases and completed upgrades already have real journal evidence; audio only observes them.
func _on_ledger_audio(entry: Dictionary) -> void:
	var type := str(entry.get("source",{}).get("type",""))
	if type in ["asset","asset_buy","upgrade"] and entry["lines"].any(func(l):return l["acct"]=="fixed_assets" and float(l.get("dr",0))>0):play("fanfare",-9)

func _ancestor_modal(node: Node) -> Node:
	var current := node.get_parent()
	while current!=null:
		if current is Modal:return current
		current=current.get_parent()
	return null
func _industry_for_ui(node: Node) -> String:
	var key: String=node.get_script().resource_path.get_file().get_basename()
	return {"manufacturing_ui":"manufacturing","real_estate_ui":"real_estate","media_ui":"media","creative_pitch":"media","hotel_ui":"hotel","auction_game":"automotive","energy_ui":"energy"}.get(key,"")
