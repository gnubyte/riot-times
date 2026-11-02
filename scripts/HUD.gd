extends CanvasLayer
# Full HUD: crosshair, hp/hunger/rads bars, XP bar, ammo, weapon, inventory grid,
# character sheet with stat allocation, pickup log, damage flashes, death screen.

class_name GameHUD

var player: Player = null

var hp_bar: ProgressBar
var hunger_bar: ProgressBar
var rads_bar: ProgressBar
var thirst_bar: ProgressBar
var xp_bar: ProgressBar
var ammo_label: Label
var weapon_label: Label
var prompt_label: Label
var msg_label: Label
var msg_tween: Tween
var level_label: Label
var caps_label: Label
var stamina_bar: ProgressBar
var crosshair: Control
var crosshair_lines: Array[ColorRect] = []
var hitmark: Label
var hitmark_tween: Tween
var reload_btn: Button
var reload_box: Panel
var reload_fill: ColorRect
var cursor_dot: ColorRect
var vignette: ColorRect
var flash: ColorRect
var inv_panel: PanelContainer
var inv_grid: GridContainer
var char_panel: PanelContainer
var char_stats_box: VBoxContainer
var death_panel: PanelContainer
var slot_labels := {}
var toast := ""

func _ready() -> void:
	layer = 10
	_build()
	GameData.state_changed.connect(_refresh)
	GameData.message_shown.connect(_show_message)
	GameData.leveled_up.connect(_on_level_up)
	GameData.died.connect(_on_died)
	GameData.damage_taken.connect(func(_a, _s): damage_flash())

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.theme
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# vignette / radiation tint
	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.3, 0.8, 0.2, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	# damage flash
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.8, 0.1, 0.1, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	# crosshair (dynamic gap driven by spread bloom)
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var line := ColorRect.new()
		var horiz := i < 2
		var sign := -1 if i % 2 == 0 else 1
		line.color = Color(1, 1, 1, 0.85)
		if horiz:
			line.size = Vector2(10, 2)
			line.position = Vector2(sign * 8, -1)
		else:
			line.size = Vector2(2, 10)
			line.position = Vector2(-1, sign * 8)
		crosshair.add_child(line)
		crosshair_lines.append(line)
	root.add_child(crosshair)

	# hit marker (X near crosshair, pops on enemy hit)
	hitmark = Label.new()
	hitmark.set_anchors_preset(Control.PRESET_CENTER)
	hitmark.position = Vector2(-14, -20)
	hitmark.text = "✕"
	hitmark.add_theme_font_size_override("font_size", 26)
	hitmark.add_theme_color_override("font_color", Color(1, 0.35, 0.25))
	hitmark.modulate.a = 0.0
	hitmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hitmark)

	# bottom-left bars
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.position = Vector2(16, -225)
	bl.custom_minimum_size = Vector2(260, 0)
	root.add_child(bl)
	hp_bar = _bar(bl, "HP", Color(0.8, 0.2, 0.2))
	stamina_bar = _bar(bl, "STAMINA", Color(0.35, 0.8, 0.65))
	hunger_bar = _bar(bl, "HUNGER", Color(0.85, 0.6, 0.2))
	thirst_bar = _bar(bl, "THIRST", Color(0.3, 0.55, 0.85))
	rads_bar = _bar(bl, "RADS", Color(0.5, 0.9, 0.2))
	var bl2 := HBoxContainer.new()
	bl.add_child(bl2)
	level_label = Label.new()
	level_label.text = "Lv 1"
	level_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	bl2.add_child(level_label)
	caps_label = Label.new()
	caps_label.text = "Glowshards: 0"
	caps_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	bl2.add_child(caps_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(260, 10)
	xp_bar.show_percentage = false
	xp_bar.max_value = 100
	bl.add_child(xp_bar)

	# bottom-right ammo / weapon
	var br := VBoxContainer.new()
	br.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	br.position = Vector2(-290, -235)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.custom_minimum_size = Vector2(280, 0)
	root.add_child(br)
	weapon_label = Label.new()
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.add_theme_font_size_override("font_size", 20)
	weapon_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	br.add_child(weapon_label)
	ammo_label = Label.new()
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.add_theme_font_size_override("font_size", 34)
	ammo_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	br.add_child(ammo_label)
	# reload progress strip (visible while reloading)
	var rp_box := Panel.new()
	rp_box.custom_minimum_size = Vector2(270, 12)
	rp_box.visible = false
	br.add_child(rp_box)
	reload_fill = ColorRect.new()
	reload_fill.color = Color(1, 0.8, 0.3)
	reload_fill.size = Vector2(0, 12)
	rp_box.add_child(reload_fill)
	reload_box = rp_box
	# on-screen RELOAD button (works with captured mouse via manual dispatch)
	reload_btn = Button.new()
	reload_btn.text = "⟳ RELOAD"
	reload_btn.custom_minimum_size = Vector2(150, 44)
	reload_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	reload_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	reload_btn.focus_mode = Control.FOCUS_NONE
	reload_btn.pressed.connect(func():
		if player != null: player._start_reload())
	reload_btn.mouse_entered.connect(func(): SFX.play("ui", -14.0, 1.4))
	br.add_child(reload_btn)
	UIFX.bezzle(reload_btn)
	# virtual cursor dot: shows where a click will land while mouse is captured
	cursor_dot = ColorRect.new()
	cursor_dot.size = Vector2(7, 7)
	cursor_dot.color = Color(1, 0.9, 0.5, 0.9)
	cursor_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cursor_dot)

	# interaction prompt (center-bottom)
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-200, -220)
	prompt_label.custom_minimum_size = Vector2(400, 0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	root.add_child(prompt_label)

	# message log (top-center)
	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-300, 90)
	msg_label.custom_minimum_size = Vector2(600, 0)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.add_theme_font_size_override("font_size", 19)
	root.add_child(msg_label)

	# hotbar labels
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hb.position = Vector2(-140, -46)
	hb.add_theme_constant_override("separation", 10)
	root.add_child(hb)
	for pair in [["1", "gun"], ["2", "melee"], ["3", "hat"], ["4", "armor"]]:
		_hotbar_slot(hb, pair[0], pair[1])

	_ignore_clicks(root)
	_build_inventory(root)
	_build_char_sheet(root)
	_build_death(root)
	_refresh()

