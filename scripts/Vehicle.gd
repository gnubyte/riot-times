extends VehicleBody3D
# Scrap Buggy: a Mad Max roll-cage runabout. Fuel, hull damage, headlights, horn,
# a chase camera, and a spiked ram that turns the dead into flying meat.
# Engines are LOUD — everything within earshot knows you're coming.

class_name Vehicle

const MAX_STEER := 0.5
const ENGINE := 2600.0
const BRAKE := 35.0
const PAINTS := [Color(0.6, 0.28, 0.12), Color(0.25, 0.32, 0.38), Color(0.3, 0.34, 0.22)]

var index := 0
var fuel := 60.0
var hp := 400.0
var hp_max := 450.0
var paint := 0
var driver: Player = null
var cam: Camera3D
var cam_yaw := 0.0
var cam_pitch := -0.22
var _cam_idle := 0.0
var lights: Array[SpotLight3D] = []
var _hit: Area3D
var _noise_t := 0.0
var _wrecked := false
var _last_speed := 0.0
var _horn_cd := 0.0
var _fwd := 1.0

func _ready() -> void:
	add_to_group("vehicle")
	add_to_group("metal")
	collision_layer = 32
	collision_mask = 1 | 2 | 32
	mass = 950.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_crash)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 0.9, 4.1)
	cs.shape = bs
	cs.position = Vector3(0, 0.75, 0)
	add_child(cs)
	var cs2 := CollisionShape3D.new()
	var bs2 := BoxShape3D.new()
	bs2.size = Vector3(1.7, 0.9, 2.0)
	cs2.shape = bs2
	cs2.position = Vector3(0, 1.55, 0.2)
	add_child(cs2)
	_build_body()
	for wp in [Vector3(-0.98, 0.5, 1.35), Vector3(0.98, 0.5, 1.35), Vector3(-0.98, 0.5, -1.35), Vector3(0.98, 0.5, -1.35)]:
		var wh := VehicleWheel3D.new()
		wh.position = wp
		wh.wheel_radius = 0.46
		wh.wheel_rest_length = 0.18
		wh.suspension_travel = 0.28
		wh.suspension_stiffness = 48.0
		wh.suspension_max_force = 9000.0
		wh.damping_compression = 1.9
		wh.damping_relaxation = 2.3
		wh.wheel_friction_slip = 2.6
		wh.wheel_roll_influence = 0.08
		wh.use_as_traction = true
		wh.use_as_steering = wp.z > 0.0
		add_child(wh)
		var tire := Viewmodels.cyl(wh, 0.46, 0.34, Vector3.ZERO, MonsterBodies.m(Color(0.07, 0.07, 0.07), 0.95), false)
		tire.rotation.z = PI / 2.0
		tire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var hub := Viewmodels.cyl(wh, 0.2, 0.36, Vector3.ZERO, MonsterBodies.m(Color(0.5, 0.5, 0.52), 0.4, 0.0, 0.8), false)
		hub.rotation.z = PI / 2.0
	cam = Camera3D.new()
	cam.top_level = true
	cam.fov = 78.0
	cam.far = 1200.0
	add_child(cam)
	for x in [-0.6, 0.6]:
		var sl := SpotLight3D.new()
		sl.light_color = Color(1.0, 0.92, 0.75)
		sl.light_energy = 4.0
		sl.spot_range = 40.0
		sl.spot_angle = 32.0
		sl.shadow_enabled = x < 0.0
		sl.position = Vector3(x, 1.0, 2.15)
		sl.rotation.y = PI
		sl.rotation.x = -0.08
		sl.visible = false
		add_child(sl)
		lights.append(sl)
	_hit = Area3D.new()
	_hit.collision_layer = 0
	_hit.collision_mask = 4
	var hs := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(2.4, 1.6, 1.4)
	hs.shape = hb
	hs.position = Vector3(0, 1.0, 2.5)
	_hit.add_child(hs)
	add_child(_hit)
	_hit.body_entered.connect(_on_ram)

