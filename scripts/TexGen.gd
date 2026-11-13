class_name TexGen
extends RefCounted
# Material texture generator: albedo + height (-> normal map) + roughness for every
# surface, built from native FastNoiseLite layers (value, cellular, ridged) and
# combined per pixel over raw byte arrays so 256px sets build in a blink.
# Results are cached to user://texcache so later launches just load PNGs.

const VERSION := 5
const KEYS := ["concrete", "plaster", "brick", "asphalt", "cobble", "tile", "wood", "rusty_metal",
	"corrugated", "dust", "grass", "leaves", "bark", "rock", "sandbag", "gunmetal", "polymer", "fabric", "walnut"]

static var _noise_cache := {}

static func has_key(key: String) -> bool:
	return key in KEYS

# Returns {"albedo": Image RGB8, "height": Image L8, "rough": Image L8}
static func make(key: String, size: int) -> Dictionary:
	var dir := "user://texcache_v%d" % VERSION
	var base := "%s/%s_%d" % [dir, key, size]
	if FileAccess.file_exists(base + "_a.png") and FileAccess.file_exists(base + "_h.png") and FileAccess.file_exists(base + "_r.png"):
		var a := Image.load_from_file(base + "_a.png")
		var h := Image.load_from_file(base + "_h.png")
		var r := Image.load_from_file(base + "_r.png")
		if a != null and h != null and r != null:
			h.convert(Image.FORMAT_L8)
			r.convert(Image.FORMAT_L8)
			a.convert(Image.FORMAT_RGB8)
			return {"albedo": a, "height": h, "rough": r}
	var out := _build(key, size)
	DirAccess.make_dir_recursive_absolute(dir)
	(out.albedo as Image).save_png(base + "_a.png")
	(out.height as Image).save_png(base + "_h.png")
	(out.rough as Image).save_png(base + "_r.png")
	return out

# ---------- noise layers (seamless, 0..1 bytes) ----------
static func _layer(size: int, seed: int, freq: float, kind := "fbm", octaves := 5, stretch := Vector2.ONE) -> PackedByteArray:
	var k := "%d_%d_%.4f_%s_%d_%s" % [size, seed, freq, kind, octaves, str(stretch)]
	if _noise_cache.has(k):
		return _noise_cache[k]
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = octaves
	match kind:
		"fbm":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
		"ridged":
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		"cell":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
			n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			n.cellular_jitter = 0.9
		"cellid":
			n.noise_type = FastNoiseLite.TYPE_CELLULAR
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
			n.cellular_jitter = 0.9
		"white":
			n.noise_type = FastNoiseLite.TYPE_VALUE
			n.fractal_type = FastNoiseLite.FRACTAL_NONE
			n.frequency = 1.0
	var w := int(size * stretch.x)
	var h := int(size * stretch.y)
	var img := n.get_seamless_image(w, h, false, false, 0.1, true)
	if stretch != Vector2.ONE:
		img.resize(size, size, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_L8)
	var data := img.get_data()
	_noise_cache[k] = data
	return data

static func _img(size: int, rgb: PackedByteArray, hgt: PackedByteArray, rgh: PackedByteArray) -> Dictionary:
	return {
		"albedo": Image.create_from_data(size, size, false, Image.FORMAT_RGB8, rgb),
		"height": Image.create_from_data(size, size, false, Image.FORMAT_L8, hgt),
		"rough": Image.create_from_data(size, size, false, Image.FORMAT_L8, rgh),
	}

static func _b(v: float) -> int:
	return clampi(int(v * 255.0), 0, 255)

