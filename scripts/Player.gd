extends CharacterBody3D
# First-person survivor. CoD-style movement (sprint, slide, slide-jump, mantle), a
# weapon state machine with per-gun handling (ADS time, recoil pattern, bloom,
# tactical/empty reloads, swap times, sprint-to-fire), quick melee, throwables,
# healing, fishing, controller look curves + aim assist, and the camera juice.

class_name Player

signal weapon_fired
signal hit_confirmed(info: Dictionary)

const GRAVITY := 22.0
const JUMP_V := 7.2
const EYE_STAND := 1.62
const EYE_CROUCH := 1.08
const EYE_SLIDE := 0.86
const VIEW_SCALE := 0.35          # whole view rig scaled toward the eye: no wall clipping
const SPRINT_MUL := 1.58
const CROUCH_MUL := 0.52
const STAMINA_MAX := 100.0
const PAD_HOLD := 0.28

var world: Node = null
var cam_pivot: Node3D
var cam: Camera3D
var view_root: Node3D
var flashlight: SpotLight3D
var capsule: CapsuleShape3D
var col_shape: CollisionShape3D

# ---- movement ----
var stance := "stand"             # stand | crouch | slide
var sprinting := false
var sprint_latch := false
var slide_t := 0.0
var slide_cd := 0.0
var stamina := STAMINA_MAX
var stamina_delay := 0.0
var eye_h := EYE_STAND
var coyote := 0.0
var jump_buffer := 0.0
var fall_speed := 0.0
var was_air := false
var mantling := false
var mantle_from := Vector3.ZERO
var mantle_to := Vector3.ZERO
var mantle_t := 0.0
var mantle_dur := 0.4
var step_t := 0.0
var kill_rush_t := 0.0
var in_vehicle: Node = null
var dead := false
var wet := false
var _autosave_t := 60.0

# ---- look ----
var pitch := 0.0
var look_delta := Vector2.ZERO
var stick_accel := 0.0
var aim_assist := AimAssist.new()
var _ads_prev := false

# ---- weapons ----
var winst := {}
var wstats := {}
var vm: Node3D = null
var vm_key := ""
var vm_mode := "gun"              # gun | melee | item
var act := "ready"                # ready | swap_out | swap_in | reload | melee | throw | use | fish
var act_t := 0.0
var act_dur := 0.0
var act_data := {}
var fire_cd := 0.0
var bloom := 0.0
var ads_t := 0.0
var sprint_blend := 0.0
var shot_index := 0
var choir_heat := 0.0
var _fire_queue_t := 0.0
var _trigger_prev := false
var _auto_reload := false
var _padx_t := -1.0
var interact_target: Object = null
var interact_text := ""
var fish_spot := Vector3.INF
var _flash_mesh: MeshInstance3D = null

# ---- camera juice ----
var recoil := Vector2.ZERO        # spring-recovering aim offset (pitch, yaw), radians
var trauma := 0.0
var shake_t := 0.0
var fov_punch := 0.0
var flinch := Vector3.ZERO
var flinch_v := Vector3.ZERO
var land_dip := 0.0
var cam_roll := 0.0
var bob_t := 0.0
var bob_amt := 0.0
var vm_kick := 0.0
var vm_rise := 0.0
var vm_roll := 0.0
var vm_sway := Vector2.ZERO
var vm_cycle := 0.0               # slide / pump / bolt travel 0..1
var base_fov := 80.0
var _debug_autofire := OS.get_environment("RT_DEBUG_AUTOFIRE") == "1"

func _ready() -> void:
	add_to_group("player")
	collision_layer = 64
	collision_mask = 1 | 2 | 4 | 32
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	col_shape = CollisionShape3D.new()
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.78
	col_shape.shape = capsule
	col_shape.position.y = 0.89
	add_child(col_shape)
	cam_pivot = Node3D.new()
	cam_pivot.position.y = EYE_STAND
	add_child(cam_pivot)
	cam = Camera3D.new()
	cam.near = 0.02
	cam.far = 700.0
	cam.current = true
	cam_pivot.add_child(cam)
	view_root = Node3D.new()
	view_root.scale = Vector3.ONE * VIEW_SCALE
	cam.add_child(view_root)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.light_energy = 3.2
	flashlight.spot_range = 34.0
	flashlight.spot_angle = 30.0
	flashlight.spot_attenuation = 1.1
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.18, -0.12, 0.0)
	flashlight.visible = false
	cam.add_child(flashlight)
	world = get_tree().get_first_node_in_group("world_root")
	GameData.damage_taken.connect(_on_damage)
	GameData.died.connect(_on_died)
	GameData.form_changed.connect(func(_f): _equip_active(true))
	GameData.inventory_changed.connect(_on_inventory_changed)
	apply_settings()
	_equip_active(true)

func apply_settings() -> void:
	base_fov = float(UITheme.settings.get("fov", 80.0))

# ================= input =================
func _input(event: InputEvent) -> void:
	if dead or in_vehicle != null or not GameData.is_captured():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire_queue_t = 0.16
	elif event is InputEventMouseMotion:
		var sens := 0.0022 * float(UITheme.settings.get("mouse_sens", 1.0))
		sens *= lerpf(1.0, float(UITheme.settings.get("ads_mul", 0.85)) / _zoom(1.0), ads_t)
		var rel: Vector2 = event.relative
		if UITheme.settings.get("invert_y", false):
			rel.y = -rel.y
		_add_look(-rel.x * sens, -rel.y * sens)
		look_delta += rel * 0.0025

func _unhandled_input(event: InputEvent) -> void:
	if dead or in_vehicle != null or not GameData.is_captured():
		return
	if event.is_action_pressed("jump"):
		jump_buffer = 0.15
	elif event.is_action_pressed("crouch"):
		_press_crouch()
	elif event.is_action_pressed("reload"):
		_try_reload()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_try_interact()
	elif event.is_action_pressed("pad_x"):
		_padx_t = 0.0
	elif event.is_action_released("pad_x"):
		if _padx_t >= 0.0 and _padx_t < PAD_HOLD:
			if act == "fish":
				_try_interact()
			else:
				_try_reload()
		_padx_t = -1.0
	elif event.is_action_pressed("melee"):
		_start_melee()
	elif event.is_action_pressed("swap") or event.is_action_pressed("next_weapon") or event.is_action_pressed("prev_weapon"):
		_swap_to("secondary" if GameData.active_slot == "primary" else "primary")
	elif event.is_action_pressed("slot_1"):
		_swap_to("primary")
	elif event.is_action_pressed("slot_2"):
		_swap_to("secondary")
	elif event.is_action_pressed("throw"):
		_start_throw()
	elif event.is_action_pressed("heal"):
		_start_heal()
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("cycle_throwable"):
		cycle_throwable()
	elif event.is_action_pressed("sprint") and event is InputEventJoypadButton:
		sprint_latch = not sprint_latch

func _add_look(yaw_d: float, pitch_d: float) -> void:
	rotate_y(yaw_d)
	pitch = clampf(pitch + pitch_d, -1.5, 1.5)

func _zoom(def := 1.0) -> float:
	if vm_mode != "gun" or wstats.is_empty():
		return def
	return float(wstats.get("ads_zoom", def))

# ================= main loop =================
func _physics_process(delta: float) -> void:
	if dead:
		return
	GameData.player_pos = global_position
	GameData.player_yaw = rotation.y
	var env: Dictionary = world.env_at(global_position) if world != null and world.has_method("env_at") else {}
	env["sprinting"] = sprinting
	wet = bool(env.get("wet", false))
	GameData.survival_tick(delta, env)
	if dead or not GameData.alive:
		return
	_autosave_t -= delta
	if _autosave_t <= 0.0:
		_autosave_t = 60.0
		if world != null and world.has_method("save_vehicles"):
			world.save_vehicles()
		GameData.autosave()
	if in_vehicle != null:
		return
	_move(delta)
	_weapons(delta)
	_interact_scan(delta)
	kill_rush_t = maxf(0.0, kill_rush_t - delta)

func _process(delta: float) -> void:
	if dead or in_vehicle != null:
		return
	if GameData.is_captured():
		_stick_look(delta)
	_camera(delta)
	_update_viewmodel(delta)

