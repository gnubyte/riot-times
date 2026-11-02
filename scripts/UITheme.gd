extends Node
# UITheme — global theme, font smoothing, audio buses and persisted settings.

var theme: Theme
var settings := {
	"master_volume": 1.0,
	"sfx_volume": 1.0,
	"window_mode": "windowed",     # windowed | borderless | fullscreen
	"resolution": "",               # "WxH" or "" = desktop
	"vsync": true,
	"fps_target": 0,               # 0 = unlocked, else 60/75/90/120
	"res_scale": 1.0,              # 3D render scale 0.5..1.0
	"quality": "high",             # low | medium | high (shadows/particles/AA)
	"mouse_sens": 1.0,
	"pad_sens": 1.0,
	"ads_mul": 0.85,               # aim-down-sights sensitivity (relative to zoom)
	"invert_y": false,
	"aim_assist": true,            # controller only
	"aa_strength": 1.0,
	"fov": 80.0,
	"vibration": true,
	"damage_numbers": true,
}

const SAVE_PATH := "user://ui_settings.cfg"

func _ready() -> void:
	_setup_buses()
	load_settings()
	theme = _build_theme()
	_apply_settings()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
	# send every SFX player (2D, 3D, ambience) to the SFX bus
	SFX.set_bus("SFX")

func master_volume(v: float) -> void:
	settings.master_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, settings.master_volume)))
	save_settings()

func sfx_volume(v: float) -> void:
	settings.sfx_volume = clampf(v, 0.0, 1.0)
	var idx := AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, settings.sfx_volume)))
	save_settings()

func set_setting(key: String, v) -> void:
	settings[key] = v
	save_settings()

func set_window_mode(m: String) -> void:
	settings.window_mode = m
	_apply_window()
	save_settings()

func set_resolution(res: String) -> void:
	settings.resolution = res
	_apply_window()
	save_settings()

func set_vsync(on: bool) -> void:
	settings.vsync = on
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)
	save_settings()

func set_fps_target(fps: int) -> void:
	settings.fps_target = fps
	_apply_perf()
	save_settings()

func set_res_scale(v: float) -> void:
	settings.res_scale = clampf(v, 0.5, 1.0)
	_apply_perf()
	save_settings()

func set_quality(q: String) -> void:
	settings.quality = q
	_apply_perf()
	save_settings()

func _apply_perf() -> void:
	Engine.max_fps = maxi(0, int(settings.fps_target))
	var root := get_tree().root if is_inside_tree() else null
	if root == null:
		return
	var scale := clampf(settings.res_scale, 0.5, 1.0)
	# dev tool: RT_DEBUG_SCALE forces supersampling (used to measure 4K pixel cost)
	var dev_scale := OS.get_environment("RT_DEBUG_SCALE").to_float()
	if dev_scale > 1.0:
		scale = dev_scale
	root.scaling_3d_scale = scale
	# FSR keeps 4K crisp even at reduced internal resolution
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	match String(settings.quality):
		"low":
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			root.use_debanding = false
		"medium":
			root.msaa_3d = Viewport.MSAA_DISABLED
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		_:
			root.msaa_3d = Viewport.MSAA_2X
			root.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA

func available_resolutions() -> Array[String]:
	var out: Array[String] = ["Desktop"]
	var seen := {}
	for r in [Vector2i(3840, 2160), Vector2i(2560, 1440), Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1440, 900), Vector2i(1366, 768), Vector2i(1280, 720)]:
		var s := "%dx%d" % [r.x, r.y]
		if not seen.has(s):
			seen[s] = true
			out.append(s)
	return out

func _apply_window() -> void:
	var win := get_window()
	match settings.window_mode:
		"fullscreen":
			win.mode = Window.MODE_FULLSCREEN
		"borderless":
			win.mode = Window.MODE_WINDOWED
			win.borderless = true
			var scr := DisplayServer.screen_get_size()
			win.size = scr
			win.position = Vector2i.ZERO
		_:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			if settings.resolution != "" and settings.resolution != "Desktop":
				var parts: Array = settings.resolution.split("x")
				if parts.size() == 2:
					win.size = Vector2i(int(parts[0]), int(parts[1]))

func _apply_settings() -> void:
	master_volume(settings.master_volume)
	sfx_volume(settings.sfx_volume)
	_apply_window()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	_apply_perf()

