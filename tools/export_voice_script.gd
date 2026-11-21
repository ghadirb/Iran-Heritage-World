extends SceneTree
## Generates documentation/voice-script.csv (every narratable sentence, exact file name the game looks for)
## and documentation/voice-missing.csv (only the lines that have NO audio file yet = what to record next).
## Lines come from VoiceLines (single source of truth). Run:
##   godot --headless --path app -s ../tools/export_voice_script.gd
const HEADER := "\ufeffردیف,نام فایل (بدون پسوند),مرحله,نوع,گوینده,صدای پیشنهادی,اولویت,متن\n"

func _has_audio(key: String) -> bool:
	var root := ProjectSettings.globalize_path("res://")
	for ext in ["ogg", "mp3", "wav"]:
		if FileAccess.file_exists(root.path_join("audio/voice/%s.%s" % [key, ext])):
			return true
		if FileAccess.file_exists(root.path_join("../assets-source/audio/%s.%s" % [key, ext])):
			return true
	return false

func _line(f: FileAccess, n: int, r: Dictionary) -> void:
	f.store_csv_line(PackedStringArray([str(n), r["key"], r["level"], r["kind"], r["who"], VoiceLines.VOICES.get(r["who"], ""), str(r["priority"]), r["text"]]))

func _init() -> void:
	var docs := ProjectSettings.globalize_path("res://").path_join("../documentation/")
	var all := FileAccess.open(docs + "voice-script.csv", FileAccess.WRITE)
	var miss := FileAccess.open(docs + "voice-missing.csv", FileAccess.WRITE)
	all.store_string(HEADER)
	miss.store_string(HEADER)
	var rows: Array = VoiceLines.all_lines()
	var chars := 0
	var miss_chars := 0
	var miss_n := 0
	for i in range(rows.size()):
		var r: Dictionary = rows[i]
		_line(all, i + 1, r)
		chars += (r["text"] as String).length()
		if not _has_audio(str(r["key"])):
			miss_n += 1
			miss_chars += (r["text"] as String).length()
			_line(miss, i + 1, r)   # same row number as in voice-script.csv
	all.close()
	miss.close()
	print("lines=%d chars=%d | missing audio: %d lines, %d chars (~%d s)" % [rows.size(), chars, miss_n, miss_chars, miss_chars / 13])
	quit()
