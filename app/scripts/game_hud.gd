extends CanvasLayer

var mission_label: Label
var message_label: Label
var learning_panel: PanelContainer
var learning_text: Label

func _ready() -> void:
	_build_interface()

func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var heading := Label.new()
	heading.text = "ایران؛ سفر در تاریخ و اسطوره‌ها"
	heading.add_theme_font_size_override("font_size", 25)
	heading.position = Vector2(24, 16)
	heading.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72))
	root.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "فصل نخست | راز زال و سیمرغ"
	subtitle.position = Vector2(26, 52)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.92, 0.94))
	root.add_child(subtitle)

	var mission_panel := PanelContainer.new()
	mission_panel.position = Vector2(24, 88)
	mission_panel.custom_minimum_size = Vector2(330, 84)
	root.add_child(mission_panel)
	var mission_box := VBoxContainer.new()
	mission_box.add_theme_constant_override("separation", 6)
	mission_panel.add_child(mission_box)
	var mission_title := Label.new()
	mission_title.text = "ماموریت فعلی"
	mission_title.add_theme_color_override("font_color", Color(0.55, 0.39, 0.18))
	mission_box.add_child(mission_title)
	mission_label = Label.new()
	mission_label.text = "ردّ آشیانه"
	mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_label.add_theme_color_override("font_color", Color(0.12, 0.13, 0.15))
	mission_box.add_child(mission_label)

	var learn_button := _make_button("دانشنامه", Vector2(24, 188), Vector2(150, 48))
	learn_button.pressed.connect(show_knowledge)
	root.add_child(learn_button)

	message_label = Label.new()
	message_label.position = Vector2(24, 246)
	message_label.size = Vector2(430, 90)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	root.add_child(message_label)

	var help := Label.new()
	help.text = "حرکت با دکمه‌ها | چرخش دوربین: کشیدن سمت راست صفحه | تعامل"
	help.position = Vector2(24, 340)
	help.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	root.add_child(help)

	var controls := HBoxContainer.new()
	controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position = Vector2(24, -92)
	controls.add_theme_constant_override("separation", 8)
	root.add_child(controls)
	_add_hold_button(controls, "◀", "move_left")
	_add_hold_button(controls, "▲", "move_forward")
	_add_hold_button(controls, "▼", "move_back")
	_add_hold_button(controls, "▶", "move_right")
	_add_action_button(controls, "تعامل", "interact")

	learning_panel = PanelContainer.new()
	learning_panel.set_anchors_preset(Control.PRESET_CENTER)
	learning_panel.position = Vector2(-230, -160)
	learning_panel.custom_minimum_size = Vector2(460, 320)
	learning_panel.size = Vector2(460, 320)
	learning_panel.visible = false
	root.add_child(learning_panel)
	var panel_box := VBoxContainer.new()
	learning_panel.add_child(panel_box)
	var close_button := _make_button("بستن", Vector2.ZERO, Vector2(90, 40))
	close_button.pressed.connect(func() -> void: learning_panel.visible = false)
	panel_box.add_child(close_button)
	learning_text = Label.new()
	learning_text.text = "زال و سیمرغ\n\nزال و سیمرغ از شخصیت‌های حماسی شاهنامه فردوسی‌اند. در روایت شاهنامه، زال در کوهستان البرز به دست سیمرغ پرورش می‌یابد. این داستان بخشی از ادبیات حماسی ایران است و نباید به‌عنوان رویدادی تاریخیِ اثبات‌شده معرفی شود.\n\nدر نسخه نهایی، ارجاع دقیق به متن مبنا و منابع پژوهشی افزوده خواهد شد."
	learning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	learning_text.add_theme_color_override("font_color", Color(0.12, 0.13, 0.15))
	learning_text.add_theme_font_size_override("font_size", 17)
	panel_box.add_child(learning_text)

func _make_button(caption: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = at
	button.custom_minimum_size = button_size
	button.add_theme_font_size_override("font_size", 17)
	return button

func _add_hold_button(container: HBoxContainer, caption: String, action: StringName) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(54, 54)
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	container.add_child(button)

func _add_action_button(container: HBoxContainer, caption: String, action: StringName) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(94, 54)
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	container.add_child(button)

func set_mission(title: String, description: String) -> void:
	if mission_label:
		mission_label.text = "%s\n%s" % [title, description]

func show_message(message: String) -> void:
	if message_label:
		message_label.text = message

func show_knowledge() -> void:
	if learning_panel:
		learning_panel.visible = true
