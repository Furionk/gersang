extends Node
const OUT:String="res://artifacts/tests/combat-empower/"
var passed:int=0
var failures:Array[String]=[]
var checks:Array[Dictionary]=[]
var game:GameDirector
func _ready()->void:
	get_tree().create_timer(180).timeout.connect(func()->void:get_tree().quit(2));call_deferred("run")
func check(ok:bool,name_text:String)->void:
	checks.append({"pass":ok,"test":name_text});print("PASS | " if ok else "FAIL | ",name_text)
	if ok:passed+=1
	else:failures.append(name_text)
func skill(id:String)->SkillDefinition:return load("res://features/skills/data/"+id+".tres")
func unit(id:String)->UnitDefinition:return load("res://features/units/data/monsters/"+id+".tres")
func target(at:Vector2)->TacticalUnit:
	var data:UnitDefinition=unit("beast").duplicate(true);data.level=1;data.max_health=1000000;data.defense=0;data.strength=0;data.armor=0;data.magic_resistance=0;data.evasion=0
	return game.spawn_unit(data,1,at,false)
func capture(id:String)->void:
	if DisplayServer.get_name()=="headless":return
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+id+".png")
func clear_effects()->void:
	for effect:BattleSkillEffect in game.effects:effect.finish()
	game.effects.clear()