# ================= movement =================
func _press_crouch() -> void:
	if mantling:
		return
	if stance == "slide":
		_set_stance("crouch")
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if sprinting and is_on_floor() and slide_cd <= 0.0 and hs > 4.0:
		_start_slide()
	elif stance == "crouch":
		if _can_stand():
			_set_stance("stand")
	else:
		_set_stance("crouch")

func _start_slide() -> void:
	var d := GameData.derived()
	_set_stance("slide")
	slide_t = 0.8 * (1.0 + (float(d.stamina_mul) - 1.0) * 0.5)
	slide_cd = 0.7
	var hv := Vector3(velocity.x, 0, velocity.z)
	var dir := hv.normalized() if hv.length() > 0.5 else -global_transform.basis.z
	var spd := maxf(hv.length(), float(d.move_speed) * SPRINT_MUL) * 1.28
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	sprinting = false
	SFX.play("slide", -6.0, randf_range(0.95, 1.08))
	_emit_noise(9.0)
	_rumble(0.15, 0.3, 0.2)

func _set_stance(s: String) -> void:
	stance = s
	match s:
		"stand":
			capsule.height = 1.78
		"crouch":
			capsule.height = 1.2
		"slide":
			capsule.height = 1.0
	col_shape.position.y = capsule.height * 0.5

func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.6, 0), global_position + Vector3(0, 1.85, 0), 1 | 2)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()

func _move(delta: float) -> void:
	var d := GameData.derived()
	var form := GameData.form
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_transform.basis * Vector3(input.x, 0, input.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	var on_floor := is_on_floor()
	coyote = 0.12 if on_floor else coyote - delta
	jump_buffer -= delta
	slide_cd -= delta

	# ---- sprint & stamina ----
	if GameData.input_mode == "pad" and input.length() < 0.25:
		sprint_latch = false
	var want_sprint := (Input.is_action_pressed("sprint") or sprint_latch) and input.y < -0.3
	var heavy: bool = float(d.load) > 1.25
	var can_sprint := stance != "slide" and ads_t < 0.35 and act != "use" and act != "fish" and not heavy and stamina > 0.5 and not mantling
	if want_sprint and can_sprint:
		if stance == "crouch" and _can_stand():
			_set_stance("stand")
		sprinting = stance == "stand"
	else:
		sprinting = false
	var free_run := GameData.buffs.has("energized") or form == "wolf"
	if sprinting and not free_run:
		stamina -= 12.5 / float(d.stamina_mul) * delta
		stamina_delay = 0.9
	else:
		stamina_delay -= delta
		if stamina_delay <= 0.0:
			stamina += (22.0 if GameData.body_temp > 35.5 else 13.0) * delta
	stamina = clampf(stamina, 0.0, STAMINA_MAX)
	if stamina <= 0.5:
		sprinting = false
		sprint_latch = false

	# ---- speed ----
	var speed: float = d.move_speed
	if kill_rush_t > 0.0:
		speed *= 1.0 + float(d.kill_rush)
	if stance == "crouch":
		speed *= CROUCH_MUL
	if sprinting:
		speed *= SPRINT_MUL * (1.12 if form == "vampire" and GameData.is_night() else 1.0)
	if vm_mode == "gun" and not wstats.is_empty():
		speed *= lerpf(float(wstats.get("move_mul", 1.0)), 0.6 * float(wstats.get("move_mul", 1.0)), ads_t)
	if act == "use" or act == "fish":
		speed *= 0.45
	if wet:
		speed *= 0.65

	if mantling:
		_mantle_step(delta)
	else:
		if stance == "slide":
			slide_t -= delta
			var hv := Vector3(velocity.x, 0, velocity.z)
			hv = hv.move_toward(Vector3.ZERO, 6.5 * delta)
			hv += wish * 3.0 * delta
			velocity.x = hv.x
			velocity.z = hv.z
			if slide_t <= 0.0 or hv.length() < 3.0 or not on_floor:
				_set_stance("crouch" if not _can_stand() else "stand")
		else:
			var target := wish * speed
			var accel := 13.0 if on_floor else 3.2
			if on_floor and wish.length() < 0.05:
				accel = 16.0
			var hv2 := Vector3(velocity.x, 0, velocity.z).lerp(target, clampf(accel * delta, 0.0, 1.0))
			velocity.x = hv2.x
			velocity.z = hv2.z
		# jump / mantle
		if jump_buffer > 0.0:
			if _try_mantle(wish, true):
				jump_buffer = 0.0
			elif coyote > 0.0:
				var jv := JUMP_V * (1.38 if form == "wolf" else 1.0)
				velocity.y = jv
				if stance == "slide":
					velocity.x *= 1.06
					velocity.z *= 1.06
				if stance != "stand":
					_set_stance("stand")
				jump_buffer = 0.0
				coyote = 0.0
				SFX.play("jump", -10.0)
				_emit_noise(4.0)
		elif on_floor and sprinting and wish.length() > 0.6:
			_try_mantle(wish, false)
		if not on_floor:
			velocity.y -= GRAVITY * delta
		elif velocity.y < 0.0:
			velocity.y = -0.5
	move_and_slide()

	# ---- landing ----
	var air := not is_on_floor()
	if air:
		fall_speed = minf(fall_speed, velocity.y)
	if was_air and not air and not mantling:
		var impact := -fall_speed
		land_dip = clampf(impact / 11.0, 0.15, 1.2)
		trauma = minf(1.0, trauma + clampf((impact - 6.0) / 20.0, 0.0, 0.5))
		SFX.play("land", -10.0 + clampf(impact - 6.0, 0.0, 8.0), randf_range(0.9, 1.1))
		_emit_noise(clampf(impact, 3.0, 14.0))
		if impact > 13.5 and form != "wolf":
			GameData.take_damage((impact - 13.5) * 7.0, "a bad fall")
		fall_speed = 0.0
	was_air = air

	# ---- footsteps ----
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 1.0 and stance != "slide" and not mantling:
		step_t += delta * hs * 0.55
		if step_t >= 1.0:
			step_t = 0.0
			var hard: bool = world != null and world.has_method("is_hard_floor") and world.is_hard_floor(global_position)
			var vol := -20.0 if stance == "crouch" else (-12.0 if sprinting else -16.0)
			SFX.play("step_hard" if hard else "step", vol, randf_range(0.88, 1.12))
			var r := 1.5 if stance == "crouch" else (13.0 if sprinting else 5.5)
			if GameData.form == "wolf":
				r *= 0.5
			_emit_noise(r)

func _try_mantle(wish: Vector3, from_jump: bool) -> bool:
	if mantling:
		return false
	var dir := wish
	if dir.length() < 0.3:
		if not from_jump:
			return false
		dir = -global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized()
	var space := get_world_3d().direct_space_state
	var o := global_position + Vector3(0, 0.5, 0)
	var q := PhysicsRayQueryParameters3D.create(o, o + dir * 0.85, 1 | 2 | 32)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit.normal as Vector3).y > 0.5:
		return false
	var max_h := 2.1 if from_jump else 1.25
	var top_from: Vector3 = hit.position + dir * 0.35
	top_from.y = global_position.y + max_h + 0.12
	var q2 := PhysicsRayQueryParameters3D.create(top_from, Vector3(top_from.x, global_position.y + 0.35, top_from.z), 1 | 2 | 32)
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty() or (top.normal as Vector3).y < 0.7:
		return false
	var h: float = top.position.y - global_position.y
	if h < 0.42 or h > max_h:
		return false
	var q3 := PhysicsRayQueryParameters3D.create(top.position + Vector3(0, 0.08, 0), top.position + Vector3(0, 1.3, 0), 1 | 2 | 32)
	q3.exclude = [get_rid()]
	if not space.intersect_ray(q3).is_empty():
		return false
	var q4 := PhysicsRayQueryParameters3D.create(cam.global_position, top.position + Vector3(0, 0.9, 0), 1 | 2 | 32)
	q4.exclude = [get_rid()]
	if not space.intersect_ray(q4).is_empty():
		return false
	mantling = true
	mantle_t = 0.0
	mantle_dur = 0.26 + h * 0.14
	mantle_from = global_position
	mantle_to = top.position + dir * 0.3 + Vector3(0, 0.04, 0)
	velocity = Vector3.ZERO
	sprinting = false
	if stance == "slide":
		_set_stance("stand")
	SFX.play("mantle", -8.0)
	_emit_noise(5.0)
	return true

