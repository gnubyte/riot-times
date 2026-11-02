extends Node
# Scene manager: TITLE -> CREATOR -> LOADING (world build) -> GAME, pause + settings.
# One life: CONTINUE resumes the living survivor; death sends you back here to start
# a new one in the same, persistent world.

enum Mode { TITLE, CREATOR, GAME, PAUSE, SETTINGS, LOADING }

var mode := Mode.TITLE
var title_ui: Control
var creator_ui: Control
var game_world: World = null
var creator: CharacterCreator = null
var pause_menu: Control = null
var settings_menu: SettingsMenu = null
var loading: LoadingScreen = null
var _fps_probe: Timer = null
var _shots := false
var _shot_t := 0.0
var _shot_n := 0
var _quit_after := 0.0

var art_sky: Texture2D
var art_skyline: Texture2D
var art_grain: Texture2D
var art_vignette: Texture2D

# ---------- mouse capture ----------
# Windows drops the cursor clip on focus loss; re-grab only while actually playing.
func _want_mouse_capture() -> bool:
	if mode != Mode.GAME or get_tree().paused or settings_menu != null:
		return false
	if not GameData.alive:
		return false
	if game_world and game_world.hud:
		var hud: GameHUD = game_world.hud
		if (hud.menu != null and hud.menu.visible) or hud.death.visible:
			return false
	return true

func _process(delta: float) -> void:
	if _want_mouse_capture() and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _shots and mode == Mode.GAME:
		_shot_t -= delta
		if _shot_t <= 0.0:
			_shot_t = 2.5
			_screenshot()
	if _quit_after > 0.0 and mode == Mode.GAME:
		_quit_after -= delta
		if _quit_after <= 0.0:
			get_tree().quit()

func _on_window_focus_entered() -> void:
	if _want_mouse_capture():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_now()

func _save_now() -> void:
	if mode in [Mode.GAME, Mode.PAUSE] and GameData.alive and game_world != null:
		game_world.save_vehicles()
		GameData.autosave()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.setup()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_window().focus_entered.connect(_on_window_focus_entered)
	GameData.show_title.connect(_on_show_title)
	_shots = OS.get_environment("RT_DEBUG_SHOTS") == "1"
	_quit_after = OS.get_environment("RT_DEBUG_QUIT_AFTER").to_float()
	if OS.get_environment("RT_DEBUG_FPS") == "1":
		_fps_probe = Timer.new()
		_fps_probe.wait_time = 2.0
		_fps_probe.autostart = true
		_fps_probe.timeout.connect(func():
			var chasing := 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if m.state == "chase":
					chasing += 1
			print("RTFPS %.1f  draw=%d  objs=%d  proc=%.1fms  phys=%.1fms  mons=%d chase=%d nodes=%d" % [Engine.get_frames_per_second(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
				get_tree().get_nodes_in_group("monsters").size(), chasing, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]))
		add_child(_fps_probe)
	_generate_art()
	_build_title()
	if OS.get_environment("RT_DEBUG_AUTOSTART") == "1":
		_clear_title()
		if GameData.has_survivor() and OS.get_environment("RT_DEBUG_FRESH") != "1":
			_start_game(true)
		else:
			GameData.start_new("Tester", OS.get_environment("RT_DEBUG_BG") if OS.get_environment("RT_DEBUG_BG") != "" else "soldier", {})
			if OS.get_environment("RT_DEBUG_TIME") != "":
				GameData.world["time"] = OS.get_environment("RT_DEBUG_TIME").to_float()
			_start_game(false)

func _generate_art() -> void:
	art_sky = UIArt.sky_texture(800, 450)
	art_skyline = UIArt.skyline_texture(800, 210, 0)
	art_grain = UIArt.grain_texture(0.06)
	art_vignette = UIArt.vignette_texture(400, 225)

# Track the last device used so prompts and aim assist follow it.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		GameData.input_mode = "pad"
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 3.0):
		GameData.input_mode = "kbm"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if settings_menu != null:
			return
		if mode == Mode.GAME and not GameData.alive:
			return
		match mode:
			Mode.PAUSE: _resume()
			Mode.GAME: _pause()
			_: pass

