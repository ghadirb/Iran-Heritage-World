extends Node3D
class_name WorldController

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

var found_clues: Array[String] = []
var clues_required := 3
var mission_complete := false
var clue_nodes: Array[Node3D] = []
var simorgh_wings: Array[MeshInstance3D] = []
var player_art: Node3D
var player_left_arm: Node3D
var player_right_arm: Node3D
var simorgh_root: Node3D

const CLUES := [
	{"id":"white_feather","title":"پر سپید","position":Vector3(-5.0, 0.65, -7.0),"hint":"ردی از پرهای سپید در کنار صخره پیدا کردی."},
	{"id":"old_nest","title":"شاخه‌های آشیانه","position":Vector3(5.5, 0.65, -11.0),"hint":"شاخه‌های بزرگ، از نزدیکی یک آشیانه خبر می‌دهند."},
	{"id":"mountain_mark","title":"نشان کوهستان","position":Vector3(1.0, 0.65, -19.0),"hint":"نقش کهنی روی سنگ دیده می‌شود؛ راه به سوی بلندی ادامه دارد."}
]

func _ready() -> void:
	_register_actions()
	_build_landscape()
	_build_player_art()
	_build_simorgh()
	_spawn_clues()
	hud.set_mission("ردّ آشیانه", "سه نشانه را در کوهستان پیدا کن.")
	hud.show_message("به دامنه البرز خوش آمدی. مسیر سنگی را دنبال کن و نشانه‌های زرین را بیاب.")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		_interact_nearest()
	if is_instance_valid(player_art):
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.25
		var swing := sin(Time.get_ticks_msec() * 0.009) * 0.38 if moving else 0.0
		player_left_arm.rotation.x = swing
		player_right_arm.rotation.x = -swing
		player_art.position.y = 0.03 + (absf(sin(Time.get_ticks_msec() * 0.012)) * 0.045 if moving else 0.0)
	if is_instance_valid(simorgh_root):
		simorgh_root.position.y = 7.4 + sin(Time.get_ticks_msec() * 0.0012) * 0.32
		for index in range(simorgh_wings.size()):
			simorgh_wings[index].rotation.z = sin(Time.get_ticks_msec() * 0.008 + float(index)) * 0.34

func _register_actions() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	InputMap.action_add_event("interact", event)

func _build_landscape() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.25, 0.43)
	sky_mat.sky_horizon_color = Color(0.83, 0.67, 0.48)
	sky_mat.ground_bottom_color = Color(0.13, 0.19, 0.18)
	sky_mat.ground_horizon_color = Color(0.48, 0.47, 0.39)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.64, 0.72, 0.82)
	env.ambient_light_energy = 0.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.61, 0.68, 0.72)
	env.fog_density = 0.006
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48.0
	add_child(sun)

	_add_ground()
	_add_trail()
	_add_mountain_ridges()
	_add_forest()
	_add_stream()
	_add_ancient_ruins()
	_add_brazier()

func _add_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "ValleyGround"
	add_child(ground)
	var mesh_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(58, 72)
	plane.subdivide_width = 12
	plane.subdivide_depth = 16
	mesh_node.mesh = plane
	mesh_node.position = Vector3(0, -0.12, -15)
	mesh_node.material_override = _material(Color(0.24, 0.32, 0.25), 1.0)
	ground.add_child(mesh_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(58, 0.5, 72)
	collision.shape = shape
	collision.position = Vector3(0, -0.38, -15)
	ground.add_child(collision)

func _add_trail() -> void:
	for i in range(13):
		var z := -float(i) * 2.55 - 1.0
		var x := sin(float(i) * 0.42) * 1.1
		var stone := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.5 + sin(float(i)) * 0.35, 0.12, 1.9)
		stone.mesh = mesh
		stone.position = Vector3(x, 0.02, z)
		stone.rotation.y = sin(float(i) * 0.8) * 0.08
		stone.material_override = _material(Color(0.48, 0.39, 0.28), 1.0)
		add_child(stone)

