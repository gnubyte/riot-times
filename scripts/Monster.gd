extends CharacterBody3D
# Every AI in the wasteland: zombies (walker, runner, brute, screamer, bloater, Goliath),
# the Gaunt, werewolves, vampires, Scrapjaw raiders, Haven guards and wildlife.
# Perception = sight cone + awareness meter + hearing (Noise). Movement = navmesh paths
# where baked, direct steering elsewhere. Death = a physics corpse + loot.

class_name Monster

signal died(m: Monster, info: Dictionary)

const DEFS := {
	"walker": {name="Walker", faction="undead", hp=70.0, walk=1.0, run=2.3, dmg=12.0, rate=1.3, reach=1.75, xp=18, sight=22.0, fov=120.0, hearing=1.0, body="zombie", scale=1.0, bite="zombie", loot="zombie", groan=true},
	"runner": {name="Runner", faction="undead", hp=48.0, walk=1.3, run=6.4, dmg=9.0, rate=0.85, reach=1.6, xp=24, sight=30.0, fov=140.0, hearing=1.2, body="zombie_lean", scale=0.97, bite="zombie", loot="zombie", groan=true, runner=true},
	"brute": {name="Brute", faction="undead", hp=430.0, walk=1.0, run=3.4, dmg=32.0, rate=1.9, reach=2.3, xp=95, armor=0.3, sight=24.0, fov=110.0, hearing=0.9, body="zombie_big", scale=1.3, bite="zombie", loot="brute", knock=9.0, heavy=true},
	"screamer": {name="Screamer", faction="undead", hp=85.0, walk=1.2, run=3.8, dmg=8.0, rate=1.0, reach=1.6, xp=45, sight=34.0, fov=160.0, hearing=1.4, body="zombie_thin", scale=1.02, bite="zombie", loot="zombie", screamer=true},
	"bloater": {name="Bloater", faction="undead", hp=150.0, walk=0.9, run=1.9, dmg=10.0, rate=1.4, reach=1.8, xp=50, sight=18.0, fov=110.0, hearing=0.8, body="zombie_fat", scale=1.12, bite="zombie", loot="zombie", bloater=true},
	"goliath": {name="Goliath", faction="undead", hp=3200.0, walk=1.6, run=3.9, dmg=55.0, rate=2.4, reach=4.2, xp=1300, armor=0.2, sight=40.0, fov=150.0, hearing=1.2, body="giant", scale=2.5, bite="zombie", loot="boss", knock=14.0, boss=true, heavy=true},
	"gaunt": {name="The Gaunt", faction="undead", hp=2600.0, walk=2.2, run=12.5, dmg=85.0, rate=1.1, reach=3.6, xp=1600, armor=0.15, sight=5.0, fov=360.0, hearing=1.7, body="gaunt", scale=1.6, loot="boss", boss=true, gaunt=true, heavy=true},
	"werewolf": {name="Werewolf", faction="beast", hp=460.0, walk=2.4, run=8.8, dmg=26.0, rate=0.9, reach=2.3, xp=170, sight=40.0, fov=150.0, hearing=1.4, body="wolf", scale=1.0, bite="wolf", loot="beast", weak="silver", leaps=true, night_eyes=true},
	"vampire": {name="Vampire", faction="beast", hp=330.0, walk=2.0, run=6.6, dmg=20.0, rate=1.0, reach=2.0, xp=160, sight=38.0, fov=140.0, hearing=1.3, body="vampire", scale=1.0, bite="vampire", loot="beast", weak="fire", blinks=true, drain=0.5, night_eyes=true},
	"raider": {name="Scrapjaw Gunner", faction="raider", hp=115.0, walk=1.8, run=4.6, dmg=8.0, rate=1.0, reach=1.8, xp=45, sight=46.0, fov=130.0, hearing=1.2, body="raider", scale=1.0, loot="raider", ranged=true, range=30.0, burst=4, spread=2.6},
	"psycho": {name="Scrapjaw Psycho", faction="raider", hp=95.0, walk=2.2, run=7.0, dmg=22.0, rate=0.95, reach=2.1, xp=40, sight=42.0, fov=140.0, hearing=1.3, body="psycho", scale=1.0, loot="raider"},
	"gnasher": {name="King Gnasher", faction="raider", hp=1650.0, walk=1.5, run=3.2, dmg=9.0, rate=1.0, reach=2.2, xp=650, armor=0.35, sight=50.0, fov=150.0, hearing=1.2, body="raider_boss", scale=1.25, loot="boss", ranged=true, range=34.0, burst=14, spread=3.4, boss=true, heavy=true},
	"guard": {name="Haven Guard", faction="haven", hp=900.0, walk=0.0, run=0.0, dmg=26.0, rate=1.0, reach=1.8, xp=0, sight=58.0, fov=200.0, hearing=1.0, body="guard", scale=1.0, loot="", ranged=true, range=58.0, burst=2, spread=1.2, stationary=true},
	"boar": {name="Mutant Boar", faction="wild", hp=90.0, walk=1.3, run=7.2, dmg=14.0, rate=1.1, reach=1.7, xp=15, sight=20.0, fov=220.0, hearing=1.3, body="boar", scale=1.0, loot="boar", wild="charge"},
	"deer": {name="Deer", faction="wild", hp=55.0, walk=1.5, run=9.5, dmg=0.0, rate=1.0, reach=1.0, xp=12, sight=34.0, fov=280.0, hearing=1.6, body="deer", scale=1.0, loot="deer", wild="flee"},
}

const LOOT := {
	"zombie": [["@ammo", 1, 1, 0.13], ["shards", 2, 8, 0.25], ["bandage", 1, 1, 0.06], ["@food", 1, 1, 0.05], ["@valuable", 1, 1, 0.04], ["cloth", 1, 2, 0.1]],
	"brute": [["@ammo", 1, 2, 0.6], ["shards", 8, 25, 0.8], ["@melee", 1, 1, 0.15], ["@armor", 1, 1, 0.12], ["weapon_parts", 1, 2, 0.3]],
	"boss": [["@weapon_boss", 1, 1, 1.0], ["@ammo", 2, 3, 1.0], ["shards", 80, 200, 1.0], ["@cure", 1, 1, 0.5], ["@armor_good", 1, 1, 0.5]],
	"beast": [["shards", 10, 30, 0.8], ["silverleaf", 1, 1, 0.15], ["blood_pack", 1, 1, 0.15], ["@valuable", 1, 1, 0.2], ["raw_meat", 1, 2, 0.3]],
	"raider": [["@raider_gun", 1, 1, 0.22], ["@ammo", 1, 2, 0.7], ["shards", 5, 20, 0.7], ["@food", 1, 1, 0.2], ["@throwable", 1, 1, 0.12], ["@valuable", 1, 1, 0.12]],
	"boar": [["raw_meat", 2, 3, 1.0]],
	"deer": [["raw_meat", 2, 4, 1.0]],
}

