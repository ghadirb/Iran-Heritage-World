class_name DifficultyRules
extends RefCounted
## Builds a harder variant of a level at load time, without editing LevelData.
## 0 = easy (the original levels, unchanged), 1 = medium, 2 = challenge.
## Every rule only reshuffles/spreads what already exists, so levels stay finishable.

const NAMES := ["آسان", "متوسط", "چالشی"]
const INTERACT_RADIUS := [4.2, 3.6, 3.0]   # how close the player must stand to interact
const BEAM_RANGE := [9999.0, 40.0, 16.0]   # light beams over clues are only visible this close
const CHAIN_COUNT := [22, 15, 11]          # stone platforms in the chasm (fewer = bigger gaps)
const CHAIN_SWAY := [1.1, 1.8, 2.6]
const FIRE_WORDS := {"fire_red": "رنگ خون", "fire_blue": "رنگ آسمان", "fire_yellow": "رنگ خورشید", "fire_green": "رنگ بهار"}
const FIRE_SEQUENCE := [["fire_red", "fire_blue", "fire_yellow", "fire_green"], ["fire_red", "fire_blue", "fire_yellow", "fire_green"], ["fire_blue", "fire_green", "fire_red", "fire_yellow"]]
const MOVING_STONES := [0, 3, 4]       # how many chasm stones slide sideways
const MOVING_AMP := [0.0, 1.5, 2.2]       # metres either side
const MOVING_SPEED := [0.0, 0.8, 1.1]
const CARRY_SPEED := [0.9, 0.8, 0.68]   # run-speed factor while carrying a log
const LOG_FAR := [0.0, 22.0, 45.0]        # extra metres between logs and the fires
const LOG_WIDE := [1.0, 1.6, 2.2]
const BRIDGE_TRUNKS := [1, 1, 2]       # trunks that must reach the river bank (spares are always added)
const SIDE_FACTORS := [1.0, 0.55, 0.9, 0.7]
const CHASE_SPEED := [4.7, 5.5, 6.0]
const CHASE_START_GAP := [30.0, 25.0, 22.0]
const CHASE_GATE_COUNT := [3, 4, 5]
const CHASE_GAP_WIDTH := [8.0, 6.6, 5.4]
const CHASE_CATCH_RADIUS := [2.0, 2.25, 2.5]
const WATCH_OMEGA := [26.0, 34.0, 44.0]       # beam sweep, degrees per second
const WATCH_HALF := [18.0, 21.0, 24.0]        # beam half-angle, degrees
const WATCH_RANGE := [19.0, 21.0, 23.0]
const WATCH_GRACE := [0.55, 0.4, 0.3]         # seconds in light before being seen
const WIND_COUNT := [3, 4, 5]
const WIND_SPEED := [0.85, 1.15, 1.45]
const WIND_SWEEP := [8.0, 10.0, 12.0]
const WIND_RADIUS := [1.65, 1.9, 2.15]
const ROLL_FINISH_Z := [-88.0, -88.0, -88.0]
const ROLL_MASS := [10.0, 14.0, 18.0]
const ROLL_RAIL_HALF_WIDTH := [4.2, 3.5, 3.0]
const TURNING_BEAM_COUNT := [4, 5, 6]
const TURNING_BEAM_SPEED := [0.25, 0.42, 0.58]
const TURNING_BEAM_ANGLE := [0.16, 0.27, 0.38]
const TURNING_BEAM_WIDTH := [3.1, 2.75, 2.4]
const LAMP_WALK_LIMIT := [4.6, 4.0, 3.6]   # m/s above which oil spills (stick half-way ~3.4)
const LAMP_DRAIN := [0.16, 0.24, 0.34]     # oil per second while running
const LAMP_JUMP_COST := [0.10, 0.18, 0.28]
const LAMP_NEED := [0.10, 0.25, 0.40]      # oil needed at the tower
const MOSAIC_COUNT := [4, 5, 6]            # tiles in the court
const MOSAIC_SEQ_LEN := [3, 4, 5]          # tiles in the order to repeat (never more than the tiles)
const MOSAIC_SHOW_TIME := [1.1, 0.85, 0.65]   # seconds each tile stays lit while the order is shown
const MOSAIC_TILE_RADIUS := [1.6, 1.5, 1.35]

