extends Control
# The pause-the-world menu: INVENTORY (weight, rarity, compare, equip/use/drop),
# SKILLS (three trees + the curse branch), SURVIVOR (stats, conditions, memorial),
# BOUNTIES. Also hosts Haven/camp stations: trader, workbench, cooking, stash, board.
# Fully controller-navigable: LB/RB switch tabs, A selects, B closes.

class_name GameMenu

const TABS := ["INVENTORY", "SKILLS", "SURVIVOR", "BOUNTIES"]
const RECIPES := [
	{name="Grilled Steak", out="cooked_meat", n=1, inp={"raw_meat": 1}, xp=10},
	{name="Fire-Roasted Fish", out="cooked_fish", n=1, inp={"raw_fish": 1}, xp=10},
	{name="Clean Water", out="clean_water", n=1, inp={"dirty_water": 1}, xp=5},
	{name="Wasteland Stew", out="stew", n=1, inp={"raw_meat": 1, "beans": 1, "dirty_water": 1}, xp=25},
	{name="Pine Needle Tea", out="pine_tea", n=1, inp={"pine_needles": 2, "clean_water": 1}, xp=10},
	{name="Silverleaf Tincture", out="silverleaf_tincture", n=1, inp={"silverleaf": 2, "clean_water": 1}, xp=60},
	{name="Smoked Glowing Carp", out="cooked_fish", n=3, inp={"glow_carp": 1}, xp=20},
]

var hud: GameHUD
var tab_i := 0
var station := ""
var station_node: Node = null
var sel := {}
var panel: PanelContainer
var title: Label
var tab_row: HBoxContainer
var info_lbl: Label
var body: HBoxContainer
var _stock: Array = []
var _stock_day := -1
var _first_focus: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.theme
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.015, 0.01, 0.82)
	add_child(dim)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1240, 760)
	panel.position = Vector2(-620, -380)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	title.custom_minimum_size = Vector2(260, 0)
	head.add_child(title)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tab_row)
	info_lbl = Label.new()
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_lbl.add_theme_font_size_override("font_size", 16)
	head.add_child(info_lbl)
	var sep := HSeparator.new()
	v.add_child(sep)
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)
	var hint := Label.new()
	hint.text = "LB/RB or Z/X: switch tabs   ·   A/click: select   ·   B/Esc/Tab: close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	v.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("menu") and GameData.alive and hud != null and hud.player != null and hud.player.in_vehicle == null and not get_tree().paused:
			get_viewport().set_input_as_handled()
			open_tabs()
		return
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif station == "" and event.is_action_pressed("tab_next"):
		get_viewport().set_input_as_handled()
		tab_i = (tab_i + 1) % TABS.size()
		_rebuild()
	elif station == "" and event.is_action_pressed("tab_prev"):
		get_viewport().set_input_as_handled()
		tab_i = (tab_i + TABS.size() - 1) % TABS.size()
		_rebuild()

func open_tabs() -> void:
	station = ""
	station_node = null
	_open()

func open_station(kind: String, node: Node) -> void:
	station = kind
	station_node = node
	_open()

func _open() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	sel = {}
	SFX.play("ui", -8.0, 0.9)
	_rebuild()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	if GameData.alive:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	SFX.play("ui", -10.0, 0.75)

# ---------------- helpers ----------------
func _label(parent: Node, text: String, size := 16, col := Color(0.9, 0.88, 0.82)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, cb: Callable, col := Color(0.95, 0.9, 0.8), min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.add_theme_color_override("font_focus_color", col.lightened(0.3))
	b.add_theme_font_size_override("font_size", 15)
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.focus_mode = Control.FOCUS_ALL
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.35, 0.25, 0.1, 0.95)
	fs.border_color = Color(1.0, 0.8, 0.35)
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(6)
	fs.set_content_margin_all(10)
	b.add_theme_stylebox_override("focus", fs)
	b.pressed.connect(func():
		SFX.play("click", -10.0)
		cb.call())
	parent.add_child(b)
	if _first_focus == null:
		_first_focus = b
	return b

