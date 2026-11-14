extends Node
# GameData — the living survivor (ONE life: permadeath) and the persistent world
# (memorial, graves, Haven stash, bounties, day/time) that outlives every survivor.

signal state_changed
signal inventory_changed
signal xp_gained(amount: int)
signal leveled_up(level: int)
signal damage_taken(amount: float, source: String, from_pos: Vector3)
signal died(cause: String)
signal message_shown(text: String, color: Color)
signal banner_shown(title: String, sub: String, color: Color)
signal item_picked(entry: Dictionary)
signal item_used(id: String)
signal show_title
signal form_changed(form: String)
signal curse_changed(curse: String)
signal skills_changed
signal quests_changed
signal kill_registered(kind: String, headshot: bool)

const SURVIVOR_PATH := "user://rt_survivor.json"
const WORLD_PATH := "user://rt_world.json"
const LEVEL_CAP := 30
const MAX_GRAVES := 6

const BACKGROUNDS := {
	"soldier": {name="Soldier", desc="Ex-military. Tighter recoil, tougher hide. Starts with an assault rifle.", fx={recoil=-0.12, hp=10.0}},
	"medic": {name="Medic", desc="Heals hit harder, curses take longer. Starts with a pistol and a med bag.", fx={heal=0.4, infection=-0.3}},
	"mechanic": {name="Mechanic", desc="Vehicles last longer and sip fuel. Starts with a shotgun and a wrench.", fx={vehicle=0.25, carry=6.0}},
	"hunter": {name="Hunter", desc="Quiet and deadly at range. Starts with a crossbow, a knife and a rod.", fx={noise=-0.2, headshot=0.12}},
	"drifter": {name="Drifter", desc="Needs less, carries more, shrugs off cold. Starts with a revolver.", fx={needs=-0.2, warmth=5.0, carry=4.0}},
}

const QUEST_POOL := [
	{id="thin_herd", name="Thin the Herd", desc="Kill 25 undead.", stat="kill_undead", goal=25, xp=400, shards=80, reward="@weapon"},
	{id="headhunter", name="Headhunter", desc="Land 15 headshot kills.", stat="headshot", goal=15, xp=450, shards=90, reward="@melee"},
	{id="mall_rat", name="Mall Rat", desc="Loot 8 containers in the Galleria.", stat="loot_mall", goal=8, xp=600, shards=120, reward="@armor"},
	{id="silver_lining", name="Silver Lining", desc="Gather 3 Silverleaf herbs in Pinewood.", stat="silverleaf", goal=3, xp=350, shards=60, reward="silverleaf_tincture"},
	{id="specimen", name="Specimen G-9", desc="Recover the G-9 file from Black Site Halberd.", stat="note_g9", goal=1, xp=1200, shards=300, reward="@weapon_epic"},
	{id="scrapjaw", name="Off With His Crown", desc="Kill King Gnasher at the Scrapjaw Yard.", stat="kill_gnasher", goal=1, xp=900, shards=250, reward="@weapon_rare"},
	{id="goliath", name="The Bigger They Are", desc="Kill the Goliath in the Galleria atrium.", stat="kill_goliath", goal=1, xp=1000, shards=260, reward="@weapon_epic"},
	{id="angler", name="Gone Fishing", desc="Catch 4 fish at Pinewood lake.", stat="fish", goal=4, xp=250, shards=60, reward="stew"},
	{id="night_owl", name="Night Owl", desc="Kill 5 vampires or werewolves.", stat="kill_night", goal=5, xp=700, shards=150, reward="@weapon_rare"},
	{id="camp_cook", name="Camp Cook", desc="Cook 5 meals.", stat="cook", goal=5, xp=200, shards=40, reward="campfire_kit"},
	{id="raider_cull", name="Rust Never Sleeps", desc="Kill 12 Scrapjaws.", stat="kill_raider", goal=12, xp=500, shards=110, reward="@weapon"},
]

var input_mode := "kbm"      # kbm | pad — last device used (prompts, aim assist)
var force_captured := false  # headless tests can't grab the cursor

# ---------- the survivor ----------
var char_name := "Survivor"
var background := "drifter"
var look := {}
var level := 1
var xp := 0
var skill_points := 0
var skills := {}
var hp := 100.0
var hunger := 100.0
var thirst := 100.0
var blood := 70.0             # vampire satiation
var body_temp := 37.0
var rads := 0.0
var poison := 0.0             # food poisoning 0..100
var curse := ""               # "" | rot | wolf | vampire
var curse_progress := 0.0     # 0..100, turned at 100
var turned := false
var form := "human"           # human | wolf | vampire | zombie
var buffs := {}               # name -> seconds left
var inventory: Array = []
var equipped := {"primary": 0, "secondary": 0, "melee": 0, "head": 0, "body": 0, "back": 0}
var active_slot := "primary"
var throwable := "frag"
var shards := 0
var alive := true
var stats := {"kills": 0, "headshots": 0, "undead": 0, "looted": 0, "days": 0}
var playtime := 0.0
var since_damage := 0.0
var last_stand_day := -1
var discovered := {}
var player_pos := Vector3.ZERO
var player_yaw := 0.0
var has_position := false

