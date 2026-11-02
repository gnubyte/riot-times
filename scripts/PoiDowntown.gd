class_name PoiDowntown
extends RefCounted
# DOWNTOWN: the plaza ringed by wrecked skyscrapers, an explorable office ruin with a
# sniper perch, a parking garage you can drive up, and below it all the GALLERIA UNDER:
# a dead neon mall (stores, food court, atrium fountain under a broken skylight) and
# a service sub-level where something sleeps.

const Y := World.MALL_Y          # mall floor top
const CEIL := -6.0               # corridor ceiling (bottom)
const SUB := -17.5               # sub-level floor top
static var rng := RandomNumberGenerator.new()

static func build(w: World, b: WorldBuilder) -> void:
	rng.seed = 90210
	_plaza(w, b)
	_mall_shell(w, b)
	_stores(w, b)
	_atrium(w, b)
	_sublevel(w, b)
	_ring_towers(w, b)
	_office_ruin(w, b, Vector3(-70, 0, -45))
	_garage(w, b, Vector3(40, 0, -24))
	_blocks(w, b)
	_streets(w, b)
	_residents(w)
	w.add_poi("plaza", "DOWNTOWN PLAZA", World.PLAZA, 40.0, 150)
	w.add_poi("mall", "GALLERIA UNDER", Vector3(0, Y, -80), 30.0, 250)
	w.add_poi("sublevel", "SERVICE LEVEL", Vector3(0, SUB, -115), 25.0, 300)
	w.add_poi("meridian", "MERIDIAN TOWER", Vector3(-70, 12, -45), 18.0, 150)
	w.add_poi("garage", "PLAZA PARKING", Vector3(58, 4, -4), 20.0, 100)

# ---------------- plaza (the roof of the mall) ----------------
static func _plaza(w: World, b: WorldBuilder) -> void:
	var t := Color(0.82, 0.8, 0.76)
	b.box(Vector3(80, 0.6, 20), Vector3(0, -0.25, -100), "cobble", Vector3.ZERO, true, t)
	b.box(Vector3(80, 0.6, 10), Vector3(0, -0.25, -65), "cobble", Vector3.ZERO, true, t)
	b.box(Vector3(30, 0.6, 20), Vector3(-25, -0.25, -80), "cobble", Vector3.ZERO, true, t)
	b.box(Vector3(30, 0.6, 20), Vector3(25, -0.25, -80), "cobble", Vector3.ZERO, true, t)
	b.box(Vector3(33.5, 0.6, 30), Vector3(-23.25, -0.25, -45), "cobble", Vector3.ZERO, true, t)
	b.box(Vector3(33.5, 0.6, 30), Vector3(23.25, -0.25, -45), "cobble", Vector3.ZERO, true, t)
	b.box(Vector3(13, 0.6, 2), Vector3(0, -0.25, -31), "cobble", Vector3.ZERO, true, t)
	for oc in [[Vector3(80, 0.55, 20), Vector3(0, -0.25, -100)], [Vector3(80, 0.55, 10), Vector3(0, -0.25, -65)], [Vector3(30, 0.55, 20), Vector3(-25, -0.25, -80)], [Vector3(30, 0.55, 20), Vector3(25, -0.25, -80)], [Vector3(33.5, 0.55, 30), Vector3(-23.25, -0.25, -45)], [Vector3(33.5, 0.55, 30), Vector3(23.25, -0.25, -45)]]:
		b.occluder(oc[0], oc[1])
	# curb ring
	for e in [[Vector3(0, 0.1, -110.3), Vector3(80.6, 0.2, 0.6)], [Vector3(0, 0.1, -29.7), Vector3(80.6, 0.2, 0.6)], [Vector3(-40.3, 0.1, -70), Vector3(0.6, 0.2, 80)], [Vector3(40.3, 0.1, -70), Vector3(0.6, 0.2, 80)]]:
		b.box(e[1], e[0], "concrete", Vector3.ZERO, false, Color(0.7, 0.7, 0.68))
	# skylight frame + railing around the hole
	var rail := Color(0.45, 0.45, 0.48)
	for side in [-1.0, 1.0]:
		b.box(Vector3(20.4, 1.0, 0.12), Vector3(0, 0.5, -80 + side * 10.1), "metal", Vector3.ZERO, true, rail)
		b.box(Vector3(0.12, 1.0, 20.4), Vector3(side * 10.1, 0.5, -80), "metal", Vector3.ZERO, true, rail)
	for i in 5:
		b.box(Vector3(0.25, 0.25, 20.0), Vector3(-8 + i * 4, -0.4, -80), "metal", Vector3.ZERO, false, Color(0.3, 0.3, 0.32))
	b.box(Vector3(6.0, 0.05, 4.0), Vector3(-5, -0.42, -76), "glass", Vector3(0.1, 0.2, 0.05), false)
	b.box(Vector3(4.0, 0.05, 3.0), Vector3(6, -0.42, -85), "glass", Vector3(-0.08, 0.6, 0.1), false)
	# grand stair entrance with canopy and neon
	b.ramp(Vector3(0, Y, -58), Vector3(0, 0.0, -34), 12.6, "concrete", true, Color(0.75, 0.74, 0.72))
	for x in [-6.5, 6.5]:
		b.box(Vector3(0.5, 13.2, 28.0), Vector3(x, Y + 6.6 - 0.6, -46.0), "tile", Vector3.ZERO, true, Color(0.55, 0.6, 0.65))
		b.box(Vector3(0.4, 1.1, 28.0), Vector3(x, 0.55, -46.0), "metal", Vector3.ZERO, true, rail)
	for x in [-6.2, 6.2]:
		b.box(Vector3(0.25, 4.0, 0.25), Vector3(x, 2.0, -33.0), "metal", Vector3.ZERO, true, rail)
	b.box(Vector3(13.6, 0.3, 4.0), Vector3(0, 4.1, -33.5), "metal", Vector3(-0.08, 0, 0), true, Color(0.25, 0.25, 0.28))
	b.neon_text("GALLERIA UNDER", Vector3(0, 4.9, -31.6), 0.0, "pink", 150)
	b.box(Vector3(10.5, 0.12, 0.12), Vector3(0, 4.45, -31.7), "neon_cyan", Vector3.ZERO, false)
	# statue, planters, benches
	b.box(Vector3(4, 1.6, 4), Vector3(-22, 0.8, -95), "concrete", Vector3.ZERO, true, Color(0.6, 0.6, 0.58))
	b.box(Vector3(0.9, 2.2, 0.6), Vector3(-22, 2.7, -95), "metal", Vector3(0, 0.3, 0), true, Color(0.35, 0.45, 0.38))
	b.box(Vector3(0.4, 1.4, 0.3), Vector3(-21.4, 3.3, -95), "metal", Vector3(0, 0.3, -0.9), false, Color(0.35, 0.45, 0.38))
	for p in [Vector3(-28, 0, -52), Vector3(28, 0, -52), Vector3(-28, 0, -102), Vector3(28, 0, -102), Vector3(24, 0, -66), Vector3(-24, 0, -66)]:
		b.box(Vector3(3, 0.8, 3), p + Vector3(0, 0.4, 0), "concrete", Vector3.ZERO, true, Color(0.6, 0.58, 0.55))
		b.cyl(0.18, 4.5, p + Vector3(0, 3.0, 0), "bark", true, Color(0.5, 0.4, 0.32), 6)
		for k in 3:
			b.box(Vector3(0.12, 0.12, 2.0), p + Vector3(0, 3.6 + k * 0.6, 0), "bark", Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * PI, 0.6), false, Color(0.45, 0.35, 0.3))
	for i in 6:
		var bp := Vector3(rng.randf_range(-34, 34), 0, rng.randf_range(-105, -40))
		if absf(bp.x) < 12.0 and bp.z < -60.0 and bp.z > -95.0:
			continue
		b.box(Vector3(2.4, 0.45, 0.7), bp + Vector3(0, 0.45, 0), "wood", Vector3(0, rng.randf() * PI, 0), true, Color(0.55, 0.42, 0.3))
	# quarantine checkpoint
	var cp := Vector3(22, 0, -40)
	for i in 8:
		b.box(Vector3(0.75, 0.38, 0.45), cp + Vector3(-5 + i * 0.75, 0.19, -4), "sandbag", Vector3(0, rng.randf_range(-0.05, 0.05), 0), true, Color(0.82, 0.78, 0.62))
		b.box(Vector3(0.75, 0.38, 0.45), cp + Vector3(-5 + i * 0.75, 0.55, -4), "sandbag", Vector3(0, rng.randf_range(-0.05, 0.05), 0), true, Color(0.82, 0.78, 0.62))
	b.box(Vector3(5, 2.6, 4), cp + Vector3(2, 1.3, 2), "corrugated", Vector3(0, 0.2, 0), true, Color(0.35, 0.42, 0.3))
	w.container("military", cp + Vector3(-2.5, 0, 0), 0.4)
	w.container("ammo_box", cp + Vector3(-0.8, 0, 1.2), 1.2)
	var sign := Label3D.new()
	sign.text = "QUARANTINE CHECKPOINT\nNO ENTRY BELOW"
	sign.font_size = 46
	sign.outline_size = 8
	sign.modulate = Color(1.0, 0.85, 0.2)
	sign.position = cp + Vector3(-2, 1.6, -4.3)
	sign.rotation.y = PI
	w.add_child(sign)
	# crashed helicopter
	var hp := Vector3(-26, 0, -42)
	b.box(Vector3(3.2, 2.6, 8.0), hp + Vector3(0, 1.2, 0), "metal", Vector3(0.0, 0.7, 0.35), true, Color(0.3, 0.35, 0.28))
	b.box(Vector3(0.8, 0.8, 7.0), hp + Vector3(3.4, 1.3, 4.6), "metal", Vector3(0.1, 0.7, 0.4), true, Color(0.3, 0.35, 0.28))
	for k in 3:
		b.box(Vector3(0.35, 0.08, 7.5), hp + Vector3(0, 2.8, 0), "metal", Vector3(0.2, k * 1.1, 0.15), false, Color(0.2, 0.2, 0.22))
	w.burning_barrel(hp + Vector3(4, 0, -3))
	w.container("military", hp + Vector3(-2.5, 0, 2.5), 0.9)

