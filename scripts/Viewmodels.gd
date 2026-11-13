class_name Viewmodels
extends RefCounted
# Procedural first-person models. Every gun gets named sub-nodes the Player animates:
#   Gun (body + trigger hand), Mag (magazine + support hand), Muzzle (barrel tip),
#   Sight (the point that lines up with the screen center when aiming), and optional
#   Pump / Bolt / Slide / Arrow nodes for class-specific reload & cycle animations.
# Parts are chamfered meshes (edges catch the light) with PBR materials: worn
# gunmetal, stippled polymer, grained wood, rubber, glass optics with lit reticles.
# Built at real-world scale; the Player scales the whole view rig down so it never clips.

static var _mats := {}
static var _meshes := {}

# ---------------- materials ----------------
static func mat(key: String, col: Color, metal := 0.5, rough := 0.5, emit := 0.0) -> StandardMaterial3D:
	var k := "%s_%s_%.2f_%.2f_%.2f" % [key, col.to_html(), metal, rough, emit]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	_mats[k] = m
	return m

static func surf(key: String, tex: String, tint: Color, metal: float, rough_mul: float, uv := 9.0) -> StandardMaterial3D:
	var k := "surf_%s" % key
	if _mats.has(k):
		return _mats[k]
	var m := Proc.pbr(tex, tint, uv, metal, rough_mul, false)
	_mats[k] = m
	return m

static func _steel() -> StandardMaterial3D: return surf("steel", "gunmetal", Color(0.62, 0.63, 0.66), 0.85, 0.8, 3.0)
static func _blued() -> StandardMaterial3D: return surf("blued", "gunmetal", Color(0.36, 0.4, 0.5), 0.85, 0.7, 3.0)
static func _park() -> StandardMaterial3D: return surf("park", "gunmetal", Color(0.5, 0.52, 0.5), 0.55, 1.1, 3.0)
static func _alu() -> StandardMaterial3D: return surf("alu", "gunmetal", Color(1.2, 1.22, 1.28), 0.9, 0.55, 3.0)
static func _poly() -> StandardMaterial3D: return surf("poly", "polymer", Color(1, 1, 1), 0.0, 1.0, 14.0)
static func _tan() -> StandardMaterial3D: return surf("tan", "polymer", Color(4.6, 3.9, 2.7), 0.0, 1.0, 14.0)
static func _odg() -> StandardMaterial3D: return surf("odg", "polymer", Color(2.6, 3.0, 2.0), 0.0, 1.0, 14.0)
static func _wood() -> StandardMaterial3D: return surf("wood", "walnut", Color(1, 1, 1), 0.0, 1.0, 4.0)
static func _rubber() -> StandardMaterial3D: return mat("rubber", Color(0.05, 0.05, 0.05), 0.0, 0.95)
static func _dark() -> StandardMaterial3D: return mat("bore", Color(0.01, 0.01, 0.012), 0.2, 0.9)
static func _brass() -> StandardMaterial3D: return mat("brassvm", Color(0.85, 0.65, 0.28), 1.0, 0.28)
static func _glove() -> StandardMaterial3D: return surf("glove", "fabric", Color(0.55, 0.45, 0.36), 0.0, 1.0, 22.0)
static func _skin() -> StandardMaterial3D: return mat("skin", Color(0.72, 0.53, 0.4), 0.0, 0.62)
static func _sleeve() -> StandardMaterial3D: return surf("sleeve", "fabric", Color(0.36, 0.38, 0.3), 0.0, 1.0, 16.0)

static func _glass(tint := Color(0.08, 0.16, 0.22)) -> StandardMaterial3D:
	var k := "glass_%s" % tint.to_html()
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.8
	m.roughness = 0.02
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.2
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	_mats[k] = m
	return m