func _scroll(parent: Node, w: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(w, 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	sc.add_child(v)
	return v

func _col(parent: Node, w: float) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(w, 0)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	parent.add_child(v)
	return v

func _entry_text(e: Dictionary) -> String:
	var t := ItemDB.display_name(e)
	var cnt := int(e.get("count", 1))
	if cnt > 1:
		t += "  ×%d" % cnt
	if ItemDB.is_unique(e.id):
		t += "  Lv%d" % int(e.get("level", 1))
	var uid := int(e.get("uid", 0))
	if uid != 0:
		for s in GameData.equipped:
			if int(GameData.equipped[s]) == uid:
				t += "   [%s]" % s.to_upper()
	return t

func _entry_color(e: Dictionary) -> Color:
	if ItemDB.is_unique(e.id):
		return ItemDB.rarity_color(int(e.get("rarity", 0)))
	return Color(0.9, 0.88, 0.82)

# ---------------- build ----------------
func _rebuild() -> void:
	for c in tab_row.get_children():
		c.queue_free()
	for c in body.get_children():
		c.queue_free()
	_first_focus = null
	var d := GameData.derived()
	info_lbl.text = "%.1f / %.0f kg%s     ✦ %d     %d skill pt%s" % [float(d.weight), float(d.carry), "  OVERLOADED" if d.encumbered else "", GameData.shards, GameData.skill_points, "" if GameData.skill_points == 1 else "s"]
	info_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if d.encumbered else Color(0.85, 0.85, 0.8))
	if station != "":
		title.text = {"trader": "MAGS' TRADING POST", "workbench": "WORKBENCH", "stove": "COOKING", "campfire": "CAMPFIRE", "stash": "HAVEN STASH", "board": "BOUNTY BOARD"}.get(station, station.to_upper())
		match station:
			"trader": _trader()
			"workbench": _workbench()
			"stove", "campfire": _cooking()
			"stash": _stash()
			"board": _board()
	else:
		title.text = GameData.char_name.to_upper()
		for i in TABS.size():
			var idx := i
			var tb := Button.new()
			tb.text = TABS[i]
			tb.toggle_mode = true
			tb.button_pressed = i == tab_i
			tb.focus_mode = Control.FOCUS_NONE
			tb.pressed.connect(func():
				tab_i = idx
				_rebuild())
			tab_row.add_child(tb)
		match tab_i:
			0: _inventory()
			1: _skills()
			2: _survivor()
			3: _bounties()
	if _first_focus != null:
		_first_focus.call_deferred("grab_focus")

# ---------------- inventory ----------------
const CATS := [["WEAPONS", ["weapon"]], ["MELEE", ["melee"]], ["ARMOR & PACKS", ["armor"]], ["AMMO", ["ammo"]],
	["MEDS & CURES", ["med", "cure"]], ["FOOD & DRINK", ["food", "drink"]], ["THROWABLES", ["throwable"]],
	["TOOLS & MATERIALS", ["tool", "material"]], ["VALUABLES & NOTES", ["valuable", "note"]]]

func _inventory() -> void:
	var left := _scroll(body, 520)
	for cat in CATS:
		var items := GameData.inventory.filter(func(e): return ItemDB.item_type(e.id) in cat[1])
		if items.is_empty():
			continue
		_label(left, cat[0], 14, Color(1.0, 0.75, 0.35))
		for e in items:
			var entry: Dictionary = e
			var b := _button(left, _entry_text(entry), func():
				sel = entry
				_rebuild(), _entry_color(entry), 500)
			b.icon = ItemDB.icon(entry)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 28)
			if sel == entry:
				_first_focus = b
	if GameData.inventory.is_empty():
		_label(left, "Empty. Go scavenge.", 16)
	var right := _col(body, 660)
	if sel.is_empty() or not GameData.inventory.has(sel):
		_equip_summary(right)
		return
	_label(right, ItemDB.display_name(sel), 26, _entry_color(sel))
	_label(right, ItemDB.describe(sel), 15)
	var t := ItemDB.item_type(sel.id)
	if t == "weapon":
		var cur := GameData.active_weapon()
		if not cur.is_empty() and int(cur.uid) != int(sel.uid):
			var a := ItemDB.weapon_stats(sel)
			var b2 := ItemDB.weapon_stats(cur)
			var parts := []
			for k in [["dmg", "DMG"], ["rpm", "RPM"], ["mag", "MAG"]]:
				var dv := float(a[k[0]]) * (int(a.pellets) if k[0] == "dmg" else 1) - float(b2[k[0]]) * (int(b2.pellets) if k[0] == "dmg" else 1)
				parts.append("%s %s%.0f" % [k[1], "+" if dv >= 0 else "", dv])
			var dr := (float(a.rv) - float(b2.rv))
			parts.append("RECOIL %s%.1f" % ["+" if dr >= 0 else "", dr])
			_label(right, "vs %s:  %s" % [ItemDB.display_name(cur), "   ".join(parts)], 14, Color(0.7, 0.85, 1.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	right.add_child(row)
	var e2 := sel
	match t:
		"weapon":
			_button(row, "EQUIP PRIMARY", func(): GameData.equip(int(e2.uid), "primary"); _rebuild())
			_button(row, "EQUIP SECONDARY", func(): GameData.equip(int(e2.uid), "secondary"); _rebuild())
		"melee", "armor":
			if GameData.is_equipped(int(e2.uid)):
				_button(row, "UNEQUIP", func():
					for s in GameData.equipped:
						if int(GameData.equipped[s]) == int(e2.uid):
							GameData.unequip(s)
					_rebuild())
			else:
				_button(row, "EQUIP", func(): GameData.equip(int(e2.uid)); _rebuild())
		"food", "drink", "med", "cure":
			_button(row, "USE", func():
				var id: String = e2.id
				if float(ItemDB.get_def(id).get("use_time", 0.0)) > 0.0:
					close()
					hud.player.request_use(id)
				else:
					GameData.use_item(id)
					if not GameData.inventory.has(e2):
						sel = {}
					_rebuild())
		"throwable":
			_button(row, "SET AS THROWABLE", func(): GameData.throwable = e2.id; GameData.touch(); _rebuild())
		"tool":
			if e2.id == "campfire_kit":
				_button(row, "BUILD CAMPFIRE", func(): close(); hud.player.place_campfire())
		"note":
			_button(row, "READ", func(): close(); GameData.banner(ItemDB.get_def(e2.id).name, ItemDB.get_def(e2.id).desc, Color(0.9, 0.85, 0.7)))
	if t != "note":
		_button(row, "DROP" if int(e2.get("count", 1)) <= 1 else "DROP ALL", func(): _drop(e2); sel = {}; _rebuild(), Color(1.0, 0.6, 0.5))
	_equip_summary(right)

func _equip_summary(parent: Node) -> void:
	_label(parent, "EQUIPPED", 14, Color(1.0, 0.75, 0.35))
	for s in ["primary", "secondary", "melee", "head", "body", "back"]:
		var e := GameData.weapon(s)
		var txt := "%-10s %s" % [s.to_upper(), ItemDB.display_name(e) + "  Lv%d" % int(e.get("level", 1)) if not e.is_empty() else "—"]
		_label(parent, txt, 15, _entry_color(e) if not e.is_empty() else Color(0.55, 0.55, 0.5))
	var d := GameData.derived()
	_label(parent, "Armor %.0f (%.0f%% damage reduction)   Warmth +%.0f   Carry %.0f kg" % [float(d.armor), float(d.dr) * 100.0, float(d.warmth), float(d.carry)], 14, Color(0.75, 0.8, 0.85))

func _drop(e: Dictionary) -> void:
	var p := hud.player
	var removed := {}
	if ItemDB.is_unique(e.id):
		removed = GameData.remove_uid(int(e.uid))
	else:
		removed = {"id": e.id, "count": int(e.count)}
		GameData.remove_item(e.id, int(e.count))
	if removed.is_empty():
		return
	var lp := LootPickup.new()
	lp.entry = removed
	p.world.add_child(lp)
	lp.global_position = p.global_position + (-p.global_transform.basis.z) * 1.2 + Vector3(0, 1.0, 0)
	lp.linear_velocity = -p.global_transform.basis.z * 2.0

# ---------------- skills ----------------
func _skills() -> void:
	for tree in ["gunslinger", "survivor", "scavenger", "curse"]:
		if tree == "curse" and GameData.curse == "":
			continue
		var col := _col(body, 290 if GameData.curse != "" else 390)
		var td: Dictionary = Skills.TREES[tree]
		_label(col, td.name, 20, td.color)
		_label(col, td.desc, 13, Color(0.7, 0.68, 0.62))
		for sid in Skills.in_tree(tree):
			var sd: Dictionary = Skills.SKILLS[sid]
			if tree == "curse" and sd.get("curse", "") != GameData.curse:
				continue
			var rank := GameData.skill_rank(sid)
			var pips := "●".repeat(rank) + "○".repeat(int(sd.max) - rank)
			var s2: String = sid
			var b := _button(col, "%s   %s" % [sd.name, pips], func():
				if GameData.learn(s2):
					_rebuild(), td.color.lightened(0.2) if rank > 0 else Color(0.85, 0.85, 0.8), 270)
			b.disabled = not GameData.can_learn(sid)
			b.tooltip_text = sd.desc
			_label(col, sd.desc, 12, Color(0.65, 0.63, 0.58))

# ---------------- survivor ----------------
func _survivor() -> void:
	var left := _col(body, 600)
	var bg: Dictionary = GameData.BACKGROUNDS.get(GameData.background, {})
	_label(left, "%s — %s, level %d" % [GameData.char_name, bg.get("name", "Survivor"), GameData.level], 22, Color(1.0, 0.85, 0.5))
	_label(left, bg.get("desc", ""), 14, Color(0.75, 0.72, 0.66))
	_label(left, "XP %d / %d" % [GameData.xp, GameData.xp_needed()], 15)
	var d := GameData.derived()
	_label(left, "Health %d / %d   Armor %.0f%%   Move speed %.1f m/s\nRecoil x%.2f   Handling x%.2f   Headshots x%.2f   Noise x%.2f\nCarry %.1f / %.0f kg   Warmth +%.0f   Loot luck +%.0f%%" % [
		int(GameData.hp), int(GameData.hp_max()), float(d.dr) * 100.0, float(d.move_speed), float(d.recoil_mul), float(d.handling_mul),
		float(d.head_mul), float(d.noise_mul), float(d.weight), float(d.carry), float(d.warmth), float(d.luck) * 100.0], 15, Color(0.8, 0.85, 0.9))
	var cond := []
	cond.append("Body temperature %.1f°C" % GameData.body_temp)
	if GameData.poison > 0.0:
		cond.append("Food poisoning (%d%%)" % int(GameData.poison))
	if GameData.curse != "":
		cond.append("%s — %s" % [GameData.CURSE_NAMES[GameData.curse], "TURNED (%s form)" % GameData.form if GameData.turned else "%d%% to turning" % int(GameData.curse_progress)])
	if GameData.rads > 0.0:
		cond.append("Radiation %d" % int(GameData.rads))
	_label(left, "CONDITIONS", 14, Color(1.0, 0.75, 0.35))
	_label(left, "\n".join(cond), 15)
	_label(left, "RECORD", 14, Color(1.0, 0.75, 0.35))
	_label(left, "Kills %d (undead %d)   Headshots %d   Containers looted %d   Days survived %d" % [int(GameData.stats.get("kills", 0)), int(GameData.stats.get("undead", 0)), int(GameData.stats.get("headshots", 0)), int(GameData.stats.get("looted", 0)), maxi(0, GameData.day() - int(GameData.stats.get("start_day", GameData.day())))], 15)
	var right := _scroll(body, 560)
	_label(right, "MEMORIAL", 18, Color(0.85, 0.85, 0.9))
	var mem: Array = GameData.world.get("memorial", [])
	if mem.is_empty():
		_label(right, "No one has died here. Yet.", 14, Color(0.6, 0.6, 0.6))
	for i in range(mem.size() - 1, -1, -1):
		var m: Dictionary = mem[i]
		_label(right, "✝ %s — %s, Lv %d. %d days, %d kills. %s%s" % [m.get("name", "?"), GameData.BACKGROUNDS.get(m.get("background", ""), {}).get("name", ""), int(m.get("level", 1)), int(m.get("days", 0)), int(m.get("kills", 0)), "Killed by " + String(m.get("cause", "?")), (" · rose as " + GameData.CURSE_NAMES.get(m.get("curse", ""), "")) if String(m.get("curse", "")) != "" else ""], 14, Color(0.78, 0.76, 0.72))

# ---------------- bounties ----------------
func _bounties() -> void:
	var col := _col(body, 1200)
	_label(col, "Bounties are posted at Haven's board. Complete them anywhere; claim the reward at the board.", 15, Color(0.75, 0.72, 0.66))
	for q in GameData.world.get("quests", []):
		var qd := GameData.quest_def(q.id)
		if qd.is_empty():
			continue
		_label(col, "%s%s" % ["✔ " if q.done else "", qd.name], 22, Color(0.6, 1.0, 0.6) if q.done else Color(1.0, 0.85, 0.5))
		_label(col, "%s   Progress %d/%d   Reward: %d XP, %d ✦%s" % [qd.desc, mini(int(q.progress), int(qd.goal)), int(qd.goal), int(qd.xp), int(qd.get("shards", 0)), ", plus gear" if String(qd.get("reward", "")) != "" else ""], 15)

# ---------------- stations ----------------
func _board() -> void:
	var col := _col(body, 1200)
	var done := 0
	for q in GameData.world.get("quests", []):
		if q.done:
			done += 1
	_bounties_into(col)
	if done > 0:
		_button(col, "CLAIM %d COMPLETED BOUNT%s" % [done, "Y" if done == 1 else "IES"], func():
			var n := GameData.claim_quests()
			GameData.banner("BOUNTIES CLAIMED", "%d reward%s collected. New bounties posted." % [n, "" if n == 1 else "s"], Color(0.55, 1.0, 0.6))
			_rebuild(), Color(0.6, 1.0, 0.6))
	else:
		_label(col, "Nothing to claim yet.", 15, Color(0.6, 0.6, 0.6))

func _bounties_into(col: Node) -> void:
	for q in GameData.world.get("quests", []):
		var qd := GameData.quest_def(q.id)
		if qd.is_empty():
			continue
		_label(col, "%s%s   %d/%d" % ["✔ " if q.done else "", qd.name, mini(int(q.progress), int(qd.goal)), int(qd.goal)], 20, Color(0.6, 1.0, 0.6) if q.done else Color(1.0, 0.85, 0.5))
		_label(col, qd.desc, 14)

func _roll_stock() -> void:
	if _stock_day == GameData.day() and not _stock.is_empty():
		return
	_stock_day = GameData.day()
	_stock.clear()
	var lvl := clampi(GameData.level, 1, 14)
	for i in 3:
		_stock.append(ItemDB.roll_weapon("", lvl, ItemDB.roll_rarity(lvl, 0.3)))
	_stock.append(ItemDB.roll_melee("", lvl, ItemDB.roll_rarity(lvl)))
	for i in 2:
		_stock.append(ItemDB.roll_armor("", lvl, ItemDB.roll_rarity(lvl)))
	_stock.append(ItemDB.roll_armor(["satchel", "hiking_pack", "military_pack"][mini(2, lvl / 4)], lvl, 1))
	for id in ["bandage", "medkit", "antibiotics", "clean_water", "beans", "frag", "molotov", "noisemaker", "fuel_can", "campfire_kit", "antiviral", "silverleaf_tincture", "sanguine_serum", "fishing_rod", "rad_flush"]:
		_stock.append({"id": id, "count": 1})
	for a in ItemDB.AMMO_PACK:
		_stock.append({"id": a, "count": int(ItemDB.AMMO_PACK[a][1])})

func _price(e: Dictionary) -> int:
	return maxi(1, int(ItemDB.value_of(e) * 1.6))

func _trader() -> void:
	_roll_stock()
	var left := _scroll(body, 580)
	_label(left, "SELL (half value)", 16, Color(1.0, 0.75, 0.35))
	for e in GameData.inventory:
		var entry: Dictionary = e
		if ItemDB.item_type(entry.id) == "note" or GameData.is_equipped(int(entry.get("uid", 0))):
			continue
		var each := maxi(1, int(ItemDB.value_of({"id": entry.id, "count": 1, "rarity": entry.get("rarity", 0), "level": entry.get("level", 1)}) * 0.5))
		var cnt := int(entry.get("count", 1))
		var sell_n := cnt if ItemDB.item_type(entry.id) in ["ammo", "material"] else 1
		_button(left, "%s  →  %d ✦%s" % [_entry_text(entry), each * sell_n, "" if sell_n == 1 else " (all)"], func():
			if ItemDB.is_unique(entry.id):
				GameData.remove_uid(int(entry.uid))
			else:
				GameData.remove_item(entry.id, sell_n)
			GameData.shards += each * sell_n
			SFX.play("pickup", -6.0, 0.8)
			GameData.touch()
			_rebuild(), _entry_color(entry), 560)
	var right := _scroll(body, 600)
	_label(right, "MAGS' STOCK (restocks daily)", 16, Color(1.0, 0.75, 0.35))
	for e in _stock:
		var item: Dictionary = e
		var price := _price(item)
		var b := _button(right, "%s  —  %d ✦" % [_entry_text(item), price], func():
			if GameData.shards < price:
				GameData.game_message("Not enough Glowshards.", Color(1, 0.5, 0.4))
				return
			GameData.shards -= price
			GameData.add_entry(item)
			_stock.erase(item)
			SFX.play("pickup", -4.0, 1.1)
			_rebuild(), _entry_color(item), 580)
		b.disabled = GameData.shards < price
		b.tooltip_text = ItemDB.describe(item)

func _upgrade_cost(e: Dictionary) -> Dictionary:
	var lvl := int(e.get("level", 1))
	return {"scrap": 3 + lvl * 2, "weapon_parts": 1 + lvl / 3, "shards": 12 * lvl}

func _workbench() -> void:
	var left := _scroll(body, 560)
	_label(left, "YOUR GEAR", 16, Color(1.0, 0.75, 0.35))
	for e in GameData.inventory:
		var entry: Dictionary = e
		if not ItemDB.is_unique(entry.id):
			continue
		var b := _button(left, _entry_text(entry), func():
			sel = entry
			_rebuild(), _entry_color(entry), 540)
		if sel == entry:
			_first_focus = b
	var right := _col(body, 620)
	_label(right, "Scrap %d   Weapon Parts %d   ✦ %d" % [GameData.count_item("scrap"), GameData.count_item("weapon_parts"), GameData.shards], 16, Color(0.8, 0.85, 0.9))
	if sel.is_empty() or not GameData.inventory.has(sel):
		_label(right, "Pick a weapon, melee weapon or armor piece to upgrade its level or break it down for parts.", 15)
		return
	_label(right, ItemDB.display_name(sel), 24, _entry_color(sel))
	_label(right, ItemDB.describe(sel), 14)
	var cost := _upgrade_cost(sel)
	var cap := GameData.level + 2
	var lvl := int(sel.get("level", 1))
	var can := lvl < cap and GameData.count_item("scrap") >= int(cost.scrap) and GameData.count_item("weapon_parts") >= int(cost.weapon_parts) and GameData.shards >= int(cost.shards)
	var e2 := sel
	var up := _button(right, "UPGRADE to Lv %d  —  %d scrap, %d parts, %d ✦" % [lvl + 1, int(cost.scrap), int(cost.weapon_parts), int(cost.shards)], func():
		GameData.remove_item("scrap", int(cost.scrap))
		GameData.remove_item("weapon_parts", int(cost.weapon_parts))
		GameData.shards -= int(cost.shards)
		e2["level"] = int(e2.level) + 1
		GameData.add_xp(30)
		SFX.play("skill", -4.0)
		GameData.touch()
		GameData.inventory_changed.emit()
		_rebuild(), Color(0.6, 1.0, 0.6))
	up.disabled = not can
	if lvl >= cap:
		_label(right, "Max upgrade level is your level + 2.", 13, Color(1.0, 0.6, 0.5))
	if not GameData.is_equipped(int(sel.uid)):
		_button(right, "DISMANTLE  (+%d scrap, +%d parts)" % [3 + int(sel.get("rarity", 0)) * 2, 1 + int(sel.get("rarity", 0))], func():
			var r := int(e2.get("rarity", 0))
			GameData.remove_uid(int(e2.uid))
			GameData.add_item("scrap", 3 + r * 2)
			GameData.add_item("weapon_parts", 1 + r)
			sel = {}
			SFX.play("equip", -4.0, 0.7)
			_rebuild(), Color(1.0, 0.65, 0.5))

func _cooking() -> void:
	var col := _col(body, 1200)
	_label(col, "Cook over the fire. Cooked food is safe and stronger; warm drinks fight the cold.", 15, Color(0.75, 0.72, 0.66))
	for r in RECIPES:
		var rec: Dictionary = r
		var have := true
		var parts := []
		for id in rec.inp:
			var need := int(rec.inp[id])
			var got := GameData.count_item(id)
			parts.append("%s %d/%d" % [ItemDB.get_def(id).name, got, need])
			if got < need:
				have = false
		var b := _button(col, "%s  ×%d     ←  %s" % [rec.name, int(rec.n), ",  ".join(parts)], func():
			for id in rec.inp:
				GameData.remove_item(id, int(rec.inp[id]))
			GameData.add_entry({"id": rec.out, "count": int(rec.n)})
			GameData.add_xp(int(rec.xp))
			GameData.progress("cook")
			SFX.play("sizzle", -4.0)
			_rebuild(), Color(1.0, 0.85, 0.6), 1100)
		b.disabled = not have

func _stash() -> void:
	var stash: Array = GameData.world.get("stash", [])
	var left := _scroll(body, 590)
	_label(left, "YOUR PACK  →  stash", 16, Color(1.0, 0.75, 0.35))
	for e in GameData.inventory:
		var entry: Dictionary = e
		if GameData.is_equipped(int(entry.get("uid", 0))):
			continue
		_button(left, _entry_text(entry), func():
			var moved := {}
			if ItemDB.is_unique(entry.id):
				moved = GameData.remove_uid(int(entry.uid))
			else:
				moved = {"id": entry.id, "count": int(entry.count)}
				GameData.remove_item(entry.id, int(entry.count))
			if not moved.is_empty():
				var merged := false
				if not ItemDB.is_unique(moved.id):
					for s in stash:
						if s.id == moved.id:
							s["count"] = int(s.count) + int(moved.count)
							merged = true
				if not merged:
					stash.append(moved)
				GameData.world["stash"] = stash
				GameData.save_world()
			_rebuild(), _entry_color(entry), 570)
	var right := _scroll(body, 590)
	_label(right, "HAVEN STASH  →  pack   (survives death)", 16, Color(1.0, 0.75, 0.35))
	for e in stash:
		var entry2: Dictionary = e
		_button(right, _entry_text(entry2), func():
			stash.erase(entry2)
			GameData.world["stash"] = stash
			GameData.add_entry(entry2, true)
			GameData.save_world()
			_rebuild(), _entry_color(entry2), 570)
	if stash.is_empty():
		_label(right, "Empty. Whatever you leave here outlives you.", 14, Color(0.6, 0.6, 0.6))
