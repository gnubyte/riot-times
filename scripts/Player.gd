extends CharacterBody3D
# First-person player controller: movement w/ stamina sprint, mouselook, springs-recoil
# gun physics, shell casings, mantling/vaulting, reload & shoot & jump viewmodel
# animation states, hit flinches, FX juice.

class_name Player

signal shot_fired
signal melee_swing
signal reload_started
signal ammo_changed(loaded: int, reserve: int)
signal hit_registered(dmg: float, enemy: Node)
signal crosshair_spread_changed(v: float)
signal stamina_changed(cur: float, maxv: float, sprinting: bool)

const GRAVITY := 24.0
const JUMP := 7.2
const EYE := Vector3(0, 1.62, 0)

# sprint
const STAMINA_MAX := 100.0
const SPRINT_DRAIN := 24.0
const SPRINT_REGEN := 18.0
const SPRINT_REGEN_DELAY := 0.7
const SPRINT_RESUME_FRAC := 0.25   # must recover past 25% before sprinting again

# mantle
const MANTLE_MIN := 0.45           # ledge height range (waist ~ chest)
const MANTLE_MAX := 1.35
const MANTLE_TIME := 0.45

var cam: Camera3D
var muzzle: Node3D
var view_root: Node3D
var viewmodel: Node3D = null
var vm_gun: Node3D = null          # gun meshes sub-node
var vm_mag: Node3D = null          # magazine + support hand sub-node
var bob_t := 0.0

var sensitivity := 0.0022
var cam_pitch := 0.0               # own the pitch so recoil can layer on top
var ads := false
var ads_base_fov := 75.0
var fire_accum := 0.0
var melee_cd := 0.0
var reload_t := 0.0
var reloading := false
var dead := false
var move_speed := 5.0
var interact_ray: RayCast3D
var shake_amt := 0.0
var spot_light: SpotLight3D = null

# ---- physics recoil springs ----
var recoil_pitch := 0.0            # radians of kick
var recoil_vel_p := 0.0
var recoil_yaw := 0.0
var recoil_vel_y := 0.0
var vm_kick := 0.0                 # viewmodel punch (visual only)
var vm_kick_up := 0.0
const RECOIL_STIFF := 90.0         # spring constant
const RECOIL_DAMP := 11.0

# ---- spread bloom ----
var bloom := 0.0
const BLOOM_PER_SHOT := 0.004
const BLOOM_DECAY := 0.02          # radians/sec recovery
const BLOOM_MAX := 0.05

# ---- stamina state ----
var stamina := STAMINA_MAX
var stamina_locked := false        # true until stamina recovers past threshold
var sprinting := false
var regen_delay := 0.0
var step_t := 0.0

# ---- mantle state ----
var mantling := false
var mantle_from := Vector3.ZERO
var mantle_to := Vector3.ZERO
var mantle_t := 0.0
var mantle_probe: RayCast3D
var mantle_check_up: RayCast3D
var mantle_check_head: RayCast3D

# ---- flinch / animation state ----
var flinch_pitch := 0.0            # hit reaction camera kick
var flinch_vel := 0.0
var vm_flinch := 0.0               # viewmodel dip when hurt
var _recoil_yaw_applied := 0.0
var land_dip := 0.0                # crouch-dip on landing
var was_airborne := false
var vm_anim := "idle"              # idle|shoot|reload|jump|sprint|mantle|melee
var block_fire_until := 0          # msec gate so clicking HUD buttons doesn't shoot
var vm_anim_t := 0.0
var vm_mix := {}                   # per-pose blend weights (smooth transitions)
var jump_hold := 0.0
var shoot_hold := 0.0
# event-driven action queue: a quick click can press+release *between* physics ticks,
# so just_pressed() polled in _physics_process misses it. Queue from _unhandled_input.
var _fire_queued := false
var _interact_queued := false
var _reload_queued := false

# ---- shell casings pool ----
static var shell_mesh: CylinderMesh = null
static var shell_mat: StandardMaterial3D = null
var active_shells := 0
const MAX_SHELLS := 24

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1 | 2 | 4 | 8
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0, 0.875, 0)
	add_child(col)
	cam = Camera3D.new()
	cam.position = EYE
	cam.current = true
	cam.fov = ads_base_fov
	add_child(cam)
	muzzle = Node3D.new()
	muzzle.position = EYE + Vector3(0.14, -0.1, -0.55)
	add_child(muzzle)
	view_root = Node3D.new()
	view_root.position = EYE
	add_child(view_root)
	interact_ray = RayCast3D.new()
	interact_ray.target_position = Vector3(0, 0, -2.6)
	interact_ray.collision_mask = 2 | 8
	interact_ray.position = EYE
	add_child(interact_ray)
	# mantle probes (hidden rays parented to player)
	mantle_probe = RayCast3D.new()
	mantle_probe.collision_mask = 2 | 4
	mantle_probe.target_position = Vector3(0, 0, -0.9)
	add_child(mantle_probe)
	mantle_check_up = RayCast3D.new()
	mantle_check_up.collision_mask = 2 | 4
	mantle_check_up.target_position = Vector3(0, 1.9, 0)
	add_child(mantle_check_up)
	mantle_check_head = RayCast3D.new()
	mantle_check_head.collision_mask = 2 | 4
	mantle_check_head.target_position = Vector3(0, 1.6, 0)
	add_child(mantle_check_head)
	_build_eyes()
	_refresh_viewmodel()
	GameData.state_changed.connect(_on_state_changed)
	GameData.died.connect(_on_died)

