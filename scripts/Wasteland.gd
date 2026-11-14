class_name Wasteland
extends RefCounted
# Fills the open land between locations so travel tells a story: a crashed airliner,
# an overrun military checkpoint, an evacuation bus convoy, burnt farmsteads, a field
# of crosses, a pylon line marching across the hills, plus scattered dead trees, rock
# outcrops, craters, rubble, drums, body bags and corpse piles. Smoke columns rise
# from the worst sites so they read from far away.

static var rng := RandomNumberGenerator.new()
static var placed: Array = []   # [kind, origin] of each set piece (debug / screenshots)

static func build(w: World, b: WorldBuilder, atmo: Atmosphere) -> void:
	rng.seed = 6661
	placed.clear()
	_set_pieces(w, b, atmo)
	_pylons(w, b)
	_scatter(w, b)
	_city_smoke(atmo)

# ---------------- helpers ----------------
static func _free(w: World, x: float, z: float, pad := 12.0) -> bool:
	if absf(x) > 262.0 or absf(z) > 262.0:
		return false
	var p := Vector3(x, 0, z)
	if w.zone_at(p) != "wild":
		return false
	if w.road_dist(x, z) < 9.0:
		return false
	for poi in w.pois:
		if Vector2(x - poi.pos.x, z - poi.pos.z).length() < float(poi.r) + pad:
			return false
	return true

static func _y(w: World, x: float, z: float) -> float:
	return w.height(x, z)

# Euler rotation that points a Y-axis cylinder along `dir`.
static func _along(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	if d.is_equal_approx(Vector3.UP) or d.is_equal_approx(Vector3.DOWN):
		return Vector3.ZERO if d.y > 0.0 else Vector3(PI, 0, 0)
	return Basis(Quaternion(Vector3.UP, d)).get_euler()

static func _dead_tree(w: World, b: WorldBuilder, x: float, z: float, s := 1.0) -> void:
	var y := _y(w, x, z)
	var lean := Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))
	var h := rng.randf_range(4.0, 7.5) * s
	var basis := Basis.from_euler(lean)
	b.cyl(0.24 * s, h, Vector3(x, y + h * 0.5 - 0.2, z), "bark", true, Color(0.35, 0.32, 0.3), 7, lean, 0.09 * s)
	for i in rng.randi_range(3, 6):
		var t := rng.randf_range(0.45, 0.9)
		var at := Vector3(x, y - 0.2, z) + basis * Vector3(0, h * t, 0)
		var yaw := rng.randf() * TAU
		var pitch := rng.randf_range(0.6, 1.2)
		var bl := rng.randf_range(1.2, 2.6) * s * (1.2 - t)
		var dir := Basis.from_euler(Vector3(0, yaw, 0)) * Basis.from_euler(Vector3(pitch, 0, 0)) * Vector3.UP
		b.cyl(0.07 * s, bl, at + dir * bl * 0.5, "bark", false, Color(0.33, 0.3, 0.28), 5, _along(dir), 0.025 * s)

static func _rock(w: World, b: WorldBuilder, x: float, z: float, s := 1.0) -> void:
	var y := _y(w, x, z)
	for i in rng.randi_range(2, 4):
		var sz := Vector3(rng.randf_range(1.2, 3.2), rng.randf_range(0.8, 2.4), rng.randf_range(1.2, 3.0)) * s
		var off := Vector3(rng.randf_range(-1.5, 1.5), sz.y * 0.3 - 0.3, rng.randf_range(-1.5, 1.5)) * s
		b.box(sz, Vector3(x, y, z) + off, "rock", Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)), true, Color(0.62, 0.6, 0.52))

static func _rubble(w: World, b: WorldBuilder, x: float, z: float, s := 1.0, key := "concrete") -> void:
	var y := _y(w, x, z)
	for i in rng.randi_range(5, 10):
		var sz := Vector3(rng.randf_range(0.3, 1.4), rng.randf_range(0.2, 0.7), rng.randf_range(0.3, 1.2)) * s
		b.box(sz, Vector3(x + rng.randf_range(-2.0, 2.0) * s, y + sz.y * 0.3, z + rng.randf_range(-2.0, 2.0) * s), key, Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)), false, Color(0.7, 0.68, 0.62))
	# rebar
	for i in 3:
		b.cyl(0.02, rng.randf_range(0.8, 1.6), Vector3(x + rng.randf_range(-1.0, 1.0), y + 0.5, z + rng.randf_range(-1.0, 1.0)), "rusty", false, Color(0.4, 0.25, 0.18), 4, Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)))

static func _crater(w: World, b: WorldBuilder, x: float, z: float, r: float) -> void:
	var y := _y(w, x, z)
	b.cyl(r, 0.06, Vector3(x, y + 0.02, z), "dust", false, Color(0.18, 0.17, 0.15), 14)
	b.cyl(r * 0.6, 0.07, Vector3(x, y + 0.03, z), "dust", false, Color(0.08, 0.08, 0.07), 12)
	for i in 10:
		var a := TAU * i / 10.0 + rng.randf_range(-0.2, 0.2)
		var sz := Vector3(rng.randf_range(0.6, 1.4), rng.randf_range(0.2, 0.45), rng.randf_range(0.4, 0.9))
		b.box(sz, Vector3(x + cos(a) * r, y + 0.1, z + sin(a) * r), "dust", Vector3(0.3, -a, 0), false, Color(0.5, 0.45, 0.38))

