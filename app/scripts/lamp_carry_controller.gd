class_name LampCarryController
extends RefCounted
## Chapter 12: carry a caravan lamp along a road. Running or jumping spills its oil;
## calm steps keep the flame. Oil jars (static, never moving) refill the lamp and act as the
## checkpoints. A lamp that goes out only returns the player to the last jar, so the level
## always stays finishable.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var stations: Array[Vector3] = []
var visited: Array[bool] = []
var finish_pos := Vector3.ZERO
var finish_radius := 3.2
var refill_radius := 3.0
var walk_limit := 4.4
var drain := 0.2
var jump_cost := 0.15
var need := 0.2
var oil := 1.0
var elapsed := 0.0
var zone := -1
var last_station := Vector3.ZERO     # Vector3.ZERO = none yet (spawn is used instead)
var was_on_floor := true
var warn_cool := 0.0
var low_cool := 0.0
var refills := 0
var outs := 0
var active := false
var arrived := false
var item := "lamp"          # "lamp", "cylinder" (fragile clay cylinder) or "gift" (a golden cup carried to a gate)
var lamp: Node3D
var item_mat: StandardMaterial3D
var flame: MeshInstance3D
var light: OmniLight3D

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["lamp_road"]
	item = str(data.get("item", "lamp"))
	walk_limit = float(data["walk_limit"])
	drain = float(data["drain"])
	jump_cost = float(data["jump_cost"])
	need = float(data["need"])
	refill_radius = float(data.get("refill_radius", 3.0))
	var fz := float(data["finish_z"])
	finish_pos = Vector3(terrain.path_x(fz), terrain.height(terrain.path_x(fz), fz), fz)
	for z_value in (data["stations"] as Array):
		var z := float(z_value)
		var x := terrain.path_x(z)
		var p := Vector3(x, terrain.height(x, z), z)
		stations.append(p)
		visited.append(false)
		_build_station(p)
	_build_tower(finish_pos)
	_build_lamp()

func reset() -> void:
	oil = 1.0
	elapsed = 0.0
	zone = -1
	last_station = Vector3.ZERO
	was_on_floor = true
	warn_cool = 0.0
	low_cool = 0.0
	refills = 0
	outs = 0
	arrived = false
	active = true
	for i in range(visited.size()):
		visited[i] = false

## Called after the world put the player back at the last jar.
func after_out() -> void:
	oil = 1.0
	zone = -1
	was_on_floor = true

func step(delta: float, pos: Vector3, vel: Vector3, on_floor: bool, facing_y: float) -> String:
	if not active:
		return ""
	elapsed += delta
	warn_cool = maxf(warn_cool - delta, 0.0)
	low_cool = maxf(low_cool - delta, 0.0)
	_follow(pos, facing_y)
	var speed := Vector2(vel.x, vel.z).length()
	if was_on_floor and not on_floor and vel.y > 3.0:
		oil -= jump_cost
	was_on_floor = on_floor
	if on_floor and speed > walk_limit:
		oil -= drain * delta
	var result := ""
	var in_zone := -1
	for i in range(stations.size()):
		var s := stations[i]
		if Vector2(pos.x - s.x, pos.z - s.z).length() < refill_radius and absf(pos.y - s.y) < 3.0:
			in_zone = i
	if in_zone >= 0:
		if in_zone != zone:
			zone = in_zone
			visited[in_zone] = true
			last_station = stations[in_zone]
			result = "refill" if oil < 0.9 else "station"
			if result == "refill":
				refills += 1
		oil = minf(1.0, oil + 0.9 * delta)
	else:
		zone = -1
	if oil <= 0.0:
		oil = 0.0
		outs += 1
		return "out"
	if Vector2(pos.x - finish_pos.x, pos.z - finish_pos.z).length() < finish_radius:
		if oil >= need:
			active = false
			arrived = true
			return "arrived"
		if low_cool <= 0.0:
			low_cool = 4.0
			return "low"
	if result == "" and oil < 0.3 and warn_cool <= 0.0:
		warn_cool = 8.0
		return "warn"
	return result