var eye_l: MeshInstance3D
var eye_r: MeshInstance3D
func _build_eyes() -> void:
	if GameData.species == "robot":
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.2, 0.2)
		m.emission_enabled = true
		m.emission = Color(1, 0.1, 0.1)
		m.emission_energy_multiplier = 4.0
		for side in [-0.09, 0.09]:
			var e := MeshInstance3D.new()
			var sm := SphereMesh.new(); sm.radius = 0.04; sm.height = 0.08
			e.mesh = sm; e.material_override = m
			e.position = Vector3(side, 1.6, -0.25)
			add_child(e)

func _input(event: InputEvent) -> void:
	if OS.get_environment("RT_DEBUG_INPUT") == "1" and (event is InputEventMouseButton or event is InputEventKey):
		print("INPUTPROBE _input got ", event.get_class(), " dead=", dead, " cap=", GameData.is_captured())
	# _input always sees events even when the GUI eats them; queue fire presses so a
	# quick click can't slip between physics ticks (dropped shots).
	if not dead and GameData.is_captured():
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_fire_queued = true
		elif event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_E: _interact_queued = true
				KEY_R: _reload_queued = true

func _unhandled_input(event: InputEvent) -> void:
	if OS.get_environment("RT_DEBUG_INPUT") == "1":
		if event is InputEventMouseMotion:
			print("INPUTPROBE motion rel=", event.relative, " mode=", Input.get_mouse_mode())
		elif event is InputEventMouseButton:
			print("INPUTPROBE button=", event.button_index, " pressed=", event.pressed, " mode=", Input.get_mouse_mode())
	if dead: return
	if event is InputEventMouseMotion and GameData.is_captured():
		var sens := sensitivity * (0.45 if ads else 1.0)
		rotate_y(-event.relative.x * sens)
		cam_pitch -= event.relative.y * sens
		cam_pitch = clampf(cam_pitch, -1.45, 1.45)
		if OS.get_environment("RT_DEBUG_INPUT") == "1":
			print("INPUTPROBE LOOK yaw=%.3f pitch=%.3f" % [rotation.y, cam_pitch])
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F: _toggle_flashlight()
			KEY_1: GameData.set_active_slot("gun")
			KEY_2: GameData.set_active_slot("melee")
			KEY_3:
				for e in GameData.inventory:
					if ItemDB.get_def(e["id"])["type"] == "hat":
						GameData.equip(e["id"])
						break
			KEY_4:
				for e in GameData.inventory:
					if ItemDB.get_def(e["id"])["type"] == "armor":
						GameData.equip(e["id"])
						break