static func _drum(b: WorldBuilder, p: Vector3, tipped := false, col := Color(0.42, 0.2, 0.12)) -> void:
	if tipped:
		b.cyl(0.3, 0.88, p + Vector3(0, 0.3, 0), "rusty", true, col, 10, Vector3(PI / 2.0, rng.randf() * TAU, 0))
	else:
		b.cyl(0.3, 0.88, p + Vector3(0, 0.44, 0), "rusty", true, col, 10)
		b.cyl(0.31, 0.03, p + Vector3(0, 0.3, 0), "metal", false, col.darkened(0.3), 10)

static func _body_bag(b: WorldBuilder, p: Vector3, yaw: float) -> void:
	b.box(Vector3(0.55, 0.28, 1.8), p + Vector3(0, 0.14, 0), "rubber", Vector3(0, yaw, 0), false, Color(0.08, 0.09, 0.08))
	b.box(Vector3(0.5, 0.3, 0.5), p + Basis(Vector3.UP, yaw) * Vector3(0, 0.15, -0.65), "rubber", Vector3(0, yaw, 0), false, Color(0.06, 0.07, 0.06))

static func _corpse(b: WorldBuilder, p: Vector3, yaw: float) -> void:
	var bas := Basis(Vector3.UP, yaw)
	var cloth: Color = [Color(0.3, 0.32, 0.38), Color(0.4, 0.2, 0.15), Color(0.3, 0.3, 0.22)][rng.randi() % 3]
	b.box(Vector3(0.45, 0.2, 0.7), p + bas * Vector3(0, 0.12, 0), "plaster", Vector3(0, yaw, 0), false, cloth)
	b.box(Vector3(0.22, 0.2, 0.24), p + bas * Vector3(0, 0.12, -0.5), "plaster", Vector3(0, yaw + 0.3, 0), false, Color(0.45, 0.48, 0.38))
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.14, 0.14, 0.8), p + bas * Vector3(s * 0.13, 0.08, 0.72), "plaster", Vector3(0, yaw + s * 0.15, 0), false, cloth.darkened(0.3))
		b.box(Vector3(0.11, 0.11, 0.6), p + bas * Vector3(s * 0.4, 0.08, -0.15), "plaster", Vector3(0, yaw + s * 1.1, 0), false, Color(0.42, 0.45, 0.36))
	b.box(Vector3(1.2, 0.02, 1.0), p + bas * Vector3(0.1, 0.015, -0.2), "paint", Vector3(0, yaw, 0), false, Color(0.2, 0.02, 0.02))

static func _barricade(b: WorldBuilder, p: Vector3, yaw: float) -> void:
	var bas := Basis(Vector3.UP, yaw)
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.1, 1.0, 0.8), p + bas * Vector3(s * 1.0, 0.5, 0), "wood", Vector3(0, yaw, s * 0.2), false, Color(0.5, 0.42, 0.32))
	b.box(Vector3(2.6, 0.3, 0.06), p + bas * Vector3(0, 0.85, 0), "paint", Vector3(0, yaw, 0.05), true, Color(0.8, 0.65, 0.1))
	b.box(Vector3(2.6, 0.3, 0.06), p + bas * Vector3(0, 0.45, 0), "paint", Vector3(0, yaw, -0.04), false, Color(0.75, 0.15, 0.1))

static func _cross(b: WorldBuilder, p: Vector3, yaw: float) -> void:
	var lean := Vector3(rng.randf_range(-0.12, 0.12), yaw, rng.randf_range(-0.12, 0.12))
	var bas := Basis.from_euler(lean)
	b.box(Vector3(0.1, 1.5, 0.08), p + bas * Vector3(0, 0.6, 0), "wood", lean, false, Color(0.45, 0.38, 0.3))
	b.box(Vector3(0.7, 0.1, 0.08), p + bas * Vector3(0, 1.0, 0), "wood", lean, false, Color(0.45, 0.38, 0.3))
	b.box(Vector3(0.5, 0.15, 1.6), p + Basis(Vector3.UP, yaw) * Vector3(0, 0.05, 0.9), "dust", Vector3(0, yaw, 0), false, Color(0.35, 0.3, 0.24))

static func _sign(b: WorldBuilder, p: Vector3, yaw: float, text: String, col := Color(0.85, 0.82, 0.75)) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 140
	l.outline_size = 0
	l.modulate = Color(0.12, 0.02, 0.02)
	l.position = p
	l.rotation.y = yaw
	l.visibility_range_end = 110.0
	l.double_sided = false
	b.root.add_child(l)
	b.box(Vector3(0.08, 0.08, 0.08), p, "paint", Vector3.ZERO, false, col)