# While the mouse is captured, any STOP/PAUSE control under the pinned cursor would
# swallow clicks (progress bars / labels over the HUD "steal" gunshots). Make them
# click-through. Modal panels (inventory etc.) are built afterwards and keep their clicks.
func _ignore_clicks(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_clicks(c)

var slot_item_labels := {}
func _hotbar_slot(parent: Control, num: String, slot: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(96, 54)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	p.add_child(box)
	var l1 := Label.new()
	l1.text = "[%s] %s" % [num, slot.to_upper()]
	l1.add_theme_font_size_override("font_size", 10)
	l1.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(l1)
	var l2 := Label.new()
	l2.add_theme_font_size_override("font_size", 12)
	box.add_child(l2)
	slot_item_labels[slot] = l2
	parent.add_child(p)
	return p

func _bar(parent: Control, label: String, color: Color) -> ProgressBar:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	box.add_child(l)
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(260, 14)
	b.show_percentage = false
	b.max_value = 100
	var st := StyleBoxFlat.new()
	st.bg_color = color
	b.add_theme_stylebox_override("fill", st)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	b.add_theme_stylebox_override("background", bg)
	box.add_child(b)
	return b

func _build_inventory(root: Control) -> void:
	inv_panel = PanelContainer.new()
	inv_panel.set_anchors_preset(Control.PRESET_CENTER)
	inv_panel.position = Vector2(-360, -270)
	inv_panel.custom_minimum_size = Vector2(720, 540)
	inv_panel.visible = false
	root.add_child(inv_panel)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	inv_panel.add_child(hbox)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(450, 0)
	hbox.add_child(left)
	var title := Label.new()
	title.text = "INVENTORY  [Tab / I to close]"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	left.add_child(title)
	inv_grid = GridContainer.new()
	inv_grid.columns = 6
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(inv_grid)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(240, 0)
	hbox.add_child(right)
	var eqtitle := Label.new()
	eqtitle.text = "EQUIPPED"
	eqtitle.add_theme_font_size_override("font_size", 16)
	right.add_child(eqtitle)
	for slot in ["gun", "melee", "hat", "armor"]:
		var r := HBoxContainer.new()
		right.add_child(r)
		var cap := Label.new()
		cap.text = slot.to_upper().rpad(7) + ": "
		cap.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		r.add_child(cap)
		var val := Label.new()
		val.name = "EQ_" + slot
		r.add_child(val)
		slot_labels[slot + "_eq"] = val
	right.add_child(Control.new())
	var help := Label.new()
	help.text = "Click item to use/equip.\n1 gun  2 melee\nE interact  R/⟳ reload\nRT aim  LShift sprint\nWalk at a low wall to mantle"
	help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	help.add_theme_font_size_override("font_size", 12)
	right.add_child(help)

func _build_char_sheet(root: Control) -> void:
	char_panel = PanelContainer.new()
	char_panel.set_anchors_preset(Control.PRESET_CENTER)
	char_panel.position = Vector2(-240, -300)
	char_panel.custom_minimum_size = Vector2(480, 600)
	char_panel.visible = false
	root.add_child(char_panel)
	char_stats_box = VBoxContainer.new()
	char_stats_box.add_theme_constant_override("separation", 6)
	char_panel.add_child(char_stats_box)

func _build_death(root: Control) -> void:
	death_panel = PanelContainer.new()
	death_panel.set_anchors_preset(Control.PRESET_CENTER)
	death_panel.position = Vector2(-220, -140)
	death_panel.custom_minimum_size = Vector2(440, 220)
	death_panel.visible = false
	root.add_child(death_panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	death_panel.add_child(box)
	var t := Label.new()
	t.text = "YOU DIED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 40)
	t.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15))
	box.add_child(t)
	var sub := Label.new()
	sub.text = "The wasteland claims another."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0, 10)
	box.add_child(spacer)
	var btn_r := Button.new()
	btn_r.text = "Respawn at settlement"
	btn_r.pressed.connect(func():
		GameData.revive_at()
		death_panel.visible = false)
	box.add_child(btn_r)
	var btn_t := Button.new()
	btn_t.text = "Back to title"
	btn_t.pressed.connect(func():
		GameData.show_title.emit())
	box.add_child(btn_t)

