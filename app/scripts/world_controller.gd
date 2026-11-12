extends Node3D
class_name WorldController
## Builds each chapter from LevelData, runs interactions and mission flow.

const TALK_KINDS := ["npc", "quiz"]
const AUTO_RADIUS := {"clue": 1.9, "log": 1.7, "brazier": 2.6}
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
var trunks: Array[RigidBody3D] = []   # pushable tree trunks (bridge levels)
var bridge_need := 0
var bridge_delivered := 0
var bridge_built := false
var bridge_slot: Area3D
var _hint_trunk_shown := false
var scale_stones: Array[RigidBody3D] = []
var scale_target := 0
var scale_sum := 0
var scale_solved := false
var scale_hold := 0.0
var scale_pan_l := Vector3.ZERO
var scale_beam: Node3D
var scale_lamp: MeshInstance3D
var scale_door: StaticBody3D
var scale_door_col: CollisionShape3D

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
	trunks.clear()
	scale_stones.clear()
	scale_sum = 0
	scale_solved = false
	scale_hold = 0.0
	scale_beam = null
	scale_lamp = null
	scale_door = null
	scale_door_col = null
	bridge_need = 0
	bridge_delivered = 0
	bridge_built = false
	bridge_slot = null
	_hint_trunk_shown = false
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
	if level.has("bridge"):
		_build_bridge()
	if level.has("scale"):
		_build_scale_gate()
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
		voice_keys = [intro_key, lid + "__" + str(level.get("intro_extra_key", "intro_extra")), objective_key] if level.has("intro_extra") else [intro_key, objective_key]
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
		var pts := terrain.scatter_points(tree_count, maxf(5.0, float(level.get("lane_clear", 0.0))), float(level["valley_half"]) + 22.0)
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
			var rp := terrain.scatter_points(rock_count / 3, maxf(3.0, float(level.get("lane_clear", 0.0))), float(level["valley_half"]) + 20.0, false)
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
			"scale":
				node = Node3D.new()   # logical anchor; the pans, beam and gate are built by _build_scale_gate()
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
					"gatekeeper":
						node = PropFactory.make_figure(Color("#3b4a5a"), Color("#a8a39a"), true)
					_:
						node = PropFactory.make_stone_tablet()
		node.position = pos
		level_root.add_child(node)
		if str(data["kind"]) == "npc" and str(data["id"]) in ["sam", "mobed", "gatekeeper"]:
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
		var kind_here := str((it["data"] as Dictionary)["kind"])
		if only_kind != "" and kind_here != only_kind:
			continue
		if only_kind == "" and kind_here not in TALK_KINDS:
			continue   # the interact button is for conversation only
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
	## Interact is for conversation only (NPCs and question pedestals).
	if not level_active or hud.is_modal_open():
		return
	var it := _nearest_item()
	if it.is_empty():
		_msg("nothing_to_talk", 3.0)
		return
	var d: Dictionary = it["data"]
	match str(d["kind"]):
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

## Physical actions: walking into things picks them up / delivers them. Edge-triggered
## (fires when the player ENTERS the radius) so nothing repeats while standing still.
func _auto_actions() -> void:
	if not level_active or hud.is_modal_open():
		return
	for it in items:
		var d: Dictionary = it["data"]
		var kind := str(d["kind"])
		if not AUTO_RADIUS.has(kind):
			continue
		var node: Node3D = it["node"]
		if not is_instance_valid(node):
			it["inside"] = false
			continue
		var a := player.global_position
		var b := node.global_position
		var inside := Vector2(a.x - b.x, a.z - b.z).length() < float(AUTO_RADIUS[kind]) and absf(a.y - b.y) < 3.2
		var was := bool(it.get("inside", false))
		it["inside"] = inside
		if not inside or was:
			continue
		match kind:
			"clue":
				if not bool(it["done"]):
					_collect(it)
					hud.toast(str(d["hint"]), 4.0)
					if GameState.voice_mode == 2:
						AudioManager.play_voice("%s__hint_%s" % [str(level["id"]), str(d["id"])])
					_check_finish()
			"log":
				if not bool(it["done"]) and carrying.is_empty():
					_pick_log(it)
			"brazier":
				if bool(it["done"]):
					continue
				if not carrying.is_empty() or not _has_logs():
					_use_brazier(it)
				else:
					_msg("need_log", 3.5)

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
	_msg("log_carry", 4.5)

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
	_auto_actions()
	_update_bridge()
	_update_scale(delta)
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
	if level.has("bridge"):
		failures += await _selftest_bridge()
	if level.has("scale"):
		failures += await _selftest_scale()
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