# ---------------- mall shell ----------------
static func _mall_shell(w: World, b: WorldBuilder) -> void:
	var floor_t := Color(0.85, 0.83, 0.8)
	# floor slab with the service-stair hole (x 51.5..57.5, z -57..-43)
	b.box(Vector3(111.5, 0.4, 80), Vector3(-4.25, Y - 0.2, -80), "tile", Vector3.ZERO, true, floor_t)
	b.occluder(Vector3(111.0, 0.35, 79.5), Vector3(-4.25, Y - 0.2, -80))
	b.box(Vector3(8.5, 0.4, 63), Vector3(55.75, Y - 0.2, -88.5), "tile", Vector3.ZERO, true, floor_t)
	b.box(Vector3(8.5, 0.4, 3), Vector3(55.75, Y - 0.2, -41.5), "tile", Vector3.ZERO, true, floor_t)
	b.box(Vector3(2.5, 0.4, 14), Vector3(58.75, Y - 0.2, -50), "tile", Vector3.ZERO, true, floor_t)
	# ceiling (corridor height 6 m), open over the atrium and stairwell
	var ct := Color(0.5, 0.5, 0.52)
	var cy := CEIL + 0.2
	for oc in [[Vector3(120, 0.4, 25), Vector3(0, cy, -107.5)], [Vector3(120, 0.4, 5), Vector3(0, cy, -62.5)], [Vector3(45, 0.4, 30), Vector3(-37.5, cy, -80)], [Vector3(45, 0.4, 30), Vector3(37.5, cy, -80)], [Vector3(53.5, 0.4, 20), Vector3(-33.25, cy, -50)], [Vector3(53.5, 0.4, 20), Vector3(33.25, cy, -50)]]:
		b.occluder(oc[0], oc[1])
	b.box(Vector3(120, 0.4, 25), Vector3(0, cy, -107.5), "concrete", Vector3.ZERO, true, ct)
	b.box(Vector3(120, 0.4, 5), Vector3(0, cy, -62.5), "concrete", Vector3.ZERO, true, ct)
	b.box(Vector3(45, 0.4, 30), Vector3(-37.5, cy, -80), "concrete", Vector3.ZERO, true, ct)
	b.box(Vector3(45, 0.4, 30), Vector3(37.5, cy, -80), "concrete", Vector3.ZERO, true, ct)
	b.box(Vector3(53.5, 0.4, 20), Vector3(-33.25, cy, -50), "concrete", Vector3.ZERO, true, ct)
	b.box(Vector3(53.5, 0.4, 20), Vector3(33.25, cy, -50), "concrete", Vector3.ZERO, true, ct)
	# outer walls
	var wt := Color(0.62, 0.6, 0.66)
	b.wall(Vector3(-60, Y, -120), Vector3(60, Y, -120), 6.0, 0.6, "tile", wt)
	b.wall(Vector3(-60, Y, -40), Vector3(60, Y, -40), 6.0, 0.6, "tile", wt, [[60.0, 13.0]])
	b.wall(Vector3(-60, Y, -120), Vector3(-60, Y, -40), 6.0, 0.6, "tile", wt)
	b.wall(Vector3(60, Y, -120), Vector3(60, Y, -40), 6.0, 0.6, "tile", wt)
	# atrium upper gallery walls (ceiling to plaza slab)
	var ah := -0.6 - CEIL
	for z in [-95.0, -65.0]:
		b.box(Vector3(30, ah, 0.5), Vector3(0, CEIL + ah * 0.5, z), "tile", Vector3.ZERO, true, Color(0.7, 0.68, 0.74))
	for x in [-15.0, 15.0]:
		b.box(Vector3(0.5, ah, 30), Vector3(x, CEIL + ah * 0.5, -80), "tile", Vector3.ZERO, true, Color(0.7, 0.68, 0.74))
	# gallery balcony ring with neon trim
	for z in [-94.0, -66.0]:
		b.box(Vector3(28, 0.3, 2.0), Vector3(0, CEIL + 0.8, z + (1.0 if z < -80.0 else -1.0)), "tile", Vector3.ZERO, true, Color(0.75, 0.72, 0.78))
		b.box(Vector3(28, 0.08, 0.08), Vector3(0, CEIL + 0.98, z + (2.0 if z < -80.0 else -2.0)), "neon_purple", Vector3.ZERO, false)
	# dead ceiling panels + a few live ones
	for i in 10:
		var lp := Vector3(rng.randf_range(-50, 50), CEIL - 0.05, [-80.0, -62.0, -105.0][i % 3] + rng.randf_range(-3, 3))
		var live := i % 3 == 0
		b.box(Vector3(2.4, 0.1, 0.6), lp, "glow_white" if live else "metal", Vector3.ZERO, false, Color(0.3, 0.3, 0.3))
		if live:
			var l := b.light(lp + Vector3(0, -0.6, 0), Color(0.85, 0.9, 1.0), 12.0, 1.3)
			w._flicker.append({"l": l, "base": 1.3})
	# exit signs
	for p in [Vector3(-59.6, Y + 4.8, -80), Vector3(59.6, Y + 4.8, -100), Vector3(0, Y + 5.2, -119.6)]:
		b.box(Vector3(0.2 if absf(p.x) > 50.0 else 1.2, 0.4, 1.2 if absf(p.x) > 50.0 else 0.2), p, "neon_green", Vector3.ZERO, false)