func _physics_process(delta: float) -> void:
	if dead:
		return
	GameData.survival_tick(delta)
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var d := GameData.derived()
	move_speed = d.move_speed
	var basis := global_transform.basis
	var wish := (basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# ---------- sprint / stamina ----------
	var want_sprint := Input.is_action_pressed("sprint") and wish.length() > 0.1 \
		and not ads and not mantling and not reloading \
		and not stamina_locked and stamina > 0.0
	if want_sprint:
		sprinting = true
		stamina = maxf(0.0, stamina - SPRINT_DRAIN * delta)
		regen_delay = SPRINT_REGEN_DELAY
		if stamina <= 0.0:
			stamina_locked = true
			sprinting = false
	else:
		sprinting = false
		regen_delay = maxf(0.0, regen_delay - delta)
		if regen_delay <= 0.0:
			stamina = minf(STAMINA_MAX, stamina + SPRINT_REGEN * delta)
	if stamina_locked and stamina > STAMINA_MAX * SPRINT_RESUME_FRAC:
		stamina_locked = false
	stamina_changed.emit(stamina, STAMINA_MAX, sprinting)

	var speed_mul := 1.0
	if sprinting: speed_mul = 1.55
	elif ads: speed_mul = 0.55
	var target := wish * move_speed * speed_mul
	var accel := 12.0 if is_on_floor() else 4.0
	if mantling: accel = 2.0
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0, 1))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0, 1))

	# ---------- mantling ----------
	if mantling:
		_physics_mantle(delta)
	elif is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
			jump_hold = 0.45
		elif wish.length() > 0.5 and _try_mantle(wish):
			pass
	else:
		velocity.y -= GRAVITY * delta
		# vaulting off a low ledge while moving: small hop assist
		if Input.is_action_just_pressed("jump") and velocity.y > -4.0:
			_try_air_mantle(wish)

	move_and_slide()

	# landing dip detection
	var airborne_now := not is_on_floor()
	if was_airborne and not airborne_now:
		land_dip = clampf(absf(_last_fall_speed) / 12.0, 0.2, 1.0)
		SFX.play("land", -12.0, randf_range(0.9, 1.1))
	was_airborne = airborne_now
	if velocity.y < 0.0:
		_last_fall_speed = velocity.y
	land_dip = lerpf(land_dip, 0.0, clampf(delta * 7.0, 0, 1))

	# footsteps while walking/sprinting
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 1.0 and not mantling:
		step_t += delta * hspeed * (0.85 if sprinting else 0.62)
		if step_t >= 1.0:
			step_t -= 1.0
			SFX.play("step", -16.0, randf_range(0.9, 1.15) * (1.1 if sprinting else 1.0))

	# view bob (harder while sprinting)
	if is_on_floor() and hspeed > 0.5 and not mantling:
		var bob_amp := 2.1 if sprinting else 1.6
		var amp_y := 0.03 if sprinting else 0.02
		var amp_x := 0.022 if sprinting else 0.015
		bob_t += delta * hspeed * bob_amp
		view_root.position = EYE + Vector3(sin(bob_t) * amp_x, sin(bob_t * 2.0) * amp_y - land_dip * 0.12, 0)
	else:
		view_root.position = view_root.position.lerp(EYE + Vector3(0, -land_dip * 0.12, 0), 10.0 * delta)

	# weapon logic
	fire_accum -= delta
	melee_cd -= delta
	_update_ads()
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
	_refresh_viewmodel_if_needed()

	# recoil spring integration (physics of the gun)
	var accel_p := -RECOIL_STIFF * recoil_pitch - RECOIL_DAMP * recoil_vel_p
	recoil_vel_p += accel_p * delta
	recoil_pitch += recoil_vel_p * delta
	var accel_y := -RECOIL_STIFF * recoil_yaw - RECOIL_DAMP * recoil_vel_y
	recoil_vel_y += accel_y * delta
	recoil_yaw += recoil_vel_y * delta
	# flinch spring
	var fa := -70.0 * flinch_pitch - 9.0 * flinch_vel
	flinch_vel += fa * delta
	flinch_pitch += flinch_vel * delta
	vm_kick = lerpf(vm_kick, 0.0, clampf(12.0 * delta, 0, 1))
	vm_kick_up = lerpf(vm_kick_up, 0.0, clampf(9.0 * delta, 0, 1))
	vm_flinch = lerpf(vm_flinch, 0.0, clampf(6.0 * delta, 0, 1))
	jump_hold = maxf(0.0, jump_hold - delta)
	shoot_hold = maxf(0.0, shoot_hold - delta)

	# spread bloom recovery
	bloom = maxf(0.0, bloom - BLOOM_DECAY * delta)
	crosshair_spread_changed.emit(bloom)

	# camera = mouse pitch + recoil + flinch
	cam.rotation.x = cam_pitch + recoil_pitch + flinch_pitch
	# apply yaw recoil as a delta so it doesn't accumulate per-frame
	rotate_y((recoil_yaw - _recoil_yaw_applied) * 0.35)
	_recoil_yaw_applied = recoil_yaw

	# animation state machine (blended)
	_update_vm_state()
	_update_viewmodel(delta)

	if GameData.is_captured():
		if OS.get_environment("RT_DEBUG_INPUT") == "1" and _fire_queued:
			print("INPUTPROBE phys: queued slot=%s gun=%s acc=%.2f" % [GameData.active_slot, GameData.equipped.gun, fire_accum])
		if Time.get_ticks_msec() < block_fire_until:
			_fire_queued = false
			return
		var slot := GameData.active_slot
		if slot == "gun" and GameData.equipped.gun != "":
			var gdef := ItemDB.get_def(GameData.equipped.gun)
			if gdef.get("auto", false) and Input.is_action_pressed("fire"):
				_shoot()
			elif _fire_queued and fire_accum <= 0.0:
				_fire_queued = false
				_shoot()
		elif slot == "melee" and _fire_queued and melee_cd <= 0.0:
			_fire_queued = false
			_melee()
		if (_reload_queued or Input.is_action_just_pressed("reload")) and not reloading:
			_reload_queued = false
			_start_reload()
		if _interact_queued:
			_interact_queued = false
			_try_interact()
	else:
		_fire_queued = false
		_interact_queued = false

var _last_fall_speed := 0.0

