class_name TerrainBuilder
extends RefCounted
## Procedural valley: height function, coloured terrain mesh, river strip and
## batched (MultiMesh) vegetation. Everything is generated at runtime so the
## repository stays light and the look can be tuned from LevelData.

var cfg: Dictionary
var noise_a := FastNoiseLite.new()
var noise_b := FastNoiseLite.new()
var noise_c := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

var x_min := -80.0
var x_max := 80.0
var z_max := 30.0
var z_min := -150.0

var c_grass: Color
var c_grass2: Color
var c_rock: Color
var c_path: Color
var c_snow: Color

func _init(config: Dictionary) -> void:
	cfg = config
	var seed_value := int(cfg.get("seed", 1))
	rng.seed = seed_value
	noise_a.seed = seed_value
	noise_a.frequency = 0.028
	noise_a.fractal_octaves = 3
	noise_b.seed = seed_value + 7
	noise_b.frequency = 0.09
	noise_c.seed = seed_value + 19
	noise_c.frequency = 0.05
	z_min = -float(cfg.get("length", 90.0)) - 45.0
	c_grass = Color(str(cfg.get("grass", "#5f8f45")))
	c_grass2 = Color(str(cfg.get("grass2", "#8aa04a")))
	c_rock = Color(str(cfg.get("rock", "#7d7868")))
	c_path = Color(str(cfg.get("path", "#a98557")))
	c_snow = Color(str(cfg.get("snow", "#ffffff")))

# ---------- height field ----------

func path_x(z: float) -> float:
	return sin(z * 0.07) * float(cfg.get("path_sway", 2.0)) + cos(z * 0.031 + 1.3) * float(cfg.get("path_sway", 2.0)) * 0.6

func base_height(z: float) -> float:
	var h := 0.0
	var slope := float(cfg.get("slope", 0.0))
	if slope != 0.0:
		h += minf(-z, float(cfg.get("slope_max", 80.0))) * slope if z < 0.0 else 0.0
	if cfg.has("step"):
		var st: Dictionary = cfg["step"]
		var sz := float(st["z"])
		var blend := float(st.get("blend", 4.0))
		h += float(st["height"]) * (1.0 - smoothstep(sz - blend, sz + blend, z))
	return h

func river_x(z: float) -> float:
	return path_x(z) + float((cfg.get("river", {}) as Dictionary).get("offset", 0.0))

func height(x: float, z: float) -> float:
	var px := path_x(z)
	var d := absf(x - px)
	var amp := float(cfg.get("amp", 2.0))
	var hills := noise_a.get_noise_2d(x, z) * amp + noise_b.get_noise_2d(x, z) * amp * 0.28
	var side := maxf(0.0, d - float(cfg.get("valley_half", 12.0)))
	var ridge := 1.0 + noise_c.get_noise_2d(x * 1.3, z * 1.3) * 0.55
	var mount := pow(side, 1.42) * float(cfg.get("mount_rise", 0.15)) * ridge
	var path_mask := smoothstep(3.5, 9.5, d)
	if cfg.has("nest"):
		# keep the summit around the nest flat and walkable
		var nz: Vector2 = cfg["nest"]
		var nd := Vector2(x - nz.x, z - nz.y).length()
		path_mask = minf(path_mask, smoothstep(14.0, 24.0, nd))
		mount *= smoothstep(14.0, 30.0, nd)
	if bool(cfg.get("hall", false)):
		path_mask = smoothstep(26.0, 34.0, d)
		hills *= 0.1
	var h := base_height(z) + lerpf(hills * 0.12, hills + mount, path_mask)
	if cfg.has("river"):
		var rw := float((cfg["river"] as Dictionary).get("width", 1.5))
		var dr := absf(x - river_x(z))
		var carve := 1.0 - smoothstep(rw, rw + 3.0, dr)
		h = lerpf(h, base_height(z) - 0.75, carve)
	if cfg.has("chasm"):
		var ch: Dictionary = cfg["chasm"]
		var z0 := float(ch["z0"])
		var z1 := float(ch["z1"])
		var ew := float(ch.get("edge", 2.0))
		# sharp, grid-aligned lips: solid ground right up to z0 and from z1 on,
		# so the player never slides off a long slope before the first jump
		var inside := smoothstep(z0, z0 - ew, z) * smoothstep(z1 - ew, z1, z)
		h -= float(ch["depth"]) * inside
	return h

func normal_at(x: float, z: float) -> Vector3:
	var e := 0.6
	return Vector3(height(x - e, z) - height(x + e, z), 2.0 * e, height(x, z - e) - height(x, z + e)).normalized()

# ---------- terrain mesh ----------