# ---------- the world (persists across lives) ----------
var world := {}

var _derived := {}
var _dirty := true
var _god := false

func _ready() -> void:
	_god = OS.get_environment("RT_DEBUG_GOD") == "1"
	load_world()

func game_message(text: String, color := Color(1, 1, 1)) -> void:
	message_shown.emit(text, color)

func banner(title: String, sub := "", color := Color(1, 0.85, 0.4)) -> void:
	banner_shown.emit(title, sub, color)

func touch() -> void:
	_dirty = true
	state_changed.emit()

func _inv_touch() -> void:
	_dirty = true
	inventory_changed.emit()
	state_changed.emit()

func is_captured() -> bool:
	return force_captured or Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

# ---------- world clock ----------
func time_of_day() -> float:
	return float(world.get("time", 8.0))

func day() -> int:
	return int(world.get("day", 1))

func is_night() -> bool:
	var t := time_of_day()
	return t < 5.5 or t >= 20.0

func is_siege_night() -> bool:
	return day() % 3 == 0

# ---------- new survivor ----------
func start_new(pname: String, bg: String, look_cfg := {}) -> void:
	char_name = pname.strip_edges() if pname.strip_edges() != "" else "Survivor"
	background = bg if BACKGROUNDS.has(bg) else "drifter"
	look = look_cfg.duplicate(true)
	level = 1; xp = 0; skill_points = 1; skills = {}
	hunger = 85.0; thirst = 85.0; blood = 70.0; body_temp = 37.0; rads = 0.0; poison = 0.0
	curse = ""; curse_progress = 0.0; turned = false; form = "human"; buffs = {}
	inventory = []
	equipped = {"primary": 0, "secondary": 0, "melee": 0, "head": 0, "body": 0, "back": 0}
	active_slot = "primary"; throwable = "frag"
	shards = 25; alive = true; playtime = 0.0; since_damage = 99.0; last_stand_day = -1
	stats = {"kills": 0, "headshots": 0, "undead": 0, "looted": 0, "days": 0, "start_day": day()}
	discovered = {}
	has_position = false
	_give_kit(background)
	_dirty = true
	hp = derived().hp_max
	if world.get("quests", []).is_empty():
		_refill_quests()
	touch()
	inventory_changed.emit()
	save_survivor()

func _give_kit(bg: String) -> void:
	var gun := {}
	var melee := {}
	match bg:
		"soldier":
			gun = ItemDB.roll_weapon("ar", 1, 0); melee = ItemDB.roll_melee("knife", 1, 0)
			add_item("ammo_556", 60); add_item("frag", 1); add_item("bandage", 2)
			_equip_new(ItemDB.roll_armor("jacket", 1, 0))
		"medic":
			gun = ItemDB.roll_weapon("pistol", 1, 0); melee = ItemDB.roll_melee("knife", 1, 0)
			add_item("ammo_9mm", 45); add_item("medkit", 1); add_item("bandage", 4); add_item("antibiotics", 2)
			_equip_new(ItemDB.roll_armor("jacket", 1, 0))
		"mechanic":
			gun = ItemDB.roll_weapon("shotgun", 1, 0); melee = ItemDB.roll_melee("wrench", 1, 0)
			add_item("ammo_12g", 20); add_item("scrap", 6); add_item("weapon_parts", 3); add_item("bandage", 2)
			_equip_new(ItemDB.roll_armor("leather", 1, 0))
		"hunter":
			gun = ItemDB.roll_weapon("crossbow", 1, 0); melee = ItemDB.roll_melee("knife", 1, 1)
			add_item("bolts", 14); add_item("fishing_rod", 1); add_item("campfire_kit", 1); add_item("pine_needles", 4); add_item("bandage", 2)
			_equip_new(ItemDB.roll_armor("jacket", 1, 0))
		_:
			gun = ItemDB.roll_weapon("revolver", 1, 0); melee = ItemDB.roll_melee("machete", 1, 0)
			add_item("ammo_44", 18); add_item("jerky", 2); add_item("soda", 1); add_item("bandage", 2)
			_equip_new(ItemDB.roll_armor("beanie", 1, 0))
			_equip_new(ItemDB.roll_armor("satchel", 1, 0))
	add_item("beans", 2)
	add_item("clean_water", 2)
	_equip_new(gun)
	_equip_new(melee)
	# everyone gets a scrappy sidearm so the second slot isn't empty
	if bg != "medic":
		var side := ItemDB.roll_weapon("pistol", 1, 0)
		side["ammo"] = 15
		_equip_new(side, "secondary")
		add_item("ammo_9mm", 30)
	active_slot = "primary"

func _equip_new(e: Dictionary, slot := "") -> void:
	if e.is_empty():
		return
	add_entry(e, true)
	equip(int(e.uid), slot)

