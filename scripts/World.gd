extends Node3D
# Procedurally builds the dusty post-nuclear settlement: terrain, buildings,
# a ruined bridge over a glowing river, props, containers, enemies, radiation zones.

class_name World

var rng := RandomNumberGenerator.new()
var world_root: Node3D
var player: Player
var spawn_points: Array[Vector3] = []
var rad_zones: Array[Dictionary] = []   # {pos, radius, rate}
var enemy_spawns: Array[Dictionary] = []
var respawn_point := Vector3(0, 0.2, 8)

func _ready() -> void:
	rng.seed = 1337
	add_to_group("world_root")
	_build_environment()
	_build_ground()
	_build_river_and_bridge()
	_build_settlement()
	_build_props()
	_spawn_containers()
	_spawn_ammo_caches()
	_spawn_enemies()
	_build_player()
	_build_weapons_training_dummy()
	_ensure_tangents()

# Normal-mapped StandardMaterial3Ds need tangents; primitive meshes built at runtime
# don't carry them — rebuild them via SurfaceTool once at world load.
func _ensure_tangents() -> void:
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D
			if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
			if mat != null and mat.normal_enabled and mi.mesh != null and mi.mesh.get_surface_count() > 0:
				var arr := mi.mesh.surface_get_arrays(0)
				var tan = arr[Mesh.ARRAY_TANGENT] if arr.size() > Mesh.ARRAY_TANGENT else null
				if tan == null or tan.is_empty():
					var st := SurfaceTool.new()
					st.create_from(mi.mesh, 0)
					var nrm = arr[Mesh.ARRAY_NORMAL] if arr.size() > Mesh.ARRAY_NORMAL else null
					if nrm == null or nrm.is_empty():
						st.generate_normals()
					st.generate_tangents()
					var new_mesh := st.commit()
					if new_mesh != null:
						mi.mesh = new_mesh

# Scavengable ammunition: seeded ammo cans scattered around the map, plus loose
# shells on the ground near fighting spots. The player must hunt for resupply.
func _spawn_ammo_caches() -> void:
	var spots := [
		Vector3(10.5, 0.2, -15.8),   # behind building 1
		Vector3(31, 0.2, -16),       # between buildings 2-3
		Vector3(2.2, 0.2, 17.5),     # west of the south row
		Vector3(35, 0.2, 24.5),      # behind building 5
		Vector3(48.5, 0.2, 22),      # east side
		Vector3(54, 0.2, -12),       # near bridge approach
		Vector3(69.5, 0.2, -2),      # far side of the river
		Vector3(76, 0.2, 10),        # far camp
		Vector3(-14, 0.2, -20),      # deep west ruins
		Vector3(-30, 0.2, 26),       # northwest
		Vector3(20, 0.2, 38),        # south field
		Vector3(44, 0.2, -34),       # northeast wastes
	]
	for p in spots:
		var it := Interactable.new()
		add_child(it)
		var pos: Vector3 = p
		pos.y += _terrain_height(pos.x, pos.z, false)
		it.setup("ammo_cache", pos, self)
	# loose shell piles: instant-reserve loot pickups (no interact needed beyond E)
	var loose := [
		["ammo_10mm", 8, Vector3(16, 0.25, -10.2)],
		["ammo_10mm", 6, Vector3(40.8, 0.25, -13.2)],
		["ammo_rifle", 5, Vector3(49.8, 0.25, -6.2)],
		["energy_cell", 4, Vector3(3.8, 0.25, 22.2)],
		["ammo_10mm", 10, Vector3(56.5, 0.25, 5.2)],
		["energy_cell", 5, Vector3(77.5, 0.25, -4.5)],
	]
	for e in loose:
		var lp := LootPickup.new()
		add_child(lp)
		var pos: Vector3 = e[2]
		pos.y += _terrain_height(pos.x, pos.z, false)
		lp.global_position = pos
		lp.setup(e[0], e[1])

func _env(node: Node3D) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var prog := ProceduralSkyMaterial.new()
	prog.sky_top_color = Color(0.18, 0.14, 0.30)
	prog.sky_horizon_color = Color(0.95, 0.55, 0.22)
	prog.ground_bottom_color = Color(0.22, 0.16, 0.10)
	prog.ground_horizon_color = Color(0.95, 0.55, 0.22)
	prog.sun_angle_max = 32.0
	prog.sun_curve = 0.12
	prog.sky_energy_multiplier = 1.15
	sky.sky_material = prog
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.fog_light_color = Color(0.85, 0.62, 0.38)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.06
	env.fog_aerial_perspective = 0.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.18
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 55, 0)
	sun.light_color = Color(1.0, 0.82, 0.58)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.8
	add_child(sun)

