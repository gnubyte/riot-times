extends CharacterBody3D
# Mutated wasteland creature. Procedural body, simple AI, XP + loot on death.

class_name Enemy

signal enemy_died(enemy: Node)

var def := {}
var hp := 20.0
var hp_max := 20.0
var speed := 3.0
var damage := 5.0
var xp_value := 20
var aggro := false
var aggro_range := 18.0
var attack_range := 2.6
var attack_cd := 0.0
var wander_timer := 0.0
var wander_dir := Vector3.ZERO
var home := Vector3.ZERO
var body_mat: StandardMaterial3D
var dead := false
var target: Node3D = null

const DEFS := {
	"radroach": {
		name="Radiation Roach", hp=18, speed=4.2, damage=4, xp=12, aggro=12,
		scale=0.55, color=Color(0.5, 0.3, 0.1), body="bug",
		loot=[["shards", 3, 8, 1.0], ["mut_meat", 1, 1, 0.5]],
	},
	"molerat": {
		name="Glow Molerat", hp=34, speed=3.4, damage=7, xp=22, aggro=14,
		scale=0.9, color=Color(0.75, 0.6, 0.45), body="quad",
		loot=[["shards", 4, 12, 1.0], ["mut_meat", 1, 2, 0.9], ["jerky", 1, 1, 0.3]],
	},
	"fireant": {
		name="Giant Fire Ant", hp=48, speed=4.6, damage=9, xp=32, aggro=16,
		scale=1.0, color=Color(0.6, 0.12, 0.08), body="bug",
		loot=[["shards", 5, 15, 1.0], ["mut_meat", 1, 2, 0.8]],
	},
	"dog": {
		name="Irradiated Dog", hp=42, speed=5.2, damage=10, xp=35, aggro=20,
		scale=1.0, color=Color(0.45, 0.35, 0.25), body="quad",
		loot=[["shards", 3, 10, 1.0], ["jerky", 1, 2, 0.6], ["mut_meat", 1, 2, 0.7], ["ammo_10mm", 4, 10, 0.4]],
	},
	"brahmin": {
		name="Two-Headed Brahmin", hp=90, speed=2.2, damage=8, xp=45, aggro=6,
		scale=1.5, color=Color(0.55, 0.4, 0.28), body="cow",
		loot=[["mut_meat", 3, 6, 1.0], ["jerky", 2, 3, 0.8], ["shards", 2, 8, 1.0]],
	},
	"centipede": {
		name="Radiation Centipede", hp=110, speed=3.6, damage=13, xp=60, aggro=18,
		scale=1.6, color=Color(0.35, 0.5, 0.2), body="centipede",
		loot=[["shards", 10, 25, 1.0], ["mut_meat", 2, 4, 0.9], ["radaway", 1, 1, 0.25], ["energy_cell", 2, 5, 0.3]],
	},
	"beast": {
		name="Radscorpion Behemoth", hp=260, speed=2.8, damage=22, xp=180, aggro=24,
		scale=2.6, color=Color(0.5, 0.25, 0.4), body="scorpion",
		loot=[["shards", 40, 90, 1.0], ["stimpak", 1, 2, 0.6], ["fusion_core", 1, 1, 0.3], ["rifle", 1, 1, 0.15], ["armor_metal", 1, 1, 0.2]],
	},
}

func setup(id: String, spawn_pos: Vector3) -> void:
	def = DEFS.get(id, DEFS["molerat"])
	name = "Enemy_" + id + "_" + str(randi() % 100000)
	global_position = spawn_pos
	home = spawn_pos
	hp_max = float(def.hp); hp = hp_max
	speed = def.speed; damage = def.damage; xp_value = def.xp; aggro_range = def.aggro
	collision_layer = 4
	collision_mask = 1 | 2 | 8
	_build_body()
	add_to_group("enemies")

