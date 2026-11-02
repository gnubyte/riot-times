extends Node
# Item database — all game items defined procedurally.
# types: gun, melee, ammo, food, heal, radaway, armor, hat, misc

var ITEMS := {
	# ---- Guns ----
	"pistol": {type="gun", name="10mm Pistol", weight=4.0, value=120, stack=1,
		dmg=9.0, rate=4.0, auto=false, spread=0.012, range=120.0, ammo_id="ammo_10mm", mag=12,
		desc="A trusty semi-auto. The wasteland's workhorse."},
	"smg": {type="gun", name="Scrap SMG", weight=6.5, value=210, stack=1,
		dmg=7.0, rate=11.0, auto=true, spread=0.035, range=80.0, ammo_id="ammo_10mm", mag=24,
		desc="Welded together from rebar and prayer. Full auto."},
	"rifle": {type="gun", name="Hunting Rifle", weight=9.0, value=380, stack=1,
		dmg=34.0, rate=1.1, auto=false, spread=0.004, range=300.0, ammo_id="ammo_rifle", mag=5,
		desc="Bolt-action. Punches right through a bloatfly."},
	"laser": {type="gun", name="Laser Rifle", weight=7.0, value=650, stack=1,
		dmg=22.0, rate=3.5, auto=false, spread=0.008, range=200.0, ammo_id="energy_cell", mag=20,
		desc="Pre-war tech. Searing beam, smells like ozone."},

	# ---- Melee ----
	"fists": {type="melee", name="Fists", weight=0.0, value=0, stack=1,
		dmg=4.0, rate=1.6, reach=2.0, desc="Bare knuckles. Free forever."},
	"pipe": {type="melee", name="Rusty Pipe", weight=3.0, value=30, stack=1,
		dmg=10.0, rate=1.4, reach=2.3, desc="A length of pipe. Classic."},
	"bat": {type="melee", name="Nail Bat", weight=4.0, value=55, stack=1,
		dmg=14.0, rate=1.2, reach=2.5, desc="Wood, nails, bad intentions."},
	"machete": {type="melee", name="Machete", weight=3.5, value=90, stack=1,
		dmg=17.0, rate=2.0, reach=2.4, desc="Fast slicing blade."},
	"sledge": {type="melee", name="Super Sledge", weight=11.0, value=260, stack=1,
		dmg=38.0, rate=0.7, reach=2.7, desc="Slow, heavy, absolutely final."},

	# ---- Ammo ----
	"ammo_10mm": {type="ammo", name="10mm Rounds", weight=0.01, value=2, stack=200, ammo_count=1, desc="Pistol & SMG ammo."},
	"ammo_rifle": {type="ammo", name=".308 Rounds", weight=0.02, value=4, stack=100, ammo_count=1, desc="Rifle ammo."},
	"energy_cell": {type="ammo", name="Energy Cells", weight=0.03, value=8, stack=100, ammo_count=1, desc="Laser rifle power."},

	# ---- Food & healing ----
	"beans": {type="food", name="Canned Beans", weight=0.4, value=8, stack=10, hunger=30, hp=2, rad=0, desc="Mystery meat, mostly bean."},
	"jerky": {type="food", name="Iguana-on-a-Stick Jerky", weight=0.2, value=10, stack=10, hunger=22, hp=1, rad=1, desc="Chewy. Slightly crunchy."},
	"mut_meat": {type="food", name="Raw Mutant Meat", weight=0.5, value=4, stack=10, hunger=35, hp=-2, rad=8, desc="Radioactive and gristly. Ghouls love it."},
	"stimpak": {type="heal", name="Stimpak", weight=0.2, value=45, stack=8, hp=45, hunger=0, rad=0, desc="Instant trauma kit. Organics only."},
	"fusion_core": {type="heal", name="Fusion Core", weight=0.2, value=60, stack=8, hp=45, hunger=0, rad=0, robots_only=true, desc="Recharges synthoids. Machines only."},
	"radaway": {type="radaway", name="RadAway", weight=0.2, value=50, stack=6, rad_clear=40, desc="Flushes radstuff from your veins."},
	"water": {type="food", name="Dirty Water", weight=0.5, value=3, stack=10, hunger=12, hp=-1, rad=4, desc="Filters are for quitters."},
	"cola": {type="food", name="Nuka Buzz Cola", weight=0.4, value=15, stack=10, hunger=10, hp=4, rad=0, desc="Still fizzy after the bomb."},

	# ---- Hats ----
	"cap_police": {type="hat", name="Police Cap", weight=0.3, value=25, stack=1, dr=0.0, rad_resist=0, stat={"PE":1}, color=Color(0.15,0.2,0.35), desc="Authority, bottled."},
	"hat_cowboy": {type="hat", name="Cowboy Hat", weight=0.5, value=90, stack=1, dr=0.02, rad_resist=0, stat={"AG":1}, color=Color(0.45,0.28,0.15), desc="Makes the whole wasteland your range."},
	"hat_miner": {type="hat", name="Mining Helmet", weight=1.2, value=60, stack=1, dr=0.08, rad_resist=5, color=Color(0.85,0.7,0.15), desc="Headlamp included (it works, once)."},
	"hat_tophat": {type="hat", name="Top Hat", weight=0.4, value=140, stack=1, dr=0.0, rad_resist=0, stat={"CHA":2}, color=Color(0.1,0.1,0.12), desc="For the distinguished raider."},
	"mask_ghoul": {type="hat", name="Ghoul Mask", weight=0.6, value=70, stack=1, dr=0.03, rad_resist=25, color=Color(0.35,0.5,0.25), desc="Breather + the right look."},

	# ---- Body armor ----
	"armor_leather": {type="armor", name="Leather Armor", weight=6.0, value=110, stack=1, dr=0.15, rad_resist=0, color=Color(0.42,0.27,0.14), desc="Tanned iguana hide."},
	"armor_lab": {type="armor", name="Lab Coat", weight=2.0, value=40, stack=1, dr=0.03, rad_resist=30, stat={"INT":1}, color=Color(0.88,0.9,0.86), desc="Science never stopped. Neither did the cancer."},
	"armor_metal": {type="armor", name="Scrapskin Vest", weight=9.0, value=180, stack=1, dr=0.28, rad_resist=8, stat={"AG":-1}, color=Color(0.5,0.5,0.55), desc="Car panels and hubcaps."},
	"armor_combat": {type="armor", name="Combat Armor", weight=13.0, value=520, stack=1, dr=0.42, rad_resist=15, color=Color(0.3,0.33,0.28), desc="Actual military issue. Heavier than hope."},

	# ---- Misc ----
	"shards": {type="misc", name="Glowshards", weight=0.0, value=1, stack=9999, desc="Slivers of irradiated glass the wasteland trusts because they glow. Count them twice; the glow lies."},
}