# ---------------- stores ----------------
static func _storefront(b: WorldBuilder, z: float, x0: float, x1: float, centers: Array) -> void:
	var openings := []
	for cx in centers:
		openings.append([float(cx) - x0, 8.0, 4.2])
	b.wall(Vector3(x0, Y, z), Vector3(x1, Y, z), 6.0, 0.5, "tile", Color(0.55, 0.55, 0.62), openings)

static func _stores(w: World, b: WorldBuilder) -> void:
	var zt := Color(0.6, 0.6, 0.66)
	# storefront walls
	_storefront(b, -73.0, -60.0, -15.0, [-52.5, -37.5, -22.5])
	_storefront(b, -73.0, 15.0, 60.0, [22.5, 45.0])
	_storefront(b, -87.0, -60.0, -15.0, [-45.0, -22.5])
	_storefront(b, -87.0, 15.0, 60.0, [22.5, 45.0])
	# partitions
	for x in [-45.0, -30.0, 30.0]:
		b.wall(Vector3(x, Y, -73), Vector3(x, Y, -40), 6.0, 0.4, "plaster", zt)
	for x in [-30.0, 30.0]:
		b.wall(Vector3(x, Y, -120), Vector3(x, Y, -87), 6.0, 0.4, "plaster", zt)
	# concourse side walls of the inner stores (with side doors)
	for x in [-15.0, 15.0]:
		b.wall(Vector3(x, Y, -65), Vector3(x, Y, -40), 6.0, 0.5, "tile", Color(0.58, 0.56, 0.64), [[12.0, 4.0, 3.2]])
		b.wall(Vector3(x, Y, -120), Vector3(x, Y, -95), 6.0, 0.5, "tile", Color(0.58, 0.56, 0.64), [[13.0, 4.0, 3.2]])
	# signs (south stores face -Z, north stores face +Z)
	b.neon_text("RX PLUS", Vector3(-52.5, Y + 5.1, -73.35), PI, "green", 110)
	b.neon_text("THREADZ", Vector3(-37.5, Y + 5.1, -73.35), PI, "pink", 110)
	b.neon_text("VOLTAGE", Vector3(-22.5, Y + 5.1, -73.35), PI, "cyan", 100)
	b.neon_text("LOCK & LOAD", Vector3(22.5, Y + 5.1, -73.35), PI, "red", 80)
	b.neon_text("FRESHWAY MARKET", Vector3(45.0, Y + 5.1, -73.35), PI, "yellow", 110)
	b.neon_text("FOOD COURT", Vector3(-45.0, Y + 5.1, -86.65), 0.0, "orange", 120)
	b.neon_text("TOY ATTIC", Vector3(-22.5, Y + 5.1, -86.65), 0.0, "yellow", 90, false)
	b.neon_text("PEAK SPORTS", Vector3(22.5, Y + 5.1, -86.65), 0.0, "blue", 85)
	b.neon_text("NEON ARCADE", Vector3(45.0, Y + 5.1, -86.65), 0.0, "purple", 110)
	# --- pharmacy
	_counter(b, Vector3(-52.5, Y, -45), 10.0, Color(0.85, 0.88, 0.9))
	for i in 3:
		w.container("pharmacy", Vector3(-58.6, Y, -50 - i * 6.0), PI * 0.5, "mall", 7)
	w.container("register", Vector3(-52.5, Y, -47.5), PI, "mall", 7)
	# --- clothing
	for i in 4:
		var cp := Vector3(-41 + (i % 2) * 7.0, Y, -66 + (i / 2) * 10.0)
		if i < 3:
			w.container("clothing", cp, rng.randf() * PI, "mall", 7)
		else:
			b.box(Vector3(1.4, 0.05, 0.05), cp + Vector3(0, 1.6, 0), "metal", Vector3.ZERO, false)
	for i in 3:
		b.box(Vector3(0.45, 1.8, 0.3), Vector3(-43 + i * 2.5, Y + 0.9, -45), "plaster", Vector3.ZERO, true, Color(0.92, 0.88, 0.82))
	# --- electronics
	for i in 4:
		var tv := Vector3(-28.8, Y + 1.6 + (i % 2) * 1.2, -50 - (i / 2) * 6.0)
		b.box(Vector3(0.2, 1.0, 1.7), tv, "glow_cyan" if i % 2 == 0 else "glow_blue", Vector3.ZERO, false)
	w.container("crate", Vector3(-22, Y, -55), 0.3, "mall", 7)
	w.container("register", Vector3(-22.5, Y, -47), PI, "mall", 7)
	# --- gun store
	_counter(b, Vector3(22.5, Y, -58), 10.0, Color(0.3, 0.28, 0.26))
	w.container("weapons", Vector3(25.5, Y, -45), PI, "mall", 8)
	w.container("weapons", Vector3(19.5, Y, -45), PI, "mall", 8)
	for i in 3:
		w.container("ammo_box", Vector3(17 + i * 1.2, Y + 1.05, -58), rng.randf() * PI, "mall", 8)
	w.container("locker", Vector3(29, Y, -50), -PI * 0.5, "mall", 8)
	for i in 5:
		b.box(Vector3(0.1, 0.08, 1.0), Vector3(29.6, Y + 2.0 + (i % 2) * 0.6, -63 + i * 1.6), "metal", Vector3.ZERO, false, Color(0.2, 0.2, 0.2))
	# --- supermarket
	for row in 3:
		for k in 2:
			var sp := Vector3(36 + row * 8.0, Y, -64 + k * 9.0)
			w.container("supermarket", sp, PI * 0.5, "mall", 7)
			b.box(Vector3(0.7, 1.9, 5.0), sp + Vector3(0, 0.95, 4.0), "metal", Vector3.ZERO, true, Color(0.55, 0.57, 0.6))
	for i in 2:
		w.container("fridge", Vector3(32 + i * 1.0, Y, -41.0), PI, "mall", 7)
	for i in 2:
		w.container("register", Vector3(36 + i * 6.0, Y, -70.0), 0.0, "mall", 7)
	b.box(Vector3(6.4, 1.1, 0.3), Vector3(54.5, Y + 0.55, -57.4), "metal", Vector3.ZERO, true, Color(0.4, 0.4, 0.4))
	var svc := Label3D.new()
	svc.text = "SERVICE\nSTAFF ONLY"
	svc.font_size = 40
	svc.modulate = Color(1.0, 0.25, 0.2)
	svc.position = Vector3(54.5, Y + 2.6, -58.0)
	svc.rotation.y = 0.0
	w.add_child(svc)
	b.light(Vector3(54.5, Y + 3.5, -55), Color(1.0, 0.15, 0.1), 7.0, 1.4)
	# --- food court
	for i in 3:
		var fc := Vector3(-55 + i * 10.0, Y, -117)
		_counter(b, fc + Vector3(0, 0, 2), 8.0, Color(0.6, 0.3, 0.25).lerp(Color(0.3, 0.3, 0.6), i * 0.4))
		w.container("fridge", fc + Vector3(-3, 0, -1.2), 0.0, "mall", 7)
	b.neon_text("NOODLE NOVA", Vector3(-55, Y + 3.6, -118.9), 0.0, "purple", 60, false)
	b.neon_text("BURGER BLAST", Vector3(-45, Y + 3.6, -118.9), 0.0, "orange", 60, false)
	b.neon_text("TACO TOMB", Vector3(-35, Y + 3.6, -118.9), 0.0, "green", 60)
	w.container("register", Vector3(-45, Y, -112.5), 0.0, "mall", 7)
	for i in 8:
		var tp := Vector3(-55 + (i % 4) * 7.0, Y, -100 - (i / 4) * 6.0)
		b.cyl(0.9, 0.08, tp + Vector3(0, 0.95, 0), "plaster", true, Color(0.9, 0.9, 0.88), 10)
		b.cyl(0.08, 0.95, tp + Vector3(0, 0.47, 0), "metal", false, Color(0.4, 0.4, 0.4), 6)
	# --- toy store
	for i in 2:
		w.container("crate", Vector3(-25 + i * 5.0, Y, -110), rng.randf() * PI, "mall", 7)
	w.container("register", Vector3(-22.5, Y, -92), 0.0, "mall", 7)
	for i in 12:
		b.box(Vector3(0.18, 0.3, 0.12), Vector3(-29 + rng.randf() * 1.0, Y + 0.9 + (i % 4) * 0.45, -100 - (i / 4) * 2.0), "plaster", Vector3.ZERO, false, Color.from_hsv(rng.randf(), 0.4, 0.9))
	# --- sports
	w.container("locker", Vector3(17, Y, -105), PI * 0.5, "mall", 7)
	w.container("crate", Vector3(25, Y, -112), 0.0, "mall", 7)
	w.container("crate", Vector3(27, Y, -100), 0.6, "mall", 7)
	# --- arcade
	for i in 10:
		var ap := Vector3(33 + (i % 5) * 5.5, Y, -112 + (i / 5) * 12.0)
		b.box(Vector3(1.0, 2.0, 0.9), ap + Vector3(0, 1.0, 0), "metal", Vector3.ZERO, true, Color(0.15, 0.12, 0.2))
		b.box(Vector3(0.8, 0.6, 0.05), ap + Vector3(0, 1.45, 0.46), ["glow_pink", "glow_cyan", "glow_purple", "glow_yellow"][i % 4], Vector3.ZERO, false)
	b.light(Vector3(45, Y + 2.5, -106), Color(0.7, 0.3, 1.0), 14.0, 1.6)
	w.container("register", Vector3(55, Y, -95), PI * 0.5, "mall", 7)
	w.container("crate", Vector3(38, Y, -95), 0.0, "mall", 7)

