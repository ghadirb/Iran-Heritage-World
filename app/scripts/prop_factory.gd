class_name PropFactory
extends RefCounted
## Stylised characters and set pieces built from primitives. Placeholder art:
## licensed final models can replace these without changing gameplay code.

static func mat(color: Color, rough: float = 0.85, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

static func part(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scl
	return mi

static func sphere(r: float = 0.5, segs: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s

static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c

static func cylinder(rt: float, rb: float, h: float, segs: int = 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	return c

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

# ---------- Zal (player) ----------

static func make_zal() -> Node3D:
	var root := Node3D.new()
	root.name = "Zal"
	var skin := mat(Color("#c99468"), 0.7)
	var tunic := mat(Color("#8c3b24"), 0.9)
	var trim := mat(Color("#d6a447"), 0.4, 0.3)
	var cloak := mat(Color("#2f5d63"), 0.95)
	var boots := mat(Color("#3a2a20"), 0.9)
	var hair := mat(Color("#f2efe4"), 0.8)
	var body := part(capsule(0.34, 1.0), tunic, Vector3(0, 1.0, 0), Vector3(1.0, 1.0, 0.8))
	root.add_child(body)
	root.add_child(part(cylinder(0.37, 0.37, 0.12, 16), trim, Vector3(0, 0.88, 0), Vector3(1, 1, 0.82)))
	# cloak behind (+Z is front of the model, so cloak sits at -Z)
	var cloak_node := part(box(Vector3(0.68, 0.95, 0.06)), cloak, Vector3(0, 1.05, -0.3))
	cloak_node.rotation.x = 0.12
	root.add_child(cloak_node)
	root.add_child(part(sphere(0.23), skin, Vector3(0, 1.72, 0.0)))
	root.add_child(part(sphere(0.255, 16), hair, Vector3(0, 1.83, -0.04), Vector3(1, 0.7, 1.0)))
	root.add_child(part(capsule(0.12, 0.55), hair, Vector3(0, 1.58, -0.2)))
	for s in [-1.0, 1.0]:
		root.add_child(part(sphere(0.035, 8), mat(Color("#1d1a16")), Vector3(s * 0.085, 1.74, 0.2)))
	var arms: Array = []
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(s * 0.44, 1.38, 0)
		pivot.name = "ArmL" if s < 0 else "ArmR"
		pivot.add_child(part(capsule(0.09, 0.62), tunic, Vector3(0, -0.28, 0)))
		pivot.add_child(part(sphere(0.09, 10), skin, Vector3(0, -0.62, 0)))
		root.add_child(pivot)
		arms.append(pivot)
	var legs: Array = []
	for s in [-1.0, 1.0]:
		var pivot2 := Node3D.new()
		pivot2.position = Vector3(s * 0.17, 0.62, 0)
		pivot2.add_child(part(capsule(0.1, 0.62), mat(Color("#3b3f45"), 0.9), Vector3(0, -0.22, 0)))
		pivot2.add_child(part(box(Vector3(0.2, 0.18, 0.34)), boots, Vector3(0, -0.56, 0.06)))
		root.add_child(pivot2)
		legs.append(pivot2)
	root.set_meta("arms", arms)
	root.set_meta("legs", legs)
	return root

static func animate_zal(zal: Node3D, moving: bool, t: float) -> void:
	var swing := sin(t * 10.0) * 0.7 if moving else 0.0
	var arms: Array = zal.get_meta("arms")
	var legs: Array = zal.get_meta("legs")
	(arms[0] as Node3D).rotation.x = swing * 0.8
	(arms[1] as Node3D).rotation.x = -swing * 0.8
	(legs[0] as Node3D).rotation.x = -swing
	(legs[1] as Node3D).rotation.x = swing
	zal.position.y = absf(sin(t * 10.0)) * 0.05 if moving else 0.0

# ---------- Simorgh ----------

static func make_simorgh() -> Node3D:
	var root := Node3D.new()
	root.name = "Simorgh"
	var gold := mat(Color("#e0a63a"), 0.35, 0.25, 0.25)
	var teal := mat(Color("#1f8a8a"), 0.45, 0.1, 0.2)
	var crimson := mat(Color("#c4362a"), 0.5, 0.0, 0.25)
	var cream := mat(Color("#f3e3b6"), 0.6, 0.0, 0.15)
	root.add_child(part(sphere(0.9, 20), gold, Vector3(0, 0, 0), Vector3(1.0, 0.8, 1.5)))
	root.add_child(part(sphere(0.6, 16), cream, Vector3(0, -0.08, -0.35), Vector3(0.95, 0.8, 1.0)))
	var neck := part(capsule(0.22, 1.3), gold, Vector3(0, 0.85, -1.15))
	neck.rotation.x = -0.45
	root.add_child(neck)
	root.add_child(part(sphere(0.34, 16), cream, Vector3(0, 1.45, -1.75), Vector3(1, 0.95, 1.2)))
	var beak := part(cylinder(0.0, 0.13, 0.5, 8), crimson, Vector3(0, 1.4, -2.2))
	beak.rotation.x = -PI / 2.0
	root.add_child(beak)
	for s in [-1.0, 1.0]:
		root.add_child(part(sphere(0.06, 8), mat(Color("#101010")), Vector3(s * 0.17, 1.52, -1.95)))
	for i in range(5):
		var crest := part(cylinder(0.0, 0.05, 0.5 + float(i) * 0.08, 6), crimson if i % 2 == 0 else teal, Vector3(0, 1.78, -1.55 + float(i) * 0.1))
		crest.rotation.x = 0.5 + float(i) * 0.14
		root.add_child(crest)
	# wings: root pivot + fanned feathers
	var wing_roots: Array = []
	for s in [-1.0, 1.0]:
		var wr := Node3D.new()
		wr.position = Vector3(s * 0.7, 0.2, -0.2)
		wr.name = "WingL" if s < 0 else "WingR"
		for f in range(9):
			var fl := float(f) / 8.0
			var length := 3.4 - absf(fl - 0.35) * 1.2
			var feather := part(capsule(0.12, length), [teal, gold, crimson][f % 3], Vector3(s * (length * 0.5 + 0.2), 0.0, -0.5 + fl * 1.5), Vector3(1.0, 1.0, 0.35))
			feather.rotation.z = s * (PI / 2.0 + 0.15 - fl * 0.35)
			feather.rotation.y = s * (0.35 - fl * 0.5)
			wr.add_child(feather)
		root.add_child(wr)
		wing_roots.append(wr)
	# tail
	for i in range(9):
		var fl2 := float(i) / 8.0 - 0.5
		var tail := part(capsule(0.1, 3.2), [teal, gold, crimson][i % 3], Vector3(fl2 * 1.7, 0.05 - absf(fl2) * 0.3, 2.6), Vector3(1.0, 1.0, 0.3))
		tail.rotation.x = PI / 2.0 + 0.1
		tail.rotation.z = -fl2 * 0.9
		root.add_child(tail)
	root.set_meta("wings", wing_roots)
	var aura := OmniLight3D.new()
	aura.light_color = Color("#ffd38a")
	aura.light_energy = 0.8
	aura.omni_range = 14.0
	root.add_child(aura)
	return root

static func animate_simorgh(simorgh: Node3D, t: float) -> void:
	var wings: Array = simorgh.get_meta("wings")
	var flap := sin(t * 1.6) * 0.18
	(wings[0] as Node3D).rotation.z = -flap
	(wings[1] as Node3D).rotation.z = flap

# ---------- humans / NPC ----------

static func make_figure(robe: Color, hair_col: Color, turban: bool) -> Node3D:
	var root := Node3D.new()
	var skin := mat(Color("#c28e62"), 0.7)
	root.add_child(part(capsule(0.38, 1.5), mat(robe, 0.9), Vector3(0, 0.85, 0)))
	root.add_child(part(cylinder(0.4, 0.4, 0.12), mat(Color("#d6a447"), 0.4, 0.3), Vector3(0, 0.95, 0)))
	root.add_child(part(sphere(0.25), skin, Vector3(0, 1.85, 0)))
	if turban:
		root.add_child(part(sphere(0.3), mat(Color("#f0e8d6"), 0.8), Vector3(0, 2.0, 0), Vector3(1.0, 0.75, 1.0)))
	else:
		root.add_child(part(sphere(0.27), mat(hair_col, 0.8), Vector3(0, 1.97, -0.03), Vector3(1.0, 0.7, 1.0)))
	root.add_child(part(capsule(0.19, 0.5), mat(hair_col, 0.8), Vector3(0, 1.62, 0.18), Vector3(1.1, 0.9, 0.8)))
	return root

static func make_stone_tablet() -> Node3D:
	var root := Node3D.new()
	var stone := mat(Color("#9a8f7c"), 1.0)
	root.add_child(part(box(Vector3(1.6, 2.3, 0.4)), stone, Vector3(0, 1.15, 0)))
	root.add_child(part(box(Vector3(1.9, 0.25, 0.7)), stone, Vector3(0, 0.12, 0)))
	var glyph := mat(Color("#f0b040"), 0.4, 0.2, 1.4)
	for i in range(4):
		root.add_child(part(box(Vector3(1.0 - float(i) * 0.12, 0.07, 0.04)), glyph, Vector3(0, 1.75 - float(i) * 0.3, 0.22)))
	return root

static func make_pedestal(book_color: Color = Color("#f0b040")) -> Node3D:
	var root := Node3D.new()
	var stone := mat(Color("#b8ab92"), 0.9)
	root.add_child(part(cylinder(0.7, 0.85, 0.3), stone, Vector3(0, 0.15, 0)))
	root.add_child(part(cylinder(0.45, 0.55, 1.0), stone, Vector3(0, 0.8, 0)))
	root.add_child(part(cylinder(0.75, 0.6, 0.18), stone, Vector3(0, 1.38, 0)))
	var tome := part(box(Vector3(0.7, 0.12, 0.5)), mat(book_color, 0.4, 0.2, 1.2), Vector3(0, 1.55, 0))
	tome.rotation.x = -0.25
	root.add_child(tome)
	return root

static func make_brazier(color: Color) -> Node3D:
	var root := Node3D.new()
	var stone := mat(Color("#5b5348"), 0.8)
	root.add_child(part(cylinder(0.45, 0.65, 0.35), stone, Vector3(0, 0.18, 0)))
	root.add_child(part(cylinder(0.2, 0.28, 1.0), stone, Vector3(0, 0.8, 0)))
	root.add_child(part(cylinder(0.6, 0.28, 0.35), stone, Vector3(0, 1.45, 0)))
	var gem := part(sphere(0.2, 10), mat(color, 0.2, 0.0, 2.2), Vector3(0, 1.8, 0), Vector3(1, 1.3, 1))
	gem.name = "Gem"
	root.add_child(gem)
	return root

static func make_flame(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Flame"
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.38, 0.38)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.vertex_color_use_as_albedo = true
	fm.albedo_color = color
	p.mesh = qm
	p.material_override = fm
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = Vector3(0, 1.75, 0)
	root.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.6
	light.omni_range = 9.0
	light.position = Vector3(0, 2.3, 0)
	root.add_child(light)
	return root

# ---------- collectibles ----------

## Archery target: concentric rings facing local +Z (use look_at(..., true) to turn it toward the shooter) on a pole.
static func make_target(radius: float, pole_h: float) -> Node3D:
	var root := Node3D.new()
	var colors := [Color("#f4efe4"), Color("#c0392b"), Color("#f4efe4"), Color("#c0392b")]
	for i in range(4):
		var r := radius * (1.0 - float(i) * 0.22)
		var ring := part(cylinder(r, r, 0.1), mat(colors[i], 0.7), Vector3(0, 0, 0.03 * float(i)))
		ring.rotation.x = PI * 0.5
		ring.name = "Ring%d" % i
		root.add_child(ring)
	root.add_child(part(cylinder(0.08, 0.1, pole_h), mat(Color("#6b4a2b"), 0.95), Vector3(0, -pole_h * 0.5, -0.12)))
	return root

## Arrow: the tip is at the origin and points to local -Z (so look_at(position + velocity) aims it).
static func make_arrow() -> Node3D:
	var root := Node3D.new()
	var shaft := part(cylinder(0.025, 0.025, 1.1), mat(Color("#b58b52"), 0.8), Vector3(0, 0, 0.55))
	shaft.rotation.x = PI * 0.5
	root.add_child(shaft)
	var tip := part(cylinder(0.0, 0.07, 0.22), mat(Color("#8c8f96"), 0.4, 0.6), Vector3(0, 0, -0.05))
	tip.rotation.x = -PI * 0.5
	root.add_child(tip)
	for k in range(2):
		var fin := part(box(Vector3(0.01, 0.16, 0.2)), mat(Color("#f4efe4"), 0.9), Vector3(0, 0, 1.0))
		fin.rotation.z = float(k) * PI * 0.5
		root.add_child(fin)
	return root

## Small bow carried by the player in archery chapters (attach to the character art).
static func make_bow() -> Node3D:
	var root := Node3D.new()
	var wood := mat(Color("#7a4a22"), 0.8)
	root.add_child(part(box(Vector3(0.06, 0.4, 0.06)), wood, Vector3(0, 0, 0)))
	var up := part(box(Vector3(0.05, 0.5, 0.05)), wood, Vector3(0, 0.42, 0.1))
	up.rotation.x = 0.45
	root.add_child(up)
	var low := part(box(Vector3(0.05, 0.5, 0.05)), wood, Vector3(0, -0.42, 0.1))
	low.rotation.x = -0.45
	root.add_child(low)
	root.add_child(part(box(Vector3(0.012, 1.25, 0.012)), mat(Color("#efe6d2"), 0.9), Vector3(0, 0, 0.0)))
	return root

## Non-violent, stylised pressure cue for the chase course. It has no collider.
static func make_mist_chaser() -> Node3D:
	var root := Node3D.new()
	root.name = "MistShadow"
	var mist := mat(Color(0.20, 0.31, 0.43, 0.68), 0.8, 0.0, 1.1)
	for i in range(4):
		var puff := part(sphere(0.7 + float(i) * 0.1, 10), mist, Vector3((float(i) - 1.5) * 0.35, 0.2 + float(i % 2) * 0.35, 0.0), Vector3(1.0, 1.2, 1.0))
		root.add_child(puff)
	var eye_mat := mat(Color("#d9f6ff"), 0.2, 0.0, 2.2)
	for side in [-1.0, 1.0]:
		root.add_child(part(sphere(0.09, 8), eye_mat, Vector3(side * 0.24, 0.65, -0.62)))
	var trail := CPUParticles3D.new()
	trail.amount = 14
	trail.lifetime = 1.3
	trail.direction = Vector3(0, 0.3, 1)
	trail.spread = 35.0
	trail.initial_velocity_min = 0.25
	trail.initial_velocity_max = 0.7
	trail.gravity = Vector3(0, 0.1, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	trail.mesh = quad
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = Color(0.55, 0.75, 0.9, 0.28)
	trail.material_override = pm
	root.add_child(trail)
	return root

## A readable gust: broad enough to see from behind, but intentionally cheap.
static func make_wind_gust() -> Node3D:
	var root := Node3D.new()
	root.name = "WindGust"
	var particles := CPUParticles3D.new()
	particles.amount = 32
	particles.lifetime = 1.2
	particles.preprocess = 1.2
	particles.direction = Vector3(1, 0.18, 0)
	particles.spread = 22.0
	particles.initial_velocity_min = 2.2
	particles.initial_velocity_max = 3.8
	particles.gravity = Vector3(0, 0.15, 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.42, 0.42)
	particles.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.78, 0.94, 1.0, 0.52)
	particles.material_override = material
	root.add_child(particles)
	var core := part(sphere(0.45, 10), mat(Color(0.7, 0.9, 1.0, 0.5), 0.4, 0.0, 1.4), Vector3(0, 0.3, 0), Vector3(1.0, 1.8, 1.0))
	root.add_child(core)
	return root

static func make_clay_ball() -> Node3D:
	var root := Node3D.new()
	root.name = "ClayBallVisual"
	var clay := mat(Color("#a85e3d"), 0.92)
	var band := mat(Color("#d59a55"), 0.75, 0.0, 0.08)
	root.add_child(part(sphere(1.1, 16), clay))
	root.add_child(part(cylinder(1.13, 1.13, 0.12, 16), band, Vector3(0, 0, 0), Vector3(1, 1, 1)))
	return root

## A piece of firewood the player can pick up and carry (see WorldController._pick_log).
static func make_trunk() -> Node3D:
	var root := Node3D.new()
	var bark := mat(Color("#6a4a2c"), 1.0)
	var body := part(cylinder(0.5, 0.5, 2.6, 12), bark)
	body.rotation.z = PI * 0.5
	root.add_child(body)
	for s in [-1.0, 1.0]:
		var cap := part(cylinder(0.46, 0.46, 0.06, 12), mat(Color("#c9a26b"), 0.9), Vector3(s * 1.3, 0, 0))
		cap.rotation.z = PI * 0.5
		root.add_child(cap)
	for k in range(3):
		root.add_child(part(box(Vector3(0.5, 0.08, 0.1)), mat(Color("#4a3320"), 1.0), Vector3(-0.8 + 0.8 * float(k), 0.5, 0.0)))
	return root

static func make_log() -> Node3D:
	var root := Node3D.new()
	var body := part(cylinder(0.22, 0.22, 1.4, 8), mat(Color("#6b4a2b"), 0.95), Vector3(0, 0.25, 0))
	body.rotation.z = PI * 0.5
	root.add_child(body)
	var halo := part(sphere(0.12, 8), mat(Color("#ffb347"), 0.2, 0.2, 2.0), Vector3(0, 0.95, 0))
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	return root

static func make_clue_marker(kind: String) -> Node3D:
	var root := Node3D.new()
	var glow := mat(Color("#ffd36b"), 0.2, 0.2, 2.4)
	if kind == "banner":
		root.add_child(part(cylinder(0.05, 0.06, 3.4), mat(Color("#5b4636"), 0.9), Vector3(0, 1.7, 0)))
		root.add_child(part(box(Vector3(1.2, 0.8, 0.04)), mat(Color("#b3261e"), 0.7, 0.0, 0.3), Vector3(0.62, 3.0, 0)))
		root.add_child(part(sphere(0.14, 10), glow, Vector3(0, 3.5, 0)))
	else:
		var ring := part(TorusMesh.new(), glow, Vector3(0, 0.0, 0))
		(ring.mesh as TorusMesh).inner_radius = 0.28
		(ring.mesh as TorusMesh).outer_radius = 0.4
		ring.name = "Ring"
		root.add_child(ring)
		var orb := part(sphere(0.16, 12), glow, Vector3(0, 0.0, 0))
		orb.name = "Orb"
		root.add_child(orb)
	var beam := part(cylinder(0.11, 0.11, 9.0, 8), beam_material(), Vector3(0, 4.5, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.name = "Beam"   # world_controller hides it from afar on harder difficulties
	root.add_child(beam)
	var spark := CPUParticles3D.new()
	spark.amount = 16
	spark.lifetime = 1.6
	spark.direction = Vector3.UP
	spark.spread = 40.0
	spark.initial_velocity_min = 0.3
	spark.initial_velocity_max = 0.8
	spark.gravity = Vector3.ZERO
	spark.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spark.emission_sphere_radius = 0.5
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_color = Color("#ffe39a")
	spark.mesh = qm
	spark.material_override = sm
	root.add_child(spark)
	return root

static func beam_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.8, 0.35, 0.18)
	return m

static func make_burst(color: Color = Color("#ffd36b")) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 36
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -3.0, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	p.mesh = qm
	p.material_override = m
	return p

# ---------- set dressing ----------

static func make_tent(cloth: Color) -> Node3D:
	var root := Node3D.new()
	var tent := part(cylinder(0.0, 2.6, 2.6, 8), mat(cloth, 0.95), Vector3(0, 1.3, 0))
	root.add_child(tent)
	root.add_child(part(cylinder(0.04, 0.04, 1.2), mat(Color("#5b4636")), Vector3(0, 3.1, 0)))
	root.add_child(part(box(Vector3(0.6, 0.35, 0.03)), mat(Color("#d6a447"), 0.5, 0.2, 0.4), Vector3(0.32, 3.45, 0)))
	return root

static func make_column(height: float = 9.0) -> Node3D:
	var root := Node3D.new()
	var stone := mat(Color("#c4b08c"), 0.9)
	root.add_child(part(box(Vector3(2.0, 0.5, 2.0)), stone, Vector3(0, 0.25, 0)))
	root.add_child(part(cylinder(0.7, 0.8, height, 18), stone, Vector3(0, height * 0.5 + 0.5, 0)))
	root.add_child(part(box(Vector3(1.9, 0.6, 1.9)), mat(Color("#d2bc92"), 0.85), Vector3(0, height + 0.8, 0)))
	return root

static func make_nest() -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wood := mat(Color("#6b4a2d"), 1.0)
	for i in range(70):
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.6, 5.2)
		var branch := part(cylinder(0.07, 0.09, rng.randf_range(2.0, 3.8), 6), wood, Vector3(cos(a) * r, 0.25 + rng.randf() * 0.9, sin(a) * r))
		branch.rotation = Vector3(rng.randf_range(-0.4, 0.4), a + rng.randf_range(-0.7, 0.7), PI / 2.0 + rng.randf_range(-0.3, 0.3))
		root.add_child(branch)
	root.add_child(part(cylinder(3.2, 2.6, 0.6, 20), mat(Color("#8a6a3d"), 1.0), Vector3(0, 0.1, 0)))
	return root
