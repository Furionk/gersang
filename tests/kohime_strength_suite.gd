extends Node
var game: GameDirector
var passed: int=0
var failed: int=0
var checks: Array[Dictionary]=[]
const OUT: String="res://artifacts/kohime-strength-2026-10-11/"
func _ready() -> void:
	get_tree().create_timer(90).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks.append({"test":caption,"pass":ok})
	print("PASS | " if ok else "FAIL | ",caption)
	if ok: passed+=1
	else: failed+=1
func key(pressed: bool, echo_key: bool=false) -> void:
	var event: InputEventKey=InputEventKey.new()
	event.keycode=KEY_X; event.physical_keycode=KEY_X; event.pressed=pressed; event.echo=echo_key
	get_viewport().push_input(event,false)
	await get_tree().process_frame
func capture() -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+"claw-army.png")
func fixture(at: Vector2, flying: bool=false) -> TacticalUnit:
	var data: UnitDefinition=load("res://features/units/data/monsters/beast.tres").duplicate(true)
	data.max_health=1000000; data.defense=0; data.armor=0; data.magic_resistance=0; data.evasion=0
	data.movement_type=UnitDefinition.Movement.AIR if flying else UnitDefinition.Movement.GROUND
	return game.spawn_unit(data,1,at,false)
func run() -> void:
	LegacyPartyFixture.install()
	DirAccess.make_dir_recursive_absolute(OUT)
	check(not PartyProgress.persistence_enabled,"test isolates formal progress")
	var before: Dictionary=PartyProgress.serialize()
	game=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	game.set_physics_process(false); game.cinematic_camera=false
	var trial: Dictionary=game.debug_trial_unit("kohime")
	var hero: TacticalUnit=game.get_unit(trial.unit_id)
	hero.combat_stats.intelligence=100; hero.vitals.mana=0
	var skill: SkillDefinition=load("res://features/skills/data/earth_claw.tres")
	var template: UnitDefinition=skill.effect_data.summon_definition
	check(skill.mana_cost==0 and skill.cooldown==0 and skill.effect_data.summon_limit==0,"X zero MP cooldown and no summon cap")
	var all_casts: bool=true
	for i: int in 65:
		all_casts=game.selection.activate_skill(skill.id) and all_casts
		hero.tick(1.0/60.0)
	var group: Array=hero.abilities.active_summon_groups.get(skill.id,[])
	check(all_casts and group.size()==65,"65 consecutive casts create 65 living claws beyond60")
	# Normal regeneration occurred during those ticks; explicitly test empty mana now.
	hero.vitals.mana=0
	check(hero.vitals.mana==0 and hero.abilities.available(skill),"zero mana still permits another fresh cast")
	check(game.roster_ids.size()==7,"unlimited summons consume no permanent roster positions")
	var claw: TacticalUnit=game.get_unit(group[0])
	check(is_equal_approx(claw.vitals.max_health,1620),"wisdom100 gives HP1620")
	check(is_equal_approx(claw.combat_stats.defense,80),"wisdom100 gives defense80")
	check(is_equal_approx(claw.attack_interval_now(),0.45),"normal stab interval0.45")
	check(claw.definition.speed==150 and claw.definition.attack_range==110,"claw faster movement and better reach")
	check(not claw.definition.controllable and claw.definition.random_nearby_target,"claw remains autonomous")
	check(template.max_health==420 and template.defense==0 and template.intelligence==0,"shared summon template not mutated")
	hero.combat_stats.intelligence=200
	await key(true); hero.tick(1.0/60.0); await key(false)
	group=hero.abilities.active_summon_groups[skill.id]
	var stronger: TacticalUnit=game.get_unit(group.back())
	check(group.size()==66,"actual X key creates one additional claw")
	check(stronger.vitals.max_health==2820 and stronger.combat_stats.defense==160,"new summon snapshots wisdom200 health defense")
	check(claw.vitals.max_health==1620 and claw.combat_stats.defense==80 and claw.definition.intelligence==100,"existing claws keep release snapshot")
	await key(true,true); hero.tick(1.0/60.0); await key(false)
	check(hero.abilities.active_summon_groups[skill.id].size()==66,"held-key echo does not spam summons")
	for effect: BattleSkillEffect in game.effects:
		if effect.data.kind==SkillEffectDefinition.Kind.SUMMON: effect.finish()
	game._tick_effects(0)
	var point: Vector2=game._safe_spawn(Vector2(750,650))
	claw.position=point
	var target: TacticalUnit=fixture(point+Vector2(30,0))
	var other: TacticalUnit=fixture(point+Vector2(70,0))
	var air: TacticalUnit=fixture(point+Vector2(25,0),true)
	var hp: float=target.vitals.health; var other_hp: float=other.vitals.health; var air_hp: float=air.vitals.health
	game.basic_attack(claw,target,99999)
	check(is_equal_approx(hp-target.vitals.health,320) and is_equal_approx(other_hp-other.vitals.health,320),"wisdom100 stab deals320 AoE exactly once")
	check(air.vitals.health==air_hp,"claw AoE still excludes air")
	var stakes: SkillDefinition=load("res://features/skills/data/earth_stakes.tres")
	game.resolve_skill(hero,stakes,point,-1)
	var field: BattleSkillEffect=game.effects.back()
	check(stakes.radius==160 and stakes.effect_data.radius==160 and stakes.range==400,"main technique larger field and casting reach")
	check(is_equal_approx(field.power,155),"wisdom200 main skill pulse155")
	hp=target.vitals.health
	game.basic_attack(claw,target,99999)
	check(is_equal_approx(hp-target.vitals.health,560),"own field amplifies stab1.75x")
	check(is_equal_approx(claw.attack_interval_now(),0.45/1.4),"own field accelerates stab1.4x")
	game.resolve_skill(hero,stakes,point,-1)
	var second: BattleSkillEffect=game.effects.back()
	check(game.summon_field_multiplier(claw,target.position)==1.75 and is_equal_approx(claw.attack_interval_now(),0.45/1.4),"overlapping fields never multiply bonuses")
	claw.position=point+Vector2(400,0)
	check(is_equal_approx(claw.attack_interval_now(),0.45),"leaving field immediately restores normal attack speed")
	claw.position=point
	var stranger: TacticalUnit=game.spawn_unit(hero.definition,0,game._safe_spawn(point+Vector2(220,0)),false)
	game.resolve_skill(stranger,stakes,point,-1)
	field.finish(); second.finish()
	check(game.summon_field_multiplier(claw,target.position)==1 and is_equal_approx(claw.attack_interval_now(),0.45),"another sorceress field cannot buff these claws")
	var enemy_definition: UnitDefinition=load("res://features/units/data/monsters/earth_claw_enemy.tres")
	check(enemy_definition.attack_interval==1.2 and enemy_definition.skills[0].damage_formula=="15+intelligence*1.4","enemy variant not unintentionally strengthened")
	var enemy_sorceress: UnitDefinition=load("res://features/units/data/monsters/kohime_enemy.tres")
	var enemy_template: UnitDefinition=enemy_sorceress.skills[1].effect_data.summon_definition
	check(enemy_template.attack_interval==1.2 and enemy_template.intelligence==0 and enemy_template.skills[0].damage_formula=="15+intelligence*1.4","enemy sorceress retains dedicated original-strength summon")
	var invalid: SkillEffectDefinition=skill.effect_data.duplicate(true)
	invalid.summon_health_bonus_formula="bad_variable"
	check(not SummonScaling.evaluate(invalid,hero.stats_snapshot()).valid,"invalid HP formula rejected")
	invalid=skill.effect_data.duplicate(true); invalid.summon_defense_bonus_formula="bad_variable"
	check(not SummonScaling.evaluate(invalid,hero.stats_snapshot()).valid,"invalid defense formula rejected")
	game.camera.position=Iso.project(point)+Vector2(100,0); game.camera.force_update_scroll()
	await capture()
	var expired_id: int=claw.unit_id
	claw.summon_left=0.001; claw.tick(0.01); await get_tree().process_frame; hero.abilities.tick(0)
	check(expired_id not in hero.abilities.active_summon_groups[skill.id],"expired claw removed from live summon group")
	check(PartyProgress.serialize()==before,"summon army does not alter saved characters")
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	check(game.effects.is_empty() and game.units.size()==1,"return clears entire summon army and fields")
	var report: Dictionary={"passed":passed,"failed":failed,"tests":checks,"rendered":DisplayServer.get_name()!="headless"}
	var file: FileAccess=FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "render.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("KOHIME_STRENGTH_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failed==0 else 1)