func _mat(key: String, color := Color(1, 1, 1), rough := 0.92, metal := 0.0, uv := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Proc.tex(key)
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.uv1_scale = Vector3(uv, uv, uv)
	# generated normal maps give real surface depth to every surface
	var nm := Proc.normal_tex(key)
	if nm != null:
		m.normal_enabled = true
		m.normal_texture = nm
		m.normal_scale = 1.4
	return m

func _box(size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, static_body := true) -> Node3D:
	if static_body:
		var sb := StaticBody3D.new()
		sb.collision_layer = 2
		sb.collision_mask = 0
		sb.position = pos
		sb.rotation = rot
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = size
		mi.mesh = bm; mi.material_override = mat
		sb.add_child(mi)
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new(); cs.size = size
		col.shape = cs
		sb.add_child(col)
		add_child(sb)
		return sb
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = size
		mi.mesh = bm; mi.material_override = mat
		mi.position = pos; mi.rotation = rot
		add_child(mi)
		return mi

func _cyl(r: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 2
	sb.position = pos; sb.rotation = rot
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h
	mi.mesh = cm; mi.material_override = mat
	sb.add_child(mi)
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new(); cs.radius = r; cs.height = h
	col.shape = cs
	sb.add_child(col)
	add_child(sb)
	return sb

func _build_environment() -> void:
	_env(self)

func _terrain_height(wx: float, wz: float, noise := true) -> float:
	var d := Vector2(wx, wz).length()
	# river trench
	if absf(wx - 62.0) < 8.0 and absf(wz) < 128.0:
		return -3.4
	var edge := 1.0
	if absf(wx - 62.0) < 20.0: edge = 0.3   # flatten banks
	var h := 0.0
	if d > 55.0:
		h = (sin(wx * 0.08) + cos(wz * 0.07)) * 1.6 * clampf((d - 55.0) / 40.0, 0.0, 1.0) * edge
		if noise: h += randf_range(0.0, 0.35) * edge
	elif d > 42.0:
		if noise: h = randf_range(0.0, 0.15)
	return h

func _build_ground() -> void:
	rng.seed = 9001
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	add_child(ground)
	var mi := MeshInstance3D.new()
	var verts := PackedVector3Array()
	var idxs := PackedInt32Array()
	var uvs := PackedVector2Array()
	var n := 120
	var sz := 360.0
	for z in n + 1:
		for x in n + 1:
			var wx := -sz / 2.0 + sz * x / n
			var wz := -sz / 2.0 + sz * z / n
			var h := _terrain_height(wx, wz)
			verts.append(Vector3(wx, h, wz))
			uvs.append(Vector2(x * 0.4, z * 0.4))
	for z in n:
		for x in n:
			var a := z * (n + 1) + x
			idxs.append(a); idxs.append(a + 1); idxs.append(a + n + 2)
			idxs.append(a); idxs.append(a + n + 2); idxs.append(a + n + 1)
	var arrays := Array()
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idxs
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(0, _mat("dust", Color(0.95, 0.85, 0.68), 0.95, 0.0, 0.12))
	mi.mesh = am
	ground.add_child(mi)
	var col := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(_triangles_from(verts, idxs))
	col.shape = sh
	ground.add_child(col)

func _triangles_from(verts: PackedVector3Array, idxs: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in idxs.size():
		out.append(verts[idxs[i]])
	return out

func _build_river_and_bridge() -> void:
	# riverbed trench along x = 62 (runs north-south), water surface lower
	_box(Vector3(26, 0.4, 260), _mat("dust", Color(0.5, 0.45, 0.3)), Vector3(62, -3.4, 0), Vector3.ZERO, false)
	# water — animated toxic shader water with vertex waves
	var water := MeshInstance3D.new()
	var wm := PlaneMesh.new(); wm.size = Vector2(22, 258)
	wm.subdivide_width = 40
	wm.subdivide_depth = 160
	water.mesh = wm
	var wmat := Shaders.water_material()
	water.material_override = wmat
	water.position = Vector3(62, -1.6, 0)
	add_child(water)
	animated_water = water
	# radiation in the river
	rad_zones.append({"pos": Vector3(62, 0, 0), "radius": 14.0, "rate": 3.5, "trench": true})
	# bridge deck spanning the river along X
	var deck := _mat("concrete", Color(0.7, 0.7, 0.68))
	_box(Vector3(26, 0.6, 9), deck, Vector3(62, -0.3, 6))
	# rails (broken)
	_box(Vector3(8, 1.1, 0.5), deck, Vector3(51, 0.55, 1.7))
	_box(Vector3(7, 1.1, 0.5), deck, Vector3(65, 0.55, 10.3))
	# piers in the river
	for i in 3:
		_cyl(1.1, 5.0, _mat("concrete", Color(0.6, 0.6, 0.58)), Vector3(62, -1.4, -6 + i * 12))
	# collapsed span pieces in water
	_box(Vector3(4, 0.5, 6), deck, Vector3(61, -2.4, -8), Vector3(0.3, 0.2, 0.1), false)
	_bridge_lamps()

var animated_water: MeshInstance3D = null
var bridge_lamps: Array[OmniLight3D] = []
var dust_particles: GPUParticles3D = null

func _bridge_lamps() -> void:
	for i in 4:
		var pole := _cyl(0.12, 4.2, _mat("rusty_metal", Color(0.5, 0.5, 0.5), 0.6, 0.8), Vector3(52 + i * 5, 2.1, 1.7))
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.75, 0.4)
		lamp.omni_range = 7.0
		lamp.light_energy = 0.8
		lamp.position = Vector3(0, 2.2, 0)
		pole.add_child(lamp)
		bridge_lamps.append(lamp)
		var bulb := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.18; sm.height = 0.36
		bulb.mesh = sm
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(1, 0.9, 0.6)
		bm.emission_enabled = true; bm.emission = Color(1, 0.8, 0.4); bm.emission_energy_multiplier = 3.0
		bulb.material_override = bm
		bulb.position = Vector3(0, 2.2, 0)
		pole.add_child(bulb)

func _build_settlement() -> void:
	# central plaza road (cobble)
	_box(Vector3(70, 0.08, 12), _mat("cobble", Color(0.9, 0.85, 0.75)), Vector3(24, 0.04, 6), Vector3.ZERO, false)
	# sign
	_build_sign(Vector3(14, 0, -6), "RIOT TIMES")
	# buildings around plaza
	var wall_mats := [_mat("plaster", Color(1.0, 0.9, 0.78)), _mat("concrete", Color(0.85, 0.82, 0.78)), _mat("corrugated", Color(0.8, 0.75, 0.7), 0.7, 0.6), _mat("wood", Color(0.9, 0.8, 0.7))]
	var roof_mat := _mat("rusty_metal", Color(0.75, 0.6, 0.5), 0.85, 0.4)
	var layout := [
		{"pos": Vector3(4, 0, -12), "size": Vector3(10, 4.5, 8), "door": "z+"},
		{"pos": Vector3(20, 0, -14), "size": Vector3(12, 5.0, 9), "door": "z+"},
		{"pos": Vector3(38, 0, -12), "size": Vector3(9, 4.0, 8), "door": "z+"},
		{"pos": Vector3(6, 0, 20), "size": Vector3(11, 4.6, 8), "door": "z-"},
		{"pos": Vector3(26, 0, 22), "size": Vector3(10, 4.2, 9), "door": "z-"},
		{"pos": Vector3(44, 0, 18), "size": Vector3(12, 5.2, 10), "door": "x-"},
		{"pos": Vector3(52, 0, -8), "size": Vector3(8, 4.0, 8), "door": "x-"},
	]
	var bi := 0
	for b in layout:
		_build_building(b.pos, b.size, wall_mats[bi % wall_mats.size()], roof_mat, b.door)
		bi += 1
	# watchtower near bridge
	_build_tower(Vector3(50, 0, 2))
	# shanty shacks
	for i in 6:
		var ang := rng.randf_range(0, TAU)
		var rad := rng.randf_range(28, 44)
		var p := Vector3(24 + cos(ang) * rad, 0, 4 + sin(ang) * rad * 0.6)
		_box(Vector3(rng.randf_range(2.5, 4), rng.randf_range(2.2, 3), rng.randf_range(2.5, 4)), wall_mats[i % wall_mats.size()], p, Vector3(0, rng.randf_range(0, 1), 0))
	spawn_points.append(Vector3(8, 0.3, 8))
	spawn_points.append(Vector3(24, 0.3, 8))
	spawn_points.append(Vector3(30, 0.3, -4))
	respawn_point = Vector3(24, 0.3, 8)

func _build_sign(pos: Vector3, text: String) -> void:
	for side in [-1.0, 1.0]:
		_cyl(0.12, 4.0, _mat("rusty_metal", Color(0.5, 0.5, 0.5), 0.6, 0.9), pos + Vector3(side * 2.6, 2, 0))
	var panel := _box(Vector3(6, 1.6, 0.2), _mat("corrugated", Color(0.7, 0.4, 0.2)), pos + Vector3(0, 3.4, 0))
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 190
	lbl.outline_size = 12
	lbl.modulate = Color(1, 0.85, 0.3)
	lbl.position = Vector3(0, 0, 0.14)
	panel.add_child(lbl)
	var lbl2 := Label3D.new()
	lbl2.text = "STILL STANDING"
	lbl2.font_size = 90
	lbl2.outline_size = 8
	lbl2.modulate = Color(0.95, 0.9, 0.8)
	lbl2.position = Vector3(0, -0.4, 0.14)
	panel.add_child(lbl2)

func _build_building(pos: Vector3, size: Vector3, wall: StandardMaterial3D, roof: StandardMaterial3D, door_side: String) -> void:
	var h := size.y
	var w := size.x
	var dp := 1.4 # doorway width
	# walls as 4 boxes, one split for doorway
	var t := 0.3
	# north wall (z-)
	_wall(Vector3(w, h, t), wall, pos + Vector3(0, h / 2, -size.z / 2), door_side == "z-")
	_wall(Vector3(w, h, t), wall, pos + Vector3(0, h / 2, size.z / 2), door_side == "z+")
	_wall(Vector3(t, h, size.z), wall, pos + Vector3(-w / 2, h / 2, 0), door_side == "x-")
	_wall(Vector3(t, h, size.z), wall, pos + Vector3(w / 2, h / 2, 0), door_side == "x+")
	# roof + parapet
	_box(Vector3(w + 0.4, 0.28, size.z + 0.4), roof, pos + Vector3(0, h + 0.14, 0))
	_parapet(pos, size, wall)
	# swinging door leaf in the doorway
	_door_leaf(pos, size, door_side)
	# windows: frame + glowing or boarded glass on the front face
	for i in 2:
		if randf() < 0.5:
			continue
		_window(pos + Vector3(-w / 4 + i * w / 2.0, h * 0.55, size.z / 2 + 0.17), Vector3(1.1, 1.0, 0.08))
	# rooftop clutter
	var seed_id := int(pos.x * 7 + pos.z * 13)
	if seed_id % 3 == 0:
		_water_tank(pos + Vector3(w * 0.25, h + 0.28, -size.z * 0.2))
	if seed_id % 2 == 0:
		_vent_pipe(pos + Vector3(-w * 0.3, h + 0.28, size.z * 0.25))
	if seed_id % 4 == 1:
		_antenna(pos + Vector3(w * 0.1, h + 0.28, size.z * 0.1))
	if seed_id % 5 == 2:
		_solar_dish(pos + Vector3(-w * 0.15, h + 0.3, -size.z * 0.25))

func _parapet(pos: Vector3, size: Vector3, wall: StandardMaterial3D) -> void:
	var y := size.y + 0.52
	var t := 0.22
	_box(Vector3(size.x + 0.4, 0.45, t), wall, pos + Vector3(0, y, -size.z / 2 - 0.1), Vector3.ZERO, false)
	_box(Vector3(size.x + 0.4, 0.45, t), wall, pos + Vector3(0, y, size.z / 2 + 0.1), Vector3.ZERO, false)
	_box(Vector3(t, 0.45, size.z + 0.4), wall, pos + Vector3(-size.x / 2 - 0.1, y, 0), Vector3.ZERO, false)
	_box(Vector3(t, 0.45, size.z + 0.4), wall, pos + Vector3(size.x / 2 + 0.1, y, 0), Vector3.ZERO, false)

func _door_leaf(pos: Vector3, size: Vector3, side: String) -> void:
	var wood := _mat("wood", Color(0.65, 0.5, 0.35), 0.85)
	var door := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.4, 2.6, 0.09)
	door.mesh = bm
	door.material_override = wood
	var handle := MeshInstance3D.new()
	var hb := BoxMesh.new(); hb.size = Vector3(0.06, 0.06, 0.18)
	handle.mesh = hb
	handle.material_override = _mat("rusty_metal", Color(0.6, 0.6, 0.6), 0.5, 0.8)
	var hinge := Node3D.new()
	add_child(hinge)
	hinge.global_position = pos
	match side:
		"z-":
			hinge.position += Vector3(-0.7, 1.32, -size.z / 2)
			hinge.rotation.y = randf_range(-0.9, -0.35)
			door.position = Vector3(0.7, 0, 0)
		"z+":
			hinge.position += Vector3(-0.7, 1.32, size.z / 2)
			hinge.rotation.y = randf_range(0.35, 0.9)
			door.position = Vector3(0.7, 0, 0)
		"x-":
			hinge.position += Vector3(-size.x / 2, 1.32, -0.7)
			hinge.rotation.y = PI / 2 + randf_range(-0.5, 0.5)
			door.position = Vector3(0.7, 0, 0)
		_:
			hinge.position += Vector3(size.x / 2, 1.32, -0.7)
			hinge.rotation.y = -PI / 2 + randf_range(-0.5, 0.5)
			door.position = Vector3(0.7, 0, 0)
	hinge.add_child(door)
	handle.position = Vector3(1.25, 0.1, 0.08)
	door.add_child(handle)

func _window(pos: Vector3, size: Vector3) -> void:
	# frame
	var frame_mat := _mat("wood", Color(0.5, 0.4, 0.32), 0.85)
	_box(Vector3(size.x, 0.09, size.z), frame_mat, pos + Vector3(0, size.y / 2, 0), Vector3.ZERO, false)
	_box(Vector3(size.x, 0.09, size.z), frame_mat, pos + Vector3(0, -size.y / 2, 0), Vector3.ZERO, false)
	_box(Vector3(0.09, size.y, size.z), frame_mat, pos + Vector3(-size.x / 2, 0, 0), Vector3.ZERO, false)
	_box(Vector3(0.09, size.y, size.z), frame_mat, pos + Vector3(size.x / 2, 0, 0), Vector3.ZERO, false)
	# glass: glowing lamp-lit, or boarded planks
	if randf() < 0.5:
		var win := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(size.x - 0.1, size.y - 0.1, 0.05)
		win.mesh = bm
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color(0.15, 0.18, 0.22)
		wm.emission_enabled = true
		wm.emission = Color(0.55, 0.42, 0.22)
		wm.emission_energy_multiplier = randf_range(0.4, 1.6)
		win.material_override = wm
		add_child(win)
		win.global_position = pos
	else:
		var plank := _mat("wood", Color(0.55, 0.42, 0.28), 0.9)
		for i in 3:
			_box(Vector3(size.x, 0.22, 0.05), plank, pos + Vector3(0, -0.28 + i * 0.28, 0), Vector3(0, 0, randf_range(-0.06, 0.06)), false)

func _water_tank(pos: Vector3) -> void:
	var m := _mat("rusty_metal", Color(0.6, 0.55, 0.5), 0.75, 0.6)
	# legs
	for dx in [-0.3, 0.3]:
		for dz in [-0.3, 0.3]:
			_cyl(0.045, 0.6, m, pos + Vector3(dx, 0.3, dz))
	var tank := _cyl(0.55, 0.9, m, pos + Vector3(0, 1.05, 0))
	# rust patch sphere on top
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = 0.55; sm.height = 0.3
	cap.mesh = sm
	cap.material_override = _mat("rusty_metal", Color(0.5, 0.35, 0.2), 0.9, 0.4)
	cap.position = pos + Vector3(0, 1.5, 0)
	add_child(cap)

func _vent_pipe(pos: Vector3) -> void:
	var m := _mat("rusty_metal", Color(0.55, 0.55, 0.58), 0.6, 0.8)
	_cyl(0.14, 0.8, m, pos + Vector3(0, 0.4, 0))
	_cyl(0.2, 0.12, m, pos + Vector3(0, 0.86, 0))

func _antenna(pos: Vector3) -> void:
	var m := _mat("rusty_metal", Color(0.5, 0.5, 0.5), 0.6, 0.9)
	_cyl(0.035, 2.2, m, pos + Vector3(0, 1.1, 0))
	for i in 3:
		_box(Vector3(0.7 - i * 0.18, 0.025, 0.025), m, pos + Vector3(0, 1.6 + i * 0.25, 0), Vector3(0, 0, 0), false)

func _solar_dish(pos: Vector3) -> void:
	var dish := MeshInstance3D.new()
	var prm := PrismMesh.new()
	prm.size = Vector3(0.9, 0.25, 0.55)
	dish.mesh = prm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.76, 0.78)
	m.metallic = 0.7
	m.roughness = 0.4
	dish.material_override = m
	dish.rotation = Vector3(0.6, 0.4, 0)
	dish.position = pos + Vector3(0, 0.45, 0)
	add_child(dish)
	_box(Vector3(0.1, 0.4, 0.1), _mat("rusty_metal", Color(0.5, 0.5, 0.5), 0.7, 0.8), pos, Vector3.ZERO, false)