const BARKS_SPOT := ["MEAT! FRESH MEAT!", "I CALL DIBS ON YOUR TEETH!", "SHINY! GIMME THE SHINY!", "WHO WANTS TO BLEED?", "HAHAHA! A VISITOR!", "YOUR FACE! I WANT IT!", "SCRAPJAWS! WE GOT ONE!"]
const BARKS_HURT := ["OW! RUDE!", "THAT'S MY GOOD SIDE!", "I LIKE IT!", "AGAIN! AGAIN!", "YOU'LL PAY FOR THAT!"]
const BARKS_KILL := ["DIBS ON THE BOOTS!", "HAHAHAHA!", "TOO EASY!", "INTO THE STEW POT!"]

static var _flash_mat: StandardMaterial3D = null
static var corpses: Array = []

var kind := "walker"
var def := {}
var level := 1
var faction := "undead"
var hp := 100.0
var hp_max := 100.0
var dmg := 10.0
var armor := 0.0
var xp_value := 10
var display_name := ""
var state := "wander"
var state_t := 0.0
var target: Node3D = null
var last_seen := Vector3.INF
var investigate_pos := Vector3.INF
var awareness := 0.0
var home := Vector3.ZERO
var leash := 45.0
var spawn_pos := Vector3.ZERO
var path := PackedVector3Array()
var path_i := 0
var _path_goal := Vector3.INF
var repath_t := 0.0
var think_t := 0.0
var attack_cd := 0.0
var special_cd := 2.0
var special_cd2 := 4.0
var windup := 0.0
var windup_kind := ""
var stagger := 0.0
var burn_t := 0.0
var burn_owner: Node = null
var dead := false
var parts := {}
var anim_t := 0.0
var flash_t := 0.0
var groan_t := 5.0
var stuck_t := 0.0
var _stuck_check := Vector3.ZERO
var _sidestep := Vector3.ZERO
var _sidestep_t := 0.0
var horde := false
var dormant := false
var revenant := {}
var night_only := false
var lod := 0
var hurt_by_player := false
var lost_t := 0.0
var burst_left := 0
var burst_t := 0.0
var strafe_dir := 1.0
var strafe_t := 0.0
var flinch_k := 0.0
var wander_to := Vector3.INF
var head_shape: CollisionShape3D = null
var _burn_fx: Node3D = null
var _bark: Label3D = null
var _opts := {}
var _shadows := true
var _anim_skip := 0
var rng := RandomNumberGenerator.new()

func setup(k: String, pos: Vector3, lvl: int, opts := {}) -> void:
	kind = k if DEFS.has(k) else "walker"
	def = DEFS[kind]
	level = maxi(1, lvl)
	faction = def.faction
	_opts = opts
	var lv := 1.0 + 0.09 * (level - 1)
	hp_max = float(def.hp) * lv * float(opts.get("hp_mul", 1.0))
	hp = hp_max
	dmg = float(def.dmg) * (1.0 + 0.05 * (level - 1)) * float(opts.get("dmg_mul", 1.0))
	armor = float(def.get("armor", 0.0))
	xp_value = int(float(def.xp) * (1.0 + 0.1 * (level - 1)) * float(opts.get("xp_mul", 1.0)))
	display_name = opts.get("name", def.name)
	spawn_pos = pos
	home = opts.get("home", pos)
	leash = float(opts.get("leash", 45.0))
	dormant = bool(opts.get("dormant", false))
	horde = bool(opts.get("horde", false))
	night_only = bool(opts.get("night_only", false))
	revenant = opts.get("revenant", {})

func _ready() -> void:
	rng.randomize()
	add_to_group("monsters")
	add_to_group(faction)
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 32 | 64
	if def.get("stationary", false):
		collision_mask = 1 | 2
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)
	var s := float(def.scale)
	var col := CollisionShape3D.new()
	match def.body:
		"gaunt":
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.0, 1.3, 2.4) * s
			col.shape = bs
			col.position = Vector3(0, 0.65, -0.3) * s
		"boar", "deer":
			var qb := BoxShape3D.new()
			qb.size = Vector3(0.5, 0.75 if def.body == "boar" else 1.3, 1.1)
			col.shape = qb
			col.position = Vector3(0, qb.size.y * 0.5, 0)
		_:
			var cap := CapsuleShape3D.new()
			cap.radius = 0.36 * s * (1.2 if def.body in ["zombie_fat", "wolf"] else 1.0)
			cap.height = 1.82 * s * (1.12 if def.body == "wolf" else 1.0)
			col.shape = cap
			col.position = Vector3(0, cap.height * 0.5, 0)
	add_child(col)
	parts = MonsterBodies.build(def.body, rng)
	var root: Node3D = parts.root
	root.scale = Vector3.ONE * s
	add_child(root)
	if parts.has("head_mesh") and def.body in ["gaunt", "giant", "wolf", "boar", "deer"]:
		head_shape = CollisionShape3D.new()
		var hs := SphereShape3D.new()
		hs.radius = float(parts.get("head_r", 0.17)) * s * 1.2
		head_shape.shape = hs
		add_child(head_shape)
	global_position = spawn_pos
	rotation.y = rng.randf_range(0.0, TAU)
	think_t = rng.randf_range(0.0, 0.5)
	if dormant:
		state = "dormant"
	elif def.get("stationary", false):
		state = "guard"
	else:
		state = "wander"
	if not revenant.is_empty():
		_make_revenant_look()
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.albedo_color = Color(0.32, 0.28, 0.24)

func _make_revenant_look() -> void:
	var glow := MonsterBodies.m(Color(0.4, 1.0, 0.6), 0.4, 3.0)
	for e in parts.eyes:
		(e as MeshInstance3D).material_override = glow
	var l := Label3D.new()
	l.text = display_name
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.outline_size = 10
	l.modulate = Color(0.6, 1.0, 0.7)
	l.position = Vector3(0, 2.4 * float(def.scale), 0)
	add_child(l)

# ================= public API =================
func is_targetable() -> bool:
	return not dead and is_inside_tree()

func aim_point(head: bool) -> Vector3:
	if head and parts.has("head"):
		return (parts.head as Node3D).to_global(parts.get("head_center", Vector3(0, 0.16, 0)))
	if parts.has("torso") and not parts.get("quad", false):
		return (parts.torso as Node3D).to_global(Vector3(0, 0.38, 0))
	return global_position + Vector3(0, 0.8 * float(def.scale), 0)