var icon_cache := {}

func get_def(id: String) -> Dictionary:
	return ITEMS.get(id, {})

func item_name(id: String) -> String:
	return get_def(id).get("name", id)

func item_type(id: String) -> String:
	return get_def(id).get("type", "misc")

# ---------- Procedural icons ----------
func icon(id: String) -> Texture2D:
	if icon_cache.has(id):
		return icon_cache[id]
	var d := get_def(id)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var t: String = d.get("type", "misc")
	match t:
		"gun": _draw_gun(img)
		"melee": _draw_melee(img)
		"ammo": _draw_ammo(img)
		"food": _draw_food(img)
		"heal": _draw_heal(img)
		"radaway": _draw_radaway(img)
		"hat": _draw_hat(img, d.get("color", Color.GRAY))
		"armor": _draw_armor(img, d.get("color", Color.GRAY))
		_: _draw_shards(img)
	var tex := ImageTexture.create_from_image(img)
	icon_cache[id] = tex
	return tex

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(img, x, y, c)

func _draw_gun(img: Image) -> void:
	var steel := Color(0.35, 0.36, 0.4)
	var grip := Color(0.2, 0.13, 0.09)
	_rect(img, 6, 12, 26, 16, steel)      # barrel/slide
	_rect(img, 8, 16, 14, 26, grip)       # grip
	_rect(img, 16, 16, 22, 19, steel)     # trigger guard block
	_rect(img, 22, 8, 26, 12, steel)      # sight rise

func _draw_melee(img: Image) -> void:
	_rect(img, 8, 24, 10, 27, Color(0.3, 0.2, 0.1)) # handle
	for i in 18:
		_px(img, 10 + i, 22 - int(i * 0.8), Color(0.62, 0.63, 0.66))
		_px(img, 10 + i, 23 - int(i * 0.8), Color(0.62, 0.63, 0.66))
		_px(img, 11 + i, 22 - int(i * 0.8), Color(0.45, 0.25, 0.15)) # rust

func _draw_ammo(img: Image) -> void:
	var brass := Color(0.78, 0.62, 0.22)
	for k in 3:
		var bx := 7 + k * 8
		_rect(img, bx, 14, bx + 4, 26, brass)
		_px(img, bx + 1, 12, brass); _px(img, bx + 2, 12, brass)
		_px(img, bx + 1, 13, brass); _px(img, bx + 2, 13, brass)
		_px(img, bx + 2, 11, Color(0.45, 0.4, 0.35))