func _mantle_step(delta: float) -> void:
	mantle_t += delta
	var t := clampf(mantle_t / mantle_dur, 0.0, 1.0)
	var up := clampf(t / 0.55, 0.0, 1.0)
	var fwd := clampf((t - 0.35) / 0.65, 0.0, 1.0)
	var p := mantle_from
	p.y = lerpf(mantle_from.y, mantle_to.y, up * up * (3.0 - 2.0 * up))
	var horiz := Vector2(mantle_from.x, mantle_from.z).lerp(Vector2(mantle_to.x, mantle_to.z), fwd * fwd * (3.0 - 2.0 * fwd))
	p.x = horiz.x
	p.z = horiz.y
	global_position = p
	velocity = Vector3.ZERO
	if t >= 1.0:
		mantling = false
		var f := -global_transform.basis.z
		velocity = Vector3(f.x, 0, f.z) * 2.0

# ================= look =================
func _stick_look(delta: float) -> void:
	var raw := InputSetup.right_stick()
	var mag := raw.length()
	var dz := 0.12
	var n := clampf((mag - dz) / (1.0 - dz), 0.0, 1.0) if mag > dz else 0.0
	var aa_on: bool = UITheme.settings.get("aim_assist", true) and GameData.input_mode == "pad" and vm_mode == "gun"
	if n > 0.0:
		var dirv := raw / mag
		var curved := pow(n, 2.0)
		var sens := float(UITheme.settings.get("pad_sens", 1.0))
		if n > 0.95:
			stick_accel = minf(stick_accel + delta, 0.6)
		else:
			stick_accel = maxf(0.0, stick_accel - delta * 4.0)
		var boost := 1.0 + clampf((stick_accel - 0.12) / 0.35, 0.0, 1.0) * 0.9
		var ads_scale := lerpf(1.0, float(UITheme.settings.get("ads_mul", 0.85)) / sqrt(_zoom(1.0)) * 0.8, ads_t)
		var slow := aim_assist.slowdown if aa_on else 1.0
		var ly := -dirv.x * curved * deg_to_rad(310.0) * sens * boost * ads_scale * slow * delta
		var lp := -dirv.y * curved * deg_to_rad(205.0) * sens * ads_scale * slow * delta
		if UITheme.settings.get("invert_y", false):
			lp = -lp
		_add_look(ly, lp)
		look_delta += Vector2(-ly, -lp) * 2.5
	else:
		stick_accel = 0.0
	if aa_on:
		var moving := Vector2(velocity.x, velocity.z).length() > 0.6
		var rng := float(wstats.get("r1", 60.0)) * 1.2
		var rot := aim_assist.update(cam, delta, ads_t, rng, moving, n > 0.05, float(UITheme.settings.get("aa_strength", 1.0)))
		_add_look(rot.x, rot.y)
	else:
		aim_assist.slowdown = 1.0
	# sniper scope breathing + cold shivers move the aim itself
	var t := Time.get_ticks_msec() / 1000.0
	if ads_t > 0.9 and float(wstats.get("ads_zoom", 1.0)) >= 2.0:
		_add_look(sin(t * 0.9) * 0.00022, cos(t * 1.3) * 0.00016)
	if GameData.body_temp < 35.0:
		var sh := (35.0 - GameData.body_temp) * 0.0004
		_add_look(randf_range(-sh, sh), randf_range(-sh, sh))

# ================= weapons =================
func _on_inventory_changed() -> void:
	var cur := GameData.active_weapon()
	if vm_mode == "gun" and act == "ready":
		var key := _vm_key_for(cur)
		if key != vm_key:
			_equip_active(true)
	if not cur.is_empty() and not winst.is_empty() and int(cur.get("uid", 0)) == int(winst.get("uid", -1)):
		winst = cur

func _vm_key_for(e: Dictionary) -> String:
	if not GameData.can_use_guns():
		return "form_" + GameData.form
	if e.is_empty():
		return "melee_" + String(GameData.melee_weapon().id)
	return "gun_%d" % int(e.get("uid", 0))

func _equip_active(force := false) -> void:
	var e := GameData.active_weapon() if GameData.can_use_guns() else {}
	if e.is_empty() and GameData.can_use_guns():
		var other := "secondary" if GameData.active_slot == "primary" else "primary"
		if not GameData.weapon(other).is_empty():
			GameData.active_slot = other
			e = GameData.active_weapon()
	var key := _vm_key_for(e)
	if key == vm_key and not force:
		return
	_end_act()
	winst = e
	if e.is_empty():
		wstats = {}
		_set_vm(Viewmodels.build_melee(GameData.melee_weapon()), "melee", key)
	else:
		wstats = ItemDB.weapon_stats(e)
		_set_vm(Viewmodels.build(e), "gun", key)
	ads_t = 0.0
	bloom = 0.0
	aim_assist.reset()

func _set_vm(node: Node3D, mode: String, key: String) -> void:
	if vm != null:
		vm.queue_free()
	vm = node
	vm_mode = mode
	vm_key = key
	if mode == "gun":
		vm.set_meta("hip", (vm.get_meta("hip", Vector3(0.17, -0.15, -0.36)) as Vector3) * Vector3(1.1, 1.08, 1.18))
	view_root.add_child(vm)
	_flash_mesh = null
	var muzzle := vm.get_node_or_null("Gun/Muzzle") as Node3D
	if muzzle != null:
		_flash_mesh = MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.16, 0.16)
		_flash_mesh.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_texture = Proc.particle_soft(Color(1, 0.8, 0.45, 1))
		m.albedo_color = Color(1.0, 0.85, 0.55)
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_flash_mesh.material_override = m
		_flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flash_mesh.visible = false
		muzzle.add_child(_flash_mesh)
	var arrow := vm.get_node_or_null("Gun/Arrow") as Node3D
	if arrow != null:
		arrow.visible = int(winst.get("ammo", 0)) > 0

func _begin_act(a: String, dur: float, data := {}) -> void:
	act = a
	act_t = 0.0
	act_dur = maxf(0.01, dur)
	act_data = data

func _end_act() -> void:
	var was := act
	act = "ready"
	act_t = 0.0
	act_data = {}
	if was == "fish" and world != null and world.has_method("clear_bobber"):
		world.clear_bobber()

func _weapons(delta: float) -> void:
	fire_cd -= delta
	_fire_queue_t -= delta
	if _padx_t >= 0.0:
		_padx_t += delta
		if _padx_t >= PAD_HOLD:
			_padx_t = -1.0
			_try_interact()
	var d := GameData.derived()
	var melee_only := not GameData.can_use_guns() or winst.is_empty()
	if act != "ready":
		act_t += delta
		_act_tick()
	# ---- ADS ----
	var want_ads := Input.is_action_pressed("ads") and vm_mode == "gun" and not melee_only and act == "ready" and not mantling
	if want_ads and not _ads_prev and UITheme.settings.get("aim_assist", true) and GameData.input_mode == "pad":
		aim_assist.begin_snap()
	_ads_prev = want_ads
	if not wstats.is_empty():
		var ads_rate := 1.0 / maxf(0.05, float(wstats.ads_time) / float(d.handling_mul))
		ads_t = move_toward(ads_t, 1.0 if want_ads else 0.0, ads_rate * delta)
	else:
		ads_t = move_toward(ads_t, 0.0, 6.0 * delta)
	if want_ads:
		sprinting = false
		sprint_latch = false
	var s2f := float(wstats.get("s2f", 0.15))
	sprint_blend = move_toward(sprint_blend, 1.0 if sprinting else 0.0, delta / maxf(0.06, s2f))
	bloom = maxf(0.0, bloom - delta * (7.0 if fire_cd <= 0.0 else 1.2))
	choir_heat = maxf(0.0, choir_heat - delta * 0.6)
	# ---- trigger ----
	var trig := Input.is_action_pressed("fire") or _debug_autofire
	var just := (trig and not _trigger_prev) or _fire_queue_t > 0.0
	_trigger_prev = trig
	if (trig or just) and sprinting:
		sprinting = false
		sprint_latch = false
	if act == "use" and just:
		_end_act()
		_restore_vm()
	if act == "fish" and (trig or sprinting):
		_end_act()
	if melee_only:
		if just and act == "ready":
			_fire_queue_t = 0.0
			_start_melee()
		return
	if act != "ready":
		if act == "reload" and wstats.get("shell_reload", false) and just and int(winst.get("ammo", 0)) > 0:
			_end_act()
		else:
			return
	if _auto_reload and fire_cd <= 0.0:
		_auto_reload = false
		_try_reload()
		return
	if sprint_blend > 0.3:
		return
	if fire_cd <= 0.0:
		var mode: String = wstats.mode
		if (mode == "auto" and trig) or (mode != "auto" and just):
			_fire_queue_t = 0.0
			_shoot()
	if not trig and fire_cd <= -0.15:
		shot_index = 0

