extends Node3D
# The wasteland. Builds terrain, roads and every point of interest (Haven, Downtown +
# the Galleria mall, Camp Halberd + Black Site, Pinewood & the lake, Scrapjaw Yard,
# the gas station), then runs day/night lighting, temperature, zones, discovery,
# graves & revenants, vehicles, fishing, campfires and navmesh baking.

class_name World

static var nav_ready := false

const HALF := 340.0
const HAVEN := Vector3(0, 0, 165)
const PLAZA := Vector3(0, 0, -70)
const PLAZA_RECT := Rect2(-40, -110, 80, 80)        # x, z, w, d (surface slab over the mall)
const MALL_RECT := Rect2(-60, -120, 120, 80)
const MALL_Y := -12.0
const MILITARY := Vector3(215, 0, -215)
const LAB_Y := -14.0
const RAIDERS := Vector3(235, 0, 105)
const FOREST := Vector3(-205, 0, -10)
const LAKE := Vector3(-245, 0, 120)
const LAKE_R := 36.0
const WATER_Y := -1.1
const GAS := Vector3(110, 0, 182)
const ZONE_LEVEL := {"haven": 1, "wild": 3, "forest": 4, "downtown": 5, "mall": 7, "sublevel": 9, "raider": 7, "military": 10, "lab": 12}

# road polylines (x, z)
const ROADS := [
	[Vector2(0, 132), Vector2(0, 40)],
	[Vector2(37, 165), Vector2(110, 165), Vector2(205, 112)],
	[Vector2(-37, 165), Vector2(-120, 125), Vector2(-185, 45)],
	[Vector2(118, -60), Vector2(190, -150), Vector2(178, -205)],
]

var b: WorldBuilder
var player: Player = null
var hud: GameHUD = null
var director: Director = null
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ShaderMaterial
var pois: Array = []
var _covered_t := 0.0
var _covered := false
var _poi_t := 0.0
var bobber: MeshInstance3D = null
var _nav_pending := 0
var _flicker: Array = []
var _built := false
var zone_name := ""

func _ready() -> void:
	add_to_group("world_root")
	nav_ready = false
	Monster.corpses.clear()

# Builds in steps so the loading screen can animate. Await this.
func build(progress: Callable) -> void:
	b = WorldBuilder.new(self)
	_environment()
	await _step(progress, 0.08)
	_terrain()
	await _step(progress, 0.22)
	_roads()
	PoiHaven.build(self, b)
	await _step(progress, 0.32)
	PoiDowntown.build(self, b)
	await _step(progress, 0.52)
	PoiMilitary.build(self, b)
	await _step(progress, 0.62)
	PoiWilds.build(self, b)
	await _step(progress, 0.72)
	b.commit()
	await _step(progress, 0.8)
	_spawn_graves()
	_spawn_vehicles()
	_build_player()
	director = Director.new()
	director.world = self
	add_child(director)
	await _step(progress, 0.88)
	_bake_nav()
	_built = true
	update_lighting(0.0)

func _step(progress: Callable, v: float) -> void:
	if progress.is_valid():
		progress.call(v)
	await get_tree().process_frame

# ================= terrain =================
func road_dist(x: float, z: float) -> float:
	var best := 9999.0
	var p := Vector2(x, z)
	for r in ROADS:
		for i in range(r.size() - 1):
			var a: Vector2 = r[i]
			var c: Vector2 = r[i + 1]
			var ab := c - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			best = minf(best, p.distance_to(a + ab * t))
	return best

static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func height(x: float, z: float) -> float:
	var h := sin(x * 0.021) * cos(z * 0.017) * 3.2 + sin(x * 0.047 + 1.3) * sin(z * 0.039) * 1.5 + sin(x * 0.11) * cos(z * 0.13) * 0.35
	var fd := Vector2(x - FOREST.x, z - FOREST.z).length()
	h += clampf(1.0 - fd / 170.0, 0.0, 1.0) * sin(x * 0.035 + 0.7) * cos(z * 0.03) * 4.5
	var edge := maxf(absf(x), absf(z))
	if edge > 270.0:
		h += pow((edge - 270.0) / 70.0, 2.0) * 55.0
	var flat := 0.0
	flat = maxf(flat, 1.0 - _smooth(55.0, 85.0, Vector2(x - HAVEN.x, z - HAVEN.z).length()))
	var dx := maxf(0.0, maxf(-150.0 - x, x - 150.0))
	var dz := maxf(0.0, maxf(-225.0 - z, z - 50.0))
	flat = maxf(flat, 1.0 - _smooth(0.0, 35.0, Vector2(dx, dz).length()))
	flat = maxf(flat, 1.0 - _smooth(80.0, 110.0, Vector2(x - MILITARY.x, z - MILITARY.z).length()))
	flat = maxf(flat, 1.0 - _smooth(50.0, 75.0, Vector2(x - RAIDERS.x, z - RAIDERS.z).length()))
	flat = maxf(flat, 1.0 - _smooth(28.0, 50.0, Vector2(x - GAS.x, z - GAS.z).length()))
	flat = maxf(flat, 1.0 - _smooth(7.0, 22.0, road_dist(x, z)))
	h = lerpf(h, 0.0, flat)
	var ld := Vector2(x - LAKE.x, z - LAKE.z).length()
	if ld < LAKE_R + 16.0:
		h = lerpf(h, -3.2, 1.0 - _smooth(LAKE_R - 8.0, LAKE_R + 16.0, ld))
	return h