# ---------- derived stats (cached) ----------
func fx_sum() -> Dictionary:
	var fx := {}
	for sid in skills:
		var sd: Dictionary = Skills.SKILLS.get(sid, {})
		if sd.is_empty():
			continue
		if sd.tree == "curse" and sd.get("curse", "") != curse:
			continue
		for k in sd.fx:
			fx[k] = float(fx.get(k, 0.0)) + float(sd.fx[k]) * int(skills[sid])
	var bg: Dictionary = BACKGROUNDS.get(background, {}).get("fx", {})
	for k in bg:
		fx[k] = float(fx.get(k, 0.0)) + float(bg[k])
	return fx

func derived() -> Dictionary:
	if not _dirty and not _derived.is_empty():
		return _derived
	var fx := fx_sum()
	var armor := 0.0
	var warmth := float(fx.get("warmth", 0.0))
	var carry := 32.0 + float(fx.get("carry", 0.0))
	var gas := false
	var sun := false
	for slot in ["head", "body", "back"]:
		var e := find_uid(int(equipped[slot]))
		if e.is_empty():
			continue
		var a := ItemDB.armor_stats(e)
		armor += float(a.get("armor", 0.0))
		warmth += float(a.get("warmth", 0.0))
		carry += float(a.get("carry", 0.0))
		gas = gas or a.get("gas", false)
		sun = sun or a.get("sun", false)
	var hp_max := 100.0 + float(fx.get("hp", 0.0)) + (level - 1) * 3.0
	var speed := 5.2
	var dr := armor / (armor + 70.0)
	match form:
		"wolf":
			hp_max += 70.0; speed *= 1.45 * (1.0 + float(fx.get("wolf_power", 0.0)))
			dr = clampf(dr + 0.2 + float(fx.get("wolf_armor", 0.0)), 0.0, 0.8); carry += 30.0
		"vampire":
			hp_max += 25.0
			if is_night(): speed *= 1.18
		"zombie":
			hp_max += 90.0; speed *= 0.95; dr = clampf(dr + 0.25, 0.0, 0.8)
	if curse == "rot" and not turned and curse_progress > 70.0:
		hp_max -= 25.0   # fever
	if buffs.has("tough"):
		dr = clampf(dr + 0.25, 0.0, 0.85)
	var weight := total_weight()
	var over := weight / maxf(1.0, carry)
	var enc := over > 1.0
	if enc:
		speed *= clampf(1.0 - (over - 1.0) * 1.2, 0.45, 0.85)
	_derived = {
		"fx": fx, "armor": armor, "dr": dr, "warmth": warmth, "carry": carry, "weight": weight,
		"encumbered": enc, "load": over, "hp_max": hp_max, "move_speed": speed,
		"gas_mask": gas, "sun_shield": sun,
		"recoil_mul": maxf(0.3, 1.0 + float(fx.get("recoil", 0.0))),
		"handling_mul": 1.0 + float(fx.get("handling", 0.0)),
		"reload_mul": 1.0 + float(fx.get("reload", 0.0)),
		"mag_mul": 1.0 + float(fx.get("mag", 0.0)),
		"head_mul": 1.0 + float(fx.get("headshot", 0.0)),
		"noise_mul": maxf(0.25, 1.0 + float(fx.get("noise", 0.0))),
		"stamina_mul": 1.0 + float(fx.get("stamina", 0.0)),
		"melee_mul": 1.0 + float(fx.get("melee", 0.0)) + (0.6 if form == "vampire" and is_night() else 0.0),
		"stealth_add": float(fx.get("stealth", 0.0)),
		"luck": float(fx.get("luck", 0.0)),
		"needs_mul": maxf(0.3, 1.0 + float(fx.get("needs", 0.0))),
		"infection_mul": maxf(0.2, 1.0 + float(fx.get("infection", 0.0))),
		"heal_mul": 1.0 + float(fx.get("heal", 0.0)),
		"chef_mul": 1.0 + float(fx.get("chef", 0.0)),
		"vehicle": float(fx.get("vehicle", 0.0)),
		"regen": float(fx.get("regen", 0.0)),
		"kill_rush": float(fx.get("kill_rush", 0.0)),
		"air_spread": maxf(0.1, 1.0 + float(fx.get("air_spread", 0.0))),
		"poison_mul": maxf(0.1, 1.0 + float(fx.get("poison", 0.0))),
		"drain_mul": 1.0 + float(fx.get("vamp_drain", 0.0)),
		"sun_resist": clampf(float(fx.get("sun_resist", 0.0)), 0.0, 0.9),
		"rot_decay": maxf(0.1, 1.0 + float(fx.get("rot_decay", 0.0))),
		"last_stand": float(fx.get("last_stand", 0.0)) > 0.0,
	}
	_dirty = false
	return _derived

func hp_max() -> float:
	return float(derived().hp_max)

func can_use_guns() -> bool:
	return form == "human" or form == "vampire"

# ---------- inventory ----------
func add_entry(e: Dictionary, silent := false) -> void:
	var id: String = e.get("id", "")
	if id == "" or not ItemDB.exists(id):
		return
	var cnt := int(e.get("count", 1))
	if id == "shards":
		shards += cnt
		if not silent:
			item_picked.emit(e)
		touch()
		return
	if ItemDB.is_unique(id):
		var copy := e.duplicate(true)
		if not copy.has("uid"):
			copy["uid"] = ItemDB.new_uid()
		copy["count"] = 1
		inventory.append(copy)
	else:
		var merged := false
		for s in inventory:
			if s.id == id:
				s["count"] = int(s.count) + cnt
				merged = true
				break
		if not merged:
			inventory.append({"id": id, "count": cnt})
	if not silent:
		item_picked.emit(e)
	_inv_touch()