func _mk_button(text: String, size := Vector2(360, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): SFX.play("ui", -14.0, 1.3))
	b.focus_entered.connect(func(): SFX.play("ui", -16.0, 1.4))
	b.pressed.connect(func(): SFX.play("click", -8.0))
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.36, 0.24, 0.1, 0.96)
	fs.border_color = Color(1.0, 0.8, 0.35)
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(6)
	fs.set_content_margin_all(14)
	b.add_theme_stylebox_override("focus", fs)
	UIFX.bezzle(b)
	return b

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

func _clear_title() -> void:
	if title_ui and is_instance_valid(title_ui):
		title_ui.queue_free()
	title_ui = null

# ---------------- TITLE ----------------
func _build_title() -> void:
	mode = Mode.TITLE
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_clear_title()
	title_ui = Control.new()
	title_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_ui.theme = UITheme.theme
	add_child(title_ui)
	_build_backdrop(title_ui)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-260, -330)
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 6)
	title_ui.add_child(box)
	var t := Label.new()
	t.text = "RIOT TIMES"
	t.add_theme_font_size_override("font_size", 90)
	t.add_theme_color_override("font_color", Color(0.96, 0.68, 0.2))
	t.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.0, 0.9))
	t.add_theme_constant_override("shadow_offset_x", 4)
	t.add_theme_constant_override("shadow_offset_y", 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var tt := t.create_tween().set_loops()
	tt.tween_property(t, "modulate", Color(1.15, 1.05, 0.95), 1.6)
	tt.tween_property(t, "modulate", Color(0.92, 0.9, 0.95), 1.6)
	var sub := Label.new()
	sub.text = "— survive the dead · loot the ruins · one life —"
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color(0.82, 0.72, 0.56))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 22)
	box.add_child(spacer)
	var pc := PanelContainer.new()
	box.add_child(pc)
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", 12)
	pc.add_child(mcol)
	var first: Button = null
	if GameData.has_survivor():
		var peek := _peek_survivor()
		var b_cont := _mk_button("CONTINUE — %s" % peek, Vector2(480, 56))
		b_cont.pressed.connect(func():
			_clear_title()
			_start_game(true))
		mcol.add_child(b_cont)
		first = b_cont
	var b_new := _mk_button("NEW SURVIVOR", Vector2(480, 52))
	b_new.pressed.connect(func():
		if GameData.has_survivor():
			_confirm_abandon()
		else:
			_clear_title()
			_build_creator())
	mcol.add_child(b_new)
	if first == null:
		first = b_new
	var b_set := _mk_button("SETTINGS", Vector2(480, 52))
	b_set.pressed.connect(func(): _open_settings(func(): _build_title()))
	mcol.add_child(b_set)
	var b_q := _mk_button("QUIT", Vector2(480, 52))
	b_q.pressed.connect(func(): get_tree().quit())
	mcol.add_child(b_q)
	var fallen: int = GameData.world.get("memorial", []).size()
	var info := Label.new()
	info.text = "World day %d  ·  %d fallen survivor%s  ·  %d grave%s waiting" % [GameData.day(), fallen, "" if fallen == 1 else "s", GameData.world.get("graves", []).size(), "" if GameData.world.get("graves", []).size() == 1 else "s"]
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.75, 0.68, 0.58))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)
	var hint := Label.new()
	hint.text = "Controller or keyboard & mouse. Controls are in Settings → Controls."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.62, 0.58, 0.5))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var ver := Label.new()
	ver.text = "v2.0 — the dead hear everything"
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-280, -34)
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.55, 0.5, 0.42))
	title_ui.add_child(ver)
	first.call_deferred("grab_focus")

func _peek_survivor() -> String:
	var f := FileAccess.open(GameData.SURVIVOR_PATH, FileAccess.READ)
	if f == null:
		return "survivor"
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return "survivor"
	return "%s, Lv %d %s" % [d.get("name", "?"), int(d.get("level", 1)), GameData.BACKGROUNDS.get(d.get("background", ""), {}).get("name", "")]

