extends "res://tests/rainbow_action_suite.gd"
var content_checked: bool = false

func run() -> void:
	var settings: RainbowActionProfile = load("res://features/rainbow/data/default_action.tres")
	check(settings.weapons.size() == 11, "eleven existing formation types have native action equipment")
	for weapon: RainbowWeaponDefinition in settings.weapons:
		var skin: SpriteSheetLayout = weapon.layout
		check(skin != null and skin.valid_for(Vector2i(skin.source_texture.get_size())), "authored crop and pivot layout validates: " + str(weapon.unit_id))
		var source: Image = skin.source_texture.get_image()
		var visible: bool = true
		for rect: Rect2i in skin.frame_rects:
			visible = visible and source.get_region(rect).get_used_rect().get_area() > 100
		check(visible and skin.rows == 4 and skin.columns == 4, "sixteen painted nonempty poses: " + str(weapon.unit_id))
		check(weapon.effect_texture != null, "dedicated projectile raster: " + str(weapon.unit_id))
		var definition: UnitDefinition = load("res://features/units/data/mercenaries/" + str(weapon.unit_id) + ".tres")
		check(definition.sprite_layout != skin, "ordinary unit art is not replaced: " + str(weapon.unit_id))
	var old_world: WorldMap2D = load("res://artifacts/rainbow-content/before/features/world/data/rainbow_temple.tscn").instantiate()
	var new_world: WorldMap2D = load("res://features/world/data/rainbow_temple.tscn").instantiate()
	for node_path: String in ["Ground/Walkable_Mask", "Ground/Obstacles_TileMap"]:
		var preserved: bool = true
		for x: int in 34:
			for y: int in 32:
				preserved = preserved and old_world.get_node(node_path).get_cell_source_id(Vector2i(x,y)) == new_world.get_node(node_path).get_cell_source_id(Vector2i(x,y))
		check(preserved, "original frontcourt masks preserved; authorized eastern expansion excluded: " + node_path)
	var old_def: WorldMapDefinition = old_world.compile_definition()
	var new_def: WorldMapDefinition = new_world.compile_definition()
	var before_shapes: Array = []
	var after_shapes: Array = []
	for domain: PolygonDomain in old_def.blockers + old_def.walkable: before_shapes.append([domain.outer,domain.holes])
	for domain: PolygonDomain in new_def.blockers + new_def.walkable: after_shapes.append([domain.outer,domain.holes])
	check(new_def.extent == Vector2(5120,6400) and not new_def.walkable.is_empty(),"twelve-zone expansion compiles native walkable contours")
	check(old_def.entries == new_def.entries and old_def.portals == new_def.portals, "native temple entries and exit unchanged")
	old_world.free(); new_world.free()
	var old_arena: BattlefieldMap = load("res://artifacts/rainbow-content/before/features/battle/maps/rainbow_temple.tscn").instantiate()
	var new_arena: BattlefieldMap = load("res://features/battle/maps/rainbow_temple.tscn").instantiate()
	var before: Dictionary = BattlefieldCompiler.compile(old_arena)
	var after: Dictionary = BattlefieldCompiler.compile(new_arena)
	check(before.blocked == after.blocked and before.walkable == after.walkable and before.zones == after.zones, "battle navigation, cells and five spawn zones unchanged")
	old_arena.free(); new_arena.free()
	await super.run()

func begin_encounter() -> bool:
	var reached: bool = await super.begin_encounter()
	if reached and not content_checked:
		content_checked = true
		await verify_weapons()
	return reached

