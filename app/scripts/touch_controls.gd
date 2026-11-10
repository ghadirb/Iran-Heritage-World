class_name TouchControls
extends Control
## Real multi-touch controls: floating virtual stick (left), camera drag (any
## free finger), jump / interact buttons (right) and small menu buttons.
## Works with emulated touch from the mouse on desktop too.

signal jump_pressed
signal interact_pressed
signal menu_pressed
signal knowledge_pressed
signal look_delta(relative: Vector2)

const STICK_RADIUS := 86.0

var enabled := true:
	set(value):
		enabled = value
		if not enabled:
			_release_all()
		queue_redraw()
var interact_ready := false:
	set(value):
		if value != interact_ready:
			interact_ready = value
			queue_redraw()

var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_id := -1
var _button_touches: Dictionary = {}   # finger index -> button name

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _btn_center(name: String) -> Vector2:
	match name:
		"jump": return Vector2(size.x - 110.0, size.y - 120.0)
		"interact": return Vector2(size.x - 250.0, size.y - 78.0)
		"menu": return Vector2(size.x - 44.0, 44.0)
		"knowledge": return Vector2(size.x - 112.0, 44.0)
	return Vector2.ZERO

func _btn_radius(name: String) -> float:
	match name:
		"jump": return 54.0
		"interact": return 62.0
		_: return 32.0

func _hit_button(pos: Vector2) -> String:
	for name in ["jump", "interact", "menu", "knowledge"]:
		if pos.distance_to(_btn_center(name)) <= _btn_radius(name) + 10.0:
			return name
	return ""

func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_id:
			_stick_pos = drag.position
			_update_stick()
		elif drag.index == _look_id:
			look_delta.emit(drag.relative)

func _on_press(index: int, pos: Vector2) -> void:
	var hit := _hit_button(pos)
	if hit != "":
		_button_touches[index] = hit
		match hit:
			"jump": jump_pressed.emit()
			"interact": interact_pressed.emit()
			"menu": menu_pressed.emit()
			"knowledge": knowledge_pressed.emit()
		queue_redraw()
		return
	if _stick_id == -1 and pos.x < size.x * 0.45 and pos.y > size.y * 0.22:
		_stick_id = index
		_stick_origin = pos
		_stick_pos = pos
		_update_stick()
		queue_redraw()
		return
	if _look_id == -1:
		_look_id = index

func _on_release(index: int) -> void:
	if _button_touches.has(index):
		_button_touches.erase(index)
		queue_redraw()
	if index == _stick_id:
		_stick_id = -1
		GameState.move_vector = Vector2.ZERO
		queue_redraw()
	if index == _look_id:
		_look_id = -1

func _update_stick() -> void:
	var delta := _stick_pos - _stick_origin
	if delta.length() > STICK_RADIUS:
		_stick_origin = _stick_pos - delta.normalized() * STICK_RADIUS
		delta = _stick_pos - _stick_origin
	var v := delta / STICK_RADIUS
	GameState.move_vector = v if v.length() > 0.12 else Vector2.ZERO
	queue_redraw()

func _release_all() -> void:
	_stick_id = -1
	_look_id = -1
	_button_touches.clear()
	GameState.move_vector = Vector2.ZERO

func _draw() -> void:
	if not enabled:
		return
	# virtual stick
	var base_pos := _stick_origin if _stick_id != -1 else Vector2(150.0, size.y - 130.0)
	var knob := _stick_pos if _stick_id != -1 else base_pos
	draw_circle(base_pos, STICK_RADIUS, Color(0.05, 0.08, 0.1, 0.32))
	draw_arc(base_pos, STICK_RADIUS, 0.0, TAU, 48, Color(1.0, 0.86, 0.55, 0.55), 3.0, true)
	draw_circle(knob, 38.0, Color(1.0, 0.86, 0.55, 0.62 if _stick_id != -1 else 0.38))
	# action buttons
	_draw_button("jump", Color(0.2, 0.28, 0.3, 0.6), "پرش")
	_draw_button("interact", Color(0.88, 0.62, 0.2, 0.9) if interact_ready else Color(0.2, 0.28, 0.3, 0.6), "تعامل")
	_draw_button("menu", Color(0.12, 0.16, 0.2, 0.7), "≡")
	_draw_button("knowledge", Color(0.12, 0.16, 0.2, 0.7), "دانش")

func _draw_button(name: String, color: Color, caption: String) -> void:
	var c := _btn_center(name)
	var r := _btn_radius(name)
	var pressed := _button_touches.values().has(name)
	draw_circle(c, r, color.lightened(0.25) if pressed else color)
	draw_arc(c, r, 0.0, TAU, 40, Color(1.0, 0.86, 0.55, 0.85), 2.5, true)
	var font := get_theme_default_font()
	var fs := 22 if r > 40.0 else 15
	var ts := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.28), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.82))
