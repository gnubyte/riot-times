extends RigidBody3D
# A dropped item: physics object with a rarity-colored light beam (Uncommon+ gear),
# a floating name tag up close, and auto-pickup for ammo, bolts and Glowshards.

class_name LootPickup

var entry := {}
var freeze_on_spawn := false
var taken := false
var _label: Label3D
var _check_t := 0.0
var _age := 0.0
var _auto := false

func _ready() -> void:
	add_to_group("loot")
	collision_layer = 8
	collision_mask = 1 | 2
	mass = 1.5
	angular_damp = 2.0
	linear_damp = 0.4
	var id: String = entry.get("id", "scrap")
	var t := ItemDB.item_type(id)
	_auto = t == "ammo" or t == "currency"
	var r := int(entry.get("rarity", 0))
	var col: Color = ItemDB.rarity_color(r) if ItemDB.is_unique(id) else Color(0.95, 0.85, 0.45)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	var size := Vector3(0.24, 0.16, 0.24)
	if t == "weapon":
		size = Vector3(0.18, 0.14, 0.7)
	elif t == "melee":
		size = Vector3(0.1, 0.1, 0.7)
	elif t == "armor":
		size = Vector3(0.4, 0.2, 0.32)
	bs.size = size
	cs.shape = bs
	add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	match t:
		"weapon", "melee": mat.albedo_color = Color(0.22, 0.22, 0.24); mat.metallic = 0.7; mat.roughness = 0.4
		"armor": mat.albedo_color = Color(0.35, 0.33, 0.28)
		"ammo": mat.albedo_color = Color(0.45, 0.42, 0.25)
		"food", "drink": mat.albedo_color = Color(0.7, 0.65, 0.55)
		"med", "cure": mat.albedo_color = Color(0.9, 0.9, 0.92)
		"currency": mat.albedo_color = Color(0.4, 1.0, 0.5); mat.emission_enabled = true; mat.emission = Color(0.3, 1.0, 0.4); mat.emission_energy_multiplier = 1.5
		_: mat.albedo_color = Color(0.55, 0.5, 0.42)
	mi.material_override = mat
	add_child(mi)
	# rarity stripe so even commons read as "gear"
	if ItemDB.is_unique(id):
		var stripe := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(size.x + 0.01, 0.03, size.z * 0.6)
		stripe.mesh = sb
		var sm := StandardMaterial3D.new()
		sm.albedo_color = col
		sm.emission_enabled = true
		sm.emission = col
		sm.emission_energy_multiplier = 1.5
		stripe.material_override = sm
		add_child(stripe)
	if ItemDB.is_unique(id) and r >= 1:
		_beam(col, r)
	_label = Label3D.new()
	var nm := ItemDB.display_name(entry)
	var cnt := int(entry.get("count", 1))
	if cnt > 1:
		nm += " x%d" % cnt
	if ItemDB.is_unique(id):
		nm += "  Lv%d" % int(entry.get("level", 1))
	_label.text = nm
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 30
	_label.outline_size = 8
	_label.modulate = col
	_label.position = Vector3(0, 0.45, 0)
	_label.visibility_range_end = 9.0
	_label.no_depth_test = false
	add_child(_label)
	if freeze_on_spawn:
		freeze = true
	if r >= 4:
		SFX.play_3d("legendary", global_position, 0.0, 1.0, 60.0)

func _beam(col: Color, r: int) -> void:
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.06
	cm.height = 2.5 + r * 0.8
	cm.radial_segments = 6
	beam.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.55)
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = cm.height * 0.5
	beam.top_level = true
	add_child(beam)
	beam.set_meta("h", cm.height * 0.5)
	set_meta("beam", beam)
	if r >= 3:
		var l := OmniLight3D.new()
		l.light_color = col
		l.omni_range = 4.0
		l.light_energy = 1.2
		l.position.y = 0.5
		add_child(l)

func _physics_process(delta: float) -> void:
	_age += delta
	if has_meta("beam"):
		var b: MeshInstance3D = get_meta("beam")
		b.global_position = global_position + Vector3(0, float(b.get_meta("h")), 0)
		b.global_rotation = Vector3.ZERO
	if _age > 480.0:
		queue_free()
		return
	if not _auto:
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.2
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and not p.dead and p.in_vehicle == null and p.global_position.distance_to(global_position) < 1.6:
		interact(p)

func prompt() -> String:
	var nm := ItemDB.display_name(entry)
	var cnt := int(entry.get("count", 1))
	if cnt > 1:
		nm += " x%d" % cnt
	var w := ItemDB.weight_of(entry)
	return "Take %s  (%.1f kg)" % [nm, w] if w >= 0.05 else "Take %s" % nm

func interact(_p: Node) -> void:
	if taken:
		return
	taken = true
	GameData.add_entry(entry)
	var id: String = entry.get("id", "")
	if id == "silverleaf":
		GameData.progress("silverleaf", int(entry.get("count", 1)))
	elif id == "note_g9":
		GameData.progress("note_g9")
	if ItemDB.item_type(id) == "note":
		GameData.banner(ItemDB.get_def(id).name, ItemDB.get_def(id).desc, Color(0.9, 0.85, 0.7))
	SFX.play("pickup", -6.0, randf_range(1.0, 1.25))
	queue_free()