# ---------------- set pieces ----------------
static func _set_pieces(w: World, b: WorldBuilder, atmo: Atmosphere) -> void:
	var cands := [Vector2(70, 98), Vector2(-78, 92), Vector2(180, 30), Vector2(65, 238), Vector2(-95, 232),
		Vector2(170, 245), Vector2(-60, -250), Vector2(75, -252), Vector2(240, 210), Vector2(-150, 250),
		Vector2(235, -40), Vector2(140, 60), Vector2(-20, 245), Vector2(200, 165), Vector2(-120, 60)]
	var kinds := ["crash", "checkpoint", "convoy", "farm", "graves", "farm", "checkpoint", "convoy", "crash_small", "graves", "farm", "camp", "convoy", "camp", "farm"]
	for i in cands.size():
		var c: Vector2 = cands[i]
		if not _free(w, c.x, c.y, 18.0):
			# nudge around until we find open ground
			var ok := false
			for k in 10:
				var t := c + Vector2(rng.randf_range(-35, 35), rng.randf_range(-35, 35))
				if _free(w, t.x, t.y, 18.0):
					c = t
					ok = true
					break
			if not ok:
				continue
		var o := Vector3(c.x, _y(w, c.x, c.y), c.y)
		var yaw := rng.randf() * TAU
		placed.append([kinds[i], o])
		match kinds[i]:
			"crash": _airliner(w, b, atmo, o, yaw, true)
			"crash_small": _airliner(w, b, atmo, o, yaw, false)
			"checkpoint": _checkpoint(w, b, atmo, o, yaw)
			"convoy": _convoy(w, b, o, yaw)
			"farm": _farm(w, b, atmo, o, yaw)
			"graves": _graves(w, b, o, yaw)
			"camp": _camp(w, b, o, yaw)

static func _airliner(w: World, b: WorldBuilder, atmo: Atmosphere, o: Vector3, yaw: float, full: bool) -> void:
	var hull := Color(0.62, 0.62, 0.6)
	var burnt := Color(0.12, 0.11, 0.1)
	var len := 22.0 if full else 11.0
	# fuselage lying in a scorched trench, nose buried
	var rot := Vector3(0.0, yaw, PI / 2.0 + 0.05)
	var bas := Basis(Vector3.UP, yaw)
	b.cyl(2.4, len, o + Vector3(0, 1.9, 0), "metal", true, hull, 16, Vector3(0, yaw + PI / 2.0, PI / 2.0 + 0.05))
	b.cyl(2.45, len * 0.35, o + bas * Vector3(len * 0.3, 1.9, 0), "metal", false, burnt, 16, Vector3(0, yaw + PI / 2.0, PI / 2.0 + 0.05))
	# torn end shows a dark interior ring
	b.cyl(2.2, 0.2, o + bas * Vector3(len * 0.5 + 0.05, 1.9, 0), "metal", false, Color(0.04, 0.04, 0.04), 16, Vector3(0, yaw + PI / 2.0, PI / 2.0))
	# window strip
	for i in int(len / 1.2):
		for s in [-1.0, 1.0]:
			b.box(Vector3(0.35, 0.45, 0.05), o + bas * Vector3(-len * 0.45 + i * 1.2, 2.6, s * 2.36), "paint", Vector3(0, yaw, 0), false, Color(0.06, 0.07, 0.08))
	# airline stripe
	for s in [-1.0, 1.0]:
		b.box(Vector3(len * 0.9, 0.3, 0.05), o + bas * Vector3(0, 2.1, s * 2.4), "paint", Vector3(0, yaw, 0), false, Color(0.55, 0.12, 0.1))
	# wing snapped and dug in
	b.box(Vector3(5.0, 0.4, 16.0), o + bas * Vector3(-2.0, 0.7, 9.0), "metal", Vector3(0.12, yaw, -0.08), true, hull.darkened(0.15))
	b.cyl(1.1, 3.6, o + bas * Vector3(-1.6, 0.4, 6.0), "metal", true, burnt, 12, Vector3(0, yaw + PI / 2.0, PI / 2.0))   # engine
	b.cyl(0.8, 0.1, o + bas * Vector3(-3.45, 0.4, 6.0), "metal", false, Color(0.03, 0.03, 0.03), 12, Vector3(0, yaw + PI / 2.0, PI / 2.0))
	if full:
		# tail section broken off further back
		var t := o + bas * Vector3(len * 0.5 + 12.0, 0, 3.0)
		t.y = _y(w, t.x, t.z)
		b.cyl(2.0, 7.0, t + Vector3(0, 1.7, 0), "metal", true, hull, 14, Vector3(0, yaw + PI / 2.0 + 0.4, PI / 2.0 - 0.08))
		b.box(Vector3(4.5, 6.0, 0.35), t + Basis(Vector3.UP, yaw + 0.4) * Vector3(2.0, 5.0, 0), "metal", Vector3(0, yaw + 0.4, 0.4), true, hull)
		b.box(Vector3(1.0, 2.0, 0.37), t + Basis(Vector3.UP, yaw + 0.4) * Vector3(2.4, 5.6, 0), "paint", Vector3(0, yaw + 0.4, 0.4), false, Color(0.55, 0.12, 0.1))
		# debris trail and luggage
		for i in 26:
			var d := o + bas * Vector3(rng.randf_range(-len, len + 18.0), 0, rng.randf_range(-9, 9))
			d.y = _y(w, d.x, d.z)
			if rng.randf() < 0.5:
				b.box(Vector3(rng.randf_range(0.5, 2.5), rng.randf_range(0.05, 0.4), rng.randf_range(0.5, 2.0)), d + Vector3(0, 0.15, 0), "metal", Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)), false, hull.darkened(rng.randf_range(0.0, 0.8)))
			else:
				var lc: Color = [Color(0.2, 0.25, 0.4), Color(0.5, 0.15, 0.12), Color(0.15, 0.15, 0.15), Color(0.4, 0.35, 0.2)][rng.randi() % 4]
				b.box(Vector3(0.45, 0.25, 0.65), d + Vector3(0, 0.13, 0), "plaster", Vector3(0, rng.randf() * TAU, rng.randf_range(-0.2, 0.2)), false, lc)
		for i in 6:
			var cp := o + bas * Vector3(rng.randf_range(-len * 0.4, len * 0.6), 0, rng.randf_range(-7, 7))
			cp.y = _y(w, cp.x, cp.z)
			_body_bag(b, cp, rng.randf() * TAU)
		w.container("crate", o + bas * Vector3(len * 0.5 + 1.5, 0.2, 0.5), yaw, "wild")
		w.container("crate", o + bas * Vector3(-3.0, 0.2, -4.0), yaw, "wild")
	_crater(w, b, o.x, o.z, 9.0 if full else 6.0)
	w.burning_barrel(o + bas * Vector3(len * 0.35, 0, -3.5))
	atmo.smoke_column(o + bas * Vector3(len * 0.3, 3.5, 0), 55.0 if full else 35.0)