func _draw_food(img: Image) -> void:
	_rect(img, 10, 10, 22, 26, Color(0.55, 0.6, 0.65)) # can
	_rect(img, 10, 12, 22, 14, Color(0.75, 0.3, 0.2))  # label
	_rect(img, 10, 22, 22, 24, Color(0.75, 0.3, 0.2))

func _draw_heal(img: Image) -> void:
	_rect(img, 8, 22, 20, 26, Color(0.85, 0.85, 0.9))   # barrel
	_rect(img, 10, 24, 18, 24, Color(0.9, 0.2, 0.25))
	_rect(img, 6, 18, 8, 28, Color(0.7, 0.7, 0.75))     # plunger
	_rect(img, 20, 12, 26, 14, Color(0.75, 0.75, 0.8))  # needle hub
	for i in 6: _px(img, 24 + i, 13 - i, Color(0.8, 0.8, 0.85))

func _draw_radaway(img: Image) -> void:
	_rect(img, 9, 8, 22, 26, Color(0.2, 0.6, 0.75))
	_rect(img, 11, 12, 20, 22, Color(0.1, 0.15, 0.15))
	# trefoil-ish dots
	_px(img, 15, 14, Color(1, 0.9, 0.2)); _px(img, 12, 19, Color(1, 0.9, 0.2)); _px(img, 18, 19, Color(1, 0.9, 0.2))
	_rect(img, 14, 7, 17, 8, Color(0.15, 0.4, 0.5))

func _draw_hat(img: Image, c: Color) -> void:
	_rect(img, 6, 20, 26, 24, c)          # brim
	_rect(img, 11, 10, 21, 20, c.lightened(0.1)) # crown

func _draw_armor(img: Image, c: Color) -> void:
	_rect(img, 8, 10, 24, 26, c)
	_rect(img, 6, 10, 10, 20, c.darkened(0.2)) # shoulder
	_rect(img, 22, 10, 26, 20, c.darkened(0.2))
	_rect(img, 12, 14, 20, 22, c.lightened(0.12)) # chest plate

func _draw_shards(img: Image) -> void:
	# three glowing green glass slivers — the Glowshard currency
	var shards := [
		[[13, 6], [8, 22], [13, 26], [16, 9]],
		[[20, 10], [17, 24], [22, 27], [25, 13]],
		[[7, 14], [5, 25], [9, 27], [11, 16]],
	]
	var fillc := Color(0.55, 0.95, 0.45)
	var edge := Color(0.85, 1.0, 0.7)
	for s in shards:
		# crude polygon fill via bbox + edge test
		var minx := 32; var maxx := 0; var miny := 32; var maxy := 0
		for p in s:
			minx = mini(minx, p[0]); maxx = maxi(maxx, p[0])
			miny = mini(miny, p[1]); maxy = maxi(maxy, p[1])
		for y in range(miny, maxy + 1):
			for x in range(minx, maxx + 1):
				if _inside_poly(x, y, s):
					_px(img, x, y, fillc)
		for i in s.size():
			var a: Array = s[i]; var b: Array = s[(i + 1) % s.size()]
			_line_px(img, a[0], a[1], b[0], b[1], edge)

func _inside_poly(x: int, y: int, pts: Array) -> bool:
	var inside := false
	var n := pts.size()
	var j := n - 1
	for i in n:
		var pi: Array = pts[i]; var pj: Array = pts[j]
		var yi: float = pi[1]; var yj: float = pj[1]
		if (yi > y) != (yj > y):
			var xi: float = pi[0]; var xj: float = pj[0]
			if float(x) < (xj - xi) * (float(y) - yi) / (yj - yi) + xi:
				inside = not inside
		j = i
	return inside

func _line_px(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0); var dy := -absi(y1 - y0)
	var sx := -1 if x0 > x1 else 1; var sy := -1 if y0 > y1 else 1
	var err := dx + dy
	while true:
		if x0 >= 0 and y0 >= 0 and x0 < img.get_width() and y0 < img.get_height():
			img.set_pixel(x0, y0, c)
		if x0 == x1 and y0 == y1: break
		var e2 := 2 * err
		if e2 >= dy: err += dy; x0 += sx
		if e2 <= dx: err += dx; y0 += sy

