class_name IceLakeController
extends RefCounted
## Chapter 16: a frozen lake. On the ice the courier slides (low acceleration, so speed and braking are
## slow); stone islands give grip and act as checkpoints; thin-ice holes (dark discs) drop the courier back
## to the last island. Holes are never placed inside the corridor that joins the islands, so a careful
## route always exists. Jumping over a hole is allowed.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var islands: Array[Vector2] = []
var island_radius := 4.0
var holes: Array[Vector3] = []          # (x, z, radius)
var lake_min := Vector2(-22.0, -118.0)
var lake_max := Vector2(22.0, -12.0)
var ice_accel := 5.0
var corridor := 3.0
var ground_y := 0.0
var on_ice := false
var last_island := -1                   # -1 = none yet (spawn is used)
var best_island := -1
var started := false
var active := false
var arrived := false
var plunges := 0

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary, spawn: Vector2) -> void:
	root = parent
	terrain = terrain_builder
	data = level["ice_lake"]
	island_radius = float(data["island_radius"])
	ice_accel = float(data["accel"])
	corridor = float(data["corridor"])
	lake_min = data["lake_min"]
	lake_max = data["lake_max"]
	for p in (data["islands"] as Array):
		islands.append(p)
	ground_y = terrain.height(0.0, (lake_min.y + lake_max.y) * 0.5)
	var route: Array[Vector2] = [spawn]
	route.append_array(islands)
	_make_holes(route)
	_build_lake()
	for p in islands:
		_build_island(p)
	for h in holes:
		_build_hole(h)

func reset() -> void:
	on_ice = false
	last_island = -1
	best_island = -1
	started = false
	active = true
	arrived = false
	plunges = 0

func island_center(i: int) -> Vector3:
	var p := islands[i]
	return Vector3(p.x, terrain.height(p.x, p.y), p.y)

func in_lake(p: Vector2) -> bool:
	return p.x > lake_min.x and p.x < lake_max.x and p.y > lake_min.y and p.y < lake_max.y

func on_island(p: Vector2) -> int:
	for i in range(islands.size()):
		if p.distance_to(islands[i]) < island_radius:
			return i
	return -1

func step(_delta: float, pos: Vector3) -> String:
	if not active:
		return ""
	var p := Vector2(pos.x, pos.z)
	var isl := on_island(p)
	on_ice = in_lake(p) and isl < 0
	var result := ""
	if not started and on_ice:
		started = true
		result = "start"
	if isl >= 0 and isl != last_island:
		last_island = isl
		best_island = maxi(best_island, isl)
		if isl == islands.size() - 1:
			active = false
			arrived = true
			return "arrived"
	if on_ice and pos.y < ground_y + 0.8:
		for h in holes:
			if p.distance_to(Vector2(h.x, h.y)) < h.z - 0.25:
				plunges += 1
				return "plunge"
	return result

func _dist_to_route(p: Vector2, route: Array[Vector2]) -> float:
	var best := 1e9
	for i in range(route.size() - 1):
		var cp := Geometry2D.get_closest_point_to_segment(p, route[i], route[i + 1])
		best = minf(best, cp.distance_to(p))
	return best

func _make_holes(route: Array[Vector2]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data["seed"])
	var count := int(data["hole_count"])
	var radius := float(data["hole_radius"])
	var tries := 0
	while holes.size() < count and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(lake_min.x + radius + 0.5, lake_max.x - radius - 0.5), rng.randf_range(lake_min.y + radius + 0.5, lake_max.y - radius - 0.5))
		if _dist_to_route(p, route) < radius + corridor:
			continue
		var ok := true
		for isl in islands:
			if p.distance_to(isl) < island_radius + radius + 1.0:
				ok = false
		for h in holes:
			if p.distance_to(Vector2(h.x, h.y)) < radius + h.z + 1.5:
				ok = false
		if ok:
			holes.append(Vector3(p.x, p.y, radius))

func _build_lake() -> void:
	var size := lake_max - lake_min
	var c := (lake_min + lake_max) * 0.5
	var m := PropFactory.mat(Color("#bfe0f2"), 0.08, 0.15)
	var ice := PropFactory.part(PropFactory.box(Vector3(size.x, 0.1, size.y)), m, Vector3(c.x, ground_y + 0.03, c.y))
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ice)

func _build_island(p: Vector2) -> void:
	var n := Node3D.new()
	n.name = "StoneIsland"
	n.position = Vector3(p.x, terrain.height(p.x, p.y), p.y)
	n.add_child(PropFactory.part(PropFactory.cylinder(island_radius, island_radius + 0.2, 0.34, 20), PropFactory.mat(Color("#7d7468"), 1.0), Vector3(0, 0.14, 0)))
	n.add_child(PropFactory.part(PropFactory.cylinder(island_radius - 0.5, island_radius - 0.5, 0.06, 20), PropFactory.mat(Color("#a79c8a"), 1.0), Vector3(0, 0.33, 0)))
	n.add_child(PropFactory.part(PropFactory.cylinder(0.09, 0.09, 6.0, 8), PropFactory.beam_material(), Vector3(0, 3.0, 0)))
	root.add_child(n)

func _build_hole(h: Vector3) -> void:
	var n := Node3D.new()
	n.name = "ThinIce"
	n.position = Vector3(h.x, ground_y + 0.09, h.y)
	var dark := PropFactory.part(PropFactory.cylinder(h.z, h.z, 0.04, 20), PropFactory.mat(Color("#0b2238"), 0.2), Vector3.ZERO)
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(dark)
	var ring := PropFactory.part(TorusMesh.new(), PropFactory.mat(Color("#f2f8ff"), 0.6), Vector3(0, 0.02, 0))
	(ring.mesh as TorusMesh).inner_radius = h.z - 0.18
	(ring.mesh as TorusMesh).outer_radius = h.z + 0.12
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	root.add_child(n)
