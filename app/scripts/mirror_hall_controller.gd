class_name MirrorHallController
extends RefCounted
## Chapter 14: a hall of mirrors. A beam of light leaves a lamp, bounces off the mirrors and has to reach
## a far lantern. Next to every mirror lie two discs: standing on the yellow one turns the mirror clockwise,
## standing on the blue one turns it counter-clockwise, one small step at a time. Running across a disc does
## not turn anything (the first turn needs a longer stand), nothing can fail, and there is no time limit.

const PLUS_COLOR := "#e0b23a"    # clockwise
const MINUS_COLOR := "#4a8fd9"   # counter-clockwise
const START_RADIUS := 14.0       # the hint appears when the player comes this close to the first mirror
const MAX_BOUNCES := 6
const MAX_LENGTH := 60.0
const BEAM_HEIGHT := 1.1

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var layout: Dictionary
var source := Vector2.ZERO
var source_angle := 0.0                # radians, on the (x, z) plane
var target := Vector2.ZERO
var target_radius := 1.1
var mirror_half := 1.6
var step_deg := 15
var disc_radius := 1.3
var delay := 0.7                       # first turn after standing this long on a disc
var interval := 0.6                    # then one more step this often
var mirrors: Array[Dictionary] = []    # {pos: Vector2, phi: int (deg, 0..179), solution: int, start: int, node, plus: Vector2, minus: Vector2}
var phase := "idle"                    # idle | input | done
var solved := false
var turns := 0
var active := false
var dwell_disc := -1                   # mirror index * 2 + (0 plus, 1 minus); -1 none
var dwell_t := 0.0
var tick_t := 0.0
var turned_this_stand := false
var beam_nodes: Array[MeshInstance3D] = []
var lantern_mat: StandardMaterial3D
var ground_y := 0.0
var dirty := true

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["light"]
	layout = data["layout"]
	step_deg = int(data["step_deg"])
	disc_radius = float(data["disc_radius"])
	delay = float(data["delay"])
	interval = float(data["interval"])
	mirror_half = float(data["mirror_half"])
	target_radius = float(data["target_radius"])
	var src: Vector2 = layout["source"]
	var tgt: Vector2 = layout["target"]
	source = src
	source_angle = deg_to_rad(float(layout.get("angle", 0.0)))
	target = tgt
	ground_y = terrain.height(src.x, src.y)
	for m in (layout["mirrors"] as Array):
		var p: Vector2 = (m as Dictionary)["pos"]
		var entry := {
			"pos": p, "phi": int(m["start"]), "solution": int(m["solution"]), "start": int(m["start"]),
			"plus": p + Vector2(2.6, 2.6), "minus": p + Vector2(-2.6, 2.6), "node": null,
		}
		entry["node"] = _build_mirror(mirrors.size(), entry)
		mirrors.append(entry)
	_build_source()
	_build_lantern()
	for _i in range(mirrors.size() + 1):
		var b := MeshInstance3D.new()
		b.mesh = PropFactory.cylinder(0.07, 0.07, 1.0, 8)
		b.material_override = PropFactory.beam_material()
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(b)
		beam_nodes.append(b)
	_refresh()

func reset() -> void:
	phase = "idle"
	solved = false
	turns = 0
	active = true
	dwell_disc = -1
	dwell_t = 0.0
	tick_t = 0.0
	turned_this_stand = false
	for m in mirrors:
		m["phi"] = int(m["start"])
	dirty = true
	_refresh()

## Signed number of steps (positive = clockwise / yellow disc) that brings mirror `i` to its solution.
func steps_needed(i: int) -> int:
	var m: Dictionary = mirrors[i]
	var diff := posmod(int(m["solution"]) - int(m["phi"]), 180)
	var k := diff / step_deg
	if k > 180 / step_deg / 2:
		k -= 180 / step_deg
	return k

func disc_pos(i: int, plus: bool) -> Vector2:
	return (mirrors[i] as Dictionary)["plus" if plus else "minus"]

func mirror_pos(i: int) -> Vector2:
	return (mirrors[i] as Dictionary)["pos"]