func _wall(size: Vector3, mat: Material, pos: Vector3, has_door: bool) -> void:
	if not has_door:
		_box(size, mat, pos)
		return
	# split: door in middle (1.4 wide x 2.6 tall)
	var door_w := 1.5
	var door_h := 2.7
	var side_w := (absf(size.x if size.x > size.z else size.z) - door_w) / 2.0
	if size.x > size.z:
		_box(Vector3(side_w, size.y, size.z), mat, pos + Vector3(-(door_w + side_w) / 2, 0, 0))
		_box(Vector3(side_w, size.y, size.z), mat, pos + Vector3((door_w + side_w) / 2, 0, 0))
		_box(Vector3(door_w, size.y - door_h, size.z), mat, pos + Vector3(0, (door_h - (size.y - door_h)) / 2.0, 0))
	else:
		_box(Vector3(size.x, size.y, side_w), mat, pos + Vector3(0, 0, -(door_w + side_w) / 2))
		_box(Vector3(size.x, size.y, side_w), mat, pos + Vector3(0, 0, (door_w + side_w) / 2))
		_box(Vector3(size.x, size.y - door_h, door_w), mat, pos + Vector3(0, (door_h - (size.y - door_h)) / 2, 0))

func _build_tower(pos: Vector3) -> void:
	var wood := _mat("wood", Color(0.8, 0.7, 0.6))
	for x in [-1.6, 1.6]:
		for z in [-1.6, 1.6]:
			_cyl(0.16, 7.0, wood, pos + Vector3(x, 3.5, z))
	_box(Vector3(4.2, 0.3, 4.2), wood, pos + Vector3(0, 5.4, 0))
	_box(Vector3(4.6, 0.25, 4.6), _mat("rusty_metal", Color(0.6, 0.5, 0.4)), pos + Vector3(0, 7.6, 0))
	_box(Vector3(4.2, 1.0, 0.3), wood, pos + Vector3(0, 6.1, -2.0))
	var barrel := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.height = 0.9; cm.top_radius = 0.35; cm.bottom_radius = 0.35
	barrel.mesh = cm
	barrel.position = pos + Vector3(0, 6.2, 0)
	add_child(barrel)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.5, 0.15)
	fire.omni_range = 9.0
	fire.light_energy = 1.6
	fire.position = pos + Vector3(0, 6.4, 0)
	add_child(fire)
	torches.append({"light": fire, "base": 1.6})