func is_unaware() -> bool:
	return (state == "wander" or state == "dormant" or state == "investigate" or state == "idle") and awareness < 0.7

func hear(pos: Vector3, radius: float, dist: float, nkind: String) -> void:
	if dead or faction == "haven":
		return
	var eff := radius * float(def.hearing)
	if dist > eff:
		return
	if faction == "wild":
		if def.get("wild", "") == "flee" or dist < eff * 0.5:
			_flee(pos)
		return
	if nkind == "player" or nkind == "explosion" or nkind == "lure" or nkind == "scream" or nkind == "vehicle":
		if dormant:
			_wake()
		if state == "chase" and not def.get("gaunt", false):
			return
		var err := clampf(dist / eff, 0.0, 1.0) * 6.0
		investigate_pos = pos + Vector3(rng.randf_range(-err, err), 0, rng.randf_range(-err, err))
		var p := _player()
		if def.get("gaunt", false):
			if p != null and nkind == "player":
				target = p
				last_seen = pos
				_set_state("chase")
			else:
				_set_state("investigate")
			return
		if nkind == "lure":
			_set_state("investigate")
			return
		if (dist < eff * 0.45 or (nkind == "scream" and dist < 35.0)) and p != null and _hostile_to_player() and p.global_position.distance_to(pos) < 12.0:
			_engage(p)
		elif state != "chase":
			_set_state("investigate")

func take_hit(info: Dictionary) -> Dictionary:
	if dead:
		return {}
	var amount := float(info.get("dmg", 0.0))
	var head := false
	var pos: Vector3 = info.get("pos", Vector3.INF)
	if not info.get("melee", false) and not info.get("explosive", false) and pos != Vector3.INF and parts.has("head"):
		var hc := aim_point(true)
		head = pos.distance_to(hc) <= float(parts.get("head_r", 0.17)) * float(def.scale) * 1.45
	if head:
		amount *= float(info.get("head_mul", 1.5)) * (1.25 if faction == "undead" else 1.0)
	var element: String = info.get("element", "")
	var weak: String = def.get("weak", "")
	if element == "silver":
		amount *= 2.0 if weak == "silver" else (1.25 if kind == "vampire" else 1.0)
	elif element == "fire":
		amount *= 1.6 if weak == "fire" else 1.0
		ignite(3.0, info.get("attacker", null))
	if info.get("stake", false) and kind == "vampire":
		amount *= 3.0
	amount *= 1.0 - armor * (0.5 if head else 1.0)
	if info.get("stun", false):
		stagger = 0.8
	var from_player: bool = info.get("source", "") == "player"
	if from_player:
		hurt_by_player = true
	hp -= amount
	flash_t = 0.07
	flinch_k = clampf(amount / maxf(1.0, hp_max * 0.25), 0.3, 1.0)
	if not def.get("heavy", false) and amount > hp_max * 0.22:
		stagger = maxf(stagger, 0.35)
	var dir: Vector3 = info.get("dir", Vector3.FORWARD)
	if faction != "raider" or randf() < 0.6:
		Combat.blood(pos if pos != Vector3.INF else aim_point(false), -dir, Color(0.3, 0.32, 0.12) if kind == "bloater" else Color(0.45, 0.04, 0.04))
	if rng.randf() < 0.5:
		SFX.play_3d("hit_flesh", global_position + Vector3.UP, -6.0, rng.randf_range(0.85, 1.15), 30.0)
	if faction == "raider" and rng.randf() < 0.2:
		bark(BARKS_HURT)
	var attacker: Node = info.get("attacker", null)
	if dormant:
		_wake()
	if attacker is Node3D and _is_enemy(attacker):
		_engage(attacker as Node3D)
	elif from_player and _hostile_to_player():
		_engage(_player())
	elif faction == "wild" and def.get("wild", "") == "charge" and from_player:
		_engage(_player())
	elif faction == "wild":
		_flee(global_position - dir * 5.0)
	var killed := false
	if hp <= 0.0:
		killed = true
		_die(info, head)
	return {"dealt": amount, "killed": killed, "head": head, "element": element}

func knockback(dir: Vector3, force: float) -> void:
	if dead or def.get("stationary", false):
		return
	var resist := 0.15 if def.get("heavy", false) else 1.0
	var f := force * resist
	velocity += Vector3(dir.x, 0, dir.z).normalized() * f + Vector3.UP * f * 0.25
	if f > 3.0:
		stagger = maxf(stagger, 0.25)

func ignite(dur: float, by: Node) -> void:
	if dead:
		return
	burn_t = maxf(burn_t, dur)
	burn_owner = by
	if _burn_fx == null and not Combat.low_fx():
		_burn_fx = Node3D.new()
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.15)
		l.omni_range = 4.0
		l.light_energy = 1.5
		l.position.y = 1.0
		_burn_fx.add_child(l)
		var p := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.25, 0.8, 0.25)
		pm.direction = Vector3.UP
		pm.gravity = Vector3(0, 2.0, 0)
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.5
		pm.scale_min = 0.15
		pm.scale_max = 0.35
		pm.color = Color(1.0, 0.55, 0.15)
		p.process_material = pm
		p.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(1, 1, 1, 1)))
		p.amount = 18
		p.lifetime = 0.6
		p.position.y = 0.9
		_burn_fx.add_child(p)
		add_child(_burn_fx)

func bark(lines: Array) -> void:
	if dead or lod > 0:
		return
	if _bark == null:
		_bark = Label3D.new()
		_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bark.font_size = 34
		_bark.outline_size = 10
		_bark.modulate = Color(1.0, 0.8, 0.3)
		_bark.position = Vector3(0, 2.25 * float(def.scale), 0)
		add_child(_bark)
	_bark.text = lines[rng.randi() % lines.size()]
	_bark.modulate.a = 1.0
	var t := _bark.create_tween()
	t.tween_interval(1.6)
	t.tween_property(_bark, "modulate:a", 0.0, 0.5)
	SFX.play_3d("raider_shout", global_position + Vector3.UP * 1.6, -2.0, rng.randf_range(0.85, 1.25), 50.0)

# ================= perception =================
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _hostile_to_player() -> bool:
	match faction:
		"undead": return GameData.form != "zombie"
		"beast":
			if kind == "werewolf" and GameData.form == "wolf": return false
			if kind == "vampire" and GameData.form == "vampire": return false
			return true
		"raider": return true
		"wild": return def.get("wild", "") == "charge" and hurt_by_player
	return false