func step(delta: float, pos: Vector3, on_floor: bool) -> String:
	if not active:
		return ""
	var result := ""
	if phase == "idle":
		var first: Vector2 = (mirrors[0] as Dictionary)["pos"]
		if Vector2(pos.x - first.x, pos.z - first.y).length() < START_RADIUS:
			phase = "input"
			result = "watch"
	elif phase == "input":
		var under := _disc_under(pos) if on_floor else -1
		if under != dwell_disc:
			dwell_disc = under
			dwell_t = 0.0
			tick_t = 0.0
			turned_this_stand = false
		if under >= 0:
			dwell_t += delta
			var turn := false
			if not turned_this_stand:
				if dwell_t >= delay:
					turn = true
					turned_this_stand = true
					tick_t = 0.0
			else:
				tick_t += delta
				if tick_t >= interval:
					tick_t -= interval
					turn = true
			if turn:
				var mi := under / 2
				var sign := 1 if under % 2 == 0 else -1
				var m: Dictionary = mirrors[mi]
				m["phi"] = posmod(int(m["phi"]) + sign * step_deg, 180)
				turns += 1
				dirty = true
				result = "turn"
		if dirty:
			_refresh()
			if _hits_target():
				solved = true
				phase = "done"
				active = false
				result = "solved"
				_refresh()
	return result

func _disc_under(pos: Vector3) -> int:
	for i in range(mirrors.size()):
		var m: Dictionary = mirrors[i]
		if absf(pos.y - ground_y) > 3.0:
			continue
		var pp: Vector2 = m["plus"]
		var mp: Vector2 = m["minus"]
		if Vector2(pos.x - pp.x, pos.z - pp.y).length() < disc_radius:
			return i * 2
		if Vector2(pos.x - mp.x, pos.z - mp.y).length() < disc_radius:
			return i * 2 + 1
	return -1

func _current_mirrors() -> Array:
	var arr := []
	for m in mirrors:
		arr.append({"pos": m["pos"], "phi": deg_to_rad(float(m["phi"]))})
	return arr

func _hits_target() -> bool:
	return bool(trace(source, source_angle, _current_mirrors(), target, target_radius, mirror_half)["hit"])

## Pure geometry (also used by the sanity check): follow the beam from `src` at angle `a` (radians on the
## (x, z) plane) through the mirrors (each {pos, phi}: a segment through pos along direction phi).
static func trace(src: Vector2, a: float, mirror_list: Array, tgt: Vector2, tgt_radius: float, half: float) -> Dictionary:
	var points: Array[Vector2] = [src]
	var p := src
	var ang := a
	var hit := false
	var last := -1
	for _b in range(MAX_BOUNCES + 1):
		var d := Vector2(cos(ang), sin(ang))
		var best_t := MAX_LENGTH
		var best_i := -1
		for i in range(mirror_list.size()):
			if i == last:
				continue
			var mm: Dictionary = mirror_list[i]
			var u := Vector2(cos(float(mm["phi"])), sin(float(mm["phi"])))
			var c: Vector2 = mm["pos"]
			var denom := d.x * u.y - d.y * u.x
			if absf(denom) < 0.0001:
				continue   # beam parallel to the mirror
			var w := c - p
			var t := (w.x * u.y - w.y * u.x) / denom
			var s := (w.x * d.y - w.y * d.x) / denom
			if t > 0.02 and absf(s) <= half and t < best_t:
				best_t = t
				best_i = i
		# does the beam reach the lantern before the next mirror?
		var to_t := tgt - p
		var along := to_t.dot(d)
		if along > 0.0 and along < best_t:
			var perp := absf(to_t.x * d.y - to_t.y * d.x)
			if perp <= tgt_radius:
				points.append(p + d * along)
				hit = true
				break
		p = p + d * best_t
		points.append(p)
		if best_i < 0:
			break
		var phi := float((mirror_list[best_i] as Dictionary)["phi"])
		ang = 2.0 * phi - ang
		last = best_i
	return {"points": points, "hit": hit}

func _refresh() -> void:
	dirty = false
	for m in mirrors:
		(m["node"] as Node3D).rotation.y = -deg_to_rad(float(m["phi"]))
	var res := trace(source, source_angle, _current_mirrors(), target, target_radius, mirror_half)
	var pts: Array = res["points"]
	for i in range(beam_nodes.size()):
		var b := beam_nodes[i]
		if i + 1 < pts.size():
			var a2: Vector2 = pts[i]
			var b2: Vector2 = pts[i + 1]
			var len := a2.distance_to(b2)
			var from3 := Vector3(a2.x, ground_y + BEAM_HEIGHT, a2.y)
			var to3 := Vector3(b2.x, ground_y + BEAM_HEIGHT, b2.y)
			if len < 0.05:
				b.visible = false
				continue
			b.visible = true
			var dir3 := (to3 - from3).normalized()
			var basis := Basis.looking_at(dir3, Vector3.UP) * Basis(Vector3.RIGHT, PI / 2.0)
			b.transform = Transform3D(basis.scaled(Vector3(1.0, len, 1.0)), (from3 + to3) * 0.5)
		else:
			b.visible = false
	if is_instance_valid(lantern_mat):
		var hit := bool(res["hit"])
		lantern_mat.emission_enabled = true
		lantern_mat.emission = Color("#ffd98a")
		lantern_mat.emission_energy_multiplier = 4.0 if hit else 0.3

