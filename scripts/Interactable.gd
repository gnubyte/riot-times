extends StaticBody3D
# Things you press [interact] on. Containers roll zone-leveled loot and pop it out
# as physics pickups; Haven stations open their panels; graves give back a dead
# survivor's gear; herbs, notes, beds and campfires do what they say.

class_name Interactable

const CONTAINER_TITLES := {
	"crate": "Supply Crate", "locker": "Locker", "fridge": "Fridge", "dumpster": "Dumpster",
	"car_trunk": "Car Trunk", "weapons": "Weapons Crate", "military": "Military Crate",
	"pharmacy": "Medicine Cabinet", "clothing": "Clothing Rack", "supermarket": "Shelf",
	"register": "Cash Register", "toolbox": "Toolbox", "lab": "Lab Cabinet", "raider": "Scrapjaw Stash",
	"ammo_box": "Ammo Can", "cabin": "Old Chest",
}
const STATIONS := {
	"trader": "Trade with Mags", "workbench": "Use Workbench", "stove": "Cook", "campfire": "Cook at Campfire",
	"bed": "Sleep", "stash": "Open Haven Stash", "board": "Bounty Board",
}

var kind := "crate"
var level := 1
var zone := ""
var looted := false
var title := ""
var data := {}
var _lid: Node3D = null
var _label: Label3D = null
var _respawn_t := 0.0

func setup(k: String, lvl := 1, opts := {}) -> Interactable:
	kind = k
	level = lvl
	zone = opts.get("zone", "")
	data = opts.get("data", {})
	title = CONTAINER_TITLES.get(k, STATIONS.get(k, k.capitalize()))
	return self

func is_container() -> bool:
	return CONTAINER_TITLES.has(kind)

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 2 | 8
	collision_mask = 0
	var size := _build()
	var keep: Array = []
	if _lid != null:
		keep.append(_lid)
	for m in MonsterBodies.merge_children(self, keep):
		(m as GeometryInstance3D).visibility_range_end = 75.0
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position = Vector3(0, size.y * 0.5, 0)
	add_child(col)
	if kind in ["trader", "workbench", "stove", "bed", "stash", "board", "grave"]:
		_label = Label3D.new()
		_label.text = title if kind != "grave" else "Grave of %s" % data.get("name", "a survivor")
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 30
		_label.outline_size = 8
		_label.modulate = Color(1.0, 0.85, 0.5) if kind != "grave" else Color(0.6, 1.0, 0.7)
		_label.position = Vector3(0, size.y + 0.45, 0)
		_label.visibility_range_end = 14.0
		add_child(_label)

func prompt() -> String:
	if kind == "grave":
		return "Recover %s's belongings" % data.get("name", "the dead")
	if kind == "herb":
		return "Harvest Silverleaf" if not looted else ""
	if kind == "note":
		return "Read %s" % ItemDB.get_def(data.get("note", "note_mall")).get("name", "note")
	if is_container():
		return ("Search %s" % title) if not looted else "%s (empty)" % title
	return STATIONS.get(kind, title)

func interact(p: Node) -> void:
	if is_container():
		_open_container()
		return
	match kind:
		"grave":
			_open_grave()
		"herb":
			if looted:
				return
			looted = true
			GameData.add_entry({"id": "silverleaf", "count": 1})
			GameData.progress("silverleaf")
			GameData.add_xp(20)
			SFX.play("pickup", -6.0, 0.8)
			visible = false
			_respawn_t = 600.0
			set_process(true)
		"note":
			var nid: String = data.get("note", "note_mall")
			if GameData.count_item(nid) == 0:
				GameData.add_entry({"id": nid, "count": 1})
				if nid == "note_g9":
					GameData.progress("note_g9")
					GameData.add_xp(250)
			GameData.banner(ItemDB.get_def(nid).name, ItemDB.get_def(nid).desc, Color(0.9, 0.85, 0.7))
		"bed":
			_sleep()
		_:
			var hud = get_tree().get_first_node_in_group("hud")
			if hud != null:
				hud.open_station(kind, self)

func _process(delta: float) -> void:
	if kind == "herb" and looted:
		_respawn_t -= delta
		if _respawn_t <= 0.0:
			looted = false
			visible = true
			set_process(false)

