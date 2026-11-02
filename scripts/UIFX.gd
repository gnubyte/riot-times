class_name UIFX
extends RefCounted
# Button juice: springy hover "bezzle", press punch, focus glow. Attach to any Control.

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
