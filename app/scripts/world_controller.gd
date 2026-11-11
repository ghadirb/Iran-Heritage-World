extends Node3D
class_name WorldController
## Builds each chapter from LevelData, runs interactions and mission flow.

var interact_radius := 4.2
var beam_range := 9999.0

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
var moving_stones: Dictionary = {}   # chain index -> {"body": AnimatableBody3D, "base": Vector3, "phase": float}
var chain_time := 0.0
var carrying: Dictionary = {}       # the log item the player holds (empty = nothing)
var base_run_speed := 6.2

func _ready() -> void:
	selftest = OS.get_cmdline_user_args().has("--selftest")
	player = PlayerController.new()
	player.name = "Player"
	base_run_speed = player.run_speed
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
	hud.start_level.connect(_start_level_async)
	hud.restart_requested.connect(func() -> void: load_level(level_index))
	GameState.quality_changed.connect(_apply_quality)
	if OS.get_cmdline_user_args().has("--jumptest"):
		await get_tree().process_frame
		await _run_jumptest()
		return
	if selftest:
		await get_tree().process_frame
		await _run_selftest()
		return
	var shot := _arg_value("--shot")
	if shot != "":
		await _run_screenshot(shot)
		return
	# No 3D level behind the menu: building it before the player taps anything
	# froze weak phones and made the menu unresponsive.
	hud.show_main_menu()
	if GameState.safe_mode_triggered:
		hud.toast("بازی در حالت سبک (کم‌مصرف) شروع شد. از «تنظیمات» می‌توانید کیفیت را تغییر دهید.", 8.0)

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

func _start_level_async(index: int) -> void:
	hud.show_loading("در حال بارگذاری مرحله…")
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.begin_loading_guard()
	load_level(index, true)
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.end_loading_guard()

func load_level(index: int, announce: bool = true) -> void:
	level_index = clampi(index, 0, LevelData.LEVELS.size() - 1)
	GameState.current_level = level_index
	level = DifficultyRules.apply(LevelData.LEVELS[level_index], GameState.difficulty)
	interact_radius = DifficultyRules.INTERACT_RADIUS[GameState.difficulty]
	beam_range = DifficultyRules.BEAM_RANGE[GameState.difficulty]
	level_active = false
	finished = false
	mistakes = 0
	brazier_next = 0
	moving_stones.clear()
	chain_time = 0.0
	carrying = {}
	player.run_speed = base_run_speed
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
	AudioManager.play_level(level)
	var lid := str(level["id"])
	# A reworded (harder) variant has its own narration keys; missing files are simply skipped.
	var intro_key := str(level.get("voice_intro", lid + "__intro"))
	var objective_key := str(level.get("voice_objective", lid + "__objective"))
	var voice_keys: Array = [objective_key]
	if announce:
		voice_keys = [intro_key, lid + "__intro_extra", objective_key] if level.has("intro_extra") else [intro_key, objective_key]
	hud.set_level_voice(voice_keys)
	if announce:
		hud.toast((str(level["intro"]) + " " + str(level.get("intro_extra", ""))).strip_edges(), 8.0)

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
	GameState.apply_engine_quality()
	if sun:
		sun.shadow_enabled = GameState.shadows
	if world_env:
		world_env.environment.glow_enabled = q >= 2
		world_env.environment.fog_enabled = true
		world_env.environment.adjustment_enabled = q >= 1
	var fractions := [0.3, 0.6, 1.0]
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
	# Anchor the first stone to solid ground BEFORE the chasm, not to the
	# terrain height inside the chasm (which is dozens of metres lower).
	var z_start := float(ch["z0"]) + 5.0
	var z_end := float(ch["z1"])
	var start_x := terrain.path_x(z_start)
	var end_x := terrain.path_x(z_end)
	var y_start := terrain.height(start_x, z_start) + 0.12
	var y_end := terrain.height(end_x, z_end) + 0.65
	var platform_y := lerpf(y_start, y_end, t)
	return Vector3(x, platform_y, z)

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
		var is_moving: bool = (ch.get("moving", []) as Array).has(i)
		holder.position = Vector3.ZERO if is_moving else p
		holder.rotation.y = sin(float(i) * 2.1) * 0.5
		holder.add_child(PropFactory.part(PropFactory.box(Vector3(3.4, 1.4, 3.4)), stone, Vector3(0, -0.7, 0)))
		holder.add_child(PropFactory.part(PropFactory.box(Vector3(3.5, 0.12, 3.5)), moss, Vector3(0, -0.04, 0)))
		holder.add_child(PropFactory.part(PropFactory.cylinder(0.9, 0.2, 6.0, 7), stone, Vector3(0, -4.4, 0)))
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(3.4, 1.4, 3.4)
		cs.shape = bx
		cs.rotation.y = holder.rotation.y
		if is_moving:
			# A sliding stone is its own AnimatableBody3D so it carries the player.
			var mover := AnimatableBody3D.new()
			mover.name = "MovingStone%d" % i
			mover.sync_to_physics = true
			mover.position = p
			cs.position = Vector3(0, -0.7, 0)
			mover.add_child(cs)
			mover.add_child(holder)
			level_root.add_child(mover)
			moving_stones[i] = {"body": mover, "base": p, "phase": float(i) * 1.7}
		else:
			level_root.add_child(holder)
			cs.position = p + Vector3(0, -0.7, 0)
			body.add_child(cs)