func _confirm_abandon() -> void:
	var dlg := PanelContainer.new()
	dlg.set_anchors_preset(Control.PRESET_CENTER)
	dlg.position = Vector2(-280, -110)
	dlg.custom_minimum_size = Vector2(560, 0)
	title_ui.add_child(dlg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	dlg.add_child(v)
	var l := Label.new()
	l.text = "Abandon %s?\nThey walk into the wastes and are never seen again." % _peek_survivor()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var yes := _mk_button("ABANDON & START OVER", Vector2(520, 50))
	yes.pressed.connect(func():
		GameData.load_survivor()
		GameData.player_pos = World.HAVEN + Vector3(0, 0.5, 10)
		GameData.die("the open road")
		_clear_title()
		_build_creator())
	v.add_child(yes)
	var no := _mk_button("KEEP PLAYING THEM", Vector2(520, 50))
	no.pressed.connect(func(): dlg.queue_free())
	v.add_child(no)
	no.call_deferred("grab_focus")

func _open_settings(on_close: Callable) -> void:
	_close_settings()
	settings_menu = SettingsMenu.new(on_close)
	settings_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(settings_menu)
	settings_menu.closed.connect(func():
		settings_menu = null
		if game_world != null and game_world.player != null:
			game_world.player.apply_settings()
		if on_close.is_valid():
			on_close.call())

func _close_settings() -> void:
	if settings_menu:
		settings_menu.queue_free()
		settings_menu = null

func _on_show_title() -> void:
	_close_settings()
	_save_now()
	get_tree().paused = false
	Engine.time_scale = 1.0
	if loading:
		loading.queue_free()
		loading = null
	if pause_menu and is_instance_valid(pause_menu):
		pause_menu.queue_free()
		pause_menu = null
	if game_world:
		game_world.queue_free()
		game_world = null
	SFX.ambience("")
	SFX.engine_loop(false)
	if GameData.alive:
		_build_title()
	else:
		_build_creator()

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
	Engine.time_scale = 1.0
	loading = LoadingScreen.new()
	add_child(loading)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var t0 := Time.get_ticks_msec()
	await get_tree().process_frame
	if load_save:
		GameData.load_survivor()
	loading.set_progress(0.05)
	var names: Array = SFX.ALL + SFX.LOOPS
	for i in names.size():
		SFX.warm(names[i])
		if i % 6 == 0:
			loading.set_progress(0.05 + 0.2 * float(i) / names.size())
			await get_tree().process_frame
	game_world = World.new()
	add_child(game_world)
	await game_world.build(func(p: float): loading.set_progress(0.25 + p * 0.75))
	var wait := 1.2 - (Time.get_ticks_msec() - t0) / 1000.0
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	await get_tree().process_frame
	if loading:
		loading.finish_and_free()
		loading = null
	mode = Mode.GAME
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_build_pause_menu()
	if not load_save:
		GameData.banner("HAVEN", "%s steps out of the bunkhouse. Day %d. Make it count." % [GameData.char_name, GameData.day()], Color(1.0, 0.85, 0.45))
	else:
		GameData.banner("WELCOME BACK", "Day %d, %02d:%02d." % [GameData.day(), int(GameData.time_of_day()), int(fmod(GameData.time_of_day(), 1.0) * 60.0)], Color(1.0, 0.85, 0.45))

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
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(380, 0)
	pc.position = Vector2(-190, -200)
	pause_menu.add_child(pc)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pc.add_child(box)
	var t := Label.new()
	t.text = "PAUSED"
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var b_res := _mk_button("RESUME", Vector2(340, 48))
	b_res.name = "Resume"
	b_res.pressed.connect(_resume)
	box.add_child(b_res)
	var b_set := _mk_button("SETTINGS", Vector2(340, 48))
	b_set.pressed.connect(func():
		pause_menu.visible = false
		_open_settings(Callable(func():
			if mode == Mode.GAME or mode == Mode.PAUSE:
				_pause())))
	box.add_child(b_set)
	var b_title := _mk_button("SAVE & QUIT TO TITLE", Vector2(340, 48))
	b_title.pressed.connect(func(): GameData.show_title.emit())
	box.add_child(b_title)
	var b_quit := _mk_button("SAVE & QUIT GAME", Vector2(340, 48))
	b_quit.pressed.connect(func():
		_save_now()
		get_tree().quit())
	box.add_child(b_quit)

func _pause() -> void:
	mode = Mode.PAUSE
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_build_pause_menu()
	if pause_menu:
		pause_menu.visible = true
		var r := pause_menu.find_child("Resume", true, false) as Button
		if r:
			r.call_deferred("grab_focus")

func _resume() -> void:
	mode = Mode.GAME
	if pause_menu:
		pause_menu.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---------------- dev: auto screenshots ----------------
func _screenshot() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("user://shots")
	var p := "user://shots/shot_%02d.png" % _shot_n
	img.save_png(p)
	print("RTSHOT ", ProjectSettings.globalize_path(p))
	_shot_n += 1
