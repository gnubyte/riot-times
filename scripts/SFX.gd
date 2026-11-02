extends Node
# Procedural audio — every sound is synthesized at load, no assets.
# 2D pool for the player/UI, 3D pool for the world, crossfaded ambience loops,
# and a dedicated engine loop for vehicles.

const RATE := 22050
var cache := {}
var players: Array[AudioStreamPlayer] = []
var players_3d: Array[AudioStreamPlayer3D] = []
var _next_3d := 0
var amb_a: AudioStreamPlayer
var amb_b: AudioStreamPlayer
var amb_current := ""
var amb_fade := 0.0
var engine_player: AudioStreamPlayer3D = null
var _rng := RandomNumberGenerator.new()

const ALL := ["shot_pistol", "shot_revolver", "shot_smg", "shot_ar", "shot_shotgun", "shot_dmr",
	"shot_sniper", "shot_lmg", "shot_suppressed", "shot_crossbow", "shot_raider", "dry_fire", "mag_out",
	"mag_in", "bolt", "pump", "shell_in", "equip", "hit_flesh", "hit_metal", "hit_dirt", "hitmarker",
	"headshot", "kill", "swing", "swing_heavy", "melee_hit", "step", "step_hard", "land", "slide",
	"jump", "mantle", "hurt", "heartbeat", "cough", "vomit", "eat", "drink", "heal", "levelup",
	"skill", "quest", "pickup", "ui", "click", "zombie_groan", "zombie_attack", "runner_shriek",
	"brute_roar", "scream", "bloater_pop", "goliath_roar", "slam", "gaunt_shriek", "gaunt_click",
	"wolf_howl", "wolf_snarl", "vamp_hiss", "blink", "raider_shout", "boar_grunt", "explosion",
	"fire", "beep", "glass", "horde", "bell", "horn", "crash", "splash", "reel", "bite", "sizzle",
	"open", "legendary", "whoosh", "thunk"]
const LOOPS := ["amb_day", "amb_night", "amb_mall", "amb_lab", "engine"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 4242
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	for i in 28:
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = "Master"
		p3.unit_size = 8.0
		p3.max_distance = 90.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p3)
		players_3d.append(p3)
	amb_a = AudioStreamPlayer.new()
	amb_b = AudioStreamPlayer.new()
	for a in [amb_a, amb_b]:
		a.bus = "Master"
		a.volume_db = -80.0
		add_child(a)

func set_bus(bus: String) -> void:
	for p in players: p.bus = bus
	for p in players_3d: p.bus = bus
	amb_a.bus = bus
	amb_b.bus = bus

# Main generates everything up front during loading (a few per frame) so the first
# Gaunt shriek doesn't hitch the frame.
func warm(sname: String) -> void:
	_gen(sname)

