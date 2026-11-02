extends Node
# The Director paces the wasteland: the clock (20 real minutes per day), ambient
# population around you, HORDE RUSHES once you've been comfortable too long, Haven
# SIEGES every third night, night hunters (werewolves, vampires, a roaming Gaunt)
# and screamer reinforcements.

class_name Director

const DAY_SECONDS := 1200.0
const POP := {"haven": 2, "wild": 7, "forest": 3, "downtown": 14, "mall": 3, "sublevel": 1, "raider": 1, "military": 7, "lab": 1}

var world: World
var dynamic: Array = []
var calm_t := 0.0
var horde_cd := 260.0
var _spawn_t := 4.0
var _queue: Array = []
var _was_night := false
var _siege_day := -1
var siege_active := false
var siege_wave := 0
var siege_t := 0.0
var siege_mobs: Array = []
var _warned_day := -1
var _night_gaunt: Monster = null
var _gaunt_rolled_day := -1
var _heartbeat_t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("director")
	_rng.randomize()
	_was_night = GameData.is_night()

func _process(delta: float) -> void:
	if world == null or world.player == null or not GameData.alive:
		return
	_clock(delta)
	_drain_queue()
	var p := world.player
	var engaged := false
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.state == "chase" and m.target == p:
			engaged = true
			break
	calm_t = 0.0 if engaged else calm_t + delta
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = 2.5
		_population()
	horde_cd -= delta
	var zone := world.zone_at(p.global_position)
	if horde_cd <= 0.0 and calm_t > 70.0 and zone in ["downtown", "wild", "military", "forest"] and OS.get_environment("RT_NO_HORDES") != "1":
		horde_rush()
	_siege(delta)
	# low-HP heartbeat
	if GameData.hp < GameData.hp_max() * 0.3:
		_heartbeat_t -= delta
		if _heartbeat_t <= 0.0:
			_heartbeat_t = 0.85
			SFX.play("heartbeat", -6.0)

# ---------------- clock ----------------
func _clock(delta: float) -> void:
	var t := GameData.time_of_day() + delta * 24.0 / DAY_SECONDS
	if t >= 24.0:
		t -= 24.0
		GameData.world["day"] = GameData.day() + 1
		GameData.stats["days"] = int(GameData.stats.get("days", 0)) + 1
		GameData.banner("DAY %d" % GameData.day(), "You made it through another night.", Color(1.0, 0.85, 0.5))
		GameData.add_xp(60)
	GameData.world["time"] = t
	var night := GameData.is_night()
	if night != _was_night:
		_was_night = night
		if night:
			GameData.banner("NIGHT FALLS", "Colder. Darker. Louder. Better loot, worse company.", Color(0.6, 0.7, 1.0))
		else:
			GameData.banner("DAWN", "The night hunters crawl back into the dark.", Color(1.0, 0.8, 0.5))
	if GameData.is_siege_night() and t >= 19.0 and t < 22.0 and _warned_day != GameData.day():
		_warned_day = GameData.day()
		GameData.banner("SIEGE TONIGHT", "The horde comes for Haven at 22:00. Man the gates.", Color(1.0, 0.35, 0.25))
		SFX.play("bell", -2.0)

func skip_hours(h: float) -> void:
	var t := GameData.time_of_day() + h
	while t >= 24.0:
		t -= 24.0
		GameData.world["day"] = GameData.day() + 1
	GameData.world["time"] = t
	_was_night = GameData.is_night()

func hostiles_near(pos: Vector3, r: float) -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.faction in ["undead", "beast", "raider"] and (m as Node3D).global_position.distance_to(pos) < r:
			n += 1
	return n

