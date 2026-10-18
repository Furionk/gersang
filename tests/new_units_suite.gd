extends Node
var passed: int=0
var failed: int=0
var game: GameDirector
var observations: Array[Dictionary]=[]
var baseline: Dictionary
func _ready() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	observations.append({"test":label,"pass":ok})
	if ok: passed+=1
	else: failed+=1
func ability(id: String) -> SkillDefinition: return load("res://features/skills/data/"+id+".tres") as SkillDefinition
func fixture(at: Vector2, flying: bool=false) -> TacticalUnit:
	var data: UnitDefinition=UnitDefinition.new()
	data.id=&"fixture"; data.display_name="Isolated target"; data.max_health=1000000; data.max_mana=0
	data.magic_resistance=0; data.defense=0; data.armor=0; data.evasion=0
	data.sprite_path="res://features/units/art/earth_claw.png"
	data.sprite_layout=load("res://features/units/data/layouts/earth_claw_layout.tres")
	data.movement_type=UnitDefinition.Movement.AIR if flying else UnitDefinition.Movement.GROUND
	return game.spawn_unit(data,1,at,false)
func cast(caster: TacticalUnit, id: String, point: Vector2, target: int=-1) -> BattleSkillEffect:
	game.resolve_skill(caster,ability(id),point,target)
	return game.effects.back()
func clear_effects() -> void:
	for effect: BattleSkillEffect in game.effects: effect.finish()
	game.effects.clear()