func add_item(id: String, count := 1) -> void:
	add_entry({"id": id, "count": count}, true)

func count_item(id: String) -> int:
	var c := 0
	for e in inventory:
		if e.id == id:
			c += int(e.count)
	return c

func remove_item(id: String, count := 1) -> bool:
	for i in range(inventory.size() - 1, -1, -1):
		var e: Dictionary = inventory[i]
		if e.id == id and not ItemDB.is_unique(id):
			var have := int(e.count)
			if have < count:
				return false
			e["count"] = have - count
			if int(e.count) <= 0:
				inventory.remove_at(i)
			_inv_touch()
			return true
	return false

func find_uid(uid: int) -> Dictionary:
	if uid == 0:
		return {}
	for e in inventory:
		if int(e.get("uid", -1)) == uid:
			return e
	return {}

func remove_uid(uid: int) -> Dictionary:
	for i in inventory.size():
		if int(inventory[i].get("uid", -1)) == uid:
			var e: Dictionary = inventory[i]
			inventory.remove_at(i)
			for slot in equipped:
				if int(equipped[slot]) == uid:
					equipped[slot] = 0
			_inv_touch()
			return e
	return {}

func total_weight() -> float:
	var w := 0.0
	for e in inventory:
		w += ItemDB.weight_of(e)
	return w

func weapon(slot: String) -> Dictionary:
	return find_uid(int(equipped.get(slot, 0)))

func active_weapon() -> Dictionary:
	return weapon(active_slot)

func melee_weapon() -> Dictionary:
	match form:
		"wolf": return {"id": "claws", "level": level, "rarity": 0}
		"vampire":
			if is_night():
				return {"id": "vamp_claws", "level": level, "rarity": 0}
		"zombie": return {"id": "rot_fists", "level": level, "rarity": 0}
	var m := weapon("melee")
	return m if not m.is_empty() else {"id": "fists", "level": 1, "rarity": 0}

func is_equipped(uid: int) -> bool:
	for s in equipped:
		if int(equipped[s]) == uid:
			return true
	return false

func equip(uid: int, slot := "") -> bool:
	var e := find_uid(uid)
	if e.is_empty():
		return false
	match ItemDB.item_type(e.id):
		"weapon":
			if slot != "primary" and slot != "secondary":
				if int(equipped.primary) == 0: slot = "primary"
				elif int(equipped.secondary) == 0: slot = "secondary"
				else: slot = active_slot
			for s in ["primary", "secondary"]:
				if int(equipped[s]) == uid:
					equipped[s] = 0
			equipped[slot] = uid
			active_slot = slot
		"melee":
			equipped.melee = uid
		"armor":
			equipped[ItemDB.ARMOR[e.id].slot] = uid
		_:
			return false
	SFX.play("equip", -8.0)
	_inv_touch()
	return true

func unequip(slot: String) -> void:
	equipped[slot] = 0
	_inv_touch()

func set_active_slot(s: String) -> void:
	if s == active_slot:
		return
	active_slot = s
	touch()

func owned_ammo_types() -> Array:
	var out := []
	for s in ["primary", "secondary"]:
		var w := weapon(s)
		if not w.is_empty():
			out.append(ItemDB.WEAPONS[w.id].ammo)
	return out

# ---------- consumables ----------
func can_use(id: String) -> String:
	var def := ItemDB.get_def(id)
	var t: String = def.get("type", "")
	if count_item(id) <= 0:
		return "You don't have that."
	if form == "wolf" and t != "cure":
		return "Wolves don't use items."
	match t:
		"food", "drink":
			if form == "vampire" and def.get("blood", 0.0) <= 0.0:
				return "Food turns to ash in your mouth. You need blood."
			if form == "zombie" and not def.get("raw", false):
				return "The Hollow only hungers for raw meat."
		"med":
			if form == "zombie":
				return "Medicine does nothing for the dead."
		"cure":
			var c: String = def.get("cure", "")
			if c == "rot" and (curse != "rot" or turned): return "No early Rot to cure." if curse != "rot" else "Too late for antivirals. You need Lazarus Serum."
			if c == "rot_turned" and curse != "rot": return "You aren't carrying the Rot."
			if c == "wolf" and curse != "wolf": return "You don't carry the wolf."
			if c == "vampire" and curse != "vampire": return "You aren't a vampire."
		"throwable", "tool", "material", "ammo", "valuable", "note", "currency":
			return "Can't consume that."
		"weapon", "melee", "armor":
			return "Equip it instead."
	return ""