func _act_tick() -> void:
	var k := act_t / act_dur
	match act:
		"reload":
			if not act_data.get("mid", false) and k > 0.55 and not wstats.get("shell_reload", false):
				act_data["mid"] = true
				SFX.play("mag_in", -8.0)
			if act_t >= act_dur:
				_finish_reload()
		"swap_out":
			if act_t >= act_dur:
				GameData.set_active_slot(act_data.get("slot", "primary"))
				_equip_active(true)
				var d := GameData.derived()
				_begin_act("swap_in", float(wstats.get("swap", 0.35)) * 0.55 / float(d.handling_mul))
		"swap_in":
			if act_t >= act_dur:
				_end_act()
		"melee":
			var ms: Dictionary = act_data.stats
			if not act_data.get("hit", false) and act_t >= float(ms.time) * float(ms.hit_at):
				act_data["hit"] = true
				_melee_hit(ms)
			if act_t >= act_dur:
				_end_act()
				_restore_vm()
		"throw":
			if not act_data.get("thrown", false) and act_t >= 0.26:
				act_data["thrown"] = true
				_release_throw(act_data.id)
			if act_t >= act_dur:
				_end_act()
				_restore_vm()
		"use":
			if act_t >= act_dur:
				var id: String = act_data.id
				_end_act()
				GameData.use_item(id)
				_restore_vm()
		"fish":
			_fish_tick()

# ---------- shooting ----------
func _mag_size() -> int:
	return int(ceil(float(wstats.get("mag", 1)) * float(GameData.derived().mag_mul)))

func _reserve() -> int:
	if wstats.is_empty():
		return 0
	return GameData.count_item(wstats.ammo)

func _shoot() -> void:
	var s := wstats
	var ammo := int(winst.get("ammo", 0))
	if ammo <= 0:
		SFX.play("dry_fire", -6.0)
		fire_cd = 0.22
		if _reserve() > 0:
			_try_reload()
		else:
			GameData.game_message("Out of %s." % ItemDB.get_def(s.ammo).name, Color(1, 0.55, 0.4))
		return
	winst["ammo"] = ammo - 1
	var rpm := float(s.rpm)
	if s.get("mag", 0) > 100 or "choir" in winst.get("perks", []):
		rpm *= 1.0 + choir_heat * 0.6
		choir_heat = minf(1.0, choir_heat + 0.035)
	fire_cd = 60.0 / rpm
	shot_index += 1
	var d := GameData.derived()
	var spread := _spread_deg()
	var dmg := float(s.dmg)
	if s.get("last_word", false) and ammo == 1:
		dmg *= 3.0
	if s.get("projectile", false):
		_fire_bolt(dmg)
	else:
		for i in int(s.pellets):
			_fire_ray(_spread_dir(spread), dmg)
	bloom = minf(float(s.bloom_max), bloom + float(s.bloom) * lerpf(1.0, 0.4, ads_t))
	# recoil: a per-gun pattern (vertical climb + drifting horizontal) — ~70% springs
	# back, the rest is real climb the player pulls down.
	var rm: float = float(d.recoil_mul) * lerpf(1.0, 0.78, ads_t) * (0.85 if stance == "crouch" else 1.0)
	var rv := deg_to_rad(float(s.rv)) * rm * randf_range(0.88, 1.12)
	var drift := sin(shot_index * 0.55 + float(int(winst.get("uid", 3)) % 7)) * 0.75 + randf_range(-0.45, 0.45)
	var rh := deg_to_rad(float(s.rh)) * rm * drift
	var perm := float(s.perm)
	recoil += Vector2(rv * (1.0 - perm), rh * (1.0 - perm))
	pitch = clampf(pitch + rv * perm, -1.5, 1.5)
	rotate_y(rh * perm)
	# feel
	vm_kick = minf(vm_kick + float(s.kick) * 0.045, 0.12)
	vm_rise = minf(vm_rise + float(s.kick) * 0.055, 0.28)
	vm_roll += randf_range(-1.0, 1.0) * float(s.kick) * 0.035
	vm_cycle = 1.0
	fov_punch = minf(fov_punch + float(s.shake) * 2.2, 4.0)
	trauma = minf(1.0, trauma + float(s.shake) * 0.3)
	_muzzle_flash()
	var id: String = winst.id
	if id != "crossbow" and id != "shotgun" and id != "sniper" and id != "revolver":
		_eject_shell()
	elif id == "shotgun" or id == "sniper":
		var tr := get_tree().create_timer(fire_cd * 0.45)
		tr.timeout.connect(func():
			if is_instance_valid(self) and not dead:
				SFX.play("pump" if id == "shotgun" else "bolt", -8.0)
				_eject_shell())
	var snd := "shot_suppressed" if s.get("suppressed", false) else "shot_" + id
	SFX.play(snd, -2.0, randf_range(0.95, 1.05))
	_emit_noise(float(s.noise))
	_rumble(0.2 + float(s.shake) * 0.4, 0.1 + float(s.shake) * 0.7, 0.07 + float(s.shake) * 0.12)
	var arrow: Node3D = _vm_node("Gun/Arrow")
	if arrow != null:
		arrow.visible = int(winst.ammo) > 0
	weapon_fired.emit()
	if int(winst.ammo) == 0 and _reserve() > 0:
		_auto_reload = true

func _spread_deg() -> float:
	var s := wstats
	var d := GameData.derived()
	var base := lerpf(float(s.hip), float(s.ads_spread), ads_t)
	var hs := Vector2(velocity.x, velocity.z).length()
	var move := clampf(hs / 6.0, 0.0, 1.4) * lerpf(1.3, 0.25, ads_t)
	var air := 0.0
	if not is_on_floor():
		air = 2.4 * float(d.air_spread)
	if stance == "slide":
		air += 1.2 * float(d.air_spread)
	var crouch := -0.25 * base if stance == "crouch" else 0.0
	return maxf(0.0, base + bloom + move + air + crouch)

func _spread_dir(spread_deg: float) -> Vector3:
	var b := cam.global_transform.basis
	var r := tan(deg_to_rad(spread_deg)) * sqrt(randf())
	var a := randf() * TAU
	return (-b.z + b.x * r * cos(a) + b.y * r * sin(a)).normalized()

func _falloff(dist: float) -> float:
	var r0 := float(wstats.r0)
	var r1 := float(wstats.r1)
	if dist <= r0:
		return 1.0
	if dist >= r1:
		return float(wstats.fall)
	return lerpf(1.0, float(wstats.fall), (dist - r0) / (r1 - r0))

func monster_of(col: Object) -> Node:
	if col == null:
		return null
	if col is Node and (col as Node).is_in_group("monsters"):
		return col
	return null

func _hit_info(dmg: float, pos: Vector3, dir: Vector3) -> Dictionary:
	var d := GameData.derived()
	return {"dmg": dmg, "pos": pos, "dir": dir, "element": wstats.get("element", ""), "source": "player",
		"weapon": winst.get("id", ""), "head_mul": float(wstats.get("head", 1.5)) * float(d.head_mul),
		"force": dmg * 0.06, "stake": wstats.get("stake", false), "attacker": self}