static func _checkpoint(w: World, b: WorldBuilder, atmo: Atmosphere, o: Vector3, yaw: float) -> void:
	var bas := Basis(Vector3.UP, yaw)
	var olive := Color(0.32, 0.36, 0.24)
	# sandbag horseshoe walls
	for i in 9:
		var a := -PI * 0.6 + i * PI * 1.2 / 8.0
		var p := o + bas * Vector3(sin(a) * 7.0, 0, cos(a) * 7.0)
		p.y = _y(w, p.x, p.z)
		b.box(Vector3(2.6, 1.2, 0.9), p + Vector3(0, 0.55, 0), "sandbag", Vector3(0, yaw + a, 0), true, Color(0.7, 0.62, 0.45))
	# burnt-out tank with drooping barrel
	var t := o + bas * Vector3(-4.0, 0, -2.0)
	var tb := Basis(Vector3.UP, yaw + 0.5)
	b.box(Vector3(3.4, 1.2, 6.6), t + Vector3(0, 0.95, 0), "metal", Vector3(0, yaw + 0.5, 0.06), true, olive.darkened(0.45))
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.7, 1.0, 7.0), t + tb * Vector3(s * 1.95, 0.55, 0), "rubber", Vector3(0, yaw + 0.5, 0), true, Color(0.1, 0.1, 0.09))
		for k in 5:
			b.cyl(0.42, 0.72, t + tb * Vector3(s * 1.95, 0.5, -2.6 + k * 1.3), "metal", false, Color(0.15, 0.14, 0.12), 8, Vector3(0, yaw + 0.5, PI / 2.0))
	b.box(Vector3(2.4, 0.9, 2.8), t + tb * Vector3(0, 1.95, 0.3), "metal", Vector3(0, yaw + 0.9, 0.12), true, olive.darkened(0.55))
	b.cyl(0.13, 4.2, t + tb * Vector3(0.6, 1.7, -2.4), "metal", false, olive.darkened(0.6), 8, Vector3(0.4 - PI / 2.0, yaw + 0.9, 0))
	# hesco barriers, razor wire, warning signs
	for i in 4:
		var p := o + bas * Vector3(-6.0 + i * 4.0, 0, 9.0)
		p.y = _y(w, p.x, p.z)
		b.box(Vector3(1.5, 1.6, 1.5), p + Vector3(0, 0.8, 0), "chain", Vector3(0, yaw, 0), true, Color(0.75, 0.7, 0.55))
		b.box(Vector3(1.4, 1.5, 1.4), p + Vector3(0, 0.75, 0), "dust", Vector3(0, yaw, 0), false, Color(0.55, 0.48, 0.36))
	for i in 6:
		var p := o + bas * Vector3(-10.0 + i * 4.0, 0, 11.5)
		p.y = _y(w, p.x, p.z)
		b.cyl(0.35, 3.8, p + Vector3(0, 0.35, 0), "chain", false, Color(0.6, 0.6, 0.6), 8, Vector3(0, yaw + PI / 2.0, PI / 2.0))
	_barricade(b, o + bas * Vector3(6.0, 0, 8.5), yaw)
	_sign(b, o + bas * Vector3(0, 2.2, 9.8) + Vector3(0, _y(w, o.x, o.z) - o.y, 0), yaw + PI, "QUARANTINE\nTURN BACK")
	# the soldiers who held it
	for i in 5:
		var p := o + bas * Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-5, 6))
		p.y = _y(w, p.x, p.z)
		if i < 3:
			_body_bag(b, p, rng.randf() * TAU)
		else:
			_corpse(b, p, rng.randf() * TAU)
	for i in 4:
		var p := o + bas * Vector3(rng.randf_range(-4, 5), 0, rng.randf_range(-4, 4))
		p.y = _y(w, p.x, p.z)
		_drum(b, p, rng.randf() < 0.5, olive)
	w.container("military", o + bas * Vector3(3.0, 0.2, 2.0), yaw, "wild")
	w.burning_barrel(o + bas * Vector3(2.0, 0, -3.0))
	atmo.smoke_column(t + Vector3(0, 2.5, 0), 40.0)
	w.spawn_monster("walker", o + bas * Vector3(2, 0.4, 14), -1, {})
	w.spawn_monster("walker", o + bas * Vector3(-3, 0.4, 15), -1, {})

