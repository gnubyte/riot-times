class_name Proc
# Procedural textures & helpers — no external assets anywhere.
# Every material gets an albedo + a generated normal map for real surface depth.

static var cache := {}
static var height_cache := {}
static var normal_cache := {}
static var extras := {}

static func tex(key: String, size := 128) -> Texture2D:
	var ck := key + "_" + str(size)
	if cache.has(ck):
		return cache[ck]
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var himg := Image.create(size, size, false, Image.FORMAT_L8)
	match key:
		"dust": _dust(img, himg)
		"rusty_metal": _rusty(img, himg)
		"wood": _wood(img, himg)
		"concrete": _concrete(img, himg)
		"plaster": _plaster(img, himg)
		"cobble": _cobble(img, himg)
		"corrugated": _corrugated(img, himg)
		"water": _water(img, himg)
		"skin": _skin(img, himg)
		"chain": _chain(img, himg)
		"asphalt": _asphalt(img, himg)
		"sandbag": _sandbag(img, himg)
		_: _dust(img, himg)
	var t := ImageTexture.create_from_image(img)
	cache[ck] = t
	height_cache[ck] = himg
	return t

static func normal_tex(key: String, size := 128) -> Texture2D:
	var ck := key + "_" + str(size)
	tex(key, size) # ensure generated
	if normal_cache.has(ck):
		return normal_cache[ck]
	var himg: Image = height_cache.get(ck)
	if himg == null:
		return null
	var nm := himg.duplicate()
	nm.bump_map_to_normal_map(1.8)
	var t := ImageTexture.create_from_image(nm)
	normal_cache[ck] = t
	return t

static func mat(key: String, albedo := Color(1, 1, 1), rough := 0.9, metallic := 0.0, size := 128) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(key, size)
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metallic
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	var nm := normal_tex(key, size)
	if nm != null:
		m.normal_enabled = true
		m.normal_texture = nm
	return m

static func particle_quad(tex: Texture2D, emissive := true, quad_size := 1.0) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(quad_size, quad_size)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = emissive
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = emissive
	m.albedo_texture = tex
	if emissive:
		m.emission_enabled = true
		m.emission = Color(1, 0.92, 0.75)
		m.emission_energy_multiplier = 1.1
	q.material = m
	return q

