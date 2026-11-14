extends CanvasLayer
# In-game HUD: post-process (damage, cold, sickness, curses), dynamic crosshair,
# hit markers, damage direction arcs, vitals + status chips, weapon/ammo panel,
# compass with POIs, bounty tracker, pickup feed, banners, interact prompt with hold
# ring, vehicle gauges, sniper scope, noise meter, and the permadeath screen.

class_name GameHUD

var player: Player = null
var world: World = null
var root: Control
var fx: ColorRect
var fx_mat: ShaderMaterial
var cross: Control
var cross_lines: Array[ColorRect] = []
var cross_dot: ColorRect
var hitmark: Control
var hit_lines: Array[ColorRect] = []
var xp_pop: Label
var arcs: Array = []
var barrel: ToxicBarrel
var can: AmmoCan
var hp_label: Label
var hp_max_lbl: Label
var chips: HFlowContainer
var noise_lbl: Label
var level_lbl: Label
var xp_bar: ProgressBar
var wpn_name: Label
var wpn_sub: Label
var ammo_lbl: Label
var reserve_lbl: Label
var gear_lbl: Label
var compass: Control
var compass_lbl: Label
var clock_lbl: Label
var zone_lbl: Label
var quest_box: VBoxContainer
var feed: VBoxContainer
var banner_title: Label
var banner_sub: Label
var banner_tween: Tween
var msg: Label
var msg_tween: Tween
var prompt: Label
var hold_bar: ProgressBar
var car_box: VBoxContainer
var car_speed: Label
var car_fuel: ProgressBar
var car_hull: ProgressBar
var scope: Control
var death: Control
var menu: GameMenu = null
var dmg_pulse := 0.0
var flash_k := 0.0
var flash_col := Color(0, 0, 0)
var _last_zone := ""
var _chip_t := 0.0

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_build()
	GameData.message_shown.connect(_on_message)
	GameData.banner_shown.connect(_on_banner)
	GameData.damage_taken.connect(_on_damage)
	GameData.died.connect(_on_died)
	GameData.item_picked.connect(_on_pick)
	GameData.item_used.connect(_on_item_used)
	GameData.leveled_up.connect(func(l): _on_banner("LEVEL %d" % l, "+%d skill point%s — open the menu (%s)" % [2 if l % 5 == 0 else 1, "s" if l % 5 == 0 else "", InputSetup.glyph("menu")], Color(0.66, 0.97, 0.3)))
	GameData.xp_gained.connect(_on_xp)
	GameData.quests_changed.connect(_refresh_quests)
	menu = GameMenu.new()
	menu.hud = self
	add_child(menu)
	_refresh_quests()
	if player != null:
		player.hit_confirmed.connect(on_hit)

