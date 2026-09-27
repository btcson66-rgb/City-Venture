extends RefCounted
## Every script in the project must compile.

var runner


func _collect(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sd in d.get_directories():
		_collect(dir + "/" + sd, out)


func test_all_scripts_compile() -> void:
	var files: Array = []
	for root in ["res://scripts", "res://autoload", "res://tests/walkthrough"]:
		_collect(root, files)
	for f in files:
		var s: GDScript = load(f)
		runner.check(s != null and s.can_instantiate(), "compiles: " + f)
