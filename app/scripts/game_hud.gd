extends CanvasLayer
class_name GameHUD
## All 2D interface: HUD, dialogue, quiz, menus. Built in code so the project
## has no binary UI assets. Persian text is right-to-left.

signal jump_pressed
signal interact_pressed
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
	touch.look_delta.connect(func(rel: Vector2) -> void: look_delta.emit(rel))
	touch.menu_pressed.connect(show_pause_menu)
	touch.knowledge_pressed.connect(show_knowledge_list)
	_build_hud()
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
	left.custom_minimum_size = Vector2(400, 0)
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
	objective_label.custom_minimum_size = Vector2(360, 0)
	obj_box.add_child(objective_label)
	progress_label = _label("", 15, INK, true)
	obj_box.add_child(progress_label)
	progress_back = ColorRect.new()
	progress_back.color = Color(0.2, 0.15, 0.1, 0.35)
	progress_back.custom_minimum_size = Vector2(360, 8)
	obj_box.add_child(progress_back)
	progress_fill = ColorRect.new()
	progress_fill.color = Color(0.72, 0.45, 0.1)
	progress_fill.size = Vector2(0, 8)
	progress_back.add_child(progress_fill)

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

func set_level_info(title: String, subtitle: String) -> void:
	title_label.text = title
	subtitle_label.text = subtitle
	hud_cards.visible = true

func set_objective(text: String) -> void:
	objective_label.text = text

func set_progress(caption: String, found: int, total: int) -> void:
	progress_label.text = "%s: %s از %s" % [caption, fa(found), fa(total)]
	progress_fill.size.x = 360.0 * float(found) / float(maxi(total, 1))

func toast(text: String, seconds: float = 4.5) -> void:
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.reset_size()
	toast_panel.position.x = (root.size.x - toast_panel.size.x) * 0.5
	toast_panel.position.y = root.size.y - toast_panel.size.y - 24.0
	toast_timer = seconds

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
	while not modal_stack.is_empty():
		close_top_modal()

func _sync_block() -> void:
	GameState.ui_blocked = not modal_stack.is_empty()
	touch.enabled = modal_stack.is_empty()

func is_modal_open() -> bool:
	return not modal_stack.is_empty()

func show_dialogue(speaker: String, lines: Array, choices: Array, after_lines: Array, on_done: Callable) -> void:
	var box := _open_modal(720)
	box.add_child(_label(speaker, 26, Color(0.45, 0.25, 0.08), true))
	var body := _label("", 21, INK)
	body.custom_minimum_size = Vector2(660, 90)
	box.add_child(body)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	# Lambdas capture locals by value, so shared state lives in one dictionary.
	var st := {"queue": lines.duplicate(), "choices_pending": not choices.is_empty(), "step": Callable()}
	st["step"] = func() -> void:
		for c in actions.get_children():
			c.queue_free()
		var queue: Array = st["queue"]
		if queue.is_empty():
			close_top_modal()
			on_done.call()
			return
		body.text = str(queue.pop_front())
		if queue.is_empty() and st["choices_pending"]:
			st["choices_pending"] = false
			for choice in choices:
				var reply: String = str(choice["reply"])
				actions.add_child(_button(str(choice["text"]), func() -> void:
					var q: Array = st["queue"]
					q.clear()
					q.append(reply)
					q.append_array(after_lines)
					(st["step"] as Callable).call(), Vector2(600, 52)))
			return
		actions.add_child(_button("ادامه", func() -> void: (st["step"] as Callable).call(), Vector2(200, 52)))
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
	for i in range(options.size()):
		var idx := i
		var b := _button(str(options[i]), func() -> void: pass, Vector2(660, 56))
		buttons.append(b)
		box.add_child(b)
		b.pressed.connect(func() -> void:
			if idx == answer:
				for other in buttons:
					other.disabled = true
				feedback.text = "✔ درست! " + str(data["explain"])
				feedback.add_theme_color_override("font_color", Color(0.12, 0.42, 0.2))
				var cont := _button("ادامه", func() -> void:
					close_top_modal()
					on_result.call(true, true), Vector2(200, 52))
				box.add_child(cont)
			else:
				b.disabled = true
				feedback.text = "✘ پاسخ درست نیست؛ دوباره فکر کن."
				feedback.add_theme_color_override("font_color", Color(0.6, 0.15, 0.1))
				on_result.call(false, false))
	box.add_child(feedback)
	box.add_child(_button("بستن", close_top_modal, Vector2(140, 44)))

func show_level_complete(level: Dictionary, star_count: int, has_next: bool, on_next: Callable) -> void:
	var box := _open_modal(700)
	box.add_child(_label("مرحله کامل شد!", 30, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
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
	_add_quality_controls(box)

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

func show_settings() -> void:
	close_all_modals()
	var box := _open_modal(460)
	box.add_child(_label("تنظیمات", 28, Color(0.45, 0.25, 0.08), true, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("اگر بازی کند است یا گوشی هنگ می‌کند، کیفیت را «سبک» و سایه‌ها را «خاموش» بگذارید.", 15, INK))
	_add_quality_controls(box)
	box.add_child(_button("بازگشت", show_main_menu, Vector2(380, 54)))

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
	box.add_child(_button("تنظیمات و کیفیت تصویر", show_settings, Vector2(360, 54)))
	box.add_child(_label("این بازی روایتی ادبی و بازآفرینی تخیلی است؛ زال و سیمرغ شخصیت‌های حماسی شاهنامه‌اند، نه اشخاص تاریخیِ اثبات‌شده.", 13, Color(0.4, 0.3, 0.2)))