func _fire_ray(dir: Vector3, dmg: float) -> void:
	var from := cam.global_position
	var max_range := float(wstats.r1) * 2.6
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var end := from + dir * max_range
	var pierce := bool(wstats.get("pierce", false))
	for pass_i in (6 if pierce else 1):
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_range, 1 | 2 | 4 | 32)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		end = hit.position
		var mon := monster_of(hit.collider)
		if mon != null:
			var dist := cam.global_position.distance_to(hit.position)
			var info := _hit_info(dmg * _falloff(dist) * randf_range(0.93, 1.07), hit.position, dir)
			var res: Dictionary = mon.take_hit(info)
			_on_hit_result(res, hit.position, mon)
			if wstats.get("explosive", false):
				Combat.explode(hit.position, 2.4, dmg * 0.45, self, {"small": true})
			if not pierce:
				break
			exclude.append(hit.rid)
			from = hit.position + dir * 0.05
		else:
			var col: Object = hit.collider
			if col is RigidBody3D:
				(col as RigidBody3D).apply_impulse(dir * dmg * 0.05, hit.position - (col as RigidBody3D).global_position)
			if col != null and col.has_method("take_hit"):
				col.take_hit(_hit_info(dmg, hit.position, dir))
			Combat.impact(hit.position, hit.normal, Combat.surface_of(col))
			if wstats.get("explosive", false):
				Combat.explode(hit.position, 2.4, dmg * 0.45, self, {"small": true})
			break
	if not wstats.get("suppressed", false) or randf() < 0.3:
		Combat.tracer(_muzzle_true_pos(), end, Color(1.0, 0.85, 0.5))

func _fire_bolt(dmg: float) -> void:
	var b := Projectile.new()
	var dir := _spread_dir(_spread_deg())
	b.setup("bolt", cam.global_position + dir * 0.4, dir * float(wstats.get("speed", 70.0)), _hit_info(dmg, Vector3.ZERO, dir))
	b.owner_node = self
	world.add_child(b)

func _on_hit_result(res: Dictionary, pos: Vector3, mon: Node, melee := false) -> void:
	if res.is_empty() or float(res.get("dealt", 0.0)) <= 0.0:
		return
	var head: bool = res.get("head", false)
	var kill: bool = res.get("killed", false)
	Combat.damage_number(pos, float(res.dealt), head, kill, String(res.get("element", "")), String(res.get("note", "")))
	hit_confirmed.emit({"head": head, "kill": kill, "dmg": res.dealt, "melee": melee})
	SFX.play("headshot" if head else "hitmarker", -5.0 if head else -9.0, randf_range(0.97, 1.05))
	if kill:
		SFX.play("kill", -5.0, randf_range(0.95, 1.05))
		kill_rush_t = 4.0
		if head or melee or float(wstats.get("dmg", 0.0)) >= 55.0:
			hitstop(0.05 if melee else 0.035)
		_rumble(0.3, 0.5, 0.12)
	var leech := float(wstats.get("leech", 0.0)) if not melee else 0.0
	if leech > 0.0:
		GameData.heal(float(res.dealt) * leech)
	if head and not melee and wstats.get("sermon", false):
		_ricochet(pos, mon, float(res.dealt) * 0.6)

func _ricochet(from: Vector3, skip: Node, dmg: float) -> void:
	var best: Node = null
	var bd := 14.0
	for m in get_tree().get_nodes_in_group("monsters"):
		if m == skip or not m.is_targetable():
			continue
		var dd := from.distance_to(m.global_position)
		if dd < bd:
			bd = dd
			best = m
	if best != null:
		var to: Vector3 = best.aim_point(true)
		Combat.tracer(from, to, Color(1.0, 0.95, 0.6))
		var res: Dictionary = best.take_hit(_hit_info(dmg, to, (to - from).normalized()))
		_on_hit_result(res, to, best)

func hitstop(dur: float) -> void:
	if Engine.time_scale < 0.99:
		return
	Engine.time_scale = 0.06
	get_tree().create_timer(dur, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func _muzzle_true_pos() -> Vector3:
	var m: Node3D = _vm_node("Gun/Muzzle")
	if m == null:
		return cam.global_position - cam.global_transform.basis.z * 0.5
	var local := cam.global_transform.affine_inverse() * m.global_position
	return cam.global_transform * (local / VIEW_SCALE)

func _muzzle_flash() -> void:
	if wstats.get("suppressed", false) or wstats.get("projectile", false):
		return
	if _flash_mesh != null:
		_flash_mesh.visible = true
		_flash_mesh.scale = Vector3.ONE * randf_range(0.8, 1.4) * (1.6 if winst.id in ["shotgun", "sniper", "revolver"] else 1.0)
		_flash_mesh.rotation.z = randf() * TAU
		get_tree().create_timer(0.045).timeout.connect(func():
			if is_instance_valid(_flash_mesh): _flash_mesh.visible = false)
	Combat.flash_light(_muzzle_true_pos(), Color(1.0, 0.78, 0.4), 6.0, 2.6)

func _eject_shell() -> void:
	if vm == null:
		return
	var right := cam.global_transform.basis.x
	var p := _muzzle_true_pos() - cam.global_transform.basis.z * -0.25 + right * 0.05
	Combat.shell(p, velocity * 0.5 + right * randf_range(1.4, 2.4) + Vector3.UP * randf_range(1.6, 2.6) + cam.global_transform.basis.z * 0.4, winst.id == "shotgun")

# ---------- reload ----------
func _try_reload() -> void:
	if winst.is_empty() or act != "ready":
		return
	var mag := _mag_size()
	if int(winst.get("ammo", 0)) >= mag:
		return
	if _reserve() <= 0:
		GameData.game_message("No %s left. Scavenge crates, cars, gun stores." % ItemDB.get_def(wstats.ammo).name, Color(1, 0.55, 0.4))
		return
	var d := GameData.derived()
	var empty := int(winst.get("ammo", 0)) == 0
	var dur: float
	if wstats.get("shell_reload", false):
		dur = (float(wstats.reload) + 0.25) / float(d.reload_mul)
	else:
		dur = float(wstats.reload_empty if empty else wstats.reload) / float(d.reload_mul)
	_end_act()
	_begin_act("reload", dur, {"empty": empty})
	SFX.play("mag_out" if not wstats.get("shell_reload", false) else "equip", -8.0)
	_auto_reload = false

func _finish_reload() -> void:
	var mag := _mag_size()
	var have := int(winst.get("ammo", 0))
	var d := GameData.derived()
	if wstats.get("shell_reload", false):
		if GameData.remove_item(wstats.ammo, 1):
			winst["ammo"] = have + 1
			SFX.play("shell_in", -8.0, randf_range(0.95, 1.08))
		if int(winst.ammo) < mag and _reserve() > 0:
			_begin_act("reload", float(wstats.reload) / float(d.reload_mul), {"empty": false})
			return
		SFX.play("pump", -7.0)
	else:
		var need := mag - have
		var got := mini(need, _reserve())
		if got > 0:
			GameData.remove_item(wstats.ammo, got)
			winst["ammo"] = have + got
		if act_data.get("empty", false) and winst.id in ["pistol", "sniper", "dmr", "smg", "ar", "lmg"]:
			SFX.play("bolt", -8.0)
	var arrow: Node3D = _vm_node("Gun/Arrow")
	if arrow != null:
		arrow.visible = true
	_end_act()
	GameData.touch()

# ---------- swap ----------
func _swap_to(slot: String) -> void:
	if slot == GameData.active_slot or GameData.weapon(slot).is_empty() or not GameData.can_use_guns():
		return
	if act == "swap_out" or act == "melee" or act == "throw" or act == "use":
		return
	_end_act()
	var d := GameData.derived()
	_begin_act("swap_out", float(wstats.get("swap", 0.35)) * 0.45 / float(d.handling_mul), {"slot": slot})
	ads_t = 0.0
	SFX.play("equip", -10.0, 1.1)

# ---------- melee ----------
func _start_melee() -> void:
	if act in ["melee", "throw", "use", "swap_out", "swap_in"] or mantling:
		return
	var m := GameData.melee_weapon()
	var ms := ItemDB.melee_stats(m)
	if stamina < 2.0 and GameData.form == "human":
		return
	_end_act()
	if GameData.form == "human":
		stamina = maxf(0.0, stamina - float(ms.stamina))
		stamina_delay = 0.6
	_begin_act("melee", float(ms.time), {"stats": ms, "hit": false, "id": m.id})
	sprinting = false
	ads_t = 0.0
	_set_vm(Viewmodels.build_melee(m), "melee", "melee_" + String(m.id))
	SFX.play("swing_heavy" if float(ms.time) > 0.7 else "swing", -6.0, randf_range(0.92, 1.08))

func _restore_vm() -> void:
	var e := GameData.active_weapon() if GameData.can_use_guns() else {}
	if not e.is_empty() and vm_mode == "gun" and vm_key == _vm_key_for(e):
		return
	_equip_active(true)
	if vm_mode == "gun":
		_begin_act("swap_in", 0.16)

func _melee_hit(ms: Dictionary) -> void:
	var d := GameData.derived()
	var fwd := -cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = float(ms.radius) + 0.35
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), cam.global_position + fwd * float(ms.reach) * 0.55)
	q.collision_mask = 4 | 2 | 32
	q.exclude = [get_rid()]
	var targets := []
	var hit_world := false
	for r in space.intersect_shape(q, 24):
		var mon := monster_of(r.collider)
		if mon == null:
			hit_world = true
			continue
		if mon in targets or not mon.is_targetable():
			continue
		var to: Vector3 = mon.aim_point(false) - cam.global_position
		if to.length() > float(ms.reach) + 1.4 or fwd.angle_to(to.normalized()) > deg_to_rad(80.0):
			continue
		var lq := PhysicsRayQueryParameters3D.create(cam.global_position, mon.aim_point(false), 1 | 2)
		if not space.intersect_ray(lq).is_empty():
			continue
		targets.append(mon)
	targets.sort_custom(func(a, b): return cam.global_position.distance_to(a.global_position) < cam.global_position.distance_to(b.global_position))
	var hits := 0
	for mon in targets:
		if hits >= int(ms.cleave):
			break
		hits += 1
		var stealth: bool = mon.is_unaware()
		var mul := float(d.melee_mul) * ((float(ms.stealth) + float(d.stealth_add)) if stealth else 1.0)
		var info := {"dmg": float(ms.dmg) * mul, "pos": mon.aim_point(false), "dir": fwd, "element": ms.get("element", ""),
			"source": "player", "weapon": act_data.get("id", "fists"), "head_mul": 1.0, "force": float(ms.knock),
			"melee": true, "stealth": stealth, "stun": ms.get("stun", false), "attacker": self}
		var res: Dictionary = mon.take_hit(info)
		mon.knockback(fwd, float(ms.knock))
		if stealth and not res.is_empty():
			res["note"] = "SNEAK ATTACK"
		_on_hit_result(res, info.pos, mon, true)
		var leech := float(ms.get("leech", 0.0))
		if leech > 0.0 and not res.is_empty():
			GameData.heal(float(res.dealt) * leech * float(d.drain_mul))
			if GameData.form == "vampire":
				GameData.blood = minf(100.0, GameData.blood + float(res.dealt) * 0.2)
		if ms.get("quake", false):
			Combat.explode(mon.global_position, 3.5, float(ms.dmg) * 0.4, self, {"small": true, "no_self": true})
	if hits > 0:
		SFX.play("melee_hit", -3.0, randf_range(0.9, 1.1))
		trauma = minf(1.0, trauma + 0.22)
		vm_kick = 0.06
		hitstop(0.03)
		_rumble(0.4, 0.6, 0.12)
	elif hit_world:
		SFX.play("hit_dirt", -6.0)
		trauma = minf(1.0, trauma + 0.08)
	_emit_noise(float(ms.noise) + (4.0 if hits > 0 else 0.0))