# ---------- refresh ----------
func _refresh() -> void:
	if not is_inside_tree(): return
	hp_bar.max_value = maxf(1, GameData.hp_max)
	hp_bar.value = GameData.hp
	hunger_bar.value = GameData.hunger
	thirst_bar.value = GameData.thirst
	rads_bar.max_value = maxf(1, GameData.hp_max)
	rads_bar.value = GameData.rads
	level_label.text = "Lv %d" % GameData.level
	xp_bar.max_value = maxf(1, GameData.xp_needed())
	xp_bar.value = GameData.xp
	caps_label.text = "✦ %d" % GameData.shards
	var slot := GameData.active_slot
	if slot == "gun" and GameData.equipped.gun != "":
		var g := ItemDB.get_def(GameData.equipped.gun)
		weapon_label.text = g.name
		ammo_label.text = "%d / %d %s" % [int(GameData.loaded_ammo.get(GameData.equipped.gun, 0)), g.mag, GameData.reserve_ammo(g.ammo_id)]
	elif slot == "melee":
		weapon_label.text = ItemDB.item_name(GameData.equipped.melee if GameData.equipped.melee != "" else "fists")
		ammo_label.text = "melee"
	else:
		weapon_label.text = "unarmed"
		ammo_label.text = ""
	for s in ["gun", "melee", "hat", "armor"]:
		var lbl: Label = slot_item_labels[s]
		var id: String = GameData.equipped[s]
		lbl.text = ItemDB.item_name(id) if id != "" else "(empty)"
		var eq := slot_labels.get(s + "_eq") as Label
		if eq: eq.text = ItemDB.item_name(id) if id != "" else "-"
	vignette.color.a = clampf(GameData.rads / maxf(1, GameData.hp_max) * 0.35, 0.0, 0.35)
	if player != null:
		stamina_bar.value = player.stamina
		var low := player.stamina < 25.0
		stamina_bar.modulate = Color(1, 0.5, 0.4) if low else Color(1, 1, 1)
		# reload button state: dim while full / while reloading
		var gid: String = GameData.equipped.gun
		reload_btn.visible = player != null and not player.dead and GameData.active_slot == "gun" and gid != ""
		if player.reloading and reload_box != null:
			reload_box.visible = true
			var gdef := ItemDB.get_def(gid)
			var total := 1.1 if gid != "rifle" else 1.8
			var frac := clampf(1.0 - player.reload_t / total, 0.0, 1.0)
			reload_fill.size = Vector2(270.0 * frac, 12)
		elif reload_box != null:
			reload_box.visible = false