func _is_enemy(n: Node) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	if n is Player:
		return _hostile_to_player() or (faction == "wild" and hurt_by_player)
	if n is Monster:
		var f: String = (n as Monster).faction
		match faction:
			"undead": return f == "raider" or f == "haven"
			"beast": return f == "raider" or f == "haven"
			"raider": return f == "undead" or f == "beast" or f == "haven"
			"haven": return f == "undead" or f == "beast" or f == "raider"
	return false

func _target_pos(t: Node3D) -> Vector3:
	if t is Player and (t as Player).in_vehicle != null:
		return ((t as Player).in_vehicle as Node3D).global_position
	return t.global_position

func _visibility(t: Node3D, d: float) -> float:
	var sight := float(def.sight)
	var night := GameData.is_night()
	if t is Player:
		var p := t as Player
		if night and not def.get("night_eyes", false):
			sight *= 1.25 if p.flashlight.visible else 0.5
		if p.stance == "crouch":
			sight *= 0.6
		if p.in_vehicle != null:
			sight *= 2.0
	if global_position.y < -4.0 and not def.get("night_eyes", false):
		sight *= 0.7
	if d > sight:
		return 0.0
	var to := _target_pos(t) - global_position
	to.y = 0.0
	var fwd := -global_transform.basis.z
	if d > 3.5 and rad_to_deg(fwd.angle_to(to.normalized())) > float(def.fov) * 0.5:
		return 0.0
	var eye := global_position + Vector3(0, 1.5 * float(def.scale), 0)
	var q := PhysicsRayQueryParameters3D.create(eye, _target_pos(t) + Vector3(0, 1.2, 0), 1 | 2)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return 0.0
	return clampf(1.7 - d / sight, 0.25, 1.7)

func _perceive(dt: float) -> void:
	var best: Node3D = null
	var best_d := INF
	var p := _player()
	if p != null and not p.dead and _hostile_to_player():
		var d := global_position.distance_to(_target_pos(p))
		if d < float(def.sight) * 2.0:
			var vis := _visibility(p, d)
			if vis > 0.0:
				awareness += vis * dt * 2.6
				if awareness >= 1.0:
					best = p
					best_d = d
			else:
				awareness = maxf(0.0, awareness - dt * 0.25)
	var groups := []
	match faction:
		"undead", "beast": groups = ["raider", "haven"]
		"raider": groups = ["undead", "beast", "haven"]
		"haven": groups = ["undead", "beast", "raider"]
	for g in groups:
		for n in get_tree().get_nodes_in_group(g):
			if n == self or not (n as Monster).is_targetable():
				continue
			var d2 := global_position.distance_to((n as Node3D).global_position)
			if d2 < best_d and d2 < float(def.sight) * (1.0 if faction != "haven" else 1.2):
				if _visibility(n, d2) > 0.0:
					best = n
					best_d = d2
	if best != null:
		_engage(best)

func _engage(t: Node3D) -> void:
	if t == null or dead:
		return
	if state != "chase" and faction == "raider" and t is Player:
		bark(BARKS_SPOT)
	if state != "chase":
		if kind == "werewolf":
			SFX.play_3d("wolf_howl", global_position + Vector3.UP * 2.0, 0.0, rng.randf_range(0.9, 1.1), 120.0)
		elif faction == "undead" and not def.get("gaunt", false) and rng.randf() < 0.6:
			SFX.play_3d("runner_shriek" if def.get("runner", false) else "zombie_attack", global_position + Vector3.UP * 1.6, -2.0, rng.randf_range(0.85, 1.15), 55.0)
	target = t
	awareness = 1.5
	last_seen = _target_pos(t)
	lost_t = 0.0
	if dormant:
		_wake()
	if state != "chase" and state != "scream":
		_set_state("chase")

func _wake() -> void:
	if not dormant:
		return
	dormant = false
	if def.get("gaunt", false):
		SFX.play_3d("gaunt_shriek", global_position + Vector3.UP, 6.0, 1.0, 160.0)
		GameData.banner("SOMETHING HEARD YOU", "Stay quiet. Stay low. Don't run.", Color(0.85, 0.85, 0.9))
	_set_state("investigate")

func _flee(from: Vector3) -> void:
	var away := global_position - from
	away.y = 0.0
	investigate_pos = global_position + away.normalized() * 25.0
	_set_state("flee")

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	path = PackedVector3Array()
	repath_t = 0.0