var torches: Array = []
var flicker_sprites: Array[MeshInstance3D] = []

func _build_props() -> void:
	var rust := _mat("rusty_metal", Color(0.8, 0.7, 0.65), 0.8, 0.6)
	# wrecked cars on the road
	for i in 4:
		var cp := Vector3(rng.randf_range(6, 48), 0.6, 6 + rng.randf_range(-3, 3))
		if cp.distance_to(Vector3(24, 0.6, 8)) < 9: continue
		_box(Vector3(2.2, 1.1, 4.4), _mat("corrugated", Color(randf_range(0.5, 0.8), 0.5, 0.42), 0.7, 0.5), cp, Vector3(0, rng.randf_range(-0.4, 0.4), 0))
		_box(Vector3(1.9, 0.7, 1.8), _mat("corrugated", Color(0.45, 0.5, 0.5), 0.5, 0.6), cp + Vector3(0, 1.2, -0.2), Vector3(0, rng.randf_range(-0.4, 0.4), 0))
	# barrels (some radioactive)
	for i in 10:
		var bp := Vector3(rng.randf_range(-30, 55), 0.6, rng.randf_range(-30, 30))
		if bp.distance_to(Vector3(24, 0, 6)) < 6: continue
		var b := _cyl(0.42, 1.2, rust, bp)
		if randf() < 0.3:
			# glowing barrel => rad zone
			var lbl := Label3D.new()
			lbl.text = "☢"
			lbl.font_size = 70
			lbl.modulate = Color(0.5, 1.0, 0.2)
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0, 1.0, 0)
			b.add_child(lbl)
			var glow := OmniLight3D.new()
			glow.light_color = Color(0.4, 1.0, 0.2)
			glow.omni_range = 4.0
			glow.light_energy = 0.9
			glow.position = Vector3(0, 0.8, 0)
			b.add_child(glow)
			rad_zones.append({"pos": bp, "radius": 3.4, "rate": 6.0, "trench": false})
	# rubble piles
	for i in 26:
		var rp := Vector3(rng.randf_range(-40, 60), 0.2, rng.randf_range(-40, 40))
		if rp.distance_to(Vector3(24, 0, 6)) < 5: continue
		for j in randi_range(2, 5):
			_box(Vector3(randf_range(0.3, 1.2), randf_range(0.2, 0.6), randf_range(0.3, 1.2)), _mat("concrete", Color(0.75, 0.72, 0.68)), rp + Vector3(randf_range(-1, 1), j * 0.12, randf_range(-1, 1)), Vector3(0, randf_range(0, 3), 0), false)
	# dead trees
	for i in 12:
		var tp := Vector3(rng.randf_range(-60, 55), 0, rng.randf_range(-60, 55))
		if tp.distance_to(Vector3(24, 0, 6)) < 14 or absf(tp.x - 62) < 16: continue
		var trunk := _cyl(0.18, randf_range(3, 5), _mat("wood", Color(0.45, 0.35, 0.3)), tp + Vector3(0, 2, 0))
		for br in 3:
			_box(Vector3(0.12, 0.12, randf_range(1.2, 2.2)), _mat("wood", Color(0.45, 0.35, 0.3)), tp + Vector3(randf_range(-0.8, 0.8), randf_range(2.2, 3.6), randf_range(-0.8, 0.8)), Vector3(randf_range(-0.6, 0.6), randf_range(0, 3), randf_range(-0.6, 0.6)), false)
	_power_lines()
	_sandbag_emplacements()
	_street_clutter()
	_campfire(Vector3(18, 0, 12))
	_campfire(Vector3(46, 0, -2))

