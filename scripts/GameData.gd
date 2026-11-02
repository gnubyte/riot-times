extends Node
# GameData — the single source of truth for the player character:
# species, S.P.E.C.I.A.L.-ish stats, XP/level, hunger, rads, inventory, equipment.

signal state_changed
signal xp_gained(amount: int)
signal leveled_up(level: int)
signal item_added(id: String, count: int)
signal damage_taken(amount: float, source: String)
signal died
signal message_shown(text: String, color: Color)
signal enter_world
signal show_title

func game_message(text: String, color := Color(1, 1, 1)) -> void:
	message_shown.emit(text, color)

const SPECIAL := ["STR", "PER", "AGL", "END", "CHA", "INT", "LCK"]
const MAX_LEVEL_XP_BASE := 100.0
const INV_SIZE := 24

var species := "human"           # human | ghoul | robot
var char_name := "Wanderer"
var look := {}                   # customization choices from creator

var level := 1
var xp := 0
var stat_points := 0
var base_stats := {"STR":5, "PER":5, "AGL":5, "END":5, "CHA":5, "INT":5, "LCK":5}

var hp := 100.0
var hp_max := 100.0
var hunger := 100.0              # 0 = starving, 100 = full
var thirst := 100.0
var rads := 0.0

var inventory := []              # Array[Dictionary] {id, count}
var equipped := {"gun": "", "melee": "", "hat": "", "armor": ""}
var ammo_reserve := {}           # ammo_id -> count
var shards := 0                  # currency: Glowshards — irradiated glass slivers that faintly glow

var alive := true
var kills := {}                  # enemy_id -> count
var playtime := 0.0

# ---------- species profiles ----------
static func species_profile(s: String) -> Dictionary:
	match s:
		"ghoul":
			return {"hp": 90, "hunger_rate": 0.7, "rad_resist": 60.0, "speech": 1.25,
				"desc": "Radiation-proof, ugly, and hungry all the time. Mutant meat won't hurt you."}
		"robot":
			return {"hp": 130, "hunger_rate": 0.0, "rad_resist": 90.0, "speech": 0.6,
				"desc": "A stubborn pre-war synthoid. No hunger, huge damage soak, cannot eat or stim."}
		_:
			return {"hp": 100, "hunger_rate": 1.0, "rad_resist": 10.0, "speech": 1.0,
				"desc": "Soft, squishy, and stubbornly alive."}

func start_new(s: String, pname: String, custom := {}) -> void:
	species = s
	char_name = pname if pname.strip_edges() != "" else "Wanderer"
	look = custom.duplicate(true)
	level = 1; xp = 0; stat_points = 3
	base_stats = {"STR": 5, "PER": 5, "AGL": 5, "END": 5, "CHA": 5, "INT": 5, "LCK": 5}
	# species stat flavor
	match species:
		"ghoul": base_stats["END"] += 2; base_stats["CHA"] -= 3; base_stats["STR"] += 1
		"robot": base_stats["STR"] += 2; base_stats["AGL"] -= 1; base_stats["INT"] += 1; base_stats["CHA"] -= 2
		_: base_stats["CHA"] += 1
	hp_max = species_profile(species).hp + (base_stats.END - 5) * 8
	hp = hp_max
	hunger = 100.0; thirst = 100.0; rads = 0.0
	alive = true
	kills = {}
	playtime = 0.0
	inventory.clear()
	ammo_reserve = {"ammo_10mm": 24}
	shards = 50
	equipped = {"gun": "", "melee": "", "hat": "", "armor": ""}
	# starting kit
	add_item("pipe", 1)
	add_item("beans", 2)
	add_item("pistol", 1)
	add_item("ammo_10mm", 24)
	equip("pipe")
	equip("pistol")
	set_active_slot("gun")
	# magazine-loaded state for guns is stored per gun:
	loaded_ammo = {"pistol": 0, "smg": 0, "rifle": 0, "laser": 0}
	state_changed.emit()

# Loaded rounds per gun id (per weapon, not per ammo type).
var loaded_ammo := {}