func play(sname: String, vol_db := 0.0, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = null
	for c in players:
		if not c.playing:
			p = c
			break
	if p == null:
		p = players[0]
	p.stream = _gen(sname)
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.play()

func play_3d(sname: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, max_dist := 90.0) -> void:
	if not is_inside_tree():
		return
	var p := players_3d[_next_3d]
	_next_3d = (_next_3d + 1) % players_3d.size()
	p.stream = _gen(sname)
	p.global_position = pos
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.unit_size = clampf(max_dist / 9.0, 3.0, 30.0)
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.play()

# ---------- ambience ----------
func ambience(loop_name: String, vol_db := -18.0) -> void:
	if loop_name == amb_current:
		return
	amb_current = loop_name
	var incoming := amb_b if amb_a.playing and amb_a.volume_db > -60.0 else amb_a
	var outgoing := amb_a if incoming == amb_b else amb_b
	if loop_name != "":
		incoming.stream = _gen(loop_name)
		incoming.volume_db = -60.0
		incoming.play()
		var ti := create_tween()
		ti.tween_property(incoming, "volume_db", vol_db, 2.5)
	if outgoing.playing:
		var to := create_tween()
		to.tween_property(outgoing, "volume_db", -80.0, 2.5)
		to.tween_callback(outgoing.stop)

func engine_loop(on: bool, host: Node3D = null, pitch := 1.0, vol_db := -6.0) -> void:
	if on:
		if engine_player == null or not is_instance_valid(engine_player):
			engine_player = AudioStreamPlayer3D.new()
			engine_player.bus = players[0].bus
			engine_player.unit_size = 10.0
			engine_player.max_distance = 80.0
			engine_player.stream = _gen("engine")
		if host != null and engine_player.get_parent() != host:
			if engine_player.get_parent():
				engine_player.get_parent().remove_child(engine_player)
			host.add_child(engine_player)
		engine_player.pitch_scale = clampf(pitch, 0.4, 3.0)
		engine_player.volume_db = vol_db
		if not engine_player.playing:
			engine_player.play()
	elif engine_player != null and is_instance_valid(engine_player):
		engine_player.stop()

# ---------- synthesis ----------
func _gen(sname: String) -> AudioStreamWAV:
	if cache.has(sname):
		return cache[sname]
	var f := AudioStreamWAV.new()
	f.format = AudioStreamWAV.FORMAT_16_BITS
	f.mix_rate = RATE
	f.stereo = false
	var s: PackedFloat32Array
	match sname:
		"shot_pistol": s = _gunshot(0.32, 0.9, 1300.0, 0.25, 0.6)
		"shot_revolver": s = _gunshot(0.6, 1.0, 700.0, 0.5, 1.0)
		"shot_smg": s = _gunshot(0.2, 0.75, 1700.0, 0.15, 0.45)
		"shot_ar": s = _gunshot(0.38, 0.95, 1100.0, 0.3, 0.75)
		"shot_shotgun": s = _gunshot(0.7, 1.0, 420.0, 0.6, 1.2)
		"shot_dmr": s = _gunshot(0.55, 1.0, 900.0, 0.45, 0.9)
		"shot_sniper": s = _gunshot(1.1, 1.0, 600.0, 0.8, 1.3)
		"shot_lmg": s = _gunshot(0.36, 1.0, 850.0, 0.3, 0.85)
		"shot_raider": s = _gunshot(0.3, 0.8, 1000.0, 0.25, 0.6)
		"shot_suppressed": s = _suppressed()
		"shot_crossbow": s = _twang()
		"dry_fire": s = _click(0.04, 3200.0)
		"mag_out": s = _metal_clack(0.12, 1900.0, 800.0)
		"mag_in": s = _metal_clack(0.1, 1500.0, 2400.0, true)
		"bolt": s = _concat([_metal_clack(0.09, 1300.0, 2200.0, true), _silence(0.07), _metal_clack(0.11, 1700.0, 900.0)])
		"pump": s = _concat([_scrape(0.09, 0.4), _silence(0.05), _metal_clack(0.1, 1200.0, 700.0, true)])
		"shell_in": s = _metal_clack(0.08, 2200.0, 1100.0, true)
		"equip": s = _concat([_scrape(0.12, 0.25), _metal_clack(0.07, 2000.0, 1400.0)])
		"hit_flesh": s = _thud(110.0, 0.16, 0.9, 0.5)
		"hit_metal": s = _ping(2600.0, 0.18)
		"hit_dirt": s = _thud(70.0, 0.12, 0.5, 0.8)
		"hitmarker": s = _click(0.035, 4200.0)
		"headshot": s = _ding(1750.0, 0.3)
		"kill": s = _concat([_thud(90.0, 0.12, 1.0, 0.3), _ding(980.0, 0.22)])
		"swing": s = _whoosh(0.18, 0.08)
		"swing_heavy": s = _whoosh(0.32, 0.04)
		"whoosh": s = _whoosh(0.4, 0.05)
		"melee_hit": s = _concat([_thud(85.0, 0.2, 1.0, 0.7)])
		"thunk": s = _thud(60.0, 0.25, 1.0, 0.4)
		"step": s = _step(0.35)
		"step_hard": s = _step(0.6)
		"land": s = _thud(70.0, 0.16, 0.8, 0.6)
		"slide": s = _scrape(0.55, 0.7)
		"jump": s = _scrape(0.12, 0.3)
		"mantle": s = _concat([_scrape(0.2, 0.5), _thud(120.0, 0.1, 0.5, 0.4)])
		"hurt": s = _vowel(0.28, 150.0, [650.0, 1100.0], 0.8, 0.5)
		"heartbeat": s = _concat([_thud(55.0, 0.12, 1.0, 0.0), _silence(0.1), _thud(50.0, 0.14, 0.8, 0.0)])
		"cough": s = _concat([_vowel(0.12, 180.0, [500.0, 1400.0], 0.6, 0.9), _silence(0.08), _vowel(0.14, 170.0, [480.0, 1300.0], 0.6, 0.9)])
		"vomit": s = _vowel(0.7, 120.0, [400.0, 900.0], 0.9, 0.8)
		"eat": s = _chomp()
		"drink": s = _gulp()
		"heal": s = _scrape(0.35, 0.45)
		"levelup": s = _arp([523.25, 659.25, 784.0, 1046.5], 0.7)
		"skill": s = _arp([659.25, 987.77], 0.35)
		"quest": s = _arp([392.0, 523.25, 659.25, 784.0, 1046.5], 0.9)
		"pickup": s = _blip(660.0, 990.0, 0.1)
		"ui": s = _blip(440.0, 540.0, 0.05)
		"click": s = _click(0.05, 2500.0)
		"zombie_groan": s = _vowel(1.3, 85.0, [520.0, 900.0], 0.9, 0.55, 0.18)
		"zombie_attack": s = _vowel(0.45, 120.0, [700.0, 1200.0], 1.0, 0.7, 0.25)
		"runner_shriek": s = _vowel(0.7, 330.0, [900.0, 2400.0], 1.0, 0.45, 0.3)
		"brute_roar": s = _vowel(1.1, 60.0, [380.0, 700.0], 1.0, 0.6, 0.2)
		"scream": s = _vowel(1.9, 520.0, [1100.0, 2900.0], 1.0, 0.35, 0.12)
		"bloater_pop": s = _concat([_thud(45.0, 0.35, 1.0, 0.9), _scrape(0.5, 0.6)])
		"goliath_roar": s = _vowel(1.8, 42.0, [300.0, 600.0], 1.0, 0.7, 0.15)
		"slam": s = _thud(38.0, 0.7, 1.0, 0.7)
		"gaunt_shriek": s = _gaunt()
		"gaunt_click": s = _clicks(0.9, 14)
		"wolf_howl": s = _howl()
		"wolf_snarl": s = _vowel(0.5, 95.0, [600.0, 1500.0], 1.0, 0.8, 0.35)
		"vamp_hiss": s = _hiss(0.7)
		"blink": s = _reverse(_whoosh(0.35, 0.03))
		"raider_shout": s = _vowel(0.55, 210.0, [800.0, 1250.0], 1.0, 0.4, 0.4)
		"boar_grunt": s = _vowel(0.35, 95.0, [450.0, 900.0], 0.9, 0.6, 0.5)
		"explosion": s = _explosion()
		"fire": s = _crackle(1.2)
		"beep": s = _blip(1800.0, 1800.0, 0.09)
		"glass": s = _glass()
		"horde": s = _horde()
		"bell": s = _bell()
		"horn": s = _horn()
		"crash": s = _concat([_thud(60.0, 0.3, 1.0, 0.7), _ping(1400.0, 0.3)])
		"splash": s = _splash()
		"reel": s = _clicks(0.6, 18)
		"bite": s = _blip(300.0, 180.0, 0.12)
		"sizzle": s = _crackle(1.0, true)
		"open": s = _concat([_metal_clack(0.08, 900.0, 600.0), _scrape(0.25, 0.3)])
		"legendary": s = _arp([784.0, 1174.66, 1567.98], 0.8, true)
		"amb_day": s = _wind(4.0, 0.22, false)
		"amb_night": s = _wind(4.0, 0.14, true)
		"amb_mall": s = _hum(4.0, 0.16)
		"amb_lab": s = _drone(4.0)
		"engine": s = _engine()
		_: s = _click(0.05, 2500.0)
	f.data = _encode(s)
	if sname in LOOPS:
		f.loop_mode = AudioStreamWAV.LOOP_FORWARD
		f.loop_begin = 0
		f.loop_end = s.size()
	else:
		f.loop_mode = AudioStreamWAV.LOOP_DISABLED
	cache[sname] = f
	return f

func _encode(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	return bytes

func _n() -> float:
	return _rng.randf_range(-1.0, 1.0)

func _buf(dur: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(dur * RATE))
	return s

func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out

func _silence(dur: float) -> PackedFloat32Array:
	return _buf(dur)

func _reverse(s: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(s.size())
	for i in s.size():
		out[i] = s[s.size() - 1 - i]
	return out

# gunshot: transient crack + tonal body + low boom + filtered echo tail
func _gunshot(dur: float, amp: float, tone: float, tail: float, boom: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var n := s.size()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		var crack := _n() * exp(-t * 90.0)
		var body := sin(TAU * tone * t * (1.0 - x * 0.4)) * 0.35 * exp(-t * 28.0)
		var low := sin(TAU * (55.0 + 30.0 * exp(-t * 20.0)) * t) * boom * exp(-t * 9.0)
		lp = lerpf(lp, _n(), 0.22)
		lp2 = lerpf(lp2, lp, 0.08)
		var echo := lp2 * tail * 2.2 * exp(-t * 4.5) * (1.0 - exp(-t * 30.0))
		s[i] = (crack * 0.85 + body + low * 0.8 + echo) * amp
	return s

func _suppressed() -> PackedFloat32Array:
	var s := _buf(0.14)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _n(), 0.15)
		s[i] = (lp * 0.9 + sin(TAU * 140.0 * t) * 0.3) * exp(-t * 32.0) + _n() * 0.15 * exp(-t * 200.0)
	return s

func _twang() -> PackedFloat32Array:
	var s := _buf(0.32)
	for i in s.size():
		var t := float(i) / RATE
		var f := 190.0 * (1.0 + 0.04 * exp(-t * 30.0))
		s[i] = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.01 * t) + 0.25 * sin(TAU * f * 3.02 * t)) * exp(-t * 11.0) * 0.45 + _n() * exp(-t * 120.0) * 0.4
	return s

func _click(dur: float, f: float) -> PackedFloat32Array:
	var s := _buf(dur)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (_n() * 0.5 + sin(TAU * f * t)) * exp(-t * 160.0) * 0.8
	return s

func _metal_clack(dur: float, f1: float, f2: float, sharp := false) -> PackedFloat32Array:
	var s := _buf(dur)
	var k := 60.0 if sharp else 35.0
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * f1 * t) * 0.4 + sin(TAU * f2 * t) * 0.3 + _n() * 0.5 * exp(-t * 300.0)) * exp(-t * k)
	return s

