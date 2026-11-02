class_name PoiMilitary
extends RefCounted
# CAMP HALBERD: fenced base with towers, barracks, hangar, motor pool and a command
# bunker whose stairs go down to BLACK SITE HALBERD: red-lit corridors, labs with the
# cures, a broken containment wing, and the specimen hall where G-9 waits for a sound.

const LY := World.LAB_Y
static var rng := RandomNumberGenerator.new()

static func build(w: World, b: WorldBuilder) -> void:
	rng.seed = 4477
	var c := World.MILITARY
	var x0 := c.x - 40.0
	var x1 := c.x + 40.0
	var z0 := c.z - 40.0
	var z1 := c.z + 40.0
	# fence (see-through chain link) + posts + wire
	var ft := Color(0.75, 0.75, 0.75)
	b.wall(Vector3(x0, 0, z0), Vector3(x1, 0, z0), 3.4, 0.08, "chain", ft)
	b.wall(Vector3(x0, 0, z1), Vector3(x1, 0, z1), 3.4, 0.08, "chain", ft)
	b.wall(Vector3(x0, 0, z0), Vector3(x0, 0, z1), 3.4, 0.08, "chain", ft, [[40.0, 10.0]])
	b.wall(Vector3(x1, 0, z0), Vector3(x1, 0, z1), 3.4, 0.08, "chain", ft)
	for i in 17:
		for side in 4:
			var t := i / 16.0
			var p: Vector3
			match side:
				0: p = Vector3(lerpf(x0, x1, t), 0, z0)
				1: p = Vector3(lerpf(x0, x1, t), 0, z1)
				2: p = Vector3(x0, 0, lerpf(z0, z1, t))
				_: p = Vector3(x1, 0, lerpf(z0, z1, t))
			if side == 2 and absf(p.z - c.z) < 5.5:
				continue
			b.box(Vector3(0.12, 3.8, 0.12), p + Vector3(0, 1.9, 0), "metal", Vector3.ZERO, false, Color(0.45, 0.45, 0.45))
	for e in [[Vector3(c.x, 3.6, z0), Vector3(80, 0.05, 0.05)], [Vector3(c.x, 3.6, z1), Vector3(80, 0.05, 0.05)], [Vector3(x1, 3.6, c.z), Vector3(0.05, 0.05, 80)]]:
		b.box(e[1], e[0], "rusty", Vector3.ZERO, false)
	# gate: barrier arm + guard booth
	b.box(Vector3(0.2, 0.2, 9.0), Vector3(x0 - 0.5, 1.1, c.z - 1.0), "paint", Vector3(0, 0, 0.9), false, Color(0.9, 0.85, 0.2))
	b.box(Vector3(3, 2.8, 3), Vector3(x0 + 3, 1.4, c.z + 8), "concrete", Vector3.ZERO, true, Color(0.6, 0.62, 0.56))
	var sign := Label3D.new()
	sign.text = "CAMP HALBERD\nRESTRICTED — USE OF DEADLY FORCE AUTHORIZED"
	sign.font_size = 48
	sign.outline_size = 8
	sign.modulate = Color(0.95, 0.9, 0.75)
	sign.position = Vector3(x0 - 0.3, 2.6, c.z + 7.5)
	sign.rotation.y = -PI * 0.5
	w.add_child(sign)
	# towers
	for tp in [Vector3(x0 + 3, 0, z0 + 3), Vector3(x1 - 3, 0, z0 + 3), Vector3(x0 + 3, 0, z1 - 3), Vector3(x1 - 3, 0, z1 - 3)]:
		for lx in [-1.6, 1.6]:
			for lz in [-1.6, 1.6]:
				b.box(Vector3(0.3, 6.5, 0.3), tp + Vector3(lx, 3.25, lz), "metal", Vector3.ZERO, true, Color(0.4, 0.42, 0.36))
		b.box(Vector3(4, 0.3, 4), tp + Vector3(0, 6.5, 0), "metal", Vector3.ZERO, true, Color(0.4, 0.42, 0.36))
		b.box(Vector3(4.4, 0.2, 4.4), tp + Vector3(0, 8.6, 0), "corrugated", Vector3.ZERO, false, Color(0.35, 0.4, 0.3))
		for k in 4:
			var off: Vector3 = [Vector3(2, 0, 0), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, -2)][k]
			b.box(Vector3(0.1, 1.0, 4.0) if k < 2 else Vector3(4.0, 1.0, 0.1), tp + off + Vector3(0, 7.1, 0), "sandbag", Vector3.ZERO, false, Color(0.75, 0.72, 0.6))
		var l := b.light(tp + Vector3(0, 7.8, 0), Color(1.0, 0.9, 0.7), 16.0, 1.2)
		w._flicker.append({"l": l, "base": 1.2})
	b.box(Vector3(80, 0.06, 80), Vector3(c.x, 0.03, c.z), "concrete", Vector3.ZERO, false, Color(0.6, 0.6, 0.56))
	_barracks(w, b, Vector3(c.x + 17, 0, c.z + 23))
	_hangar(w, b, Vector3(c.x + 20, 0, c.z - 23))
	# motor pool
	for i in 2:
		_truck(w, b, Vector3(c.x - 22 + i * 7.0, 0, c.z - 25), 0.1 * (i - 0.5))
	w.container("toolbox", Vector3(c.x - 26, 0, c.z - 18), 0.0)
	w.container("toolbox", Vector3(c.x - 12, 0, c.z - 18), 0.0)
	# sandbag walls & barrels in the yard
	for k in 6:
		var sp := Vector3(c.x + rng.randf_range(-25, 15), 0, c.z + rng.randf_range(-10, 12))
		var yaw := rng.randf() * PI
		for i in 5:
			for j in 2:
				b.box(Vector3(0.72, 0.36, 0.42), sp + Basis.from_euler(Vector3(0, yaw, 0)) * Vector3(i * 0.72 - 1.4, 0.18 + j * 0.36, 0), "sandbag", Vector3(0, yaw, 0), true, Color(0.78, 0.74, 0.6))
	for k in 5:
		var gp := Vector3(c.x + 4 + k * 1.1, 0, c.z - 8 + (k % 2) * 1.1)
		b.cyl(0.4, 1.2, gp + Vector3(0, 0.6, 0), "rusty", true, Color(0.4, 0.6, 0.25), 10)
		b.box(Vector3(0.5, 0.05, 0.5), gp + Vector3(0, 1.22, 0), "neon_green", Vector3.ZERO, false)
	w.container("military", Vector3(c.x - 5, 0, c.z + 5), 0.3)
	w.container("ammo_box", Vector3(c.x + 9, 0, c.z + 2), 1.1)
	_bunker_and_lab(w, b)
	# residents
	for i in 13:
		var p := Vector3(c.x + rng.randf_range(-34, 34), 0.3, c.z + rng.randf_range(-34, 34))
		var k2 := "walker" if i % 3 != 0 else "runner"
		if i == 6: k2 = "screamer"
		w.spawn_monster(k2, p, 10, {"leash": 30.0})
	w.spawn_monster("brute", Vector3(c.x - 10, 0.3, c.z - 15), 10)
	w.spawn_monster("brute", Vector3(c.x + 22, 0.3, c.z - 22), 10)
	w.add_poi("halberd", "CAMP HALBERD", c, 38.0, 250)

