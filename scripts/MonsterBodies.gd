class_name MonsterBodies
extends RefCounted
# Procedural bodies with animation pivots. Humanoids: hips > torso > head/arms, hips > legs.
# Quadrupeds: body > head + four legs + tail. Returns a dict of parts for the animator.

static var _cache := {}

static func m(col: Color, rough := 0.85, emit := 0.0, metal := 0.0) -> StandardMaterial3D:
	var k := "%s_%.2f_%.2f_%.2f" % [col.to_html(), rough, emit, metal]
	if _cache.has(k):
		return _cache[k]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emit
	_cache[k] = mat
	return mat

static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, parts: Dictionary, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	parts.meshes.append(mi)
	return mi

static func _sph(parent: Node3D, r: float, pos: Vector3, mat: Material, parts: Dictionary) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if r < 0.05 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	parts.meshes.append(mi)
	return mi

static func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

static func build(body: String, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Dictionary
	match body:
		"zombie": parts = _zombie(rng, 1.0, 1.0, "walker")
		"zombie_lean": parts = _zombie(rng, 0.86, 1.02, "runner")
		"zombie_big": parts = _zombie(rng, 1.45, 1.05, "brute")
		"zombie_thin": parts = _zombie(rng, 0.8, 1.08, "screamer")
		"zombie_fat": parts = _zombie(rng, 1.75, 0.98, "bloater")
		"giant": parts = _zombie(rng, 1.3, 1.0, "goliath")
		"gaunt": parts = _gaunt()
		"wolf": parts = _wolfman(rng)
		"vampire": parts = _vampire(rng)
		"raider", "psycho", "raider_boss", "guard": parts = _raider(rng, body)
		"boar": parts = _quad(rng, "boar")
		"deer": parts = _quad(rng, "deer")
		_: parts = _zombie(rng, 1.0, 1.0, "walker")
	# one draw per (limb, material) instead of one per box
	var keep: Array = parts.eyes.duplicate()
	for k in ["jaw", "saw"]:
		if parts.has(k):
			keep.append(parts[k])
	parts.meshes = merge_children(parts.root, keep)
	for mi in parts.meshes:
		(mi as GeometryInstance3D).visibility_range_end = 140.0
	return parts

# Merge sibling MeshInstance3Ds that share a material into one mesh, recursively per
# pivot, so animated limbs stay separate. Returns every mesh left under `node`.
static func merge_children(node: Node3D, keep: Array = []) -> Array:
	var out := []
	var groups := {}
	for c in node.get_children():
		if c is MeshInstance3D and c.get_child_count() == 0 and not (c in keep) and (c as MeshInstance3D).mesh is PrimitiveMesh:
			var mat: Material = (c as MeshInstance3D).material_override
			if not groups.has(mat):
				groups[mat] = []
			groups[mat].append(c)
		elif c is MeshInstance3D:
			out.append(c)
		elif c is Node3D:
			out.append_array(merge_children(c, keep))
	for mat in groups:
		var list: Array = groups[mat]
		if list.size() < 2:
			out.append(list[0])
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			st.append_from((mi as MeshInstance3D).mesh, 0, (mi as MeshInstance3D).transform)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = mat
		node.add_child(merged)
		for mi in list:
			node.remove_child(mi)
			mi.free()
		out.append(merged)
	return out

# ---------------- humanoid core ----------------
static func _humanoid(o: Dictionary) -> Dictionary:
	var parts := {"meshes": [], "quad": false, "eyes": []}
	var root := Node3D.new()
	parts.root = root
	var h: float = o.get("h", 1.0)
	var g: float = o.get("g", 1.0)
	var al: float = o.get("arm", 1.0)
	var ll: float = o.get("leg", 1.0)
	var skin: Material = o.skin
	var shirt: Material = o.shirt
	var pants: Material = o.pants
	var hips := _pivot(root, Vector3(0, 0.93 * h * ll, 0))
	parts.hips = hips
	parts.hips_y = 0.93 * h * ll
	var torso := _pivot(hips, Vector3(0, 0.05 * h, 0))
	parts.torso = torso
	_box(torso, Vector3(0.42 * g, 0.24 * h, 0.24 * g), Vector3(0, 0.02, 0), pants, parts)                 # pelvis
	parts.chest = _box(torso, Vector3(0.46 * g, 0.5 * h, 0.27 * g), Vector3(0, 0.38 * h, 0), shirt, parts)
	var neck_y := 0.7 * h
	var head := _pivot(torso, Vector3(0, neck_y, 0))
	parts.head = head
	var hs: float = o.get("head", 1.0) * h
	_box(head, Vector3(0.1, 0.08, 0.1) * hs, Vector3(0, 0.02, 0), skin, parts)                          # neck
	parts.head_mesh = _box(head, Vector3(0.22, 0.26, 0.24) * hs, Vector3(0, 0.16 * hs, 0.0), skin, parts)
	parts.head_center = Vector3(0, 0.16 * hs, 0)
	parts.head_r = 0.17 * hs
	var shoulder_y := 0.6 * h
	for side in [-1.0, 1.0]:
		var arm := _pivot(torso, Vector3(side * 0.29 * g, shoulder_y, 0))
		_box(arm, Vector3(0.13 * g, 0.36 * h * al, 0.13 * g), Vector3(0, -0.17 * h * al, 0), shirt, parts)
		_box(arm, Vector3(0.11, 0.34 * h * al, 0.11), Vector3(0, -0.5 * h * al, 0), skin, parts)
		_box(arm, Vector3(0.1, 0.12, 0.08), Vector3(0, -0.72 * h * al, 0), skin, parts)
		parts["arm_l" if side < 0 else "arm_r"] = arm
		var leg := _pivot(hips, Vector3(side * 0.12 * g, 0, 0))
		_box(leg, Vector3(0.16 * g, 0.48 * h * ll, 0.17 * g), Vector3(0, -0.24 * h * ll, 0), pants, parts)
		_box(leg, Vector3(0.14, 0.44 * h * ll, 0.15), Vector3(0, -0.68 * h * ll, 0), pants, parts)
		_box(leg, Vector3(0.14, 0.09, 0.26), Vector3(0, -0.89 * h * ll, -0.05), o.get("boots", pants), parts)
		parts["leg_l" if side < 0 else "leg_r"] = leg
	return parts

static func _eyes(parts: Dictionary, col: Color, energy: float, spread := 0.055, y := 0.18, size := 0.022) -> void:
	var head: Node3D = parts.head
	var e := m(col, 0.4, energy)
	for side in [-1.0, 1.0]:
		var eye := _sph(head, size, Vector3(side * spread, y, -0.12), e, parts)
		parts.eyes.append(eye)

# ---------------- undead ----------------
static func _zombie(rng: RandomNumberGenerator, girth: float, height: float, kind: String) -> Dictionary:
	var skins := [Color(0.48, 0.52, 0.42), Color(0.55, 0.5, 0.45), Color(0.42, 0.45, 0.4), Color(0.6, 0.55, 0.5), Color(0.38, 0.4, 0.36)]
	var shirts := [Color(0.3, 0.32, 0.4), Color(0.45, 0.2, 0.18), Color(0.25, 0.3, 0.22), Color(0.5, 0.45, 0.35), Color(0.2, 0.2, 0.22), Color(0.55, 0.52, 0.48), Color(0.15, 0.25, 0.4)]
	var pants := [Color(0.18, 0.2, 0.3), Color(0.25, 0.22, 0.18), Color(0.12, 0.12, 0.13), Color(0.35, 0.3, 0.22)]
	var skin_c: Color = skins[rng.randi() % skins.size()]
	var skin := m(skin_c, 0.9)
	var shirt := m((shirts[rng.randi() % shirts.size()] as Color).darkened(rng.randf_range(0.0, 0.3)), 0.95)
	var pant := m(pants[rng.randi() % pants.size()], 0.95)
	var o := {"h": height, "g": girth, "skin": skin, "shirt": shirt, "pants": pant}
	if kind == "screamer":
		o["arm"] = 1.15
		o["head"] = 1.1
	if kind == "goliath":
		o["arm"] = 1.2
		skin = m(Color(0.45, 0.42, 0.38), 0.9)
		o.skin = skin
		o.shirt = skin
	if kind == "bloater":
		o.shirt = m(skin_c.lerp(Color(0.5, 0.55, 0.3), 0.4), 0.7)
	var parts := _humanoid(o)
	parts.kind = kind
	var torso: Node3D = parts.torso
	var gore := m(Color(0.35, 0.05, 0.05), 0.6)
	# wounds & tatters
	for i in rng.randi_range(1, 3):
		_box(torso, Vector3(rng.randf_range(0.06, 0.14), rng.randf_range(0.06, 0.14), 0.02), Vector3(rng.randf_range(-0.18, 0.18) * girth, rng.randf_range(0.2, 0.55) * height, -0.14 * girth), gore, parts)
	_eyes(parts, Color(0.95, 0.9, 0.55), 0.8 if kind != "runner" else 2.5)
	match kind:
		"screamer":
			var jaw := _box(parts.head, Vector3(0.16, 0.16, 0.1), Vector3(0, 0.02, -0.08), gore, parts)
			parts.jaw = jaw
		"bloater":
			var pus := m(Color(0.6, 0.95, 0.25), 0.4, 1.6)
			for i in 9:
				_sph(torso, rng.randf_range(0.05, 0.11), Vector3(rng.randf_range(-0.25, 0.25) * girth, rng.randf_range(0.15, 0.6), rng.randf_range(-0.16, 0.16) * girth), pus, parts)
			_sph(torso, 0.34 * girth * 0.6, Vector3(0, 0.3, -0.08), o.shirt, parts)
		"brute":
			var plate := m(Color(0.32, 0.3, 0.28), 0.6, 0.0, 0.5)
			_box(torso, Vector3(0.52 * girth, 0.3, 0.32 * girth), Vector3(0, 0.5 * height, 0), plate, parts)
			_box(parts.head, Vector3(0.26, 0.12, 0.26), Vector3(0, 0.28, 0), plate, parts)
		"goliath":
			var bone := m(Color(0.85, 0.82, 0.72), 0.6)
			for i in 7:
				_box(torso, Vector3(0.06, rng.randf_range(0.25, 0.5), 0.06), Vector3(rng.randf_range(-0.3, 0.3) * girth, rng.randf_range(0.4, 0.7) * height, 0.16 * girth), bone, parts, Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.5, 0.5)))
			_sph(torso, 0.2, Vector3(0.28 * girth, 0.62, -0.05), gore, parts)
	if kind == "walker" and rng.randf() < 0.12:
		(parts.arm_l as Node3D).visible = false   # lost an arm somewhere
	return parts

