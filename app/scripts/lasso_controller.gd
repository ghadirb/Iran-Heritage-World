class_name LassoController
extends RefCounted
## Chapter 10: a herd runs across a meadow; one colt (Rakhsh: saffron with rose-red dapples) is the one to lasso.
## Face a horse that is close enough and press the lasso button: the nearest horse inside the throw cone is
## caught. Any other horse is simply released (it bends under the hand in the story), only Rakhsh stays.
## Nothing can fail: a missed or wrong throw costs a short cooldown (and a mistake), never the level.

const COATS := ["#8a8a8a", "#6b4a32", "#e3dfd4", "#3a3430", "#a88a62", "#7a6a5a"]

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var horses: Array[Dictionary] = []    # {node, dir, speed, lane, phase, rakhsh}
var half_width := 22.0
var throw_range := 10.0
var cone := deg_to_rad(28.0)
var cooldown := 0.0
var elapsed := 0.0
var caught := false
var wrong := 0
var throws := 0
var rope: MeshInstance3D
var rope_t := 0.0
var rope_target: Node3D
var active := false

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["lasso"]
	half_width = float(data["half_width"])
	throw_range = float(data["range"])
	cone = deg_to_rad(float(data["cone"]))
	var count := int(data["count"])
	var z0 := float(data["z0"])
	var z1 := float(data["z1"])
	var speed := float(data["speed"])
	var rakhsh_index := int(data.get("rakhsh_index", 2)) % count
	for i in range(count):
		var lane := lerpf(z0, z1, float(i) / float(maxi(count - 1, 1)))
		var is_rakhsh := i == rakhsh_index
		var node := PropFactory.make_horse(Color("#e6a93c") if is_rakhsh else Color(COATS[i % COATS.size()]), is_rakhsh)
		node.name = "Rakhsh" if is_rakhsh else "Horse"
		var dir := 1.0 if i % 2 == 0 else -1.0
		var x := lerpf(-half_width, half_width, fmod(float(i) * 0.37 + 0.15, 1.0))
		node.position = Vector3(x, terrain.height(x, lane), lane)
		root.add_child(node)
		horses.append({"node": node, "dir": dir, "speed": speed * (1.0 + 0.12 * float(i % 3)), "lane": lane, "phase": float(i) * 0.9, "rakhsh": is_rakhsh})
	rope = PropFactory.part(PropFactory.cylinder(0.04, 0.04, 1.0, 6), PropFactory.mat(Color("#b8894a"), 0.9), Vector3.ZERO)
	rope.visible = false
	rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rope)

func reset() -> void:
	active = true
	caught = false
	wrong = 0
	throws = 0
	cooldown = 0.0
	rope.visible = false
	rope_target = null

func rakhsh() -> Dictionary:
	for h in horses:
		if bool(h["rakhsh"]):
			return h
	return {}

func step(delta: float, player_pos: Vector3, facing_y: float) -> String:
	if not active:
		return ""
	elapsed += delta
	cooldown = maxf(cooldown - delta, 0.0)
	for h in horses:
		var n: Node3D = h["node"]
		if bool(h["rakhsh"]) and caught:
			# the caught colt follows the courier's side
			var side := Basis(Vector3.UP, facing_y) * Vector3(2.2, 0.0, -1.6)
			var want := player_pos + side
			n.position = n.position.lerp(Vector3(want.x, terrain.height(want.x, want.z), want.z), minf(delta * 3.0, 1.0))
			n.rotation.y = lerp_angle(n.rotation.y, facing_y, minf(delta * 4.0, 1.0))
			continue
		var x := n.position.x + float(h["dir"]) * float(h["speed"]) * delta
		if x > half_width:
			x = -half_width
		elif x < -half_width:
			x = half_width
		n.position = Vector3(x, terrain.height(x, float(h["lane"])) + absf(sin(elapsed * 9.0 + float(h["phase"]))) * 0.07, float(h["lane"]))
		n.rotation.y = PI * 0.5 * float(h["dir"])
	# rope: flies out, then stays on Rakhsh once caught
	if is_instance_valid(rope_target):
		var from := player_pos + Vector3(0, 1.2, 0)
		var to := rope_target.global_position + Vector3(0, 1.6, 0)
		rope.visible = true
		rope.global_position = (from + to) * 0.5
		rope.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
		rope.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		rope.scale = Vector3(1, from.distance_to(to), 1)
		if not caught:
			rope_t -= delta
			if rope_t <= 0.0:
				rope.visible = false
				rope_target = null
	return ""

## Returns "caught", "wrong", "none" (no horse in the cone/range) or "cooldown".
func throw_lasso(player_pos: Vector3, facing_y: float) -> String:
	if not active or caught:
		return "cooldown"
	if cooldown > 0.0:
		return "cooldown"
	cooldown = 1.1
	throws += 1
	var fwd := Vector3(sin(facing_y), 0.0, cos(facing_y))
	var best: Dictionary = {}
	var best_angle := cone
	for h in horses:
		var rel: Vector3 = (h["node"] as Node3D).global_position - player_pos
		rel.y = 0.0
		var dist := rel.length()
		if dist > throw_range or dist < 1.0:
			continue
		var ang := fwd.angle_to(rel)
		if ang < best_angle:
			best_angle = ang
			best = h
	if best.is_empty():
		return "none"
	rope_target = best["node"]
	rope_t = 0.35
	if bool(best["rakhsh"]):
		caught = true
		return "caught"
	wrong += 1
	return "wrong"