# ================= brain =================
func _think(dt: float) -> void:
	var p := _player()
	var pd := 9999.0
	if p != null:
		pd = global_position.distance_to(p.global_position)
	lod = 0 if pd < 65.0 else (1 if pd < 130.0 else 2)
	if parts.has("root"):
		(parts.root as Node3D).visible = lod < 2
		var want_shadow := pd < 40.0
		if want_shadow != _shadows:
			_shadows = want_shadow
			for mi in parts.meshes:
				(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if want_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if night_only and not GameData.is_night() and state != "chase":
		if pd > 40.0:
			queue_free()
			return
	if kind == "vampire" and not GameData.is_night() and not (global_position.y < -3.0):
		ignite(2.0, null)
	match state:
		"dormant":
			return
		"guard":
			_perceive(dt)
		"wander", "idle":
			_perceive(dt)
			if wander_to == Vector3.INF or global_position.distance_to(wander_to) < 1.5 or state_t > 14.0:
				state_t = 0.0
				if rng.randf() < 0.35:
					wander_to = global_position
				else:
					var a := rng.randf() * TAU
					var r := rng.randf_range(4.0, 14.0)
					wander_to = home + Vector3(cos(a) * r, 0, sin(a) * r)
		"investigate":
			_perceive(dt)
			if investigate_pos == Vector3.INF or (global_position.distance_to(investigate_pos) < 2.0 and state_t > 3.0) or state_t > 20.0:
				if def.get("gaunt", false) and not horde:
					home = global_position
				_set_state("wander")
		"chase":
			if target == null or not is_instance_valid(target) or (target is Player and (target as Player).dead) or (target is Monster and (target as Monster).dead):
				target = null
				_set_state("wander")
				return
			if target is Player and not _hostile_to_player():
				target = null
				_set_state("wander")
				return
			var d := global_position.distance_to(_target_pos(target))
			var vis := _visibility(target, d) if not def.get("gaunt", false) else (1.0 if d < 6.0 else 0.0)
			if vis > 0.0:
				last_seen = _target_pos(target)
				lost_t = 0.0
			else:
				lost_t += dt
				if def.get("gaunt", false):
					var quiet := Hearing.player_noise < 4.0 and target is Player
					if quiet and lost_t > 2.5:
						investigate_pos = last_seen
						target = null
						_set_state("investigate")
						return
				elif lost_t > (12.0 if horde else 7.0):
					investigate_pos = last_seen
					target = null
					_set_state("investigate")
					return
			if not horde and not def.get("boss", false) and global_position.distance_to(home) > leash * 2.5 and d > 20.0:
				target = null
				investigate_pos = home
				_set_state("investigate")
		"flee":
			if state_t > 7.0:
				_set_state("wander")

func _physics_process(delta: float) -> void:
	if dead:
		return
	state_t += delta
	think_t -= delta
	if think_t <= 0.0:
		var interval := 0.3 if lod == 0 else (0.9 if lod == 1 else 1.6)
		think_t = interval
		_think(interval)
		if dead or not is_inside_tree():
			return
	if lod >= 2 and not horde and state != "chase":
		return
	attack_cd -= delta
	special_cd -= delta
	special_cd2 -= delta
	stagger -= delta
	if burn_t > 0.0:
		burn_t -= delta
		var bd := 7.0 * delta * (2.0 if kind == "vampire" else 1.0)
		hp -= bd
		if hp <= 0.0:
			_die({"source": "player" if burn_owner is Player else "fire", "dir": Vector3.UP, "force": 1.0}, false)
			return
		if burn_t <= 0.0 and _burn_fx != null:
			_burn_fx.queue_free()
			_burn_fx = null
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5
	var want := Vector3.ZERO
	var speed := 0.0
	if stagger > 0.0 or state == "dormant":
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	elif windup > 0.0:
		windup -= delta
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		if target != null and is_instance_valid(target):
			_face(_target_pos(target) - global_position, delta * 6.0)
		if windup <= 0.0:
			_strike()
	else:
		match state:
			"wander":
				if wander_to != Vector3.INF and global_position.distance_to(wander_to) > 1.2:
					_steer(wander_to, float(def.walk), delta)
				else:
					_brake(delta)
			"investigate":
				var spd := float(def.walk) * 1.5
				if def.get("runner", false) or def.get("gaunt", false):
					spd = float(def.run) * 0.75
				if investigate_pos != Vector3.INF and global_position.distance_to(investigate_pos) > 1.5:
					_steer(investigate_pos, spd, delta)
				else:
					_brake(delta)
					rotation.y += delta * 0.8
			"flee":
				_steer(investigate_pos, float(def.run), delta)
			"guard":
				_brake(delta)
				if target != null and is_instance_valid(target) and not (target as Monster).dead:
					_ranged(delta)
				else:
					target = null
			"chase":
				if target != null and is_instance_valid(target):
					if def.get("ranged", false):
						_ranged(delta)
					else:
						_melee_chase(delta)
			_:
				_brake(delta)
	move_and_slide()
	_unstick(delta)

func _process(delta: float) -> void:
	if dead or lod >= 2:
		return
	_anim_skip += 1
	if lod == 1 and _anim_skip % 3 != 0:
		return
	_animate(delta * (3.0 if lod == 1 else 1.0))
	if flash_t > 0.0:
		flash_t -= delta
		var on := flash_t > 0.0
		for mi in parts.meshes:
			(mi as GeometryInstance3D).material_overlay = _flash_mat if on else null
	if head_shape != null and parts.has("head"):
		head_shape.global_position = aim_point(true)
	if def.get("groan", false) and lod == 0:
		groan_t -= delta
		if groan_t <= 0.0:
			groan_t = rng.randf_range(5.0, 13.0)
			SFX.play_3d("zombie_groan", global_position + Vector3.UP * 1.6, -6.0, rng.randf_range(0.8, 1.2), 32.0)
	if def.get("gaunt", false) and state == "chase" and lod == 0:
		groan_t -= delta
		if groan_t <= 0.0:
			groan_t = rng.randf_range(1.2, 2.5)
			SFX.play_3d("gaunt_click", global_position + Vector3.UP, 0.0, rng.randf_range(0.9, 1.1), 50.0)

# ================= movement =================
func _face(dir: Vector3, k: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(k, 0.0, 1.0))

func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)

func _steer(dest: Vector3, speed: float, delta: float) -> void:
	var to := dest - global_position
	to.y = 0.0
	var next := dest
	if World.nav_ready and to.length() > 2.5 and lod == 0:
		repath_t -= delta
		var far := to.length() > 20.0
		if repath_t <= 0.0 or path.is_empty() or (dest.distance_to(_path_goal) > (6.0 if far else 2.5) and repath_t < 0.3):
			repath_t = rng.randf_range(1.0, 1.6) if far else rng.randf_range(0.45, 0.75)
			# open ground with a clear line: just run at it, skip the pathfinder
			var direct := false
			if absf(dest.y - global_position.y) < 1.5 and to.length() < 25.0:
				var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, dest + Vector3.UP * 0.8, 2)
				direct = get_world_3d().direct_space_state.intersect_ray(q).is_empty()
			if direct:
				path = PackedVector3Array([dest])
			else:
				path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position, dest, true)
			path_i = 0
			_path_goal = dest
		while path_i < path.size() and Vector2(path[path_i].x - global_position.x, path[path_i].z - global_position.z).length() < 0.9:
			path_i += 1
		if path_i < path.size():
			next = path[path_i]
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	if _sidestep_t > 0.0:
		_sidestep_t -= delta
		dir = (dir + _sidestep).normalized()
	if GameData.is_night() and faction == "undead":
		speed *= 1.15
	var k := 1.0 - exp(-8.0 * delta)
	velocity.x = lerpf(velocity.x, dir.x * speed, k)
	velocity.z = lerpf(velocity.z, dir.z * speed, k)
	_face(dir, delta * 8.0)

func _unstick(delta: float) -> void:
	stuck_t += delta
	if stuck_t < 0.8:
		return
	var moved := global_position.distance_to(_stuck_check)
	var wanted := Vector2(velocity.x, velocity.z).length() > 0.6
	_stuck_check = global_position
	stuck_t = 0.0
	if wanted and moved < 0.25:
		if is_on_floor() and rng.randf() < 0.6:
			velocity.y = 5.5
		_sidestep = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		_sidestep_t = 0.7
		path = PackedVector3Array()