static func _convoy(w: World, b: WorldBuilder, o: Vector3, yaw: float) -> void:
	# evacuation buses and cars, abandoned bumper to bumper
	var bas := Basis(Vector3.UP, yaw)
	for i in 3:
		var p := o + bas * Vector3(rng.randf_range(-0.8, 0.8), 0, -14.0 + i * 13.0)
		p.y = _y(w, p.x, p.z)
		var by := yaw + rng.randf_range(-0.25, 0.25)
		var tipped := i == 1
		var bb := Basis.from_euler(Vector3(0, by, PI / 2.0 - 0.1 if tipped else 0.0))
		var lift := 1.35 if tipped else 1.7
		var col := Color(0.75, 0.6, 0.12) if i != 2 else Color(0.18, 0.22, 0.3)
		var xf := Transform3D(bb, p + Vector3(0, lift, 0))
		b.add_box_mesh(Vector3(2.5, 2.6, 11.0), xf, "rusty", col)
		b.add_box_col(Vector3(2.5, 2.6, 11.0), xf)
		for k in 8:
			for s in [-1.0, 1.0]:
				b.add_box_mesh(Vector3(0.06, 0.9, 1.0), xf * Transform3D(Basis(), Vector3(s * 1.26, 0.55, -4.5 + k * 1.25)), "windows", Color(0.35, 0.38, 0.42))
		b.add_box_mesh(Vector3(2.3, 1.0, 0.06), xf * Transform3D(Basis(), Vector3(0, 0.55, -5.51)), "windows", Color(0.35, 0.38, 0.42))
		if not tipped:
			for wz in [-3.8, 3.6]:
				for s in [-1.0, 1.0]:
					b.cyl(0.55, 0.35, p + bb * Vector3(s * 1.15, 0.55 - lift + 1.15, wz), "rubber", false, Color(0.07, 0.07, 0.07), 10, Vector3(0, by, PI / 2.0))
		var r2 := RandomNumberGenerator.new()
		r2.seed = int(p.x * 31.0 + p.z)
		w.car_wreck(o + bas * Vector3(4.2, 0, -10.0 + i * 11.0) + Vector3(0, _y(w, o.x, o.z) - o.y, 0), yaw + rng.randf_range(-0.6, 0.6), r2, 3, i == 2)
	# luggage and belongings spilled out
	for i in 18:
		var d := o + bas * Vector3(rng.randf_range(-4, 7), 0, rng.randf_range(-18, 18))
		d.y = _y(w, d.x, d.z)
		var lc: Color = [Color(0.2, 0.25, 0.4), Color(0.5, 0.15, 0.12), Color(0.15, 0.15, 0.15), Color(0.4, 0.35, 0.2), Color(0.6, 0.55, 0.45)][rng.randi() % 5]
		b.box(Vector3(rng.randf_range(0.3, 0.6), rng.randf_range(0.2, 0.35), rng.randf_range(0.4, 0.7)), d + Vector3(0, 0.13, 0), "plaster", Vector3(0, rng.randf() * TAU, rng.randf_range(-0.3, 0.3)), false, lc)
	for i in 4:
		var d := o + bas * Vector3(rng.randf_range(-3, 6), 0, rng.randf_range(-16, 16))
		d.y = _y(w, d.x, d.z)
		_corpse(b, d, rng.randf() * TAU)
	_sign(b, o + bas * Vector3(-3.0, 2.6, 0) + Vector3(0, 0.5, 0), yaw - PI / 2.0, "EVAC ROUTE\nCLOSED")
	b.box(Vector3(0.12, 3.0, 0.12), o + bas * Vector3(-3.0, 1.5, 0), "metal", Vector3.ZERO, false, Color(0.4, 0.4, 0.4))
	w.container("car_trunk", o + bas * Vector3(2.5, 0.2, 2.0), yaw, "wild")
	for i in 3:
		w.spawn_monster("walker", o + bas * Vector3(rng.randf_range(-3, 6), 0.4, rng.randf_range(-12, 12)), -1, {})

