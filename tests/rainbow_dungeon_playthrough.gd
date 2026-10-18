extends "res://tests/rainbow_dungeon_suite.gd"
## Production movement/attack inputs drive victories; no administrative damage or healing.
func _ready() -> void:
	# New boss targets exceed the inherited 180-second whole-suite watchdog.
	get_tree().create_timer(1200).timeout.connect(func() -> void:
		print("FAIL | natural-play watchdog 1200 seconds")
		get_tree().quit(2))
	call_deferred("run")

func run() -> void:
	var seed_value: int = 55047
	var habitats: Array[String] = ["rainbow_beast_nest","rainbow_high_priest","rainbow_dragon_throne"]
	var idle: bool = "--idle" in OS.get_cmdline_user_args()
	var fixture_level: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--habitat="): habitats.assign([arg.trim_prefix("--habitat=")])
		if arg.begins_with("--level="): fixture_level = int(arg.trim_prefix("--level="))
	if fixture_level > 0:
		for record: CharacterRecord in PartyProgress.records:
			record.experience = CharacterRecord.CURVE.threshold(fixture_level)
			var stats: Dictionary = record.stats()
			record.health = stats.health; record.mana = stats.mana
	context = WorldContext.new(); context.initialize(PartyProgress.serialize(),seed_value,true)
	print("NATURAL_SEED ",seed_value)
	context.save.enabled = true; context.save.path = "user://rainbow_dungeon_playthrough.dat"
	WorldSession.context = context
	game = load("res://main.tscn").instantiate(); add_child(game)
	check(await wait_world(),"natural-play world loaded")
	game.set_physics_process(false)
	for portal: Dictionary in context.current_map().portals:
		if portal.id == "rainbow_door": context.state.player.position = portal.point
	check(context.begin_portal("rainbow_door").ok and await wait_world(),"natural-play enters real portal")
	for habitat: String in habitats:
		var world_zoom: Vector2 = game.camera.zoom
		if not await enter_party(habitat): check(false,"natural-play encounter starts: "+habitat); break
		var battle: RainbowActionBattle = game.action_battle
		battle.switch_to(game.roster_ids[1])
		var elapsed: float = 0.0
		var phases: Dictionary = {}
		var specials: int = 0
		for frame: int in 28800:
			await get_tree().physics_frame
			if game.mode != &"battle": break
			var leader: TacticalUnit = battle.controlled()
			if not idle and leader != null and leader.alive():
				var actor: RainbowActionActor = battle.actors[leader.unit_id]
				battle.movement = battle.ai_direction(actor)
				battle.boosting = not battle.mechanics.safe_destination(actor).is_empty()
				# Lead the whole formation into engagement range after a defensive retreat.
				var target: TacticalUnit = game.nearest_enemy(leader,100000)
				if target != null and leader.position.distance_to(target.position) > 280 and battle.mechanics.safe_destination(actor).is_empty():
					battle.movement = battle.path_direction(actor,target.position)
			game._physics_process(1.0/60.0)
			elapsed += 1.0/60.0
			for state: Dictionary in battle.mechanics.states.values(): phases[int(state.phase)] = true
			specials = battle.mechanics.serial
			if frame == 480: await shot("natural-"+habitat)
			if frame % 1200 == 0:
				var boss: RainbowActionActor = battle.mechanics.boss_actor()
				if boss != null: print("DRAGON_PROGRESS ",elapsed," hp=",boss.unit.vitals.health," at=",boss.unit.position," leader=",battle.controlled().position," survivors=",game.living_ids(0).size())
		if idle: check(game.last_result != "victory","idle input does not clear challenge: "+habitat)
		elif habitats.size() == 1: check(game.last_result == "victory" and game.mode == &"results","natural victory without forced damage: "+habitat)
		else: check(game.last_result in ["victory","defeat"] and game.mode == &"results","unhealed sequential encounter resolves naturally: "+habitat)
		print("NATURAL_METRICS ",JSON.stringify({"habitat":habitat,"seconds":elapsed,"phases":phases.keys(),"warnings":specials,"survivors":game.living_ids(0).size(),"result":game.last_result}))
		if game.mode == &"battle": game.retreat()
		game.start_world(); check(await wait_world(),"natural-play settlement returns")
		check(game.camera.zoom.is_equal_approx(world_zoom), "boss camera zoom restored on world return")
	finish()

func finish() -> void:
	var file := FileAccess.open("res://artifacts/rainbow-dungeon/playthrough-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"checks":observations},"\t")); file.close()
	print("RAINBOW_PLAYTHROUGH_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
