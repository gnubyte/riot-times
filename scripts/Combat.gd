class_name Combat
extends RefCounted
# Shared combat juice & area damage: tracers, impacts, blood, Borderlands-style
# damage numbers, explosions, molotov fire, bloater gas, shell casings, muzzle light.

static var _shells := 0
static var _decals: Array = []

static func world() -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("world_root") as Node3D

static func low_fx() -> bool:
	return UITheme.settings.get("quality", "high") == "low" or OS.get_environment("RT_NO_PARTICLES") == "1"

static func _unshaded(col: Color, add := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# Bullet streak that actually travels (~420 m/s) instead of a static line.
static func tracer(from: Vector3, to: Vector3, col := Color(1.0, 0.85, 0.5)) -> void:
	var w := world()
	if w == null:
		return
	var dir := to - from
	var length := dir.length()
	if length < 1.0:
		return
	dir /= length
	var streak := minf(length * 0.5, 5.0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.022, 0.022, streak)
	mi.mesh = bm
	mi.material_override = _unshaded(Color(col.r * 2.5, col.g * 2.5, col.b * 2.0, 0.85))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	mi.look_at_from_position(from + dir * streak * 0.5, from + dir * (streak * 0.5 + 1.0), up)
	var t := mi.create_tween()
	t.tween_property(mi, "global_position", to - dir * streak * 0.5, maxf(0.02, length / 420.0))
	t.tween_callback(mi.queue_free)

static func surface_of(col: Object) -> String:
	if col == null:
		return "dirt"
	if col is Node:
		var n := col as Node
		if n.is_in_group("terrain"):
			return "dirt"
		if n.is_in_group("vehicle") or n.is_in_group("metal"):
			return "metal"
	return "concrete"

static func _burst(w: Node3D, pos: Vector3, dir: Vector3, col: Color, amount: int, speed: float, size: float, life: float, grav := -9.8, spread := 55.0) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.05
	pm.direction = dir
	pm.spread = spread
	pm.gravity = Vector3(0, grav, 0)
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.scale_min = size * 0.5
	pm.scale_max = size
	pm.color = col
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	p.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(1, 1, 1, 1)), col.r + col.g > 1.2)
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	w.add_child(p)
	p.global_position = pos
	p.emitting = true
	w.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

static func impact(pos: Vector3, normal: Vector3, surface := "concrete") -> void:
	var w := world()
	if w == null:
		return
	if not low_fx():
		match surface:
			"metal":
				_burst(w, pos, normal, Color(1.0, 0.75, 0.35), 10, 5.0, 0.04, 0.35, -12.0, 40.0)
			"dirt":
				_burst(w, pos, normal, Color(0.55, 0.45, 0.32), 9, 2.2, 0.18, 0.7, -6.0, 35.0)
			_:
				_burst(w, pos, normal, Color(0.6, 0.58, 0.55), 8, 2.6, 0.12, 0.55, -7.0, 40.0)
				_burst(w, pos, normal, Color(1.0, 0.8, 0.45), 4, 4.0, 0.03, 0.2, -12.0, 30.0)
	_decal(w, pos, normal)
	SFX.play_3d("hit_metal" if surface == "metal" else "hit_dirt", pos, -12.0, randf_range(0.85, 1.15), 30.0)