static func _farm(w: World, b: WorldBuilder, atmo: Atmosphere, o: Vector3, yaw: float) -> void:
	# burnt farmhouse shell: brick walls with window holes, collapsed roof beams
	var bas := Basis(Vector3.UP, yaw)
	var hw := 5.0
	var hd := 4.0
	var hy := o.y - 0.3
	var corners := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	for i in 4:
		var a: Vector3 = o + bas * corners[i]
		var c: Vector3 = o + bas * corners[(i + 1) % 4]
		a.y = hy
		c.y = hy
		var len := a.distance_to(c)
		var holes := [[len * 0.3, 1.0, 1.2], [len * 0.7, 1.0, 1.2]] if i % 2 == 0 else [[len * 0.5, 0.0, 2.1]]
		var hgt := rng.randf_range(2.4, 3.6) if i != 2 else 1.4      # one wall half collapsed
		b.wall(a, c, hgt, 0.3, "brick", Color(0.55, 0.42, 0.36), holes)
	# soot band and charred beams
	for i in 5:
		var p := o + bas * Vector3(-hw + 1.0 + i * 2.0, 0, rng.randf_range(-1.5, 1.5))
		b.box(Vector3(0.22, 0.22, hd * 2.2), Vector3(p.x, hy + rng.randf_range(0.4, 2.8), p.z), "wood", Vector3(rng.randf_range(-0.5, 0.5), yaw, rng.randf_range(-0.3, 0.3)), false, Color(0.12, 0.1, 0.09))
	_rubble(w, b, o.x, o.z, 1.2, "brick")
	b.box(Vector3(1.2, 6.0, 1.2), o + bas * Vector3(hw - 1.0, 3.0 - 0.3, hd - 0.8), "brick", Vector3(0, yaw, 0), true, Color(0.45, 0.35, 0.3))   # chimney stands
	# barn: corrugated sheds leaning, silo
	var barn := o + bas * Vector3(14.0, 0, 3.0)
	barn.y = _y(w, barn.x, barn.z)
	b.box(Vector3(7.0, 4.0, 0.15), barn + Basis(Vector3.UP, yaw) * Vector3(0, 2.0, -4.0), "corrugated", Vector3(0, yaw, 0.08), true, Color(0.55, 0.25, 0.18))
	b.box(Vector3(7.0, 4.0, 0.15), barn + Basis(Vector3.UP, yaw) * Vector3(0, 2.0, 4.0), "corrugated", Vector3(0, yaw, -0.05), true, Color(0.55, 0.25, 0.18))
	b.box(Vector3(0.15, 4.0, 8.0), barn + Basis(Vector3.UP, yaw) * Vector3(3.5, 2.0, 0), "corrugated", Vector3(0, yaw, 0), true, Color(0.5, 0.23, 0.17))
	b.box(Vector3(7.6, 0.12, 5.0), barn + Basis(Vector3.UP, yaw) * Vector3(0, 3.0, 1.5), "corrugated", Vector3(0.35, yaw, 0.1), false, Color(0.45, 0.42, 0.38))
	var silo := o + bas * Vector3(-12.0, 0, 6.0)
	silo.y = _y(w, silo.x, silo.z)
	b.cyl(2.2, 11.0, silo + Vector3(0, 5.4, 0), "corrugated", true, Color(0.6, 0.6, 0.58), 14)
	b.cyl(2.3, 1.2, silo + Vector3(0, 11.4, 0), "metal", false, Color(0.4, 0.35, 0.3), 14, Vector3.ZERO, 0.4)
	# fence posts, hay bales, dead tree in the yard, tractor wreck
	for i in 14:
		var p := o + bas * Vector3(-16.0 + i * 2.6, 0, -10.0)
		p.y = _y(w, p.x, p.z)
		if rng.randf() < 0.8:
			b.box(Vector3(0.14, 1.3, 0.14), p + Vector3(0, 0.6, 0), "wood", Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), false, Color(0.4, 0.34, 0.27))
	for i in 5:
		var p := o + bas * Vector3(rng.randf_range(8, 18), 0, rng.randf_range(-8, -5))
		p.y = _y(w, p.x, p.z)
		b.cyl(0.7, 1.2, p + Vector3(0, 0.7, 0), "grass", true, Color(0.72, 0.62, 0.3), 10, Vector3(0, rng.randf() * TAU, PI / 2.0))
	var tp := o + bas * Vector3(6.0, 0, -6.5)
	tp.y = _y(w, tp.x, tp.z)
	b.box(Vector3(1.4, 1.2, 2.6), tp + Vector3(0, 1.0, 0), "rusty", Vector3(0, yaw + 0.7, 0), true, Color(0.5, 0.18, 0.1))
	b.cyl(0.85, 0.5, tp + Basis(Vector3.UP, yaw + 0.7) * Vector3(0.95, 0.85, 0.9), "rubber", false, Color(0.08, 0.08, 0.08), 10, Vector3(0, yaw + 0.7, PI / 2.0))
	b.cyl(0.85, 0.5, tp + Basis(Vector3.UP, yaw + 0.7) * Vector3(-0.95, 0.85, 0.9), "rubber", false, Color(0.08, 0.08, 0.08), 10, Vector3(0, yaw + 0.7, PI / 2.0))
	_dead_tree(w, b, o.x + 9.0, o.z - 12.0, 1.3)
	w.container("locker", o + bas * Vector3(-3.5, 0.0, 2.8) + Vector3(0, hy - o.y + 0.3, 0), yaw, "wild")
	if rng.randf() < 0.6:
		atmo.smoke_column(o + Vector3(0, 2.0, 0), 28.0)
		w.burning_barrel(o + bas * Vector3(1.0, 0, 0) + Vector3(0, hy - o.y, 0))
	w.spawn_monster("walker", o + bas * Vector3(10, 0.4, -2), -1, {})