## Firewood flow (automatic, no interact button): no wood = no fire; the correct fire burns the wood;
## a wrong fire returns it and resets the order.
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
	var far := Vector3(player.global_position.x, player.global_position.y, player.global_position.z + 40.0)
	player.global_position = (fires[0]["node"] as Node3D).global_position + Vector3(1.0, 0.5, 0)
	_auto_actions()   # no wood: must NOT light the fire
	if bool(fires[0]["done"]) or brazier_next != 0:
		bad += 1
	player.global_position = (logs[0]["node"] as Node3D).global_position + Vector3(0.8, 0.5, 0)
	_auto_actions()   # walk onto the log: picked up
	if carrying.is_empty() or player.run_speed >= base_run_speed:
		bad += 1
	player.global_position = (fires[2]["node"] as Node3D).global_position + Vector3(1.0, 0.5, 0)
	_auto_actions()   # wrong fire: wood returns, fires reset
	if not carrying.is_empty() or bool(logs[0]["done"]) or brazier_next != 0:
		bad += 1
	player.global_position = far
	_auto_actions()
	player.global_position = (logs[0]["node"] as Node3D).global_position + Vector3(0.8, 0.5, 0)
	_auto_actions()
	player.global_position = (fires[0]["node"] as Node3D).global_position + Vector3(1.0, 0.5, 0)
	_auto_actions()   # right fire: lit, wood burned
	if not bool(fires[0]["done"]) or brazier_next != 1 or not carrying.is_empty():
		bad += 1
	# the interact button must NOT do any of the physical actions
	_interact()
	print("  log flow: %s" % ("ok" if bad == 0 else "FAILED (%d)" % bad))
	player.global_position = spawn_point
	return bad

## Pushing a trunk into the slot builds the bridge, and the player can then walk across it.
func _selftest_bridge() -> int:
	var gap := _gap_info()
	var need := bridge_need
	var guard := 0
	while bridge_delivered < need and guard < need + 2:
		guard += 1
		if trunks.is_empty():
			break
		var rb: RigidBody3D = trunks[0]
		var start_z := rb.global_position.z + 2.1
		player.global_position = Vector3(rb.global_position.x, terrain.height(rb.global_position.x, start_z) + 0.6, start_z)
		player.velocity = Vector3.ZERO
		var before := bridge_delivered
		for _f in range(900):
			await get_tree().physics_frame
			if not is_instance_valid(rb) or bridge_delivered > before:
				break
			GameState.move_vector = Vector2(clampf((rb.global_position.x - player.global_position.x) * 0.8, -1.0, 1.0), -1.0)
		GameState.move_vector = Vector2.ZERO
		if bridge_delivered <= before:
			print("  bridge: trunk %d never reached the bank (z=%.1f)" % [guard, rb.global_position.z if is_instance_valid(rb) else 0.0])
			return 1
	if not bridge_built:
		print("  bridge: not built after delivering %d trunks" % bridge_delivered)
		return 1
	# walk across
	var mid := float(gap["mid"])
	var target := Vector2(terrain.path_x(float(gap["far"]) - 6.0), float(gap["far"]) - 6.0)
	var near_pos := Vector2(terrain.path_x(float(gap["near"]) + 3.0), float(gap["near"]) + 3.0)
	player.global_position = Vector3(near_pos.x, terrain.height(near_pos.x, near_pos.y) + 0.6, near_pos.y)
	player.velocity = Vector3.ZERO
	var crossed := false
	for _f in range(900):
		await get_tree().physics_frame
		var d := target - Vector2(player.global_position.x, player.global_position.z)
		if d.length() < 1.5 and player.is_on_floor():
			crossed = true
			break
		if player.global_position.y < kill_y:
			break
		GameState.move_vector = d.normalized()
	GameState.move_vector = Vector2.ZERO
	print("  bridge: need=%d built=%s crossed=%s" % [need, bridge_built, crossed])
	player.global_position = spawn_point
	return 0 if crossed else 1

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