func _scrape(dur: float, amp: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var x := float(i) / s.size()
		lp = lerpf(lp, _n(), 0.12)
		s[i] = lp * sin(x * PI) * amp * 1.6
	return s

func _thud(f: float, dur: float, amp: float, noise: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _n(), 0.25)
		s[i] = (sin(TAU * f * t * (1.0 - t * 0.8)) + lp * noise) * exp(-t * (6.0 / dur)) * amp
	return s

func _ping(f: float, dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * f * t) * 0.5 + sin(TAU * f * 1.48 * t) * 0.3 + _n() * exp(-t * 200.0) * 0.4) * exp(-t * 18.0)
	return s

func _ding(f: float, dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 3.01 * t) * 0.1) * exp(-t * 11.0) * 0.7
	return s

func _whoosh(dur: float, cut: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var x := float(i) / s.size()
		lp = lerpf(lp, _n(), cut + x * 0.15)
		s[i] = lp * pow(sin(x * PI), 1.5) * 2.4
	return s

func _step(hard: float) -> PackedFloat32Array:
	var s := _buf(0.08)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _n(), 0.3 + hard * 0.4)
		s[i] = (lp * 0.7 + sin(TAU * 90.0 * t) * 0.3) * exp(-t * 55.0) * 0.6
	return s

