class_name RollingCourseController
extends RefCounted
## A physical rolling course: the player pushes a clay ball through a light
## guiding channel. The ball is a real RigidBody3D; the controller only owns
## setup, loss recovery, and the finish check.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var ball: RigidBody3D
var home := Vector3.ZERO
var finish := Vector3.ZERO
var goal_radius := 2.4
var active := false
var completed := false

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["rolling_course"]
	var start_z := float(data["start_z"])
	var finish_z := float(data["finish_z"])
	var x := terrain.path_x(start_z)
	home = Vector3(x, terrain.height(x, start_z) + 1.18, start_z)
	finish = Vector3(terrain.path_x(finish_z), terrain.height(terrain.path_x(finish_z), finish_z), finish_z)
	goal_radius = float(data.get("goal_radius", 2.5))
	_build_channel(start_z, finish_z, float(data["rail_half_width"]))
	_build_ball(float(data["mass"]))
	var marker := PropFactory.make_clue_marker("goal")
	marker.position = finish + Vector3(0, 1.1, 0)
	root.add_child(marker)

func reset() -> void:
	completed = false
	active = true
	_restore_ball()

func step() -> String:
	if not active or ball == null or not is_instance_valid(ball):
		return ""
	if ball.global_position.y < float(data.get("kill_y", -30.0)) + 1.0:
		_restore_ball()
		return "lost"
	var horizontal := Vector2(ball.global_position.x - finish.x, ball.global_position.z - finish.z).length()
	if ball.global_position.z <= finish.z and horizontal <= goal_radius:
		active = false
		completed = true
		ball.freeze = true
		return "finished"
	return ""

func _restore_ball() -> void:
	if ball == null or not is_instance_valid(ball):
		return
	ball.freeze = false
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.global_position = home

func _build_ball(mass: float) -> void:
	ball = RigidBody3D.new()
	ball.name = "ClayGuideBall"
	ball.mass = mass
	ball.linear_damp = 0.65
	ball.angular_damp = 0.32
	ball.continuous_cd = true
	ball.add_to_group("pushable")
	var pm := PhysicsMaterial.new()
	pm.friction = 0.7
	pm.rough = true
	ball.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.1
	cs.shape = shape
	ball.add_child(cs)
	ball.add_child(PropFactory.make_clay_ball())
	root.add_child(ball)
	ball.global_position = home

func _build_channel(start_z: float, finish_z: float, half_width: float) -> void:
	var center_z := (start_z + finish_z) * 0.5
	var length := absf(start_z - finish_z) + 7.0
	var x := terrain.path_x(center_z)
	var rail_body := StaticBody3D.new()
	rail_body.name = "ClayCourseRails"
	var rail_mat := PropFactory.mat(Color("#826549"), 1.0)
	for side: float in [-1.0, 1.0]:
		var rail_x: float = x + side * half_width
		var y: float = terrain.height(rail_x, center_z) + 0.55
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.48, 1.1, length)
		cs.shape = shape
		cs.position = Vector3(rail_x, y, center_z)
		rail_body.add_child(cs)
		rail_body.add_child(PropFactory.part(PropFactory.box(Vector3(0.5, 1.1, length)), rail_mat, Vector3(rail_x, y, center_z)))
	# A painted centre line makes the route readable without adding per-frame work.
	var line := PropFactory.part(PropFactory.box(Vector3(0.16, 0.035, length)), PropFactory.mat(Color("#d5b56d"), 0.75, 0.0, 0.12), Vector3(x, terrain.height(x, center_z) + 0.025, center_z))
	rail_body.add_child(line)
	root.add_child(rail_body)
