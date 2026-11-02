extends Node
# Scene manager: TITLE -> CHARACTER CREATOR -> (LOADING) -> GAME, pause + settings.

enum Mode { TITLE, CREATOR, GAME, PAUSE, SETTINGS, LOADING }

# ---------- mouse capture enforcement ----------
# Windows silently drops the OS cursor clip when the window loses focus (alt-tab,
# a popup, the console wrapper stealing activation...). Godot caches mouse_mode and
# early-returns when you re-request the same mode, so after such a focus loss the
# clip never gets re-pushed and mouse-look silently dies. We heal it from the window
# focus signal — never from a timer, because a periodic VISIBLE/CAPTURED flick would
# itself drop motion events mid-drag and make aiming feel broken.
func _want_mouse_capture() -> bool:
	if mode != Mode.GAME or get_tree().paused:
		return false
	if settings_menu != null:
		return false
	if game_world and game_world.hud:
		var hud: CanvasLayer = game_world.hud
		if hud.inv_panel.visible or hud.char_panel.visible or hud.death_panel.visible:
			return false
	if not GameData.alive:
		return false
	return true

func _process(_delta: float) -> void:
	# If the mode silently reverted to VISIBLE (focus loss) while we should be in
	# gameplay, re-grab once. We only ever ADD a capture, never flick it off.
	if _want_mouse_capture() and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_window_focus_entered() -> void:
	# Coming back into focus after a clip-dropping focus loss: force Godot to
	# re-apply the OS clip even though its cached mode already says CAPTURED.
	if _want_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

var mode := Mode.TITLE
var title_ui: Control
var creator_ui: Control
var game_world: World = null
var creator: CharacterCreator = null
var pause_menu: Control = null
var settings_menu: SettingsMenu = null
var loading: LoadingScreen = null
var _fps_probe: Timer = null

# cached art (generated once)
var art_sky: Texture2D
var art_skyline: Texture2D
var art_grain: Texture2D
var art_vignette: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var win := get_window()
	win.focus_entered.connect(_on_window_focus_entered)
	if OS.get_environment("RT_DEBUG_FPS") == "1":
		_fps_probe = Timer.new()
		_fps_probe.wait_time = 2.0
		_fps_probe.autostart = true
		_fps_probe.timeout.connect(func():
			print("RTFPS %.1f" % Engine.get_frames_per_second()))
		add_child(_fps_probe)
	await _generate_art()
	_build_title()
	# dev tool: RT_DEBUG_AUTOSTART=1 jumps straight into the game
	if OS.get_environment("RT_DEBUG_AUTOSTART") == "1":
		if title_ui and is_instance_valid(title_ui):
			title_ui.queue_free()
			title_ui = null
		if GameData.has_save():
			_start_game(true)
		else:
			GameData.start_new("human", "Wanderer", {})
			_start_game(false)

func _generate_art() -> void:
	art_sky = UIArt.sky_texture(800, 450)
	art_skyline = UIArt.skyline_texture(800, 210, 0)
	art_grain = UIArt.grain_texture(0.06)
	art_vignette = UIArt.vignette_texture(400, 225)

