class_name TurningBridgeController
extends RefCounted
## A light balancing bridge: narrow rotating beams are AnimatableBody3D nodes
## so their motion is real physics and can carry the player. Only the rest pads
## are static checkpoints.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var beams: Array[Dictionary] = []
var pads: Array[Vector3] = []
var finish_z := -80.0
var speed := 0.5
var angle := 0.35
var width := 2.6
var elapsed := 0.0
var active := false
var crossed := false

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["turning_bridge"]
	finish_z = float(data["finish_z"])
	speed = float(data["speed"])
	angle = float(data["angle"])
	width = float(data["width"])
	var count := int(data["count"])
	var z0 := float(data["beam_z0"])
	var z1 := float(data["beam_z1"])
	for i in range(count):
		var t := float(i) / float(maxi(count - 1, 1))
		_build_beam(lerpf(z0, z1, t), float(i) * 1.65)
	for z_value in (data["pads"] as Array):
		_build_pad(float(z_value))

func reset() -> void:
	elapsed = 0.0
	crossed = false
	active = true
	for beam in beams:
		var body: AnimatableBody3D = beam["body"]
		body.rotation.y = 0.0

func step(delta: float, player_position: Vector3) -> String:
	if not active:
		return ""
	elapsed += delta
	for beam in beams:
		var body: AnimatableBody3D = beam["body"]
		body.rotation.y = sin(elapsed * speed + float(beam["phase"])) * angle
	if player_position.z <= finish_z:
		active = false
		crossed = true
		return "crossed"
	return ""

func static_checkpoint(player_position: Vector3) -> Vector3:
	var best := Vector3.ZERO
	for pad in pads:
		if player_position.z < pad.z + 2.0 and Vector2(player_position.x - pad.x, player_position.z - pad.z).length() < 2.3:
			best = pad + Vector3(0, 0.75, 0)
	return best

func guide_point(player_position: Vector3) -> Vector3:
	for beam in beams:
		var body: AnimatableBody3D = beam["body"]
		if body.global_position.z < player_position.z - 0.8:
			return body.global_position
	return Vector3(terrain.path_x(finish_z), _deck_height(finish_z), finish_z)

func _deck_height(z_value: float) -> float:
	var chasm: Dictionary = data["chasm"]
	var z0 := float(chasm["z0"]) + 2.0
	var z1 := float(chasm["z1"]) - 2.0
	var y0 := terrain.height(terrain.path_x(z0), z0) + 0.62
	var y1 := terrain.height(terrain.path_x(z1), z1) + 0.62
	var t := inverse_lerp(z0, z1, z_value)
	return lerpf(y0, y1, t)

func _build_beam(z_value: float, phase: float) -> void:
	var x := terrain.path_x(z_value)
	var body := AnimatableBody3D.new()
	body.name = "TurningBeam"
	body.sync_to_physics = true
	body.position = Vector3(x, _deck_height(z_value), z_value)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.52, 11.5)
	cs.shape = shape
	cs.position = Vector3(0, -0.26, 0)
	body.add_child(cs)
	var wood := PropFactory.mat(Color("#795234"), 1.0)
	body.add_child(PropFactory.part(PropFactory.box(Vector3(width, 0.42, 11.5)), wood, Vector3(0, -0.21, 0)))
	body.add_child(PropFactory.part(PropFactory.cylinder(0.25, 0.3, 3.2, 10), PropFactory.mat(Color("#51402f"), 1.0), Vector3(0, -1.8, 0)))
	root.add_child(body)
	beams.append({"body": body, "phase": phase})

func _build_pad(z_value: float) -> void:
	var x := terrain.path_x(z_value)
	var y := _deck_height(z_value)
	var pad := StaticBody3D.new()
	pad.name = "BridgeRestPad"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.4, 0.65, 3.4)
	cs.shape = shape
	cs.position = Vector3(x, y - 0.33, z_value)
	pad.add_child(cs)
	pad.add_child(PropFactory.part(PropFactory.box(Vector3(5.4, 0.55, 3.4)), PropFactory.mat(Color("#9b7043"), 0.95), Vector3(x, y - 0.28, z_value)))
	root.add_child(pad)
	pads.append(Vector3(x, y, z_value))
