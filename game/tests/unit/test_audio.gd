extends RefCounted
var runner
func test_every_district_day_night_and_building_type_has_actual_sound() -> void:
	for id in DataDB.districts:
		var day := Sound.ambient_for_scene("district",id,false)
		var night := Sound.ambient_for_scene("district",id,true)
		runner.check(day!="" and night!="" and day!=night,"distinct day/night ambience: "+id)
		for tag in [day,night]:
			var path := "res://assets/audio/ambient/%s.ogg"%tag
			runner.check(ResourceLoader.exists(path),"exists: "+path)
			if ResourceLoader.exists(path):runner.check(load(path).get_length()>=15,"actual loop duration")
	for id in DataDB.buildings:
		var tag := Sound.ambient_for_scene("interior",id,false)
		runner.check(ResourceLoader.exists("res://assets/audio/ambient/%s.ogg"%tag),"building ambience: "+id)
	runner.eq(Sound.ambient_for_scene("interior","unit12_factory",false),"factory","actual factory id")
	runner.eq(Sound.track_for_scene("interior","helio_warehouse",false),"energy_work","actual solar workplace track")

func test_original_compositions_have_three_matching_stems_and_total_audio_budget() -> void:
	runner.check(Sound.cfg()["tracks"].size()>=12,"at least twelve new compositions")
	for tag in Sound.cfg()["tracks"]:
		var length := 0.0
		for suffix in ["","_pulse","_lift"]:
			var path := "res://assets/audio/music/%s%s.ogg"%[tag,suffix]
			runner.check(ResourceLoader.exists(path),"stem exists")
			if not ResourceLoader.exists(path):continue
			var duration: float=load(path).get_length()
			if suffix=="":length=duration
			else:runner.check(absf(length-duration)<.002,"stems loop at identical duration")
	var bytes := 0
	for folder in ["music","ambient","sfx"]:
		for name in DirAccess.get_files_at("res://assets/audio/"+folder):
			if name.ends_with(".ogg"):bytes+=FileAccess.open("res://assets/audio/"+folder+"/"+name,FileAccess.READ).get_length()
	runner.check(bytes<=int(Sound.cfg()["audio_budget_bytes"]),"all audio at most 25 decimal MB")

func test_buses_pool_and_mute_preserve_existing_controls() -> void:
	runner.check(AudioServer.get_bus_index("Music")>=0 and AudioServer.get_bus_index("SFX")>=0 and AudioServer.get_bus_index("Ambient")>=0,"three correct buses")
	runner.eq(AudioServer.get_bus_send(AudioServer.get_bus_index("Ambient")),"SFX","ambience follows existing SFX volume control")
	for player in [Sound._a,Sound._b]+Sound._stems_a+Sound._stems_b:runner.eq(player.bus,"Music","music and stems routed")
	for player in Sound._ambient_pair:runner.eq(player.bus,"Ambient","environment routed")
	var music := Sound.music_volume;var sfx := Sound.sfx_volume
	Sound.music_volume=0;Sound.sfx_volume=0;Sound._apply_volumes()
	runner.check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"both controls mute")
	Sound.music_volume=music;Sound.sfx_volume=sfx;Sound._apply_volumes()

func test_all_seven_work_screens_have_feedback_without_changing_scores() -> void:
	var screens: Array=[ManufacturingUI.new(),RealEstateUI.new(),MediaUI.new(),CreativePitch.new({}),HotelUI.new(),AuctionGame.new(""),EnergyUI.new()]
	for screen in screens:
		var b := Button.new();screen.add_child(b)
		var cue := Sound.feedback_for(b)
		runner.check(cue!="" and ResourceLoader.exists("res://assets/audio/sfx/%s.ogg"%cue),"mapped actual work screen")
		screen.free()

func test_scene_policy_intensity_and_moods_expire() -> void:
	Sound._mood_until=0
	runner.eq(Sound.track_for_scene("district","riverside",true),"city_night","night city composition")
	var queue: Array=EventEngine.S()["queue"].duplicate(true)
	EventEngine.S()["queue"]=[{"id":"energy_typhoon"}]
	runner.eq(Sound.track_for_scene("district","riverside",false),"crisis","actual queued crisis")
	runner.eq(Sound.intensity(),2,"crisis enables all stems")
	EventEngine.S()["queue"]=queue
	Sound._mood="roadshow";Sound._mood_until=Time.get_ticks_msec()+1000
	runner.eq(Sound.track_for_scene("interior","nexus_cowork",false),"roadshow","roadshow presentation cue")
	Sound._mood_until=0
	runner.check(Sound.track_for_scene("interior","nexus_cowork",false)!="roadshow","mood expires instead of persisting")
	runner.check(Ledger.check_balanced(),"audio selection has no economic side effect")

func test_web_gesture_defers_and_unlocks_audio_once() -> void:
	var unlocked := Sound._audio_unlocked;var pending := Sound._pending_music
	Sound._audio_unlocked=false
	Sound.music("founders")
	runner.eq(Sound._pending_music,"founders","before a gesture the requested score is deferred")
	var released := InputEventScreenTouch.new();released.pressed=false
	Sound._input(released)
	runner.check(not Sound._audio_unlocked,"released touch cannot unlock")
	var pressed := InputEventScreenTouch.new();pressed.pressed=true
	Sound._input(pressed)
	runner.check(Sound._audio_unlocked,"real pressed touch unlocks and replays deferred selection")
	Sound._input(pressed)
	runner.check(Sound._audio_unlocked,"subsequent gestures do not reinitialize audio")
	Sound._audio_unlocked=unlocked;Sound._pending_music=pending
