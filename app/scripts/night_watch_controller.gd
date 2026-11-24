class_name NightWatchController
extends RefCounted
## Chapter 15: a night crossing. Watch-lantern towers sweep a beam of light around them. Awnings (shade
## zones) are always safe and act as checkpoints. Standing in a beam outside the shade for longer than a
## short grace time sends the courier back to the last awning; nothing else can fail and there is no
## time limit, so the level always stays finishable.

const BEAM_HEIGHT := 0.22
const SEGMENTS := 14

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var towers: Array[Dictionary] = []     # {pos: Vector2, phase: float (rad), dir: float, node: Node3D}
var zones: Array[Vector2] = []
var zone_radius := 3.0
var beam_range := 20.0
var half_angle := deg_to_rad(20.0)
var omega := deg_to_rad(30.0)          # rad/s
var grace := 0.35
var elapsed := 0.0
var expo := 0.0
var zone := -1
var best_zone := -1
var last_zone := -1                    # -1 = none yet (spawn is used)
var started := false
var active := false
var arrived := false
var seen_count := 0

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["night_watch"]
	zone_radius = float(data["zone_radius"])
	beam_range = float(data["range"])
	half_angle = deg_to_rad(float(data["half_angle"]))
	omega = deg_to_rad(float(data["omega"]))
	grace = float(data["grace"])
	for z in (data["zones"] as Array):
		var p: Vector2 = z
		zones.append(p)
		_build_awning(p)
	for t in (data["towers"] as Array):
		var td: Dictionary = t
		var entry := {"pos": td["pos"], "phase": deg_to_rad(float(td["phase"])), "dir": float(td["dir"]), "node": null}
		entry["node"] = _build_tower(entry)
		towers.append(entry)

func reset() -> void:
	elapsed = 0.0
	expo = 0.0
	zone = -1
	best_zone = -1
	last_zone = -1
	started = false
	active = true
	arrived = false
	seen_count = 0
	_update_visuals()

func after_seen() -> void:
	expo = 0.0
	zone = -1

func zone_center(i: int) -> Vector3:
	var p := zones[i]
	return Vector3(p.x, terrain.height(p.x, p.y), p.y)

func tower_angle(i: int, t: float) -> float:
	var td: Dictionary = towers[i]
	return float(td["phase"]) + float(td["dir"]) * omega * t

func in_shade(p: Vector2) -> bool:
	for z in zones:
		if p.distance_to(z) < zone_radius:
			return true
	return false

## True when point p (x, z) is lit by some beam at time t. `margin_deg` widens the beam (used by bots).
func lit(p: Vector2, t: float, margin_deg: float = 0.0) -> bool:
	if in_shade(p):
		return false
	var wide := half_angle + deg_to_rad(margin_deg)
	for i in range(towers.size()):
		var tp: Vector2 = (towers[i] as Dictionary)["pos"]
		var d := p - tp
		if d.length() > beam_range + margin_deg * 0.1:
			continue
		var diff := absf(wrapf(d.angle() - tower_angle(i, t), -PI, PI))
		if diff < wide:
			return true
	return false

func step(delta: float, pos: Vector3, _on_floor: bool) -> String:
	if not active:
		return ""
	elapsed += delta
	_update_visuals()
	var p := Vector2(pos.x, pos.z)
	var result := ""
	if not started and pos.z < 4.0:
		started = true
		result = "watch"
	var in_zone := -1
	for i in range(zones.size()):
		if p.distance_to(zones[i]) < zone_radius:
			in_zone = i
	if in_zone >= 0 and in_zone != zone:
		zone = in_zone
		last_zone = in_zone
		best_zone = maxi(best_zone, in_zone)
		if in_zone == zones.size() - 1:
			active = false
			arrived = true
			return "arrived"
	elif in_zone < 0:
		zone = -1
	if lit(p, elapsed):
		expo += delta
		if expo >= grace:
			seen_count += 1
			return "seen"
	else:
		expo = maxf(expo - 2.0 * delta, 0.0)
	return result

func _update_visuals() -> void:
	for i in range(towers.size()):
		var n: Node3D = (towers[i] as Dictionary)["node"]
		if is_instance_valid(n):
			var beam := n.get_node_or_null("Beam") as Node3D
			if beam:
				beam.rotation.y = -tower_angle(i, elapsed)

func _build_awning(p: Vector2) -> void:
	var n := Node3D.new()
	n.name = "ShadeAwning"
	n.position = Vector3(p.x, terrain.height(p.x, p.y), p.y)
	var wood := PropFactory.mat(Color("#6b4a2b"), 0.9)
	for c in [Vector2(1.4, 1.4), Vector2(-1.4, 1.4), Vector2(1.4, -1.4), Vector2(-1.4, -1.4)]:
		n.add_child(PropFactory.part(PropFactory.cylinder(0.08, 0.1, 2.5, 8), wood, Vector3(c.x, 1.25, c.y)))
	n.add_child(PropFactory.part(PropFactory.box(Vector3(3.4, 0.12, 3.4)), PropFactory.mat(Color("#9b3b2e"), 0.95), Vector3(0, 2.55, 0)))
	var ring := PropFactory.part(TorusMesh.new(), PropFactory.mat(Color("#7fd0ff"), 0.3, 0.2, 1.6), Vector3(0, 0.1, 0))
	(ring.mesh as TorusMesh).inner_radius = zone_radius - 0.12
	(ring.mesh as TorusMesh).outer_radius = zone_radius
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	root.add_child(n)

func _build_tower(entry: Dictionary) -> Node3D:
	var p: Vector2 = entry["pos"]
	var n := Node3D.new()
	n.name = "WatchTower"
	var y := terrain.height(p.x, p.y)
	n.position = Vector3(p.x, y, p.y)
	n.add_child(PropFactory.part(PropFactory.cylinder(0.9, 1.3, 5.0, 12), PropFactory.mat(Color("#8f8777"), 1.0), Vector3(0, 2.5, 0)))
	n.add_child(PropFactory.part(PropFactory.sphere(0.42, 10), PropFactory.mat(Color("#ffd36b"), 0.2, 0.0, 2.6), Vector3(0, 5.4, 0)))
	var beam := Node3D.new()
	beam.name = "Beam"
	beam.position = Vector3(0, BEAM_HEIGHT, 0)
	var mi := MeshInstance3D.new()
	mi.mesh = _sector_mesh()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.4, 0.32)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(mi)
	n.add_child(beam)
	root.add_child(n)
	return n

## Flat fan, pointing along +X in the node's own space (rotation.y = -angle turns it to the world angle).
func _sector_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.append(Vector3.ZERO)
	for i in range(SEGMENTS + 1):
		var a := -half_angle + 2.0 * half_angle * float(i) / float(SEGMENTS)
		verts.append(Vector3(cos(a), 0.0, sin(a)) * beam_range)
	for i in range(SEGMENTS):
		idx.append(0)
		idx.append(i + 1)
		idx.append(i + 2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
