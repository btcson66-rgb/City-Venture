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
	var t := Time.get_ticks_usec()
	var text := SaveSystem.read_text(path)
	print("LOAD read+gunzip %.0f ms (%d chars)" % [(Time.get_ticks_usec() - t) / 1000.0, text.length()])
	t = Time.get_ticks_usec()
	var decoded := SaveCodec.decode(text)
	print("LOAD decode (parse + validation) %.0f ms ok=%s" % [(Time.get_ticks_usec() - t) / 1000.0, str(decoded["ok"])])
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