func _on_spread(v: float) -> void:
	# push crosshair arms outward with bloom
	var g := 8.0 + v * 320.0
	for i in 4:
		var line := crosshair_lines[i]
		var horiz := i < 2
		var sign := -1 if i % 2 == 0 else 1
		if horiz:
			line.position = Vector2(sign * g, -1)
		else:
			line.position = Vector2(-1, sign * g)

func _on_hit_registered(_dmg: float, enemy: Node) -> void:
	SFX.play("ui", -10.0, 1.7)
	hitmark.modulate.a = 1.0
	hitmark.scale = Vector2(1.5, 1.5)
	hitmark.pivot_offset = hitmark.size * 0.5
	if hitmark_tween: hitmark_tween.kill()
	hitmark_tween = create_tween()
	hitmark_tween.set_parallel(true)
	hitmark_tween.tween_property(hitmark, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	hitmark_tween.tween_property(hitmark, "modulate:a", 0.0, 0.35).set_delay(0.08)

func _process(delta: float) -> void:
	if player == null or not is_inside_tree(): return
	_vc_settle += delta
	if cursor_dot != null:
		var captured := GameData.is_captured()
		if captured:
			_spring_vc(delta)
		cursor_dot.visible = captured
		if captured:
			cursor_dot.position = _vc - Vector2(3.5, 3.5)
	if not player.is_connected("hit_registered", _on_hit_registered):
		player.hit_registered.connect(_on_hit_registered)
	if not player.is_connected("crosshair_spread_changed", _on_spread):
		player.crosshair_spread_changed.connect(_on_spread)
	# crosshair only while playing (mouse captured), never over menus
	crosshair.visible = GameData.is_captured()
	# reload button: while captured, Godot sends no hover/click to Controls, so drive it
	# from the virtual cursor. The dot springs back to screen center when idle and only
	# ARMS after dwelling on the button, so looking around (even toward the bottom-right
	# corner where this button lives) can never steal a gunshot into a reload.
	if reload_btn != null:
		if GameData.is_captured():
			# never let the pinned OS cursor hit-stop the button during gameplay
			if reload_btn.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				reload_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var on_btn := reload_btn.get_global_rect().has_point(_vc)
			var vp := get_viewport().get_visible_rect().size
			_vc_far = maxf(_vc_far, _vc.distance_to(vp * 0.5))
			# arm only when the dot is AT the button, was deliberately flicked there
			# (travelled far from center) AND has settled — never mid-flick, so
			# sweeping the crosshair past the corner can't steal the click
			if on_btn and _vc_far > 120.0 and _vc_settle > 0.08:
				_vc_dwell += get_process_delta_time()
				if _vc_dwell >= VC_ARM_TIME:
					_vc_parked = true
			else:
				_vc_dwell = 0.0
				_vc_parked = false
			var hover_now := _vc_parked
			if hover_now != reload_btn.has_meta("hov"):
				reload_btn.set_meta("hov", hover_now)
				if hover_now:
					reload_btn.mouse_entered.emit()
				else:
					reload_btn.mouse_exited.emit()
			var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			if hover_now and down and not reload_btn.has_meta("dn"):
				reload_btn.set_meta("dn", true)
				reload_btn.button_down.emit()
			elif reload_btn.has_meta("dn"):
				reload_btn.remove_meta("dn")
				reload_btn.button_up.emit()
				if hover_now and player != null:
					# suppress the gunshot for this click so clicking RELOAD doesn't fire
					player.block_fire_until = Time.get_ticks_msec() + 250
					reload_btn.pressed.emit()
		elif reload_btn.mouse_filter != Control.MOUSE_FILTER_STOP:
			# mouse is free (inventory/pause/death panel): real hover + click again
			reload_btn.mouse_filter = Control.MOUSE_FILTER_STOP
			_vc_parked = false
			_vc_dwell = 0.0
			if reload_btn.has_meta("hov"):
				reload_btn.set_meta("hov", false)
				reload_btn.mouse_exited.emit()

const VC_ARM_TIME := 0.16
var _vc := Vector2(-100, -100)
var _vc_parked := false
var _vc_dwell := 0.0
var _vc_settle := 1.0  # seconds since the last mouse motion
var _vc_far := 0.0   # how far the dot has travelled from center since it last sprang back
func _spring_vc(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.5)
	if not _vc_parked:
		_vc = _vc.lerp(center, clampf(delta * 5.0, 0, 1))
		if _vc.distance_to(center) < 5.0:
			_vc = center
			_vc_dwell = 0.0
			_vc_far = 0.0

func _virtual_cursor() -> Vector2:
	return _vc

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if GameData.is_captured():
			var vp := get_viewport().get_visible_rect().size
			if _vc.x < 0.0:
				_vc = Vector2(vp.x * 0.5, vp.y * 0.5)
			_vc = (_vc + event.relative).clamp(Vector2.ZERO, Vector2(vp) - Vector2.ONE)
			_vc_settle = 0.0
		else:
			_vc = get_viewport().get_mouse_position()
			_vc_parked = false
			_vc_dwell = 0.0
	_update_prompt()
	if Input.is_action_just_pressed("inventory"):
		inv_panel.visible = not inv_panel.visible
		if inv_panel.visible:
			char_panel.visible = false
			_refresh_inventory()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if Input.is_action_just_pressed("character"):
		char_panel.visible = not char_panel.visible
		if char_panel.visible:
			inv_panel.visible = false
			_refresh_char()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _update_prompt() -> void:
	var txt := ""
	if player.interact_ray.is_colliding():
		var c := player.interact_ray.get_collider()
		if c and c.has_method("interact"):
			txt = "[E] Open %s" % c.title
	if txt == "":
		# check loot proximity
		var space := player.get_world_3d().direct_space_state
		var shape := SphereShape3D.new(); shape.radius = 1.9
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), player.global_position + Vector3(0, 0.8, 0))
		q.collision_mask = 8
		for h in space.intersect_shape(q, 1):
			var col: Object = h.collider
			if col and col.has_method("try_pickup"):
				txt = "[E] Take %s" % ItemDB.item_name(col.item_id)
				break
	prompt_label.text = txt

