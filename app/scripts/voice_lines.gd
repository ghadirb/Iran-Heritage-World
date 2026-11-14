class_name VoiceLines
extends RefCounted
## Single source of truth for every sentence that can be narrated. Used by the CSV export tool
## (tools/export_voice_script.gd) and by the self-test (reports lines that have no audio yet).
## Row: {key, level, kind, who, text, priority, base}. `base` rows are the original (easy) lines;
## the rest are difficulty variants and newer lines, appended AFTER the base rows so old row numbers stay stable.

const VOICES := {
	"راوی": "نیکو (زن) - روایتگر و قصه‌گو",
	"دانشنامه": "دانا (مرد) - خبری و آموزنده",
	"سیمرغ": "مهتاب (زن) - نجواگر و آرامش‌بخش",
	"سام": "بهرام (مرد) - حماسی و نافذ",
	"سنگ‌نوشته": "شهاب (مرد) - قدرتمند و رسا",
	"راهنمای تالار": "آرتین (مرد) - با اصالت و شیک",
	"نگهبان دروازه": "کامیار (مرد) - مصمم و جدی",
	"آرش": "آرش (مرد) - مطمئن و تاثیرگذار",
}

static func _row(rows: Array, seen: Dictionary, lid: String, key: String, kind: String, who: String, text: String, priority: int, base: bool) -> void:
	var full := "%s__%s" % [lid, key]
	if seen.has(full):
		return
	seen[full] = true
	rows.append({"key": full, "level": lid, "kind": kind, "who": who, "text": text.replace("\n", " ").strip_edges(), "priority": priority, "base": base})

static func _interactable_rows(rows: Array, seen: Dictionary, lid: String, items: Array, only_new_than: Array, base: bool, tag: String) -> void:
	for d in items:
		var id := str(d["id"])
		if only_new_than.has(id):
			continue
		match str(d["kind"]):
			"clue":
				_row(rows, seen, lid, "hint_" + id, "سرنخ (فقط حالت خودکار)" + tag, "راوی", str(d["hint"]), 2, base)
			"quiz":
				_row(rows, seen, lid, id + "_q", "پرسش" + tag, "دانشنامه", str(d["question"]), 1, base)
				_row(rows, seen, lid, id + "_explain", "توضیح پاسخ" + tag, "دانشنامه", str(d["explain"]), 1, base)
			"npc":
				var who := str(d["speaker"])
				var lines: Array = d["lines"]
				for i in range(lines.size()):
					_row(rows, seen, lid, "%s_L%d" % [id, i + 1], "گفت‌وگو", who, str(lines[i]), 1, base)
				var choices: Array = d.get("choices", [])
				for j in range(choices.size()):
					_row(rows, seen, lid, "%s_R%d" % [id, j + 1], "پاسخ به گزینه %d" % (j + 1), who, str(choices[j]["reply"]), 1, base)
				var after: Array = d.get("after", [])
				for k in range(after.size()):
					_row(rows, seen, lid, "%s_A%d" % [id, k + 1], "ادامه گفت‌وگو", who, str(after[k]), 1, base)

## Reading the answer options aloud: key <quiz>_opt<N>, N = original option number (stable under shuffling).
static func _option_rows(rows: Array, seen: Dictionary, lid: String, items: Array, tag: String) -> void:
	for d in items:
		if str(d["kind"]) != "quiz":
			continue
		var ids: Array = d.get("option_ids", [])
		var opts: Array = d["options"]
		var pairs: Array = []
		for j in range(opts.size()):
			pairs.append([(int(ids[j]) if j < ids.size() else j), str(opts[j])])
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
		for p in pairs:
			_row(rows, seen, lid, "%s_opt%d" % [str(d["id"]), int(p[0]) + 1], "گزینه‌ی پرسش" + tag, "دانشنامه", str(p[1]), 1, false)

