extends Node
var passed: int=0
var failed: int=0
var observations: Array[Dictionary]=[]
var game: GameDirector
const OUT: String="res://artifacts/roster-effects-polish-2026-10-11/"
func _ready() -> void:
	get_tree().create_timer(100).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	observations.append({"test":label,"pass":ok})
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func ability(id: String) -> SkillDefinition: return load("res://features/skills/data/"+id+".tres") as SkillDefinition
func capture(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name_text+".png")
func fixture(at: Vector2, flying: bool=false) -> TacticalUnit:
	var data: UnitDefinition=load("res://features/units/data/monsters/beast.tres").duplicate(true)
	data.max_health=1000000; data.defense=0; data.armor=0; data.magic_resistance=0; data.evasion=0
	data.movement_type=UnitDefinition.Movement.AIR if flying else UnitDefinition.Movement.GROUND
	return game.spawn_unit(data,1,at,false)
func run() -> void:
	LegacyPartyFixture.install()
	DirAccess.make_dir_recursive_absolute(OUT)
	check(not PartyProgress.persistence_enabled,"isolated progress only")
	var original: Dictionary=PartyProgress.serialize()
	check(MercenaryRoster.deposit(original,0).is_empty(),"main cannot be deposited")
	check(MercenaryRoster.withdraw(original,"missing").is_empty(),"full party cannot withdraw")
	game=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	var panel: ItemDebugPanel=game.hud.item_debug
	panel.toggle(); panel.tabs.current_tab=1
	var storage: MercenaryStoragePanel=panel.storage
	var old: Dictionary=PartyProgress.records[1].serialize()
	storage.slots.select(0); storage.deposit_button.pressed.emit()
	check(PartyProgress.records.size()==6 and PartyProgress.reserves.size()==1,"F2 deposit without replacement")
	check(PartyProgress.reserves[0].serialize()==old,"deposit preserves full record")
	check(WorldSession.context.state.player_party.deployed_units.size()==6,"world snapshot follows smaller party")
	storage.reserves.select(0); storage.withdraw_button.pressed.emit()
	check(PartyProgress.records.size()==7 and PartyProgress.reserves.is_empty(),"F2 withdraw without swap")
	check(PartyProgress.records.back().serialize()==old,"withdraw keeps persistent identity and gear")
	for i: int in 6:
		storage.slots.select(0); storage.deposit_button.pressed.emit()
	check(PartyProgress.records.size()==1 and PartyProgress.reserves.size()==6,"all six mercenaries can be stored")
	check(storage.deposit_button.disabled and storage.exchange_button.disabled,"main-only controls show no deposit or swap")
	var small: Dictionary=PartyProgress.serialize()
	check(PartyProgress.restore(small) and PartyProgress.serialize()==small,"main-only schema roundtrip")
	game.hud.progression.show_inventory(); game.hud.progression.refresh(0)
	check(game.hud.progression.roster_buttons[0].visible and not game.hud.progression.roster_buttons[1].visible,"dossier hides empty roster positions")
	game.hud.close_windows(); panel.toggle(); panel.tabs.current_tab=1
	var ninja_fixture: CharacterRecord=CharacterRecord.new(); ninja_fixture.initialize(load("res://features/units/data/mercenaries/ninja.tres"),"fixture_ninja",false); PartyProgress.reserves.append(ninja_fixture); storage.refresh()
	storage.reserves.select(6); storage.withdraw_button.pressed.emit()
	var kohime_fixture: CharacterRecord=CharacterRecord.new(); kohime_fixture.initialize(load("res://features/units/data/mercenaries/kohime.tres"),"fixture_kohime",false); PartyProgress.reserves.append(kohime_fixture); storage.refresh()
	storage.reserves.select(6); storage.withdraw_button.pressed.emit()
	check(PartyProgress.records.size()==3 and PartyProgress.records[1].definition.id==&"ninja" and PartyProgress.records[2].definition.id==&"kohime","new classes independently taken out Lv1")
	check(PartyProgress.records[1].level()==1 and PartyProgress.records[2].level()==1,"withdraw never grants XP")
	var context: WorldContext=WorldSession.context
	context.save.enabled=true; context.save.path="user://roster_polish_%d.dat"%OS.get_process_id(); context.save.fail_writes=1
	var before: Dictionary=context.snapshot()
	check(not WorldSession.change_mercenary_roster("deposit","",1).ok and context.snapshot()==before,"failed deposit publishes nothing")
	check(WorldSession.change_mercenary_roster("deposit","",1).ok,"same deposit can retry")
	var stored: Dictionary=context.save.load_best()
	check(stored.progress.party.size()==2 and stored.player_party.deployed_units.size()==2,"disk includes reduced roster and coherent snapshot")
	check(PartyProgress.restore(stored.progress),"variable-party save restores")
	context.save.enabled=false
	check(WorldSession.change_mercenary_roster("withdraw",small.party[0].id).ok==false,"warehouse lookup cannot take out deployed main")
	var ninja_id: String=PartyProgress.reserves.back().persistent_id
	check(WorldSession.change_mercenary_roster("withdraw",ninja_id).ok,"stored ninja taken out after disk restore")
	storage.refresh(); await capture("warehouse-three-active")
	var encounter: WorldContext=WorldContext.new(); encounter.initialize(PartyProgress.serialize(),4242,true)
	var monster: Dictionary=encounter.state.maps.river_bay.parties.values()[0]
	encounter.state.player.position=monster.position+Vector2(5,0)
	encounter.state.player.protected_until_ms=0; encounter.state.player.cooldown_until_ms=0
	var entered: Dictionary=encounter.encounters.try_begin("player",monster.party_id,"player")
	check(entered.ok and encounter.state.active_encounter.player_party_snapshot.deployed_units.size()==3,"real encounter snapshot has actual three members")
	if entered.ok:
		var session: Dictionary=encounter.state.active_encounter
		session.state="LOADING"; encounter.encounters.mark_in_battle(session.encounter_id)
		var result: Dictionary={"encounter_id":session.encounter_id,"outcome":"victory","player_unit_results":[],"defeated_enemy_unit_ids":[],"consumed_items":[]}
		for member: Dictionary in session.player_party_snapshot.deployed_units: result.player_unit_results.append({"unit_id":member.unit_id,"hp":50.0,"mp":20.0})
		for enemy: Dictionary in session.enemy_party_snapshots:
			for member: Dictionary in enemy.deployed_units: result.defeated_enemy_unit_ids.append(member.unit_id)
		var reserve_before: Array=encounter.state.progress.reserve.duplicate(true)
		check(encounter.settlement.apply(result).ok and encounter.state.progress.party.size()==3,"three-member victory settles correctly")
		check(encounter.state.progress.reserve==reserve_before,"stored six remain untouched by victory")
	panel.hide()
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	game.set_physics_process(false)
	check(game.living_ids(0).size()==3,"practice battle spawns only actual three active members")
	check(game.roster_ids.size()==3,"battle roster follows actual active count")
	var kohime: TacticalUnit
	var ninja: TacticalUnit
	for actor: TacticalUnit in game.units.values():
		if actor.definition.id==&"kohime": kohime=actor
		if actor.definition.id==&"ninja": ninja=actor
	var center: Vector2=game._safe_spawn(Vector2(700,650))
	kohime.position=center; ninja.position=center+Vector2(-150,0)
	game.camera.position=Iso.project(center)+Vector2(120,-70); game.camera.force_update_scroll(); game.cinematic_camera=false
	game.resolve_skill(kohime,ability("earth_claw"),game._safe_spawn(center+Vector2(100,0)),-1)
	var claw: TacticalUnit=game.get_unit(int(kohime.abilities.active_summons[&"earth_claw"]))
	check(claw.definition.visual_scale==1.8 and claw.view.sprite.scale.x>kohime.view.sprite.scale.x*1.5,"claw visibly larger with foot anchor")
	check(not claw.definition.controllable and claw.definition.random_nearby_target,"large claw keeps autonomous policy")
	check(claw.definition.sprite_layout.attack_columns==[3,4,0],"claw lift stab recover animation")
	var target: TacticalUnit=fixture(claw.position+Vector2(50,0))
	var nearby: TacticalUnit=fixture(target.position+Vector2(25,0))
	var air: TacticalUnit=fixture(target.position+Vector2(10,0),true)
	var hp: float=target.vitals.health; var next_hp: float=nearby.vitals.health; var air_hp: float=air.vitals.health
	var expected: float=float(claw.available_skills()[0].result(claw.stats_snapshot()).value)
	game.basic_attack(claw,target,0)
	check(is_equal_approx(hp-target.vitals.health,expected) and is_equal_approx(next_hp-nearby.vitals.health,expected),"claw strike wisdom AoE once only")
	check(air.vitals.health==air_hp,"spikes do not hit air")
	var burst: AdvancedSkillVisual
	for child: Node in game.render_root.get_children():
		if child is AdvancedSkillVisual and child.kind==SkillEffectDefinition.Kind.STAKES: burst=child
	check(burst!=null and burst.stakes.size()>1 and burst.stakes[0].texture.resource_path==ability("earth_stakes").effect_data.sprite_path,"claw emits actual first-skill spike art")
	if burst!=null: burst.age=0.25; burst.update_stakes()
	claw.attack_windup_left=0.2; claw.view._process(0)
	await capture("claw-stab")
	game.resolve_skill(ninja,ability("ninja_fire_trail"),ninja.position,-1)
	var trail: BattleSkillEffect=game.effects.back()
	for i: int in 5:
		ninja.position+=Vector2(36,0); trail.tick(0.1)
	check(trail.advanced.visual.flames.size()==6,"fire trail uses pooled animated sprites")
	check(trail.advanced.visual.flames[0].texture.resource_path.ends_with("fire-trail-v2.png"),"real flame bitmap used")
	check(trail.advanced.visual.flames[0].position==Iso.project(trail.advanced.trail[0].point),"fire foot remains projected at trail position")
	await capture("ninja-fire-trail")
	trail.tick(3.0)
	check(trail.advanced.trail.is_empty() and trail.advanced.visual.flames.is_empty(),"old flames expire without orphan sprites")
	var mage: TacticalUnit=game.spawn_unit(load("res://features/units/data/mercenaries/mage.tres"),0,center+Vector2(-200,150),false)
	var lightning: SkillDefinition=ability("lightning")
	hp=target.vitals.health
	game.resolve_skill(mage,lightning,target.position,-1)
	check(target.vitals.health<hp,"lightning still damages instantly")
	var bolt: SkillVfx
	for child: Node in game.render_root.get_children():
		if child is SkillVfx and child.sprite!=null and child.sprite.texture.resource_path.ends_with("lightning-v2.png"): bolt=child
	check(bolt!=null and bolt.position==Iso.project(target.position),"lightning textured strike at target")
	if bolt!=null: bolt.age=0.24; bolt._process(0)
	await capture("lightning-strike")
	var dragon: SkillDefinition=ability("dragon")
	var far: Vector2=mage.position+Vector2(850,0)
	var far_target: TacticalUnit=fixture(far)
	game.selection.select_ids([mage.unit_id])
	check(game.selection.activate_skill(dragon.id),"R direction targeting can be armed")
	check(game.selection.confirm_skill(far),"fire dragon accepts far left confirmation")
	var mage_position: Vector2=mage.position
	mage.tick(1.0/60.0)
	var wave: BattleSkillEffect=game.effects.back()
	check(mage.position==mage_position and wave.skill.id==&"dragon","far fire dragon casts without approaching")
	check(wave.data.distance>850 and wave.data.distance>=Vector2(game.ground.cells).length()*Iso.CELL,"wave traverses scene diagonal")
	check(dragon.effect_data.distance==480 and dragon.effect_data.duration==2,"shared dragon Resource not mutated")
	hp=far_target.vitals.health
	wave.tick(900.0/wave.data.speed)
	check(far_target.vitals.health<hp,"wave hits beyond former 480 distance")
	check(SkillDescription.describe(dragon,mage.stats_snapshot(),"測試",dragon.result(mage.stats_snapshot())).contains("全戰場"),"tooltip communicates full battlefield")
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	check(game.hud.world_hud.roster_buttons[2].visible and not game.hud.world_hud.roster_buttons[3].visible,"return world roster follows active count")
	var report: Dictionary={"passed":passed,"failed":failed,"tests":observations,"rendered":DisplayServer.get_name()!="headless"}
	var file: FileAccess=FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "render.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ROSTER_EFFECTS_POLISH_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failed==0 else 1)