# ---------- mantling ----------
var _dbg_gate := ""
func _probe_mantle(wish: Vector3) -> bool:
	# fires mantle if blocked ahead by a ledge in waist range with clearance on top
	if wish.length() < 0.3:
		_dbg_gate = "nowish"
		return false
	var dir := wish.normalized()
	mantle_probe.global_position = global_position + Vector3(dir.x * 0.25, 0.62, dir.z * 0.25)
	mantle_probe.target_position = dir * 0.6
	mantle_probe.force_raycast_update()
	if not mantle_probe.is_colliding():
		_dbg_gate = "nobody"
		return false
	var wall_hit := mantle_probe.get_collision_point()
	var wall_normal := mantle_probe.get_collision_normal()
	if wall_normal.y > 0.4:   # walked into a floor, not a wall
		_dbg_gate = "floorhit n=%.2f" % wall_normal.y
		return false
	# is the wall top between waist and chest? cast up from just inside the wall face
	var up_from := wall_hit + dir * 0.12 + Vector3(0, 0.05, 0)
	mantle_check_up.global_position = up_from
	mantle_check_up.force_raycast_update()
	if not mantle_check_up.is_colliding():
		_dbg_gate = "noup"
		return false   # nothing to grab (bottomless fence) — no mantle
	var ledge_y := mantle_check_up.get_collision_point().y
	var ledge_h := ledge_y - global_position.y
	if ledge_h < MANTLE_MIN or ledge_h > MANTLE_MAX:
		_dbg_gate = "height %.2f" % ledge_h
		return false
	# clearance above ledge (headroom)
	mantle_check_head.global_position = Vector3(up_from.x, ledge_y + 0.05, up_from.z)
	mantle_check_head.force_raycast_update()
	if mantle_check_head.is_colliding():
		return false
	# target: stand spot on the ledge
	mantle_to = Vector3(wall_hit.x + dir.x * 0.5, ledge_y + 0.05, wall_hit.z + dir.z * 0.5)
	var feet_check := PhysicsRayQueryParameters3D.create(mantle_to + Vector3(0, 0.3, 0), mantle_to + Vector3(0, -1.2, 0), 1 | 2)
	feet_check.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(feet_check).is_empty():
		return false   # no floor on the other side
	mantle_to.y = mantle_check_up.get_collision_point().y + 0.02
	return true

func _try_mantle(wish: Vector3) -> bool:
	if mantling or not is_on_floor():
		return false
	# only when actually pressed against something
	var dir := wish.normalized()
	var blocked := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position + Vector3(0, 0.6, 0) + dir * 0.55, 2 | 4)
	blocked.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(blocked).is_empty():
		return false
	if not _probe_mantle(wish):
		return false
	_begin_mantle()
	return true

func _try_air_mantle(wish: Vector3) -> bool:
	# while jumping onto a waist-high obstacle, snap the mantle so you clear it "with ease"
	if wish.length() < 0.3:
		return false
	if not _probe_mantle(wish):
		return false
	_begin_mantle()
	return true

func _begin_mantle() -> void:
	mantling = true
	mantle_t = 0.0
	mantle_from = global_position
	velocity = Vector3.ZERO
	jump_hold = MANTLE_TIME
	SFX.play("mantle", -10.0)

func _physics_mantle(delta: float) -> void:
	mantle_t += delta
	var t := clampf(mantle_t / MANTLE_TIME, 0.0, 1.0)
	# arc: rise then glide forward (ease-in-out)
	var e := t * t * (3.0 - 2.0 * t)
	var mid_boost := sin(t * PI) * 0.35
	var p := mantle_from.lerp(mantle_to, e)
	p.y += mid_boost
	global_position = p
	velocity = Vector3(0, cos(t * PI) * 0.5, 0)
	if t >= 1.0:
		mantling = false
		velocity = Vector3.ZERO

func _update_vm_state() -> void:
	var st := "idle"
	if mantling: st = "mantle"
	elif reloading: st = "reload"
	elif jump_hold > 0.0 or not is_on_floor(): st = "jump"
	elif shoot_hold > 0.0: st = "shoot"
	elif sprinting: st = "sprint"
	elif vm_anim != "idle" and vm_anim_t > 0.0:
		st = vm_anim   # linger briefly on one-shot states
	if st != vm_anim:
		vm_anim = st
		vm_anim_t = 0.55 if st in ["shoot", "melee"] else 0.0
	else:
		vm_anim_t = maxf(0.0, vm_anim_t - get_physics_process_delta_time())
	# smooth per-pose blend weights
	for pose in ["idle", "shoot", "reload", "jump", "sprint", "mantle", "melee", "ads"]:
		var want := 1.0 if vm_anim == pose else 0.0
		if pose == "ads": want = 1.0 if ads else 0.0
		if pose == "idle": want = 1.0 if vm_anim in ["idle", "ads"] else 0.0
		var cur: float = vm_mix.get(pose, 0.0)
		vm_mix[pose] = lerpf(cur, want, clampf(9.0 * get_physics_process_delta_time(), 0, 1))

