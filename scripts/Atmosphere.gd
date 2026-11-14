class_name Atmosphere
extends Node3D
# Mood layer over the open world: falling ash and drifting spores around the player,
# distant smoke columns rising from burning ruins, and dry lightning inside the
# sickly overcast (sky flash + rolling thunder).

var world: World
var _ash: GPUParticles3D
var _spores: GPUParticles3D
var _flash := 0.0
var _next_strike := 12.0
var _thunder_t := -1.0
var _rng := RandomNumberGenerator.new()

func setup(w: World) -> void:
	world = w
	_rng.randomize()
	if Combat.low_fx():
		return
	_ash = _field(Color(0.55, 0.55, 0.5, 0.7), 900, 0.07, Vector3(0, -0.5, 0), 9.0, false)
	_spores = _field(Color(0.6, 1.0, 0.3, 0.9), 120, 0.05, Vector3(0, 0.05, 0), 12.0, true)

func _field(col: Color, amount: int, size: float, grav: Vector3, life: float, glow: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 9, 22)
	pm.direction = Vector3(1, -0.2, 0.4)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.9
	pm.gravity = grav
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color = col
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 1))
	ramp.add_point(0.85, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := Proc.particle_quad(Proc.particle_soft(Color(1, 1, 1, 1)), false, size)
	var qm := q.material as StandardMaterial3D
	if glow:
		qm.emission_enabled = true
		qm.emission = Color(0.6, 1.0, 0.3)
		qm.emission_energy_multiplier = 2.0
	p.draw_pass_1 = q
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -15, -30), Vector3(60, 30, 60))
	add_child(p)
	return p

# Tall, slow smoke column over a burning ruin; visible from across the map.
func smoke_column(pos: Vector3, height := 40.0, dark := true) -> void:
	if Combat.low_fx():
		return
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.5
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = height / 14.0
	pm.initial_velocity_max = height / 10.0
	pm.gravity = Vector3(0.6, 0.0, 0.25)
	pm.damping_min = 0.2
	pm.damping_max = 0.4
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var sc := Curve.new()
	sc.max_value = 3.0
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(1, 3.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	var c0 := Color(0.06, 0.06, 0.055, 1.0) if dark else Color(0.45, 0.5, 0.35, 0.8)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 0.25, 0.1, 0.0))
	ramp.add_point(0.05, c0)
	ramp.add_point(0.6, Color(c0.r * 1.3, c0.g * 1.3, c0.b * 1.3, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(c0.r * 1.6, c0.g * 1.6, c0.b * 1.5, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	p.process_material = pm
	var q := Proc.particle_quad(Proc.particle_soft(Color(1, 1, 1, 1)), false, height * 0.28)
	(q.material as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	p.draw_pass_1 = q
	p.amount = 64
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(Vector3(-40, -5, -40), Vector3(80, height * 1.8, 80))
	p.position = pos
	add_child(p)

func _process(delta: float) -> void:
	if world == null:
		return
	var cam := get_viewport().get_camera_3d()
	var under := world._under_k > 0.5
	if cam != null:
		for f in [_ash, _spores]:
			if f != null:
				(f as GPUParticles3D).global_position = cam.global_position
				(f as GPUParticles3D).emitting = not under
	# dry lightning
	_next_strike -= delta
	if _next_strike <= 0.0 and not under:
		_next_strike = _rng.randf_range(10.0, 32.0) * (0.6 if GameData.is_night() else 1.0)
		_flash = _rng.randf_range(0.7, 1.0)
		_thunder_t = _rng.randf_range(0.8, 3.0)
		var a := _rng.randf() * TAU
		world.sky_mat.set_shader_parameter("flash_dir", Vector2(cos(a), sin(a)) * _rng.randf_range(0.5, 1.6))
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.2)
		# double-pulse flicker
		var f := _flash * (0.6 + 0.4 * sin(_flash * 40.0))
		world.sky_mat.set_shader_parameter("flash", f)
		world.env.ambient_light_energy += f * 0.6
	if _thunder_t > 0.0:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			SFX.play("explosion", -20.0, 0.32)