func _build_body() -> void:
	var col: Color = PAINTS[paint % PAINTS.size()]
	var bodym := MonsterBodies.m(col, 0.6, 0.0, 0.4)
	var dark := MonsterBodies.m(Color(0.12, 0.12, 0.13), 0.5, 0.0, 0.7)
	var rust := MonsterBodies.m(Color(0.45, 0.28, 0.16), 0.8, 0.0, 0.3)
	var parts := {"meshes": []}
	var root := Node3D.new()
	add_child(root)
	MonsterBodies._box(root, Vector3(1.8, 0.45, 4.0), Vector3(0, 0.75, 0), bodym, parts)
	MonsterBodies._box(root, Vector3(1.6, 0.35, 1.2), Vector3(0, 1.05, 1.4), bodym, parts)                       # hood
	MonsterBodies._box(root, Vector3(0.6, 0.35, 0.6), Vector3(0, 1.32, 1.2), dark, parts)                        # blower
	MonsterBodies._box(root, Vector3(1.85, 0.12, 0.5), Vector3(0, 0.7, 2.15), rust, parts)                       # ram
	for k in 5:
		MonsterBodies._box(root, Vector3(0.06, 0.06, 0.55), Vector3(-0.8 + k * 0.4, 0.75, 2.5), dark, parts, Vector3(0.0, 0, 0))
	for x in [-0.82, 0.82]:
		for z in [-0.9, 0.7]:
			MonsterBodies._box(root, Vector3(0.07, 1.1, 0.07), Vector3(x, 1.5, z), dark, parts)             # roll cage
	MonsterBodies._box(root, Vector3(1.7, 0.07, 0.07), Vector3(0, 2.05, -0.9), dark, parts)
	MonsterBodies._box(root, Vector3(1.7, 0.07, 0.07), Vector3(0, 2.05, 0.7), dark, parts)
	MonsterBodies._box(root, Vector3(0.07, 0.07, 1.6), Vector3(-0.82, 2.05, -0.1), dark, parts)
	MonsterBodies._box(root, Vector3(0.07, 0.07, 1.6), Vector3(0.82, 2.05, -0.1), dark, parts)
	MonsterBodies._box(root, Vector3(0.55, 0.7, 0.55), Vector3(-0.4, 1.25, -0.2), MonsterBodies.m(Color(0.3, 0.2, 0.12), 0.9), parts)   # seats
	MonsterBodies._box(root, Vector3(0.55, 0.7, 0.55), Vector3(0.4, 1.25, -0.2), MonsterBodies.m(Color(0.3, 0.2, 0.12), 0.9), parts)
	for x in [-0.95, 0.95]:
		var pipe := Viewmodels.cyl(root, 0.07, 1.3, Vector3(x, 1.1, -1.3), dark, false)
		pipe.rotation.x = 0.4
	MonsterBodies._box(root, Vector3(1.4, 0.5, 0.6), Vector3(0, 1.1, -1.8), rust, parts)                        # fuel drum
	var spare := Viewmodels.cyl(root, 0.42, 0.28, Vector3(0, 1.55, -2.0), MonsterBodies.m(Color(0.07, 0.07, 0.07), 0.95), false)
	spare.rotation.x = PI / 2.0
	for x in [-0.6, 0.6]:
		MonsterBodies._box(root, Vector3(0.25, 0.18, 0.06), Vector3(x, 1.0, 2.13), MonsterBodies.m(Color(1.0, 0.95, 0.8), 0.3, 2.0), parts)

func interact(p: Node) -> void:
	if _wrecked:
		GameData.game_message("This one's done. Burnt out.", Color(0.8, 0.6, 0.5))
		return
	if driver != null:
		return
	if fuel < 15.0 and GameData.count_item("fuel_can") > 0:
		GameData.remove_item("fuel_can", 1)
		fuel = minf(100.0, fuel + 40.0)
		SFX.play("drink", -4.0, 0.6)
		GameData.game_message("Refueled: %d%%" % int(fuel), Color(0.9, 0.85, 0.5))
		return
	if hp < hp_max * 0.6 and GameData.count_item("scrap") >= 5:
		GameData.remove_item("scrap", 5)
		hp = minf(hp_max, hp + 120.0)
		SFX.play("equip", -2.0, 0.7)
		GameData.game_message("Patched the hull: %d%%" % int(hp / hp_max * 100.0), Color(0.9, 0.85, 0.5))
		return
	enter(p as Player)