## Where a stone is right now (moving stones slide, the rest never move).
func stone_now(i: int) -> Vector3:
	if moving_stones.has(i):
		var m: Dictionary = moving_stones[i]
		if is_instance_valid(m["body"]):
			return (m["body"] as Node3D).global_position
	return chain_position(i)

func _physics_process(delta: float) -> void:
	if not level_active or moving_stones.is_empty():
		return
	chain_time += delta
	var ch: Dictionary = level["chain"]
	var amp := float(ch.get("move_amp", 0.0))
	var spd := float(ch.get("move_speed", 0.0))
	for i in moving_stones:
		var m: Dictionary = moving_stones[i]
		if is_instance_valid(m["body"]):
			(m["body"] as Node3D).position = (m["base"] as Vector3) + Vector3(sin(chain_time * spd + float(m["phase"])) * amp, 0, 0)

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
	# soft round dot instead of a hard square
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.size = Vector2(0.16, 0.16)
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
			"log":
				node = PropFactory.make_log()
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
		items.append({"data": data, "node": node, "done": false, "base_y": pos.y, "home": pos})

func _non_finale_items() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in items:
		var d: Dictionary = it["data"]
		if not bool(d.get("finale", false)) and str(d["kind"]) != "log":   # logs are tools, not goals
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

func _nearest_item(only_kind: String = "") -> Dictionary:
	var best: Dictionary = {}
	var best_d := interact_radius
	for it in items:
		if bool(it["done"]) and str((it["data"] as Dictionary)["kind"]) != "brazier":
			continue
		if only_kind != "" and str((it["data"] as Dictionary)["kind"]) != only_kind:
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
	if not carrying.is_empty():
		# Holding firewood: interact at a fire to place it, anywhere else to put it down.
		var fire := _nearest_item("brazier")
		if fire.is_empty():
			_drop_log()
		else:
			_use_brazier(fire)
		return
	var it := _nearest_item()
	if it.is_empty():
		_msg("nothing_near", 3.0)
		return
	var d: Dictionary = it["data"]
	match str(d["kind"]):
		"clue":
			_collect(it)
			hud.toast(str(d["hint"]), 4.0)
			if GameState.voice_mode == 2:
				AudioManager.play_voice("%s__hint_%s" % [str(level["id"]), str(d["id"])])
			_check_finish()
		"log":
			_pick_log(it)
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
				_say(str(d["hint"]), "%s__%s_locked" % [str(level["id"]), str(d["id"])], 3.5)
				return
			hud.show_dialogue(str(d["speaker"]), d["lines"], d.get("choices", []), d.get("after", []), func() -> void:
				_mark_done(it)
				_finish_level(), str(d["id"]))

func _collect(it: Dictionary) -> void:
	var node: Node3D = it["node"]
	if is_instance_valid(node):
		var burst := PropFactory.make_burst()
		burst.position = node.global_position
		level_root.add_child(burst)
		get_tree().create_timer(2.0).timeout.connect(burst.queue_free)
		node.queue_free()
		it["node"] = null   # a freed node must not stay referenced by _process
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