## Where a walking bot (or a hint) should head: the next jar it has not reached yet, then the tower.
func guide_point(_pos: Vector3) -> Vector3:
	for i in range(stations.size()):
		if not visited[i]:
			return stations[i]
	return finish_pos

func _follow(pos: Vector3, facing_y: float) -> void:
	if not is_instance_valid(lamp):
		return
	lamp.global_position = pos + Basis(Vector3.UP, facing_y) * Vector3(-0.42, 0.95, 0.22)
	if item != "lamp":
		# the object looks stressed as it loses its steadiness
		item_mat.albedo_color = (Color("#7a4a2c") if item == "cylinder" else Color("#8a6a1f")).lerp(Color("#c99a64") if item == "cylinder" else Color("#e6bd4c"), clampf(oil, 0.0, 1.0))
		return
	var flicker := 1.0 + 0.07 * sin(elapsed * 17.0)
	var k := (0.35 + 0.65 * clampf(oil, 0.0, 1.0)) * flicker
	flame.scale = Vector3.ONE * k
	light.light_energy = 0.3 + 1.3 * clampf(oil, 0.0, 1.0)

func _build_lamp() -> void:
	lamp = Node3D.new()
	lamp.name = "CaravanLamp"
	if item == "gift":
		item_mat = PropFactory.mat(Color("#e6bd4c"), 0.3, 0.6)
		lamp.add_child(PropFactory.part(PropFactory.cylinder(0.05, 0.08, 0.1, 10), item_mat, Vector3(0, -0.16, 0)))
		lamp.add_child(PropFactory.part(PropFactory.cylinder(0.17, 0.07, 0.22, 12), item_mat, Vector3(0, 0.0, 0)))
		root.add_child(lamp)
		return
	if item == "cylinder":
		item_mat = PropFactory.mat(Color("#c99a64"), 0.95)
		var cyl := PropFactory.part(PropFactory.cylinder(0.13, 0.13, 0.46, 12), item_mat, Vector3(0, 0.0, 0))
		cyl.rotation.z = PI * 0.5   # carried lying down, like the object in the museum
		lamp.add_child(cyl)
		root.add_child(lamp)
		return
	lamp.add_child(PropFactory.part(PropFactory.cylinder(0.12, 0.16, 0.22, 10), PropFactory.mat(Color("#8a5a3a"), 0.9), Vector3(0, -0.12, 0)))
	flame = PropFactory.part(PropFactory.sphere(0.13, 10), PropFactory.mat(Color("#ffb347"), 0.2, 0.0, 3.0), Vector3(0, 0.08, 0))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(flame)
	light = OmniLight3D.new()
	light.light_color = Color("#ffc062")
	light.omni_range = 6.0
	light.shadow_enabled = false
	lamp.add_child(light)
	root.add_child(lamp)

