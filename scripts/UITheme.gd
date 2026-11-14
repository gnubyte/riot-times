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

	# BUTTON — beveled riveted plates from UIArt
	var sbt := func(state: int, cm := Vector2(18, 11)) -> StyleBoxTexture:
		var s := StyleBoxTexture.new()
		s.texture = UIArt.button_texture(state)
		for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			s.set_texture_margin(side, 16)
		s.content_margin_left = cm.x
		s.content_margin_right = cm.x
		s.content_margin_top = cm.y
		s.content_margin_bottom = cm.y
		return s
	var sb: StyleBoxTexture = sbt.call(0)
	t.set_stylebox("normal", "Button", sb)
	t.set_stylebox("hover", "Button", sbt.call(1))
	var sbp: StyleBoxTexture = sbt.call(2)
	sbp.content_margin_top = 13 # content rides 1px lower when pressed in
	t.set_stylebox("pressed", "Button", sbp)
	t.set_stylebox("disabled", "Button", sbt.call(3))
	var focus: StyleBoxTexture = sbt.call(4)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.95, 0.9, 0.8))
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.7))
	t.set_color("font_focus_color", "Button", Color(1, 0.97, 0.8))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 0.85))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.44))
	t.set_color("font_shadow_color", "Button", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Button", 1)
	t.set_constant("shadow_offset_y", "Button", 1)
	t.set_font_size("font_size", "Button", 18)

	# PANEL — riveted plate
	var panel := StyleBoxTexture.new()
	panel.texture = UIArt.plate_texture()
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		panel.set_texture_margin(side, 20)
	panel.content_margin_left = 22
	panel.content_margin_right = 22
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	t.set_stylebox("panel", "PanelContainer", panel)

	# dark inset well (lists, readouts) — also exposed for menus
	sb_inset = StyleBoxTexture.new()
	sb_inset.texture = UIArt.inset_texture()
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb_inset.set_texture_margin(side, 8)
	sb_inset.content_margin_left = 12
	sb_inset.content_margin_right = 12
	sb_inset.content_margin_top = 8
	sb_inset.content_margin_bottom = 8

	# slim amber header strip with hairline
	sb_header = StyleBoxFlat.new()
	sb_header.bg_color = Color(0.13, 0.15, 0.126, 0.9)
	sb_header.border_color = Color(0.555, 0.951, 0.224, 0.7)
	sb_header.set_border_width_all(0)
	sb_header.border_width_bottom = 2
	sb_header.content_margin_left = 12
	sb_header.content_margin_right = 12
	sb_header.content_margin_top = 4
	sb_header.content_margin_bottom = 5

	# PROGRESS
	var bg := StyleBoxTexture.new()
	bg.texture = UIArt.inset_texture()
	bg.modulate_color = Color(0.9, 0.85, 0.8)
	for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		bg.set_texture_margin(side, 6)
	t.set_stylebox("background", "ProgressBar", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.488, 0.921, 0.154)
	fill.border_width_top = 1
	fill.border_color = Color(0.651, 0.97, 0.385)
	fill.set_corner_radius_all(3)
	t.set_stylebox("fill", "ProgressBar", fill)

	# LINE EDIT — inset well
	var le := sb_inset.duplicate()
	t.set_stylebox("normal", "LineEdit", le)
	var lef := sb_inset.duplicate()
	lef.modulate_color = Color(1.5, 1.35, 1.1)
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", Color(0.95, 0.9, 0.8))

	# HSLIDER
	var grab_area := StyleBoxFlat.new()
	grab_area.bg_color = Color(0.444, 0.825, 0.154)
	grab_area.set_corner_radius_all(5)
	grab_area.set_content_margin_all(6)
	t.set_stylebox("grabber_area", "HSlider", grab_area)
	var grab_area_hl := grab_area.duplicate()
	grab_area_hl.bg_color = Color(0.555, 0.951, 0.224)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab_area_hl)
	var slot := sb_inset.duplicate()
	slot.content_margin_left = 4
	slot.content_margin_right = 4
	slot.content_margin_top = 4
	slot.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slot)
	var gg := StyleBoxFlat.new()
	gg.bg_color = Color(0.95, 0.9, 0.8)
	gg.set_corner_radius_all(9)
	gg.set_content_margin_all(10)
	t.set_stylebox("grabber", "HSlider", gg)
	var gg_hl := gg.duplicate()
	gg_hl.bg_color = Color(0.629, 0.97, 0.35)
	t.set_stylebox("grabber_highlight", "HSlider", gg_hl)
	t.set_constant("center_grabber", "HSlider", 1)

	# CHECKBOX
	t.set_color("checkbox_color", "CheckBox", Color(0.518, 0.873, 0.21))
	t.set_font_size("font_size", "CheckBox", 17)

	# SCROLLBARS
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0.08, 0.07, 0.06, 0.7)
	sbg.set_corner_radius_all(4)
	t.set_stylebox("scroll", "HScrollbar", sbg)
	t.set_stylebox("scroll", "VScrollbar", sbg)
	var sbgr := StyleBoxFlat.new()
	sbgr.bg_color = Color(0.278, 0.376, 0.196, 0.85)
	sbgr.set_corner_radius_all(4)
	sbgr.set_content_margin_all(2)
	t.set_stylebox("grabber", "HScrollbar", sbgr)
	t.set_stylebox("grabber", "VScrollbar", sbgr)
	var sbgr_h := sbgr.duplicate()
	sbgr_h.bg_color = Color(0.555, 0.951, 0.224, 0.95)
	t.set_stylebox("grabber_highlight", "HScrollbar", sbgr_h)
	t.set_stylebox("grabber_highlight", "VScrollbar", sbgr_h)

	# LIST ROWS — flat, no rivets: dense lists read as a manifest, not a wall of bolts
	sb_row = {}
	var row := StyleBoxFlat.new()
	row.bg_color = Color(0.088, 0.102, 0.086, 0.85)
	row.border_color = Color(0.214, 0.246, 0.207, 0.7)
	row.set_border_width_all(1)
	row.set_corner_radius_all(3)
	row.content_margin_left = 10
	row.content_margin_right = 10
	row.content_margin_top = 6
	row.content_margin_bottom = 6
	sb_row["normal"] = row
	var row_h := row.duplicate()
	row_h.bg_color = Color(0.152, 0.175, 0.147, 0.95)
	row_h.border_color = Color(0.555, 0.951, 0.224, 0.9)
	sb_row["hover"] = row_h
	var row_p := row.duplicate()
	row_p.bg_color = Color(0.06, 0.07, 0.059, 0.95)
	row_p.border_color = Color(0.629, 0.97, 0.315, 0.9)
	sb_row["pressed"] = row_p
	sb_row["disabled"] = row
	var row_f := row.duplicate()
	row_f.bg_color = Color(0.133, 0.153, 0.129, 0.95)
	row_f.border_color = Color(0.636, 0.97, 0.35, 1.0)
	row_f.set_border_width_all(2)
	sb_row["focus"] = row_f
	return t

# Shared extra styleboxes built with the theme (menus pick these up).
var sb_inset: StyleBox
var sb_header: StyleBox
var sb_row: Dictionary
