class_name Viewmodels
extends RefCounted
# Procedural first-person models. Every gun gets named sub-nodes the Player animates:
#   Gun (body + trigger hand), Mag (magazine + support hand), Muzzle (barrel tip),
#   Sight (the point that lines up with the screen center when aiming), and optional
#   Pump / Bolt / Slide / Arrow nodes for class-specific reload & cycle animations.
# Built at real-world scale; the Player scales the whole view rig down so it never clips.

static var _mats := {}

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

static func _steel() -> StandardMaterial3D: return mat("steel", Color(0.16, 0.165, 0.18), 0.85, 0.38)
static func _park() -> StandardMaterial3D: return mat("park", Color(0.24, 0.25, 0.23), 0.6, 0.55)
static func _poly() -> StandardMaterial3D: return mat("poly", Color(0.1, 0.1, 0.11), 0.1, 0.7)
static func _wood() -> StandardMaterial3D: return mat("wood", Color(0.4, 0.25, 0.13), 0.05, 0.6)
static func _tan() -> StandardMaterial3D: return mat("tan", Color(0.52, 0.45, 0.31), 0.15, 0.7)
static func _glove() -> StandardMaterial3D: return mat("glove", Color(0.16, 0.12, 0.09), 0.0, 0.85)
static func _skin() -> StandardMaterial3D: return mat("skin", Color(0.72, 0.53, 0.4), 0.0, 0.75)
static func _sleeve() -> StandardMaterial3D: return mat("sleeve", Color(0.24, 0.27, 0.32), 0.0, 0.9)