# ---------- derived stats ----------
func stat(key: String) -> int:
	var v: int = base_stats.get(key, 5)
	for slot in ["hat", "armor"]:
		var id: String = equipped[slot]
		if id != "":
			var st = ItemDB.get_def(id).get("stat", null)
			if st != null and st is Dictionary:
				v += int(st.get(key, 0))
	return clampi(v, 1, 15)

func derived() -> Dictionary:
	var prof := species_profile(species)
	var dmg_mul := 1.0 + (stat("STR") - 5) * 0.06 + (level - 1) * 0.03
	var crit := clampf(0.05 + (stat("LCK") - 5) * 0.02 + (stat("PER") - 5) * 0.01, 0.02, 0.5)
	var dr := 0.0 + (stat("END") - 5) * 0.015
	dr += prof.rad_resist * 0.0
	for slot in ["hat", "armor"]:
		var id: String = equipped[slot]
		if id != "":
			dr += float(ItemDB.get_def(id).get("dr", 0.0))
	dr = clampf(dr, 0.0, 0.75)
	var rad_resist: float = prof.rad_resist
	for slot in ["hat", "armor"]:
		var id: String = equipped[slot]
		if id != "":
			rad_resist += float(ItemDB.get_def(id).get("rad_resist", 0.0))
	var move_speed := 5.0 + (stat("AGL") - 5) * 0.14
	var enc := 0.0
	for e in inventory:
		enc += float(ItemDB.get_def(e["id"]).get("weight", 0.0)) * int(e["count"])
	if enc > carry_capacity():
		move_speed *= 0.7
	return {
		"dmg_mul": dmg_mul, "crit": crit, "dr": dr, "rad_resist": rad_resist,
		"move_speed": move_speed, "carry": carry_capacity(), "encumbered": enc > carry_capacity(),
		"hunger_rate": prof.hunger_rate, "speech": prof.speech,
	}

func carry_capacity() -> float:
	return 40.0 + stat("STR") * 6.0 + level * 2.0

# ---------- inventory ----------
func add_item(id: String, count := 1) -> bool:
	if not ItemDB.ITEMS.has(id):
		push_warning("Unknown item %s" % id)
		return false
	var def := ItemDB.get_def(id)
	if def.type == "misc" and id == "shards":
		shards += count
		state_changed.emit()
		return true
	if def.type == "ammo":
		# ammo also goes to quick-reserve so reloads feel good
		ammo_reserve[id] = int(ammo_reserve.get(id, 0)) + count * int(def.get("ammo_count", 1))
		state_changed.emit()
		item_added.emit(id, count)
		return true
	var max_stack := int(def.get("stack", 1))
	for e in inventory:
		if e["id"] == id and e["count"] < max_stack:
			var space: int = max_stack - int(e["count"])
			var take := mini(space, count)
			e["count"] = int(e["count"]) + take
			count -= take
			if count <= 0:
				state_changed.emit(); item_added.emit(id, take); return true
	if inventory.size() < INV_SIZE and count > 0:
		inventory.append({"id": id, "count": count})
		state_changed.emit()
		item_added.emit(id, count)
		return true
	return inventory.size() > 0

func remove_item(id: String, count := 1) -> bool:
	var left := count
	for i in range(inventory.size() - 1, -1, -1):
		if inventory[i]["id"] == id:
			var take: int = mini(int(inventory[i]["count"]), left)
			inventory[i]["count"] = int(inventory[i]["count"]) - take
			left -= take
			if int(inventory[i]["count"]) <= 0:
				inventory.remove_at(i)
			if left <= 0:
				break
	if left < count:
		state_changed.emit()
		return true
	return false

func count_item(id: String) -> int:
	var c := 0
	for e in inventory:
		if e["id"] == id: c += int(e["count"])
	return c

func reserve_ammo(id: String) -> int:
	return int(ammo_reserve.get(id, 0))

func take_reserve(id: String, n: int) -> int:
	var have := reserve_ammo(id)
	var take := mini(have, n)
	ammo_reserve[id] = have - take
	state_changed.emit()
	return take

