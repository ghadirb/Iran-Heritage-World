extends CanvasLayer

var mission_label: Label
var message_label: Label
var progress_label: Label
var progress_fill: ColorRect
var learning_panel: PanelContainer
var learning_text: Label

const INK := Color(0.16, 0.14, 0.12)
const PARCHMENT := Color(0.91, 0.84, 0.69)
const GOLD := Color(0.82, 0.62, 0.29)

func _ready() -> void:
	_build_interface()

func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var title_panel := _panel(Vector2(22, 18), Vector2(390, 78), root, Color(0.08, 0.12, 0.14, 0.78))
	var heading := Label.new()
	heading.text = "ایران | سفر در تاریخ و اسطوره‌ها"
	heading.position = Vector2(16, 10)
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", PARCHMENT)
	title_panel.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "فصل نخست  •  راز زال و سیمرغ"
	subtitle.position = Vector2(17, 43)
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", GOLD)
	title_panel.add_child(subtitle)

	var mission_panel := _panel(Vector2(22, 110), Vector2(330, 112), root, Color(0.91, 0.84, 0.69, 0.93))
	var mission_caption := Label.new()
	mission_caption.text = "✦  مأموریت جاری"
	mission_caption.position = Vector2(15, 9)
	mission_caption.add_theme_color_override("font_color", Color(0.52, 0.32, 0.12))
	mission_caption.add_theme_font_size_override("font_size", 17)
	mission_panel.add_child(mission_caption)
	mission_label = Label.new()
	mission_label.text = "ردّ آشیانه"
	mission_label.position = Vector2(15, 39)
	mission_label.size = Vector2(295, 42)
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.add_theme_color_override("font_color", INK)
	mission_label.add_theme_font_size_override("font_size", 16)
	mission_panel.add_child(mission_label)

	progress_label = Label.new()
	progress_label.text = "نشانه‌ها  ۰ / ۳"
	progress_label.position = Vector2(24, 232)
	progress_label.add_theme_color_override("font_color", PARCHMENT)
	progress_label.add_theme_font_size_override("font_size", 16)
	root.add_child(progress_label)
	var progress_back := ColorRect.new()
	progress_back.position = Vector2(24, 260)
	progress_back.size = Vector2(220, 7)
	progress_back.color = Color(0.05, 0.08, 0.09, 0.75)
	root.add_child(progress_back)
	progress_fill = ColorRect.new()
	progress_fill.size = Vector2(0, 7)
	progress_fill.color = GOLD
	progress_back.add_child(progress_fill)

	var knowledge := _button("دانشنامه", Vector2(22, 282), Vector2(140, 44))
	knowledge.pressed.connect(show_knowledge)
	root.add_child(knowledge)

	var message_panel := _panel(Vector2(22, 338), Vector2(390, 82), root, Color(0.08, 0.12, 0.14, 0.78))
	message_label = Label.new()
	message_label.position = Vector2(13, 9)
	message_label.size = Vector2(364, 64)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", PARCHMENT)
	message_label.add_theme_font_size_override("font_size", 15)
	message_panel.add_child(message_label)

	var help := Label.new()
	help.text = "حرکت: دکمه‌ها  |  نگاه: کشیدن سمت راست  |  تعامل: نزدیک نشانه شو"
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.position = Vector2(20, -34)
	help.size = Vector2(900, 26)
	help.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
	help.add_theme_font_size_override("font_size", 14)
	root.add_child(help)

	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(22, -94)
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	_add_hold_button(controls, "◀", "move_left")
	_add_hold_button(controls, "▲", "move_forward")
	_add_hold_button(controls, "▼", "move_back")
	_add_hold_button(controls, "▶", "move_right")
	_add_action_button(controls, "تعامل", "interact")

	learning_panel = _panel(Vector2.ZERO, Vector2(540, 390), root, Color(0.91, 0.84, 0.69, 0.98))
	learning_panel.set_anchors_preset(Control.PRESET_CENTER)
	learning_panel.position = Vector2(-270, -195)
	learning_panel.visible = false
	var panel_box := VBoxContainer.new()
	panel_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_box.add_theme_constant_override("separation", 12)
	learning_panel.add_child(panel_box)
	var top := HBoxContainer.new()
	panel_box.add_child(top)
	var panel_title := Label.new()
	panel_title.text = "دانشنامه | زال و سیمرغ"
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_title.add_theme_color_override("font_color", Color(0.42, 0.25, 0.12))
	panel_title.add_theme_font_size_override("font_size", 21)
	top.add_child(panel_title)
	var close_button := _button("بستن", Vector2.ZERO, Vector2(82, 38))
	close_button.pressed.connect(func() -> void: learning_panel.visible = false)
	top.add_child(close_button)
	learning_text = Label.new()
	learning_text.text = "زال و سیمرغ\n\nزال و سیمرغ از چهره‌های حماسی شاهنامه فردوسی‌اند. در روایت شاهنامه، زال در کودکی در کوهستان البرز رها می‌شود و سیمرغ او را به آشیانه می‌برد و پرورش می‌دهد.\n\nاین روایت بخشی از ادبیات حماسی و اسطوره‌ای ایران است؛ نه گزارشی تاریخی که وقوع آن اثبات شده باشد. در نسخه‌های بعدی، منابع و ارجاع دقیق به متن شاهنامه نیز افزوده می‌شود."
	learning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	learning_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	learning_text.add_theme_color_override("font_color", INK)
	learning_text.add_theme_font_size_override("font_size", 18)
	panel_box.add_child(learning_text)

func _panel(at: Vector2, panel_size: Vector2, parent: Control, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _button(caption: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = at
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 16)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.21, 0.2, 0.94)
	normal.border_color = GOLD
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.28, 0.31, 0.24, 0.98)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_color_override("font_color", PARCHMENT)
	return button

func _add_hold_button(container: HBoxContainer, caption: String, action: StringName) -> void:
	var button := _button(caption, Vector2.ZERO, Vector2(58, 58))
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	container.add_child(button)

func _add_action_button(container: HBoxContainer, caption: String, action: StringName) -> void:
	var button := _button(caption, Vector2.ZERO, Vector2(104, 58))
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	container.add_child(button)

func set_mission(title: String, description: String) -> void:
	if mission_label:
		mission_label.text = "%s\n%s" % [title, description]

func set_progress(found: int, total: int) -> void:
	if progress_label:
		progress_label.text = "نشانه‌ها  %d / %d" % [found, total]
	if progress_fill:
		progress_fill.size.x = 220.0 * float(found) / float(maxi(total, 1))

func show_message(message: String) -> void:
	if message_label:
		message_label.text = message

func show_knowledge() -> void:
	if learning_panel:
		learning_panel.visible = true
