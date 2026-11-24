class_name SinkingStonesController
extends RefCounted
## Chapter 17: stepping stones over a river gorge. A stone starts crumbling the moment it is stepped on:
## it shakes, then drops out for a few seconds and comes back. Solid rest pads (static, never crumbling) are
## the checkpoints; falling only returns the player to the last pad, so the level is always finishable.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var tiles: Array[Dictionary] = []     # {pos: Vector3 (top centre), body, mesh, mat, state, t, stepped}
var pads: Array[Vector3] = []
var radius := 1.5
var spacing := 3.4
var hold := 1.0
var down_time := 3.0
var finish_z := -92.0
var active := false
var crossed := false
var crumbled := 0

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["sinking_stones"]
	radius = float(data["radius"])
	spacing = float(data["spacing"])
	hold = float(data["hold"])
	down_time = float(data["down_time"])
	finish_z = float(data["finish_z"])
	var chasm: Dictionary = data["chasm"]
	var z0 := float(chasm["z0"])
	var z1 := float(chasm["z1"])
	var pad_z: Array = data["pads"]
	var stops: Array[float] = [z0 - 4.0]
	for pz in pad_z:
		stops.append(float(pz))
	stops.append(z1)
	var zig := 1.0
	for i in range(stops.size() - 1):
		var a := stops[i]
		var b := stops[i + 1]
		# last stone sits ~1 m from the next pad's edge (a pad is 3.4 m long; the far bank has no pad)
		var pad_half := 1.7 if i < stops.size() - 2 else 0.0
		var end_z := b + pad_half + 1.0 + radius
		# the first stone after a pad starts ~1 m beyond the pad's far edge (not on top of the pad)
		var start_z := a if i == 0 else a - (1.7 + 1.0 + radius)
		var n := maxi(int(ceil((start_z - end_z) / spacing)), 1)
		for k in range(n + 1):
			var z := lerpf(start_z, end_z, float(k) / float(n))
			var x := terrain.path_x(z) + zig
			zig = -zig
			_build_tile(Vector3(x, _deck(z), z))
	for pz in pad_z:
		_build_pad(float(pz))
	if bool(data.get("water", true)):   # a mountain gorge (Damavand) has no river at its bottom
		_build_water(z0, z1)

func reset() -> void:
	active = true
	crossed = false
	crumbled = 0
	for t in tiles:
		_set_state(t, "idle")
		t["stepped"] = false
		t["t"] = 0.0

func step(delta: float, pos: Vector3, on_floor: bool) -> String:
	if not active:
		return ""
	for t in tiles:
		var top: Vector3 = t["pos"]
		var near := Vector2(pos.x - top.x, pos.z - top.z).length() < radius + 0.1 and pos.y > top.y - 0.3 and pos.y < top.y + 1.3
		match str(t["state"]):
			"idle":
				if near and on_floor:
					t["stepped"] = true
				if bool(t["stepped"]):
					t["t"] = float(t["t"]) + delta
					_wobble(t, float(t["t"]) > hold * 0.5)
					if float(t["t"]) >= hold:
						_set_state(t, "gone")
						t["t"] = 0.0
						crumbled += 1
			"gone":
				t["t"] = float(t["t"]) + delta
				if float(t["t"]) >= down_time and not (Vector2(pos.x - top.x, pos.z - top.z).length() < radius + 1.2 and pos.y > top.y - 2.5):
					_set_state(t, "idle")
					t["stepped"] = false
					t["t"] = 0.0
	if pos.z <= finish_z:
		active = false
		crossed = true
		return "crossed"
	return ""

func static_checkpoint(pos: Vector3) -> Vector3:
	var best := Vector3.ZERO
	for pad in pads:
		if Vector2(pos.x - pad.x, pos.z - pad.z).length() < 2.3 and absf(pos.y - pad.y) < 1.6:
			best = pad + Vector3(0, 0.75, 0)
	return best

## Next place a walking bot should aim for: the first stone or pad ahead of it, then the far bank.
func guide_point(pos: Vector3) -> Vector3:
	var best_z := -1e9
	var best := Vector3(terrain.path_x(finish_z), 0.0, finish_z)
	var found := false
	for t in tiles:
		var p: Vector3 = t["pos"]
		if p.z < pos.z - 1.4 and (not found or p.z > best_z) and str(t["state"]) == "idle":
			best_z = p.z
			best = p
			found = true
	for pad in pads:
		if pad.z < pos.z - 1.4 and (not found or pad.z > best_z):
			best_z = pad.z
			best = pad
			found = true
	return best

func _deck(z: float) -> float:
	var chasm: Dictionary = data["chasm"]
	var za := float(chasm["z0"]) + 1.5
	var zb := float(chasm["z1"]) - 2.5
	var ya := terrain.height(terrain.path_x(za), za)
	var yb := terrain.height(terrain.path_x(zb), zb)
	return lerpf(ya, yb, inverse_lerp(za, zb, z)) + 0.05

func _set_state(t: Dictionary, state: String) -> void:
	t["state"] = state
	var body: StaticBody3D = t["body"]
	var gone := state == "gone"
	body.collision_layer = 0 if gone else 1
	body.collision_mask = 0 if gone else 1
	body.visible = not gone
	if not gone:
		_wobble(t, false)

func _wobble(t: Dictionary, shaking: bool) -> void:
	var body: StaticBody3D = t["body"]
	var top: Vector3 = t["pos"]
	var mat: StandardMaterial3D = t["mat"]
	if shaking:
		var k := float(t["t"]) * 38.0
		body.position = top + Vector3(sin(k) * 0.07, 0.0, cos(k * 1.3) * 0.07)
		mat.albedo_color = Color("#b8683f")
	else:
		body.position = top
		mat.albedo_color = Color("#8d8473") if not bool(t["stepped"]) else Color("#a07a56")

func _build_tile(top: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "SinkingStone"
	body.position = top
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 0.6
	cs.shape = shape
	cs.position = Vector3(0, -0.3, 0)
	body.add_child(cs)
	var mat := PropFactory.mat(Color("#8d8473"), 1.0)
	body.add_child(PropFactory.part(PropFactory.cylinder(radius, radius + 0.15, 0.6, 14), mat, Vector3(0, -0.3, 0)))
	root.add_child(body)
	tiles.append({"pos": top, "body": body, "mat": mat, "state": "idle", "t": 0.0, "stepped": false})

func _build_pad(z: float) -> void:
	var x := terrain.path_x(z)
	var y := _deck(z)
	var pad := StaticBody3D.new()
	pad.name = "RestPad"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.4, 0.65, 3.4)
	cs.shape = shape
	cs.position = Vector3(x, y - 0.33, z)
	pad.add_child(cs)
	pad.add_child(PropFactory.part(PropFactory.box(Vector3(5.4, 0.55, 3.4)), PropFactory.mat(Color("#9b7043"), 0.95), Vector3(x, y - 0.28, z)))
	pad.add_child(PropFactory.part(PropFactory.cylinder(0.09, 0.09, 6.0, 8), PropFactory.beam_material(), Vector3(x, y + 3.0, z)))
	root.add_child(pad)
	pads.append(Vector3(x, y, z))

func _build_water(z0: float, z1: float) -> void:
	var m := PropFactory.mat(Color("#2f6f93"), 0.1, 0.2)
	var length := absf(z1 - z0) + 6.0
	var w := PropFactory.part(PropFactory.box(Vector3(60.0, 0.2, length)), m, Vector3(0, -5.5, (z0 + z1) * 0.5))
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(w)