# ---------- river bridge (push a tree trunk to the bank) ----------

func _gap_info() -> Dictionary:
	var ch: Dictionary = level["chasm"]
	var near_z := float(ch["z0"])
	var far_z := float(ch["z1"]) - float(ch.get("edge", 2.0))
	return {"near": near_z, "far": far_z, "mid": (near_z + far_z) * 0.5}

func _build_bridge() -> void:
	var br: Dictionary = level["bridge"]
	var gap := _gap_info()
	bridge_need = int(DifficultyRules.BRIDGE_TRUNKS[GameState.difficulty])
	var spawn_list: Array = br["trunks"]
	var count := mini(bridge_need + 2, spawn_list.size())
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	for i in range(count):
		var off: Vector2 = spawn_list[i]
		var z := off.y
		var x := terrain.path_x(z) + off.x
		var rb := RigidBody3D.new()
		rb.name = "Trunk%d" % i
		rb.mass = 30.0
		rb.linear_damp = 1.6
		rb.angular_damp = 2.2
		rb.continuous_cd = true
		rb.physics_material_override = pm
		rb.add_to_group("pushable")
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5
		cyl.height = 2.6
		cs.shape = cyl
		cs.rotation.z = PI * 0.5
		rb.add_child(cs)
		rb.add_child(PropFactory.make_trunk())
		level_root.add_child(rb)
		rb.global_position = Vector3(x, terrain.height(x, z) + 0.9, z)
		rb.set_meta("home", rb.global_position)
		trunks.append(rb)
	# detection zone on the near bank
	var px := terrain.path_x(float(gap["near"]) + 3.0)
	var by := terrain.height(px, float(gap["near"]) + 3.0)
	bridge_slot = Area3D.new()
	bridge_slot.name = "BridgeSlot"
	var slot_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(18.0, 4.0, 4.5)
	slot_shape.shape = box
	bridge_slot.add_child(slot_shape)
	bridge_slot.position = Vector3(px, by + 1.0, float(gap["near"]) + 2.6)
	level_root.add_child(bridge_slot)
	bridge_slot.body_entered.connect(_on_slot_body)
	# water at the bottom of the gap (falling in = respawn)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(170.0, absf(float(gap["near"]) - float(gap["far"])) + 6.0)
	water.mesh = plane
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://shaders/water.gdshader")
	water.material_override = wmat
	water.position = Vector3(0.0, float(br.get("water_y", -2.3)), float(gap["mid"]))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level_root.add_child(water)

func _on_slot_body(body: Node3D) -> void:
	if bridge_built or not (body is RigidBody3D) or not trunks.has(body as RigidBody3D):
		return
	var rb := body as RigidBody3D
	trunks.erase(rb)
	var burst := PropFactory.make_burst(Color("#c9a26b"))
	burst.position = rb.global_position
	level_root.add_child(burst)
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)
	rb.queue_free()
	bridge_delivered += 1
	if bridge_delivered >= bridge_need:
		_build_deck()
		_msg("bridge_built", 5.0)
	else:
		_msg("bridge_more", 4.0)