func _add_mountain_ridges() -> void:
	for i in range(11):
		var side := -1.0 if i % 2 == 0 else 1.0
		var peak := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 5.5 + float(i % 3) * 1.2
		cone.height = 15.0 + float(i % 4) * 2.5
		cone.radial_segments = 7
		peak.mesh = cone
		peak.position = Vector3(side * (15.0 + float(i % 3) * 2.0), 5.7, -float(i) * 5.0 - 5.0)
		peak.rotation.z = side * -0.12
		peak.material_override = _material(Color(0.30 + float(i % 3) * 0.025, 0.36 + float(i % 2) * 0.025, 0.37), 1.0)
		add_child(peak)
	for i in range(8):
		var rock_at := Vector3(-1.0 if i % 2 == 0 else 1.0, 3.2 + float(i % 3), -23.0 - float(i) * 3.1)
		_add_rock(rock_at, Vector3(8.0, 6.0, 7.0), Color(0.42, 0.45, 0.43))

func _add_forest() -> void:
	for i in range(34):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (5.8 + float((i * 7) % 13))
		var z := -float((i * 11) % 46) - 1.5
		_add_tree(Vector3(x, 0.0, z), 0.78 + float(i % 4) * 0.12)

func _add_stream() -> void:
	var water := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.65, 38.0)
	mesh.subdivide_depth = 8
	water.mesh = mesh
	water.position = Vector3(8.8, 0.035, -17.0)
	water.rotation_degrees.y = -7.0
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.16, 0.48, 0.59, 0.78)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.22
	water_mat.metallic = 0.12
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.035, 0.12, 0.16)
	water_mat.emission_energy_multiplier = 0.35
	water.material_override = water_mat
	add_child(water)
	for i in range(9):
		_add_rock(Vector3(7.4 + float(i % 2) * 2.4, 0.25, -float(i) * 4.0 - 1.0), Vector3(1.0, 0.7, 1.3), Color(0.39, 0.44, 0.42))

func _add_ancient_ruins() -> void:
	var stone_color := Color(0.62, 0.53, 0.39)
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.65, 3.3, 0.7)
		pillar.mesh = mesh
		pillar.position = Vector3(side * 3.0, 1.65, -26.0)
		pillar.material_override = _material(stone_color, 0.96)
		add_child(pillar)
		var capital := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.95, 0.28, 0.95)
		capital.mesh = cap_mesh
		capital.position = Vector3(side * 3.0, 3.35, -26.0)
		capital.material_override = _material(Color(0.76, 0.65, 0.46), 0.9)
		add_child(capital)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(6.7, 0.7, 0.9)
	lintel.mesh = lintel_mesh
	lintel.position = Vector3(0, 3.65, -26.0)
	lintel.material_override = _material(stone_color, 0.95)
	add_child(lintel)
	var emblem := MeshInstance3D.new()
	var emblem_mesh := TorusMesh.new()
	emblem_mesh.inner_radius = 0.42
	emblem_mesh.outer_radius = 0.62
	emblem.mesh = emblem_mesh
	emblem.position = Vector3(0, 3.65, -25.48)
	emblem.material_override = _material(Color(0.82, 0.61, 0.28), 0.55)
	add_child(emblem)

func _add_brazier() -> void:
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.38
	base_mesh.bottom_radius = 0.52
	base_mesh.height = 0.65
	base.mesh = base_mesh
	base.position = Vector3(-3.6, 0.32, -18.0)
	base.material_override = _material(Color(0.36, 0.31, 0.27), 0.8)
	add_child(base)
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.24
	flame_mesh.height = 0.75
	flame.mesh = flame_mesh
	flame.position = Vector3(-3.6, 0.95, -18.0)
	flame.scale = Vector3(0.7, 1.4, 0.7)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.43, 0.12)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.22, 0.035)
	flame_mat.emission_energy_multiplier = 2.0
	flame.material_override = flame_mat
	add_child(flame)
	var light := OmniLight3D.new()
	light.position = Vector3(-3.6, 1.2, -18.0)
	light.light_color = Color(1.0, 0.42, 0.13)
	light.light_energy = 1.3
	light.omni_range = 5.0
	add_child(light)

