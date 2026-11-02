class_name PoiWilds
extends RefCounted
# PINEWOOD (forest, lake + dock, cabins, ranger tower, silverleaf, wildlife),
# SCRAPJAW YARD (raider camp + King Gnasher's throne) and the highway GAS STATION.

static var rng := RandomNumberGenerator.new()

static func build(w: World, b: WorldBuilder) -> void:
	rng.seed = 1312
	_forest(w, b)
	_lake(w, b)
	_cabins(w, b)
	_raider_camp(w, b)
	_gas_station(w, b)
	w.add_poi("pinewood", "PINEWOOD", World.FOREST, 60.0, 120)
	w.add_poi("lake", "SILVER LAKE", World.LAKE, World.LAKE_R + 8.0, 120)
	w.add_poi("scrapjaw", "SCRAPJAW YARD", World.RAIDERS, 34.0, 200)
	w.add_poi("gas", "LAST CHANCE GAS", World.GAS, 16.0, 60)

# ---------------- forest ----------------
static func _forest(w: World, b: WorldBuilder) -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_cols: Array[Color] = []
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("navsrc")
	w.add_child(body)
	var placed: Array[Vector2] = []
	var tries := 0
	while trunks.size() < 650 and tries < 9000:
		tries += 1
		var x := rng.randf_range(-325.0, -95.0)
		var z := rng.randf_range(-230.0, 230.0)
		var fw := w._forest_w(x, z)
		if rng.randf() > fw * 1.15:
			continue
		if w.road_dist(x, z) < 8.0 or Vector2(x - World.LAKE.x, z - World.LAKE.z).length() < World.LAKE_R + 7.0:
			continue
		if Vector2(x - World.HAVEN.x, z - World.HAVEN.z).length() < 60.0:
			continue
		var p2 := Vector2(x, z)
		var ok := true
		for q in placed:
			if q.distance_squared_to(p2) < 16.0:
				ok = false
				break
		if not ok:
			continue
		placed.append(p2)
		_add_tree(w, body, trunks, crowns, crown_cols, x, z, false)
	# a sparse line of dead trees across the wastes
	for i in 60:
		var x2 := rng.randf_range(-280.0, 280.0)
		var z2 := rng.randf_range(-280.0, 280.0)
		if w._forest_w(x2, z2) > 0.1 or w.road_dist(x2, z2) < 10.0 or w.zone_at(Vector3(x2, 0, z2)) in ["haven", "downtown", "military", "raider"]:
			continue
		_add_tree(w, body, trunks, crowns, crown_cols, x2, z2, true)
	_multimesh(w, trunks, _trunk_mesh(), b.material("bark"), [])
	_multimesh(w, crowns, _crown_mesh(), b.material("leaves"), crown_cols)
	# boulders
	for i in 70:
		var bx := rng.randf_range(-320.0, -90.0)
		var bz := rng.randf_range(-220.0, 220.0)
		if w.road_dist(bx, bz) < 9.0 or Vector2(bx - World.LAKE.x, bz - World.LAKE.z).length() < World.LAKE_R + 3.0:
			continue
		var s := rng.randf_range(0.8, 3.2)
		b.box(Vector3(s * 1.3, s, s * 1.1), Vector3(bx, w.height(bx, bz) + s * 0.3, bz), "rock", Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * PI, rng.randf_range(-0.4, 0.4)), true, Color(0.75, 0.75, 0.72))
	# ranger lookout
	var rp := Vector3(-185, 0, -95)
	rp.y = w.height(rp.x, rp.z)
	for lx in [-2.0, 2.0]:
		for lz in [-2.0, 2.0]:
			b.box(Vector3(0.35, 9.5, 0.35), rp + Vector3(lx, 4.75, lz), "wood", Vector3.ZERO, true, Color(0.55, 0.42, 0.3))
	b.box(Vector3(5.0, 0.3, 5.0), rp + Vector3(0, 9.4, 0), "wood", Vector3.ZERO, true, Color(0.6, 0.48, 0.34))
	b.box(Vector3(5.6, 0.25, 5.6), rp + Vector3(0, 12.0, 0), "wood", Vector3(0.05, 0, 0), true, Color(0.45, 0.32, 0.22))
	for k in 3:
		var off: Vector3 = [Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0), Vector3(0, 0, -2.5)][k]
		b.box(Vector3(0.1, 1.0, 5.0) if k < 2 else Vector3(5.0, 1.0, 0.1), rp + off + Vector3(0, 10.0, 0), "wood", Vector3.ZERO, true, Color(0.55, 0.42, 0.3))
	b.ramp(rp + Vector3(-3.4, 0, 8.0), rp + Vector3(-3.4, 4.7, 2.6), 1.4, "wood", true, Color(0.55, 0.42, 0.3))
	b.box(Vector3(2.0, 0.25, 2.0), rp + Vector3(-3.4, 4.6, 1.6), "wood", Vector3.ZERO, true, Color(0.55, 0.42, 0.3))
	b.ramp(rp + Vector3(-1.5, 4.7, 1.6), rp + Vector3(-1.5, 9.4, -1.8), 1.3, "wood", true, Color(0.55, 0.42, 0.3))
	w.container("ammo_box", rp + Vector3(1.2, 9.55, -1.2), 0.0, "", 5)
	w.container("crate", rp + Vector3(1.2, 9.55, 1.2), 0.0, "", 5)
	w.add_poi("lookout", "RANGER LOOKOUT", rp, 10.0, 80)
	# wildlife
	for i in 8:
		var dp := Vector3(rng.randf_range(-290, -120), 0, rng.randf_range(-180, 180))
		dp.y = w.height(dp.x, dp.z) + 0.3
		w.spawn_monster("deer", dp, 3, {"leash": 60.0})
	for i in 5:
		var bp := Vector3(rng.randf_range(-280, -130), 0, rng.randf_range(-150, 150))
		bp.y = w.height(bp.x, bp.z) + 0.3
		w.spawn_monster("boar", bp, 4, {"leash": 40.0})
	# silverleaf
	for i in 12:
		var a := rng.randf() * TAU
		var r := World.LAKE_R + rng.randf_range(2.0, 14.0)
		var hp := Vector3(World.LAKE.x + cos(a) * r, 0, World.LAKE.z + sin(a) * r)
		if i >= 8:
			hp = Vector3(rng.randf_range(-260, -150), 0, rng.randf_range(-120, 60))
		hp.y = w.height(hp.x, hp.z)
		var herb := Interactable.new().setup("herb", 1)
		w.add_child(herb)
		herb.global_position = hp