static func _barracks(w: World, b: WorldBuilder, p: Vector3) -> void:
	var t := Color(0.55, 0.58, 0.48)
	b.wall(p + Vector3(-13, 0, -5), p + Vector3(13, 0, -5), 3.6, 0.3, "plaster", t, [[13.0, 1.8, 2.5]])
	b.wall(p + Vector3(-13, 0, 5), p + Vector3(13, 0, 5), 3.6, 0.3, "plaster", t, [[6.0, 1.4, 1.2], [20.0, 1.4, 1.2]])
	b.wall(p + Vector3(-13, 0, -5), p + Vector3(-13, 0, 5), 3.6, 0.3, "plaster", t)
	b.wall(p + Vector3(13, 0, -5), p + Vector3(13, 0, 5), 3.6, 0.3, "plaster", t)
	b.box(Vector3(27, 0.3, 11), p + Vector3(0, 3.75, 0), "corrugated", Vector3.ZERO, true, Color(0.4, 0.42, 0.36))
	b.box(Vector3(26, 0.1, 10), p + Vector3(0, 0.05, 0), "wood", Vector3.ZERO, true, Color(0.6, 0.5, 0.4))
	for i in 6:
		var bp := p + Vector3(-11 + i * 4.4, 0, 2.5)
		b.box(Vector3(0.9, 0.5, 2.0), bp + Vector3(0, 0.45, 0), "metal", Vector3.ZERO, true, Color(0.4, 0.45, 0.35))
		b.box(Vector3(0.9, 0.5, 2.0), bp + Vector3(0, 1.6, 0), "metal", Vector3.ZERO, true, Color(0.4, 0.45, 0.35))
	for i in 4:
		w.container("locker", p + Vector3(-10 + i * 6.0, 0, -4.3), 0.0)
	w.container("military", p + Vector3(10, 0, -1), 0.0)
	b.light(p + Vector3(0, 3.0, 0), Color(1.0, 0.85, 0.6), 12.0, 0.9)

