extends RigidBody3D
# Thrown gear: Frag (fused), Molotov (bursts into fire on impact), Noisemaker
# (beeps loudly to lure the dead, then pops).

class_name Throwable

var kind := "frag"
var owner_node: Node = null
var t := 0.0
var landed := false
var _beep_t := 0.0
var _led: MeshInstance3D = null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 2 | 32
	mass = 0.6
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.07
	cs.shape = sh
	add_child(cs)
	match kind:
		"frag":
			var g := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.055
			sm.height = 0.11
			g.mesh = sm
			g.material_override = Viewmodels.mat("frag", Color(0.25, 0.3, 0.2), 0.3, 0.6)
			add_child(g)
		"molotov":
			Viewmodels.cyl(self, 0.035, 0.16, Vector3.ZERO, Viewmodels.mat("bottle", Color(0.35, 0.5, 0.25), 0.2, 0.15), false)
			Viewmodels.box(self, Vector3(0.04, 0.06, 0.04), Vector3(0, 0.11, 0), Viewmodels.mat("flame", Color(1.0, 0.55, 0.1), 0.0, 1.0, 4.0))
		_:
			Viewmodels.box(self, Vector3(0.08, 0.05, 0.11), Vector3.ZERO, Viewmodels.mat("noisebox", Color(0.75, 0.62, 0.1), 0.3, 0.5))
			_led = Viewmodels.box(self, Vector3(0.018, 0.018, 0.018), Vector3(0, 0.03, 0.03), Viewmodels.mat("led", Color(1, 0.1, 0.1), 0.0, 0.5, 5.0))
	for c in get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	t += delta
	match kind:
		"frag":
			if t >= 2.3:
				Combat.explode(global_position + Vector3(0, 0.2, 0), 7.5, 150.0, owner_node)
				queue_free()
		"molotov":
			if t > 6.0:
				_burst()
		"noisemaker":
			if landed:
				_beep_t -= delta
				if _beep_t <= 0.0:
					_beep_t = 0.45
					SFX.play_3d("beep", global_position, 2.0, 1.0, 70.0)
					Hearing.emit_noise(global_position, 55.0, "lure", false)
					if _led != null:
						_led.visible = not _led.visible
				if t >= 7.5:
					Combat.explode(global_position + Vector3(0, 0.2, 0), 4.5, 90.0, owner_node, {"small": true})
					queue_free()

func _on_body(_b: Node) -> void:
	if kind == "molotov" and t > 0.04:
		_burst()
		return
	if not landed:
		landed = true
		SFX.play_3d("hit_metal", global_position, -14.0, 0.7, 25.0)

func _burst() -> void:
	if is_queued_for_deletion():
		return
	SFX.play_3d("glass", global_position, -2.0, 1.0, 50.0)
	Combat.fire_zone(global_position, 3.8, 8.0, owner_node)
	queue_free()