# ---------------- population ----------------
func _population() -> void:
	var p := world.player.global_position
	var zone := world.zone_at(p)
	var night := GameData.is_night()
	for i in range(dynamic.size() - 1, -1, -1):
		var m = dynamic[i]
		if not is_instance_valid(m) or m.dead:
			dynamic.remove_at(i)
			continue
		if (m as Node3D).global_position.distance_to(p) > 160.0 and not m.horde:
			m.queue_free()
			dynamic.remove_at(i)
	var budget: int = POP.get(zone, 5)
	if night:
		budget = int(budget * 1.6) + 2
	var near := 0
	for m in dynamic:
		if (m as Node3D).global_position.distance_to(p) < 110.0:
			near += 1
	if near < budget:
		var kind := _pick_kind(zone, night)
		var under := zone in ["mall", "sublevel", "lab"]
		var sp := _spawn_point(p, 45.0, 85.0, under)
		if sp != Vector3.INF:
			var n := 1 if kind in ["brute", "screamer", "bloater", "boar", "deer"] else _rng.randi_range(1, 3)
			for k in n:
				_queue.append([kind, sp + Vector3(_rng.randf_range(-2, 2), 0, _rng.randf_range(-2, 2)), {}])
	if night:
		if zone == "forest" and _count("werewolf") < 2 and _rng.randf() < 0.25:
			var wp := _spawn_point(p, 50.0, 80.0, false)
			if wp != Vector3.INF:
				_queue.append(["werewolf", wp, {"night_only": true}])
		if zone in ["downtown", "wild"] and _count("vampire") < 2 and _rng.randf() < 0.18:
			var vp := _spawn_point(p, 45.0, 75.0, false)
			if vp != Vector3.INF:
				_queue.append(["vampire", vp, {"night_only": true}])
		if zone == "downtown" and _gaunt_rolled_day != GameData.day() and GameData.time_of_day() > 21.0:
			_gaunt_rolled_day = GameData.day()
			if _rng.randf() < 0.4 and (_night_gaunt == null or not is_instance_valid(_night_gaunt)):
				var gp := _spawn_point(p, 90.0, 120.0, false)
				if gp != Vector3.INF:
					_night_gaunt = world.spawn_monster("gaunt", gp, 8, {"night_only": true, "leash": 200.0, "name": "The Gaunt"})
					dynamic.append(_night_gaunt)
					SFX.play("gaunt_shriek", -10.0, 0.8)
					GameData.game_message("Something shrieks in the distance. Keep quiet tonight.", Color(0.8, 0.8, 0.9))

func _count(kind: String) -> int:
	var n := 0
	for m in dynamic:
		if is_instance_valid(m) and m.kind == kind:
			n += 1
	return n

func _pick_kind(zone: String, night: bool) -> String:
	var r := _rng.randf()
	match zone:
		"forest":
			if not night and r < 0.5:
				return "deer" if _rng.randf() < 0.6 else "boar"
			return "walker" if r < 0.85 else "runner"
		"military":
			if r < 0.08: return "brute"
			if r < 0.13: return "screamer"
			return "runner" if r < 0.5 else "walker"
		"downtown":
			if r < 0.05: return "brute"
			if r < 0.09: return "screamer"
			if r < 0.15: return "bloater"
			return "runner" if r < (0.45 if night else 0.32) else "walker"
	return "runner" if r < (0.35 if night else 0.22) else "walker"

func _spawn_point(p: Vector3, rmin: float, rmax: float, underground: bool) -> Vector3:
	var space := world.get_world_3d().direct_space_state
	var cam := world.player.cam
	for attempt in 12:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(rmin, rmax)
		var q := p + Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(q.x) > 300.0 or absf(q.z) > 300.0:
			continue
		var from := Vector3(q.x, (p.y + 2.5) if underground else 120.0, q.z)
		var rq := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (12.0 if underground else 200.0), 1 | 2)
		var hit := space.intersect_ray(rq)
		if hit.is_empty():
			continue
		q = hit.position + Vector3(0, 0.4, 0)
		if underground and absf(q.y - p.y) > 3.0:
			continue
		if not underground and q.y > 3.0 and world.zone_at(q) != "downtown":
			continue
		var z := world.zone_at(q)
		if z == "haven":
			continue
		var to := q + Vector3(0, 1.2, 0) - cam.global_position
		if (-cam.global_transform.basis.z).dot(to.normalized()) > 0.45 and to.length() < 75.0:
			var los := PhysicsRayQueryParameters3D.create(cam.global_position, q + Vector3(0, 1.2, 0), 1 | 2)
			if space.intersect_ray(los).is_empty():
				continue
		return q
	return Vector3.INF