func _refresh_inventory() -> void:
	for c in inv_grid.get_children():
		c.queue_free()
	for e in GameData.inventory:
		var b := Button.new()
		b.custom_minimum_size = Vector2(70, 70)
		var id: String = e["id"]
		var cnt: int = int(e["count"])
		var def := ItemDB.get_def(id)
		b.icon = ItemDB.icon(id)
		b.expand_icon = false
		b.text = ("\n" + str(cnt)) if cnt > 1 else ""
		b.tooltip_text = "%s\n%s\nValue: %d" % [def["name"], def["desc"], def["value"]]
		b.pressed.connect(func(): _use_item(id))
		b.mouse_entered.connect(func(): SFX.play("ui", -18.0, 1.4))
		UIFX.bezzle(b)
		inv_grid.add_child(b)
	if GameData.inventory.is_empty():
		var l := Label.new()
		l.text = "Empty."
		inv_grid.add_child(l)

func _use_item(id: String) -> void:
	var def := ItemDB.get_def(id)
	match def.type:
		"gun", "melee", "hat", "armor":
			GameData.equip(id)
			GameData.set_active_slot("gun" if def.type == "gun" else ("melee" if def.type == "melee" else GameData.active_slot))
		"food", "heal", "radaway":
			if not GameData.eat(id):
				if GameData.species == "robot":
					GameData.game_message("A robot does not eat.", Color(0.7, 0.7, 0.8))
				else:
					GameData.game_message("Cannot use that.", Color(0.9, 0.5, 0.5))
		"ammo":
			GameData.game_message("Ammo auto-feeds your magazines.", Color(0.7, 0.8, 0.9))
	_refresh_inventory()
	_refresh()

