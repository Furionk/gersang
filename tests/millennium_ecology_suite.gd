extends Node
var game: GameDirector
var passed: int=0
var failed: int=0
var checks: Array[Dictionary]=[]
var deaths: int=0
const OUT: String="res://artifacts/millennium-ecology-2026-10-11/"
func _ready() -> void:
	get_tree().create_timer(150).timeout.connect(func()->void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks.append({"test":caption,"pass":ok})
	print("PASS | " if ok else "FAIL | ",caption)
	if ok: passed+=1
	else: failed+=1
func definition(id: String) -> UnitDefinition: return load("res://features/units/data/monsters/"+id+".tres") as UnitDefinition
func capture(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name_text+".png")
func fixture(point: Vector2, flying: bool=false) -> TacticalUnit:
	var data: UnitDefinition=definition("beast").duplicate(true)
	data.max_health=1000000; data.defense=0; data.magic_resistance=0; data.armor=0; data.evasion=0
	data.movement_type=UnitDefinition.Movement.AIR if flying else UnitDefinition.Movement.GROUND
	return game.spawn_unit(data,0,point,false)
func clear_lane() -> Vector2:
	for y: int in range(4,game.ground.cells.y-4):
		for x: int in range(4,game.ground.cells.x-14):
			var free: bool=true
			for offset: int in 12:
				if game.ground._navigation_blocked(Vector2i(x+offset,y)): free=false; break
			if free: return (Vector2(x,y)+Vector2.ONE*0.5)*Iso.CELL
	return Vector2.ZERO
func charge_for(effect: BattleSkillEffect) -> void:
	for frame: int in 100:
		if effect.done: break
		await get_tree().physics_frame
		effect.tick(1.0/60.0)
func run() -> void:
	LegacyPartyFixture.install()
	DirAccess.make_dir_recursive_absolute(OUT)
	check(not PartyProgress.persistence_enabled,"isolated progress")
	var progress: Dictionary=PartyProgress.serialize()
	WorldCatalog.initialize()
	var map: WorldMapDefinition=WorldCatalog.definitions.millennium_lake
	check(map.content_version==3 and map.habitats.size()==10,"lake has10 native regions and revision3")
	check(WorldValidator.validate(map,WorldCatalog.definitions).is_empty(),"native lake configuration validates")
	var context: WorldContext=WorldContext.new(); context.initialize(progress,12345,true); context.ensure_map(map.map_id)
	var runtime: Dictionary=context.state.maps.millennium_lake
	check(runtime.parties.size()==40 and runtime.slots.size()==40,"all40 authored parties actually spawn")
	var legal: bool=true; var levels: bool=true; var guardian_party: Dictionary
	var counts: Dictionary={"millennium_worm":0,"millennium_bird":0,"millennium_wolf":0,"lake_guardian":0}
	for party: Dictionary in runtime.parties.values():
		var habitat: WorldHabitat=map.habitat(party.habitat_id)
		legal=legal and context.navigation.segment_legal(map.map_id,party.habitat_id,"SPAWN",party.home,party.home,habitat.profile.radius)
		for member: Dictionary in party.deployed_units:
			if member.definition_id=="millennium_worm": levels=levels and member.level>=30 and member.level<=70
			elif member.definition_id=="millennium_bird": levels=levels and member.level>=40 and member.level<=60
			elif member.definition_id=="millennium_wolf": levels=levels and member.level>=50 and member.level<=80
			elif member.definition_id=="lake_guardian": levels=levels and member.level==50; guardian_party=party
		var kind: String=party.deployed_units[0].definition_id
		if counts.has(kind): counts[kind]+=1
	check(legal,"all40 spawn/home points legal with radius and holes")
	check(levels,"all requested monster level ranges respected")
	check(counts.millennium_worm==15 and counts.millennium_bird==12 and counts.millennium_wolf==12 and counts.lake_guardian==1,"species population distribution correct")
	var route: Dictionary=context.navigation.find_path(map.map_id,"","PLAYER",map.entries.entrance.point,guardian_party.position,16)
	check(route.ok,"central boss reachable from actual entrance across existing bridges")
	for id: String in ["millennium_worm","millennium_bird","millennium_wolf","millennium_lord"]:
		var data: UnitDefinition=definition(id); var texture: Texture2D=load(data.sprite_path)
		check(data.sprite_layout.valid_for(texture.get_size()) and data.portrait_texture!=null,id+" native48-frame art and portrait")
	# Simulate the old added guardian region; discard only the explicitly retired parties.
	var old: Dictionary=context.snapshot()
	for slot_id: String in old.maps.millennium_lake.slots.keys():
		var slot: Dictionary=old.maps.millennium_lake.slots[slot_id]
		if slot.habitat_id.begins_with("lake_worm_") or slot.habitat_id.begins_with("lake_bird_") or slot.habitat_id.begins_with("lake_wolf_"):
			old.maps.millennium_lake.parties.erase(slot.party_id); old.maps.millennium_lake.slots.erase(slot_id)
	old.maps.millennium_lake.definition_version=1
	var retired: WorldHabitat=map.retired_habitats[0]
	var cells: Dictionary=context.navigation._cache(map.map_id,retired.habitat_id,"SPAWN",retired.profile.radius)
	var random: RandomNumberGenerator=RandomNumberGenerator.new(); random.seed=123
	var retired_ids: Array[String]=[]
	for index: int in 10:
		var party: Dictionary=PartyBuilder.build(retired.profile.templates[0],random,context.allocate)
		var point: Vector2=cells.grid.get_point_position(cells.cells[index%cells.cells.size()])
		var slot_id: String=map.map_id+"/"+retired.habitat_id+"/"+str(index)
		party.merge({"map_id":map.map_id,"habitat_id":retired.habitat_id,"slot_id":slot_id,"position":point,"home":point,"life_state":"ACTIVE","movement_state":"IDLE","encounter_id":"","path":PackedVector2Array(),"think_due_ms":200,"chase_until_ms":0})
		old.maps.millennium_lake.parties[party.party_id]=party
		old.maps.millennium_lake.slots[slot_id]={"slot_id":slot_id,"habitat_id":retired.habitat_id,"state":"OCCUPIED","party_id":party.party_id,"generation_index":1,"respawn_due_ms":0,"pending_party":{}}
		retired_ids.append(party.party_id)
	old.id_counter=context.state.id_counter
	var guardian_id: String=guardian_party.party_id
	var member_id: String=guardian_party.deployed_units[0].unit_id
	old.maps.millennium_lake.parties[guardian_id].deployed_units[0].level=6
	old.maps.millennium_lake.parties[guardian_id].deployed_units[0].resolved_stats.health=240
	var river: Dictionary=old.maps.river_bay.duplicate(true)
	context.publish(old); context.state.active_encounter={"encounter_id":"locked"}
	context.ensure_map(map.map_id)
	check(context.state.maps.millennium_lake.definition_version==1 and context.state.maps.millennium_lake.parties.size()==11,"migration defers while encounter locked")
	context.state.active_encounter={}; context.ensure_map(map.map_id)
	check(context.state.maps.millennium_lake.parties.size()==40,"old save removes10 duplicates and gains39 new parties")
	check(context.state.maps.millennium_lake.parties[guardian_id].deployed_units[0].unit_id==member_id and context.state.maps.millennium_lake.parties[guardian_id].deployed_units[0].level==50,"old guardian upgraded preserving persistent IDs")
	check(retired_ids.all(func(id: String)->bool: return not context.state.maps.millennium_lake.parties.has(id)) and context.state.maps.river_bay==river and context.state.progress==progress,"migration only removes retired parties preserving other maps and progress")
	context.state.player.map_id=map.map_id; context.state.player.position=map.entries.entrance.point
	context.state.player.protected_until_ms=9999999
	for tick: int in 80: context.tick(0.1)
	legal=true
	for party: Dictionary in context.state.maps.millennium_lake.parties.values():
		legal=legal and context.navigation.segment_legal(map.map_id,party.habitat_id,"CHASE",party.position,party.position,map.habitat(party.habitat_id).profile.radius)
	check(legal,"world AI remains in legal pursuit areas after movement")
	game=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false); game.cinematic_camera=false
	WorldSession.context.ensure_map(map.map_id)
	WorldSession.context.state.player.map_id=map.map_id; WorldSession.context.state.player.position=map.entries.entrance.point
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.camera.zoom=Vector2.ONE*0.32; game.camera.position=Iso.project(map.extent*0.5); game.camera.force_update_scroll()
	await capture("lake-population")
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	game.set_physics_process(false); game.camera.zoom=Vector2.ONE
	var start: Vector2=clear_lane(); check(start!=Vector2.ZERO,"fixture has actual walkable charge lane")
	var target: TacticalUnit=fixture(start+Vector2(250,0))
	var nearby: TacticalUnit=fixture(target.position+Vector2(0,35))
	var air: TacticalUnit=fixture(target.position,true)
	var worm: TacticalUnit=game.spawn_unit(definition("millennium_worm"),1,start+Vector2(0,150),false)
	worm.definition=worm.definition.duplicate(true); worm.definition.level=50
	worm._refresh_stats()
	worm.definition.skills.assign(worm.definition.skills.map(func(s: SkillDefinition)->SkillDefinition: return s.duplicate(true)))
	worm.definition.skills[0].proc_chance=1.0; worm.vitals.health=worm.vitals.max_health-100
	worm.abilities.on_basic_damage_landed(40,target)
	worm.abilities.on_basic_damage_landed(40,target)
	worm.abilities.on_basic_damage_landed(40,target)
	var group: Array=worm.abilities.active_summon_groups.get(&"lake_worm_split",[])
	check(group.size()==2,"attack-hit splits capped at2")
	check(is_equal_approx(worm.vitals.health,worm.vitals.max_health-70),"three actual hits steal25percent")
	for id: int in group:
		var clone: TacticalUnit=game.get_unit(id)
		check(clone.is_summon and clone.definition.level==50 and clone.definition.experience_reward==0 and clone.definition.skills.size()==1,"clone inherits level without recursive splitting or rewards")
	var bird: TacticalUnit=game.spawn_unit(definition("millennium_bird"),1,start+Vector2(0,-120),false)
	check(bird.definition.movement_type==UnitDefinition.Movement.AIR and bird.definition.attack_range==360,"bird flight and ranged attack")
	var hp: float=target.vitals.health; var nearby_hp: float=nearby.vitals.health
	bird.abilities.on_basic_damage_landed(50,target)
	var fire: BattleSkillEffect=game.effects.back()
	check(fire.data.kind==SkillEffectDefinition.Kind.FLAME and target.vitals.health<hp and nearby.vitals.health<nearby_hp,"bird hits trigger real AoE flame")
	fire.tick(1.6); check(fire.ticks==4,"bird flame has4 timed damage pulses")
	var wolf: TacticalUnit=game.spawn_unit(definition("millennium_wolf"),1,start,false)
	hp=target.vitals.health; var air_hp: float=air.vitals.health
	game.resolve_skill(wolf,wolf.definition.skills[0],target.position,target.unit_id)
	var dash: BattleSkillEffect=game.effects.back(); await charge_for(dash)
	check(wolf.position.distance_to(start)>200 and dash.hit_counts.get(target.unit_id,0)==1 and target.vitals.health<hp,"wolf physically charges and hits once")
	check(air.vitals.health==air_hp,"ground wolf charge excludes flying target")
	var wall: Vector2i=Vector2i((start+Vector2(160,0))/Iso.CELL)
	game.ground.add_wall(88444,[wall+Vector2i(0,-1),wall,wall+Vector2i(0,1)])
	wolf.position=start; hp=target.vitals.health
	game.resolve_skill(wolf,wolf.definition.skills[0],target.position,target.unit_id)
	dash=game.effects.back(); await charge_for(dash)
	check(wolf.position.x<start.x+160 and target.vitals.health==hp,"ice wall stops ground charge without damage behind it")
	var lord: TacticalUnit=game.spawn_unit(definition("millennium_lord"),1,start,false)
	hp=target.vitals.health; lord.vitals.health-=1000; var lord_hp: float=lord.vitals.health
	game.resolve_skill(lord,lord.definition.skills[0],target.position,target.unit_id)
	var sky: BattleSkillEffect=game.effects.back(); await charge_for(sky)
	check(lord.position.x>start.x+200 and target.vitals.health<hp,"flying boss true charge passes ground wall")
	check(lord.vitals.health>lord_hp,"boss steals life from charge damage")
	game.ground.remove_wall(88444)
	var guardian: TacticalUnit=game.spawn_unit(definition("lake_guardian"),1,start+Vector2(100,100),false)
	guardian.persistent_unit_id="evolution_fixture"; var battle_id: int=guardian.unit_id
	guardian.died.connect(func(_id: int)->void: deaths+=1)
	game.apply_damage(guardian,999999,false,CombatMath.Kind.MAGIC)
	check(guardian.alive() and guardian.definition.id==&"millennium_lord" and guardian.definition.level==99,"guardian lethal hit evolves to live Lv99 boss")
	check(guardian.unit_id==battle_id and guardian.persistent_unit_id=="evolution_fixture" and deaths==0,"evolution preserves identity without death event")
	check(guardian.definition.movement_type==UnitDefinition.Movement.AIR and guardian.collision_mask==0,"evolution uses actual air movement and collision")
	for enemy: TacticalUnit in game.units.values():
		if enemy.team==1 and enemy!=guardian: enemy.vitals.health=0
	game._physics_process(0.01)
	check(game.mode==&"battle" and game.living_ids(1)==[battle_id],"first form death cannot cause premature victory")
	game.camera.position=Iso.project(guardian.position)+Vector2(120,0); game.camera.force_update_scroll()
	await capture("evolved-flying-boss")
	game.apply_damage(guardian,999999,false,CombatMath.Kind.MAGIC)
	game.apply_damage(guardian,999999,false,CombatMath.Kind.MAGIC)
	check(not guardian.alive() and deaths==1 and game.battle_experience==6000,"only final death counted once with6000 total reward")
	# Real world receipt derives reward from the fixed guardian snapshot, not evolved extra units.
	var settlement: WorldContext=WorldContext.new(); settlement.initialize(progress,789,true); settlement.ensure_map(map.map_id)
	var boss_party: Dictionary
	for p: Dictionary in settlement.state.maps.millennium_lake.parties.values():
		if p.deployed_units[0].definition_id=="lake_guardian": boss_party=p; break
	settlement.state.player.map_id=map.map_id; settlement.state.player.position=boss_party.position
	settlement.state.player.protected_until_ms=0; settlement.state.player.cooldown_until_ms=0
	var entered: Dictionary=settlement.encounters.try_begin("player",boss_party.party_id,"player")
	check(entered.ok,"actual guardian world party starts encounter")
	if entered.ok:
		var session: Dictionary=settlement.state.active_encounter; session.state="LOADING"; settlement.encounters.mark_in_battle(session.encounter_id)
		var result: Dictionary={"encounter_id":session.encounter_id,"outcome":"victory","player_unit_results":[],"defeated_enemy_unit_ids":[boss_party.deployed_units[0].unit_id],"consumed_items":[]}
		for member: Dictionary in session.player_party_snapshot.deployed_units: result.player_unit_results.append({"unit_id":member.unit_id,"hp":50.0,"mp":10.0})
		var committed: Dictionary=settlement.settlement.apply(result)
		check(committed.ok and settlement.state.applied_results[session.encounter_id].experience==6000,"world settles two-stage reward6000 once")
		var settled: Dictionary=settlement.state.progress.duplicate(true); settlement.settlement.apply(result)
		check(settlement.state.progress==settled,"repeated boss callback never duplicates rewards")
	# Drive the actual lake scene + persistent encounter, including the real finish_battle path.
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	var real_context: WorldContext=WorldSession.context
	var real_party: Dictionary
	for p: Dictionary in real_context.state.maps.millennium_lake.parties.values():
		if p.deployed_units[0].definition_id=="lake_guardian": real_party=p; break
	real_context.state.player.map_id=map.map_id; real_context.state.player.position=real_party.position
	real_context.state.player.protected_until_ms=0; real_context.state.player.cooldown_until_ms=0
	var real_entry: Dictionary=real_context.encounters.try_begin("player",real_party.party_id,"player")
	check(real_entry.ok,"formal lake encounter reserves central guardian")
	if real_entry.ok:
		var ticket: String=real_context.state.active_encounter.encounter_id
		real_context.state.active_encounter.state="LOADING"
		game._encounter_battle(real_context.state.active_encounter.duplicate(true))
		while game.mode!=&"battle": await get_tree().process_frame
		game.set_physics_process(false)
		var central: TacticalUnit
		for enemy: TacticalUnit in game.units.values():
			if enemy.team==1: central=enemy; break
		check(game.ground.battle_id=="millennium_lake" and central.definition.level==50,"formal encounter uses authored lake scene and Lv50")
		game.apply_damage(central,999999,false,CombatMath.Kind.MAGIC)
		check(central.alive() and central.definition.level==99 and central.persistent_unit_id==real_party.deployed_units[0].unit_id,"formal guardian evolves retaining snapshot identity")
		game.camera.position=Iso.project(central.position)+Vector2(120,0); game.camera.force_update_scroll()
		await capture("actual-lake-boss")
		game.apply_damage(central,999999,false,CombatMath.Kind.MAGIC); game._physics_process(0.01)
		check(game.mode==&"battle" and game.victory_pending and not real_context.state.applied_results.has(ticket),"formal victory waits for operable cleanup before reward")
		for frame: int in 122: game._physics_process(1.0/60.0)
		check(game.mode==&"results" and real_context.state.applied_results[ticket].experience==6000,"real terminal result settles one boss reward")
		var paid: Dictionary=real_context.state.progress.duplicate(true)
		real_context.settlement.apply(game.settlement_result)
		check(real_context.state.progress==paid,"real encounter repeated result remains idempotent")
	var report: Dictionary={"passed":passed,"failed":failed,"tests":checks,"rendered":DisplayServer.get_name()!="headless"}
	var file: FileAccess=FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "render.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MILLENNIUM_ECOLOGY_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failed==0 else 1)
