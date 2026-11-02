extends CanvasLayer
# Settings screen: VIDEO (window mode, resolution, vsync) + AUDIO (master/sfx) tabs.

class_name SettingsMenu

signal closed

var root: Control
var video_box: VBoxContainer
var perf_box: VBoxContainer
var audio_box: VBoxContainer
var mode_buttons := {}
var fps_buttons := {}
var quality_buttons := {}
var res_scale_slider: HSlider
var res_option: OptionButton
var vsync_check: CheckBox
var master_slider: HSlider
var sfx_slider: HSlider
var on_change_cb: Callable = Callable()

func _init(on_change: Callable = Callable()) -> void:
	layer = 20
	on_change_cb = on_change

func _ready() -> void:
	_build()
	_refresh_from_settings()

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.theme
	add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.03, 0.85)
	root.add_child(dim)

	var grain := TextureRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.texture = UIArt.grain_texture(0.05)
	grain.stretch_mode = TextureRect.STRETCH_TILE
	root.add_child(grain)

	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.position = Vector2(-320, -300)
	pc.custom_minimum_size = Vector2(640, 600)
	root.add_child(pc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pc.add_child(col)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	# tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(tabs)
	var tab_video := Button.new()
	tab_video.text = "VIDEO"
	tab_video.custom_minimum_size = Vector2(150, 44)
	var tab_perf := Button.new()
	tab_perf.text = "PERFORMANCE"
	tab_perf.custom_minimum_size = Vector2(190, 44)
	var tab_audio := Button.new()
	tab_audio.text = "AUDIO"
	tab_audio.custom_minimum_size = Vector2(150, 44)
	tabs.add_child(tab_video)
	tabs.add_child(tab_perf)
	tabs.add_child(tab_audio)
	_button_fx(tab_video)
	_button_fx(tab_perf)
	_button_fx(tab_audio)

	video_box = VBoxContainer.new()
	video_box.add_theme_constant_override("separation", 12)
	video_box.custom_minimum_size = Vector2(580, 360)
	col.add_child(video_box)
	perf_box = VBoxContainer.new()
	perf_box.add_theme_constant_override("separation", 12)
	perf_box.custom_minimum_size = Vector2(580, 360)
	perf_box.visible = false
	col.add_child(perf_box)
	audio_box = VBoxContainer.new()
	audio_box.add_theme_constant_override("separation", 12)
	audio_box.custom_minimum_size = Vector2(580, 360)
	audio_box.visible = false
	col.add_child(audio_box)

	func_tab_active(tab_video, true)
	func_tab_active(tab_perf, false)
	func_tab_active(tab_audio, false)
	tab_video.pressed.connect(func():
		video_box.visible = true
		perf_box.visible = false
		audio_box.visible = false
		func_tab_active(tab_video, true)
		func_tab_active(tab_perf, false)
		func_tab_active(tab_audio, false))
	tab_perf.pressed.connect(func():
		video_box.visible = false
		perf_box.visible = true
		audio_box.visible = false
		func_tab_active(tab_video, false)
		func_tab_active(tab_perf, true)
		func_tab_active(tab_audio, false))
	tab_audio.pressed.connect(func():
		video_box.visible = false
		perf_box.visible = false
		audio_box.visible = true
		func_tab_active(tab_video, false)
		func_tab_active(tab_perf, false)
		func_tab_active(tab_audio, true))

	# ---- video controls ----
	video_box.add_child(_section("WINDOW MODE"))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	video_box.add_child(modes)
	for pair in [["Windowed", "windowed"], ["Borderless", "borderless"], ["Fullscreen", "fullscreen"]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.custom_minimum_size = Vector2(180, 42)
		b.pressed.connect(_set_mode.bind(String(pair[1])))
		modes.add_child(b)
		mode_buttons[String(pair[1])] = b
		_button_fx(b)

	video_box.add_child(_section("RESOLUTION  (windowed mode)"))
	res_option = OptionButton.new()
	res_option.custom_minimum_size = Vector2(280, 42)
	for r in UITheme.available_resolutions():
		res_option.add_item(r)
	res_option.item_selected.connect(func(i):
		UITheme.set_resolution(res_option.get_item_text(i))
		_notify_change())
	video_box.add_child(res_option)

	video_box.add_child(_section("V-SYNC"))
	vsync_check = CheckBox.new()
	vsync_check.text = "Enable V-Sync"
	vsync_check.toggled.connect(func(on):
		UITheme.set_vsync(on)
		_notify_change())
	video_box.add_child(vsync_check)

	# ---- performance controls ----
	perf_box.add_child(_section("FRAME RATE TARGET"))
	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 10)
	perf_box.add_child(fps_row)
	for pair in [["60", 60], ["90", 90], ["120", 120], ["UNLOCKED", 0]]:
		var fb := Button.new()
		fb.text = String(pair[0])
		fb.custom_minimum_size = Vector2(130, 42)
		fb.pressed.connect(_set_fps.bind(int(pair[1])))
		fps_row.add_child(fb)
		fps_buttons[int(pair[1])] = fb
		_button_fx(fb)
	perf_box.add_child(_section("3D RESOLUTION SCALE  (lower = faster at 4K)"))
	res_scale_slider = _make_slider(UITheme.settings.res_scale)
	res_scale_slider.min_value = 0.5
	res_scale_slider.value_changed.connect(func(v):
		UITheme.set_res_scale(v)
		_notify_change())
	perf_box.add_child(_slider_row(res_scale_slider))
	perf_box.add_child(_section("QUALITY PRESET"))
	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 10)
	perf_box.add_child(q_row)
	for pair in [["LOW", "low"], ["MEDIUM", "medium"], ["HIGH", "high"]]:
		var qb := Button.new()
		qb.text = String(pair[0])
		qb.custom_minimum_size = Vector2(150, 42)
		qb.pressed.connect(_set_quality.bind(String(pair[1])))
		q_row.add_child(qb)
		quality_buttons[String(pair[1])] = qb
		_button_fx(qb)
	var perf_hint := Label.new()
	perf_hint.text = "For 60–120 FPS at 4K: UNLOCKED or 120 fps + scale 0.75–1.0.\nThe game upscales with FSR so it still looks sharp."
	perf_hint.add_theme_font_size_override("font_size", 13)
	perf_hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
	perf_box.add_child(perf_hint)

	# ---- audio controls ----
	audio_box.add_child(_section("MASTER VOLUME"))
	master_slider = _make_slider(UITheme.settings.master_volume)
	master_slider.value_changed.connect(func(v):
		UITheme.master_volume(v)
		_notify_change())
	audio_box.add_child(_slider_row(master_slider))

	audio_box.add_child(_section("EFFECTS VOLUME"))
	sfx_slider = _make_slider(UITheme.settings.sfx_volume)
	sfx_slider.value_changed.connect(func(v):
		UITheme.sfx_volume(v)
		_notify_change())
	audio_box.add_child(_slider_row(sfx_slider))

	var hint := Label.new()
	hint.text = "Sounds play live as you slide. Settings are saved automatically."
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.48))
	audio_box.add_child(hint)

	# ---- bottom buttons ----
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 48)
	back.pressed.connect(_close)
	row.add_child(back)
	_button_fx(back)