func use_item(id: String) -> bool:
	var why := can_use(id)
	if why != "":
		game_message(why, Color(1, 0.6, 0.5))
		return false
	var def := ItemDB.get_def(id)
	var d := derived()
	remove_item(id, 1)
	var t: String = def.get("type", "")
	item_used.emit(id)
	if t == "food" or t == "drink":
		var cooked: bool = not def.get("raw", false) and id in ["cooked_meat", "cooked_fish", "stew", "pine_tea", "clean_water"]
		var mul: float = d.chef_mul if cooked else 1.0
		if form == "vampire":
			blood = clampf(blood + float(def.get("blood", 0.0)), 0.0, 100.0)
			SFX.play("drink", -4.0, 0.8)
		elif form == "zombie":
			hp = minf(hp_max(), hp + 30.0)
			buffs["fed"] = 90.0
			SFX.play("eat", -2.0, 0.7)
		else:
			hunger = clampf(hunger + float(def.get("hunger", 0.0)) * mul, 0.0, 100.0)
			thirst = clampf(thirst + float(def.get("thirst", 0.0)) * mul, 0.0, 100.0)
			hp = clampf(hp + float(def.get("hp", 0.0)) * mul, 0.0, hp_max())
			body_temp += float(def.get("warm", 0.0)) * mul
			if def.has("stamina"):
				buffs["energized"] = 20.0
			if def.has("rads"):
				rads += float(def.rads)
			var pc: float = float(def.get("poison", 0.0)) * float(d.poison_mul)
			if pc > 0.0 and randf() < pc:
				poison = clampf(poison + 55.0, 0.0, 100.0)
				game_message("Your stomach lurches. Food poisoning.", Color(0.7, 0.9, 0.3))
			if form == "wolf" and def.get("raw", false):
				hunger = clampf(hunger + 10.0, 0.0, 100.0)
			SFX.play("drink" if t == "drink" else "eat", -3.0)
	elif t == "med":
		hp = clampf(hp + float(def.get("hp", 0.0)) * d.heal_mul, 0.0, hp_max())
		if def.get("buff", "") == "tough":
			buffs["tough"] = 30.0
		if def.get("cure", "") == "poison":
			poison = 0.0
		if def.has("rot_slow") and curse == "rot" and not turned:
			curse_progress = maxf(0.0, curse_progress - float(def.rot_slow))
		if def.has("rads"):
			rads = maxf(0.0, rads + float(def.rads))
		SFX.play("heal", -4.0)
	elif t == "cure":
		cure_curse()
		SFX.play("levelup", -6.0, 0.8)
	touch()
	return true

# ---------- damage ----------
func take_damage(amount: float, source := "", from_pos := Vector3.INF, kind := "") -> float:
	if not alive or amount <= 0.0:
		return 0.0
	var d := derived()
	amount *= (1.0 - float(d.dr))
	if _god:
		amount = 0.0
	hp -= amount
	since_damage = 0.0
	match kind:
		"zombie":
			if form == "human" and randf() < 0.09 * float(d.infection_mul):
				infect("rot", 22.0)
		"wolf":
			if form == "human" and randf() < 0.3 * float(d.infection_mul):
				infect("wolf", 15.0)
		"vampire":
			if form == "human" and randf() < 0.3 * float(d.infection_mul):
				infect("vampire", 15.0)
		"gas":
			if not d.gas_mask and form == "human":
				infect("rot", amount * 0.8)
	if hp <= 0.0:
		if d.last_stand and last_stand_day != day():
			hp = 1.0
			last_stand_day = day()
			buffs["tough"] = 3.0
			banner("LAST STAND", "Not today.", Color(1, 0.35, 0.25))
		else:
			hp = 0.0
			damage_taken.emit(amount, source, from_pos)
			die(source)
			return amount
	damage_taken.emit(amount, source, from_pos)
	return amount

func heal(amount: float) -> void:
	hp = clampf(hp + amount, 0.0, hp_max())

# Armor-ignoring attrition (sun, thirst for blood): no hit flash, no flinch.
var burning_sun := false
func drain(amount: float, cause: String) -> void:
	if not alive or _god:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		die(cause)

# ---------- curses ----------
const CURSE_NAMES := {"rot": "THE ROT", "wolf": "LYCANTHROPY", "vampire": "VAMPIRISM"}

func infect(c: String, amount: float) -> void:
	if c == "":
		return
	if curse != "" and curse != c:
		return   # one curse at a time
	var fresh := curse == ""
	curse = c
	if not turned:
		curse_progress = clampf(curse_progress + amount * float(derived().infection_mul), 0.0, 100.0)
	if fresh:
		banner("INFECTED: %s" % CURSE_NAMES[c], _curse_hint(c), Color(0.85, 0.25, 0.35))
		curse_changed.emit(curse)
		touch()

func _curse_hint(c: String) -> String:
	match c:
		"rot": return "Find an Antiviral Shot before it takes you. Pharmacies, the lab."
		"wolf": return "Silverleaf Tincture can burn it out. Or embrace the moon."
		"vampire": return "Sanguine Serum restores you. Until then, fear the sun."
	return ""