static func _counter(b: WorldBuilder, pos: Vector3, length: float, tint: Color) -> void:
	b.box(Vector3(length, 1.05, 0.9), pos + Vector3(0, 0.52, 0), "wood", Vector3.ZERO, true, tint)

# ---------------- atrium ----------------
static func _atrium(w: World, b: WorldBuilder) -> void:
	var c := Vector3(0, Y, -80)
	# fountain basin
	for i in 16:
		var a := TAU * i / 16.0
		b.box(Vector3(2.6, 0.8, 0.5), c + Vector3(cos(a) * 6.0, 0.4, sin(a) * 6.0), "tile", Vector3(0, -a + PI * 0.5, 0), true, Color(0.7, 0.75, 0.8))
	var water := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 5.8
	cm.bottom_radius = 5.8
	cm.height = 0.05
	cm.radial_segments = 24
	water.mesh = cm
	water.material_override = Shaders.water_material(false)
	w.add_child(water)
	water.position = c + Vector3(0, 0.55, 0)
	b.cyl(0.9, 2.4, c + Vector3(0, 1.2, 0), "tile", true, Color(0.75, 0.75, 0.8), 10)
	b.box(Vector3(1.2, 1.6, 0.8), c + Vector3(0, 3.2, 0), "metal", Vector3(0, 0.4, 0), true, Color(0.5, 0.6, 0.55))
	# planters + dead trees, benches
	for p in [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(-11, 0, 11), Vector3(11, 0, 11)]:
		b.box(Vector3(3, 0.9, 3), c + p + Vector3(0, 0.45, 0), "tile", Vector3.ZERO, true, Color(0.6, 0.62, 0.66))
		b.cyl(0.22, 6.0, c + p + Vector3(0, 3.6, 0), "bark", true, Color(0.45, 0.38, 0.3), 6)
		for k in 4:
			b.box(Vector3(0.14, 0.14, 2.6), c + p + Vector3(0, 4.2 + k * 0.7, 0), "bark", Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * PI, 0.5), false, Color(0.42, 0.34, 0.28))
	# decorative escalators to the gallery, blocked with rubble
	for side in [-1.0, 1.0]:
		b.ramp(c + Vector3(side * 12.0, 0, 12), c + Vector3(side * 12.0, 5.4, 2), 2.2, "metal", true, Color(0.45, 0.45, 0.5))
		for k in 5:
			b.box(Vector3(rng.randf_range(0.6, 1.5), rng.randf_range(0.4, 1.0), rng.randf_range(0.6, 1.5)), c + Vector3(side * 12.0 + rng.randf_range(-1, 1), 5.6 + k * 0.3, 2.0 + rng.randf_range(-1, 1)), "concrete", Vector3(rng.randf(), rng.randf(), rng.randf()), true, Color(0.6, 0.58, 0.55))
	# fallen skylight frame + glass
	b.box(Vector3(0.3, 0.3, 9.0), c + Vector3(-4, 0.4, 6), "metal", Vector3(0.1, 0.5, 0.3), true, Color(0.3, 0.3, 0.32))
	b.box(Vector3(3.0, 0.05, 2.0), c + Vector3(-3, 0.1, 7), "glass", Vector3(0.0, 0.4, 0.05), false)
	# light falling through the skylight + neon ring
	var sl := SpotLight3D.new()
	sl.light_color = Color(0.85, 0.9, 1.0)
	sl.light_energy = 2.5
	sl.spot_range = 22.0
	sl.spot_angle = 40.0
	sl.shadow_enabled = true
	sl.rotation.x = -PI * 0.5
	w.add_child(sl)
	sl.position = Vector3(0, -0.8, -80)
	sl.set_meta("skylight", true)
	w.set_meta("skylight", sl)
	for i in 12:
		var a2 := TAU * i / 12.0
		b.box(Vector3(3.2, 0.1, 0.1), c + Vector3(cos(a2) * 13.5, 5.2, sin(a2) * 13.5), "neon_pink" if i % 2 == 0 else "neon_cyan", Vector3(0, -a2 + PI * 0.5, 0), false)
	b.light(c + Vector3(0, 4.5, 0), Color(1.0, 0.4, 0.8), 18.0, 1.4)