func _forest_w(x: float, z: float) -> float:
	var fd := Vector2(x - FOREST.x, z - FOREST.z).length()
	var lk := clampf(1.0 - (Vector2(x - LAKE.x, z - LAKE.z).length() - LAKE_R - 10.0) / 45.0, 0.0, 1.0)
	return maxf(clampf(1.0 - (fd - 120.0) / 80.0, 0.0, 1.0), lk)

# Terrain cells cut out where something is built below ground level (plaza slab over
# the mall, the bunker stairwell). A cell is cut only if it lies fully inside a hole.
const HOLES := [Rect2(-40, -110, 80, 80), Rect2(200, -200, 8, 12)]
func _cell_cut(cx: float, cz: float, half_cell: float) -> bool:
	var cell := Rect2(cx - half_cell, cz - half_cell, half_cell * 2.0, half_cell * 2.0)
	for h in HOLES:
		if (h as Rect2).encloses(cell):
			return true
	return false

func _terrain() -> void:
	var cell := 4.0
	var n := int(HALF * 2.0 / cell)
	var hmap := PackedFloat32Array()
	hmap.resize((n + 1) * (n + 1))
	for zi in n + 1:
		for xi in n + 1:
			hmap[zi * (n + 1) + xi] = height(-HALF + xi * cell, -HALF + zi * cell)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("terrain")
	body.add_to_group("navsrc")
	add_child(body)
	var mat := _terrain_material()
	var chunks := 5
	var per := n / chunks
	for cz in chunks:
		for cx in chunks:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var faces := PackedVector3Array()
			var x0 := cx * per
			var z0 := cz * per
			var x1 := n if cx == chunks - 1 else x0 + per
			var z1 := n if cz == chunks - 1 else z0 + per
			var w := x1 - x0 + 1
			for zi in range(z0, z1 + 1):
				for xi in range(x0, x1 + 1):
					var wx := -HALF + xi * cell
					var wz := -HALF + zi * cell
					var hh: float = hmap[zi * (n + 1) + xi]
					verts.append(Vector3(wx, hh, wz))
					var hl: float = hmap[zi * (n + 1) + maxi(0, xi - 1)]
					var hr: float = hmap[zi * (n + 1) + mini(n, xi + 1)]
					var hd: float = hmap[maxi(0, zi - 1) * (n + 1) + xi]
					var hu: float = hmap[mini(n, zi + 1) * (n + 1) + xi]
					norms.append(Vector3(hl - hr, 2.0 * cell, hd - hu).normalized())
					var fw := _forest_w(wx, wz)
					var road := 1.0 - _smooth(5.0, 12.0, road_dist(wx, wz))
					cols.append(Color(fw, 1.0 - road * 0.35, road, 1.0))
			for zi in range(z1 - z0):
				for xi in range(x1 - x0):
					var cxw := -HALF + (x0 + xi + 0.5) * cell
					var czw := -HALF + (z0 + zi + 0.5) * cell
					if _cell_cut(cxw, czw, cell * 0.5):
						continue
					var a := zi * w + xi
					idx.append(a); idx.append(a + 1); idx.append(a + w + 1)
					idx.append(a); idx.append(a + w + 1); idx.append(a + w)
					faces.append(verts[a]); faces.append(verts[a + 1]); faces.append(verts[a + w + 1])
					faces.append(verts[a]); faces.append(verts[a + w + 1]); faces.append(verts[a + w])
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = norms
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			am.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			add_child(mi)
			var cs := CollisionShape3D.new()
			var sh := ConcavePolygonShape3D.new()
			sh.set_faces(faces)
			cs.shape = sh
			body.add_child(cs)

