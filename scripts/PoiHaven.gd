class_name PoiHaven
extends RefCounted
# HAVEN — the walled safe zone. Three gates (chokepoints when the horde comes),
# guard towers, trader, workbench, kitchen, bunkhouse + stash, bounty board, campfire.

static func build(w: World, b: WorldBuilder) -> void:
	var c := World.HAVEN
	var wall_tint := Color(0.75, 0.68, 0.6)
	var x0 := c.x - 35.0
	var x1 := c.x + 35.0
	var z0 := c.z - 35.0
	var z1 := c.z + 35.0
	# concrete footing + scrap walls with gate openings
	b.wall(Vector3(x0, 0, z0), Vector3(x1, 0, z0), 4.6, 0.7, "corrugated", wall_tint, [[35.0, 10.0]])
	b.wall(Vector3(x0, 0, z1), Vector3(x1, 0, z1), 4.6, 0.7, "corrugated", wall_tint)
	b.wall(Vector3(x0, 0, z0), Vector3(x0, 0, z1), 4.6, 0.7, "corrugated", wall_tint, [[35.0, 10.0]])
	b.wall(Vector3(x1, 0, z0), Vector3(x1, 0, z1), 4.6, 0.7, "corrugated", wall_tint, [[35.0, 10.0]])
	for p in [[Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x0, 0, z1), Vector3(x1, 0, z1)], [Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1)]]:
		var a: Vector3 = p[0]
		var e: Vector3 = p[1]
		var length := a.distance_to(e)
		var dir := (e - a).normalized()
		var n := int(length / 2.2)
		for i in n:
			var t := (i + 0.5) / n
			var pos := a.lerp(e, t) + Vector3(0, 4.9, 0)
			b.box(Vector3(0.12, 0.9, 0.12), pos, "rusty", Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), false, Color(0.6, 0.55, 0.5))
		b.box(Vector3(0.9 if absf(dir.x) < 0.5 else length, 0.18, length if absf(dir.x) < 0.5 else 0.9), a.lerp(e, 0.5) + Vector3(0, 0.09, 0), "concrete", Vector3.ZERO, false, Color(0.7, 0.68, 0.64))
	# gates: frames, towers with guards, sandbags
	_gate(w, b, Vector3(c.x, 0, z0), 0.0)
	_gate(w, b, Vector3(x0, 0, c.z), PI * 0.5)
	_gate(w, b, Vector3(x1, 0, c.z), PI * 0.5)
	# ground: packed dirt yard + gravel paths
	b.box(Vector3(70, 0.06, 70), Vector3(c.x, 0.03, c.z), "dust", Vector3.ZERO, false, Color(0.82, 0.74, 0.62))
	b.box(Vector3(6, 0.08, 70), Vector3(c.x, 0.05, c.z), "cobble", Vector3.ZERO, false, Color(0.8, 0.78, 0.72))
	b.box(Vector3(70, 0.08, 6), Vector3(c.x, 0.05, c.z), "cobble", Vector3.ZERO, false, Color(0.8, 0.78, 0.72))
	# trader shack (NE)
	var tpos := c + Vector3(22, 0, -23)
	_shack(b, tpos, Vector2(10, 8), Color(0.55, 0.42, 0.3), PI * 0.5)
	w.container("trader", tpos + Vector3(-2.2, 0, 0), PI * 0.5)
	b.neon_text("MAGS' TRADING POST", tpos + Vector3(-5.2, 4.1, 0), -PI * 0.5, "orange", 70)
	# workbench shed (NW)
	var wpos := c + Vector3(-22, 0, -23)
	_shack(b, wpos, Vector2(10, 8), Color(0.5, 0.45, 0.4), -PI * 0.5)
	w.container("workbench", wpos + Vector3(1.5, 0, 0), -PI * 0.5)
	w.container("toolbox", wpos + Vector3(2.5, 1.05, 2.2), 0.0, "", 1)
	# kitchen pavilion (SW)
	var kpos := c + Vector3(-22, 0, 20)
	for px in [-4.5, 4.5]:
		for pz in [-4.5, 4.5]:
			b.box(Vector3(0.3, 3.2, 0.3), kpos + Vector3(px, 1.6, pz), "wood", Vector3.ZERO, true, Color(0.7, 0.6, 0.5))
	b.box(Vector3(10.5, 0.25, 10.5), kpos + Vector3(0, 3.3, 0), "corrugated", Vector3(0, 0, 0.05), true, Color(0.6, 0.5, 0.42))
	w.container("stove", kpos + Vector3(0, 0, -2), 0.0)
	b.box(Vector3(3.0, 0.1, 1.2), kpos + Vector3(0, 0.95, 2.2), "wood", Vector3.ZERO, true, Color(0.75, 0.6, 0.45))
	b.box(Vector3(0.1, 0.9, 1.0), kpos + Vector3(-1.4, 0.45, 2.2), "wood", Vector3.ZERO, false)
	b.box(Vector3(0.1, 0.9, 1.0), kpos + Vector3(1.4, 0.45, 2.2), "wood", Vector3.ZERO, false)
	w.container("fridge", kpos + Vector3(3.8, 0, -3.5), 0.0, "", 1)
	# bunkhouse (SE) with bed + stash
	var bpos := c + Vector3(22, 0, 22)
	b.wall(bpos + Vector3(-6, 0, -5), bpos + Vector3(6, 0, -5), 3.4, 0.35, "wood", Color(0.62, 0.48, 0.36))
	b.wall(bpos + Vector3(-6, 0, 5), bpos + Vector3(6, 0, 5), 3.4, 0.35, "wood", Color(0.62, 0.48, 0.36))
	b.wall(bpos + Vector3(-6, 0, -5), bpos + Vector3(-6, 0, 5), 3.4, 0.35, "wood", Color(0.62, 0.48, 0.36), [[5.0, 1.8, 2.4]])
	b.wall(bpos + Vector3(6, 0, -5), bpos + Vector3(6, 0, 5), 3.4, 0.35, "wood", Color(0.62, 0.48, 0.36))
	b.box(Vector3(13, 0.3, 11), bpos + Vector3(0, 3.55, 0), "corrugated", Vector3(0.05, 0, 0), true, Color(0.55, 0.42, 0.35))
	w.container("bed", bpos + Vector3(2.5, 0, 0), 0.0)
	w.container("stash", bpos + Vector3(-4.6, 0, -3.6), PI * 0.5)
	b.light(bpos + Vector3(0, 2.8, 0), Color(1.0, 0.75, 0.45), 9.0, 1.2)
	# bounty board near the north gate
	w.container("board", c + Vector3(7, 0, -28), 0.0)
	# central campfire with log benches
	w.container("campfire", c + Vector3(0, 0, 3), 0.0)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		b.box(Vector3(2.2, 0.45, 0.45), c + Vector3(cos(a) * 3.2, 0.22, 3 + sin(a) * 3.2), "bark", Vector3(0, -a + PI * 0.5, 0), true, Color(0.7, 0.6, 0.5))
	# well, garden, generator, floodlights
	b.cyl(1.0, 1.0, c + Vector3(-8, 0.5, 11), "rock", true, Color(0.7, 0.68, 0.64), 12)
	b.box(Vector3(0.15, 2.4, 0.15), c + Vector3(-8.9, 1.2, 11), "wood", Vector3.ZERO, false)
	b.box(Vector3(0.15, 2.4, 0.15), c + Vector3(-7.1, 1.2, 11), "wood", Vector3.ZERO, false)
	b.box(Vector3(2.2, 0.15, 0.15), c + Vector3(-8, 2.4, 11), "wood", Vector3.ZERO, false)
	for gx in 3:
		b.box(Vector3(2.5, 0.25, 4.0), c + Vector3(-6 + gx * 3.5, 0.12, 30), "dust", Vector3.ZERO, false, Color(0.45, 0.32, 0.22))
		for k in 4:
			b.box(Vector3(0.25, 0.5, 0.25), c + Vector3(-6 + gx * 3.5, 0.45, 28.6 + k * 0.9), "leaves", Vector3.ZERO, false, Color(0.7, 1.0, 0.6))
	b.box(Vector3(2.0, 1.4, 1.2), c + Vector3(30, 0.7, 30), "rusty", Vector3.ZERO, true, Color(0.5, 0.55, 0.4))
	for fp in [Vector3(-30, 0, -30), Vector3(30, 0, -30), Vector3(-30, 0, 30), Vector3(0, 0, 0) + Vector3(12, 0, 8)]:
		b.box(Vector3(0.2, 7.0, 0.2), c + fp + Vector3(0, 3.5, 0), "metal", Vector3.ZERO, true, Color(0.5, 0.5, 0.5))
		b.box(Vector3(0.8, 0.4, 0.5), c + fp + Vector3(0, 7.0, 0), "neon_white", Vector3.ZERO, false)
		b.light(c + fp + Vector3(0, 6.6, 0), Color(1.0, 0.92, 0.8), 22.0, 1.6, false)
	# parked buggy spot marker
	b.box(Vector3(4.5, 0.07, 7.0), c + Vector3(24, 0.04, 1), "asphalt", Vector3.ZERO, false, Color(0.6, 0.6, 0.6))
	# guards on the towers
	for gp in [Vector3(c.x - 7.5, 5.3, z0 - 2.0), Vector3(c.x + 7.5, 5.3, z0 - 2.0), Vector3(x0 - 2.0, 5.3, c.z + 7.5), Vector3(x1 + 2.0, 5.3, c.z - 7.5)]:
		w.spawn_monster("guard", gp, 6, {"name": "Haven Guard"})
	w.add_poi("haven", "HAVEN", c, 30.0, 40)