# ---------------- service sub-level ----------------
static func _sublevel(w: World, b: WorldBuilder) -> void:
	var wt := Color(0.42, 0.42, 0.4)
	var h := (Y - 0.4) - SUB
	var fl := Color(0.45, 0.44, 0.42)
	# stairs down from the supermarket back
	b.ramp(Vector3(54.5, SUB, -57), Vector3(54.5, Y, -43.2), 5.8, "metal", true, Color(0.4, 0.4, 0.42))
	b.wall(Vector3(51.5, SUB, -43), Vector3(51.5, SUB, -57), h + 0.4, 0.3, "concrete", wt)
	b.wall(Vector3(51.5, SUB, -43), Vector3(58, SUB, -43), h + 0.4, 0.3, "concrete", wt)
	for r in [[Vector3(50, SUB, -57), Vector3(58, SUB, -118)], [Vector3(-58, SUB, -118), Vector3(58, SUB, -112)], [Vector3(-58, SUB, -112), Vector3(-52, SUB, -60)], [Vector3(-58, SUB, -66), Vector3(-40, SUB, -50)], [Vector3(22, SUB, -108), Vector3(50, SUB, -88)]]:
		var a: Vector3 = r[0]
		var e: Vector3 = r[1]
		var size := Vector3(absf(e.x - a.x), 0.5, absf(e.z - a.z))
		b.box(size, Vector3((a.x + e.x) * 0.5, SUB - 0.25, (a.z + e.z) * 0.5), "concrete", Vector3.ZERO, true, fl)
	b.box(Vector3(8, 0.5, 14), Vector3(54, SUB - 0.25, -50), "concrete", Vector3.ZERO, true, fl)
	# east tunnel
	b.wall(Vector3(50, SUB, -57), Vector3(50, SUB, -112), h, 0.4, "concrete", wt, [[41.0, 4.0, 3.2]])
	b.wall(Vector3(58, SUB, -43), Vector3(58, SUB, -118), h, 0.4, "concrete", wt)
	# north tunnel
	b.wall(Vector3(50, SUB, -112), Vector3(-52, SUB, -112), h, 0.4, "concrete", wt)
	b.wall(Vector3(58, SUB, -118), Vector3(-58, SUB, -118), h, 0.4, "concrete", wt)
	# west tunnel + storage
	b.wall(Vector3(-52, SUB, -112), Vector3(-52, SUB, -66), h, 0.4, "concrete", wt)
	b.wall(Vector3(-58, SUB, -118), Vector3(-58, SUB, -50), h, 0.4, "concrete", wt)
	b.wall(Vector3(-52, SUB, -66), Vector3(-40, SUB, -66), h, 0.4, "concrete", wt)
	b.wall(Vector3(-40, SUB, -66), Vector3(-40, SUB, -50), h, 0.4, "concrete", wt)
	b.wall(Vector3(-58, SUB, -50), Vector3(-40, SUB, -50), h, 0.4, "concrete", wt)
	# boiler room
	b.wall(Vector3(22, SUB, -108), Vector3(50, SUB, -108), h, 0.4, "concrete", wt)
	b.wall(Vector3(22, SUB, -88), Vector3(50, SUB, -88), h, 0.4, "concrete", wt)
	b.wall(Vector3(22, SUB, -108), Vector3(22, SUB, -88), h, 0.4, "concrete", wt)
	for i in 3:
		b.cyl(2.2, 4.0, Vector3(28 + i * 7.5, SUB + 2.0, -102), "rusty", true, Color(0.5, 0.42, 0.35), 12)
	# pipes along tunnels
	for seg in [[Vector3(57.4, SUB + 4.2, -80), Vector3(0.3, 0.3, 70), 0], [Vector3(0, SUB + 4.3, -117.4), Vector3(112, 0.3, 0.3), 0], [Vector3(-57.4, SUB + 4.2, -88), Vector3(0.3, 0.3, 60), 0]]:
		b.box(seg[1], seg[0], "rusty", Vector3.ZERO, false, Color(0.45, 0.4, 0.35))
	# red emergency lights
	for lp in [Vector3(54, SUB + 4.0, -70), Vector3(54, SUB + 4.0, -105), Vector3(10, SUB + 4.0, -115), Vector3(-30, SUB + 4.0, -115), Vector3(-55, SUB + 4.0, -85), Vector3(36, SUB + 4.4, -98)]:
		b.box(Vector3(0.4, 0.2, 0.4), lp + Vector3(0, 0.6, 0), "neon_red", Vector3.ZERO, false)
		var l := b.light(lp, Color(1.0, 0.12, 0.08), 13.0, 1.8)
		w._flicker.append({"l": l, "base": 1.8})
	# loot
	w.container("lab", Vector3(46, SUB, -90), PI, "", 10)
	w.container("military", Vector3(25, SUB, -91), 0.0, "", 10)
	w.container("weapons", Vector3(-48, SUB, -56), 0.0, "", 9)
	w.container("ammo_box", Vector3(-44, SUB, -62), 0.4, "", 9)
	w.container("ammo_box", Vector3(-55, SUB, -60), 1.4, "", 9)
	w.container("toolbox", Vector3(-55.5, SUB, -95), 0.0, "", 9)
	var note := Interactable.new().setup("note", 1, {"data": {"note": "note_mall"}})
	w.add_child(note)
	note.global_position = Vector3(53, SUB + 0.02, -62)

# ---------------- skyscrapers ----------------
static func _tower(w: World, b: WorldBuilder, pos: Vector3, size: Vector2, h: float, style := "", neon := "") -> void:
	var glass_tints := [Color(0.55, 0.7, 0.85), Color(0.6, 0.62, 0.66), Color(0.75, 0.6, 0.45), Color(0.5, 0.65, 0.6)]
	var tint: Color = glass_tints[rng.randi() % glass_tints.size()]
	var conc := Color(0.72, 0.7, 0.66).darkened(rng.randf_range(0.0, 0.25))
	var y0 := w.height(pos.x, pos.z)
	# podium
	b.box(Vector3(size.x + 2.0, 5.0, size.y + 2.0), Vector3(pos.x, y0 + 2.5, pos.z), "concrete", Vector3.ZERO, true, conc)
	b.box(Vector3(size.x + 2.1, 2.6, size.y + 2.1), Vector3(pos.x, y0 + 1.6, pos.z), "windows", Vector3.ZERO, false, Color(0.35, 0.38, 0.4))
	if neon != "":
		var yaw := 0.0
		b.neon_text(neon, Vector3(pos.x, y0 + 3.6, pos.z + size.y * 0.5 + 1.08), yaw, ["pink", "cyan", "yellow", "red", "purple"][rng.randi() % 5], 90)
	var top := h
	var lean := style == "lean"
	var jag := style == "jagged"
	var shaft_h := h - 5.0
	if lean:
		shaft_h = h * 0.6
	b.box(Vector3(size.x, shaft_h, size.y), Vector3(pos.x, y0 + 5.0 + shaft_h * 0.5, pos.z), "windows", Vector3.ZERO, true, tint)
	b.occluder(Vector3(size.x - 0.4, shaft_h - 0.4, size.y - 0.4), Vector3(pos.x, y0 + 5.0 + shaft_h * 0.5, pos.z))
	var bands := int(shaft_h / 12.0)
	for i in bands:
		b.box(Vector3(size.x + 0.5, 0.6, size.y + 0.5), Vector3(pos.x, y0 + 5.0 + (i + 1) * 12.0, pos.z), "concrete", Vector3.ZERO, false, conc)
	if lean:
		var lh := h - shaft_h - 5.0
		var pivot := Vector3(pos.x + size.x * 0.5, y0 + 5.0 + shaft_h, pos.z)
		var ang := rng.randf_range(0.1, 0.16) * (1.0 if rng.randf() < 0.5 else -1.0)
		var basis := Basis.from_euler(Vector3(0, 0, ang))
		var center := pivot + basis * Vector3(-size.x * 0.5, lh * 0.5, 0)
		b.box(Vector3(size.x, lh, size.y), center, "windows", Vector3(0, 0, ang), true, tint.darkened(0.1))
		top = center.y + lh * 0.5
		for k in 8:
			b.box(Vector3(rng.randf_range(1, 3), rng.randf_range(0.5, 2), rng.randf_range(1, 3)), pivot + Vector3(rng.randf_range(-size.x, 0), rng.randf_range(-1, 1), rng.randf_range(-size.y * 0.5, size.y * 0.5)), "concrete", Vector3(rng.randf(), rng.randf(), rng.randf()), false, conc)
	elif jag:
		var cols := 4
		for i in cols:
			for j in cols:
				var jh := rng.randf_range(0.0, 9.0)
				if rng.randf() < 0.3:
					continue
				var cx := pos.x - size.x * 0.5 + (i + 0.5) * size.x / cols
				var cz := pos.z - size.y * 0.5 + (j + 0.5) * size.y / cols
				b.box(Vector3(size.x / cols, jh, size.y / cols), Vector3(cx, y0 + 5.0 + shaft_h + jh * 0.5, cz), "windows", Vector3.ZERO, true, tint)
		for k in 10:
			b.box(Vector3(rng.randf_range(0.2, 0.4), rng.randf_range(1, 4), rng.randf_range(0.2, 0.4)), Vector3(pos.x + rng.randf_range(-size.x * 0.5, size.x * 0.5), y0 + 5.0 + shaft_h + rng.randf_range(0, 4), pos.z + rng.randf_range(-size.y * 0.5, size.y * 0.5)), "rusty", Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)), false)
	else:
		var ry := y0 + 5.0 + shaft_h
		b.box(Vector3(size.x + 0.4, 1.0, size.y + 0.4), Vector3(pos.x, ry + 0.5, pos.z), "concrete", Vector3.ZERO, true, conc)
		b.box(Vector3(4, 3, 4), Vector3(pos.x + size.x * 0.25, ry + 2.5, pos.z - size.y * 0.2), "concrete", Vector3.ZERO, true, conc)
		b.cyl(0.15, 12.0, Vector3(pos.x - size.x * 0.3, ry + 7.0, pos.z + size.y * 0.2), "metal", false, Color(0.5, 0.5, 0.5), 6)
		var beacon := b.light(Vector3(pos.x - size.x * 0.3, ry + 13.2, pos.z + size.y * 0.2), Color(1.0, 0.1, 0.05), 6.0, 2.0)
		beacon.distance_fade_enabled = false
		w._flicker.append({"l": beacon, "base": 2.0})
		b.box(Vector3(0.3, 0.3, 0.3), Vector3(pos.x - size.x * 0.3, ry + 13.1, pos.z + size.y * 0.2), "neon_red", Vector3.ZERO, false)
	# rubble skirt
	for k in rng.randi_range(4, 9):
		var a := rng.randf() * TAU
		var r := maxf(size.x, size.y) * 0.5 + rng.randf_range(1.5, 5.0)
		b.box(Vector3(rng.randf_range(0.6, 2.5), rng.randf_range(0.3, 1.2), rng.randf_range(0.6, 2.5)), Vector3(pos.x + cos(a) * r, y0 + 0.3, pos.z + sin(a) * r), "concrete", Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * PI, rng.randf_range(-0.3, 0.3)), true, conc)
	if rng.randf() < 0.5:
		w.container("dumpster", Vector3(pos.x + size.x * 0.5 + 2.5, y0, pos.z + rng.randf_range(-size.y * 0.3, size.y * 0.3)), PI * 0.5)

