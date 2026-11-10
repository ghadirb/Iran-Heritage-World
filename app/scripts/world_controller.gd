extends Node3D
class_name WorldController
## Builds each chapter from LevelData, runs interactions and mission flow.

const INTERACT_RADIUS := 4.2

@onready var hud: GameHUD = $HUD

var player: PlayerController
var level_root: Node3D
var level: Dictionary = {}
var level_index := 0
var terrain: TerrainBuilder
var items: Array[Dictionary] = []
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var grass_instances: Array[MultiMeshInstance3D] = []
var clouds: Array[MeshInstance3D] = []
var simorgh: Node3D
var spawn_point := Vector3.ZERO
var checkpoint := Vector3.ZERO
var brazier_next := 0
var mistakes := 0
var level_active := false
var finished := false
var kill_y := -30.0
var selftest := false

func _ready() -> void:
	selftest = OS.get_cmdline_user_args().has("--selftest")
	player = PlayerController.new()
	player.name = "Player"
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	player.add_child(shape)
	player.art = PropFactory.make_zal()
	player.add_child(player.art)
	add_child(player)
	hud.jump_pressed.connect(player.request_jump)
	hud.look_delta.connect(player.add_look)
	hud.interact_pressed.connect(_interact)
	hud.start_level.connect(load_level)
	hud.restart_requested.connect(func() -> void: load_level(level_index))
	GameState.quality_changed.connect(_apply_quality)
	if selftest:
		await get_tree().process_frame
		await _run_selftest()
		return
	var shot := _arg_value("--shot")
	if shot != "":
		await _run_screenshot(shot)
		return
	load_level(clampi(GameState.unlocked_level, 0, LevelData.LEVELS.size() - 1), false)
	hud.show_main_menu()