# ---------- throwables & items ----------
func cycle_throwable() -> void:
	var order := ["frag", "molotov", "noisemaker"]
	var i := order.find(GameData.throwable)
	for k in range(1, 4):
		var c: String = order[(i + k) % 3]
		if GameData.count_item(c) > 0:
			GameData.throwable = c
			GameData.touch()
			SFX.play("ui", -10.0)
			return

func _start_throw() -> void:
	if act != "ready" or GameData.form == "wolf" or GameData.form == "zombie":
		return
	var id := GameData.throwable
	if GameData.count_item(id) <= 0:
		cycle_throwable()
		id = GameData.throwable
		if GameData.count_item(id) <= 0:
			GameData.game_message("No throwables. Frags, Molotovs and Noisemakers turn up in military crates.", Color(0.9, 0.7, 0.5))
			return
	_begin_act("throw", 0.5, {"id": id, "thrown": false})
	ads_t = 0.0
	_set_vm(Viewmodels.build_item(id), "item", "item_" + id)
	vm.set_meta("hip", Vector3(0.16, -0.12, -0.3))

func _release_throw(id: String) -> void:
	if not GameData.remove_item(id, 1):
		return
	var t := Throwable.new()
	var fwd := -cam.global_transform.basis.z
	t.kind = id
	t.owner_node = self
	world.add_child(t)
	t.global_position = cam.global_position + fwd * 0.6 + Vector3(0, -0.1, 0)
	t.linear_velocity = fwd * 17.0 + Vector3.UP * 3.5 + velocity * 0.6
	t.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	SFX.play("whoosh", -8.0)

func _start_heal() -> void:
	if act != "ready":
		return
	var pick := ""
	if GameData.form == "vampire":
		pick = "blood_pack" if GameData.count_item("blood_pack") > 0 else ""
		if pick == "":
			GameData.game_message("You need blood. Bite something, or find blood packs in pharmacies.", Color(0.9, 0.3, 0.35))
			return
	elif GameData.form != "human":
		return
	else:
		var missing := GameData.hp_max() - GameData.hp
		if missing < 1.0:
			GameData.game_message("You're already patched up.", Color(0.8, 0.8, 0.8))
			return
		if missing > 45.0 and GameData.count_item("medkit") > 0:
			pick = "medkit"
		elif GameData.count_item("bandage") > 0:
			pick = "bandage"
		elif GameData.count_item("medkit") > 0:
			pick = "medkit"
		elif GameData.count_item("painkillers") > 0:
			pick = "painkillers"
	if pick == "":
		GameData.game_message("No bandages or medkits.", Color(1, 0.55, 0.45))
		return
	request_use(pick)

# Consumables from the HUD/menu: meds channel (interruptible), food is instant.
func request_use(id: String) -> void:
	var def := ItemDB.get_def(id)
	var why := GameData.can_use(id)
	if why != "":
		GameData.game_message(why, Color(1, 0.6, 0.5))
		return
	var ut := float(def.get("use_time", 0.0))
	if ut <= 0.0 or act != "ready":
		GameData.use_item(id)
		return
	_end_act()
	_begin_act("use", ut, {"id": id})
	ads_t = 0.0
	sprinting = false
	_set_vm(Viewmodels.build_item("bandage" if id == "bandage" else "syringe"), "item", "item_use")
	vm.set_meta("hip", Vector3(0.05, -0.14, -0.3))
	SFX.play("heal", -6.0)

func place_campfire() -> void:
	if world == null or not world.has_method("spawn_campfire"):
		return
	var fwd := -global_transform.basis.z
	var p := global_position + fwd * 1.6
	if GameData.remove_item("campfire_kit", 1):
		world.spawn_campfire(p)
		GameData.game_message("Campfire built. Warmth, light, cooking.", Color(1.0, 0.75, 0.4))

func toggle_flashlight() -> void:
	flashlight.visible = not flashlight.visible
	SFX.play("click", -10.0, 1.3 if flashlight.visible else 0.8)

# ---------- interaction ----------
func _interactable_of(col: Object) -> Object:
	if col == null:
		return null
	if col.has_method("interact"):
		return col
	var p := (col as Node).get_parent() if col is Node else null
	if p != null and p.has_method("interact"):
		return p
	return null

