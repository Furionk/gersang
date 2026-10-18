extends "res://tests/rainbow_dungeon_suite.gd"
## Isolated 60-second production-combat probe. Only the target's HP pool is extended.
func run() -> void:
	var level: int = 25
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): level = int(arg.trim_prefix("--level="))
	for record: CharacterRecord in PartyProgress.records:
		record.experience = CharacterRecord.CURVE.threshold(level)
		var stats: Dictionary = record.stats()
		record.health = stats.health; record.mana = stats.mana
	context = WorldContext.new(); context.initialize(PartyProgress.serialize(),55047,true)
	context.save.enabled = false; WorldSession.context = context
	game = load("res://main.tscn").instantiate(); add_child(game)
	check(await wait_world(),"benchmark world")
	game.set_physics_process(false)
	for portal: Dictionary in context.current_map().portals:
		if portal.id == "rainbow_door": context.state.player.position = portal.point
	check(context.begin_portal("rainbow_door").ok and await wait_world(),"benchmark temple")
	if not await enter_party("rainbow_dragon_throne"): check(false,"benchmark boss"); finish(); return
	var battle: RainbowActionBattle = game.action_battle
	var boss: RainbowActionActor = battle.mechanics.boss_actor()
	boss.unit.vitals.max_health = 1000000; boss.unit.vitals.health = 1000000
	var damage: float = 0
	var elapsed: float = 0
	for frame: int in 3600:
		await get_tree().physics_frame
		if game.mode != &"battle": break
		var leader: TacticalUnit = battle.controlled()
		if leader != null and leader.alive():
			var actor: RainbowActionActor = battle.actors[leader.unit_id]
			battle.movement = battle.ai_direction(actor)
			battle.boosting = not battle.mechanics.safe_destination(actor).is_empty()
			if leader.position.distance_to(boss.unit.position) > 280 and not battle.boosting: battle.movement = battle.path_direction(actor,boss.unit.position)
		var before: float = boss.unit.vitals.health
		game._physics_process(1.0/60.0)
		damage += before - boss.unit.vitals.health
		elapsed += 1.0/60.0
	var result := {"level":level,"members":game.roster_ids.size(),"seconds":elapsed,"damage":damage,"dps":damage/maxf(1,elapsed),"survivors":game.living_ids(0).size(),"fixture":"standard initial loadout, no attribute allocation, production AI and simple dragon attacks, target HP extended only"}
	var file := FileAccess.open("res://artifacts/rainbow-overhaul/dps-%d.json" % level,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("DPS_RESULT ",JSON.stringify(result))
	game.retreat(); finish()