func verify_weapons() -> void:
	var battle: RainbowActionBattle = game.action_battle
	game.set_physics_process(false)
	battle.input_override = true
	var parked: Dictionary = {}
	for id: int in battle.actors:
		var actor: RainbowActionActor = battle.actors[id]
		parked[id] = actor.unit.position
		actor.unit.position = Vector2(110,110); actor.pose.reset(actor.unit.position)
	for weapon: RainbowWeaponDefinition in battle.profile.weapons:
		var definition: UnitDefinition = load("res://features/units/data/mercenaries/" + str(weapon.unit_id) + ".tres")
		var shooter: TacticalUnit = game.spawn_unit(definition,0,Vector2(550,700),false)
		shooter.position = Vector2(550,700); shooter.facing = Vector2.RIGHT
		shooter.vitals.max_mana = 100; shooter.vitals.mana = 100
		var actor := RainbowActionActor.new(); actor.setup(shooter,battle.profile); battle.actors[shooter.unit_id] = actor
		var targets: Array[TacticalUnit] = []
		for offset: float in [220.0,280.0,340.0]:
			var victim: TacticalUnit = game.spawn_unit(load("res://features/units/data/monsters/rainbow_slime.tres"),1,Vector2(550+offset,700),false)
			victim.position = Vector2(550+offset,700)
			victim.vitals.max_health = 100000; victim.vitals.health = 100000
			var target_actor := RainbowActionActor.new(); target_actor.setup(victim,battle.profile)
			battle.actors[victim.unit_id] = target_actor; targets.append(victim)
		check(actor.weapon == weapon and shooter.definition == definition and shooter.view.action_layout == weapon.layout, "skin and weapon scoped to live encounter: " + str(weapon.unit_id))
		check(actor.request(&"ranged") and is_equal_approx(actor.windup,weapon.ranged_windup) and is_equal_approx(shooter.vitals.mana,100-weapon.mana_cost), "distinct ranged windup and MP charge: " + str(weapon.unit_id))
		shooter.view._process(0)
		check(shooter.view.sprite.frame == 0,"anticipation pose remains until release: " + str(weapon.unit_id))
		check(actor.advance(weapon.ranged_windup+0.001) == &"ranged", "windup releases once: " + str(weapon.unit_id))
		battle.release(actor,&"ranged")
		shooter.view._process(0)
		check(shooter.view.sprite.frame == 1,"attack pose matches authoritative release: " + str(weapon.unit_id))
		check(battle.projectiles.size() == weapon.projectile_count, "authored projectile pattern: " + str(weapon.unit_id))
		for step: int in 90: battle.tick_projectiles(1.0/60.0)
		check(targets[0].vitals.health < 100000, "real ranged collision deals damage: " + str(weapon.unit_id))
		if weapon.pierce > 1:
			check(targets[1].vitals.health < 100000, "piercing reaches second target: " + str(weapon.unit_id))
			check((battle.actors[targets[0].unit_id] as RainbowActionActor).hits == 1, "piercing never re-hits same target: " + str(weapon.unit_id))
		if weapon.splash > 0: check(targets[1].vitals.health < 100000,"blast reaches nearby target: " + str(weapon.unit_id))
		battle.projectiles.clear()
		var victim: TacticalUnit = targets[0]
		victim.position = shooter.position + Vector2(weapon.melee_range*0.8,0)
		victim.vitals.health = 100000
		actor.action = &""; actor.recovery = 0; actor.hit_stop = 0
		check(actor.request(&"melee") and is_equal_approx(actor.windup,weapon.melee_windup), "distinct melee timing: " + str(weapon.unit_id))
		battle.release(actor,actor.advance(weapon.melee_windup+0.001))
		check(victim.vitals.health < 100000 and is_equal_approx((battle.actors[victim.unit_id] as RainbowActionActor).stun,weapon.stagger), "melee reach and stagger use weapon data: " + str(weapon.unit_id))
		victim.position = shooter.position - Vector2(weapon.melee_range*0.8,0)
		victim.vitals.health = 100000
		battle.release(actor,&"melee")
		check(victim.vitals.health == 100000,"melee cone excludes enemies behind: " + str(weapon.unit_id))
		if weapon.effect in ["rifle", "curse"]:
			shooter.position = Vector2(640,500)
			for target: TacticalUnit in targets: target.position = Vector2(850,500); target.vitals.health = 100000
			battle.release(actor,&"ranged")
			for step: int in 90: battle.tick_projectiles(1.0/60.0)
			check(targets[0].vitals.health == 100000,"ranged attack cannot cross native pillar: " + str(weapon.unit_id))
		battle.projectiles.clear()
		for item: TacticalUnit in targets + [shooter]:
			battle.actors.erase(item.unit_id); game.units.erase(item.unit_id); item.view.queue_free(); item.queue_free()
		battle.swings.clear(); battle.feedback.impacts.clear()
		await get_tree().process_frame
	for id: int in parked:
		var actor: RainbowActionActor = battle.actors[id]
		actor.unit.position = parked[id]; actor.pose.reset(actor.unit.position)
	battle.input_override = false
	battle.feedback.notice_left = 0

func finish() -> void:
	var file := FileAccess.open("res://artifacts/rainbow-content/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"checks":observations},"\t")); file.close()
	print("RAINBOW_CONTENT_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