func _key(code: int, physical: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = physical
	return e

func _mb(button: int) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e

func _setup_input() -> void:
	var acts := {
		"move_forward": [_key(KEY_W, KEY_W)],
		"move_back": [_key(KEY_S, KEY_S)],
		"move_left": [_key(KEY_A, KEY_A)],
		"move_right": [_key(KEY_D, KEY_D)],
		"jump": [_key(KEY_SPACE, KEY_SPACE)],
		"sprint": [_key(KEY_SHIFT, KEY_SHIFT)],
		"fire": [_mb(MOUSE_BUTTON_LEFT)],
		"ads": [_mb(MOUSE_BUTTON_RIGHT)],
		"reload": [_key(KEY_R, KEY_R)],
		"interact": [_key(KEY_E, KEY_E)],
		"inventory": [_key(KEY_TAB, KEY_TAB), _key(KEY_I, KEY_I)],
		"character": [_key(KEY_C, KEY_C)],
		"pause": [_key(KEY_ESCAPE, KEY_ESCAPE)],
		"slot_gun": [_key(KEY_1, KEY_1)],
		"slot_melee": [_key(KEY_2, KEY_2)],
		"slot_hat": [_key(KEY_3, KEY_3)],
		"slot_armor": [_key(KEY_4, KEY_4)],
	}
	for a in acts:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for ev in acts[a]:
			InputMap.action_add_event(a, ev)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if settings_menu != null:
			return # settings owns ESC while open
		if mode == Mode.GAME and not GameData.alive:
			return # death panel owns the screen when dead
		match mode:
			Mode.PAUSE: _resume()
			Mode.GAME: _pause()
			_: pass

# effective button: hover + click sounds, min size
func _mk_button(text: String, size := Vector2(360, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): SFX.play("ui", -14.0, 1.3))
	b.pressed.connect(func(): SFX.play("click", -8.0))
	UIFX.bezzle(b)
	return b

# shared menu backdrop: sky art + skyline + grain + vignette
func _build_backdrop(parent: Control, dark := true) -> void:
	var sky := TextureRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.texture = art_sky
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if dark:
		sky.modulate = Color(1, 1, 1, 0.75)
	parent.add_child(sky)
	var line := TextureRect.new()
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -190
	line.texture = art_skyline
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(line)
	var grain := TextureRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.texture = art_grain
	grain.stretch_mode = TextureRect.STRETCH_TILE
	parent.add_child(grain)
	var vig := TextureRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.texture = art_vignette
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(vig)

# ---------------- TITLE ----------------
func _build_title() -> void:
	mode = Mode.TITLE
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if title_ui and is_instance_valid(title_ui):
		title_ui.queue_free()
	title_ui = Control.new()
	title_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_ui.theme = UITheme.theme
	add_child(title_ui)
	_build_backdrop(title_ui)

	# big title with layered shadow
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-200, -290)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 6)
	title_ui.add_child(box)

	var t := Label.new()
	t.text = "RIOT TIMES"
	t.add_theme_font_size_override("font_size", 84)
	t.add_theme_color_override("font_color", Color(0.96, 0.68, 0.2))
	t.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.0, 0.9))
	t.add_theme_constant_override("shadow_offset_x", 4)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	# slow pulsing glow on title
	var tt := t.create_tween().set_loops()
	tt.tween_property(t, "modulate", Color(1.15, 1.05, 0.95), 1.6)
	tt.tween_property(t, "modulate", Color(0.92, 0.9, 0.95), 1.6)

	var sub := Label.new()
	sub.text = "— a post-nuclear FPS RPG sandbox —"
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color(0.82, 0.72, 0.56))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	sub.add_theme_constant_override("shadow_offset_y", 2)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	box.add_child(spacer)

	# menu buttons in a themed panel
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(420, 0)
	box.add_child(pc)
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", 12)
	pc.add_child(mcol)

	var b_new := _mk_button("NEW CHARACTER")
	b_new.pressed.connect(func():
		title_ui.queue_free()
		title_ui = null
		_build_creator())
	mcol.add_child(b_new)

	var b_cont := _mk_button("CONTINUE")
	b_cont.disabled = not GameData.has_save()
	b_cont.pressed.connect(func():
		title_ui.queue_free()
		title_ui = null
		_start_game(true))
	mcol.add_child(b_cont)

	var b_set := _mk_button("SETTINGS")
	b_set.pressed.connect(func(): _open_settings(func(): _build_title()))
	mcol.add_child(b_set)

	var b_q := _mk_button("QUIT")
	b_q.pressed.connect(func(): get_tree().quit())
	mcol.add_child(b_q)

	var hint := Label.new()
	hint.text = "WASD move · LShift sprint · Space jump/mantle · Mouse aim\nLMB fire · RMB aim · R/⟳ reload · E interact/take · F flashlight\nTab inventory · C character · 1 gun 2 melee · Esc pause"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.68, 0.64, 0.55))
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	var ver := Label.new()
	ver.text = "v1.0 — stay hydrated, stay rad-free"
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-260, -34)
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	title_ui.add_child(ver)

	GameData.show_title.connect(func():
		_close_settings()
		get_tree().paused = false
		if loading: loading.queue_free(); loading = null
		if game_world:
			game_world.queue_free()
			game_world = null
		_build_title())