static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func cyl(parent: Node3D, r: float, length: float, pos: Vector3, m: Material, along_z := true, r2 := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r if r2 < 0.0 else r2
	cm.height = length
	cm.radial_segments = 10
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

# A gloved hand + forearm sleeve reaching back off-screen.
static func _hand(parent: Node3D, pos: Vector3, rot: Vector3, support := false) -> void:
	var h := Node3D.new()
	h.position = pos
	h.rotation = rot
	parent.add_child(h)
	box(h, Vector3(0.05, 0.06, 0.085), Vector3.ZERO, _glove())
	box(h, Vector3(0.048, 0.02, 0.05), Vector3(0, 0.035, -0.02), _skin())          # knuckles
	box(h, Vector3(0.018, 0.02, 0.05), Vector3(-0.03 if not support else 0.03, 0.01, -0.02), _skin())  # thumb
	var arm := box(h, Vector3(0.065, 0.065, 0.42), Vector3(0, -0.01, 0.25), _sleeve())
	arm.rotation.x = 0.12

static func _rarity_mat(e: Dictionary) -> StandardMaterial3D:
	var r := int(e.get("rarity", 0))
	var c: Color = ItemDB.rarity_color(r)
	return mat("rar", c, 0.4, 0.4, 0.0 if r < 3 else (0.8 if r == 3 else 1.8))

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
		"pistol": _pistol(root, gun, mag, rm, false)
		"revolver": _pistol(root, gun, mag, rm, true)
		"smg": _smg(root, gun, mag, rm)
		"ar": _ar(root, gun, mag, rm)
		"shotgun": _shotgun(root, gun, mag, rm)
		"dmr": _rifle(root, gun, mag, rm, false)
		"sniper": _rifle(root, gun, mag, rm, true)
		"lmg": _lmg(root, gun, mag, rm)
		"crossbow": _crossbow(root, gun, mag, rm)
		_: _pistol(root, gun, mag, rm, false)
	if "hushed" in e.get("perks", []):
		var muz := root.get_node("Gun/Muzzle") as Node3D
		cyl(gun, 0.022, 0.16, muz.position + Vector3(0, 0, -0.07), _poly())
		muz.position.z -= 0.15
	return root

static func _pistol(root: Node3D, gun: Node3D, mag: Node3D, rm: Material, revolver: bool) -> void:
	if revolver:
		cyl(gun, 0.016, 0.2, Vector3(0, 0.035, -0.17), _steel())
		box(gun, Vector3(0.026, 0.012, 0.19), Vector3(0, 0.052, -0.16), _steel())       # top strap
		cyl(gun, 0.03, 0.05, Vector3(0, 0.03, -0.045), _steel())                          # cylinder
		box(gun, Vector3(0.03, 0.05, 0.07), Vector3(0, 0.025, 0.0), _steel())             # frame
		box(gun, Vector3(0.03, 0.1, 0.045), Vector3(0, -0.04, 0.03), _wood(), Vector3(0.35, 0, 0))
		box(gun, Vector3(0.006, 0.012, 0.012), Vector3(0, 0.064, -0.255), _steel())       # front sight
		box(gun, Vector3(0.024, 0.006, 0.03), Vector3(0, 0.056, -0.05), rm)
		_marker(gun, "Muzzle", Vector3(0, 0.035, -0.28))
		_marker(gun, "Sight", Vector3(0, 0.066, 0.0))
		var cylmag := cyl(mag, 0.028, 0.045, Vector3(0, 0.03, -0.045), _steel())
		cylmag.name = "Drum"
	else:
		var slide := Node3D.new(); slide.name = "Slide"
		gun.add_child(slide)
		box(slide, Vector3(0.032, 0.036, 0.19), Vector3(0, 0.04, -0.09), _steel())
		box(slide, Vector3(0.006, 0.01, 0.01), Vector3(0, 0.063, -0.18), _steel())         # front sight
		box(slide, Vector3(0.026, 0.01, 0.012), Vector3(0, 0.063, -0.005), _steel())       # rear sight
		box(gun, Vector3(0.03, 0.025, 0.17), Vector3(0, 0.012, -0.08), _poly())            # frame
		box(gun, Vector3(0.03, 0.1, 0.045), Vector3(0, -0.04, 0.0), _poly(), Vector3(0.28, 0, 0))
		box(gun, Vector3(0.033, 0.006, 0.15), Vector3(0, 0.023, -0.09), rm)
		_marker(gun, "Muzzle", Vector3(0, 0.04, -0.2))
		_marker(gun, "Sight", Vector3(0, 0.069, 0.0))
		box(mag, Vector3(0.024, 0.09, 0.035), Vector3(0, -0.06, 0.008), _steel(), Vector3(0.28, 0, 0))
	_hand(gun, Vector3(0.0, -0.045, 0.02), Vector3(0.28, 0, -0.08))
	_hand(mag, Vector3(-0.022, -0.055, 0.0), Vector3(0.2, 0.2, 0.25), true)
	root.set_meta("hip", Vector3(0.15, -0.135, -0.33))
	root.set_meta("ads_dist", 0.24)

static func _smg(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.042, 0.055, 0.26), Vector3(0, 0.02, -0.1), _park())
	cyl(gun, 0.022, 0.13, Vector3(0, 0.025, -0.29), _poly())                               # shroud
	box(gun, Vector3(0.03, 0.09, 0.04), Vector3(0, -0.045, 0.0), _poly(), Vector3(0.3, 0, 0))
	box(gun, Vector3(0.03, 0.04, 0.14), Vector3(0, 0.0, 0.1), _poly())                     # stub stock
	box(gun, Vector3(0.044, 0.006, 0.2), Vector3(0, 0.0, -0.1), rm)
	# reflex sight
	box(gun, Vector3(0.036, 0.008, 0.05), Vector3(0, 0.052, -0.05), _poly())
	box(gun, Vector3(0.004, 0.035, 0.004), Vector3(-0.016, 0.07, -0.07), _poly())
	box(gun, Vector3(0.004, 0.035, 0.004), Vector3(0.016, 0.07, -0.07), _poly())
	box(gun, Vector3(0.036, 0.004, 0.004), Vector3(0, 0.088, -0.07), _poly())
	box(gun, Vector3(0.004, 0.004, 0.002), Vector3(0, 0.072, -0.07), mat("dot", Color(1, 0.15, 0.1), 0.0, 0.5, 6.0))
	_marker(gun, "Muzzle", Vector3(0, 0.025, -0.36))
	_marker(gun, "Sight", Vector3(0, 0.072, -0.03))
	box(mag, Vector3(0.026, 0.13, 0.035), Vector3(0, -0.07, -0.1), _steel(), Vector3(0.08, 0, 0))
	_hand(gun, Vector3(0.0, -0.05, 0.025), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.02, -0.035, -0.2), Vector3(0, 0.1, 0.3), true)
	root.set_meta("hip", Vector3(0.16, -0.14, -0.34))
	root.set_meta("ads_dist", 0.2)

