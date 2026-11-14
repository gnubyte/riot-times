class_name UIArt
extends RefCounted
# Procedural 2D art for menus/loading/HUD chrome — painted into Images at startup.
# Everything shares the wasteland palette below. Backdrops: dusk sky, skyline
# silhouette + lit windows, near-ground foreground. Chrome: riveted plates,
# beveled buttons, inset wells, hazard strip.

const PAL := {
	"ink": Color(0.04, 0.03, 0.028),
	"ink2": Color(0.051, 0.059, 0.05),
	"panel": Color(0.089, 0.103, 0.086),
	"panel_hi": Color(0.174, 0.2, 0.168),
	"panel_lo": Color(0.045, 0.037, 0.032),
	"steel": Color(0.304, 0.35, 0.294),
	"steel_hi": Color(0.53, 0.51, 0.47),
	"steel_lo": Color(0.17, 0.17, 0.18),
	"rust": Color(0.55, 0.27, 0.11),
	"rust_hi": Color(0.76, 0.42, 0.17),
	"amber": Color(0.555, 0.951, 0.224),
	"gold": Color(0.636, 0.97, 0.35),
	"cream": Color(0.93, 0.88, 0.77),
	"text": Color(0.88, 0.85, 0.78),
	"danger": Color(0.92, 0.26, 0.14),
	"toxic": Color(0.65, 0.95, 0.3),
	"rad": Color(0.45, 1.0, 0.55),
	"water": Color(0.4, 0.68, 0.9),
	"blood": Color(0.66, 0.08, 0.1),
}

const BAYER := [0.0, 0.5, 0.125, 0.625, 0.75, 0.25, 0.875, 0.375, 0.1875, 0.6875, 0.0625, 0.5625, 0.9375, 0.4375, 0.8125, 0.3125]

static var _cache := {}

static func _cached(key: String, paint: Callable) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(paint.call())
	return _cache[key]

# ---------------- dusk sky ----------------
# Banded sunset with ordered-dither grain, sun with halo + retro slit lines,
# horizontal cloud banks lit from below, stars up top, dust haze at the bottom.
static func sky_texture(w := 960, h := 540) -> Texture2D:
	return _cached("sky%d,%d" % [w, h], func() -> Image: return _paint_sky(w, h))

