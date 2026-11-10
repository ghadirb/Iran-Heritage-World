extends Node3D
class_name WorldController

@onready var player: CharacterBody3D = $Player
@onready var hud: CanvasLayer = $HUD

var found_clues: Array[String] = []
var clues_required := 3
var mission_complete := false
var clue_nodes: Array[Node3D] = []

const CLUES := [
	{"id":"white_feather","title":"پر سپید","position":Vector3(-5.0, 0.6, -7.0),"hint":"ردی از پرهای سپید در کنار صخره پیدا کردی."},
	{"id":"old_nest","title":"شاخه‌های آشیانه","position":Vector3(5.5, 0.6, -11.0),"hint":"شاخه‌های بزرگ، از نزدیکی یک آشیانه خبر می‌دهند."},
	{"id":"mountain_mark","title":"نشان کوهستان","position":Vector3(1.0, 0.6, -19.0),"hint":"نقش کهنی روی سنگ دیده می‌شود؛ راه به سوی بلندی ادامه دارد."}
]

func _ready() -> void:
	_register_actions()
	_build_landscape()
	_spawn_clues()
	hud.set_mission("ردّ آشیانه", "سه نشانه را در کوهستان پیدا کن.")
	hud.show_message("به دامنه البرز خوش آمدی. اطراف را بگرد و نشانه‌ها را پیدا کن.")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		_interact_nearest()

func _register_actions() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	InputMap.action_add_event("interact", event)

func _build_landscape() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.66, 0.76)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	_add_box("ValleyFloor", Vector3(0, -0.6, -8), Vector3(42, 1, 54), Color(0.28, 0.34, 0.25), true)
	_add_box("Trail", Vector3(0, -0.04, -10), Vector3(3.2, 0.12, 29), Color(0.48, 0.39, 0.27), false)

	for i in range(9):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (8.0 + float(i % 3) * 2.0)
		var z := -float(i) * 3.6 - 1.0
		_add_rock(Vector3(x, 1.2 + float(i % 2), z), Vector3(3.8, 3.0 + float(i % 3), 3.2), Color(0.39, 0.43, 0.42))

	for i in range(18):
		var x := float((i * 7) % 29) - 14.0
		var z := -float((i * 11) % 42) - 1.0
		if absf(x) > 4.0:
			_add_tree(Vector3(x, 0, z))

	_add_rock(Vector3(0, 5.0, -25.0), Vector3(10.0, 8.0, 5.0), Color(0.48, 0.49, 0.46))
	_add_rock(Vector3(-13, 3.5, -21), Vector3(7.0, 6.0, 8.0), Color(0.34, 0.39, 0.38))
	_add_rock(Vector3(13, 4.0, -27), Vector3(8.0, 7.0, 7.0), Color(0.42, 0.44, 0.41))

func _add_box(label: String, at: Vector3, dimensions: Vector3, tint: Color, solid: bool) -> void:
	var parent: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.name = label
	parent.position = at
	add_child(parent)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(tint)
	parent.add_child(mesh_node)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		parent.add_child(collision)

func _add_rock(at: Vector3, dimensions: Vector3, tint: Color) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 5
	rock.mesh = mesh
	rock.position = at
	rock.scale = dimensions * 0.5
	rock.material_override = _material(tint)
	add_child(rock)

func _add_tree(at: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1.7
	trunk.mesh = trunk_mesh
	trunk.position = at + Vector3(0, 0.85, 0)
	trunk.material_override = _material(Color(0.30, 0.22, 0.15))
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 0.9
	crown_mesh.height = 1.8
	crown.mesh = crown_mesh
	crown.position = at + Vector3(0, 2.0, 0)
	crown.scale = Vector3(0.85, 1.25, 0.85)
	crown.material_override = _material(Color(0.22, 0.34, 0.24))
	add_child(crown)

func _material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.92
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
		var glow := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.32
		mesh.height = 0.64
		glow.mesh = mesh
		glow.material_override = _material(Color(0.93, 0.78, 0.43))
		marker.add_child(glow)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.76, 0.38)
		light.light_energy = 0.65
		light.omni_range = 3.0
		marker.add_child(light)
		clue_nodes.append(marker)

func _interact_nearest() -> void:
	if mission_complete:
		hud.show_message("این بخش از ماجراجویی را کامل کرده‌ای. به آشیانه نگاه کن و روایت را بخوان.")
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
		hud.show_message("چیزی برای تعامل در نزدیکی تو نیست. به نشانه‌های نورانی نزدیک‌تر شو.")
		return
	var clue_id := str(nearest.get_meta("clue_id"))
	var clue_hint := str(nearest.get_meta("clue_hint"))
	found_clues.append(clue_id)
	nearest.queue_free()
	hud.show_message(clue_hint)
	hud.set_mission("ردّ آشیانه", "نشانه‌های پیدا شده: %d از %d" % [found_clues.size(), clues_required])
	if found_clues.size() == clues_required:
		_complete_mission()

func _complete_mission() -> void:
	mission_complete = true
	hud.set_mission("نشانه‌ها پیدا شدند", "ماجرای زال و سیمرغ را در دانشنامه بخوان.")
	hud.show_message("هر سه نشانه را پیدا کردی. در روایت شاهنامه، سیمرغ زال را در البرز می‌یابد و پرورش می‌دهد. این روایت حماسی و اسطوره‌ای است، نه گزارش تاریخی.")
	hud.show_knowledge()