static func _graves(w: World, b: WorldBuilder, o: Vector3, yaw: float) -> void:
	# field of hasty crosses around a mass grave trench
	var bas := Basis(Vector3.UP, yaw)
	for r in 5:
		for c in 8:
			if rng.randf() < 0.15:
				continue
			var p := o + bas * Vector3(-10.0 + c * 2.8 + rng.randf_range(-0.4, 0.4), 0, -8.0 + r * 3.6)
			p.y = _y(w, p.x, p.z)
			_cross(b, p, yaw + rng.randf_range(-0.15, 0.15))
	var trench := o + bas * Vector3(0, 0, 12.0)
	trench.y = _y(w, trench.x, trench.z)
	b.box(Vector3(14.0, 0.1, 4.0), trench + Vector3(0, 0.02, 0), "dust", Vector3(0, yaw, 0), false, Color(0.12, 0.1, 0.08))
	b.box(Vector3(15.0, 1.0, 1.2), trench + bas * Vector3(0, 0.4, 2.6), "dust", Vector3(0, yaw, 0), true, Color(0.42, 0.36, 0.28))
	for i in 7:
		_body_bag(b, trench + bas * Vector3(-6.0 + i * 2.0, 0.02, rng.randf_range(-1.0, 1.0)), yaw + PI / 2.0 + rng.randf_range(-0.3, 0.3))
	b.box(Vector3(0.12, 0.12, 1.6), trench + bas * Vector3(7.5, 0.6, 1.0), "wood", Vector3(0.8, yaw, 0.2), false, Color(0.4, 0.33, 0.25))   # abandoned shovel
	_sign(b, o + bas * Vector3(0, 2.4, -11.0) + Vector3(0, 0.3, 0), yaw + PI, "FORGIVE US")
	b.box(Vector3(2.8, 1.2, 0.1), o + bas * Vector3(0, 2.4, -10.95) + Vector3(0, 0.3, 0), "wood", Vector3(0, yaw, 0), false, Color(0.75, 0.7, 0.6))
	for s in [-1.0, 1.0]:
		b.box(Vector3(0.12, 3.0, 0.12), o + bas * Vector3(s * 1.2, 1.5, -10.9), "wood", Vector3(0, yaw, 0), false, Color(0.4, 0.33, 0.25))
	_dead_tree(w, b, o.x - 12.0, o.z + 4.0, 1.4)
	_dead_tree(w, b, o.x + 13.0, o.z - 6.0, 1.1)
	w.spawn_monster("walker", trench + Vector3(1, 0.4, 0), -1, {})

static func _camp(w: World, b: WorldBuilder, o: Vector3, yaw: float) -> void:
	# a survivor camp that didn't make it: torn tents, cold fire, a last message
	var bas := Basis(Vector3.UP, yaw)
	var tcols := [Color(0.3, 0.4, 0.25), Color(0.55, 0.3, 0.12), Color(0.2, 0.3, 0.45)]
	for i in 3:
		var a := TAU * i / 3.0
		var p := o + bas * Vector3(cos(a) * 5.0, 0, sin(a) * 5.0)
		p.y = _y(w, p.x, p.z)
		var ty := yaw + a + PI / 2.0
		for s in [-1.0, 1.0]:
			b.box(Vector3(2.6, 0.06, 1.7), p + Basis(Vector3.UP, ty) * Vector3(0, 0.75, s * 0.6), "sandbag", Vector3(s * 0.85, ty, 0), false, tcols[i])
	b.cyl(0.8, 0.12, o + Vector3(0, 0.06, 0), "dust", false, Color(0.08, 0.07, 0.06), 10)
	for i in 6:
		var a := TAU * i / 6.0
		b.box(Vector3(0.3, 0.2, 0.3), o + Vector3(cos(a) * 0.85, 0.1, sin(a) * 0.85), "rock", Vector3(0, a, 0), false, Color(0.5, 0.48, 0.44))
	for i in 3:
		b.cyl(0.05, 1.0, o + Vector3(rng.randf_range(-0.3, 0.3), 0.15, rng.randf_range(-0.3, 0.3)), "wood", false, Color(0.08, 0.07, 0.06), 5, Vector3(PI / 2.0, rng.randf() * TAU, 0))
	_sign(b, o + bas * Vector3(0, 1.6, -7.5) + Vector3(0, 0.2, 0), yaw + PI, "HAVEN IS\nNORTH")
	b.box(Vector3(2.0, 1.0, 0.08), o + bas * Vector3(0, 1.6, -7.45) + Vector3(0, 0.2, 0), "wood", Vector3(0, yaw, 0), false, Color(0.7, 0.62, 0.5))
	b.box(Vector3(0.1, 1.8, 0.1), o + bas * Vector3(0, 0.9, -7.4), "wood", Vector3(0, yaw, 0), false, Color(0.4, 0.33, 0.25))
	for i in 3:
		var p := o + bas * Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
		p.y = _y(w, p.x, p.z)
		_corpse(b, p, rng.randf() * TAU)
	w.container("stash", o + bas * Vector3(2.0, 0.1, 1.5), yaw, "wild")

# ---------------- pylon line ----------------
static func _pylons(w: World, b: WorldBuilder) -> void:
	# a high-voltage line crossing the map; some towers buckled, wires sagging or cut
	var path := [Vector2(-255, 75), Vector2(-150, 85), Vector2(-60, 70), Vector2(60, 72), Vector2(160, 40), Vector2(255, 10)]
	var prev := Vector3.INF
	var prev_ok := false
	for i in range(path.size() - 1):
		var a: Vector2 = path[i]
		var c: Vector2 = path[i + 1]
		var n := int(a.distance_to(c) / 45.0)
		for k in n:
			var p2 := a.lerp(c, float(k) / n)
			var ok := absf(p2.x) < 262.0 and w.zone_at(Vector3(p2.x, 0, p2.y)) != "downtown" and w.road_dist(p2.x, p2.y) > 6.0
			var top := Vector3.INF
			if ok:
				var yaw := atan2(c.x - a.x, c.y - a.y)
				var bent := rng.randf() < 0.18
				top = _pylon(w, b, Vector3(p2.x, _y(w, p2.x, p2.y), p2.y), yaw, bent)
				if bent:
					top = Vector3.INF
			if prev != Vector3.INF and top != Vector3.INF and prev_ok:
				_wire(b, prev, top)
			prev = top
			prev_ok = top != Vector3.INF