func build_terrain(step: float = 2.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := int((x_max - x_min) / step) + 1
	var rows := int((z_max - z_min) / step) + 1
	for r in range(rows):
		for c in range(cols):
			var x := x_min + float(c) * step
			var z := z_max - float(r) * step
			var h := height(x, z)
			var n := normal_at(x, z)
			st.set_color(_color_at(x, z, h, n))
			st.set_normal(n)
			st.add_vertex(Vector3(x, h, z))
	for r in range(rows - 1):
		for c in range(cols - 1):
			var i := r * cols + c
			st.add_index(i)
			st.add_index(i + cols)
			st.add_index(i + 1)
			st.add_index(i + 1)
			st.add_index(i + cols)
			st.add_index(i + cols + 1)
	return st.commit()

func _color_at(x: float, z: float, h: float, n: Vector3) -> Color:
	var d := absf(x - path_x(z))
	var mix_n := clampf(noise_c.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5, 0.0, 1.0)
	var col := c_grass.lerp(c_grass2, mix_n)
	var slope := 1.0 - n.y
	col = col.lerp(c_rock, smoothstep(0.16, 0.38, slope))
	var snow_line := float(cfg.get("snow_line", 25.0))
	var snow_amount := smoothstep(snow_line, snow_line + 6.0, h + noise_b.get_noise_2d(x, z) * 3.0) * (1.0 - smoothstep(0.35, 0.6, slope))
	col = col.lerp(c_snow, snow_amount)
	var on_path := 1.0 - smoothstep(1.8, 3.6, d + noise_b.get_noise_2d(x * 3.0, z * 3.0) * 0.8)
	if bool(cfg.get("hall", false)):
		on_path = 1.0 - smoothstep(24.0, 26.0, d)
	col = col.lerp(c_path, on_path * 0.9)
	if cfg.has("river"):
		var rw := float((cfg["river"] as Dictionary).get("width", 1.5))
		var dr := absf(x - river_x(z))
		col = col.lerp(Color("#8d7d62"), 1.0 - smoothstep(rw, rw + 2.0, dr))
	return col

func terrain_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("detail", 1.0 if GameState.quality >= 1 else 0.0)
	return mat

# ---------- water ----------

func build_river() -> MeshInstance3D:
	if not cfg.has("river"):
		return null
	var rw := float((cfg["river"] as Dictionary).get("width", 1.5)) + 0.9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := z_max - 4.0
	var rows := 0
	while z > z_min + 6.0:
		var cx := river_x(z)
		var y := base_height(z) - 0.38
		for side in [0, 1]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(float(side), float(rows)))
			st.add_vertex(Vector3(cx + (-rw if side == 0 else rw), y, z))
		rows += 1
		z -= 2.0
	for r in range(rows - 1):
		var i := r * 2
		st.add_index(i); st.add_index(i + 1); st.add_index(i + 2)
		st.add_index(i + 1); st.add_index(i + 3); st.add_index(i + 2)
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst

# ---------- procedural prop meshes (flat shaded, vertex coloured) ----------

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, sway: Array = [0.0, 0.0, 0.0]) -> void:
	for pair in [[a, ca, sway[0]], [b, cb, sway[1]], [c, cc, sway[2]]]:
		var col: Color = pair[1]
		col.a = float(pair[2])
		st.set_color(col)
		st.add_vertex(pair[0])

func _cone(st: SurfaceTool, base_y: float, radius: float, height_value: float, segs: int, c_bottom: Color, c_top: Color, wobble: float = 0.0) -> void:
	var tip := Vector3(0, base_y + height_value, 0)
	for i in range(segs):
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var r0 := radius * (1.0 + rng.randf_range(-wobble, wobble))
		var r1 := radius * (1.0 + rng.randf_range(-wobble, wobble))
		var p0 := Vector3(cos(a0) * r0, base_y, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, base_y, sin(a1) * r1)
		_tri(st, p0, tip, p1, c_bottom, c_top, c_bottom)

func make_pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_dark := Color("#4a3322")
	var trunk_light := Color("#5d4128")
	for i in range(6):
		var a0 := TAU * float(i) / 6.0
		var a1 := TAU * float(i + 1) / 6.0
		var b0 := Vector3(cos(a0) * 0.2, 0.0, sin(a0) * 0.2)
		var b1 := Vector3(cos(a1) * 0.2, 0.0, sin(a1) * 0.2)
		var t0 := Vector3(cos(a0) * 0.12, 2.0, sin(a0) * 0.12)
		var t1 := Vector3(cos(a1) * 0.12, 2.0, sin(a1) * 0.12)
		_tri(st, b0, t0, b1, trunk_dark, trunk_light, trunk_dark)
		_tri(st, b1, t0, t1, trunk_dark, trunk_light, trunk_light)
	var tiers := 5
	for t in range(tiers):
		var f := float(t) / float(tiers - 1)
		var radius := lerpf(1.45, 0.55, f)
		var base := 1.3 + float(t) * 0.95
		var dark := Color("#1f4a2b").lerp(Color("#2d6a38"), f)
		var light := Color("#3c8445").lerp(Color("#66a752"), f)
		_cone(st, base, radius, 1.9 - f * 0.3, 8, dark, light, 0.1)
	st.generate_normals()
	return st.commit()