func prompt() -> String:
	if _wrecked:
		return "Burnt-out buggy"
	if fuel < 15.0 and GameData.count_item("fuel_can") > 0:
		return "Refuel buggy (Jerry Can)"
	if hp < hp_max * 0.6 and GameData.count_item("scrap") >= 5:
		return "Repair buggy (5 scrap)"
	return "Drive Scrap Buggy  (fuel %d%%)" % int(fuel)

func enter(p: Player) -> void:
	if p == null:
		return
	driver = p
	sleeping = false
	can_sleep = false
	p.enter_vehicle(self)
	cam.current = true
	cam_yaw = 0.0
	SFX.engine_loop(true, self, 0.8, -8.0)
	SFX.play("equip", -6.0, 0.7)
	GameData.discover("buggy", "SCRAP BUGGY", 40)

func exit() -> void:
	if driver == null:
		return
	var out := global_position + global_transform.basis.x * -1.8 + Vector3(0, 0.4, 0)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.2, 0), out + Vector3(0, 0.8, 0), 1 | 2)
	if not space.intersect_ray(q).is_empty():
		out = global_position + global_transform.basis.x * 1.8 + Vector3(0, 0.4, 0)
	driver.exit_vehicle(out)
	driver = null
	can_sleep = true
	cam.current = false
	engine_force = 0.0
	brake = 8.0
	SFX.engine_loop(false)
	var w := get_tree().get_first_node_in_group("world_root")
	if w != null:
		w.save_vehicles()

func _unhandled_input(event: InputEvent) -> void:
	if driver == null:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pad_x"):
		get_viewport().set_input_as_handled()
		exit()
	elif event.is_action_pressed("flashlight"):
		for l in lights:
			l.visible = not l.visible
		SFX.play("click", -8.0)
	elif event.is_action_pressed("horn") and _horn_cd <= 0.0:
		_horn_cd = 0.8
		SFX.play_3d("horn", global_position, 2.0, 1.0, 120.0)
		Hearing.emit_noise(global_position, 80.0, "vehicle", true)
	elif event is InputEventMouseMotion and GameData.is_captured():
		cam_yaw -= event.relative.x * 0.004
		cam_pitch = clampf(cam_pitch - event.relative.y * 0.003, -0.9, 0.3)
		_cam_idle = 0.0

func _physics_process(delta: float) -> void:
	_horn_cd -= delta
	var speed := linear_velocity.length()
	if driver == null or _wrecked:
		engine_force = 0.0
		brake = 6.0 if driver == null else 20.0
		return
	driver.global_position = global_position + Vector3(0, 0.6, 0)
	var d := GameData.derived()
	var throttle := Input.get_action_strength("move_forward")
	var trig_t := Input.get_action_strength("fire") if GameData.input_mode == "pad" else 0.0
	throttle = maxf(throttle, trig_t)
	var rev := Input.get_action_strength("move_back")
	if GameData.input_mode == "pad":
		rev = maxf(rev, Input.get_action_strength("ads"))
	var steer_in := Input.get_axis("move_right", "move_left")
	var boost := Input.is_action_pressed("sprint")
	var fwd_speed := linear_velocity.dot(global_transform.basis.z) * _fwd
	var force := 0.0
	brake = 0.0
	if fuel > 0.0:
		if throttle > 0.05:
			force = ENGINE * throttle * (1.4 if boost else 1.0)
		elif rev > 0.05:
			if fwd_speed > 2.0:
				brake = BRAKE * rev
			else:
				force = -ENGINE * 0.6 * rev
	elif throttle > 0.05 and _noise_t <= 0.0:
		GameData.game_message("Out of fuel. Find a Jerry Can.", Color(1.0, 0.6, 0.4))
	if Input.is_action_pressed("jump"):
		brake = BRAKE * 1.4
	engine_force = force * _fwd
	var steer_limit := MAX_STEER * clampf(1.0 - speed / 45.0, 0.35, 1.0)
	steering = move_toward(steering, steer_in * steer_limit, delta * 2.6)
	if absf(force) > 0.0:
		fuel = maxf(0.0, fuel - absf(force) / ENGINE * 0.28 * delta * (1.6 if boost else 1.0) * (1.0 - float(d.vehicle)))
	SFX.engine_loop(true, self, 0.7 + clampf(speed / 22.0, 0.0, 1.5) + throttle * 0.15, -8.0 + throttle * 4.0)
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = 0.5
		Hearing.emit_noise(global_position, 22.0 + speed * 1.6, "vehicle", true)
	_last_speed = speed