## Challenge mode counts change, so these objective texts avoid numbers.
const CHALLENGE_TEXT := {
	"alborz_foothills": {"objective": "همه‌ی نشانه‌های زرین را در دامنه البرز پیدا کن."},
	"stone_pass": {"objective": "از گذرگاه سنگی بگذر و همه‌ی پرهای سپید را جمع کن."},
	"return_to_plain": {"objective": "همه‌ی درفش‌ها را در دشت پیدا کن و با سام گفت‌وگو کن."},
	"hall_of_questions": {"intro": "در تالار، پایه‌های پرسش برپاست. به هر پایه نزدیک شو و پاسخ درست را برگزین.", "objective": "به همه‌ی پرسش‌ها درباره‌ی تفاوت تاریخ، ادبیات و اسطوره پاسخ بده."},
}

const EXTRA_QUIZZES := [
	{"kind": "quiz", "id": "quiz_4", "title": "پرسش چهارم", "pos": Vector2(6.0, -40.0),
		"question": "زال با چه ویژگی‌ای به دنیا آمد؟",
		"options": ["موی سپید", "چشمان سبز", "بال‌های کوچک"], "answer": 0,
		"explain": "در شاهنامه، زال با موی سپید به دنیا آمد."},
	{"kind": "quiz", "id": "quiz_5", "title": "پرسش پنجم", "pos": Vector2(-6.0, -44.0),
		"question": "سیمرغ هنگام جدایی چه چیزی به زال داد تا در نیاز بسوزاند؟",
		"options": ["تاج زرین", "پر خود", "شمشیر"], "answer": 1,
		"explain": "سیمرغ پری به زال داد تا هرگاه به یاری او نیاز شد، آن را در آتش بنهد."},
]

static func apply(src: Dictionary, d: int) -> Dictionary:
	if d <= 0:
		return src
	var lv: Dictionary = src.duplicate(true)
	lv["difficulty"] = d
	lv["subtitle"] = "%s • %s" % [str(lv["subtitle"]), NAMES[d]]
	if d >= 2 and CHALLENGE_TEXT.has(str(lv["id"])):
		var tx: Dictionary = CHALLENGE_TEXT[str(lv["id"])]
		for k in tx:
			lv[k] = tx[k]
			# Reworded text needs its own recording: documentation/voice-script.csv lists it (VoiceLines).
			lv["voice_" + str(k)] = "%s__%s_d%d" % [str(lv["id"]), str(k), d]
	var items: Array = lv["interactables"]
	if d >= 2:
		_add_extra_clues(lv, items)
		if lv.has("chain"):
			_add_extra_feathers(items)
		if str(lv["id"]) == "hall_of_questions":
			for q in EXTRA_QUIZZES:
				items.insert(items.size() - 1, (q as Dictionary).duplicate(true))   # keep the finale last
	_scatter_clues(lv, items, d)
	if lv.has("chain"):
		_widen_chain(lv, items, d)
	_hide_fire_order(lv, items, d)
	_scatter_logs(lv, items, d)
	_shuffle_quiz_options(items)
	_apply_chase(lv, d)
	_apply_wind_course(lv, d)
	_apply_rolling_course(lv, d)
	_apply_turning_bridge(lv, d)
	_apply_lamp_road(lv, d)
	_apply_mosaic(lv, d)
	_apply_night_watch(lv, d)
	_apply_light(lv, d)
	return lv

## Same route, harder pursuit: less lead, more gates, and narrower safe gaps.
static func _apply_chase(lv: Dictionary, d: int) -> void:
	if not lv.has("chase"):
		return
	var chase: Dictionary = lv["chase"]
	chase["speed"] = CHASE_SPEED[d]
	chase["start_gap"] = CHASE_START_GAP[d]
	chase["gate_count"] = CHASE_GATE_COUNT[d]
	chase["gap_width"] = CHASE_GAP_WIDTH[d]
	chase["catch_radius"] = CHASE_CATCH_RADIUS[d]

static func _apply_wind_course(lv: Dictionary, d: int) -> void:
	if not lv.has("wind_course"):
		return
	var wind: Dictionary = lv["wind_course"]
	wind["count"] = WIND_COUNT[d]
	wind["speed"] = WIND_SPEED[d]
	wind["sweep"] = WIND_SWEEP[d]
	wind["radius"] = WIND_RADIUS[d]

static func _apply_rolling_course(lv: Dictionary, d: int) -> void:
	if not lv.has("rolling_course"):
		return
	var course: Dictionary = lv["rolling_course"]
	course["finish_z"] = ROLL_FINISH_Z[d]
	course["mass"] = ROLL_MASS[d]
	course["rail_half_width"] = ROLL_RAIL_HALF_WIDTH[d]