static func _pylon(w: World, b: WorldBuilder, p: Vector3, yaw: float, bent: bool) -> Vector3:
	var h := 18.0
	var steel := Color(0.4, 0.4, 0.38)
	var lean := Vector3(0.0, yaw, 0.45 if bent else 0.0)
	var bas := Basis.from_euler(lean)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var foot := Vector3(sx * 2.2, 0, sz * 2.2)
			var head := Vector3(sx * 0.6, h, sz * 0.6)
			var mid := (foot + head) * 0.5
			var dir := (head - foot).normalized()
			b.cyl(0.12, foot.distance_to(head), p + bas * mid, "metal", false, steel, 4, _along(bas * dir))
	for k in 5:
		var y := 2.5 + k * 3.2
		var wdt := lerpf(4.4, 1.2, y / h)
		for s in [-1.0, 1.0]:
			b.box(Vector3(wdt, 0.1, 0.1), p + bas * Vector3(0, y, s * wdt * 0.5), "metal", lean + Vector3(0, 0, 0.0), false, steel)
			b.box(Vector3(0.1, 0.1, wdt), p + bas * Vector3(s * wdt * 0.5, y, 0), "metal", lean, false, steel)
		b.box(Vector3(wdt * 1.4, 0.08, 0.08), p + bas * Vector3(0, y + 1.6, wdt * 0.5), "metal", lean + Vector3(0, 0, 0.5), false, steel)
	b.box(Vector3(9.0, 0.3, 0.3), p + bas * Vector3(0, h - 2.0, 0), "metal", Basis.from_euler(lean).rotated(Vector3.UP, PI / 2.0).get_euler(), false, steel)
	b.box(Vector3(1.6, 1.6, 1.6), p + Vector3(0, 0.3, 0), "concrete", Vector3.ZERO, true, Color(0.6, 0.6, 0.58))
	return p + bas * Vector3(0, h - 2.0, 0) + Basis(Vector3.UP, yaw) * Vector3(4.2, -0.4, 0)

static func _wire(b: WorldBuilder, a: Vector3, c: Vector3) -> void:
	var segs := 8
	var sag := a.distance_to(c) * 0.06
	var last := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(c, t) - Vector3(0, sin(t * PI) * sag, 0)
		var mid := (last + p) * 0.5
		var dir := (p - last)
		b.cyl(0.03, dir.length(), mid, "rubber", false, Color(0.05, 0.05, 0.05), 3, _along(dir))
		last = p

# ---------------- scatter ----------------
static func _scatter(w: World, b: WorldBuilder) -> void:
	var cell := 16.0
	var x := -258.0
	while x < 258.0:
		var z := -258.0
		while z < 258.0:
			var px := x + rng.randf_range(0, cell)
			var pz := z + rng.randf_range(0, cell)
			var roll := rng.randf()
			if roll < 0.62 and _free(w, px, pz, 6.0):
				var k := rng.randf()
				if k < 0.3:
					_dead_tree(w, b, px, pz, rng.randf_range(0.8, 1.3))
				elif k < 0.45:
					_rock(w, b, px, pz, rng.randf_range(0.6, 1.4))
				elif k < 0.55:
					_rubble(w, b, px, pz, rng.randf_range(0.7, 1.2))
				elif k < 0.62:
					_crater(w, b, px, pz, rng.randf_range(2.5, 5.0))
				elif k < 0.7:
					var p := Vector3(px, _y(w, px, pz), pz)
					for i in rng.randi_range(1, 4):
						_drum(b, p + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5)), rng.randf() < 0.4, [Color(0.42, 0.2, 0.12), Color(0.25, 0.35, 0.2), Color(0.5, 0.45, 0.1)][rng.randi() % 3])
				elif k < 0.76:
					var p2 := Vector3(px, _y(w, px, pz), pz)
					var r2 := RandomNumberGenerator.new()
					r2.seed = int(px * 17.0 + pz * 3.0)
					w.car_wreck(p2, rng.randf() * TAU, r2, 3, rng.randf() < 0.5)
				elif k < 0.82:
					_corpse(b, Vector3(px, _y(w, px, pz), pz), rng.randf() * TAU)
				elif k < 0.88:
					# telephone pole, leaning
					var lean := Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
					var y := _y(w, px, pz)
					b.cyl(0.14, 7.5, Vector3(px, y + 3.6, pz), "wood", true, Color(0.35, 0.28, 0.22), 6, lean)
					b.box(Vector3(1.6, 0.12, 0.12), Vector3(px, y, pz) + Basis.from_euler(lean) * Vector3(0, 6.8, 0), "wood", lean, false, Color(0.35, 0.28, 0.22))
				elif k < 0.93:
					# tire pile
					var y2 := _y(w, px, pz)
					for i in rng.randi_range(3, 7):
						b.cyl(0.45, 0.28, Vector3(px + rng.randf_range(-0.8, 0.8), y2 + 0.15 + (i % 3) * 0.26, pz + rng.randf_range(-0.8, 0.8)), "rubber", i == 0, Color(0.07, 0.07, 0.07), 10, Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)))
				else:
					_barricade(b, Vector3(px, _y(w, px, pz), pz), rng.randf() * TAU)
			z += cell
		x += cell

static func _city_smoke(atmo: Atmosphere) -> void:
	# fires still burning in the city and at the base: visible landmarks on the skyline
	for p in [Vector3(-95, 30, -150), Vector3(110, 25, -30), Vector3(40, 40, -190), Vector3(230, 5, -190), Vector3(-130, 10, 0)]:
		atmo.smoke_column(p, 70.0)
