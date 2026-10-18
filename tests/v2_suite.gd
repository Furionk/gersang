extends Node

func authored_skill_ids(units: Array[TacticalUnit]) -> Array:
	var result: Dictionary = {}
	for unit: TacticalUnit in units:
		for skill: SkillDefinition in unit.available_skills():
			if skill.manual(): result[skill.id]=true
	var ids: Array = result.keys(); ids.sort()
	return ids
func hud_skill_ids() -> Array:
	var ids: Array = game.hud.skill_buttons.keys(); ids.sort()
	return ids
var game: GameDirector
var failures: Array[String] = []
var passed: Array[String] = []
var metrics: Dictionary = {}
func check(value: bool, name_text: String) -> void:
	if value:
		passed.append(name_text)
		print("PASS | ", name_text)
	else:
		failures.append(name_text)
		push_error("FAIL | " + name_text)
func skill(unit: TacticalUnit, id: StringName) -> SkillDefinition:
	for candidate: SkillDefinition in unit.definition.skills:
		if candidate.id == id:
			return candidate
	return null
func fixed_skill_fixture() -> EncounterDefinition:
	# This suite uses fixed skill-range coordinates; random shipped deployments are
	# tested separately by battlefield_scene_suite and multi_party_suite.
	var fixture: EncounterDefinition = Catalog.encounters()[0].duplicate(true)
	fixture.battlefield_scene=""
	return fixture
func wait_mode(expected: StringName) -> void:
	var end: int = Time.get_ticks_msec() + 10000
	while game.mode != expected and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	check(game.mode == expected, "mode " + String(expected))
func effects_for(seconds: float, step: float = 1.0 / 60.0) -> void:
	for frame: int in int(round(seconds / step)):
		game._tick_effects(step)
func clear_effects() -> void:
	for effect: BattleSkillEffect in game.effects:
		effect.finish()
	game.effects.clear()
func ready(unit: TacticalUnit) -> void:
	unit.issue_command({"kind":"stop"})
	unit.cooldowns.clear()
	unit.vitals.mana = unit.vitals.max_mana
