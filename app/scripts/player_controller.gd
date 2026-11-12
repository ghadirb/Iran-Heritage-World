extends CharacterBody3D
class_name PlayerController
## Third-person character. Moves relative to the camera; driven by the virtual
## stick (GameState.move_vector) or the keyboard. The camera rig is a top-level
## node so rotating the character never rotates the camera.

signal jumped

@export var run_speed: float = 6.2
@export var acceleration: float = 28.0
@export var jump_velocity: float = 8.0
@export var turn_speed: float = 12.0
@export var look_sensitivity: float = 0.0055
@export var min_pitch: float = -1.1
@export var max_pitch: float = 0.15

var rig: Node3D
var spring: SpringArm3D
var camera: Camera3D
var art: Node3D
var yaw := 0.0
var pitch := -0.32
var coyote := 0.0
var jump_buffer := 0.0
var input_enabled := true
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(56.0)
	safe_margin = 0.03
	_register_keys()
	rig = Node3D.new()
	rig.name = "CameraRig"
	rig.top_level = true
	add_child(rig)
	spring = SpringArm3D.new()
	spring.spring_length = 6.4
	spring.margin = 0.3
	spring.shape = SphereShape3D.new()
	(spring.shape as SphereShape3D).radius = 0.3
	spring.add_excluded_object(get_rid())
	rig.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.1
	camera.far = 400.0
	camera.current = true
	spring.add_child(camera)
	rig.global_position = global_position + Vector3(0, 1.5, 0)

func add_look(relative: Vector2) -> void:
	yaw -= relative.x * look_sensitivity
	pitch = clampf(pitch - relative.y * look_sensitivity, min_pitch, max_pitch)

func request_jump() -> void:
	jump_buffer = 0.15

func snap_camera_behind(face_yaw: float = 0.0) -> void:
	yaw = face_yaw
	pitch = -0.3
	if rig:
		rig.global_position = global_position + Vector3(0, 1.5, 0)

func _process(delta: float) -> void:
	if rig == null:
		return
	var key_look := Input.get_axis("look_left", "look_right")
	if input_enabled and key_look != 0.0:
		yaw -= key_look * 2.0 * delta
	rig.global_position = rig.global_position.lerp(global_position + Vector3(0, 1.5, 0), 1.0 - exp(-14.0 * delta))
	rig.rotation = Vector3(pitch, yaw, 0.0)

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if input_enabled:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back") + GameState.move_vector
		if input_vector.length() > 1.0:
			input_vector = input_vector.normalized()
		if Input.is_action_just_pressed("jump"):
			request_jump()
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var direction := right * input_vector.x + forward * -input_vector.y
	var target := direction * run_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if direction.length_squared() > 0.01 and art:
		var target_angle := atan2(direction.x, direction.z)
		art.rotation.y = lerp_angle(art.rotation.y, target_angle, turn_speed * delta)

	if is_on_floor():
		coyote = 0.12
	else:
		coyote -= delta
		velocity.y -= gravity * delta
	jump_buffer -= delta
	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = jump_velocity
		jump_buffer = 0.0
		coyote = 0.0
		jumped.emit()
	move_and_slide()
	_push_bodies(delta)

func _register_keys() -> void:
	_add_key("move_forward", [KEY_W, KEY_UP])
	_add_key("move_back", [KEY_S, KEY_DOWN])
	_add_key("move_left", [KEY_A, KEY_LEFT])
	_add_key("move_right", [KEY_D, KEY_RIGHT])
	_add_key("jump", [KEY_SPACE])
	_add_key("interact", [KEY_E, KEY_ENTER])
	_add_key("look_left", [KEY_Q])
	_add_key("look_right", [KEY_R])

func _add_key(action_name: StringName, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action_name, event)


## Walking into a heavy body (tree trunk) rolls it away from the player.
func _push_bodies(delta: float) -> void:
	for i in range(get_slide_collision_count()):
		var c := get_slide_collision(i)
		var body := c.get_collider() as RigidBody3D
		if body == null or not body.is_in_group("pushable"):
			continue
		var n := c.get_normal()
		var dir := Vector3(-n.x, 0.0, -n.z)
		if dir.length() < 0.2:
			continue
		dir = dir.normalized()
		var want := dir * run_speed * 0.8
		body.sleeping = false
		body.linear_velocity.x = move_toward(body.linear_velocity.x, want.x, 40.0 * delta)
		body.linear_velocity.z = move_toward(body.linear_velocity.z, want.z, 40.0 * delta)