func _build_deck() -> void:
	bridge_built = true
	var gap := _gap_info()
	var near_z := float(gap["near"])
	var far_z := float(gap["far"])
	var mid := float(gap["mid"])
	var length := absf(near_z - far_z) + 4.0
	var px := terrain.path_x(mid)
	var top := maxf(terrain.height(terrain.path_x(near_z + 1.0), near_z + 1.0), terrain.height(terrain.path_x(far_z - 1.0), far_z - 1.0)) + 0.03
	var width := 5.0
	var deck := StaticBody3D.new()
	deck.name = "BridgeDeck"
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(width, 0.5, length)
	cs.shape = bx
	cs.position = Vector3(px, top - 0.25, mid)
	deck.add_child(cs)
	var bark := PropFactory.mat(Color("#6a4a2c"), 1.0)
	var planks := PropFactory.mat(Color("#a9815a"), 0.95)
	deck.add_child(PropFactory.part(PropFactory.box(Vector3(width, 0.18, length)), planks, Vector3(px, top - 0.09, mid)))
	for s in [-1.0, 1.0]:
		var rail := PropFactory.part(PropFactory.cylinder(0.3, 0.3, length, 10), bark, Vector3(px + s * (width * 0.5), top - 0.05, mid))
		rail.rotation.x = PI * 0.5
		deck.add_child(rail)
	for k in range(bridge_need + 1):
		var z := near_z - 1.5 - float(k) * (length - 3.0) / float(maxi(bridge_need, 1))
		deck.add_child(PropFactory.part(PropFactory.box(Vector3(width + 0.6, 0.12, 0.35)), bark, Vector3(px, top + 0.02, z)))
	level_root.add_child(deck)
	for rb in trunks:
		rb.queue_free()   # spares are no longer needed
	trunks.clear()

func _update_bridge() -> void:
	if not level.has("bridge"):
		return
	var gap := _gap_info()
	# a trunk that fell into the river returns to where it started (the level stays finishable)
	for rb in trunks:
		if is_instance_valid(rb) and rb.global_position.y < kill_y + 1.0:
			rb.linear_velocity = Vector3.ZERO
			rb.angular_velocity = Vector3.ZERO
			rb.global_position = rb.get_meta("home")
			_msg("trunk_lost", 3.0)
		elif is_instance_valid(rb) and not _hint_trunk_shown and rb.global_position.distance_to(player.global_position) < 3.2:
			_hint_trunk_shown = true
	# respawn at solid ground on either bank, never inside the gap
	if player.is_on_floor():
		var z := player.global_position.z
		if z > float(gap["near"]) + 2.0 or z < float(gap["far"]) - 2.0:
			checkpoint = player.global_position + Vector3(0, 0.4, 0)

# ---------- balance gate (push millstones onto the left pan) ----------