static func _hangar(w: World, b: WorldBuilder, p: Vector3) -> void:
	var t := Color(0.45, 0.48, 0.42)
	b.wall(p + Vector3(-15, 0, -11), p + Vector3(15, 0, -11), 10.0, 0.4, "corrugated", t)
	b.wall(p + Vector3(-15, 0, 11), p + Vector3(15, 0, 11), 10.0, 0.4, "corrugated", t)
	b.wall(p + Vector3(15, 0, -11), p + Vector3(15, 0, 11), 10.0, 0.4, "corrugated", t)
	b.box(Vector3(31, 0.4, 23), p + Vector3(0, 10.2, 0), "corrugated", Vector3.ZERO, true, t.darkened(0.15))
	b.box(Vector3(0.4, 2.0, 23), p + Vector3(-15, 9.0, 0), "corrugated", Vector3.ZERO, true, t)
	# helicopter wreck
	b.box(Vector3(3.0, 2.8, 9.0), p + Vector3(2, 1.6, 0), "metal", Vector3(0, PI * 0.5, 0.15), true, Color(0.3, 0.35, 0.28))
	b.box(Vector3(0.8, 0.9, 7.0), p + Vector3(9, 2.0, 0.6), "metal", Vector3(0, PI * 0.5, 0.1), true, Color(0.3, 0.35, 0.28))
	for k in 4:
		b.box(Vector3(0.35, 0.08, 9.0), p + Vector3(2, 3.2, 0), "metal", Vector3(0, k * 0.8, 0.1), false, Color(0.2, 0.2, 0.22))
	w.container("weapons", p + Vector3(-8, 0, -8), 0.0)
	w.container("weapons", p + Vector3(-4, 0, -8), 0.2)
	w.container("military", p + Vector3(10, 0, 8), PI)
	w.container("ammo_box", p + Vector3(-9, 0, 8), 0.5)
	w.container("ammo_box", p + Vector3(-7, 0, 8.5), 1.2)
	var l := b.light(p + Vector3(0, 8.5, 0), Color(1.0, 0.95, 0.8), 18.0, 1.0)
	w._flicker.append({"l": l, "base": 1.0})

