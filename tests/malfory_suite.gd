extends Node
var game: GameDirector
var passed: int=0
var failed: int=0
var tests: Array[Dictionary]=[]
const OUT: String="res://artifacts/malfory-2026-10-11/"
func check(ok: bool,text: String) -> void:
	tests.append({"test":text,"pass":ok}); print("PASS | " if ok else "FAIL | ",text)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void:
	get_tree().create_timer(90).timeout.connect(func()->void:get_tree().quit(2))
	call_deferred("run")
func capture(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+name_text+".png")
func target(point: Vector2,hp: float=10000,air: bool=false) -> TacticalUnit:
	var data: UnitDefinition=load("res://features/units/data/monsters/beast.tres").duplicate(true)
	data.max_health=hp; data.magic_resistance=0; data.defense=0; data.evasion=0; data.damage=0
	data.movement_type=UnitDefinition.Movement.AIR if air else UnitDefinition.Movement.GROUND
	return game.spawn_unit(data,1,point,false)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	check(not PartyProgress.persistence_enabled,"isolated formal progress")
	check(not WorldSession.context.save.enabled,"world save writes disabled in isolated suite")
	var unit: UnitDefinition=load("res://features/units/data/mercenaries/malfory.tres")
	check(unit.level==1 and unit.id==&"malfory","Lv1 native unit")
	check(unit.sprite_layout.valid_for((load(unit.sprite_path) as Texture2D).get_size()),"48 native sprite regions valid")
	check(unit.portrait_texture.atlas==unit.standee_texture.atlas and unit.eyes_texture.atlas==unit.standee_texture.atlas,"one standee PNG shared by all UI crops")
	check(unit.skills[0].resource_path.ends_with("crucio.tres") and unit.skills[1].resource_path.ends_with("avada_kedavra.tres"),"skills use editable external Resources")
	check(Catalog.new_unit_ids().has("malfory") and MercenaryRoster.paths().has(unit.resource_path),"native catalog exposes recruitable Malfory")
	game=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	var before: Dictionary=PartyProgress.serialize().duplicate(true)
	var recruited: Dictionary=WorldSession.change_mercenary_roster("recruit",unit.resource_path)
	check(not recruited.ok and PartyProgress.records.size()==10,"fixed roster rejects duplicate recruitment")
	var recruit_id: String=PartyProgress.records[9].persistent_id
	check(PartyProgress.records[9].level()==25,"preset Malfory starts Lv25")
	var deposit: Dictionary=WorldSession.change_mercenary_roster("deposit","",9)
	var withdraw: Dictionary=WorldSession.change_mercenary_roster("withdraw",recruit_id)
	check(deposit.ok and withdraw.ok and PartyProgress.records.size()==10,"standalone deposit then withdraw Malfory")
	check(PartyProgress.records[1].persistent_id==before.party[1].id,"other mercenary unchanged")
	game.hud.progression.show_inventory(); PartyProgress.select_slot(9)
	await capture("dossier"); game.hud.close_windows()
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	game.set_physics_process(false); game.cinematic_camera=false
	var caster: TacticalUnit
	for actor: TacticalUnit in game.units.values():
		if actor.team==0 and actor.definition.id==unit.id: caster=actor
	check(caster!=null,"normal roster Malfory deploys in battle")
	var point: Vector2=game._safe_spawn(Vector2(750,650)); caster.position=point-Vector2(100,0)
	caster.combat_stats.intelligence=100; caster.vitals.mana=10000
	var enemy: TacticalUnit=target(point)
	var flying: TacticalUnit=target(point+Vector2(30,0),10000,true)
	var far: TacticalUnit=target(point+Vector2(500,0))
	var curse: SkillDefinition=unit.skills[0]
	game.resolve_skill(caster,curse,point,-1)
	var effect: BattleSkillEffect=game.effects.back()
	check(effect.data.duration==12 and effect.power==150,"wisdom100 gives12s curse and150 per tick")
	check(is_equal_approx(enemy.statuses.speed_multiplier(),0.65),"wisdom100 slows35 percent")
	check(enemy.vitals.health==9850 and flying.vitals.health==9850 and far.vitals.health==10000,"AoE hits air/ground enemies only within range")
	enemy.position=point+Vector2(600,0); caster.combat_stats.intelligence=200
	effect.tick(1)
	check(enemy.vitals.health==9700 and effect.power==150,"attached curse follows target outside area and retains release snapshot")
	effect.tick(11)
	check(effect.ticks==12 and enemy.vitals.health==8200 and effect.done,"12 pulses then ends without extra tick")
	enemy.statuses.tick(12)
	check(enemy.statuses.speed_multiplier()==1,"slow expires and restores movement")
	caster.combat_stats.intelligence=1000
	game.resolve_skill(caster,curse,point,-1)
	check(is_equal_approx(flying.statuses.speed_multiplier(),0.2),"slow cap80 percent")
	var burst: SkillDefinition=unit.skills[1]
	caster.combat_stats.intelligence=0; enemy.position=point; enemy.vitals.health=10000
	game.resolve_skill(caster,burst,point,-1)
	check(enemy.vitals.health==5000,"wisdom0 deals50 percent maximum HP")
	caster.combat_stats.intelligence=100; enemy.vitals.health=8000
	game.resolve_skill(caster,burst,point,-1)
	var death_burst: BattleSkillEffect=game.effects.back()
	check(not enemy.alive() and death_burst.hit_counts[enemy.unit_id]==1,"wisdom100 uses max not current HP and can kill")
	check(game.spell_flash.rect.visible and game.spell_flash.rect.mouse_filter==Control.MOUSE_FILTER_IGNORE,"brief green flash is nonblocking")
	death_burst.tick(0.2)
	game.camera.position=Iso.project(point); game.camera.force_update_scroll()
	await capture("green-skull-burst")
	await get_tree().create_timer(0.3).timeout
	check(not game.spell_flash.rect.visible,"flash ends automatically")
	var windup_target: TacticalUnit=target(point+Vector2(50,0))
	caster.vitals.mana=10000
	check(caster.abilities.request(burst,point,-1),"fresh targeted cast request accepted")
	caster.tick(0.01)
	check(caster.cast_left>0 and windup_target.vitals.health==10000,"0.5s windup does not hit early")
	caster.tick(0.49)
	check(windup_target.vitals.health==10000,"before cast completion no damage")
	caster.tick(0.02)
	check(not windup_target.alive(),"cast completion releases percent burst")
	var bad: SkillDefinition=burst.duplicate(true); bad.id=&"malfory_bad"; bad.effect_data.target_max_hp_ratio_formula="unknown_stat*1"
	caster.definition=caster.definition.duplicate(); caster.definition.skills.append(bad)
	check(not caster.abilities.available(bad),"invalid percent formula rejected without MP spend")
	check(curse.cooldown==0 and burst.cooldown==0 and curse.default_key==KEY_Q and burst.default_key==KEY_W,"zero cooldown resource-owned Q/W defaults")
	game.start_world()
	check(game.effects.is_empty() and not game.spell_flash.rect.visible,"return clears curse effects and flash")
	var report: Dictionary={"passed":passed,"failed":failed,"tests":tests,"rendered":DisplayServer.get_name()!="headless"}
	var file: FileAccess=FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "render.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MALFORY_RESULT ",JSON.stringify(report)); get_tree().quit(0 if failed==0 else 1)