func save_settings() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			if settings.has(k):
				settings[k] = data[k]

# ---------- theme ----------
func _build_theme() -> Theme:
	var t := Theme.new()
	# smooth text: anti-aliased every pixel, quarter-pixel subpixel positioning, kerning
	var f := ThemeDB.fallback_font
	if f is FontFile:
		var ff := f as FontFile
		ff.antialiasing = 1 # FONT_ANTIALIASING_EVERY_PIXEL
		ff.hinting = 2     # FONT_HINTING_NORMAL
		ff.subpixel_positioning = 2 # SUBPIXEL_POSITIONING_ONE_QUARTER
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 17
	t.set_color("font_color", "Label", Color(0.88, 0.85, 0.78))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_font_size("font_size", "Label", 17)

	# BUTTON
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.12, 0.08, 0.92)
	sb.border_color = Color(0.72, 0.5, 0.22, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_offset = Vector2(0, 3)
	t.set_stylebox("normal", "Button", sb)
	var hov := sb.duplicate()
	hov.bg_color = Color(0.32, 0.22, 0.1, 0.96)
	hov.border_color = Color(0.98, 0.75, 0.32)
	t.set_stylebox("hover", "Button", hov)
	var pres := sb.duplicate()
	pres.bg_color = Color(0.45, 0.3, 0.12)
	pres.border_color = Color(1.0, 0.85, 0.45)
	t.set_stylebox("pressed", "Button", pres)
	var dis := sb.duplicate()
	dis.bg_color = Color(0.12, 0.11, 0.1, 0.7)
	dis.border_color = Color(0.35, 0.32, 0.28, 0.6)
	t.set_stylebox("disabled", "Button", dis)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.95, 0.9, 0.8))
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.7))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.44))
	t.set_color("font_shadow_color", "Button", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Button", 1)
	t.set_constant("shadow_offset_y", "Button", 1)
	t.set_font_size("font_size", "Button", 18)

	# PANELS
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.08, 0.06, 0.94)
	panel.border_color = Color(0.6, 0.42, 0.2)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(16)
	panel.shadow_size = 10
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_offset = Vector2(0, 4)
	t.set_stylebox("panel", "PanelContainer", panel)

	# PROGRESS
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.06, 0.8)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.4, 0.32, 0.22)
	t.set_stylebox("background", "ProgressBar", bg)

	# LINE EDIT
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.14, 0.12, 0.1, 0.95)
	le.border_color = Color(0.6, 0.45, 0.25)
	le.set_border_width_all(1)
	le.set_corner_radius_all(4)
	le.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", le)
	var lef := le.duplicate()
	lef.border_color = Color(0.98, 0.75, 0.32)
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", Color(0.95, 0.9, 0.8))

	# HSLIDER
	var grab_area := StyleBoxFlat.new()
	grab_area.bg_color = Color(0.85, 0.6, 0.22)
	grab_area.set_corner_radius_all(5)
	grab_area.set_content_margin_all(6)
	t.set_stylebox("grabber_area", "HSlider", grab_area)
	var grab_area_hl := grab_area.duplicate()
	grab_area_hl.bg_color = Color(0.98, 0.75, 0.32)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab_area_hl)
	var slot := StyleBoxFlat.new()
	slot.bg_color = Color(0.14, 0.12, 0.1)
	slot.border_color = Color(0.45, 0.36, 0.24)
	slot.set_border_width_all(1)
	slot.set_corner_radius_all(5)
	slot.set_content_margin_all(6)
	t.set_stylebox("slider", "HSlider", slot)
	var gg := StyleBoxFlat.new()
	gg.bg_color = Color(0.95, 0.9, 0.8)
	gg.set_corner_radius_all(9)
	gg.set_content_margin_all(10)
	t.set_stylebox("grabber", "HSlider", gg)
	var gg_hl := gg.duplicate()
	gg_hl.bg_color = Color(1, 0.85, 0.5)
	t.set_stylebox("grabber_highlight", "HSlider", gg_hl)
	t.set_constant("center_grabber", "HSlider", 1)

	# CHECKBOX
	t.set_color("checkbox_color", "CheckBox", Color(0.9, 0.7, 0.3))
	t.set_font_size("font_size", "CheckBox", 17)
	return t