func capture(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/new-units-2026-10-11/"+name_text+".png")
func run() -> void:
	LegacyPartyFixture.install()
	check(not PartyProgress.persistence_enabled,"test cannot write real progress")
	baseline=PartyProgress.serialize().duplicate(true)
	check(Catalog.party().size()==7,"permanent party stays seven")
	for id: String in ["kohime","ninja","teppo","earth_claw"]:
		var folder: String="summons" if id=="earth_claw" else "mercenaries"
		var definition: UnitDefinition=load("res://features/units/data/"+folder+"/"+id+".tres")
		var texture: Texture2D=load(definition.sprite_path)
		check(definition.sprite_layout.valid_for(texture.get_size()),id+" complete authored 48-frame layout")
		check(definition.portrait_texture!=null and CharacterArt.texture(definition,"portrait")==definition.portrait_texture,id+" uses own portrait not merchant")
		check(texture.get_image().detect_alpha()!=Image.ALPHA_NONE,id+" actual transparent bitmap")
		var animations: SpriteFrames=SpriteAtlas.frames(texture,definition.sprite_layout)
		check(animations.has_animation(&"walk_5") and animations.get_frame_count(&"walk_5")==definition.sprite_layout.columns_for("walk").size() and animations.get_frame_count(&"walk_5")>=2,id+" eight-direction authored walking animation")
		var a: Rect2i=definition.sprite_layout.frame_rects[1]
		var b: Rect2i=definition.sprite_layout.frame_rects[2]
		check(texture.get_image().get_region(a).get_data()!=texture.get_image().get_region(b).get_data(),id+" distinct walk phases")
	for id: String in ["earth_stakes","earth_claw","ninja_stealth","ninja_fire_trail","ninja_chain","teppo_sniper","teppo_comrades","teppo_triple","claw_strike"]:
		check(ability(id).cooldown==0,id+" cooldown zero")
	game=load("res://main.tscn").instantiate(); add_child(game)
	var deadline: int=Time.get_ticks_msec()+15000
	while game.mode!=&"world" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	check(not game.debug_trial_unit("kohime").ok,"Debug refuses world mutation")
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	check(game.mode==&"battle","real native battlefield started")
	if game.mode!=&"battle": get_tree().quit(1); return
	game.set_physics_process(false)
	var count_before: int=game.units.size()
	var trial_button: Button=game.hud.item_debug.find_child("Trial_kohime",true,false)
	trial_button.pressed.emit()
	check(game.units.size()==count_before+1,"real F2 button signal reaches trial implementation")
	var trials: Dictionary={}
	for id: String in Catalog.NEW_UNIT_IDS:
		var result: Dictionary=game.debug_trial_unit(id)
		check(result.ok,id+" F2 Debug trial creates real tactical unit")
		trials[id]=game.get_unit(result.unit_id)
		check(result.unit_id in game.selection.selected_ids,id+" Debug trial is selected")
		check(trials[id].permanent_slot==-1 and trials[id].is_summon,id+" excluded from save and permanent rewards")
		for skill: SkillDefinition in trials[id].available_skills(): check(InputMap.has_action(skill.action) and GameSettings.bindings[str(skill.action)]==skill.default_key,str(skill.id)+" Resource hotkey registered")
	var kohime: TacticalUnit=trials.kohime
	var ninja: TacticalUnit=trials.ninja
	var teppo: TacticalUnit=trials.teppo
	check(PartyProgress.serialize()==baseline,"Debug does not change seven-party progression")
	var point: Vector2=kohime.position+Vector2(80,0)
	var ground_enemy: TacticalUnit=fixture(point)
	var air_enemy: TacticalUnit=fixture(ground_enemy.position,true)
	var before: float=ground_enemy.vitals.health
	var air_before: float=air_enemy.vitals.health
	var stake: BattleSkillEffect=cast(kohime,"earth_stakes",ground_enemy.position)
	var power: float=float(ability("earth_stakes").result(kohime.stats_snapshot()).value)
	for i: int in 20: stake.tick(0.5)
	check(stake.done and stake.ticks==20,"stakes 10 seconds exactly 20 half-second ticks")
	check(is_equal_approx(before-ground_enemy.vitals.health,power*20),"stakes authoritative wisdom damage")
	check(air_enemy.vitals.health==air_before,"stakes ignores air targets")
	clear_effects()
	for fps: int in [30,120]:
		before=ground_enemy.vitals.health
		var timed: BattleSkillEffect=cast(kohime,"earth_stakes",ground_enemy.position)
		for frame: int in fps*10: timed.tick(1.0/float(fps))
		check(timed.ticks==20 and is_equal_approx(before-ground_enemy.vitals.health,power*20),"stakes identical damage at "+str(fps)+" FPS")
		clear_effects()
	var claw_effect: BattleSkillEffect=cast(kohime,"earth_claw",kohime.position)
	var claw_id: int=int(kohime.abilities.active_summons[&"earth_claw"])
	var claw: TacticalUnit=game.get_unit(claw_id)
	check(not claw.definition.controllable and claw.definition.random_nearby_target,"earth claw autonomous policy")
	check(is_equal_approx(claw.definition.intelligence,kohime.stats_snapshot().intelligence),"claw stores caster wisdom at release")
	var wisdom: float=claw.definition.intelligence
	kohime.combat_stats.intelligence+=100
	check(claw.definition.intelligence==wisdom,"existing claw does not rescale after caster stat changes")
	kohime.combat_stats.intelligence-=100
	game.selection.select_ids([claw_id]); check(game.selection.selected_ids.is_empty(),"claw cannot be directly selected")
	game.selection.select_box(Rect2(Vector2(-100000,-100000),Vector2(200000,200000)))
	check(claw_id not in game.selection.selected_ids,"claw cannot be box-selected")
	claw.issue_command({"kind":"move","point":Vector2.ZERO}); check(claw.active.is_empty(),"claw rejects direct movement commands")
	before=ground_enemy.vitals.health; air_before=air_enemy.vitals.health
	game.basic_attack(claw,ground_enemy,99999)
	var claw_power: float=float(claw.available_skills()[0].result(claw.stats_snapshot()).value)
	check(is_equal_approx(before-ground_enemy.vitals.health,claw_power),"claw stab replaces basic damage with wisdom AoE")
	check(air_enemy.vitals.health==air_before,"claw stab excludes air targets")
	claw.enemy_scan_left=0; claw.think_left=0
	claw.tick(0.01)
	check(claw.locked_attack_id>=0,"autonomous claw actually chooses nearby enemy")
	clear_effects()
	cast(teppo,"teppo_comrades",teppo.position+Vector2(50,0))
	var group: Array=teppo.abilities.active_summon_groups[&"teppo_comrades"]
	check(group.size()==2,"teppo summons exactly two")
	var companion: TacticalUnit=game.get_unit(group[0])
	var expected: float=20+float(teppo.stats_snapshot().agility)*0.8+float(teppo.stats_snapshot().strength)*0.8
	check(is_equal_approx(companion.definition.damage,expected),"teppo summons scale agility and strength")
	game.selection.select_ids([group[0],group[1]])
	check(game.selection.selected_ids.size()==2,"both teppo companions controllable")
	check(not teppo.abilities.available(ability("teppo_comrades")),"living group prevents unlimited repeated summon")
	companion.vitals.damage_resolved(9999999); teppo.abilities.tick(0.01)
	check(teppo.abilities.available(ability("teppo_comrades")),"one lost companion permits refill")
	cast(teppo,"teppo_comrades",teppo.position)
	check(teppo.abilities.active_summon_groups[&"teppo_comrades"].size()==2,"refill retains survivor and respects limit two")
	clear_effects()
	var base_attack: float=teppo.stats_snapshot().attack
	var base_range: float=teppo.attack_range_now()
	var base_interval: float=teppo.attack_interval_now()
	cast(teppo,"teppo_sniper",teppo.position)
	check(is_equal_approx(teppo.attack_range_now(),base_range+180),"sniper modifies actual firing range")
	cast(teppo,"teppo_triple",teppo.position)
	check(is_equal_approx(teppo.stats_snapshot().attack,(base_attack+30)*3),"triple means plus 200 percent and stacks correctly with sniper")
	check(is_equal_approx(teppo.attack_interval_now(),base_interval/1.5),"triple attack speed plus 50 percent")
	teppo.attack_timer=0
	teppo._engage(fixture(teppo.position+Vector2(30,0)),0.01)
	check(is_equal_approx(teppo.attack_windup_left,GameSettings.profile.attack_windup/1.5),"triple scales attack windup as well as interval")
	teppo.attack_windup_left=-1; teppo._stop_motion()
	var time: float=float(ability("teppo_triple").effect_data.resolved_duration(teppo.stats_snapshot()).value)
	check(is_equal_approx(time,10+(teppo.stats_snapshot().agility+teppo.stats_snapshot().strength)*0.05),"triple duration agility strength formula")
	cast(teppo,"teppo_triple",teppo.position)
	check(is_equal_approx(teppo.stats_snapshot().attack,(base_attack+30)*3),"recasting triple refreshes without multiplicative accumulation")
	teppo.statuses.tick(time+0.1)
	check(is_equal_approx(teppo.stats_snapshot().attack,base_attack) and is_equal_approx(teppo.attack_range_now(),base_range) and is_equal_approx(teppo.attack_interval_now(),base_interval),"temporary buffs restore all derived values after expiry")
	clear_effects()
	cast(ninja,"ninja_stealth",ninja.position)
	check(ninja.statuses.hidden() and is_equal_approx(ninja.statuses.speed_multiplier(),1.2),"stealth enabled and speed bonus")
	check(game.validate_skill_target(ground_enemy,ability("ninja_chain"),ninja.position,ninja.unit_id)!="","enemy targeting refuses hidden unit")
	var reveal: float=ninja.statuses.reveal(true)
	check(is_equal_approx(reveal,90+ninja.stats_snapshot().agility*1.5) and not ninja.statuses.hidden(),"first attack consumes correct reveal bonus")
	check(ninja.statuses.reveal(true)==0,"reveal bonus cannot be reused")
	clear_effects()
	ninja.position=ground_enemy.position+Vector2(15,0) # Isolated overlap fixture, not a movement test.
	before=ground_enemy.vitals.health
	var trail_effect: BattleSkillEffect=cast(ninja,"ninja_fire_trail",ninja.position)
	check(ground_enemy.vitals.health<before,"fire trail applies actual damage to ground target")
	ninja.position+=Vector2(50,0); trail_effect.tick(0.5)
	check(trail_effect.advanced.trail.size()==2,"moving ninja leaves real spatial fire points")
	trail_effect.tick(0.5)
	check(trail_effect.advanced.trail.size()==2,"stationary ninja does not duplicate fire points")
	trail_effect.tick(3)
	check(trail_effect.advanced.trail.is_empty(),"old flame points expire")
	clear_effects()
	for offset: Vector2 in [Vector2(105,0),Vector2(0,110),Vector2(105,110)]: fixture(ground_enemy.position+offset)
	var chain: BattleSkillEffect=cast(ninja,"ninja_chain",ground_enemy.position,ground_enemy.unit_id)
	check(chain.hit_counts.size()==4,"chain jumps to four distinct nearby enemies")
	check(chain.hit_counts.size()<=4,"chain caps targets per pulse")
	for count: int in chain.hit_counts.values(): check(count==1,"chain never revisits enemy during one pulse")
	for i: int in 4: chain.tick(1.0)
	check(chain.ticks==4 and chain.done,"chain four fixed one-second pulses")
	clear_effects()
	game.camera.position=Iso.project(ground_enemy.position)
	game.camera.zoom=Vector2.ONE*0.9
	var picture: BattleSkillEffect=cast(kohime,"earth_stakes",ground_enemy.position)
	picture.tick(0.7)
	await capture("earth-stakes")
	clear_effects()
	game.selection.select_ids([ninja.unit_id])
	picture=cast(ninja,"ninja_chain",ground_enemy.position,ground_enemy.unit_id)
	picture.tick(0.05)
	await capture("chain-lightning")
	clear_effects()
	game.hud.item_debug.toggle()
	await capture("debug-new-units")
	game.hud.item_debug.hide()
	for id: String in Catalog.NEW_UNIT_IDS:
		var result: Dictionary=game.debug_trial_unit(id,true)
		check(result.ok,id+" Debug enemy version spawns")
		var enemy: TacticalUnit=game.get_unit(result.unit_id)
		enemy.definition=enemy.definition.duplicate(true) as UnitDefinition
		for ability_data: SkillDefinition in enemy.available_skills(): ability_data.ai_cast_chance=1.0
		enemy.position=teppo.position+Vector2(30,0)
		check(enemy._auto_enemy_skill(teppo),id+" enemy AI creates real cast command")
		enemy.tick(0.01)
		check(enemy.casts==1,id+" enemy AI actually releases configured skill")
	clear_effects()
	for kind: String in ["kohime","ninja","teppo","earth_claw"]:
		var enemy: UnitDefinition=load("res://features/units/data/monsters/"+kind+"_enemy.tres")
		check(enemy.skills.size()>0,kind+" enemy variant usable by native region Inspector")
	check(PartyProgress.serialize()==baseline,"full skill suite preserves formal party data")
	var file: FileAccess=FileAccess.open("res://artifacts/new-units-2026-10-11/"+("headless" if DisplayServer.get_name()=="headless" else "render")+"-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"observations":observations,"physical_mouse":"unverified"},"\t")); file.close()
	print("NEW_UNITS_SUITE_RESULT passed=",passed," failed=",failed)
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failed==0 else 1)