func _build_scale_gate() -> void:
	var sc: Dictionary = level["scale"]
	var diff := GameState.difficulty
	scale_target = int((sc["target"] as Array)[diff])
	var weights: Array = (sc["stones"] as Array)[diff]
	var z := float(sc["z"])
	var cx := terrain.path_x(z)
	var gy := terrain.height(cx, z)
	var pan_off := 6.0
	scale_pan_l = Vector3(cx - pan_off, terrain.height(cx - pan_off, z), z)
	var pan_r := Vector3(cx + pan_off, terrain.height(cx + pan_off, z), z)
	var font: Font = load("res://fonts/Vazirmatn-Bold.ttf")
	var pan_mat := PropFactory.mat(Color("#c9b78e"), 0.9)
	var rim_mat := PropFactory.mat(Color("#8a7a58"), 0.9)
	for p in [scale_pan_l, pan_r]:
		level_root.add_child(PropFactory.part(PropFactory.cylinder(3.3, 3.3, 0.3, 36), rim_mat, p + Vector3(0, 0.02, 0)))
		level_root.add_child(PropFactory.part(PropFactory.cylinder(3.0, 3.0, 0.3, 36), pan_mat, p + Vector3(0, 0.06, 0)))
	# the fixed "offering" on the right pan (its number is the weight to match)
	var offer := PropFactory.part(PropFactory.cylinder(1.5, 1.5, 1.1, 20), PropFactory.mat(Color("#6d6659"), 0.95), pan_r + Vector3(0, 0.7, 0))
	level_root.add_child(offer)
	var offer_body := StaticBody3D.new()
	var ocs := CollisionShape3D.new()
	var ocyl := CylinderShape3D.new()
	ocyl.radius = 1.5
	ocyl.height = 1.1
	ocs.shape = ocyl
	offer_body.add_child(ocs)
	offer_body.position = pan_r + Vector3(0, 0.7, 0)
	level_root.add_child(offer_body)
	level_root.add_child(_weight_label(hud.fa(scale_target), pan_r + Vector3(0, 2.5, 0), font, 0.02))
	# balance beam on a post; tilts with (left - right)
	var post := PropFactory.part(PropFactory.cylinder(0.25, 0.35, 7.0, 10), PropFactory.mat(Color("#5b4a38"), 0.9), Vector3(cx, gy + 3.5, z))
	level_root.add_child(post)
	scale_beam = Node3D.new()
	scale_beam.position = Vector3(cx, gy + 7.0, z)
	scale_beam.add_child(PropFactory.part(PropFactory.box(Vector3(pan_off * 2.0 + 1.6, 0.3, 0.3)), PropFactory.mat(Color("#c79a3d"), 0.4, 0.4), Vector3.ZERO))
	for sx in [-pan_off, pan_off]:
		scale_beam.add_child(PropFactory.part(PropFactory.sphere(0.45, 12), PropFactory.mat(Color("#c79a3d"), 0.4, 0.4), Vector3(sx, -0.1, 0)))
	level_root.add_child(scale_beam)
	scale_lamp = PropFactory.part(PropFactory.sphere(0.5, 14), PropFactory.mat(Color("#d9a441"), 0.3, 0.0, 2.0), Vector3(cx, gy + 7.9, z))
	level_root.add_child(scale_lamp)
	# millstones
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.rough = true
	for i in range(weights.size()):
		var w := int(weights[i])
		var r := 0.5 + 0.1 * float(w)
		var sx2 := scale_pan_l.x + (float(i) - float(weights.size() - 1) * 0.5) * 2.8
		var sz2 := z + 11.0 + float(i % 2) * 2.6
		var rb := RigidBody3D.new()
		rb.name = "Millstone%d" % i
		rb.mass = 8.0 * float(w)
		rb.linear_damp = 8.0
		rb.angular_damp = 20.0
		rb.axis_lock_angular_x = true
		rb.axis_lock_angular_z = true
		rb.continuous_cd = true
		rb.physics_material_override = pm
		rb.add_to_group("pushable")
		rb.set_meta("w", w)
		rb.set_meta("r", r)
		rb.set_meta("push_factor", 1.0 / sqrt(float(w)))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = r
		cyl.height = 1.5
		cs.shape = cyl
		rb.add_child(cs)
		var shade := Color("#a89d88").darkened(0.05 * float(w))
		rb.add_child(PropFactory.part(PropFactory.cylinder(r, r, 1.5, 20), PropFactory.mat(shade, 0.95)))
		rb.add_child(PropFactory.part(PropFactory.cylinder(r * 0.22, r * 0.22, 1.54, 10), PropFactory.mat(Color("#5d5648"), 0.9)))
		level_root.add_child(rb)
		rb.global_position = Vector3(sx2, terrain.height(sx2, sz2) + 0.85, sz2)
		rb.set_meta("home", rb.global_position)
		rb.add_child(_weight_label(hud.fa(w), Vector3(0, 1.3, 0), font, 0.012, true))
		scale_stones.append(rb)
	# the gate: pillars, lintel, door, and walls so it cannot be walked around
	var gz := z - 14.0
	var stone := PropFactory.mat(Color("#b4a58a"), 0.95)
	var gate_body := StaticBody3D.new()
	gate_body.name = "GateWalls"
	level_root.add_child(gate_body)
	for side in [-1.0, 1.0]:
		level_root.add_child(PropFactory.part(PropFactory.box(Vector3(1.4, 8.0, 1.6)), stone, Vector3(cx + side * 3.6, gy + 4.0, gz)))
		level_root.add_child(PropFactory.part(PropFactory.box(Vector3(34.0, 7.0, 1.6)), stone, Vector3(cx + side * 21.7, gy + 3.5, gz)))
		var wc := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(34.0, 14.0, 1.6)
		wc.shape = wb
		wc.position = Vector3(cx + side * 21.7, gy + 6.0, gz)
		gate_body.add_child(wc)
		var pc := CollisionShape3D.new()
		var pb := BoxShape3D.new()
		pb.size = Vector3(1.4, 8.0, 1.6)
		pc.shape = pb
		pc.position = Vector3(cx + side * 3.6, gy + 4.0, gz)
		gate_body.add_child(pc)
	level_root.add_child(PropFactory.part(PropFactory.box(Vector3(8.6, 1.2, 1.6)), stone, Vector3(cx, gy + 8.4, gz)))
	scale_door = StaticBody3D.new()
	scale_door.name = "GateDoor"
	scale_door.position = Vector3(cx, gy + 3.9, gz)
	scale_door.add_child(PropFactory.part(PropFactory.box(Vector3(5.8, 7.8, 0.8)), PropFactory.mat(Color("#6a4a2c"), 0.8), Vector3.ZERO))
	scale_door.add_child(PropFactory.part(PropFactory.box(Vector3(5.8, 0.3, 0.9)), PropFactory.mat(Color("#c79a3d"), 0.4, 0.5), Vector3(0, 2.0, 0)))
	scale_door.add_child(PropFactory.part(PropFactory.box(Vector3(5.8, 0.3, 0.9)), PropFactory.mat(Color("#c79a3d"), 0.4, 0.5), Vector3(0, -2.0, 0)))
	scale_door_col = CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(5.8, 7.8, 0.8)
	scale_door_col.shape = dbox
	scale_door.add_child(scale_door_col)
	level_root.add_child(scale_door)