# ---------------- primitives ----------------
static func _bevel_mesh(size: Vector3, bev: float) -> ArrayMesh:
	var key := "%.4f_%.4f_%.4f_%.4f" % [size.x, size.y, size.z, bev]
	if _meshes.has(key):
		return _meshes[key]
	var h := size * 0.5
	var b := minf(bev, minf(h.x, minf(h.y, h.z)) * 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var px := func(sx: float, sy: float, sz: float) -> Vector3: return Vector3(sx * h.x, sy * (h.y - b), sz * (h.z - b))
	var py := func(sx: float, sy: float, sz: float) -> Vector3: return Vector3(sx * (h.x - b), sy * h.y, sz * (h.z - b))
	var pz := func(sx: float, sy: float, sz: float) -> Vector3: return Vector3(sx * (h.x - b), sy * (h.y - b), sz * h.z)
	for s in [-1.0, 1.0]:
		_quad(st, px.call(s, -1, -1), px.call(s, 1, -1), px.call(s, 1, 1), px.call(s, -1, 1))
		_quad(st, py.call(-1, s, -1), py.call(1, s, -1), py.call(1, s, 1), py.call(-1, s, 1))
		_quad(st, pz.call(-1, -1, s), pz.call(1, -1, s), pz.call(1, 1, s), pz.call(-1, 1, s))
	for sa in [-1.0, 1.0]:
		for sb in [-1.0, 1.0]:
			_quad(st, px.call(sa, sb, -1), px.call(sa, sb, 1), py.call(sa, sb, 1), py.call(sa, sb, -1))
			_quad(st, px.call(sa, -1, sb), px.call(sa, 1, sb), pz.call(sa, 1, sb), pz.call(sa, -1, sb))
			_quad(st, py.call(-1, sa, sb), py.call(1, sa, sb), pz.call(1, sa, sb), pz.call(-1, sa, sb))
			for sc in [-1.0, 1.0]:
				_tri(st, px.call(sa, sb, sc), py.call(sa, sb, sc), pz.call(sa, sb, sc))
	var m := st.commit()
	_meshes[key] = m
	return m

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14:
		return
	if n.dot(a + b + c) > 0.0:
		var t := b
		b = c
		c = t
		n = -n
	var out := (-n).normalized()
	for v in [a, b, c]:
		st.set_normal(out)
		st.add_vertex(v)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(st, a, b, c)
	_tri(st, a, c, d)

# Chamfered box. Bevel defaults to a fraction of the thinnest side.
static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO, bevel := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bv := bevel if bevel >= 0.0 else minf(size.x, minf(size.y, size.z)) * 0.18
	if bv <= 0.0005:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	else:
		mi.mesh = _bevel_mesh(size, bv)
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, r: float, length: float, pos: Vector3, m: Material, along_z := true, r2 := -1.0, segs := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r2 < 0.0 else r2
	cm.height = length
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	if along_z:
		mi.rotation = Vector3(PI / 2.0, 0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _marker(parent: Node3D, nm: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n

# ---------------- detail kits ----------------
# Picatinny rail: base strip + teeth.
static func _rail(p: Node3D, z0: float, z1: float, y: float, w: float, m: Material) -> void:
	var len := absf(z1 - z0)
	box(p, Vector3(w, 0.006, len), Vector3(0, y, (z0 + z1) * 0.5), m, Vector3.ZERO, 0.001)
	var n := int(len / 0.0105)
	for i in n:
		box(p, Vector3(w * 1.12, 0.005, 0.0055), Vector3(0, y + 0.005, minf(z0, z1) + 0.006 + i * 0.0105), m, Vector3.ZERO, 0.001)

static func _screw(p: Node3D, pos: Vector3, r := 0.0035) -> void:
	var s := cyl(p, r, 0.003, pos, _alu(), false, -1.0, 8)
	s.rotation = Vector3(0, 0, PI / 2.0)

static func _trigger(p: Node3D, z: float, y: float, m: Material) -> void:
	box(p, Vector3(0.008, 0.004, 0.07), Vector3(0, y - 0.042, z - 0.005), m, Vector3.ZERO, 0.0015)          # guard bottom
	box(p, Vector3(0.008, 0.042, 0.005), Vector3(0, y - 0.021, z - 0.04), m, Vector3.ZERO, 0.0015)         # guard front
	box(p, Vector3(0.005, 0.026, 0.006), Vector3(0, y - 0.016, z - 0.012), _alu(), Vector3(0.35, 0, 0), 0.001)  # trigger blade

static func _serrations(p: Node3D, z0: float, count: int, size: Vector3, y: float, w: float) -> void:
	for i in count:
		for sx in [-1.0, 1.0]:
			box(p, Vector3(0.002, size.y, size.z), Vector3(sx * w * 0.5, y, z0 + i * size.z * 2.0), _dark(), Vector3.ZERO, 0.0)

static func _brake(p: Node3D, z: float, y: float, r: float) -> void:
	cyl(p, r, 0.05, Vector3(0, y, z), _blued())
	cyl(p, r * 0.55, 0.052, Vector3(0, y, z - 0.001), _dark())
	for i in 3:
		for sx in [-1.0, 1.0]:
			box(p, Vector3(0.004, r * 1.1, 0.007), Vector3(sx * r * 0.9, y, z - 0.015 + i * 0.013), _dark(), Vector3.ZERO, 0.0)

static func _bore(p: Node3D, z: float, y: float, r: float) -> void:
	cyl(p, r, 0.004, Vector3(0, y, z - 0.002), _dark(), true, -1.0, 12)

# A gloved hand + fingers wrapped around a grip, forearm sleeve reaching off-screen.
static func _hand(parent: Node3D, pos: Vector3, rot: Vector3, support := false) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation = rot
	parent.add_child(h)
	box(h, Vector3(0.05, 0.062, 0.082), Vector3.ZERO, _glove(), Vector3.ZERO, 0.012)
	for i in 4:
		box(h, Vector3(0.052, 0.014, 0.019), Vector3(0, 0.026 - i * 0.017, -0.046), _glove(), Vector3(0, 0, 0.05), 0.005)
	box(h, Vector3(0.016, 0.018, 0.05), Vector3(-0.03 if not support else 0.03, 0.022, -0.026), _glove(), Vector3(0, 0, 0.2), 0.006)
	box(h, Vector3(0.03, 0.03, 0.03), Vector3(0, -0.02, 0.05), _skin(), Vector3.ZERO, 0.008)        # wrist
	var cuff := box(h, Vector3(0.06, 0.06, 0.05), Vector3(0, -0.012, 0.075), _glove(), Vector3.ZERO, 0.012)
	cuff.rotation.x = 0.1
	var arm := box(h, Vector3(0.058, 0.06, 0.4), Vector3(0, -0.04, 0.27), _sleeve(), Vector3.ZERO, 0.018)
	arm.rotation.x = 0.28

static func _rarity_mat(e: Dictionary) -> StandardMaterial3D:
	var r := int(e.get("rarity", 0))
	var c: Color = ItemDB.rarity_color(r)
	return mat("rar", c, 0.5, 0.35, 0.0 if r < 3 else (0.35 if r == 3 else 0.8))

# Glowing reticle dot/ring that sits on the sight line.
static func _reticle(p: Node3D, pos: Vector3, ring := false, col := Color(1.0, 0.2, 0.12)) -> void:
	if ring:
		var rr := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.0034
		tm.outer_radius = 0.0043
		rr.mesh = tm
		rr.material_override = mat("ret", col, 0.0, 0.5, 6.0)
		rr.rotation.x = PI / 2.0
		rr.position = pos
		rr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(rr)
	var d := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0009
	sm.height = 0.0018
	d.mesh = sm
	d.material_override = mat("retd", col, 0.0, 0.5, 8.0)
	d.position = pos
	p.add_child(d)

# ---------------- guns ----------------
static func build(e: Dictionary) -> Node3D:
	var id: String = e.get("id", "pistol")
	var root := Node3D.new()
	root.name = "VM_" + id
	var gun := Node3D.new(); gun.name = "Gun"
	var mag := Node3D.new(); mag.name = "Mag"
	root.add_child(gun)
	root.add_child(mag)
	var rm := _rarity_mat(e)
	match id:
		"pistol": _pistol(root, gun, mag, rm)
		"revolver": _revolver(root, gun, mag, rm)
		"smg": _smg(root, gun, mag, rm)
		"ar": _ar(root, gun, mag, rm)
		"shotgun": _shotgun(root, gun, mag, rm)
		"dmr": _rifle(root, gun, mag, rm, false)
		"sniper": _rifle(root, gun, mag, rm, true)
		"lmg": _lmg(root, gun, mag, rm)
		"crossbow": _crossbow(root, gun, mag, rm)
		_: _pistol(root, gun, mag, rm)
	if "hushed" in e.get("perks", []):
		var muz := root.get_node("Gun/Muzzle") as Node3D
		cyl(gun, 0.021, 0.17, muz.position + Vector3(0, 0, -0.08), _park())
		for i in 3:
			cyl(gun, 0.0215, 0.006, muz.position + Vector3(0, 0, -0.03 - i * 0.05), _dark())
		_bore(gun, muz.position.z - 0.165, muz.position.y, 0.006)
		muz.position.z -= 0.16
	return root

static func _pistol(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	var slide := Node3D.new(); slide.name = "Slide"
	gun.add_child(slide)
	box(slide, Vector3(0.031, 0.034, 0.19), Vector3(0, 0.041, -0.09), _steel(), Vector3.ZERO, 0.004)
	box(slide, Vector3(0.026, 0.008, 0.17), Vector3(0, 0.059, -0.09), _steel(), Vector3.ZERO, 0.003)         # top flat
	_serrations(slide, -0.008, 6, Vector3(0, 0.024, 0.003), 0.043, 0.031)
	box(slide, Vector3(0.002, 0.012, 0.03), Vector3(0.0157, 0.046, -0.05), _dark(), Vector3.ZERO, 0.0)         # ejection port
	box(slide, Vector3(0.006, 0.009, 0.008), Vector3(0, 0.067, -0.172), _steel(), Vector3.ZERO, 0.002)       # front sight
	box(slide, Vector3(0.002, 0.002, 0.002), Vector3(0, 0.069, -0.1765), mat("trit", Color(0.4, 1.0, 0.5), 0.0, 0.5, 5.0), Vector3.ZERO, 0.0)
	box(slide, Vector3(0.024, 0.009, 0.01), Vector3(-0.0, 0.067, -0.006), _steel(), Vector3.ZERO, 0.002)     # rear sight
	_bore(slide, -0.186, 0.039, 0.0055)
	box(gun, Vector3(0.029, 0.022, 0.165), Vector3(0, 0.013, -0.085), _poly(), Vector3.ZERO, 0.004)          # frame
	_rail(gun, -0.16, -0.11, 0.0005, 0.02, _poly())
	_trigger(gun, -0.03, 0.006, _poly())
	box(gun, Vector3(0.03, 0.105, 0.046), Vector3(0, -0.043, 0.004), _poly(), Vector3(0.28, 0, 0), 0.007)     # grip
	box(gun, Vector3(0.031, 0.06, 0.03), Vector3(0, -0.04, 0.003), mat("stip", Color(0.06, 0.06, 0.065), 0.0, 1.0), Vector3(0.28, 0, 0), 0.006)
	box(gun, Vector3(0.033, 0.006, 0.12), Vector3(0, 0.024, -0.09), rm, Vector3.ZERO, 0.002)
	_screw(gun, Vector3(0.0152, 0.012, -0.03))
	_marker(gun, "Muzzle", Vector3(0, 0.04, -0.2))
	_marker(gun, "Sight", Vector3(0, 0.0705, 0.0))
	box(mag, Vector3(0.023, 0.09, 0.034), Vector3(0, -0.058, 0.009), _steel(), Vector3(0.28, 0, 0), 0.003)
	box(mag, Vector3(0.03, 0.01, 0.042), Vector3(0, -0.1, 0.024), _poly(), Vector3(0.28, 0, 0), 0.003)
	_hand(gun, Vector3(0.0, -0.045, 0.022), Vector3(0.28, 0, -0.08))
	_hand(mag, Vector3(-0.022, -0.055, 0.0), Vector3(0.2, 0.2, 0.25), true)
	root.set_meta("hip", Vector3(0.15, -0.135, -0.33))
	root.set_meta("ads_dist", 0.24)

static func _revolver(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	cyl(gun, 0.0135, 0.2, Vector3(0, 0.034, -0.17), _blued(), true, -1.0, 20)
	box(gun, Vector3(0.016, 0.012, 0.2), Vector3(0, 0.05, -0.17), _blued(), Vector3.ZERO, 0.003)           # top rib
	for i in 6:
		box(gun, Vector3(0.012, 0.004, 0.02), Vector3(0, 0.0575, -0.09 - i * 0.026), _dark(), Vector3.ZERO, 0.0)  # vent rib cuts
	box(gun, Vector3(0.018, 0.018, 0.17), Vector3(0, 0.017, -0.16), _blued(), Vector3.ZERO, 0.004)         # ejector shroud
	_bore(gun, -0.271, 0.034, 0.007)
	box(gun, Vector3(0.03, 0.055, 0.075), Vector3(0, 0.026, -0.008), _blued(), Vector3.ZERO, 0.006)       # frame
	var drum := Node3D.new(); drum.name = "Drum"
	mag.add_child(drum)
	drum.position = Vector3(0, 0.031, -0.045)
	cyl(drum, 0.026, 0.046, Vector3.ZERO, _steel(), true, -1.0, 18)
	for i in 6:
		var a := TAU * i / 6.0
		box(drum, Vector3(0.005, 0.005, 0.047), Vector3(cos(a) * 0.025, sin(a) * 0.025, 0), _dark(), Vector3(0, 0, a), 0.0)
	box(gun, Vector3(0.008, 0.016, 0.022), Vector3(0, 0.058, 0.03), _steel(), Vector3(0.5, 0, 0), 0.002)     # hammer
	box(gun, Vector3(0.004, 0.011, 0.014), Vector3(0, 0.0625, -0.262), _steel(), Vector3.ZERO, 0.001)        # blade sight
	box(gun, Vector3(0.012, 0.005, 0.01), Vector3(0, 0.0585, 0.0), _steel(), Vector3.ZERO, 0.001)
	_trigger(gun, -0.0, 0.0, _blued())
	box(gun, Vector3(0.034, 0.1, 0.05), Vector3(0, -0.04, 0.03), _wood(), Vector3(0.38, 0, 0), 0.012)        # grip
	box(gun, Vector3(0.036, 0.008, 0.03), Vector3(0, -0.035, 0.035), rm, Vector3(0.38, 0, 0), 0.002)
	_screw(gun, Vector3(0.0175, -0.035, 0.03), 0.004)
	_marker(gun, "Muzzle", Vector3(0, 0.034, -0.275))
	_marker(gun, "Sight", Vector3(0, 0.0645, 0.0))
	_hand(gun, Vector3(0.0, -0.045, 0.045), Vector3(0.38, 0, -0.08))
	_hand(mag, Vector3(-0.022, -0.05, 0.02), Vector3(0.25, 0.2, 0.25), true)
	root.set_meta("hip", Vector3(0.15, -0.135, -0.33))
	root.set_meta("ads_dist", 0.24)

static func _reflex(gun: Node3D, z: float, y: float) -> float:
	# compact red dot: base, hood, tinted glass, glowing dot. Returns sight height.
	box(gun, Vector3(0.03, 0.01, 0.045), Vector3(0, y + 0.005, z), _alu(), Vector3.ZERO, 0.002)
	box(gun, Vector3(0.004, 0.032, 0.03), Vector3(-0.015, y + 0.026, z), _park(), Vector3.ZERO, 0.0015)
	box(gun, Vector3(0.004, 0.032, 0.03), Vector3(0.015, y + 0.026, z), _park(), Vector3.ZERO, 0.0015)
	box(gun, Vector3(0.034, 0.005, 0.03), Vector3(0, y + 0.043, z), _park(), Vector3.ZERO, 0.0015)
	box(gun, Vector3(0.026, 0.026, 0.002), Vector3(0, y + 0.026, z - 0.012), _glass(Color(0.35, 0.18, 0.1)), Vector3.ZERO, 0.0)
	box(gun, Vector3(0.008, 0.008, 0.012), Vector3(0.02, y + 0.012, z + 0.006), _park(), Vector3.ZERO, 0.002)   # battery cap
	_reticle(gun, Vector3(0, y + 0.026, z - 0.0135))
	return y + 0.026

static func _smg(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.04, 0.05, 0.26), Vector3(0, 0.022, -0.1), _park(), Vector3.ZERO, 0.006)            # receiver
	box(gun, Vector3(0.002, 0.014, 0.04), Vector3(0.0205, 0.03, -0.06), _dark(), Vector3.ZERO, 0.0)          # ejection port
	box(gun, Vector3(0.012, 0.006, 0.014), Vector3(-0.024, 0.033, -0.17), _steel(), Vector3.ZERO, 0.002)     # charging knob
	cyl(gun, 0.022, 0.14, Vector3(0, 0.025, -0.29), _poly(), true, -1.0, 14)                         # shroud
	for i in 5:
		for sx in [-1.0, 1.0]:
			box(gun, Vector3(0.004, 0.009, 0.012), Vector3(sx * 0.0205, 0.026, -0.245 - i * 0.022), _dark(), Vector3.ZERO, 0.0)
	cyl(gun, 0.009, 0.05, Vector3(0, 0.025, -0.38), _blued())
	_bore(gun, -0.405, 0.025, 0.005)
	_rail(gun, -0.2, -0.0, 0.047, 0.022, _park())
	var sy := _reflex(gun, -0.06, 0.052)
	_trigger(gun, -0.03, 0.0, _park())
	box(gun, Vector3(0.03, 0.095, 0.04), Vector3(0, -0.045, 0.002), _poly(), Vector3(0.3, 0, 0), 0.007)
	box(gun, Vector3(0.026, 0.07, 0.03), Vector3(0, -0.04, -0.26), _poly(), Vector3(-0.1, 0, 0), 0.008)    # vertical grip
	for sx in [-1.0, 1.0]:
		box(gun, Vector3(0.006, 0.006, 0.17), Vector3(sx * 0.016, 0.01, 0.11), _steel(), Vector3.ZERO, 0.002)   # wire stock
	box(gun, Vector3(0.04, 0.05, 0.012), Vector3(0, -0.005, 0.19), _rubber(), Vector3.ZERO, 0.004)
	box(gun, Vector3(0.042, 0.006, 0.18), Vector3(0, 0.0, -0.1), rm, Vector3.ZERO, 0.002)
	_screw(gun, Vector3(0.0205, 0.01, -0.03))
	_screw(gun, Vector3(0.0205, 0.01, -0.15))
	_marker(gun, "Muzzle", Vector3(0, 0.025, -0.41))
	_marker(gun, "Sight", Vector3(0, sy, -0.03))
	box(mag, Vector3(0.024, 0.13, 0.034), Vector3(0, -0.07, -0.1), _steel(), Vector3(0.08, 0, 0), 0.004)
	for i in 4:
		box(mag, Vector3(0.026, 0.003, 0.03), Vector3(0, -0.03 - i * 0.025, -0.1 + i * 0.002), _dark(), Vector3(0.08, 0, 0), 0.0)
	box(mag, Vector3(0.03, 0.01, 0.04), Vector3(0, -0.137, -0.106), _poly(), Vector3(0.08, 0, 0), 0.003)
	_hand(gun, Vector3(0.0, -0.05, 0.026), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.004, -0.045, -0.26), Vector3(0, 0.1, 0.25), true)
	root.set_meta("hip", Vector3(0.16, -0.14, -0.34))
	root.set_meta("ads_dist", 0.2)

static func _holo(gun: Node3D, z: float, y: float) -> float:
	box(gun, Vector3(0.036, 0.012, 0.075), Vector3(0, y + 0.006, z), _park(), Vector3.ZERO, 0.003)       # body
	box(gun, Vector3(0.012, 0.01, 0.022), Vector3(0.022, y + 0.008, z + 0.02), _park(), Vector3.ZERO, 0.002)
	for sx in [-1.0, 1.0]:
		box(gun, Vector3(0.005, 0.044, 0.05), Vector3(sx * 0.019, y + 0.034, z - 0.008), _park(), Vector3.ZERO, 0.002)
	box(gun, Vector3(0.043, 0.006, 0.05), Vector3(0, y + 0.057, z - 0.008), _park(), Vector3.ZERO, 0.002)
	box(gun, Vector3(0.033, 0.038, 0.002), Vector3(0, y + 0.034, z - 0.03), _glass(Color(0.18, 0.28, 0.32)), Vector3.ZERO, 0.0)
	box(gun, Vector3(0.033, 0.038, 0.002), Vector3(0, y + 0.034, z + 0.015), _glass(Color(0.18, 0.28, 0.32)), Vector3.ZERO, 0.0)
	_reticle(gun, Vector3(0, y + 0.034, z - 0.032), true)
	return y + 0.034

static func _ar(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.042, 0.045, 0.24), Vector3(0, 0.032, -0.08), _park(), Vector3.ZERO, 0.005)        # upper
	box(gun, Vector3(0.038, 0.04, 0.17), Vector3(0, -0.006, -0.07), _park(), Vector3.ZERO, 0.005)         # lower
	box(gun, Vector3(0.002, 0.016, 0.05), Vector3(0.0215, 0.032, -0.06), _dark(), Vector3.ZERO, 0.0)         # ejection port
	box(gun, Vector3(0.003, 0.018, 0.054), Vector3(0.0225, 0.032, -0.06), _park(), Vector3(0, 0.15, 0), 0.001)  # dust cover
	cyl(gun, 0.008, 0.02, Vector3(0.024, 0.043, -0.005), _park(), true, -1.0, 10)                    # forward assist
	box(gun, Vector3(0.03, 0.01, 0.03), Vector3(0, 0.05, 0.05), _park(), Vector3.ZERO, 0.002)             # charging handle
	box(gun, Vector3(0.05, 0.05, 0.24), Vector3(0, 0.03, -0.32), _tan(), Vector3.ZERO, 0.008)            # handguard
	for i in 6:
		for sx in [-1.0, 1.0]:
			box(gun, Vector3(0.003, 0.009, 0.022), Vector3(sx * 0.025, 0.026, -0.235 - i * 0.034), _dark(), Vector3.ZERO, 0.0)  # M-LOK slots
	_rail(gun, -0.44, 0.04, 0.058, 0.022, _park())
	cyl(gun, 0.0085, 0.16, Vector3(0, 0.034, -0.5), _blued())
	box(gun, Vector3(0.02, 0.024, 0.026), Vector3(0, 0.036, -0.455), _blued(), Vector3.ZERO, 0.003)      # gas block
	_brake(gun, -0.6, 0.034, 0.012)
	_bore(gun, -0.626, 0.034, 0.005)
	var sy := _holo(gun, -0.06, 0.062)
	_trigger(gun, -0.03, -0.006, _park())
	box(gun, Vector3(0.03, 0.095, 0.04), Vector3(0, -0.055, 0.0), _poly(), Vector3(0.3, 0, 0), 0.008)    # grip
	cyl(gun, 0.016, 0.15, Vector3(0, 0.02, 0.1), _park())                                            # buffer tube
	box(gun, Vector3(0.04, 0.06, 0.16), Vector3(0, 0.005, 0.16), _tan(), Vector3.ZERO, 0.01)              # stock
	box(gun, Vector3(0.042, 0.066, 0.014), Vector3(0, 0.002, 0.245), _rubber(), Vector3.ZERO, 0.004)
	box(gun, Vector3(0.044, 0.007, 0.15), Vector3(0, -0.026, -0.08), rm, Vector3.ZERO, 0.002)
	for z in [-0.12, -0.03, 0.03]:
		_screw(gun, Vector3(0.0195, -0.01, z))
	_marker(gun, "Muzzle", Vector3(0, 0.034, -0.63))
	_marker(gun, "Sight", Vector3(0, sy, -0.02))
	var magn := Node3D.new()
	mag.add_child(magn)
	magn.position = Vector3(0, -0.03, -0.1)
	box(magn, Vector3(0.026, 0.09, 0.05), Vector3(0, -0.04, 0), _steel(), Vector3(-0.12, 0, 0), 0.004)
	box(magn, Vector3(0.026, 0.07, 0.048), Vector3(0, -0.11, 0.014), _steel(), Vector3(-0.32, 0, 0), 0.004)
	for i in 3:
		box(magn, Vector3(0.028, 0.004, 0.044), Vector3(0, -0.03 - i * 0.03, 0.002 + i * 0.004), _dark(), Vector3(-0.15, 0, 0), 0.0)
	box(magn, Vector3(0.032, 0.012, 0.054), Vector3(0, -0.145, 0.03), _poly(), Vector3(-0.32, 0, 0), 0.003)
	_hand(gun, Vector3(0.0, -0.06, 0.022), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.01, -0.01, -0.32), Vector3(0, 0.0, 0.35), true)
	root.set_meta("hip", Vector3(0.17, -0.15, -0.36))
	root.set_meta("ads_dist", 0.19)

static func _shotgun(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	cyl(gun, 0.0145, 0.56, Vector3(0, 0.042, -0.37), _blued(), true, -1.0, 20)
	box(gun, Vector3(0.008, 0.005, 0.5), Vector3(0, 0.058, -0.36), _blued(), Vector3.ZERO, 0.0015)       # vent rib
	cyl(gun, 0.0125, 0.42, Vector3(0, 0.012, -0.3), _blued(), true, -1.0, 16)                       # mag tube
	cyl(gun, 0.0135, 0.02, Vector3(0, 0.012, -0.515), _steel())                                     # mag cap
	_bore(gun, -0.651, 0.042, 0.009)
	box(gun, Vector3(0.044, 0.062, 0.19), Vector3(0, 0.026, -0.02), _blued(), Vector3.ZERO, 0.007)       # receiver
	box(gun, Vector3(0.002, 0.02, 0.06), Vector3(0.0225, 0.035, -0.03), _dark(), Vector3.ZERO, 0.0)          # ejection port
	for i in 4:
		cyl(gun, 0.0085, 0.05, Vector3(-0.026, 0.02 - i * 0.0, -0.06 + i * 0.022), mat("shellvm", Color(0.7, 0.08, 0.06), 0.1, 0.5), false).rotation = Vector3(0, 0, 0)   # side saddle
	box(gun, Vector3(0.006, 0.07, 0.11), Vector3(-0.024, 0.025, -0.03), _poly(), Vector3.ZERO, 0.002)
	box(gun, Vector3(0.04, 0.07, 0.27), Vector3(0, -0.004, 0.18), _wood(), Vector3(-0.08, 0, 0), 0.012)  # stock
	box(gun, Vector3(0.042, 0.08, 0.016), Vector3(0, -0.014, 0.315), _rubber(), Vector3(-0.08, 0, 0), 0.005)
	box(gun, Vector3(0.006, 0.006, 0.006), Vector3(0, 0.063, -0.635), mat("bead", Color(0.95, 0.9, 0.7), 0.9, 0.2), Vector3.ZERO, 0.002)
	_trigger(gun, 0.02, 0.0, _blued())
	box(gun, Vector3(0.046, 0.007, 0.13), Vector3(0, 0.0, -0.02), rm, Vector3.ZERO, 0.002)
	_screw(gun, Vector3(0.0225, 0.02, 0.03))
	_screw(gun, Vector3(0.0225, 0.02, -0.08))
	var pump := Node3D.new(); pump.name = "Pump"
	gun.add_child(pump)
	box(pump, Vector3(0.05, 0.045, 0.15), Vector3(0, 0.006, -0.3), _wood(), Vector3.ZERO, 0.012)
	for i in 6:
		box(pump, Vector3(0.052, 0.004, 0.006), Vector3(0, 0.006 + (i % 2) * 0.0, -0.36 + i * 0.024), _dark(), Vector3.ZERO, 0.0)
	_hand(pump, Vector3(-0.005, -0.03, -0.3), Vector3(0, 0, 0.35), true)
	_marker(gun, "Muzzle", Vector3(0, 0.042, -0.655))
	_marker(gun, "Sight", Vector3(0, 0.0665, 0.02))
	cyl(mag, 0.0085, 0.06, Vector3(0, -0.04, -0.06), mat("shellvm", Color(0.7, 0.08, 0.06), 0.1, 0.5))
	cyl(mag, 0.0088, 0.012, Vector3(0, -0.04, -0.03), _brass())
	_hand(gun, Vector3(0.0, -0.045, 0.065), Vector3(0.3, 0, -0.08))
	root.set_meta("hip", Vector3(0.17, -0.15, -0.34))
	root.set_meta("ads_dist", 0.22)

static func _rifle(root: Node3D, gun: Node3D, mag: Node3D, rm: Material, sniper: bool) -> void:
	var bl := 0.42 if not sniper else 0.56
	var br := 0.012 if not sniper else 0.0145
	box(gun, Vector3(0.042, 0.055, 0.3), Vector3(0, 0.024, -0.08), _park() if not sniper else _blued(), Vector3.ZERO, 0.006)
	cyl(gun, br, bl, Vector3(0, 0.03, -0.23 - bl * 0.5), _blued(), true, -1.0, 20)
	for i in 6:
		var a := TAU * i / 6.0
		box(gun, Vector3(0.003, 0.003, bl * 0.6), Vector3(cos(a) * br * 0.95, 0.03 + sin(a) * br * 0.95, -0.23 - bl * 0.45), _dark(), Vector3(0, 0, a), 0.0)  # fluting
	if sniper:
		_brake(gun, -0.23 - bl - 0.02, 0.03, br * 1.25)
		_bore(gun, -0.23 - bl - 0.046, 0.03, 0.005)
	else:
		_bore(gun, -0.23 - bl, 0.03, 0.005)
	box(gun, Vector3(0.05, 0.05, 0.3), Vector3(0, 0.0, -0.33), _wood() if sniper else _odg(), Vector3.ZERO, 0.01)
	box(gun, Vector3(0.046, 0.085, 0.3), Vector3(0, -0.005, 0.21), _wood() if sniper else _odg(), Vector3(-0.06, 0, 0), 0.014)
	box(gun, Vector3(0.03, 0.025, 0.12), Vector3(0, 0.05, 0.2), _wood() if sniper else _odg(), Vector3(-0.06, 0, 0), 0.008)   # cheek riser
	box(gun, Vector3(0.048, 0.094, 0.016), Vector3(0, -0.012, 0.365), _rubber(), Vector3(-0.06, 0, 0), 0.005)
	box(gun, Vector3(0.032, 0.09, 0.042), Vector3(0, -0.05, 0.03), _poly(), Vector3(0.3, 0, 0), 0.008)
	_trigger(gun, 0.0, -0.002, _park())
	box(gun, Vector3(0.048, 0.008, 0.28), Vector3(0, -0.017, -0.12), rm, Vector3.ZERO, 0.002)
	# scope: tube, bells, turrets, rings, lens
	var sy := 0.092
	cyl(gun, 0.02, 0.24, Vector3(0, sy, -0.08), _blued(), true, -1.0, 20)
	cyl(gun, 0.029, 0.07, Vector3(0, sy, -0.235), _blued(), true, 0.02, 20)
	cyl(gun, 0.026, 0.06, Vector3(0, sy, 0.065), _blued(), true, 0.02, 20)
	cyl(gun, 0.011, 0.024, Vector3(0, sy + 0.028, -0.09), _alu(), false, -1.0, 12)
	var side := cyl(gun, 0.011, 0.024, Vector3(0.028, sy, -0.09), _alu(), false, -1.0, 12)
	side.rotation.z = PI / 2.0
	for z in [-0.15, -0.01]:
		box(gun, Vector3(0.048, 0.012, 0.02), Vector3(0, sy - 0.014, z), _park(), Vector3.ZERO, 0.003)
		box(gun, Vector3(0.016, 0.03, 0.02), Vector3(0, 0.066, z), _park(), Vector3.ZERO, 0.003)
	var lens := cyl(gun, 0.025, 0.003, Vector3(0, sy, 0.096), _glass(Color(0.05, 0.12, 0.2)), true, -1.0, 20)
	lens.name = "Lens"
	cyl(gun, 0.027, 0.004, Vector3(0, sy, -0.271), _glass(Color(0.1, 0.25, 0.3)), true, -1.0, 20)
	if sniper:
		var bolt := Node3D.new(); bolt.name = "Bolt"
		gun.add_child(bolt)
		var arm := cyl(bolt, 0.006, 0.06, Vector3(0.035, 0.03, 0.02), _steel(), false)
		arm.rotation = Vector3(0, 0, PI / 2.0)
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.012; sm.height = 0.024
		knob.mesh = sm
		knob.material_override = _steel()
		knob.position = Vector3(0.068, 0.03, 0.02)
		bolt.add_child(knob)
		for sx in [-1.0, 1.0]:
			box(gun, Vector3(0.008, 0.008, 0.16), Vector3(sx * 0.012, -0.02, -0.42), _park(), Vector3(0, sx * 0.08, 0), 0.002)   # folded bipod
	_marker(gun, "Muzzle", Vector3(0, 0.03, -0.23 - bl - (0.05 if sniper else 0.0)))
	_marker(gun, "Sight", Vector3(0, sy, 0.1))
	box(mag, Vector3(0.028, 0.07, 0.07), Vector3(0, -0.04, -0.08), _steel(), Vector3.ZERO, 0.004)
	box(mag, Vector3(0.032, 0.01, 0.075), Vector3(0, -0.078, -0.08), _poly(), Vector3.ZERO, 0.003)
	_hand(gun, Vector3(0.0, -0.06, 0.055), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.01, -0.035, -0.32), Vector3(0, 0, 0.35), true)
	root.set_meta("hip", Vector3(0.17, -0.155, -0.36))
	root.set_meta("ads_dist", 0.12 if not sniper else 0.1)

static func _lmg(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.056, 0.07, 0.36), Vector3(0, 0.024, -0.08), _park(), Vector3.ZERO, 0.008)
	box(gun, Vector3(0.058, 0.018, 0.2), Vector3(0, 0.066, -0.06), _park(), Vector3.ZERO, 0.005)          # feed cover
	_rail(gun, -0.15, 0.03, 0.078, 0.022, _park())
	box(gun, Vector3(0.062, 0.06, 0.22), Vector3(0, 0.03, -0.35), _poly(), Vector3.ZERO, 0.01)            # handguard
	for i in 5:
		for sx in [-1.0, 1.0]:
			cyl(gun, 0.006, 0.004, Vector3(sx * 0.031, 0.032, -0.27 - i * 0.04), _dark(), false).rotation.z = PI / 2.0
	cyl(gun, 0.016, 0.3, Vector3(0, 0.035, -0.6), _blued(), true, -1.0, 18)
	_brake(gun, -0.76, 0.035, 0.018)
	_bore(gun, -0.786, 0.035, 0.007)
	box(gun, Vector3(0.012, 0.06, 0.13), Vector3(0, 0.1, -0.15), _park(), Vector3.ZERO, 0.004)            # carry handle
	box(gun, Vector3(0.007, 0.022, 0.007), Vector3(0, 0.072, -0.44), _steel(), Vector3.ZERO, 0.002)
	box(gun, Vector3(0.03, 0.014, 0.012), Vector3(0, 0.088, 0.04), _steel(), Vector3.ZERO, 0.002)
	box(gun, Vector3(0.05, 0.085, 0.24), Vector3(0, 0.0, 0.2), _poly(), Vector3.ZERO, 0.012)
	box(gun, Vector3(0.052, 0.09, 0.016), Vector3(0, -0.002, 0.325), _rubber(), Vector3.ZERO, 0.005)
	box(gun, Vector3(0.034, 0.1, 0.045), Vector3(0, -0.06, 0.02), _poly(), Vector3(0.3, 0, 0), 0.008)
	_trigger(gun, -0.01, -0.012, _park())
	for sx in [-1.0, 1.0]:
		box(gun, Vector3(0.009, 0.009, 0.2), Vector3(sx * 0.014, -0.005, -0.55), _park(), Vector3(0, sx * 0.06, 0), 0.002)
	box(gun, Vector3(0.06, 0.01, 0.3), Vector3(0, -0.02, -0.1), rm, Vector3.ZERO, 0.003)
	_marker(gun, "Muzzle", Vector3(0, 0.035, -0.79))
	_marker(gun, "Sight", Vector3(0, 0.083, 0.06))
	box(mag, Vector3(0.09, 0.1, 0.1), Vector3(-0.07, -0.06, -0.1), _odg(), Vector3.ZERO, 0.01)          # box mag
	box(mag, Vector3(0.094, 0.012, 0.104), Vector3(-0.07, -0.01, -0.1), _park(), Vector3.ZERO, 0.003)
	for i in 6:
		cyl(mag, 0.005, 0.03, Vector3(-0.03 + i * 0.0, -0.005 + i * 0.006, -0.1), _brass(), false).rotation = Vector3(0, 0, PI / 2.0 + i * 0.1)   # belt
	_hand(gun, Vector3(0.0, -0.068, 0.04), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.01, -0.03, -0.34), Vector3(0, 0, 0.35), true)
	root.set_meta("hip", Vector3(0.18, -0.17, -0.37))
	root.set_meta("ads_dist", 0.22)

