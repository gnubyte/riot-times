extends Node3D
# Ray-stepped projectiles with gravity: crossbow bolts (recoverable), Goliath's
# thrown debris. Hits monsters, the player, vehicles or sticks into the world.

class_name Projectile

var kind := "bolt"
var vel := Vector3.ZERO
var info := {}
var owner_node: Node = null
var life := 6.0
var gravity := 5.0
var _mesh: Node3D

func setup(k: String, pos: Vector3, v: Vector3, inf: Dictionary) -> void:
	kind = k
	position = pos
	vel = v
	info = inf
	if kind == "rock":
		gravity = 14.0

func _ready() -> void:
	_mesh = Node3D.new()
	add_child(_mesh)
	if kind == "bolt":
		Viewmodels.cyl(_mesh, 0.006, 0.5, Vector3.ZERO, Viewmodels.mat("shaft", Color(0.3, 0.3, 0.3), 0.6, 0.4))
		Viewmodels.cyl(_mesh, 0.012, 0.04, Vector3(0, 0, -0.27), Viewmodels.mat("steel", Color(0.16, 0.165, 0.18), 0.85, 0.38), true, 0.0)
		Viewmodels.box(_mesh, Vector3(0.002, 0.03, 0.06), Vector3(0, 0.0, 0.22), Viewmodels.mat("fletch", Color(0.8, 0.2, 0.15), 0.0, 0.8))
	else:
		var mi := Viewmodels.box(_mesh, Vector3(0.7, 0.55, 0.6), Vector3.ZERO, Viewmodels.mat("rubble", Color(0.45, 0.43, 0.4), 0.0, 0.9))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_orient()

func _orient() -> void:
	if vel.length() > 0.1:
		var up := Vector3.UP if absf(vel.normalized().y) < 0.98 else Vector3.RIGHT
		look_at(global_position + vel, up)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	vel.y -= gravity * delta
	var from := global_position
	var to := from + vel * delta
	var mask := 1 | 2 | 4 | 32
	if kind == "rock":
		mask = 1 | 2 | 32 | 64
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	if owner_node is CollisionObject3D:
		q.exclude = [(owner_node as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		_orient()
		if kind == "rock":
			_mesh.rotate_x(delta * 6.0)
		return
	var col: Object = hit.collider
	var dir := vel.normalized()
	if kind == "rock":
		if col is Player:
			GameData.take_damage(float(info.get("dmg", 40.0)), "flying debris", from)
		Combat.impact(hit.position, hit.normal, "concrete")
		SFX.play_3d("slam", hit.position, -4.0, 1.4, 60.0)
		queue_free()
		return
	if col is Node and (col as Node).is_in_group("monsters"):
		var inf := info.duplicate()
		inf["pos"] = hit.position
		inf["dir"] = dir
		var res: Dictionary = col.take_hit(inf)
		if owner_node is Player and not res.is_empty():
			(owner_node as Player)._on_hit_result(res, hit.position, col)
		if inf.get("stake", false) and col.faction == "undead":
			Combat.explode(hit.position, 2.5, float(inf.dmg) * 0.5, owner_node, {"small": true})
		SFX.play_3d("hit_flesh", hit.position, -6.0, 1.0, 20.0)
		queue_free()
		return
	Combat.impact(hit.position, hit.normal, Combat.surface_of(col))
	# stuck bolts can be pulled back out
	if randf() < 0.7 and col is StaticBody3D:
		var lp := LootPickup.new()
		lp.entry = {"id": "bolts", "count": 1}
		lp.freeze_on_spawn = true
		get_parent().add_child(lp)
		lp.global_position = hit.position - dir * 0.2
	queue_free()
