extends SceneTree
## Generates documentation/voice-script.csv: every sentence that can be narrated,
## with the exact file name the game looks for.
## Run: godot --headless --path app -s ../tools/export_voice_script.gd
const VOICES := {
	"راوی": "نیکو (زن) - روایتگر و قصه‌گو",
	"دانشنامه": "دانا (مرد) - خبری و آموزنده",
	"سیمرغ": "مهتاب (زن) - نجواگر و آرامش‌بخش",
	"سام": "بهرام (مرد) - حماسی و نافذ",
	"سنگ‌نوشته": "شهاب (مرد) - قدرتمند و رسا",
	"راهنمای تالار": "آرتین (مرد) - با اصالت و شیک",
}

var rows: Array = []

func _add(level_id: String, key: String, kind: String, who: String, text: String, priority: int) -> void:
	rows.append([rows.size() + 1, "%s__%s" % [level_id, key], level_id, kind, who, VOICES.get(who, ""), priority, text.replace("\n", " ").strip_edges()])

func _init() -> void:
	for level in LevelData.LEVELS:
		var lid := str(level["id"])
		_add(lid, "intro", "معرفی مرحله", "راوی", str(level["intro"]), 1)
		_add(lid, "objective", "هدف مرحله", "راوی", str(level["objective"]), 1)
		for d in level["interactables"]:
			var id := str(d["id"])
			match str(d["kind"]):
				"clue":
					_add(lid, "hint_" + id, "سرنخ (فقط حالت خودکار)", "راوی", str(d["hint"]), 2)
				"quiz":
					_add(lid, id + "_q", "پرسش", "دانشنامه", str(d["question"]), 1)
					_add(lid, id + "_explain", "توضیح پاسخ", "دانشنامه", str(d["explain"]), 1)
				"npc":
					var who := str(d["speaker"])
					var lines: Array = d["lines"]
					for i in range(lines.size()):
						_add(lid, "%s_L%d" % [id, i + 1], "گفت‌وگو", who, str(lines[i]), 1)
					var choices: Array = d.get("choices", [])
					for j in range(choices.size()):
						_add(lid, "%s_R%d" % [id, j + 1], "پاسخ به گزینه %d" % (j + 1), who, str(choices[j]["reply"]), 1)
					var after: Array = d.get("after", [])
					for k in range(after.size()):
						_add(lid, "%s_A%d" % [id, k + 1], "ادامه گفت‌وگو", who, str(after[k]), 1)
		var kn: Dictionary = level["knowledge"]
		_add(lid, "knowledge", "دانشنامه", "دانشنامه", str(kn["text"]), 1)
	var out := ProjectSettings.globalize_path("res://").path_join("../documentation/voice-script.csv")
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\ufeffردیف,نام فایل (بدون پسوند),مرحله,نوع,گوینده,صدای پیشنهادی,اولویت,متن\n")
	var chars := 0
	var chars1 := 0
	for r in rows:
		f.store_csv_line(PackedStringArray([str(r[0]), r[1], r[2], r[3], r[4], r[5], str(r[6]), r[7]]))
		chars += (r[7] as String).length()
		if int(r[6]) == 1:
			chars1 += (r[7] as String).length()
	f.close()
	print("lines=%d chars=%d (essential chars=%d) ~%d s audio" % [rows.size(), chars, chars1, chars / 13])
	quit()