static func _add_tree(w: World, body: StaticBody3D, trunks: Array[Transform3D], crowns: Array[Transform3D], cols: Array[Color], x: float, z: float, dead: bool) -> void:
	var y := w.height(x, z)
	var s := rng.randf_range(0.8, 1.5)
	var h := 9.0 * s
	var basis := Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04), rng.randf() * TAU, rng.randf_range(-0.04, 0.04)))
	trunks.append(Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(x, y + h * 0.5 - 0.3, z)))
	if not dead:
		for k in 2:
			var cs := s * (1.0 - k * 0.3)
			crowns.append(Transform3D(basis.scaled(Vector3(cs, cs, cs)), Vector3(x, y + h * (0.55 + k * 0.28), z)))
			cols.append(Color(0.8, 0.95, 0.8).darkened(rng.randf_range(0.0, 0.35)))
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3 * s
	cyl.height = h
	col.shape = cyl
	col.position = Vector3(x, y + h * 0.5, z)
	body.add_child(col)

static func _trunk_mesh() -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.32
	cm.height = 9.0
	cm.radial_segments = 7
	cm.rings = 1
	return cm

static func _crown_mesh() -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 2.6
	cm.height = 5.2
	cm.radial_segments = 8
	cm.rings = 1
	return cm

static func _multimesh(w: World, xfs: Array[Transform3D], mesh: Mesh, mat: Material, cols: Array[Color]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	w.add_child(mmi)

# ---------------- lake ----------------
static func _lake(w: World, b: WorldBuilder) -> void:
	var water := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = World.LAKE_R + 6.0
	cm.bottom_radius = World.LAKE_R + 6.0
	cm.height = 0.05
	cm.radial_segments = 40
	water.mesh = cm
	water.material_override = Shaders.water_material(false)
	w.add_child(water)
	water.position = Vector3(World.LAKE.x, World.WATER_Y, World.LAKE.z)
	# dock on the south shore
	var d0 := Vector3(World.LAKE.x + 4, 0, World.LAKE.z + World.LAKE_R + 4)
	d0.y = w.height(d0.x, d0.z) + 0.25
	for i in 8:
		b.box(Vector3(2.6, 0.12, 1.4), Vector3(d0.x, maxf(World.WATER_Y + 0.35, d0.y - i * 0.05), d0.z - i * 1.45), "wood", Vector3(0, rng.randf_range(-0.02, 0.02), 0), true, Color(0.6, 0.48, 0.34))
		if i % 2 == 0:
			for sx in [-1.2, 1.2]:
				b.box(Vector3(0.2, 2.2, 0.2), Vector3(d0.x + sx, World.WATER_Y - 0.5, d0.z - i * 1.45), "wood", Vector3.ZERO, false, Color(0.4, 0.3, 0.22))
	var sign := Label3D.new()
	sign.text = "GOOD FISHING\nface the water to cast"
	sign.font_size = 36
	sign.outline_size = 6
	sign.modulate = Color(0.85, 0.95, 1.0)
	sign.position = d0 + Vector3(1.6, 1.4, 1.0)
	w.add_child(sign)
	w.container("toolbox", d0 + Vector3(-1.8, 0.0, 1.5), 0.0, "", 3)

static func _cabin(w: World, b: WorldBuilder, p: Vector3, yaw: float, extra: String) -> void:
	p.y = w.height(p.x, p.z)
	var basis := Basis.from_euler(Vector3(0, yaw, 0))
	var logs := Color(0.55, 0.4, 0.27)
	var corners := [Vector3(-4, 0, -3), Vector3(4, 0, -3), Vector3(4, 0, 3), Vector3(-4, 0, 3)]
	for i in 4:
		var a: Vector3 = p + basis * corners[i]
		var e: Vector3 = p + basis * corners[(i + 1) % 4]
		var openings := []
		if i == 2:
			openings = [[4.0, 1.4, 2.3]]
		elif i == 0:
			openings = [[4.0, 1.4, 1.0]]
		b.wall(a, e, 3.0, 0.35, "wood", logs, openings)
	b.box(Vector3(9.2, 0.25, 4.2), p + basis * Vector3(0, 3.55, -1.6), "wood", Vector3(0.45, yaw, 0), true, Color(0.35, 0.25, 0.18))
	b.box(Vector3(9.2, 0.25, 4.2), p + basis * Vector3(0, 3.55, 1.6), "wood", Vector3(-0.45, yaw, 0), true, Color(0.35, 0.25, 0.18))
	b.box(Vector3(8, 0.15, 6), p + Vector3(0, 0.07, 0), "wood", Vector3(0, yaw, 0), true, Color(0.5, 0.38, 0.26))
	w.container("cabin", p + basis * Vector3(-2.5, 0, -1.8), yaw, "", 4)
	if extra == "stove":
		w.container("stove", p + basis * Vector3(2.8, 0, -1.8), yaw)
	elif extra == "bed":
		w.container("fridge", p + basis * Vector3(3.0, 0, -2.0), yaw)
	b.light(p + Vector3(0, 2.5, 0), Color(1.0, 0.7, 0.4), 6.0, 0.6)

static func _cabins(w: World, b: WorldBuilder) -> void:
	_cabin(w, b, Vector3(-175, 0, 70), 0.3, "stove")
	_cabin(w, b, Vector3(-235, 0, -55), -0.6, "bed")
	_cabin(w, b, Vector3(-206, 0, 160), 2.6, "stove")
	_cabin(w, b, Vector3(-280, 0, 10), 1.4, "")
	var note := Interactable.new().setup("note", 1, {"data": {"note": "note_wolf"}})
	w.add_child(note)
	var np := Vector3(-235, 0, -55)
	note.global_position = Vector3(np.x + 1.0, w.height(np.x, np.z) + 0.2, np.z + 1.0)
	w.add_poi("cabins", "PINEWOOD CABINS", Vector3(-206, 0, 160), 14.0, 60)

# ---------------- Scrapjaw Yard ----------------
static func _raider_camp(w: World, b: WorldBuilder) -> void:
	var c := World.RAIDERS
	var tints := [Color(0.6, 0.35, 0.2), Color(0.35, 0.5, 0.5), Color(0.75, 0.6, 0.2), Color(0.5, 0.48, 0.45), Color(0.55, 0.2, 0.15)]
	# ring wall of scrap, gap facing west (toward the road)
	var segs := 22
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var mid := (a0 + a1) * 0.5
		if absf(wrapf(mid - PI, -PI, PI)) < 0.32:
			continue
		var r := 30.0 + rng.randf_range(-1.5, 1.5)
		var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var hh := rng.randf_range(3.5, 5.5)
		var tint: Color = tints[rng.randi() % tints.size()]
		b.box(Vector3(0.35, hh, p0.distance_to(p1) + 0.6), (p0 + p1) * 0.5 + Vector3(0, hh * 0.5, 0), "corrugated", Vector3(rng.randf_range(-0.06, 0.06), -mid, rng.randf_range(-0.05, 0.05)), true, tint)
		if i % 3 == 0:
			for k in 3:
				b.box(Vector3(0.12, 1.4, 0.12), (p0 + p1) * 0.5 + Vector3(0, hh + 0.4, 0) + Vector3(cos(mid), 0, sin(mid)) * (k - 1) * 0.5, "rusty", Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)), false)
	# gate arch with sign
	var gate := c + Vector3(-31, 0, 0)
	for side in [-1.0, 1.0]:
		b.box(Vector3(0.8, 7.0, 0.8), gate + Vector3(0, 3.5, side * 5.0), "rusty", Vector3.ZERO, true, Color(0.5, 0.35, 0.25))
	b.box(Vector3(0.6, 1.4, 11.0), gate + Vector3(0, 7.0, 0), "corrugated", Vector3.ZERO, false, Color(0.4, 0.3, 0.2))
	b.neon_text("SCRAPJAW YARD", gate + Vector3(-0.4, 7.0, 0), -PI * 0.5, "orange", 140)
	for k in 5:
		b.box(Vector3(0.1, 0.1, 0.1), gate + Vector3(-0.5, 6.0 - k * 0.15, -3 + k * 1.5), "plaster", Vector3.ZERO, false, Color(0.95, 0.92, 0.85))
	# stacked car walls inside
	for i in 6:
		var a := rng.randf() * TAU
		var r2 := rng.randf_range(10.0, 22.0)
		w.car_wreck(c + Vector3(cos(a) * r2, 0, sin(a) * r2), a, rng, 7, true)
	# towers with gunners
	for tp in [c + Vector3(-24, 0, -14), c + Vector3(-24, 0, 14), c + Vector3(18, 0, -20)]:
		for lx in [-1.5, 1.5]:
			for lz in [-1.5, 1.5]:
				b.box(Vector3(0.35, 6.0, 0.35), tp + Vector3(lx, 3.0, lz), "rusty", Vector3.ZERO, true, Color(0.45, 0.35, 0.28))
		b.box(Vector3(3.8, 0.3, 3.8), tp + Vector3(0, 6.0, 0), "corrugated", Vector3.ZERO, true, Color(0.55, 0.4, 0.25))
		for k in 4:
			var off: Vector3 = [Vector3(1.9, 0, 0), Vector3(-1.9, 0, 0), Vector3(0, 0, 1.9), Vector3(0, 0, -1.9)][k]
			b.box(Vector3(0.1, 1.1, 3.8) if k < 2 else Vector3(3.8, 1.1, 0.1), tp + off + Vector3(0, 6.7, 0), "corrugated", Vector3.ZERO, true, Color(0.5, 0.42, 0.3))
		w.spawn_monster("raider", tp + Vector3(0, 6.5, 0), 7, {"leash": 3.0})
	# throne
	var th := c + Vector3(22, 0, 0)
	b.box(Vector3(7, 1.3, 7), th + Vector3(0, 0.65, 0), "rusty", Vector3.ZERO, true, Color(0.45, 0.32, 0.22))
	b.box(Vector3(2.0, 0.6, 2.0), th + Vector3(0.5, 1.6, 0), "metal", Vector3.ZERO, true, Color(0.5, 0.45, 0.3))
	b.box(Vector3(0.5, 3.5, 2.4), th + Vector3(1.6, 3.0, 0), "metal", Vector3.ZERO, true, Color(0.5, 0.45, 0.3))
	for k in 7:
		b.box(Vector3(0.12, 1.4, 0.12), th + Vector3(1.6, 5.2, -1.2 + k * 0.4), "metal", Vector3(0, 0, rng.randf_range(-0.3, 0.3)), false, Color(0.75, 0.7, 0.55))
	for k in 6:
		b.box(Vector3(0.25, 0.25, 0.25), th + Vector3(rng.randf_range(-3, 3), 1.42, rng.randf_range(-3, 3)), "plaster", Vector3(0, rng.randf(), 0), false, Color(0.95, 0.92, 0.85))
	b.neon_text("KING", th + Vector3(1.4, 6.3, 0), -PI * 0.5, "red", 90)
	w.spawn_monster("gnasher", th + Vector3(-1.0, 1.6, 0), 9, {"leash": 12.0, "name": "King Gnasher"})
	w.container("weapons", th + Vector3(2.8, 1.3, 2.5), 0.0, "", 9)
	# camp clutter, fires, tents, cages, stashes
	for bp in [c + Vector3(-12, 0, 0), c + Vector3(5, 0, 12), c + Vector3(5, 0, -12), c + Vector3(14, 0, 6), c + Vector3(-5, 0, -18), c + Vector3(-18, 0, 8)]:
		w.burning_barrel(bp)
	for tp2 in [c + Vector3(-8, 0, 16), c + Vector3(8, 0, -17), c + Vector3(-14, 0, -12)]:
		b.box(Vector3(4.0, 0.15, 3.0), tp2 + Vector3(-1.0, 1.4, 0), "corrugated", Vector3(0, 0, 0.75), true, Color(0.55, 0.45, 0.3))
		b.box(Vector3(4.0, 0.15, 3.0), tp2 + Vector3(1.0, 1.4, 0), "corrugated", Vector3(0, 0, -0.75), true, Color(0.5, 0.4, 0.28))
	for cg in [c + Vector3(-2, 0, 22), c + Vector3(12, 0, 18)]:
		for k in 8:
			var a2 := TAU * k / 8.0
			b.box(Vector3(0.08, 2.4, 0.08), cg + Vector3(cos(a2) * 1.2, 1.2, sin(a2) * 1.2), "rusty", Vector3.ZERO, true, Color(0.4, 0.35, 0.3))
		b.box(Vector3(2.6, 0.1, 2.6), cg + Vector3(0, 2.4, 0), "rusty", Vector3.ZERO, false)
	for sp in [c + Vector3(-15, 0, -4), c + Vector3(10, 0, 15), c + Vector3(16, 0, -10), c + Vector3(-4, 0, 9)]:
		w.container("raider", sp, rng.randf() * TAU, "", 7)
	w.container("ammo_box", c + Vector3(0, 0, -6), 0.4, "", 7)
	w.container("ammo_box", c + Vector3(-9, 0, 4), 1.4, "", 7)
	for i in 3:
		w.spawn_monster("raider", c + Vector3(rng.randf_range(-15, 10), 0.4, rng.randf_range(-15, 15)), 7, {"leash": 20.0})
	for i in 4:
		w.spawn_monster("psycho", c + Vector3(rng.randf_range(-15, 10), 0.4, rng.randf_range(-15, 15)), 7, {"leash": 25.0})
	b.box(Vector3(64, 0.05, 64), c + Vector3(0, 0.02, 0), "dust", Vector3.ZERO, false, Color(0.75, 0.62, 0.48))