func _power_lines() -> void:
	var pole_mat := _mat("wood", Color(0.4, 0.32, 0.24), 0.9)
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color(0.08, 0.08, 0.09)
	var poles := [Vector3(2, 0, -1.5), Vector3(18, 0, -1.5), Vector3(34, 0, -1.5), Vector3(50, 0, -1.5)]
	for p in poles:
		_cyl(0.14, 6.4, pole_mat, p + Vector3(0, 3.2, 0))
		_box(Vector3(1.6, 0.12, 0.12), pole_mat, p + Vector3(0, 5.9, 0), Vector3.ZERO, false)
		_box(Vector3(1.2, 0.12, 0.12), pole_mat, p + Vector3(0, 5.3, 0), Vector3.ZERO, false)
	for i in range(poles.size() - 1):
		var a: Vector3 = poles[i] + Vector3(0, 6.0, 0)
		var b: Vector3 = poles[i + 1] + Vector3(0, 5.85, 0)
		_sagging_wire(a, b, wire_mat, 0.55)
		_sagging_wire(a + Vector3(0, -0.6, 0), b + Vector3(0, -0.6, 0), wire_mat, 0.7)
	# one snapped pole leaning near the bridge
	var lean := _cyl(0.14, 5.0, pole_mat, Vector3(54, 1.4, -3.5))
	lean.rotation.z = 0.9
	lean.rotation.y = 0.4