func _blip(f0: float, f1: float, dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var ph := 0.0
	for i in s.size():
		var x := float(i) / s.size()
		ph += lerpf(f0, f1, x) / RATE
		s[i] = sin(TAU * ph) * (1.0 - x) * 0.5
	return s

func _arp(notes: Array, dur: float, shimmer := false) -> PackedFloat32Array:
	var s := _buf(dur)
	var n := s.size()
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		var idx := clampi(int(x * notes.size()), 0, notes.size() - 1)
		var f: float = notes[idx]
		var local := x * notes.size() - idx
		var v := sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)
		if shimmer:
			v += 0.25 * sin(TAU * f * 3.0 * t + sin(t * 30.0))
		s[i] = v * (1.0 - local * 0.5) * 0.35 * (1.0 - x * 0.5)
	return s

func _chomp() -> PackedFloat32Array:
	var s := _buf(0.3)
	var lp := 0.0
	for i in s.size():
		var x := float(i) / s.size()
		lp = lerpf(lp, _n(), 0.3)
		var gate := 1.0 if int(x * 5.0) % 2 == 0 else 0.15
		s[i] = lp * gate * (1.0 - x) * 0.8
	return s

func _gulp() -> PackedFloat32Array:
	var s := _buf(0.45)
	var ph := 0.0
	for i in s.size():
		var x := float(i) / s.size()
		var f := 180.0 + 120.0 * sin(fmod(x * 3.0, 1.0) * PI)
		ph += f / RATE
		var gate := sin(fmod(x * 3.0, 1.0) * PI)
		s[i] = sin(TAU * ph) * gate * 0.5
	return s

