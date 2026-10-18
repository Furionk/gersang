extends "res://tests/combat_ux_suite.gd"
func run()->void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/tests/ui-humanized")
	GameSettings.settings_path="res://artifacts/tests/ui-humanized/settings.cfg"
	GameSettings.control_groups.clear()
	LegacyPartyFixture.install()
	game=load("res://main.tscn").instantiate()
	add_child(game)
	while game.mode!=&"world":await get_tree().process_frame
	var old_definition:UnitDefinition=PartyProgress.records[2].definition
	PartyProgress.records[2].definition=load("res://features/units/data/mercenaries/ninja.tres")
	game.hud.world_hud.refresh()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/ui-humanized/ninja-roster.png")
	PartyProgress.records[2].definition=old_definition
	game.start_battle(Catalog.encounters()[0])
	while game.selection==null:await get_tree().process_frame
	game.set_physics_process(false)
	game.cinematic_camera=false
	var selection:SelectionController=game.selection
	var hero:TacticalUnit=game.get_unit(game.roster_ids[0])
	var healer:TacticalUnit=game.get_unit(game.roster_ids[4])
	selection.select_ids([hero.unit_id,healer.unit_id])
	await key(KEY_EQUAL,false,true)
	check(selection.groups.get(11,[]).size()==2,"Ctrl+= stores two selected units")
	check(hero.view.group_label=="=","group badge follows assignment")
	selection.select_ids([])
	await key(KEY_EQUAL)
	check(selection.selected_ids.size()==2,"= recalls group")
	selection.restore_groups()
	check(selection.groups.get(11,[]).size()==2,"persistent characters restore group")
	hero.is_summon=true
	selection.select_ids([hero.unit_id])
	await key(KEY_MINUS,false,true)
	check(selection.groups.get(10,[]).size()==1,"summon group exists this battle")
	selection.store_group(0)
	selection.restore_groups()
	check(not selection.groups.has(10),"summon group does not restore next battle")
	selection.select_ids([healer.unit_id])
	selection.recall_group(0)
	check(selection.selected_ids==[healer.unit_id],"expired summon group does not select unrelated roster slot")
	hero.is_summon=false
	selection.select_ids(game.roster_ids)
	var heal:SkillDefinition=load("res://features/skills/data/heal.tres")
	healer.abilities.set_autocast(heal,true)
	game.hud._update_skill_availability()
	check(GameSettings.support_modes.get(healer.character.persistent_id+":"+str(heal.id),false),"auto setting stored by character identity")
	var button:SkillCommandButton=game.hud.skill_buttons.get(heal.id)
	check(button!=null and button.auto_mode==2,"automatic skill shows orbit feedback")
	var phase:float=button.phase
	await get_tree().create_timer(0.1).timeout
	check(button.phase!=phase,"automatic border animates continuously")
	var conflicts:Dictionary=selection.conflicting_skills()
	check(not conflicts.is_empty(),"duplicate selected skill keys reported")
	for id:StringName in conflicts:check(game.hud.skill_buttons[id].conflicted,"conflict badge is red: "+str(id))
	var before:int=game.audio.feedback_count
	game.hud.skill_buttons[heal.id].pressed.emit()
	check(game.audio.feedback_count==before+1,"icon activation produces one feedback sound")
	selection.cancel()
	before=game.audio.feedback_count
	await key(KEY_T)
	check(game.audio.feedback_count==before+1,"conflicting hotkey produces audible feedback")
	ready(hero)
	hero.vitals.mana=0
	selection.select_ids([hero.unit_id])
	selection.cancel()
	var costly:SkillDefinition
	for skill:SkillDefinition in hero.available_skills():
		if skill.manual() and skill.mana_cost>0:costly=skill;break
	game.hud._update_skill_availability()
	await get_tree().process_frame
	var unavailable:SkillCommandButton=game.hud.skill_buttons[costly.id]
	check(not unavailable.disabled and unavailable.get_meta("label").text=="法力不足","mana shortage remains clickable and visibly explained")
	before=game.audio.feedback_count
	await click(unavailable.get_global_rect().get_center())
	check(game.audio.feedback_count==before+1 and game.audio.last_feedback=="error" and unavailable.rejected_left>0,"insufficient mana icon click plays error and flashes border")
	check(selection.armed_skill_id==&"" and hero.vitals.mana==0,"rejected skill does not arm or spend mana")
	before=game.audio.feedback_count
	await key(int(GameSettings.bindings[str(costly.action)]) as Key)
	check(game.audio.feedback_count==before+1 and game.hud.log_lines[-1].contains("需要 MP"),"insufficient mana hotkey reports cost and plays feedback")
	await key(int(GameSettings.bindings[str(costly.action)]) as Key,true)
	check(game.audio.feedback_count==before+1,"held insufficient mana hotkey does not repeat feedback")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/ui-mana-feedback/insufficient-mana.png")
	ready(hero)
	game.hud._update_skill_availability()
	check(unavailable.get_meta("label").text!="法力不足","mana recovery clears unavailable label")
	await key(KEY_X)
	check(game.hud.window.visible,"X opens travel menu")
	await key(KEY_X,true)
	check(game.hud.window.visible,"held X leaves menu open")
	await key(KEY_X)
	check(not game.hud.window.visible,"fresh X closes menu")
	var trial:Dictionary=game.debug_trial_unit("ninja")
	var ninja:TacticalUnit=game.get_unit(trial.unit_id)
	ready(ninja)
	selection.select_ids([ninja.unit_id])
	var targeted:SkillDefinition
	for skill:SkillDefinition in ninja.available_skills():
		if skill.target_mode==SkillDefinition.Target.ENEMY:targeted=skill;break
	check(targeted!=null and selection.activate_skill(targeted.id),"ninja target skill arms")
	var motion:InputEventMouseMotion=InputEventMouseMotion.new()
	motion.position=Vector2(500,250)
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	for child:Node in game.hud.root.get_children():
		if child is SkillTargetCursor:check(child.visible and not child.caption.is_empty(),"target acquisition cursor and prompt visible")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/ui-humanized/target-cursor.png")
	selection.cancel()
	game.debug_trial_unit("teppo")
	game.debug_trial_unit("kohime")
	game.debug_trial_unit("malfory")
	selection.select_ids(game.living_ids(0))
	game.hud.next_refresh=0
	await get_tree().process_frame
	check(game.hud.skill_buttons.size()>12,"all skills retained beyond twelve")
	check(is_equal_approx(game.hud.root.get_node("BattleDock").size.y,148),"many skills preserve original 148px battlefield HUD budget")
	check(game.hud.battle_layout.skill_scroll.clip_contents,"overflow clipped inside scroll panel")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/ui-humanized/battle.png")
	selection.cancel()
	game.ground_click_feedback.clear()
	await click(Vector2(750,350),MOUSE_BUTTON_RIGHT)
	check(game.ground_click_feedback.rings.size()==1,"battle right click acknowledges ground movement")
	game.ground_click_feedback.clear()
	await click(game.hud.battle_layout.menu_button.get_global_rect().get_center())
	check(game.hud.window.visible and game.ground_click_feedback.rings.is_empty(),"menu icon does not pass click to ground")
	await key(KEY_X)
	GameSettings.profile.ui_scale=1.4
	game.hud.battle_layout._layout()
	check(is_equal_approx(game.hud.root.get_node("BattleDock").size.y,172),"enlarged HUD preserves original accessibility height")
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll:ScrollContainer=game.hud.battle_layout.skill_scroll
	scroll.scroll_vertical=10000
	await get_tree().process_frame
	var last:Control=game.hud.skill_grid.get_child(game.hud.skill_grid.get_child_count()-1)
	check(scroll.scroll_vertical>0,"overflow actually scrolls at enlarged size")
	check(scroll.get_global_rect().intersects(last.get_global_rect()),"last skill reachable with enlarged UI")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/ui-humanized/enlarged.png")
	GameSettings.profile.ui_scale=1.0
	game.hud.battle_layout._layout()
	scroll.scroll_vertical=0
	var healing:SupportVfx=SupportVfx.new()
	healing.target=hero
	game.render_root.add_child(healing)
	var supplying:SupportVfx=SupportVfx.new()
	supplying.target=healer;supplying.mana=true
	game.render_root.add_child(supplying)
	await get_tree().create_timer(0.18).timeout
	check(healing.frame<4 and supplying.frame>=4,"support sprites use independent heal and mana rows")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/ui-humanized/support.png")
	await get_tree().create_timer(0.5).timeout
	check(not is_instance_valid(healing) and not is_instance_valid(supplying),"support sprites clean up after playback")
	GameSettings.load_settings()
	healer.abilities.autocast.clear()
	check(healer.abilities.autocast_enabled(heal),"support mode reloads from disk without local cache")
	print("UI_HUMANIZED_RESULT passed=%d failed=%d"%[passed,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