static func _ar(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.045, 0.065, 0.3), Vector3(0, 0.02, -0.08), _park())                 # receiver
	box(gun, Vector3(0.05, 0.055, 0.22), Vector3(0, 0.025, -0.32), _tan())                 # handguard
	cyl(gun, 0.011, 0.2, Vector3(0, 0.03, -0.5), _steel())
	box(gun, Vector3(0.02, 0.03, 0.04), Vector3(0, 0.03, -0.6), _steel())                  # muzzle brake
	box(gun, Vector3(0.032, 0.1, 0.04), Vector3(0, -0.05, 0.0), _poly(), Vector3(0.3, 0, 0))
	box(gun, Vector3(0.04, 0.07, 0.2), Vector3(0, 0.0, 0.17), _tan())                       # stock
	box(gun, Vector3(0.047, 0.008, 0.26), Vector3(0, -0.012, -0.08), rm)
	# holo sight
	box(gun, Vector3(0.04, 0.012, 0.07), Vector3(0, 0.058, -0.06), _poly())
	box(gun, Vector3(0.005, 0.045, 0.005), Vector3(-0.02, 0.083, -0.08), _poly())
	box(gun, Vector3(0.005, 0.045, 0.005), Vector3(0.02, 0.083, -0.08), _poly())
	box(gun, Vector3(0.045, 0.005, 0.005), Vector3(0, 0.106, -0.08), _poly())
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.0035; tm.outer_radius = 0.0045
	ring.mesh = tm
	ring.material_override = mat("holo", Color(1.0, 0.3, 0.2), 0.0, 0.5, 5.0)
	ring.rotation.x = PI / 2.0
	ring.position = Vector3(0, 0.084, -0.08)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun.add_child(ring)
	_marker(gun, "Muzzle", Vector3(0, 0.03, -0.63))
	_marker(gun, "Sight", Vector3(0, 0.084, -0.02))
	box(mag, Vector3(0.028, 0.15, 0.05), Vector3(0, -0.08, -0.1), _steel(), Vector3(-0.22, 0, 0))
	_hand(gun, Vector3(0.0, -0.055, 0.02), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.01, -0.02, -0.32), Vector3(0, 0.0, 0.35), true)
	root.set_meta("hip", Vector3(0.17, -0.15, -0.36))
	root.set_meta("ads_dist", 0.19)