func give_reserve(id: String, n: int) -> void:
	ammo_reserve[id] = reserve_ammo(id) + n
	state_changed.emit()

func equip(id: String) -> bool:
	var def := ItemDB.get_def(id)
	if not def or count_item(id) <= 0:
		return false
	var slot: String = ""
	match def.type:
		"gun", "melee": slot = def.type
		"hat": slot = "hat"
		"armor": slot = "armor"
		_: return false
	# unequip current to inventory stays simple: it's still in inventory list.
	equipped[slot] = id
	if slot == "gun":
		if not loaded_ammo.has(id):
			loaded_ammo[id] = 0
	SFX.play("ui")
	state_changed.emit()
	return true

func unequip(slot: String) -> void:
	equipped[slot] = ""
	state_changed.emit()

func held_gun() -> String: return equipped.gun
func held_melee() -> String: return equipped.melee

# Single source of truth for "mouse is captured" (playing FPS mode).
# Headless test runs can't grab the OS cursor, so tests set force_captured.
var force_captured := false
func is_captured() -> bool:
	return force_captured or Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

func current_weapon_slot() -> String:
	return active_slot

var active_slot := "gun"   # gun | melee (which hand is up)

func set_active_slot(s: String) -> void:
	if equipped[s] == "" and s == "gun": return
	active_slot = s
	state_changed.emit()

# ---------- combat & survival ----------
func take_damage(amount: float, source := "generic") -> void:
	if not alive: return
	if OS.get_environment("RT_DEBUG_GOD") == "1":
		return
	var d := derived()
	amount = maxf(1.0, amount * (1.0 - d.dr))
	hp -= amount
	SFX.play("hurt", -4.0, randf_range(0.9, 1.1))
	damage_taken.emit(amount, source)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		died.emit()
	state_changed.emit()

func heal(amount: float) -> void:
	if species == "robot" and amount > 0:
		return # robots use fusion cores
	hp = clampf(hp + amount, 0.0, hp_max)
	state_changed.emit()

func heal_robot(amount: float) -> void:
	hp = clampf(hp + amount, 0.0, hp_max)
	state_changed.emit()

func add_radiation(amount: float) -> void:
	var resist: float = derived().rad_resist
	amount *= (1.0 - clampf(resist / 100.0, 0.0, 0.9))
	if amount <= 0: return
	rads += amount
	state_changed.emit()

func clear_radiation(amount: float) -> void:
	rads = maxf(0.0, rads - amount)
	state_changed.emit()

func eat(id: String) -> bool:
	var def := ItemDB.get_def(id)
	if def.get("type", "") not in ["food", "heal", "radaway"]:
		return false
	if count_item(id) <= 0:
		return false
	if species == "robot":
		if def.type == "heal" and not def.get("robots_only", false):
			return false
		if def.type == "food":
			return false
	if def.type == "heal" and def.get("robots_only", false) and species != "robot":
		return false
	remove_item(id, 1)
	if def.type == "radaway":
		clear_radiation(float(def.get("rad_clear", 30)))
		SFX.play("ui", -2.0, 1.4)
	else:
		hunger = clampf(hunger + float(def.get("hunger", 0)), 0.0, 100.0)
		thirst = clampf(thirst + float(def.get("hunger", 0)) * 0.5, 0.0, 100.0)
		var hpo: float = float(def.get("hp", 0))
		if hpo > 0:
			if species == "robot": heal_robot(hpo)
			else: heal(hpo)
		elif hpo < 0:
			take_damage(-hpo, "bad food")
		var r: float = float(def.get("rad", 0))
		if r > 0:
			if species == "ghoul" and id == "mut_meat":
				r = 0.0
			add_radiation(r)
		SFX.play("eat")
	state_changed.emit()
	return true

