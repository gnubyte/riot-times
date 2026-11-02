extends Node3D
# A lingering hazard: molotov fire (burns everything, vampires most) or bloater gas
# (spreads the Rot to anyone without a gas mask; the dead don't mind).

class_name FireZone

var radius := 3.5
var life := 8.0
var gas := false
var owner_node: Node = null
var _tick := 0.0
var _light: OmniLight3D

func _ready() -> void:
	var col := Color(0.45, 0.9, 0.25, 0.55) if gas else Color(1.0, 0.55, 0.15, 1.0)
	if not Combat.low_fx():
		var p := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius * 0.8
		pm.direction = Vector3.UP
		pm.spread = 25.0
		pm.gravity = Vector3(0, 1.2 if not gas else 0.15, 0)
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 1.6 if not gas else 0.5
		pm.scale_min = 0.3 if not gas else 1.2
		pm.scale_max = 0.8 if not gas else 2.4
		pm.color = col
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.9))
		ramp.set_color(1, Color(1, 1, 1, 0))
		var rt := GradientTexture1D.new()
		rt.gradient = ramp
		pm.color_ramp = rt
		p.process_material = pm
		p.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(1, 1, 1, 1)), not gas)
		p.amount = 40 if not gas else 26
		p.lifetime = 0.9 if not gas else 3.0
		add_child(p)
		p.position.y = 0.2
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2) if not gas else Color(0.4, 0.9, 0.3)
	_light.omni_range = radius * 2.5
	_light.light_energy = 2.2 if not gas else 0.6
	_light.position.y = 0.6
	add_child(_light)
	if not gas:
		SFX.play_3d("fire", global_position, -4.0, 1.0, 40.0)

func _physics_process(delta: float) -> void:
	life -= delta
	if not gas:
		_light.light_energy = 2.2 * randf_range(0.7, 1.15) * clampf(life, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.3
	for m in get_tree().get_nodes_in_group("monsters"):
		if not m.is_targetable():
			continue
		if (m as Node3D).global_position.distance_to(global_position) <= radius:
			if gas:
				if m.faction != "undead":
					m.take_hit({"dmg": 4.0, "pos": m.aim_point(false), "dir": Vector3.UP, "element": "", "source": "gas", "head_mul": 1.0, "force": 0.0})
			else:
				m.ignite(3.0, owner_node)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.dead and player.in_vehicle == null:
		var d := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
		if d <= radius and absf(player.global_position.y - global_position.y) < 2.5:
			if gas:
				if not GameData.derived().gas_mask and GameData.form != "zombie":
					GameData.take_damage(2.0, "toxic gas", global_position, "gas")
			else:
				GameData.take_damage(3.5 * (1.8 if GameData.form == "vampire" else 1.0), "fire", global_position)
	if not gas and randf() < 0.3:
		Hearing.emit_noise(global_position, 12.0, "fire", false)