# ================= combat =================
func _melee_chase(delta: float) -> void:
	var tp := _target_pos(target)
	var d := global_position.distance_to(tp)
	var flat := Vector2(tp.x - global_position.x, tp.z - global_position.z).length()
	# specials first
	if def.get("screamer", false) and special_cd <= 0.0 and d < 30.0:
		special_cd = 16.0
		windup = 1.6
		windup_kind = "scream"
		SFX.play_3d("scream", global_position + Vector3.UP * 1.7, 6.0, rng.randf_range(0.95, 1.05), 140.0)
		Hearing.emit_noise(global_position, 55.0, "scream", false)
		var dir_n := get_tree().get_first_node_in_group("director")
		if dir_n != null:
			dir_n.call("screamer_called", global_position)
		return
	if def.get("bloater", false) and d < 2.8 and windup <= 0.0:
		windup = 0.75
		windup_kind = "pop"
		SFX.play_3d("zombie_groan", global_position + Vector3.UP, 0.0, 0.6, 30.0)
		return
	if kind == "goliath":
		if d < 6.5 and special_cd <= 0.0:
			special_cd = 6.0
			windup = 0.95
			windup_kind = "slam"
			SFX.play_3d("goliath_roar", global_position + Vector3.UP * 4.0, 4.0, 1.0, 120.0)
			return
		if d > 12.0 and special_cd2 <= 0.0:
			special_cd2 = 5.5
			windup = 0.8
			windup_kind = "throw"
			return
	if def.get("leaps", false) and d > 4.0 and d < 11.0 and special_cd <= 0.0 and is_on_floor():
		special_cd = 3.5
		var ld := (tp - global_position)
		ld.y = 0.0
		velocity = ld.normalized() * 15.0 + Vector3.UP * 6.5
		SFX.play_3d("wolf_snarl", global_position + Vector3.UP * 1.8, 0.0, 1.0, 50.0)
		return
	if def.get("blinks", false) and d > 7.0 and d < 30.0 and special_cd <= 0.0:
		special_cd = 4.5
		_blink(tp)
		return
	if flat <= float(def.reach) and absf(tp.y - global_position.y) < 2.5 * float(def.scale):
		_face(tp - global_position, delta * 10.0)
		_brake(delta)
		if attack_cd <= 0.0:
			attack_cd = float(def.rate)
			windup = maxf(0.22, float(def.rate) * 0.32)
			windup_kind = "melee"
			if faction == "undead" and rng.randf() < 0.5:
				SFX.play_3d("zombie_attack", global_position + Vector3.UP * 1.6, -4.0, rng.randf_range(0.9, 1.2), 30.0)
			elif kind == "werewolf":
				SFX.play_3d("wolf_snarl", global_position + Vector3.UP * 1.8, -2.0, rng.randf_range(0.9, 1.1), 40.0)
			elif kind == "vampire":
				SFX.play_3d("vamp_hiss", global_position + Vector3.UP * 1.7, -2.0, 1.0, 30.0)
			elif kind == "psycho":
				bark(["DIE DIE DIE!", "STAB STAB STAB!", "HOLD STILL!"])
	else:
		var spd := float(def.run)
		if kind == "walker" and d > 12.0:
			spd = float(def.walk) * 1.6
		_steer(tp, spd, delta)

func _strike() -> void:
	match windup_kind:
		"scream":
			return
		"pop":
			_pop()
			return
		"slam":
			SFX.play_3d("slam", global_position, 6.0, 0.8, 120.0)
			Combat.impact(global_position + Vector3.UP * 0.1, Vector3.UP, "dirt")
			var p := _player()
			if p != null and not p.dead:
				var d := global_position.distance_to(p.global_position)
				if d < 7.0 and _hostile_to_player():
					GameData.take_damage(dmg * 0.85 * (1.0 - d / 9.0), display_name, global_position, "zombie")
					p.velocity += (p.global_position - global_position).normalized() * 9.0 + Vector3.UP * 6.0
				if d < 30.0:
					p.trauma = minf(1.0, p.trauma + (1.0 - d / 30.0) * 0.9)
			return
		"throw":
			if target != null and is_instance_valid(target):
				var from := global_position + Vector3(0, 4.2, 0)
				var tp := _target_pos(target) + Vector3(0, 1.0, 0)
				var flight := clampf(from.distance_to(tp) / 22.0, 0.6, 1.6)
				var v := (tp - from) / flight
				v.y += 0.5 * 14.0 * flight
				var pr := Projectile.new()
				pr.setup("rock", from, v, {"dmg": dmg * 0.8})
				pr.owner_node = self
				get_parent().add_child(pr)
				SFX.play_3d("goliath_roar", from, 0.0, 1.3, 90.0)
			return
	if target == null or not is_instance_valid(target):
		return
	var tp2 := _target_pos(target)
	var to := tp2 - global_position
	var flat := Vector2(to.x, to.z).length()
	var fwd := -global_transform.basis.z
	if flat > float(def.reach) + 0.7 or fwd.dot(Vector3(to.x, 0, to.z).normalized()) < 0.2:
		return
	if target is Player:
		var p2 := target as Player
		if p2.in_vehicle != null:
			p2.in_vehicle.call("take_hit", {"dmg": dmg, "pos": global_position, "dir": to.normalized()})
			GameData.take_damage(dmg * 0.25, display_name, global_position)
		else:
			GameData.take_damage(dmg, display_name, global_position, def.get("bite", ""))
			if def.has("knock"):
				p2.velocity += Vector3(to.x, 0, to.z).normalized() * float(def.knock) + Vector3.UP * 3.0
		if def.has("drain"):
			hp = minf(hp_max, hp + dmg * float(def.drain))
	elif target is Monster:
		var res: Dictionary = (target as Monster).take_hit({"dmg": dmg, "pos": (target as Monster).aim_point(false), "dir": to.normalized(), "source": "monster", "attacker": self, "head_mul": 1.0, "melee": true})
		if res.get("killed", false) and faction == "raider":
			bark(BARKS_KILL)