# ---------- First-person view-model meshes ----------
# Each gun builds two animated groups: GunNode (the weapon + trigger hand) and
# MagNode (magazine + support hand) so the Player can drive reload animations.
func build_viewmodel(id: String) -> Node3D:
	var root := Node3D.new()
	var t := item_type(id)
	match t:
		"gun":
			var gun := Node3D.new(); gun.name = "GunNode"
			var mag := Node3D.new(); mag.name = "MagNode"
			root.add_child(gun)
			root.add_child(mag)
			match id:
				"pistol": _vm_pistol(root, gun, mag)
				"smg": _vm_smg(root, gun, mag)
				"rifle": _vm_rifle(root, gun, mag)
				"laser": _vm_laser(root, gun, mag)
		"fists", "melee":
			_vm_melee(root, id)
		_:
			var b := _box(Vector3(0.06, 0.06, 0.1), Color(0.4, 0.4, 0.4))
			root.add_child(b)
	return root

var _hand_col := Color(0.76, 0.6, 0.46)
func _hand(size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	# a gloved wrapped hand gripping the weapon
	var mi := _box(size, _hand_col, pos, rot, 0.0)
	var m := mi.material_override as StandardMaterial3D
	m.roughness = 0.9
	return mi

func _vm_pistol(root: Node3D, gun: Node3D, mag: Node3D) -> void:
	gun.add_child(_box(Vector3(0.06, 0.07, 0.34), Color(0.3, 0.31, 0.35), Vector3(0, 0.02, -0.18), Vector3.ZERO, 0.8))
	gun.add_child(_box(Vector3(0.055, 0.18, 0.07), Color(0.18, 0.12, 0.08), Vector3(0, -0.09, -0.05), Vector3(0.25, 0, 0), 0.1))
	gun.add_child(_box(Vector3(0.02, 0.02, 0.06), Color(0.1, 0.1, 0.12), Vector3(0, 0.06, -0.3), Vector3.ZERO, 0.9))
	# trigger hand under the grip
	gun.add_child(_hand(Vector3(0.07, 0.11, 0.09), Vector3(0.005, -0.11, -0.045), Vector3(0.25, 0, -0.1)))
	# magazine + support hand (animated during reload)
	mag.add_child(_box(Vector3(0.045, 0.12, 0.055), Color(0.25, 0.26, 0.3), Vector3(0, -0.1, -0.16), Vector3.ZERO, 0.7))
	mag.add_child(_hand(Vector3(0.09, 0.07, 0.12), Vector3(-0.02, -0.08, -0.17), Vector3(0, 0, 0.15)))

func _vm_smg(root: Node3D, gun: Node3D, mag: Node3D) -> void:
	gun.add_child(_box(Vector3(0.07, 0.09, 0.42), Color(0.42, 0.35, 0.25), Vector3(0, 0.02, -0.2), Vector3.ZERO, 0.6))
	gun.add_child(_box(Vector3(0.05, 0.2, 0.06), Color(0.2, 0.13, 0.09), Vector3(0, -0.1, -0.04), Vector3(0.2, 0, 0), 0.1))
	gun.add_child(_box(Vector3(0.03, 0.03, 0.22), Color(0.3, 0.3, 0.34), Vector3(0, 0.04, -0.42), Vector3.ZERO, 0.9))
	gun.add_child(_box(Vector3(0.04, 0.05, 0.14), Color(0.6, 0.5, 0.35), Vector3(0, 0.03, -0.52), Vector3.ZERO, 0.2))
	gun.add_child(_hand(Vector3(0.07, 0.11, 0.09), Vector3(0.005, -0.12, -0.035), Vector3(0.2, 0, -0.1)))
	# stick mag + support hand
	mag.add_child(_box(Vector3(0.04, 0.14, 0.05), Color(0.55, 0.45, 0.3), Vector3(0, -0.12, -0.18), Vector3(0, 0, 0.15), 0.5))
	mag.add_child(_hand(Vector3(0.09, 0.07, 0.12), Vector3(-0.02, -0.1, -0.19), Vector3(0, 0, 0.2)))

func _vm_rifle(root: Node3D, gun: Node3D, mag: Node3D) -> void:
	gun.add_child(_box(Vector3(0.05, 0.07, 0.5), Color(0.32, 0.2, 0.1), Vector3(0, 0.0, -0.18), Vector3.ZERO, 0.05))
	gun.add_child(_box(Vector3(0.035, 0.035, 0.6), Color(0.35, 0.36, 0.4), Vector3(0, 0.03, -0.6), Vector3.ZERO, 0.9))
	gun.add_child(_box(Vector3(0.03, 0.09, 0.05), Color(0.32, 0.2, 0.1), Vector3(0, -0.09, 0.0), Vector3(0.2, 0, 0), 0.05))
	gun.add_child(_box(Vector3(0.04, 0.06, 0.16), Color(0.15, 0.15, 0.18), Vector3(0, 0.08, -0.28), Vector3.ZERO, 0.7))
	gun.add_child(_box(Vector3(0.025, 0.025, 0.02), Color(0.3, 0.5, 0.7), Vector3(0, 0.08, -0.37), Vector3.ZERO, 0.2))
	gun.add_child(_hand(Vector3(0.07, 0.1, 0.08), Vector3(0.005, -0.1, -0.01), Vector3(0.2, 0, -0.1)))
	# bolt-action: support hand on the forestock (no dangling mag)
	mag.add_child(_hand(Vector3(0.09, 0.07, 0.11), Vector3(-0.01, -0.05, -0.3), Vector3(0, 0, 0.1)))

func _vm_laser(root: Node3D, gun: Node3D, mag: Node3D) -> void:
	gun.add_child(_box(Vector3(0.07, 0.1, 0.5), Color(0.25, 0.28, 0.3), Vector3(0, 0.02, -0.22), Vector3.ZERO, 0.7))
	gun.add_child(_box(Vector3(0.05, 0.16, 0.06), Color(0.2, 0.13, 0.09), Vector3(0, -0.08, -0.05), Vector3(0.2, 0, 0), 0.1))
	gun.add_child(_box(Vector3(0.03, 0.03, 0.3), Color(0.4, 0.42, 0.46), Vector3(0, 0.06, -0.5), Vector3.ZERO, 0.9))
	var emitter := _box(Vector3(0.05, 0.05, 0.04), Color(0.2, 0.9, 0.5), Vector3(0, 0.06, -0.66), Vector3.ZERO, 0.2)
	var em := emitter.material_override as StandardMaterial3D
	em.emission_enabled = true; em.emission = Color(0.2, 1.0, 0.5); em.emission_energy_multiplier = 3.0
	gun.add_child(emitter)
	gun.add_child(_hand(Vector3(0.07, 0.1, 0.08), Vector3(0.005, -0.1, -0.04), Vector3(0.2, 0, -0.1)))
	# energy cell pack + support hand
	mag.add_child(_box(Vector3(0.05, 0.09, 0.07), Color(0.15, 0.5, 0.35), Vector3(0, -0.09, -0.2), Vector3.ZERO, 0.4))
	var cell := _box(Vector3(0.02, 0.02, 0.02), Color(0.3, 1.0, 0.6), Vector3(0, -0.045, -0.2), Vector3.ZERO, 0.1)
	var cm := cell.material_override as StandardMaterial3D
	cm.emission_enabled = true; cm.emission = Color(0.3, 1.0, 0.6); cm.emission_energy_multiplier = 2.0
	mag.add_child(cell)
	mag.add_child(_hand(Vector3(0.09, 0.07, 0.12), Vector3(-0.02, -0.08, -0.21), Vector3(0, 0, 0.18)))

func _mat(c: Color, metal: float = 0.4) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.55
	return m

func _box(size: Vector3, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, metal := 0.4) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, metal)
	mi.position = pos
	mi.rotation = rot
	return mi

func _vm_melee(root: Node3D, id: String) -> void:
	var c := Color(0.5, 0.35, 0.2)
	var size := Vector3(0.045, 0.045, 0.7)
	match id:
		"pipe": c = Color(0.45, 0.3, 0.22)
		"bat": c = Color(0.5, 0.32, 0.14); size = Vector3(0.07, 0.07, 0.8)
		"machete": c = Color(0.65, 0.67, 0.7); size = Vector3(0.02, 0.08, 0.65)
		"sledge": c = Color(0.4, 0.4, 0.44); size = Vector3(0.09, 0.09, 0.9)
		"fists": c = Color(0.6, 0.45, 0.35); size = Vector3(0.1, 0.1, 0.12)
	root.add_child(_box(size, c, Vector3(0, 0.0, -0.35), Vector3.ZERO, 0.5))
	if id == "sledge":
		root.add_child(_box(Vector3(0.28, 0.14, 0.16), Color(0.35, 0.36, 0.4), Vector3(0, 0.05, -0.78), Vector3.ZERO, 0.85))
	if id == "machete":
		root.add_child(_box(Vector3(0.05, 0.05, 0.16), Color(0.2, 0.12, 0.08), Vector3(0, 0.0, -0.05), Vector3.ZERO, 0.1))