static func _apply_turning_bridge(lv: Dictionary, d: int) -> void:
	if not lv.has("turning_bridge"):
		return
	var bridge: Dictionary = lv["turning_bridge"]
	bridge["count"] = TURNING_BEAM_COUNT[d]
	bridge["speed"] = TURNING_BEAM_SPEED[d]
	bridge["angle"] = TURNING_BEAM_ANGLE[d]
	bridge["width"] = TURNING_BEAM_WIDTH[d]

static func _apply_lamp_road(lv: Dictionary, d: int) -> void:
	if not lv.has("lamp_road"):
		return
	var lamp: Dictionary = lv["lamp_road"]
	lamp["walk_limit"] = LAMP_WALK_LIMIT[d]
	lamp["drain"] = LAMP_DRAIN[d]
	lamp["jump_cost"] = LAMP_JUMP_COST[d]
	lamp["need"] = LAMP_NEED[d]

## Same court: more tiles, a longer order, a faster show and slightly smaller tiles.
static func _apply_mosaic(lv: Dictionary, d: int) -> void:
	if not lv.has("mosaic"):
		return
	var mosaic: Dictionary = lv["mosaic"]
	mosaic["count"] = MOSAIC_COUNT[d]
	mosaic["seq_len"] = MOSAIC_SEQ_LEN[d]
	mosaic["show_time"] = MOSAIC_SHOW_TIME[d]
	mosaic["tile_radius"] = MOSAIC_TILE_RADIUS[d]

## Same crossing: faster, wider beams; the hardest level adds a second tower to every stretch.
static func _apply_night_watch(lv: Dictionary, d: int) -> void:
	if not lv.has("night_watch"):
		return
	var w: Dictionary = lv["night_watch"]
	w["omega"] = WATCH_OMEGA[d]
	w["half_angle"] = WATCH_HALF[d]
	w["range"] = WATCH_RANGE[d]
	w["grace"] = WATCH_GRACE[d]
	if d >= 2:
		w["towers"] = (w["towers"] as Array) + (w["hard_towers"] as Array)

## Same hall: one, two or three mirrors in the chain (each difficulty has its own layout in the level data).
static func _apply_light(lv: Dictionary, d: int) -> void:
	if not lv.has("light"):
		return
	var light: Dictionary = lv["light"]
	var layouts: Array = light["layouts"]
	light["layout"] = layouts[mini(d, layouts.size() - 1)]

## Clues that sit right on the path are easy to spot; push them off to the sides.
static func _scatter_clues(lv: Dictionary, items: Array, d: int) -> void:
	var valley := float(lv.get("valley_half", 12.0))
	var amp := minf(4.5 if d == 1 else 6.5, valley * 0.55)
	var river_side := 0.0
	if lv.has("river"):
		river_side = signf(float((lv["river"] as Dictionary).get("offset", 0.0)))
	var length := float(lv.get("length", 100.0))
	var n := 0
	for it in items:
		var data: Dictionary = it
		if str(data["kind"]) != "clue" or not data.has("pos"):
			continue
		var side := 1.0 if n % 2 == 0 else -1.0
		if river_side != 0.0:
			side = -river_side   # never hide a clue inside the river
		var p: Vector2 = data["pos"]
		var z := clampf(p.y + (3.0 if n % 2 == 0 else -3.0) * float(d), -(length - 12.0), -8.0)
		data["pos"] = Vector2(side * amp * SIDE_FACTORS[n % 4], z)
		n += 1

## Challenge mode: two more clues placed between the existing ones.
static func _add_extra_clues(lv: Dictionary, items: Array) -> void:
	var clues: Array = []
	for it in items:
		if str((it as Dictionary)["kind"]) == "clue" and (it as Dictionary).has("pos"):
			clues.append(it)
	if clues.size() < 3:
		return
	var banner: bool = str((clues[0] as Dictionary)["id"]).begins_with("banner")
	var names := ["a", "b"]
	for i in range(2):
		var za: float = ((clues[i] as Dictionary)["pos"] as Vector2).y
		var zb: float = ((clues[i + 1] as Dictionary)["pos"] as Vector2).y
		items.insert(items.find(clues[i + 1]), {
			"kind": "clue",
			"id": ("banner_x%s" if banner else "extra_%s") % names[i],
			"title": str((clues[0] as Dictionary)["title"]),
			"pos": Vector2(0.0, (za + zb) * 0.5),
			"hint": "درفش دیگری از کاروان یافتی." if banner else "نشانه‌ی دیگری یافتی.",
		})