func _open_settings(on_close: Callable) -> void:
	_close_settings()
	settings_menu = SettingsMenu.new(on_close)
	settings_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(settings_menu)
	settings_menu.closed.connect(func():
		settings_menu = null
		if on_close.is_valid():
			on_close.call())

func _close_settings() -> void:
	if settings_menu:
		settings_menu.queue_free()
		settings_menu = null

# ---------------- CREATOR ----------------
func _build_creator() -> void:
	mode = Mode.CREATOR
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	creator_ui = Control.new()
	creator_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	creator_ui.theme = UITheme.theme
	add_child(creator_ui)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.1, 0.09, 0.08)
	creator_ui.add_child(bg)
	var grain := TextureRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.texture = art_grain
	grain.stretch_mode = TextureRect.STRETCH_TILE
	creator_ui.add_child(grain)
	creator = CharacterCreator.new()
	creator_ui.add_child(creator)
	creator.done.connect(func(_cfg):
		creator_ui.queue_free()
		creator = null
		_start_game(false))
	creator.back.connect(func():
		creator_ui.queue_free()
		creator = null
		_build_title())

func _start_game(load_save: bool) -> void:
	mode = Mode.LOADING
	get_tree().paused = false
	# loading screen with art while world builds
	loading = LoadingScreen.new()
	add_child(loading)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	loading.set_progress(0.15)
	await get_tree().process_frame
	if load_save:
		GameData.load_game()
	loading.set_progress(0.4)
	await get_tree().process_frame
	game_world = World.new()
	add_child(game_world)
	loading.set_progress(1.0)
	# keep the art on screen a beat so it reads as a real loading screen
	var wait := 1.4 - (Time.get_ticks_msec() - t0) / 1000.0
	if wait > 0.0:
		var tt := create_tween()
		tt.tween_interval(wait)
		await tt.finished
	await get_tree().process_frame
	loading.finish_and_free()
	loading = null
	mode = Mode.GAME
	GameData.respawn_requested.connect(func():
		if game_world and game_world.player:
			game_world.player.revive_at(game_world.respawn_point))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_pause_menu()

# ---------------- PAUSE ----------------
func _build_pause_menu() -> void:
	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.visible = false
		return
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	pause_menu.theme = UITheme.theme
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.015, 0.72)
	pause_menu.add_child(dim)
	var grain := TextureRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.texture = art_grain
	grain.stretch_mode = TextureRect.STRETCH_TILE
	pause_menu.add_child(grain)

	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(360, 0)
	pc.position = Vector2(-180, -220)
	pause_menu.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pc.add_child(box)
	var t := Label.new()
	t.text = "PAUSED"
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	t.add_theme_constant_override("shadow_offset_y", 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b_res := _mk_button("RESUME", Vector2(320, 48))
	b_res.pressed.connect(_resume)
	box.add_child(b_res)
	var b_save := _mk_button("SAVE GAME", Vector2(320, 48))
	b_save.pressed.connect(func():
		if GameData.save_game():
			GameData.game_message("Game saved.", Color(0.6, 1.0, 0.6)))
	box.add_child(b_save)
	var b_set := _mk_button("SETTINGS", Vector2(320, 48))
	b_set.pressed.connect(func():
		pause_menu.visible = false
		_open_settings(Callable(func():
			# returned from settings: show pause again
			if mode == Mode.GAME or mode == Mode.PAUSE:
				_pause())))
	box.add_child(b_set)
	var b_title := _mk_button("QUIT TO TITLE", Vector2(320, 48))
	b_title.pressed.connect(func():
		GameData.show_title.emit())
	box.add_child(b_title)
	var b_quit := _mk_button("QUIT GAME", Vector2(320, 48))
	b_quit.pressed.connect(func(): get_tree().quit())
	box.add_child(b_quit)

func _pause() -> void:
	mode = Mode.PAUSE
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	if game_world and game_world.hud:
		game_world.hud.crosshair.visible = false
	_build_pause_menu()
	if pause_menu: pause_menu.visible = true

func _resume() -> void:
	mode = Mode.GAME
	if pause_menu: pause_menu.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
