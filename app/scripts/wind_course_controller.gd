class_name WindCourseController
extends RefCounted
## Timed wind gates for a lightweight mobile course. Gusts are visual nodes;
## proximity is checked against a few data points instead of physics bodies.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var gusts: Array[Dictionary] = []
var finish_z := -100.0
var speed := 1.0
var sweep := 10.0
var radius := 2.0
var active := false
var escaped := false
var elapsed := 0.0
var passed := 0

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["wind_course"]
	finish_z = float(data["finish_z"])
	speed = float(data["speed"])
	sweep = float(data["sweep"])
	radius = float(data["radius"])
	var count := int(data["count"])
	var points: Array = data["gusts"]
	for i in range(mini(count, points.size())):
		var point: Dictionary = points[i]
		var node := PropFactory.make_wind_gust()
		root.add_child(node)
		gusts.append({"node": node, "z": float(point["z"]), "phase": float(point["phase"]), "passed": false})

func reset() -> void:
	elapsed = 0.0
	passed = 0
	escaped = false
	active = true
	for gust in gusts:
		gust["passed"] = false

func step(delta: float, player_position: Vector3) -> String:
	if not active:
		return ""
	elapsed += delta
	for gust in gusts:
		var p := _gust_position(gust)
		var node: Node3D = gust["node"]
		node.position = p
		node.rotation.y = sin(elapsed * speed + float(gust["phase"])) * 0.25
		if not bool(gust["passed"]) and player_position.z < float(gust["z"]) - 3.0:
			gust["passed"] = true
			passed += 1
			return "checkpoint"
		if not bool(gust["passed"]) and Vector2(player_position.x - p.x, player_position.z - p.z).length() < radius:
			return "caught"
	if passed == gusts.size() and player_position.z <= finish_z:
		active = false
		escaped = true
		return "escaped"
	return ""

func next_gust(player_position: Vector3) -> Dictionary:
	for gust in gusts:
		if not bool(gust["passed"]) and float(gust["z"]) < player_position.z - 0.5:
			return gust
	return {}

func gust_position(gust: Dictionary) -> Vector3:
	return _gust_position(gust)

## True while this gust is sweeping away from the central route.
func is_moving_away_from_path(gust: Dictionary) -> bool:
	var phase := elapsed * speed + float(gust["phase"])
	return sin(phase) * cos(phase) > 0.0

func _gust_position(gust: Dictionary) -> Vector3:
	var x := sin(elapsed * speed + float(gust["phase"])) * sweep
	var z := float(gust["z"])
	return Vector3(x, terrain.height(x, z) + 1.25, z)