func _terrain_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform sampler2D dust_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D dust_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dust_r : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec3 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, p.xy).rgb * w.z;
}
void fragment() {
	vec2 uv = wpos.xz * 0.11;
	float big = texture(noise_tex, wpos.xz * 0.0035).r;
	float mid = texture(noise_tex, wpos.xz * 0.021).r;
	// break up tiling: blend two rotated samples
	vec2 uv2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.63 + 0.37;
	float bl = smoothstep(0.35, 0.65, mid);
	vec3 d = mix(texture(dust_tex, uv).rgb, texture(dust_tex, uv2).rgb, bl) * vec3(1.04, 0.95, 0.82);
	vec3 g = mix(texture(grass_tex, uv * 0.7).rgb, texture(grass_tex, uv2 * 0.9).rgb, bl);
	vec3 r = texture(road_tex, uv * 0.5).rgb * 0.9;
	float f = smoothstep(0.15, 0.85, COLOR.r + (big - 0.5) * 0.5 + (mid - 0.5) * 0.25);
	vec3 col = mix(d, g, f);
	float road = smoothstep(0.3, 0.9, COLOR.b);
	col = mix(col, r, road);
	// slopes turn to rock (triplanar so cliffs don't smear)
	float slope = 1.0 - wnrm.y;
	float rk = smoothstep(0.22, 0.42, slope + (mid - 0.5) * 0.15);
	vec3 w = pow(abs(wnrm), vec3(4.0)); w /= (w.x + w.y + w.z);
	vec3 rp = wpos * 0.16;
	vec3 rock = tri(rock_tex, rp, w);
	col = mix(col, rock, rk);
	col *= 0.8 + big * 0.32 + (mid - 0.5) * 0.12;
	ALBEDO = col;
	float rgh = texture(dust_r, uv).r;
	ROUGHNESS = mix(mix(0.88 + rgh * 0.1, 0.95, f), 0.78, max(rk, road * 0.6));
	vec3 nd = mix(texture(dust_n, uv).rgb, texture(grass_n, uv * 0.7).rgb, f);
	vec3 nr = tri(rock_n, rp, w);
	NORMAL_MAP = mix(nd, nr, rk);
	NORMAL_MAP_DEPTH = mix(0.55, 1.6, rk);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("dust_tex", Proc.tex("dust"))
	m.set_shader_parameter("grass_tex", Proc.tex("grass"))
	m.set_shader_parameter("road_tex", Proc.tex("asphalt"))
	m.set_shader_parameter("noise_tex", Proc.noise_tile(256))
	m.set_shader_parameter("dust_n", Proc.normal_tex("dust"))
	m.set_shader_parameter("grass_n", Proc.normal_tex("grass"))
	m.set_shader_parameter("rock_tex", Proc.tex("rock"))
	m.set_shader_parameter("rock_n", Proc.normal_tex("rock"))
	m.set_shader_parameter("dust_r", Proc.rough_tex("dust"))
	return m

func _roads() -> void:
	for r in ROADS:
		for i in range(r.size() - 1):
			var a: Vector2 = r[i]
			var c: Vector2 = r[i + 1]
			var d := c - a
			var length := d.length()
			var steps := int(ceil(length / 12.0))
			for s in steps:
				var t0 := float(s) / steps
				var t1 := float(s + 1) / steps
				var p0 := a + d * t0
				var p1 := a + d * t1
				var mid := (p0 + p1) * 0.5
				var yaw := atan2(d.x, d.y)
				var y := height(mid.x, mid.y)
				b.box(Vector3(10.0, 0.12, p0.distance_to(p1) + 0.4), Vector3(mid.x, y + 0.03, mid.y), "asphalt", Vector3(0, yaw, 0), false, Color(0.9, 0.9, 0.9))
				if s % 2 == 0:
					b.box(Vector3(0.18, 0.13, 3.0), Vector3(mid.x, y + 0.04, mid.y), "paint", Vector3(0, yaw, 0), false, Color(0.85, 0.75, 0.3))
			# wrecks along the way
			var rng := RandomNumberGenerator.new()
			rng.seed = int(a.x * 13 + a.y * 7)
			for k in int(length / 45.0):
				var t := rng.randf_range(0.1, 0.9)
				var pp := a + d * t
				var side := rng.randf_range(-3.5, 3.5)
				var perp := Vector2(-d.y, d.x).normalized()
				pp += perp * side
				car_wreck(Vector3(pp.x, height(pp.x, pp.y), pp.y), atan2(d.x, d.y) + rng.randf_range(-0.6, 0.6), rng, 3)

# ---------- shared prop helpers (used by POIs) ----------
func car_wreck(pos: Vector3, yaw: float, rng: RandomNumberGenerator, level := 3, burnt := false) -> void:
	var cols := [Color(0.55, 0.15, 0.12), Color(0.2, 0.3, 0.45), Color(0.6, 0.55, 0.45), Color(0.25, 0.4, 0.3), Color(0.7, 0.68, 0.6), Color(0.15, 0.15, 0.17)]
	var c: Color = cols[rng.randi() % cols.size()]
	if burnt:
		c = Color(0.18, 0.15, 0.13)
	var basis := Basis.from_euler(Vector3(0, yaw, rng.randf_range(-0.04, 0.04)))
	var xf := Transform3D(basis, pos + Vector3(0, 0.7, 0))
	b.add_box_mesh(Vector3(1.9, 0.75, 4.3), xf, "rusty", c)
	b.add_box_col(Vector3(1.9, 1.3, 4.3), Transform3D(basis, pos + Vector3(0, 0.75, 0)))
	b.add_box_mesh(Vector3(1.7, 0.6, 2.1), xf * Transform3D(Basis(), Vector3(0, 0.6, 0.2)), "rusty", c.darkened(0.1))
	b.add_box_mesh(Vector3(1.6, 0.5, 0.06), xf * Transform3D(Basis.from_euler(Vector3(-0.5, 0, 0)), Vector3(0, 0.65, -0.92)), "windows", Color(0.4, 0.45, 0.5))
	for wx in [-0.88, 0.88]:
		for wz in [-1.35, 1.35]:
			b.cyl(0.36, 0.25, pos + basis * Vector3(wx, 0.36, wz), "rubber", false, Color(0.08, 0.08, 0.08), 8, Vector3(0, yaw, PI / 2.0))
	if rng.randf() < 0.55:
		var trunk := Interactable.new().setup("car_trunk", level)
		add_child(trunk)
		trunk.global_position = pos + basis * Vector3(0, 0.2, 2.25)
		trunk.rotation.y = yaw

func burning_barrel(pos: Vector3) -> void:
	b.cyl(0.32, 0.9, pos + Vector3(0, 0.45, 0), "rusty", true, Color(0.5, 0.35, 0.25), 10)
	var l := b.light(pos + Vector3(0, 1.3, 0), Color(1.0, 0.5, 0.15), 9.0, 2.2)
	_flicker.append({"l": l, "base": 2.2})
	var fire := Node3D.new()
	fire.add_to_group("fires")
	add_child(fire)
	fire.position = pos
	if not Combat.low_fx():
		var p := GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.22
		pm.direction = Vector3.UP
		pm.spread = 15.0
		pm.gravity = Vector3(0, 1.5, 0)
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.4
		pm.scale_min = 0.18
		pm.scale_max = 0.4
		pm.color = Color(1.0, 0.55, 0.15)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 0.3, 0.1, 0))
		var rt := GradientTexture1D.new()
		rt.gradient = ramp
		pm.color_ramp = rt
		p.process_material = pm
		p.draw_pass_1 = Proc.particle_quad(Proc.particle_soft(Color(1, 1, 1, 1)))
		p.amount = 16
		p.lifetime = 0.8
		p.position.y = 1.0
		fire.add_child(p)

