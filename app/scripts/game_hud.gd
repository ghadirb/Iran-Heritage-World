extends CanvasLayer

var learning_panel: PanelContainer

func _ready() -> void:
	_build_interface()

func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var heading := Label.new()
	heading.text = "ایران؛ سفر در تاریخ و اسطوره‌ها"
	heading.add_theme_font_size_override("font_size", 26)
	heading.position = Vector2(24, 18)
	heading.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
	root.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "نمونه اولیه | جهان زال و سیمرغ"
	subtitle.position = Vector2(26, 58)
	subtitle.add_theme_color_override("font_color", Color(0.88, 0.9, 0.92))
	root.add_child(subtitle)

	var learn_button := _make_button("دانشنامه و یادگیری", Vector2(24, 104), Vector2(210, 52))
	learn_button.pressed.connect(_toggle_learning)
	root.add_child(learn_button)

	var help := Label.new()
	help.text = "حرکت: کلیدهای WASD یا دکمه‌های لمسی"
	help.position = Vector2(24, 164)
	help.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	root.add_child(help)

	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(24, -112)
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	_add_hold_button(controls, "◀", "move_left")
	_add_hold_button(controls, "▲", "move_forward")
	_add_hold_button(controls, "▼", "move_back")
	_add_hold_button(controls, "▶", "move_right")

	learning_panel = PanelContainer.new()
	learning_panel.position = Vector2(250, 104)
	learning_panel.custom_minimum_size = Vector2(390, 250)
	learning_panel.visible = false
	root.add_child(learning_panel)

	var panel_text := Label.new()
	panel_text.text = "زال و سیمرغ\n\nاین بخش از روایت زال در شاهنامه فردوسی الهام گرفته است. زال و سیمرغ شخصیت‌های حماسی و اسطوره‌ای‌اند و نباید به‌عنوان اشخاص تاریخی اثبات‌شده معرفی شوند.\n\nدر نسخه‌های بعدی، منابع دقیق، روایت صوتی، نقشه و آزمون به این صفحه افزوده می‌شود."
	panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_text.add_theme_color_override("font_color", Color(0.12, 0.13, 0.15))
	panel_text.add_theme_font_size_override("font_size", 17)
	panel_text.custom_minimum_size = Vector2(350, 220)
	learning_panel.add_child(panel_text)

func _make_button(caption: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = at
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 18)
	return button

func _add_hold_button(container: HBoxContainer, caption: String, action: StringName) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(58, 58)
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	container.add_child(button)

func _toggle_learning() -> void:
	learning_panel.visible = not learning_panel.visible