static func _paint_sky(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var top := Color(0.025, 0.04, 0.03)
	var upper := Color(0.09, 0.15, 0.08)
	var mid := Color(0.34, 0.45, 0.15)
	var low := Color(0.7, 0.78, 0.28)
	var haze := Color(0.26, 0.32, 0.12)
	var sun := Vector2(w * 0.5, h * 0.66)
	var sun_r := h * 0.13
	# cloud banks: [y fraction, thickness px, x freq, phase, darkness, gate freq, gate phase]
	var banks := [
		[0.18, 14.0, 0.011, 1.7, 0.35, 0.004, 0.8], [0.27, 20.0, 0.007, 4.1, 0.45, 0.003, 3.1],
		[0.36, 12.0, 0.016, 0.4, 0.3, 0.005, 5.0], [0.47, 26.0, 0.006, 2.6, 0.5, 0.0025, 1.4], [0.57, 10.0, 0.013, 5.2, 0.25, 0.006, 2.2],
	]
	for y in h:
		var t := float(y) / float(h)
		var c: Color
		if t < 0.34:
			c = top.lerp(upper, t / 0.34)
		elif t < 0.56:
			c = upper.lerp(mid, (t - 0.34) / 0.22)
		elif t < 0.70:
			c = mid.lerp(low, (t - 0.56) / 0.14)
		else:
			c = low.lerp(haze, clampf((t - 0.70) / 0.30, 0.0, 1.0))
		for x in w:
			var px := c
			# cloud banks: darker mauve cores with amber-lit lower edge,
			# broken into patches by a gate sine so they aren't endless ribbons
			for b0 in banks:
				var by_f: float = float(h) * float(b0[0]) + sin(x * float(b0[2]) + float(b0[3])) * 26.0 + sin(x * float(b0[2]) * 2.7) * 9.0
				var thick: float = float(b0[1])
				var dark: float = float(b0[4]) * pow(clampf(sin(x * float(b0[5]) + float(b0[6])), 0.0, 1.0), 1.5)
				var d := absf(float(y) - by_f)
				if d < thick and dark > 0.02:
					var k := 1.0 - d / thick
					var shade := Color(0.05, 0.08, 0.05).lerp(Color(0.75, 0.88, 0.32), clampf((float(y) - by_f) / thick + 0.55, 0.0, 1.0) * 0.6)
					px = px.lerp(shade, k * dark)
			# sun halo + disc
			var sd := Vector2(x - sun.x, (y - sun.y) * 1.15).length()
			if sd < sun_r:
				px = Color(0.93, 1.0, 0.72)
			elif sd < sun_r * 2.6:
				var f := pow(1.0 - (sd - sun_r) / (sun_r * 1.6), 2.4) * 0.55
				px = px.lerp(Color(0.78, 0.95, 0.38), f)
			# retro slit lines through the sun disc: gaps widen below center
			var rel_y := float(y) - sun.y
			var slit_space := 9.0 + maxf(0.0, rel_y) * 0.4
			if sd < sun_r * 1.15 and rel_y > -sun_r and rel_y < sun_r and fmod(rel_y + 60.0, slit_space) < 3.5 and sd < sun_r * 1.02:
				px *= Color(0.5, 0.6, 0.4)
			# ordered dither grain
			var dth: float = (float(BAYER[(y & 3) * 4 + (x & 3)]) - 0.47) * 0.028
			px = Color(clampf(px.r + dth, 0, 1), clampf(px.g + dth, 0, 1), clampf(px.b + dth, 0, 1))
			# horizon light pool under the sun
			var hd := Vector2((x - sun.x) * 1.6, y - h * 1.02).length() / (h * 0.62)
			if hd < 1.0:
				px = px.lerp(Color(0.75, 0.9, 0.3), pow(1.0 - hd, 2.0) * 0.22)
			img.set_pixel(x, y, px)
	# stars in the dark band
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 150:
		var sx := rng.randi_range(0, w - 1)
		var sy := rng.randi_range(0, int(h * 0.24))
		var b := rng.randf_range(0.25, 1.0)
		var c2 := Color(0.85 + b * 0.15, 0.83 + b * 0.13, 0.78 + b * 0.2)
		img.set_pixel(sx, sy, c2)
		if rng.randf() < 0.06: # sparkles
			img.set_pixel(sx - 1, sy, Color(0.7, 0.66, 0.62))
			img.set_pixel(sx + 1, sy, Color(0.7, 0.66, 0.62))
			img.set_pixel(sx, sy - 1, Color(0.7, 0.66, 0.62))
			img.set_pixel(sx, sy + 1, Color(0.7, 0.66, 0.62))
	return img

# ---------------- skyline ----------------
# Deterministic building layout shared by the silhouette and its lit windows.
static func _skyline_rects(w: int, h: int, variant: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4211 + variant * 97
	var out := []
	var x := 0
	var base := h - 4
	while x < w:
		var bw := rng.randi_range(int(w * 0.025), int(w * 0.065))
		var bh := rng.randi_range(int(h * 0.22), int(h * 0.85))
		out.append({"x": x, "w": bw, "top": base - bh, "base": base,
			"style": rng.randi_range(0, 4), "antenna": rng.randf() < 0.22,
			"beacon": rng.randf() < 0.5})
		x += bw + rng.randi_range(2, int(w * 0.018))
	return out

# Black silhouette skyline with broken tops, antennas, bridge, dead trees.
static func skyline_texture(w := 960, h := 240, variant := 0) -> Texture2D:
	return _cached("sky%d,%d,%d" % [w, h, variant], func() -> Image: return _paint_skyline(w, h, variant))

static func _paint_skyline(w: int, h: int, variant: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.065, 0.048, 0.04, 1.0)
	var roof := Color(0.105, 0.121, 0.102, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 + variant
	var rects := _skyline_rects(w, h, variant)
	for r0 in rects:
		var rx: int = int(r0.x)
		var rw: int = int(r0.w)
		var rtop: int = int(r0.top)
		var rbase: int = int(r0.base)
		for bx in range(rx, mini(w, rx + rw)):
			var top: int = rtop
			match int(r0.style):
				1: top = rtop + (0 if (bx % 8) < 4 else 13)
				2: top = rtop + abs((bx - rx) % 18 - 9)
				3: top = rtop if (bx % 13) > 2 else rtop + 24
				4: top = rtop if (bx % 29) < 3 else rtop + 6
			for y in range(clampi(top, 0, h), rbase):
				if rng.randf() < 0.985:
					img.set_pixel(bx, y, ink)
			img.set_pixel(bx, clampi(top, 0, h - 1), roof) # roofline catch-light
		if r0.antenna:
			var ax: int = clampi(rx + rw / 2, 0, w - 1)
			for y in range(maxi(0, rtop - 16), rtop):
				img.set_pixel(ax, y, ink)
	# bridge spanning center-right
	var deck := h - 4 - int(h * 0.26)
	for bx in range(int(w * 0.40), int(w * 0.80)):
		for y in range(deck, deck + 9):
			img.set_pixel(bx, y, ink)
		if bx % 90 < 16:
			for y in range(deck, h - 4):
				img.set_pixel(bx, y, ink)
	for bx in range(int(w * 0.44), int(w * 0.76)):
		var t := float(bx - int(w * 0.44)) / float(int(w * 0.76) - int(w * 0.44))
		var ay := deck + int(sin(t * PI) * h * 0.17)
		img.set_pixel(bx, ay, ink)
		img.set_pixel(bx, ay + 1, ink)
	# dead trees
	for i in 4:
		var tx := rng.randi_range(20, w - 20)
		var th := rng.randi_range(int(h * 0.2), int(h * 0.4))
		for y in range(h - 4 - th, h - 4):
			img.set_pixel(tx, y, ink)
			if rng.randf() < 0.3:
				img.set_pixel(tx + 1, y, ink)
		for b in 5:
			var by := h - 4 - th + rng.randi_range(0, int(th * 0.5))
			var bl := rng.randi_range(8, 34)
			var dir := 1 if b % 2 == 0 else -1
			for s in bl:
				img.set_pixel(clampi(tx + dir * s, 0, w - 1), clampi(by - s / 3 + rng.randi_range(-2, 2), 0, h - 1), ink)
	# water tower on left
	var wx := int(w * 0.12)
	for y in range(h - 4 - int(h * 0.5), h - 4):
		img.set_pixel(wx, y, ink); img.set_pixel(wx + 2, y, ink)
		img.set_pixel(wx + 26, y, ink); img.set_pixel(wx + 28, y, ink)
	for yy in range(h - 4 - int(h * 0.66), h - 4 - int(h * 0.5)):
		for xx in range(wx - 6, wx + 34):
			img.set_pixel(xx, yy, ink)
	return img

# Sparse lit windows matching the skyline layout (same seed) — overlay layer
# whose alpha/energy can be animated at runtime for flicker.
static func skyline_lights_texture(w := 960, h := 240, variant := 0) -> Texture2D:
	return _cached("skyli%d,%d,%d" % [w, h, variant], func() -> Image: return _paint_lights(w, h, variant))

static func _paint_lights(w: int, h: int, variant: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + variant
	for r0 in _skyline_rects(w, h, variant):
		var cx: int = int(r0.x) + int(r0.w) / 2
		for wy in range(int(r0.top) + 5, int(r0.base) - 5, 9):
			for wx in range(int(r0.x) + 2, mini(w, int(r0.x) + int(r0.w) - 3), 7):
				if rng.randf() < 0.055:
					var warm := rng.randf()
					var col := Color(0.533, 0.97, 0.224) if warm < 0.75 else Color(0.75, 0.85, 1.0)
					var a := rng.randf_range(0.55, 0.95)
					col.a = a
					img.set_pixel(wx, wy, col)
					col.a = a * 0.5
					img.set_pixel(wx, wy + 1, col)
		if r0.antenna and r0.beacon:
			var col2 := Color(1.0, 0.22, 0.12, 0.95)
			img.set_pixel(cx, maxi(0, int(r0.top) - 16), col2)
			img.set_pixel(cx, maxi(0, int(r0.top) - 17), col2)
	return img

# Near-ground foreground: broken fence, dry grass, power pole, rubble.
static func foreground_texture(w := 960, h := 170) -> Texture2D:
	return _cached("fg%d,%d" % [w, h], func() -> Image: return _paint_foreground(w, h))

static func _paint_foreground(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.045, 0.04, 0.032, 1.0)
	var olive := Color(0.059, 0.068, 0.057, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var ground := h - 10
	# uneven ground band
	for x in w:
		var gy := ground + int(sin(x * 0.05) * 3.0 + sin(x * 0.013) * 4.0)
		for y in range(gy, h):
			img.set_pixel(x, y, ink)
	# fence: posts + two sagging wires
	var px2 := 30
	while px2 < w:
		var ph := rng.randi_range(30, 52)
		for y in range(h - 14 - ph, h - 14):
			img.set_pixel(px2, y, ink)
			img.set_pixel(px2 + 1, y, ink)
		if rng.randf() < 0.35: # broken post
			for y in range(h - 14 - ph / 2, h - 14):
				img.set_pixel(px2, y, Color(0, 0, 0, 0))
		px2 += rng.randi_range(90, 150)
	for wire in 2:
		var wy0 := h - 14 - 44 + wire * 12
		for x in w:
			var sag := sin(float(x) / float(w) * PI) * 9.0
			var y := int(wy0 + sag)
			img.set_pixel(x, clampi(y, 0, h - 1), ink)
	# power pole right-of-center with sagging lines
	var pole := int(w * 0.74)
	for y in range(20, h):
		img.set_pixel(pole, y, ink); img.set_pixel(pole + 1, y, ink); img.set_pixel(pole + 2, y, ink)
	for xx in range(pole - 26, pole + 30):
		img.set_pixel(xx, 24, ink); img.set_pixel(xx, 25, ink)
		img.set_pixel(xx, 32, ink); img.set_pixel(xx, 33, ink)
	for anchor in [[pole - 24, 25], [pole + 28, 25], [pole - 24, 33], [pole + 28, 33]]:
		var ax: int = anchor[0]
		var ay: int = anchor[1]
		var dir := -1 if ax < pole else 1
		var x0 := ax
		while x0 > 0 and x0 < w:
			var span := absf(x0 - ax)
			var y := int(ay + span * span * 0.00016)
			if y > h - 12:
				break
			img.set_pixel(x0, y, ink)
			x0 += dir
	# dry grass tufts
	for i in 46:
		var gx := rng.randi_range(4, w - 4)
		var gh := rng.randi_range(7, 17)
		var n := rng.randi_range(3, 6)
		for b in n:
			var dx := rng.randi_range(-4, 4)
			var lean := dx * gh / 6
			for s in gh:
				var yy := h - 12 - s
				var xx := clampi(gx + dx + int(lean * s / gh), 0, w - 1)
				if yy >= 0:
					img.set_pixel(xx, yy, olive)
	# rubble mounds with rebar
	for i in 7:
		var mx := rng.randi_range(10, w - 10)
		var mw := rng.randi_range(16, 40)
		var mh := rng.randi_range(6, 12)
		for x in range(mx - mw / 2, mx + mw / 2):
			var k := 1.0 - absf(float(x - mx)) / (mw / 2.0)
			for y in range(h - 12 - int(mh * k), h - 12):
				img.set_pixel(clampi(x, 0, w - 1), y, ink)
		for r2 in rng.randi_range(1, 3): # rebar sticks
			var rx := mx + rng.randi_range(-6, 6)
			for y in range(h - 12 - mh - rng.randi_range(4, 9), h - 12 - mh):
				img.set_pixel(clampi(rx, 0, w - 1), y, olive)
	return img

# ---------------- overlays ----------------
# Grain / dust overlay with alpha.
static func grain_texture(alpha := 0.09) -> Texture2D:
	var key := "grain%0.2f" % alpha
	return _cached(key, func() -> Image:
		var s := 256
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		for y in s:
			for x in s:
				var v := randf()
				var a := alpha if v < 0.5 else alpha * v * 0.4
				img.set_pixel(x, y, Color(1, 1, 1, a))
		return img)

# Subtle CRT scanlines tile.
static func scanline_texture(alpha := 0.05) -> Texture2D:
	var key := "scan%0.2f" % alpha
	return _cached(key, func() -> Image:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		for y in 4:
			for x in 4:
				var a := alpha if y % 2 == 0 else 0.0
				img.set_pixel(x, y, Color(0, 0, 0, a))
		return img)

# Vignette (dark edges), transparent center.
static func vignette_texture(w := 960, h := 540) -> Texture2D:
	return _cached("vig%d,%d" % [w, h], func() -> Image:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var center := Vector2(w * 0.5, h * 0.5)
		var maxd := center.length()
		for y in h:
			for x in w:
				var d := Vector2(x, y).distance_to(center) / maxd
				var a := pow(clampf(d, 0.0, 1.0), 2.3) * 0.74
				img.set_pixel(x, y, Color(0.02, 0.01, 0.01, a))
		return img)

# ---------------- emblem ----------------
# Rad-emblem drawn into a texture (circle + trefoil).
static func emblem_texture(size := 256, col := Color(0.555, 0.921, 0.175)) -> Texture2D:
	var key := "emb%d,%0.2f,%0.2f,%0.2f" % [size, col.r8, col.g8, col.b8]
	return _cached(key, func() -> Image: return _paint_emblem(size, col))

static func _paint_emblem(size: int, col: Color) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(size, size) * 0.5
	var R := size * 0.46
	for y in size:
		for x in size:
			var p := Vector2(x, y) - c
			var d := p.length() / R
			var ang := wrapf(p.angle(), 0, TAU)
			var px := Color(0, 0, 0, 0)
			if absf(d - 0.92) < 0.05:
				px = Color(col.r, col.g, col.b, 0.95)
			elif d < 0.42:
				if d > 0.3:
					px = Color(col.r, col.g, col.b, 0.95)
			elif d < 0.8:
				var rel := fposmod(ang - PI / 6.0, TAU * 2.0 / 3.0)
				if rel < PI * 2.0 / 3.0 * 0.58:
					px = Color(col.r, col.g, col.b, 0.9)
			img.set_pixel(x, y, px)
	return img

# Soft white radial glow — tint via modulate (item rarity glows, auras).
static func glow_texture(size := 128) -> Texture2D:
	return _cached("glow%d" % size, func() -> Image:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var c := Vector2(size, size) * 0.5
		for y in size:
			for x in size:
				var d := Vector2(x - c.x, y - c.y).length() / (size * 0.5)
				if d < 1.0:
					img.set_pixel(x, y, Color(1, 1, 1, pow(1.0 - d, 2.2) * 0.85))
		return img)

# Toothed gear ring around the emblem (loading spinner).
static func emblem_ring_texture(size := 256, col := Color(0.8, 0.6, 0.22)) -> Texture2D:
	var key := "embr%d,%0.2f,%0.2f,%0.2f" % [size, col.r8, col.g8, col.b8]
	return _cached(key, func() -> Image:
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var c := Vector2(size, size) * 0.5
		var R := size * 0.5 - 2.0
		for y in size:
			for x in size:
				var p := Vector2(x + 0.5, y + 0.5) - c
				var d := p.length()
				var ang := p.angle()
				if d > R - 3.5 and d < R:
					var tooth := fposmod(ang, TAU / 14.0) / (TAU / 14.0)
					if tooth < 0.55 or d < R - 2.0:
						img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.85))
		return img)

# ---------------- chrome (theme textures) ----------------
# Riveted dark-steel plate for panels. 9-slice: margins keep rivets + bevel.
static func plate_texture() -> Texture2D:
	return _cached("plate", func() -> Image: return _paint_plate(96, 20,
		PAL.panel, PAL.panel_hi, PAL.panel_lo, Color(0.408, 0.552, 0.288, 0.6)))

# Beveled button plates. state: 0 normal, 1 hover, 2 pressed, 3 disabled, 4 focus.
static func button_texture(state: int) -> Texture2D:
	return _cached("btn%d" % state, func() -> Image:
		var base := Color(0.108, 0.124, 0.104)
		var hi := Color(0.245, 0.282, 0.237)
		var lo := Color(0.045, 0.036, 0.03)
		var edge := Color(0.408, 0.552, 0.288, 0.55)
		var edge_w := 1
		var pressed := false
		var dim := false
		match state:
			1: # hover — energized, clearly brighter
				base = Color(0.191, 0.219, 0.184)
				hi = Color(0.368, 0.498, 0.26)
				edge = Color(0.555, 0.951, 0.224, 1.0)
			2: # pressed — pushed in: inverted bevel, darker core
				base = Color(0.062, 0.072, 0.06)
				hi = Color(0.074, 0.086, 0.072)
				lo = Color(0.228, 0.262, 0.221)
				edge = Color(0.629, 0.97, 0.315, 1.0)
				pressed = true
			3: # disabled — visibly recedes
				base = Color(0.10, 0.098, 0.094)
				hi = Color(0.12, 0.118, 0.112)
				lo = Color(0.06, 0.058, 0.055)
				edge = Color(0.294, 0.339, 0.285, 0.40)
				dim = true
			4: # focus — unmistakable bright amber ring, 2px
				base = Color(0.15, 0.173, 0.145)
				hi = Color(0.306, 0.414, 0.216)
				lo = Color(0.05, 0.04, 0.03)
				edge = Color(0.651, 0.97, 0.35, 1.0)
				edge_w = 2
		return _paint_plate(64, 16, base, hi, lo, edge, pressed, edge_w, dim))

# Dark inset well (lists, text fields).
static func inset_texture() -> Texture2D:
	return _cached("inset", func() -> Image:
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		var base := Color(0.055, 0.046, 0.038)
		for y in 48:
			for x in 48:
				var c := base
				var n: float = (float(BAYER[(y & 3) * 4 + (x & 3)]) - 0.47) * 0.02
				c = Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1))
				if y == 0 or x == 0:
					c = Color(0.02, 0.016, 0.013) # inner shadow
				elif y == 47 or x == 47:
					c = Color(0.098, 0.112, 0.095) # bottom light
				c.a = 0.92
				img.set_pixel(x, y, c)
		return img)

# Amber/black diagonal hazard strip.
static func hazard_texture() -> Texture2D:
	return _cached("hazard", func() -> Image:
		var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
		for y in 24:
			for x in 48:
				var s := fposmod(float(x + y), 16.0)
				var c := Color(0.86, 0.64, 0.16) if s < 8.0 else Color(0.05, 0.04, 0.03)
				var n: float = (float(BAYER[(y & 3) * 4 + (x & 3)]) - 0.47) * 0.05
				c = Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1))
				if y == 0 or y == 23:
					c = c.darkened(0.35)
				img.set_pixel(x, y, c)
		return img)