func _process(delta: float) -> void:
	if view_root == null: return
	if shake_amt > 0.01:
		view_root.rotation.z = randf_range(-0.012, 0.012) * shake_amt
		shake_amt = lerpf(shake_amt, 0.0, clampf(delta * 10.0, 0, 1))
	else:
		view_root.rotation.z = lerpf(view_root.rotation.z, 0.0, delta * 8.0)

func shake(a: float) -> void:
	shake_amt = minf(shake_amt + a, 3.0)

# ---------- viewmodel pose (the juice: blended poses) ----------
func _update_viewmodel(delta: float) -> void:
	if viewmodel == null: return
	var w_idle: float = vm_mix.get("idle", 1.0)
	var w_shoot: float = vm_mix.get("shoot", 0.0)
	var w_reload: float = vm_mix.get("reload", 0.0)
	var w_jump: float = vm_mix.get("jump", 0.0)
	var w_sprint: float = vm_mix.get("sprint", 0.0)
	var w_mantle: float = vm_mix.get("mantle", 0.0)
	var w_ads: float = vm_mix.get("ads", 0.0)
	var w_melee: float = vm_mix.get("melee", 0.0)

	var hip := Vector3(0.16, -0.14, -0.32)
	var ads_pos := Vector3(0, -0.08, -0.26)
	var sprint_pos := Vector3(0.24, -0.19, -0.26)
	var reload_pos := Vector3(0.05, -0.2, -0.3)
	var mantle_pos := Vector3(-0.1, 0.02, -0.18)
	var jump_pos := Vector3(0.14, -0.12, -0.3)
	var pos := hip * w_idle
	pos += ads_pos * w_ads
	pos += sprint_pos * w_sprint
	pos += reload_pos * w_reload
	pos += mantle_pos * w_mantle
	pos += jump_pos * w_jump
	pos += hip * w_melee
	pos *= 1.0 / maxf(0.001, w_idle + w_ads + w_sprint + w_reload + w_mantle + w_jump + w_melee)
	# recoil punch pushes gun back/up
	pos += Vector3(0, vm_kick_up * 0.05 - vm_flinch * 0.1, vm_kick * 0.12)
	viewmodel.position = pos

	var rot := Vector3.ZERO
	rot.x += -vm_kick * 0.55                    # muzzle flip from physics kick
	rot.x += w_reload * 0.5                     # tilt up while reloading
	rot.x += w_mantle * 0.9                     # arms up while climbing
	rot.x += w_jump * 0.25
	rot.z += w_sprint * 0.35                    # tuck to the side sprinting
	rot.z += w_reload * -0.25
	rot.y += w_reload * 0.4
	rot.y += w_sprint * -0.3
	rot.x += vm_flinch * 0.5                    # flinch: gun drops
	viewmodel.rotation = rot

	# reload sub-animation: magazine + support hand drop and return
	if vm_mag != null:
		var mp := Vector3.ZERO
		if w_reload > 0.05:
			# reload_t drives phase: 1.1-1.8s total; pull mag out ~0.3s, in ~0.3s
			var total := 1.8 if GameData.equipped.gun == "rifle" else 1.1
			var elapsed := clampf(total - reload_t, 0.0, total)
			var phase := 0.0
			if elapsed < 0.3:
				phase = elapsed / 0.3               # dropping mag
			elif elapsed < total - 0.35:
				phase = 1.0                          # mag away
			else:
				phase = maxf(0.0, (total - elapsed) / 0.35)  # mag coming back
			mp = Vector3(0, -0.16 * phase, -0.02 * phase)
			mp *= w_reload
		vm_mag.position = vm_mag.position.lerp(mp, clampf(12.0 * delta, 0, 1))

func _update_ads() -> void:
	var want_ads: bool = Input.is_action_pressed("ads") and GameData.active_slot == "gun" and GameData.equipped.gun != ""
	ads = want_ads
	var want_fov := ads_base_fov
	if ads: want_fov = 42.0
	elif sprinting: want_fov = ads_base_fov + 8.0
	if want_fov < cam.fov:
		cam.fov = lerpf(cam.fov, want_fov, 0.18)
	else:
		cam.fov = lerpf(cam.fov, want_fov, 0.14)

var current_vm_id := "__none__"
func _refresh_viewmodel_if_needed() -> void:
	var want := "__none__"
	var slot := GameData.active_slot
	if slot == "gun" and GameData.equipped.gun != "": want = GameData.equipped.gun
	elif slot == "melee": want = GameData.equipped.melee if GameData.equipped.melee != "" else "fists"
	if want != current_vm_id:
		_refresh_viewmodel()

func _refresh_viewmodel() -> void:
	var want := "__none__"
	var slot := GameData.active_slot
	if slot == "gun" and GameData.equipped.gun != "": want = GameData.equipped.gun
	elif slot == "melee": want = GameData.equipped.melee if GameData.equipped.melee != "" else "fists"
	if want == current_vm_id and viewmodel != null:
		return
	current_vm_id = want
	if viewmodel:
		viewmodel.queue_free()
	viewmodel = ItemDB.build_viewmodel(want)
	# grab animated sub-groups created by ItemDB
	vm_gun = viewmodel.get_node_or_null("GunNode")
	vm_mag = viewmodel.get_node_or_null("MagNode")
	view_root.add_child(viewmodel)