func _arg_value(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return ""

## Developer helper: godot --path app -- --shot=out.png --level=0 --z=-20 --yaw=0.4
func _run_screenshot(path: String) -> void:
	var lv := int(_arg_value("--level")) if _arg_value("--level") != "" else 0
	load_level(lv, false)
	hud.close_all_modals()
	if _arg_value("--z") != "":
		var z := float(_arg_value("--z"))
		var x := terrain.path_x(z)
		player.global_position = Vector3(x, terrain.height(x, z) + 1.0, z)
	if _arg_value("--yaw") != "":
		player.yaw = float(_arg_value("--yaw"))
	if _arg_value("--pitch") != "":
		player.pitch = float(_arg_value("--pitch"))
	hud.toast("آزمایش نمایش متن فارسی و رابط کاربری", 60.0)
	for _i in range(90):
		await get_tree().process_frame
	player.rig.global_position = player.global_position + Vector3(0, 1.5, 0)
	for _i in range(20):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	get_tree().quit()

# ---------- level loading ----------

func load_level(index: int, announce: bool = true) -> void:
	level_index = clampi(index, 0, LevelData.LEVELS.size() - 1)
	GameState.current_level = level_index
	level = LevelData.LEVELS[level_index]
	level_active = false
	finished = false
	mistakes = 0
	brazier_next = 0
	items.clear()
	grass_instances.clear()
	clouds.clear()
	simorgh = null
	if level_root:
		level_root.queue_free()
	level_root = Node3D.new()
	level_root.name = "Level"
	add_child(level_root)
	terrain = TerrainBuilder.new(level)
	kill_y = float(level.get("kill_y", -30.0))
	_build_environment()
	_build_ground()
	_build_vegetation()
	_build_decor()
	_build_interactables()
	_build_ambient_particles()
	var sp: Vector2 = level["spawn"]
	var sx := terrain.path_x(sp.y) + sp.x
	spawn_point = Vector3(sx, terrain.height(sx, sp.y) + 1.2, sp.y)
	checkpoint = spawn_point
	player.global_position = spawn_point
	player.velocity = Vector3.ZERO
	player.snap_camera_behind(0.0)
	player.input_enabled = true
	hud.close_all_modals()
	hud.set_level_info(str(level["title"]), str(level["subtitle"]))
	hud.set_objective(str(level["objective"]))
	_refresh_progress()
	_apply_quality()
	level_active = true
	if announce:
		hud.toast(str(level["intro"]), 7.0)

# ---------- environment ----------

func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(str(level["sky_top"]))
	sm.sky_horizon_color = Color(str(level["sky_horizon"]))
	sm.ground_horizon_color = Color(str(level["sky_horizon"])).darkened(0.1)
	sm.ground_bottom_color = Color(str(level["fog"])).darkened(0.35)
	sm.sky_curve = 0.18
	sm.sun_angle_max = 24.0
	sm.sun_curve = 0.12
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_color = Color(str(level["ambient"]))
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color(str(level["fog"]))
	env.fog_density = float(level["fog_density"])
	env.fog_sky_affect = 0.55
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18
	world_env.environment = env
	level_root.add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = level["sun_rot"]
	sun.light_color = Color(str(level["sun_color"]))
	sun.light_energy = float(level["sun_energy"])
	sun.shadow_enabled = true
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.6
	sun.shadow_blur = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	level_root.add_child(sun)

	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color = Color(1, 1, 1, 0.82).lerp(Color(str(level["sky_horizon"])), 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level["seed"])
	for i in range(9):
		var cloud := Node3D.new()
		for j in range(4):
			var puff := PropFactory.part(PropFactory.sphere(1.0, 12), cloud_mat, Vector3(float(j) * 9.0 - 14.0, rng.randf_range(-1.0, 1.5), rng.randf_range(-3.0, 3.0)), Vector3(12.0 + rng.randf() * 6.0, 3.5 + rng.randf() * 2.0, 8.0))
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.add_child(puff)
		cloud.position = Vector3(rng.randf_range(-150, 150), rng.randf_range(70, 110), rng.randf_range(-260, -20))
		level_root.add_child(cloud)
		clouds.append(cloud.get_child(0) as MeshInstance3D)
		cloud.set_meta("speed", rng.randf_range(0.6, 1.6))
		cloud.name = "Cloud%d" % i

func _apply_quality() -> void:
	var q := GameState.quality
	var modes := [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
	get_viewport().msaa_3d = modes[q]
	if sun:
		sun.shadow_enabled = GameState.shadows
	if world_env:
		world_env.environment.glow_enabled = q >= 1
	var fractions := [0.35, 0.7, 1.0]
	for inst in grass_instances:
		var total := inst.multimesh.instance_count
		inst.multimesh.visible_instance_count = int(float(total) * fractions[q])

# ---------- ground ----------

func _build_ground() -> void:
	var mesh := terrain.build_terrain(2.0)
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain.terrain_material()
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shp := mesh.create_trimesh_shape()
	shp.backface_collision = true
	col.shape = shp
	body.add_child(col)
	level_root.add_child(body)
	var river := terrain.build_river()
	if river:
		level_root.add_child(river)
	# invisible side / end walls
	var half := float(level["valley_half"]) + 15.0 + float(level.get("path_sway", 2.0)) * 1.8
	var length := float(level["length"])
	var wall_body := StaticBody3D.new()
	wall_body.name = "Bounds"
	for side in [-1.0, 1.0]:
		var ws := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(2.0, 200.0, length + 80.0)
		ws.shape = bx
		ws.position = Vector3(side * (half + 1.0), 40.0, -length * 0.5 + 8.0)
		wall_body.add_child(ws)
	for zpos in [terrain.z_max - 2.0, -length - 22.0]:
		var wz := CollisionShape3D.new()
		var bz := BoxShape3D.new()
		bz.size = Vector3(half * 2.0 + 10.0, 200.0, 2.0)
		wz.shape = bz
		wz.position = Vector3(0, 40.0, zpos)
		wall_body.add_child(wz)
	level_root.add_child(wall_body)

func _build_vegetation() -> void:
	var tree_count := int(level["trees"])
	if tree_count > 0:
		var pts := terrain.scatter_points(tree_count, 5.0, float(level["valley_half"]) + 22.0)
		var trees := terrain.build_multimesh(terrain.make_pine_mesh(), terrain.solid_vertex_material(0.95), pts, 0.85, 1.7)
		level_root.add_child(trees)
		var tb := StaticBody3D.new()
		for p in pts:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.3
			cyl.height = 3.0
			cs.shape = cyl
			cs.position = p + Vector3(0, 1.5, 0)
			tb.add_child(cs)
		level_root.add_child(tb)
	var rock_count := int(level["rocks"])
	if rock_count > 0:
		for variant in range(3):
			var rp := terrain.scatter_points(rock_count / 3, 3.0, float(level["valley_half"]) + 20.0, false)
			var rmat := terrain.solid_vertex_material(1.0)
			rmat.albedo_color = Color(str(level["rock"])).lightened(0.05 * float(variant))
			var rocks := terrain.build_multimesh(terrain.make_rock_mesh(variant), rmat, rp, 0.8, 3.2)
			level_root.add_child(rocks)
			var rb := StaticBody3D.new()
			for p in rp:
				var cs := CollisionShape3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 0.7
				cs.shape = sph
				cs.position = p + Vector3(0, 0.3, 0)
				rb.add_child(cs)
			level_root.add_child(rb)
	var grass_count := int(level["grass_count"])
	if grass_count > 0:
		var gp := terrain.scatter_points(grass_count, 1.6, float(level["valley_half"]) + 6.0)
		var grass := terrain.build_multimesh(terrain.make_grass_mesh(), terrain.foliage_material(), gp, 0.6, 1.25)
		grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		level_root.add_child(grass)
		grass_instances.append(grass)
	var flower_count := int(level["flowers"])
	if flower_count > 0:
		var colors := [Color("#f2f2f2"), Color("#e8559a"), Color("#f0c43a"), Color("#8f6ae0")]
		for ci in range(colors.size()):
			var fp := terrain.scatter_points(flower_count / colors.size(), 1.8, float(level["valley_half"]) + 4.0)
			var fl := terrain.build_multimesh(terrain.make_flower_mesh(colors[ci]), terrain.foliage_material(), fp, 0.9, 1.5)
			fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			level_root.add_child(fl)
			grass_instances.append(fl)

func _build_decor() -> void:
	if bool(level.get("hall", false)):
		for i in range(8):
			for side in [-1.0, 1.0]:
				var col := PropFactory.make_column()
				col.position = Vector3(side * 12.0, terrain.height(side * 12.0, 8.0 - float(i) * 8.0), 8.0 - float(i) * 8.0)
				level_root.add_child(col)
				var cb := StaticBody3D.new()
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = 1.0
				cyl.height = 10.0
				cs.shape = cyl
				cb.position = col.position + Vector3(0, 5.0, 0)
				cb.add_child(cs)
				level_root.add_child(cb)
		for i in range(4):
			var lamp := PropFactory.make_brazier(Color("#ffb347"))
			lamp.position = Vector3(0, 0.0, 2.0 - float(i) * 16.0) + Vector3(0, terrain.height(0, 2.0 - float(i) * 16.0), 0)
			lamp.add_child(PropFactory.make_flame(Color("#ff9a3c")))
			level_root.add_child(lamp)
	if bool(level.get("tents", false)):
		var tent_colors := [Color("#c8a15a"), Color("#a8483a"), Color("#d8c08a"), Color("#6c8f9a")]
		for i in range(10):
			var z := -112.0 - float(i % 5) * 6.0
			var x := terrain.path_x(z) + (-10.0 if i % 2 == 0 else 10.0) + float(i % 3) * 2.0
			var tent := PropFactory.make_tent(tent_colors[i % tent_colors.size()])
			tent.position = Vector3(x, terrain.height(x, z), z)
			tent.rotation.y = float(i) * 0.7
			level_root.add_child(tent)
	if level.has("chain"):
		_build_platform_chain()
	if level.has("nest"):
		var n: Vector2 = level["nest"]
		var nest := PropFactory.make_nest()
		nest.position = Vector3(n.x, terrain.height(n.x, n.y), n.y)
		level_root.add_child(nest)

func chain_position(i: int) -> Vector3:
	var ch: Dictionary = level["chain"]
	var count := int(ch["count"])
	var t := float(i) / float(maxi(count - 1, 1))
	var z := lerpf(float(ch["z0"]), float(ch["z1"]), t)
	var x := terrain.path_x(z) + sin(float(i) * 1.4) * float(ch["sway"])
	var z_start := float(ch["z0"]) + 3.0
	var y0 := terrain.height(terrain.path_x(z_start), z_start)
	return Vector3(x, y0 + 0.1 + float(i) * float(ch["rise"]), z)

func _build_platform_chain() -> void:
	var ch: Dictionary = level["chain"]
	var stone := PropFactory.mat(Color("#5f574c"), 1.0)
	var moss := PropFactory.mat(Color("#6fae3f"), 1.0)
	var body := StaticBody3D.new()
	body.name = "StonePlatforms"
	level_root.add_child(body)
	for i in range(int(ch["count"])):
		var p := chain_position(i)
		var holder := Node3D.new()
		holder.position = p
		holder.rotation.y = sin(float(i) * 2.1) * 0.5
		holder.add_child(PropFactory.part(PropFactory.box(Vector3(3.4, 1.4, 3.4)), stone, Vector3(0, -0.7, 0)))
		holder.add_child(PropFactory.part(PropFactory.box(Vector3(3.5, 0.12, 3.5)), moss, Vector3(0, -0.04, 0)))
		holder.add_child(PropFactory.part(PropFactory.cylinder(0.9, 0.2, 6.0, 7), stone, Vector3(0, -4.4, 0)))
		level_root.add_child(holder)
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(3.4, 1.4, 3.4)
		cs.shape = bx
		cs.position = p + Vector3(0, -0.7, 0)
		cs.rotation.y = holder.rotation.y
		body.add_child(cs)

func _build_ambient_particles() -> void:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(22, 6, 22)
	p.direction = Vector3(1, 0.2, 0.3)
	p.spread = 60.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, -0.02, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.95, 0.75, 0.7)
	p.mesh = qm
	p.material_override = m
	p.position = Vector3(0, 3.0, 0)
	player.add_child(p)
	p.name = "Motes"
	if player.has_node("Motes_old"):
		player.get_node("Motes_old").queue_free()

# ---------- interactables ----------

func _ground_pos(offset_pos: Vector2) -> Vector3:
	var z := offset_pos.y
	var x := terrain.path_x(z) + offset_pos.x
	if level.has("nest") and not (bool(level.get("hall", false))):
		x = offset_pos.x
	return Vector3(x, terrain.height(x, z), z)

func _build_interactables() -> void:
	for d in level["interactables"]:
		var data: Dictionary = d
		var pos: Vector3
		if data.has("on_chain"):
			pos = chain_position(int(data["on_chain"])) + Vector3(0, 1.1, 0)
		else:
			pos = _ground_pos(data["pos"])
		var node: Node3D
		match str(data["kind"]):
			"clue":
				node = PropFactory.make_clue_marker("banner" if str(data["id"]).begins_with("banner") else "clue")
				if not str(data["id"]).begins_with("banner"):
					pos += Vector3(0, 0.9, 0)
			"brazier":
				node = PropFactory.make_brazier(Color(str(data["color"])))
			"quiz":
				node = PropFactory.make_pedestal()
			"npc":
				match str(data["id"]):
					"simorgh":
						node = PropFactory.make_simorgh()
						node.scale = Vector3.ONE * 1.5
						pos += Vector3(0, 3.4, 0)
						simorgh = node
					"sam":
						node = PropFactory.make_figure(Color("#6d3b2e"), Color("#cfcfcf"), true)
					"mobed":
						node = PropFactory.make_figure(Color("#e6dfcf"), Color("#d8d4c8"), true)
					_:
						node = PropFactory.make_stone_tablet()
		node.position = pos
		level_root.add_child(node)
		if str(data["kind"]) == "npc" and str(data["id"]) in ["sam", "mobed"]:
			node.look_at(Vector3(pos.x, pos.y, pos.z + 10.0))
		items.append({"data": data, "node": node, "done": false, "base_y": pos.y})

func _non_finale_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in items:
		if not bool((it["data"] as Dictionary).get("finale", false)):
			out.append(it)
	return out

func _required_done() -> bool:
	for it in _non_finale_items():
		if not bool(it["done"]):
			return false
	return true

func _refresh_progress() -> void:
	var req := _non_finale_items()
	var done_count := 0
	for it in req:
		if bool(it["done"]):
			done_count += 1
	hud.set_progress(str(level["progress_label"]), done_count, req.size())

func _nearest_item() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INTERACT_RADIUS
	for it in items:
		if bool(it["done"]) and str((it["data"] as Dictionary)["kind"]) != "brazier":
			continue
		var node: Node3D = it["node"]
		if not is_instance_valid(node):
			continue
		var a := player.global_position
		var b := node.global_position
		var dist := Vector2(a.x - b.x, a.z - b.z).length()
		if dist < best_d and absf(a.y - b.y) < 7.0:
			best_d = dist
			best = it
	return best

func _interact() -> void:
	if not level_active or hud.is_modal_open():
		return
	var it := _nearest_item()
	if it.is_empty():
		hud.toast("به یکی از نشانه‌های درخشان نزدیک شو و دکمه «تعامل» را بزن.", 3.0)
		return
	var d: Dictionary = it["data"]
	match str(d["kind"]):
		"clue":
			_collect(it)
			hud.toast(str(d["hint"]), 4.0)
			_check_finish()
		"brazier":
			_use_brazier(it)
		"quiz":
			hud.show_quiz(d, func(correct: bool, finished_q: bool) -> void:
				if not correct:
					mistakes += 1
				if finished_q:
					_mark_done(it)
					_set_pedestal_done(it)
					_check_finish())
		"npc":
			if bool(d.get("finale", false)) and not _required_done():
				hud.toast(str(d["hint"]), 3.5)
				return
			hud.show_dialogue(str(d["speaker"]), d["lines"], d.get("choices", []), d.get("after", []), func() -> void:
				_mark_done(it)
				_finish_level())

func _collect(it: Dictionary) -> void:
	var node: Node3D = it["node"]
	if is_instance_valid(node):
		var burst := PropFactory.make_burst()
		burst.position = node.global_position
		level_root.add_child(burst)
		get_tree().create_timer(2.0).timeout.connect(burst.queue_free)
		node.queue_free()
	_mark_done(it)

func _mark_done(it: Dictionary) -> void:
	it["done"] = true
	_refresh_progress()

func _set_pedestal_done(it: Dictionary) -> void:
	var node: Node3D = it["node"]
	if is_instance_valid(node):
		var burst := PropFactory.make_burst(Color("#8fe39a"))
		burst.position = node.global_position + Vector3(0, 1.6, 0)
		level_root.add_child(burst)
		get_tree().create_timer(2.0).timeout.connect(burst.queue_free)

func _use_brazier(it: Dictionary) -> void:
	var d: Dictionary = it["data"]
	if bool(it["done"]):
		hud.toast("این آتش پیش‌تر روشن شده است.", 2.0)
		return
	if int(d["order"]) == brazier_next:
		brazier_next += 1
		_mark_done(it)
		var node: Node3D = it["node"]
		var flame := PropFactory.make_flame(Color(str(d["color"])))
		node.add_child(flame)
		hud.toast("%s روشن شد." % str(d["title"]), 2.5)
		_check_finish()
	else:
		mistakes += 1
		brazier_next = 0
		for other in items:
			if str((other["data"] as Dictionary)["kind"]) == "brazier":
				other["done"] = false
				var n: Node3D = other["node"]
				var fl := n.get_node_or_null("Flame")
				if fl:
					fl.queue_free()
		_refresh_progress()
		hud.toast("ترتیب درست نبود؛ آتش‌ها خاموش شدند. سرخ، آبی، زرد، سبز.", 4.0)

func _check_finish() -> void:
	if finished:
		return
	if _required_done():
		var has_finale := false
		for it in items:
			if bool((it["data"] as Dictionary).get("finale", false)):
				has_finale = true
		if has_finale:
			hud.set_objective("اکنون به سراغ «%s» برو و با او سخن بگو." % _finale_title())
			hud.toast("همه‌ی بخش‌ها کامل شد. به سراغ «%s» برو." % _finale_title(), 5.0)
		else:
			_finish_level()

func _finale_title() -> String:
	for it in items:
		var d: Dictionary = it["data"]
		if bool(d.get("finale", false)):
			return str(d["title"])
	return ""

func _finish_level() -> void:
	if finished:
		return
	finished = true
	var stars := 3 if mistakes == 0 else (2 if mistakes <= 2 else 1)
	var k: Dictionary = level["knowledge"]
	GameState.complete_level(level_index, stars, str(k["id"]))
	var has_next := level_index + 1 < LevelData.LEVELS.size()
	hud.show_level_complete(level, stars, has_next, func() -> void: load_level(level_index + 1))

# ---------- per-frame ----------

func _process(delta: float) -> void:
	if not level_active:
		return
	var t := Time.get_ticks_msec() * 0.001
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5 and player.is_on_floor()
	PropFactory.animate_zal(player.art, moving, t)
	if player.global_position.y < kill_y:
		_respawn()
	var near := _nearest_item()
	hud.set_interact_ready(not near.is_empty())
	for it in items:
		var node: Node3D = it["node"]
		if not is_instance_valid(node):
			continue
		var kind := str((it["data"] as Dictionary)["kind"])
		if kind == "clue" and not str((it["data"] as Dictionary)["id"]).begins_with("banner"):
			var ring := node.get_node_or_null("Ring")
			if ring:
				(ring as Node3D).rotation.y = t * 1.6
				(ring as Node3D).rotation.x = 1.1
			node.position.y = float(it["base_y"]) + sin(t * 2.0 + node.position.x) * 0.12
	if simorgh:
		simorgh.position.y = float(items[_simorgh_index()]["base_y"]) + sin(t * 1.1) * 0.35
		PropFactory.animate_simorgh(simorgh, t)
		simorgh.look_at(Vector3(player.global_position.x, simorgh.global_position.y, player.global_position.z), Vector3.UP, true)
	for c in clouds:
		var parent := c.get_parent() as Node3D
		parent.position.x += float(parent.get_meta("speed")) * delta
		if parent.position.x > 200.0:
			parent.position.x = -200.0

func _simorgh_index() -> int:
	for i in range(items.size()):
		if (items[i]["data"] as Dictionary)["id"] == "simorgh":
			return i
	return 0

func _respawn() -> void:
	player.global_position = checkpoint
	player.velocity = Vector3.ZERO
	hud.toast("از لبه افتادی؛ دوباره تلاش کن.", 3.0)

# ---------- self test (CI) ----------

func _run_selftest() -> void:
	var failures := 0
	for i in range(LevelData.LEVELS.size()):
		load_level(i, false)
		await get_tree().process_frame
		await get_tree().physics_frame
		for it in items:
			if not bool((it["data"] as Dictionary).get("finale", false)):
				it["done"] = true
		if not _required_done():
			failures += 1
		# exercise every UI path once
		for it in items:
			var d: Dictionary = it["data"]
			match str(d["kind"]):
				"quiz":
					hud.show_quiz(d, func(_a: bool, _b: bool) -> void: pass)
					hud.close_all_modals()
				"npc":
					hud.show_dialogue(str(d["speaker"]), d["lines"], d.get("choices", []), d.get("after", []), func() -> void: pass)
					hud.close_all_modals()
		await get_tree().create_timer(0.3).timeout
		# the player must stand on the terrain after a short settle
		for _f in range(40):
			await get_tree().physics_frame
		var standing := player.is_on_floor()
		print("level %d (%s): items=%d on_floor=%s y=%.2f" % [i, level["id"], items.size(), standing, player.global_position.y])
		if not standing:
			failures += 1
		_finish_level()
		hud.close_all_modals()
		finished = false
	hud.show_main_menu()
	hud.close_all_modals()
	hud.show_pause_menu()
	hud.close_all_modals()
	hud.show_knowledge_list()
	hud.close_all_modals()
	print("SELFTEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)