static func _gate(w: World, b: WorldBuilder, pos: Vector3, yaw: float) -> void:
	var basis := Basis.from_euler(Vector3(0, yaw, 0))
	for side in [-1.0, 1.0]:
		var tp := pos + basis * Vector3(side * 7.5, 0, -2.0)
		for lx in [-1.4, 1.4]:
			for lz in [-1.4, 1.4]:
				b.box(Vector3(0.3, 5.2, 0.3), tp + basis * Vector3(lx, 2.6, lz), "wood", Vector3(0, yaw, 0), true, Color(0.6, 0.5, 0.4))
		b.box(Vector3(3.4, 0.3, 3.4), tp + Vector3(0, 5.2, 0), "wood", Vector3(0, yaw, 0), true, Color(0.65, 0.55, 0.45))
		for k in 4:
			var off: Vector3 = [Vector3(1.6, 0, 0), Vector3(-1.6, 0, 0), Vector3(0, 0, 1.6), Vector3(0, 0, -1.6)][k]
			var sz := Vector3(0.12, 1.0, 3.4) if k < 2 else Vector3(3.4, 1.0, 0.12)
			b.box(sz, tp + basis * off + Vector3(0, 5.85, 0), "corrugated", Vector3(0, yaw, 0), true, Color(0.6, 0.55, 0.5))
		b.box(Vector3(3.8, 0.2, 3.8), tp + Vector3(0, 7.2, 0), "corrugated", Vector3(0, yaw, 0.08), false, Color(0.55, 0.45, 0.4))
		var l := b.light(tp + Vector3(0, 6.8, 0), Color(1.0, 0.8, 0.5), 16.0, 1.4)
		l.set_meta("tower", true)
		# sandbag nests outside the gate
		for i in 4:
			b.box(Vector3(0.7, 0.35, 0.4), pos + basis * Vector3(side * (6.0 + i * 0.7), 0.18, -4.5), "sandbag", Vector3(0, yaw, 0), true, Color(0.85, 0.8, 0.65))
			b.box(Vector3(0.7, 0.35, 0.4), pos + basis * Vector3(side * (6.0 + i * 0.7), 0.52, -4.5), "sandbag", Vector3(0, yaw + 0.05, 0), true, Color(0.85, 0.8, 0.65))
	# gate header sign
	b.box(Vector3(11.0, 1.0, 0.3), pos + basis * Vector3(0, 6.2, 0), "wood", Vector3(0, yaw, 0), false, Color(0.55, 0.42, 0.3))
	var lbl := Label3D.new()
	lbl.text = "HAVEN"
	lbl.font_size = 140
	lbl.outline_size = 14
	lbl.modulate = Color(1.0, 0.85, 0.35)
	w.add_child(lbl)
	lbl.position = pos + basis * Vector3(0, 6.2, -0.2)
	lbl.rotation.y = yaw + PI
	var lbl2 := lbl.duplicate() as Label3D
	w.add_child(lbl2)
	lbl2.position = pos + basis * Vector3(0, 6.2, 0.2)
	lbl2.rotation.y = yaw

static func _shack(b: WorldBuilder, pos: Vector3, size: Vector2, tint: Color, open_yaw: float) -> void:
	# three walls + roof, open toward open_yaw
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var h := 3.4
	var openside := Vector3(sin(open_yaw), 0, cos(open_yaw))
	var walls := [
		[Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(0, 0, -1)],
		[Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(0, 0, 1)],
		[Vector3(-hx, 0, -hz), Vector3(-hx, 0, hz), Vector3(-1, 0, 0)],
		[Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(1, 0, 0)],
	]
	for wl in walls:
		if (wl[2] as Vector3).dot(openside) > 0.7:
			continue
		b.wall(pos + wl[0], pos + wl[1], h, 0.3, "corrugated", tint)
	b.box(Vector3(size.x + 1.0, 0.25, size.y + 1.0), pos + Vector3(0, h + 0.15, 0), "corrugated", Vector3(0.04, 0, 0.03), true, tint.darkened(0.15))
	b.light(pos + Vector3(0, h - 0.4, 0), Color(1.0, 0.75, 0.45), 8.0, 1.0)
