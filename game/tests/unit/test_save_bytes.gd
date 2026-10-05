extends RefCounted
## Exported saves above GZIP_ABOVE are gzip files; every import path must decode bytes, not text (#98 + #22).

var runner


func test_decode_bytes_reads_plain_and_gzip_saves() -> void:
	GameState.new_game({"name": "Bytes", "seed": 7})
	var text := JSON.stringify(GameState.data)
	var plain := text.to_utf8_buffer()
	var gz := plain.compress(FileAccess.COMPRESSION_GZIP)
	runner.eq(SaveSystem.decode_bytes(plain), text, "plain JSON bytes decode unchanged")
	runner.eq(SaveSystem.decode_bytes(gz), text, "gzip bytes decode to the same JSON")


func test_big_save_file_is_gzip_and_reads_back_for_import() -> void:
	GameState.new_game({"name": "Big", "seed": 8})
	var small := "user://test_small_export.cvsave"
	runner.check(SaveSystem.save_to(small), "a real save envelope is written first")
	var text := SaveSystem.read_text(small)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(small))
	while text.length() <= SaveSystem.GZIP_ABOVE:
		text += " "   # JSON allows trailing whitespace; this only pushes the file over the gzip threshold
	var path := "user://test_big_export.cvsave"
	runner.check(SaveSystem._atomic_write(path, text), "big save written")
	var raw := FileAccess.get_file_as_bytes(path)
	runner.check(raw.size() > 2 and raw[0] == 0x1f and raw[1] == 0x8b, "big save file is gzip")
	runner.eq(SaveSystem.decode_bytes(raw), text, "bytes decode back to the exact save text")
	runner.check(SaveSystem.validate_text(SaveSystem.decode_bytes(raw))["ok"], "decoded big save passes import validation")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