static func _gaunt() -> Dictionary:
	var skin := m(Color(0.86, 0.84, 0.8), 0.55)
	var o := {"h": 1.25, "g": 0.7, "arm": 1.9, "leg": 1.35, "head": 0.85, "skin": skin, "shirt": skin, "pants": skin}
	var parts := _humanoid(o)
	parts.kind = "gaunt"
	var head: Node3D = parts.head
	_box(head, Vector3(0.03, 0.18, 0.02), Vector3(0, 0.12, -0.11), m(Color(0.25, 0.02, 0.03), 0.4), parts)   # vertical mouth
	var torso: Node3D = parts.torso
	var rib := m(Color(0.7, 0.68, 0.64), 0.6)
	for i in 5:
		_box(torso, Vector3(0.34, 0.02, 0.02), Vector3(0, 0.25 + i * 0.07, -0.135), rib, parts)
	# long fingers
	for side in ["arm_l", "arm_r"]:
		var arm: Node3D = parts[side]
		for k in 3:
			_box(arm, Vector3(0.02, 0.22, 0.02), Vector3(-0.035 + k * 0.035, -1.55, -0.03), rib, parts)
	return parts

static func _wolfman(rng: RandomNumberGenerator) -> Dictionary:
	var furs := [Color(0.22, 0.18, 0.14), Color(0.3, 0.28, 0.26), Color(0.16, 0.14, 0.13), Color(0.38, 0.3, 0.22)]
	var fur := m(furs[rng.randi() % furs.size()], 1.0)
	var o := {"h": 1.18, "g": 1.25, "arm": 1.15, "skin": fur, "shirt": fur, "pants": fur, "head": 1.1}
	var parts := _humanoid(o)
	parts.kind = "wolf"
	var head: Node3D = parts.head
	_box(head, Vector3(0.14, 0.12, 0.22), Vector3(0, 0.1, -0.2), fur, parts)                 # snout
	_box(head, Vector3(0.1, 0.05, 0.08), Vector3(0, 0.12, -0.32), m(Color(0.05, 0.04, 0.04), 0.5), parts)
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.05, 0.12, 0.04), Vector3(side * 0.09, 0.34, 0.02), fur, parts, Vector3(0, 0, side * 0.3))
	_box(head, Vector3(0.12, 0.03, 0.12), Vector3(0, 0.03, -0.25), m(Color(0.9, 0.88, 0.8), 0.4), parts)   # fangs
	_eyes(parts, Color(1.0, 0.75, 0.1), 4.0, 0.06, 0.2, 0.024)
	var tail := _pivot(parts.hips, Vector3(0, 0.0, 0.16))
	_box(tail, Vector3(0.1, 0.1, 0.5), Vector3(0, -0.05, 0.25), fur, parts, Vector3(0.5, 0, 0))
	parts.tail = tail
	var claw := m(Color(0.9, 0.88, 0.8), 0.4)
	for side in ["arm_l", "arm_r"]:
		var arm: Node3D = parts[side]
		for k in 3:
			_box(arm, Vector3(0.02, 0.1, 0.02), Vector3(-0.03 + k * 0.03, -0.92, -0.04), claw, parts)
	return parts