func _refresh_char() -> void:
	for c in char_stats_box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = "%s  —  %s  (Lv %d)" % [GameData.char_name, GameData.species.to_upper(), GameData.level]
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	char_stats_box.add_child(t)
	var pts := Label.new()
	pts.text = "Stat points: %d" % GameData.stat_points
	pts.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	char_stats_box.add_child(pts)
	for key in GameData.SPECIAL:
		var row := HBoxContainer.new()
		char_stats_box.add_child(row)
		var l := Label.new()
		l.text = "%s  %d" % [key, GameData.stat(key)]
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		var btn := Button.new()
		btn.text = "+"
		btn.disabled = GameData.stat_points <= 0
		var k: String = key
		btn.pressed.connect(func():
			GameData.raise_stat(k)
			_refresh_char())
		row.add_child(btn)
	var d := GameData.derived()
	var info := Label.new()
	info.text = """Damage bonus: x%.2f   Crit: %.0f%%   Armor: %.0f%%
Rad resist: %.0f%%   Carry: %.0f / %.0f   Speed: %.1f
Kills: %d   Playtime: %dm""" % [
		d.dmg_mul, d.crit * 100.0, d.dr * 100.0, d.rad_resist,
		_weight(), d.carry, d.move_speed,
		_kills_total(), int(GameData.playtime / 60.0)]
	info.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	char_stats_box.add_child(info)

func _weight() -> float:
	var w := 0.0
	for e in GameData.inventory:
		w += float(ItemDB.get_def(e["id"])["weight"]) * int(e["count"])
	return w

func _kills_total() -> int:
	var t := 0
	for k in GameData.kills: t += GameData.kills[k]
	return t

func _show_message(text: String, color: Color) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", color)
	if msg_tween: msg_tween.kill()
	msg_label.modulate.a = 1.0
	msg_tween = create_tween()
	msg_tween.tween_interval(2.2)
	msg_tween.tween_property(msg_label, "modulate:a", 0.0, 1.0)

func _on_level_up(new_level: int) -> void:
	_show_message("LEVEL UP! You are now level %d  (+2 stat points, press C)" % new_level, Color(1, 0.9, 0.2))

func _on_died() -> void:
	death_panel.visible = true

func damage_flash() -> void:
	flash.color.a = 0.4
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.4)
