class_name IconArt
extends RefCounted
# Hand-authored pixel art for every item icon plus HUD status glyphs.
# Sprites are painted 64x64 with a limited palette, dark outline and drop
# shadow, mounted on a small riveted backplate so the whole inventory reads
# as one set. Food and drink get the most love: recognizable, tasty, wasteland.

const S := 64
const OUT := Color(0.09, 0.06, 0.045, 1.0)

static var _cache := {}
static var _sprite_cache := {}
static var _status_cache := {}

static func icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var raw := _sprite(id, 0)
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_backplate(img)
	_silhouette(img, raw, 2, 3, Color(0, 0, 0, 0.45))
	img.blit_rect(raw, Rect2i(Vector2i.ZERO, Vector2i(S, S)), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex

# Raw sprite (no backplate) for the eat/drink animation frames.
static func eat_frame(id: String, bites: int) -> Texture2D:
	var key := "%s|%d" % [id, bites]
	if _sprite_cache.has(key):
		return _sprite_cache[key]
	var raw := _sprite(id, bites)
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(raw, Rect2i(Vector2i.ZERO, Vector2i(S, S)), Vector2i.ZERO)
	var tex := ImageTexture.create_from_image(img)
	_sprite_cache[key] = tex
	return tex

static func status_icon(name: String) -> Texture2D:
	if _status_cache.has(name):
		return _status_cache[name]
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_status_paint(img, name)
	_outline(img, OUT)
	var tex := ImageTexture.create_from_image(img)
	_status_cache[name] = tex
	return tex

# ================================================================
# raster helpers
# ================================================================
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _r(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(img, x, y, c)

static func _ell(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 2):
		for x in range(int(cx - rx), int(cx + rx) + 2):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy <= 1.02:
				_px(img, x, y, c)

static func _ell_o(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 2):
		for x in range(int(cx - rx), int(cx + rx) + 2):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			var v := dx * dx + dy * dy
			if v <= 1.02 and v >= 0.62:
				_px(img, x, y, c)

static func _ln(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color, t := 1.0) -> void:
	var steps := maxi(int(Vector2(x1 - x0, y1 - y0).length() * 2.0), 1)
	for i in steps + 1:
		var f := float(i) / float(steps)
		var x := lerpf(x0, x1, f)
		var y := lerpf(y0, y1, f)
		if t <= 1.0:
			_px(img, int(x), int(y), c)
		else:
			_r(img, int(x - (t - 1.0) / 2.0), int(y - (t - 1.0) / 2.0), int(x + t / 2.0), int(y + t / 2.0), c)

static func _tri(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, c: Color) -> void:
	var ymin := int(mini(mini(p0.y, p1.y), p2.y))
	var ymax := int(maxi(maxi(p0.y, p1.y), p2.y))
	for y in range(ymin, ymax + 1):
		var xs: Array[float] = []
		for edge in [[p0, p1], [p1, p2], [p2, p0]]:
			var a: Vector2 = edge[0]
			var b: Vector2 = edge[1]
			if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
				xs.append(lerpf(a.x, b.x, float(y - a.y) / float(b.y - a.y)))
		if xs.size() >= 2:
			xs.sort()
			for x in range(int(xs[0]), int(xs[xs.size() - 1]) + 1):
				_px(img, x, y, c)

static func _rrect(img: Image, x0: int, y0: int, x1: int, y1: int, r: int, c: Color) -> void:
	_r(img, x0 + r, y0, x1 - r, y1, c)
	_r(img, x0, y0 + r, x1, y1 - r, c)
	for dy in range(-r, r + 1):
		var k := sqrt(maxf(0.0, r * r - dy * dy))
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				_px(img, x0 + r + dx, y0 + r + dy, c)
				_px(img, x1 - r + dx, y1 - r + dy, c)

# Add a 1px dark outline around every opaque cluster.
static func _outline(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var marks: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				if (x > 0 and img.get_pixel(x - 1, y).a > 0.5) or (x < w - 1 and img.get_pixel(x + 1, y).a > 0.5) \
						or (y > 0 and img.get_pixel(x, y - 1).a > 0.5) or (y < h - 1 and img.get_pixel(x, y + 1).a > 0.5):
					marks.append(Vector2i(x, y))
	for m in marks:
		img.set_pixel(m.x, m.y, col)

# Blit a flat silhouette of src (any alpha) in one color.
static func _silhouette(dst: Image, src: Image, ox: int, oy: int, col: Color) -> void:
	for y in src.get_height():
		for x in src.get_width():
			if src.get_pixel(x, y).a > 0.4:
				_px(dst, x + ox, y + oy, col)

static func _glow(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(int(cy - r), int(cy + r) + 2):
		for x in range(int(cx - r), int(cx + r) + 2):
			var d := Vector2(x - cx, y - cy).length() / r
			if d < 1.0:
				var a := pow(1.0 - d, 2.0) * col.a
				var old := img.get_pixel(x, y)
				if old.a < 0.05:
					_px(img, x, y, Color(col.r, col.g, col.b, a))

static func _steam(img: Image, x: float, y0: int, y1: int, col: Color) -> void:
	var yy := y0
	var t := 0.0
	while yy > y1:
		# 2px-wide plume so steam survives small sizes
		_px(img, int(x + sin(t) * 3.0), yy, col)
		_px(img, int(x + sin(t) * 3.0) + 1, yy, col)
		_px(img, int(x + sin(t) * 3.0) + 1, yy - 1, Color(col.r, col.g, col.b, col.a * 0.5))
		t += 0.55
		yy -= 1

# Riveted mounting plate every icon sits on.
static func _backplate(img: Image) -> void:
	_rrect(img, 2, 2, 61, 61, 6, Color(0.10, 0.085, 0.068, 0.97))
	_rrect(img, 3, 3, 60, 60, 5, Color(0.13, 0.108, 0.086, 0.97))
	# top inner light, bottom inner shade
	for x in range(5, 59):
		img.set_pixel(x, 3, Color(0.32, 0.26, 0.18, 0.55))
		img.set_pixel(x, 60, Color(0.02, 0.015, 0.01, 0.5))
	for y in range(5, 59):
		img.set_pixel(3, y, Color(0.30, 0.24, 0.17, 0.4))
		img.set_pixel(60, y, Color(0.02, 0.015, 0.01, 0.5))
	# corner rivets
	for corner in [[7, 7], [56, 7], [7, 56], [56, 56]]:
		var cx: int = corner[0]
		var cy: int = corner[1]
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if dx * dx + dy * dy <= 3:
					_px(img, cx + dx, cy + dy, Color(0.38, 0.36, 0.33, 1.0))
		_px(img, cx - 1, cy - 1, Color(0.6, 0.57, 0.5, 1.0))

# ================================================================
# sprite dispatch
# ================================================================
static func _sprite(id: String, bites: int) -> Image:
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var t := ""
	if ItemDB.ITEMS.has(id):
		t = String(ItemDB.ITEMS[id].get("type", ""))
	elif ItemDB.WEAPONS.has(id):
		t = "weapon"
	elif ItemDB.MELEE.has(id):
		t = "melee"
	elif ItemDB.ARMOR.has(id):
		t = "armor"
	match id:
		# food
		"beans": _beans(img)
		"jerky": _jerky(img)
		"mre": _mre(img)
		"chips": _chips(img)
		"apple": _apple(img)
		"berries": _berries(img)
		"raw_meat": _meat(img, false)
		"cooked_meat": _meat(img, true)
		"raw_fish": _fish(img, false, false)
		"cooked_fish": _fish(img, true, false)
		"glow_carp": _fish(img, false, true)
		"stew": _stew(img)
		# drinks
		"dirty_water": _bottle(img, Color(0.30, 0.29, 0.16), Color(0.5, 0.48, 0.4), true)
		"clean_water": _bottle(img, Color(0.30, 0.58, 0.85), Color(0.2, 0.4, 0.7), false)
		"soda": _soda(img)
		"pine_tea": _tea(img)
		"blood_pack": _blood_pack(img)
		# meds & cures
		"bandage": _bandage(img)
		"medkit": _medkit(img)
		"painkillers": _painkillers(img)
		"antibiotics": _antibiotics(img)
		"rad_flush": _vial(img, Color(0.3, 0.6, 0.9), true)
		"antiviral": _syringe(img)
		"lazarus": _vial(img, Color(1.0, 0.85, 0.3), false)
		"silverleaf_tincture": _flask(img, Color(0.75, 0.9, 0.95))
		"sanguine_serum": _flask(img, Color(0.62, 0.06, 0.08))
		# throwables
		"frag": _frag(img)
		"molotov": _molotov(img)
		"noisemaker": _noisemaker(img)
		# materials & tools
		"scrap": _scrap(img)
		"cloth": _cloth(img)
		"weapon_parts": _parts(img)
		"silverleaf": _herb(img)
		"pine_needles": _pine(img)
		"fuel_can": _jerrycan(img)
		"fishing_rod": _rod(img)
		"campfire_kit": _campkit(img)
		# valuables & notes & currency
		"gold_ring": _ring(img)
		"old_watch": _watch(img)
		"vinyl": _vinyl(img)
		"shards": _crystals(img)
		"note_g9", "note_mall", "note_wolf": _note(img)
		_:
			match t:
				"weapon": _weapon(img, id)
				"melee": _melee_w(img, id)
				"armor": _armor_w(img, id)
				"ammo": _ammo(img, id)
				"med", "cure": _pillbottle(img)
				"throwable": _frag(img)
				"valuable": _crystals(img)
				"note": _note(img)
				_: _crate(img)
	if bites > 0:
		_bite(img, bites)
	_outline(img, OUT)
	return img

# Take chunky bites out of the top-right (eat animation).
static func _bite(img: Image, bites: int) -> void:
	var spots := [Vector2(47, 16), Vector2(20, 20), Vector2(36, 9)]
	for i in bites:
		var c: Vector2 = spots[i]
		for y in range(int(c.y - 9), int(c.y + 9)):
			for x in range(int(c.x - 9), int(c.x + 9)):
				var d := Vector2(x - c.x, y - c.y).length()
				if d < 8.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0))

# ================================================================
# food painters
# ================================================================
const STEEL := Color(0.55, 0.56, 0.58)
const STEEL_HI := Color(0.74, 0.75, 0.78)
const STEEL_LO := Color(0.31, 0.32, 0.36)
const CREAM := Color(0.91, 0.86, 0.72)
const WOOD := Color(0.44, 0.29, 0.15)

static func _beans(img: Image) -> void:
	# tin body
	_r(img, 20, 14, 44, 52, STEEL)
	_r(img, 21, 14, 23, 52, STEEL_HI)
	_r(img, 41, 14, 43, 52, STEEL_LO)
	# top + bottom rims
	_ell(img, 32, 14, 12, 4, STEEL_HI)
	_ell(img, 32, 14, 9, 3, Color(0.24, 0.25, 0.28))
	_ell(img, 32, 52, 12, 4, STEEL_LO)
	_ln(img, 30, 14, 37, 13, STEEL_HI) # pull tab
	# paper label
	_r(img, 20, 24, 44, 41, Color(0.66, 0.24, 0.13))
	_r(img, 20, 24, 44, 25, CREAM)
	_r(img, 20, 40, 44, 41, CREAM)
	_r(img, 20, 24, 21, 41, Color(1.0, 0.96, 0.85)) # left edge highlight
	_ell(img, 32, 32, 9, 6, CREAM)
	_ell(img, 29, 31, 3, 2, Color(0.84, 0.66, 0.42)) # beans
	_ell(img, 35, 33, 3, 2, Color(0.84, 0.66, 0.42))
	_ell(img, 32, 35, 3, 2, Color(0.84, 0.66, 0.42))
	_px(img, 29, 30, Color(0.95, 0.8, 0.6))
	_px(img, 35, 32, Color(0.95, 0.8, 0.6))

static func _jerky(img: Image) -> void:
	var dark := Color(0.28, 0.09, 0.05)
	var base := Color(0.50, 0.20, 0.10)
	var fiber := Color(0.66, 0.38, 0.20)
	var sheen := Color(0.80, 0.52, 0.30)
	# three overlapping strips laid diagonally
	for k in 3:
		var x0 := 13.0 + k * 4.0
		var y0 := 44.0 - k * 4.0
		var x1 := 50.0
		var y1 := 18.0 + k * 10.0
		_ln(img, x0, y0, x1, y1, base, 7.0)
		_ln(img, x0 + 3.0, y0 - 3.0, x1 - 4.0, y1 + 3.0, sheen, 2.0) # leathery sheen
		_ln(img, x0 + 5.0, y0 - 2.0, x1 - 6.0, y1 + 5.0, fiber, 1.0) # fiber streak
		_px(img, int(x0) - 2, int(y0) + 2, dark) # torn ends
		_px(img, int(x0) - 1, int(y0) + 3, dark)
		_px(img, int(x1) + 1, int(y1) - 1, dark)
	# salt speckles
	for p in [[24, 27], [39, 20], [31, 39], [45, 33]]:
		_px(img, int(p[0]), int(p[1]), Color(0.92, 0.89, 0.82))

static func _mre(img: Image) -> void:
	var olive := Color(0.42, 0.40, 0.23)
	var olive_hi := Color(0.56, 0.53, 0.31)
	var olive_lo := Color(0.27, 0.26, 0.15)
	_rrect(img, 16, 12, 48, 54, 4, olive)
	_r(img, 17, 13, 47, 14, olive_hi)
	_r(img, 16, 12, 48, 19, olive_lo) # crimp band
	_r(img, 16, 20, 48, 21, Color(0.33, 0.31, 0.18))
	_ell(img, 24, 15, 2, 2, STEEL) # press studs
	_ell(img, 40, 15, 2, 2, STEEL)
	_r(img, 16, 22, 17, 52, olive_hi) # rim light down the left edge
	_r(img, 45, 22, 47, 53, olive_lo)
	# label patch
	_rrect(img, 22, 27, 42, 45, 2, Color(0.74, 0.66, 0.47))
	_rrect(img, 23, 28, 41, 44, 2, Color(0.84, 0.78, 0.6))
	_tri(img, Vector2(32, 30), Vector2(37, 35), Vector2(32, 40), Color(0.32, 0.26, 0.13)) # star mark
	_tri(img, Vector2(32, 30), Vector2(27, 35), Vector2(32, 40), Color(0.32, 0.26, 0.13))
	_r(img, 26, 42, 38, 43, Color(0.5, 0.44, 0.3))
	_r(img, 29, 42, 35, 43, Color(0.66, 0.6, 0.44))
	# crinkle creases bottom-right — flexible packaging, not a card
	_ln(img, 38, 46, 44, 50, Color(0.22, 0.21, 0.12), 1.0)
	_ln(img, 42, 45, 46, 48, Color(0.22, 0.21, 0.12), 1.0)

static func _chips(img: Image) -> void:
	var red := Color(0.76, 0.17, 0.11)
	# bag: wider at the bottom
	for y in range(14, 53):
		var k := float(y - 14) / 39.0
		var x0 := int(lerpf(23.0, 16.0, k))
		var x1 := int(lerpf(41.0, 48.0, k))
		for x in range(x0, x1 + 1):
			var c := red
			if x < x0 + 3:
				c = Color(0.9, 0.35, 0.25) # left crease light
			if x > x1 - 3:
				c = Color(0.55, 0.10, 0.07)
			if y > 48:
				c = c.darkened(0.2)
			_px(img, x, y, c)
	# crimped top
	_r(img, 22, 10, 42, 14, Color(0.68, 0.70, 0.74))
	for x in range(23, 42, 3):
		_r(img, x, 10, x + 1, 14, Color(0.5, 0.52, 0.56))
	# flash + chip
	_ell(img, 32, 33, 11, 9, CREAM)
	_ell(img, 32, 33, 8, 6, Color(0.97, 0.94, 0.86))
	_ell(img, 32, 33, 4, 4, Color(0.96, 0.8, 0.3)) # chip
	_ell(img, 30, 31, 1, 1, Color(1.0, 0.95, 0.7))

static func _apple(img: Image) -> void:
	var red := Color(0.78, 0.14, 0.12)
	_ell(img, 32, 36, 15, 15, red)
	# shading
	for y in range(24, 50):
		for x in range(38, 50):
			var d := Vector2(x - 32, y - 36).length()
			if d < 14.5:
				_px(img, x, y, Color(0.58, 0.08, 0.07))
	_ell(img, 25, 29, 4, 5, Color(0.95, 0.42, 0.35)) # highlight
	_px(img, 24, 28, Color(1.0, 0.75, 0.65))
	_px(img, 31, 22, Color(0.4, 0.06, 0.05)) # dimple
	_ln(img, 32, 21, 34, 11, Color(0.35, 0.2, 0.08), 2.0) # stem
	_ell(img, 39, 14, 4, 2, Color(0.28, 0.52, 0.2)) # leaf
	_px(img, 37, 13, Color(0.4, 0.7, 0.3))

static func _berries(img: Image) -> void:
	var purple := Color(0.40, 0.19, 0.52)
	var purple_hi := Color(0.66, 0.47, 0.85)
	var purple_lo := Color(0.26, 0.11, 0.36)
	_ell(img, 31, 14, 3, 1.5, Color(0.28, 0.5, 0.22)) # leaves
	_ell(img, 36, 15, 3, 1.5, Color(0.24, 0.46, 0.2))
	_ln(img, 33, 16, 33, 22, Color(0.3, 0.4, 0.2))
	var hl := 0
	for b in [[24, 27], [33, 24], [42, 28], [27, 37], [38, 37], [32, 47]]:
		var bx: int = int(b[0])
		var by: int = int(b[1])
		_ell(img, bx, by, 6, 6, purple)
		_ell(img, bx + 2, by + 3, 3, 2, purple_lo)
		if hl < 3: # specular only on the top three, unified light
			_ell(img, bx - 2, by - 2, 1.5, 1.5, purple_hi)
			hl += 1
	# front berry lightest (ripe)
	_ell(img, 32, 47, 1.5, 1.5, Color(0.85, 0.75, 0.95))

static func _meat(img: Image, cooked: bool) -> void:
	var bone := Color(0.93, 0.90, 0.84)
	if cooked:
		# smaller rounded steak, browned crust + grill marks
		var meat := Color(0.46, 0.23, 0.09)
		var meat_hi := Color(0.66, 0.38, 0.15)
		_ell(img, 30, 38, 14, 11, meat)
		_ell(img, 30, 30, 13, 4, Color(0.82, 0.66, 0.38)) # crust top
		_ell(img, 30, 33, 10, 2, meat)
		for k in 3: # evenly spaced grill marks
			_ln(img, 19 + k * 8, 46, 25 + k * 8, 31, Color(0.20, 0.08, 0.03), 2.0)
		_ln(img, 23, 38, 38, 35, meat_hi, 2.0) # juicy sheen
		_ln(img, 42, 41, 51, 37, bone, 4.0)
		_ell(img, 43, 40, 2.5, 2.5, bone)
		_ell(img, 51, 37, 2.5, 2.5, bone)
	else:
		# bigger pink slab, thin fat rind, T-bone knobs, marbling inside
		var pink := Color(0.76, 0.22, 0.20)
		var pink_hi := Color(0.92, 0.5, 0.42)
		_ell(img, 30, 36, 17, 14, pink)
		_ell(img, 30, 24, 16, 3.5, Color(0.93, 0.88, 0.78)) # thin fat rind
		_ell(img, 30, 28, 15, 3, pink)
		_ln(img, 38, 32, 50, 26, bone, 5.0) # prominent T-bone
		_ell(img, 39, 31, 3.5, 3.5, bone)
		_ell(img, 50, 26, 3, 3, bone)
		_ell(img, 49, 25, 1, 1, Color(1, 1, 0.95))
		_ln(img, 20, 32, 34, 29, pink_hi, 2.0) # sheen
		_ln(img, 21, 40, 31, 37, Color(0.93, 0.72, 0.68), 1.0) # marbling
		_ln(img, 27, 44, 37, 41, Color(0.93, 0.72, 0.68), 1.0)
		_ln(img, 33, 34, 40, 38, Color(0.93, 0.72, 0.68), 1.0)

static func _fish(img: Image, cooked: bool, glow: bool) -> void:
	var body := Color(0.45, 0.53, 0.60) # raw
	var back := Color(0.28, 0.36, 0.45)
	var belly := Color(0.66, 0.72, 0.78)
	if cooked:
		body = Color(0.72, 0.48, 0.20)
		back = Color(0.5, 0.3, 0.12)
		belly = Color(0.88, 0.68, 0.38)
	elif glow:
		body = Color(0.42, 0.92, 0.5)
		back = Color(0.10, 0.42, 0.24)
		belly = Color(0.75, 1.0, 0.78)
	if glow:
		_glow(img, 30, 34, 26, Color(0.4, 1.0, 0.5, 0.4))
	# tail: two-lobed fork with a notch
	_tri(img, Vector2(42, 34), Vector2(57, 22), Vector2(57, 46), back)
	_tri(img, Vector2(44, 34), Vector2(57, 28), Vector2(57, 40), Color(0, 0, 0, 0))
	# body
	_ell(img, 29, 35, 17, 11, body)
	_ell(img, 29, 28, 16, 5, back) # back
	_ell(img, 30, 41, 14, 4, belly) # belly
	# fins
	_tri(img, Vector2(26, 24), Vector2(32, 16), Vector2(34, 25), back)
	_tri(img, Vector2(26, 44), Vector2(30, 52), Vector2(34, 44), back)
	# eye + gill + pectoral fin + mouth notch
	_ell(img, 18, 33, 2.5, 2.5, Color(0.95, 0.95, 0.9))
	_ell(img, 18, 33, 1.2, 1.2, Color(0.05, 0.05, 0.08))
	_ln(img, 24, 28, 23, 40, Color(0.2, 0.25, 0.3), 1.0)
	_tri(img, Vector2(27, 37), Vector2(33, 42), Vector2(29, 44), back)
	_px(img, 13, 37, Color(0.1, 0.12, 0.15))
	_px(img, 13, 38, Color(0.1, 0.12, 0.15))
	if cooked: # roast marks
		for k in 3:
			_ln(img, 18 + k * 9, 27, 22 + k * 9, 43, Color(0.35, 0.18, 0.06), 2.0)
	if glow: # speckles + bubbles
		for p in [[28, 30], [36, 34], [24, 38], [40, 28]]:
			_px(img, int(p[0]), int(p[1]), Color(0.8, 1.0, 0.85))
		for b in [[50, 12, 2], [55, 18, 3], [46, 8, 1]]:
			_ell_o(img, float(b[0]), float(b[1]), float(b[2]), float(b[2]), Color(0.6, 1.0, 0.7, 0.6))
	if cooked: # horizontal skewer behind, short handle
		_ln(img, 8, 30, 54, 30, Color(0.45, 0.29, 0.14), 3.0)
		_r(img, 8, 27, 13, 33, WOOD)
		_px(img, 53, 29, Color(0.3, 0.18, 0.08))
		_steam(img, 46, 16, 8, Color(1, 1, 1, 0.35))
		_steam(img, 22, 15, 8, Color(1, 1, 1, 0.3))

static func _stew(img: Image) -> void:
	_steam(img, 26, 18, 6, Color(1, 1, 1, 0.35))
	_steam(img, 38, 20, 8, Color(1, 1, 1, 0.3))
	# bowl
	_ell(img, 32, 36, 18, 6, Color(0.62, 0.32, 0.17)) # rim
	_ell(img, 32, 36, 15, 4.5, Color(0.44, 0.28, 0.11)) # broth
	for y in range(36, 54): # bowl body
		var k := float(y - 36) / 18.0
		var rx := int(lerpf(18.0, 12.0, k))
		for x in range(32 - rx, 32 + rx + 1):
			var c := Color(0.56, 0.28, 0.15)
			if y < 40:
				c = Color(0.66, 0.36, 0.19)
			if x > 32 + rx - 4:
				c = c.darkened(0.25)
			_px(img, x, y, c)
	_ell(img, 32, 54, 12, 3, Color(0.35, 0.16, 0.08))
	_ln(img, 20, 42, 26, 44, Color(0.8, 0.5, 0.3), 2.0) # highlight
	# chunks in the stew — high contrast, breaking the rim silhouette
	_r(img, 23, 32, 27, 36, Color(1.0, 0.5, 0.1)) # carrot
	_r(img, 35, 31, 39, 35, Color(0.88, 0.84, 0.66)) # potato
	_r(img, 29, 35, 33, 39, Color(0.32, 0.16, 0.09)) # meat
	for h in [[26, 30], [32, 29], [38, 30]]: # herb flecks
		_px(img, int(h[0]), int(h[1]), Color(0.4, 0.7, 0.3))

# ================================================================
# drink painters
# ================================================================
static func _bottle(img: Image, liquid: Color, cap: Color, murky: bool) -> void:
	# neck + cap
	_r(img, 26, 6, 38, 11, cap)
	_r(img, 26, 6, 38, 7, cap.lightened(0.25))
	_r(img, 27, 11, 37, 18, Color(0.75, 0.8, 0.85, 0.55)) # glass neck
	# body
	_rrect(img, 23, 18, 41, 54, 5, Color(0.75, 0.8, 0.85, 0.35))
	# liquid fill
	var top := 26
	for y in range(top, 54):
		for x in range(25, 40):
			var c := liquid
			if y == top:
				c = liquid.lightened(0.35)
			if x < 28:
				c = liquid.lightened(0.2)
			if x > 37:
				c = liquid.darkened(0.25)
			_px(img, x, y, Color(c.r, c.g, c.b, 0.9))
	if murky:
		for s in [[28, 50], [33, 52], [36, 49], [30, 47]]: # sediment
			_ell(img, float(s[0]), float(s[1]), 1.5, 1, liquid.darkened(0.45))
	else:
		_ln(img, 28, 24, 28, 50, Color(1, 1, 1, 0.35), 1.0) # glass shine
		_ln(img, 26, 24, 26, 50, liquid.lightened(0.45), 1.0) # left highlight stripe
	# label
	_r(img, 23, 34, 41, 42, CREAM)
	_r(img, 23, 34, 41, 35, Color(0.7, 0.6, 0.45))
	_ln(img, 26, 38, 38, 38, Color(0.45, 0.4, 0.3))
	_ell(img, 32, 40, 2, 1.5, cap)

static func _soda(img: Image) -> void:
	var red := Color(0.78, 0.14, 0.11)
	_r(img, 22, 16, 42, 52, red)
	_ell(img, 32, 16, 10, 3, Color(0.78, 0.78, 0.82)) # top
	_ell(img, 32, 16, 7, 2, Color(0.55, 0.55, 0.6))
	_ln(img, 29, 16, 36, 16, Color(0.85, 0.85, 0.9)) # tab
	_ell(img, 32, 52, 10, 3, Color(0.5, 0.08, 0.06))
	# bold white band across the top quarter, one emblem shape
	_r(img, 23, 19, 41, 28, Color(0.96, 0.93, 0.86))
	_ln(img, 23, 19, 41, 19, Color(1, 1, 1))
	_ell(img, 32, 36, 7, 7, Color(0.98, 0.8, 0.25))
	_ell(img, 32, 36, 2, 2, Color(1.0, 0.97, 0.9))
	for p in [[27, 44], [37, 44]]: # fizz dots
		_px(img, int(p[0]), int(p[1]), Color(1, 1, 1))
	_r(img, 23, 17, 25, 51, Color(1, 0.5, 0.4, 0.3)) # can highlight
	_r(img, 39, 17, 41, 51, Color(0.4, 0.02, 0.02))

static func _tea(img: Image) -> void:
	_steam(img, 28, 24, 12, Color(1, 1, 1, 0.4))
	_steam(img, 35, 24, 14, Color(1, 1, 1, 0.3))
	# enamel mug
	_rrect(img, 17, 26, 44, 52, 3, Color(0.42, 0.46, 0.52))
	_r(img, 18, 27, 43, 28, Color(0.58, 0.62, 0.68))
	_r(img, 41, 29, 43, 51, Color(0.28, 0.30, 0.35))
	_rrect(img, 17, 26, 44, 28, 3, Color(0.55, 0.58, 0.64))
	_ell(img, 30, 27, 12, 3.5, Color(0.55, 0.36, 0.14)) # tea
	_ell(img, 30, 27, 9, 2, Color(0.68, 0.47, 0.2))
	_px(img, 44, 28, CREAM) # enamel chip
	# handle: thick ring on the right side
	for t in 2:
		_ell_o(img, 49, 39, 5 - t, 7 - t, Color(0.42, 0.46, 0.52))
	# pine sprig across the rim — two bold clusters
	_ln(img, 20, 24, 40, 20, Color(0.25, 0.5, 0.25), 2.0)
	for k in 2:
		_ln(img, 25 + k * 9, 23 - k, 28 + k * 9, 19 - k, Color(0.35, 0.6, 0.3), 2.0)

static func _blood_pack(img: Image) -> void:
	# hanging tab
	_r(img, 29, 8, 35, 14, Color(0.7, 0.72, 0.75))
	_ell(img, 32, 10, 1.5, 1.5, Color(0.2, 0.2, 0.22))
	# bag
	_rrect(img, 20, 14, 44, 52, 7, Color(0.85, 0.88, 0.9, 0.30))
	_r(img, 21, 20, 43, 51, Color(0.55, 0.04, 0.06, 0.95)) # blood
	_r(img, 21, 20, 23, 51, Color(0.72, 0.1, 0.1, 0.95))
	_r(img, 21, 20, 43, 21, Color(0.8, 0.18, 0.16, 0.95))
	# label
	_r(img, 24, 28, 40, 36, Color(0.92, 0.9, 0.86))
	_r(img, 31, 29, 33, 35, Color(0.85, 0.1, 0.1))
	_r(img, 28, 31, 36, 33, Color(0.85, 0.1, 0.1))
	# tube — thick with a joint collar where it meets the bag
	_r(img, 30, 51, 35, 55, Color(0.6, 0.62, 0.66))
	_ln(img, 33, 53, 47, 58, Color(0.8, 0.82, 0.85), 3.0)
	_r(img, 45, 56, 51, 61, Color(0.3, 0.3, 0.33))

# ================================================================
# meds & cures
# ================================================================
static func _bandage(img: Image) -> void:
	# unrolled tail
	_ln(img, 40, 42, 55, 50, CREAM, 6.0)
	for k in 3:
		_px(img, 53 + k, 47 - k, Color(0.8, 0.76, 0.64))
	# roll
	_ell(img, 29, 33, 14, 14, CREAM)
	_ell(img, 29, 33, 7, 7, Color(0.78, 0.74, 0.62))
	_ell(img, 29, 33, 4, 4, Color(0, 0, 0, 0))
	_ln(img, 18, 26, 40, 24, Color(1, 1, 0.95), 2.0)
	# red cross stamp
	_r(img, 27, 27, 31, 39, Color(0.85, 0.15, 0.12))
	_r(img, 22, 31, 36, 35, Color(0.85, 0.15, 0.12))

static func _medkit(img: Image) -> void:
	var olive := Color(0.32, 0.37, 0.24)
	_rrect(img, 14, 24, 50, 52, 3, olive)
	_r(img, 15, 25, 49, 27, olive.lightened(0.18))
	_r(img, 14, 33, 50, 34, olive.darkened(0.3)) # lid seam
	_ell_o(img, 32, 24, 7, 3, olive.darkened(0.2)) # handle
	_r(img, 29, 20, 35, 24, Color(0.25, 0.3, 0.18))
	_r(img, 30, 30, 34, 33, STEEL) # latch
	# red cross
	_r(img, 29, 37, 35, 49, Color(0.86, 0.12, 0.1))
	_r(img, 24, 41, 40, 45, Color(0.86, 0.12, 0.1))
	_px(img, 26, 39, Color(1, 0.5, 0.4))

static func _painkillers(img: Image) -> void:
	_rrect(img, 24, 20, 40, 54, 3, Color(0.78, 0.58, 0.18))
	_r(img, 23, 14, 41, 20, Color(0.92, 0.9, 0.86))
	_r(img, 23, 14, 41, 15, Color(1, 1, 1))
	_r(img, 25, 32, 39, 44, CREAM)
	_ell(img, 32, 38, 3, 3, Color(0.85, 0.1, 0.1))
	_r(img, 25, 32, 39, 33, Color(0.7, 0.6, 0.45))
	_r(img, 26, 21, 27, 53, Color(0.9, 0.72, 0.3))
	# loose pills
	_ell(img, 20, 50, 4, 3, Color(0.95, 0.93, 0.88))
	_ln(img, 17, 50, 23, 50, Color(0.7, 0.68, 0.62))
	_ell(img, 45, 52, 4, 3, Color(0.9, 0.4, 0.35))
	_ln(img, 42, 52, 48, 52, Color(0.65, 0.28, 0.25))

static func _antibiotics(img: Image) -> void:
	_rrect(img, 15, 22, 49, 46, 3, Color(0.72, 0.74, 0.78))
	_rrect(img, 17, 24, 47, 44, 2, Color(0.8, 0.82, 0.85))
	_r(img, 15, 22, 49, 23, Color(0.85, 0.86, 0.9))
	_r(img, 15, 45, 49, 46, Color(0.5, 0.52, 0.56))
	for cy in 2:
		for cx in 2:
			var x := 23 + cx * 10
			var y := 30 + cy * 9
			_ell(img, x, y, 4, 3.5, Color(0.92, 0.94, 0.96))
			_ell(img, x - 1, y - 1, 1.5, 1, Color(1, 1, 1))
			_ell(img, x + 1, y + 1, 2, 1.5, Color(0.7, 0.72, 0.76))
	_r(img, 15, 48, 49, 49, Color(0.7, 0.2, 0.15)) # tear strip

static func _vial(img: Image, liquid: Color, rads := false) -> void:
	_r(img, 26, 10, 38, 18, Color(0.25, 0.25, 0.28)) # cap
	_r(img, 26, 10, 38, 11, Color(0.4, 0.4, 0.44))
	_rrect(img, 24, 18, 40, 53, 4, Color(0.8, 0.85, 0.9, 0.35)) # glass
	_rrect(img, 25, 19, 39, 52, 4, Color(0.55, 0.62, 0.7, 0.5)) # glass outline body
	var top := 24
	for y in range(top, 51):
		for x in range(27, 38):
			var c := liquid
			if y == top:
				c = liquid.lightened(0.4)
			if x < 30:
				c = liquid.lightened(0.2)
			_px(img, x, y, Color(c.r, c.g, c.b, 0.92))
	_ln(img, 29, 22, 29, 50, Color(1, 1, 1, 0.35))
	if rads:
		# bolder trefoil: wider blades, bigger hub
		_ell(img, 32, 37, 8, 8, Color(1.0, 0.85, 0.1))
		_ell(img, 32, 37, 2.5, 2.5, Color(0.1, 0.08, 0.05))
		for a in 3:
			var ang := -PI / 2.0 + a * TAU / 3.0
			_tri(img, Vector2(32, 37), Vector2(32 + cos(ang - 0.6) * 8, 37 + sin(ang - 0.6) * 8), Vector2(32 + cos(ang + 0.6) * 8, 37 + sin(ang + 0.6) * 8), Color(0.1, 0.08, 0.05))

static func _syringe(img: Image) -> void:
	_ln(img, 10, 54, 18, 46, STEEL_HI, 1.0) # needle
	# barrel
	_ln(img, 18, 46, 44, 20, Color(0.85, 0.88, 0.9, 0.8), 8.0)
	_ln(img, 19, 45, 43, 21, Color(0.4, 0.9, 0.5, 0.9), 5.0) # liquid
	_ln(img, 44, 20, 52, 12, Color(0.3, 0.3, 0.33), 4.0) # plunger
	_r(img, 49, 9, 56, 16, Color(0.3, 0.3, 0.33)) # flange
	_r(img, 50, 10, 55, 15, Color(0.45, 0.45, 0.5))
	# graduation ticks
	for k in 3:
		_ln(img, 26 + k * 6, 40 - k * 6, 29 + k * 6, 43 - k * 6, Color(0.2, 0.2, 0.25), 1.0)
	_ln(img, 21, 42, 25, 38, Color(1, 1, 1, 0.5), 1.0) # shine

static func _flask(img: Image, liquid: Color) -> void:
	if liquid.g > liquid.r: # silverleaf: pale glow
		_glow(img, 32, 40, 22, Color(0.7, 0.9, 0.9, 0.3))
	_rrect(img, 28, 12, 36, 26, 2, Color(0.8, 0.85, 0.9, 0.4)) # neck
	_r(img, 27, 9, 37, 13, Color(0.5, 0.36, 0.2)) # cork
	_r(img, 27, 9, 37, 10, Color(0.62, 0.46, 0.26))
	_ell(img, 32, 40, 14, 14, Color(0.82, 0.86, 0.9, 0.35)) # bulb
	_ell(img, 32, 41, 11, 11, Color(liquid.r, liquid.g, liquid.b, 0.9))
	_ell(img, 28, 36, 3, 4, Color(liquid.r, liquid.g, liquid.b, 1.0).lightened(0.3))
	_ln(img, 23, 32, 25, 34, Color(1, 1, 1, 0.4), 1.0)
	if liquid.g > liquid.r:
		_ell(img, 32, 40, 5, 2, Color(0.55, 0.85, 0.7)) # leaf
		_ell(img, 34, 41, 2, 1, Color(0.7, 1.0, 0.8))
	else:
		_r(img, 29, 36, 35, 38, Color(0.9, 0.88, 0.84)) # label
		_r(img, 31, 34, 33, 40, Color(0.8, 0.08, 0.08))
		_r(img, 28, 36, 36, 38, Color(0.8, 0.08, 0.08))

# ================================================================
# throwables
# ================================================================
static func _frag(img: Image) -> void:
	var olive := Color(0.32, 0.36, 0.22)
	_ell(img, 32, 36, 13, 14, olive)
	_ell(img, 28, 31, 4, 5, olive.lightened(0.2))
	_r(img, 28, 18, 36, 24, olive.darkened(0.15))
	_r(img, 29, 16, 35, 19, Color(0.25, 0.28, 0.18))
	# crosshatch
	for k in 4:
		_ln(img, 21 + k * 6, 26, 25 + k * 6, 48, olive.darkened(0.3), 1.0)
		_ln(img, 21 + k * 6, 48, 25 + k * 6, 26, olive.darkened(0.3), 1.0)
	# spoon lever
	_ln(img, 36, 20, 50, 26, STEEL, 3.0)
	_ell(img, 50, 27, 2, 3, STEEL_HI)
	# pin ring
	_ell_o(img, 24, 18, 4, 4, Color(0.95, 0.8, 0.25))
	_ln(img, 27, 19, 30, 22, Color(0.95, 0.8, 0.25), 1.0)

static func _molotov(img: Image) -> void:
	# bottle
	_rrect(img, 25, 24, 39, 54, 4, Color(0.3, 0.45, 0.25, 0.9))
	_r(img, 26, 25, 38, 26, Color(0.45, 0.62, 0.38, 0.9))
	_r(img, 28, 30, 36, 52, Color(0.2, 0.32, 0.16, 0.95)) # liquid
	_r(img, 28, 30, 30, 52, Color(0.32, 0.48, 0.26, 0.95))
	_r(img, 29, 16, 35, 24, Color(0.42, 0.58, 0.35, 0.85)) # neck
	_ln(img, 31, 18, 33, 28, Color(1, 1, 1, 0.3), 1.0)
	# rag wick
	_ln(img, 32, 17, 31, 8, CREAM, 4.0)
	for k in 3:
		_px(img, 29 + k * 2, 6 + (k % 2), Color(0.85, 0.8, 0.68))
	# flame
	_ell(img, 31, 6, 3, 4, Color(1.0, 0.62, 0.1))
	_ell(img, 31, 6, 1.5, 2, Color(1.0, 0.92, 0.5))

static func _noisemaker(img: Image) -> void:
	_rrect(img, 17, 26, 47, 52, 3, Color(0.62, 0.53, 0.34))
	_r(img, 18, 27, 46, 29, Color(0.75, 0.66, 0.45))
	_r(img, 17, 26, 47, 27, Color(0.75, 0.66, 0.45))
	_ln(img, 44, 22, 54, 10, STEEL, 2.0) # antenna
	_ell(img, 54, 10, 1.5, 1.5, Color(1, 0.2, 0.15)) # red tip
	for cy in 3: # speaker grill
		for cx in 3:
			_ell(img, 25 + cx * 5, 34 + cy * 5, 1.2, 1.2, Color(0.3, 0.24, 0.14))
	_r(img, 38, 32, 45, 44, Color(0.2, 0.18, 0.12)) # screen
	_r(img, 39, 34, 43, 40, Color(0.9, 0.55, 0.1))
	for k in 3:
		_r(img, 39, 34 + k * 3, 41 + k, 35 + k * 3, Color(0.2, 0.18, 0.12))
	_r(img, 20, 47, 44, 50, Color(0.5, 0.42, 0.26)) # base plate

# ================================================================
# materials & tools
# ================================================================
static func _scrap(img: Image) -> void:
	_rrect(img, 26, 32, 52, 52, 2, Color(0.36, 0.35, 0.34))
	_r(img, 27, 33, 51, 34, Color(0.5, 0.48, 0.46))
	_ln(img, 30, 42, 48, 48, Color(0.55, 0.28, 0.12), 3.0) # rust patch
	_rrect(img, 12, 14, 40, 38, 2, Color(0.46, 0.46, 0.45))
	_r(img, 13, 15, 39, 16, Color(0.62, 0.61, 0.58))
	_r(img, 12, 32, 40, 38, Color(0.28, 0.27, 0.27))
	_ln(img, 18, 24, 34, 20, Color(0.6, 0.32, 0.14), 2.0)
	_ell(img, 17, 19, 1.5, 1.5, STEEL_HI) # bolts
	_ell(img, 35, 33, 1.5, 1.5, STEEL_HI)
	_ln(img, 20, 30, 32, 28, STEEL_LO, 1.0)

static func _cloth(img: Image) -> void:
	_rrect(img, 14, 34, 50, 52, 3, Color(0.5, 0.4, 0.3))
	_rrect(img, 17, 24, 47, 40, 3, Color(0.6, 0.5, 0.39))
	_rrect(img, 20, 15, 44, 30, 3, Color(0.68, 0.58, 0.45))
	_ln(img, 20, 22, 44, 22, Color(0.42, 0.34, 0.26)) # fold seams
	_ln(img, 17, 32, 47, 32, Color(0.38, 0.3, 0.23))
	_ln(img, 23, 17, 25, 29, Color(0.42, 0.34, 0.26))
	_r(img, 14, 50, 50, 52, Color(0.3, 0.23, 0.17)) # grounding shadow
	_r(img, 24, 27, 28, 29, Color(0.8, 0.72, 0.6)) # patch
	_r(img, 24, 27, 28, 28, Color(0.9, 0.84, 0.72))

static func _parts(img: Image) -> void:
	# gear
	var cx := 26
	var cy := 38
	_ell(img, cx, cy, 9, 9, STEEL)
	_ell(img, cx, cy, 4, 4, Color(0, 0, 0, 0))
	for k in 8:
		var a := k * TAU / 8.0
		var tx := int(cx + cos(a) * 10.0)
		var ty := int(cy + sin(a) * 10.0)
		_r(img, tx - 1, ty - 1, tx + 1, ty + 1, STEEL_HI)
	_ell(img, cx - 3, cy - 3, 2, 2, Color(0.7, 0.7, 0.72))
	# spring
	for k in 5:
		_ln(img, 42, 22 + k * 6, 52, 25 + k * 6, Color(0.75, 0.76, 0.8), 2.0)
	# firing pin
	_r(img, 40, 48, 52, 52, STEEL_LO)
	_r(img, 41, 49, 51, 51, STEEL)

static func _herb(img: Image) -> void:
	_glow(img, 30, 30, 20, Color(0.7, 0.95, 0.8, 0.3))
	_ln(img, 32, 54, 29, 14, Color(0.35, 0.55, 0.35), 2.0)
	for k in 5:
		var y := 18 + k * 7
		var dir := -1 if k % 2 == 0 else 1
		_ell(img, 29 + dir * 6, y, 5, 2, Color(0.72, 0.95, 0.82))
		_ell(img, 29 + dir * 9, y - 1, 2, 1, Color(0.85, 1.0, 0.9))
	_ell(img, 29, 12, 3, 3, Color(0.85, 1.0, 0.9))
	_px(img, 28, 11, Color(1, 1, 1))

static func _pine(img: Image) -> void:
	_ln(img, 14, 50, 50, 18, Color(0.28, 0.17, 0.08), 4.0) # dark branch
	_ln(img, 14, 50, 50, 18, Color(0.4, 0.26, 0.13), 2.0)
	for k in 5:
		var t := 0.18 + k * 0.15
		var bx := int(lerpf(16.0, 48.0, t))
		var by := int(lerpf(46.0, 20.0, t))
		_px(img, bx - 6, by - 2, Color(0.1, 0.2, 0.1)) # dark base under each cluster
		_ln(img, bx, by, bx - 7, by - 2, Color(0.22, 0.5, 0.22), 2.0)
		_ln(img, bx, by, bx + 3, by + 4, Color(0.3, 0.6, 0.3), 2.0)

static func _jerrycan(img: Image) -> void:
	var red := Color(0.62, 0.15, 0.1)
	_rrect(img, 16, 18, 48, 54, 3, red)
	_r(img, 17, 19, 47, 21, Color(0.78, 0.24, 0.16))
	_r(img, 16, 50, 48, 54, Color(0.42, 0.08, 0.06))
	# X emboss
	_ln(img, 20, 28, 44, 48, red.lightened(0.22), 4.0)
	_ln(img, 20, 48, 44, 28, red.darkened(0.25), 4.0)
	# handle slot
	_rrect(img, 22, 18, 42, 26, 2, Color(0.35, 0.08, 0.06))
	_rrect(img, 24, 20, 40, 24, 2, Color(0.12, 0.05, 0.04))
	# cap + sticker
	_r(img, 41, 14, 47, 19, Color(0.85, 0.75, 0.2))
	_r(img, 42, 15, 46, 18, Color(0.95, 0.85, 0.3))
	_r(img, 20, 33, 26, 38, CREAM)
	_px(img, 22, 35, Color(0.6, 0.5, 0.3))

static func _rod(img: Image) -> void:
	_ln(img, 12, 54, 54, 10, Color(0.5, 0.33, 0.16), 2.0)
	_ln(img, 12, 54, 54, 10, Color(0.65, 0.45, 0.22), 1.0)
	# reel
	_ell(img, 25, 42, 5, 5, Color(0.3, 0.32, 0.36))
	_ell(img, 25, 42, 3, 3, Color(0.5, 0.52, 0.58))
	_ln(img, 25, 42, 30, 38, Color(0.7, 0.72, 0.78), 2.0)
	_ln(img, 21, 45, 17, 49, Color(0.2, 0.2, 0.24), 2.0) # reel foot
	# line + hook
	_ln(img, 54, 10, 50, 40, Color(0.95, 0.95, 0.95), 1.0)
	_ell_o(img, 50, 44, 3, 3, Color(0.95, 0.95, 0.95))
	_ell(img, 50, 47, 3, 1, Color(0, 0, 0, 0))
	_ell(img, 50, 42, 2, 2, Color(0.9, 0.2, 0.15)) # lure

static func _campkit(img: Image) -> void:
	# stones ring
	for k in 6:
		var a := k * TAU / 6.0
		_ell(img, 32 + cos(a) * 16.0, 46 + sin(a) * 6.0, 4, 3, Color(0.48, 0.46, 0.44))
	_ell(img, 32 + cos(0.5) * 16.0 - 1, 45 + sin(0.5) * 6.0 - 1, 1.5, 1, Color(0.62, 0.6, 0.56))
	# logs
	_ln(img, 20, 48, 44, 42, Color(0.42, 0.27, 0.13), 5.0)
	_ln(img, 20, 42, 44, 48, Color(0.5, 0.33, 0.17), 5.0)
	_ell(img, 44, 42, 2, 2, Color(0.66, 0.5, 0.3))
	_ell(img, 20, 48, 2, 2, Color(0.66, 0.5, 0.3))
	# kindling + starter flame silhouette
	_ln(img, 28, 44, 36, 38, Color(0.55, 0.4, 0.2), 2.0)
	_tri(img, Vector2(32, 26), Vector2(36, 40), Vector2(28, 40), Color(0.9, 0.5, 0.1))
	_tri(img, Vector2(32, 31), Vector2(35, 40), Vector2(29, 40), Color(1.0, 0.8, 0.3))

# ================================================================
# valuables
# ================================================================
static func _ring(img: Image) -> void:
	_ell_o(img, 32, 36, 11, 11, Color(1.0, 0.8, 0.28))
	_ell_o(img, 32, 36, 10, 10, Color(1.0, 0.8, 0.28))
	_ell_o(img, 32, 36, 8, 8, Color(0.75, 0.55, 0.15))
	_ln(img, 24, 28, 27, 25, Color(1, 1, 0.9), 2.0) # shine
	_ell(img, 32, 22, 3, 3, Color(0.9, 0.92, 1.0)) # gem
	_tri(img, Vector2(32, 18), Vector2(35, 22), Vector2(32, 25), Color(1, 1, 1))

static func _watch(img: Image) -> void:
	_ell(img, 32, 36, 13, 13, STEEL)
	_ell(img, 32, 36, 11, 11, Color(0.92, 0.88, 0.78))
	_ell(img, 30, 34, 3, 3, Color(1, 1, 0.95)) # face shine
	for k in 4: # ticks
		var a := k * TAU / 4.0
		_px(img, int(32 + cos(a) * 9.0), int(36 + sin(a) * 9.0), Color(0.3, 0.28, 0.24))
	_ln(img, 32, 36, 32, 29, Color(0.15, 0.14, 0.12), 1.0) # minute ~41
	_ln(img, 32, 36, 27, 39, Color(0.15, 0.14, 0.12), 2.0) # hour ~9
	_ell(img, 32, 36, 1, 1, Color(0.4, 0.38, 0.34))
	_r(img, 44, 34, 47, 38, STEEL_HI) # crown
	for k in 5: # chain
		_ell_o(img, 18 + k * 3, 14 - k * 2, 1.5, 1.5, Color(0.8, 0.8, 0.75))

static func _vinyl(img: Image) -> void:
	_ell(img, 32, 34, 16, 16, Color(0.09, 0.09, 0.10))
	_ell_o(img, 32, 34, 13, 13, Color(0.16, 0.16, 0.18))
	_ell_o(img, 32, 34, 10, 10, Color(0.16, 0.16, 0.18))
	_ell(img, 32, 34, 6, 6, Color(0.86, 0.62, 0.2))
	_ell(img, 32, 34, 1.5, 1.5, Color(0.09, 0.09, 0.10))
	_ln(img, 21, 25, 27, 19, Color(1, 1, 1, 0.25), 2.0) # sheen
	_ln(img, 43, 44, 45, 42, Color(1, 1, 1, 0.18), 1.0)
	_ell(img, 30, 32, 1, 1, Color(1, 0.9, 0.6))

static func _crystals(img: Image) -> void:
	_glow(img, 32, 42, 20, Color(0.45, 1.0, 0.55, 0.3))
	var green := Color(0.45, 0.95, 0.5)
	_tri(img, Vector2(32, 8), Vector2(24, 50), Vector2(40, 50), green)
	_tri(img, Vector2(32, 8), Vector2(24, 50), Vector2(29, 50), Color(0.7, 1.0, 0.75))
	_tri(img, Vector2(18, 24), Vector2(12, 50), Vector2(24, 50), green.darkened(0.15))
	_tri(img, Vector2(46, 30), Vector2(41, 50), Vector2(52, 50), green.darkened(0.1))
	_tri(img, Vector2(46, 30), Vector2(41, 50), Vector2(45, 50), Color(0.65, 1.0, 0.7))
	_ln(img, 32, 10, 32, 48, Color(0.8, 1.0, 0.85), 1.0)
	for p in [[28, 20], [36, 30], [30, 40]]:
		_px(img, int(p[0]), int(p[1]), Color(1, 1, 1))

static func _note(img: Image) -> void:
	_r(img, 16, 12, 48, 52, Color(0.88, 0.84, 0.70))
	_r(img, 16, 12, 17, 52, Color(0.78, 0.74, 0.6))
	_r(img, 16, 12, 48, 13, Color(0.94, 0.9, 0.78))
	# folded corner
	_tri(img, Vector2(48, 12), Vector2(48, 22), Vector2(48, 12), Color(0, 0, 0, 0))
	for k in 10:
		_r(img, 38 + k, 12 + k, 39 + k, 13 + k, Color(0.7, 0.66, 0.52))
	_tri(img, Vector2(48, 12), Vector2(38, 22), Vector2(48, 22), Color(0.72, 0.68, 0.55))
	# scribbles — staggered dashes with gaps
	for k in 4:
		var y := 21 + k * 7
		_ln(img, 21, y, 28, y, Color(0.4, 0.36, 0.3))
		_ln(img, 31, y, 39 if k % 2 == 0 else 35, y, Color(0.4, 0.36, 0.3))
	_ln(img, 21, 47, 29, 47, Color(0.4, 0.36, 0.3))
	# stamp — clear of the text block
	_ell_o(img, 42, 44, 5, 4, Color(0.75, 0.2, 0.15))
	_ln(img, 21, 18, 40, 17, Color(0.3, 0.27, 0.22), 2.0) # title line

static func _crate(img: Image) -> void:
	_rrect(img, 12, 18, 52, 50, 2, Color(0.42, 0.32, 0.18))
	_r(img, 13, 19, 51, 21, Color(0.55, 0.43, 0.25))
	_r(img, 13, 44, 51, 49, Color(0.3, 0.22, 0.12))
	_ln(img, 12, 18, 52, 50, Color(0.35, 0.26, 0.14), 3.0)
	_ln(img, 12, 50, 52, 18, Color(0.35, 0.26, 0.14), 3.0)
	_ell(img, 16, 22, 1.5, 1.5, STEEL_HI)
	_ell(img, 48, 46, 1.5, 1.5, STEEL_HI)

# ================================================================
# weapons / melee / armor (silhouettes with tone + accents)
# ================================================================
static func _weapon(img: Image, id: String) -> void:
	match id:
		"pistol", "revolver":
			_r(img, 14, 22, 46, 30, Color(0.38, 0.39, 0.43))
			_r(img, 14, 22, 46, 24, Color(0.55, 0.56, 0.6))
			_rrect(img, 16, 30, 28, 46, 2, Color(0.3, 0.2, 0.1))
			_r(img, 18, 32, 20, 44, Color(0.42, 0.29, 0.15))
			_r(img, 20, 26, 44, 28, Color(0.2, 0.2, 0.24))
			if id == "revolver":
				_ell(img, 22, 26, 5, 5, Color(0.25, 0.25, 0.3))
				_ell(img, 22, 26, 2, 2, Color(0.45, 0.46, 0.5))
			else:
				_r(img, 32, 30, 40, 42, Color(0.2, 0.2, 0.24))
		"smg":
			_r(img, 8, 24, 52, 32, Color(0.36, 0.37, 0.41))
			_r(img, 8, 24, 52, 26, Color(0.5, 0.51, 0.55))
			_r(img, 44, 20, 48, 38, Color(0.25, 0.25, 0.29))
			_rrect(img, 18, 32, 28, 48, 2, Color(0.3, 0.2, 0.1))
			_r(img, 28, 32, 36, 46, Color(0.22, 0.22, 0.26))
			_r(img, 24, 32, 27, 44, Color(0.3, 0.3, 0.34))
		"shotgun":
			_r(img, 4, 24, 42, 30, Color(0.3, 0.31, 0.34))
			_r(img, 4, 24, 42, 25, Color(0.45, 0.46, 0.5))
			_rrect(img, 14, 30, 44, 46, 3, Color(0.35, 0.22, 0.1))
			_r(img, 42, 26, 58, 32, Color(0.3, 0.31, 0.34))
			_r(img, 14, 28, 18, 46, Color(0.42, 0.27, 0.13))
			_r(img, 44, 30, 46, 44, Color(0.26, 0.27, 0.3))
		"sniper", "dmr":
			_r(img, 2, 26, 56, 32, Color(0.36, 0.37, 0.41))
			_r(img, 2, 26, 56, 27, Color(0.5, 0.51, 0.55))
			_rrect(img, 4, 32, 22, 44, 2, Color(0.32, 0.2, 0.1))
			_rrect(img, 20, 18, 34, 26, 2, Color(0.2, 0.2, 0.24))
			_ell_o(img, 27, 22, 5, 3, Color(0.5, 0.7, 0.8))
			_r(img, 30, 32, 40, 40, Color(0.26, 0.27, 0.3))
		"lmg":
			_r(img, 2, 24, 58, 32, Color(0.32, 0.33, 0.36))
			_r(img, 2, 24, 58, 25, Color(0.44, 0.45, 0.5))
			_rrect(img, 6, 32, 24, 46, 2, Color(0.3, 0.2, 0.1))
			_ell(img, 34, 38, 9, 8, Color(0.25, 0.26, 0.3)) # drum
			_ell(img, 34, 36, 5, 4, Color(0.4, 0.41, 0.46))
			_r(img, 26, 18, 30, 24, Color(0.25, 0.26, 0.3))
		"crossbow":
			_ln(img, 8, 34, 52, 30, WOOD, 4.0)
			_ln(img, 50, 30, 56, 24, Color(0.55, 0.56, 0.6), 2.0)
			_ln(img, 50, 8, 50, 50, Color(0.6, 0.6, 0.65), 2.0) # bow arms
			_ln(img, 50, 8, 18, 32, Color(0.85, 0.85, 0.8), 1.0) # string
			_ln(img, 50, 50, 18, 33, Color(0.85, 0.85, 0.8), 1.0)
			_r(img, 44, 30, 50, 36, Color(0.35, 0.36, 0.4))
		_:
			_r(img, 6, 26, 58, 34, Color(0.36, 0.37, 0.41))

static func _melee_w(img: Image, id: String) -> void:
	match id:
		"knife", "machete":
			var head := Color(0.62, 0.64, 0.7) if id == "knife" else Color(0.7, 0.72, 0.78)
			_ln(img, 12, 52, 34, 18, Color(0.35, 0.22, 0.1), 4.0) # grip
			_ln(img, 32, 20, 52, 10, head, 4.0)
			_ln(img, 32, 18, 50, 8, head.lightened(0.25), 1.0)
			_r(img, 28, 20, 34, 26, Color(0.3, 0.3, 0.34))
		"axe":
			_ln(img, 14, 54, 44, 14, Color(0.4, 0.26, 0.12), 4.0)
			_tri(img, Vector2(40, 18), Vector2(54, 8), Vector2(50, 26), Color(0.72, 0.18, 0.12))
			_tri(img, Vector2(38, 24), Vector2(46, 14), Vector2(44, 30), Color(0.8, 0.3, 0.2))
			_r(img, 38, 16, 42, 30, Color(0.4, 0.4, 0.44))
		"sledge":
			_ln(img, 12, 54, 42, 16, Color(0.4, 0.26, 0.12), 4.0)
			_rrect(img, 34, 8, 54, 22, 2, Color(0.5, 0.51, 0.55))
			_r(img, 35, 9, 53, 11, Color(0.65, 0.66, 0.7))
			_r(img, 34, 19, 54, 22, Color(0.3, 0.3, 0.34))
		"bat":
			_ln(img, 12, 54, 48, 12, Color(0.5, 0.34, 0.16), 5.0)
			_ln(img, 44, 15, 48, 11, Color(0.42, 0.27, 0.12), 7.0)
			_ln(img, 42, 18, 46, 14, Color(0.6, 0.42, 0.2), 1.0)
			for k in 2:
				_ln(img, 20 + k * 3, 46 - k * 3, 24 + k * 3, 44 - k * 3, Color(0.7, 0.7, 0.74), 1.0)
		"wrench":
			_ln(img, 12, 52, 46, 16, STEEL, 4.0)
			_ell_o(img, 48, 14, 6, 6, STEEL_HI)
			_r(img, 45, 8, 52, 12, Color(0, 0, 0, 0))
			_ell_o(img, 15, 50, 5, 5, STEEL)
			_ln(img, 16, 22, 20, 18, Color(0.7, 0.7, 0.74), 1.0)
		_:
			_ln(img, 12, 52, 50, 12, WOOD, 4.0)

static func _armor_w(img: Image, id: String) -> void:
	var slot: String = ItemDB.ARMOR.get(id, {}).get("slot", "body")
	match id:
		"gas_mask":
			_ell(img, 32, 32, 13, 14, Color(0.35, 0.38, 0.33))
			_ell(img, 32, 26, 13, 7, Color(0.28, 0.3, 0.26))
			_ell(img, 26, 28, 4, 3, Color(0.6, 0.75, 0.7)) # lenses
			_ell(img, 38, 28, 4, 3, Color(0.6, 0.75, 0.7))
			_ell(img, 26, 28, 1.5, 1.5, Color(0.2, 0.25, 0.3))
			_ell(img, 38, 28, 1.5, 1.5, Color(0.2, 0.25, 0.3))
			_ell(img, 32, 40, 4, 5, Color(0.25, 0.27, 0.23)) # filter
			_ell(img, 32, 39, 2, 2, Color(0.45, 0.47, 0.42))
			_ln(img, 20, 40, 12, 46, Color(0.28, 0.3, 0.26), 2.0) # straps
			_ln(img, 44, 40, 52, 46, Color(0.28, 0.3, 0.26), 2.0)
		"beanie":
			_ell(img, 32, 34, 14, 12, Color(0.45, 0.32, 0.2))
			_r(img, 18, 34, 46, 42, Color(0.45, 0.32, 0.2))
			_r(img, 18, 38, 46, 42, Color(0.55, 0.42, 0.28))
			_r(img, 18, 34, 46, 36, Color(0.58, 0.45, 0.3))
			_r(img, 30, 18, 34, 24, Color(0.55, 0.42, 0.28)) # fold knob
		"hood":
			_tri(img, Vector2(18, 48), Vector2(32, 10), Vector2(46, 48), Color(0.25, 0.22, 0.18))
			_ell(img, 32, 36, 9, 10, Color(0.05, 0.04, 0.03))
			_tri(img, Vector2(24, 20), Vector2(32, 12), Vector2(40, 20), Color(0.32, 0.28, 0.22))
		_:
			match slot:
				"head":
					_ell(img, 32, 30, 13, 12, Color(0.4, 0.42, 0.38))
					_r(img, 19, 30, 45, 46, Color(0.36, 0.38, 0.34))
					_r(img, 22, 34, 28, 44, Color(0.15, 0.16, 0.14)) # visor slit
					_r(img, 36, 34, 42, 44, Color(0.15, 0.16, 0.14))
					_r(img, 19, 30, 45, 32, Color(0.55, 0.57, 0.5))
				"back":
					_rrect(img, 16, 16, 48, 52, 6, Color(0.36, 0.33, 0.24))
					_rrect(img, 20, 20, 44, 40, 4, Color(0.42, 0.39, 0.28))
					_r(img, 20, 20, 44, 22, Color(0.5, 0.47, 0.34)) # flap
					_r(img, 24, 24, 30, 36, Color(0.3, 0.27, 0.2))
					_ln(img, 16, 24, 48, 24, Color(0.25, 0.23, 0.16), 2.0)
					_r(img, 22, 44, 26, 52, Color(0.3, 0.27, 0.2)) # pocket
					_r(img, 36, 44, 42, 52, Color(0.3, 0.27, 0.2))
				_:
					_rrect(img, 18, 12, 46, 34, 4, Color(0.38, 0.4, 0.36))
					_r(img, 14, 14, 20, 34, Color(0.32, 0.34, 0.3))
					_r(img, 44, 14, 50, 34, Color(0.32, 0.34, 0.3))
					_r(img, 20, 14, 44, 16, Color(0.52, 0.54, 0.48))
					_ln(img, 30, 12, 30, 34, Color(0.28, 0.3, 0.26), 2.0)
					_rrect(img, 22, 38, 42, 54, 3, Color(0.34, 0.36, 0.32))
					_ln(img, 24, 40, 40, 40, Color(0.45, 0.47, 0.42), 1.0)

static func _ammo(img: Image, id: String) -> void:
	var brass := Color(0.85, 0.68, 0.25)
	var tip := Color(0.45, 0.45, 0.5)
	match id:
		"ammo_12g":
			for k in 3: # red shells, brass base
				var x := 18 + k * 11
				_r(img, x, 14, x + 7, 40, Color(0.75, 0.16, 0.1))
				_r(img, x, 14, x + 7, 18, Color(0.88, 0.3, 0.2))
				_r(img, x - 1, 40, x + 8, 50, brass)
				_r(img, x - 1, 40, x + 8, 42, brass.lightened(0.25))
				_r(img, x + 1, 20, x + 2, 38, Color(0.9, 0.45, 0.35))
		"bolts":
			for k in 2:
				var y := 20 + k * 17
				_ln(img, 10, y + 6, 50, y - 4, Color(0.62, 0.44, 0.22), 2.0) # shaft
				_ln(img, 10, y + 6, 50, y - 4, Color(0.75, 0.56, 0.3), 1.0) # shaft core
				_tri(img, Vector2(50, y - 4), Vector2(58, y - 7), Vector2(52, y + 1), STEEL_HI) # head
				_ln(img, 12, y + 5, 16, y - 2, Color(0.8, 0.7, 0.5), 2.0) # fletch
				_ln(img, 16, y + 5, 20, y - 2, Color(0.8, 0.7, 0.5), 2.0)
		"ammo_44":
			for k in 3:
				var x := 20 + k * 10
				_r(img, x, 18, x + 6, 44, brass)
				_r(img, x, 12, x + 6, 18, tip)
				_r(img, x, 12, x + 6, 13, Color(0.6, 0.6, 0.66))
				_r(img, x + 1, 20, x + 2, 42, brass.lightened(0.3))
				_r(img, x - 1, 44, x + 7, 46, Color(0.6, 0.45, 0.15))
		"ammo_308":
			for k in 2:
				var x := 20 + k * 16
				_r(img, x, 16, x + 7, 46, brass)
				_r(img, x, 10, x + 7, 16, tip)
				_r(img, x + 1, 18, x + 2, 44, brass.lightened(0.3))
				_r(img, x - 1, 46, x + 8, 48, Color(0.6, 0.45, 0.15))
				_ln(img, x + 3, 12, x + 3, 15, Color(0.6, 0.6, 0.66), 1.0)
		_:
			for k in 4:
				var x := 16 + k * 9
				_r(img, x, 20, x + 5, 44, brass)
				_r(img, x, 15, x + 5, 20, tip)
				_r(img, x + 1, 22, x + 2, 42, brass.lightened(0.3))
				_r(img, x - 1, 44, x + 6, 45, Color(0.6, 0.45, 0.15))

static func _pillbottle(img: Image) -> void:
	_rrect(img, 22, 20, 42, 52, 3, Color(0.75, 0.75, 0.78))
	_r(img, 21, 13, 43, 20, Color(0.9, 0.9, 0.92))
	_r(img, 23, 30, 41, 42, CREAM)
	_r(img, 28, 34, 36, 38, Color(0.85, 0.15, 0.12))

# ================================================================
# HUD status glyphs (20x20)
# ================================================================
static func _status_paint(img: Image, name: String) -> void:
	match name:
		"food": # drumstick
			_ell(img, 9, 8, 5, 4, Color(0.72, 0.4, 0.18))
			_ell(img, 8, 7, 2, 1.5, Color(0.9, 0.6, 0.3))
			_ln(img, 12, 11, 16, 15, Color(0.92, 0.9, 0.85), 2.0)
			_ell(img, 16, 15, 1.5, 1.5, Color(0.95, 0.94, 0.9))
		"water":
			_tri(img, Vector2(10, 2), Vector2(14, 9), Vector2(6, 9), Color(0.4, 0.68, 0.9))
			_ell(img, 10, 12, 5, 5, Color(0.4, 0.68, 0.9))
			_ell(img, 10, 13, 3, 3, Color(0.6, 0.82, 0.95))
			_px(img, 8, 10, Color(0.85, 0.95, 1.0))
		"blood":
			_tri(img, Vector2(10, 2), Vector2(14, 9), Vector2(6, 9), Color(0.7, 0.08, 0.1))
			_ell(img, 10, 12, 5, 5, Color(0.7, 0.08, 0.1))
			_ell(img, 10, 13, 2.5, 2.5, Color(0.88, 0.15, 0.15))
		"temp":
			_r(img, 8, 3, 11, 13, Color(0.85, 0.85, 0.9))
			_ell(img, 10, 15, 4, 4, Color(0.9, 0.2, 0.15))
			_r(img, 9, 9, 10, 13, Color(0.9, 0.2, 0.15))
			_px(img, 13, 5, Color(0.4, 0.4, 0.45))
			_px(img, 13, 8, Color(0.4, 0.4, 0.45))
		"weight":
			_rrect(img, 4, 6, 16, 18, 3, Color(0.55, 0.42, 0.25))
			_r(img, 4, 6, 16, 8, Color(0.68, 0.55, 0.34))
			_r(img, 6, 10, 9, 15, Color(0.45, 0.34, 0.2))
			_r(img, 11, 10, 14, 15, Color(0.45, 0.34, 0.2))
			_r(img, 2, 8, 4, 14, Color(0.4, 0.3, 0.18))
			_r(img, 16, 8, 18, 14, Color(0.4, 0.3, 0.18))
		"sick":
			_ell(img, 10, 8, 7, 6, Color(0.92, 0.92, 0.88))
			_r(img, 5, 12, 15, 16, Color(0.92, 0.92, 0.88))
			_ell(img, 7, 8, 2, 2, Color(0.1, 0.1, 0.12))
			_ell(img, 13, 8, 2, 2, Color(0.1, 0.1, 0.12))
			_r(img, 8, 12, 9, 15, Color(0.1, 0.1, 0.12))
			_r(img, 11, 12, 12, 15, Color(0.1, 0.1, 0.12))
		"curse":
			_ell_o(img, 10, 10, 8, 5, Color(0.9, 0.3, 0.5))
			_ell(img, 10, 10, 4, 4, Color(0.5, 0.9, 0.4))
			_ell(img, 10, 10, 1.5, 1.5, Color(0.05, 0.1, 0.05))
		"wet":
			for k in 3:
				var x := 4.0 + k * 6.0
				var y := 6.0 + (k % 2) * 4.0
				_tri(img, Vector2(x, y), Vector2(x + 2.5, y + 4), Vector2(x - 2.5, y + 4), Color(0.4, 0.68, 0.9))
				_ell(img, x, y + 5.5, 2.5, 2.5, Color(0.4, 0.68, 0.9))
		"tough":
			_tri(img, Vector2(10, 2), Vector2(17, 5), Vector2(16, 12), Color(0.85, 0.7, 0.2))
			_tri(img, Vector2(10, 2), Vector2(16, 12), Vector2(10, 18), Color(0.85, 0.7, 0.2))
			_tri(img, Vector2(10, 2), Vector2(10, 18), Vector2(4, 12), Color(0.85, 0.7, 0.2))
			_tri(img, Vector2(10, 2), Vector2(4, 12), Vector2(3, 5), Color(0.85, 0.7, 0.2))
			_r(img, 8, 7, 12, 9, Color(0.95, 0.9, 0.5))
			_r(img, 9, 5, 11, 12, Color(0.95, 0.9, 0.5))
