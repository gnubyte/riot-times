class_name WorldBuilder
extends RefCounted
# Static-geometry batcher. Every box/cylinder is merged into one mesh per
# (material, 64 m chunk, size class) and gets a collision shape on a per-chunk
# StaticBody3D. Thousands of props become a few dozen draw calls.
# Materials are triplanar (no UVs needed) and tinted per box via vertex color.

const CHUNK := 64.0
var root: Node3D
var mats := {}
var batches := {}
var bodies := {}
var lights := 0

# face normal, U, V with N = U x V; corners wound clockwise for Godot front faces
const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)],
]

const MAT_DEFS := {
	"concrete": ["concrete", 0.9, 0.0, 0.22],
	"plaster": ["plaster", 0.92, 0.0, 0.3],
	"brick": ["brick", 0.9, 0.0, 0.35],
	"asphalt": ["asphalt", 0.95, 0.0, 0.12],
	"cobble": ["cobble", 0.9, 0.0, 0.3],
	"tile": ["tile", 0.35, 0.0, 0.35],
	"wood": ["wood", 0.85, 0.0, 0.4],
	"rusty": ["rusty_metal", 0.75, 0.5, 0.35],
	"corrugated": ["corrugated", 0.7, 0.55, 0.35],
	"metal": ["rusty_metal", 0.4, 0.85, 0.5],
	"windows": ["windows", 0.3, 0.4, 0.12],
	"sandbag": ["sandbag", 0.95, 0.0, 0.6],
	"chain": ["chain", 0.6, 0.7, 0.8],
	"dust": ["dust", 0.95, 0.0, 0.12],
	"grass": ["grass", 0.95, 0.0, 0.1],
	"bark": ["bark", 0.95, 0.0, 0.6],
	"leaves": ["leaves", 0.9, 0.0, 0.35],
	"rock": ["rock", 0.9, 0.0, 0.18],
	"rubber": ["", 0.95, 0.0, 1.0],
	"paint": ["", 0.6, 0.2, 1.0],
}

func _init(r: Node3D) -> void:
	root = r

func material(key: String) -> Material:
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if key.begins_with("neon_") or key.begins_with("glow_"):
		var c := _glow_color(key)
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 3.2 if key.begins_with("neon_") else 1.6
		m.roughness = 0.3
		m.vertex_color_use_as_albedo = false
	elif key == "glass":
		m.albedo_color = Color(0.5, 0.65, 0.7, 0.28)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic = 0.3
		m.vertex_color_use_as_albedo = false
	elif key == "water":
		return Shaders.water_material(false)
	else:
		var d: Array = MAT_DEFS.get(key, MAT_DEFS["concrete"])
		if d[0] != "":
			m.albedo_texture = Proc.tex(d[0])
			var nm := Proc.normal_tex(d[0])
			if nm != null:
				m.normal_enabled = true
				m.normal_texture = nm
				m.normal_scale = 1.2
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * float(d[3])
			m.uv1_triplanar_sharpness = 4.0
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		m.roughness = d[1]
		m.metallic = d[2]
		var rt: Texture2D = Proc.rough_tex(d[0]) if d[0] != "" else null
		if rt != null:
			# per-pixel roughness: stains, rust and cracks catch light differently
			m.roughness_texture = rt
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.roughness = clampf(float(d[1]) + 0.1, 0.0, 1.0)
		if key == "windows":
			m.emission_enabled = true
			m.emission_texture = Proc.tex("windows_emit")
			m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			m.emission = Color(1.0, 0.75, 0.45)
			m.emission_energy_multiplier = 0.9
			m.roughness = 1.0
			m.metallic = 0.25
		if key == "chain":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats[key] = m
	return m

func _glow_color(key: String) -> Color:
	match key.trim_prefix("neon_").trim_prefix("glow_"):
		"pink": return Color(1.0, 0.2, 0.7)
		"cyan": return Color(0.2, 0.9, 1.0)
		"purple": return Color(0.6, 0.25, 1.0)
		"yellow": return Color(1.0, 0.85, 0.25)
		"green": return Color(0.3, 1.0, 0.45)
		"red": return Color(1.0, 0.12, 0.1)
		"orange": return Color(1.0, 0.5, 0.15)
		"white": return Color(1.0, 0.97, 0.9)
		"blue": return Color(0.3, 0.45, 1.0)
	return Color(1, 1, 1)