func _build_body() -> void:
	var s: float = def.scale
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45 * s
	shape.height = 1.6 * s
	col.shape = shape
	col.position = Vector3(0, shape.height * 0.5, 0)
	add_child(col)

	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = def.color
	body_mat.roughness = 0.85
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.6, 1.0, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(0.5, 1.0, 0.2)
	glow.emission_energy_multiplier = 2.0

	match def.body:
		"bug": _body_bug(s, glow)
		"quad": _body_quad(s, glow)
		"cow": _body_cow(s, glow)
		"centipede": _body_centipede(s, glow)
		"scorpion": _body_scorpion(s, glow)
		_: _body_quad(s, glow)

func _mesh(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos
	_vis().add_child(mi)
	return mi

func _sphere(r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2.0
	mi.mesh = sm; mi.material_override = mat; mi.position = pos
	_vis().add_child(mi)
	return mi

# visual pivot node (separate from collision) for animation
var vis: Node3D = null
var limbs: Array[MeshInstance3D] = []
var tail: Array[MeshInstance3D] = []
var anim_t := 0.0

func _vis() -> Node3D:
	if vis == null:
		vis = Node3D.new()
		add_child(vis)
	return vis

func _limb(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := _mesh(size, pos, mat)
	limbs.append(mi)
	return mi

func _tailseg(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := _mesh(size, pos, mat)
	tail.append(mi)
	return mi

func _animate(delta: float) -> void:
	if vis == null or dead: return
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	if moving:
		anim_t += delta * (3.5 + speed * 0.9)
		vis.position.y = absf(sin(anim_t)) * 0.06 * def.scale
		vis.rotation.z = sin(anim_t * 0.5) * 0.05
	else:
		vis.position.y = lerpf(vis.position.y, 0.0, delta * 6.0)
		vis.rotation.z = lerpf(vis.rotation.z, 0.0, delta * 6.0)
	# flinch: knock the body back and recoil toward recovery
	if flinch_t > 0.0:
		flinch_t = maxf(0.0, flinch_t - delta)
		var k := flinch_t / flinch_dur
		vis.rotation.x = -flinch_str * k * k * 0.9      # snap back
		vis.position.y += k * 0.05 * def.scale
		vis.rotation.z += sin(k * 24.0) * 0.06 * k * flinch_str
	else:
		vis.rotation.x = lerpf(vis.rotation.x, 0.0, delta * 10.0)
	for i in limbs.size():
		var l := limbs[i]
		var amp := 0.55 if moving else 0.03
		if flinch_t > 0.0:
			amp = 0.9 * (flinch_t / flinch_dur)   # legs flail when hit
		l.rotation.x = sin(anim_t * 2.0 + i * PI * 0.5) * amp
	for i in tail.size():
		var t := tail[i]
		if t.has_meta("base_rot"):
			t.rotation.x = get_meta_f(t, "base_rot") + sin(anim_t + i * 0.7) * 0.12
		else:
			t.set_meta("base_rot", t.rotation.x)

var flinch_t := 0.0
var flinch_dur := 0.35
var flinch_str := 1.0

func flinch(strength := 1.0) -> void:
	flinch_t = flinch_dur
	flinch_str = clampf(strength, 0.4, 2.0)
	# stagger: shove the body opposite the shot
	if not dead and not aggro and randf() < 0.3:
		aggro = true

func _die() -> void:
	dead = true
	SFX.play("death", -6.0)
	GameData.record_kill(str(def.get("name", "creature")))
	enemy_died.emit(self)
	_spawn_loot()
	flinch(1.6)
	# death animation: recoil, collapse, fade out
	if vis != null:
		var tw0 := create_tween()
		tw0.tween_property(vis, "rotation:x", -1.25, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw0.parallel().tween_property(vis, "position:y", 0.12 * def.scale, 0.28)
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(self, "scale", Vector3(1, 0.1, 1), 0.5)
	tw.tween_callback(queue_free)
	set_physics_process(false)
	# disable collision so bullets pass through corpses
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = true

static func get_meta_f(n: Node, key: String) -> float:
	return float(n.get_meta(key))

func _body_bug(s: float, glow: Material) -> void:
	_mesh(Vector3(0.7, 0.4, 1.1) * s, Vector3(0, 0.35, 0) * s, body_mat)
	_sphere(0.22 * s, Vector3(0, 0.42, -0.65) * s, body_mat)
	for i in 6:
		var side := 1.0 if i % 2 == 0 else -1.0
		_limb(Vector3(0.08, 0.35, 0.08) * s, Vector3(side * 0.42, 0.18, (-0.3 + (i / 2.0) * 0.45) * s) , body_mat)
	_sphere(0.06 * s, Vector3(0.12, 0.55, -0.75) * s, glow)
	_sphere(0.06 * s, Vector3(-0.12, 0.55, -0.75) * s, glow)

func _body_quad(s: float, glow: Material) -> void:
	_mesh(Vector3(0.6, 0.55, 1.2) * s, Vector3(0, 0.65, 0) * s, body_mat)
	_sphere(0.28 * s, Vector3(0, 0.75, -0.72) * s, body_mat)
	for i in 4:
		var fx := 0.24 if i < 2 else -0.24
		var fz := -0.4 if i % 2 == 0 else 0.4
		_limb(Vector3(0.14, 0.5, 0.14) * s, Vector3(fx, 0.22, fz) * s, body_mat)
	# glowing eyes / sores
	_sphere(0.05 * s, Vector3(0.1, 0.82, -0.92) * s, glow)
	_sphere(0.05 * s, Vector3(-0.1, 0.82, -0.92) * s, glow)
	if randf() < 0.8:
		_sphere(0.1 * s, Vector3(randf_range(-0.2, 0.2), 0.85, randf_range(-0.3, 0.3)) * s, glow)

func _body_cow(s: float, glow: Material) -> void:
	_mesh(Vector3(0.9, 0.9, 1.7) * s, Vector3(0, 0.95, 0) * s, body_mat)
	for i in 4:
		var fx := 0.35 if i < 2 else -0.35
		var fz := -0.6 if i % 2 == 0 else 0.6
		_mesh(Vector3(0.18, 0.6, 0.18) * s, Vector3(fx, 0.3, fz) * s, body_mat)
	# two heads
	_sphere(0.3 * s, Vector3(0.25, 1.35, -0.95) * s, body_mat)
	_sphere(0.3 * s, Vector3(-0.25, 1.35, -0.95) * s, body_mat)
	_sphere(0.07 * s, Vector3(0.25, 1.45, -1.18) * s, glow)
	_sphere(0.07 * s, Vector3(-0.25, 1.45, -1.18) * s, glow)

func _body_centipede(s: float, glow: Material) -> void:
	for seg in 7:
		var z := (-0.9 + seg * 0.3) * s
		_mesh(Vector3(0.55, 0.3, 0.32) * s, Vector3(0, 0.32, z) * s, body_mat)
		if seg % 2 == 0:
			_mesh(Vector3(0.06, 0.3, 0.06) * s, Vector3(0.38, 0.15, z) * s, body_mat)
			_mesh(Vector3(0.06, 0.3, 0.06) * s, Vector3(-0.38, 0.15, z) * s, body_mat)
	_sphere(0.3 * s, Vector3(0, 0.4, -1.15) * s, body_mat)
	_sphere(0.08 * s, Vector3(0.14, 0.52, -1.3) * s, glow)
	_sphere(0.08 * s, Vector3(-0.14, 0.52, -1.3) * s, glow)

func _body_scorpion(s: float, glow: Material) -> void:
	_mesh(Vector3(0.9, 0.6, 1.6) * s, Vector3(0, 0.55, 0) * s, body_mat)
	for i in 6:
		var side := 1.0 if i % 2 == 0 else -1.0
		_mesh(Vector3(0.1, 0.5, 0.1) * s, Vector3(side * 0.55, 0.28, (-0.5 + (i / 2.0) * 0.5)), body_mat)
	# claws
	for side in [-1.0, 1.0]:
		_mesh(Vector3(0.14, 0.14, 0.7) * s, Vector3(side * 0.6, 0.45, -1.0), body_mat)
		_mesh(Vector3(0.3, 0.12, 0.35) * s, Vector3(side * 0.6, 0.45, -1.5), body_mat)
	# tail segments rising
	for t in 5:
		_mesh(Vector3(0.28, 0.28, 0.3) * s, Vector3(0, 0.7 + t * 0.28, 0.95 + t * 0.16) * s, body_mat)
	_mesh(Vector3(0.4, 0.15, 0.5) * s, Vector3(0, 2.1, 1.7) * s, glow)
	_sphere(0.1 * s, Vector3(0.18, 0.85, -0.75) * s, glow)
	_sphere(0.1 * s, Vector3(-0.18, 0.85, -0.75) * s, glow)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -0.5

	var player := _find_target()
	attack_cd -= delta
	var to_player := Vector3.ZERO
	if player != null:
		to_player = global_position.direction_to(player.global_position)
		to_player.y = 0

	# aggro check
	if player != null and not aggro:
		var dist := global_position.distance_to(player.global_position)
		if dist <= aggro_range:
			_aggro(player)
	if aggro and player != null:
		var dist := global_position.distance_to(player.global_position)
		if dist > aggro_range * 3.2:
			aggro = false
		var dir := to_player
		if dist > attack_range * 0.8:
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
		if dist <= attack_range and attack_cd <= 0.0:
			attack_cd = 1.1
			_attack(player)
		# face player
		var flat := Vector3(dir.x, 0, dir.z)
		if flat.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 10.0 * delta)
	# idle wander when not aggroed
	if not aggro:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(2.0, 6.0)
			if randf() < 0.4:
				wander_dir = Vector3.ZERO
			else:
				wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
			if global_position.distance_to(home) > 30.0:
				wander_dir = global_position.direction_to(home)
		velocity.x = wander_dir.x * speed * 0.35
		velocity.z = wander_dir.z * speed * 0.35
		if wander_dir.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(-wander_dir.x, -wander_dir.z), 5.0 * delta)
	move_and_slide()

func _find_target() -> Node3D:
	if target != null and is_instance_valid(target):
		return target
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node3D:
			target = p
			return p
	return null

func _aggro(_player: Node) -> void:
	aggro = true

func _attack(player: Node) -> void:
	if player.has_method("take_damage"):
		player.take_damage(damage, def.name)
	if "Enemy" in str(self):
		pass

func take_damage(amount: float, source := "unknown") -> void:
	if dead: return
	hp -= amount
	if body_mat != null:
		body_mat.albedo_color = def.color.lerp(Color.RED, 0.3)
		set_deferred("timer_flash", 0.15)
	# heavier rounds flinch harder
	flinch(clampf(amount / 16.0, 0.5, 2.0))
	if randf() < 0.5:
		SFX.play("hit_meat", -8.0, randf_range(0.9, 1.2))
	SFX.play("hurt_flinch", -16.0, randf_range(0.9, 1.2) / maxf(0.6, float(def.scale)))
	_blood_burst()
	if hp <= 0.0:
		_die()

func _blood_burst() -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world == null: return
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 75.0
	pm.gravity = Vector3(0, -14.0, 0)
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.5
	pm.scale_min = 0.05
	pm.scale_max = 0.13
	pm.color = Color(0.55, 0.08, 0.06)
	p.process_material = pm
	p.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(1, 1, 1, 1)), false)
	p.amount = 14
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.9
	world.add_child(p)
	p.global_position = global_position + Vector3(0, 0.6 * def.scale, 0)
	p.emitting = true
	var t := p.create_tween()
	t.tween_interval(1.0)
	t.tween_callback(p.queue_free)

var timer_flash := 0.0
func _process(delta: float) -> void:
	if dead: return
	_animate(delta)
	if timer_flash > 0.0:
		timer_flash -= delta
		if body_mat != null:
			body_mat.albedo_color = def.color.lerp(Color(2, 2, 2), clampf(timer_flash / 0.15, 0, 1) * 0.6)
		if timer_flash <= 0.0 and body_mat != null:
			body_mat.albedo_color = def.color

func _spawn_loot() -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world == null:
		return
	for entry in def.loot:
		var id: String = entry[0]
		var cmin: int = entry[1]; var cmax: int = entry[2]; var prob: float = entry[3]
		if randf() <= prob:
			var count := randi_range(cmin, cmax)
			var lp := LootPickup.new()
			world.add_child(lp)
			lp.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.2, randf_range(-0.8, 0.8))
			lp.setup(id, count)

