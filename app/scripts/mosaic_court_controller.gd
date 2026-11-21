class_name MosaicCourtController
extends RefCounted
## Chapter 13: a tiled court. Tiles light up in an order; the player repeats that order by walking
## onto each tile and standing on it for a moment (running across a tile does not count).
## A wrong tile only replays the order (no fall, no time limit, no lost progress elsewhere), and
## standing on the centre medallion replays it on demand, so the chapter is always finishable.

const TILE_COLORS := ["#d9534f", "#4a8fd9", "#e0b23a", "#4fae6a", "#9b6bd1", "#e07f3a"]
const GAP := 0.35            # dark pause between two lit tiles while the order is shown
const END_PAUSE := 0.6
const WRONG_PAUSE := 1.1
const START_RADIUS := 6.0    # the order is first shown when the player is this close to the ring edge

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var center := Vector3.ZERO
var ring_radius := 7.5
var tile_radius := 1.5
var medallion_radius := 1.7
var dwell := 0.5
var show_time := 1.0
var tiles: Array[Dictionary] = []     # {pos, node, mat, beam, lit, flash}
var sequence: Array[int] = []
var phase := "idle"                   # idle | show | input | wrong | done
var index := 0                        # next step the player must make
var phase_t := 0.0
var show_step := -1
var dwell_tile := -2                  # -1 = medallion, >=0 = tile index under the player
var dwell_t := 0.0
var blocked_tile := -2                # must be left before it can count again
var wrongs := 0
var replays := 0
var shows := 0
var solved := false
var active := false
var elapsed := 0.0
var medallion_mat: StandardMaterial3D

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["mosaic"]
	var cz := float(data["center_z"])
	var cx := terrain.path_x(cz)
	center = Vector3(cx, terrain.height(cx, cz), cz)
	ring_radius = float(data["ring_radius"])
	tile_radius = float(data["tile_radius"])
	dwell = float(data["dwell"])
	show_time = float(data["show_time"])
	var count := int(data["count"])
	var order: Array = data["order"]
	sequence.clear()
	for o in order:
		if int(o) < count and sequence.size() < int(data["seq_len"]):
			sequence.append(int(o))
	for i in range(count):
		var a := TAU * float(i) / float(count)
		var x := center.x + sin(a) * ring_radius
		var z := center.z + cos(a) * ring_radius
		var p := Vector3(x, terrain.height(x, z), z)
		tiles.append(_build_tile(i, p))
	_build_medallion()

func reset() -> void:
	phase = "idle"
	index = 0
	phase_t = 0.0
	show_step = -1
	dwell_tile = -2
	dwell_t = 0.0
	blocked_tile = -2
	wrongs = 0
	replays = 0
	shows = 0
	solved = false
	elapsed = 0.0
	active = true
	for t in tiles:
		t["lit"] = false
		t["flash"] = 0.0
	_paint()

## Where the next correct tile is (for hints and for the self-test bot).
func expected_pos() -> Vector3:
	if index < sequence.size():
		return (tiles[sequence[index]] as Dictionary)["pos"]
	return center

func tile_pos(i: int) -> Vector3:
	return (tiles[i] as Dictionary)["pos"]

func step(delta: float, pos: Vector3, on_floor: bool) -> String:
	if not active:
		return ""
	elapsed += delta
	for t in tiles:
		t["flash"] = maxf(float(t["flash"]) - delta, 0.0)
	var result := ""
	match phase:
		"idle":
			if Vector2(pos.x - center.x, pos.z - center.z).length() < ring_radius + START_RADIUS:
				_start_show()
				result = "watch"
		"show":
			result = _update_show(delta)
		"wrong":
			phase_t += delta
			if phase_t >= WRONG_PAUSE:
				_start_show()
				result = "replay"
		"input":
			result = _update_input(delta, pos, on_floor)
	_paint()
	return result

## `keep_progress`: the medallion replay must not punish the player for crossing the court,
## so it shows the order again and then continues where the player was.
func _start_show(keep_progress: bool = false) -> void:
	phase = "show"
	phase_t = 0.0
	show_step = -1
	if not keep_progress:
		index = 0
	shows += 1
	for t in tiles:
		t["lit"] = false

func _update_show(delta: float) -> String:
	phase_t += delta
	# Players who missed the order get more time on every mistake.
	var slot := (show_time * (1.0 + 0.25 * float(mini(wrongs, 3)))) + GAP
	var n := int(floor(phase_t / slot))
	var inside := fmod(phase_t, slot) < slot - GAP
	for i in range(tiles.size()):
		(tiles[i] as Dictionary)["lit"] = false
	if n < sequence.size():
		show_step = n
		if inside:
			(tiles[sequence[n]] as Dictionary)["lit"] = true
	elif phase_t >= slot * float(sequence.size()) + END_PAUSE:
		phase = "input"
		phase_t = 0.0
		dwell_tile = -2
		dwell_t = 0.0
		blocked_tile = -2   # re-armed below: the tile the player stands on must be left first
		for i in range(tiles.size()):
			(tiles[i] as Dictionary)["lit"] = false
		for i in range(index):
			(tiles[sequence[i]] as Dictionary)["lit"] = true   # tiles already done stay lit
	return ""