func _interact_scan(_delta: float) -> void:
	interact_target = null
	interact_text = ""
	if act == "fish":
		interact_text = "PULL!  [%s]" % InputSetup.glyph("interact") if act_data.get("bite", false) else "Waiting for a bite...  (move to stop)"
		return
	var from := cam.global_position
	var fwd := -cam.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 2.9, 2 | 8 | 32)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var obj: Object = null
	if not hit.is_empty():
		obj = _interactable_of(hit.collider)
	if obj == null and world != null:
		obj = world.nearest_loot(global_position, fwd, 1.7)
	if obj != null and obj.has_method("prompt"):
		interact_target = obj
		interact_text = "[%s]  %s" % [InputSetup.glyph("interact"), obj.prompt()]
		return
	fish_spot = Vector3.INF
	if world != null and GameData.count_item("fishing_rod") > 0 and GameData.form == "human":
		fish_spot = world.fishing_spot(from, fwd)
		if fish_spot != Vector3.INF:
			interact_text = "[%s]  Cast fishing line" % InputSetup.glyph("interact")

func _try_interact() -> void:
	if act == "fish":
		if act_data.get("bite", false):
			_catch_fish()
		return
	if interact_target != null and is_instance_valid(interact_target):
		interact_target.interact(self)
		return
	if fish_spot != Vector3.INF and act == "ready":
		_begin_act("fish", 999.0, {"spot": fish_spot, "wait": randf_range(4.0, 11.0), "bite": false})
		world.show_bobber(fish_spot)
		SFX.play("splash", -8.0)
		_emit_noise(3.0)

func _fish_tick() -> void:
	var wait := float(act_data.wait)
	if not act_data.bite and act_t >= wait:
		act_data["bite"] = true
		act_data["bite_t"] = act_t
		SFX.play("bite", -2.0)
		SFX.play("splash", -10.0, 1.4)
		_rumble(0.5, 0.2, 0.25)
		world.bob_bobber()
	elif act_data.bite and act_t - float(act_data.bite_t) > 1.0:
		GameData.game_message("It got away.", Color(0.7, 0.8, 0.9))
		act_data["bite"] = false
		act_data["wait"] = act_t + randf_range(4.0, 9.0)
	if Vector2(velocity.x, velocity.z).length() > 1.5:
		_end_act()

func _catch_fish() -> void:
	var id := "glow_carp" if randf() < 0.12 else "raw_fish"
	GameData.add_entry({"id": id, "count": 1})
	GameData.progress("fish")
	GameData.add_xp(25)
	SFX.play("reel", -6.0)
	SFX.play("pickup", -6.0)
	GameData.game_message("Caught: %s!" % ItemDB.get_def(id).name, Color(0.5, 0.9, 1.0))
	act_data["bite"] = false
	act_data["wait"] = act_t + randf_range(5.0, 12.0)
	world.show_bobber(act_data.spot)

# ================= damage & death =================
func _on_damage(amount: float, _source: String, _from: Vector3) -> void:
	trauma = minf(1.0, trauma + amount / 30.0)
	flinch_v += Vector3(randf_range(1.0, 2.2), 0.0, randf_range(-1.6, 1.6)) * clampf(amount / 14.0, 0.3, 1.6)
	_rumble(0.6, 0.85, 0.22)
	if act == "use" and amount > 8.0:
		_end_act()
		_restore_vm()

func _on_died(_cause: String) -> void:
	dead = true
	Engine.time_scale = 1.0
	if vm != null:
		vm.visible = false
	flashlight.visible = false
	var t := create_tween().set_parallel(true)
	t.tween_property(cam_pivot, "position:y", 0.25, 1.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(cam, "rotation:z", 1.3, 1.2).set_trans(Tween.TRANS_QUAD)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ================= vehicles =================
func enter_vehicle(v: Node) -> void:
	in_vehicle = v
	_end_act()
	ads_t = 0.0
	sprinting = false
	collision_layer = 0
	collision_mask = 0
	view_root.visible = false
	flashlight.visible = false
	cam.current = false
	velocity = Vector3.ZERO

func exit_vehicle(pos: Vector3) -> void:
	in_vehicle = null
	global_position = pos
	collision_layer = 64
	collision_mask = 1 | 2 | 4 | 32
	view_root.visible = true
	cam.current = true
	velocity = Vector3.ZERO

# ================= camera & viewmodel =================
func _camera(delta: float) -> void:
	recoil = recoil.lerp(Vector2.ZERO, 1.0 - exp(-float(wstats.get("rec", 10.0)) * (0.3 if fire_cd > -0.05 else 1.0) * delta))
	flinch_v += (-flinch * 85.0 - flinch_v * 10.0) * delta
	flinch += flinch_v * delta * 0.06
	fov_punch = lerpf(fov_punch, 0.0, 1.0 - exp(-11.0 * delta))
	trauma = maxf(0.0, trauma - delta * 1.5)
	land_dip = lerpf(land_dip, 0.0, 1.0 - exp(-7.0 * delta))
	var target_eye := EYE_STAND
	if stance == "crouch":
		target_eye = EYE_CROUCH
	elif stance == "slide":
		target_eye = EYE_SLIDE
	eye_h = lerpf(eye_h, target_eye, 1.0 - exp(-13.0 * delta))
	var hs := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and hs > 0.6 and stance != "slide" and not mantling
	bob_amt = lerpf(bob_amt, clampf(hs / 6.0, 0.0, 1.4) if moving else 0.0, 1.0 - exp(-8.0 * delta))
	bob_t += delta * hs * 1.25
	var bob_y := absf(sin(bob_t)) * 0.035 * bob_amt * lerpf(1.0, 0.25, ads_t)
	cam_pivot.position.y = eye_h - land_dip * 0.16 - bob_y
	cam_pivot.rotation.x = pitch + recoil.x + flinch.x
	var input_x := Input.get_axis("move_left", "move_right")
	var roll_target := -input_x * deg_to_rad(0.9)
	if stance == "slide":
		roll_target += deg_to_rad(4.5)
	if mantling:
		roll_target += deg_to_rad(-3.0)
	cam_roll = lerpf(cam_roll, roll_target, 1.0 - exp(-8.0 * delta))
	shake_t += delta * 28.0
	var sh := trauma * trauma
	cam.h_offset = sin(shake_t * 1.13) * cos(shake_t * 0.71) * 0.05 * sh
	cam.v_offset = sin(shake_t * 0.93 + 1.7) * 0.05 * sh
	cam.rotation = Vector3(0.0, recoil.y, cam_roll + flinch.z + sin(shake_t * 0.77) * 0.025 * sh)
	var zoom := lerpf(1.0, _zoom(1.0), ads_t * ads_t * (3.0 - 2.0 * ads_t)) if vm_mode == "gun" else 1.0
	var fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) / zoom))
	fov += sprint_blend * 7.0 * (1.0 - ads_t)
	if stance == "slide":
		fov += 6.0
	if GameData.form == "wolf":
		fov += 6.0
	fov += fov_punch * (1.0 - ads_t * 0.6)
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-18.0 * delta))
	var scoped := scoped()
	if vm != null:
		vm.visible = not scoped

func scoped() -> bool:
	return vm_mode == "gun" and bool(wstats.get("scope", false)) and ads_t > 0.85

