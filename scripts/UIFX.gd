class_name UIFX
extends RefCounted
# Motion + button juice: springy hover "bezzle", press punch, and the timed
# reveals (pop-in, cascades, glow pulses) that give menus their rhythm.

# Scale+fade pop-in with a slight back-overshoot. delay staggers cascades.
static func pop_in(c: Control, delay := 0.0, dur := 0.22) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.92, 0.92)
	c.modulate.a = 0.0
	var t := c.create_tween()
	t.tween_interval(delay)
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, dur)
	t.parallel().tween_property(c, "modulate:a", 1.0, dur * 0.7)

# Staggered reveal of a container's children (cap so long lists stay snappy).
static func cascade(box: Node, step := 0.03, cap := 14) -> void:
	var i := 0
	for c in box.get_children():
		if c is Control:
			pop_in(c, mini(i, cap) * step)
			i += 1

# Gentle breathing glow loop — tint pulses toward col.
static func glow_pulse(c: Control, col: Color, period := 1.8, strength := 0.25) -> void:
	if c == null or not c.is_inside_tree():
		return
	var t := c.create_tween().set_loops()
	t.tween_property(c, "modulate", Color(1, 1, 1).lerp(col, strength), period * 0.5)
	t.tween_property(c, "modulate", Color(1, 1, 1), period * 0.5)

# One-shot text flash used for stat popups.
static func flash(c: CanvasItem, dur := 0.9) -> void:
	if c == null:
		return
	c.modulate.a = 1.0
	var t := c.create_tween()
	t.tween_interval(dur * 0.55)
	t.tween_property(c, "modulate:a", 0.0, dur * 0.45)

static func bezzle(c: Control) -> void:
	if c.has_meta("bz"):
		return
	c.set_meta("bz", true)
	c.mouse_entered.connect(_hover.bind(c))
	c.mouse_exited.connect(_unhover.bind(c))
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	if c is Button:
		(c as Button).button_down.connect(_press.bind(c))
		(c as Button).button_up.connect(_release.bind(c))

static func _hover(c: Control) -> void:
	# update pivot now in case layout changed silently
	c.pivot_offset = c.size * 0.5
	if not c.has_meta("bz_base"):
		c.set_meta("bz_base", c.modulate)
	_pulse(c, Vector2(1.06, 1.06), 0.14, 0.012, 1.09)

static func _unhover(c: Control) -> void:
	var base: Color = c.get_meta("bz_base") if c.has_meta("bz_base") else Color(1, 1, 1)
	_pulse_to(c, Vector2.ONE, 0.22, 0.0, base)

static func _press(c: Control) -> void:
	_pulse(c, Vector2(0.95, 0.95), 0.07, 0.0, 0.97)

static func _release(c: Control) -> void:
	# springy overshoot back
	c.pivot_offset = c.size * 0.5
	_pulse(c, Vector2(1.04, 1.04), 0.1, 0.02, 1.06)
	var t2 := c.create_tween()
	t2.tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_keep(c, t2)

static func _pulse(c: Control, sc: Vector2, dur: float, wob: float, modu: float) -> void:
	_pulse_to(c, sc, dur, wob, Color(modu, modu, modu * 1.02))

static func _pulse_to(c: Control, sc: Vector2, dur: float, wob: float, col: Color) -> void:
	if c.has_meta("bz_t"):
		var old = c.get_meta("bz_t")
		if old is Tween and old.is_valid():
			old.kill()
	var t := c.create_tween()
	t.set_parallel(true)
	t.tween_property(c, "scale", sc, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "rotation", randf_range(-wob, wob) if wob > 0.0 else 0.0, dur * 1.4)
	t.tween_property(c, "modulate", col, dur)
	_keep(c, t)

static func _keep(c: Control, t: Tween) -> void:
	c.set_meta("bz_t", t)
