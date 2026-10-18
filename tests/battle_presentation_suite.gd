extends Node
var passed: int = 0
var failures: Array[String] = []
var game: GameDirector
var banners: int = 0
var returns: int = 0
func check(ok: bool, caption: String) -> void:
	if ok: passed+=1; print("PASS | ",caption)
	else: failures.append(caption); push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(45).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func click(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = get_viewport().get_stretch_transform()*at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event,false)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,false)
	await get_tree().process_frame
func capture(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/world/battle-%s.png" % name_text)
func await_mode(expected: StringName) -> void:
	while game.mode!=expected: await get_tree().process_frame
func run() -> void:
	LegacyPartyFixture.install()
	var flow: BattleResultFlow = BattleResultFlow.new()
	flow.banner_requested.connect(func(_ticket: int,_id: String) -> void: banners+=1)
	flow.return_requested.connect(func(_ticket: int,_id: String) -> void: returns+=1)
	flow.begin("test",true)
	flow.tick(1.99)
	check(flow.stage==BattleResultFlow.Stage.HOLD and banners==0 and not flow.request_return(),"PRES-01 no banner or skip before two seconds")
	flow.tick(0.011)
	check(flow.stage==BattleResultFlow.Stage.BANNER and banners==1 and flow.seconds_left()==3,"PRES-02 banner appears after two seconds")
	flow.tick(2.99)
	check(returns==0 and flow.seconds_left()==1,"PRES-03 three visible seconds before automatic return")
	flow.tick(0.011)
	check(returns==1 and not flow.request_return(),"PRES-04 automatic return latched exactly once")
	flow.tick(100)
	check(returns==1 and banners==1,"PRES-04 subsequent ticks cannot repeat events")
	flow.begin("skip")
	flow.tick(2)
	check(flow.request_return() and not flow.request_return() and returns==2,"PRES-05 rapid skip only succeeds once")
	flow.begin("failed",false)
	flow.tick(100)
	check(flow.stage==BattleResultFlow.Stage.SAVE_BLOCKED and not flow.request_return() and returns==2,"PRES-06 save failure never auto returns")
	flow.begin("long_frame")
	flow.tick(10)
	check(flow.stage==BattleResultFlow.Stage.BANNER and flow.seconds_left()==3,"PRES-03 stalled frame cannot erase banner display time")
	flow.cancel()
	flow.tick(100)
	check(flow.stage==BattleResultFlow.Stage.NONE and returns==2,"PRES-07 cancelled sequence has no delayed result")
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	await await_mode(&"world")
	game.start_battle(Catalog.encounters()[0])
	await await_mode(&"battle")
	game.set_physics_process(false)
	game.set_process(false)
	game.selection.select_ids([game.roster_ids[3]])
	game.hud.next_refresh = 0
	game.hud._process(0)
	var hud: GameHud = game.hud
	var dock: Control = hud.root.get_node("BattleDock")
	check(not hud.root.get_node("Header").visible and not hud.root.get_node("MercenaryRoster").visible,"PRES-08 no battle-wide header or world portrait column")
	check(hud.skill_buttons.size()==2 and hud.skill_buttons.has(&"dragon"),"PRES-09 selected-unit skills retained in compact dock")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,450)]:
		get_window().size = size
		for frame: int in 6: await get_tree().process_frame
		var extent: Vector2 = get_viewport().get_visible_rect().size
		check(dock.size.y>=148 and is_equal_approx(dock.get_global_rect().end.y,extent.y),"PRES-10 classic dock remains at bottom "+str(size))
		var map_rect: Rect2 = hud.mini.get_global_rect()
		var log_rect: Rect2 = hud.log_label.get_global_rect()
		var skills_rect: Rect2 = hud.skill_grid.get_global_rect()
		check(map_rect.end.x<log_rect.position.x and log_rect.end.x<skills_rect.position.x,"PRES-10 left minimap / center messages / right skills "+str(size))
		check(hud.battle_layout.info.get_global_rect().end.x<=extent.x and hud.details.is_visible_in_tree(),"PRES-11 selected portrait and stats at upper right "+str(size))
		check(hud.battle_layout.skill_scroll.get_global_rect().end.y<=hud.sequence_label.get_global_rect().position.y,"PRES-10 skills do not overlap sequence row "+str(size))
		await capture("classic-ui-%dx%d" % [size.x,size.y])
	get_window().size = Vector2i(1280,720)
	for frame: int in 6: await get_tree().process_frame
	var old_scale: float = GameSettings.profile.ui_scale
	GameSettings.set_feel("ui_scale",1.4)
	for frame: int in 3: await get_tree().process_frame
	check(dock.size.y>148 and hud.battle_layout.skill_scroll.get_global_rect().end.y<=hud.sequence_label.get_global_rect().position.y,"PRES-15 larger GUI font grows dock instead of overlapping skills")
	check(hud.details.get_global_rect().end.y<hud.battle_layout.info.get_global_rect().end.y,"PRES-15 enlarged stat text remains inside selected unit panel")
	await capture("classic-ui-large-font")
	GameSettings.set_feel("ui_scale",old_scale)
	var record: CharacterRecord = PartyProgress.records[0]
	var old_xp: int = record.experience
	for id: int in game.living_ids(1): game.apply_damage(game.get_unit(id),99999,false,CombatMath.Kind.MAGIC)
	check(game.living_ids(1).is_empty(),"PRES-12 rendered victory fixture actually has defeated enemies")
	game.battle_experience = 70
	game.finish_battle("victory")
	check(game.mode==&"results" and game.result_flow.stage==BattleResultFlow.Stage.HOLD and (hud.result==null or not hud.result.visible),"PRES-01 actual terminal state holds battlefield without popup")
	var after_xp: int = record.experience
	game.finish_battle("victory")
	check(after_xp>old_xp and record.experience==after_xp,"PRES-12 duplicate finish does not award XP twice")
	await click(Vector2(300,250))
	check(game.mode==&"results" and game.result_flow.stage==BattleResultFlow.Stage.HOLD,"PRES-01 early left click cannot skip hold")
	game.result_flow.tick(2)
	check(hud.result!=null and hud.result.visible and hud.result_seconds.text.contains("3 秒"),"PRES-02 actual scroll and countdown appear")
	await capture("victory-scroll")
	var old_ticket: int = game.result_flow.ticket
	var old_id: String = game.result_flow.encounter_id
	await click(Vector2(12,600)) # GUI minimap area: skip must also work over HUD
	await await_mode(&"world")
	check(game.mode==&"world" and not hud.result.visible,"PRES-05 native left click over HUD returns to world")
	game._complete_victory_return(old_ticket,old_id)
	check(game.mode==&"world","PRES-07 stale deferred callback ignored after return")
	game.start_battle(Catalog.encounters()[0])
	await await_mode(&"battle")
	game.set_physics_process(false)
	game.finish_battle("victory")
	game.result_flow.tick(2)
	game.result_flow.tick(3)
	await await_mode(&"world")
	check(game.mode==&"world","PRES-04 actual three-second sequence auto returns")
	check(game.result_flow.stage==BattleResultFlow.Stage.NONE,"PRES-07 map load clears result lifecycle")
	game.start_battle(Catalog.encounters()[0])
	await await_mode(&"battle")
	game.set_physics_process(false)
	game.set_process(true)
	var clock: int = Time.get_ticks_msec()
	game.finish_battle("victory")
	# SceneTreeTimer's first delta can include work before it was created.
	# This is a real-clock assertion, so use the same monotonic event origin.
	while Time.get_ticks_msec()-clock<1800: await get_tree().process_frame
	check(game.mode==&"results" and game.result_flow.stage==BattleResultFlow.Stage.HOLD and not hud.result.visible,"PRES-13 real clock holds result for two seconds")
	while Time.get_ticks_msec()-clock<2150: await get_tree().process_frame
	check(game.result_flow.stage==BattleResultFlow.Stage.BANNER and hud.result.visible,"PRES-13 real clock shows banner after hold")
	await await_mode(&"world")
	var total_time: int = Time.get_ticks_msec()-clock
	print("PRES_RETURN_METRICS elapsed_ms=",total_time)
	check(total_time>=4990 and total_time<6500,"PRES-13 actual auto return occurs after two plus three seconds")
	game.set_process(false)
	# Real encounter bridge + injected disk failure, not just a presentation stub.
	var context: WorldContext = game.world_context
	var monster: Dictionary = context.state["maps"][context.current_map().map_id]["parties"].values()[0]
	context.state["player"].merge({"position":monster["position"]+Vector2(5,0),"protected_until_ms":0,"cooldown_until_ms":0},true)
	context.refresh_player(PartyProgress.serialize())
	var begin: Dictionary = context.encounters.try_begin("player",monster["party_id"],"player")
	check(begin["ok"],"PRES-14 real encounter reserves a fixed monster party")
	context.state["active_encounter"]["state"] = "LOADING"
	game._encounter_battle(context.state["active_encounter"].duplicate(true))
	await await_mode(&"battle")
	game.set_physics_process(false)
	for id: int in game.living_ids(1): game.apply_damage(game.get_unit(id),99999,false,CombatMath.Kind.MAGIC)
	context.save.enabled = true
	context.save.path = "user://battle_presentation_test.dat"
	context.save.fail_writes = 1
	var receipts_before: int = context.state["applied_results"].size()
	game.finish_battle("victory")
	var encounter_id: String = begin["encounter_id"]
	var result_copy: Dictionary = game.settlement_result.duplicate(true)
	game.result_flow.tick(100)
	check(game.mode==&"results" and game.result_flow.stage==BattleResultFlow.Stage.SAVE_BLOCKED and hud.result.visible,"PRES-06 failed actual settlement shows retry UI and cannot auto return")
	check(context.state["applied_results"].size()==receipts_before,"PRES-14 failed commit does not publish a reward receipt")
	game.start_world() # explicit retry through existing save-first return path
	await await_mode(&"world")
	check(context.state["applied_results"].has(encounter_id) and context.party(monster["party_id"]).is_empty(),"PRES-14 successful retry consumes the same party once")
	var settled_world: Dictionary = context.snapshot()
	check(context.settlement.apply(result_copy).get("duplicate",false) and context.snapshot()==settled_world,"PRES-14 late duplicate result cannot award again")
	context.save.enabled = false
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"rendered":DisplayServer.get_name()!="headless"}
	var file: FileAccess = FileAccess.open("res://artifacts/world/battle-presentation-%s-results.json" % ("render" if report["rendered"] else "headless"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("BATTLE_PRESENTATION_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