func _on_state_changed() -> void:
	_refresh_viewmodel_if_needed()

func _on_died() -> void:
	dead = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func take_damage(amount: float, source := "creature") -> void:
	var before := GameData.hp
	GameData.take_damage(amount, source)
	var dealt := before - GameData.hp
	shake(0.5 + clampf(dealt / 20.0, 0.0, 1.0))
	# flinch: violent camera snap + gun drop — you FEEL the hit
	flinch_vel += randf_range(0.8, 1.6) * minf(1.6, dealt / 12.0)
	flinch_vel -= randf_range(0.0, 0.6)
	recoil_vel_p += randf_range(0.3, 0.9)
	recoil_vel_y += randf_range(-0.5, 0.5)
	vm_flinch = clampf(0.6 + dealt / 25.0, 0.0, 1.4)

func revive_at(pos: Vector3) -> void:
	dead = false
	global_position = pos
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	cam_pitch = 0.0
	cam.rotation = Vector3.ZERO
	recoil_pitch = 0.0
	recoil_yaw = 0.0
	_recoil_yaw_applied = 0.0
	recoil_vel_p = 0.0
	recoil_vel_y = 0.0
	bloom = 0.0
	stamina = STAMINA_MAX
	stamina_locked = false
	GameData.loaded_ammo = {}
	_refresh_viewmodel()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---------- shooting ----------
func _shoot() -> void:
	var gid: String = GameData.equipped.gun
	if gid == "": return
	var gdef := ItemDB.get_def(gid)
	if reloading: return
	var loaded := int(GameData.loaded_ammo.get(gid, 0))
	if loaded <= 0:
		SFX.play("click", -6.0)
		fire_accum = 0.25
		_start_reload()
		return
	if fire_accum > 0.0: return
	fire_accum = 1.0 / maxf(0.5, float(gdef.rate))
	GameData.loaded_ammo[gid] = loaded - 1
	GameData.state_changed.emit()
	ammo_changed.emit(loaded - 1, GameData.reserve_ammo(gdef.ammo_id))
	# ---- gun physics: recoil kicks the camera like a spring ----
	var kick_scale := float(gdef.dmg) / 12.0
	var ads_mul := 0.6 if ads else 1.0
	if sprinting: ads_mul = 1.25
	recoil_vel_p += randf_range(1.2, 1.9) * kick_scale * ads_mul
	recoil_vel_y += randf_range(-0.7, 0.7) * kick_scale * ads_mul
	vm_kick = minf(vm_kick + 0.8 * ads_mul, 1.6)
	vm_kick_up = minf(vm_kick_up + 0.5, 1.2)
	# spread bloom accumulates and recovers
	bloom = minf(bloom + BLOOM_PER_SHOT * (1.4 if not is_on_floor() else 1.0), BLOOM_MAX)
	var base_spread := float(gdef.spread)
	var move_pen := Vector2(velocity.x, velocity.z).length() * 0.0012
	var spread := base_spread + move_pen + bloom + (0.0 if ads else 0.006)
	shoot_hold = 0.14
	_shoot_ray(cam, float(gdef.dmg) * GameData.derived().dmg_mul, gid, float(gdef.range), spread)
	match gid:
		"pistol": SFX.play("shot_pistol", -4.0, randf_range(0.95, 1.05))
		"smg": SFX.play("shot_smg", -4.0, randf_range(0.95, 1.05))
		"rifle": SFX.play("shot_rifle", -2.0, randf_range(0.95, 1.05))
		"laser": SFX.play("shot_laser", -4.0, randf_range(0.95, 1.05))
	_spawn_muzzle_fx(gid)
	if gid != "laser":
		_eject_shell()
	shake(0.5 if gid == "rifle" else 0.25)
	shot_fired.emit()

func _shoot_ray(camera: Camera3D, dmg: float, weapon_id: String, max_range: float, spread: float) -> void:
	var from := camera.global_position
	var fwd := -camera.global_transform.basis.z
	fwd = Vector3(fwd.x + randf_range(-spread, spread), fwd.y + randf_range(-spread, spread), fwd.z + randf_range(-spread, spread)).normalized()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * max_range, 2 | 4 | 8)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var end := from + fwd * max_range
	if not hit.is_empty():
		end = hit.position
		var col: Node = hit["collider"]
		if col.has_method("take_damage"):
			var crit: bool = randf() < GameData.derived().crit
			var final := dmg * (2.0 if crit else 1.0)
			col.take_damage(final, weapon_id)
			hit_registered.emit(final, col)
			if crit:
				GameData.game_message("CRIT! %.0f damage" % final, Color(1, 0.5, 0.2))
			# small self-recoil impulse on hit
			recoil_vel_p -= 0.15
		_decal_at(end, fwd, weapon_id)
		_impact_fx(end, fwd, weapon_id)
	_tracer(from + fwd * 0.4, end, weapon_id == "laser")