func _turn() -> void:
	turned = true
	curse_progress = 100.0
	match curse:
		"rot":
			form = "zombie"
			banner("YOU HAVE TURNED", "The dead no longer see you. You are Hollow. Eat raw meat or rot away.", Color(0.5, 0.85, 0.35))
		"wolf":
			banner("THE WOLF IS IN YOU", "At night, you will change.", Color(0.85, 0.5, 0.2))
			if is_night():
				form = "wolf"
		"vampire":
			form = "vampire"
			blood = 60.0
			banner("YOU HAVE TURNED", "Vampire. The night is yours. The sun will kill you.", Color(0.9, 0.15, 0.25))
	_dirty = true
	hp = minf(hp_max(), hp + 40.0)
	form_changed.emit(form)
	curse_changed.emit(curse)
	touch()

func cure_curse() -> void:
	if curse == "":
		return
	var was := curse
	curse = ""
	curse_progress = 0.0
	turned = false
	var old_form := form
	form = "human"
	_dirty = true
	hp = minf(hp, hp_max())
	banner("CURED", "%s is gone from your blood." % CURSE_NAMES[was], Color(0.6, 0.95, 1.0))
	if old_form != "human":
		form_changed.emit(form)
	curse_changed.emit(curse)
	touch()

func _curse_tick(delta: float, env: Dictionary) -> void:
	if curse == "":
		return
	var d := derived()
	if not turned:
		var rate := {"rot": 0.11, "wolf": 0.085, "vampire": 0.09}.get(curse, 0.1) as float
		curse_progress += rate * delta * float(d.infection_mul)
		if curse_progress >= 100.0:
			_turn()
		return
	match curse:
		"wolf":
			var want := "wolf" if is_night() else "human"
			if want != form:
				form = want
				_dirty = true
				if form == "wolf":
					banner("THE MOON TAKES YOU", "Claws out. No guns. Hunt.", Color(0.95, 0.55, 0.2))
				else:
					hunger = minf(hunger, 25.0)
					banner("DAWN", "You wake human, starving, covered in blood.", Color(0.9, 0.8, 0.6))
				hp = minf(hp, hp_max())
				form_changed.emit(form)
				touch()
			if form == "wolf":
				heal(1.4 * delta)
		"vampire":
			burning_sun = bool(env.get("sunlit", false)) and not d.sun_shield
			if burning_sun:
				drain(4.0 * delta * (1.0 - float(d.sun_resist)), "the sun")
		"zombie", "rot":
			if not buffs.has("fed"):
				hp -= 0.12 * delta * float(d.rot_decay)
				if hp <= 0.0:
					hp = 0.0
					die("rotted away")

# ---------- per-frame survival ----------
var _sick_t := 0.0
func survival_tick(delta: float, env: Dictionary) -> void:
	if not alive:
		return
	playtime += delta
	since_damage += delta
	for b in buffs.keys():
		buffs[b] = float(buffs[b]) - delta
		if float(buffs[b]) <= 0.0:
			buffs.erase(b)
			_dirty = true
	if _god:
		return
	var d := derived()
	var nm: float = d.needs_mul
	var hot := float(env.get("ambient", 15.0)) > 30.0
	match form:
		"zombie":
			pass
		"vampire":
			blood = maxf(0.0, blood - 0.045 * delta)
			if blood <= 0.0:
				drain(0.7 * delta, "blood thirst")
		_:
			var hm := 2.4 if form == "wolf" else (1.5 if env.get("sprinting", false) else 1.0)
			if curse == "wolf" and not turned and curse_progress > 50.0:
				hm *= 1.4
			hunger = maxf(0.0, hunger - 0.05 * delta * nm * hm)
			thirst = maxf(0.0, thirst - 0.068 * delta * nm * (1.6 if hot else 1.0) * (1.3 if env.get("sprinting", false) else 1.0))
			if hunger <= 0.0:
				hp -= 0.45 * delta
			if thirst <= 0.0:
				hp -= 0.7 * delta
	# temperature: body drifts toward what you feel
	if form == "human":
		var felt := float(env.get("ambient", 15.0)) + float(d.warmth) * 0.55
		if env.get("fire", false):
			felt += 18.0
		if env.get("wet", false):
			felt -= 12.0
		if felt < 12.0:
			body_temp -= (12.0 - felt) * 0.0026 * delta
		elif felt > 33.0:
			body_temp += (felt - 33.0) * 0.003 * delta
		else:
			body_temp = move_toward(body_temp, 37.0, 0.035 * delta)
		body_temp = clampf(body_temp, 31.0, 40.5)
		if body_temp < 34.0:
			hp -= 0.55 * delta
	else:
		body_temp = move_toward(body_temp, 37.0, 0.2 * delta)
	# sickness
	if poison > 0.0:
		poison = maxf(0.0, poison - 0.35 * delta)
		thirst = maxf(0.0, thirst - 0.09 * delta)
		_sick_t -= delta
		if _sick_t <= 0.0:
			_sick_t = randf_range(18.0, 34.0)
			if poison > 20.0:
				hunger = maxf(0.0, hunger - 12.0)
				thirst = maxf(0.0, thirst - 10.0)
				SFX.play("vomit", -4.0)
				game_message("You retch. Antibiotics would help.", Color(0.7, 0.9, 0.3))
	if rads > 60.0:
		hp -= 0.25 * delta
	# regeneration when fed, watered and safe
	if form != "zombie" and since_damage > 5.0 and hunger > 25.0 and thirst > 25.0 and poison <= 0.0 and body_temp > 35.0:
		hp = minf(hp_max(), hp + (0.12 + float(d.regen)) * delta)
	_curse_tick(delta, env)
	if hp <= 0.0 and alive:
		var cause := "starvation" if hunger <= 0.0 else ("dehydration" if thirst <= 0.0 else ("hypothermia" if body_temp < 34.0 else "sickness"))
		hp = 0.0
		die(cause)