static func _ring_towers(w: World, b: WorldBuilder) -> void:
	_tower(w, b, Vector3(-50, 0, -138), Vector2(24, 22), 85.0, "lean", "HOTEL")
	_tower(w, b, Vector3(0, 0, -142), Vector2(34, 24), 98.0, "", "")
	_tower(w, b, Vector3(50, 0, -138), Vector2(22, 22), 72.0, "jagged", "BAR")
	_tower(w, b, Vector3(68, 0, -95), Vector2(22, 26), 62.0, "", "PAWN")
	_tower(w, b, Vector3(68, 0, -52), Vector2(22, 22), 46.0, "jagged", "")
	_tower(w, b, Vector3(-68, 0, -95), Vector2(22, 26), 76.0, "", "24/7")
	_tower(w, b, Vector3(-42, 0, -10), Vector2(26, 20), 54.0, "lean", "DINER")
	# billboard on the tallest tower, facing the plaza
	var bb := Vector3(0, 40, -129.5)
	b.box(Vector3(26, 10, 0.4), bb, "metal", Vector3.ZERO, false, Color(0.12, 0.1, 0.14))
	b.neon_text("GALLERIA UNDER", bb + Vector3(0, 2.0, 0.3), 0.0, "cyan", 420, false)
	b.neon_text("60 STORES  ·  NEON FOOD COURT  ·  OPEN 24/7", bb + Vector3(0, -2.4, 0.3), 0.0, "pink", 150, false)
	b.light(bb + Vector3(0, 0, 6), Color(0.5, 0.8, 1.0), 30.0, 2.0)

# ---------------- Meridian Tower (explorable ruin) ----------------
static func _office_ruin(w: World, b: WorldBuilder, c: Vector3) -> void:
	var half := 12.0
	var fh := 4.0
	var floors := 6
	var conc := Color(0.68, 0.66, 0.62)
	# columns
	for ix in 5:
		for iz in 5:
			var px := c.x - half + ix * 6.0
			var pz := c.z - half + iz * 6.0
			var colh := fh * floors if not (ix < 2 and iz > 2) else fh * (floors - 1)
			b.box(Vector3(0.7, colh, 0.7), Vector3(px, colh * 0.5, pz), "concrete", Vector3.ZERO, true, conc)
	# slabs with stair holes; stairs in the NE corner (two lanes)
	var lane_x := [c.x + 6.0 + 1.5, c.x + 9.0 + 1.5]
	for k in range(1, floors + 1):
		var y := k * fh
		var hole_lane := (k - 1) % 2
		var hx: float = lane_x[hole_lane]
		var partial := k == floors
		# slab = full rect minus the hole (x hx±1.5, z c.z-10..c.z); the roof is half collapsed
		var x0 := c.x - half if not partial else c.x - 2.0
		var x1 := c.x + half
		var z0 := c.z - half
		var z1 := c.z + half
		var top_t := conc.darkened(0.05)
		b.box(Vector3((hx - 1.5) - x0, 0.4, 24), Vector3((x0 + hx - 1.5) * 0.5, y - 0.2, c.z), "concrete", Vector3.ZERO, true, top_t)
		b.box(Vector3(x1 - (hx + 1.5), 0.4, 24), Vector3((hx + 1.5 + x1) * 0.5, y - 0.2, c.z), "concrete", Vector3.ZERO, true, top_t)
		b.box(Vector3(3.0, 0.4, 2.0), Vector3(hx, y - 0.2, z0 + 1.0), "concrete", Vector3.ZERO, true, top_t)
		b.box(Vector3(3.0, 0.4, z1 - c.z), Vector3(hx, y - 0.2, (c.z + z1) * 0.5), "concrete", Vector3.ZERO, true, top_t)
		if partial:
			continue
		# walls: broken glass panels on some bays, parapets elsewhere
		for side in 4:
			for bay in 4:
				var t := (bay + 0.5) / 4.0
				var p: Vector3
				var rot := 0.0
				match side:
					0: p = Vector3(c.x - half + t * 24.0, y, c.z - half)
					1: p = Vector3(c.x - half + t * 24.0, y, c.z + half)
					2: p = Vector3(c.x - half, y, c.z - half + t * 24.0); rot = PI * 0.5
					_: p = Vector3(c.x + half, y, c.z - half + t * 24.0); rot = PI * 0.5
				var r := rng.randf()
				if side == 3 and k >= 3:
					r = 0.9
				if r < 0.45:
					b.box(Vector3(6.0, fh - 0.4, 0.15), p + Vector3(0, fh * 0.5, 0), "windows", Vector3(0, rot, 0), true, Color(0.55, 0.62, 0.7))
				elif r < 0.8:
					b.box(Vector3(6.0, 1.0, 0.25), p + Vector3(0, 0.5, 0), "concrete", Vector3(0, rot, 0), true, conc)
	# ground floor walls with a lobby entrance facing the plaza (east)
	b.wall(Vector3(c.x - half, 0, c.z - half), Vector3(c.x + half, 0, c.z - half), fh, 0.3, "windows", Color(0.5, 0.55, 0.6))
	b.wall(Vector3(c.x - half, 0, c.z + half), Vector3(c.x + half, 0, c.z + half), fh, 0.3, "windows", Color(0.5, 0.55, 0.6), [[6.0, 3.0, 3.0]])
	b.wall(Vector3(c.x - half, 0, c.z - half), Vector3(c.x - half, 0, c.z + half), fh, 0.3, "windows", Color(0.5, 0.55, 0.6))
	b.wall(Vector3(c.x + half, 0, c.z - half), Vector3(c.x + half, 0, c.z + half), fh, 0.3, "windows", Color(0.5, 0.55, 0.6), [[16.0, 5.0, 3.2]])
	b.box(Vector3(24, 0.15, 24), Vector3(c.x, 0.07, c.z), "tile", Vector3.ZERO, true, Color(0.75, 0.73, 0.7))
	# switchback stairs
	for k in floors - 1:
		var lx: float = lane_x[k % 2]
		var y0 := k * fh
		if k % 2 == 0:
			b.ramp(Vector3(lx, y0, c.z), Vector3(lx, y0 + fh, c.z - 10.0), 2.9, "concrete", true, conc)
		else:
			b.ramp(Vector3(lx, y0, c.z - 10.0), Vector3(lx, y0 + fh, c.z), 2.9, "concrete", true, conc)
	b.box(Vector3(0.2, fh * (floors - 1), 10.0), Vector3(c.x + 9.0, fh * (floors - 1) * 0.5, c.z - 5.0), "concrete", Vector3.ZERO, true, conc)
	# rubble from the collapse
	for k in 12:
		b.box(Vector3(rng.randf_range(1, 3), rng.randf_range(0.4, 1.4), rng.randf_range(1, 3)), Vector3(c.x + rng.randf_range(0, 10), fh * (floors - 1) + 0.4, c.z + rng.randf_range(-10, 10)), "concrete", Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * PI, rng.randf_range(-0.4, 0.4)), true, conc)
	# loot by floor
	w.container("register", Vector3(c.x + 4, 0, c.z + 6), PI * 0.5, "", 5)
	w.container("locker", Vector3(c.x - 10.5, fh, c.z - 8), PI * 0.5, "", 5)
	w.container("crate", Vector3(c.x - 4, fh * 2, c.z + 6), 0.4, "", 5)
	w.container("locker", Vector3(c.x - 10.5, fh * 3, c.z + 4), PI * 0.5, "", 6)
	w.container("crate", Vector3(c.x + 2, fh * 4, c.z - 6), 1.2, "", 6)
	w.container("weapons", Vector3(c.x + 1.5, fh * floors, c.z + 8), PI * 0.5, "", 7)
	w.container("ammo_box", Vector3(c.x + 2.5, fh * floors, c.z + 5), 0.0, "", 7)
	for k in 6:
		b.box(Vector3(0.75, 0.38, 0.45), Vector3(c.x - 0.6, fh * floors + 0.19 + (k / 3) * 0.38, c.z + 3 + (k % 3) * 0.75), "sandbag", Vector3(0, PI * 0.5, 0), true, Color(0.82, 0.78, 0.62))
	for k in range(1, floors):
		w.spawn_monster("walker" if k % 2 == 0 else "runner", Vector3(c.x - 6 + rng.randf_range(-3, 3), k * fh + 0.3, c.z + rng.randf_range(-6, 6)), 5, {"leash": 8.0})
	w.spawn_monster("brute", Vector3(c.x - 5, fh * 4 + 0.3, c.z), 6, {"leash": 6.0})