func _blink(tp: Vector3) -> void:
	var a := rng.randf() * TAU
	var dest := tp + Vector3(cos(a) * 3.0, 0.5, sin(a) * 3.0)
	var q := PhysicsRayQueryParameters3D.create(dest + Vector3.UP * 3.0, dest + Vector3.DOWN * 6.0, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	Combat.flash_light(global_position + Vector3.UP, Color(0.7, 0.1, 0.2), 6.0, 3.0, 0.3)
	Combat.blood(global_position + Vector3.UP, Vector3.UP, Color(0.15, 0.02, 0.05), 16)
	SFX.play_3d("blink", global_position + Vector3.UP, 0.0, 1.0, 40.0)
	global_position = hit.position + Vector3.UP * 0.1
	velocity = Vector3.ZERO
	_face(tp - global_position, 1.0)
	SFX.play_3d("vamp_hiss", global_position + Vector3.UP, 0.0, 1.0, 40.0)
	attack_cd = minf(attack_cd, 0.25)

func _pop() -> void:
	Combat.gas_cloud(global_position + Vector3.UP * 0.5, 4.8, 10.0)
	SFX.play_3d("bloater_pop", global_position, 4.0, 1.0, 70.0)
	var p := _player()
	if p != null and not p.dead and p.global_position.distance_to(global_position) < 3.5:
		GameData.take_damage(dmg * 2.0, display_name, global_position, "gas")
	_die({"source": "player" if hurt_by_player else "self", "dir": Vector3.UP, "force": 2.0}, false)

func _ranged(delta: float) -> void:
	var tp := _target_pos(target)
	var d := global_position.distance_to(tp)
	var stationary: bool = def.get("stationary", false)
	var eye := global_position + Vector3(0, 1.5 * float(def.scale), 0)
	var q := PhysicsRayQueryParameters3D.create(eye, tp + Vector3(0, 1.1, 0), 1 | 2)
	var los := get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_face(tp - global_position, delta * 7.0)
	if not stationary:
		if d > float(def.range) or not los:
			_steer(tp, float(def.run), delta)
			burst_left = 0
		else:
			strafe_t -= delta
			if strafe_t <= 0.0:
				strafe_t = rng.randf_range(1.2, 2.8)
				strafe_dir = -strafe_dir if rng.randf() < 0.7 else strafe_dir
			var right := global_transform.basis.x
			var mv := right * strafe_dir * float(def.walk) * 1.3
			if d < 8.0:
				mv += (global_position - tp).normalized() * float(def.walk) * 1.5
			velocity.x = lerpf(velocity.x, mv.x, 1.0 - exp(-6.0 * delta))
			velocity.z = lerpf(velocity.z, mv.z, 1.0 - exp(-6.0 * delta))
	if not los or d > float(def.range) * 1.1:
		return
	if burst_left <= 0:
		if attack_cd <= 0.0:
			burst_left = int(def.burst)
			burst_t = 0.0
			attack_cd = rng.randf_range(1.1, 2.4) if not stationary else rng.randf_range(0.7, 1.3)
		return
	burst_t -= delta
	if burst_t > 0.0:
		return
	burst_t = 0.11 if kind != "guard" else 0.35
	burst_left -= 1
	var muzzle := eye
	if parts.has("muzzle"):
		muzzle = (parts.muzzle as Node3D).global_position
	var aim := tp + Vector3(0, 1.05, 0)
	var spread := deg_to_rad(float(def.spread) + clampf(d / 12.0, 0.0, 3.0))
	if target is Player:
		var pv := (target as Player).velocity
		spread += deg_to_rad(clampf(Vector2(pv.x, pv.z).length() * 0.45, 0.0, 3.5))
	var dir := (aim - muzzle).normalized()
	dir = dir.rotated(Vector3.UP, rng.randf_range(-spread, spread)).rotated(global_transform.basis.x, rng.randf_range(-spread, spread) * 0.7)
	var sq := PhysicsRayQueryParameters3D.create(muzzle, muzzle + dir * float(def.range) * 1.5, 1 | 2 | 4 | 32 | 64)
	sq.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(sq)
	var end := muzzle + dir * float(def.range) * 1.5
	if not hit.is_empty():
		end = hit.position
		var col: Object = hit.collider
		if col is Player:
			GameData.take_damage(dmg, display_name, global_position)
		elif col is Monster and col != self:
			if _is_enemy(col):
				(col as Monster).take_hit({"dmg": dmg * (2.2 if faction == "haven" else 1.0), "pos": hit.position, "dir": dir, "source": "monster", "attacker": self, "head_mul": 1.6})
		elif col != null and col.has_method("take_hit") and col is Node and (col as Node).is_in_group("vehicle"):
			col.take_hit({"dmg": dmg * 0.6, "pos": hit.position, "dir": dir})
		else:
			Combat.impact(hit.position, hit.normal, Combat.surface_of(col))
	Combat.tracer(muzzle, end, Color(1.0, 0.6, 0.35))
	Combat.flash_light(muzzle, Color(1.0, 0.7, 0.35), 5.0, 2.0)
	SFX.play_3d("shot_raider" if kind != "gnasher" else "shot_lmg", muzzle, -2.0, rng.randf_range(0.9, 1.1), 120.0)
	Hearing.emit_noise(global_position, 45.0, "gunfire", false)

# ================= death =================
func _die(info: Dictionary, head: bool) -> void:
	if dead:
		return
	dead = true
	remove_from_group("monsters")
	remove_from_group(faction)
	set_physics_process(false)
	var by_player: bool = info.get("source", "") == "player" or (hurt_by_player and info.get("source", "") in ["fire", "self", "explosion", "gas"])
	if by_player and xp_value > 0:
		GameData.register_kill(kind, faction, head, xp_value)
	died.emit(self, info)
	_drop_loot()
	if def.get("bloater", false) and info.get("source", "") != "self":
		Combat.gas_cloud(global_position + Vector3.UP * 0.5, 4.5, 9.0)
		SFX.play_3d("bloater_pop", global_position, 2.0, 1.0, 60.0)
	if def.get("boss", false):
		SFX.play_3d("goliath_roar" if faction == "undead" else "raider_shout", global_position + Vector3.UP * 2.0, 4.0, 0.7, 120.0)
	elif faction == "undead" and rng.randf() < 0.4:
		SFX.play_3d("zombie_groan", global_position + Vector3.UP, -4.0, 0.7, 30.0)
	_ragdoll(info)
	queue_free()

func _drop_loot() -> void:
	var table: Array = LOOT.get(def.get("loot", ""), [])
	var parent := get_parent()
	if parent == null:
		return
	var drops := []
	for row in table:
		if rng.randf() > float(row[3]):
			continue
		var id: String = row[0]
		var n := rng.randi_range(int(row[1]), int(row[2]))
		match id:
			"@weapon_boss":
				drops.append(ItemDB.roll_weapon("", level + 1, maxi(3, ItemDB.roll_rarity(level, 0.6, 3))))
			"@raider_gun":
				drops.append(ItemDB.roll_weapon(["smg", "ar", "shotgun", "pistol", "revolver"][rng.randi() % 5], level))
			"@armor_good":
				drops.append(ItemDB.roll_armor("", level, maxi(2, ItemDB.roll_rarity(level, 0.5, 2))))
			_:
				if id.begins_with("@"):
					for i in n:
						drops.append_array(ItemDB._roll_entry(id, 1, level, float(GameData.derived().luck), GameData.owned_ammo_types()))
				else:
					drops.append({"id": id, "count": n})
	for e in drops:
		var lp := LootPickup.new()
		lp.entry = e
		parent.add_child(lp)
		lp.global_position = global_position + Vector3(rng.randf_range(-0.5, 0.5), 1.0, rng.randf_range(-0.5, 0.5))
		lp.linear_velocity = Vector3(rng.randf_range(-2, 2), rng.randf_range(3, 5), rng.randf_range(-2, 2))

func _ragdoll(info: Dictionary) -> void:
	var parent := get_parent()
	if parent == null or not parts.has("root"):
		return
	var s := float(def.scale)
	var body := RigidBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 1 | 2
	body.mass = 45.0 * s
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.55, 1.7, 0.4) * s if not parts.get("quad", false) else Vector3(0.5, 0.5, 1.1) * s
	if def.body == "gaunt":
		bs.size = Vector3(0.8, 0.6, 2.2) * s
	cs.shape = bs
	cs.position = Vector3(0, bs.size.y * 0.5, 0)
	body.add_child(cs)
	parent.add_child(body)
	body.global_transform = global_transform
	var root: Node3D = parts.root
	root.reparent(body, true)
	for mi in parts.meshes:
		(mi as GeometryInstance3D).material_overlay = null
	# death pose: limbs go slack
	for k in ["arm_l", "arm_r"]:
		if parts.has(k):
			(parts[k] as Node3D).rotation = Vector3(rng.randf_range(-0.6, 1.4), 0, rng.randf_range(-0.8, 0.8))
	var dir: Vector3 = info.get("dir", -global_transform.basis.z)
	var force := clampf(float(info.get("force", 3.0)), 1.5, 22.0)
	body.apply_impulse((dir.normalized() * force + Vector3.UP * force * 0.35) * body.mass * 0.18, Vector3(0, 1.3 * s, 0))
	body.angular_velocity = Vector3(rng.randf_range(-2, 2), rng.randf_range(-1, 1), rng.randf_range(-2, 2))
	corpses.append(body)
	while corpses.size() > 14:
		var old = corpses.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var t := body.create_tween()
	t.tween_interval(9.0 if not def.get("boss", false) else 40.0)
	t.tween_property(root, "position:y", -1.2 * s, 2.0)
	t.tween_callback(func():
		corpses.erase(body)
		body.queue_free())