func _add_rock(at: Vector3, dimensions: Vector3, tint: Color) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	rock.mesh = mesh
	rock.position = at
	rock.scale = dimensions * 0.5
	rock.rotation = Vector3(0.12, at.x * 0.13, 0.08)
	rock.material_override = _material(tint, 1.0)
	add_child(rock)

func _add_tree(at: Vector3, tree_scale: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.2
	trunk_mesh.height = 1.7
	trunk.mesh = trunk_mesh
	trunk.position = at + Vector3(0, 0.85, 0)
	trunk.scale = Vector3.ONE * tree_scale
	trunk.material_override = _material(Color(0.29, 0.19, 0.12), 1.0)
	add_child(trunk)
	for tier in range(3):
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		crown_mesh.top_radius = 0.0
		crown_mesh.bottom_radius = 0.95 - float(tier) * 0.16
		crown_mesh.height = 1.65
		crown_mesh.radial_segments = 7
		crown.mesh = crown_mesh
		crown.position = at + Vector3(0, 1.35 + float(tier) * 0.67, 0)
		crown.scale = Vector3.ONE * tree_scale
		crown.material_override = _material(Color(0.13 + float(tier) * 0.025, 0.28 + float(tier) * 0.025, 0.20), 1.0)
		add_child(crown)

func _build_player_art() -> void:
	var old_mesh := player.get_node_or_null("BodyMesh")
	if old_mesh:
		old_mesh.queue_free()
	player_art = Node3D.new()
	player_art.name = "ZalCharacter"
	player.add_child(player_art)
	var robe := _make_mesh(CapsuleMesh.new(), Vector3(0, 0.72, 0), Vector3(0.72, 0.95, 0.58), Color(0.49, 0.24, 0.15))
	robe.name = "TravelRobe"
	player_art.add_child(robe)
	var head := _make_mesh(SphereMesh.new(), Vector3(0, 1.55, 0), Vector3(0.42, 0.46, 0.42), Color(0.72, 0.53, 0.38))
	player_art.add_child(head)
	var hair := _make_mesh(SphereMesh.new(), Vector3(0, 1.78, -0.06), Vector3(0.46, 0.34, 0.46), Color(0.88, 0.87, 0.78))
	player_art.add_child(hair)
	var sash := _make_mesh(CylinderMesh.new(), Vector3(0, 0.91, 0), Vector3(0.76, 0.13, 0.62), Color(0.78, 0.58, 0.24))
	player_art.add_child(sash)
	player_left_arm = _make_mesh(CapsuleMesh.new(), Vector3(-0.42, 0.94, 0), Vector3(0.18, 0.64, 0.18), Color(0.58, 0.31, 0.19))
	player_art.add_child(player_left_arm)
	player_right_arm = _make_mesh(CapsuleMesh.new(), Vector3(0.42, 0.94, 0), Vector3(0.18, 0.64, 0.18), Color(0.58, 0.31, 0.19))
	player_art.add_child(player_right_arm)
	for side in [-1.0, 1.0]:
		var leg := _make_mesh(CapsuleMesh.new(), Vector3(side * 0.18, 0.25, 0), Vector3(0.2, 0.55, 0.2), Color(0.22, 0.24, 0.25))
		player_art.add_child(leg)

func _build_simorgh() -> void:
	simorgh_root = Node3D.new()
	simorgh_root.name = "Simorgh"
	simorgh_root.position = Vector3(0, 7.4, -28.0)
	add_child(simorgh_root)
	var body := _make_mesh(SphereMesh.new(), Vector3.ZERO, Vector3(1.3, 0.62, 0.7), Color(0.74, 0.56, 0.28))
	simorgh_root.add_child(body)
	var head := _make_mesh(SphereMesh.new(), Vector3(0, 0.25, -0.85), Vector3(0.44, 0.42, 0.44), Color(0.88, 0.78, 0.55))
	simorgh_root.add_child(head)
	var crest_mesh := CylinderMesh.new()
	crest_mesh.top_radius = 0.0
	crest_mesh.bottom_radius = 0.22
	crest_mesh.height = 0.75
	var crest := _make_mesh(crest_mesh, Vector3(0, 0.65, -0.86), Vector3.ONE, Color(0.72, 0.22, 0.15))
	simorgh_root.add_child(crest)
	for side in [-1.0, 1.0]:
		var wing := _make_mesh(SphereMesh.new(), Vector3(side * 1.05, 0.05, 0.12), Vector3(1.5, 0.16, 0.55), Color(0.55, 0.25, 0.17))
		wing.rotation.z = side * -0.18
		simorgh_root.add_child(wing)
		simorgh_wings.append(wing)
		for feather in range(4):
			var plume := _make_mesh(CapsuleMesh.new(), Vector3(side * (1.15 + float(feather) * 0.25), -0.1, 0.42 + float(feather) * 0.13), Vector3(0.12, 0.78, 0.12), Color(0.84, 0.67, 0.38))
			plume.rotation.z = side * -0.9
			simorgh_root.add_child(plume)
	var tail := _make_mesh(CapsuleMesh.new(), Vector3(0, -0.12, 0.95), Vector3(0.22, 1.25, 0.22), Color(0.68, 0.32, 0.18))
	tail.rotation.x = -1.1
	simorgh_root.add_child(tail)

func _make_mesh(mesh: Mesh, at: Vector3, mesh_scale: Vector3, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.scale = mesh_scale
	instance.material_override = _material(tint, 0.82)
	return instance

func _material(tint: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	return mat

func _spawn_clues() -> void:
	for clue_data in CLUES:
		var marker := Node3D.new()
		marker.name = str(clue_data.id)
		marker.position = clue_data.position
		marker.set_meta("clue_id", clue_data.id)
		marker.set_meta("clue_title", clue_data.title)
		marker.set_meta("clue_hint", clue_data.hint)
		add_child(marker)
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.25
		ring_mesh.outer_radius = 0.34
		ring.mesh = ring_mesh
		ring.rotation.x = 1.1
		ring.material_override = _material(Color(0.95, 0.7, 0.28), 0.35)
		marker.add_child(ring)
		var glow := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.13
		sphere.height = 0.26
		glow.mesh = sphere
		glow.position.y = 0.25
		glow.material_override = _material(Color(1.0, 0.84, 0.48), 0.3)
		marker.add_child(glow)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.68, 0.28)
		light.light_energy = 0.85
		light.omni_range = 3.5
		marker.add_child(light)
		clue_nodes.append(marker)

func _interact_nearest() -> void:
	if mission_complete:
		hud.show_message("این بخش از ماجراجویی را کامل کرده‌ای. روایت زال و سیمرغ را در دانشنامه بخوان.")
		return
	var nearest: Node3D
	var nearest_distance := 3.2
	for marker in clue_nodes:
		if not is_instance_valid(marker) or found_clues.has(str(marker.get_meta("clue_id"))):
			continue
		var distance := player.global_position.distance_to(marker.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = marker
	if nearest == null:
		hud.show_message("به یکی از نشانه‌های زرین نزدیک شو و دکمه تعامل را بزن.")
		return
	var clue_id := str(nearest.get_meta("clue_id"))
	hud.show_message(str(nearest.get_meta("clue_hint")))
	found_clues.append(clue_id)
	nearest.queue_free()
	hud.set_progress(found_clues.size(), clues_required)
	hud.set_mission("ردّ آشیانه", "نشانه‌های پیدا شده: %d از %d" % [found_clues.size(), clues_required])
	if found_clues.size() == clues_required:
		_complete_mission()

func _complete_mission() -> void:
	mission_complete = true
	hud.set_mission("نشانه‌ها پیدا شدند", "اکنون روایت را در دانشنامه بخوان.")
	hud.show_message("هر سه نشانه را پیدا کردی. در روایت شاهنامه، سیمرغ زال را در البرز می‌یابد و پرورش می‌دهد؛ این داستان حماسی و اسطوره‌ای است.")
	hud.show_knowledge()
