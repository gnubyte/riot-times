extends Control
# Character creator: species pick, appearance options, name, live 3D preview.

class_name CharacterCreator

signal done(cfg: Dictionary)
signal back

var species := "human"
var look := {"skin": 0, "hair": 0, "head": 0, "build": 0, "voice": 0}
var name_edit: LineEdit
var preview: SubViewport
var preview_root: Node3D
var model: Node3D
var spin_angle := 0.0
var stat_preview_label: Label

const SPECIES_INFO := {
	"human": {"str": 5, "per": 5, "agl": 5, "end": 5, "cha": 6, "int": 5, "lck": 5, "hp": 100, "note": "Jack of all trades. +1 CHA"},
	"ghoul": {"str": 6, "per": 5, "agl": 5, "end": 7, "cha": 2, "int": 5, "lck": 5, "hp": 90, "note": "Rad-proof, sturdy, hideous. Raw mutant meat is free food."},
	"robot": {"str": 7, "per": 5, "agl": 4, "end": 5, "cha": 3, "int": 6, "lck": 5, "hp": 130, "note": "No hunger, no pain, no charm. Runs on fusion cores."},
}
const SKIN_NAMES := {
	"human": ["Dust-Pale", "Sun-Burnt", "Deep Brown", "Ashen", "Freckled"],
	"ghoul": ["Glow-Green", "Charred", "Moldy", "Mottled", "Radioactive"],
	"robot": ["Brushed Steel", "Rusted", "Chrome", "Camouflage", "Warning Yellow"],
}
const HAIR_NAMES := ["Bald", "Mohawk", "Shaggy", "Buzzcut", "Topknot", "Crazy"]
const HEAD_NAMES := ["Angular", "Round", "Long", "Boxy"]
const BUILD_NAMES := ["Lean", "Average", "Hulking"]

func _ready() -> void:
	theme = UITheme.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid := HBoxContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("separation", 20)
	add_child(grid)

	# left: preview
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_child(left)
	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.custom_minimum_size = Vector2(520, 520)
	left.add_child(vc)
	preview = SubViewport.new()
	preview.size = Vector2i(520, 520)
	preview.transparent_bg = false
	vc.add_child(preview)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 3.2)
	cam.rotation_degrees = Vector3(-8, 0, 0)
	cam.fov = 50
	preview.add_child(cam)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.14, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.75, 0.7)
	env.ambient_light_energy = 1.2
	we.environment = env
	preview.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_color = Color(1.0, 0.85, 0.6)
	key.light_energy = 1.2
	preview.add_child(key)
	var floor_mi := MeshInstance3D.new()
	var fm := CylinderMesh.new(); fm.height = 0.2; fm.top_radius = 1.4; fm.bottom_radius = 1.4
	floor_mi.mesh = fm
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = Color(0.3, 0.27, 0.24)
	floor_mi.material_override = fmat
	floor_mi.position = Vector3(0, -0.1, 0)
	preview.add_child(floor_mi)
	preview_root = Node3D.new()
	preview.add_child(preview_root)

	var ptit := Label.new()
	ptit.text = "PREVIEW (auto-rotates)"
	ptit.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left.add_child(ptit)

	# right: controls (scroll) with pinned button bar below
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(460, 0)
	grid.add_child(right)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sc)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 8)
	sc.add_child(box)

	var t := Label.new()
	t.text = "WHO SURVIVES THIS TIME?"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	box.add_child(t)
	var warn := Label.new()
	warn.text = "One life. When this survivor dies, they're gone for good,\nbut their body, their gear and Haven's stash stay in the world."
	warn.add_theme_font_size_override("font_size", 14)
	warn.add_theme_color_override("font_color", Color(0.85, 0.55, 0.45))
	box.add_child(warn)
	var fallen: int = GameData.world.get("memorial", []).size()
	if fallen > 0:
		var mem := Label.new()
		mem.text = "%d survivor%s rest on the memorial wall." % [fallen, "" if fallen == 1 else "s"]
		mem.add_theme_font_size_override("font_size", 13)
		mem.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		box.add_child(mem)

	# name
	var nrow := HBoxContainer.new()
	box.add_child(nrow)
	nrow.add_child(_lbl("Name:"))
	name_edit = LineEdit.new()
	name_edit.text = ["Rook", "Mara", "Jonah", "Ash", "Nova", "Cutter", "Wren", "Dutch"][randi() % 8]
	name_edit.custom_minimum_size = Vector2(220, 0)
	nrow.add_child(name_edit)

	# background (kit + edge) — pick a different one every life
	box.add_child(_lbl("Background:"))
	var srow := HFlowContainer.new()
	box.add_child(srow)
	for bg in ["soldier", "medic", "mechanic", "hunter", "drifter"]:
		var b := Button.new()
		b.text = String(GameData.BACKGROUNDS[bg].name).to_upper()
		b.toggle_mode = true
		b.button_pressed = bg == background
		b.pressed.connect(_pick_bg.bind(bg))
		srow.add_child(b)
		species_buttons[bg] = b
	stat_preview_label = Label.new()
	stat_preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stat_preview_label.custom_minimum_size = Vector2(420, 0)
	stat_preview_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	box.add_child(stat_preview_label)

	box.add_child(_sep())
	_choice_row(box, "Skin tone", "skin")
	_choice_row(box, "Hair / head shape", "hair")
	_choice_row(box, "Head", "head")
	_choice_row(box, "Build", "build")

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	right.add_child(btn_row)
	var b_back := Button.new()
	b_back.text = "← Back"
	b_back.custom_minimum_size = Vector2(140, 50)
	b_back.pressed.connect(func(): back.emit())
	btn_row.add_child(b_back)
	var b_go := Button.new()
	b_go.text = "ENTER THE WASTELAND"
	b_go.custom_minimum_size = Vector2(300, 50)
	b_go.add_theme_font_size_override("font_size", 20)
	b_go.pressed.connect(_confirm)
	btn_row.add_child(b_go)
	UIFX.bezzle(b_back)
	UIFX.bezzle(b_go)
	_pick_bg(background)
	b_go.call_deferred("grab_focus")

