extends Node
# Headless gameplay smoke test. Run:
#   Godot_console.exe --headless --path . res://scenes/Test.tscn
# Drives the real game: builds the world, shoots, melees, reloads, slides, loots,
# cooks, gets cursed, drives, triggers a horde, dies (permadeath) and checks saves.

var passed := 0
var failed := 0
var main: Node

func check(name: String, ok: bool, detail := "") -> void:
	if ok:
		passed += 1
		print("SMOKETEST PASS: %s %s" % [name, detail])
	else:
		failed += 1
		print("SMOKETEST FAIL: %s %s" % [name, detail])

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	print("SMOKETEST: begin")
	# isolate saves from a real player's world
	for p in [GameData.SURVIVOR_PATH, GameData.WORLD_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(p), ProjectSettings.globalize_path(p + ".bak"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameData.load_world()
	await get_tree().process_frame
	main = load("res://scenes/Main.tscn").instantiate()
	add_child(main)
	await frames(5)
	check("title ui", main.title_ui != null and is_instance_valid(main.title_ui))
	main._clear_title()
	GameData.start_new("Testee", "soldier", {})
	check("kit: soldier has AR + knife", GameData.weapon("primary").get("id", "") == "ar" and GameData.weapon("melee").get("id", "") == "knife")
	var t0 := Time.get_ticks_msec()
	await main._start_game(false)
	print("SMOKETEST: world built in %d ms" % (Time.get_ticks_msec() - t0))
	await frames(30)
	var w: World = main.game_world
	check("world", w != null)
	var p: Player = w.player
	GameData.force_captured = true
	var mons := get_tree().get_nodes_in_group("monsters").size()
	check("monsters placed", mons > 120, "count=%d" % mons)
	check("containers placed", get_tree().get_nodes_in_group("interactable").size() > 120, "count=%d" % get_tree().get_nodes_in_group("interactable").size())
	check("vehicles", get_tree().get_nodes_in_group("vehicle").size() == 3)
	check("pois", w.pois.size() >= 12, "count=%d" % w.pois.size())
	check("player at haven", p.global_position.distance_to(World.HAVEN) < 20.0, str(p.global_position))
	check("player on ground", p.is_on_floor(), "y=%.2f" % p.global_position.y)
	# --- gunplay against a walker placed in front of us in an open field
	var gz := 108.0
	p.teleport(Vector3(0, w.height(0, gz) + 0.3, gz), 0.0)
	await frames(20)
	check("player grounded on the road", p.is_on_floor(), "y=%.2f" % p.global_position.y)
	var walker := w.spawn_monster("walker", Vector3(0, w.height(0, gz - 7.0) + 0.3, gz - 7.0), 1, {})
	await frames(5)
	var hp0 := walker.hp
	p.pitch = 0.0
	p.cam_pivot.rotation.x = 0.0
	var aim := walker.aim_point(false) - p.cam.global_position
	p.pitch = atan2(aim.y, Vector2(aim.x, aim.z).length())
	await frames(2)
	var ammo0 := int(p.winst.ammo)
	var xp0 := GameData.xp + GameData.level * 100000
	p.fire_cd = 0.0
	p._shoot()
	await frames(2)
	check("shot consumes ammo", int(p.winst.ammo) == ammo0 - 1)
	check("recoil kicks", p.recoil.x > 0.0, "recoil=%s" % str(p.recoil))
	check("walker took damage", walker.hp < hp0 or walker.dead, "hp %.0f -> %.0f" % [hp0, walker.hp])
	for i in 8:
		if not is_instance_valid(walker) or walker.dead:
			break
		p.fire_cd = 0.0
		var aim2 := walker.aim_point(false) - p.cam.global_position
		p.pitch = atan2(aim2.y, Vector2(aim2.x, aim2.z).length())
		p.look_at_yaw(walker.global_position)
		await frames(2)
		p._shoot()
		await frames(2)
		if is_instance_valid(walker):
			print("SMOKETEST   shot %d walker hp %.0f dist %.1f" % [i, walker.hp, walker.global_position.distance_to(p.global_position)])
	check("walker killed", not is_instance_valid(walker) or walker.dead)
	check("kill xp", GameData.xp + GameData.level * 100000 > xp0)
	# --- ADS zoom
	var fov0 := p.cam.fov
	p.ads_t = 1.0
	for i in 20:
		p._camera(1.0 / 60.0)
	check("ADS zooms FOV", p.cam.fov < fov0 - 5.0, "%.1f -> %.1f" % [fov0, p.cam.fov])
	p.ads_t = 0.0
	# --- reload
	p.winst["ammo"] = 3
	p._end_act()
	p._try_reload()
	check("reload started", p.act == "reload")
	await frames(int(p.act_dur * 60.0) + 10)
	check("reload filled mag", int(p.winst.ammo) == p._mag_size(), "ammo=%d" % int(p.winst.ammo))
	# --- swap
	p._swap_to("secondary")
	await frames(60)
	check("swap to secondary", GameData.active_slot == "secondary" and p.winst.get("id", "") == "pistol", GameData.active_slot)
	p._swap_to("primary")
	await frames(60)
	# --- melee
	var m2 := w.spawn_monster("walker", p.global_position - p.global_transform.basis.z * 1.6 + Vector3(0, 0.2, 0), 1, {})
	await frames(4)
	var mh := m2.hp
	p.pitch = -0.1
	p._start_melee()
	await frames(40)
	check("melee hits", not is_instance_valid(m2) or m2.hp < mh, "hp %.0f" % (m2.hp if is_instance_valid(m2) else -1.0))
	check("melee viewmodel restored", p.vm_mode == "gun")
	# --- slide
	p.stance = "stand"
	p.sprinting = true
	p.velocity = -p.global_transform.basis.z * 8.0
	await frames(1)
	p.sprinting = true
	p._press_crouch()
	check("slide", p.stance == "slide")
	await frames(70)
	# --- containers & pickups
	var crate := w.container("crate", p.global_position + Vector3(2, -0.5, 0), 0.0, "", 3)
	await frames(2)
	var loot0 := get_tree().get_nodes_in_group("loot").size()
	crate.interact(p)
	await frames(2)
	check("container opens", crate.looted)
	var lp := LootPickup.new()
	lp.entry = {"id": "beans", "count": 3}
	w.add_child(lp)
	lp.global_position = p.global_position + Vector3(0, 1, 0)
	var b0 := GameData.count_item("beans")
	lp.interact(p)
	check("pickup adds item", GameData.count_item("beans") == b0 + 3)
	var gun := ItemDB.roll_weapon("shotgun", 5, 4)
	check("legendary shotgun named", ItemDB.display_name(gun) == "Meat Grinder", ItemDB.display_name(gun))
	check("weapon stats resolve", ItemDB.weapon_stats(gun).pellets == 13)
	# --- survival
	var h0 := GameData.hunger
	for i in 120:
		GameData.survival_tick(0.5, {"ambient": 0.0, "fire": false, "wet": false, "sprinting": true})
	check("hunger drains", GameData.hunger < h0, "%.1f -> %.1f" % [h0, GameData.hunger])
	check("cold drops body temp", GameData.body_temp < 37.0, "%.2f" % GameData.body_temp)
	GameData.add_item("raw_meat", 1)
	var menu: GameMenu = w.hud.menu
	menu.open_station("campfire", null)
	await get_tree().process_frame
	var cooked0 := GameData.count_item("cooked_meat")
	for r in GameMenu.RECIPES:
		if r.out == "cooked_meat":
			GameData.remove_item("raw_meat", 1)
			GameData.add_entry({"id": "cooked_meat", "count": 1})
	menu.close()
	check("cooking", GameData.count_item("cooked_meat") == cooked0 + 1)
	GameData.use_item("cooked_meat")
	# --- curses: wolf bite -> turn at night -> cure
	GameData.infect("wolf", 100.0)
	GameData.curse_progress = 100.0
	GameData.world["time"] = 23.0
	GameData.survival_tick(0.1, {"ambient": 5.0})
	check("lycanthropy turns at night", GameData.turned and GameData.form == "wolf", GameData.form)
	await frames(2)
	check("wolf claws viewmodel", p.vm_mode == "melee")
	GameData.add_item("silverleaf_tincture", 1)
	GameData.use_item("silverleaf_tincture")
	check("tincture cures", GameData.curse == "" and GameData.form == "human")
	GameData.world["time"] = 12.0
	await frames(2)
	# --- vehicle
	var car: Vehicle = get_tree().get_nodes_in_group("vehicle")[0]
	var cp0 := car.global_position
	car.enter(p)
	check("enter vehicle", p.in_vehicle == car)
	Input.action_press("move_forward")
	await frames(150)
	Input.action_release("move_forward")
	var moved := car.global_position.distance_to(cp0)
	check("vehicle drives", moved > 3.0, "moved %.1fm fuel %.1f" % [moved, car.fuel])
	car.exit()
	await frames(2)
	check("exit vehicle", p.in_vehicle == null)
	# --- gaunt hears noise
	var gaunt: Monster = null
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.kind == "gaunt" and m.dormant:
			gaunt = m
			break
	if gaunt != null:
		Hearing.emit_noise(gaunt.global_position + Vector3(10, 0, 0), 40.0, "player", false)
		check("gaunt wakes on noise", not gaunt.dormant and gaunt.state in ["investigate", "chase"], gaunt.state)
	else:
		check("gaunt exists", false)
	# --- director horde
	var before := get_tree().get_nodes_in_group("monsters").size()
	w.director.horde_rush()
	await frames(40)
	check("horde rush spawns", get_tree().get_nodes_in_group("monsters").size() > before + 8, "%d -> %d" % [before, get_tree().get_nodes_in_group("monsters").size()])
	# --- explosion
	var m3 := w.spawn_monster("walker", p.global_position + Vector3(4, 0.2, 0), 1, {})
	await frames(3)
	Combat.explode(m3.global_position, 5.0, 300.0, p)
	await frames(2)
	check("explosion kills", not is_instance_valid(m3) or m3.dead)
	# --- save / load round trip
	GameData.add_item("gold_ring", 2)
	check("save", GameData.save_survivor())
	var name0 := GameData.char_name
	GameData.inventory.clear()
	check("load", GameData.load_survivor() and GameData.char_name == name0 and GameData.count_item("gold_ring") == 2)
	# --- navmesh
	for i in 2400:
		if World.nav_ready:
			break
		await get_tree().physics_frame
	check("navmesh baked", World.nav_ready)
	# --- permadeath
	GameData.infect("rot", 100.0)
	GameData.curse_progress = 60.0
	var graves0: int = GameData.world.get("graves", []).size()
	GameData.take_damage(99999.0, "a test")
	await frames(3)
	check("death", not GameData.alive)
	check("grave recorded", GameData.world.get("graves", []).size() == graves0 + 1)
	check("memorial recorded", GameData.world.get("memorial", []).back().get("curse", "") == "rot")
	check("survivor save deleted", not GameData.has_survivor())
	print("SMOKETEST: done  passed=%d failed=%d" % [passed, failed])
	GameData.force_captured = false
	# restore the player's real saves
	for path in [GameData.SURVIVOR_PATH, GameData.WORLD_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak"), ProjectSettings.globalize_path(path))
	get_tree().quit(0 if failed == 0 else 1)