static func _decal(w: Node3D, pos: Vector3, normal: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = Proc.particle_soft(Color(0.04, 0.035, 0.03, 1.0))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	var up := Vector3.UP if absf(normal.y) < 0.95 else Vector3.RIGHT
	mi.look_at_from_position(pos + normal * 0.012, pos + normal * 0.012 - normal, up)
	_decals.append(mi)
	while _decals.size() > 60:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()

static func blood(pos: Vector3, dir: Vector3, col := Color(0.5, 0.04, 0.04), amount := 12) -> void:
	var w := world()
	if w == null or low_fx():
		return
	_burst(w, pos, dir + Vector3.UP * 0.3, col, amount, 3.8, 0.11, 0.65, -14.0, 50.0)

# Floating combat text. White = normal, yellow & big = critical (headshot),
# red = killing blow, element tints for fire/silver.
static func damage_number(pos: Vector3, value: float, head := false, kill := false, element := "", note := "") -> void:
	if not UITheme.settings.get("damage_numbers", true):
		return
	var w := world()
	if w == null:
		return
	var col := Color(1, 1, 1)
	if element == "fire":
		col = Color(1.0, 0.55, 0.2)
	elif element == "silver":
		col = Color(0.75, 0.9, 1.0)
	if head:
		col = Color(1.0, 0.85, 0.15)
	if kill:
		col = Color(1.0, 0.3, 0.22) if not head else Color(1.0, 0.55, 0.1)
	var l := Label3D.new()
	l.text = str(int(round(value)))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 52 if not head else 72
	l.outline_size = 16
	l.outline_modulate = Color(0.05, 0.02, 0.0, 0.9)
	l.modulate = col
	l.render_priority = 20
	l.outline_render_priority = 19
	w.add_child(l)
	var off := Vector3(randf_range(-0.35, 0.35), randf_range(0.1, 0.4), randf_range(-0.35, 0.35))
	l.global_position = pos + off
	l.scale = Vector3.ONE * 1.8
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "global_position", l.global_position + Vector3(off.x * 0.6, 1.0, off.z * 0.6), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.55)
	t.tween_property(l, "outline_modulate:a", 0.0, 0.35).set_delay(0.55)
	t.chain().tween_callback(l.queue_free)
	var tag := note
	if tag == "" and head:
		tag = "CRITICAL!"
	if tag != "":
		var c := Label3D.new()
		c.text = tag
		c.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		c.no_depth_test = true
		c.fixed_size = true
		c.pixel_size = 0.0011
		c.font_size = 30
		c.outline_size = 10
		c.modulate = Color(1.0, 0.95, 0.4)
		c.render_priority = 20
		w.add_child(c)
		c.global_position = pos + off + Vector3(0, 0.35, 0)
		var t2 := c.create_tween()
		t2.tween_property(c, "global_position", c.global_position + Vector3(0, 0.9, 0), 0.85)
		t2.parallel().tween_property(c, "modulate:a", 0.0, 0.35).set_delay(0.5)
		t2.tween_callback(c.queue_free)

static func flash_light(pos: Vector3, col: Color, rng := 6.0, energy := 2.5, dur := 0.06) -> void:
	var w := world()
	if w == null:
		return
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	l.shadow_enabled = false
	w.add_child(l)
	l.global_position = pos
	var t := l.create_tween()
	t.tween_property(l, "light_energy", 0.0, dur)
	t.tween_callback(l.queue_free)

static func shell(pos: Vector3, vel: Vector3, red := false) -> void:
	if _shells >= 26 or low_fx():
		return
	var w := world()
	if w == null:
		return
	_shells += 1
	var rb := RigidBody3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008 if not red else 0.013
	cm.bottom_radius = cm.top_radius
	cm.height = 0.03 if not red else 0.06
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = Viewmodels.mat("brass", Color(0.8, 0.62, 0.25) if not red else Color(0.7, 0.1, 0.08), 0.9, 0.3)
	mi.rotation.z = PI / 2.0
	rb.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.014
	cs.shape = sh
	rb.add_child(cs)
	rb.collision_layer = 16
	rb.collision_mask = 1 | 2
	rb.mass = 0.02
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	var pinged := [false]
	rb.body_entered.connect(func(_b):
		if not pinged[0] and is_instance_valid(rb):
			pinged[0] = true
			SFX.play_3d("hit_metal", rb.global_position, -26.0, randf_range(1.6, 2.2), 12.0))
	w.add_child(rb)
	rb.global_position = pos
	rb.linear_velocity = vel
	rb.angular_velocity = Vector3(randf_range(-25, 25), randf_range(-25, 25), randf_range(-25, 25))
	w.get_tree().create_timer(3.5).timeout.connect(func():
		_shells -= 1
		if is_instance_valid(rb):
			rb.queue_free())

