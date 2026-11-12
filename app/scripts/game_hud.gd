extends CanvasLayer
class_name GameHUD
## All 2D interface: HUD, dialogue, quiz, menus. Built in code so the project
## has no binary UI assets. Persian text is right-to-left.

signal jump_pressed
signal interact_pressed
signal shoot_pressed
signal look_delta(relative: Vector2)
signal start_level(index: int)
signal restart_requested
signal main_menu_requested

const INK := Color(0.16, 0.12, 0.09)
const PARCHMENT := Color(0.94, 0.88, 0.74)
const GOLD := Color(0.86, 0.64, 0.28)
const NIGHT := Color(0.07, 0.1, 0.13, 0.82)

var root: Control
var hud_cards: Control
var voice_slot: HBoxContainer
var card_w := 360.0
var _last_found := 0
var _last_total := 1
var touch: TouchControls
var title_label: Label
var subtitle_label: Label
var objective_label: Label
var progress_label: Label
var progress_fill: ColorRect
var progress_back: ColorRect
var toast_panel: PanelContainer
var toast_label: Label
var toast_timer := 0.0
var modal_layer: Control
var modal_stack: Array[Control] = []
var _bold: Font

func _ready() -> void:
	layer = 10
	_bold = load("res://fonts/Vazirmatn-Bold.ttf")
	root = Control.new()
	root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	touch = TouchControls.new()
	root.add_child(touch)
	touch.jump_pressed.connect(func() -> void: jump_pressed.emit())
	touch.interact_pressed.connect(func() -> void: interact_pressed.emit())
	touch.shoot_pressed.connect(func() -> void: shoot_pressed.emit())
	touch.look_delta.connect(func(rel: Vector2) -> void: look_delta.emit(rel))
	touch.menu_pressed.connect(show_pause_menu)
	touch.knowledge_pressed.connect(show_knowledge_list)
	_update_card_width()
	_build_hud()
	GameState.ui_changed.connect(_on_ui_changed)
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)

func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_panel.visible = false
	if Input.is_action_just_pressed("interact") and modal_stack.is_empty():
		interact_pressed.emit()
	if Input.is_action_just_pressed("shoot") and modal_stack.is_empty():
		shoot_pressed.emit()
	if Input.is_action_just_pressed("ui_cancel"):
		if modal_stack.is_empty():
			show_pause_menu()

# ---------- helpers ----------

func fa(value: int) -> String:
	var out := ""
	for ch in str(value):
		out += "۰۱۲۳۴۵۶۷۸۹"[int(ch)] if ch >= "0" and ch <= "9" else ch
	return out

func _style(color: Color, radius: int = 14, border: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	if border:
		sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85)
		sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb

func _label(text: String, size: int, color: Color, bold: bool = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _bold)
	l.horizontal_alignment = align
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.language = "fa"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(text: String, callback: Callable, minimum: Vector2 = Vector2(180, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = minimum
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", PARCHMENT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.5))
	var normal := _style(Color(0.2, 0.26, 0.24, 0.96), 12)
	var hover := _style(Color(0.32, 0.38, 0.3, 0.98), 12)
	var pressed := _style(Color(0.52, 0.38, 0.16, 1.0), 12)
	var disabled := _style(Color(0.14, 0.16, 0.16, 0.8), 12, false)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(callback)
	return b

# ---------- always-on HUD ----------

func _build_hud() -> void:
	var left := VBoxContainer.new()
	left.position = Vector2(34, 16)
	left.custom_minimum_size = Vector2(card_w + 40.0, 0)
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	hud_cards = left
	left.visible = false

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(NIGHT, 14))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 0)
	card.add_child(card_box)
	title_label = _label("", 24, PARCHMENT, true)
	card_box.add_child(title_label)
	subtitle_label = _label("", 15, GOLD)
	card_box.add_child(subtitle_label)

	var obj := PanelContainer.new()
	obj.add_theme_stylebox_override("panel", _style(Color(0.94, 0.88, 0.74, 0.93), 14))
	obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(obj)
	var obj_box := VBoxContainer.new()
	obj.add_child(obj_box)
	obj_box.add_child(_label("✦ هدف مرحله", 14, Color(0.5, 0.3, 0.1), true))
	objective_label = _label("", 17, INK)
	objective_label.custom_minimum_size = Vector2(card_w, 0)
	obj_box.add_child(objective_label)
	progress_label = _label("", 15, INK, true)
	obj_box.add_child(progress_label)
	progress_back = ColorRect.new()
	progress_back.color = Color(0.2, 0.15, 0.1, 0.35)
	progress_back.custom_minimum_size = Vector2(card_w, 8)
	obj_box.add_child(progress_back)
	progress_fill = ColorRect.new()
	progress_fill.color = Color(0.72, 0.45, 0.1)
	progress_fill.size = Vector2(0, 8)
	progress_back.add_child(progress_fill)
	voice_slot = HBoxContainer.new()
	voice_slot.alignment = BoxContainer.ALIGNMENT_END
	obj_box.add_child(voice_slot)

	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _style(NIGHT, 14))
	toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_panel.position.y -= 40
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_panel)
	toast_label = _label("", 18, PARCHMENT, false, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.custom_minimum_size = Vector2(560, 0)
	toast_panel.add_child(toast_label)

func _update_card_width() -> void:
	# Bigger UI scale => narrower HUD cards so they do not cover the game view.
	card_w = [360.0, 320.0, 250.0][GameState.ui_scale_index]

func _on_ui_changed() -> void:
	_update_card_width()
	hud_cards.custom_minimum_size = Vector2(card_w + 40.0, 0)
	objective_label.custom_minimum_size = Vector2(card_w, 0)
	progress_back.custom_minimum_size = Vector2(card_w, 8)
	progress_fill.size.x = card_w * float(_last_found) / float(maxi(_last_total, 1))
	hud_cards.reset_size()

func set_level_info(title: String, subtitle: String) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	hud_cards.visible = true

func set_objective(text: String) -> void:
	objective_label.text = text

func set_progress(caption: String, found: int, total: int) -> void:
	progress_label.text = "%s: %s از %s" % [caption, fa(found), fa(total)]
	_last_found = found
	_last_total = total
	progress_fill.size.x = card_w * float(found) / float(maxi(total, 1))

func toast(text: String, seconds: float = 4.5) -> void:
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.reset_size()
	toast_panel.position.x = (root.size.x - toast_panel.size.x) * 0.5
	toast_panel.position.y = root.size.y - toast_panel.size.y - 24.0
	toast_timer = seconds

## Archery chapters show the crosshair and the shoot button.
func set_archery(on: bool) -> void:
	touch.archery = on

func set_interact_ready(value: bool) -> void:
	touch.interact_ready = value

# ---------- modals ----------

func _open_modal(min_width: float = 640.0) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.94, 0.88, 0.74, 0.98), 18))
	panel.custom_minimum_size = Vector2(min_width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	modal_stack.append(dim)
	_sync_block()
	return box

func close_top_modal() -> void:
	if modal_stack.is_empty():
		return
	var top: Control = modal_stack.pop_back()
	top.queue_free()
	_sync_block()

func close_all_modals() -> void:
	AudioManager.stop_voice()
	while not modal_stack.is_empty():
		close_top_modal()

func _sync_block() -> void:
	GameState.ui_blocked = not modal_stack.is_empty()
	touch.enabled = modal_stack.is_empty()

func is_modal_open() -> bool:
	return not modal_stack.is_empty()

# ---------- narration helpers ----------

func _vk(key: String) -> String:
	return "%s__%s" % [str(LevelData.LEVELS[GameState.current_level]["id"]), key]

## Small "listen" button, or null when narration is off / no audio file exists.
func _voice_button(keys: Array) -> Button:
	if GameState.voice_mode == 0:
		return null
	var any := false
	for k in keys:
		if AudioManager.voice_path(str(k)) != "":
			any = true
	if not any:
		return null
	var b := _button("▶ شنیدن", func() -> void: AudioManager.play_voice_sequence(keys), Vector2(140, 46))
	b.add_theme_font_size_override("font_size", 17)
	return b

func _auto_voice(keys: Array) -> void:
	if GameState.voice_mode == 2:
		AudioManager.play_voice_sequence(keys)

## Called by the world when a level starts: narration button on the objective card.
func set_level_voice(keys: Array) -> void:
	for c in voice_slot.get_children():
		c.queue_free()
	var b := _voice_button(keys)
	if b:
		voice_slot.add_child(b)
	_auto_voice(keys)

func show_dialogue(speaker: String, lines: Array, choices: Array, after_lines: Array, on_done: Callable, voice_key: String = "") -> void:
	var box := _open_modal(720)
	box.add_child(_label(speaker, 26, Color(0.45, 0.25, 0.08), true))
	var body := _label("", 21, INK)
	body.custom_minimum_size = Vector2(660, 90)
	box.add_child(body)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var ids: Array = []
	for i in range(lines.size()):
		ids.append("%s_L%d" % [voice_key, i + 1])
	# Lambdas capture locals by value, so shared state lives in one dictionary.
	var st := {"queue": lines.duplicate(), "ids": ids, "choices_pending": not choices.is_empty(), "step": Callable()}
	st["step"] = func() -> void:
		for c in actions.get_children():
			c.queue_free()
		AudioManager.stop_voice()
		var queue: Array = st["queue"]
		var qids: Array = st["ids"]
		if queue.is_empty():
			close_top_modal()
			on_done.call()
			return
		body.text = str(queue.pop_front())
		var vkeys: Array = []
		if voice_key != "" and not qids.is_empty():
			vkeys = [_vk(str(qids.pop_front()))]
		var vb := _voice_button(vkeys) if not vkeys.is_empty() else null
		if queue.is_empty() and st["choices_pending"]:
			st["choices_pending"] = false
			if vb:
				actions.add_child(vb)
			for ci in range(choices.size()):
				var choice: Dictionary = choices[ci]
				var reply: String = str(choice["reply"])
				var reply_id := "%s_R%d" % [voice_key, ci + 1]
				actions.add_child(_button(str(choice["text"]), func() -> void:
					var q: Array = st["queue"]
					var qi: Array = st["ids"]
					q.clear()
					qi.clear()
					q.append(reply)
					qi.append(reply_id)
					for ai in range(after_lines.size()):
						q.append(after_lines[ai])
						qi.append("%s_A%d" % [voice_key, ai + 1])
					(st["step"] as Callable).call(), Vector2(600, 52)))
			_auto_voice(vkeys)
			return
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		actions.add_child(row)
		row.add_child(_button("ادامه", func() -> void: (st["step"] as Callable).call(), Vector2(200, 52)))
		if vb:
			row.add_child(vb)
		_auto_voice(vkeys)
	(st["step"] as Callable).call()

func show_quiz(data: Dictionary, on_result: Callable) -> void:
	var box := _open_modal(720)
	box.add_child(_label(str(data["title"]), 24, Color(0.45, 0.25, 0.08), true))
	var q := _label(str(data["question"]), 22, INK, true)
	q.custom_minimum_size = Vector2(660, 56)
	box.add_child(q)
	var feedback := _label("", 18, Color(0.15, 0.4, 0.2))
	feedback.custom_minimum_size = Vector2(660, 0)
	var buttons: Array[Button] = []
	var answer := int(data["answer"])
	var options: Array = data["options"]
	var q_key := _vk("%s_q" % str(data["id"]))
	var e_key := _vk("%s_explain" % str(data["id"]))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	var ids: Array = data.get("option_ids", [])   # original option index per shown option (after shuffling)
	var opt_keys: Array = []
	for i in range(options.size()):
		opt_keys.append(_vk("%s_opt%d" % [str(data["id"]), (int(ids[i]) if i < ids.size() else i) + 1]))
	for i in range(options.size()):
		var idx := i
		var ovb := _voice_button([opt_keys[i]])
		var b := _button(str(options[i]), func() -> void: pass, Vector2(660 - (148 if ovb else 0), 56))
		buttons.append(b)
		var orow := HBoxContainer.new()
		orow.add_theme_constant_override("separation", 8)
		orow.add_child(b)
		if ovb:
			orow.add_child(ovb)
		box.add_child(orow)
		b.pressed.connect(func() -> void:
			if idx == answer:
				for other in buttons:
					other.disabled = true
				feedback.text = "✔ " + str(GameMessages.TEXT["quiz_correct"]) + " " + str(data["explain"])
				feedback.add_theme_color_override("font_color", Color(0.12, 0.42, 0.2))
				var cont := _button("ادامه", func() -> void:
					AudioManager.stop_voice()
					close_top_modal()
					on_result.call(true, true), Vector2(200, 52))
				box.add_child(cont)
				var eb := _voice_button([e_key])
				if eb:
					bottom.add_child(eb)
				_auto_voice(["game__quiz_correct", e_key])
			else:
				b.disabled = true
				feedback.text = "✘ " + str(GameMessages.TEXT["quiz_wrong"])
				_auto_voice(["game__quiz_wrong"])
				feedback.add_theme_color_override("font_color", Color(0.6, 0.15, 0.1))
				on_result.call(false, false))
	box.add_child(feedback)
	bottom.add_child(_button("بستن", func() -> void:
		AudioManager.stop_voice()
		close_top_modal(), Vector2(140, 44)))
	var qb := _voice_button([q_key] + opt_keys)
	if qb:
		bottom.add_child(qb)
	box.add_child(bottom)
	_auto_voice([q_key] + opt_keys)

func show_level_complete(level: Dictionary, star_count: int, has_next: bool, on_next: Callable) -> void:
	var box := _open_modal(700)
	box.add_child(_label(GameMessages.TEXT["level_complete"], 30, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	var stars := ""
	for i in range(3):
		stars += "★" if i < star_count else "☆"
	box.add_child(_label(stars, 44, Color(0.78, 0.5, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	var k: Dictionary = level["knowledge"]
	box.add_child(_label("دانشنامه: " + str(k["title"]), 20, Color(0.45, 0.25, 0.08), true))
	var text := _label(str(k["text"]), 17, INK)
	text.custom_minimum_size = Vector2(640, 120)
	box.add_child(text)
	box.add_child(_label("نوع محتوا: روایت ادبی/اسطوره‌ای یا بازآفرینی تخیلی - نیازمند بازبینی پژوهشی پیش از انتشار.", 13, Color(0.4, 0.3, 0.2)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	if has_next:
		row.add_child(_button("مرحله بعد", func() -> void:
			close_all_modals()
			on_next.call(), Vector2(200, 54)))
	row.add_child(_button("تکرار", func() -> void:
		close_all_modals()
		restart_requested.emit(), Vector2(140, 54)))
	row.add_child(_button("منو", func() -> void:
		close_all_modals()
		show_main_menu(), Vector2(140, 54)))
	var k_key := _vk("knowledge")
	var kb := _voice_button([k_key])
	if kb:
		row.add_child(kb)
	_auto_voice(["game__level_complete", k_key])

func show_pause_menu() -> void:
	if not modal_stack.is_empty():
		return
	var box := _open_modal(460)
	box.add_child(_label("توقف", 28, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_button("ادامه بازی", close_top_modal, Vector2(380, 54)))
	box.add_child(_button("شروع دوباره مرحله", func() -> void:
		close_all_modals()
		restart_requested.emit(), Vector2(380, 54)))
	box.add_child(_button("انتخاب مرحله", func() -> void:
		close_all_modals()
		show_main_menu(), Vector2(380, 54)))
	box.add_child(_button("تنظیمات (سختی، کیفیت، صدا، اندازه)", func() -> void: show_settings(show_pause_menu), Vector2(380, 54)))

func _add_quality_controls(box: VBoxContainer) -> void:
	var quality_names := ["کیفیت: سبک (پیشنهادی گوشی ضعیف)", "کیفیت: متوسط", "کیفیت: بالا"]
	var qb := _button(quality_names[GameState.quality], func() -> void: pass, Vector2(380, 54))
	qb.pressed.connect(func() -> void:
		GameState.set_quality((GameState.quality + 1) % 3)
		qb.text = quality_names[GameState.quality])
	box.add_child(qb)
	var sb := _button("سایه‌ها: روشن" if GameState.shadows else "سایه‌ها: خاموش", func() -> void: pass, Vector2(380, 54))
	sb.pressed.connect(func() -> void:
		GameState.set_shadows(not GameState.shadows)
		sb.text = "سایه‌ها: روشن" if GameState.shadows else "سایه‌ها: خاموش")
	box.add_child(sb)
	var ui_names := ["اندازه نوشته و دکمه‌ها: عادی", "اندازه نوشته و دکمه‌ها: بزرگ", "اندازه نوشته و دکمه‌ها: خیلی بزرگ"]
	var ub := _button(ui_names[GameState.ui_scale_index], func() -> void: pass, Vector2(380, 54))
	ub.pressed.connect(func() -> void:
		GameState.set_ui_scale((GameState.ui_scale_index + 1) % 3)
		ub.text = ui_names[GameState.ui_scale_index])
	box.add_child(ub)

func show_loading(text: String) -> void:
	var box := _open_modal(420)
	box.add_child(_label(text, 24, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("لطفاً چند لحظه صبر کنید", 15, INK, false, HORIZONTAL_ALIGNMENT_CENTER))

func show_settings(back: Callable = Callable()) -> void:
	if not back.is_valid():
		back = show_main_menu
	close_all_modals()
	var box := _open_modal(460)
	box.add_child(_label("تنظیمات", 28, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	var diff_names := ["سختی بازی: آسان (نشانه‌ها نزدیک و پیدا)", "سختی بازی: متوسط", "سختی بازی: چالشی (جست‌وجوی بیشتر)"]
	var db := _button(diff_names[GameState.difficulty], func() -> void: pass, Vector2(380, 54))
	db.pressed.connect(func() -> void:
		GameState.set_difficulty((GameState.difficulty + 1) % 3)
		db.text = diff_names[GameState.difficulty]
		toast("سختی از شروع بعدی مرحله (یا «شروع دوباره مرحله») اعمال می‌شود.", 4.0))
	box.add_child(db)
	_add_quality_controls(box)
	box.add_child(_button("تنظیمات صدا", func() -> void: show_audio_settings(back), Vector2(380, 54)))
	box.add_child(_button("بازگشت", func() -> void: back.call(), Vector2(380, 54)))

const LEVEL_STEPS := [0.0, 0.35, 0.7, 1.0]
const LEVEL_NAMES := ["خاموش", "کم", "متوسط", "زیاد"]

func _nearest_step(v: float) -> int:
	var best := 0
	for i in range(LEVEL_STEPS.size()):
		if absf(LEVEL_STEPS[i] - v) < absf(LEVEL_STEPS[best] - v):
			best = i
	return best

func show_audio_settings(back: Callable) -> void:
	close_all_modals()
	var box := _open_modal(460)
	box.add_child(_label("تنظیمات صدا", 28, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	var mi := [_nearest_step(GameState.music_volume)]
	var mb := _button("موسیقی: " + LEVEL_NAMES[mi[0]], func() -> void: pass, Vector2(380, 54))
	mb.pressed.connect(func() -> void:
		mi[0] = (mi[0] + 1) % LEVEL_STEPS.size()
		GameState.set_audio(LEVEL_STEPS[mi[0]], GameState.ambience_volume, GameState.voice_mode)
		mb.text = "موسیقی: " + LEVEL_NAMES[mi[0]])
	box.add_child(mb)
	var ai := [_nearest_step(GameState.ambience_volume)]
	var ab := _button("صدای طبیعت (باد و آب): " + LEVEL_NAMES[ai[0]], func() -> void: pass, Vector2(380, 54))
	ab.pressed.connect(func() -> void:
		ai[0] = (ai[0] + 1) % LEVEL_STEPS.size()
		GameState.set_audio(GameState.music_volume, LEVEL_STEPS[ai[0]], GameState.voice_mode)
		ab.text = "صدای طبیعت (باد و آب): " + LEVEL_NAMES[ai[0]])
	box.add_child(ab)
	var voice_names := ["روایت صوتی: خاموش", "روایت صوتی: فقط با دکمه «شنیدن»", "روایت صوتی: خودکار (پیش‌فرض)"]
	var vb := _button(voice_names[GameState.voice_mode], func() -> void: pass, Vector2(380, 54))
	vb.pressed.connect(func() -> void:
		GameState.set_audio(GameState.music_volume, GameState.ambience_volume, (GameState.voice_mode + 1) % 3)
		vb.text = voice_names[GameState.voice_mode])
	box.add_child(vb)
	box.add_child(_button("بازگشت", func() -> void: show_settings(back), Vector2(380, 54)))

func show_knowledge_list() -> void:
	if not modal_stack.is_empty():
		return
	var box := _open_modal(700)
	box.add_child(_label("دانشنامه", 28, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	var found := 0
	for level in LevelData.LEVELS:
		var k: Dictionary = level["knowledge"]
		if GameState.knowledge.has(k["id"]):
			found += 1
			box.add_child(_label("• " + str(k["title"]), 19, Color(0.45, 0.25, 0.08), true))
			var t := _label(str(k["text"]), 16, INK)
			t.custom_minimum_size = Vector2(640, 0)
			box.add_child(t)
	if found == 0:
		box.add_child(_label("با کامل کردن هر مرحله، یک مدخل به دانشنامه اضافه می‌شود.", 18, INK))
	box.add_child(_button("بستن", close_top_modal, Vector2(160, 48)))

func show_main_menu() -> void:
	close_all_modals()
	hud_cards.visible = false
	AudioManager.enter_menu()
	var box := _open_modal(760)
	box.add_child(_label("ایران؛ سفر در تاریخ و اسطوره‌ها", 32, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("فصل نخست • راز زال و سیمرغ", 18, Color(0.5, 0.35, 0.12), false, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for i in range(LevelData.LEVELS.size()):
		var level: Dictionary = LevelData.LEVELS[i]
		var unlocked: bool = i <= GameState.unlocked_level
		var star_count := int(GameState.stars.get(str(i), 0))
		var caption := "%s  %s" % [str(level["title"]), "★".repeat(star_count) + "☆".repeat(3 - star_count)] if unlocked else "🔒 " + str(level["title"])
		var idx := i
		var b := _button(caption, func() -> void:
			close_all_modals()
			start_level.emit(idx), Vector2(360, 56))
		b.disabled = not unlocked
		grid.add_child(b)
	var cont_idx := mini(GameState.unlocked_level, LevelData.LEVELS.size() - 1)
	box.add_child(_button("ادامه سفر", func() -> void:
		close_all_modals()
		start_level.emit(cont_idx), Vector2(360, 60)))
	box.add_child(_button("تنظیمات (سختی، کیفیت، صدا، اندازه)", func() -> void: show_settings(show_main_menu), Vector2(360, 54)))
	box.add_child(_label("این بازی روایتی ادبی و بازآفرینی تخیلی است؛ زال و سیمرغ شخصیت‌های حماسی شاهنامه‌اند، نه اشخاص تاریخیِ اثبات‌شده.", 13, Color(0.4, 0.3, 0.2)))
