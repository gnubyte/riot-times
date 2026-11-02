extends Node
# Hearing (autoload): everything loud is heard. Monsters within (radius x their
# hearing) react — zombies shamble over, hordes converge, and the Gaunt comes at a
# sprint. Sound carries half as far through floors (surface <-> mall <-> sub-level).

signal noise_made(pos: Vector3, radius: float, kind: String)

var player_noise := 0.0   # loudest recent player noise radius (HUD meter), decays

func emit_noise(pos: Vector3, radius: float, kind := "", from_player := false) -> void:
	if radius <= 0.0:
		return
	if from_player:
		player_noise = maxf(player_noise, radius)
	noise_made.emit(pos, radius, kind)
	var reach := radius * 1.7
	var r2 := reach * reach
	for m in get_tree().get_nodes_in_group("monsters"):
		var n := m as Node3D
		if n == null:
			continue
		var d2 := n.global_position.distance_squared_to(pos)
		if d2 > r2:
			continue
		var r := radius
		if absf(n.global_position.y - pos.y) > 5.0:
			r *= 0.5
		var d := sqrt(d2)
		if d <= r * 1.7:
			m.hear(pos, r, d, kind)

func _process(delta: float) -> void:
	player_noise = maxf(0.0, player_noise - 35.0 * delta)