func _sagging_wire(a: Vector3, b: Vector3, mat: Material, sag: float) -> void:
	var segs := 8
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := a.lerp(b, t0) + Vector3(0, -4.0 * sag * t0 * (1.0 - t0), 0)
		var p1 := a.lerp(b, t1) + Vector3(0, -4.0 * sag * t1 * (1.0 - t1), 0)
		var mid := (p0 + p1) * 0.5
		var ln := p0.distance_to(p1)
		var box := _box(Vector3(0.035, 0.035, ln + 0.03), mat, mid, Vector3.ZERO, false)
		box.look_at_from_position(mid, p1, Vector3.UP)

func _sandbag_emplacements() -> void:
	var bag := _mat("sandbag", Color(0.9, 0.85, 0.7), 0.95)
	var spots := [
		{"pos": Vector3(55, 0, 8.5), "n": 5, "rot": 0.0},
		{"pos": Vector3(55, 0, 3.5), "n": 5, "rot": 0.0},
		{"pos": Vector3(70, 0, 9.5), "n": 4, "rot": 0.2},
		{"pos": Vector3(43, 0, -5.5), "n": 4, "rot": 1.4},
	]
	for s in spots:
		var base: Vector3 = s.pos
		var rot: float = s.rot
		for row in 3:
			for i in int(s.n):
				var off := (float(i) - (int(s.n) - 1) * 0.5) * 0.62
				var p := base + Vector3(off, 0.17 + row * 0.33, (randf() - 0.5) * 0.12)
				var wob := Vector3(0, rot + randf_range(-0.08, 0.08), randf_range(-0.05, 0.05))
				_box(Vector3(0.62, 0.3, 0.34), bag, p, wob)

func _street_clutter() -> void:
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.1, 0.09, 0.09)
	rubber.roughness = 1.0
	for i in 7:
		var p := Vector3(rng.randf_range(0, 55), 0.16, rng.randf_range(0, 12) + (2 if i % 2 == 0 else -2))
		if p.distance_to(Vector3(24, 0, 6)) < 4: continue
		var t := _cyl(0.34, 0.16, rubber, p)
		t.rotation.x = PI / 2 if randf() < 0.4 else 0
		t.rotation.z = randf_range(0, PI)
	# shopping-cart-ish scrap cart on the road
	var c := Vector3(30, 0, 6.6)
	var m2 := _mat("rusty_metal", Color(0.6, 0.6, 0.62), 0.5, 0.9)
	_box(Vector3(0.9, 0.55, 1.3), m2, c + Vector3(0, 0.65, 0), Vector3(0, 0.3, 0), false)
	_box(Vector3(0.06, 0.8, 0.06), m2, c + Vector3(0.5, 1.1, -0.6), Vector3(0.3, 0.3, 0), false)
	for w in [Vector3(-0.4, 0.18, -0.5), Vector3(0.4, 0.18, -0.5), Vector3(-0.4, 0.18, 0.5), Vector3(0.4, 0.18, 0.5)]:
		_cyl(0.16, 0.1, rubber, c + w)
	# traffic cone toppled
	_box(Vector3(0.35, 0.35, 0.4), _mat("concrete", Color(0.85, 0.35, 0.1)), Vector3(27, 0.18, 9.2), Vector3(1.5, 0.6, 0), false)

