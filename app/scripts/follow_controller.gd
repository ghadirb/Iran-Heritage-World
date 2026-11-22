class_name FollowController
extends RefCounted
## Chapter 11, second labour: a wild ram leads the way through a waterless desert to a spring. It walks ahead and
## waits when the courier lags. Blue mirages (pools) shimmer off the path; running to one only makes it
## vanish (a mistake). Nothing can fail: the ram always waits.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var ram: Node3D
var points: Array[Vector3] = []
var idx := 0
var speed := 3.4
var wait_dist := 14.0
var mirages: Array[Dictionary] = []   # {pos, node, gone}
var mirage_radius := 3.0
var spring: Vector3
var active := false
var reached := false
var vanished := 0
var elapsed := 0.0

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["follow"]
	speed = float(data["speed"])
	wait_dist = float(data["wait_dist"])
	var fz := float(data["finish_z"])
	var count := int(data["points"])
	var z0 := float(data["start_z"])
	for i in range(count + 1):
		var z := lerpf(z0, fz, float(i) / float(count))
		var x := terrain.path_x(z) + sin(float(i) * 1.7) * float(data["sway"])
		points.append(Vector3(x, terrain.height(x, z), z))
	spring = points[points.size() - 1]
	ram = PropFactory.make_ram()
	ram.position = points[0]
	root.add_child(ram)
	_build_spring(spring)
	var offsets: Array = data["mirage_offsets"]
	for k in range(offsets.size()):
		var seg := clampi(1 + k * 2, 1, points.size() - 2)
		var side := 1.0 if k % 2 == 0 else -1.0
		var p := points[seg] + Vector3(side * float(offsets[k]), 0, 0)
		p.y = terrain.height(p.x, p.z)
		var disc := PropFactory.part(PropFactory.cylinder(2.6, 2.6, 0.05, 20), PropFactory.mat(Color("#5fb4ec"), 0.1, 0.2, 0.8), Vector3.ZERO)
		disc.position = p + Vector3(0, 0.06, 0)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(disc)
		mirages.append({"pos": p, "node": disc, "gone": false})

func reset() -> void:
	active = true
	reached = false
	vanished = 0
	idx = 0
	elapsed = 0.0
	ram.position = points[0]
	for m in mirages:
		m["gone"] = false
		(m["node"] as Node3D).visible = true

## Returns "mirage", "reached" or "".
func step(delta: float, player_pos: Vector3) -> String:
	if not active:
		return ""
	elapsed += delta
	var result := ""
	var pd := Vector2(player_pos.x - ram.position.x, player_pos.z - ram.position.z).length()
	if idx < points.size() - 1 and pd < wait_dist:
		var target := points[idx + 1]
		var to := target - ram.position
		to.y = 0.0
		if to.length() < 0.6:
			idx += 1
		else:
			ram.position += to.normalized() * speed * delta
			ram.position.y = terrain.height(ram.position.x, ram.position.z) + absf(sin(elapsed * 8.0)) * 0.05
			ram.rotation.y = atan2(to.x, to.z)
	for m in mirages:
		if bool(m["gone"]):
			continue
		var mp: Vector3 = m["pos"]
		if Vector2(player_pos.x - mp.x, player_pos.z - mp.z).length() < mirage_radius:
			m["gone"] = true
			(m["node"] as Node3D).visible = false
			vanished += 1
			result = "mirage"
	if idx >= points.size() - 1 and Vector2(player_pos.x - spring.x, player_pos.z - spring.z).length() < 5.0:
		active = false
		reached = true
		return "reached"
	return result

func _build_spring(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	n.add_child(PropFactory.part(PropFactory.cylinder(2.2, 2.4, 0.3, 18), PropFactory.mat(Color("#8a8070"), 1.0), Vector3(0, 0.1, 0)))
	n.add_child(PropFactory.part(PropFactory.cylinder(1.9, 1.9, 0.2, 18), PropFactory.mat(Color("#2f8fd0"), 0.05, 0.3, 0.5), Vector3(0, 0.28, 0)))
	root.add_child(n)