## Shows a message and, in automatic narration mode, speaks it when a recording exists.
func _say(text: String, voice_key: String, seconds: float) -> void:
	hud.toast(text, seconds)
	if GameState.voice_mode == 2:
		AudioManager.play_voice(voice_key)

func _msg(id: String, seconds: float) -> void:
	_say(str(GameMessages.TEXT[id]), "game__" + id, seconds)

func _has_logs() -> bool:
	for it in items:
		if str((it["data"] as Dictionary)["kind"]) == "log":
			return true
	return false

func _pick_log(it: Dictionary) -> void:
	carrying = it
	it["done"] = true   # hidden from "nearest item" while carried
	var node: Node3D = it["node"]
	node.reparent(player, false)
	node.position = Vector3(0, 2.3, 0)
	node.rotation = Vector3.ZERO
	player.run_speed = base_run_speed * float(DifficultyRules.CARRY_SPEED[GameState.difficulty])
	_msg("log_pick", 4.5)

func _release_log() -> void:
	carrying = {}
	player.run_speed = base_run_speed

func _drop_log() -> void:
	var it := carrying
	var node: Node3D = it["node"]
	var x := player.global_position.x
	var z := player.global_position.z
	node.reparent(level_root, false)
	node.position = Vector3(x, terrain.height(x, z), z)
	it["done"] = false
	_release_log()
	_msg("log_drop", 2.0)

## Wrong fire: the wood is not lost, it goes back where it was found.
func _return_log() -> void:
	var it := carrying
	var node: Node3D = it["node"]
	node.reparent(level_root, false)
	node.position = it["home"]
	it["done"] = false
	_release_log()

func _use_brazier(it: Dictionary) -> void:
	var d: Dictionary = it["data"]
	if bool(it["done"]):
		hud.toast("این آتش پیش‌تر روشن شده است.", 2.0)
		return
	if _has_logs() and carrying.is_empty():
		_msg("need_log", 3.5)
		return
	if int(d["order"]) == brazier_next:
		brazier_next += 1
		if not carrying.is_empty():
			(carrying["node"] as Node3D).queue_free()   # the wood burns
			carrying["node"] = null   # never keep a freed node in an item (typed reads would error)
			_release_log()
		_mark_done(it)
		var node: Node3D = it["node"]
		var flame := PropFactory.make_flame(Color(str(d["color"])))
		node.add_child(flame)
		_say(GameMessages.FIRE_LIT % str(d["title"]), "%s__fire_lit_%s" % [str(level["id"]), str(d["id"])], 2.5)
		_check_finish()
	else:
		mistakes += 1
		brazier_next = 0
		if not carrying.is_empty():
			_return_log()
		for other in items:
			if str((other["data"] as Dictionary)["kind"]) == "brazier":
				other["done"] = false
				var n: Node3D = other["node"]
				var fl := n.get_node_or_null("Flame")
				if fl:
					fl.queue_free()
		_refresh_progress()
		_say(GameMessages.wrong_order(level), str(level.get("voice_order_wrong", "%s__order_wrong" % str(level["id"]))), 5.0)

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
			_say(GameMessages.GO_FINALE % _finale_title(), "%s__go_finale" % str(level["id"]), 5.0)
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
	if level.has("chain") and player.is_on_floor():
		_update_platform_checkpoint()
	var near := _nearest_item()
	hud.set_interact_ready(not near.is_empty())
	var river_dist := -1.0
	if level.has("river"):
		river_dist = absf(player.global_position.x - terrain.river_x(player.global_position.z))
	AudioManager.update_ambience(level, player.global_position.y, river_dist)
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
		if kind == "clue" and beam_range < 1000.0:
			var beam := node.get_node_or_null("Beam")
			if beam:
				(beam as Node3D).visible = player.global_position.distance_to(node.global_position) < beam_range
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
	_msg("fall", 3.0)

func _update_platform_checkpoint() -> void:
	var ch: Dictionary = level["chain"]
	for i in range(int(ch["count"])):
		if moving_stones.has(i):
			continue   # never respawn onto a stone that has slid away
		var p := stone_now(i)
		var horizontal := Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length()
		if horizontal <= 1.45 and absf(player.global_position.y - p.y) <= 1.9:
			checkpoint = player.global_position
			return