# ---------------- gas station ----------------
static func _gas_station(w: World, b: WorldBuilder) -> void:
	var g := World.GAS
	b.box(Vector3(34, 0.1, 26), g + Vector3(0, 0.05, 0), "concrete", Vector3.ZERO, true, Color(0.65, 0.64, 0.6))
	for px in [-6.0, 6.0]:
		for pz in [-3.5, 3.5]:
			b.box(Vector3(0.4, 5.0, 0.4), g + Vector3(px - 5, 2.5, pz - 6), "metal", Vector3.ZERO, true, Color(0.7, 0.7, 0.72))
	b.box(Vector3(14, 0.6, 9), g + Vector3(-5, 5.3, -6), "metal", Vector3.ZERO, true, Color(0.8, 0.25, 0.2))
	b.box(Vector3(14.1, 0.2, 9.1), g + Vector3(-5, 5.0, -6), "glow_white", Vector3.ZERO, false)
	for k in 3:
		b.box(Vector3(0.8, 1.6, 0.6), g + Vector3(-10 + k * 5, 0.8, -6), "metal", Vector3.ZERO, true, Color(0.85, 0.82, 0.75))
	# mini-mart
	var m := g + Vector3(8, 0, 4)
	var mt := Color(0.82, 0.78, 0.7)
	b.wall(m + Vector3(-6, 0, -5), m + Vector3(6, 0, -5), 3.6, 0.3, "plaster", mt, [[3.0, 1.6, 2.4], [8.5, 4.0, 2.2]])
	b.wall(m + Vector3(-6, 0, 5), m + Vector3(6, 0, 5), 3.6, 0.3, "plaster", mt)
	b.wall(m + Vector3(-6, 0, -5), m + Vector3(-6, 0, 5), 3.6, 0.3, "plaster", mt)
	b.wall(m + Vector3(6, 0, -5), m + Vector3(6, 0, 5), 3.6, 0.3, "plaster", mt)
	b.box(Vector3(12.6, 0.3, 10.6), m + Vector3(0, 3.75, 0), "concrete", Vector3.ZERO, true, Color(0.5, 0.5, 0.5))
	w.container("supermarket", m + Vector3(-1, 0, 1.5), 0.0, "", 3)
	w.container("supermarket", m + Vector3(3, 0, 1.5), 0.0, "", 3)
	w.container("fridge", m + Vector3(5.2, 0, -2), -PI * 0.5, "", 3)
	w.container("register", m + Vector3(-4, 0, -2.5), PI * 0.5, "", 3)
	w.container("toolbox", m + Vector3(-5, 0, 4), 0.0, "", 3)
	b.neon_text("LAST CHANCE GAS", g + Vector3(-5, 6.4, -1.4), 0.0, "red", 80)
	b.light(m + Vector3(0, 3.0, 0), Color(0.85, 0.95, 1.0), 9.0, 0.8)
	w.car_wreck(g + Vector3(-9, 0, 4), 1.4, rng, 3)
	for i in 3:
		w.spawn_monster("walker", g + Vector3(rng.randf_range(-12, 12), 0.3, rng.randf_range(-10, 10)), 3)
