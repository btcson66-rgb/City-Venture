extends Node
## Times each phase of loading a large save: file read + gunzip, JSON parse, validation/decode, migration, state hooks.
## godot --headless --path game -- --bot=loadprobe --file=<absolute slot json>


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--file="):
			path = arg.substr(7)
	if "--resave" in OS.get_cmdline_user_args():
		var d := "user://loadprobe"
		DirAccess.make_dir_recursive_absolute(d)
		SaveSystem.DIR = d
		DirAccess.copy_absolute(path, d.path_join("slot_98.json"))
		SaveSystem.load_data(98)
		var out := OS.get_cmdline_user_args()
		print("RESAVE ", SaveSystem.save_to(d.path_join("slot_77.json"), 77, true), " ", ProjectSettings.globalize_path(d.path_join("slot_77.json")))
		get_tree().quit()
		return
	if "--real" in OS.get_cmdline_user_args():
		var d2 := "user://loadprobe"
		SaveSystem.DIR = d2
		DirAccess.copy_absolute(path, d2.path_join("slot_98.json"))
		for round in 3:
			var t0 := Time.get_ticks_usec()
			var ok0 := SaveSystem.load_data(98)
			print("LOAD real #%d %.0f ms ok=%s" % [round + 1, (Time.get_ticks_usec() - t0) / 1000.0, str(ok0)])
		get_tree().quit()
		return
	var t := Time.get_ticks_usec()
	var text := SaveSystem.read_text(path)
	print("LOAD read+gunzip %.0f ms (%d chars)" % [(Time.get_ticks_usec() - t) / 1000.0, text.length()])
	t = Time.get_ticks_usec()
	var parser := JSON.new()
	parser.parse(text)
	print("LOAD json parse %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	var unpacked: Dictionary = parser.data["data"]
	SaveCodec.unpack(unpacked)
	print("LOAD unpack blobs %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	var decoded := SaveCodec.decode(text, true)
	print("LOAD decode (parse + validation) %.0f ms ok=%s" % [(Time.get_ticks_usec() - t) / 1000.0, str(decoded["ok"])])
	if "--dump" in OS.get_cmdline_user_args():
		var o: Dictionary = decoded["payload"]["data"]["ecommerce"]["orders"]
		var st := {}
		for k in o: st[o[k].get("status")] = st.get(o[k].get("status"), 0) + 1
		print("DUMP ", o.size(), st)
		var i := 0
		for k in o:
			i += 1
			if i in [100, 15000]: print("DUMP ", JSON.stringify(o[k]))
		print("DUMP keys ", decoded["payload"]["data"]["ecommerce"].keys())
	if "--bench" in OS.get_cmdline_user_args():
		var o2: Dictionary = decoded["payload"]["data"]["ecommerce"]["orders"]
		var vb := var_to_bytes(o2)
		var js := JSON.stringify(o2)
		for r in 3:
			var ok := JSON.new()
			t = Time.get_ticks_usec()
			ok.parse(js)
			print("BENCH json.parse %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
			ok = null
			t = Time.get_ticks_usec()
			var back = bytes_to_var(vb)
			print("BENCH b2v %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
			back = null
	t = Time.get_ticks_usec()
	var data: Dictionary = SaveSystem._migrate(decoded["payload"]["data"])
	print("LOAD migrate %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	GameState.data = data
	SaveSystem._restore_lean(GameState.data)
	Contracts.reconcile_closed()
	print("LOAD reconcile_closed %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	Contracts.reconcile_tags()
	print("LOAD reconcile_tags %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	Growth.check(true)
	print("LOAD growth.check %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	t = Time.get_ticks_usec()
	GameState.unpack_rng()
	EventBus.state_loaded.emit()
	print("LOAD unpack+state_loaded %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	# The real entry point, twice: the second load also frees the first load's state, as loading over a running game does.
	var dir := "user://loadprobe"
	DirAccess.make_dir_recursive_absolute(dir)
	SaveSystem.DIR = dir
	DirAccess.copy_absolute(path, dir.path_join("slot_98.json"))
	for round in 2:
		t = Time.get_ticks_usec()
		var ok := SaveSystem.load_data(98)
		print("LOAD load_data #%d %.0f ms ok=%s" % [round + 1, (Time.get_ticks_usec() - t) / 1000.0, str(ok)])
	get_tree().quit()
