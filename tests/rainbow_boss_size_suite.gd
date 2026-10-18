extends "res://tests/rainbow_dungeon_suite.gd"

func verify_mechanics() -> void:
	await super.verify_mechanics()
	var battle: RainbowActionBattle = game.action_battle
	var boss: RainbowActionActor = battle.actors[game.living_ids(1)[0]]
	if not boss.enemy.boss: return
	var hero: RainbowActionActor = battle.actors[battle.controlled_id]
	for actor: RainbowActionActor in battle.actors.values():
		actor.unit.position = Vector2(1300,1100)
		actor.unit.velocity = Vector2.ZERO
	boss.unit.position = Vector2(800,600)
	check(is_equal_approx(boss.body_shape.shape.radius, boss.enemy.body_radius), "boss native physical shape uses own radius: " + boss.enemy.pattern)
	check(boss.unit.collision_layer & 8 != 0 and hero.unit.collision_mask & 8 != 0, "boss body blocks player through isolated action layer")
	hero.unit.position = boss.unit.position + Vector2(boss.body_radius + hero.body_radius + 30, 0)
	for frame: int in 4: await get_tree().physics_frame
	var collision := KinematicCollision2D.new()
	check(hero.unit.test_move(hero.unit.transform, Vector2(-100,0), collision), "walking through boss body produces real physics collision")
	check(collision.get_collider() == boss.unit, "blocking collider is the boss, not scenery")
	hero.unit.position = boss.unit.position + Vector2(hero.profile.melee_range + boss.extra_radius() * 0.6,0)
	hero.attack_facing = Vector2.LEFT
	var hp: float = boss.unit.vitals.health
	battle.release(hero, &"melee")
	check(boss.unit.vitals.health < hp, "melee reaches enlarged body without reaching old center range")
	hero.attack_facing = Vector2.RIGHT
	hp = boss.unit.vitals.health
	battle.release(hero, &"melee")
	check(boss.unit.vitals.health == hp, "enlarged body does not allow attacking behind the player")
	var offset: float = (boss.body_radius + GameSettings.profile.collision_radius + 7) * 0.5
	battle.projectiles.clear()
	battle.projectiles.append({"id":999,"source_id":hero.unit.unit_id,"point":boss.unit.position+Vector2(-160,offset),"velocity":Vector2(320,0),"left":2.0,"team":0,"power":30.0,"scale":1.0,"weapon":hero.weapon,"hit_ids":[],"pierce":1})
	hp = boss.unit.vitals.health
	battle.tick_projectiles(1.0)
	check(boss.unit.vitals.health < hp, "projectile grazing enlarged torso hits outside old small radius")
	battle.projectiles.clear()
	battle.projectiles.append({"id":1000,"source_id":hero.unit.unit_id,"point":boss.unit.position+Vector2(-160,boss.body_radius+20),"velocity":Vector2(320,0),"left":2.0,"team":0,"power":30.0,"scale":1.0,"weapon":hero.weapon,"hit_ids":[],"pierce":1})
	hp = boss.unit.vitals.health
	battle.tick_projectiles(1.0)
	check(boss.unit.vitals.health == hp, "projectile outside enlarged body still misses")
	check(boss.body_radius + hero.body_radius + 24 < (170 if boss.enemy.pattern == "dragon" else 145), "boss footprint leaves reachable safe-ring space")
	boss.hit_flash = 0; boss.hit_stop = 0; hero.hit_flash = 0
	hero.unit.position = boss.unit.position + Vector2(140,100)
	boss.pose.reset(boss.unit.position); hero.pose.reset(hero.unit.position)
	battle.follow_camera(1.0)
	check(game.camera.zoom.x < battle.original_camera_zoom.x, "near-boss camera widens framing")
	if DisplayServer.get_name() != "headless":
		for frame: int in 4: await get_tree().process_frame
		await shot("body-size-" + boss.enemy.pattern)
	boss.restore_body()
	check(boss.unit.collision_layer == boss.original_layer and boss.body_shape.shape == boss.original_shape, "disposing body override restores original collision resources")
