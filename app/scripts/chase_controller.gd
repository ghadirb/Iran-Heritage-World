class_name ChaseController
extends RefCounted
## Lightweight, data-driven chase course. The pursuer has no collision body:
## it is a readable pressure cue, while the child chooses safe gaps by moving.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var difficulty := 0
var pursuer: Node3D
var gates: Array[Dictionary] = []
var active := false
var escaped := false
var start_z := 0.0
var finish_z := -100.0
var speed := 5.0
var start_gap := 28.0
var catch_radius := 2.2
var time := 0.0

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary, diff: int) -> void:
	root = parent
	terrain = terrain_builder
	data = level["chase"]
	difficulty = diff
	finish_z = float(data["finish_z"])
	speed = float(data["speed"])
	start_gap = float(data["start_gap"])
	catch_radius = float(data["catch_radius"])
	var gate_count := int(data["gate_count"])
	var gate_width := float(data["gap_width"])
	var points: Array = data["gates"]
	for i in range(mini(gate_count, points.size())):
		var point: Dictionary = points[i]
		_build_gate(float(point["z"]), float(point["gap_x"]), gate_width)
	pursuer = PropFactory.make_mist_chaser()
	root.add_child(pursuer)

func reset(spawn: Vector3) -> void:
	start_z = spawn.z
	time = 0.0
	escaped = false
	active = true
	if is_instance_valid(pursuer):
		_place_pursuer(Vector3(spawn.x, spawn.y, spawn.z + start_gap))

func _build_gate(z: float, gap_x: float, gap_width: float) -> void:
	# Two short walls leave one clearly visible opening. Their visual and physics
	# shapes share the same dimensions, so every course is physically honest.
	var lane_half := 17.0
	var left_end := gap_x - gap_width * 0.5
	var right_start := gap_x + gap_width * 0.5
	_make_wall(z, (left_end - lane_half) * 0.5, left_end - (-lane_half))
	_make_wall(z, (right_start + lane_half) * 0.5, lane_half - right_start)
	gates.append({"z": z, "gap_x": gap_x, "gap_width": gap_width})

func _make_wall(z: float, x: float, width: float) -> void:
	if width <= 0.1:
		return
	var ground := terrain.height(x, z)
	var body := StaticBody3D.new()
	body.name = "MistGate"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 3.6, 1.25)
	shape.shape = box
	shape.position = Vector3(x, ground + 1.8, z)
	body.add_child(shape)
	root.add_child(body)
	var wall := PropFactory.part(PropFactory.box(Vector3(width, 3.6, 1.0)), PropFactory.mat(Color(0.24, 0.32, 0.42, 0.82), 0.9, 0.0, 0.35), Vector3(x, ground + 1.8, z))
	root.add_child(wall)
	var cap := PropFactory.part(PropFactory.box(Vector3(width, 0.12, 1.22)), PropFactory.mat(Color("#b4d9df"), 0.5, 0.0, 1.4), Vector3(x, ground + 3.56, z))
	root.add_child(cap)

func step(delta: float, player_position: Vector3) -> String:
	if not active or not is_instance_valid(pursuer):
		return ""
	time += delta
	if player_position.z <= finish_z:
		active = false
		escaped = true
		return "escaped"
	var p := pursuer.global_position
	# The shadow makes steady progress rather than teleporting to the player;
	# it can be outrun by moving through the course without stopping.
	p.z = move_toward(p.z, player_position.z, speed * delta)
	p.x = move_toward(p.x, player_position.x, speed * 0.42 * delta)
	_place_pursuer(p)
	var horizontal := Vector2(p.x - player_position.x, p.z - player_position.z).length()
	if horizontal < catch_radius:
		active = false
		return "caught"
	return ""

func guide_point(player_position: Vector3) -> Vector3:
	# Used only by the deterministic self-test bot; a child sees the glowing gap.
	for gate in gates:
		if float(gate["z"]) < player_position.z - 0.8:
			var x := float(gate["gap_x"])
			var z := float(gate["z"])
			return Vector3(x, terrain.height(x, z), z)
	return Vector3(0.0, terrain.height(0.0, finish_z), finish_z)

func _place_pursuer(pos: Vector3) -> void:
	var ground := terrain.height(pos.x, pos.z)
	pursuer.global_position = Vector3(pos.x, ground + 1.7 + sin(time * 3.0) * 0.16, pos.z)
	pursuer.rotation.y = sin(time * 1.4) * 0.14