func _weight_label(text: String, pos: Vector3, font: Font, pixel: float, billboard: bool = true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 120
	l.pixel_size = pixel * 1.6
	l.outline_size = 14
	l.modulate = Color("#ffe39a")
	l.outline_modulate = Color("#3a2a12")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = pos
	return l

func _update_scale(delta: float) -> void:
	if not level.has("scale") or scale_beam == null:
		return
	var total := 0
	var still := true
	for rb in scale_stones:
		if not is_instance_valid(rb):
			continue
		var p := rb.global_position
		if p.y < -20.0:
			rb.linear_velocity = Vector3.ZERO
			rb.global_position = rb.get_meta("home")
			continue
		if Vector2(p.x - scale_pan_l.x, p.z - scale_pan_l.z).length() < 3.0 and absf(p.y - scale_pan_l.y) < 2.2:
			total += int(rb.get_meta("w"))
			if rb.linear_velocity.length() > 0.6:
				still = false
	scale_sum = total
	scale_beam.rotation.z = lerpf(scale_beam.rotation.z, clampf(float(total - scale_target) * 0.07, -0.5, 0.5), 1.0 - exp(-4.0 * delta))
	var lamp_mat := scale_lamp.material_override as StandardMaterial3D
	var lamp_color := Color("#3fd16a") if total == scale_target else (Color("#e06a3a") if total > scale_target else Color("#d9a441"))
	lamp_mat.albedo_color = lamp_color
	lamp_mat.emission = lamp_color
	if scale_solved:
		return
	if total == scale_target and still:
		scale_hold += delta
	else:
		scale_hold = 0.0
	if scale_hold >= 1.2:
		_solve_scale()

func _solve_scale() -> void:
	scale_solved = true
	for it in items:
		if str((it["data"] as Dictionary)["kind"]) == "scale":
			_mark_done(it)
	_msg("scale_solved", 4.5)
	var tw := create_tween()
	tw.tween_property(scale_door, "position:y", scale_door.position.y + 8.2, 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: scale_door_col.set_deferred("disabled", true))
	_check_finish()

func _subset_for(weights: Array, target: int) -> Array:
	var n := weights.size()
	var best: Array = []
	for mask in range(1, 1 << n):
		var sum := 0
		var idxs: Array = []
		for b in range(n):
			if mask & (1 << b):
				sum += int(weights[b])
				idxs.append(b)
		if sum == target and (best.is_empty() or idxs.size() < best.size()):
			best = idxs   # fewest stones = fewest to fit on the pan
	return best

## Bot: the gate stays shut until the weights match; pushing the right millstones opens it; then walk through.
func _selftest_scale() -> int:
	var cx := terrain.path_x(float((level["scale"] as Dictionary)["z"]))
	var gate_z := float((level["scale"] as Dictionary)["z"]) - 14.0
	# 1) closed gate really blocks
	player.global_position = Vector3(cx, terrain.height(cx, gate_z + 4.0) + 0.6, gate_z + 4.0)
	player.velocity = Vector3.ZERO
	for _f in range(150):
		await get_tree().physics_frame
		GameState.move_vector = Vector2(0, -1)
	GameState.move_vector = Vector2.ZERO
	if player.global_position.z < gate_z:
		print("  scale: player walked through the CLOSED gate")
		return 1
	# 2) push the stones whose weights sum to the target onto the left pan
	var ws: Array = []
	for rb in scale_stones:
		ws.append(int(rb.get_meta("w")))
	var pick := _subset_for(ws, scale_target)
	if pick.is_empty():
		print("  scale: no stone combination reaches %d" % scale_target)
		return 1
	var pan_center := Vector2(scale_pan_l.x, scale_pan_l.z)
	var slot_n := 0
	for idx in pick:
		# each stone gets its own spot on the pan, like a player would (stones cannot overlap)
		var ang := float(slot_n) * TAU / float(maxi(pick.size(), 1)) + 0.4
		var pan := pan_center + Vector2(cos(ang), sin(ang)) * 1.7
		slot_n += 1
		var rb: RigidBody3D = scale_stones[idx]
		var r := float(rb.get_meta("r"))
		for f in range(800):
			var sp := Vector2(rb.global_position.x, rb.global_position.z)
			var to_pan := pan - sp
			if to_pan.length() < 0.9:
				break
			var dirv := to_pan.normalized()
			var behind := sp - dirv * (r + 0.7)
			if f == 0:
				player.global_position = Vector3(behind.x, terrain.height(behind.x, behind.y) + 0.6, behind.y)
				player.velocity = Vector3.ZERO
			var pp := Vector2(player.global_position.x, player.global_position.z)
			var mv := dirv + (behind - pp) * 1.2
			GameState.move_vector = mv.limit_length(1.0)
			await get_tree().physics_frame
			if f == 799:
				print("    push timeout: stone w=%d at %s slot %s player %s" % [int(rb.get_meta("w")), rb.global_position, pan, player.global_position])
		GameState.move_vector = Vector2.ZERO
	# 3) wait for the balance + door animation, then walk through
	player.global_position = Vector3(cx, terrain.height(cx, gate_z + 8.0) + 0.6, gate_z + 8.0)   # step away from the stones
	player.velocity = Vector3.ZERO
	for _f in range(480):
		await get_tree().physics_frame
	if not scale_solved:
		print("  scale: not solved (sum=%d target=%d hold=%.2f)" % [scale_sum, scale_target, scale_hold])
		for rb in scale_stones:
			print("    stone w=%d pos=%s vel=%.2f" % [int(rb.get_meta("w")), rb.global_position, rb.linear_velocity.length()])
		return 1
	player.global_position = Vector3(cx, terrain.height(cx, gate_z + 4.0) + 0.6, gate_z + 4.0)
	player.velocity = Vector3.ZERO
	var through := false
	for _f in range(400):
		await get_tree().physics_frame
		GameState.move_vector = Vector2(0, -1)
		if player.global_position.z < gate_z - 5.0 and player.is_on_floor():
			through = true
			break
	GameState.move_vector = Vector2.ZERO
	print("  scale: target=%d stones=%s solved=%s through_gate=%s" % [scale_target, str(ws), scale_solved, through])
	player.global_position = spawn_point
	return 0 if through else 1