# pseudo-voice: glottal pulse train through formant resonators
func _vowel(dur: float, f0: float, formants: Array, amp: float, breath: float, wobble := 0.1) -> PackedFloat32Array:
	var s := _buf(dur)
	var n := s.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		var f := f0 * (1.0 + wobble * sin(TAU * 5.5 * t) + _rng.randf_range(-0.03, 0.03) + (0.15 * (1.0 - x) if wobble > 0.2 else 0.0))
		ph = fmod(ph + f / RATE, 1.0)
		s[i] = (ph * 2.0 - 1.0) * (1.0 - breath) + _n() * breath
	var out := PackedFloat32Array()
	out.resize(n)
	for fm in formants:
		var r := _resonate(s, float(fm), 140.0)
		for i in n:
			out[i] += r[i]
	for i in n:
		var x := float(i) / n
		var env := minf(1.0, x * 12.0) * pow(1.0 - x, 0.8)
		out[i] = clampf(out[i] * 0.06 * amp * env, -1.0, 1.0)
	return out

func _resonate(inp: PackedFloat32Array, freq: float, bw: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(inp.size())
	var r := exp(-PI * bw / RATE)
	var b1 := 2.0 * r * cos(TAU * freq / RATE)
	var b2 := -r * r
	var y1 := 0.0
	var y2 := 0.0
	for i in inp.size():
		var y := inp[i] * (1.0 - r) + b1 * y1 + b2 * y2
		y2 = y1
		y1 = y
		out[i] = y
	return out

func _gaunt() -> PackedFloat32Array:
	var s := _buf(1.9)
	var n := s.size()
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		var f1 := 1400.0 + 900.0 * sin(t * 2.3) + 300.0 * sin(t * 37.0)
		var f2 := f1 * 1.07
		p1 += f1 / RATE
		p2 += f2 / RATE
		var env := minf(1.0, x * 6.0) * pow(1.0 - x, 1.2)
		s[i] = (sin(TAU * p1) * 0.4 + sin(TAU * p2) * 0.35 + _n() * 0.25) * env * 0.8
	return s

func _clicks(dur: float, count: int) -> PackedFloat32Array:
	var s := _buf(dur)
	for k in count:
		var start := int(_rng.randf_range(0.0, dur - 0.03) * RATE)
		var f := _rng.randf_range(2500.0, 4200.0)
		for j in int(0.02 * RATE):
			if start + j < s.size():
				var t := float(j) / RATE
				s[start + j] += sin(TAU * f * t) * exp(-t * 400.0) * 0.6
	return s

func _howl() -> PackedFloat32Array:
	var s := _buf(2.6)
	var n := s.size()
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		var f := 380.0 + 320.0 * sin(minf(x * 1.6, 1.0) * PI * 0.5) - 150.0 * maxf(0.0, x - 0.7) * 3.0
		f *= 1.0 + 0.015 * sin(TAU * 6.0 * t)
		ph += f / RATE
		var env := minf(1.0, x * 4.0) * pow(1.0 - x, 0.6)
		s[i] = (sin(TAU * ph) + 0.35 * sin(TAU * ph * 2.0) + _n() * 0.06) * env * 0.5
	return s

func _hiss(dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var prev := 0.0
	for i in s.size():
		var x := float(i) / s.size()
		var w := _n()
		s[i] = (w - prev) * 0.5 * minf(1.0, x * 8.0) * (1.0 - x)
		prev = w
	return s

func _explosion() -> PackedFloat32Array:
	var s := _buf(1.6)
	var lp := 0.0
	var lp2 := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _n(), 0.18)
		lp2 = lerpf(lp2, lp, 0.05)
		var boom := sin(TAU * (40.0 + 60.0 * exp(-t * 8.0)) * t) * exp(-t * 3.5)
		s[i] = (boom * 0.9 + lp2 * 3.0 * exp(-t * 2.2) + _n() * exp(-t * 40.0) * 0.8) * 0.9
	return s

func _crackle(dur: float, sizzle := false) -> PackedFloat32Array:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		lp = lerpf(lp, _n(), 0.6 if sizzle else 0.3)
		var pop := 0.0
		if _rng.randf() < (0.004 if sizzle else 0.0015):
			pop = _rng.randf_range(0.5, 1.0)
		s[i] = lp * (0.25 if sizzle else 0.35) + pop * _n()
	return s

func _glass() -> PackedFloat32Array:
	var s := _buf(0.6)
	for k in 9:
		var f := _rng.randf_range(2500.0, 6000.0)
		var start := int(_rng.randf_range(0.0, 0.2) * RATE)
		for j in range(start, s.size()):
			var t := float(j - start) / RATE
			s[j] += sin(TAU * f * t) * exp(-t * 14.0) * 0.12
	for i in int(0.05 * RATE):
		s[i] += _n() * (1.0 - float(i) / (0.05 * RATE)) * 0.6
	return s

func _horde() -> PackedFloat32Array:
	var s := _buf(3.2)
	for k in 7:
		var v := _vowel(_rng.randf_range(1.4, 2.8), _rng.randf_range(60.0, 140.0), [_rng.randf_range(400.0, 700.0), _rng.randf_range(850.0, 1300.0)], 0.8, 0.5, 0.25)
		var off := int(_rng.randf_range(0.0, 0.8) * RATE)
		for i in v.size():
			if off + i < s.size():
				s[off + i] += v[i] * 0.4
	return s

func _bell() -> PackedFloat32Array:
	var s := _buf(2.4)
	for i in s.size():
		var t := float(i) / RATE
		s[i] = (sin(TAU * 440.0 * t) * 0.5 + sin(TAU * 1100.0 * t) * 0.25 + sin(TAU * 1660.0 * t) * 0.15 + sin(TAU * 2410.0 * t) * 0.1) * exp(-t * 1.6) * 0.6
	return s

func _horn() -> PackedFloat32Array:
	var s := _buf(0.7)
	for i in s.size():
		var t := float(i) / RATE
		var x := float(i) / s.size()
		var sq1 := signf(sin(TAU * 392.0 * t))
		var sq2 := signf(sin(TAU * 494.0 * t))
		s[i] = (sq1 + sq2) * 0.18 * minf(1.0, x * 30.0) * minf(1.0, (1.0 - x) * 12.0)
	return s

func _splash() -> PackedFloat32Array:
	var s := _buf(0.5)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _n(), 0.35)
		s[i] = (lp * exp(-t * 7.0) + sin(TAU * (300.0 - t * 200.0) * t) * exp(-t * 20.0) * 0.4) * 0.8
	return s