static func _truck(w: World, b: WorldBuilder, p: Vector3, yaw: float) -> void:
	var olive := Color(0.32, 0.36, 0.24)
	var basis := Basis.from_euler(Vector3(0, yaw, 0))
	b.box(Vector3(2.5, 1.0, 7.5), p + basis * Vector3(0, 1.0, 0), "metal", Vector3(0, yaw, 0), true, olive)
	b.box(Vector3(2.4, 1.6, 2.2), p + basis * Vector3(0, 2.2, -2.4), "metal", Vector3(0, yaw, 0), true, olive)
	b.box(Vector3(2.5, 2.2, 4.8), p + basis * Vector3(0, 2.6, 1.2), "corrugated", Vector3(0, yaw, 0), true, Color(0.4, 0.42, 0.3))
	for wz in [-2.6, 0.8, 2.6]:
		for wx in [-1.2, 1.2]:
			b.cyl(0.55, 0.4, p + basis * Vector3(wx, 0.55, wz), "rubber", false, Color(0.08, 0.08, 0.08), 8, Vector3(0, yaw, PI * 0.5))
	w.container("car_trunk", p + basis * Vector3(0, 0.3, 3.9), yaw)

static func _bunker_and_lab(w: World, b: WorldBuilder) -> void:
	var c := World.MILITARY
	var bp := Vector3(c.x - 13, 0, c.z + 23)       # bunker center (202, 0, -192)
	var conc := Color(0.55, 0.56, 0.52)
	# bunker shell over the stair hole
	b.wall(bp + Vector3(-7, 0, -6), bp + Vector3(7, 0, -6), 4.5, 0.8, "concrete", conc)
	b.wall(bp + Vector3(-7, 0, 6), bp + Vector3(7, 0, 6), 4.5, 0.8, "concrete", conc, [[7.0, 2.2, 2.6]])
	b.wall(bp + Vector3(-7, 0, -6), bp + Vector3(-7, 0, 6), 4.5, 0.8, "concrete", conc)
	b.wall(bp + Vector3(7, 0, -6), bp + Vector3(7, 0, 6), 4.5, 0.8, "concrete", conc)
	b.box(Vector3(15, 0.8, 13), bp + Vector3(0, 4.9, 0), "concrete", Vector3.ZERO, true, conc)
	# bunker floor around the stair hole (terrain is cut at x 200..208, z -200..-188)
	b.box(Vector3(5, 0.3, 12), bp + Vector3(-4.5, -0.1, 0), "concrete", Vector3.ZERO, true, conc)
	b.box(Vector3(3, 0.3, 12), bp + Vector3(5.5, -0.1, 0), "concrete", Vector3.ZERO, true, conc)
	b.box(Vector3(6, 0.3, 3), bp + Vector3(1, -0.1, 4.5), "concrete", Vector3.ZERO, true, conc)
	b.box(Vector3(8, 0.3, 2), bp + Vector3(2, -0.1, -7), "concrete", Vector3.ZERO, true, conc)
	var sign := Label3D.new()
	sign.text = "LEVEL B — AUTHORIZED PERSONNEL\n☢ BIOHAZARD ☢"
	sign.font_size = 40
	sign.modulate = Color(1.0, 0.3, 0.2)
	sign.outline_size = 6
	sign.position = bp + Vector3(1, 3.2, 3.4)
	w.add_child(sign)
	b.light(bp + Vector3(0, 3.6, 0), Color(1.0, 0.15, 0.1), 10.0, 1.6)
	# stair tunnel: from bunker (z -185) north/down to the lab at z -216
	var sx := bp.x + 1.0
	b.ramp(Vector3(sx, LY, -217.0), Vector3(sx, 0.0, -189.0), 5.6, "concrete", true, conc)
	b.wall(Vector3(sx - 3.0, LY, -186), Vector3(sx - 3.0, LY, -218), absf(LY) + 0.2, 0.4, "concrete", conc)
	b.wall(Vector3(sx + 3.0, LY, -186), Vector3(sx + 3.0, LY, -218), absf(LY) + 0.2, 0.4, "concrete", conc)
	b.box(Vector3(6.4, 0.4, 24), Vector3(sx, -0.6, -207.5), "concrete", Vector3.ZERO, true, conc)
	# ---- the lab ----
	var tile := Color(0.82, 0.84, 0.86)
	var h := 5.0
	var floor_t := Color(0.65, 0.67, 0.68)
	b.box(Vector3(74, 0.4, 48), Vector3(215, LY - 0.2, -228), "tile", Vector3.ZERO, true, floor_t)
	b.box(Vector3(74, 0.4, 48), Vector3(215, LY + h + 0.2, -228), "concrete", Vector3.ZERO, true, Color(0.4, 0.4, 0.42))
	# outer walls
	b.wall(Vector3(178, LY, -252), Vector3(252, LY, -252), h, 0.5, "tile", tile)
	b.wall(Vector3(178, LY, -204), Vector3(252, LY, -204), h, 0.5, "tile", tile, [[sx - 178.0, 6.0]])
	b.wall(Vector3(178, LY, -252), Vector3(178, LY, -204), h, 0.5, "tile", tile)
	b.wall(Vector3(252, LY, -252), Vector3(252, LY, -204), h, 0.5, "tile", tile)
	# security checkpoint room (x 196..210, z -216..-204) opening into the main hall
	b.wall(Vector3(196, LY, -216), Vector3(196, LY, -204), h, 0.3, "tile", tile)
	b.wall(Vector3(210, LY, -216), Vector3(210, LY, -204), h, 0.3, "tile", tile, [[6.0, 2.0, 2.6]])
	b.wall(Vector3(196, LY, -216), Vector3(210, LY, -216), h, 0.3, "tile", tile, [[7.0, 3.0, 3.0]])
	b.box(Vector3(4, 1.1, 1), Vector3(200, LY + 0.55, -212), "metal", Vector3.ZERO, true, Color(0.4, 0.42, 0.45))
	w.container("locker", Vector3(197, LY, -208), PI * 0.5, "", 12)
	# director's office (x 178..196, z -216..-204) — the G-9 file
	b.wall(Vector3(178, LY, -216), Vector3(196, LY, -216), h, 0.3, "tile", tile, [[14.0, 1.8, 2.5]])
	b.box(Vector3(3, 0.9, 1.4), Vector3(186, LY + 0.45, -210), "wood", Vector3.ZERO, true, Color(0.4, 0.28, 0.18))
	var note := Interactable.new().setup("note", 12, {"data": {"note": "note_g9"}})
	w.add_child(note)
	note.global_position = Vector3(186, LY + 0.92, -210)
	w.container("lab", Vector3(179, LY, -207), PI * 0.5, "", 12)
	# main hall z -226..-216 runs the full width; labs and containment south of it
	for x in [196.0, 214.0, 230.0]:
		b.wall(Vector3(x, LY, -252), Vector3(x, LY, -226), h, 0.3, "tile", tile)
	b.wall(Vector3(178, LY, -226), Vector3(252, LY, -226), h, 0.3, "tile", tile, [[9.0, 2.2, 2.6], [27.0, 2.2, 2.6], [44.0, 2.2, 2.6], [63.0, 3.0, 3.0]])
	# specimen hall (x 214..252, z -216..-204) north of the hall's east end
	b.wall(Vector3(214, LY, -216), Vector3(252, LY, -216), h, 0.3, "tile", tile, [[19.0, 4.0, 3.4]])
	b.wall(Vector3(214, LY, -216), Vector3(214, LY, -204), h, 0.3, "tile", tile)
	# labs: cabinets with the cures
	for lp in [Vector3(181, LY, -240), Vector3(181, LY, -248), Vector3(199, LY, -240), Vector3(199, LY, -249), Vector3(211, LY, -244)]:
		w.container("lab", lp, PI * 0.5 if lp.x < 190.0 else -PI * 0.5, "", 12)
	for k in 4:
		b.box(Vector3(4, 0.95, 1.4), Vector3(187 + (k % 2) * 18.0, LY + 0.47, -236 - (k / 2) * 8.0), "metal", Vector3.ZERO, true, Color(0.75, 0.78, 0.8))
	# containment cells (x 230..252): glass fronts, mostly broken
	for k in 4:
		var cz := -250.0 + k * 6.0
		b.wall(Vector3(240, LY, cz), Vector3(252, LY, cz), h, 0.3, "tile", tile)
		if k != 2:
			b.box(Vector3(0.08, h, 5.4), Vector3(240, LY + h * 0.5, cz + 3.0), "glass", Vector3.ZERO, k == 0)
	b.box(Vector3(0.4, 0.4, 5.8), Vector3(242, LY + 0.2, -235), "metal", Vector3(0.3, 0.6, 1.2), true, Color(0.3, 0.3, 0.32))
	var g9 := Label3D.new()
	g9.text = "G-9"
	g9.font_size = 120
	g9.modulate = Color(1.0, 0.2, 0.15)
	g9.position = Vector3(251.6, LY + 3.4, -235)
	g9.rotation.y = -PI * 0.5
	w.add_child(g9)
	for k in 6:
		b.box(Vector3(rng.randf_range(0.2, 0.6), 0.05, rng.randf_range(0.2, 0.6)), Vector3(rng.randf_range(236, 250), LY + 0.03, rng.randf_range(-248, -230)), "neon_red", Vector3(0, rng.randf() * PI, 0), false)
	# specimen hall: restraint frame, gouges
	b.box(Vector3(6, 0.5, 6), Vector3(234, LY + 0.25, -210), "metal", Vector3.ZERO, true, Color(0.3, 0.3, 0.32))
	for k in 4:
		b.box(Vector3(0.3, 4.5, 0.3), Vector3(231 + (k % 2) * 6.0, LY + 2.25, -213 + (k / 2) * 6.0), "metal", Vector3.ZERO, true, Color(0.35, 0.35, 0.38))
	w.container("military", Vector3(248, LY, -208), 0.0, "", 12)
	w.container("lab", Vector3(217, LY, -206), 0.0, "", 13)
	# lights: red emergency + flicker
	for lp2 in [Vector3(sx, LY + 4.3, -210), Vector3(190, LY + 4.3, -221), Vector3(215, LY + 4.3, -221), Vector3(240, LY + 4.3, -221), Vector3(188, LY + 4.3, -244), Vector3(205, LY + 4.3, -244), Vector3(245, LY + 4.3, -240), Vector3(234, LY + 4.3, -210)]:
		b.box(Vector3(0.5, 0.15, 0.5), lp2 + Vector3(0, 0.55, 0), "neon_red", Vector3.ZERO, false)
		var l := b.light(lp2, Color(1.0, 0.1, 0.06), 14.0, 2.0)
		w._flicker.append({"l": l, "base": 2.0})
	var white := b.light(Vector3(205, LY + 4.0, -240), Color(0.85, 0.95, 1.0), 10.0, 1.0)
	w._flicker.append({"l": white, "base": 1.0})
	# residents
	for sp in [Vector3(203, LY + 0.3, -210), Vector3(190, LY + 0.3, -221), Vector3(220, LY + 0.3, -221), Vector3(188, LY + 0.3, -244), Vector3(205, LY + 0.3, -246), Vector3(222, LY + 0.3, -240), Vector3(246, LY + 0.3, -244), Vector3(240, LY + 0.3, -221)]:
		w.spawn_monster("walker" if rng.randf() < 0.6 else "runner", sp, 12, {"leash": 10.0})
	w.spawn_monster("gaunt", Vector3(234, LY + 0.6, -210), 12, {"dormant": true, "name": "Specimen G-9"})
	w.add_poi("blacksite", "BLACK SITE HALBERD", Vector3(215, LY, -228), 25.0, 400)