static func _crossbow(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.04, 0.045, 0.5), Vector3(0, 0.0, -0.12), _wood(), Vector3.ZERO, 0.01)
	box(gun, Vector3(0.02, 0.006, 0.4), Vector3(0, 0.026, -0.15), _park(), Vector3.ZERO, 0.002)            # flight rail
	for sx in [-1.0, 1.0]:
		var limb := box(gun, Vector3(0.17, 0.016, 0.034), Vector3(sx * 0.09, 0.012, -0.34), _poly(), Vector3(0, sx * -0.35, 0), 0.006)
		limb.rotation.y = sx * -0.35
		var cam := cyl(gun, 0.02, 0.012, Vector3(sx * 0.17, 0.012, -0.3), _alu(), false, -1.0, 14)
		cam.rotation = Vector3.ZERO
	box(gun, Vector3(0.04, 0.06, 0.04), Vector3(0, 0.0, -0.37), _park(), Vector3.ZERO, 0.006)             # riser
	box(gun, Vector3(0.04, 0.065, 0.2), Vector3(0, -0.018, 0.18), _wood(), Vector3.ZERO, 0.012)
	box(gun, Vector3(0.042, 0.07, 0.014), Vector3(0, -0.018, 0.286), _rubber(), Vector3.ZERO, 0.004)
	box(gun, Vector3(0.03, 0.08, 0.04), Vector3(0, -0.05, 0.02), _poly(), Vector3(0.3, 0, 0), 0.007)
	_trigger(gun, 0.0, -0.01, _park())
	box(gun, Vector3(0.042, 0.005, 0.3), Vector3(0, -0.012, -0.1), rm, Vector3.ZERO, 0.002)
	var string_mi := box(gun, Vector3(0.34, 0.003, 0.003), Vector3(0, 0.028, -0.2), mat("string", Color(0.85, 0.82, 0.7), 0.0, 0.8), Vector3.ZERO, 0.0)
	string_mi.name = "String"
	var sy := _reflex(gun, -0.02, 0.03)
	var arrow := Node3D.new(); arrow.name = "Arrow"
	gun.add_child(arrow)
	cyl(arrow, 0.0045, 0.38, Vector3(0, 0.034, -0.18), mat("shaft", Color(0.18, 0.18, 0.2), 0.6, 0.35))
	cyl(arrow, 0.008, 0.03, Vector3(0, 0.034, -0.385), _steel(), true, 0.0)
	for k in 3:
		var fl := box(arrow, Vector3(0.002, 0.012, 0.05), Vector3(0, 0.034, -0.01), mat("fletchvm", Color(0.85, 0.2, 0.12), 0.0, 0.8), Vector3(0, 0, TAU * k / 3.0), 0.0)
		fl.position += Vector3(cos(TAU * k / 3.0 + PI / 2.0), sin(TAU * k / 3.0 + PI / 2.0), 0) * 0.006
	_marker(gun, "Muzzle", Vector3(0, 0.03, -0.4))
	_marker(gun, "Sight", Vector3(0, sy, 0.01))
	_hand(gun, Vector3(0.0, -0.05, 0.04), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.015, -0.03, -0.2), Vector3(0, 0, 0.3), true)
	root.set_meta("hip", Vector3(0.16, -0.14, -0.34))
	root.set_meta("ads_dist", 0.24)