func _campfire(pos: Vector3) -> void:
	if OS.get_environment("RT_NO_PARTICLES") == "1":
		return
	# ring of stones
	for i in 8:
		var a := TAU * i / 8.0
		_box(Vector3(0.3, 0.2, 0.3), _mat("concrete", Color(0.5, 0.48, 0.45)), pos + Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(0, a, 0), false)
	# logs
	var logm := _mat("wood", Color(0.3, 0.2, 0.12), 0.95)
	_cyl(0.07, 0.8, logm, pos + Vector3(0, 0.12, 0), Vector3(0, 0.4, PI / 2.4))
	_cyl(0.07, 0.8, logm, pos + Vector3(0, 0.14, 0), Vector3(PI / 2.4, 1.1, 0))
	# flame billboards (animated quads)
	for i in 3:
		var flame := MeshInstance3D.new()
		var pm := QuadMesh.new()
		pm.size = Vector2(0.34, 0.5) - Vector2(0.08, 0.12) * i
		flame.mesh = pm
		var fm := StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.vertex_color_use_as_albedo = true
		fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var col := Color(1.0, 0.6, 0.15, 0.85) if i == 0 else (Color(1.0, 0.8, 0.3, 0.7) if i == 1 else Color(1.0, 0.95, 0.6, 0.5))
		fm.albedo_color = col
		fm.emission_enabled = true
		fm.emission = col
		fm.emission_energy_multiplier = 1.0
		flame.material_override = fm
		flame.position = pos + Vector3(randf_range(-0.1, 0.1), 0.5 + i * 0.12, randf_range(-0.1, 0.1))
		add_child(flame)
		flicker_sprites.append(flame)
	# point light
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.18)
	light.omni_range = 8.0
	light.light_energy = 1.5
	light.position = pos + Vector3(0, 0.7, 0)
	add_child(light)
	torches.append({"light": light, "base": 1.5})
	# rising embers + thin smoke
	if OS.get_environment("RT_NO_PARTICLES") != "1":
		var emb := GPUParticles3D.new()
		var epm := ParticleProcessMaterial.new()
		epm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		epm.emission_sphere_radius = 0.25
		epm.direction = Vector3(0, 1, 0)
		epm.spread = 18.0
		epm.gravity = Vector3(0, 0.6, 0)
		epm.initial_velocity_min = 0.8
		epm.initial_velocity_max = 1.8
		epm.scale_min = 0.03
		epm.scale_max = 0.07
		epm.color = Color(1.0, 0.6, 0.2)
		emb.process_material = epm
		emb.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(1, 0.75, 0.3, 1)))
		emb.amount = 24
		emb.lifetime = 1.6
		emb.position = pos + Vector3(0, 0.5, 0)
		add_child(emb)
		var sm := GPUParticles3D.new()
		var spm := ParticleProcessMaterial.new()
		spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		spm.emission_sphere_radius = 0.2
		spm.direction = Vector3(0.15, 1, 0)
		spm.spread = 8.0
		spm.gravity = Vector3.ZERO
		spm.initial_velocity_min = 0.5
		spm.initial_velocity_max = 1.0
		spm.scale_min = 0.15
		spm.scale_max = 0.45
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.45, 0.42, 0.38, 0.10))
		ramp.set_color(1, Color(0.35, 0.33, 0.3, 0.0))
		var ramp_tex := GradientTexture1D.new()
		ramp_tex.gradient = ramp
		spm.color_ramp = ramp_tex
		sm.process_material = spm
		sm.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(0.55, 0.52, 0.48, 0.28)), false)
		sm.amount = 14
		sm.lifetime = 3.5
		sm.position = pos + Vector3(0, 0.8, 0)
		add_child(sm)

func _spawn_containers() -> void:
	var spots := [
		{"kind": "crate", "pos": Vector3(6, 0.35, -7.4)},
		{"kind": "crate", "pos": Vector3(22, 0.35, -9.0)},
		{"kind": "locker", "pos": Vector3(16, 0.01, -11.0)},   # inside building 2
		{"kind": "fridge", "pos": Vector3(3.0, 0.01, -13.5)},   # inside building 1
		{"kind": "crate", "pos": Vector3(9.0, 0.35, -14.5)},
		{"kind": "locker", "pos": Vector3(40.5, 0.01, -14.0)},
		{"kind": "fridge", "pos": Vector3(24.0, 0.01, 19.0)},   # inside building 5
		{"kind": "crate", "pos": Vector3(8.0, 0.35, 17.0)},
		{"kind": "weapons_stash", "pos": Vector3(3.0, 0.35, 23.0)}, # inside the bunker-ish building 4
		{"kind": "locker", "pos": Vector3(44.0, 0.01, 15.0)},
		{"kind": "weapons_stash", "pos": Vector3(49.0, 0.35, -8.0)},
		{"kind": "dumpster", "pos": Vector3(30.0, 0.01, -8.5)},
		{"kind": "dumpster", "pos": Vector3(14.0, 0.01, 12.0)},
		{"kind": "crate", "pos": Vector3(57, 0.35, 6)},         # bridge start
		{"kind": "locker", "pos": Vector3(70, 0.2, 12)},        # far side of bridge
		{"kind": "weapons_stash", "pos": Vector3(78, 0.2, -6)}, # across-river hazard camp
	]
	for s in spots:
		var it := Interactable.new()
		add_child(it)
		var p: Vector3 = s.pos
		p.y += _terrain_height(p.x, p.z, false)
		it.setup(s.kind, p, self)