# ---------- area damage ----------
static func explode(pos: Vector3, radius: float, dmg: float, owner: Node, opts := {}) -> void:
	var w := world()
	if w == null:
		return
	var small: bool = opts.get("small", false)
	var tree := w.get_tree()
	for m in tree.get_nodes_in_group("monsters"):
		if not m.is_targetable():
			continue
		var c: Vector3 = m.aim_point(false)
		var d := c.distance_to(pos)
		if d > radius:
			continue
		var k := pow(1.0 - d / radius, 0.7)
		var info := {"dmg": dmg * k, "pos": c, "dir": (c - pos).normalized(), "element": opts.get("element", ""),
			"source": "player" if owner is Player else "explosion", "weapon": "explosion", "head_mul": 1.0,
			"force": (18.0 if not small else 6.0) * k, "explosive": true, "attacker": owner}
		var res: Dictionary = m.take_hit(info)
		m.knockback((c - pos).normalized() + Vector3.UP * 0.4, (12.0 if not small else 4.0) * k)
		if owner is Player and not res.is_empty():
			(owner as Player)._on_hit_result(res, c, m)
	var player := tree.get_first_node_in_group("player") as Player
	if player != null and not player.dead and not (opts.get("no_self", false) and owner == player):
		var pd := (player.global_position + Vector3(0, 1, 0)).distance_to(pos)
		if pd < radius and player.in_vehicle == null:
			GameData.take_damage(dmg * pow(1.0 - pd / radius, 0.8) * 0.55, "an explosion", pos)
		if pd < radius * 4.0:
			player.trauma = minf(1.0, player.trauma + (1.0 - pd / (radius * 4.0)) * (0.9 if not small else 0.35))
	for v in tree.get_nodes_in_group("vehicle"):
		var vd: float = (v as Node3D).global_position.distance_to(pos)
		if vd < radius:
			v.take_hit({"dmg": dmg * (1.0 - vd / radius), "pos": pos, "dir": Vector3.UP})
	var space := w.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), pos)
	q.collision_mask = 8 | 16
	for r in space.intersect_shape(q, 32):
		var b = r.collider
		if b is RigidBody3D:
			var dir: Vector3 = ((b as RigidBody3D).global_position - pos)
			(b as RigidBody3D).apply_central_impulse(dir.normalized() * (8.0 if not small else 2.0) + Vector3.UP * 3.0)
	# visuals
	flash_light(pos + Vector3(0, 0.5, 0), Color(1.0, 0.6, 0.25), radius * 3.0, 9.0 if not small else 4.0, 0.25)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	ball.mesh = sm
	var bmat := _unshaded(Color(1.0, 0.6, 0.2, 0.9))
	ball.material_override = bmat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(ball)
	ball.global_position = pos
	var t := ball.create_tween().set_parallel(true)
	t.tween_property(ball, "scale", Vector3.ONE * radius * (1.1 if not small else 0.7), 0.18).set_ease(Tween.EASE_OUT)
	t.tween_property(bmat, "albedo_color:a", 0.0, 0.3)
	t.chain().tween_callback(ball.queue_free)
	if not low_fx():
		_burst(w, pos, Vector3.UP, Color(1.0, 0.7, 0.3), 24 if not small else 8, 12.0 if not small else 5.0, 0.08, 0.5, -12.0, 180.0)
		_burst(w, pos + Vector3.UP * 0.5, Vector3.UP, Color(0.18, 0.16, 0.15), 16 if not small else 5, 3.5, 1.4 if not small else 0.5, 2.2, 0.6, 70.0)
	SFX.play_3d("explosion", pos, 2.0 if not small else -8.0, randf_range(0.9, 1.1) * (1.0 if not small else 1.5), 160.0)
	Hearing.emit_noise(pos, 90.0 if not small else 35.0, "explosion", owner is Player)

static func fire_zone(pos: Vector3, radius: float, dur: float, owner: Node) -> void:
	var w := world()
	if w == null:
		return
	var z := FireZone.new()
	z.radius = radius
	z.life = dur
	z.owner_node = owner
	w.add_child(z)
	z.global_position = pos
	Hearing.emit_noise(pos, 25.0, "fire", owner is Player)

static func gas_cloud(pos: Vector3, radius: float, dur: float) -> void:
	var w := world()
	if w == null:
		return
	var z := FireZone.new()
	z.radius = radius
	z.life = dur
	z.gas = true
	w.add_child(z)
	z.global_position = pos
