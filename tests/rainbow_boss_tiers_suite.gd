extends "res://tests/rainbow_dungeon_suite.gd"
func run() -> void:
	context = WorldContext.new(); context.initialize(PartyProgress.serialize(),55049,true)
	context.save.enabled = false; WorldSession.context = context
	game = load("res://main.tscn").instantiate(); add_child(game)
	check(await wait_world(),"tier test world")
	game.set_physics_process(false)
	for portal: Dictionary in context.current_map().portals:
		if portal.id == "rainbow_door": context.state.player.position = portal.point
	check(context.begin_portal("rainbow_door").ok and await wait_world(),"tier test temple")
	for tier: int in 4:
		for species: String in ["dragon","priest"]:
			var habitat: String = ("rainbow_dragon_throne" if species == "dragon" else "rainbow_high_priest") if tier == 0 else "rainbow_%s_tier_%d" % ["fire_dragon" if species == "dragon" else "lava_priest",tier]
			if not await enter_party(habitat): check(false,"entry " + habitat); continue
			var battle: RainbowActionBattle = game.action_battle
			for member: RainbowActionActor in battle.actors.values():
				if member.unit.alive(): member.unit.vitals.health = member.unit.vitals.max_health
			var mechanics: RainbowTempleMechanics = battle.mechanics
			var bosses: Array[int] = game.living_ids(1)
			check(bosses.size() == (1 if species == "dragon" else 1<<tier), "correct independent boss count: " + habitat)
			var boss: RainbowActionActor = battle.actors[bosses[0]]
			check(boss.enemy.boss_tier.tier == tier,"native tier resource: " + habitat)
			for ratio: float in [0.6,0.3]:
				mechanics.hazards.clear()
				for state: Dictionary in mechanics.states.values(): state.timer = 100; state.pending = false
				var hp: float = battle.controlled().vitals.health
				boss.unit.vitals.health = boss.unit.vitals.max_health * ratio
				mechanics.tick(0.01)
				check(battle.controlled().vitals.health == hp,"phase transition has no surprise damage: " + habitat)
			check(mechanics.states[bosses[0]].phase == (3 if species == "dragon" else 2),"phase threshold: " + habitat)
			if species == "priest":
				for state: Dictionary in mechanics.states.values(): state.timer = 0
				var bounded: bool = true
				for step: int in 60:
					mechanics.tick(0.1)
					var active: int = 0
					for state: Dictionary in mechanics.states.values():
						if state.pending: active += 1
					if active > (1 if bosses.size() <= 2 else 2): bounded = false
				check(bounded,"ritual major casters stay bounded: " + habitat)
				var body_clear: bool = true
				for id: int in bosses:
					var member: RainbowActionActor = battle.actors[id]
					var shape := CircleShape2D.new(); shape.radius = member.body_radius
					var query := PhysicsShapeQueryParameters2D.new()
					query.shape = shape; query.transform = Transform2D(0,member.unit.position); query.collision_mask = 5
					if not game.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): body_clear = false
				check(body_clear,"priest ritual placement clears complete native collision body")
				if bosses.size() > 1:
					var survivor: TacticalUnit = game.get_unit(bosses[1])
					var before: float = survivor.vitals.health
					game.apply_damage(boss.unit,10000000,false,CombatMath.Kind.MAGIC)
					mechanics.tick(0.01)
					check(survivor.vitals.health == before and mechanics.living_priests().size() == bosses.size()-1,"priest HP independent and dead leader removed")
					check(mechanics.regroup_until > mechanics.ritual_clock,"death starts regroup warning")
			else:
				var produced: bool = true
				var original_pool: PackedStringArray = boss.enemy.boss_tier.attack_pool.duplicate()
				for move: String in original_pool:
					mechanics.hazards.clear()
					var controlled_actor: RainbowActionActor = battle.actors[battle.controlled_id]
					controlled_actor.action = &""; controlled_actor.recovery = 0; controlled_actor.stun = 0
					controlled_actor.unit.position = Vector2(800,1000)
					boss.unit.position = Vector2(800,480)
					for frame: int in 2: await get_tree().physics_frame
					boss.enemy = boss.enemy.duplicate(true)
					boss.enemy.boss_tier.attack_pool = PackedStringArray([move])
					boss.enemy.boss_tier.weights = PackedFloat32Array([1])
					mechanics.begin_special(boss)
					produced = produced and not mechanics.hazards.is_empty()
					for hazard: Dictionary in mechanics.hazards:
						check(hazard.warning >= 1.2,"complete attack warning: " + move)
				check(produced,"each tier move admits a reachable attack: " + habitat)
				mechanics.hazards.clear()
				for state: Dictionary in mechanics.states.values(): state.timer = 100; state.pending = false
				var victim: RainbowActionActor = battle.actors[battle.controlled_id]
				var hits_before: int = victim.hits
				for sample: int in 2:
					mechanics.hazards.append({"id":90000+sample,"source":boss.unit.unit_id,"kind":"orb","center":victim.unit.position,"radius":32.0,"inner":0.0,"direction":Vector2.RIGHT,"angle":PI,"warning":0.02+sample*0.1,"total":1.2,"power":1.0,"fired":false,"flash":0.18,"projectile_group":90000,"previous":victim.unit.position})
				for step: int in 20: mechanics.tick(0.01)
				check(victim.hits == hits_before+1,"one projectile hits each victim once across path samples")
				mechanics.hazards.clear()
			boss.pose.reset(boss.unit.position)
			var camera_actor: RainbowActionActor = battle.actors[battle.controlled_id]
			camera_actor.pose.reset(camera_actor.unit.position)
			battle.follow_camera(1.0)
			await shot("tier-%d-%s" % [tier,species])
			print("TIER_METRICS ",JSON.stringify({"tier":tier,"species":species,"max_schedule_us":mechanics.max_schedule_us,"schedule_checks":mechanics.schedule_checks,"seed":mechanics.rng.seed}))
			game.retreat(); game.start_world()
			check(await wait_world() and game.action_battle == null,"tier retreat restores world: " + habitat)
	finish()