func _spawn_enemies() -> void:
	var spawns := [
		{"id": "brahmin", "pos": Vector3(-18, 0, 18), "n": 3},
		{"id": "brahmin", "pos": Vector3(40, 0, 34), "n": 2},
		{"id": "radroach", "pos": Vector3(30, 0, -25), "n": 4},
		{"id": "radroach", "pos": Vector3(-35, 0, -10), "n": 4},
		{"id": "molerat", "pos": Vector3(12, 0, 35), "n": 3},
		{"id": "molerat", "pos": Vector3(-25, 0, -30), "n": 3},
		{"id": "dog", "pos": Vector3(45, 0, -30), "n": 3},
		{"id": "dog", "pos": Vector3(-40, 0, 25), "n": 2},
		{"id": "fireant", "pos": Vector3(52, 0, 28), "n": 4},
		{"id": "fireant", "pos": Vector3(20, 0, -40), "n": 4},
		{"id": "centipede", "pos": Vector3(56, 0, -18), "n": 2},   # near bridge far side
		{"id": "centipede", "pos": Vector3(64, 0, 30), "n": 2},    # in river shallows
		{"id": "beast", "pos": Vector3(62, 0, -45), "n": 1},       # the bridge boss
	]
	for s in spawns:
		for i in s.n:
			var e := Enemy.new()
			add_child(e)
			var p: Vector3 = s.pos + Vector3(randf_range(-3, 3), 0.3, randf_range(-3, 3))
			p.y += _terrain_height(p.x, p.z, false)
			e.setup(s.id, p)
			e.enemy_died.connect(_on_enemy_died)
			enemy_spawns.append({"id": s.id, "pos": s.pos, "respawn_t": 90.0})

func _on_enemy_died(e: Node) -> void:
	GameData.add_xp(e.xp_value)
	GameData.game_message("+%d XP  (%s slain)" % [e.xp_value, e.def.name], Color(0.5, 1.0, 0.5))

func _build_player() -> void:
	player = Player.new()
	add_child(player)
	var sp := spawn_points[1]
	var yaw := 0.0
	# dev tool: RT_DEBUG_SPAWN=bridge|river|far|boss to test remote areas
	match OS.get_environment("RT_DEBUG_SPAWN"):
		"bridge": sp = Vector3(56, 0.4, 6); yaw = -PI / 2.0
		"river": sp = Vector3(62, -2.6, 0)
		"far": sp = Vector3(74, 0.4, 6); yaw = PI / 2.0
		"boss": sp = Vector3(62, 0.4, -36)
	player.global_position = sp
	player.revive_at(player.global_position)
	player.rotation.y = yaw
	var hud := GameHUD.new()
	add_child(hud)
	hud.player = player
	self.hud = hud

var hud: GameHUD = null

func _build_weapons_training_dummy() -> void:
	# two practice targets in the plaza so shooting feels alive
	for i in 2:
		var base := Vector3(20 + i * 4, 0, 2)
		_cyl(0.08, 1.6, _mat("wood", Color(0.7, 0.6, 0.5)), base + Vector3(0, 0.8, 0))
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.28; sm.height = 0.56
		head.mesh = sm
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.85, 0.25, 0.2)
		hm.roughness = 0.6
		head.material_override = hm
		head.position = base + Vector3(0, 1.8, 0)
		add_child(head)

func _physics_process(delta: float) -> void:
	# radiation zones
	if GameData.alive and player != null:
		for z in rad_zones:
			if not z.trench:
				var d := Vector2(player.global_position.x - z.pos.x, player.global_position.z - z.pos.z).length()
				if d < z.radius:
					GameData.add_radiation(z.rate * delta * (1.0 - d / z.radius))
			else:
				# river: only if player is low (in water)
				if player.global_position.z > -40 and player.global_position.z < 40 and absf(player.global_position.x - 62.0) < z.radius and player.global_position.y < -0.5:
					GameData.add_radiation(z.rate * delta)
	# flicker bridge lamps and torches
	for t in torches:
		t.light.light_energy = t.base * (0.8 + randf() * 0.4)
	# flame sprite flicker
	var tt2 := Time.get_ticks_msec() * 0.01
	for f in flicker_sprites:
		var s := 0.85 + 0.3 * sin(tt2 * 3.0 + f.position.x * 9.0) * cos(tt2 * 2.0 + f.position.z * 7.0)
		f.scale = Vector3(s, 0.8 + 0.35 * absf(sin(tt2 * 2.0 + f.position.y * 10.0)), s)
	# respawn enemies
	for s in enemy_spawns:
		s.respawn_t -= delta
		if s.respawn_t <= 0.0:
			s.respawn_t = 120.0
			# don't stack spawns on the player
			if player and player.global_position.distance_to(s.pos) > 24:
				var e := Enemy.new()
				add_child(e)
				e.setup(s.id, s.pos + Vector3(randf_range(-2, 2), 0.2, randf_range(-2, 2)))
				e.enemy_died.connect(_on_enemy_died)
	# water animated in shader; follow the player with the dust field
	if dust_particles != null and player != null:
		dust_particles.global_position = Vector3(player.global_position.x, 1.5, player.global_position.z)