func _batch(key: String, origin: Vector3, small: bool) -> Dictionary:
	var cx := int(floor(origin.x / CHUNK))
	var cz := int(floor(origin.z / CHUNK))
	var bk := "%s|%d|%d|%s" % [key, cx, cz, "s" if small else "b"]
	if not batches.has(bk):
		batches[bk] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "i": PackedInt32Array(), "key": key, "small": small}
	return batches[bk]

func _body(origin: Vector3, layer: int) -> StaticBody3D:
	var cx := int(floor(origin.x / CHUNK))
	var cz := int(floor(origin.z / CHUNK))
	var k := "%d|%d|%d" % [cx, cz, layer]
	if not bodies.has(k):
		var sb := StaticBody3D.new()
		sb.collision_layer = layer
		sb.collision_mask = 0
		sb.add_to_group("navsrc")
		root.add_child(sb)
		bodies[k] = sb
	return bodies[k]

# ---------- primitives ----------
func box(size: Vector3, pos: Vector3, key := "concrete", rot := Vector3.ZERO, collide := true, tint := Color(1, 1, 1), layer := 2) -> void:
	var xf := Transform3D(Basis.from_euler(rot), pos)
	add_box_mesh(size, xf, key, tint)
	if collide:
		add_box_col(size, xf, layer)

func add_box_mesh(size: Vector3, xf: Transform3D, key: String, tint := Color(1, 1, 1)) -> void:
	var small := size.x * size.y * size.z < 1.5 and maxf(size.x, maxf(size.y, size.z)) < 3.0
	var b := _batch(key, xf.origin, small)
	var hs := size * 0.5
	var v: PackedVector3Array = b.v
	var n: PackedVector3Array = b.n
	var c: PackedColorArray = b.c
	var idx: PackedInt32Array = b.i
	for f in FACES:
		var N: Vector3 = f[0]
		var U: Vector3 = f[1]
		var V: Vector3 = f[2]
		var base := v.size()
		var wn := (xf.basis * N).normalized()
		for s in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			var local: Vector3 = (N + U * float(s[0]) + V * float(s[1])) * hs
			v.append(xf * local)
			n.append(wn)
			c.append(tint)
		idx.append(base); idx.append(base + 2); idx.append(base + 1)
		idx.append(base); idx.append(base + 3); idx.append(base + 2)
	b.v = v
	b.n = n
	b.c = c
	b.i = idx

func add_box_col(size: Vector3, xf: Transform3D, layer := 2) -> void:
	var sb := _body(xf.origin, layer)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	sb.add_child(cs)

func cyl(r: float, h: float, pos: Vector3, key := "concrete", collide := true, tint := Color(1, 1, 1), segs := 10, rot := Vector3.ZERO, r_top := -1.0) -> void:
	var xf := Transform3D(Basis.from_euler(rot), pos)
	var rt := r if r_top < 0.0 else r_top
	var small := r < 0.6 and h < 3.0
	var b := _batch(key, pos, small)
	var v: PackedVector3Array = b.v
	var n: PackedVector3Array = b.n
	var c: PackedColorArray = b.c
	var idx: PackedInt32Array = b.i
	var hh := h * 0.5
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0b := Vector3(cos(a0) * r, -hh, sin(a0) * r)
		var p1b := Vector3(cos(a1) * r, -hh, sin(a1) * r)
		var p0t := Vector3(cos(a0) * rt, hh, sin(a0) * rt)
		var p1t := Vector3(cos(a1) * rt, hh, sin(a1) * rt)
		var nn := (xf.basis * Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))).normalized()
		var base := v.size()
		for p in [p0b, p1b, p1t, p0t]:
			v.append(xf * p)
			n.append(nn)
			c.append(tint)
		idx.append(base); idx.append(base + 1); idx.append(base + 2)
		idx.append(base); idx.append(base + 2); idx.append(base + 3)
		# caps
		var up := (xf.basis * Vector3.UP).normalized()
		var cb := v.size()
		v.append(xf * Vector3(0, hh, 0)); v.append(xf * p0t); v.append(xf * p1t)
		for k in 3:
			n.append(up)
			c.append(tint)
		idx.append(cb); idx.append(cb + 1); idx.append(cb + 2)
		var cb2 := v.size()
		v.append(xf * Vector3(0, -hh, 0)); v.append(xf * p1b); v.append(xf * p0b)
		for k in 3:
			n.append(-up)
			c.append(tint)
		idx.append(cb2); idx.append(cb2 + 1); idx.append(cb2 + 2)
	b.v = v
	b.n = n
	b.c = c
	b.i = idx
	if collide:
		var sb := _body(pos, 2)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r, rt)
		sh.height = h
		cs.shape = sh
		cs.transform = xf
		sb.add_child(cs)

