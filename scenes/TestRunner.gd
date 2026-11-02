extends Node
# Temporary automated gameplay smoke test. Run via: godot --headless res://scenes/Test.tscn

func _ammo_caches() -> int:
	var n := 0
	for i in get_tree().get_nodes_in_group("interactable"):
		if i.kind == "ammo_cache":
			n += 1
	return n

func _test_mouse(p: Node) -> void:
	# mouse-look: inject a captured mouse-motion event, camera must yaw+pitch
	GameData.force_captured = true
	p.dead = false
	p.rotation = Vector3.ZERO
	p.cam_pitch = 0.0
	var m := InputEventMouseMotion.new()
	m.relative = Vector2(120.0, -60.0)
	m.button_mask = 0
	Input.parse_input_event(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var yaw_ok := absf(p.rotation.y) > 0.05
	var pitch_ok := absf(p.cam_pitch) > 0.05
	print("SMOKETEST mouse-look: yaw=%.3f pitch=%.3f -> %s" % [p.rotation.y, p.cam_pitch, "PASS" if (yaw_ok and pitch_ok) else "FAIL"])
	# left click fires (equipped gun, ammo loaded), via the event queue.
	# NOTE: parse_input_event defers dispatch, so the event object must not be mutated
	# afterwards — use separate press/release instances or the press arrives as a release.
	GameData.equip("pistol")
	p._refresh_viewmodel()
	GameData.give_reserve("ammo_10mm", 30)
	GameData.loaded_ammo["pistol"] = 12
	p.block_fire_until = 0
	p.fire_accum = 0.0
	p._fire_queued = false
	var btn_pos: Vector2 = p.get_parent().hud.reload_btn.get_global_rect().get_center()
	var bp := InputEventMouseButton.new()
	bp.button_index = MOUSE_BUTTON_LEFT
	bp.pressed = true
	bp.position = btn_pos
	Input.parse_input_event(bp)
	var br := InputEventMouseButton.new()
	br.button_index = MOUSE_BUTTON_LEFT
	br.pressed = false
	br.position = btn_pos
	Input.parse_input_event(br)
	var fired := false
	for i in 12:
		await get_tree().physics_frame
		if int(GameData.loaded_ammo.get("pistol", 12)) < 12:
			fired = true
	print("SMOKETEST click fires gun: ammo=%d queued=%s acc=%.2f block=%d slot=%s gun=%s -> %s" % [
		int(GameData.loaded_ammo.get("pistol", -1)), str(p._fire_queued), p.fire_accum,
		p.block_fire_until, GameData.active_slot, GameData.equipped.gun, "PASS" if fired else "FAIL"])
	# R key reloads (start below full mag so the reload is accepted)
	GameData.loaded_ammo["pistol"] = 4
	p.reload_t = 0.0
	p.reloading = false
	var r := InputEventKey.new()
	r.keycode = KEY_R
	r.physical_keycode = KEY_R
	r.pressed = true
	Input.parse_input_event(r)
	var ru := InputEventKey.new()
	ru.keycode = KEY_R
	ru.physical_keycode = KEY_R
	ru.pressed = false
	Input.parse_input_event(ru)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("SMOKETEST R reload: reloading=%s -> %s" % [str(p.reloading), "PASS" if p.reloading else "FAIL"])
	p.reloading = false
	# clean up injected state so later tests don't inherit camera/key drift
	GameData.force_captured = false
	p._fire_queued = false
	p._reload_queued = false
	p._interact_queued = false
	p.cam_pitch = 0.0
	p.rotation = Vector3.ZERO
	p.cam.rotation = Vector3.ZERO

func _test_new_systems(p: Node) -> void:
	# sprint drains stamina (needs forward input like real gameplay)
	p.stamina = 100.0
	Input.action_press("sprint")
	Input.action_press("move_forward")
	p._physics_process(1.0 / 60.0)
	p._physics_process(1.0 / 60.0)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	print("SMOKETEST sprint: sprinting=%s stamina<100: %s" % [str(p.sprinting), str(p.stamina < 100.0)])
	# reload via button path (smg is equipped)
	GameData.give_reserve("ammo_10mm", 60)
	p._start_reload()
	print("SMOKETEST reload started: %s (expect true)" % str(p.reloading))
	p.reload_t = 0.01
	p._physics_process(0.05)
	print("SMOKETEST reload finished, smg mag=%d (expect >0)" % int(GameData.loaded_ammo.get("smg", -1)))
	# recoil spring kicks then settles
	p.recoil_vel_p = 2.0
	for i in 40:
		p._physics_process(1.0 / 60.0)
	print("SMOKETEST recoil settles: pitch=%.3f" % absf(p.recoil_pitch))
	# hit flinch moves the camera
	p.flinch_vel = 1.5
	p._physics_process(1.0 / 60.0)
	print("SMOKETEST flinch: pitch=%.3f vm=%.2f" % [p.flinch_pitch, p.vm_flinch])
	await _test_mantle(p)

func _test_mantle(p: Node) -> void:
	# teleport to the sandbag emplacement (waist-high wall) and walk into it
	var world := get_tree().get_first_node_in_group("world_root")
	if world == null:
		print("SMOKETEST FAIL: no world for mantle test")
		return
	p.mantling = false
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(55.0, 0.3, 10.4)   # 1.5m south of the sandbag line at z=8.5
	p.rotation.y = 0                               # default forward is -Z: faces the wall
	for i in 30:
		await get_tree().physics_frame            # settle on the ground
	Input.action_press("move_forward")
	var mantled := false
	var y_before: float = p.global_position.y
	for i in 90:
		await get_tree().physics_frame
		if p.mantling or p.global_position.y > y_before + 0.5:
			mantled = true
			break
	Input.action_release("move_forward")
	if mantled:
		# let the mantle finish; player should end up past the sandbag wall (z < 8.4)
		for i in 90:
			await get_tree().physics_frame
			if not p.mantling and p.velocity.length() < 0.1:
				break
		mantled = p.global_position.z < 8.5
	Input.action_release("move_forward")
	print("SMOKETEST mantle over sandbag: %s (y %.2f -> %.2f gate=%s pos=%s)" % [str(mantled), y_before, p.global_position.y, str(p._dbg_gate), str(p.global_position)])
	if not mantled:
		print("SMOKETEST FAIL: mantle did not trigger")
	else:
		print("SMOKETEST PASS: mantle")

func _ready() -> void:
	print("SMOKETEST: begin")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var main_scene: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main_scene)
	for i in 30:
		await get_tree().process_frame
	if main_scene.title_ui == null or not is_instance_valid(main_scene.title_ui):
		print("SMOKETEST FAIL: title ui missing")
	else:
		print("SMOKETEST PASS: title ui built")
	# settings menu round-trip from title
	main_scene._open_settings(Callable())
	await get_tree().process_frame
	main_scene._close_settings()
	UITheme.set_window_mode("windowed")
	UITheme.master_volume(0.8)
	var db: float = AudioServer.get_bus_volume_db(0)
	print("SMOKETEST master 0.8 => bus0 %.1f dB (expect ~-1.9)" % db)
	UITheme.master_volume(1.0)
	UITheme.sfx_volume(0.5)
	print("SMOKETEST sfx bus: ", AudioServer.get_bus_name(AudioServer.get_bus_index("SFX")), " db=", AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	UITheme.sfx_volume(1.0)
	print("SMOKETEST res list: ", UITheme.available_resolutions())
	main_scene.title_ui.queue_free()
	main_scene.title_ui = null
	GameData.start_new("human", "Testee", {"skin": 1, "hair": 2, "head": 0, "build": 1})
	await main_scene._start_game(false)
	print("SMOKETEST: game started")
	for i in 120:
		await get_tree().process_frame
	var world: Node = main_scene.game_world
	if world == null:
		print("SMOKETEST FAIL: no world")
		get_tree().quit(1)
		return
	print("SMOKETEST: world ok, players=%d enemies=%d interactables=%d ammo_caches=%d" % [
		get_tree().get_nodes_in_group("player").size(),
		get_tree().get_nodes_in_group("enemies").size(),
		get_tree().get_nodes_in_group("interactable").size(),
		_ammo_caches()])
	GameData.add_item("pistol", 1)
	GameData.add_item("smg", 1)
	GameData.add_item("armor_leather", 1)
	GameData.add_item("hat_cowboy", 1)
	GameData.add_item("beans", 3)
	GameData.equip("smg")
	GameData.give_reserve("ammo_10mm", 60)
	print("SMOKETEST INV: %d slots, shards=%d" % [GameData.inventory.size(), GameData.shards])
	GameData.eat("beans")
	print("SMOKETEST hunger after beans: ", GameData.hunger)
	GameData.equip("hat_cowboy")
	GameData.equip("armor_leather")
	print("SMOKETEST derived: ", GameData.derived())
	var p: Node = get_tree().get_nodes_in_group("player")[0]
	await _test_mouse(p)
	await _test_new_systems(p)
	var live: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			live.append(e)
	print("SMOKETEST live enemies: %d of %d" % [live.size(), get_tree().get_nodes_in_group("enemies").size()])
	if live.size() > 0:
		var e: Node = live[0]
		p.rotation = Vector3.ZERO
		p.cam.rotation = Vector3.ZERO
		e.global_position = p.global_position + Vector3(0, 0.9, -3.0)
		await get_tree().physics_frame
		p.rotation = Vector3.ZERO
		p.cam.rotation = Vector3.ZERO
		await get_tree().physics_frame
		var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
		var from: Vector3 = p.cam.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, 0, -10), 2 | 4 | 8)
		q.exclude = [p.get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		print("SMOKETEST probe-ray hit: ", hit.get("collider", "NONE"))
		print("SMOKETEST enemy now at ", e.global_position, " cam at ", p.cam.global_position)
		p._shoot_ray(p.cam, 500.0, "test", 300.0, 0.0)
		await get_tree().process_frame
		print("SMOKETEST enemy hp after 500 dmg: %.1f dead=%s" % [e.hp, e.dead])
		if e.hp > 0:
			print("SMOKETEST FAIL: ray did not damage enemy")
		else:
			print("SMOKETEST PASS: enemy killed by ray")
	GameData.add_xp(250)
	print("SMOKETEST: after 250xp level=%d points=%d" % [GameData.level, GameData.stat_points])
	GameData.take_damage(99999.0, "test")
	print("SMOKETEST: death triggered, alive=%s" % str(GameData.alive))
	GameData.revive_at()
	print("SMOKETEST: revived hp=%.0f alive=%s" % [GameData.hp, str(GameData.alive)])
	# species rules: robot can't eat food but can use fusion core; ghoul rad resist
	GameData.start_new("robot", "Stobby", {})
	var ate: bool = GameData.eat("beans")
	print("SMOKETEST robot ate beans (should be false): ", ate)
	GameData.add_item("fusion_core", 1)
	GameData.hp = 50
	var used: bool = GameData.eat("fusion_core")
	print("SMOKETEST robot used fusion core (true) hp back up: ", used, " hp=", GameData.hp)
	GameData.start_new("ghoul", "Ghoulia", {})
	GameData.add_radiation(50.0)
	print("SMOKETEST ghoul rads after 50 rad (resisted, expect ~20): %.1f" % GameData.rads)
	GameData.add_item("mut_meat", 1)
	GameData.eat("mut_meat")
	print("SMOKETEST ghoul ate mut meat, hunger=%.0f" % GameData.hunger)
	# pause must freeze the world
	var pf: Node = get_tree().get_nodes_in_group("player")[0]
	var elive: Array = []
	for e3 in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e3) and not e3.dead:
			elive.append(e3)
	var watched: Node = elive[0]
	watched.aggro = true
	watched.target = pf
	main_scene._pause()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pos_a: Vector3 = watched.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pos_b: Vector3 = watched.global_position
	print("SMOKETEST pause freeze: moved=%.4f (expect 0)" % pos_a.distance_to(pos_b))
	if pos_a.distance_to(pos_b) > 0.05:
		print("SMOKETEST FAIL: world not frozen while paused")
	else:
		print("SMOKETEST PASS: pause freezes world")
	# pause -> settings -> back must return to PAUSE (frozen), not live game
	main_scene._open_settings(Callable(func():
		if main_scene.mode == 3 or main_scene.mode == 2:
			main_scene._pause()))
	await get_tree().process_frame
	var settings_open: bool = main_scene.settings_menu != null
	main_scene._close_settings()
	await get_tree().process_frame
	# simulate BACK press closing the menu with its callback
	if settings_open:
		print("SMOKETEST PASS: settings opened from pause")
	else:
		print("SMOKETEST FAIL: settings did not open from pause")
	# now test the callback path directly
	main_scene._open_settings(Callable(func(): main_scene._pause()))
	await get_tree().process_frame
	main_scene.settings_menu.closed.emit()
	main_scene._close_settings()
	await get_tree().process_frame
	print("SMOKETEST after settings back: paused=%s pause_visible=%s mouse=%d" % [str(get_tree().paused), str(main_scene.pause_menu.visible), Input.get_mouse_mode()])
	if get_tree().paused and main_scene.pause_menu.visible and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		print("SMOKETEST PASS: settings back returns to frozen pause menu")
	else:
		print("SMOKETEST FAIL: settings back did not restore pause")
	main_scene._resume()
	# melee damage test
	GameData.start_new("human", "Melee", {})
	GameData.add_item("sledge", 1)
	GameData.equip("sledge")
	var p2: Node = get_tree().get_nodes_in_group("player")[0]
	var live2: Array = []
	for e2 in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e2) and not e2.dead:
			live2.append(e2)
	if live2.size() > 0:
		var e2: Node = live2[0]
		p2.rotation = Vector3.ZERO
		p2.cam.rotation = Vector3.ZERO
		e2.global_position = p2.global_position + Vector3(0, 0.8, -1.5)
		await get_tree().physics_frame
		p2.rotation = Vector3.ZERO
		p2.cam.rotation = Vector3.ZERO
		await get_tree().physics_frame
		p2._melee()
		await get_tree().process_frame
		print("SMOKETEST melee sledge: enemy hp=%.0f (max %.0f)" % [e2.hp, e2.hp_max])
	# container interaction
	var conts: Array = get_tree().get_nodes_in_group("interactable")
	if conts.size() > 0:
		var c: Node = conts[0]
		var before: int = GameData.inventory.size() + GameData.shards
		c.interact(null)
		var after: int = GameData.inventory.size() + GameData.shards
		print("SMOKETEST container interact: before=%d after=%d looted=%s" % [before, after, c.looted])
		c.interact(null)  # second time should say "already picked clean"
	# save & load
	GameData.add_item("shards", 123)
	GameData.add_item("rifle", 1)
	GameData.add_xp(60)
	var saved: bool = GameData.save_game()
	GameData.start_new("human", "Blank", {})
	var loaded: bool = GameData.load_game()
	print("SMOKETEST save=%s load=%s name=%s shards=%d rifle=%d xp=%d" % [saved, loaded, GameData.char_name, GameData.shards, GameData.count_item("rifle"), GameData.xp])
	# quit to title must tear down world and rebuild the menu
	GameData.show_title.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if main_scene.game_world == null and main_scene.title_ui != null and is_instance_valid(main_scene.title_ui) and not get_tree().paused:
		print("SMOKETEST PASS: quit to title rebuilt menu and freed world")
	else:
		print("SMOKETEST FAIL: quit to title state world=%s title=%s paused=%s" % [main_scene.game_world, main_scene.title_ui, get_tree().paused])
	print("SMOKETEST: done")
	get_tree().quit(0)