func func_tab_active(b: Button, on: bool) -> void:
	if on:
		b.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
		b.modulate = Color(1.15, 1.05, 0.9)
	else:
		b.remove_theme_color_override("font_color")
		b.modulate = Color(0.8, 0.8, 0.8)

func _close() -> void:
	closed.emit()
	queue_free()

func _make_slider(cur: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = cur
	s.custom_minimum_size = Vector2(430, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

func _slider_row(sl: HSlider) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.add_child(sl)
	var pct := Label.new()
	pct.text = "%d%%" % int(sl.value * 100)
	pct.custom_minimum_size = Vector2(64, 0)
	hbox.add_child(pct)
	sl.value_changed.connect(func(v):
		pct.text = "%d%%" % int(v * 100)
		SFX.play("ui", -18.0, 1.0 + v * 0.6))
	return hbox

func _section(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.78, 0.62, 0.4))
	return l

func _set_mode(m: String) -> void:
	UITheme.set_window_mode(m)
	_refresh_from_settings()
	_notify_change()

func _set_fps(fps: int) -> void:
	UITheme.set_fps_target(fps)
	_refresh_from_settings()
	_notify_change()

func _set_quality(q: String) -> void:
	UITheme.set_quality(q)
	_refresh_from_settings()
	_notify_change()

func _notify_change() -> void:
	if on_change_cb.is_valid():
		on_change_cb.call()

func _button_fx(b: Button) -> void:
	b.mouse_entered.connect(func(): SFX.play("ui", -14.0, 1.2))
	UIFX.bezzle(b)

func _refresh_from_settings() -> void:
	for m in mode_buttons:
		func_tab_active(mode_buttons[m], UITheme.settings.window_mode == m)
	for f in fps_buttons:
		func_tab_active(fps_buttons[f], int(UITheme.settings.fps_target) == int(f))
	for q in quality_buttons:
		func_tab_active(quality_buttons[q], String(UITheme.settings.quality) == String(q))
	var want: String = String(UITheme.settings.resolution)
	if want == "":
		want = "Desktop"
	for i in res_option.item_count:
		if res_option.get_item_text(i) == want:
			res_option.select(i)
			break
	vsync_check.set_pressed_no_signal(bool(UITheme.settings.vsync))
	master_slider.set_value_no_signal(UITheme.settings.master_volume)
	sfx_slider.set_value_no_signal(UITheme.settings.sfx_volume)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