func _build_mirror(i: int, entry: Dictionary) -> Node3D:
	var p: Vector2 = entry["pos"]
	var y := terrain.height(p.x, p.y)
	var n := Node3D.new()
	n.name = "Mirror%d" % i
	n.position = Vector3(p.x, y, p.y)
	var frame := PropFactory.mat(Color("#8a6a3a"), 0.6)
	var glass := PropFactory.mat(Color("#dfe9f2"), 0.15, 0.9, 0.7)
	var w := mirror_half * 2.0
	n.add_child(PropFactory.part(PropFactory.box(Vector3(w + 0.2, 1.8, 0.16)), frame, Vector3(0, 1.1, 0)))
	n.add_child(PropFactory.part(PropFactory.box(Vector3(w, 1.6, 0.2)), glass, Vector3(0, 1.1, 0)))
	n.add_child(PropFactory.part(PropFactory.cylinder(0.25, 0.3, 0.2, 8), frame, Vector3(0, 0.1, 0)))
	root.add_child(n)
	# the two turning discs (yellow: clockwise, one stud; blue: counter-clockwise, two studs)
	var stud := PropFactory.mat(Color("#efe6d0"), 0.6)
	for k in range(2):
		var dp: Vector2 = entry["plus" if k == 0 else "minus"]
		var dn := Node3D.new()
		dn.name = "MirrorDisc%d_%d" % [i, k]
		dn.position = Vector3(dp.x, terrain.height(dp.x, dp.y), dp.y)
		var col := Color(PLUS_COLOR if k == 0 else MINUS_COLOR)
		var dm := PropFactory.mat(col, 0.5)
		dm.emission_enabled = true
		dm.emission = col
		dm.emission_energy_multiplier = 0.6
		dn.add_child(PropFactory.part(PropFactory.cylinder(disc_radius, disc_radius, 0.14, 20), dm, Vector3(0, 0.07, 0)))
		for s in range(k + 1):
			dn.add_child(PropFactory.part(PropFactory.cylinder(0.12, 0.12, 0.1, 8), stud, Vector3((float(s) - float(k) * 0.5) * 0.4, 0.19, 0)))
		root.add_child(dn)
	return n

func _build_source() -> void:
	var n := Node3D.new()
	n.name = "LightSource"
	n.position = Vector3(source.x, ground_y, source.y)
	n.rotation.y = -source_angle
	var stone := PropFactory.mat(Color("#7f7466"), 0.8)
	n.add_child(PropFactory.part(PropFactory.cylinder(0.5, 0.65, 0.9, 10), stone, Vector3(0, 0.45, 0)))
	var glow := PropFactory.mat(Color("#ffd98a"), 0.3)
	glow.emission_enabled = true
	glow.emission = Color("#ffd98a")
	glow.emission_energy_multiplier = 3.0
	n.add_child(PropFactory.part(PropFactory.sphere(0.34, 10), glow, Vector3(0, 1.1, 0)))
	root.add_child(n)

func _build_lantern() -> void:
	var n := Node3D.new()
	n.name = "FarLantern"
	var y := terrain.height(target.x, target.y)
	n.position = Vector3(target.x, y, target.y)
	var stone := PropFactory.mat(Color("#7f7466"), 0.8)
	n.add_child(PropFactory.part(PropFactory.cylinder(0.45, 0.6, 0.9, 10), stone, Vector3(0, 0.45, 0)))
	lantern_mat = PropFactory.mat(Color("#cfae6a"), 0.4)
	n.add_child(PropFactory.part(PropFactory.cylinder(0.45, 0.45, 0.9, 10), lantern_mat, Vector3(0, 1.35, 0)))
	n.add_child(PropFactory.part(PropFactory.cylinder(0.05, 0.6, 0.45, 10), stone, Vector3(0, 2.0, 0)))
	root.add_child(n)