# A sloped walkable ramp (visual steps optional) from p0 (bottom) to p1 (top).
func ramp(p0: Vector3, p1: Vector3, width: float, key := "concrete", steps := true, tint := Color(1, 1, 1)) -> void:
	var d := p1 - p0
	var flat := Vector2(d.x, d.z).length()
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, flat)
	var mid := (p0 + p1) * 0.5
	var len := d.length()
	var xf := Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0)), mid)
	add_box_col(Vector3(width, 0.2, len), xf)
	if steps:
		var n_steps := int(maxf(2.0, absf(d.y) / 0.22))
		for i in n_steps:
			var t := (i + 0.5) / n_steps
			var sp := p0.lerp(p1, t)
			var sx := Transform3D(Basis.from_euler(Vector3(0, yaw, 0)), sp + Vector3(0, -absf(d.y) / n_steps * 0.5, 0))
			add_box_mesh(Vector3(width, absf(d.y) / n_steps, flat / n_steps + 0.02), sx, key, tint)
	else:
		add_box_mesh(Vector3(width, 0.2, len), xf, key, tint)

# Wall segment with an opening (door/storefront). Axis "x" runs along X.
func wall(a: Vector3, b2: Vector3, height: float, thick: float, key: String, tint := Color(1, 1, 1), openings: Array = []) -> void:
	var dir := b2 - a
	var length := Vector2(dir.x, dir.z).length()
	var yaw := atan2(dir.x, dir.z)
	var basis := Basis.from_euler(Vector3(0, yaw, 0))
	var cuts := openings.duplicate()
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var cursor := 0.0
	for o in cuts:
		var s: float = o[0] - o[1] * 0.5
		var e: float = o[0] + o[1] * 0.5
		var oh: float = o[2] if o.size() > 2 else height
		if s > cursor:
			_wall_piece(a, basis, cursor, s, 0.0, height, thick, key, tint)
		if oh < height:
			_wall_piece(a, basis, s, e, oh, height, thick, key, tint)
		cursor = e
	if cursor < length:
		_wall_piece(a, basis, cursor, length, 0.0, height, thick, key, tint)

func _wall_piece(a: Vector3, basis: Basis, s: float, e: float, y0: float, y1: float, thick: float, key: String, tint: Color) -> void:
	var len := e - s
	if len <= 0.01 or y1 - y0 <= 0.01:
		return
	var center := a + basis * Vector3(0, (y0 + y1) * 0.5, (s + e) * 0.5)
	var xf := Transform3D(basis, center)
	var size := Vector3(thick, y1 - y0, len)
	add_box_mesh(size, xf, key, tint)
	add_box_col(size, xf)

# ---------- occlusion: big solid boxes hide whatever is behind them ----------
func occluder(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var oi := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = size
	oi.occluder = bo
	root.add_child(oi)
	oi.position = pos
	oi.rotation = rot

# ---------- lights (budgeted) ----------
func light(pos: Vector3, col: Color, rng := 8.0, energy := 1.5, shadow := false) -> OmniLight3D:
	lights += 1
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	l.shadow_enabled = shadow
	l.distance_fade_enabled = true
	l.distance_fade_begin = 55.0
	l.distance_fade_length = 20.0
	root.add_child(l)
	l.position = pos
	return l

func neon_text(text: String, pos: Vector3, yaw: float, col_key: String, size := 160, with_light := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 0
	var c := _glow_color(col_key)
	l.modulate = Color(c.r * 2.4, c.g * 2.4, c.b * 2.4)
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = false
	l.visibility_range_end = 120.0
	root.add_child(l)
	if with_light:
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		light(pos + fwd * 1.2, c, 9.0, 2.2)
	return l

# ---------- commit ----------
func commit() -> void:
	for bk in batches:
		var b: Dictionary = batches[bk]
		if (b.v as PackedVector3Array).is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = b.v
		arrays[Mesh.ARRAY_NORMAL] = b.n
		arrays[Mesh.ARRAY_COLOR] = b.c
		arrays[Mesh.ARRAY_INDEX] = b.i
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(0, material(b.key))
		var mi := MeshInstance3D.new()
		mi.mesh = am
		if b.small:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 170.0
			mi.visibility_range_end_margin = 20.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if String(b.key).begins_with("neon_") or b.key == "glass":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	batches.clear()