# ================= animation =================
func _animate(delta: float) -> void:
	if parts.is_empty():
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	var run := clampf(hs / maxf(1.0, float(def.run)), 0.0, 1.0)
	anim_t += delta * (1.5 + hs * 1.7)
	flinch_k = lerpf(flinch_k, 0.0, 1.0 - exp(-8.0 * delta))
	var torso: Node3D = parts.get("torso")
	if parts.get("quad", false):
		var legs: Array = parts.legs
		var amp := clampf(hs / 3.0, 0.0, 1.0) * 0.7
		for i in legs.size():
			var ph := 0.0 if (i == 0 or i == 3) else PI
			(legs[i] as Node3D).rotation.x = sin(anim_t + ph) * amp
		if torso != null:
			torso.rotation.x = -flinch_k * 0.4
		return
	var hips: Node3D = parts.hips
	var leg_l: Node3D = parts.leg_l
	var leg_r: Node3D = parts.leg_r
	var arm_l: Node3D = parts.arm_l
	var arm_r: Node3D = parts.arm_r
	var head: Node3D = parts.head
	var crawl: bool = def.get("gaunt", false) or (kind == "werewolf" and run > 0.6)
	var stride := clampf(hs / 2.5, 0.0, 1.0) * (0.75 if not def.get("runner", false) else 1.0)
	var base_y: float = parts.get("hips_y", 0.93)
	leg_l.rotation.x = sin(anim_t) * stride
	leg_r.rotation.x = -sin(anim_t) * stride
	hips.position.y = lerpf(hips.position.y, base_y - absf(sin(anim_t)) * 0.05 * stride, 0.3)
	var lean := 0.12
	var la := 0.0
	var ra := 0.0
	var lz := 0.0
	var rz := 0.0
	match faction:
		"undead":
			if def.get("runner", false):
				lean = 0.35 + run * 0.15
				la = sin(anim_t + PI) * 1.1 * stride + 0.4
				ra = sin(anim_t) * 1.1 * stride + 0.4
			else:
				la = 1.3 + sin(anim_t * 0.5) * 0.15
				ra = 1.35 + sin(anim_t * 0.5 + 1.0) * 0.15
				lz = 0.12
				rz = -0.12
		"raider", "haven":
			lean = 0.05
			if def.get("ranged", false):
				ra = 1.45
				la = 1.3
				lz = 0.5
			else:
				la = sin(anim_t + PI) * 0.9 * stride
				ra = 0.9 + sin(anim_t) * 0.3
		_:
			la = sin(anim_t + PI) * 0.8 * stride
			ra = sin(anim_t) * 0.8 * stride
	if crawl:
		# on all fours: torso pitched flat, arms reach forward-down, legs fold back
		lean = 1.4 if def.get("gaunt", false) else 1.0
		var reach_fwd := -0.55 if def.get("gaunt", false) else -0.35
		la = reach_fwd + sin(anim_t + PI) * 0.6 * maxf(0.3, stride)
		ra = reach_fwd + sin(anim_t) * 0.6 * maxf(0.3, stride)
		leg_l.rotation.x = -0.9 + sin(anim_t) * stride * 0.6
		leg_r.rotation.x = -0.9 - sin(anim_t) * stride * 0.6
		hips.position.y = lerpf(hips.position.y, base_y * 0.62, 0.2)
	if windup > 0.0:
		var w := clampf(1.0 - windup / maxf(0.2, float(def.rate) * 0.32), 0.0, 1.0)
		match windup_kind:
			"melee":
				la = lerpf(2.6, 0.6, w * w)
				ra = lerpf(2.7, 0.5, w * w)
			"scream":
				lean = -0.25
				la = 0.6
				ra = 0.6
				lz = 0.8
				rz = -0.8
				if parts.has("jaw"):
					(parts.jaw as Node3D).position.y = -0.06 * absf(sin(anim_t * 6.0))
			"slam":
				la = 2.9
				ra = 2.9
				lean = -0.2 + w * 0.8
			"throw":
				ra = 3.0 - w * 2.0
	torso.rotation.x = lean + flinch_k * -0.5
	torso.rotation.z = sin(anim_t * 0.5) * 0.04
	arm_l.rotation = arm_l.rotation.lerp(Vector3(la, 0, lz), 1.0 - exp(-14.0 * delta))
	arm_r.rotation = arm_r.rotation.lerp(Vector3(ra, 0, rz), 1.0 - exp(-14.0 * delta))
	if faction == "undead" and not crawl:
		head.rotation.z = sin(anim_t * 0.3) * 0.18
	elif crawl:
		head.rotation.x = -1.2
	if parts.has("saw"):
		(parts.saw as Node3D).rotate_object_local(Vector3.UP, delta * 30.0)
	if parts.has("tail"):
		(parts.tail as Node3D).rotation.y = sin(anim_t * 0.8) * 0.4