func _update_viewmodel(delta: float) -> void:
	if vm == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var hip: Vector3 = vm.get_meta("hip", Vector3(0.17, -0.15, -0.35))
	var pos := hip
	var rot := Vector3.ZERO
	var e := ads_t * ads_t * (3.0 - 2.0 * ads_t)
	var sway_amt := lerpf(1.0, 0.12, e)
	if vm_mode == "gun":
		var sight := vm.get_node_or_null("Gun/Sight") as Node3D
		if sight != null:
			var ads_pos := -sight.position + Vector3(0, 0, -float(vm.get_meta("ads_dist", 0.2)))
			pos = hip.lerp(ads_pos, e)
		pos += Vector3(-0.05, -0.045, 0.045) * sprint_blend
		rot += Vector3(-0.32, 0.62, 0.38) * sprint_blend
		if act == "reload":
			var k := clampf(act_t / act_dur, 0.0, 1.0)
			var rb := sin(k * PI)
			rot += Vector3(0.28, 0.32, -0.42) * rb
			pos += Vector3(-0.03, -0.035, 0.03) * rb
			var mag := vm.get_node_or_null("Mag") as Node3D
			if mag != null and not wstats.get("shell_reload", false):
				var out := 0.0
				if k < 0.3:
					out = k / 0.3
				elif k < 0.62:
					out = 1.0
				else:
					out = maxf(0.0, 1.0 - (k - 0.62) / 0.25)
				mag.position = Vector3(-0.02 * out, -0.2 * out, 0.04 * out)
				mag.rotation = Vector3(0.6 * out, 0, 0.3 * out)
			elif mag != null:
				var bounce := absf(sin(k * PI * 1.0))
				mag.position = Vector3(0, -0.06 * (1.0 - bounce), 0.02)
		else:
			var mag2 := vm.get_node_or_null("Mag") as Node3D
			if mag2 != null:
				mag2.position = mag2.position.lerp(Vector3.ZERO, 1.0 - exp(-20.0 * delta))
				mag2.rotation = mag2.rotation.lerp(Vector3.ZERO, 1.0 - exp(-20.0 * delta))
		if act == "swap_out":
			var k2 := clampf(act_t / act_dur, 0.0, 1.0)
			pos.y -= 0.3 * k2
			rot.x -= 0.9 * k2
		elif act == "swap_in":
			var k3 := 1.0 - clampf(act_t / act_dur, 0.0, 1.0)
			pos.y -= 0.3 * k3 * k3
			rot.x -= 0.9 * k3 * k3
		# slide / pump / bolt cycling
		vm_cycle = maxf(0.0, vm_cycle - delta * 9.0)
		var slide := vm.get_node_or_null("Gun/Slide") as Node3D
		if slide != null:
			slide.position.z = 0.035 * vm_cycle if int(winst.get("ammo", 1)) > 0 else 0.035
		var pump := vm.get_node_or_null("Gun/Pump") as Node3D
		if pump != null:
			var pk := 0.0
			if fire_cd > 0.0 and wstats.get("mode", "") == "pump":
				var cyc := 60.0 / float(wstats.rpm)
				var ph := 1.0 - fire_cd / cyc
				pk = sin(clampf((ph - 0.2) / 0.6, 0.0, 1.0) * PI)
			pump.position.z = 0.08 * pk
		var bolt := vm.get_node_or_null("Gun/Bolt") as Node3D
		if bolt != null:
			var bk := 0.0
			if fire_cd > 0.0 and wstats.get("mode", "") == "bolt":
				var cyc2 := 60.0 / float(wstats.rpm)
				var ph2 := 1.0 - fire_cd / cyc2
				bk = sin(clampf((ph2 - 0.2) / 0.6, 0.0, 1.0) * PI)
			bolt.position.z = 0.06 * bk
			bolt.rotation.z = -0.9 * minf(1.0, bk * 2.0)
	elif vm_mode == "melee":
		var swing := vm.get_node_or_null("Swing") as Node3D
		if act == "melee" and swing != null:
			var ms: Dictionary = act_data.stats
			var k4 := clampf(act_t / float(ms.time), 0.0, 1.0)
			var ha := float(ms.hit_at)
			var overhead: bool = String(act_data.get("id", "")) in ["axe", "sledge"]
			var wind := Vector3(-0.5, 0.6, 0.8) if not overhead else Vector3(-1.3, 0.2, 0.1)
			var strike := Vector3(0.6, -0.9, -0.6) if not overhead else Vector3(0.9, -0.1, 0.0)
			var a: Vector3
			var p := Vector3.ZERO
			if k4 < ha * 0.55:
				var w := k4 / (ha * 0.55)
				a = Vector3.ZERO.lerp(wind, w * w * (3.0 - 2.0 * w))
				p = Vector3(0.06, 0.05, 0.05) * w
			elif k4 < ha:
				var s := (k4 - ha * 0.55) / (ha * 0.45)
				a = wind.lerp(strike, s * s)
				p = Vector3(0.06, 0.05, 0.05).lerp(Vector3(-0.2, -0.08, -0.12), s)
			else:
				var r := (k4 - ha) / (1.0 - ha)
				a = strike.lerp(Vector3.ZERO, r * r * (3.0 - 2.0 * r))
				p = Vector3(-0.2, -0.08, -0.12).lerp(Vector3.ZERO, r)
			swing.rotation = a
			swing.position = p
		elif swing != null:
			swing.rotation = swing.rotation.lerp(Vector3.ZERO, 1.0 - exp(-12.0 * delta))
	elif vm_mode == "item":
		var k5 := clampf(act_t / act_dur, 0.0, 1.0)
		if act == "throw":
			if k5 < 0.5:
				pos += Vector3(0.05, 0.08, 0.12) * (k5 / 0.5)
				rot.x += 0.6 * (k5 / 0.5)
			else:
				var r2 := (k5 - 0.5) / 0.5
				pos += Vector3(0.05, 0.08, 0.12).lerp(Vector3(-0.05, -0.15, -0.3), minf(1.0, r2 * 3.0))
				rot.x += lerpf(0.6, -0.8, minf(1.0, r2 * 3.0))
		elif act == "use":
			pos += Vector3(0.0, sin(k5 * PI * 4.0) * 0.01, 0.0)
			rot.z += sin(k5 * PI) * 0.4
	# look sway, breathing, cold shivers, bob, recoil kick
	vm_sway = vm_sway.lerp(look_delta.limit_length(1.0) * 0.07, 1.0 - exp(-9.0 * delta))
	look_delta = look_delta.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
	pos += Vector3(-vm_sway.x * 0.35, vm_sway.y * 0.35, 0.0) * sway_amt
	rot += Vector3(vm_sway.y * 0.5, -vm_sway.x * 0.7, -vm_sway.x * 0.4) * sway_amt
	var breath := 0.004 * sway_amt
	pos += Vector3(sin(t * 1.1) * breath, sin(t * 2.2) * breath * 0.7, 0.0)
	if GameData.body_temp < 35.5:
		var sv := (35.5 - GameData.body_temp) * 0.004
		pos += Vector3(randf_range(-sv, sv), randf_range(-sv, sv), 0.0)
	var bx := sin(bob_t) * 0.012 * bob_amt * sway_amt * (1.6 if sprinting else 1.0)
	var by := -absf(cos(bob_t)) * 0.012 * bob_amt * sway_amt * (1.6 if sprinting else 1.0)
	pos += Vector3(bx, by, 0.0)
	rot.z += sin(bob_t) * 0.02 * bob_amt * sway_amt
	pos.z += vm_kick
	pos.y += vm_rise * 0.06 - land_dip * 0.03
	rot.x += vm_rise
	rot.z += vm_roll
	vm_kick = lerpf(vm_kick, 0.0, 1.0 - exp(-18.0 * delta))
	vm_rise = lerpf(vm_rise, 0.0, 1.0 - exp(-11.0 * delta))
	vm_roll = lerpf(vm_roll, 0.0, 1.0 - exp(-9.0 * delta))
	vm.position = pos
	vm.rotation = rot

# ================= helpers =================
func _emit_noise(r: float) -> void:
	var d := GameData.derived()
	r *= float(d.noise_mul)
	if d.encumbered:
		r *= 1.3
	Hearing.emit_noise(global_position, r, "player", true)

func _rumble(weak: float, strong: float, dur: float) -> void:
	if GameData.input_mode != "pad" or not UITheme.settings.get("vibration", true):
		return
	for dev in Input.get_connected_joypads():
		Input.start_joy_vibration(dev, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), dur)

func current_spread() -> float:
	if wstats.is_empty():
		return 0.0
	return _spread_deg()

func act_progress() -> float:
	if act == "ready" or act == "fish":
		return -1.0
	return clampf(act_t / act_dur, 0.0, 1.0)

func interact_hold_progress() -> float:
	return clampf(_padx_t / PAD_HOLD, 0.0, 1.0) if _padx_t >= 0.0 else 0.0

func look_at_yaw(p: Vector3) -> void:
	var to := p - global_position
	rotation.y = atan2(-to.x, -to.z)

func _vm_node(path: String) -> Node3D:
	if vm == null:
		return null
	return vm.get_node_or_null(path) as Node3D

func teleport(pos: Vector3, yaw := 0.0) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	velocity = Vector3.ZERO
	pitch = 0.0