func _drain_queue() -> void:
	var n := 0
	while not _queue.is_empty() and n < 3:
		n += 1
		var e: Array = _queue.pop_front()
		var opts: Dictionary = e[2]
		var m := world.spawn_monster(e[0], e[1], -1, opts)
		dynamic.append(m)
		if opts.get("rush", false):
			m.target = world.player
			m.awareness = 2.0
			m.horde = true
			m._set_state("chase")
		elif opts.has("goto"):
			m.investigate_pos = opts.goto
			m._set_state("investigate")
		if opts.get("siege", false):
			siege_mobs.append(m)

# ---------------- events ----------------
func horde_rush() -> void:
	var p := world.player.global_position
	horde_cd = _rng.randf_range(300.0, 470.0) * (0.7 if GameData.is_night() else 1.0)
	calm_t = 0.0
	var count := clampi(14 + GameData.day() * 2 + (8 if GameData.is_night() else 0), 14, 38)
	var a := _rng.randf() * TAU
	var center := p + Vector3(cos(a), 0, sin(a)) * 80.0
	var spawned := 0
	for i in count:
		var sp := _spawn_point(center, 0.0, 14.0, false)
		if sp == Vector3.INF:
			continue
		var kind := "runner" if _rng.randf() < 0.55 else "walker"
		if i == 3:
			kind = "brute"
		elif i == 7:
			kind = "screamer"
		_queue.append([kind, sp, {"rush": true}])
		spawned += 1
	if spawned > 0:
		GameData.banner("HORDE INCOMING", "Something set them off. Run, or make a stand.", Color(1.0, 0.3, 0.2))
		SFX.play("horde", 0.0, 0.9)
		SFX.play_3d("scream", center, 10.0, 0.9, 200.0)

func screamer_called(pos: Vector3) -> void:
	var n := _rng.randi_range(3, 6)
	for i in n:
		var sp := _spawn_point(pos, 35.0, 55.0, pos.y < -3.0)
		if sp != Vector3.INF:
			_queue.append(["runner", sp, {"goto": pos}])

func _siege(delta: float) -> void:
	var t := GameData.time_of_day()
	var p := world.player.global_position
	if not siege_active and GameData.is_siege_night() and t >= 22.0 and t < 23.5 and _siege_day != GameData.day():
		_siege_day = GameData.day()
		if p.distance_to(World.HAVEN) < 150.0:
			siege_active = true
			siege_wave = 0
			siege_t = 0.0
			siege_mobs.clear()
			GameData.banner("SIEGE!", "They're at the gates. Hold Haven until the waves break.", Color(1.0, 0.25, 0.2))
			SFX.play("bell", 0.0)
			SFX.play("horde", 2.0, 0.8)
		else:
			GameData.game_message("Distant gunfire from Haven. The guards held the walls without you.", Color(0.9, 0.8, 0.6))
	if not siege_active:
		return
	siege_t += delta
	if siege_wave < 5 and siege_t >= siege_wave * 28.0:
		siege_wave += 1
		var gates := [World.HAVEN + Vector3(0, 0, -95), World.HAVEN + Vector3(-95, 0, 0), World.HAVEN + Vector3(95, 0, 0)]
		var n := 9 + siege_wave * 2
		for i in n:
			var g: Vector3 = gates[i % 3]
			var sp := _spawn_point(g, 0.0, 16.0, false)
			if sp == Vector3.INF:
				continue
			var kind := "runner" if i % 2 == 0 else "walker"
			if i == 0 and siege_wave % 2 == 0:
				kind = "brute"
			if i == 1 and siege_wave >= 3:
				kind = "screamer"
			_queue.append([kind, sp, {"goto": World.HAVEN, "siege": true, "horde": true}])
		GameData.game_message("Wave %d/5" % siege_wave, Color(1.0, 0.5, 0.4))
	var alive := 0
	for m in siege_mobs:
		if is_instance_valid(m) and not m.dead:
			alive += 1
	if (siege_wave >= 5 and siege_t > 150.0 and alive == 0) or siege_t > 420.0:
		siege_active = false
		GameData.banner("SIEGE BROKEN", "Haven stands. +400 XP, +120 Glowshards.", Color(0.55, 1.0, 0.6))
		GameData.add_xp(400)
		GameData.shards += 120
		GameData.add_entry(ItemDB.roll_weapon("", GameData.level, maxi(2, ItemDB.roll_rarity(GameData.level, 0.4))))
		GameData.touch()