var hunger_tick_accum := 0.0
var starvation_accum := 0.0
func survival_tick(delta: float) -> void:
	if not alive: return
	playtime += delta
	if OS.get_environment("RT_DEBUG_GOD") == "1":
		return  # dev tool: no hunger/thirst/starvation drain (used by live tests)
	var d := derived()
	hunger_tick_accum += delta
	if hunger_tick_accum >= 1.0:
		hunger_tick_accum -= 1.0
		var rate := float(d.hunger_rate) * 0.28
		hunger = clampf(hunger - rate, 0.0, 100.0)
		thirst = clampf(thirst - rate * 0.8, 0.0, 100.0)
		# radiation sickness / regen
		if rads > hp_max * 0.6:
			starvation_accum += 1.0
			if starvation_accum >= 4.0:
				starvation_accum = 0.0
				take_damage(2.0, "radiation sickness")
		elif hunger <= 0.0:
			starvation_accum += 1.0
			if starvation_accum >= 5.0:
				starvation_accum = 0.0
				take_damage(3.0, "starvation")
		elif rads < hp_max * 0.25 and hunger > 40.0:
			# healthy & fed -> slow regen
			if hp < hp_max:
				hp = clampf(hp + 0.5, 0.0, hp_max)
				state_changed.emit()

# ---------- XP ----------
func xp_needed() -> int:
	return int(MAX_LEVEL_XP_BASE * pow(1.55, level - 1))

func add_xp(amount: int) -> void:
	if amount <= 0: return
	xp += amount
	xp_gained.emit(amount)
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		stat_points += 2
		hp_max += 6
		hp = hp_max
		leveled_up.emit(level)
		SFX.play("levelup")
	state_changed.emit()

func raise_stat(key: String) -> bool:
	if stat_points <= 0: return false
	base_stats[key] = base_stats[key] + 1
	stat_points -= 1
	hp_max = species_profile(species).hp + (base_stats.END - 5) * 8 + (level - 1) * 6
	state_changed.emit()
	return true

func record_kill(enemy_id: String) -> void:
	kills[enemy_id] = int(kills.get(enemy_id, 0)) + 1
	state_changed.emit()

signal respawn_requested
func revive_at() -> void:
	alive = true
	hp = hp_max
	hunger = clampf(hunger, 30.0, 100.0)
	thirst = clampf(thirst, 30.0, 100.0)
	rads = maxf(0.0, rads - hp_max * 0.3)
	state_changed.emit()
	respawn_requested.emit()

func save_game() -> bool:
	var f := FileAccess.open("user://riot_times_save.json", FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify({
		"species": species, "name": char_name, "look": look,
		"level": level, "xp": xp, "points": stat_points, "stats": base_stats,
		"hp": hp, "hp_max": hp_max, "hunger": hunger, "thirst": thirst, "rads": rads,
		"inv": inventory, "equipped": equipped, "ammo": ammo_reserve, "loaded": loaded_ammo,
		"shards": shards, "kills": kills, "playtime": playtime,
	}))
	f.close()
	return true

func has_save() -> bool:
	return FileAccess.file_exists("user://riot_times_save.json")

func load_game() -> bool:
	if not has_save(): return false
	var f := FileAccess.open("user://riot_times_save.json", FileAccess.READ)
	if f == null: return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY: return false
	species = data.get("species", "human")
	char_name = data.get("name", "Wanderer")
	look = data.get("look", {})
	level = int(data.get("level", 1)); xp = int(data.get("xp", 0))
	stat_points = int(data.get("points", 0))
	base_stats = data.get("stats", base_stats)
	hp = float(data.get("hp", 100)); hp_max = float(data.get("hp_max", 100))
	hunger = float(data.get("hunger", 100)); thirst = float(data.get("thirst", 100))
	rads = float(data.get("rads", 0))
	inventory = data.get("inv", [])
	equipped = data.get("equipped", equipped)
	ammo_reserve = data.get("ammo", {})
	loaded_ammo = data.get("loaded", {})
	# "caps" is the legacy key from the old bottle-cap economy saves
	shards = int(data.get("shards", data.get("caps", 0)))
	kills = data.get("kills", {})
	playtime = float(data.get("playtime", 0))
	alive = hp > 0
	state_changed.emit()
	return true