# ---------- XP & skills ----------
func xp_needed() -> int:
	return int(120.0 * pow(float(level), 1.45))

func add_xp(amount: int, reason := "") -> void:
	if amount <= 0 or not alive:
		return
	xp += amount
	xp_gained.emit(amount)
	while level < LEVEL_CAP and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 2 if level % 5 == 0 else 1
		_dirty = true
		hp = hp_max()
		leveled_up.emit(level)
		SFX.play("levelup", -4.0)
	touch()

func skill_rank(sid: String) -> int:
	return int(skills.get(sid, 0))

func can_learn(sid: String) -> bool:
	var sd: Dictionary = Skills.SKILLS.get(sid, {})
	if sd.is_empty() or skill_points <= 0 or skill_rank(sid) >= int(sd.max):
		return false
	if sd.tree == "curse" and sd.get("curse", "") != curse:
		return false
	return true

func learn(sid: String) -> bool:
	if not can_learn(sid):
		return false
	skills[sid] = skill_rank(sid) + 1
	skill_points -= 1
	_dirty = true
	SFX.play("skill", -4.0)
	skills_changed.emit()
	touch()
	return true

# ---------- kills, discovery, bounties ----------
func register_kill(kind: String, faction: String, headshot: bool, xp_value: int) -> void:
	stats["kills"] = int(stats.get("kills", 0)) + 1
	if headshot:
		stats["headshots"] = int(stats.get("headshots", 0)) + 1
		progress("headshot")
	if faction == "undead":
		stats["undead"] = int(stats.get("undead", 0)) + 1
		progress("kill_undead")
	if faction == "raider":
		progress("kill_raider")
	if kind in ["werewolf", "vampire"]:
		progress("kill_night")
	if kind == "gnasher":
		progress("kill_gnasher")
	if kind == "goliath":
		progress("kill_goliath")
	if form == "wolf":
		hunger = minf(100.0, hunger + 8.0)
	add_xp(int(xp_value * (1.35 if headshot else 1.0)))
	kill_registered.emit(kind, headshot)

func discover(poi: String, title: String, xp_value := 120) -> void:
	if discovered.has(poi):
		return
	discovered[poi] = true
	banner(title, "Discovered  +%d XP" % xp_value, Color(0.95, 0.85, 0.55))
	add_xp(xp_value)

func _refill_quests() -> void:
	var active: Array = world.get("quests", [])
	var have := {}
	for q in active:
		have[q.id] = true
	var pool := QUEST_POOL.duplicate()
	pool.shuffle()
	for q in pool:
		if active.size() >= 3:
			break
		if have.has(q.id):
			continue
		active.append({"id": q.id, "progress": 0, "done": false})
	world["quests"] = active
	quests_changed.emit()

func quest_def(qid: String) -> Dictionary:
	for q in QUEST_POOL:
		if q.id == qid:
			return q
	return {}

func progress(stat: String, n := 1) -> void:
	var changed := false
	for q in world.get("quests", []):
		var qd := quest_def(q.id)
		if qd.is_empty() or q.done or qd.stat != stat:
			continue
		q["progress"] = int(q.progress) + n
		changed = true
		if int(q.progress) >= int(qd.goal):
			q["done"] = true
			banner("BOUNTY COMPLETE", "%s — claim it at Haven's board." % qd.name, Color(0.55, 1.0, 0.6))
			SFX.play("quest", -4.0)
	if changed:
		quests_changed.emit()

func claim_quests() -> int:
	var claimed := 0
	var keep := []
	for q in world.get("quests", []):
		if not q.done:
			keep.append(q)
			continue
		var qd := quest_def(q.id)
		claimed += 1
		add_xp(int(qd.xp))
		shards += int(qd.get("shards", 0))
		var rw: String = qd.get("reward", "")
		match rw:
			"@weapon": add_entry(ItemDB.roll_weapon("", level, maxi(1, ItemDB.roll_rarity(level))))
			"@weapon_rare": add_entry(ItemDB.roll_weapon("", level, maxi(2, ItemDB.roll_rarity(level))))
			"@weapon_epic": add_entry(ItemDB.roll_weapon("", level, maxi(3, ItemDB.roll_rarity(level, 0.5))))
			"@armor": add_entry(ItemDB.roll_armor("", level, maxi(2, ItemDB.roll_rarity(level))))
			"@melee": add_entry(ItemDB.roll_melee("", level, maxi(2, ItemDB.roll_rarity(level))))
			"": pass
			_: add_entry({"id": rw, "count": 1})
	world["quests"] = keep
	_refill_quests()
	touch()
	return claimed