func _wind(dur: float, amp: float, crickets: bool) -> PackedFloat32Array:
	var s := _buf(dur)
	var n := s.size()
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, _n(), 0.03)
		lp2 = lerpf(lp2, lp, 0.1)
		var gust := 0.6 + 0.4 * sin(TAU * t / dur) * sin(TAU * 3.0 * t / dur)
		var v := lp2 * 6.0 * gust * amp
		if crickets:
			var chirp := sin(TAU * 4400.0 * t) * maxf(0.0, sin(TAU * 18.0 * t)) * maxf(0.0, sin(TAU * 1.0 * t / dur * 4.0))
			v += chirp * 0.03
		s[i] = v
	return s

func _hum(dur: float, amp: float) -> PackedFloat32Array:
	var s := _buf(dur)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		lp = lerpf(lp, _n(), 0.02)
		var flick := 1.0 + 0.3 * sin(TAU * t / dur * 7.0)
		s[i] = (sin(TAU * 60.0 * t) * 0.5 + sin(TAU * 120.0 * t) * 0.3 + sin(TAU * 180.0 * t) * 0.1 * flick + lp * 2.5) * amp
	return s

func _drone(dur: float) -> PackedFloat32Array:
	var s := _buf(dur)
	for i in s.size():
		var t := float(i) / RATE
		var beat := sin(TAU * 0.5 * t / dur * 2.0)
		s[i] = (sin(TAU * 55.0 * t) * 0.4 + sin(TAU * 55.5 * t) * 0.3 + sin(TAU * 82.5 * t) * 0.15 * beat + _n() * 0.02) * 0.4
	return s

func _engine() -> PackedFloat32Array:
	var s := _buf(0.5)
	var lp := 0.0
	for i in s.size():
		var t := float(i) / RATE
		var saw := fmod(t * 50.0, 1.0) * 2.0 - 1.0
		var saw2 := fmod(t * 100.0, 1.0) * 2.0 - 1.0
		lp = lerpf(lp, saw * 0.7 + saw2 * 0.3 + _n() * 0.2, 0.25)
		var putt := 0.7 + 0.3 * absf(sin(TAU * 25.0 * t))
		s[i] = lp * putt * 0.6
	return s