func _lbl(parent: Node, size := 16, col := Color(0.92, 0.9, 0.84), align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

# Stenciled paint on the drum: dark hard-edged shadow, letter-spaced.
func _stencil(parent: Node, size: int, col: Color) -> Label:
	var l := _lbl(parent, size, col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.02, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	return l

# Anchor a control that is already in the tree: offsets are relative to the anchor.
func _place(c: Control, preset: int, x: float, y: float, w: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = x
	c.offset_top = y
	c.offset_right = x + w
	c.offset_bottom = y + 10.0
	c.grow_vertical = Control.GROW_DIRECTION_END

func _bar(parent: Node, size: Vector2, col: Color, bg := Color(0, 0, 0, 0.55)) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	b.max_value = 100.0
	var f := StyleBoxFlat.new()
	f.bg_color = col
	f.set_corner_radius_all(2)
	f.border_width_top = 1
	f.border_color = col.lightened(0.4)
	b.add_theme_stylebox_override("fill", f)
	var g := StyleBoxFlat.new()
	g.bg_color = bg
	g.set_corner_radius_all(2)
	g.border_color = Color(1, 1, 1, 0.12)
	g.set_border_width_all(1)
	b.add_theme_stylebox_override("background", g)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b

# Translucent rivet-free plate behind a HUD block.
func _hud_plate(preset: int, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(preset)
	p.offset_left = rect.position.x
	p.offset_top = rect.position.y
	p.offset_right = rect.position.x + rect.size.x
	p.offset_bottom = rect.position.y + rect.size.y
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.032, 0.55)
	sb.border_color = Color(0.72, 0.5, 0.22, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p

func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.theme
	add_child(root)
	fx = ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_mat = Shaders.postfx_material()
	fx.material = fx_mat
	root.add_child(fx)
	# scope overlay
	scope = Control.new()
	scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.visible = false
	root.add_child(scope)
	var ring := TextureRect.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.texture = _scope_tex()
	ring.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.add_child(ring)
	for side in 4:
		var r := ColorRect.new()
		r.color = Color(0, 0, 0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scope.add_child(r)
		r.set_meta("side", side)
	# crosshair
	cross = Control.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)
	for i in 4:
		var l := ColorRect.new()
		l.color = Color(1, 1, 1, 0.9)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cross.add_child(l)
		cross_lines.append(l)
	cross_dot = ColorRect.new()
	cross_dot.size = Vector2(3, 3)
	cross_dot.position = Vector2(-1.5, -1.5)
	cross_dot.color = Color(1, 1, 1, 0.9)
	cross.add_child(cross_dot)
	hitmark = Control.new()
	hitmark.set_anchors_preset(Control.PRESET_CENTER)
	hitmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hitmark.modulate.a = 0.0
	root.add_child(hitmark)
	for i in 4:
		var hl := ColorRect.new()
		hl.size = Vector2(11, 3)
		hl.pivot_offset = Vector2(0, 1.5)
		hl.color = Color(1, 1, 1)
		var a := PI * 0.25 + i * PI * 0.5
		hl.position = Vector2(cos(a), sin(a)) * 9.0 - Vector2(0, 1.5)
		hl.rotation = a
		hitmark.add_child(hl)
		hit_lines.append(hl)
	xp_pop = _lbl(root, 20, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	_place(xp_pop, Control.PRESET_CENTER, -60, 26, 120)
	xp_pop.modulate.a = 0.0
	# damage arcs
	for i in 4:
		var arc := TextureRect.new()
		arc.texture = _arc_tex()
		arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		arc.set_anchors_preset(Control.PRESET_CENTER)
		arc.size = Vector2(240, 60)
		arc.pivot_offset = Vector2(120, 170)
		arc.position = Vector2(-120, -170)
		arc.modulate = Color(1, 0.15, 0.1, 0.0)
		root.add_child(arc)
		arcs.append({"node": arc, "t": 0.0, "from": Vector3.ZERO})
	# vitals (bottom-left): a rusted drum in a toxic puddle, stats stenciled on it
	barrel = ToxicBarrel.new()
	root.add_child(barrel)
	barrel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	barrel.offset_left = 4
	barrel.offset_top = -ToxicBarrel.SIZE.y - 6
	barrel.offset_right = 4 + ToxicBarrel.SIZE.x
	barrel.offset_bottom = -6
	chips = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 5)
	chips.add_theme_constant_override("v_separation", 3)
	chips.position = Vector2(66, 100)
	chips.size = Vector2(312, 60)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrel.add_child(chips)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	hp_row.position = Vector2(72, 18)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrel.add_child(hp_row)
	hp_label = _stencil(hp_row, 30, Color(0.86, 0.9, 0.72))
	hp_max_lbl = _stencil(hp_row, 15, Color(0.62, 0.68, 0.5))
	hp_max_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	var lvl_row := HBoxContainer.new()
	lvl_row.add_theme_constant_override("separation", 14)
	lvl_row.position = Vector2(196, 30)
	lvl_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barrel.add_child(lvl_row)
	level_lbl = _stencil(lvl_row, 14, Color(0.66, 0.97, 0.36))
	noise_lbl = _stencil(lvl_row, 14, Color(0.7, 0.85, 1.0))
	xp_bar = _bar(root, Vector2(0, 4), Color(0.6, 0.95, 0.25), Color(0, 0, 0, 0.35))
	xp_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	xp_bar.offset_top = -4
	# weapon (bottom-right): a rusted ammo can in the same toxic puddle
	can = AmmoCan.new()
	root.add_child(can)
	can.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	can.offset_left = -AmmoCan.SIZE.x - 4
	can.offset_top = -AmmoCan.SIZE.y - 4
	can.offset_right = -4
	can.offset_bottom = -4
	wpn_name = _stencil(can, 19, Color(1, 1, 1))
	wpn_name.position = Vector2(30, 24)
	wpn_name.size = Vector2(340, 24)
	wpn_name.clip_text = true
	wpn_sub = _stencil(can, 13, Color(0.72, 0.78, 0.6))
	wpn_sub.position = Vector2(34, 60)
	wpn_sub.size = Vector2(122, 56)
	wpn_sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	var am := HBoxContainer.new()
	am.alignment = BoxContainer.ALIGNMENT_END
	am.add_theme_constant_override("separation", 6)
	am.position = Vector2(170, 56)
	am.size = Vector2(206, 62)
	am.mouse_filter = Control.MOUSE_FILTER_IGNORE
	can.add_child(am)
	ammo_lbl = _lbl(am, 46, Color(0.75, 1.0, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
	ammo_lbl.add_theme_color_override("font_shadow_color", Color(0.35, 0.8, 0.1, 0.45))
	ammo_lbl.add_theme_constant_override("shadow_offset_x", 0)
	ammo_lbl.add_theme_constant_override("shadow_offset_y", 0)
	ammo_lbl.add_theme_constant_override("shadow_outline_size", 8)
	ammo_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reserve_lbl = _lbl(am, 18, Color(0.5, 0.72, 0.35))
	reserve_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear_lbl = _stencil(can, 13, Color(0.82, 0.84, 0.74))
	gear_lbl.position = Vector2(32, 158)
	gear_lbl.size = Vector2(352, 20)
	gear_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# compass + clock (top-center)
	compass = Control.new()
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-300, 14)
	compass.size = Vector2(600, 30)
	compass.clip_contents = true
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(compass)
	var cbg := ColorRect.new()
	cbg.color = Color(0, 0, 0, 0.35)
	cbg.size = Vector2(600, 30)
	cbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.add_child(cbg)
	compass_lbl = _lbl(compass, 15, Color(0.95, 0.9, 0.8))
	var tick := ColorRect.new()
	tick.color = Color(0.6, 0.95, 0.25)
	tick.size = Vector2(2, 30)
	tick.position = Vector2(299, 0)
	compass.add_child(tick)
	clock_lbl = _lbl(root, 16, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_place(clock_lbl, Control.PRESET_CENTER_TOP, -200, 48, 400)
	zone_lbl = _lbl(root, 20, Color(0.75, 0.95, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	_place(zone_lbl, Control.PRESET_CENTER_TOP, -250, 72, 500)
	zone_lbl.modulate.a = 0.0
	# quests (top-right)
	quest_box = VBoxContainer.new()
	quest_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_box.position = Vector2(-330, 18)
	quest_box.custom_minimum_size = Vector2(310, 0)
	quest_box.add_theme_constant_override("separation", 2)
	root.add_child(quest_box)
	# pickup feed (left)
	feed = VBoxContainer.new()
	feed.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	feed.position = Vector2(26, -40)
	feed.custom_minimum_size = Vector2(420, 0)
	feed.add_theme_constant_override("separation", 2)
	root.add_child(feed)
	# banner + message
	banner_title = _lbl(root, 46, Color(0.66, 0.97, 0.36), HORIZONTAL_ALIGNMENT_CENTER)
	_place(banner_title, Control.PRESET_CENTER_TOP, -500, 150, 1000)
	banner_title.modulate.a = 0.0
	banner_sub = _lbl(root, 20, Color(0.92, 0.9, 0.84), HORIZONTAL_ALIGNMENT_CENTER)
	_place(banner_sub, Control.PRESET_CENTER_TOP, -500, 212, 1000)
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.modulate.a = 0.0
	msg = _lbl(root, 19, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_place(msg, Control.PRESET_CENTER_BOTTOM, -450, -250, 900)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.modulate.a = 0.0
	prompt = _lbl(root, 20, Color(1.0, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_place(prompt, Control.PRESET_CENTER, -300, 70, 600)
	hold_bar = _bar(root, Vector2(140, 5), Color(1.0, 0.9, 0.5))
	_place(hold_bar, Control.PRESET_CENTER, -70, 104, 140)
	hold_bar.visible = false
	# vehicle
	car_box = VBoxContainer.new()
	car_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	car_box.position = Vector2(-150, -120)
	car_box.custom_minimum_size = Vector2(300, 0)
	car_box.visible = false
	root.add_child(car_box)
	car_speed = _lbl(car_box, 40, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_lbl(car_box, 12, Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER).text = "FUEL"
	car_fuel = _bar(car_box, Vector2(300, 8), Color(0.95, 0.75, 0.25))
	_lbl(car_box, 12, Color(0.8, 0.8, 0.8), HORIZONTAL_ALIGNMENT_CENTER).text = "HULL"
	car_hull = _bar(car_box, Vector2(300, 8), Color(0.6, 0.8, 0.9))
	_lbl(car_box, 13, Color(0.75, 0.75, 0.7), HORIZONTAL_ALIGNMENT_CENTER).text = "%s exit · %s horn · %s lights · %s handbrake" % [InputSetup.glyph("interact"), InputSetup.glyph("horn"), InputSetup.glyph("flashlight"), InputSetup.glyph("jump")]
	_build_death()

func _scope_tex() -> Texture2D:
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s * 0.5, y - s * 0.5).length() / (s * 0.5)
			var a := clampf((d - 0.92) / 0.03, 0.0, 1.0)
			var line := (absi(x - s / 2) < 1 or absi(y - s / 2) < 1) and d < 0.9 and d > 0.03
			var thick := (absi(x - s / 2) < 3 and d > 0.45 and d < 0.9) or (absi(y - s / 2) < 3 and d > 0.45 and d < 0.9)
			if line or thick:
				a = 1.0
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)

func _arc_tex() -> Texture2D:
	var img := Image.create(240, 60, false, Image.FORMAT_RGBA8)
	for y in 60:
		for x in 240:
			var cx := (x - 120.0) / 120.0
			var curve := 30.0 - (1.0 - cx * cx) * 24.0
			var d := absf(y - curve)
			var a := clampf(1.0 - d / 9.0, 0.0, 1.0) * (1.0 - absf(cx))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

func _build_death() -> void:
	death = Control.new()
	death.set_anchors_preset(Control.PRESET_FULL_RECT)
	death.visible = false
	root.add_child(death)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.0, 0.0, 0.78)
	death.add_child(bg)

func _show_death(cause: String) -> void:
	for c in death.get_children():
		if c is PanelContainer:
			c.queue_free()
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.custom_minimum_size = Vector2(640, 0)
	pc.position = Vector2(-320, -260)
	death.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	var t := _lbl(v, 56, Color(0.95, 0.2, 0.15), HORIZONTAL_ALIGNMENT_CENTER)
	t.text = "YOU DIED"
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.0, 0.9))
	t.add_theme_constant_override("outline_size", 8)
	var mem: Array = GameData.world.get("memorial", [])
	var last: Dictionary = mem.back() if not mem.is_empty() else {}
	var s := _lbl(v, 20, Color(0.92, 0.88, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.text = "%s, %s, level %d.\nKilled by %s after %d day%s and %d kills." % [last.get("name", GameData.char_name),
		GameData.BACKGROUNDS.get(last.get("background", "drifter"), {}).get("name", "Survivor"), int(last.get("level", 1)), cause,
		int(last.get("days", 0)), "" if int(last.get("days", 0)) == 1 else "s", int(last.get("kills", 0))]
	var s2 := _lbl(v, 17, Color(0.75, 0.85, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	s2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var curse: String = last.get("curse", "")
	if curse != "":
		s2.text = "You died carrying %s. Your body will rise. Kill what you became to get your gear back." % GameData.CURSE_NAMES.get(curse, curse)
	else:
		s2.text = "Your body and everything you carried lie where you fell. Haven remembers you."
	var b1 := Button.new()
	b1.text = "NEW SURVIVOR"
	b1.custom_minimum_size = Vector2(300, 52)
	b1.pressed.connect(func(): GameData.show_title.emit())
	v.add_child(b1)
	UIFX.bezzle(b1)
	death.visible = true
	# timed sequence: title slams in, red pulse, memorial fades up, button last
	b1.modulate.a = 0.0
	s.modulate.a = 0.0
	s2.modulate.a = 0.0
	var bg: ColorRect = death.get_child(0)
	bg.color = Color(0.08, 0.0, 0.0, 0.0)
	pc.pivot_offset = pc.size * 0.5
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.78, 0.4)
	tw.parallel().tween_property(pc, "scale", Vector2.ONE, 0.3).from(Vector2(1.6, 1.6)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pc, "modulate:a", 1.0, 0.25).from(0.0)
	tw.tween_interval(0.35)
	tw.parallel().tween_property(s, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(s2, "modulate:a", 1.0, 0.4).set_delay(0.12)
	tw.tween_property(b1, "modulate:a", 1.0, 0.3).set_delay(0.2)
	tw.tween_callback(func():
		flash_screen(Color(0.7, 0.05, 0.0, 0.4), 0.5)
		b1.grab_focus())

# ================= events =================
func _on_message(text: String, col: Color) -> void:
	msg.text = text
	msg.add_theme_color_override("font_color", col)
	msg.modulate.a = 1.0
	if msg_tween:
		msg_tween.kill()
	msg_tween = create_tween()
	msg_tween.tween_interval(2.6)
	msg_tween.tween_property(msg, "modulate:a", 0.0, 0.8)

func _on_banner(title: String, sub: String, col: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", col)
	banner_sub.text = sub
	banner_title.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	banner_title.scale = Vector2(1.15, 1.15)
	banner_title.pivot_offset = Vector2(500, 25)
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner_title, "modulate:a", 1.0, 0.25)
	banner_tween.tween_property(banner_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.4).set_delay(0.15)
	banner_tween.chain().tween_interval(3.4)
	banner_tween.chain().set_parallel(true)
	banner_tween.tween_property(banner_title, "modulate:a", 0.0, 0.8)
	banner_tween.tween_property(banner_sub, "modulate:a", 0.0, 0.8)

func _on_damage(amount: float, _src: String, from: Vector3) -> void:
	dmg_pulse = minf(1.0, dmg_pulse + amount / 25.0)
	if from == Vector3.INF or player == null:
		return
	var best = arcs[0]
	for a in arcs:
		if a.t < best.t:
			best = a
	best.t = 1.2
	best.from = from

func _on_died(cause: String) -> void:
	if menu != null:
		menu.close()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_callback(func(): _show_death(cause))

func _on_pick(e: Dictionary) -> void:
	var id: String = e.get("id", "")
	var l := _lbl(feed, 17, ItemDB.rarity_color(int(e.get("rarity", 0))) if ItemDB.is_unique(id) else Color(0.95, 0.92, 0.82))
	var cnt := int(e.get("count", 1))
	var t := "+ %s" % ItemDB.display_name(e)
	if cnt > 1:
		t += " x%d" % cnt
	if ItemDB.is_unique(id):
		t += "  Lv%d %s" % [int(e.get("level", 1)), ItemDB.RARITY_NAMES[int(e.get("rarity", 0))]]
	l.text = t
	var tw := l.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	while feed.get_child_count() > 6:
		feed.get_child(0).queue_free()
		feed.remove_child(feed.get_child(0))

# ---------------- timed consume feedback ----------------
# The item pops in big, bites disappear in step with the chomp SFX, then the
# stat flashes stagger in — the "well timed" eating moment.
func _on_item_used(id: String) -> void:
	var def := ItemDB.get_def(id)
	var t: String = def.get("type", "")
	if not t in ["food", "drink", "med", "cure"]:
		return
	if def.is_empty():
		return
	# big item icon, center-bottom
	var icon := TextureRect.new()
	icon.texture = IconArt.eat_frame(id, 0)
	icon.custom_minimum_size = Vector2(120, 120)
	icon.size = Vector2(120, 120)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.position = Vector2(-60, 96)
	icon.pivot_offset = Vector2(60, 60)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	icon.scale = Vector2(0.6, 0.6)
	icon.modulate.a = 0.0
	var tw := icon.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "scale", Vector2.ONE, 0.16)
	tw.parallel().tween_property(icon, "modulate:a", 1.0, 0.1)
	# bite steps timed to extra chomps (the first chomp already played in use_item)
	tw.tween_interval(0.16)
	tw.tween_callback(func():
		icon.texture = IconArt.eat_frame(id, 1)
		if t in ["food", "drink"]:
			SFX.play("eat" if t == "food" else "drink", -8.0, 1.15)
		icon.scale = Vector2(1.06, 1.06))
	tw.tween_interval(0.18)
	tw.tween_callback(func():
		icon.texture = IconArt.eat_frame(id, 2)
		if t in ["food", "drink"]:
			SFX.play("eat" if t == "food" else "drink", -9.0, 0.95))
	tw.tween_interval(0.16)
	tw.parallel().tween_property(icon, "position:y", 58.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(icon, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(icon.queue_free)
	# staggered stat flashes near the vitals
	var lines: Array = []
	if GameData.form == "vampire" and float(def.get("blood", 0.0)) > 0.0:
		lines.append(["+%d BLOOD" % int(float(def.get("blood", 0.0))), Color(0.85, 0.15, 0.2)])
	else:
		if float(def.get("hunger", 0.0)) != 0.0:
			lines.append(["%s%d FOOD" % ["+" if float(def.hunger) > 0 else "", int(float(def.hunger))], Color(0.95, 0.75, 0.35)])
		if float(def.get("thirst", 0.0)) != 0.0:
			lines.append(["%s%d WATER" % ["+" if float(def.thirst) > 0 else "", int(float(def.thirst))], Color(0.45, 0.75, 1.0)])
		if float(def.get("hp", 0.0)) > 0.0:
			lines.append(["+%d HP" % int(float(def.hp)), Color(0.45, 0.95, 0.45)])
		if float(def.get("warm", 0.0)) > 0.0:
			lines.append(["WARM +%d°" % int(float(def.warm)), Color(1.0, 0.6, 0.3)])
		if float(def.get("rads", 0.0)) > 0.0:
			lines.append(["+%d RADS" % int(float(def.rads)), Color(0.45, 1.0, 0.55)])
		if def.has("stamina"):
			lines.append(["ENERGIZED", Color(0.9, 0.9, 0.4)])
	if float(def.get("warm", 0.0)) > 0.0:
		flash_screen(Color(1.0, 0.75, 0.35, 0.35), 0.7)
	for i in mini(lines.size(), 5):
		var line: Array = lines[i]
		var l := _lbl(root, 22, line[1])
		l.text = line[0]
		l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		l.position = Vector2(34, -226 - i * 28)
		l.pivot_offset = Vector2(0, 12)
		l.modulate.a = 0.0
		var lt := l.create_tween()
		lt.tween_interval(0.5 + i * 0.13)
		lt.tween_property(l, "modulate:a", 1.0, 0.08)
		lt.parallel().tween_property(l, "scale", Vector2(1.0, 1.0), 0.14).from(Vector2(0.8, 0.8)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		lt.tween_interval(0.9)
		lt.tween_property(l, "modulate:a", 0.0, 0.45)
		lt.parallel().tween_property(l, "position:y", -238 - i * 28, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		lt.tween_callback(l.queue_free)

func _on_xp(amount: int) -> void:
	xp_pop.text = "+%d XP" % amount
	xp_pop.modulate.a = 1.0
	var t := xp_pop.create_tween()
	t.tween_interval(0.7)
	t.tween_property(xp_pop, "modulate:a", 0.0, 0.4)

func on_hit(info: Dictionary) -> void:
	var col := Color(1, 1, 1)
	if info.get("head", false):
		col = Color(1.0, 0.8, 0.2)
	if info.get("kill", false):
		col = Color(1.0, 0.25, 0.2)
	for hl in hit_lines:
		hl.color = col
		hl.size = Vector2(15 if info.get("kill", false) else 11, 3)
	hitmark.modulate.a = 1.0
	hitmark.scale = Vector2.ONE * (1.5 if info.get("kill", false) else 1.25)
	var t := hitmark.create_tween()
	t.set_parallel(true)
	t.tween_property(hitmark, "scale", Vector2.ONE, 0.12)
	t.tween_property(hitmark, "modulate:a", 0.0, 0.3).set_delay(0.08 if not info.get("kill", false) else 0.2)

func _refresh_quests() -> void:
	if quest_box == null:
		return
	for c in quest_box.get_children():
		c.queue_free()
	var h := _lbl(quest_box, 14, Color(0.66, 0.95, 0.36), HORIZONTAL_ALIGNMENT_RIGHT)
	h.text = "BOUNTIES"
	for q in GameData.world.get("quests", []):
		var qd := GameData.quest_def(q.id)
		if qd.is_empty():
			continue
		var l := _lbl(quest_box, 14, Color(0.6, 1.0, 0.6) if q.done else Color(0.88, 0.86, 0.8), HORIZONTAL_ALIGNMENT_RIGHT)
		l.text = ("✔ %s — claim at Haven" % qd.name) if q.done else "%s  %d/%d" % [qd.name, mini(int(q.progress), int(qd.goal)), int(qd.goal)]

func flash_screen(col: Color, dur: float) -> void:
	flash_col = col
	flash_k = 1.0
	var t := create_tween()
	t.tween_property(self, "flash_k", 0.0, dur)

# ================= per frame =================
func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var captured := GameData.is_captured()
	var menu_open := menu != null and menu.visible
	_update_fx(delta)
	_update_crosshair(captured and not menu_open)
	_update_vitals(delta)
	_update_weapon()
	_update_compass()
	_update_arcs(delta)
	prompt.text = player.interact_text if not menu_open else ""
	var hp := player.interact_hold_progress()
	hold_bar.visible = hp > 0.0
	hold_bar.value = hp * 100.0
	var v = player.in_vehicle
	car_box.visible = v != null
	if v != null:
		var info: Dictionary = v.hud_info()
		car_speed.text = "%d km/h" % int(info.speed)
		car_fuel.value = float(info.fuel)
		car_hull.value = float(info.hp) * 100.0
	scope.visible = player.scoped() and not menu_open
	if scope.visible:
		_layout_scope()
	if world != null and world.zone_name != _last_zone:
		_last_zone = world.zone_name
		var names := {"haven": "HAVEN — SAFE", "wild": "THE WASTES", "forest": "PINEWOOD", "downtown": "DOWNTOWN", "mall": "GALLERIA UNDER", "sublevel": "SERVICE LEVEL", "raider": "SCRAPJAW TERRITORY", "military": "CAMP HALBERD", "lab": "BLACK SITE"}
		zone_lbl.text = "%s   ·   Lv %d" % [names.get(_last_zone, _last_zone.to_upper()), World.ZONE_LEVEL.get(_last_zone, 1)]
		zone_lbl.modulate.a = 1.0
		var t := zone_lbl.create_tween()
		t.tween_interval(2.5)
		t.tween_property(zone_lbl, "modulate:a", 0.0, 1.0)

func _layout_scope() -> void:
	var vp := root.get_viewport_rect().size
	var side := minf(vp.x, vp.y)
	var x0 := (vp.x - side) * 0.5
	for c in scope.get_children():
		if c is ColorRect:
			var r := c as ColorRect
			match int(r.get_meta("side")):
				0: r.position = Vector2(0, 0); r.size = Vector2(x0 + 1, vp.y)
				1: r.position = Vector2(x0 + side - 1, 0); r.size = Vector2(x0 + 2, vp.y)
				_: r.size = Vector2.ZERO

func _update_fx(delta: float) -> void:
	dmg_pulse = maxf(0.0, dmg_pulse - delta * 1.6)
	var hp_k := GameData.hp / maxf(1.0, GameData.hp_max())
	var low := clampf((0.45 - hp_k) / 0.45, 0.0, 1.0)
	var cold := clampf((36.0 - GameData.body_temp) / 2.5, 0.0, 1.0)
	var sick := clampf(GameData.poison / 60.0, 0.0, 1.0)
	fx_mat.set_shader_parameter("vignette", 0.35 + low * 0.4 + (0.3 if player.scoped() else 0.0))
	fx_mat.set_shader_parameter("desat", low * 0.7 + (0.35 if GameData.form == "zombie" else 0.0))
	fx_mat.set_shader_parameter("red", low * 0.55 + dmg_pulse * 0.5)
	fx_mat.set_shader_parameter("aberration", dmg_pulse * 1.2 + low * 0.4 + sick * 0.6)
	fx_mat.set_shader_parameter("frost", cold * 0.8)
	fx_mat.set_shader_parameter("wobble", sick + (0.4 if GameData.curse == "rot" and GameData.curse_progress > 70.0 and not GameData.turned else 0.0))
	var tint := Color(1, 1, 1)
	var tint_amt := 0.0
	var lift := 0.0
	match GameData.form:
		"wolf":
			tint = Color(1.0, 0.7, 0.4); tint_amt = 0.35; lift = 0.18
		"vampire":
			tint = Color(1.0, 0.45, 0.5); tint_amt = 0.3 if GameData.is_night() else 0.15
			lift = 0.25 if GameData.is_night() else 0.0
		"zombie":
			tint = Color(0.7, 0.95, 0.6); tint_amt = 0.35
	if sick > 0.0:
		tint = tint.lerp(Color(0.75, 1.0, 0.55), sick * 0.5)
		tint_amt = maxf(tint_amt, sick * 0.3)
	if GameData.burning_sun and GameData.form == "vampire":
		tint = Color(1.0, 0.6, 0.3)
		tint_amt = 0.5
	fx_mat.set_shader_parameter("tint", tint)
	fx_mat.set_shader_parameter("tint_amt", tint_amt)
	fx_mat.set_shader_parameter("lift", lift)
	fx_mat.set_shader_parameter("flash", flash_k)
	fx_mat.set_shader_parameter("flash_color", flash_col)

func _update_crosshair(show: bool) -> void:
	var gun := player.vm_mode == "gun" and not player.wstats.is_empty()
	cross.visible = show and player.in_vehicle == null and not player.scoped()
	if not cross.visible:
		return
	var ads := player.ads_t
	var spread := player.current_spread()
	var vp := root.get_viewport_rect().size
	var px := tan(deg_to_rad(spread)) / tan(deg_to_rad(player.cam.fov * 0.5)) * vp.y * 0.5
	var gap := clampf(px, 4.0, 160.0)
	var a := clampf(1.0 - ads * 1.6, 0.0, 1.0) if gun else 0.0
	for i in 4:
		var l := cross_lines[i]
		var horiz := i < 2
		var sgn := -1.0 if i % 2 == 0 else 1.0
		if horiz:
			l.size = Vector2(10, 2)
			l.position = Vector2(sgn * gap + (-10.0 if sgn < 0 else 0.0), -1)
		else:
			l.size = Vector2(2, 10)
			l.position = Vector2(-1, sgn * gap + (-10.0 if sgn < 0 else 0.0))
		l.color.a = 0.9 * a
	cross_dot.color.a = 0.9 if (ads < 0.5 or not gun) else 0.0
	if player.aim_assist.target != null and GameData.input_mode == "pad" and gun:
		for l in cross_lines:
			l.color = Color(1.0, 0.75, 0.6, l.color.a)
	else:
		for l in cross_lines:
			l.color = Color(1, 1, 1, l.color.a)

func _chip(text: String, col: Color, icon_name := "") -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.018, 0.72)
	sb.border_color = Color(col.r, col.g, col.b, 0.55)
	sb.set_border_width_all(0)
	sb.border_width_left = 2
	sb.set_corner_radius_all(1)
	sb.content_margin_left = 5
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	if icon_name != "":
		var ic := TextureRect.new()
		ic.texture = IconArt.status_icon(icon_name)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(14, 14)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var l := _lbl(row, 12, col)
	l.text = text
	# pulse when the reading changes vs the last refresh
	var idx := chips.get_child_count() - 1
	if _chip_old.has(idx) and String(_chip_old[idx]) != text:
		p.pivot_offset = p.size * 0.5
		p.scale = Vector2(1.18, 1.18)
		var tw := p.create_tween()
		tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_chip_prev[idx] = text

var _chip_prev := {}
var _chip_old := {}

func _update_vitals(delta: float) -> void:
	var mx := GameData.hp_max()
	barrel.set_vitals(GameData.hp / maxf(1.0, mx), player.stamina / Player.STAMINA_MAX)
	hp_label.text = str(int(ceil(GameData.hp)))
	hp_max_lbl.text = "/ %d  HP" % int(mx)
	hp_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.72) if GameData.hp > mx * 0.3 else Color(1.0, 0.4, 0.3))
	level_lbl.text = "LV %d   ✦ %d" % [GameData.level, GameData.shards]
	xp_bar.max_value = maxf(1.0, GameData.xp_needed())
	xp_bar.value = GameData.xp
	var nz := Hearing.player_noise
	var bars := clampi(int(nz / 15.0) + (1 if nz > 1.0 else 0), 0, 6)
	noise_lbl.text = "NOISE " + "|".repeat(bars) + ".".repeat(6 - bars)
	noise_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0).lerp(Color(1.0, 0.4, 0.3), bars / 6.0))
	_chip_t -= delta
	if _chip_t > 0.0:
		return
	_chip_t = 0.3
	for c in chips.get_children():
		c.queue_free()
		chips.remove_child(c)
	_chip_old = _chip_prev.duplicate()
	_chip_prev.clear()
	if GameData.form == "vampire":
		_chip("BLOOD %d" % int(GameData.blood), Color(0.9, 0.2, 0.25) if GameData.blood > 25.0 else Color(1.0, 0.4, 0.3), "blood")
	elif GameData.form != "zombie":
		_chip("FOOD %d" % int(GameData.hunger), Color(0.95, 0.75, 0.35) if GameData.hunger > 25.0 else Color(1.0, 0.35, 0.3), "food")
		_chip("WATER %d" % int(GameData.thirst), Color(0.45, 0.75, 1.0) if GameData.thirst > 25.0 else Color(1.0, 0.35, 0.3), "water")
	var bt := GameData.body_temp
	var tc := Color(0.8, 0.9, 0.85)
	var tt := "%.1f°" % bt
	if bt < 35.5:
		tc = Color(0.55, 0.8, 1.0)
		tt += " COLD" if bt > 34.0 else " FREEZING"
	elif bt > 38.5:
		tc = Color(1.0, 0.55, 0.3)
		tt += " HOT"
	_chip(tt, tc, "temp")
	var d := GameData.derived()
	_chip("%.1f/%.0f kg" % [float(d.weight), float(d.carry)], Color(1.0, 0.4, 0.3) if d.encumbered else Color(0.75, 0.75, 0.72), "weight")
	if GameData.poison > 0.0:
		_chip("SICK", Color(0.65, 0.95, 0.3), "sick")
	if GameData.curse != "":
		var cn: String = {"rot": "ROT", "wolf": "WOLF", "vampire": "VAMPIRE"}[GameData.curse]
		if GameData.turned:
			_chip("%s · TURNED" % cn, Color(0.9, 0.3, 0.45), "curse")
		else:
			_chip("%s %d%%" % [cn, int(GameData.curse_progress)], Color(0.9, 0.35, 0.5), "curse")
	if player.wet:
		_chip("WET", Color(0.5, 0.7, 1.0), "wet")
	if GameData.buffs.has("tough"):
		_chip("TOUGH", Color(0.9, 0.9, 0.5), "tough")

func _update_weapon() -> void:
	var e := player.winst
	if player.vm_mode == "melee" or e.is_empty():
		var m := GameData.melee_weapon()
		var rc: Color = ItemDB.rarity_color(int(m.get("rarity", 0)))
		wpn_name.text = ItemDB.display_name(m).to_upper()
		wpn_name.add_theme_color_override("font_color", rc)
		wpn_sub.text = "MELEE
%s / %s swing" % [InputSetup.glyph("fire"), InputSetup.glyph("melee")]
		ammo_lbl.text = "--"
		reserve_lbl.text = ""
		can.set_weapon(0, 0, rc, true)
	else:
		var rc2: Color = ItemDB.rarity_color(int(e.get("rarity", 0)))
		wpn_name.text = ItemDB.display_name(e).to_upper()
		wpn_name.add_theme_color_override("font_color", rc2)
		wpn_sub.text = "LV %d %s
%s" % [int(e.get("level", 1)), String(ItemDB.RARITY_NAMES[int(e.get("rarity", 0))]).to_upper(), String(player.wstats.get("mode", "")).to_upper()]
		var ammo := int(e.get("ammo", 0))
		ammo_lbl.text = str(ammo)
		var mag := player._mag_size()
		ammo_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3) if ammo <= mag / 4 else Color(0.75, 1.0, 0.45))
		reserve_lbl.text = "/ %d" % player._reserve()
		can.set_weapon(ammo, mag, rc2, false)
	var ap := player.act_progress()
	can.set_action(ap if ap >= 0.0 and player.act in ["reload", "use"] else -1.0)
	var heals := GameData.count_item("bandage") + GameData.count_item("medkit")
	gear_lbl.text = "%s %s ×%d    %s heal ×%d" % [InputSetup.glyph("throw"), ItemDB.get_def(GameData.throwable).get("name", "").to_upper(), GameData.count_item(GameData.throwable), InputSetup.glyph("heal"), heals]

func _update_compass() -> void:
	var yaw := player.global_rotation.y
	if player.in_vehicle != null:
		yaw = (player.in_vehicle as Vehicle).cam.global_rotation.y
	var heading := fposmod(-rad_to_deg(yaw), 360.0)
	var marks := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}
	var text := ""
	_mark_i = 0
	for deg in marks:
		_compass_mark(float(deg), heading, marks[deg], Color(0.95, 0.9, 0.8), 15)
	if world != null:
		var named := ""
		var best := 10.0
		for poi in world.pois:
			var to0: Vector3 = (poi.pos as Vector3) - player.global_position
			var off := absf(wrapf(fposmod(rad_to_deg(atan2(to0.x, -to0.z)), 360.0) - heading, -180.0, 180.0))
			if off < best and to0.length() < 600.0 and to0.length() > 25.0:
				best = off
				named = poi.id
		for poi in world.pois:
			var to: Vector3 = (poi.pos as Vector3) - player.global_position
			var bearing := fposmod(rad_to_deg(atan2(to.x, -to.z)), 360.0)
			var known := GameData.discovered.has(poi.id)
			if to.length() < 600.0:
				var sub := "%s %dm" % [String(poi.title), int(to.length())] if poi.id == named else ""
				_compass_mark(bearing, heading, "◆" if known else "◇", Color(1.0, 0.75, 0.3) if known else Color(0.7, 0.7, 0.7), 13, sub)
		var hv := World.HAVEN - player.global_position
		_compass_mark(fposmod(rad_to_deg(atan2(hv.x, -hv.z)), 360.0), heading, "⌂", Color(0.5, 1.0, 0.6), 18)
	compass_lbl.text = text
	for i in range(_mark_i, _marks.size()):
		(_marks[i] as Label).visible = false
	var t := GameData.time_of_day()
	var hh := int(t)
	var mm := int((t - hh) * 60.0)
	clock_lbl.text = "DAY %d · %02d:%02d %s" % [GameData.day(), hh, mm, "☾" if GameData.is_night() else "☀"]
	if GameData.is_siege_night() and t > 18.0:
		clock_lbl.text += "   ⚠ SIEGE NIGHT"

var _marks: Array = []
var _mark_i := 0
func _compass_mark(bearing: float, heading: float, txt: String, col: Color, size: int, sub := "") -> void:
	var diff := wrapf(bearing - heading, -180.0, 180.0)
	if absf(diff) > 75.0:
		return
	var x := 300.0 + diff / 75.0 * 300.0
	if _mark_i >= _marks.size():
		var nl := _lbl(compass, size, col, HORIZONTAL_ALIGNMENT_CENTER)
		nl.custom_minimum_size = Vector2(200, 0)
		_marks.append(nl)
	var l: Label = _marks[_mark_i]
	_mark_i += 1
	l.visible = true
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.text = txt if sub == "" else "%s %s" % [txt, sub]
	l.position = Vector2(x - 100.0, 4)

func _update_arcs(delta: float) -> void:
	for a in arcs:
		var n: TextureRect = a.node
		if a.t <= 0.0:
			n.modulate.a = 0.0
			continue
		a.t -= delta
		var to: Vector3 = (a.from as Vector3) - player.global_position
		var local := player.global_transform.basis.inverse() * to
		var ang := atan2(local.x, -local.z)
		n.rotation = ang
		n.modulate = Color(1.0, 0.15, 0.1, clampf(a.t, 0.0, 1.0))