func run()->void:
	LegacyPartyFixture.install();DirAccess.make_dir_recursive_absolute(OUT)
	check(not PartyProgress.persistence_enabled,"test isolates all player saves")
	var stats:Dictionary={"strength":50,"intelligence":100,"attack":100,"agility":50}
	for id:String in ["blast","dragon","quake"]:
		var data:SkillDefinition=skill(id);var base:Dictionary=DamageFormula.evaluate(data.damage_formula,stats)
		check(is_equal_approx(data.result(stats).value,base.value*3),id+" exact formula times3 once")
	check(skill("blast").radius==300 and skill("blast").effect_data.use_skill_radius,"blast radius doubles and single Radius owns actual range")
	check(skill("dragon").effect_data.width==120 and skill("dragon").effect_data.line_visual_count==3 and skill("dragon").battlefield_range,"dragon doubles width and retains full battlefield range")
	check(is_equal_approx(DamageFormula.evaluate(skill("avada_kedavra").effect_data.target_max_hp_ratio_formula,stats).value,0.45),"player Avada35percent plus INT0.1percent")
	check(is_equal_approx(DamageFormula.evaluate(skill("illusion_avada").effect_data.target_max_hp_ratio_formula,stats).value,0.25),"phantom Avada original50percent plusINT0.5percent then25percent unchanged")
	check(skill("summon").effect_data.summon_limit==0 and skill("earth_claw").mana_cost>0,"unlimited loyal spirits and paid earth claws authored")
	check(skill("heal").support_interval==0.1 and skill("supply").support_interval==0.1,"both support scan intervals configurable and faster")
	# Stat migration: simulated old save, no reroll or player mutations.
	var context:WorldContext=WorldContext.new();context.initialize(PartyProgress.serialize(),781,true)
	var runtime:Dictionary=context.state.maps.river_bay;var party:Dictionary=runtime.parties.values()[0];var member:Dictionary=party.deployed_units[0]
	member.balance_revision=0;member.resolved_stats.health*=0.5;member.current_hp=member.resolved_stats.health*0.37
	var id:String=member.unit_id;var level:int=member.level;var location:Vector2=party.position;var count:int=runtime.parties.size();var progress:Dictionary=context.state.progress.duplicate(true)
	context.state.active_encounter={"encounter_id":"locked"};context.ensure_map("river_bay");check(member.balance_revision==0,"numeric refresh defers locked encounter")
	context.state.active_encounter={};context.ensure_map("river_bay")
	check(member.balance_revision==1 and is_equal_approx(member.current_hp/member.resolved_stats.health,0.37),"old enemy numerical stats update preserving wounded HP ratio")
	check(member.unit_id==id and member.level==level and party.position==location and runtime.parties.size()==count and context.state.progress==progress,"migration preserves IDs levels positions composition and player progress")
	var snapshot:Dictionary=context.snapshot();context.ensure_map("river_bay");check(context.snapshot()==snapshot,"numeric revision idempotent no reapply")
	var all_tuned:bool=true
	for name:String in DirAccess.get_files_at("res://features/units/data/monsters"):
		if name.ends_with(".tres"):
			var data:UnitDefinition=load("res://features/units/data/monsters/"+name)
			all_tuned=all_tuned and data.balance_revision==1 and not data.tactical_hint.is_empty() and data.minimum_ai_cast_time>0
	check(all_tuned,"every monster has authored enhancement and counterplay hint")
	check(unit("school_gatekeeper").armor>unit("school_dementor").armor and unit("school_gatekeeper").magic_resistance<unit("school_dementor").magic_resistance,"tank and caster have genuinely different physical/magic counters")
	game=load("res://main.tscn").instantiate();add_child(game)
	while game.mode!=&"world":await get_tree().process_frame
	game.set_physics_process(false);game.set_process(false);game.cinematic_camera=false;game.audio.muted=true
	game.start_battle((load("res://features/world/data/hogwarts_arena.tres") as ArenaDefinition).encounter)
	while game.mode!=&"battle":await get_tree().process_frame
	game.set_physics_process(false)
	for actor:TacticalUnit in game.units.values():actor.vitals.health=0
	var caster_data:UnitDefinition=load("res://features/units/data/mercenaries/malfory.tres");caster_data=caster_data.duplicate(true)
	caster_data.skills.assign([skill("blast"),skill("dragon"),skill("lightning"),skill("wheel"),skill("ninja_chain"),skill("summon"),skill("earth_claw")]);caster_data.max_mana=100000
	var caster:TacticalUnit=game.spawn_unit(caster_data,0,Vector2(950,850),false)
	var enemy:TacticalUnit=target(Vector2(1150,850));var second:TacticalUnit=target(Vector2(1200,930))
	game.camera.zoom=Vector2.ONE;game.camera.position=Iso.project(enemy.position);game.camera.force_update_scroll()
	game.resolve_skill(caster,skill("blast"),caster.position,-1);var blast:BattleSkillEffect=game.effects.back()
	blast.tick(0.8) # D17 fixed sites expand outward, never hit the outer band instantly.
	check(blast.data.radius==skill("blast").radius and blast.hit_counts.has(enemy.unit_id),"blast actual damage reaches newly doubled radius")
	check(skill("blast").effect_data.radius==300,"release does not mutate shared blast data")
	clear_effects();game.resolve_skill(caster,skill("dragon"),Vector2(1800,850),-1);var dragon:BattleSkillEffect=game.effects.back()
	dragon.tick(0.5);check(dragon.visuals.size()==3 and dragon.data.width==120,"three dragons render one120-wide damage band")
	await capture("triple-dragon")
	print("DRAGON_RENDER_TRACE ",dragon.visuals[0].sprite.region_rect," scale=",dragon.visuals[0].sprite.scale," cell=",dragon.visuals[0].cell)
	clear_effects()
	# Storm scheduling/source RNG is deterministic at different physics step sizes.
	var sites:Array[Array]=[];var totals:Array[float]=[]
	for fps:int in [30,120]:
		game.rng.seed=714;enemy.vitals.health=enemy.vitals.max_health;second.vitals.health=second.vitals.max_health
		game.resolve_skill(caster,skill("lightning"),enemy.position,-1);var storm:BattleSkillEffect=game.effects.back()
		for frame:int in fps*2:storm.tick(1.0/fps)
		sites.append(storm.storm_sites.duplicate());totals.append(enemy.vitals.max_health-enemy.vitals.health)
		check(storm.storm_wave_index==4 and storm.storm_sites.size()==20,"four actual stochastic waves20 strikes "+str(fps)+"FPS")
		clear_effects()
	check(sites[0]==sites[1] and is_equal_approx(totals[0],totals[1]),"seeded lightning positions and damage identical30/120FPS")
	game.resolve_skill(caster,skill("lightning"),enemy.position,-1);await capture("storm");clear_effects()
	# New wheel starts at caster and cannot hurt its distant target instantly.
	enemy.position=Vector2(1550,850);var hp:float=enemy.vitals.health
	game.resolve_skill(caster,skill("wheel"),enemy.position,enemy.unit_id);var wheel:BattleSkillEffect=game.effects.back()
	check(wheel.point==caster.position and enemy.vitals.health==hp,"wheel starts at caster no target teleport or instant damage")
	wheel.tick(0.2);check(wheel.point.distance_to(caster.position)>0 and wheel.point.distance_to(enemy.position)>100,"wheel moves at authored speed before arrival")
	for frame:int in 90:wheel.tick(1.0/60.0)
	check(wheel.follow_reached and enemy.vitals.health<hp,"wheel reaches enemy then repeated damage")
	enemy.position+=Vector2(100,0);var old_point:Vector2=wheel.point;wheel.tick(0.1)
	check(wheel.point.distance_to(enemy.position)<old_point.distance_to(enemy.position),"wheel actually follows moving target")
	check(wheel.visuals[0].life>wheel.age,"wheel rendering lifetime includes travel so no invisible final damage")
	await capture("tracking-wheel");clear_effects();enemy.position=Vector2(1150,850)
	if DisplayServer.get_name()!="headless":await get_tree().create_timer(0.8).timeout
	game.rng.seed=715;game.resolve_skill(caster,skill("ninja_chain"),enemy.position,enemy.unit_id);var chain:BattleSkillEffect=game.effects.back()
	check(chain.advanced.orbs.size()>=8 and chain.advanced.orb_events.is_empty(),"targets each receive4 orbs with no simultaneous initial damage")
	var unique:Dictionary={}
	for orb:Dictionary in chain.advanced.orbs:unique[orb.next]=true
	check(unique.size()>1,"each electric orb has independently jittered first interval")
	for frame:int in 60:chain.tick(1.0/60.0)
	check(chain.advanced.orb_events.size()>0 and chain.hit_counts.has(enemy.unit_id),"staggered balls really damage enemy using fixed combat ticks")
	await capture("orbit-lightning");clear_effects()
	var orb_schedules:Array[Array]=[]
	for fps:int in [30,120]:
		game.rng.seed=715;enemy.vitals.health=enemy.vitals.max_health;second.vitals.health=second.vitals.max_health
		game.resolve_skill(caster,skill("ninja_chain"),enemy.position,enemy.unit_id);var replay:BattleSkillEffect=game.effects.back()
		for frame:int in fps*2:replay.tick(1.0/fps)
		var events:Array=replay.advanced.orb_events.duplicate(true)
		events.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.time<b.time)
		orb_schedules.append(events);clear_effects()
	check(orb_schedules[0]==orb_schedules[1],"per-orb seeds retain identical staggered schedules30/120FPS")
	var mana:float=caster.vitals.mana;caster.abilities.request(skill("earth_claw"),caster.position,-1);caster._tick_cast(0.01)
	check(is_equal_approx(mana-caster.vitals.mana,35),"earth claw actual authorized cast consumes35MP")
	for i:int in 6:game.resolve_skill(caster,skill("summon"),caster.position+Vector2(30,0),-1)
	var spirits:Array= caster.abilities.active_summon_groups.get(&"summon",[])
	check(spirits.size()==6 and caster.abilities.available(skill("summon")),"six spirits coexist with next summon still available")
	var spirit:TacticalUnit=game.get_unit(spirits[0]);spirit.position=Vector2(1000,700);enemy.position=Vector2(1200,700)
	spirit.issue_command({"kind":"attack","target":enemy.unit_id})
	var shots_before:int=spirit.shots
	for frame:int in 120:
		await get_tree().physics_frame;spirit.tick(1.0/60.0)
	check(spirit.shots-shots_before>=15,"spirit actual two-second firing rate is machinegun-fast")
	spirit.active.clear();spirit.locked_attack_id=enemy.unit_id;spirit.fsm.transition(&"attack");spirit.think_left=0.24
	shots_before=spirit.shots
	for frame:int in 60:spirit.tick(1.0/60.0)
	check(spirit.shots-shots_before>=8,"automatic ranged fire not bottlenecked by0.24s target scan")
	var healer_data:UnitDefinition=load("res://features/units/data/mercenaries/healer.tres");healer_data=healer_data.duplicate(true);healer_data.max_mana=100000
	var healer:TacticalUnit=game.spawn_unit(healer_data,0,Vector2(950,950),false)
	caster.vitals.max_health=1000000;caster.vitals.health=1000
	var initial_health:float=caster.vitals.health
	for frame:int in 120:healer.tick(1.0/60.0)
	check(healer.casts>=8 and caster.vitals.health>initial_health,"healer actual support cadence and stronger healing")
	clear_effects()
	# Immediate evolved body + freeze + real snapshot fade and persistent fog.
	var boss:TacticalUnit=game.spawn_unit(unit("voldemort_illusion"),1,Vector2(1400,1000),false)
	game.camera.position=Iso.project(boss.position);game.camera.force_update_scroll();await get_tree().process_frame
	game.apply_damage(boss,1000000,false,CombatMath.Kind.MAGIC)
	check(boss.definition.id==&"ganondorf_phantom" and boss.alive() and game.phases.frozen(),"Ganon actor exists immediately at start of transition")
	check(game.phases.overlay is BloodMoonTransition and is_instance_valid(game.phases.fog),"full-frame cinematic and persistent blood mist active")
	game.phases.tick(0.25);await capture("doomsday-fade")
	game.phases.tick(0.5);await capture("doomsday-title")
	game.phases.tick(1.26)
	check(not game.phases.frozen() and is_instance_valid(game.phases.fog),"blood fog remains after2s freeze without extending pause")
	await capture("blood-fog-battle")
	game.phases.reset();check(game.phases.fog==null and game.phases.overlay==null,"cinematic fog and snapshot lifecycle cleaned on exit")
	var report:Dictionary={"passed":passed,"failed":failures.size(),"failures":failures,"tests":checks,"rendered":DisplayServer.get_name()!="headless"}
	var file:FileAccess=FileAccess.open(OUT+("headless.json" if not report.rendered else "render.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COMBAT_EMPOWER_RESULT ",JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