func _process(delta: float) -> void:
	if driver == null:
		return
	# chase camera with orbit; recenters behind the car while driving
	var rs := InputSetup.right_stick()
	if rs.length() > 0.15:
		cam_yaw -= rs.x * delta * 2.5
		cam_pitch = clampf(cam_pitch - rs.y * delta * 1.6, -0.9, 0.3)
		_cam_idle = 0.0
	_cam_idle += delta
	if _cam_idle > 1.5 and linear_velocity.length() > 3.0:
		cam_yaw = lerp_angle(cam_yaw, 0.0, delta * 2.0)
		cam_pitch = lerpf(cam_pitch, -0.22, delta * 2.0)
	var yaw := global_rotation.y + cam_yaw + (0.0 if _fwd > 0.0 else PI)
	var back := Vector3(sin(yaw), 0, cos(yaw)) * -6.8
	var target := global_position + back + Vector3(0, 2.7 - cam_pitch * 5.0, 0)
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.6, 0), target, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		target = hit.position + (global_position - target).normalized() * 0.4
	cam.global_position = cam.global_position.lerp(target, 1.0 - exp(-10.0 * delta))
	cam.look_at(global_position + Vector3(0, 1.3, 0), Vector3.UP)
	var spd := linear_velocity.length()
	cam.fov = lerpf(cam.fov, 74.0 + clampf(spd, 0.0, 30.0) * 0.45, 1.0 - exp(-4.0 * delta))

func _on_ram(body: Node) -> void:
	if not (body is Monster) or (body as Monster).dead:
		return
	var speed := linear_velocity.length()
	if speed < 4.0:
		return
	var m := body as Monster
	var dir := linear_velocity.normalized()
	var res: Dictionary = m.take_hit({"dmg": speed * 9.0, "pos": m.aim_point(false), "dir": dir, "source": "player" if driver != null else "vehicle",
		"head_mul": 1.0, "force": speed * 1.6, "melee": true, "attacker": driver})
	m.knockback(dir + Vector3.UP * 0.6, speed * 0.9)
	if driver != null and not res.is_empty():
		driver._on_hit_result(res, m.aim_point(false), m, true)
	hp -= 3.0
	linear_velocity *= 0.96
	SFX.play_3d("melee_hit", m.global_position, 0.0, 0.8, 40.0)

func _on_crash(body: Node) -> void:
	var impact := absf(_last_speed - linear_velocity.length())
	if impact < 6.0 or body is Monster:
		return
	var d := GameData.derived()
	var dmg := (impact - 6.0) * 12.0 * (1.0 - float(d.vehicle))
	take_hit({"dmg": dmg, "pos": global_position, "dir": Vector3.UP})
	SFX.play_3d("crash", global_position, 0.0, randf_range(0.9, 1.1), 60.0)
	if driver != null:
		driver.trauma = minf(1.0, driver.trauma + impact / 20.0)
		if impact > 12.0:
			GameData.take_damage((impact - 12.0) * 3.0, "a crash", global_position)

func take_hit(info: Dictionary) -> void:
	if _wrecked:
		return
	hp -= float(info.get("dmg", 0.0))
	if hp <= 0.0:
		_wreck()

func _wreck() -> void:
	_wrecked = true
	hp = 0.0
	var who := driver
	if driver != null:
		exit()
	Combat.explode(global_position + Vector3(0, 1, 0), 6.0, 120.0, null)
	SFX.engine_loop(false)
	for c in get_children():
		if c is Node3D and c.get_child_count() > 0 and not (c is VehicleWheel3D):
			for mi in c.get_children():
				if mi is MeshInstance3D:
					(mi as MeshInstance3D).material_override = MonsterBodies.m(Color(0.1, 0.09, 0.08), 0.9)
	if who != null:
		GameData.game_message("The buggy is wrecked.", Color(1.0, 0.5, 0.4))

func hud_info() -> Dictionary:
	return {"speed": linear_velocity.length() * 3.6, "fuel": fuel, "hp": hp / hp_max}