# ---------- self test (CI) ----------

func _report_missing_voice() -> void:
	# Informational only: lists narration lines that have no audio file yet (see VoiceLines).
	var base_total := 0
	var base_missing := 0
	var new_total := 0
	var new_missing := 0
	for row in VoiceLines.all_lines():
		var missing := AudioManager.voice_path(str(row["key"])) == ""
		if bool(row["base"]):
			base_total += 1
			base_missing += 1 if missing else 0
		else:
			new_total += 1
			new_missing += 1 if missing else 0
		if missing:
			print("VOICE missing: ", row["key"])
	print("VOICE coverage: %d/%d (original) | new lines: %d/%d" % [base_total - base_missing, base_total, new_total - new_missing, new_total])

func _run_selftest() -> void:
	var failures := 0
	_report_missing_voice()
	for diff in range(3):
		GameState.difficulty = diff
		for i in range(LevelData.LEVELS.size()):
			failures += await _selftest_level(i)
	GameState.difficulty = 1
	hud.show_main_menu()
	hud.close_all_modals()
	hud.show_pause_menu()
	hud.close_all_modals()
	hud.show_knowledge_list()
	hud.close_all_modals()
	print("SELFTEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _selftest_level(i: int) -> int:
	var failures := 0
	load_level(i, false)
	await get_tree().process_frame
	await get_tree().physics_frame
	if _has_logs():
		failures += await _selftest_logs()
	for it in items:
		if not bool((it["data"] as Dictionary).get("finale", false)):
			it["done"] = true
	if not _required_done():
		failures += 1
	failures += _selftest_difficulty_sanity()
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
	if not moving_stones.is_empty():
		failures += await _selftest_carry()
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
	return failures

## Firewood flow: no wood = no fire; correct fire burns it; wrong fire returns it; drop works.
func _selftest_logs() -> int:
	var bad := 0
	var logs: Array = []
	var fires: Dictionary = {}
	for it in items:
		var d: Dictionary = it["data"]
		if str(d["kind"]) == "log":
			logs.append(it)
		elif str(d["kind"]) == "brazier":
			fires[int(d["order"])] = it
	player.global_position = (fires[0]["node"] as Node3D).global_position + Vector3(1.0, 0.5, 0)
	_interact()   # no wood: must NOT light the fire
	if bool(fires[0]["done"]) or brazier_next != 0:
		bad += 1
	player.global_position = (logs[0]["node"] as Node3D).global_position + Vector3(0.8, 0.5, 0)
	_interact()   # pick up
	if carrying.is_empty() or player.run_speed >= base_run_speed:
		bad += 1
	player.global_position = (fires[2]["node"] as Node3D).global_position + Vector3(1.0, 0.5, 0)
	_interact()   # wrong fire: wood returns, fires reset
	if not carrying.is_empty() or bool(logs[0]["done"]) or brazier_next != 0:
		bad += 1
	player.global_position = (logs[0]["node"] as Node3D).global_position + Vector3(0.8, 0.5, 0)
	_interact()
	player.global_position = Vector3(player.global_position.x, player.global_position.y, player.global_position.z + 12.0)
	_interact()   # far from any fire: drop
	if not carrying.is_empty() or player.run_speed != base_run_speed:
		bad += 1
	player.global_position = (logs[0]["node"] as Node3D).global_position + Vector3(0.8, 0.5, 0)
	_interact()
	player.global_position = (fires[0]["node"] as Node3D).global_position + Vector3(1.0, 0.5, 0)
	_interact()   # right fire: lit, wood burned
	if not bool(fires[0]["done"]) or brazier_next != 1 or not carrying.is_empty():
		bad += 1
	print("  log flow: %s" % ("ok" if bad == 0 else "FAILED (%d)" % bad))
	player.global_position = spawn_point
	return bad

## A player standing on a sliding stone must be carried along, not left behind.
func _selftest_carry() -> int:
	var idx: int = moving_stones.keys()[0]
	var start := stone_now(idx)
	player.global_position = start + Vector3(0, 1.0, 0)
	player.velocity = Vector3.ZERO
	for _f in range(30):
		await get_tree().physics_frame
	var x0 := player.global_position.x - stone_now(idx).x
	for _f in range(90):
		await get_tree().physics_frame
	var x1 := player.global_position.x - stone_now(idx).x
	var still_on := player.is_on_floor() and absf(x1) < 1.7
	print("  carry test: stone %d offset %.2f -> %.2f on_stone=%s" % [idx, x0, x1, still_on])
	player.global_position = spawn_point
	return 0 if still_on else 1

## Harder variants must stay finishable: valid quiz answers, clues on real stones, nothing below the kill line.
func _selftest_difficulty_sanity() -> int:
	var bad := 0
	for it in items:
		var d: Dictionary = it["data"]
		if str(d["kind"]) == "quiz":
			var opts: Array = d["options"]
			if int(d["answer"]) < 0 or int(d["answer"]) >= opts.size():
				bad += 1
		if d.has("on_chain") and int(d["on_chain"]) >= int((level["chain"] as Dictionary)["count"]):
			bad += 1
		var node: Node3D = it["node"]
		if is_instance_valid(node) and node.global_position.y < kill_y + 2.0:
			print("  unreachable item: ", d["id"])
			bad += 1
	if level.has("chain"):
		var chd: Dictionary = level["chain"]
		for mi in (chd.get("moving", []) as Array):
			if int(mi) <= 0 or int(mi) >= int(chd["count"]) - 1 or not moving_stones.has(int(mi)):
				bad += 1
	var orders := []
	for it in items:
		if str((it["data"] as Dictionary)["kind"]) == "brazier":
			orders.append(int((it["data"] as Dictionary)["order"]))
	orders.sort()
	if not orders.is_empty() and orders != [0, 1, 2, 3]:
		bad += 1
	return bad

## Bot that crosses the stone pass with the real physics (CI regression test).
func _run_jumptest() -> void:
	var jump_dist := 3.8
	var failures := 0
	for variant in range(3):
		GameState.difficulty = variant
		load_level(1, false)
		hud.close_all_modals()
		await get_tree().physics_frame
		jump_dist = [3.6, 3.8, 3.4][variant]
		var targets: Array[Vector3] = []
		var lip_z := float((level["chasm"] as Dictionary)["z0"]) + 3.0
		targets.append(Vector3(terrain.path_x(lip_z), 0, lip_z))
		var count := int((level["chain"] as Dictionary)["count"])
		for i in range(count):
			targets.append(chain_position(i))
		var far_z := float((level["chasm"] as Dictionary)["z1"]) - 6.0
		targets.append(Vector3(terrain.path_x(far_z), 0, far_z))
		var reached := 0
		for t in range(targets.size()):
			var target := targets[t]
			var frames := 0
			var ok := false
			while frames < 420:
				frames += 1
				await get_tree().physics_frame
				var d := Vector2(target.x - player.global_position.x, target.z - player.global_position.z)
				if d.length() < 1.5 and player.is_on_floor():
					ok = true
					break
				GameState.move_vector = d.normalized()
				if player.is_on_floor() and t > 0 and d.length() > 2.2 and (_ground_ends_ahead(d.normalized()) or d.length() < jump_dist):
					player.request_jump()
				elif player.is_on_floor() and t == 0 and d.length() < 0.9:
					ok = true
				if player.global_position.y < kill_y:
					break
			if not ok:
				print("  bot stuck heading to waypoint %d at %s (target %s) frames=%d floor=%s" % [t, player.global_position, target, frames, player.is_on_floor()])
				break
			reached += 1
		GameState.move_vector = Vector2.ZERO
		print("jumptest difficulty %d (jump at %.1f m): reached %d / %d waypoints" % [variant, jump_dist, reached, targets.size()])
		if reached < targets.size():
			failures += 1
	print("JUMPTEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(0 if failures == 0 else 1)




## True when there is no solid ground 0.55 m ahead (a human jumps right at the lip).
func _ground_ends_ahead(dir: Vector2) -> bool:
	var from := player.global_position + Vector3(dir.x, 0.5, dir.y) * 0.55
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.5, 0))
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