static func particle_soft(col := Color(1, 1, 1, 1)) -> Texture2D:
	var ck := "soft_" + str(col)
	if extras.has(ck):
		return extras[ck]
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x, y).distance_to(Vector2(s, s) * 0.5) / (s * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 2.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	var t := ImageTexture.create_from_image(img)
	extras[ck] = t
	return t

static func noise_tile(size := 128) -> Texture2D:
	if extras.has("noise" + str(size)):
		return extras["noise" + str(size)]
	var small := Image.create(32, 32, false, Image.FORMAT_L8)
	for y in 32:
		for x in 32:
			small.set_pixel(x, y, Color(randf(), 0, 0, 1))
	small.resize(size, size)
	var t := ImageTexture.create_from_image(small)
	extras["noise" + str(size)] = t
	return t

# ---------- painters (albedo + height together) ----------

# tileable value noise — gives textures real blotch/swirl structure instead of TV static
static func _vnoise(x: int, y: int, s: int, seed: int) -> float:
	# hash integer lattice with wrap for seamless tiling
	var h := (x * 374761393 + y * 668265263 + seed * 1442695040888963407)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float((h & 0xFFFF)) / 65535.0

static func _smooth_noise(x: int, y: int, s: int, cell: int, seed: int) -> float:
	var fx := float(x) / cell
	var fy := float(y) / cell
	var x0 := int(floorf(fx)) % s
	var y0 := int(floorf(fy)) % s
	var x1 := (x0 + cell) % s
	var y1 := (y0 + cell) % s
	var tx := fmod(float(x), float(cell)) / cell
	var ty := fmod(float(y), float(cell)) / cell
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _vnoise(x0, y0, s, seed)
	var b := _vnoise(x1, y0, s, seed)
	var c := _vnoise(x0, y1, s, seed)
	var d := _vnoise(x1, y1, s, seed)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

static func _fbm(x: int, y: int, s: int, seed: int) -> float:
	var v := 0.0
	var cell := s / 2
	var amp := 0.5
	while cell >= 2:
		v += _smooth_noise(x, y, s, cell, seed + cell) * amp
		amp *= 0.55
		cell = int(cell / 2.0)
	return v

static func _dust(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var n := _fbm(x, y, s, 17) - 0.5     # big soft drifts
			var grit := randf_range(-0.05, 0.05)
			var patch := 0.0
			if n < -0.22: patch = -0.1           # darker packed dirt patches
			var base := 0.55 + n * 0.22 + grit + patch
			var pebble := 0.0
			if randf() < 0.004: pebble = 0.12
			img.set_pixel(x, y, Color(base * 1.06, base * 0.93, base * 0.72))
			hi.set_pixel(x, y, Color(clampf(0.5 + n * 1.6 + grit * 4.0 + pebble, 0, 1), 0, 0, 1))

static func _rusty(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var n := _fbm(x, y, s, 41) - 0.5
			var grit := randf_range(-0.03, 0.03)
			var rust := n > 0.08 or randf() < 0.04
			var c := Color(0.42 + n * 0.3 + grit, 0.44 + n * 0.3 + grit, 0.47 + n * 0.3) if not rust else Color(0.46 + n * 0.2, 0.24 + n * 0.1, 0.1)
			img.set_pixel(x, y, c)
			var h := 0.5 - 0.16 if rust else 0.5 + n * 0.3
			hi.set_pixel(x, y, Color(clampf(h + grit, 0, 1), 0, 0, 1))

static func _wood(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var grain := sin(y * 0.6 + sin(x * 0.05) * 3.0) * 0.06
			var n := randf_range(-0.03, 0.03)
			var plankline := 1.0 if (x % 32) < 2 else 1.0
			var base := 0.42 + grain + n
			img.set_pixel(x, y, Color(base * 1.1, base * 0.8, base * 0.5) * plankline)
			var h := 0.5 + grain
			if (x % 32) < 2: h = 0.2
			hi.set_pixel(x, y, Color(clampf(h, 0, 1), 0, 0, 1))

static func _concrete(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var n := _fbm(x, y, s, 7) - 0.5
			var grit := randf_range(-0.04, 0.04)
			var crack := false
			# thin crack lines following a noise ridge
			var ridge := absf(_smooth_noise(x, y, s, s / 2, 99) - 0.5)
			if ridge < 0.008 and randf() < 0.7: crack = true
			var g := 0.56 + n * 0.18 + grit + (-0.25 if crack else 0.0)
			img.set_pixel(x, y, Color(g, g * 0.99, g * 0.95))
			hi.set_pixel(x, y, Color(clampf(0.5 + n * 1.2 + grit * 4.0 + (-0.45 if crack else 0.0), 0, 1), 0, 0, 1))

static func _plaster(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var n := randf_range(-0.05, 0.05)
			var stain := 0.0 if randf() > 0.03 else -0.12
			var g := 0.72 + n + stain
			img.set_pixel(x, y, Color(g, g * 0.95, g * 0.84))
			hi.set_pixel(x, y, Color(clampf(0.5 + n * 2.5, 0, 1), 0, 0, 1))

static func _cobble(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var cell := 16
			var cx: int = (x / cell) + ((y / cell) % 2) * 3
			var h := float((cx * 7 + (y / cell) * 13) % 9) / 9.0
			var dome := 0.0
			var lx := float(x % cell) / cell - 0.5
			var ly := float(y % cell) / cell - 0.5
			dome = clampf(0.35 - (lx * lx + ly * ly), 0.0, 0.35)
			var g := 0.4 + h * 0.22 + randf_range(-0.03, 0.03) + dome * 0.3
			var gap := x % cell < 2 or y % cell < 2
			if gap: g *= 0.55
			img.set_pixel(x, y, Color(g, g * 0.94, g * 0.8))
			var hh := 0.35 + h * 0.3 + dome
			if gap: hh = 0.1
			hi.set_pixel(x, y, Color(clampf(hh, 0, 1), 0, 0, 1))

static func _corrugated(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var rib := sin(x * PI / 8.0) * 0.12
			var rust := 0.0 if randf() > 0.1 else -0.2
			var g := 0.55 + rib + randf_range(-0.02, 0.02) + rust
			img.set_pixel(x, y, Color(g * 0.95, g * 0.9, g * 0.85))
			hi.set_pixel(x, y, Color(clampf(0.5 + rib, 0, 1), 0, 0, 1))

static func _water(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var n := randf_range(-0.05, 0.05)
			var ripple := sin((x + y) * 0.35) * 0.05
			img.set_pixel(x, y, Color(0.18 + n, 0.34 + ripple + n, 0.3 + ripple + n))
			hi.set_pixel(x, y, Color(clampf(0.5 + ripple * 4.0, 0, 1), 0, 0, 1))

static func _skin(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var n := randf_range(-0.02, 0.02)
			img.set_pixel(x, y, Color(0.8 + n, 0.65 + n, 0.5 + n))
			hi.set_pixel(x, y, Color(clampf(0.5 + n * 4.0, 0, 1), 0, 0, 1))

static func _chain(img: Image, hi: Image) -> void:
	var s := img.get_width()
	img.fill(Color(0.32, 0.33, 0.36))
	hi.fill(Color(0.4, 0, 0, 1))
	for y in s:
		for x in s:
			if (x % 16) < 6 and (y % 8) > 2:
				img.set_pixel(x, y, Color(0.5, 0.5, 0.54))
				hi.set_pixel(x, y, Color(0.75, 0, 0, 1))
			elif randf() < 0.05:
				img.set_pixel(x, y, Color(0.45, 0.25, 0.12))

static func _asphalt(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var n := randf_range(-0.04, 0.04)
			var gravel := randf() < 0.25
			var g := 0.22 + n + (0.1 if gravel else 0.0)
			var oil := 0.0
			if randf() < 0.004: oil = -0.08
			img.set_pixel(x, y, Color(g, g, g * 1.05 + oil))
			var h := 0.4 + (0.18 if gravel else 0.0) + n * 2.0
			if randf() < 0.004: h = 0.05 # cracks
			hi.set_pixel(x, y, Color(clampf(h, 0, 1), 0, 0, 1))

static func _sandbag(img: Image, hi: Image) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var weave := (sin(x * 1.2) + sin(y * 1.2)) * 0.03
			var n := randf_range(-0.03, 0.03)
			var base := 0.62 + weave + n
			img.set_pixel(x, y, Color(base * 0.95, base * 0.88, base * 0.62))
			hi.set_pixel(x, y, Color(clampf(0.5 + weave * 3.0 + n * 2.0, 0, 1), 0, 0, 1))