## Short in-game messages that are not story text (see GameMessages). Level-independent ones use level "game".
static func _message_rows(rows: Array, seen: Dictionary) -> void:
	for id in GameMessages.TEXT:
		_row(rows, seen, "game", str(id), "پیام کوتاه بازی", "راوی", str(GameMessages.TEXT[id]), 2, false)
	for level in LevelData.LEVELS:
		var lid := str(level["id"])
		var finale_title := ""
		for d in level["interactables"]:
			match str(d["kind"]):
				"brazier":
					_row(rows, seen, lid, "fire_lit_" + str(d["id"]), "پیام کوتاه بازی (آتش روشن شد)", "راوی", GameMessages.FIRE_LIT % str(d["title"]), 2, false)
				"npc":
					if bool(d.get("finale", false)):
						finale_title = str(d["title"])
						_row(rows, seen, lid, "%s_locked" % str(d["id"]), "پیام کوتاه بازی (هنوز زود است)", "راوی", str(d["hint"]), 2, false)
		if finale_title != "":
			_row(rows, seen, lid, "go_finale", "پیام کوتاه بازی (برو سراغ شخصیت)", "راوی", GameMessages.GO_FINALE % finale_title, 2, false)

static func all_lines() -> Array:
	var rows: Array = []
	var seen := {}
	# 1) original lines (identical order to the first version of the script)
	for level in LevelData.LEVELS:
		var lid := str(level["id"])
		_row(rows, seen, lid, "intro", "معرفی مرحله", "راوی", str(level["intro"]), 1, true)
		_row(rows, seen, lid, "objective", "هدف مرحله", "راوی", str(level["objective"]), 1, true)
		_interactable_rows(rows, seen, lid, level["interactables"], [], true, "")
		_row(rows, seen, lid, "knowledge", "دانشنامه", "دانشنامه", str((level["knowledge"] as Dictionary)["text"]), 1, true)
	# 2) newer lines: mechanic hints, then each harder variant (text that differs + items that do not exist on easy)
	for level in LevelData.LEVELS:
		var lid := str(level["id"])
		if level.has("intro_extra"):
			_row(rows, seen, lid, str(level.get("intro_extra_key", "intro_extra")), "جمله‌ی راهنمای مکانیک (بعد از معرفی)", "راوی", str(level["intro_extra"]), 1, false)
		var base_ids: Array = []
		for d in level["interactables"]:
			base_ids.append(str(d["id"]))
		for diff in [1, 2]:
			var v: Dictionary = DifficultyRules.apply(level, diff)
			var tag := " (سختی %s)" % DifficultyRules.NAMES[diff]
			if str(v["intro"]) != str(level["intro"]):
				_row(rows, seen, lid, "intro_d%d" % diff, "معرفی مرحله" + tag, "راوی", str(v["intro"]), 1, false)
			if str(v["objective"]) != str(level["objective"]):
				_row(rows, seen, lid, "objective_d%d" % diff, "هدف مرحله" + tag, "راوی", str(v["objective"]), 1, false)
			_interactable_rows(rows, seen, lid, v["interactables"], base_ids, false, tag)
	# 3) answer options read aloud + short in-game messages (appended last: rows above keep their numbers)
	for level in LevelData.LEVELS:
		var lid := str(level["id"])
		_option_rows(rows, seen, lid, level["interactables"], "")
		if _has_kind(level, "brazier"):
			_row(rows, seen, lid, "order_wrong", "پیام کوتاه بازی (ترتیب آتش‌ها اشتباه بود)", "راوی", GameMessages.wrong_order(level), 2, false)
		for diff in [1, 2]:
			var v: Dictionary = DifficultyRules.apply(level, diff)
			var tag := " (سختی %s)" % DifficultyRules.NAMES[diff]
			_option_rows(rows, seen, lid, v["interactables"], tag)
			if v.has("order_hint"):
				_row(rows, seen, lid, "order_wrong_d%d" % diff, "پیام کوتاه بازی (ترتیب آتش‌ها اشتباه بود)" + tag, "راوی", GameMessages.wrong_order(v), 2, false)
	_message_rows(rows, seen)
	return rows

static func _has_kind(level: Dictionary, kind: String) -> bool:
	for d in level["interactables"]:
		if str(d["kind"]) == kind:
			return true
	return false
