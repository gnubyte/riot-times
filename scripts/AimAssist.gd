class_name AimAssist
extends RefCounted
# Controller aim assist, the three layers modern shooters use:
#   1. slowdown  — look speed drops while the reticle is on/near a target
#   2. tracking  — when you or the target move, the camera follows the target's
#                  apparent motion (the "sticky" rotational assist)
#   3. ADS snap  — pulling the left trigger eases the reticle onto a target in a cone
# Head bias: if the reticle is closer to the head than the chest, it tracks the head.

var target: Node3D = null
var slowdown := 1.0
var _last_err := Vector2.ZERO
var _has_last := false
var _snap_t := 0.0
var _scan_t := 0.0

func begin_snap() -> void:
	_snap_t = 0.18

func reset() -> void:
	target = null
	_has_last = false
	slowdown = 1.0

# Returns (yaw, pitch) radians to add this frame.
func update(cam: Camera3D, delta: float, ads_t: float, max_range: float, moving: bool, stick_active: bool, strength: float) -> Vector2:
	_scan_t -= delta
	if _scan_t <= 0.0 or target == null or not is_instance_valid(target) or not target.call("is_targetable"):
		_scan_t = 0.08
		var best := _acquire(cam, max_range, lerpf(8.0, 10.0, ads_t))
		if best != target:
			_has_last = false
			target = best
	if target == null or not is_instance_valid(target):
		target = null
		slowdown = 1.0
		_snap_t = 0.0
		return Vector2.ZERO
	var err := _err_to(cam, _aim_point(cam, target))
	var ang := err.length()
	var cone := deg_to_rad(lerpf(8.0, 10.0, ads_t))
	if ang > cone * 1.4:
		reset()
		return Vector2.ZERO
	var inner := deg_to_rad(lerpf(4.5, 3.2, ads_t))
	var k := clampf(1.0 - ang / inner, 0.0, 1.0)
	slowdown = lerpf(1.0, lerpf(0.6, 0.4, ads_t), k * strength)
	var rot := Vector2.ZERO
	if _has_last and (moving or stick_active):
		rot += (err - _last_err) * lerpf(0.42, 0.62, ads_t) * strength
	if moving or stick_active:
		var pull := clampf(1.0 - ang / cone, 0.0, 1.0)
		rot += err * clampf(delta * lerpf(1.3, 2.4, ads_t), 0.0, 0.2) * pull * strength
	if _snap_t > 0.0:
		_snap_t -= delta
		rot += err * clampf(delta * 14.0, 0.0, 1.0) * 0.85 * strength
	_last_err = err - rot
	_has_last = true
	return rot

func _acquire(cam: Camera3D, max_range: float, cone_deg: float) -> Node3D:
	var fwd := -cam.global_transform.basis.z
	var origin := cam.global_position
	var cands := []
	for m in cam.get_tree().get_nodes_in_group("monsters"):
		if not m.call("is_targetable"):
			continue
		var p: Vector3 = m.call("aim_point", false)
		var to := p - origin
		var dist := to.length()
		if dist > max_range or dist < 0.5:
			continue
		var ang := rad_to_deg(fwd.angle_to(to / dist))
		if ang > cone_deg:
			continue
		cands.append([ang + dist * 0.03, m, p])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var space := cam.get_world_3d().direct_space_state
	for i in mini(3, cands.size()):
		var q := PhysicsRayQueryParameters3D.create(origin, cands[i][2], 1 | 2)
		if space.intersect_ray(q).is_empty():
			return cands[i][1]
	return null

func _aim_point(cam: Camera3D, m: Node3D) -> Vector3:
	var chest: Vector3 = m.call("aim_point", false)
	var head: Vector3 = m.call("aim_point", true)
	var fwd := -cam.global_transform.basis.z
	var o := cam.global_position
	if fwd.angle_to((head - o).normalized()) < fwd.angle_to((chest - o).normalized()):
		return head
	return chest

static func _err_to(cam: Camera3D, p: Vector3) -> Vector2:
	var l := cam.global_transform.affine_inverse() * p
	var yaw := atan2(-l.x, -l.z)
	var pitch := atan2(l.y, Vector2(l.x, l.z).length())
	return Vector2(yaw, pitch)
