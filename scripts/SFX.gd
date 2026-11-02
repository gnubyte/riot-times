extends Node
# Procedural sound effects — everything synthesized at load, no assets.

const RATE := 22050
var cache := {}
var players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)

func _gen(sname: String) -> AudioStreamWAV:
	if cache.has(sname):
		return cache[sname]
	var f := AudioStreamWAV.new()
	f.format = AudioStreamWAV.FORMAT_16_BITS
	f.mix_rate = RATE
	f.stereo = false
	match sname:
		"shot_pistol": f.data = _gunshot(0.14, 0.9, 1400.0)
		"shot_smg": f.data = _gunshot(0.1, 0.7, 1800.0)
		"shot_rifle": f.data = _gunshot(0.3, 1.0, 900.0)
		"shot_laser": f.data = _zap()
		"click": f.data = _click()
		"hit_meat": f.data = _thud(120.0, 0.18, 0.8)
		"swing": f.data = _swing()
		"pickup": f.data = _blip(660.0, 880.0, 0.12)
		"hurt": f.data = _thud(80.0, 0.22, 1.0)
		"ui": f.data = _blip(440.0, 520.0, 0.06)
		"levelup": f.data = _fanfare()
		"eat": f.data = _chomp()
		"death": f.data = _death()
		"step": f.data = _step()
		"land": f.data = _land()
		"mantle": f.data = _mantle()
		"mag_out": f.data = _mag_out()
		"mag_in": f.data = _mag_in()
		"shell": f.data = _shell()
		"hurt_flinch": f.data = _thud(140.0, 0.14, 0.9)
		_: f.data = _click()
	f.loop_mode = AudioStreamWAV.LOOP_DISABLED
	cache[sname] = f
	return f

func play(sname: String, vol_db := 0.0, pitch := 1.0) -> void:
	var p := _free_player()
	if p == null:
		return
	p.stream = _gen(sname)
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()

func _free_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	return players[0]

func _sine(ph: float) -> float:
	return sin(ph * TAU)

func _noise() -> float:
	return randf_range(-1.0, 1.0)

func _encode(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		bytes.encode_s16(i * 2, v)
	return bytes

func _gunshot(dur: float, amp: float, tone: float) -> PackedByteArray:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var decay := pow(1.0 - t, 4.0)
		var crack := _noise() * (1.0 - clampf(t * 30.0, 0.0, 1.0))
		var body := _sine(float(i) * tone / float(RATE)) * 0.35 * pow(1.0 - t, 2.0)
		lp = lerpf(lp, _noise(), 0.3)
		s[i] = (crack * 0.8 + body + lp * 0.3) * amp * (decay * 0.6 + 0.4)
	return _encode(s)

func _zap() -> PackedByteArray:
	var n := int(0.22 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var freq: float = lerpf(1800.0, 220.0, t) / float(RATE)
		var w := _sine(float(i) * freq)
		var hum := _sine(float(i) * freq * 1.5) * 0.3
		s[i] = (w + hum + _noise() * 0.1) * pow(1.0 - t, 2.0) * 0.7
	return _encode(s)

func _click() -> PackedByteArray:
	var n := int(0.05 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		s[i] = _noise() * pow(1.0 - t, 8.0) * _sine(float(i) * 2500.0 / float(RATE))
	return _encode(s)

func _thud(freq: float, dur: float, amp: float) -> PackedByteArray:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		s[i] = _sine(float(i) * freq / float(RATE)) * pow(1.0 - t, 3.0) * amp
	return _encode(s)

func _swing() -> PackedByteArray:
	var n := int(0.14 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env := sin(t * PI)
		lp = lerpf(lp, _noise(), 0.06)
		s[i] = lp * env * 0.9
	return _encode(s)

func _blip(f0: float, f1: float, dur: float) -> PackedByteArray:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var freq: float = lerpf(f0, f1, t) / float(RATE)
		s[i] = _sine(float(i) * freq) * (1.0 - t) * 0.5
	return _encode(s)

func _chomp() -> PackedByteArray:
	var n := int(0.16 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var gate := 1.0 if int(t * 3.0) % 2 == 0 else 0.2
		lp = lerpf(lp, _noise(), 0.25)
		s[i] = lp * gate * (1.0 - t) * 0.7
	return _encode(s)

func _fanfare() -> PackedByteArray:
	var n := int(0.7 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var notes := [523.25, 659.25, 784.0, 1046.5]
	for i in n:
		var t := float(i) / float(n)
		var idx := clampi(int(t * notes.size()), 0, notes.size() - 1)
		var freq: float = notes[idx] / float(RATE)
		var local := t * float(notes.size()) - float(idx)
		var env := 1.0 - clampf(local, 0.0, 1.0) * 0.6
		s[i] = (_sine(float(i) * freq) + _sine(float(i) * freq * 2.0) * 0.3) * env * 0.4 * (1.0 - t * 0.5)
	return _encode(s)

func _death() -> PackedByteArray:
	var n := int(0.6 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var freq: float = lerpf(180.0, 30.0, t) / float(RATE)
		var g := _sine(float(i) * freq)
		lp = lerpf(lp, _noise(), 0.1)
		s[i] = (g * 0.8 + lp * 0.3) * pow(1.0 - t, 1.5) * 0.9
	return _encode(s)

# dust-boot scuff for footsteps
func _step() -> PackedByteArray:
	var n := int(0.06 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		lp = lerpf(lp, _noise(), 0.35)
		s[i] = lp * pow(1.0 - t, 2.5) * 0.35
	return _encode(s)

# heavier boot thud on landing
func _land() -> PackedByteArray:
	var n := int(0.12 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var thud := _sine(float(i) * 70.0 / float(RATE)) * pow(1.0 - t, 2.0)
		lp = lerpf(lp, _noise(), 0.3)
		s[i] = (thud * 0.7 + lp * 0.4) * pow(1.0 - t, 1.5) * 0.8
	return _encode(s)

# cloth/scuff effort for mantling
func _mantle() -> PackedByteArray:
	var n := int(0.22 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env := sin(t * PI)
		lp = lerpf(lp, _noise(), 0.12)
		var grunt := _sine(float(i) * lerpf(160.0, 110.0, t) / float(RATE)) * 0.25
		s[i] = (lp * 0.6 + grunt) * env * 0.7
	return _encode(s)

# metallic magazine drop
func _mag_out() -> PackedByteArray:
	var n := int(0.1 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var ping := _sine(float(i) * 2100.0 / float(RATE)) * 0.3 + _sine(float(i) * 900.0 / float(RATE)) * 0.3
		s[i] = ping * pow(1.0 - t, 6.0) * (1.0 - t * 0.3)
	return _encode(s)

# magazine seat click
func _mag_in() -> PackedByteArray:
	var n := int(0.09 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var click := _noise() * pow(1.0 - t, 14.0) * 0.8
		var body := _sine(float(i) * 1500.0 / float(RATE)) * pow(1.0 - t, 4.0) * 0.4
		s[i] = click + body
	return _encode(s)

# tiny brass tink on the floor
func _shell() -> PackedByteArray:
	var n := int(0.14 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / float(n)
		var f1 := _sine(float(i) * 3400.0 / float(RATE))
		var f2 := _sine(float(i) * 5100.0 / float(RATE))
		s[i] = (f1 * 0.5 + f2 * 0.3) * pow(1.0 - t, 5.0) * 0.35
	return _encode(s)