func _tile_under(pos: Vector3) -> int:
	for i in range(tiles.size()):
		var p: Vector3 = (tiles[i] as Dictionary)["pos"]
		if Vector2(pos.x - p.x, pos.z - p.z).length() < tile_radius and absf(pos.y - p.y) < 2.5:
			return i
	if Vector2(pos.x - center.x, pos.z - center.z).length() < medallion_radius and absf(pos.y - center.y) < 2.5:
		return -1
	return -2

func _update_input(delta: float, pos: Vector3, on_floor: bool) -> String:
	var under := _tile_under(pos)
	if not on_floor:
		under = -2
	if blocked_tile == -2 and phase_t == 0.0:
		blocked_tile = under   # standing on a tile when the order ends: leave it before it counts
	phase_t += delta
	if under != blocked_tile:
		blocked_tile = -2
	if under != dwell_tile:
		dwell_tile = under
		dwell_t = 0.0
	if under == -2 or under == blocked_tile:
		return ""
	dwell_t += delta
	# the medallion needs a longer stand, so walking across the middle of the court never replays by accident
	if dwell_t < dwell * (1.6 if under == -1 else 1.0):
		return ""
	blocked_tile = under
	dwell_t = 0.0
	if under == -1:
		replays += 1
		_start_show(true)
		return "replay"
	if under == sequence[index]:
		(tiles[under] as Dictionary)["lit"] = true
		index += 1
		if index >= sequence.size():
			phase = "done"
			solved = true
			active = false
			for t in tiles:
				t["lit"] = true
			return "solved"
		return "right"
	wrongs += 1
	index = 0
	phase = "wrong"
	phase_t = 0.0
	for t in tiles:
		t["lit"] = false
	(tiles[under] as Dictionary)["flash"] = WRONG_PAUSE
	return "wrong"

func _paint() -> void:
	for i in range(tiles.size()):
		var t: Dictionary = tiles[i]
		var m: StandardMaterial3D = t["mat"]
		var lit := bool(t["lit"])
		var flash := float(t["flash"]) > 0.0
		var base := Color(TILE_COLORS[i % TILE_COLORS.size()])
		m.albedo_color = base if lit else base.darkened(0.55)
		m.emission_enabled = true
		m.emission = Color("#d93a3a") if flash else base
		m.emission_energy_multiplier = 3.0 if lit else (1.6 if flash else 0.0)
		(t["beam"] as Node3D).visible = lit
	if is_instance_valid(medallion_mat):
		medallion_mat.emission_energy_multiplier = 1.6 if phase == "input" else 0.5

func _build_tile(i: int, p: Vector3) -> Dictionary:
	var n := Node3D.new()
	n.name = "MosaicTile%d" % i
	n.position = p
	var m := PropFactory.mat(Color(TILE_COLORS[i % TILE_COLORS.size()]).darkened(0.55), 0.7)
	var disc := PropFactory.part(PropFactory.cylinder(tile_radius, tile_radius, 0.16, 6), m, Vector3(0, 0.08, 0))
	n.add_child(disc)
	# the number of studs tells tiles apart without relying on colour alone
	var stud_mat := PropFactory.mat(Color("#efe6d0"), 0.6)
	for s in range(i + 1):
		var sx := (float(s) - float(i) * 0.5) * 0.36
		n.add_child(PropFactory.part(PropFactory.cylinder(0.1, 0.1, 0.1, 8), stud_mat, Vector3(sx, 0.2, 0)))
	var beam := PropFactory.part(PropFactory.cylinder(0.1, 0.1, 6.0, 8), PropFactory.beam_material(), Vector3(0, 3.1, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	n.add_child(beam)
	root.add_child(n)
	return {"pos": p, "node": n, "mat": m, "beam": beam, "lit": false, "flash": 0.0}

func _build_medallion() -> void:
	var n := Node3D.new()
	n.name = "MosaicMedallion"
	n.position = center
	medallion_mat = PropFactory.mat(Color("#d9a441"), 0.4, 0.2, 0.5)
	n.add_child(PropFactory.part(PropFactory.cylinder(medallion_radius, medallion_radius, 0.14, 16), medallion_mat, Vector3(0, 0.07, 0)))
	n.add_child(PropFactory.part(PropFactory.sphere(0.32, 10), PropFactory.mat(Color("#efe6d0"), 0.5), Vector3(0, 0.34, 0)))
	root.add_child(n)
