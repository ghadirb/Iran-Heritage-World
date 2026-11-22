class_name GuardController
extends RefCounted
## Chapter 11, first labour: Rostam sleeps in the reeds. Lions circle him and sometimes run at him. Run into a
## charging lion to make it back off; enough lions driven back and the labour is done. A lion that reaches
## Rostam only startles him (a mistake) and backs off too, so nothing can fail.

var root: Node3D
var terrain: TerrainBuilder
var data: Dictionary
var center := Vector3.ZERO
var lions: Array[Dictionary] = []     # {node, angle, state, t, dir}
var radius := 13.0
var omega := 0.6
var dash_speed := 4.5
var interval := 4.0
var need := 3
var driven := 0
var startled := 0
var active := false
var finished := false
var waked := false                    # lions start moving only once the courier comes near
var wake_dist := 26.0

func build(parent: Node3D, terrain_builder: TerrainBuilder, level: Dictionary) -> void:
	root = parent
	terrain = terrain_builder
	data = level["guard"]
	var c: Vector2 = data["center"]
	center = Vector3(c.x, terrain.height(c.x, c.y), c.y)
	radius = float(data["radius"])
	omega = float(data["omega"])
	dash_speed = float(data["dash_speed"])
	interval = float(data["interval"])
	need = int(data["need"])
	var count := int(data["count"])
	var sleeper := PropFactory.make_sleeper()
	sleeper.position = center
	sleeper.rotation.y = 0.4
	root.add_child(sleeper)
	for i in range(count):
		var node := PropFactory.make_lion()
		root.add_child(node)
		var ang := TAU * float(i) / float(count)
		lions.append({"node": node, "angle": ang, "state": "circle", "t": interval * (0.4 + 0.5 * float(i)), "dir": 1.0 if i % 2 == 0 else -1.0})
		_place(lions[i], radius)

func reset() -> void:
	active = true
	finished = false
	waked = false
	driven = 0
	startled = 0
	for i in range(lions.size()):
		var l := lions[i]
		l["state"] = "circle"
		l["t"] = interval * (0.4 + 0.5 * float(i))
		_place(l, radius)

func _place(l: Dictionary, r: float) -> void:
	var a := float(l["angle"])
	var p := center + Vector3(sin(a), 0.0, cos(a)) * r
	p.y = terrain.height(p.x, p.z)
	var n: Node3D = l["node"]
	var prev := n.position
	n.position = p
	var dir := p - prev
	if dir.length() > 0.001:
		n.rotation.y = atan2(dir.x, dir.z)

## Returns "driven", "startled", "all" (labour done) or "".
func step(delta: float, player_pos: Vector3) -> String:
	if not active:
		return ""
	if not waked:
		if Vector2(player_pos.x - center.x, player_pos.z - center.z).length() < wake_dist:
			waked = true
		else:
			return ""
	var result := ""
	for l in lions:
		var n: Node3D = l["node"]
		match str(l["state"]):
			"circle":
				l["angle"] = float(l["angle"]) + float(l["dir"]) * omega * delta
				_place(l, radius)
				l["t"] = float(l["t"]) - delta
				if float(l["t"]) <= 0.0:
					l["state"] = "dash"
			"dash":
				var to := center - n.position
				to.y = 0.0
				if to.length() < 1.6:
					startled += 1
					l["state"] = "flee"
					l["t"] = 1.8
					result = "startled"
					continue
				n.position += to.normalized() * dash_speed * delta
				n.position.y = terrain.height(n.position.x, n.position.z)
				n.rotation.y = atan2(to.x, to.z)
				var pd := Vector2(player_pos.x - n.position.x, player_pos.z - n.position.z).length()
				if pd < 2.1:
					driven += 1
					l["state"] = "flee"
					l["t"] = 1.8
					result = "driven"
			"flee":
				var away := n.position - center
				away.y = 0.0
				n.position += away.normalized() * 7.0 * delta
				n.position.y = terrain.height(n.position.x, n.position.z)
				n.rotation.y = atan2(away.x, away.z)
				l["t"] = float(l["t"]) - delta
				if float(l["t"]) <= 0.0 or away.length() > radius * 1.3:
					l["angle"] = atan2(away.x, away.z)
					l["state"] = "circle"
					l["t"] = interval
	if driven >= need and not finished:
		finished = true
		active = false
		return "all"
	return result

## The charging lion nearest to Rostam (a bot or a hint can run at it).
func charging_lion() -> Dictionary:
	var best: Dictionary = {}
	var best_d := 1e9
	for l in lions:
		if str(l["state"]) != "dash":
			continue
		var d := ((l["node"] as Node3D).position - center).length()
		if d < best_d:
			best_d = d
			best = l
	return best