static func _shotgun(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	cyl(gun, 0.016, 0.55, Vector3(0, 0.04, -0.36), _steel())                               # barrel
	cyl(gun, 0.014, 0.42, Vector3(0, 0.01, -0.3), _steel())                                # mag tube
	box(gun, Vector3(0.045, 0.06, 0.18), Vector3(0, 0.025, -0.02), _steel())               # receiver
	box(gun, Vector3(0.04, 0.07, 0.26), Vector3(0, -0.005, 0.18), _wood(), Vector3(-0.08, 0, 0))
	box(gun, Vector3(0.006, 0.01, 0.006), Vector3(0, 0.06, -0.62), mat("bead", Color(0.9, 0.9, 0.85), 0.8, 0.3))
	box(gun, Vector3(0.047, 0.008, 0.14), Vector3(0, 0.0, -0.02), rm)
	var pump := Node3D.new(); pump.name = "Pump"
	gun.add_child(pump)
	box(pump, Vector3(0.05, 0.045, 0.14), Vector3(0, 0.005, -0.3), _wood())
	_hand(pump, Vector3(-0.005, -0.03, -0.3), Vector3(0, 0, 0.35), true)
	_marker(gun, "Muzzle", Vector3(0, 0.04, -0.65))
	_marker(gun, "Sight", Vector3(0, 0.066, 0.02))
	box(mag, Vector3(0.02, 0.02, 0.06), Vector3(0, -0.04, -0.06), mat("shell", Color(0.75, 0.12, 0.1), 0.2, 0.5))
	_hand(gun, Vector3(0.0, -0.045, 0.06), Vector3(0.3, 0, -0.08))
	root.set_meta("hip", Vector3(0.17, -0.15, -0.34))
	root.set_meta("ads_dist", 0.22)

static func _rifle(root: Node3D, gun: Node3D, mag: Node3D, rm: Material, sniper: bool) -> void:
	box(gun, Vector3(0.045, 0.06, 0.32), Vector3(0, 0.02, -0.08), _park() if not sniper else _steel())
	cyl(gun, 0.012 if not sniper else 0.014, 0.42 if not sniper else 0.55, Vector3(0, 0.03, -0.45 if not sniper else -0.52), _steel())
	box(gun, Vector3(0.05, 0.05, 0.3), Vector3(0, 0.0, -0.32), _wood() if sniper else _poly())
	box(gun, Vector3(0.045, 0.08, 0.28), Vector3(0, -0.005, 0.2), _wood() if sniper else _poly(), Vector3(-0.06, 0, 0))
	box(gun, Vector3(0.032, 0.09, 0.04), Vector3(0, -0.05, 0.03), _poly(), Vector3(0.3, 0, 0))
	box(gun, Vector3(0.047, 0.008, 0.28), Vector3(0, -0.015, -0.12), rm)
	# scope
	cyl(gun, 0.022, 0.26, Vector3(0, 0.09, -0.08), _steel())
	cyl(gun, 0.028, 0.06, Vector3(0, 0.09, -0.23), _steel())
	cyl(gun, 0.026, 0.05, Vector3(0, 0.09, 0.06), _steel())
	box(gun, Vector3(0.012, 0.03, 0.02), Vector3(0, 0.065, -0.14), _steel())
	box(gun, Vector3(0.012, 0.03, 0.02), Vector3(0, 0.065, 0.0), _steel())
	var lens := cyl(gun, 0.021, 0.004, Vector3(0, 0.09, 0.086), mat("lens", Color(0.05, 0.1, 0.15), 0.9, 0.05, 0.4))
	lens.name = "Lens"
	if sniper:
		var bolt := Node3D.new(); bolt.name = "Bolt"
		gun.add_child(bolt)
		cyl(bolt, 0.008, 0.06, Vector3(0.035, 0.03, 0.02), _steel(), false).rotation = Vector3(0, 0, PI / 2.0)
		var knob := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.012; sm.height = 0.024
		knob.mesh = sm
		knob.material_override = _steel()
		knob.position = Vector3(0.068, 0.03, 0.02)
		bolt.add_child(knob)
	_marker(gun, "Muzzle", Vector3(0, 0.03, -0.7 if not sniper else -0.8))
	_marker(gun, "Sight", Vector3(0, 0.09, 0.1))
	box(mag, Vector3(0.03, 0.08, 0.06), Vector3(0, -0.045, -0.08), _steel())
	_hand(gun, Vector3(0.0, -0.06, 0.05), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.01, -0.035, -0.32), Vector3(0, 0, 0.35), true)
	root.set_meta("hip", Vector3(0.17, -0.155, -0.36))
	root.set_meta("ads_dist", 0.12 if not sniper else 0.1)