# ---------------- Plaza Parking (drivable garage) ----------------
static func _garage(w: World, b: WorldBuilder, o: Vector3) -> void:
	var lh := 3.6
	var levels := 3
	var conc := Color(0.66, 0.65, 0.63)
	var lanes := [o.x + 30.0, o.x + 34.0]
	# pillars
	for ix in 6:
		for iz in 6:
			var px := o.x + 1.0 + ix * 6.0
			if px > o.x + 27.5:
				continue
			b.box(Vector3(0.6, lh * levels, 0.6), Vector3(px, lh * levels * 0.5, o.z + 2.0 + iz * 7.2), "concrete", Vector3.ZERO, true, conc)
	for k in range(1, levels + 1):
		var y := k * lh
		var hole: float = lanes[(k - 1) % 2]
		b.box(Vector3(28, 0.35, 40), Vector3(o.x + 14, y - 0.17, o.z + 20), "concrete", Vector3.ZERO, true, conc)
		var other: float = lanes[k % 2]
		b.box(Vector3(4, 0.35, 40), Vector3(other, y - 0.17, o.z + 20), "concrete", Vector3.ZERO, true, conc)
		b.box(Vector3(4, 0.35, 8), Vector3(hole, y - 0.17, o.z + 4), "concrete", Vector3.ZERO, true, conc)
		b.box(Vector3(4, 0.35, 8), Vector3(hole, y - 0.17, o.z + 36), "concrete", Vector3.ZERO, true, conc)
		# parapets with gaps
		for side in [o.z + 0.15, o.z + 39.85]:
			b.box(Vector3(36, 1.0, 0.3), Vector3(o.x + 18, y + 0.5, side), "concrete", Vector3.ZERO, true, conc)
		b.box(Vector3(0.3, 1.0, 40), Vector3(o.x + 35.85, y + 0.5, o.z + 20), "concrete", Vector3.ZERO, true, conc)
		b.box(Vector3(0.3, 1.0, 16), Vector3(o.x + 0.15, y + 0.5, o.z + 8), "concrete", Vector3.ZERO, true, conc)
		b.box(Vector3(0.3, 1.0, 16), Vector3(o.x + 0.15, y + 0.5, o.z + 32), "concrete", Vector3.ZERO, true, conc)
	b.box(Vector3(36, 0.15, 40), Vector3(o.x + 18, 0.07, o.z + 20), "asphalt", Vector3.ZERO, true, Color(0.75, 0.75, 0.75))
	for k in levels:
		var lx: float = lanes[k % 2]
		var y0 := k * lh
		if k % 2 == 0:
			b.ramp(Vector3(lx, y0, o.z + 32.0), Vector3(lx, y0 + lh, o.z + 8.0), 3.9, "asphalt", false, Color(0.7, 0.7, 0.7))
		else:
			b.ramp(Vector3(lx, y0, o.z + 8.0), Vector3(lx, y0 + lh, o.z + 32.0), 3.9, "asphalt", false, Color(0.7, 0.7, 0.7))
	b.neon_text("PLAZA PARKING", Vector3(o.x - 0.2, 3.0, o.z + 20), -PI * 0.5, "yellow", 90)
	for k in levels + 1:
		for n in 3:
			var cp := Vector3(o.x + 5.0 + n * 8.0, k * lh, o.z + (5.0 if (k + n) % 2 == 0 else 35.0))
			w.car_wreck(cp, PI * 0.5 + rng.randf_range(-0.2, 0.2), rng, 5)
	w.container("toolbox", Vector3(o.x + 2, lh, o.z + 20), 0.0, "", 5)
	w.container("crate", Vector3(o.x + 20, lh * 2, o.z + 20), 0.0, "", 5)
	w.container("military", Vector3(o.x + 14, lh * 3, o.z + 20), 0.0, "", 6)
	for k in 5:
		w.spawn_monster(["walker", "walker", "runner", "walker", "screamer"][k], Vector3(o.x + 8 + k * 4, (k % 3) * lh + 0.3, o.z + 20), 5, {"leash": 15.0})

