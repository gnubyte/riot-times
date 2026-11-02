extends StaticBody3D
# Dropped loot you walk near / press E to take. Spinning box with a floating label.

class_name LootPickup

var item_id := "shards"
var count := 1
var taken := false

func setup(id: String, c := 1) -> void:
	item_id = id
	count = c

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.22, 0.22)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	match ItemDB.get_def(item_id).get("type", "misc"):
		"gun", "melee": m.albedo_color = Color(0.6, 0.62, 0.7); m.metallic = 0.7
		"ammo": m.albedo_color = Color(0.8, 0.65, 0.2)
		"armor": m.albedo_color = Color(0.45, 0.4, 0.3)
		"hat": m.albedo_color = Color(0.6, 0.3, 0.5)
		_: m.albedo_color = Color(0.85, 0.75, 0.3)
	m.emission_enabled = true
	m.emission = m.albedo_color * 0.5
	mi.material_override = m
	add_child(mi)
	_mesh = mi
	var lbl := Label3D.new()
	lbl.text = "%s x%d" % [ItemDB.item_name(item_id), count]
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 34
	lbl.outline_size = 6
	lbl.modulate = Color(1, 0.92, 0.45)
	add_child(lbl)
	_label = lbl
	lbl.position = Vector3(0, 0.45, 0)
	add_to_group("loot")

var _mesh: MeshInstance3D
var _label: Label3D
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	if _mesh:
		_mesh.rotate_y(delta * 2.0)
		_mesh.position.y = sin(_t * 2.5) * 0.06

func try_pickup() -> bool:
	if taken:
		return false
	taken = true
	GameData.add_item(item_id, count)
	SFX.play("pickup", -6.0, randf_range(1.0, 1.3))
	queue_free()
	return true