func _open_container() -> void:
	if looted:
		GameData.game_message("Already picked clean.", Color(0.7, 0.7, 0.7))
		return
	looted = true
	var luck := float(GameData.derived().luck) + (0.15 if GameData.is_night() else 0.0)
	var items := ItemDB.roll_container(kind, level, luck, GameData.owned_ammo_types())
	GameData.stats["looted"] = int(GameData.stats.get("looted", 0)) + 1
	if zone == "mall":
		GameData.progress("loot_mall")
	SFX.play_3d("open", global_position, -4.0, randf_range(0.9, 1.1), 20.0)
	Hearing.emit_noise(global_position, 6.0, "player", true)
	if items.is_empty():
		GameData.game_message("Nothing useful. The wasteland gives nothing today.", Color(0.7, 0.7, 0.7))
	_pop(items)
	if _lid != null:
		var t := create_tween()
		t.tween_property(_lid, "rotation:x", -1.4, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in get_children():
		if c is MeshInstance3D and c != _lid:
			var mi := c as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = m.albedo_color.darkened(0.35)
				mi.material_override = m
	GameData.add_xp(4)

func _pop(items: Array) -> void:
	var parent := get_parent()
	var up := global_position + Vector3(0, 1.0, 0)
	var fwd := -global_transform.basis.z
	var i := 0
	for e in items:
		var lp := LootPickup.new()
		lp.entry = e
		parent.add_child(lp)
		lp.global_position = up + Vector3(randf_range(-0.2, 0.2), i * 0.12, randf_range(-0.2, 0.2))
		lp.linear_velocity = fwd * randf_range(1.2, 2.4) + Vector3(randf_range(-1.2, 1.2), randf_range(2.5, 4.0), randf_range(-1.2, 1.2))
		lp.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		i += 1

func _open_grave() -> void:
	var items: Array = data.get("items", [])
	var sh := int(data.get("shards", 0))
	if sh > 0:
		items = items.duplicate()
		items.append({"id": "shards", "count": sh})
	_pop(items)
	GameData.remove_grave(int(data.get("gid", -1)))
	GameData.save_world()
	GameData.banner("REMEMBERED", "%s's gear is yours now." % data.get("name", "The dead"), Color(0.6, 1.0, 0.7))
	SFX.play("quest", -6.0, 0.8)
	queue_free()

func _sleep() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	var world := get_tree().get_first_node_in_group("world_root")
	var director := get_tree().get_first_node_in_group("director")
	if director != null and director.call("hostiles_near", global_position, 30.0) > 0:
		GameData.game_message("You can't sleep with the dead this close.", Color(1, 0.5, 0.4))
		return
	var t := GameData.time_of_day()
	var hours := 8.0
	if t >= 20.0:
		hours = (24.0 - t) + 7.0
	elif t < 6.0:
		hours = 7.0 - t
	else:
		hours = 3.0
	if director != null:
		director.call("skip_hours", hours)
	GameData.heal(60.0)
	GameData.hunger = maxf(5.0, GameData.hunger - hours * 2.5)
	GameData.thirst = maxf(5.0, GameData.thirst - hours * 3.0)
	GameData.body_temp = 37.0
	GameData.autosave()
	GameData.banner("YOU SLEEP", "%d hours pass. Game saved." % int(hours), Color(0.75, 0.8, 1.0))
	if p != null and world != null:
		world.call("fade_flash", Color(0, 0, 0), 1.2)

# ---------------- visuals ----------------
static var _mcache := {}
func _mat(c: Color, metal := 0.0, rough := 0.85, tex := "") -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [c.to_html(), metal, rough, tex]
	if _mcache.has(key):
		return _mcache[key]
	var m := _new_mat(c, metal, rough, tex)
	_mcache[key] = m
	return m

func _new_mat(c: Color, metal := 0.0, rough := 0.85, tex := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if tex != "":
		m.albedo_texture = Proc.tex(tex)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.5, 1.5, 1.5)
	return m

func _b(size: Vector3, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi

func _build() -> Vector3:
	match kind:
		"crate", "cabin":
			var wood := _mat(Color(0.62, 0.46, 0.3) if kind == "crate" else Color(0.45, 0.3, 0.18), 0.0, 0.9, "wood")
			_b(Vector3(0.9, 0.6, 0.9), Vector3(0, 0.3, 0), wood)
			_lid = Node3D.new()
			_lid.position = Vector3(0, 0.6, 0.45)
			add_child(_lid)
			_b(Vector3(0.92, 0.08, 0.92), Vector3(0, 0.04, -0.45), wood, _lid)
			return Vector3(0.9, 0.65, 0.9)
		"locker", "stash":
			var steel := _mat(Color(0.42, 0.48, 0.55) if kind == "locker" else Color(0.55, 0.42, 0.2), 0.6, 0.5, "corrugated")
			_b(Vector3(0.8, 1.9, 0.6), Vector3(0, 0.95, 0), steel)
			for i in 3:
				_b(Vector3(0.5, 0.03, 0.02), Vector3(0, 1.6 - i * 0.08, -0.31), _mat(Color(0.1, 0.1, 0.1)))
			return Vector3(0.8, 1.9, 0.6)
		"fridge":
			_b(Vector3(0.8, 1.7, 0.75), Vector3(0, 0.85, 0), _mat(Color(0.88, 0.87, 0.82), 0.3, 0.4))
			_b(Vector3(0.05, 0.4, 0.05), Vector3(0.3, 1.1, -0.4), _mat(Color(0.6, 0.6, 0.6), 0.8, 0.3))
			return Vector3(0.8, 1.7, 0.75)
		"dumpster":
			_b(Vector3(1.8, 1.1, 1.0), Vector3(0, 0.55, 0), _mat(Color(0.2, 0.4, 0.25), 0.5, 0.6, "rusty_metal"))
			_lid = Node3D.new()
			_lid.position = Vector3(0, 1.1, 0.5)
			add_child(_lid)
			_b(Vector3(1.82, 0.06, 1.02), Vector3(0, 0.03, -0.5), _mat(Color(0.12, 0.12, 0.12), 0.2, 0.8), _lid)
			return Vector3(1.8, 1.1, 1.0)
		"car_trunk":
			return Vector3(1.6, 0.9, 0.6)
		"weapons", "military", "ammo_box":
			var olive := _mat(Color(0.3, 0.36, 0.22), 0.3, 0.7)
			var sz := Vector3(1.3, 0.55, 0.7) if kind != "ammo_box" else Vector3(0.55, 0.38, 0.32)
			_b(sz, Vector3(0, sz.y * 0.5, 0), olive)
			_b(Vector3(sz.x * 0.6, 0.02, 0.02), Vector3(0, sz.y * 0.6, -sz.z * 0.5 - 0.01), _mat(Color(0.95, 0.8, 0.2), 0.0, 0.5))
			_lid = Node3D.new()
			_lid.position = Vector3(0, sz.y, sz.z * 0.5)
			add_child(_lid)
			_b(Vector3(sz.x + 0.02, 0.06, sz.z + 0.02), Vector3(0, 0.03, -sz.z * 0.5), olive, _lid)
			return sz
		"pharmacy", "lab":
			_b(Vector3(1.2, 1.8, 0.45), Vector3(0, 0.9, 0), _mat(Color(0.9, 0.92, 0.94) if kind == "pharmacy" else Color(0.6, 0.65, 0.68), 0.4, 0.4))
			_b(Vector3(0.3, 0.08, 0.02), Vector3(0, 1.4, -0.235), _mat(Color(0.9, 0.1, 0.1)))
			_b(Vector3(0.08, 0.3, 0.02), Vector3(0, 1.4, -0.235), _mat(Color(0.9, 0.1, 0.1)))
			return Vector3(1.2, 1.8, 0.45)
		"clothing":
			_b(Vector3(1.5, 0.05, 0.05), Vector3(0, 1.6, 0), _mat(Color(0.7, 0.7, 0.7), 0.8, 0.3))
			for i in 6:
				_b(Vector3(0.2, 0.7, 0.4), Vector3(-0.6 + i * 0.24, 1.2, 0), _mat(Color.from_hsv(float(randi() % 6) / 6.0, 0.5, 0.6)))
			return Vector3(1.5, 1.7, 0.5)
		"supermarket":
			var shelf := _mat(Color(0.55, 0.57, 0.6), 0.6, 0.5)
			_b(Vector3(2.2, 1.9, 0.7), Vector3(0, 0.95, 0), shelf)
			for y in 3:
				for x in 7:
					if randf() < 0.55:
						_b(Vector3(0.2, 0.28, 0.25), Vector3(-0.9 + x * 0.3, 0.45 + y * 0.6, -0.25), _mat(Color.from_hsv(float(randi() % 6) / 6.0, 0.6, 0.75)))
			return Vector3(2.2, 1.9, 0.7)
		"register":
			_b(Vector3(1.2, 1.0, 0.6), Vector3(0, 0.5, 0), _mat(Color(0.3, 0.28, 0.3), 0.2, 0.6))
			_b(Vector3(0.4, 0.25, 0.35), Vector3(0, 1.12, 0), _mat(Color(0.15, 0.15, 0.17), 0.5, 0.4))
			return Vector3(1.2, 1.25, 0.6)
		"toolbox":
			_b(Vector3(0.7, 0.35, 0.35), Vector3(0, 0.175, 0), _mat(Color(0.75, 0.12, 0.08), 0.5, 0.5))
			return Vector3(0.7, 0.35, 0.35)
		"raider":
			var scrap := _mat(Color(0.5, 0.35, 0.2), 0.5, 0.7, "rusty_metal")
			_b(Vector3(1.2, 0.7, 0.8), Vector3(0, 0.35, 0), scrap)
			for i in 4:
				_b(Vector3(0.04, 0.25, 0.04), Vector3(-0.45 + i * 0.3, 0.82, 0), _mat(Color(0.7, 0.7, 0.7), 0.8, 0.3))
			return Vector3(1.2, 0.7, 0.8)
		"trader":
			var wood2 := _mat(Color(0.5, 0.36, 0.22), 0.0, 0.9, "wood")
			_b(Vector3(2.6, 1.05, 0.7), Vector3(0, 0.52, 0), wood2)
			var npc := MonsterBodies.build("guard", RandomNumberGenerator.new())
			var nroot: Node3D = npc.root
			nroot.position = Vector3(0, 0, 0.9)
			nroot.rotation.y = PI
			add_child(nroot)
			var sign := Label3D.new()
			sign.text = "TRADE"
			sign.font_size = 120
			sign.modulate = Color(2.0, 1.4, 0.3)
			sign.outline_size = 0
			sign.position = Vector3(0, 2.6, 0.9)
			sign.rotation.y = PI
			add_child(sign)
			return Vector3(2.6, 1.05, 0.7)
		"workbench":
			var wood3 := _mat(Color(0.55, 0.4, 0.26), 0.0, 0.9, "wood")
			_b(Vector3(2.0, 0.12, 0.9), Vector3(0, 0.95, 0), wood3)
			for x in [-0.9, 0.9]:
				for z in [-0.38, 0.38]:
					_b(Vector3(0.1, 0.9, 0.1), Vector3(x, 0.45, z), wood3)
			_b(Vector3(0.25, 0.2, 0.2), Vector3(-0.6, 1.1, 0), _mat(Color(0.3, 0.3, 0.32), 0.8, 0.4))
			_b(Vector3(0.6, 0.05, 0.1), Vector3(0.3, 1.04, 0.1), _mat(Color(0.6, 0.15, 0.1), 0.6, 0.5))
			return Vector3(2.0, 1.05, 0.9)
		"stove", "campfire":
			if kind == "stove":
				Viewmodels.cyl(self, 0.4, 0.9, Vector3(0, 0.45, 0), _mat(Color(0.25, 0.22, 0.2), 0.6, 0.7, "rusty_metal"), false)
				Viewmodels.cyl(self, 0.22, 0.2, Vector3(0, 1.0, 0), _mat(Color(0.5, 0.5, 0.52), 0.8, 0.4), false)
			else:
				for i in 8:
					var a := TAU * i / 8.0
					_b(Vector3(0.22, 0.15, 0.22), Vector3(cos(a) * 0.45, 0.07, sin(a) * 0.45), _mat(Color(0.45, 0.43, 0.4)))
				_b(Vector3(0.7, 0.08, 0.08), Vector3(0, 0.1, 0), _mat(Color(0.3, 0.2, 0.1)), null).rotation.y = 0.6
				_b(Vector3(0.7, 0.08, 0.08), Vector3(0, 0.14, 0), _mat(Color(0.3, 0.2, 0.1)), null).rotation.y = -0.7
			var flame := _b(Vector3(0.25, 0.35, 0.25), Vector3(0, 0.35 if kind == "campfire" else 0.95, 0), _new_mat(Color(1.0, 0.55, 0.15), 0.0, 1.0))
			(flame.material_override as StandardMaterial3D).emission_enabled = true
			(flame.material_override as StandardMaterial3D).emission = Color(1.0, 0.5, 0.1)
			(flame.material_override as StandardMaterial3D).emission_energy_multiplier = 4.0
			flame.set_meta("flame", true)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.55, 0.2)
			l.omni_range = 9.0
			l.light_energy = 2.0
			l.position.y = 0.8
			l.shadow_enabled = kind == "campfire"
			add_child(l)
			add_to_group("fires")
			return Vector3(0.9, 0.9, 0.9) if kind == "stove" else Vector3(1.0, 0.3, 1.0)
		"bed":
			_b(Vector3(0.9, 0.4, 2.0), Vector3(0, 0.2, 0), _mat(Color(0.35, 0.33, 0.28), 0.0, 0.9))
			_b(Vector3(0.85, 0.12, 1.9), Vector3(0, 0.46, 0), _mat(Color(0.5, 0.2, 0.18), 0.0, 1.0))
			_b(Vector3(0.6, 0.1, 0.35), Vector3(0, 0.55, 0.75), _mat(Color(0.85, 0.82, 0.75), 0.0, 1.0))
			return Vector3(0.9, 0.6, 2.0)
		"board":
			_b(Vector3(1.8, 1.2, 0.08), Vector3(0, 1.6, 0), _mat(Color(0.55, 0.4, 0.25), 0.0, 0.9, "wood"))
			for x in [-0.8, 0.8]:
				_b(Vector3(0.1, 2.2, 0.1), Vector3(x, 1.1, 0), _mat(Color(0.4, 0.28, 0.18)))
			for i in 5:
				_b(Vector3(0.3, 0.35, 0.01), Vector3(-0.6 + i * 0.3, 1.6 + randf_range(-0.3, 0.3), -0.05), _mat(Color(0.92, 0.9, 0.8)))
			return Vector3(1.8, 2.2, 0.3)
		"grave":
			var stone := _mat(Color(0.5, 0.5, 0.5), 0.0, 0.9)
			_b(Vector3(0.1, 1.2, 0.1), Vector3(0, 0.6, 0.3), stone)
			_b(Vector3(0.6, 0.1, 0.1), Vector3(0, 0.95, 0.3), stone)
			_b(Vector3(0.5, 0.4, 0.35), Vector3(0, 0.2, -0.2), _mat(Color(0.35, 0.3, 0.2)))
			var gl := OmniLight3D.new()
			gl.light_color = Color(0.4, 1.0, 0.6)
			gl.omni_range = 5.0
			gl.light_energy = 1.2
			gl.position.y = 1.0
			add_child(gl)
			return Vector3(0.7, 1.2, 0.8)
		"herb":
			var leaf := _new_mat(Color(0.75, 0.95, 0.9), 0.0, 0.5)
			leaf.emission_enabled = true
			leaf.emission = Color(0.6, 1.0, 0.95)
			leaf.emission_energy_multiplier = 1.4
			for i in 6:
				var a2 := TAU * i / 6.0
				_b(Vector3(0.05, 0.35, 0.12), Vector3(cos(a2) * 0.1, 0.17, sin(a2) * 0.1), leaf).rotation = Vector3(cos(a2) * 0.4, a2, sin(a2) * 0.4)
			return Vector3(0.4, 0.4, 0.4)
		"note":
			_b(Vector3(0.3, 0.02, 0.4), Vector3(0, 0.01, 0), _mat(Color(0.92, 0.88, 0.72)))
			var gl2 := OmniLight3D.new()
			gl2.light_color = Color(1.0, 0.9, 0.6)
			gl2.omni_range = 2.0
			gl2.light_energy = 0.8
			gl2.position.y = 0.3
			add_child(gl2)
			return Vector3(0.4, 0.15, 0.5)
	_b(Vector3(0.8, 0.6, 0.8), Vector3(0, 0.3, 0), _mat(Color(0.5, 0.5, 0.5)))
	return Vector3(0.8, 0.6, 0.8)
