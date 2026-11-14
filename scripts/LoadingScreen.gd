extends CanvasLayer
# Loading screen: layered dusk art (sky, skyline + lit windows, foreground),
# emblem in a counter-rotating gear ring, shine-sweep progress bar, rotating tips.

class_name LoadingScreen

var root: Control
var bar: ProgressBar
var bar_shine: TextureRect
var tip: Label
var pct: Label
var emblem: TextureRect
var ring: TextureRect
var spin := 0.0
var tips_i := 0
var target := 0.0
var done := false

const TIPS := [
	"Every gunshot is heard for 60 meters. Melee and crossbows are quiet. Hushed guns are quieter.",
	"The Gaunt is blind. It hunts sound. Crouch, don't run, and don't shoot.",
	"Kill the Screamer first, or the whole street comes running.",
	"Bloaters pop into toxic gas that spreads the Rot. A gas mask laughs at it.",
	"Silver hurts werewolves. Fire hurts vampires. Stakes hurt them a lot.",
	"You only get one life. Your body and your gear stay where you fall.",
	"Die cursed, and you'll rise again. Your next survivor will have to put you down.",
	"Every third night the horde comes for Haven. Be there, or hope the guards hold.",
	"Night loot is better. Night is also when the wolves come out.",
	"Raw meat and dirty water can make you sick. Cook it at a fire.",
	"Cold makes your aim shake. Warm clothes, fires and pine tea fix that.",
	"Weight matters. Over capacity you're slower, louder, and you can't sprint.",
	"Slide by crouching mid-sprint. Jump out of a slide to keep the momentum.",
	"Engines are loud. Park away from where you're going to loot.",
	"The Galleria under the plaza is rich and packed. The skylight is a fast way down.",
	"Leave your best gear in Haven's stash. It outlives you.",
]

func _init() -> void:
	layer = 30

func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.theme = UITheme.theme
	add_child(root)
	var vpsize := get_viewport().get_visible_rect().size

	var sky := TextureRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.texture = UIArt.sky_texture()
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(sky)

	var line := TextureRect.new()
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -220
	line.texture = UIArt.skyline_texture(960, 220, 1)
	line.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(line)

	var lights := TextureRect.new()
	lights.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lights.offset_top = -220
	lights.texture = UIArt.skyline_lights_texture(960, 220, 1)
	lights.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(lights)

	var fg := TextureRect.new()
	fg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fg.texture = UIArt.foreground_texture(960, 130)
	fg.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(fg)

	var vign := TextureRect.new()
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	vign.texture = UIArt.vignette_texture(640, 360)
	vign.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(vign)

	# emblem inside a gear ring
	var emblem_box := Control.new()
	emblem_box.custom_minimum_size = Vector2(160, 160)
	emblem_box.size = Vector2(160, 160)
	emblem_box.position = Vector2(vpsize.x * 0.5 - 80, vpsize.y * 0.34)
	emblem_box.pivot_offset = Vector2(80, 80)
	root.add_child(emblem_box)
	ring = TextureRect.new()
	ring.texture = UIArt.emblem_ring_texture(192)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.stretch_mode = TextureRect.STRETCH_SCALE
	emblem_box.add_child(ring)
	emblem = TextureRect.new()
	emblem.texture = UIArt.emblem_texture(192, Color(0.533, 0.921, 0.175))
	emblem.set_anchors_preset(Control.PRESET_FULL_RECT)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem_box.add_child(emblem)
	UIFX.glow_pulse(emblem, Color(0.629, 0.97, 0.35), 2.0, 0.25)

	var t := Label.new()
	t.text = "RIOT TIMES"
	t.set_anchors_preset(Control.PRESET_CENTER_TOP)
	t.position = Vector2(-300, 40)
	t.custom_minimum_size = Vector2(600, 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 56)
	t.add_theme_color_override("font_color", Color(0.503, 0.921, 0.154))
	t.add_theme_color_override("font_outline_color", Color(0.019, 0.021, 0.018, 0.9))
	t.add_theme_constant_override("outline_size", 7)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	t.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(t)

	var st := Label.new()
	st.text = "the wasteland is loading your regrets..."
	st.set_anchors_preset(Control.PRESET_CENTER_TOP)
	st.position = Vector2(-300, 112)
	st.custom_minimum_size = Vector2(600, 0)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 17)
	st.add_theme_color_override("font_color", Color(0.85, 0.75, 0.6))
	st.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.85))
	st.add_theme_constant_override("outline_size", 4)
	root.add_child(st)

	# progress bar + sliding shine (clipped so the shine never parks off the end)
	var bar_holder := Control.new()
	bar_holder.position = Vector2(vpsize.x * 0.5 - 260, vpsize.y - 140)
	bar_holder.size = Vector2(520, 22)
	bar_holder.clip_contents = true
	root.add_child(bar_holder)
	bar = ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.show_percentage = false
	bar.max_value = 100
	bar.value = 0
	bar_holder.add_child(bar)
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0.481, 0.873, 0.175)
	fstyle.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fstyle)
	bar_shine = TextureRect.new()
	bar_shine.texture = UIArt.grain_texture(0.9)
	bar_shine.stretch_mode = TextureRect.STRETCH_SCALE
	bar_shine.modulate = Color(1, 1, 1, 0.5)
	bar_shine.size = Vector2(46, 10)
	bar_shine.position = Vector2(-46, 6)
	bar_holder.add_child(bar_shine)
	var shine_tw := create_tween().set_loops()
	shine_tw.tween_property(bar_shine, "position:x", 520.0, 1.1).set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	pct = Label.new()
	pct.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pct.position = Vector2(270, -143)
	pct.custom_minimum_size = Vector2(80, 0)
	pct.add_theme_font_size_override("font_size", 16)
	pct.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	pct.text = "0%"
	root.add_child(pct)

	tip = Label.new()
	tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip.position = Vector2(-300, -95)
	tip.custom_minimum_size = Vector2(600, 60)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 17)
	tip.add_theme_color_override("font_color", Color(0.92, 0.85, 0.68))
	tip.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.01, 0.85))
	tip.add_theme_constant_override("outline_size", 4)
	tip.text = "TIP: " + TIPS[randi() % TIPS.size()]
	root.add_child(tip)

func set_progress(v: float) -> void:
	target = clampf(v, 0.0, 1.0)

func _process(delta: float) -> void:
	if bar == null:
		return
	spin += delta * 90.0
	if emblem:
		emblem.rotation_degrees = fposmod(spin, 360)
	if ring:
		ring.rotation_degrees = -fposmod(spin * 0.6, 360)
	bar.value = lerpf(bar.value, target * 100.0, clampf(delta * 8.0, 0, 1))
	pct.text = "%d%%" % int(bar.value)
	_t_acc += delta
	if _t_acc > 3.0:
		_t_acc = 0.0
		tip.text = "TIP: " + TIPS[randi() % TIPS.size()]
		tip.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(tip, "modulate:a", 1.0, 0.35)

var _t_acc := 0.0

func finish_and_free() -> void:
	if done: return
	done = true
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)