# ---------- shell casings: real physics props ----------
func _eject_shell() -> void:
	if active_shells >= MAX_SHELLS:
		return
	if OS.get_environment("RT_NO_PARTICLES") == "1":
		return
	if shell_mesh == null:
		shell_mesh = CylinderMesh.new()
		shell_mesh.top_radius = 0.011
		shell_mesh.bottom_radius = 0.011
		shell_mesh.height = 0.035
		shell_mesh.radial_segments = 6
		shell_mesh.rings = 1
		shell_mat = StandardMaterial3D.new()
		shell_mat.albedo_color = Color(0.78, 0.62, 0.22)
		shell_mat.metallic = 0.9
		shell_mat.roughness = 0.3
	active_shells += 1
	var rb := RigidBody3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = shell_mesh
	mi.rotation.z = PI / 2.0
	rb.add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.018
	cs.shape = sh
	rb.add_child(cs)
	rb.collision_layer = 16   # dedicated layer: collides with world, ignored by rays/player
	rb.collision_mask = 1 | 2
	rb.contact_monitor = true
	rb.max_contacts_reported = 1
	rb.mass = 0.02
	rb.body_entered.connect(func(_who):
		if is_instance_valid(rb) and not rb.is_settled():
			SFX.play("shell", -14.0, randf_range(0.9, 1.3)))
	var world := get_tree().get_first_node_in_group("world_root")
	if world == null:
		active_shells -= 1
		return
	world.add_child(rb)   # world space so the moving player doesn't drag the casing
	rb.global_transform = Transform3D(Basis(), muzzle.global_position + Vector3(0.02, 0.02, 0))
	var right := global_transform.basis.x
	var up := Vector3.UP
	rb.linear_velocity = (velocity * 0.4) + right * randf_range(1.2, 2.2) + up * randf_range(1.6, 2.8)
	rb.angular_velocity = Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	get_tree().create_timer(4.0).timeout.connect(func():
		active_shells -= 1
		if is_instance_valid(rb): rb.queue_free())

func _spawn_muzzle_fx(weapon_id: String) -> void:
	for c in muzzle.get_children():
		c.queue_free()
	var light := OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.5) if weapon_id == "laser" else Color(1.0, 0.8, 0.4)
	light.omni_range = 5.0
	light.light_energy = 3.0
	muzzle.add_child(light)
	var spark := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.05; sm.height = 0.1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.9, 0.5)
	m.emission_enabled = true
	m.emission = Color(1, 0.8, 0.3)
	m.emission_energy_multiplier = 6.0
	spark.mesh = sm
	spark.material_override = m
	muzzle.add_child(spark)
	var t := create_tween()
	t.tween_property(light, "light_energy", 0.0, 0.07)
	t.parallel().tween_property(spark, "scale", Vector3(1.8, 1.8, 1.8), 0.06)
	t.tween_callback(func(): light.queue_free(); spark.queue_free())

# ---------- combat juice ----------
func _tracer(from: Vector3, to: Vector3, green := false) -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world == null: return
	var mi := MeshInstance3D.new()
	var pm := QuadMesh.new()
	pm.size = Vector2(0.02, maxf(0.5, from.distance_to(to)))
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_color = Color(0.4, 1.0, 0.5, 0.85) if green else Color(1.0, 0.9, 0.55, 0.85)
	m.emission_enabled = true
	m.emission = Color(0.3, 1.0, 0.4) if green else Color(1, 0.85, 0.4)
	m.emission_energy_multiplier = 2.2
	mi.material_override = m
	world.add_child(mi)
	var mid := (from + to) * 0.5
	mi.global_position = mid
	mi.look_at_from_position(mid, to, Vector3.UP)
	mi.rotate_object_local(Vector3.UP, PI / 2.0)
	var t := create_tween()
	t.tween_property(m, "albedo_color:a", 0.0, 0.06)
	t.tween_callback(mi.queue_free)

func _impact_fx(pos: Vector3, dir: Vector3, weapon_id: String) -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world == null: return
	if OS.get_environment("RT_NO_PARTICLES") != "1":
		var is_laser := weapon_id == "laser"
		var p := GPUParticles3D.new()
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pmat.emission_sphere_radius = 0.05
		pmat.direction = -dir
		pmat.spread = 60.0
		pmat.gravity = Vector3(0, -9.8, 0)
		pmat.initial_velocity_min = 1.5
		pmat.initial_velocity_max = 3.5
		pmat.scale_min = 0.02
		pmat.scale_max = 0.05
		pmat.color = Color(0.3, 1.0, 0.4) if is_laser else Color(1.0, 0.7, 0.3)
		p.process_material = pmat
		p.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(1, 0.85, 0.5, 1)))
		p.amount = 10
		p.lifetime = 0.4
		p.one_shot = true
		p.explosiveness = 1.0
		world.add_child(p)
		p.global_position = pos
		p.emitting = true
		var t := create_tween()
		t.tween_interval(0.6)
		t.tween_callback(p.queue_free)
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.4) if weapon_id == "laser" else Color(1.0, 0.75, 0.35)
	light.omni_range = 2.0
	light.light_energy = 1.2
	world.add_child(light)
	light.global_position = pos + dir * -0.05
	var lt := create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.08)
	lt.tween_callback(light.queue_free)