static func build_melee(e: Dictionary) -> Node3D:
	var id: String = e.get("id", "fists")
	var root := Node3D.new()
	root.name = "VM_melee_" + id
	var swing := Node3D.new(); swing.name = "Swing"
	root.add_child(swing)
	var rm := _rarity_mat(e)
	match id:
		"knife":
			box(swing, Vector3(0.022, 0.03, 0.1), Vector3(0, 0, -0.03), _poly())
			box(swing, Vector3(0.008, 0.03, 0.16), Vector3(0, 0.005, -0.15), _steel())
			box(swing, Vector3(0.024, 0.006, 0.02), Vector3(0, 0, -0.07), rm)
		"machete":
			box(swing, Vector3(0.024, 0.03, 0.11), Vector3(0, 0, -0.03), _wood())
			box(swing, Vector3(0.006, 0.05, 0.42), Vector3(0, 0.012, -0.29), _steel())
			box(swing, Vector3(0.026, 0.006, 0.02), Vector3(0, 0, -0.08), rm)
		"wrench":
			box(swing, Vector3(0.03, 0.03, 0.4), Vector3(0, 0, -0.17), mat("red", Color(0.55, 0.1, 0.08), 0.6, 0.5))
			box(swing, Vector3(0.05, 0.09, 0.05), Vector3(0, 0.03, -0.38), _steel())
			box(swing, Vector3(0.032, 0.006, 0.03), Vector3(0, 0, -0.05), rm)
		"bat":
			cyl(swing, 0.016, 0.6, Vector3(0, 0, -0.27), _wood(), true, 0.026)
			for k in 6:
				box(swing, Vector3(0.006, 0.07, 0.006), Vector3(0, 0, -0.38 - k * 0.035), _steel(), Vector3(0, 0, k * 0.6))
			box(swing, Vector3(0.03, 0.006, 0.03), Vector3(0, 0, -0.03), rm)
		"axe":
			box(swing, Vector3(0.028, 0.03, 0.62), Vector3(0, 0, -0.27), _wood())
			box(swing, Vector3(0.012, 0.14, 0.1), Vector3(0, 0.06, -0.55), mat("red", Color(0.62, 0.08, 0.06), 0.6, 0.4))
			box(swing, Vector3(0.008, 0.06, 0.08), Vector3(0, 0.15, -0.55), _steel())
			box(swing, Vector3(0.03, 0.006, 0.03), Vector3(0, 0, -0.05), rm)
		"sledge":
			box(swing, Vector3(0.03, 0.03, 0.82), Vector3(0, 0, -0.36), _wood())
			box(swing, Vector3(0.09, 0.09, 0.2), Vector3(0, 0, -0.78), _steel(), Vector3(0, PI / 2.0, 0))
			box(swing, Vector3(0.032, 0.006, 0.03), Vector3(0, 0, -0.06), rm)
		"claws":
			_claw_arm(swing, mat("fur", Color(0.22, 0.16, 0.11), 0.0, 1.0), mat("claw", Color(0.85, 0.82, 0.72), 0.2, 0.3), 0.06)
		"vamp_claws":
			_claw_arm(swing, mat("pale", Color(0.82, 0.8, 0.84), 0.0, 0.6), mat("nail", Color(0.15, 0.05, 0.07), 0.3, 0.3), 0.04)
		"rot_fists":
			_claw_arm(swing, mat("rot", Color(0.38, 0.45, 0.3), 0.0, 0.9), mat("bone", Color(0.75, 0.72, 0.6), 0.0, 0.6), 0.025)
		_:
			box(swing, Vector3(0.06, 0.06, 0.08), Vector3(0, 0, -0.02), _glove())
	if id != "claws" and id != "vamp_claws" and id != "rot_fists":
		_hand(swing, Vector3(0, -0.005, 0.0), Vector3.ZERO)
	root.set_meta("hip", Vector3(0.2, -0.17, -0.3))
	return root