func container(kind: String, pos: Vector3, yaw := 0.0, zone := "", lvl := -1) -> Interactable:
	var lv := lvl if lvl > 0 else zone_level(pos)
	var it := Interactable.new().setup(kind, lv, {"zone": zone})
	add_child(it)
	it.global_position = pos
	it.rotation.y = yaw
	return it

func spawn_monster(kind: String, pos: Vector3, level := -1, opts := {}) -> Monster:
	var m := Monster.new()
	m.setup(kind, pos, level if level > 0 else zone_level(pos), opts)
	add_child(m)
	return m

func add_poi(id: String, title: String, pos: Vector3, r: float, xp := 120) -> void:
	pois.append({"id": id, "title": title, "pos": pos, "r": r, "xp": xp})

# ================= zones & environment =================
func zone_at(p: Vector3) -> String:
	if p.y < -3.0:
		if Vector2(p.x - MILITARY.x, p.z - MILITARY.z).length() < 100.0:
			return "lab"
		if MALL_RECT.grow(6.0).has_point(Vector2(p.x, p.z)):
			return "sublevel" if p.y < MALL_Y - 2.5 else "mall"
	if Vector2(p.x - HAVEN.x, p.z - HAVEN.z).length() < 48.0:
		return "haven"
	if p.x > -150.0 and p.x < 150.0 and p.z > -225.0 and p.z < 50.0:
		return "downtown"
	if Vector2(p.x - MILITARY.x, p.z - MILITARY.z).length() < 80.0:
		return "military"
	if Vector2(p.x - RAIDERS.x, p.z - RAIDERS.z).length() < 55.0:
		return "raider"
	if _forest_w(p.x, p.z) > 0.3 or Vector2(p.x - LAKE.x, p.z - LAKE.z).length() < 70.0:
		return "forest"
	return "wild"

func zone_level(p: Vector3) -> int:
	return int(ZONE_LEVEL.get(zone_at(p), 3))

func daylight() -> float:
	var t := GameData.time_of_day()
	if t < 5.0 or t > 21.0:
		return 0.0
	if t < 7.5:
		return _smooth(5.0, 7.5, t)
	if t > 18.5:
		return 1.0 - _smooth(18.5, 21.0, t)
	return 1.0

