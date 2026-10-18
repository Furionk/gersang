extends Node
var passed: int = 0
var failed: int = 0
var game: GameDirector
var context: WorldContext
var observations: Array[Dictionary] = []
func check(ok: bool, label: String) -> void:
	observations.append({"pass":ok,"test":label})
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed += 1
	else: failed += 1
func _ready() -> void:
	get_tree().create_timer(180).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func wait_world() -> bool:
	for frame: int in 600:
		await get_tree().process_frame
		if game.mode == &"world" and context.state.control_owner.is_empty(): return true
	return false
func key(code: Key, down: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = down
	Input.parse_input_event(event)
func shot(title: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-action/"+title+".png")
func begin_encounter() -> bool:
	if context.state.maps.rainbow_temple.parties.is_empty(): return false
	var party: Dictionary = context.state.maps.rainbow_temple.parties.values()[0]
	context.state.player.position = party.position + Vector2(20,0)
	context.state.player.protected_until_ms = 0; context.state.player.cooldown_until_ms = 0
	context.refresh_player(PartyProgress.serialize())
	var begin: Dictionary = context.encounters.try_begin("player",party.party_id,"player")
	check(begin.ok,"encounter reserved through existing service")
	if not begin.ok: return false
	check(context.state.active_encounter.deadline_ms - context.state.world_time_ms == 5000,"authored five-second countdown retained")
	for tick: int in 301: context.tick(1.0/60.0)
	for frame: int in 600:
		await get_tree().process_frame
		if game.mode == &"battle": return true
	return false
func run() -> void:
	check(not PartyProgress.persistence_enabled,"test bootstrap isolates real player saves")
	var packed: PackedScene = load("res://features/world/data/rainbow_temple.tscn")
	var map_node: WorldMap2D = packed.instantiate()
	var def: WorldMapDefinition = map_node.compile_definition()
	var validation: PackedStringArray = WorldValidator.validate(def, WorldCatalog.definitions, map_node)
	check(validation.is_empty(),"native new map validates: " + str(validation))
	map_node.free()
	var arena: ArenaDefinition = WorldCatalog.arenas.rainbow_temple
	var arena_node: BattlefieldMap = load(arena.encounter.battlefield_scene).instantiate()
	check(BattlefieldCompiler.compile(arena_node).errors.is_empty(),"native battle cells, blockers and five spawn zones validate")
	arena_node.free()
	check(not RainbowActionBattle.eligible(arena.encounter, {}),"practice arenas do not accidentally enable action mode")
	check(not RainbowActionBattle.eligible(arena.encounter, {"return_map_id":"river_bay"}),"region gate rejects ordinary river encounters")
	for old: String in WorldCatalog.arenas:
		if old in ["rainbow_temple","rainbow_forge","rainbow_sanctum","rainbow_throne"]: continue
		check(WorldCatalog.arenas[old].encounter.action_profile == null,"legacy encounter stays RTS: "+old)
	context = WorldContext.new(); context.initialize(PartyProgress.serialize(),42047,true)
	context.save.enabled = true; context.save.path = "user://rainbow_action_suite.dat"
	WorldSession.context = context
	game = load("res://main.tscn").instantiate(); add_child(game)
	check(await wait_world(),"real director enters world")
	game.set_physics_process(false)
	var river_original: Dictionary = context.state.maps.river_bay.duplicate(true)
	var portal: Dictionary = {}
	for candidate: Dictionary in context.current_map().portals:
		if candidate.id == "rainbow_door": portal = candidate
	check(not portal.is_empty(),"new entrance is present on main map")
	if portal.is_empty(): finish(); return
	var route: Dictionary = context.navigation.find_portal_approach("river_bay",context.state.player.position,portal.point,portal.radius,16)
	check(route.ok,"main map start has legal walking route to entrance")
	context.state.player.position = portal.point
	check(context.begin_portal("rainbow_door").ok,"real disk-backed portal transition begins")
	check(await wait_world(),"portal completes and unlocks")
	check(context.state.player.map_id == "rainbow_temple","director loaded new exploration scene")
	check(context.state.maps.rainbow_temple.parties.size() == 36,"36 native dungeon encounter parties generated")
	check(context.state.maps.river_bay == river_original,"adding new region preserves all original river parties and slots")
	await shot("01-frontcourt")
	if not await begin_encounter(): check(false,"action encounter reached battle"); finish(); return
	var battle: RainbowActionBattle = game.action_battle
	check(battle != null,"new encounter installs action controller")
	if battle == null: finish(); return
	check(battle.controlled_id == game.roster_ids[0],"main character is controlled initially")
	check(game.roster_ids.size() == PartyProgress.records.size(),"entire existing deployed formation enters")
	check(not game.selection.is_processing_unhandled_input(),"RTS input handler disabled only for action encounter")
	if DisplayServer.get_name() != "headless":
		var original_size: Vector2i = get_window().size
		for window_size: Vector2i in [Vector2i(800,450),Vector2i(1600,900)]:
			get_window().size = window_size
			for frame: int in 6: await get_tree().process_frame
			var safe: Rect2 = get_viewport().get_visible_rect()
			check(safe.encloses(battle.hud.roster_panel.get_global_rect()) and safe.encloses(battle.hud.action_buttons[&"run"].get_global_rect()),"bottom HUD remains inside viewport at " + str(window_size))
		get_window().size = original_size
		for frame: int in 6: await get_tree().process_frame
	var hero: TacticalUnit = battle.controlled()
	var hero_actor: RainbowActionActor = battle.actors[hero.unit_id]
	var start: Vector2 = hero.position
	key(KEY_RIGHT, true)
	for frame: int in 25:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	key(KEY_RIGHT, false)
	check(Iso.project(hero.position-start).x > 10 and absf(Iso.project(hero.position-start).y) < 2,"right key moves screen-right through projected logical coordinates")
	var before_bp: float = hero_actor.bp
	key(KEY_A, true); key(KEY_LEFT,true)
	for frame: int in 12:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	key(KEY_A,false); key(KEY_LEFT,false)
	check(hero_actor.bp < before_bp,"A running consumes per-unit BP")
	check(battle.request(&"melee"),"player melee accepts fresh command")
	var saved_recovery: float = hero_actor.recovery
	var saved_hp: float = hero.vitals.health
	var second: int = game.roster_ids[1]
	battle.hud.buttons[second].pressed.emit()
	check(battle.controlled_id == second,"roster button transfers control")
	check(hero_actor.recovery == saved_recovery and hero.vitals.health == saved_hp,"switch preserves HP and recovery")
	battle.switch_to(hero.unit_id)
	check(not battle.request(&"ranged"),"switching back cannot cancel melee recovery")
	# Freeze all actors except the controlled actor to independently test directional hits.
	for actor: RainbowActionActor in battle.actors.values():
		actor.action = &""; actor.recovery = 0; actor.stun = 100; actor.unit.attack_windup_left = -1
	hero_actor.stun = 0
	hero.position = Vector2(640,800); hero_actor.pose.reset(hero.position); hero.velocity = Vector2.ZERO
	var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	var enemy_actor: RainbowActionActor = battle.actors[enemy.unit_id]
	enemy.position = hero.position + Vector2(55,0); enemy_actor.pose.reset(enemy.position)
	hero.facing = Vector2.RIGHT
	var enemy_hp: float = enemy.vitals.health
	key(KEY_S,true); key(KEY_S,false)
	for frame: int in 12:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	check(enemy.vitals.health < enemy_hp,"S melee damages target in facing cone via UnitVitals")
	check(battle.feedback.hit_count > 0 and battle.feedback.voice_count > 0,"confirmed player hit triggers impact and authored TTS")
	check(enemy_actor.hit_flash > 0 and enemy.view.sprite.material is ShaderMaterial,"hit produces local sprite flash")
	check(Engine.time_scale == 1.0,"hit pause never changes global simulation speed")
	check(battle.hud.roster_panel.get_global_rect().position.y > get_viewport().get_visible_rect().size.y * 0.7,"party switch dock is at bottom of viewport")
	for kind: StringName in battle.hud.action_buttons:
		check(not battle.hud.action_buttons[kind].get_global_rect().intersects(battle.hud.roster_panel.get_global_rect()),"attack control does not overlap party switching: " + str(kind))
	await shot("04-polished-impact")
	hero_actor.recovery = 0; hero_actor.stun = 0; hero_actor.action = &""
	check(battle.request(&"guard"),"guard opens finite defensive window")
	var guarded: float = hero_actor.receive_hit(hero.position + hero.facing * 40, 100, 1)
	check(hero_actor.blocked_hits == 1 and guarded < 30,"front guard mitigates incoming damage")
	hero_actor.guard_left = 0; hero_actor.stun = 0; hero_actor.recovery = 0
	var unguarded: float = hero_actor.receive_hit(hero.position + hero.facing * 40, 100, 1)
	check(unguarded > guarded,"unguarded impact deals more damage")
	hero_actor.stun = 0; hero_actor.impulse = Vector2.ZERO; hero_actor.recovery = 0
	enemy.position = hero.position + Vector2(220,0); enemy_actor.pose.reset(enemy.position)
	enemy.vitals.health = enemy.vitals.max_health
	enemy_actor.stun = 100; enemy_actor.impulse = Vector2.ZERO
	enemy_hp = enemy.vitals.health
	hero.facing = Vector2.RIGHT
	key(KEY_D,true); key(KEY_D,false)
	for frame: int in 45:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	check(battle.shot_serial > 0 and enemy.vitals.health < enemy_hp,"D launches swept directional projectile and hits")
	# Input buffering must survive a local hit pause, never transfer across units.
	hero_actor.action = &""; hero_actor.guard_left = 0; hero_actor.stun = 0; hero_actor.hit_stop = 0
	hero_actor.recovery = 0.08
	var prior_shots: int = hero.shots
	check(not battle.request(&"melee") and battle.buffered == &"melee","late input queues without cancelling recovery")
	for frame: int in 18:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	check(hero.shots == prior_shots + 1,"buffered command releases exactly once")
	hero_actor.recovery = 0.08; hero_actor.action = &""
	battle.request(&"ranged"); battle.switch_to(second)
	check(battle.buffered == &"","switching drops old owner's pending input")
	battle.switch_to(hero.unit_id)
	hero_actor.recovery = 0; hero_actor.stun = 0; hero_actor.action = &""; hero_actor.hit_stop = 0
	prior_shots = hero.shots
	battle.held_action = &"melee"
	for frame: int in 64:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	battle.held_action = &""
	check(hero.shots >= prior_shots + 2,"holding attack repeats through normal windup and recovery")
	var prior_hits: int = battle.feedback.hit_count
	hero_actor.attack_facing = Vector2.LEFT
	battle.release(hero_actor, &"melee")
	check(battle.feedback.hit_count == prior_hits,"empty swing does not emit hit or damage feedback")
	var prior_voice: int = battle.feedback.voice_count
	battle.feedback.voice_enabled = false; battle.feedback.voice_left = 0
	battle.feedback.impact(hero.unit_id,enemy_actor,1,"cut",false)
	check(battle.feedback.voice_count == prior_voice,"comic TTS mute suppresses playback")
	battle.feedback.shake_enabled = false; battle.feedback._process(0)
	check(game.camera.offset == Vector2.ZERO,"reduced motion removes camera shake immediately")
	battle.feedback.voice_enabled = true; battle.feedback.shake_enabled = true
	# Test authored blocker collision, not only numerical input.
	hero.position = Vector2(450,500); hero.velocity = Vector2.ZERO; hero_actor.pose.reset(hero.position)
	hero_actor.recovery = 0; hero_actor.stun = 0; hero_actor.impulse = Vector2.ZERO
	battle.input_override = true; battle.movement = Vector2.RIGHT
	for frame: int in 35:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	check(hero.position.x < 480,"direct movement respects native pillar collision")
	battle.movement = Vector2.ZERO
	# Followers must close the gap when enemies are outside the leash.
	hero.position = Vector2(640,800); hero_actor.pose.reset(hero.position)
	var follower: TacticalUnit = game.get_unit(second)
	follower.position = Vector2(300,800)
	for actor: RainbowActionActor in battle.actors.values():
		actor.stun = 0 if actor.unit.team == 0 else 100
		actor.recovery = 0; actor.action = &""; actor.impulse = Vector2.ZERO
		if actor.unit.team == 1: actor.unit.position = Vector2(980,250)
		actor.pose.reset(actor.unit.position)
	var gap: float = follower.position.distance_to(hero.position)
	for frame: int in 80:
		await get_tree().physics_frame
		battle.tick(1.0/60.0)
	check(follower.position.distance_to(hero.position) < gap-40,"AI follows controlled leader through authored navigation")
	# Real production combat; no administrative damage for victory.
	for actor: RainbowActionActor in battle.actors.values():
		actor.stun = 0; actor.recovery = 0; actor.unit.vitals.health = actor.unit.vitals.max_health
		actor.action = &""
	var first_enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	hero.position = first_enemy.position + Vector2(0,160); hero_actor.pose.reset(hero.position)
	for frame: int in 40: await get_tree().process_frame
	await shot("02-action-battle")
	game.set_physics_process(true)
	var encounter_id: String = context.state.active_encounter.encounter_id
	var return_position: Vector2 = context.state.active_encounter.return_position
	for frame: int in 3600:
		await get_tree().physics_frame
		if game.mode == &"results" or game.mode == &"world": break
	check(game.mode in [&"results",&"world"] and game.last_result == "victory","AI combat reaches real victory without forced kills")
	if DisplayServer.get_name() != "headless":
		check(battle.feedback.voice_peak_db > -90,"TTS produces measurable output on actual UnitVoice audio bus")
	game.set_physics_process(false)
	check(context.state.applied_results.has(encounter_id),"victory commits persistent receipt")
	if context.state.applied_results.has(encounter_id):
		check(context.state.applied_results[encounter_id].experience > 0,"shared settlement awards encounter XP")
		var snapshot: Dictionary = context.snapshot()
		check(context.settlement.apply(game.settlement_result).get("duplicate",false) and context.snapshot() == snapshot,"duplicate result cannot award twice")
		check(context.save.load_best() == snapshot,"disk reload preserves complete result")
	await shot("03-victory")
	if game.mode == &"results": game.start_world()
	check(await wait_world(),"victory returns and unlocks exploration")
	check(game.action_battle == null and context.state.player.position.distance_to(return_position) < 1,"action controller disposed and exact encounter position restored")
	check(game.camera.offset == Vector2.ZERO,"return clears action camera offset")
	# Retreat path uses the same result pipeline.
	if await begin_encounter():
		var retreat_id: String = context.state.active_encounter.encounter_id
		context.save.fail_writes = 1
		game.retreat()
		check(game.last_result == "retreat","retreat uses existing result state")
		check(context.state.active_encounter.state == "SETTLING" and not context.state.applied_results.has(retreat_id),"failed disk write retains encounter without publishing reward")
		game.start_world()
		check(await wait_world(),"retreat safely returns to exploration")
		check(context.state.applied_results.has(retreat_id),"return retries and commits pending settlement")
	var exit: Dictionary = context.current_map().portals[0]
	context.state.player.position = exit.point
	check(context.begin_portal(exit.id).ok,"frontcourt exit begins return to main map")
	check(await wait_world() and context.state.player.map_id == "river_bay","returned to original main map")
	check(context.state.maps.river_bay == river_original,"original region population unchanged across victory and retreat")
	context.tick(1.0 / 60.0)
	check(context.state.player.map_id == "river_bay" and context.state.control_owner.is_empty(),"return arrival remains outside entrance trigger")
	context.state.player.position = portal.point
	check(context.begin_portal("rainbow_door").ok and await wait_world(),"reenter new region for defeat recovery")
	if await begin_encounter():
		var safe_map: String = context.state.active_encounter.safe_return_map_id
		var safe_entry: String = context.state.active_encounter.safe_return_entry_id
		var defeat_battle: RainbowActionBattle = game.action_battle
		var original_control: TacticalUnit = defeat_battle.controlled()
		game.apply_damage(original_control, 100000, false, CombatMath.Kind.MAGIC)
		defeat_battle.tick(1.0 / 60.0)
		check(defeat_battle.controlled_id != original_control.unit_id and defeat_battle.controlled().alive(),"controlled death transfers input to a living teammate")
		check(not defeat_battle.switch_to(original_control.unit_id),"dead teammate cannot take control")
		for id: int in game.living_ids(0): game.apply_damage(game.get_unit(id), 100000, false, CombatMath.Kind.MAGIC)
		game._physics_process(1.0 / 60.0)
		check(game.mode == &"results" and game.last_result == "defeat","allied extinction reaches ordinary defeat settlement")
		game.start_world()
		check(await wait_world(),"defeat returns safely with the existing recovery rules")
		check(context.state.player.map_id == safe_map and context.state.player.position.distance_to(context.map_definitions[safe_map].entries[safe_entry].point) < 1,"defeat restores authored safe return point")
	game.start_battle(WorldCatalog.arenas.meadow.encounter)
	for frame: int in 600:
		await get_tree().process_frame
		if game.mode == &"battle": break
	check(game.mode == &"battle" and game.action_battle == null and game.selection.is_processing_unhandled_input(),"ordinary battle restores RTS input and camera route")
	finish()
func finish() -> void:
	var file: FileAccess = FileAccess.open("res://artifacts/rainbow-action/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"checks":observations},"\t")); file.close()
	print("RAINBOW_ACTION_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
