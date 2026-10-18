extends Node

var game: GameDirector
var monster: TacticalUnit
var hero: TacticalUnit
var guard: TacticalUnit
var supplier: TacticalUnit
var passed: int = 0
var failures: int = 0
var finished_count: int = 0
var blocked_messages: int = 0

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS | ", title)
	else:
		failures += 1
		push_error("FAIL | " + title)

func _ready() -> void:
	get_tree().create_timer(100).timeout.connect(func() -> void:
		push_error("ICE_WALL_AI_TIMEOUT")
		get_tree().quit(2))
	call_deferred("run")

func simulate(seconds: float) -> void:
	for frame: int in int(round(seconds * 60)):
		monster.tick(1.0 / 60)
		game._tick_effects(1.0 / 60)
		game._tick_projectiles(1.0 / 60)
		await get_tree().physics_frame

func fixture() -> void:
	# Explicit sealed-choke fixture, independent of the shipped battle art/layout.
	var sealed_choke: EncounterDefinition = Catalog.encounters()[1].duplicate(true) as EncounterDefinition
	sealed_choke.battlefield_cells = Vector2i(34,28)
	sealed_choke.battlefield_scene = "" # Explicit legacy sealed-choke fixture, not a shipped scene.
	sealed_choke.battlefield_obstacles = [Rect2i(14,0,3,11),Rect2i(14,16,3,12),Rect2i(24,9,4,5)]
	game.start_battle(sealed_choke)
	while game.mode != &"battle":
		await get_tree().process_frame
	game.set_physics_process(false)
	hero = game.get_unit(game.roster_ids[0])
	guard = game.get_unit(game.roster_ids[1])
	supplier = game.get_unit(game.roster_ids[5])
	monster = game.get_unit(game.living_ids(1)[0])
	for unit: TacticalUnit in game.units.values():
		unit.issue_command({"kind":"hold"})
		unit.position = Vector2(100, 100) if unit.team == 0 else Vector2(1280, 1000)
		unit.previous_position = unit.position
		unit.vitals.max_health = 10000
		unit.vitals.health = 10000
	hero.position = Vector2(420, 540)
	guard.position = Vector2(1300, 1000)
	supplier.position = Vector2(380, 540)
	monster.position = Vector2(900, 540)
	monster.previous_position = monster.position
	monster.issue_command({"kind":"stop"})
	monster.enemy_scan_left = 3.0
	finished_count = 0
	blocked_messages = 0
	monster.command_finished.connect(func(_id: int) -> void: finished_count += 1)
	var wall: SkillDefinition
	for candidate: SkillDefinition in supplier.definition.skills:
		if candidate.id == &"ice_wall":
			wall = candidate
	check(wall != null, "fixture has configured ice wall")
	game.resolve_skill(supplier, wall, Vector2(620, 540), -1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not game.ground.wall_bodies.is_empty(), "mountain fixture has real ice wall collision bodies")
	var path: PackedVector2Array = NavigationServer2D.map_get_path(monster.agent.get_navigation_map(), monster.position, hero.position, true)
	# Physics-frame signals precede the server's synchronization; on the
	# first cold load, wait until the new polygon has actually reached it.
	for frame: int in 30:
		if path.is_empty() or path[-1].distance_to(hero.position) > 100:
			break
		await get_tree().physics_frame
		path = NavigationServer2D.map_get_path(monster.agent.get_navigation_map(), monster.position, hero.position, true)
	check(path.is_empty() or path[-1].distance_to(hero.position) > 100, "wall seals mountain choke and target is unreachable")

func capture(name_text: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.camera.position = Iso.project(Vector2(680, 560))
	game.camera.force_update_scroll()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("ice_wall","ice-wall-ai-%s.png" % name_text))

func run() -> void:
	LegacyPartyFixture.install()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	game.cinematic_camera = false
	game.message.connect(func(message: String) -> void:
		if "被阻擋" in message:
			blocked_messages += 1)
	while game.mode != &"world":
		await get_tree().process_frame
	await fixture()
	await simulate(2.9)
	check(monster.locked_attack_id == -1, "monster still waits until third second for first global scan")
	await simulate(9.1)
	print("BLOCKED | pos=", monster.position, " stuck=", monster.stuck_left, " finishes=", finished_count, " messages=", blocked_messages)
	check(monster.locked_attack_id == hero.unit_id, "blocked monster preserves original live target")
	check(finished_count == 0, "blocked autonomous chase does not finish its intention every tick")
	check(blocked_messages <= 1, "blocked monsters do not flood player message log")
	check(monster.position.x > 640 and monster.shots == 0, "blocked monster neither crosses ice wall nor attacks distant target")
	await capture("blocked")
	# D42 strengthens duration; still test natural expiry and actual pursuit/attack.
	var wall_data:SkillDefinition
	for owned:SkillDefinition in supplier.definition.skills:
		if owned.id==&"ice_wall":wall_data=owned
	await simulate(maxf(0,wall_data.effect_data.duration-12.0)+8.0)
	print("RECOVERED | pos=", monster.position, " shots=", monster.shots, " state=", monster.fsm.current)
	check(game.ground.walls.is_empty(), "ice wall expires normally")
	check(monster.position.x < 620, "monster physically resumes through restored mountain choke")
	check(monster.shots > 0, "monster attacks original target after wall expiry")
	await capture("recovered")

	await fixture()
	await simulate(12.0)
	var nearby: Vector2 = monster.position + Vector2(24, 0)
	guard.position = nearby
	guard.previous_position = nearby
	var hp: float = guard.vitals.health
	await simulate(1.0)
	check(not game.ground.walls.is_empty(), "nearby-response fixture still has active wall")
	check(monster.locked_attack_id == guard.unit_id and monster.shots > 0 and guard.vitals.health < hp, "blocked monster retaliates against newly nearby non-original target")
	await capture("retaliation")
	# A dead opportunistic target is replaced by the normal three-second scan.
	guard.vitals.damage(999999)
	await simulate(3.1)
	check(monster.locked_attack_id == hero.unit_id, "dead nearby target reacquired on normal global scan")
	await simulate(maxf(0,wall_data.effect_data.duration-16.1)+8.0)
	check(monster.shots > 1 and monster.position.distance_to(hero.position) <= monster.definition.attack_range + 18, "retargeted monster resumes pursuit and attacks after expiry")
	await fixture()
	monster.issue_command({"kind":"attack", "target":hero.unit_id})
	await simulate(6.0)
	check(monster.active.get("kind", "") == "attack" and int(monster.active.get("target", -1)) == hero.unit_id and finished_count == 0, "explicit attack command survives blocked path")
	for effect: BattleSkillEffect in game.effects:
		effect.finish()
	game.effects.clear()
	await simulate(6.0)
	check(monster.position.x < 620 and monster.shots > 0, "explicit attack resumes when dynamic wall is removed")
	game.start_world()
	while game.mode != &"world":
		await get_tree().process_frame
	check(game.effects.is_empty() and game.ground.dynamic_counts.is_empty(), "leaving battle cleans walls and blocked actors")
	print("GERSANG_ICE_WALL_AI_%s | passed=%d failed=%d" % ["PASS" if failures == 0 else "FAIL", passed, failures])
	get_tree().quit(0 if failures == 0 else 1)