static func _add_extra_feathers(items: Array) -> void:
	var at := items.size() - 1   # before the stone tablet (finale)
	items.insert(at, {"kind": "clue", "id": "feather_d", "title": "پر سپید", "on_chain": 4, "hint": "پر دیگری در باد می‌لرزد."})
	items.insert(at + 1, {"kind": "clue", "id": "feather_e", "title": "پر سپید", "on_chain": 10, "hint": "پر دیگری روی سنگ افتاده است."})

## Fewer stones = wider gaps between them. Clue positions on the chain are re-mapped.
static func _widen_chain(lv: Dictionary, items: Array, d: int) -> void:
	var ch: Dictionary = lv["chain"]
	var old_count := int(ch["count"])
	var new_count: int = CHAIN_COUNT[d]
	ch["count"] = new_count
	ch["sway"] = CHAIN_SWAY[d]
	for it in items:
		var data: Dictionary = it
		if data.has("on_chain"):
			var idx := int(data["on_chain"])
			data["on_chain"] = clampi(roundi(float(idx) * float(new_count - 1) / float(old_count - 1)), 0, new_count - 1)
	_pick_moving_stones(ch, items, d, new_count)

## Real platforming: some stones slide sideways. Stones with a clue, and the first/last stone, stay still.
static func _pick_moving_stones(ch: Dictionary, items: Array, d: int, count: int) -> void:
	var taken := {}
	for it in items:
		if (it as Dictionary).has("on_chain"):
			taken[int((it as Dictionary)["on_chain"])] = true
	var free: Array = []
	for i in range(1, count - 1):
		if not taken.has(i):
			free.append(i)
	var want: int = MOVING_STONES[d]
	var moving: Array = []
	if free.size() > 0 and want > 0:
		var step := float(free.size()) / float(want)
		for k in range(mini(want, free.size())):
			moving.append(free[mini(int(float(k) * step), free.size() - 1)])
	ch["moving"] = moving
	ch["move_amp"] = MOVING_AMP[d]
	ch["move_speed"] = MOVING_SPEED[d]

## The fire order is no longer spelled out in plain words; the player must read a riddle.
static func _hide_fire_order(lv: Dictionary, items: Array, d: int) -> void:
	var seq: Array = FIRE_SEQUENCE[d]
	var any := false
	for it in items:
		var data: Dictionary = it
		if str(data["kind"]) == "brazier":
			any = true
			data["order"] = seq.find(str(data["id"]))
	if not any:
		return
	var riddle := "نخست آتشِ %s، سپس %s، آنگاه %s و سرانجام %s." % [FIRE_WORDS[seq[0]], FIRE_WORDS[seq[1]], FIRE_WORDS[seq[2]], FIRE_WORDS[seq[3]]]
	lv["order_hint"] = riddle
	lv["intro"] = "بر بلندای البرز رسیده‌ای. آتش‌ها را به ترتیب این سرنخ روشن کن: " + riddle
	lv["objective"] = "آتش‌ها را به ترتیب سرنخ روشن کن؛ " + riddle + " سپس با سیمرغ سخن بگو."
	lv["voice_intro"] = "%s__intro_d%d" % [str(lv["id"]), d]
	lv["voice_objective"] = "%s__objective_d%d" % [str(lv["id"]), d]
	lv["voice_order_wrong"] = "%s__order_wrong_d%d" % [str(lv["id"]), d]

## Firewood starts farther from the fires and more spread out, so carrying it is a real trip.
static func _scatter_logs(lv: Dictionary, items: Array, d: int) -> void:
	var limit := float(lv.get("valley_half", 12.0)) * 0.9
	for it in items:
		var data: Dictionary = it
		if str(data["kind"]) != "log":
			continue
		var p: Vector2 = data["pos"]
		data["pos"] = Vector2(clampf(p.x * LOG_WIDE[d], -limit, limit), p.y + LOG_FAR[d])

## Answers no longer always sit in the same place.
static func _shuffle_quiz_options(items: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for it in items:
		var data: Dictionary = it
		if str(data["kind"]) != "quiz":
			continue
		var opts: Array = data["options"]
		var correct_text := str(opts[int(data["answer"])])
		var order: Array = range(opts.size())   # order[k] = original index of the option now shown at k
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Variant = order[i]
			order[i] = order[j]
			order[j] = tmp
		var shuffled: Array = []
		for oi in order:
			shuffled.append(opts[int(oi)])
		data["options"] = shuffled
		data["option_ids"] = order   # narration key of option k is <quiz>_opt<option_ids[k]+1>
		data["answer"] = shuffled.find(correct_text)