# ---------- death (permanent) ----------
func die(cause: String) -> void:
	if not alive:
		return
	alive = false
	var rise := ""
	if curse != "" and (turned or curse_progress >= 50.0):
		rise = curse
	var graves: Array = world.get("graves", [])
	graves.append({
		"pos": [player_pos.x, player_pos.y, player_pos.z], "name": char_name, "level": level,
		"curse": rise, "items": inventory.duplicate(true), "shards": int(shards * 0.6),
		"day": day(), "gid": ItemDB.new_uid(),
	})
	while graves.size() > MAX_GRAVES:
		graves.pop_front()
	world["graves"] = graves
	var mem: Array = world.get("memorial", [])
	mem.append({"name": char_name, "background": background, "level": level,
		"days": maxi(0, day() - int(stats.get("start_day", day()))), "kills": int(stats.get("kills", 0)),
		"cause": cause, "curse": rise, "died_day": day()})
	world["memorial"] = mem
	delete_survivor()
	save_world()
	died.emit(cause)
	touch()

func remove_grave(gid: int) -> void:
	var graves: Array = world.get("graves", [])
	for i in graves.size():
		if int(graves[i].get("gid", -1)) == gid:
			graves.remove_at(i)
			break
	world["graves"] = graves

# ---------- persistence ----------
func _default_world() -> Dictionary:
	return {"day": 1, "time": 8.5, "memorial": [], "graves": [], "stash": [], "quests": [],
		"haven": {"level": 1}, "vehicles": []}

func load_world() -> void:
	world = _default_world()
	if not FileAccess.file_exists(WORLD_PATH):
		return
	var f := FileAccess.open(WORLD_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			world[k] = data[k]
	_fix_ints(world.get("stash", []))
	for g in world.get("graves", []):
		_fix_ints(g.get("items", []))

func save_world() -> void:
	var f := FileAccess.open(WORLD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(world))

func has_survivor() -> bool:
	return FileAccess.file_exists(SURVIVOR_PATH)

func save_survivor() -> bool:
	if not alive:
		return false
	var f := FileAccess.open(SURVIVOR_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({
		"name": char_name, "background": background, "look": look, "level": level, "xp": xp,
		"points": skill_points, "skills": skills, "hp": hp, "hunger": hunger, "thirst": thirst,
		"blood": blood, "temp": body_temp, "rads": rads, "poison": poison, "curse": curse,
		"curse_progress": curse_progress, "turned": turned, "form": form, "inv": inventory,
		"equipped": equipped, "active": active_slot, "throwable": throwable, "shards": shards,
		"stats": stats, "playtime": playtime, "discovered": discovered, "last_stand": last_stand_day,
		"pos": [player_pos.x, player_pos.y, player_pos.z], "yaw": player_yaw,
	}))
	save_world()
	return true

func autosave() -> void:
	if alive:
		save_survivor()

func load_survivor() -> bool:
	if not has_survivor():
		return false
	var f := FileAccess.open(SURVIVOR_PATH, FileAccess.READ)
	if f == null:
		return false
	var s = JSON.parse_string(f.get_as_text())
	if typeof(s) != TYPE_DICTIONARY:
		return false
	char_name = s.get("name", "Survivor"); background = s.get("background", "drifter"); look = s.get("look", {})
	level = int(s.get("level", 1)); xp = int(s.get("xp", 0)); skill_points = int(s.get("points", 0))
	skills = {}
	var sk: Dictionary = s.get("skills", {})
	for k in sk:
		skills[k] = int(sk[k])
	hp = float(s.get("hp", 100)); hunger = float(s.get("hunger", 80)); thirst = float(s.get("thirst", 80))
	blood = float(s.get("blood", 70)); body_temp = float(s.get("temp", 37)); rads = float(s.get("rads", 0))
	poison = float(s.get("poison", 0)); curse = s.get("curse", ""); curse_progress = float(s.get("curse_progress", 0))
	turned = bool(s.get("turned", false)); form = s.get("form", "human")
	inventory = s.get("inv", []); _fix_ints(inventory)
	var eq: Dictionary = s.get("equipped", {})
	for k in equipped:
		equipped[k] = int(eq.get(k, 0))
	active_slot = s.get("active", "primary"); throwable = s.get("throwable", "frag")
	shards = int(s.get("shards", 0)); stats = s.get("stats", stats); playtime = float(s.get("playtime", 0))
	discovered = s.get("discovered", {}); last_stand_day = int(s.get("last_stand", -1))
	var p: Array = s.get("pos", [])
	if p.size() == 3:
		player_pos = Vector3(p[0], p[1], p[2])
		player_yaw = float(s.get("yaw", 0.0))
		has_position = true
	alive = true
	_dirty = true
	touch()
	inventory_changed.emit()
	return true

func delete_survivor() -> void:
	if FileAccess.file_exists(SURVIVOR_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SURVIVOR_PATH))

# JSON turns every number into a float; restore the integer fields.
func _fix_ints(arr: Array) -> void:
	for e in arr:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		for k in ["count", "uid", "rarity", "level", "ammo"]:
			if e.has(k):
				e[k] = int(e[k])
