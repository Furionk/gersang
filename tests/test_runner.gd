extends Node
var game: GameDirector
var failures: Array[String] = []
var passed: Array[String] = []
var data: Dictionary = {}

func check(condition: bool, title: String) -> void:
	if condition:
		passed.append(title)
		print("PASS | ", title)
	else:
		failures.append(title)
		push_error("FAIL | " + title)

func _ready() -> void:
	call_deferred("_run")

func _wait_mode(expected: StringName) -> void:
	var deadline: int = Time.get_ticks_msec() + 8000
	while game.mode != expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(game.mode == expected, "mode: " + String(expected))

func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _simulate(unit: TacticalUnit, seconds: float) -> void:
	for frame: int in int(seconds * 60):
		unit.tick(1.0 / 60.0)
		await get_tree().physics_frame

func _run() -> void:
	var start_time: int = Time.get_ticks_msec()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	game.cinematic_camera = false
	await _wait_mode(&"world")
	var initial_orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	check(game.world_views.size() == 22, "world has 22 independent clickable parties")
	check(game.world_hero != null and game.world_context.navigation != null, "world uses restricted AStar navigation service")
	var definitions: Array[UnitDefinition] = Catalog.party()
	check(definitions.size() == 7, "hero plus six independent roles")
	var atlas_ok: bool = true
	for definition: UnitDefinition in definitions:
		atlas_ok = atlas_ok and ResourceLoader.exists(definition.sprite_path)
	check(atlas_ok, "seven original raster sprite atlases imported")
	var ui_press: InputEventMouseButton = InputEventMouseButton.new()
	ui_press.position = game.hud.world_hud.toolbar[7].get_global_rect().get_center()
	ui_press.button_index = MOUSE_BUTTON_LEFT
	ui_press.pressed = true
	var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_motion.position = ui_press.position
	get_viewport().push_input(mouse_motion, true)
	await get_tree().process_frame
	get_viewport().push_input(ui_press, true)
	var ui_release: InputEventMouseButton = ui_press.duplicate() as InputEventMouseButton
	ui_release.pressed = false
	get_viewport().push_input(ui_release, true)
	await get_tree().process_frame
	print("GUI_ROUTE | modal=", game.hud.settings_panel != null and game.hud.settings_panel.visible, " command=", game.world_hero.active)
	check(game.hud.settings_panel != null and game.hud.settings_panel.visible and game.world_hero.active.is_empty(), "native GUI click opens settings without issuing ground movement")
	game.hud.close_windows()
	GameSettings.settings_path = "user://gersang_acceptance_settings.cfg"
	var original_key: int = int(GameSettings.bindings["skill_blast"])
	check(not GameSettings.rebind("skill_blast", KEY_1) and int(GameSettings.bindings["skill_blast"]) == original_key, "rebinding cannot shadow reserved group or camera keys")
	GameSettings.rebind("skill_blast", KEY_U)
	var persisted: ConfigFile = ConfigFile.new()
	var saved_ok: bool = persisted.load(GameSettings.settings_path) == OK
	check(saved_ok and int(persisted.get_value("keys", "skill_blast", 0)) == KEY_U, "rebound shortcut persists independently of user save")
	GameSettings.rebind("skill_blast", original_key)

	# Real engine navigation around the blocked rectangle.
	game.set_physics_process(false)
	var hero: TacticalUnit = game.world_hero
	game.world_context.state["player"]["position"] = Vector2(1100,1800)
	game.world_context.move_player(Vector2(1450,2400))
	for frame: int in 390:
		game.world_context.tick(1.0/60.0)
	hero.position = game.world_context.state["player"]["position"]
	data["world_navigation"] = {"endpoint": str(hero.position), "state": String(hero.fsm.current), "target": str(hero.nav_target)}
	print("WORLD_NAV | ", data["world_navigation"])
	check(hero.position.distance_to(Vector2(1450,2400)) < 28, "world click movement routes across river bridge")
	check(not game.ground.is_blocked(Vector2i(hero.position / Iso.CELL)), "path destination is walkable")
	var monster: Dictionary = game.world_context.state["maps"]["river_bay"]["parties"].values()[0]
	game.world_context.state["player"]["position"] = monster["position"]+Vector2(5,0)
	hero.position = game.world_context.state["player"]["position"]
	var return_point: Vector2 = hero.position
	game.world_return = return_point
	game.set_physics_process(true)
	game.world_context.encounters.try_begin("player",monster["party_id"],"player")
	game._physics_process(1.0/60.0)
	check(game.mode == &"countdown" and game.hud.countdown.visible, "3-second encounter countdown visible")
	await _seconds(1.1)
	check(game.mode == &"countdown" and game.countdown_left > 1.0, "countdown does not enter combat early")
	await _wait_mode(&"battle")
	game.set_physics_process(false)
	var ids: Array[int] = game.living_ids(0)
	check(ids.size() == 7 and game.living_ids(1).size() == monster["deployed_units"].size(), "battle spawns fixed original party and enemy instances")
	var merchant: TacticalUnit = game.get_unit(ids[0])
	var guard: TacticalUnit = game.get_unit(ids[1])
	var mage: TacticalUnit = game.get_unit(ids[3])
	var healer: TacticalUnit = game.get_unit(ids[4])
	var supplier: TacticalUnit = game.get_unit(ids[5])
	var controller: TacticalUnit = game.get_unit(ids[6])
	var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])

	game.selection.select_ids([ids[1]])
	check(game.selection.selected_ids == [ids[1]], "single selection uses unit identity")
	game.selection.select_ids([ids[2]], true)
	check(game.selection.selected_ids.size() == 2, "Shift additive selection")
	game.selection.select_ids([ids[2]], true)
	check(game.selection.selected_ids == [ids[1]], "Shift toggles a selected unit")
	game.selection.select_ids([ids[0], ids[1], ids[2]])
	game.selection.store_group(8)
	game.selection.select_ids([])
	game.selection.recall_group(8)
	check(game.selection.selected_ids.size() == 3, "Ctrl group store and number recall")
	game.selection.select_box(Rect2(-2000, -2000, 4000, 4000))
	check(game.selection.selected_ids.size() == 7, "marquee picks only living friendly units")
	game.selection.select_ids([guard.unit_id])

	guard.issue_command({"kind": "move", "point": Vector2(800, 700)})
	guard.issue_command({"kind": "move", "point": Vector2(600, 740), "queued": true})
	check(guard.queued.size() == 1, "Shift command appends to queue")
	guard.issue_command({"kind": "hold"})
	check(guard.queued.is_empty() and guard.held and guard.fsm.current == &"hold", "new hold command overrides queue")
	var guard_position: Vector2 = guard.position
	enemy.position = guard.position + Vector2(90, 0)
	await _simulate(guard, 0.6)
	check(guard.position.distance_to(guard_position) < 1.0, "hold does not chase beyond attack range")
	guard.issue_command({"kind": "stop"})
	check(guard.reacquire_left > 0.0 and guard.fsm.current == &"idle", "stop cancels command and delays reacquisition")
	await _simulate(guard, 0.7)
	check(guard.fsm.current in [&"chase", &"attack"], "friendly auto-detection resumes after stop delay")
	await _simulate(enemy, 3.1)
	check(enemy.fsm.current in [&"chase", &"attack"], "enemy independently detects and attacks party")

	# Out-of-range casts walk first, without consuming mana.
	guard.definition = guard.definition.duplicate(true) as UnitDefinition
	var blast: SkillDefinition = guard.definition.skills[0].duplicate(true) as SkillDefinition
	blast.id = &"windup_fixture"
	blast.target_mode = SkillDefinition.Target.GROUND
	blast.range = 90.0
	blast.cast_time = 0.4
	guard.definition.skills.append(blast)
	var mp_before: float = guard.vitals.mana
	guard.issue_command({"kind": "cast", "skill": blast, "point": guard.position + Vector2(180, 0)})
	guard.tick(1.0 / 60.0)
	check(is_equal_approx(guard.vitals.mana, mp_before), "out-of-range cast approaches before MP consumption")
	guard.issue_command({"kind": "stop"})
	enemy.position = guard.position + Vector2(35, 0)
	mp_before = guard.vitals.mana
	var hp_before: float = enemy.vitals.health
	guard.issue_command({"kind": "cast", "skill": blast, "point": enemy.position})
	guard.tick(1.0 / 60.0)
	check(guard.cast_left > 0 and guard.vitals.mana <= mp_before - blast.mana_cost + 0.1, "valid casting spends MP at windup start")
	guard.issue_command({"kind": "move", "point": guard.position + Vector2(50, 0)})
	await _simulate(guard, 0.3)
	check(enemy.vitals.health == hp_before and guard.cast_left < 0, "move cancels uncommitted spell damage")
	guard.issue_command({"kind": "cast", "skill": blast, "point": enemy.position})
	await _simulate(guard, 0.7)
	check(enemy.vitals.health < hp_before and guard.casts > 0, "blast releases area damage at fixed-time commit")

	merchant.vitals.mana = 10
	merchant.position = supplier.position + Vector2(25, 0)
	var supply: SkillDefinition = supplier.definition.skills[0]
	supplier.issue_command({"kind": "cast", "skill": supply, "point": merchant.position, "target": merchant.unit_id})
	await _simulate(supplier, 0.5)
	check(merchant.vitals.mana > 40, "targeted supply restores friendly MP")
	var spent: float = supplier.vitals.mana
	supplier.issue_command({"kind": "cast", "skill": supply, "target": -900, "point": supplier.position})
	supplier.tick(1.0 / 60.0)
	check(supplier.vitals.mana >= spent, "invalid friendly target does not spend MP")
	supplier.vitals.mana = 0
	check(not supplier.can_cast(supply), "MP exhaustion prevents casting")

	guard.position = healer.position + Vector2(30, 0)
	guard.vitals.health = 35
	healer.think_left = 0
	await _simulate(healer, 1.0)
	check(guard.vitals.health > 35, "automatic healer restores critically injured ally")
	enemy.position = controller.position + Vector2(40, 0)
	controller.issue_command({"kind": "cast", "skill": controller.definition.skills[0], "point": enemy.position})
	await _simulate(controller, 0.65)
	check(enemy.control_left > 0.0, "control skill applies timed crowd control")

	# Legacy repeat flags must not bypass a fresh click under the V3 contract.
	guard.vitals.mana = blast.mana_cost * 2.0 + 1
	enemy.vitals.max_health = 10000
	enemy.vitals.health = 10000
	guard.cooldowns.clear()
	var casts_before: int = guard.casts
	guard.issue_command({"kind": "cast", "skill": blast, "point": guard.position, "repeat": true})
	await _simulate(guard, 3.2)
	check(guard.casts == casts_before + 1 and guard.repeat_command.is_empty(), "legacy reserved-repeat request casts once only")
	game.selection.sequence_slots = [guard.unit_id, mage.unit_id, supplier.unit_id, controller.unit_id]
	game.selection.sequence_index = 0
	guard.vitals.mana = 0
	mage.cooldowns.clear()
	mage.vitals.mana = 100
	var sequence_id: int = game.selection.sequence_cast(mage.position)
	check(sequence_id == mage.unit_id and game.selection.sequence_index == 2, "E sequence skips unavailable slot and advances once")
	game.selection.select_ids([mage.unit_id])
	game.selection.arm(&"skill_lightning")
	check(game.selection.armed == &"skill_lightning", "GUI and key actions arm same skill command")
	game.selection.cancel()
	check(game.selection.armed == &"", "cancel clears targeting state")
	mage.issue_command({"kind": "stop"})
	mage.cooldowns.clear()
	mage.vitals.mana = 150
	var held_before: int = mage.casts
	game.selection.select_ids([mage.unit_id])
	game.selection.arm(&"skill_lightning")
	game.selection._cast_armed(mage.position)
	game.selection.cancel()
	# Simulate an old target/profile: holding a skill cannot replay it anymore.
	game.selection.repeat_target[mage.unit_id] = {"skill": mage.definition.skills[0], "point": mage.position, "target": -1}
	Input.action_press("skill_lightning")
	for frame: int in 192:
		mage.tick(1.0 / 60.0)
		game.selection.tick()
		await get_tree().physics_frame
	Input.action_release("skill_lightning")
	var held_after: int = mage.casts
	check(held_after == held_before + 1, "held skill action cannot repeat without a new click")
	await _simulate(mage, 0.6)
	check(mage.casts == held_after, "releasing skill key stops further held repeats")
	mage.issue_command({"kind": "stop"})

	# A projectile already committed survives cancellation of the attacker command.
	var gunner: TacticalUnit = game.get_unit(ids[2])
	enemy.vitals.health = enemy.vitals.max_health
	hp_before = enemy.vitals.health
	game.basic_attack(gunner, enemy, 8.0)
	gunner.issue_command({"kind": "stop"})
	game._tick_projectiles(10.0)
	check(enemy.vitals.health < hp_before, "fired projectile survives stop command")
	var before_health: float = mage.vitals.health
	guard.vitals.damage(3)
	check(mage.vitals.health == before_health, "shared unit definitions do not share runtime health")

	# Real-time fixed-step measurements at two presentation caps.
	data["timing"] = await _timing_measurements(merchant)
	var measurements: Array = data["timing"]
	check(absf(float(measurements[0]["duration"]) - float(measurements[1]["duration"])) < 0.13, "movement timing consistent at 30 and 120 presentation FPS")
	check(int(measurements[0]["shots"]) == int(measurements[1]["shots"]) and int(measurements[0]["shots"]) >= 2, "attack counts consistent at 30 and 120 presentation FPS")
	var blocked_destination: Vector2 = (Vector2(game.ground.blocked[0].position)+Vector2(game.ground.blocked[0].size)*0.5)*Iso.CELL
	merchant.issue_command({"kind": "move", "point": blocked_destination})
	await _simulate(merchant, 4.5)
	check(merchant.active.is_empty() and merchant.position.distance_to(blocked_destination) > 25.0 and game.hud.log_lines.any(func(line: String) -> bool: return line.contains("不可達")), "unreachable destination stops at walkable boundary with notice")
	game.set_physics_process(true)
	game.hud.toggle_menu()
	var live_time: float = game.time_in_battle
	await _seconds(0.2)
	check(game.time_in_battle > live_time and game.mode == &"battle", "battle menu does not pause simulation")
	game.hud.close_windows()

	for id: int in game.living_ids(1):
		game.get_unit(id).vitals.damage(99999)
	await _wait_mode(&"results")
	check(game.last_result == "victory", "victory result flow")
	game.start_world()
	await _wait_mode(&"world")
	check(game.world_hero.position.distance_to(return_point) < 1.0, "return restores pre-encounter logical position")
	for theme: int in 3:
		game.start_battle(Catalog.encounters()[theme])
		await _wait_mode(&"battle")
		check(game.ground.terrain == theme, "terrain " + str(theme) + " initializes")
		check(game.units.values().all(func(unit: TacticalUnit) -> bool: return not game.ground._navigation_blocked(Vector2i(unit.position / Iso.CELL))), "terrain " + str(theme) + " spawns every unit clear of obstacles")
		game.retreat()
		check(game.mode == &"results" and game.last_result == "retreat", "retreat result " + str(theme))
	game.start_battle(Catalog.encounters()[0])
	await _wait_mode(&"battle")
	for id: int in game.living_ids(0):
		game.get_unit(id).vitals.damage(99999)
	await _wait_mode(&"results")
	check(game.last_result == "defeat", "defeat result flow")

	game.start_battle(Catalog.encounters()[0], true)
	await _wait_mode(&"battle")
	check(game.living_ids(0).size() == 12 and game.living_ids(1).size() == 60, "stress fixture: 12 allies / 60 enemies")
	check(game.units.values().all(func(unit: TacticalUnit) -> bool: return not game.ground._navigation_blocked(Vector2i(unit.position / Iso.CELL))), "72-unit stress spawns are navigable")
	game.selection.dispatch("attack_move", Vector2(950, 650))
	await _seconds(1.2)
	var active_count: int = 0
	for unit: TacticalUnit in game.units.values():
		if unit.alive() and unit.fsm.current in [&"move", &"chase", &"attack", &"cast"]:
			active_count += 1
	data["stress_active_units"] = active_count
	check(active_count >= 8, "stress measurements include actively moving or fighting units")
	var samples: Array[float] = []
	var previous: int = Time.get_ticks_usec()
	for frame: int in 180:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	data["stress_frame_ms_p95"] = samples[int(samples.size() * 0.95)]
	data["stress_physics_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	data["command_latency_max_ms"] = game.command_latency_ms
	game.start_world()
	await _wait_mode(&"world")
	await get_tree().process_frame
	check(game.units.size() == 1 and game.projectiles.is_empty(), "repeated scene transitions clear battle units and pending projectiles")
	data["orphan_nodes_initial"] = initial_orphans
	data["orphan_nodes_final"] = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	check(float(data["orphan_nodes_final"]) <= initial_orphans + 1, "scene reloads do not accumulate orphan nodes")
	data["duration_seconds"] = (Time.get_ticks_msec() - start_time) / 1000.0
	data["passed"] = passed
	data["failures"] = failures
	var file: FileAccess = FileAccess.open(TestArtifacts.output("acceptance","acceptance-results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("GERSANG_ACCEPTANCE_%s | passed=%d failed=%d | stress_p95_ms=%.3f" % ["PASS" if failures.is_empty() else "FAIL", passed.size(), failures.size(), data["stress_frame_ms_p95"]])
	get_tree().quit(0 if failures.is_empty() else 1)

func _timing_measurements(unit: TacticalUnit) -> Array[Dictionary]:
	var measurements: Array[Dictionary] = []
	for fps: int in [30, 120]:
		Engine.max_fps = fps
		unit.position = Vector2(220, 750)
		unit.previous_position = unit.position
		unit.issue_command({"kind": "move", "point": Vector2(420, 750)})
		var start_ms: int = Time.get_ticks_msec()
		while not unit.active.is_empty() and Time.get_ticks_msec() - start_ms < 5000:
			await get_tree().physics_frame
			unit.tick(1.0 / 60.0)
		measurements.append({"fps": fps, "duration": (Time.get_ticks_msec() - start_ms) / 1000.0, "end": str(unit.position)})
		var target: TacticalUnit = game.get_unit(game.living_ids(1)[0])
		target.position = unit.position + Vector2(20, 0)
		target.vitals.health = 10000
		unit.attack_timer = 0.0
		var initial_shots: int = unit.shots
		unit.issue_command({"kind": "attack", "target": target.unit_id})
		await _simulate(unit, 2.7)
		measurements[-1]["shots"] = unit.shots - initial_shots
		unit.issue_command({"kind": "stop"})
	Engine.max_fps = 120
	return measurements