# ---------- surfaces ----------
static func _build(key: String, s: int) -> Dictionary:
	var n := s * s
	var rgb := PackedByteArray()
	rgb.resize(n * 3)
	var hgt := PackedByteArray()
	hgt.resize(n)
	var rgh := PackedByteArray()
	rgh.resize(n)
	var big := _layer(s, 11, 0.012, "fbm", 4)
	var mid := _layer(s, 23, 0.04, "fbm", 5)
	var fine := _layer(s, 37, 0.25, "fbm", 2)
	var white := _layer(s, 5, 1.0, "white")
	match key:
		"concrete", "plaster":
			var cracks := _layer(s, 71, 0.02, "ridged", 4)
			var streak := _layer(s, 91, 0.03, "fbm", 4, Vector2(0.25, 2.0))
			var peel := _layer(s, 61, 0.03, "fbm", 4)
			for i in n:
				var b := big[i] / 255.0
				var m := mid[i] / 255.0
				var f := fine[i] / 255.0
				var g := 0.5 + (b - 0.5) * 0.35 + (m - 0.5) * 0.25 + (f - 0.5) * 0.12 + (white[i] / 255.0 - 0.5) * 0.06
				var c := cracks[i] / 255.0
				var crack := clampf((c - 0.9) * 12.0, 0.0, 1.0)
				var st := clampf((streak[i] / 255.0 - 0.55) * 2.5, 0.0, 1.0)
				var r := 0.0
				var gg := 0.0
				var bb := 0.0
				var h := 0.55 + (m - 0.5) * 0.4 + (f - 0.5) * 0.3 - crack * 0.5
				var rough := 0.88 + (f - 0.5) * 0.1
				if key == "plaster":
					var p := peel[i] / 255.0
					if p > 0.66:
						# peeled to the brick/block underneath
						r = 0.42 * g + 0.12; gg = 0.3 * g + 0.1; bb = 0.24 * g + 0.08
						h -= 0.25
					else:
						r = 0.86 * (0.75 + g * 0.35); gg = 0.82 * (0.75 + g * 0.35); bb = 0.72 * (0.75 + g * 0.35)
						var edge := clampf(1.0 - absf(p - 0.66) * 30.0, 0.0, 1.0)
						r -= edge * 0.2; gg -= edge * 0.2; bb -= edge * 0.2
				else:
					r = g * 0.98; gg = g * 0.97; bb = g * 0.94
				var dark := 1.0 - st * 0.28 - crack * 0.45
				rgb[i * 3] = _b(r * dark)
				rgb[i * 3 + 1] = _b(gg * dark)
				rgb[i * 3 + 2] = _b(bb * dark * 0.98)
				hgt[i] = _b(h)
				rgh[i] = _b(rough - st * 0.1)
		"brick":
			var bw := s / 4
			var bh := s / 12
			var chip := _layer(s, 13, 0.08, "fbm", 3)
			for y in s:
				var row := y / bh
				var off := (bw / 2) if row % 2 == 1 else 0
				for x in s:
					var i := y * s + x
					var bx := (x + off) % bw
					var by := y % bh
					var id := ((x + off) / bw) * 7919 + row * 104729
					var tone := float(id % 97) / 97.0
					var m := mid[i] / 255.0
					var ch := chip[i] / 255.0
					var edge_d := mini(mini(bx, bw - bx), mini(by, bh - by))
					var mortar := edge_d < 2 or (edge_d < 4 and ch > 0.62)
					var f := fine[i] / 255.0
					var r: float
					var g: float
					var bb: float
					if mortar:
						r = 0.5 + f * 0.08; g = 0.48 + f * 0.08; bb = 0.44 + f * 0.08
						hgt[i] = _b(0.25 + f * 0.1)
						rgh[i] = _b(0.95)
					else:
						var v := 0.75 + (m - 0.5) * 0.3 + (f - 0.5) * 0.15
						r = (0.5 + tone * 0.18) * v
						g = (0.26 + tone * 0.08) * v
						bb = (0.2 + tone * 0.05) * v
						if tone > 0.85:
							r *= 0.6; g *= 0.6; bb *= 0.6
						hgt[i] = _b(0.62 + (f - 0.5) * 0.3 + (m - 0.5) * 0.2)
						rgh[i] = _b(0.82 + (f - 0.5) * 0.15)
					var soot := clampf((big[i] / 255.0 - 0.6) * 2.0, 0.0, 0.5)
					rgb[i * 3] = _b(r * (1.0 - soot))
					rgb[i * 3 + 1] = _b(g * (1.0 - soot))
					rgb[i * 3 + 2] = _b(bb * (1.0 - soot))
		"asphalt":
			var cracks := _layer(s, 72, 0.018, "ridged", 4)
			var agg := _layer(s, 19, 0.6, "cell")
			for i in n:
				var a := agg[i] / 255.0
				var f := fine[i] / 255.0
				var b := big[i] / 255.0
				var c := clampf((cracks[i] / 255.0 - 0.88) * 10.0, 0.0, 1.0)
				var stone := 1.0 - clampf(a * 1.6, 0.0, 1.0)
				var g := 0.2 + stone * 0.14 + (f - 0.5) * 0.06 + (b - 0.5) * 0.08
				var oil := clampf((mid[i] / 255.0 - 0.72) * 3.0, 0.0, 0.6)
				g *= 1.0 - oil * 0.5 - c * 0.6
				rgb[i * 3] = _b(g)
				rgb[i * 3 + 1] = _b(g * 0.99)
				rgb[i * 3 + 2] = _b(g * 1.02)
				hgt[i] = _b(0.5 + stone * 0.25 + (f - 0.5) * 0.15 - c * 0.5)
				rgh[i] = _b(0.86 - oil * 0.5 - stone * 0.08)
		"cobble":
			var cell := _layer(s, 29, 0.035, "cell")
			var cid := _layer(s, 29, 0.035, "cellid")
			for i in n:
				var d := cell[i] / 255.0
				var id := cid[i] / 255.0
				var f := fine[i] / 255.0
				var gap := clampf((d - 0.05) * 8.0, 0.0, 1.0)
				var dome := clampf(d * 1.6, 0.0, 1.0)
				var v := (0.48 + id * 0.25 + (f - 0.5) * 0.12) * (0.35 + gap * 0.65)
				var dirt := 1.0 - gap
				rgb[i * 3] = _b(v * 1.02 + dirt * 0.05)
				rgb[i * 3 + 1] = _b(v * 0.97 + dirt * 0.03)
				rgb[i * 3 + 2] = _b(v * 0.9)
				hgt[i] = _b(0.15 + sqrt(dome) * 0.75 + (f - 0.5) * 0.08)
				rgh[i] = _b(0.7 + (1.0 - gap) * 0.25 + (f - 0.5) * 0.1)
		"tile":
			var cell2 := s / 8
			var grime := _layer(s, 33, 0.05, "fbm", 4)
			for y in s:
				for x in s:
					var i := y * s + x
					var lx := x % cell2
					var ly := y % cell2
					var ed := mini(mini(lx, cell2 - lx), mini(ly, cell2 - ly))
					var grout := ed < 2
					var check := ((x / cell2) + (y / cell2)) % 2 == 0
					var f := fine[i] / 255.0
					var gm := grime[i] / 255.0
					var base := 0.8 if check else 0.66
					var near := clampf(1.0 - float(ed) / 6.0, 0.0, 1.0)
					var v := base + (f - 0.5) * 0.05 - near * 0.12 * gm - clampf((gm - 0.6) * 0.8, 0.0, 0.3)
					var cracked := white[((y / cell2) * 31 + (x / cell2) * 17) % n] > 235
					if grout:
						v = 0.22 + gm * 0.08
					elif cracked and absf(float(lx - ly)) < 1.2:
						v *= 0.4
					rgb[i * 3] = _b(v)
					rgb[i * 3 + 1] = _b(v * 0.99)
					rgb[i * 3 + 2] = _b(v * 0.97)
					hgt[i] = _b(0.15 if grout else 0.62 + (f - 0.5) * 0.04)
					rgh[i] = _b(0.95 if grout else 0.18 + gm * 0.35)
		"wood":
			var grain := _layer(s, 41, 0.05, "fbm", 5, Vector2(0.15, 3.0))
			var knots := _layer(s, 43, 0.05, "cell")
			var pw := s / 4
			for y in s:
				for x in s:
					var i := y * s + x
					var plank := x / pw
					var gr := grain[(y * s + (x + plank * 37) % s)] / 255.0
					var k := 1.0 - clampf(knots[i] / 255.0 * 6.0, 0.0, 1.0)
					var rings := 0.5 + 0.5 * sin(gr * 40.0 + k * 8.0)
					var tone := 0.85 + float((plank * 73) % 7) / 7.0 * 0.25
					var v := (0.32 + rings * 0.12 + (fine[i] / 255.0 - 0.5) * 0.06) * tone * (1.0 - k * 0.35)
					var seam := x % pw < 2
					if seam:
						v *= 0.35
					var weather := clampf((big[i] / 255.0 - 0.5) * 1.2, 0.0, 0.4)
					rgb[i * 3] = _b(v * 1.25 + weather * 0.2)
					rgb[i * 3 + 1] = _b(v * 0.9 + weather * 0.2)
					rgb[i * 3 + 2] = _b(v * 0.55 + weather * 0.2)
					hgt[i] = _b(0.1 if seam else 0.5 + rings * 0.2 - k * 0.2)
					rgh[i] = _b(0.8 + weather * 0.3)
		"walnut":
			# continuous oiled gun-stock grain, no plank seams
			var wg := _layer(s, 47, 0.04, "fbm", 5, Vector2(0.12, 3.0))
			for i in n:
				var gr := wg[i] / 255.0
				var rings := 0.5 + 0.5 * sin(gr * 34.0)
				var fig := (mid[i] / 255.0 - 0.5) * 0.1
				var v := 0.24 + rings * 0.1 + fig + (fine[i] / 255.0 - 0.5) * 0.03
				rgb[i * 3] = _b(v * 1.2)
				rgb[i * 3 + 1] = _b(v * 0.82)
				rgb[i * 3 + 2] = _b(v * 0.56)
				hgt[i] = _b(0.5 + rings * 0.06)
				rgh[i] = _b(0.42 + rings * 0.12)
		"rusty_metal", "corrugated", "gunmetal":
			var rust := _layer(s, 51, 0.025, "fbm", 5)
			var pits := _layer(s, 53, 0.35, "cell")
			var scratch := _layer(s, 57, 0.08, "ridged", 2, Vector2(3.0, 0.2))
			for y in s:
				for x in s:
					var i := y * s + x
					var ru := rust[i] / 255.0
					var f := fine[i] / 255.0
					var sc := clampf((scratch[i] / 255.0 - 0.93) * 14.0, 0.0, 1.0)
					var pit := 1.0 - clampf(pits[i] / 255.0 * 5.0, 0.0, 1.0)
					var rib := 0.0
					if key == "corrugated":
						rib = sin(float(x) / s * TAU * 8.0)
					var r: float
					var g: float
					var bb: float
					var h: float
					var rough: float
					var thr := 0.58 if key == "rusty_metal" else (0.62 if key == "corrugated" else 0.95)
					if ru > thr:
						var t := clampf((ru - thr) * 4.0, 0.0, 1.0)
						r = 0.36 + t * 0.12 + (f - 0.5) * 0.1
						g = 0.18 + t * 0.04 + (f - 0.5) * 0.05
						bb = 0.08 + (f - 0.5) * 0.03
						h = 0.42 + (f - 0.5) * 0.4 - pit * 0.2
						rough = 0.95
					else:
						var v := 0.42 + (mid[i] / 255.0 - 0.5) * 0.12 + (f - 0.5) * 0.05
						if key == "gunmetal":
							v = 0.2 + (f - 0.5) * 0.05 + (mid[i] / 255.0 - 0.5) * 0.04
						v += sc * 0.25
						r = v; g = v * 1.01; bb = v * 1.04
						h = 0.6 - sc * 0.15 - pit * 0.05
						if key == "gunmetal":
							h = 0.6 - sc * 0.1 + (f - 0.5) * 0.02
						rough = (0.45 if key == "gunmetal" else 0.5) + (f - 0.5) * 0.12 - sc * 0.25
					h += rib * 0.25
					var shade := 1.0 + rib * 0.08
					rgb[i * 3] = _b(r * shade)
					rgb[i * 3 + 1] = _b(g * shade)
					rgb[i * 3 + 2] = _b(bb * shade)
					hgt[i] = _b(h)
					rgh[i] = _b(rough)
		"polymer":
			var stip := _layer(s, 81, 0.5, "cell")
			for i in n:
				var st := stip[i] / 255.0
				var f := fine[i] / 255.0
				var v := 0.11 + (f - 0.5) * 0.02 + st * 0.02
				rgb[i * 3] = _b(v)
				rgb[i * 3 + 1] = _b(v)
				rgb[i * 3 + 2] = _b(v * 1.05)
				hgt[i] = _b(0.4 + clampf(st * 1.5, 0.0, 0.5))
				rgh[i] = _b(0.72 + st * 0.15)
		"fabric", "sandbag":
			for y in s:
				for x in s:
					var i := y * s + x
					var weave := (sin(x * 1.6) * 0.5 + 0.5) * (sin(y * 1.6 + PI * float((x / 2) % 2)) * 0.5 + 0.5)
					var f := fine[i] / 255.0
					var m := mid[i] / 255.0
					var v := 0.5 + weave * 0.15 + (f - 0.5) * 0.1 + (m - 0.5) * 0.2
					if key == "sandbag":
						rgb[i * 3] = _b(v * 0.92)
						rgb[i * 3 + 1] = _b(v * 0.84)
						rgb[i * 3 + 2] = _b(v * 0.6)
					else:
						rgb[i * 3] = _b(v * 0.6)
						rgb[i * 3 + 1] = _b(v * 0.6)
						rgb[i * 3 + 2] = _b(v * 0.62)
					hgt[i] = _b(0.4 + weave * 0.4)
					rgh[i] = _b(0.95)
		"dust", "grass":
			var ripple := _layer(s, 63, 0.02, "fbm", 3, Vector2(2.5, 0.4))
			var pebble := _layer(s, 67, 0.25, "cell")
			var blade := _layer(s, 69, 0.4, "fbm", 2, Vector2(0.2, 4.0))
			for i in n:
				var b := big[i] / 255.0
				var m := mid[i] / 255.0
				var f := fine[i] / 255.0
				var rp := sin(ripple[i] / 255.0 * 30.0) * 0.5 + 0.5
				var pb := 1.0 - clampf(pebble[i] / 255.0 * 5.0, 0.0, 1.0)
				if key == "dust":
					var v := 0.55 + (b - 0.5) * 0.2 + (m - 0.5) * 0.12 + (f - 0.5) * 0.08 + rp * 0.04
					var stonec := pb * (0.15 + white[i] / 255.0 * 0.2)
					rgb[i * 3] = _b(v * 1.06 - stonec * 0.2)
					rgb[i * 3 + 1] = _b(v * 0.92 - stonec * 0.2)
					rgb[i * 3 + 2] = _b(v * 0.7 - stonec * 0.1)
					hgt[i] = _b(0.45 + rp * 0.15 + pb * 0.35 + (f - 0.5) * 0.15)
					rgh[i] = _b(0.94)
				else:
					var bl := blade[i] / 255.0
					var dry := clampf((b - 0.5) * 2.0 + 0.3, 0.0, 1.0)
					var g := Color(0.2, 0.32, 0.12).lerp(Color(0.48, 0.44, 0.24), dry)
					var v2 := 0.75 + bl * 0.5 + (f - 0.5) * 0.2
					rgb[i * 3] = _b(g.r * v2)
					rgb[i * 3 + 1] = _b(g.g * v2)
					rgb[i * 3 + 2] = _b(g.b * v2)
					hgt[i] = _b(0.3 + bl * 0.6)
					rgh[i] = _b(0.9)
		"leaves":
			var lc := _layer(s, 77, 0.12, "cell")
			for i in n:
				var l := lc[i] / 255.0
				var f := fine[i] / 255.0
				var v := 0.18 + clampf(l * 1.3, 0.0, 0.25) + (f - 0.5) * 0.08 + (mid[i] / 255.0 - 0.5) * 0.1
				rgb[i * 3] = _b(v * 0.55)
				rgb[i * 3 + 1] = _b(v)
				rgb[i * 3 + 2] = _b(v * 0.45)
				hgt[i] = _b(0.3 + l * 0.8)
				rgh[i] = _b(0.75)
		"bark":
			var fur := _layer(s, 79, 0.08, "ridged", 4, Vector2(0.3, 2.5))
			for i in n:
				var fu := fur[i] / 255.0
				var f := fine[i] / 255.0
				var v := 0.18 + fu * 0.16 + (f - 0.5) * 0.05
				rgb[i * 3] = _b(v * 1.1)
				rgb[i * 3 + 1] = _b(v * 0.88)
				rgb[i * 3 + 2] = _b(v * 0.68)
				hgt[i] = _b(fu)
				rgh[i] = _b(0.95)
		"rock":
			var cr := _layer(s, 83, 0.03, "cell")
			var strata := _layer(s, 87, 0.02, "fbm", 4, Vector2(3.0, 0.3))
			for i in n:
				var c := cr[i] / 255.0
				var st := strata[i] / 255.0
				var f := fine[i] / 255.0
				var crack := 1.0 - clampf(c * 8.0, 0.0, 1.0)
				var v := (0.42 + (mid[i] / 255.0 - 0.5) * 0.25 + (st - 0.5) * 0.18 + (f - 0.5) * 0.1) * (1.0 - crack * 0.5)
				rgb[i * 3] = _b(v)
				rgb[i * 3 + 1] = _b(v * 0.96)
				rgb[i * 3 + 2] = _b(v * 0.9)
				hgt[i] = _b(0.3 + clampf(c * 2.0, 0.0, 0.5) + (f - 0.5) * 0.2)
				rgh[i] = _b(0.85 + (f - 0.5) * 0.1)
		"chain":
			for y in s:
				for x in s:
					var i := y * s + x
					var cx := float(x % 16) - 8.0
					var cy := float(y % 16) - 8.0
					var d := absf(absf(cx) + absf(cy) - 6.0)
					var wire := d < 1.3
					var v := 0.55 if wire else 0.0
					rgb[i * 3] = _b(v)
					rgb[i * 3 + 1] = _b(v)
					rgb[i * 3 + 2] = _b(v * 1.05)
					hgt[i] = _b(0.8 if wire else 0.0)
					rgh[i] = _b(0.4)
	return _img(s, rgb, hgt, rgh)
