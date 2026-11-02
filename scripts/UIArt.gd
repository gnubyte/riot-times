class_name UIArt
extends RefCounted
# Procedural 2D art for menus/loading — painted into Images at startup.

# Dusk wasteland sky: banded sunset, sun disc, stars up top, dust haze bottom.
static func sky_texture(w := 1600, h := 900) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		var t := float(y) / float(h)
		var c: Color
		if t < 0.32:
			c = Color(0.06, 0.05, 0.10).lerp(Color(0.22, 0.10, 0.16), t / 0.32)
		elif t < 0.58:
			c = Color(0.22, 0.10, 0.16).lerp(Color(0.72, 0.30, 0.12), (t - 0.32) / 0.26)
		elif t < 0.72:
			c = Color(0.72, 0.30, 0.12).lerp(Color(0.95, 0.62, 0.22), (t - 0.58) / 0.14)
		else:
			c = Color(0.95, 0.62, 0.22).lerp(Color(0.45, 0.25, 0.12), (t - 0.72) / 0.28)
		for x in w:
			var g := float(randi_range(-4, 4)) / 100.0
			img.set_pixel(x, y, Color(clampf(c.r + g, 0, 1), clampf(c.g + g, 0, 1), clampf(c.b + g, 0, 1)))
	# stars
	for i in 140:
		var sx := randi() % w
		var sy := randi() % int(h * 0.3)
		var b := randf_range(0.3, 1.0)
		img.set_pixel(sx, sy, Color(0.8 + b * 0.2, 0.8 + b * 0.15, 0.75 + b * 0.2))
	# sun glow + disc
	var sun := Vector2(w * 0.5, h * 0.66)
	var r := h * 0.16
	for y in range(int(sun.y - r * 2.4), mini(h, int(sun.y + r * 2.4))):
		for x in range(maxi(0, int(sun.x - r * 2.4)), mini(w, int(sun.x + r * 2.4))):
			var d := Vector2(x - sun.x, (y - sun.y) * 1.2).length()
			if d < r:
				img.set_pixel(x, y, Color(1.0, 0.88, 0.55))
			elif d < r * 2.4:
				var f := 1.0 - (d - r) / (r * 1.4)
				f = pow(f, 2.2) * 0.55
				var old := img.get_pixel(x, y)
				img.set_pixel(x, y, old.lerp(Color(1.0, 0.72, 0.3), f))
	# horizontal scanlines through the sun (retro)
	for y in range(int(sun.y - r), int(sun.y + r), 2):
		if (y - int(sun.y - r)) % 12 < 5:
			continue
		for x in range(int(maxf(0, sun.x - r)), mini(w, int(sun.x + r))):
			var dy: float = y - sun.y
			var dx_max: float = sqrt(maxf(0, r * r - dy * dy))
			if absf(x - sun.x) <= dx_max:
				var old2 := img.get_pixel(x, y)
				img.set_pixel(x, y, old2 * Color(0.7, 0.55, 0.45))
	return ImageTexture.create_from_image(img)

# Black silhouette skyline (buildings + bridge + tower + dead trees) with alpha.
static func skyline_texture(w := 1600, h := 420, variant := 0) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color(0.05, 0.035, 0.03, 1.0)
	var rngy := RandomNumberGenerator.new()
	rngy.seed = 42 + variant
	# skyline profile: blocks of buildings with broken tops
	var x := 0
	var baseline := h - 6
	while x < w:
		var bw := rngy.randi_range(int(w * 0.02), int(w * 0.06))
		var bh := rngy.randi_range(int(h * 0.25), int(h * 0.8))
		var style := rngy.randi_range(0, 4)
		for bx in range(x, mini(w, x + bw)):
			# jagged tops
			var jag := int(bh * (0.85 + 0.3 * sin((bx - x) * 0.7 + variant)))
			var top := baseline - bh + absi(jag - bh) / 3
			match style:
				0: pass # flat
				1: top = baseline - bh + (0 if (bx % 8) < 4 else 14)
				2: top = baseline - bh + abs((bx - x) % 18 - 9)
				3: top = baseline - bh if (bx % 13) > 2 else baseline - bh + 26
				_: top = baseline - bh + (bh if (bx % 29) < 3 else 0)
			for y in range(clampi(top, 0, h), h):
				if rngy.randf() < 0.985:
					img.set_pixel(bx, y, ink)
		x += bw + rngy.randi_range(2, int(w * 0.02))
	# bridge spanning center-right
	var deck_y := baseline - int(h * 0.24)
	for bx in range(int(w * 0.42), int(w * 0.78)):
		for y in range(deck_y, deck_y + 10):
			img.set_pixel(bx, y, ink)
		if bx % 90 < 18:
			for y in range(deck_y, baseline):
				img.set_pixel(bx, y, ink)
	# arch under bridge
	for bx in range(int(w * 0.46), int(w * 0.74)):
		var t := float(bx - int(w * 0.46)) / float(int(w * 0.74) - int(w * 0.46))
		var ay := deck_y + int(sin(t * PI) * h * 0.16)
		img.set_pixel(bx, ay, ink)
		img.set_pixel(bx, ay + 1, ink)
	# dead trees
	for i in 4:
		var tx := rngy.randi_range(20, w - 20)
		var th := rngy.randi_range(int(h * 0.2), int(h * 0.4))
		for y in range(baseline - th, baseline):
			img.set_pixel(tx, y, ink)
			if rngy.randf() < 0.3:
				img.set_pixel(tx + 1, y, ink)
		for b in 5:
			var by := baseline - th + rngy.randi_range(0, int(th * 0.5))
			var bl := rngy.randi_range(8, 34)
			var dir := 1 if b % 2 == 0 else -1
			for s in bl:
				img.set_pixel(clampi(tx + dir * s, 0, w - 1), clampi(by - s / 3 + rngy.randi_range(-2, 2), 0, h - 1), ink)
	# water tower on left
	var wx := int(w * 0.12)
	for y in range(baseline - int(h * 0.5), baseline):
		img.set_pixel(wx, y, ink); img.set_pixel(wx + 2, y, ink)
		img.set_pixel(wx + 26, y, ink); img.set_pixel(wx + 28, y, ink)
	for yy in range(baseline - int(h * 0.66), baseline - int(h * 0.5)):
		for xx in range(wx - 6, wx + 34):
			img.set_pixel(xx, yy, ink)
	return ImageTexture.create_from_image(img)

# Grain / dust overlay with alpha.
static func grain_texture(alpha := 0.09) -> Texture2D:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var v := randf()
			var a := alpha if v < 0.5 else alpha * v * 0.4
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	t.resource_name = "grain"
	return t

# Vignette (dark edges), transparent center — normal blend.
static func vignette_texture(w := 1600, h := 900) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var center := Vector2(w * 0.5, h * 0.5)
	var maxd := center.length()
	for y in h:
		for x in w:
			var d := Vector2(x, y).distance_to(center) / maxd
			var a := pow(clampf(d, 0.0, 1.0), 2.2) * 0.72
			img.set_pixel(x, y, Color(0.02, 0.01, 0.01, a))
	return ImageTexture.create_from_image(img)

# Rad-emblem drawn into a texture (circle + trefoil).
static func emblem_texture(size := 256, col := Color(0.95, 0.75, 0.25)) -> Texture2D:
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
				# three sectors each 100deg wide starting at 30deg offset per sector
				var rel := fposmod(ang - PI / 6.0, TAU * 2.0 / 3.0)
				if rel < PI * 2.0 / 3.0 * 0.58:
					px = Color(col.r, col.g, col.b, 0.9)
			img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)