func walk_to(unit: TacticalUnit, destination: Vector2) -> void:
	unit.issue_command({"kind":"move", "point":destination})
	var path: PackedVector2Array = NavigationServer2D.map_get_path(unit.agent.get_navigation_map(), unit.position, destination, true)
	var length: float = 0
	for i: int in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	var expected_ms: int = int((length / (unit.definition.speed * GameSettings.profile.movement_multiplier) + 2.0) * 1000)
	var deadline: int = Time.get_ticks_msec() + maxi(10000, expected_ms)
	while not unit.active.is_empty() and Time.get_ticks_msec() < deadline:
		unit.tick(1.0 / 60)
		await get_tree().physics_frame
	unit._stop_motion()
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	LegacyPartyFixture.install()
	var stats: Dictionary = {"strength":20, "attack":24, "intelligence":30, "agility":15, "vitality":25, "level":10}
	check(DamageFormula.evaluate("力量×2", stats)["value"] == 40.0, "Chinese strength formula")
	check(DamageFormula.evaluate("傷害*2", stats)["value"] == 48.0, "damage alias means base attack")
	check(DamageFormula.evaluate("智慧*2", stats)["value"] == 60.0, "wisdom alias maps to intelligence")
	check(DamageFormula.evaluate("(attack+level)*2", stats)["value"] == 68.0, "parenthesized arithmetic")
	check(not DamageFormula.evaluate("attack/0", stats)["valid"], "division by zero rejected")
	check(not DamageFormula.evaluate("unknown*2", stats)["valid"], "unknown variable rejected")
	check(not DamageFormula.evaluate("sqrt(attack)", stats)["valid"], "function calls rejected")
	check(DamageFormula.evaluate("-5", stats)["value"] == 0.0, "negative damage clamped")
	check(is_equal_approx(DamageFormula.mitigate(40, 0.25), 30), "armor applied exactly once")
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	game.cinematic_camera = false
	await wait_mode(&"world")
	game.start_battle(fixed_skill_fixture())
	await wait_mode(&"battle")
	game.set_physics_process(false)
	var ids: Array[int] = game.roster_ids.duplicate()
	var hero: TacticalUnit = game.get_unit(ids[0])
	var guard: TacticalUnit = game.get_unit(ids[1])
	var gunner: TacticalUnit = game.get_unit(ids[2])
	var mage: TacticalUnit = game.get_unit(ids[3])
	var healer: TacticalUnit = game.get_unit(ids[4])
	var supplier: TacticalUnit = game.get_unit(ids[5])
	var controller: TacticalUnit = game.get_unit(ids[6])
	var victim: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	var outside: TacticalUnit = game.get_unit(game.living_ids(1)[1])
	victim.vitals.max_health = 10000
	victim.vitals.health = 10000
	victim.vitals.armor = 0
	outside.vitals.max_health = 10000
	outside.vitals.health = 10000
	outside.vitals.armor = 0

	game.selection.select_ids([guard.unit_id])
	check(hud_skill_ids()==authored_skill_ids([guard]) and game.hud.skill_buttons.has(&"blast"), "selected guard shows exact authored skills including blast")
	var icon: TextureRect = game.hud.skill_buttons[&"blast"].get_child(0) as TextureRect
	check(icon.expand_mode == TextureRect.EXPAND_IGNORE_SIZE and icon.size.x <= 36, "skill atlas cannot enlarge or overflow HUD")
	game.selection.select_ids([guard.unit_id, mage.unit_id])
	check(hud_skill_ids()==authored_skill_ids([guard,mage]), "mixed selection exposes exact authored union of skills")
	var clone: TacticalUnit = game.spawn_unit(guard.definition, 0, Vector2(280, 660), false)
	game.selection.select_ids([guard.unit_id, clone.unit_id])
	check(game.selection.visible_skills().size()==authored_skill_ids([guard]).size() and game.selection.visible_skills().all(func(entry: Dictionary) -> bool: return entry.owners.size()==2), "every shared authored skill deduplicates both owners")
	var mp_clone: float = clone.vitals.mana
	game.selection.activate_skill(&"blast")
	check(guard.active.get("kind")=="cast" and clone.active.get("kind")=="cast" and game.selection.armed==&"","D17 instant shared self icon orders all owners without aiming")
	guard.tick(1.0 / 60)
	clone.tick(1.0 / 60)
	check(guard.casts == 1 and clone.casts == 1 and clone.vitals.mana < mp_clone, "shared icon orders every eligible selected caster")
	clear_effects()
	game.selection.select_ids([])
	check(game.hud.skill_buttons.is_empty(), "no selection clears skill grid")
	game.selection.select_ids([gunner.unit_id])
	check(game.hud.skill_buttons[&"critical"].disabled, "passive icon cannot be manually pressed")
	game.selection.arm(&"skill_blast")
	check(game.selection.armed == &"", "unowned shortcut cannot arm a skill")
	game.selection.activate_skill(&"summon", true)
	game.selection.select_ids([healer.unit_id])
	check(game.selection.armed == &"", "changing owners cancels unavailable targeting")

	ready(guard)
	var blast: SkillDefinition = skill(guard, &"blast")
	var origin: Vector2 = guard.position
	victim.position = origin + Vector2(60, 0)
	outside.position = origin + Vector2(300, 0)
	var hp: float = victim.vitals.health
	game.selection.select_ids([guard.unit_id])
	game.selection.activate_skill(&"blast")
	check(game.selection.armed_skill_id==&"" and guard.active.get("kind")=="cast" and game.selection.preview_kind()==&"none", "D17 self skill submits immediately without a target circle")
	guard.tick(1.0 / 60)
	check(guard.cast_left < 0 and game.effects.size() == 1, "instant skill commits in one logic tick")
	guard.position += Vector2(70, 60)
	effects_for(1.0)
	var history: Dictionary = game.effect_history[-1]
	check(history["skill"] == "blast" and float(history["age"]) <= 1.001 and int(history["ticks"]) == 5, "blast completes five waves within one second")
	check(int(history["hits"].get(victim.unit_id, 0)) == 1 and is_equal_approx(hp - victim.vitals.health, 40), "radial blast hits each target once")
	check(game.effects.is_empty(), "finished blast is cleaned up")

	ready(controller)
	var wheel: SkillDefinition = skill(controller, &"wheel")
	victim.position = controller.position + Vector2(60, 0)
	game.selection.select_ids([controller.unit_id])
	game.selection.activate_skill(&"wheel")
	var mp: float = controller.vitals.mana
	check(not game.selection.confirm_skill(victim.position, hero.unit_id) and controller.vitals.mana == mp and game.selection.armed != &"", "enemy skill rejects friend without spending or cancelling targeting")
	check(game.selection.confirm_skill(victim.position, victim.unit_id), "enemy click confirms wheel")
	controller.tick(1.0 / 60)
	victim.position += Vector2(40, 20)
	game._tick_effects(1.0 / 60)
	check(game.effects[0].point == victim.position, "wheel follows target position")
	effects_for(8.0)
	history = game.effect_history[-1]
	check(int(history["ticks"]) == 16 and int(history["hits"].get(victim.unit_id, 0)) == 16, "wheel applies sixteen fixed damage ticks")
	ready(controller)
	controller.abilities.request(wheel, victim.position, victim.unit_id)
	controller.tick(1.0 / 60)
	victim.vitals.damage(999999)
	game._tick_effects(1.0 / 60)
	check(game.effects.is_empty(), "target death terminates wheel")
	# Use an independent live target for the remaining effects.
	victim = game.spawn_unit(Catalog.enemy(0), 1, Vector2(750, 650), false)
	victim.vitals.max_health = 10000
	victim.vitals.health = 10000
	victim.vitals.armor = 0

	ready(hero)
	var quake: SkillDefinition = skill(hero, &"quake")
	victim.position = hero.position + Vector2(100, 0)
	hp = victim.vitals.health
	hero.abilities.request(quake, victim.position)
	hero.tick(1.0 / 60)
	effects_for(0.75)
	check(victim.statuses.speed_multiplier() == 1.0, "quake does not apply slow before shaking ends")
	effects_for(0.25)
	check(is_equal_approx(hp - victim.vitals.health, 40) and victim.statuses.speed_multiplier() == 0.5, "quake damage and delayed slow")
	victim.statuses.apply_slow(&"quake", 0.5, 3)
	check(victim.statuses.speed_multiplier() == 0.5, "same slow refreshes rather than multiplying")
	victim.statuses.tick(3.01)
	check(victim.statuses.speed_multiplier() == 1 and victim.definition.speed == 103.0, "slow expires without altering template speed")

	ready(mage)
	var dragon: SkillDefinition = skill(mage, &"dragon")
	origin = mage.position
	victim.position = origin + Vector2(200, 0)
	outside.position = origin + Vector2(200, 65)
	hp = victim.vitals.health
	var other_hp: float = outside.vitals.health
	mage.abilities.request(dragon, origin + Vector2(1, 0))
	mage.tick(1.0 / 60)
	mage.position += Vector2(280, 0)
	var dragon_lifetime: float=(Vector2(game.ground.cells).length()*Iso.CELL+dragon.effect_data.trail_length)/dragon.effect_data.speed
	effects_for(dragon_lifetime+0.05)
	check(victim.vitals.health < hp and outside.vitals.health == other_hp, "dragon straight lane damages inside but not outside width")
	check(game.effect_history[-1]["skill"]=="dragon" and game.effect_history[-1]["ticks"] == ceili((dragon_lifetime-0.000001)/dragon.effect_data.tick_interval), "dragon scene-wide fixed interval count")
	for fps: int in [30, 120]:
		clear_effects()
		ready(mage)
		mage.position = origin
		victim.position = origin + Vector2(200, 0)
		hp = victim.vitals.health
		mage.abilities.request(dragon, origin + Vector2(1, 0))
		mage.tick(1.0 / 60)
		effects_for(dragon_lifetime+0.05, 1.0 / fps)
		metrics["dragon_%d" % fps] = {"damage":hp - victim.vitals.health, "ticks":game.effect_history[-1]["ticks"]}
	check(metrics["dragon_30"] == metrics["dragon_120"], "damage ticks consistent at 30 and 120 presentation intervals")

	gunner.definition = gunner.definition.duplicate(true) as UnitDefinition
	# Passive critical boundaries are independent of new natural critical,
	# opposed hit chance and weapon variance, tested by progression_suite.
	gunner.definition.stat_rules = CombatStats.DEFAULT_RULES.duplicate() as CombatStatRules
	gunner.definition.stat_rules.attack_variance = 0
	gunner.definition.stat_rules.base_hit_chance = 1
	gunner.definition.stat_rules.accuracy_chance_factor = 0
	gunner.combat_stats["crit"] = 0.0
	victim.combat_stats["evasion"] = 0.0
	var critical: SkillDefinition = skill(gunner, &"critical")
	critical.proc_chance = 1
	ready(gunner)
	hp = victim.vitals.health
	mp = gunner.vitals.mana
	game._basic_hit(gunner, victim, gunner.definition.damage)
	check(is_equal_approx(hp - victim.vitals.health, 52) and gunner.vitals.mana == mp - 10, "100 percent critical substitutes formula damage and costs MP")
	critical.proc_chance = 0
	hp = victim.vitals.health
	game._basic_hit(gunner, victim, gunner.definition.damage)
	check(is_equal_approx(hp - victim.vitals.health, 26), "zero percent critical keeps normal attack")
	hero.definition = hero.definition.duplicate(true) as UnitDefinition
	hero.definition.stat_rules = gunner.definition.stat_rules
	hero.combat_stats["crit"] = 0.0
	var borrowed: SkillDefinition = critical.duplicate() as SkillDefinition
	borrowed.proc_chance = 1
	hero.definition.skills.append(borrowed)
	ready(hero)
	hp = victim.vitals.health
	game._basic_hit(hero, victim, hero.definition.damage)
	check(is_equal_approx(hp - victim.vitals.health, hero.definition.damage * 2), "critical works on any configured role")

	ready(gunner)
	var summon: SkillDefinition = skill(gunner, &"summon")
	var permanent_count: int = game.roster_ids.size()
	gunner.abilities.request(summon, Vector2(360, 810))
	gunner.tick(1.0 / 60)
	var spirit: TacticalUnit = game.get_unit(int(gunner.abilities.active_summons[summon.id]))
	check(spirit != null and spirit.is_summon and spirit.definition.attack_range == 280 and game.roster_ids.size() == permanent_count, "arrow spirit is independent without roster slot")
	check(not gunner.can_cast(summon), "one active spirit per caster")
	game.selection.select_ids([spirit.unit_id])
	check(game.selection.selected_ids == [spirit.unit_id], "summon can be selected")
	var spirit_id: int = spirit.unit_id
	spirit.tick(20.01)
	await get_tree().process_frame
	check(game.get_unit(spirit_id) == null, "summon expiry despawns entity")

	ready(supplier)
	supplier.position = Vector2(620, 950)
	mage.position = Vector2(430, 650)
	var wall: SkillDefinition = skill(supplier, &"ice_wall")
	var at: Vector2 = Vector2(720, 930)
	game.selection.select_ids([supplier.unit_id])
	game.selection.activate_skill(&"ice_wall")
	mp = supplier.vitals.mana
	check(not game.selection.confirm_skill(supplier.position) and supplier.vitals.mana == mp, "wall rejects occupied ground cells without MP loss")
	check(game.selection.confirm_skill(at), "valid wall accepts ground target")
	supplier.tick(1.0 / 60)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not game.ground.walls.is_empty() and not game.ground.wall_bodies.is_empty(), "ice wall has physical bodies and blocked navigation")
	var first_id: int = int(game.ground.walls.keys()[0])
	var cells: Array[Vector2i] = []
	cells.assign(game.ground.walls[first_id])
	game.ground.add_wall(99999, cells)
	game.ground.remove_wall(first_id)
	check(int(game.ground.dynamic_counts.get(cells[0], 0)) == 1, "overlapping wall keeps blocked cell until last expires")
	var from: Vector2 = Vector2(600, 950)
	var to: Vector2 = Vector2(840, 950)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ground_path: PackedVector2Array = NavigationServer2D.map_get_path(game.ground.region.get_navigation_map(), from, to, true)
	var air_path: PackedVector2Array = NavigationServer2D.map_get_path(game.ground.air_map, from, to, true)
	check(ground_path.size() > 2 and air_path.size() == 2, "ground routes around wall while air stays straight")
	for unit: TacticalUnit in game.units.values():
		unit._stop_motion()
	var ground_walker: TacticalUnit = game.spawn_unit(hero.definition, 0, Vector2(580, 950), false)
	await walk_to(ground_walker, Vector2(840, 950))
	check(ground_walker.position.distance_to(Vector2(840, 950)) < 25, "friendly ground body physically navigates around wall")
	# Keep the shared destination free; otherwise the second actor correctly
	# avoids the first actor instead of entering its occupied arrival slot.
	ground_walker.position = Vector2(300, 950)
	await get_tree().physics_frame
	var enemy_walker: TacticalUnit = game.spawn_unit(Catalog.enemy(0), 1, Vector2(580, 950), false)
	await walk_to(enemy_walker, Vector2(840, 950))
	print("ENEMY_WALL_WALK | pos=", enemy_walker.position, " state=", enemy_walker.fsm.current, " stuck=", enemy_walker.stuck_left, " nav=", enemy_walker.nav_target)
	check(enemy_walker.position.distance_to(Vector2(840, 950)) < 25, "enemy ground body physically navigates around wall")
	var flying_data: UnitDefinition = hero.definition.duplicate() as UnitDefinition
	flying_data.movement_type = UnitDefinition.Movement.AIR
	var flying: TacticalUnit = game.spawn_unit(flying_data, 0, Vector2(600, 950), false)
	await walk_to(flying, Vector2(840, 950))
	check(flying.position.distance_to(Vector2(840, 950)) < 25 and flying.collision_mask == 0, "air body physically passes ground barrier")
	game.ground.remove_wall(99999)
	clear_effects()
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(game.ground.dynamic_counts.is_empty(), "wall removal restores navigation mask")

	var invalid: SkillDefinition = skill(mage, &"dragon").duplicate() as SkillDefinition
	invalid.damage_formula = "智慧/0"
	mage.definition = mage.definition.duplicate() as UnitDefinition
	mage.definition.skills.append(invalid)
	ready(mage)
	mp = mage.vitals.mana
	check(not mage.abilities.request(invalid, mage.position + Vector2(10, 0)) and mage.vitals.mana == mp, "invalid formula prevents cast and MP cost")

	# Three-second whole-field acquisition, independent of attack updates.
	var monster: TacticalUnit = game.get_unit(game.living_ids(1)[-1])
	monster.issue_command({"kind":"stop"})
	monster.enemy_scan_left = 3
	monster.locked_attack_id = -1
	monster.position = Vector2(1200, 1000)
	monster.repath_left = 0
	await get_tree().physics_frame
	for i: int in 179:
		monster.tick(1.0 / 60)
	check(monster.locked_attack_id == -1, "monster does not scan before third second")
	monster.tick(1.0 / 60)
	check(monster.locked_attack_id in game.living_ids(0), "monster finds party across whole field at third second")
	var locked: int = monster.locked_attack_id
	monster.tick(1.0 / 60)
	check(monster.locked_attack_id == locked and monster.fsm.current in [&"chase", &"attack"], "locked target continuously pursued between scans")

	# Preserve a representative effect + wall when leaving to prove cleanup.
	ready(supplier)
	game.resolve_skill(supplier, wall, at, -1)
	check(not game.ground.dynamic_counts.is_empty(), "cleanup fixture contains dynamic wall")
	game.start_world()
	await wait_mode(&"world")
	check(game.effects.is_empty() and game.ground.dynamic_counts.is_empty() and game.units.size() == 1, "scene return clears effects summons statuses and barriers")

	game.start_battle(fixed_skill_fixture(), true)
	await wait_mode(&"battle")
	game.set_physics_process(true)
	Engine.max_fps = 120
	for unit: TacticalUnit in game.units.values():
		unit.vitals.max_health = 10000
		unit.vitals.health = 10000
	game.selection.dispatch("attack_move", Vector2(900, 650))
	await get_tree().create_timer(3.2).timeout
	var stress_guard: TacticalUnit = game.get_unit(game.roster_ids[1])
	var stress_mage: TacticalUnit = game.get_unit(game.roster_ids[3])
	var stress_hero: TacticalUnit = game.get_unit(game.roster_ids[0])
	var stress_controller: TacticalUnit = game.get_unit(game.roster_ids[6])
	var stress_supplier: TacticalUnit = game.get_unit(game.roster_ids[5])
	var stress_target: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	game.resolve_skill(stress_guard, skill(stress_guard, &"blast"), stress_guard.position, -1)
	game.resolve_skill(stress_hero, skill(stress_hero, &"quake"), stress_target.position, -1)
	game.resolve_skill(stress_mage, skill(stress_mage, &"dragon"), stress_mage.position + Vector2(300, 0), -1)
	game.resolve_skill(stress_controller, skill(stress_controller, &"wheel"), stress_target.position, stress_target.unit_id)
	game.resolve_skill(stress_supplier, skill(stress_supplier, &"ice_wall"), Vector2(360, 990), -1)
	check(game.effects.size() >= 5 and not game.ground.dynamic_counts.is_empty(), "72-unit pressure scene includes persistent skills and physical wall")
	var frame_times: Array[float] = []
	var previous_us: int = Time.get_ticks_usec()
	for frame: int in 180:
		await get_tree().process_frame
		var now_us: int = Time.get_ticks_usec()
		frame_times.append((now_us - previous_us) / 1000.0)
		previous_us = now_us
	frame_times.sort()
	metrics["stress_frame_p95_ms"] = frame_times[int(frame_times.size() * 0.95)]
	metrics["stress_physics_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
	metrics["stress_alive"] = game.living_ids(0).size() + game.living_ids(1).size()
	metrics["stress_effects_after_sample"] = game.effects.size()
	game.start_world()
	await wait_mode(&"world")
	check(game.effects.is_empty() and game.ground.dynamic_counts.is_empty(), "pressure scene effects and walls are cleared on return")
	metrics["passed"] = passed
	metrics["failures"] = failures
	var file: FileAccess = FileAccess.open(TestArtifacts.output("v2","v2-results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))
	file.close()
	print("GERSANG_V2_%s | passed=%d failed=%d" % ["PASS" if failures.is_empty() else "FAIL", passed.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