func _build_station(p: Vector3) -> void:
	var n := Node3D.new()
	n.name = "OilJar"
	n.position = p
	if item != "lamp":
		_build_rest_stand(n)
		return
	var clay := PropFactory.mat(Color("#a2603a"), 0.9)
	n.add_child(PropFactory.part(PropFactory.cylinder(0.7, 0.8, 0.25, 12), PropFactory.mat(Color("#7d7468"), 1.0), Vector3(0, 0.12, 0)))
	n.add_child(PropFactory.part(PropFactory.sphere(0.62, 14), clay, Vector3(0, 0.95, 0), Vector3(1.0, 1.15, 1.0)))
	n.add_child(PropFactory.part(PropFactory.cylinder(0.26, 0.34, 0.34, 10), clay, Vector3(0, 1.75, 0)))
	var glow := PropFactory.mat(Color("#ffd36b"), 0.2, 0.2, 2.2)
	var ring := PropFactory.part(TorusMesh.new(), glow, Vector3(0, 0.1, 0))
	(ring.mesh as TorusMesh).inner_radius = refill_radius - 0.12
	(ring.mesh as TorusMesh).outer_radius = refill_radius
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var beam := PropFactory.part(PropFactory.cylinder(0.09, 0.09, 7.0, 8), PropFactory.beam_material(), Vector3(0, 3.5, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	root.add_child(n)

## A low stone stand with a soft cloth cushion: where the fragile cylinder is allowed to rest.
func _build_rest_stand(n: Node3D) -> void:
	n.add_child(PropFactory.part(PropFactory.cylinder(0.7, 0.8, 0.25, 12), PropFactory.mat(Color("#7d7468"), 1.0), Vector3(0, 0.12, 0)))
	n.add_child(PropFactory.part(PropFactory.box(Vector3(1.5, 0.35, 0.9)), PropFactory.mat(Color("#9b3b2e"), 0.95), Vector3(0, 0.42, 0)))
	var glow := PropFactory.mat(Color("#ffd36b"), 0.2, 0.2, 2.2)
	var ring := PropFactory.part(TorusMesh.new(), glow, Vector3(0, 0.1, 0))
	(ring.mesh as TorusMesh).inner_radius = refill_radius - 0.12
	(ring.mesh as TorusMesh).outer_radius = refill_radius
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var beam := PropFactory.part(PropFactory.cylinder(0.09, 0.09, 7.0, 8), PropFactory.beam_material(), Vector3(0, 3.5, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	root.add_child(n)

func _build_tower(p: Vector3) -> void:
	var n := Node3D.new()
	n.name = "LampTower"
	n.position = p
	if item == "gift":
		# the Gate of All Nations, simplified: two tall stone columns and a lintel
		var stone := PropFactory.mat(Color("#a79c8a"), 1.0)
		n.add_child(PropFactory.part(PropFactory.cylinder(0.7, 0.8, 6.0, 12), stone, Vector3(-2.6, 3.0, 0)))
		n.add_child(PropFactory.part(PropFactory.cylinder(0.7, 0.8, 6.0, 12), stone, Vector3(2.6, 3.0, 0)))
		n.add_child(PropFactory.part(PropFactory.box(Vector3(7.2, 0.9, 1.4)), stone, Vector3(0, 6.3, 0)))
		n.add_child(PropFactory.part(PropFactory.sphere(0.3, 10), PropFactory.mat(Color("#ffd36b"), 0.2, 0.0, 2.4), Vector3(0, 7.2, 0)))
		root.add_child(n)
		return
	if item == "cylinder":
		# a mud-brick wall with an open foundation trench where the cylinder is laid
		var brick := PropFactory.mat(Color("#b08a5b"), 1.0)
		n.add_child(PropFactory.part(PropFactory.box(Vector3(2.4, 2.4, 0.9)), brick, Vector3(-2.2, 1.2, 0)))
		n.add_child(PropFactory.part(PropFactory.box(Vector3(2.4, 2.4, 0.9)), brick, Vector3(2.2, 1.2, 0)))
		n.add_child(PropFactory.part(PropFactory.box(Vector3(2.0, 1.1, 0.9)), brick, Vector3(0, 1.85, 0)))
		n.add_child(PropFactory.part(PropFactory.sphere(0.3, 10), PropFactory.mat(Color("#ffd36b"), 0.2, 0.0, 2.4), Vector3(0, 3.0, 0)))
		root.add_child(n)
		return
	var stone := PropFactory.mat(Color("#8f8777"), 1.0)
	n.add_child(PropFactory.part(PropFactory.cylinder(1.1, 1.5, 4.2, 12), stone, Vector3(0, 2.1, 0)))
	n.add_child(PropFactory.part(PropFactory.cylinder(1.5, 1.2, 0.5, 12), PropFactory.mat(Color("#6d6558"), 1.0), Vector3(0, 4.45, 0)))
	n.add_child(PropFactory.part(PropFactory.sphere(0.34, 10), PropFactory.mat(Color("#ffb347"), 0.2, 0.0, 2.6), Vector3(0, 5.0, 0)))
	root.add_child(n)