static func _vampire(rng: RandomNumberGenerator) -> Dictionary:
	var skin := m(Color(0.86, 0.84, 0.88), 0.45)
	var coat := m([Color(0.08, 0.07, 0.09), Color(0.25, 0.05, 0.08), Color(0.1, 0.1, 0.16)][rng.randi() % 3], 0.6)
	var o := {"h": 1.04, "g": 0.92, "skin": skin, "shirt": coat, "pants": m(Color(0.06, 0.06, 0.07), 0.7)}
	var parts := _humanoid(o)
	parts.kind = "vampire"
	_box(parts.torso, Vector3(0.5, 1.15, 0.06), Vector3(0, 0.1, 0.16), coat, parts)          # cloak
	_box(parts.head, Vector3(0.24, 0.08, 0.26), Vector3(0, 0.3, 0.01), m(Color(0.05, 0.05, 0.06), 0.4), parts)
	_eyes(parts, Color(1.0, 0.08, 0.1), 5.0)
	return parts

static func _raider(rng: RandomNumberGenerator, body: String) -> Dictionary:
	var skins := [Color(0.72, 0.53, 0.4), Color(0.55, 0.38, 0.26), Color(0.4, 0.28, 0.2), Color(0.82, 0.66, 0.52)]
	var skin := m(skins[rng.randi() % skins.size()], 0.75)
	var leather := m([Color(0.3, 0.2, 0.12), Color(0.18, 0.16, 0.14), Color(0.4, 0.3, 0.2)][rng.randi() % 3], 0.8)
	var pants := m([Color(0.2, 0.22, 0.26), Color(0.3, 0.25, 0.18), Color(0.15, 0.15, 0.15)][rng.randi() % 3], 0.9)
	var g := 1.0
	var h := 1.0
	if body == "raider_boss":
		g = 1.35
		h = 1.08
	var shirt: Material = skin if body == "psycho" else leather
	if body == "guard":
		shirt = m(Color(0.28, 0.32, 0.24), 0.85)
		pants = m(Color(0.22, 0.25, 0.2), 0.9)
	var parts := _humanoid({"h": h, "g": g, "skin": skin, "shirt": shirt, "pants": pants, "boots": m(Color(0.1, 0.08, 0.06), 0.9)})
	parts.kind = body
	var head: Node3D = parts.head
	var torso: Node3D = parts.torso
	var metal := m(Color(0.45, 0.43, 0.4), 0.5, 0.0, 0.6)
	if body == "guard":
		_box(head, Vector3(0.28, 0.13, 0.3), Vector3(0, 0.29, 0), m(Color(0.25, 0.28, 0.2), 0.7), parts)
		_box(torso, Vector3(0.5, 0.36, 0.32), Vector3(0, 0.42, 0), m(Color(0.2, 0.22, 0.18), 0.8), parts)
		_eyes(parts, Color(0.9, 0.85, 0.7), 0.2)
	else:
		# Borderlands-style lunatic mask with glowing slits + spikes
		var mask := m(Color(0.9, 0.88, 0.82), 0.6) if body != "raider" else m(Color(0.6, 0.15, 0.1), 0.7)
		_box(head, Vector3(0.24, 0.24, 0.04), Vector3(0, 0.16, -0.13), mask, parts)
		_box(head, Vector3(0.05, 0.015, 0.02), Vector3(-0.05, 0.19, -0.155), m(Color(1.0, 0.45, 0.1), 0.4, 4.0), parts)
		_box(head, Vector3(0.05, 0.015, 0.02), Vector3(0.05, 0.19, -0.155), m(Color(1.0, 0.45, 0.1), 0.4, 4.0), parts)
		for i in (5 if body != "raider_boss" else 8):
			_box(head, Vector3(0.03, 0.14, 0.03), Vector3(0, 0.34, -0.08 + i * 0.045), metal, parts, Vector3(-0.3 + i * 0.12, 0, 0))
		for side in [-1.0, 1.0]:
			_box(torso, Vector3(0.18, 0.08, 0.2), Vector3(side * 0.3 * g, 0.62, 0), metal, parts)
			_box(torso, Vector3(0.03, 0.14, 0.03), Vector3(side * 0.34 * g, 0.72, 0), metal, parts, Vector3(0, 0, side * -0.4))
	# weapon in hand
	var arm_r: Node3D = parts.arm_r
	match body:
		"psycho":
			var axe := _pivot(arm_r, Vector3(0, -0.72, -0.05))
			axe.rotation.x = -PI * 0.5
			_box(axe, Vector3(0.04, 0.04, 0.6), Vector3(0, 0, -0.25), m(Color(0.3, 0.2, 0.12), 0.8), parts)
			var disk := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.16
			cm.bottom_radius = 0.16
			cm.height = 0.02
			disk.mesh = cm
			disk.material_override = metal
			disk.rotation.z = PI / 2.0
			disk.position = Vector3(0, 0, -0.58)
			axe.add_child(disk)
			parts.meshes.append(disk)
			parts.saw = disk
		_:
			var gun := _pivot(arm_r, Vector3(-0.08, -0.7, -0.05))
			gun.rotation.x = -PI * 0.5
			var long := 0.75 if body != "raider_boss" else 0.95
			_box(gun, Vector3(0.07, 0.1, long), Vector3(0, 0, -long * 0.35), m(Color(0.15, 0.15, 0.16), 0.5, 0.0, 0.6), parts)
			if body == "raider_boss":
				_box(gun, Vector3(0.14, 0.14, 0.16), Vector3(-0.08, -0.08, -0.2), m(Color(0.5, 0.45, 0.3), 0.7), parts)
			parts.muzzle = _pivot(gun, Vector3(0, 0, -long * 0.8))
	return parts