func env_at(p: Vector3) -> Dictionary:
	var day_k := daylight()
	var zone := zone_at(p)
	var amb := lerpf(1.0, 18.0, day_k)
	if zone in ["mall", "sublevel", "lab"]:
		amb = 13.0
	elif zone == "forest":
		amb -= 2.5
	if p.y > 20.0:
		amb -= 4.0
	var fire := false
	for f in get_tree().get_nodes_in_group("fires"):
		if (f as Node3D).global_position.distance_to(p) < 4.5:
			fire = true
			break
	var wet := Vector2(p.x - LAKE.x, p.z - LAKE.z).length() < LAKE_R and p.y < WATER_Y - 0.2
	var underground := zone in ["mall", "sublevel", "lab"]
	return {"ambient": amb, "fire": fire, "wet": wet, "zone": zone,
		"sunlit": day_k > 0.35 and not underground and not _covered, "level": ZONE_LEVEL.get(zone, 3)}

func is_hard_floor(p: Vector3) -> bool:
	var z := zone_at(p)
	return z in ["downtown", "mall", "sublevel", "lab", "military"] or p.y > 1.0

func near_fire(p: Vector3) -> bool:
	return bool(env_at(p).fire)

# ================= lighting =================
func _sky_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type sky;
uniform vec4 sky_top_color : source_color = vec4(0.24, 0.32, 0.5, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.9, 0.7, 0.5, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.9, 0.7, 0.5, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.2, 0.17, 0.13, 1.0);
uniform float sky_energy_multiplier = 1.0;
uniform float night_k = 0.0;
uniform vec4 sun_tint : source_color = vec4(1.0, 0.9, 0.8, 1.0);
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		float t = pow(1.0 - h, 4.0);
		col = mix(sky_top_color.rgb, sky_horizon_color.rgb, t);
	} else {
		col = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, clamp(pow(-h, 0.6) * 2.0, 0.0, 1.0));
	}
	vec3 L = LIGHT0_DIRECTION;
	float sd = max(dot(d, L), 0.0);
	bool has_sun = LIGHT0_ENABLED;
	// haze glow around the sun, broad and tight
	if (has_sun) {
		col += sun_tint.rgb * (pow(sd, 8.0) * 0.35 + pow(sd, 64.0) * 0.6) * (1.0 - night_k * 0.6);
		float disk = smoothstep(0.9994, 0.9998, sd);
		col += sun_tint.rgb * disk * mix(18.0, 2.5, night_k);
	}
	// clouds: two scrolling layers projected on a dome
	if (h > 0.0 && !AT_CUBEMAP_PASS) {
		vec2 uv = d.xz / (h + 0.18);
		float c1 = texture(cloud_tex, uv * 0.18 + vec2(TIME * 0.0016, TIME * 0.0006)).r;
		float c2 = texture(cloud_tex, uv * 0.45 - vec2(TIME * 0.0025, 0.0)).r;
		float c = smoothstep(0.45, 0.78, c1 * 0.7 + c2 * 0.45);
		c *= smoothstep(0.0, 0.22, h);
		vec3 lit = mix(vec3(1.0), sun_tint.rgb, 0.45) * (0.75 + pow(sd, 4.0) * 0.8);
		vec3 shade = mix(sky_horizon_color.rgb * 0.55, sky_top_color.rgb * 0.4, 0.5);
		vec3 ccol = mix(shade, lit, smoothstep(0.3, 0.95, c1)) * mix(1.0, 0.12, night_k);
		col = mix(col, ccol, c * 0.85);
		// stars
		vec3 sp = floor(d * 380.0);
		float st = step(0.9975, hash(sp)) * night_k * (1.0 - c) * smoothstep(0.05, 0.3, h);
		col += vec3(st) * (0.6 + hash(sp + 3.0) * 1.4);
	}
	COLOR = col * sky_energy_multiplier;
}
"""
	return sh

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = _sky_shader()
	var cn := FastNoiseLite.new()
	cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn.fractal_octaves = 5
	cn.frequency = 0.006
	var ct := NoiseTexture2D.new()
	ct.width = 512
	ct.height = 512
	ct.seamless = true
	ct.noise = cn
	sky_mat.set_shader_parameter("cloud_tex", ct)
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.25
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.08
	var q: String = UITheme.settings.get("quality", "high")
	env.ssao_enabled = q == "high"
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_detail = 0.8
	env.ssil_enabled = q == "high"
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.ssr_enabled = q == "high"
	env.ssr_max_steps = 48
	env.ssr_fade_out = 1.5
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = q == "high"
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_length = 90.0
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_ambient_inject = 0.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.8
	sun.shadow_blur = 1.5
	sun.shadow_normal_bias = 1.2
	sun.light_specular = 0.8
	add_child(sun)

var _under_k := 0.0
func update_lighting(delta: float) -> void:
	var t := GameData.time_of_day()
	var day_k := daylight()
	var under := 0.0
	if player != null and is_instance_valid(player):
		var z := zone_at(player.global_position)
		under = 0.75 if z == "mall" else (1.0 if z in ["sublevel", "lab"] else 0.0)
	_under_k = move_toward(_under_k, under, delta * 1.5) if delta > 0.0 else under
	# sun arc 6:00 -> 20:00, moon the rest of the time
	var sun_up := t >= 5.5 and t <= 20.5
	var arc := clampf((t - 5.5) / 15.0, 0.0, 1.0) if sun_up else fmod((t + 24.0 - 20.5), 24.0) / 9.0
	var elev := sin(arc * PI) * deg_to_rad(62.0 if sun_up else 45.0) + deg_to_rad(4.0)
	var yaw := lerpf(deg_to_rad(-100.0), deg_to_rad(100.0), arc)
	sun.rotation = Vector3(-elev, yaw, 0.0)
	var dusk := 1.0 - absf(arc - 0.5) * 2.0
	var warm := Color(1.0, 0.62, 0.35).lerp(Color(1.0, 0.92, 0.8), clampf(dusk * 1.6, 0.0, 1.0))
	if sun_up:
		sun.light_color = warm
		sun.light_energy = lerpf(0.15, 1.55, day_k) * (1.0 - _under_k)
	else:
		sun.light_color = Color(0.55, 0.65, 1.0)
		sun.light_energy = 0.22 * (1.0 - _under_k)
	sun.shadow_enabled = _under_k < 0.9
	var night_top := Color(0.02, 0.025, 0.06)
	var night_hor := Color(0.06, 0.07, 0.12)
	var day_top := Color(0.24, 0.32, 0.5)
	var day_hor := Color(0.9, 0.7, 0.5)
	var dusk_hor := Color(0.95, 0.45, 0.2)
	var hor := day_hor.lerp(dusk_hor, clampf(1.0 - dusk * 1.4, 0.0, 1.0))
	var sh_hor: Color = night_hor.lerp(hor, day_k)
	sky_mat.set_shader_parameter("sky_top_color", night_top.lerp(day_top, day_k))
	sky_mat.set_shader_parameter("sky_horizon_color", sh_hor)
	sky_mat.set_shader_parameter("ground_horizon_color", sh_hor)
	sky_mat.set_shader_parameter("ground_bottom_color", Color(0.05, 0.04, 0.035).lerp(Color(0.25, 0.2, 0.15), day_k))
	sky_mat.set_shader_parameter("sky_energy_multiplier", lerpf(0.35, 1.0, day_k))
	sky_mat.set_shader_parameter("night_k", 1.0 - day_k)
	sky_mat.set_shader_parameter("sun_tint", warm if sun_up else Color(0.7, 0.78, 1.0))
	var amb := lerpf(0.22, 1.0, day_k) * (1.0 - _under_k * 0.88)
	if GameData.form == "vampire" or GameData.form == "wolf":
		amb = maxf(amb, 0.5)
	env.ambient_light_energy = amb
	env.ambient_light_sky_contribution = 1.0 - _under_k * 0.7
	var fog_c := Color(0.06, 0.07, 0.1).lerp(Color(0.82, 0.62, 0.42), day_k)
	env.fog_light_color = fog_c.lerp(Color(0.02, 0.02, 0.025), _under_k)
	env.fog_density = lerpf(lerpf(0.0042, 0.0026, day_k), 0.011, _under_k)
	env.volumetric_fog_albedo = Color(0.9, 0.85, 0.8)
	env.volumetric_fog_density = lerpf(lerpf(0.0045, 0.0011, day_k), 0.013, _under_k)
	env.fog_sky_affect = lerpf(0.35, 0.8, 1.0 - day_k)
	if b != null and b.mats.has("windows"):
		(b.mats["windows"] as StandardMaterial3D).emission_energy_multiplier = lerpf(2.4, 0.0, day_k)

# ================= runtime =================
func _process(delta: float) -> void:
	if not _built:
		return
	update_lighting(delta)
	for f in _flicker:
		(f.l as OmniLight3D).light_energy = float(f.base) * randf_range(0.75, 1.15)
	if player == null or not is_instance_valid(player):
		return
	_covered_t -= delta
	if _covered_t <= 0.0:
		_covered_t = 0.5
		var head := player.global_position + Vector3(0, 1.7, 0)
		var q := PhysicsRayQueryParameters3D.create(head, head + Vector3(0, 40, 0), 1 | 2)
		_covered = not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_poi_t -= delta
	if _poi_t <= 0.0:
		_poi_t = 1.0
		var pp := player.global_position
		for p in pois:
			if (p.pos as Vector3).distance_to(pp) < float(p.r):
				GameData.discover(p.id, p.title, int(p.xp))
		var z := zone_at(pp)
		zone_name = z
		match z:
			"mall", "sublevel": SFX.ambience("amb_mall", -16.0)
			"lab": SFX.ambience("amb_lab", -14.0)
			_: SFX.ambience("amb_night" if GameData.is_night() else "amb_day", -20.0)

func _build_player() -> void:
	player = Player.new()
	add_child(player)
	if GameData.has_position and GameData.player_pos.y > -60.0:
		player.teleport(GameData.player_pos + Vector3(0, 0.3, 0), GameData.player_yaw)
	else:
		player.teleport(spawn_point(), PI)
	var dbg := OS.get_environment("RT_DEBUG_SPAWN")
	match dbg:
		"plaza": player.teleport(Vector3(0, 0.5, -36), PI * 0.0)
		"mall": player.teleport(Vector3(-3, MALL_Y + 0.5, -66), 0.0)
		"atrium": player.teleport(Vector3(0, MALL_Y + 0.5, -66), 0.0)
		"sublevel": player.teleport(Vector3(-45, MALL_Y - 5.5, -108), 0.0)
		"military": player.teleport(MILITARY + Vector3(-60, 0.5, 0), PI * 0.5)
		"lab": player.teleport(Vector3(MILITARY.x + 10, LAB_Y + 0.5, MILITARY.z - 10), 0.0)
		"raiders": player.teleport(RAIDERS + Vector3(-50, 0.5, 0), PI * 0.5)
		"forest": player.teleport(LAKE + Vector3(0, 0.5, -LAKE_R - 6), PI)
		"downtown": player.teleport(Vector3(30, 0.5, 20), 0.0)
		"haven_gate": player.teleport(HAVEN + Vector3(-4, 0.4, -10), 0.35)
		"garage": player.teleport(Vector3(46, 7.4, -4), -0.6)
		"meridian": player.teleport(Vector3(-64, 20.4, -40), -1.2)
		"gas": player.teleport(GAS + Vector3(-20, 0.5, 6), -1.3)
	if OS.get_environment("RT_DEBUG_ZOO") != "":
		# dev: a frozen line-up of every body type in front of the player
		var kinds := OS.get_environment("RT_DEBUG_ZOO").split(",")
		var fwd := -player.global_transform.basis.z
		var right := player.global_transform.basis.x
		for i in kinds.size():
			var p := player.global_position + fwd * 7.0 + right * (i - (kinds.size() - 1) * 0.5) * 3.2
			p.y = height(p.x, p.z) + 0.1
			var m := spawn_monster(kinds[i], p, 1, {"dormant": true})
			m.rotation.y = player.rotation.y + PI
			m.set_physics_process(false)
			m.state = "dormant"
	if OS.get_environment("RT_DEBUG_PITCH") != "":
		player.pitch = OS.get_environment("RT_DEBUG_PITCH").to_float()
	if OS.get_environment("RT_DEBUG_YAW") != "":
		player.rotation.y = OS.get_environment("RT_DEBUG_YAW").to_float()
	hud = GameHUD.new()
	hud.player = player
	hud.world = self
	add_child(hud)

func spawn_point() -> Vector3:
	return HAVEN + Vector3(0, 0.4, 8)

func nearest_loot(pos: Vector3, fwd: Vector3, r: float) -> Object:
	var best: Object = null
	var bd := r
	for l in get_tree().get_nodes_in_group("loot"):
		var lp := l as Node3D
		var to := lp.global_position - pos
		to.y *= 0.5
		var d := to.length()
		if d > bd:
			continue
		var flat := Vector3(to.x, 0, to.z)
		if d > 0.8 and flat.length() > 0.01 and fwd.dot(flat.normalized()) < 0.2:
			continue
		bd = d
		best = l
	return best

# ================= fishing & campfires =================
func fishing_spot(from: Vector3, dir: Vector3) -> Vector3:
	if dir.y > -0.04:
		return Vector3.INF
	var t := (WATER_Y - from.y) / dir.y
	if t <= 0.0 or t > 14.0:
		return Vector3.INF
	var p := from + dir * t
	if Vector2(p.x - LAKE.x, p.z - LAKE.z).length() < LAKE_R - 2.0:
		return p
	return Vector3.INF

func show_bobber(p: Vector3) -> void:
	clear_bobber()
	bobber = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	bobber.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.2, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.2)
	m.emission_energy_multiplier = 1.5
	bobber.material_override = m
	add_child(bobber)
	bobber.global_position = p + Vector3(0, 0.04, 0)

func bob_bobber() -> void:
	if bobber != null and is_instance_valid(bobber):
		var t := bobber.create_tween()
		t.tween_property(bobber, "position:y", bobber.position.y - 0.12, 0.08)
		t.tween_property(bobber, "position:y", bobber.position.y, 0.2)

func clear_bobber() -> void:
	if bobber != null and is_instance_valid(bobber):
		bobber.queue_free()
	bobber = null

func spawn_campfire(p: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 2, 0), p + Vector3(0, -6, 0), 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var pos := p if hit.is_empty() else (hit.position as Vector3)
	var it := Interactable.new().setup("campfire", 1)
	add_child(it)
	it.global_position = pos
	get_tree().create_timer(900.0).timeout.connect(func():
		if is_instance_valid(it):
			it.queue_free())

func fade_flash(col: Color, dur: float) -> void:
	if hud != null:
		hud.flash_screen(col, dur)

# ================= graves, revenants, vehicles =================
func _spawn_graves() -> void:
	for g in GameData.world.get("graves", []):
		var pa: Array = g.get("pos", [0, 0, 0])
		var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		var curse: String = g.get("curse", "")
		if curse != "":
			var kind := "brute" if curse == "rot" else ("werewolf" if curse == "wolf" else "vampire")
			var lvl := maxi(int(g.get("level", 1)) + 2, zone_level(pos))
			var m := spawn_monster(kind, pos + Vector3(0, 0.5, 0), lvl, {"revenant": g, "name": "%s the Risen" % g.get("name", "Survivor"),
				"hp_mul": 2.2, "dmg_mul": 1.35, "xp_mul": 3.0, "leash": 25.0})
			m.died.connect(func(mm: Monster, _info: Dictionary):
				g["curse"] = ""
				g["pos"] = [mm.global_position.x, mm.global_position.y, mm.global_position.z]
				GameData.save_world()
				_place_grave(g, mm.global_position)
				GameData.banner("LAID TO REST", "%s won't rise again. Their gear is yours." % g.get("name", "Survivor"), Color(0.6, 1.0, 0.7)))
		else:
			_place_grave(g, pos)

func _place_grave(g: Dictionary, pos: Vector3) -> void:
	var it := Interactable.new().setup("grave", 1, {"data": g})
	add_child(it)
	it.global_position = pos

func _spawn_vehicles() -> void:
	var saved: Array = GameData.world.get("vehicles", [])
	if saved.is_empty():
		saved = [
			{"pos": [24.0, 0.8, 166.0], "yaw": PI * 0.5, "fuel": 60.0, "hp": 400.0, "color": 0},
			{"pos": [GAS.x + 6.0, 0.8, GAS.z - 8.0], "yaw": 1.2, "fuel": 25.0, "hp": 300.0, "color": 1},
			{"pos": [MILITARY.x - 30.0, 0.8, MILITARY.z], "yaw": -PI * 0.5, "fuel": 80.0, "hp": 500.0, "color": 2},
		]
	for i in saved.size():
		var s: Dictionary = saved[i]
		var v := Vehicle.new()
		v.index = i
		v.fuel = float(s.get("fuel", 50.0))
		v.hp = float(s.get("hp", 400.0))
		v.paint = int(s.get("color", 0))
		add_child(v)
		var pa: Array = s.get("pos", [0, 1, 0])
		v.global_position = Vector3(float(pa[0]), float(pa[1]) + 0.4, float(pa[2]))
		v.rotation.y = float(s.get("yaw", 0.0))

func save_vehicles() -> void:
	var out := []
	for v in get_tree().get_nodes_in_group("vehicle"):
		var vv := v as Vehicle
		out.append({"pos": [vv.global_position.x, vv.global_position.y, vv.global_position.z], "yaw": vv.rotation.y,
			"fuel": vv.fuel, "hp": vv.hp, "color": vv.paint})
	GameData.world["vehicles"] = out

# ================= navigation =================
func _bake_nav() -> void:
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.3)
	NavigationServer3D.map_set_cell_height(map, 0.25)
	var boxes := [
		AABB(Vector3(-140, -26, -215), Vector3(280, 100, 265)),
		AABB(Vector3(-48, -3, 122), Vector3(96, 24, 92)),
		AABB(Vector3(160, -28, -270), Vector3(110, 60, 110)),
		AABB(Vector3(190, -3, 60), Vector3(90, 24, 90)),
	]
	_nav_pending = boxes.size()
	for bx in boxes:
		var nr := NavigationRegion3D.new()
		var nm := NavigationMesh.new()
		nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nm.geometry_collision_mask = 1 | 2
		nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
		nm.geometry_source_group_name = "navsrc"
		nm.filter_baking_aabb = bx
		nm.cell_size = 0.3
		nm.cell_height = 0.25
		nm.agent_radius = 0.6
		nm.agent_height = 1.75
		nm.agent_max_climb = 0.5
		nm.agent_max_slope = 46.0
		nm.region_min_size = 4.0
		nr.navigation_mesh = nm
		add_child(nr)
		nr.bake_finished.connect(func():
			_nav_pending -= 1
			if _nav_pending <= 0:
				nav_ready = true)
		if OS.get_environment("RT_NO_NAV") == "1":
			_nav_pending -= 1
			continue
		nr.bake_navigation_mesh(true)