var species_buttons := {}
var choice_buttons := {}

func _lbl(s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_color_override("font_color", Color(0.8, 0.78, 0.72))
	return l

func _sep() -> Control:
	var c := HSeparator.new()
	c.custom_minimum_size = Vector2(0, 14)
	return c

func _choice_row(parent: VBoxContainer, label: String, key: String) -> void:
	parent.add_child(_lbl(label + ":"))
	var row := HBoxContainer.new()
	parent.add_child(row)
	var b_left := Button.new()
	b_left.text = "<"
	b_left.pressed.connect(_cycle.bind(key, -1))
	row.add_child(b_left)
	var val := Label.new()
	val.custom_minimum_size = Vector2(150, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.name = "VAL"
	row.add_child(val)
	var b_right := Button.new()
	b_right.text = ">"
	b_right.pressed.connect(_cycle.bind(key, 1))
	row.add_child(b_right)
	choice_buttons[key] = val
	_update_choice_label(key)

func _max_for(key: String) -> int:
	match key:
		"skin": return 5
		"hair": return HAIR_NAMES.size()
		"head": return HEAD_NAMES.size()
		"build": return BUILD_NAMES.size()
	return 1

func _cycle(key: String, dir: int) -> void:
	look[key] = posmod(int(look[key]) + dir, _max_for(key))
	SFX.play("ui", -10.0)
	_update_choice_label(key)
	_rebuild_model()

func _update_choice_label(key: String) -> void:
	var val: Label = choice_buttons[key]
	match key:
		"skin":
			var names: Array = SKIN_NAMES[species]
			val.text = names[int(look[key]) % names.size()]
		"hair": val.text = HAIR_NAMES[int(look[key])]
		"head": val.text = HEAD_NAMES[int(look[key])]
		"build": val.text = BUILD_NAMES[int(look[key])]

var background := "drifter"
const KITS := {
	"soldier": "Kit: Scrap AR + 60 rounds, sidearm, knife, frag, bandages, jacket.",
	"medic": "Kit: Rattler 9 + ammo, knife, medkit, 4 bandages, antibiotics, jacket.",
	"mechanic": "Kit: Boomstick + shells, sidearm, pipe wrench, scrap, weapon parts, road leathers.",
	"hunter": "Kit: Whisper Crossbow + bolts, sidearm, sharp knife, fishing rod, campfire kit, jacket.",
	"drifter": "Kit: Hand Cannon .44, sidearm, machete, jerky, soda, beanie, satchel.",
}

func _pick_bg(bg: String) -> void:
	background = bg
	species = "human"
	for k in species_buttons:
		species_buttons[k].button_pressed = (k == bg)
	var info: Dictionary = GameData.BACKGROUNDS[bg]
	stat_preview_label.text = "%s\n%s" % [String(info.desc), KITS[bg]]
	_update_choice_label("skin")
	last_sig = ""
	_rebuild_model()
	SFX.play("ui", -8.0, 1.2)

# ---------- model ----------
var last_sig := ""
func _rebuild_model() -> void:
	var sig := species + "|" + str(look)
	if sig == last_sig: return
	last_sig = sig
	for c in preview_root.get_children():
		c.queue_free()
	if model: model.queue_free()
	model = Node3D.new()
	preview_root.add_child(model)
	_build_mannequin(model)

func _mat(c: Color, metal := 0.0, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = 0.8
	if emis > 0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)
	return mi

func _sph(parent: Node, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2; sm.radial_segments = 12; sm.rings = 8
	mi.mesh = sm; mi.material_override = mat; mi.position = pos
	parent.add_child(mi)
	return mi

func skin_color() -> Color:
	match species:
		"human":
			match int(look["skin"]):
				0: return Color(0.86, 0.72, 0.6)
				1: return Color(0.75, 0.55, 0.4)
				2: return Color(0.5, 0.34, 0.24)
				3: return Color(0.7, 0.62, 0.55)
				_: return Color(0.8, 0.6, 0.5)
		"ghoul":
			match int(look["skin"]):
				0: return Color(0.45, 0.62, 0.3)
				1: return Color(0.35, 0.3, 0.28)
				2: return Color(0.5, 0.55, 0.35)
				3: return Color(0.55, 0.45, 0.4)
				_: return Color(0.6, 0.8, 0.3)
		_:
			match int(look["skin"]):
				0: return Color(0.7, 0.72, 0.75)
				1: return Color(0.55, 0.35, 0.25)
				2: return Color(0.85, 0.87, 0.9)
				3: return Color(0.35, 0.45, 0.3)
				_: return Color(0.9, 0.8, 0.2)

func _build_mannequin(root: Node3D) -> void:
	var skin := _mat(skin_color(), 0.6 if species == "robot" else 0.0)
	var cloth := _mat({"soldier": Color(0.3, 0.34, 0.24), "medic": Color(0.82, 0.82, 0.8), "mechanic": Color(0.75, 0.42, 0.15),
		"hunter": Color(0.35, 0.28, 0.18), "drifter": Color(0.55, 0.48, 0.38)}.get(background, Color(0.3, 0.28, 0.24)))
	var build := int(look["build"])
	var w: float = [0.34, 0.4, 0.5][build]
	# legs
	_box(root, Vector3(w * 0.45, 0.8, w * 0.45), Vector3(w * 0.28, 0.4, 0), cloth)
	_box(root, Vector3(w * 0.45, 0.8, w * 0.45), Vector3(-w * 0.28, 0.4, 0), cloth)
	# torso
	_box(root, Vector3(w, 0.75, w * 0.6), Vector3(0, 1.18, 0), skin if species == "robot" else cloth)
	# arms
	_box(root, Vector3(w * 0.3, 0.75, w * 0.3), Vector3(w * 0.68, 1.15, 0), skin)
	_box(root, Vector3(w * 0.3, 0.75, w * 0.3), Vector3(-w * 0.68, 1.15, 0), skin)
	# neck + head shape
	var hh: float = [0.42, 0.46, 0.52, 0.4][int(look["head"])]
	var hw: float = [0.38, 0.46, 0.34, 0.46][int(look["head"])]
	_box(root, Vector3(hw * 0.55, 0.28, hw * 0.55), Vector3(0, 1.58, 0), skin)
	_box(root, Vector3(hw, hh, hw), Vector3(0, 1.78 + hh * 0.4, 0), skin)
	# eyes
	var head_top := 1.78 + hh * 0.9
	var eye_mat := _mat(Color(0.1, 0.1, 0.1) if species != "robot" else Color(1, 0.15, 0.1), 0, 2.0 if species == "robot" else 0)
	_sph(root, 0.04, Vector3(hw * 0.22, 1.78 + hh * 0.55, hw * 0.52), eye_mat)
	_sph(root, 0.04, Vector3(-hw * 0.22, 1.78 + hh * 0.55, hw * 0.52), eye_mat)
	# hair
	match int(look["hair"]):
		1: _box(root, Vector3(hw * 0.3, 0.22, hh * 0.9), Vector3(0, head_top + 0.11, 0), _mat(Color(0.5, 0.1, 0.5)))
		2: _box(root, Vector3(hw * 1.15, 0.18, hh * 1.1), Vector3(0, head_top + 0.02, 0.02), _mat(Color(0.2, 0.15, 0.1)))
		3: _box(root, Vector3(hw * 0.95, 0.1, hh * 0.95), Vector3(0, head_top, 0), _mat(Color(0.1, 0.1, 0.1)))
		4: _box(root, Vector3(hw * 0.3, 0.25, hw * 0.3), Vector3(0, head_top + 0.12, -0.05), _mat(Color(0.3, 0.2, 0.1)))
		5:
			for i in 5:
				_box(root, Vector3(0.05, 0.3, 0.05), Vector3(cos(i * 1.2) * hw * 0.4, head_top + 0.15, sin(i * 1.2) * hw * 0.4), _mat(Color(randf_range(0.2, 0.9), randf_range(0.2, 0.9), randf_range(0.2, 0.9))))
		_: pass
	# species extras
	if species == "ghoul":
		# patches
		for i in 4:
			_sph(root, 0.06, Vector3(randf_range(-w/2, w/2), randf_range(0.9, 1.6), randf_range(-0.1, 0.3)), _mat(Color(0.3, 0.4, 0.2)))
	elif species == "robot":
		# antenna
		_box(root, Vector3(0.03, 0.35, 0.03), Vector3(hw * 0.3, head_top + 0.18, 0), _mat(Color(0.6, 0.6, 0.6), 0.9))
		_sph(root, 0.05, Vector3(hw * 0.3, head_top + 0.4, 0), _mat(Color(1, 0.2, 0.2), 0, 3))
		# chest light
		_sph(root, 0.06, Vector3(0, 1.3, w * 0.32), _mat(Color(0.2, 0.9, 1.0), 0, 3))

func _process(delta: float) -> void:
	spin_angle += delta * 0.8
	if model:
		model.rotation.y = sin(spin_angle) * 0.9

func _confirm() -> void:
	var pname := name_edit.text
	GameData.start_new(pname, background, look)
	SFX.play("levelup", -6.0)
	done.emit(look)
