extends StaticBody3D
# Lootable container (crate, locker, fridge, dumpster). Approach + press E:
# rolls a random table, transfers items to the player, shows a message.

class_name Interactable

var kind := "crate"
var looted := false
var label3d: Label3D
var title := "Container"

const TABLES := {
	"crate": [
		[["beans", 1, 3, 0.5], ["water", 1, 2, 0.4], ["shards", 3, 15, 0.7], ["pipe", 1, 1, 0.12], ["ammo_10mm", 4, 12, 0.45], ["bandage_n", 0, 0, 0.0]],
	],
	"locker": [
		[["armor_leather", 1, 1, 0.12], ["stimpak", 1, 2, 0.2], ["ammo_10mm", 6, 18, 0.4], ["cap_police", 1, 1, 0.08], ["hat_miner", 1, 1, 0.08], ["shards", 5, 25, 0.6], ["jerky", 1, 2, 0.3]],
	],
	"fridge": [
		[["beans", 1, 3, 0.6], ["cola", 1, 3, 0.4], ["water", 1, 2, 0.6], ["mut_meat", 1, 2, 0.3], ["stimpak", 1, 1, 0.1], ["radaway", 1, 1, 0.08]],
	],
	"dumpster": [
		[["shards", 1, 10, 0.6], ["beans", 1, 2, 0.3], ["water", 1, 1, 0.4], ["pipe", 1, 1, 0.15], ["bat", 1, 1, 0.1], ["ammo_10mm", 3, 10, 0.25]],
	],
	"weapons_stash": [
		[["pistol", 1, 1, 0.3], ["smg", 1, 1, 0.25], ["rifle", 1, 1, 0.15], ["machete", 1, 1, 0.2], ["sledge", 1, 1, 0.1], ["ammo_rifle", 5, 15, 0.5], ["energy_cell", 4, 12, 0.3], ["armor_combat", 1, 1, 0.08]],
	],
	# dedicated ammo caches: the map's scavengable ammunition supply
	"ammo_cache": [
		[["ammo_10mm", 10, 26, 0.85], ["ammo_rifle", 4, 10, 0.4], ["energy_cell", 3, 8, 0.3], ["shards", 2, 8, 0.5]],
	],
}

func setup(k: String, pos: Vector3, parent: Node) -> void:
	kind = k
	title = {
		"crate": "Supply Crate", "locker": "Rusty Locker", "fridge": "Dead Fridge",
		"dumpster": "Dumpster", "weapons_stash": "Weapons Stash",
		"ammo_cache": "Ammo Cache",
	}.get(k, "Container")
	if parent and get_parent() == null:
		parent.add_child(self)
	global_position = pos
	if label3d:
		label3d.text = "[E] " + title

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	var size := _size_for(kind)
	cs.size = size
	col.shape = cs
	col.position = Vector3(0, size.y * 0.5, 0)
	add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat_for(kind)
	mi.position = Vector3(0, size.y * 0.5, 0)
	add_child(mi)
	label3d = Label3D.new()
	label3d.text = "[E] " + title
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.font_size = 42
	label3d.outline_size = 8
	label3d.modulate = Color(0.9, 0.95, 0.7)
	label3d.position = Vector3(0, size.y + 0.5, 0)
	add_child(label3d)
	if kind == "ammo_cache":
		# olive ammo can with a brass band + shell rows on the lid
		var band := MeshInstance3D.new()
		var bm2 := BoxMesh.new(); bm2.size = Vector3(0.74, 0.06, 0.54)
		band.mesh = bm2
		var brm := StandardMaterial3D.new()
		brm.albedo_color = Color(0.72, 0.6, 0.25)
		brm.metallic = 0.8
		brm.roughness = 0.4
		band.material_override = brm
		band.position = Vector3(0, size.y * 0.55, 0)
		add_child(band)
		var handle := MeshInstance3D.new()
		var hm := BoxMesh.new(); hm.size = Vector3(0.3, 0.05, 0.04)
		handle.mesh = hm
		handle.material_override = brm
		handle.position = Vector3(0, size.y + 0.03, 0)
		add_child(handle)

func _size_for(k: String) -> Vector3:
	match k:
		"locker": return Vector3(0.8, 1.8, 0.6)
		"fridge": return Vector3(0.8, 1.6, 0.8)
		"dumpster": return Vector3(1.6, 1.0, 0.9)
		"weapons_stash": return Vector3(1.2, 0.6, 0.8)
		"ammo_cache": return Vector3(0.7, 0.42, 0.5)
		_: return Vector3(0.9, 0.7, 0.9)

func _mat_for(k: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.roughness = 0.9
	var key := "wood"
	match k:
		"crate":
			m.albedo_color = Color(0.75, 0.6, 0.4)
			key = "wood"
		"locker":
			m.albedo_color = Color(0.7, 0.75, 0.85); m.metallic = 0.6
			key = "corrugated"
		"fridge":
			m.albedo_color = Color(0.9, 0.88, 0.82); m.metallic = 0.4
			key = "plaster"
		"dumpster":
			m.albedo_color = Color(0.4, 0.6, 0.4); m.metallic = 0.5
			key = "rusty_metal"
		_:
			m.albedo_color = Color(0.6, 0.55, 0.45)
			key = "rusty_metal"
	# generated texture maps: albedo + height-derived normals
	m.albedo_texture = Proc.tex(key)
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var nm := Proc.normal_tex(key)
	if nm != null:
		m.normal_enabled = true
		m.normal_texture = nm
	return m

func interact(_by: Node) -> void:
	if looted:
		GameData.game_message("Already picked clean.", Color(0.7, 0.7, 0.7))
		return
	looted = true
	var gained := []
	var rolls: Array = TABLES.get(kind, TABLES["crate"])[0]
	for entry in rolls:
		var id: String = entry[0]
		var cmin: int = entry[1]; var cmax: int = entry[2]; var prob: float = entry[3]
		if cmin <= 0: continue
		if randf() <= prob:
			var count := randi_range(cmin, cmax)
			if GameData.add_item(id, count):
				gained.append("%s x%d" % [ItemDB.item_name(id), count])
	if gained.is_empty():
		GameData.game_message("Empty. The wasteland gives nothing today.", Color(0.7, 0.7, 0.7))
	else:
		GameData.game_message("Found: " + ", ".join(gained), Color(1.0, 0.9, 0.4))
	SFX.play("pickup", -2.0, 0.9)
	if label3d:
		label3d.text = "(looted)"
		label3d.modulate = Color(0.5, 0.5, 0.5)
