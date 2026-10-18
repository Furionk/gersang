extends Node
const OUT:String="res://artifacts/tests/hogwarts/"
var game:GameDirector
var passed:int=0
var failed:int=0
var checks:Array[Dictionary]=[]
var deaths:int=0
func _ready()->void:
	get_tree().create_timer(150).timeout.connect(func()->void:get_tree().quit(2))
	call_deferred("run")
func check(ok:bool,caption:String)->void:
	checks.append({"test":caption,"pass":ok})
	print("PASS | " if ok else "FAIL | ",caption)
	if ok: passed+=1
	else: failed+=1
func monster(id:String)->UnitDefinition:return load("res://features/units/data/monsters/"+id+".tres")
func target(at:Vector2)->TacticalUnit:
	var data:UnitDefinition=monster("beast").duplicate(true)
	data.max_health=100000;data.defense=0;data.armor=0;data.magic_resistance=0;data.evasion=0
	return game.spawn_unit(data,0,at,false)
func capture(name_text:String)->void:
	if DisplayServer.get_name()=="headless":return
	game.camera.force_update_scroll()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name_text+".png")
func run()->void:
	LegacyPartyFixture.install();DirAccess.make_dir_recursive_absolute(OUT)
	check(not PartyProgress.persistence_enabled,"isolated progress and save paths")
	WorldCatalog.initialize()
	var map:WorldMapDefinition=WorldCatalog.definitions.hogwarts
	check(WorldValidator.validate(map,WorldCatalog.definitions).is_empty(),"school native world and bidirectional portal valid")
	var context:WorldContext=WorldContext.new();context.initialize(PartyProgress.serialize(),7654,true);context.ensure_map("hogwarts")
	var population:Dictionary=context.state.maps.hogwarts
	check(map.habitats.size()==8 and population.parties.size()==30,"8 native regions populate all30 parties")
	var legal:bool=true;var levels:bool=true;var boss_party:Dictionary
	var kinds:Dictionary={}
	for party:Dictionary in population.parties.values():
		var habitat:WorldHabitat=map.habitat(party.habitat_id)
		legal=legal and context.navigation.segment_legal("hogwarts",party.habitat_id,"SPAWN",party.home,party.home,habitat.profile.radius)
		for member:Dictionary in party.deployed_units:
			kinds[member.definition_id]=true
			var bounds:Array={"school_dementor":[50,75],"school_dark_elf":[40,60],"school_gatekeeper":[50,70],"school_basilisk":[80,80],"school_cerberus":[75,75],"voldemort_illusion":[90,90]}[member.definition_id]
			levels=levels and member.level>=bounds[0] and member.level<=bounds[1]
			if member.definition_id=="voldemort_illusion":boss_party=party
	check(legal and levels and kinds.size()==6,"all species level ranges and legal spawn points")
	check(context.navigation.find_path("hogwarts","","PLAYER",map.entries.entrance.point,boss_party.position,16).ok,"entrance reaches central boss")
	context.state.player.protected_until_ms=99999999
	# Approach locally; a long route through an older portal legitimately enters that map first.
	context.state.player.position=WorldCatalog.definitions.river_bay.entries.school_return.point
	var approach:Dictionary=context.approach_portal("school_door")
	check(approach.ok,"river portal uses actual legal approach route")
	if approach.ok:
		for frame:int in 1500:
			context.tick(0.1)
			if context.state.mode=="TRANSITION":break
		check(context.state.player.map_id=="hogwarts" and context.state.mode=="TRANSITION","actual river travel arrives in school without teleport shortcut")
		context.complete_portal(context.state.control_owner)
		var exit_approach:Dictionary=context.approach_portal("school_exit")
		if exit_approach.ok:
			for frame:int in 300:
				context.tick(0.1)
				if context.state.mode=="TRANSITION":break
		check(exit_approach.ok and context.state.player.map_id=="river_bay","school exit returns to authored river arrival")
		context.complete_portal(context.state.control_owner)
	for id:String in ["school_dementor","school_dark_elf","school_gatekeeper","school_basilisk","school_cerberus","voldemort_illusion","ganondorf_phantom","ganondorf_echo"]:
		var data:UnitDefinition=monster(id)
		check(data.sprite_layout.valid_for(SpriteAtlas.texture_for(data).get_size()) and data.sprite_layout.resource_path.begins_with("res://features/units/data/layouts/") and data.skills[0].resource_path.begins_with("res://features/skills/data/"),id+" external editable art layout and skill")
		var fitting:bool=true
		for row:int in 8:
			for col:int in 6:
				var atlas:AtlasTexture=SpriteAtlas.frame(SpriteAtlas.texture_for(data),data.sprite_layout,row,col)
				fitting=fitting and Rect2(Vector2.ZERO,Vector2(data.sprite_layout.frame_size)).encloses(Rect2(atlas.margin.position,atlas.region.size))
		check(fitting,id+" all48 silhouettes fit native canvas at anchored foot")
	check(monster("school_dementor").movement_type==UnitDefinition.Movement.AIR,"dementor is an actual flying unit")
	check(monster("voldemort_illusion").death_phase.next_form==monster("ganondorf_phantom") and monster("ganondorf_echo").death_phase==null,"external nonrecursive phase chain")
	game=load("res://main.tscn").instantiate();add_child(game)
	while game.mode!=&"world":await get_tree().process_frame
	game.set_physics_process(false);game.set_process(false);game.cinematic_camera=false
	WorldSession.context.ensure_map("hogwarts");WorldSession.context.state.player.map_id="hogwarts";WorldSession.context.state.player.position=map.entries.entrance.point
	game.start_world()
	while game.mode!=&"world":await get_tree().process_frame
	game.set_physics_process(false);game.camera.zoom=Vector2.ONE*0.32;game.camera.position=Iso.project(map.extent*0.5)
	await capture("school-world")
	var arena:ArenaDefinition=load("res://features/world/data/hogwarts_arena.tres")
	game.start_battle(arena.encounter)
	while game.mode!=&"battle":await get_tree().process_frame
	game.set_physics_process(false)
	for unit:TacticalUnit in game.units.values():unit.vitals.health=0
	var camera_bounds:Rect2=game.battle_camera_bounds()
	var far_corner:Vector2=Iso.project((Vector2(game.ground.cells)-Vector2.ONE)*Iso.CELL)
	check(camera_bounds.has_point(far_corner) and camera_bounds.end.y>1150,"native battlefield dimensions expose far spawn cells to camera")
	var victim:TacticalUnit=target(Vector2(1000,850))
	var drain:TacticalUnit=game.spawn_unit(monster("school_dementor"),1,Vector2(800,850),false)
	drain.vitals.health=drain.vitals.max_health-500
	var before:float=drain.vitals.health
	game.resolve_skill(drain,drain.definition.skills[0],victim.position,victim.unit_id)
	var effect:BattleSkillEffect=game.effects.back()
	check(drain.channeling and drain.vitals.health>before and victim.vitals.health<victim.vitals.max_health,"soul drain channels and heals actual damage")
	victim.position=Vector2(1600,850);effect.tick(0.1)
	check(effect.done and not drain.channeling,"soul drain breaks when target leaves range")
	victim.position=Vector2(1000,850)
	game.resolve_skill(drain,drain.definition.skills[0],victim.position,victim.unit_id);effect=game.effects.back();drain.control_left=1;effect.tick(0.1)
	check(effect.done and not drain.channeling,"control interrupts channel")
	var elf:TacticalUnit=game.spawn_unit(monster("school_dark_elf"),1,Vector2(500,850),false)
	game.resolve_skill(elf,elf.definition.skills[0],victim.position,victim.unit_id)
	check(is_equal_approx(elf.position.distance_to(victim.position),130) and not game.ground._navigation_blocked(Vector2i(elf.position/Iso.CELL)),"teleport lands near enemy in legal unoccupied cell")
	var basilisk:TacticalUnit=game.spawn_unit(monster("school_basilisk"),1,Vector2(1000,1100),false)
	var petrify:SkillDefinition=basilisk.definition.skills[0]
	check(is_equal_approx(petrify.cast_time,1),"petrify authored1 second cast")
	game.resolve_skill(basilisk,petrify,victim.position,victim.unit_id)
	check(victim.control_left==4 and victim.petrified_left==4,"petrify applies four-second area control")
	victim.tick(4.1);check(victim.control_left<=0 and victim.petrified_left<=0,"petrification expires and movement recovers")
	basilisk.definition=basilisk.definition.duplicate(true)
	basilisk.definition.skills[0].ai_cast_chance=1.0
	check(basilisk._auto_enemy_skill(victim),"monster AI selects authored petrification skill")
	basilisk._tick_cast(0.01);basilisk.tick(0.6)
	check(victim.control_left<=0 and basilisk.cast_left>0,"actual enemy cast honors1 second windup")
	basilisk.tick(0.41)
	check(victim.petrified_left==4,"actual enemy AI release applies petrification without direct resolve shortcut")
	victim.tick(4.1)
	var guard:TacticalUnit=game.spawn_unit(monster("school_gatekeeper"),1,Vector2(1400,850),false)
	var n:int=game.effects.size();guard.abilities.on_basic_damage_landed(50,victim)
	check(game.effects.size()==n+1 and game.effects.back().data.kind==SkillEffectDefinition.Kind.LINE,"guardian actual attack proc releases linear shockwave")
	var red:SkillDefinition=monster("school_cerberus").skills[0]
	check(red.effect_data.kind==SkillEffectDefinition.Kind.CHARGE and red.effect_data.width>=150 and red.tint.r>red.tint.b,"cerberus has large red physical charge")
	var full:SkillDefinition=load("res://features/skills/data/avada_kedavra.tres")
	var weak:SkillDefinition=monster("voldemort_illusion").skills[0]
	var stats:Dictionary={"intelligence":120}
	check(is_equal_approx(float(DamageFormula.evaluate(weak.effect_data.target_max_hp_ratio_formula,stats).value),0.275),"D42 illusion preserves original Avada ratio at120INT independently of changed player spell")
	for unit:TacticalUnit in game.units.values():if unit.team==1:unit.vitals.health=0
	for old_effect:BattleSkillEffect in game.effects:old_effect.finish()
	game.effects.clear()
	var boss:TacticalUnit=game.spawn_unit(monster("voldemort_illusion"),1,Vector2(1400,1000),false)
	boss.persistent_unit_id="school-boss-fixture";boss.died.connect(func(_id:int)->void:deaths+=1)
	var unit_id:int=boss.unit_id;var original_blocked:Array[Rect2i]=game.ground.blocked.duplicate(true)
	game.apply_damage(boss,1000000,false,CombatMath.Kind.MAGIC)
	check(boss.alive() and boss.definition.id==&"ganondorf_phantom" and boss.unit_id==unit_id and boss.persistent_unit_id=="school-boss-fixture" and deaths==0,"first lethal evolves sameID without death or early reward")
	check(game.phases.frozen() and game.phases.changed_scene.ends_with("hogwarts_blood_moon.tscn") and game.ground.blocked==original_blocked,"bloodmoon swaps native scene retaining exact navigation")
	var hp:float=victim.vitals.health;var clock:float=game.phases.hazard_left
	game.retreat();game._physics_process(1.9)
	check(game.mode==&"battle" and game.phases.frozen() and victim.vitals.health==hp and game.phases.hazard_left==clock,"cinematic freezes battle hazard and retreat for full2 seconds")
	game._physics_process(0.11);check(not game.phases.frozen(),"battle resumes after transformation2 seconds")
	game.camera.zoom=Vector2.ONE*0.7;game.camera.position=Iso.project(boss.position)
	await capture("blood-moon-boss")
	game.phases.tick(2.99);check(victim.vitals.health==hp,"bloodmoon no damage before3 seconds")
	var boss_hp:float=boss.vitals.health;game.phases.tick(0.02)
	check(is_equal_approx(hp-victim.vitals.health,victim.vitals.max_health*0.01) and is_equal_approx(boss_hp-boss.vitals.health,boss.vitals.max_health*0.01),"single bloodmoon pulse1percent maximumHP affects both teams including boss")
	game.apply_damage(boss,1000000,false,CombatMath.Kind.MAGIC)
	var clones:Array[int]=game.living_ids(1)
	check(deaths==1 and clones.size()==5 and game.phases.pending.is_empty(),"second lethal spawns exactly5 enemies and one final death")
	var valid_clones:bool=true;var points:Array[Vector2]=[]
	for id:int in clones:
		var clone:TacticalUnit=game.get_unit(id)
		valid_clones=valid_clones and clone.definition.id==&"ganondorf_echo" and clone.definition.death_phase==null and clone.persistent_unit_id.is_empty() and clone.definition.experience_reward==0 and clone.definition.outgoing_damage_scale==0.5 and not points.has(clone.position) and not game.ground._navigation_blocked(Vector2i(clone.position/Iso.CELL))
		points.append(clone.position)
	check(valid_clones,"echoes use unique legal random cells no recursive phase or extra receipt IDs")
	check(points.all(func(p:Vector2)->bool:return game.battle_camera_bounds().has_point(Iso.project(p))),"camera can reach all random final echo positions")
	var echo:TacticalUnit=game.get_unit(clones[0]);var local_skill:SkillDefinition=echo.definition.skills[0].duplicate(true)
	local_skill.damage_type=CombatMath.Kind.MAGIC;local_skill.damage_formula="100"
	echo.position=victim.position;var before_echo:float=victim.vitals.health;game.resolve_skill(echo,local_skill,victim.position+Vector2(300,0),victim.unit_id)
	var expected_power:float=100*local_skill.formula_multiplier
	check(is_equal_approx(game.effects.back().power,expected_power) and is_equal_approx(game.effects.back().snapshot.damage_scale,0.5),"echo shockwave snapshots authored formula multiplier then half final damage once")
	check(is_equal_approx(before_echo-victim.vitals.health,expected_power*0.5),"echo actual pulse equals half strengthened formula")
	game.effects.back().finish();game.phases.hazard=null
	game._physics_process(0.01);check(game.mode==&"battle" and not game.victory_pending,"five live echoes prevent premature victory")
	for id:int in clones:game.apply_damage(game.get_unit(id),1000000,false,CombatMath.Kind.MAGIC)
	check(game.living_ids(1).is_empty() and game.phases.pending.is_empty() and deaths==1,"all echoes die permanently without additional split")
	game._physics_process(0.01);check(game.victory_pending and game.mode==&"battle","only final extinction begins normal operable cleanup")
	# Persistent settlement must pay once for the original snapshot, not six phase bodies.
	context.state.player.map_id="hogwarts";context.state.player.position=boss_party.position;context.state.player.protected_until_ms=0;context.state.player.cooldown_until_ms=0
	var entry:Dictionary=context.encounters.try_begin("player",boss_party.party_id,"player")
	check(entry.ok,"actual school world boss encounter reserves correctly")
	if entry.ok:
		var session:Dictionary=context.state.active_encounter;session.state="LOADING";context.encounters.mark_in_battle(session.encounter_id)
		var result:Dictionary={"encounter_id":session.encounter_id,"outcome":"victory","player_unit_results":[],"defeated_enemy_unit_ids":[boss_party.deployed_units[0].unit_id],"consumed_items":[]}
		for member:Dictionary in session.player_party_snapshot.deployed_units:result.player_unit_results.append({"unit_id":member.unit_id,"hp":50.0,"mp":10.0})
		var settled:Dictionary=context.settlement.apply(result)
		check(settled.ok and context.state.applied_results[session.encounter_id].experience==30000,"three-stage boss pays authored original reward once")
		var progress:Dictionary=context.state.progress.duplicate(true);context.settlement.apply(result)
		check(context.state.progress==progress,"repeated settlement cannot duplicate boss reward")
	game.start_world()
	while game.mode!=&"world":await get_tree().process_frame
	game.set_physics_process(false)
	var live:WorldContext=WorldSession.context;var actual_boss:Dictionary
	for party:Dictionary in live.state.maps.hogwarts.parties.values():
		if party.deployed_units[0].definition_id=="voldemort_illusion":actual_boss=party;break
	live.state.player.map_id="hogwarts";live.state.player.position=actual_boss.position;live.state.player.protected_until_ms=0;live.state.player.cooldown_until_ms=0
	var entered:Dictionary=live.encounters.try_begin("player",actual_boss.party_id,"player")
	check(entered.ok,"formal native school boss encounter starts")
	if entered.ok:
		var ticket:String=live.state.active_encounter.encounter_id;live.state.active_encounter.state="LOADING"
		game._encounter_battle(live.state.active_encounter.duplicate(true))
		while game.mode!=&"battle":await get_tree().process_frame
		game.set_physics_process(false)
		var real_boss:TacticalUnit=game.get_unit(game.living_ids(1)[0])
		check(game.ground.battle_id=="hogwarts" and real_boss.persistent_unit_id==actual_boss.deployed_units[0].unit_id,"formal encounter loads school battlefield and snapshot ID")
		game.apply_damage(real_boss,1000000,false,CombatMath.Kind.MAGIC);game._physics_process(2.01)
		game.apply_damage(real_boss,1000000,false,CombatMath.Kind.MAGIC)
		for id:int in game.living_ids(1):game.apply_damage(game.get_unit(id),1000000,false,CombatMath.Kind.MAGIC)
		game._physics_process(0.01)
		check(game.mode==&"battle" and game.victory_pending and not live.state.applied_results.has(ticket),"formal final extinction waits without early settlement")
		for frame:int in 122:game._physics_process(1.0/60.0)
		check(game.mode==&"results" and live.state.applied_results.has(ticket) and live.state.applied_results[ticket].experience==30000,"actual three-stage battle settles30000XP exactly once")
		check(game.settlement_result.defeated_enemy_unit_ids==[actual_boss.deployed_units[0].unit_id],"formal receipt includes only original boss not blank phase IDs")
		var paid:Dictionary=live.state.progress.duplicate(true);live.settlement.apply(game.settlement_result)
		check(live.state.progress==paid,"actual battle callback remains idempotent")
	var report:Dictionary={"passed":passed,"failed":failed,"tests":checks,"rendered":DisplayServer.get_name()!="headless"}
	var file:FileAccess=FileAccess.open(OUT+("render.json" if report.rendered else "headless.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("HOGWARTS_RESULT ",JSON.stringify(report));get_tree().quit(0 if failed==0 else 1)