static func _paint_plate(size: int, margin: int, base: Color, hi: Color, lo: Color, edge: Color, pressed := false, edge_w := 1, dim_rivets := false) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for y in size:
		for x in size:
			var c := base
			# vertical light-to-shade falloff + brushed noise
			var grad: float = 0.05 - 0.09 * (float(y) / float(size - 1))
			c = Color(clampf(c.r + grad, 0, 1), clampf(c.g + grad, 0, 1), clampf(c.b + grad, 0, 1))
			var n: float = (float(BAYER[(y & 3) * 4 + (x & 3)]) - 0.47) * 0.022 + (rng.randf() - 0.5) * 0.008
			c = Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1))
			# bevel: crisp 1px light top/left, dark bottom/right (inverted when pressed)
			if not pressed:
				if y == edge_w or x == edge_w:
					c = hi
				elif y == size - 1 - edge_w or x == size - 1 - edge_w:
					c = lo
			else:
				if y == edge_w or x == edge_w:
					c = lo
				elif y == size - 1 - edge_w or x == size - 1 - edge_w:
					c = hi
			# outer edge ring (edge_w px)
			if x < edge_w or y < edge_w or x >= size - edge_w or y >= size - edge_w:
				c = Color(edge.r, edge.g, edge.b, 1.0)
			c.a = 0.97
			img.set_pixel(x, y, c)
	# inner hairline
	for i in range(margin - 2, size - margin + 3):
		img.set_pixel(i, margin - 2, Color(edge.r, edge.g, edge.b, 0.16))
		img.set_pixel(i, size - margin + 1, Color(edge.r, edge.g, edge.b, 0.10))
		img.set_pixel(margin - 2, i, Color(edge.r, edge.g, edge.b, 0.16))
		img.set_pixel(size - margin + 1, i, Color(edge.r, edge.g, edge.b, 0.10))
	# corner brackets: thin L-shaped accent ticks (clean, utilitarian)
	var o := 5
	var L := 9
	for corner in [[o, o, 1, 1], [size - 1 - o, o, -1, 1], [o, size - 1 - o, 1, -1], [size - 1 - o, size - 1 - o, -1, -1]]:
		var cx: int = corner[0]
		var cy: int = corner[1]
		var bc := Color(edge.r, edge.g, edge.b, 0.55 if dim_rivets else 0.95)
		for i in L:
			for t in 2:
				img.set_pixel(cx + i * int(corner[2]), cy + t * int(corner[3]), bc)
				img.set_pixel(cx + t * int(corner[2]), cy + i * int(corner[3]), bc)
	return img