func make_rock_mesh(seed_offset: int) -> ArrayMesh:
	var local := RandomNumberGenerator.new()
	local.seed = int(cfg.get("seed", 1)) * 31 + seed_offset
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 8
	var rings := 5
	var verts: Array = []
	for r in range(rings + 1):
		var row: Array = []
		var phi := PI * float(r) / float(rings)
		for s in range(segs):
			var theta := TAU * float(s) / float(segs)
			var rad := 1.0 + local.randf_range(-0.22, 0.22)
			if r == 0 or r == rings:
				rad = 1.0
			row.append(Vector3(sin(phi) * cos(theta), cos(phi) * 0.8, sin(phi) * sin(theta)) * rad)
		verts.append(row)
	var base := Color("#ffffff")
	for r in range(rings):
		for s in range(segs):
			var s2 := (s + 1) % segs
			var a: Vector3 = verts[r][s]
			var b: Vector3 = verts[r][s2]
			var c: Vector3 = verts[r + 1][s]
			var d: Vector3 = verts[r + 1][s2]
			var shade1 := base.darkened(local.randf_range(0.0, 0.18))
			var shade2 := base.darkened(local.randf_range(0.0, 0.18))
			_tri(st, a, c, b, shade1, shade1, shade1)
			_tri(st, b, c, d, shade2, shade2, shade2)
	st.generate_normals()
	return st.commit()

func make_grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_c := Color("#3d6a2a")
	var tip_c := Color("#9ccc5a")
	for i in range(7):
		var ang := TAU * float(i) / 7.0 + rng.randf() * 0.5
		var off := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.0, 0.22)
		var dir := Vector3(-sin(ang), 0, cos(ang))
		var tall := rng.randf_range(0.5, 0.95)
		var lean := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.05, 0.25)
		_tri(st, off - dir * 0.045, off + lean + Vector3(0, tall, 0), off + dir * 0.045, base_c, tip_c, base_c, [0.0, 1.0, 0.0])
	st.generate_normals()
	return st.commit()

func make_flower_mesh(petal: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := Color("#4a7a34")
	_tri(st, Vector3(-0.015, 0, 0), Vector3(0, 0.42, 0), Vector3(0.015, 0, 0), stem, stem, stem, [0.0, 1.0, 0.0])
	for i in range(5):
		var a0 := TAU * float(i) / 5.0
		var a1 := TAU * float(i + 1) / 5.0
		var c := Vector3(0, 0.44, 0)
		_tri(st, c, c + Vector3(cos(a0) * 0.1, 0.03, sin(a0) * 0.1), c + Vector3(cos(a1) * 0.1, 0.03, sin(a1) * 0.1), Color("#ffe27a"), petal, petal, [1.0, 1.0, 1.0])
	st.generate_normals()
	return st.commit()

func foliage_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/foliage.gdshader")
	return mat

func solid_vertex_material(roughness: float = 0.95) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	return mat

# ---------- scatter ----------

func scatter_points(count: int, min_path_dist: float, max_spread: float, avoid_river: bool = true) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var attempts := 0
	while pts.size() < count and attempts < count * 12:
		attempts += 1
		var z := rng.randf_range(z_min + 8.0, z_max - 6.0)
		var x := path_x(z) + rng.randf_range(-max_spread, max_spread)
		if absf(x - path_x(z)) < min_path_dist:
			continue
		if avoid_river and cfg.has("river"):
			var rw := float((cfg["river"] as Dictionary).get("width", 1.5)) + 2.5
			if absf(x - river_x(z)) < rw:
				continue
		var h := height(x, z)
		if h < -3.0 and cfg.has("chasm"):
			continue
		var n := normal_at(x, z)
		if n.y < 0.72:
			continue
		pts.append(Vector3(x, h, z))
	return pts

func build_multimesh(mesh: Mesh, material: Material, points: Array[Vector3], scale_min: float, scale_max: float, tint_variation: bool = false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in range(points.size()):
		var s := rng.randf_range(scale_min, scale_max)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
		mm.set_instance_transform(i, Transform3D(basis, points[i] - Vector3(0, 0.03, 0)))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = material
	return inst