static func _claw_arm(parent: Node3D, skin: Material, claw: Material, claw_len: float) -> void:
	box(parent, Vector3(0.08, 0.07, 0.1), Vector3(0, 0, -0.02), skin)
	box(parent, Vector3(0.085, 0.085, 0.45), Vector3(0, -0.01, 0.24), skin)
	for k in 4:
		var x := -0.03 + k * 0.02
		box(parent, Vector3(0.012, 0.012, claw_len + 0.03), Vector3(x, 0.02, -0.08 - claw_len * 0.5), claw, Vector3(-0.3, 0, 0))

static func build_item(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"frag":
			var g := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.035; sm.height = 0.07
			g.mesh = sm
			g.material_override = mat("frag", Color(0.25, 0.3, 0.2), 0.3, 0.6)
			root.add_child(g)
			box(root, Vector3(0.015, 0.03, 0.015), Vector3(0, 0.04, 0), _steel())
		"molotov":
			cyl(root, 0.025, 0.11, Vector3.ZERO, mat("bottle", Color(0.35, 0.5, 0.25), 0.2, 0.15), false)
			cyl(root, 0.012, 0.05, Vector3(0, 0.07, 0), mat("rag", Color(0.8, 0.7, 0.5), 0.0, 1.0), false)
			var flame := box(root, Vector3(0.03, 0.04, 0.03), Vector3(0, 0.105, 0), mat("flame", Color(1.0, 0.55, 0.1), 0.0, 1.0, 4.0))
			flame.name = "Flame"
		"noisemaker":
			box(root, Vector3(0.05, 0.03, 0.07), Vector3.ZERO, mat("noisebox", Color(0.75, 0.62, 0.1), 0.3, 0.5))
			box(root, Vector3(0.01, 0.01, 0.01), Vector3(0, 0.02, 0.02), mat("led", Color(1, 0.1, 0.1), 0.0, 0.5, 5.0))
		"bandage":
			cyl(root, 0.03, 0.05, Vector3.ZERO, mat("band", Color(0.92, 0.9, 0.85), 0.0, 1.0), false)
		_:
			cyl(root, 0.012, 0.12, Vector3.ZERO, mat("syr", Color(0.8, 0.9, 1.0), 0.2, 0.2, 0.6))
			cyl(root, 0.002, 0.04, Vector3(0, 0, -0.08), _steel())
	_hand(root, Vector3(0, -0.04, 0.02), Vector3(0.2, 0, 0))
	return root
