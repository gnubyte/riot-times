class_name InputSetup
extends RefCounted
# Builds the whole InputMap in code: keyboard/mouse + gamepad (Xbox layout).
# Pad X is shared: tap = reload, hold = interact (CoD-style) — Player resolves it.

const MOVE_DEADZONE := 0.18
const TRIGGER_DEADZONE := 0.25

static func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	return e

static func _mb(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e

static func _jb(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1   # any pad
	return e

static func _ja(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e

static func setup() -> void:
	var acts := {
		"move_forward": [_key(KEY_W), _ja(JOY_AXIS_LEFT_Y, -1.0)],
		"move_back": [_key(KEY_S), _ja(JOY_AXIS_LEFT_Y, 1.0)],
		"move_left": [_key(KEY_A), _ja(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _ja(JOY_AXIS_LEFT_X, 1.0)],
		"jump": [_key(KEY_SPACE), _jb(JOY_BUTTON_A)],
		"sprint": [_key(KEY_SHIFT), _jb(JOY_BUTTON_LEFT_STICK)],
		"crouch": [_key(KEY_C), _key(KEY_CTRL), _jb(JOY_BUTTON_B)],
		"fire": [_mb(MOUSE_BUTTON_LEFT), _ja(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"ads": [_mb(MOUSE_BUTTON_RIGHT), _ja(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"reload": [_key(KEY_R)],
		"interact": [_key(KEY_E)],
		"pad_x": [_jb(JOY_BUTTON_X)],
		"melee": [_key(KEY_V), _mb(MOUSE_BUTTON_XBUTTON1), _jb(JOY_BUTTON_RIGHT_STICK)],
		"swap": [_key(KEY_Q), _jb(JOY_BUTTON_Y)],
		"slot_1": [_key(KEY_1)],
		"slot_2": [_key(KEY_2)],
		"next_weapon": [_mb(MOUSE_BUTTON_WHEEL_DOWN)],
		"prev_weapon": [_mb(MOUSE_BUTTON_WHEEL_UP)],
		"throw": [_key(KEY_G), _jb(JOY_BUTTON_RIGHT_SHOULDER)],
		"heal": [_key(KEY_H), _jb(JOY_BUTTON_LEFT_SHOULDER)],
		"flashlight": [_key(KEY_F), _jb(JOY_BUTTON_DPAD_UP)],
		"cycle_throwable": [_key(KEY_T), _jb(JOY_BUTTON_DPAD_DOWN)],
		"horn": [_key(KEY_B), _jb(JOY_BUTTON_DPAD_LEFT)],
		"menu": [_key(KEY_TAB), _key(KEY_I), _jb(JOY_BUTTON_BACK)],
		"pause": [_key(KEY_ESCAPE), _jb(JOY_BUTTON_START)],
		"tab_prev": [_jb(JOY_BUTTON_LEFT_SHOULDER), _key(KEY_Z)],
		"tab_next": [_jb(JOY_BUTTON_RIGHT_SHOULDER), _key(KEY_X)],
	}
	for a in acts:
		var dz := 0.5
		if a.begins_with("move_"):
			dz = MOVE_DEADZONE
		elif a == "fire" or a == "ads":
			dz = TRIGGER_DEADZONE
		if InputMap.has_action(a):
			InputMap.action_erase_events(a)
			InputMap.action_set_deadzone(a, dz)
		else:
			InputMap.add_action(a, dz)
		for ev in acts[a]:
			InputMap.action_add_event(a, ev)
	# menus: let the stick and d-pad drive focus, A/B accept/cancel (Godot defaults
	# already include the d-pad; add the left stick for comfort)
	_add_if_missing("ui_up", _ja(JOY_AXIS_LEFT_Y, -1.0))
	_add_if_missing("ui_down", _ja(JOY_AXIS_LEFT_Y, 1.0))
	_add_if_missing("ui_left", _ja(JOY_AXIS_LEFT_X, -1.0))
	_add_if_missing("ui_right", _ja(JOY_AXIS_LEFT_X, 1.0))

static func _add_if_missing(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and ev is InputEventJoypadMotion \
				and e.axis == ev.axis and signf(e.axis_value) == signf(ev.axis_value):
			return
	InputMap.action_add_event(action, ev)

# Right stick, raw. Radial deadzone + response curve are applied by the Player.
static func right_stick() -> Vector2:
	var v := Vector2.ZERO
	for d in Input.get_connected_joypads():
		var s := Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
		if s.length() > v.length():
			v = s
	return v

# Button glyph for prompts, following the last-used device.
static func glyph(action: String) -> String:
	if GameData.input_mode == "pad":
		match action:
			"interact": return "Hold X"
			"reload": return "X"
			"jump": return "A"
			"crouch": return "B"
			"swap": return "Y"
			"melee": return "R3"
			"sprint": return "L3"
			"throw": return "RB"
			"heal": return "LB"
			"flashlight": return "D-pad ↑"
			"menu": return "View"
			"pause": return "Menu"
			"fire": return "RT"
			"ads": return "LT"
			"horn": return "D-pad ←"
			"accept": return "A"
			"back": return "B"
		return action
	match action:
		"interact": return "E"
		"reload": return "R"
		"jump": return "Space"
		"crouch": return "C"
		"swap": return "Q"
		"melee": return "V"
		"sprint": return "Shift"
		"throw": return "G"
		"heal": return "H"
		"flashlight": return "F"
		"menu": return "Tab"
		"pause": return "Esc"
		"fire": return "LMB"
		"ads": return "RMB"
		"horn": return "B"
		"accept": return "Enter"
		"back": return "Esc"
	return action