# ---------------- outer city blocks ----------------
static func _blocks(w: World, b: WorldBuilder) -> void:
	for bx in [-125.0, -75.0, -25.0, 25.0, 75.0, 125.0]:
		for bz in [35.0, -15.0, -65.0, -115.0, -165.0, -205.0]:
			if absf(bx) < 95.0 and bz > -160.0 and bz < 30.0:
				continue
			if absf(bx) < 30.0 and bz > -30.0:
				continue
			var p := Vector3(bx + rng.randf_range(-3, 3), 0, bz + rng.randf_range(-3, 3))
			var r := rng.randf()
			if r < 0.55:
				_tower(w, b, p, Vector2(rng.randf_range(16, 26), rng.randf_range(16, 26)), rng.randf_range(24.0, 70.0), ["", "", "jagged", "lean"][rng.randi() % 4], ["", "", "MOTEL", "BAR", "LIQUOR", "PAWN"][rng.randi() % 6])
			elif r < 0.85:
				for k in 2:
					var lp := p + Vector3(-9 + k * 18, 0, rng.randf_range(-4, 4))
					var lh := rng.randf_range(7.0, 15.0)
					var tint := Color.from_hsv(rng.randf_range(0.02, 0.12), 0.25, rng.randf_range(0.55, 0.8))
					b.box(Vector3(14, lh, 18), lp + Vector3(0, lh * 0.5 + w.height(lp.x, lp.z), 0), "brick" if rng.randf() < 0.5 else "plaster", Vector3.ZERO, true, tint)
					b.box(Vector3(14.2, 2.6, 18.2), lp + Vector3(0, 1.7 + w.height(lp.x, lp.z), 0), "windows", Vector3.ZERO, false, Color(0.35, 0.35, 0.38))
					if rng.randf() < 0.6:
						w.container(["crate", "locker", "fridge", "dumpster"][rng.randi() % 4], lp + Vector3(8.2, w.height(lp.x, lp.z), rng.randf_range(-6, 6)), PI * 0.5)
			else:
				for k in 6:
					var rp := p + Vector3(rng.randf_range(-15, 15), 0, rng.randf_range(-15, 15))
					b.box(Vector3(rng.randf_range(1, 4), rng.randf_range(0.5, 2.0), rng.randf_range(1, 4)), rp + Vector3(0, 0.4 + w.height(rp.x, rp.z), 0), "concrete", Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * PI, 0), true, Color(0.62, 0.6, 0.57))
				w.car_wreck(p + Vector3(rng.randf_range(-8, 8), w.height(p.x, p.z), rng.randf_range(-8, 8)), rng.randf() * TAU, rng, 4, true)

# ---------------- streets ----------------
static func _streets(w: World, b: WorldBuilder) -> void:
	# asphalt over the downtown ground (around, never over, the plaza holes)
	var at := Color(0.62, 0.62, 0.62)
	b.box(Vector3(300, 0.08, 115), Vector3(0, 0.02, -167.5), "asphalt", Vector3.ZERO, false, at)
	b.box(Vector3(300, 0.08, 85), Vector3(0, 0.02, 12.5), "asphalt", Vector3.ZERO, false, at)
	b.box(Vector3(110, 0.08, 80), Vector3(-95, 0.02, -70), "asphalt", Vector3.ZERO, false, at)
	b.box(Vector3(110, 0.08, 80), Vector3(95, 0.02, -70), "asphalt", Vector3.ZERO, false, at)
	# wrecks & barricades around the plaza ring and the avenue
	for i in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(46.0, 58.0)
		var p := Vector3(cos(a) * r, 0, -70 + sin(a) * r * 1.1)
		if p.x > 38.0 and p.z > -26.0:
			continue
		w.car_wreck(p, a + PI * 0.5 + rng.randf_range(-0.4, 0.4), rng, 5, rng.randf() < 0.25)
	for i in 7:
		var p2 := Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-24, 40))
		w.car_wreck(p2, rng.randf_range(-0.5, 0.5) + (PI if rng.randf() < 0.5 else 0.0), rng, 4)
	# buses as barricades
	for bp in [[Vector3(-46, 0, -24), 0.3], [Vector3(47, 0, -120), 1.2], [Vector3(-60, 0, -122), 0.1]]:
		var pos: Vector3 = bp[0]
		var yaw: float = bp[1]
		b.box(Vector3(2.6, 2.4, 11.0), pos + Vector3(0, 1.6, 0), "rusty", Vector3(0, yaw, 0.04), true, Color(0.75, 0.6, 0.25))
		b.box(Vector3(2.65, 0.9, 10.0), pos + Vector3(0, 2.2, 0), "windows", Vector3(0, yaw, 0.04), false, Color(0.3, 0.35, 0.4))
		w.container("crate", pos + Vector3(2.0, 0, 0), yaw)
	# jersey barriers and burning barrels
	for i in 14:
		var p3 := Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-200, 40))
		if absf(p3.x) < 42.0 and p3.z < -28.0 and p3.z > -112.0:
			continue
		b.box(Vector3(3.0, 0.9, 0.6), p3 + Vector3(0, 0.45, 0), "concrete", Vector3(0, rng.randf() * PI, 0), true, Color(0.75, 0.74, 0.7))
	for p4 in [Vector3(-14, 0, 10), Vector3(14, 0, -18), Vector3(-48, 0, -60), Vector3(48, 0, -108), Vector3(60, 0, -28)]:
		w.burning_barrel(p4)
	# street lights (dead) along the avenue
	for i in 6:
		for side in [-1.0, 1.0]:
			var sp := Vector3(side * 9.0, 0, 40 - i * 13.0)
			b.box(Vector3(0.18, 7.0, 0.18), sp + Vector3(0, 3.5, 0), "metal", Vector3.ZERO, true, Color(0.35, 0.35, 0.38))
			b.box(Vector3(2.0, 0.15, 0.25), sp + Vector3(-side * 0.9, 7.0, 0), "metal", Vector3.ZERO, false, Color(0.35, 0.35, 0.38))

# ---------------- residents ----------------
static func _residents(w: World) -> void:
	# plaza & streets
	for i in 14:
		var p := Vector3(rng.randf_range(-36, 36), 0.3, rng.randf_range(-106, -36))
		if absf(p.x) < 11.0 and p.z < -68.0 and p.z > -92.0:
			continue
		var k := "walker"
		if i % 5 == 0: k = "runner"
		if i == 7: k = "screamer"
		if i == 11: k = "bloater"
		w.spawn_monster(k, p, 5)
	for i in 14:
		var p2 := Vector3(rng.randf_range(-130, 130), 0.3, rng.randf_range(-210, 40))
		if absf(p2.x) < 42.0 and p2.z < -28.0 and p2.z > -112.0:
			continue
		p2.y = w.height(p2.x, p2.z) + 0.3
		w.spawn_monster("runner" if i % 4 == 0 else "walker", p2, 4)
	# the Galleria — packed
	var mall_spots := [
		Vector3(0, 0, -62), Vector3(-8, 0, -100), Vector3(8, 0, -110), Vector3(-30, 0, -80), Vector3(30, 0, -80),
		Vector3(-50, 0, -80), Vector3(50, 0, -80), Vector3(-10, 0, -115), Vector3(10, 0, -64), Vector3(0, 0, -105),
		Vector3(-52, 0, -55), Vector3(-37, 0, -60), Vector3(-22, 0, -52), Vector3(22, 0, -50), Vector3(40, 0, -55),
		Vector3(52, 0, -66), Vector3(-45, 0, -105), Vector3(-22, 0, -105), Vector3(22, 0, -100), Vector3(45, 0, -100),
		Vector3(38, 0, -112), Vector3(-55, 0, -100), Vector3(-35, 0, -95), Vector3(55, 0, -110), Vector3(-12, 0, -58),
	]
	for i in mall_spots.size():
		var mp: Vector3 = mall_spots[i] + Vector3(rng.randf_range(-2, 2), Y + 0.3, rng.randf_range(-2, 2))
		var k2 := "walker"
		if i % 3 == 1: k2 = "runner"
		if i == 4 or i == 19: k2 = "brute"
		if i == 14: k2 = "screamer"
		if i in [16, 21, 22]: k2 = "bloater"
		w.spawn_monster(k2, mp, 7, {"leash": 20.0})
		if i % 2 == 0:
			w.spawn_monster("walker", mp + Vector3(1.5, 0, 1.0), 7, {"leash": 20.0})
	w.spawn_monster("goliath", Vector3(0, Y + 0.3, -88), 8, {"leash": 14.0, "name": "The Goliath"})
	# sub-level
	for sp in [Vector3(54, SUB + 0.3, -75), Vector3(54, SUB + 0.3, -110), Vector3(0, SUB + 0.3, -115), Vector3(-30, SUB + 0.3, -115), Vector3(-55, SUB + 0.3, -90), Vector3(-50, SUB + 0.3, -58)]:
		w.spawn_monster("walker", sp, 9, {"leash": 12.0})
	w.spawn_monster("gaunt", Vector3(36, SUB + 0.3, -95), 9, {"dormant": true, "name": "The Gaunt"})