func _toggle_flashlight() -> void:
	if spot_light == null:
		spot_light = SpotLight3D.new()
		spot_light.light_color = Color(1.0, 0.95, 0.8)
		spot_light.light_energy = 1.6
		spot_light.spot_range = 22.0
		spot_light.spot_angle = 32.0
		spot_light.spot_attenuation = 1.4
		spot_light.position = Vector3(0.1, -0.05, 0)
		cam.add_child(spot_light)
	spot_light.visible = not spot_light.visible
	SFX.play("click", -8.0, 1.4 if spot_light.visible else 0.8)

# ---------- decal ----------
func _decal_at(pos: Vector3, dir: Vector3, weapon_id: String) -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world == null: return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.09, 0.08)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	world.add_child(mi)
	mi.global_position = pos + dir.normalized() * -0.01
	mi.look_at(mi.global_position - dir)
	var t := create_tween()
	t.tween_interval(8.0)
	t.tween_callback(mi.queue_free)

# ---------- melee ----------
func _melee() -> void:
	var mid: String = GameData.equipped.melee
	if mid == "": mid = "fists"
	var mdef := ItemDB.get_def(mid)
	melee_cd = 1.0 / maxf(0.5, float(mdef.rate))
	vm_anim = "melee"
	vm_anim_t = 0.4
	vm_kick = 1.0
	SFX.play("swing", -8.0, randf_range(0.9, 1.1))
	melee_swing.emit()
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * float(mdef.reach), 4)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col: Node = hit["collider"]
		if col.has_method("take_damage"):
			var crit: bool = randf() < GameData.derived().crit * 1.2
			var dmg: float = float(mdef.dmg) * GameData.derived().dmg_mul * (2.5 if crit else 1.0)
			col.take_damage(dmg, mid)
			hit_registered.emit(dmg, col)
			if crit:
				GameData.game_message("CRITICAL MELEE! %.0f" % dmg, Color(1, 0.5, 0.2))
			SFX.play("hit_meat", -4.0, randf_range(0.8, 1.0))
			shake(0.4)
			recoil_vel_p += 0.5

# ---------- reload ----------
func _start_reload() -> void:
	var gid: String = GameData.equipped.gun
	if gid == "": return
	var gdef := ItemDB.get_def(gid)
	var mag := int(gdef.mag)
	var loaded := int(GameData.loaded_ammo.get(gid, 0))
	if loaded >= mag: return
	var reserve := GameData.reserve_ammo(gdef.ammo_id)
	if reserve <= 0:
		GameData.game_message("Out of %s! Search crates, lockers and ammo caches." % ItemDB.item_name(gdef.ammo_id), Color(1, 0.4, 0.3))
		SFX.play("click", -6.0)
		return
	reloading = true
	reload_t = 1.1 if gid != "rifle" else 1.8
	reload_started.emit()
	SFX.play("mag_out", -8.0)
	# schedule the mag-in click mid-animation
	var half := maxf(0.2, reload_t * 0.55)
	var tree := get_tree()
	await tree.create_timer(half).timeout
	if reloading and is_inside_tree():
		SFX.play("mag_in", -8.0)

func _finish_reload() -> void:
	reloading = false
	var gid: String = GameData.equipped.gun
	if gid == "": return
	var gdef := ItemDB.get_def(gid)
	var mag := int(gdef.mag)
	var loaded := int(GameData.loaded_ammo.get(gid, 0))
	var need := mag - loaded
	var got := GameData.take_reserve(gdef.ammo_id, need)
	GameData.loaded_ammo[gid] = loaded + got
	GameData.state_changed.emit()
	ammo_changed.emit(loaded + got, GameData.reserve_ammo(gdef.ammo_id))
	SFX.play("click", -4.0, 0.8)

# ---------- interaction ----------
func _try_interact() -> void:
	if is_instance_valid(interact_ray) and interact_ray.is_colliding():
		var c := interact_ray.get_collider()
		if c and c.has_method("interact"):
			c.interact(self)
			return
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), global_position + Vector3(0, 0.8, 0))
	q.collision_mask = 8
	for h in space.intersect_shape(q, 6):
		var col: Object = h.collider
		if col and col.has_method("try_pickup"):
			if col.try_pickup():
				return
	GameData.game_message("Nothing to take here.", Color(0.7, 0.7, 0.7))