static func _lmg(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.06, 0.08, 0.36), Vector3(0, 0.02, -0.08), _park())
	box(gun, Vector3(0.065, 0.06, 0.22), Vector3(0, 0.03, -0.35), _poly())
	cyl(gun, 0.016, 0.3, Vector3(0, 0.035, -0.58), _steel())
	box(gun, Vector3(0.012, 0.06, 0.12), Vector3(0, 0.1, -0.14), _poly())                 # carry handle
	box(gun, Vector3(0.05, 0.085, 0.24), Vector3(0, 0.0, 0.2), _poly())
	box(gun, Vector3(0.034, 0.1, 0.045), Vector3(0, -0.06, 0.02), _poly(), Vector3(0.3, 0, 0))
	box(gun, Vector3(0.062, 0.01, 0.3), Vector3(0, -0.02, -0.1), rm)
	box(gun, Vector3(0.008, 0.02, 0.008), Vector3(0, 0.08, -0.4), _steel())
	box(gun, Vector3(0.03, 0.012, 0.01), Vector3(0, 0.072, 0.04), _steel())
	_marker(gun, "Muzzle", Vector3(0, 0.035, -0.74))
	_marker(gun, "Sight", Vector3(0, 0.08, 0.06))
	box(mag, Vector3(0.09, 0.1, 0.1), Vector3(-0.07, -0.06, -0.1), _tan())               # box mag
	_hand(gun, Vector3(0.0, -0.065, 0.04), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.01, -0.03, -0.34), Vector3(0, 0, 0.35), true)
	root.set_meta("hip", Vector3(0.18, -0.17, -0.37))
	root.set_meta("ads_dist", 0.22)

static func _crossbow(root: Node3D, gun: Node3D, mag: Node3D, rm: Material) -> void:
	box(gun, Vector3(0.04, 0.045, 0.5), Vector3(0, 0.0, -0.12), _wood())
	box(gun, Vector3(0.36, 0.02, 0.03), Vector3(0, 0.01, -0.34), _park(), Vector3(0, 0, 0))  # limbs
	box(gun, Vector3(0.04, 0.06, 0.2), Vector3(0, -0.02, 0.18), _wood())
	box(gun, Vector3(0.03, 0.08, 0.04), Vector3(0, -0.05, 0.02), _poly(), Vector3(0.3, 0, 0))
	box(gun, Vector3(0.042, 0.006, 0.3), Vector3(0, 0.024, -0.1), rm)
	var string_mi := box(gun, Vector3(0.3, 0.004, 0.004), Vector3(0, 0.022, -0.2), mat("string", Color(0.85, 0.82, 0.7), 0.0, 0.8))
	string_mi.name = "String"
	box(gun, Vector3(0.006, 0.03, 0.006), Vector3(0, 0.05, -0.3), _steel())                # front post
	box(gun, Vector3(0.02, 0.012, 0.01), Vector3(0, 0.045, 0.0), _steel())
	var arrow := Node3D.new(); arrow.name = "Arrow"
	gun.add_child(arrow)
	cyl(arrow, 0.005, 0.38, Vector3(0, 0.03, -0.18), mat("shaft", Color(0.3, 0.3, 0.3), 0.6, 0.4))
	cyl(arrow, 0.009, 0.03, Vector3(0, 0.03, -0.38), _steel(), true, 0.0)
	_marker(gun, "Muzzle", Vector3(0, 0.03, -0.4))
	_marker(gun, "Sight", Vector3(0, 0.051, 0.02))
	_hand(gun, Vector3(0.0, -0.05, 0.04), Vector3(0.3, 0, -0.08))
	_hand(mag, Vector3(-0.015, -0.03, -0.2), Vector3(0, 0, 0.3), true)
	root.set_meta("hip", Vector3(0.16, -0.14, -0.34))
	root.set_meta("ads_dist", 0.24)

# ---------------- melee & forms ----------------
# Melee root pivots at the wrist; the Player swings "Swing" through an arc.
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