# ---------------- wildlife ----------------
static func _quad(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var parts := {"meshes": [], "quad": true, "eyes": [], "kind": kind}
	var root := Node3D.new()
	parts.root = root
	var col := Color(0.35, 0.25, 0.2) if kind == "boar" else Color(0.55, 0.4, 0.26)
	var hide := m(col.darkened(rng.randf_range(0.0, 0.2)), 0.95)
	var leg_h := 0.42 if kind == "boar" else 0.85
	var body := _pivot(root, Vector3(0, leg_h + 0.2, 0))
	parts.torso = body
	parts.hips = body
	var bl := 1.0 if kind == "boar" else 1.1
	_box(body, Vector3(0.5, 0.45, bl) if kind == "boar" else Vector3(0.36, 0.4, bl), Vector3.ZERO, hide, parts)
	var head := _pivot(body, Vector3(0, 0.12 if kind == "boar" else 0.35, -bl * 0.5))
	parts.head = head
	if kind == "boar":
		parts.head_mesh = _box(head, Vector3(0.32, 0.3, 0.36), Vector3(0, -0.05, -0.15), hide, parts)
		var tusk := m(Color(0.92, 0.9, 0.8), 0.4)
		_box(head, Vector3(0.03, 0.1, 0.03), Vector3(-0.1, -0.08, -0.33), tusk, parts, Vector3(0.4, 0, 0))
		_box(head, Vector3(0.03, 0.1, 0.03), Vector3(0.1, -0.08, -0.33), tusk, parts, Vector3(0.4, 0, 0))
		parts.head_center = Vector3(0, -0.05, -0.15)
	else:
		_box(head, Vector3(0.12, 0.42, 0.14), Vector3(0, 0.12, 0.0), hide, parts, Vector3(0.3, 0, 0))
		parts.head_mesh = _box(head, Vector3(0.16, 0.16, 0.3), Vector3(0, 0.34, -0.12), hide, parts)
		var antler := m(Color(0.75, 0.7, 0.6), 0.6)
		for side in [-1.0, 1.0]:
			_box(head, Vector3(0.03, 0.3, 0.03), Vector3(side * 0.08, 0.55, -0.05), antler, parts, Vector3(0, 0, side * 0.5))
			_box(head, Vector3(0.03, 0.18, 0.03), Vector3(side * 0.16, 0.62, -0.12), antler, parts, Vector3(-0.5, 0, side * 0.2))
		parts.head_center = Vector3(0, 0.34, -0.12)
	parts.head_r = 0.18
	var legs := []
	for i in 4:
		var fx := -0.17 if i % 2 == 0 else 0.17
		var fz := -bl * 0.38 if i < 2 else bl * 0.38
		var leg := _pivot(body, Vector3(fx, -0.15, fz))
		_box(leg, Vector3(0.1, leg_h + 0.1, 0.1), Vector3(0, -(leg_h + 0.1) * 0.5, 0), hide, parts)
		legs.append(leg)
	parts.legs = legs
	return parts
