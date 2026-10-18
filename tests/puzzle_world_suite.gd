extends Node
var passed: int = 0
var failed: int = 0
var checks: Array[Dictionary] = []
var game: GameDirector
const OUT: String = "res://artifacts/puzzle-world/"

func check(ok: bool, label: String) -> void:
	checks.append({"test":label,"pass":ok})
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed += 1
	else: failed += 1

func _ready() -> void:
	get_tree().create_timer(150).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")

func fixture(hp: float, maximum: float, element: int = 0) -> Dictionary:
	return {"id":1,"name":"test","hp":hp,"max_hp":maximum,"attack":10.0,"element":element}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var rules: PuzzleRules = load("res://features/puzzle/data/default_rules.tres")
	var elements: Dictionary = {"gunner":0,"teppo":0,"merchant":1,"guard":1,"kohime":1,"healer":2,"supplier":2,"malfory":2,"mage":3,"controller":3,"ninja":3}
	for id: String in elements:
		var definition: UnitDefinition = load("res://features/units/data/mercenaries/"+id+".tres")
		check(definition.puzzle_element==elements[id] and definition.puzzle_monster==null,"native soldier affinity "+id)
	for id: String in ["fire","water","grass","electric"]:
		var definition: UnitDefinition = load("res://features/units/data/monsters/puzzle_"+id+".tres")
		check(definition.sprite_layout.valid_for(Vector2i(SpriteAtlas.texture_for(definition).get_size())),"monster layout valid "+id)
		check(is_equal_approx(PartyBuilder.resolve_member(definition,25,"test").current_hp,550.4),"Lv25 gunner reference health "+id)
	var board: PuzzleBoard = PuzzleBoard.new()
	for seed_value: int in 30:
		board.initialize(seed_value)
		check(board.matches().is_empty() and board.has_move(),"initial stable playable board %d"%seed_value)
	var same: PuzzleBoard = PuzzleBoard.new()
	same.initialize(29)
	check(same.cells == board.cells,"seed deterministic")
	board.cells.assign([0,1,0,2,3,4, 1,0,2,3,4,0, 2,3,4,0,1,2, 3,4,0,1,2,3, 4,0,1,2,3,4])
	board.swap(1,7)
	check(board.matches().size()==1 and board.matches()[0].count==3,"single adjacent swap creates one horizontal combo")
	board.cells.fill(4)
	check(board.matches().size()==1 and board.matches()[0].count==30,"connected horizontal and vertical matches count once")
	board.cells.assign([0,0,0,1,2,3, 1,2,3,0,1,2, 2,3,4,0,2,3, 3,4,1,0,3,4, 4,1,2,3,4,1])
	check(board.matches().size()==2,"disconnected same-color matches count twice")
	check(board.path_between(0,14)==[1,2,8,14],"fast diagonal drag uses adjacent deterministic path")
	var groups: Array[Dictionary] = board.matches()
	board.clear_groups(groups)
	board.refill()
	check(not board.cells.has(-1) and board.cells.size()==30,"gravity/refill fills every empty cell")
	check(PuzzleRules.affinity(0,2)==2 and PuzzleRules.affinity(2,0)==0.5 and PuzzleRules.affinity(3,0)==1 and PuzzleRules.affinity(1,0)==2,"element affinity cycle and neutral electricity")
	var model: PuzzleCombat = PuzzleCombat.new()
	model.setup([fixture(50,100)],[fixture(1000,1000,2)],rules,5)
	var formula_actions: Array[Dictionary] = model.actions([{"element":0,"count":3},{"element":0,"count":4},{"element":4,"count":3}])
	check(formula_actions[0].combos==3,"queued attack retains original combo count")
	check(is_equal_approx(model.apply_action(formula_actions[0]).amount,67.5),"extra orb plus three combo multiplier and affinity")
	check(is_equal_approx(model.apply_action(formula_actions[1]).amount,15),"heart recovery uses total combo multiplier")
	model.setup([fixture(1,100),fixture(100,100),fixture(0,100)],[fixture(500,500,2)],rules,5)
	check(is_equal_approx(model.distribute(80,false),80) and model.friends[0].hp==0 and is_equal_approx(model.friends[1].hp,21),"pooled damage redistributes overkill")
	model.distribute(300,true)
	check(model.friends[0].hp==0 and model.friends[1].hp==100 and model.friends[2].hp==0,"healing caps and never revives")
	model.distribute(100,false)
	check(model.outcome()=="defeat","pooled extinction defeats")
	model.setup([fixture(100,100)],[fixture(10,10,2),fixture(200,200,2)],rules,5)
	var actions: Array[Dictionary] = model.actions([{"element":0,"count":3},{"element":0,"count":4}])
	var hit: Dictionary = model.apply_action(actions[0])
	check(hit.amount==10 and model.enemies[1].hp==200 and model.live_target()==1,"single attack no overflow and target retargets")
	var dead_clock: float = model.enemies[0].cooldown
	model.enemies[1].cooldown=0.5
	check(model.tick_enemies(0.25).is_empty(),"enemy waits for seconds deadline")
	check(model.tick_enemies(0.25).size()==1 and is_equal_approx(model.health(),92),"enemy attacks at cooldown deadline without player turn")
	check(model.enemies[0].cooldown==dead_clock and model.enemies[1].cooldown==rules.enemy_cooldown_seconds,"dead clock frozen and live cooldown resets")
	check(model.tick_enemies(20).size()==2,"large delta catches elapsed cooldowns")
	var timer_control: PuzzleController = PuzzleController.new()
	timer_control.setup([fixture(100,100)],[fixture(1000,1000)],rules,22)
	for phase: String in ["ready","drag","clear","fall","actions"]:
		timer_control.stage=phase; timer_control.delay=100
		timer_control.combat.enemies[0].cooldown=0.1
		var before_hp: float=timer_control.combat.health()
		timer_control.advance(0.2)
		check(timer_control.combat.health()<before_hp,"realtime attack during "+phase)
	timer_control.focused=false
	var paused_clock: float=timer_control.combat.enemies[0].cooldown
	timer_control.advance(20)
	check(timer_control.combat.enemies[0].cooldown==paused_clock,"focus freezes enemy seconds")
	timer_control.focused=true; timer_control.stage="blocked"; timer_control.advance(20)
	check(timer_control.combat.enemies[0].cooldown==paused_clock,"transition freezes enemy seconds")
	timer_control.stage="drag"; timer_control.selected=0
	timer_control.combat.friends[0].hp=1; timer_control.combat.enemies[0].cooldown=0
	timer_control.advance(0.1)
	check(timer_control.stage=="done" and timer_control.selected==-1,"lethal timed attack ends drag immediately")
	timer_control.free()
	model.friends[0].hp=0
	check(model.apply_action({"kind":"attack","actor":0,"power":100}).is_empty(),"soldier killed by clock cannot execute queued attack")
	var control: PuzzleController = PuzzleController.new()
	control.setup([fixture(100,100)],[fixture(1000,1000)],rules,123)
	control.press(0); control.release()
	check(control.stage=="ready" and control.combat.turn==1,"click without swap is free")
	control.press(0); control.drag(14)
	check(control.selected==14 and control.moved,"continuous drag follows all intervening cells")
	control.focused=false; control.advance(8)
	check(control.remaining==6 and control.stage=="drag","focus loss pauses timer")
	control.focused=true; control.advance(7)
	check(control.stage=="match","six second timeout releases")
	for step: int in 300:
		if control.stage in ["ready","done"]: break
		control.advance(0.5)
	check(control.stage=="ready" and control.combat.turn==2,"cascade completes exactly one turn")
	control.action_queue.append({"kind":"attack","actor":0,"power":1.0})
	control.attack_delay=0
	control.press(0)
	var before_attack: float=control.combat.enemies[0].hp
	control.advance(0.01)
	check(control.stage=="drag" and control.combat.enemies[0].hp<before_attack,"next drag stays active while previous combo attacks")
	control.release()
	control.board.initialize(719)
	var zero_pair: Array[int] = []
	for a: int in 30:
		for b: int in control.board.neighbors(a):
			control.board.swap(a,b)
			var empty: bool = control.board.matches().is_empty()
			control.board.swap(a,b)
			if empty: zero_pair.assign([a,b]); break
		if not zero_pair.is_empty(): break
	control.press(zero_pair[0]); control.drag(zero_pair[1]); control.release()
	for step: int in 40: control.advance(0.5)
	check(control.combat.turn==3 and control.combos==0,"zero combo swap consumes enemy turn")
	control.free()
	await population()
	await integration()
	await preview()
	var rendered: bool = DisplayServer.get_name() != "headless"
	var report: Dictionary = {"passed":passed,"failed":failed,"rendered":rendered,"checks":checks}
	FileAccess.open(OUT+("render.json" if rendered else "headless.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PUZZLE_WORLD_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failed==0 else 1)

func population() -> void:
	WorldCatalog.initialize()
	var map: WorldMapDefinition = WorldCatalog.definitions.river_bay
	check(map.tile_authoring_errors.is_empty(),"native terrain/region calibration valid")
	var before_scene: WorldMap2D = load("res://artifacts/puzzle-world/before/river_bay.tscn").instantiate()
	var before_map: WorldMapDefinition = before_scene.compile_definition()
	before_scene.free()
	var original_routes_preserved: bool=true
	for portal: Dictionary in before_map.portals: original_routes_preserved=original_routes_preserved and portal in map.portals
	for entry: String in before_map.entries: original_routes_preserved=original_routes_preserved and map.entries.get(entry)==before_map.entries[entry]
	check(original_routes_preserved,"original artist portals and arrival points preserved alongside added entrances")
	var old_domains_unchanged: bool = true
	for habitat: WorldHabitat in before_map.habitats:
		var now: WorldHabitat = map.habitat(habitat.habitat_id)
		for key: String in ["spawn_domain","activity_domain","chase_domain"]:
			old_domains_unchanged = old_domains_unchanged and habitat.get(key).outer==now.get(key).outer and habitat.get(key).holes==now.get(key).holes
	check(old_domains_unchanged,"all original monster domains remain exact")
	var old_map: WorldMapDefinition = map.duplicate(true)
	for i: int in range(old_map.habitats.size()-1,-1,-1):
		if old_map.habitats[i].habitat_id.begins_with("puzzle_"): old_map.habitats.remove_at(i)
	var old: WorldContext = WorldContext.new()
	old.initialize(PartyProgress.serialize(),8031,true,{"river_bay":old_map})
	var saved: Dictionary = old.snapshot()
	var current: WorldContext = WorldContext.new()
	current.initialize(PartyProgress.serialize(),8031,true)
	current.publish(saved)
	current.ensure_map("river_bay")
	var runtime: Dictionary = current.state.maps.river_bay
	check(runtime.parties.size()==saved.maps.river_bay.parties.size()+40,"old save adds exactly forty parties")
	var preserved: bool = true
	for id: String in saved.maps.river_bay.parties:
		preserved = preserved and runtime.parties[id]==saved.maps.river_bay.parties[id]
	for id: String in saved.maps.river_bay.slots:
		preserved = preserved and runtime.slots[id]==saved.maps.river_bay.slots[id]
	check(preserved and current.state.progress==saved.progress and current.state.player==saved.player,"old party members slots timers and player progress exact")
	var count: int = 0
	for party: Dictionary in runtime.parties.values():
		if not String(party.habitat_id).begins_with("puzzle_"): continue
		count += 1
		var habitat: WorldHabitat = map.habitat(party.habitat_id)
		check(party.deployed_units.size()>=1 and party.deployed_units.size()<=3 and party.deployed_units[0].level==25 and habitat.profile.speed==255,"new party Lv25 count and speed")
		check(current.navigation.segment_legal("river_bay",party.habitat_id,"WANDER",party.position,party.position,habitat.profile.radius),"new monster pose legal")
	check(count==40,"all four elemental populations spawned")
	var once: Dictionary = current.snapshot()
	current.ensure_map("river_bay")
	check(once==current.snapshot(),"population sync idempotent")
	current.save.enabled=true
	current.save.path="user://puzzle-migration-suite.dat"
	check(current.checkpoint().ok,"additive population checkpoint written to isolated disk")
	var reopened: WorldContext = WorldContext.new()
	reopened.initialize(PartyProgress.serialize(),8031,true)
	reopened.publish(current.save.load_best())
	reopened.ensure_map("river_bay")
	check(reopened.snapshot()==current.snapshot(),"disk reopen preserves added parties and original progress")
	var legal_fast: bool = true
	current.state.player.protected_until_ms=99999999
	for frame: int in 24:
		for party: Dictionary in current.state.maps.river_bay.parties.values():
			if not String(party.habitat_id).begins_with("puzzle_"): continue
			var old_position: Vector2 = party.position
			MonsterBrain.tick(current,party,0.05)
			legal_fast = legal_fast and old_position.distance_to(party.position)<=12.751 and current.navigation.segment_legal("river_bay",party.habitat_id,"CHASE",old_position,party.position,16)
		current.state.world_time_ms+=50
	check(legal_fast,"high speed monsters retain legal radius-aware segments without teleport")
	current.publish(saved)
	current.state.active_encounter={"encounter_id":"locked"}
	current.state.mode="ENCOUNTER"
	current.ensure_map("river_bay")
	check(current.state.maps.river_bay==saved.maps.river_bay,"locked encounter defers population addition")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT+label+".png")

func mouse(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position=point; event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
	get_viewport().push_input(event,true)

func integration() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)
	while game.mode != &"world": await get_tree().process_frame
	game.set_physics_process(false)
	check(not PartyProgress.persistence_enabled,"test progress isolated")
	var context: WorldContext = game.world_context
	var party: Dictionary = {}
	for candidate: Dictionary in context.state.maps.river_bay.parties.values():
		if candidate.habitat_id=="puzzle_fire": party=candidate; break
	context.state.player.position=party.position+Vector2(2,0)
	context.state.player.protected_until_ms=0; context.state.player.cooldown_until_ms=0
	var begun: Dictionary = context.encounters.try_begin("player",party.party_id,"player")
	check(begun.ok,"real world puzzle party begins encounter")
	await capture("world-countdown")
	for step: int in 310:
		if game.mode not in [&"world",&"countdown"]: break
		game._physics_process(1.0/60.0)
		await get_tree().process_frame
	while game.mode == &"loading": await get_tree().process_frame
	check(game.mode==&"battle","five second encounter loads normal RTS battlefield")
	if game.mode!=&"battle": return
	var puzzle: TacticalUnit
	var friend: TacticalUnit = game.get_unit(game.roster_ids[0])
	for unit: TacticalUnit in game.units.values():
		if unit.team==1 and unit.definition.puzzle_monster!=null: puzzle=unit
	var other: TacticalUnit = game.spawn_unit(load("res://features/units/data/monsters/beast.tres"),1,game._safe_spawn(Vector2(700,700)),false)
	var summon: TacticalUnit = game.spawn_summon(friend.definition,friend,friend.position+Vector2(40,0),10)
	game.projectiles.append({"left":3.0,"target":other.unit_id,"attacker":friend.unit_id,"power":1.0})
	var hp: float = friend.vitals.health
	game.basic_attack(puzzle,friend,9999)
	check(game.mode==&"puzzle" and friend.vitals.health==hp,"first attack switches without dealing normal damage")
	var active: PuzzleBattle = game.puzzle_battle
	game.basic_attack(puzzle,friend,9999)
	check(game.puzzle_battle==active,"simultaneous triggers share one lock")
	while active.phase!="play": await get_tree().process_frame
	var control: PuzzleController = active.controller
	var at: Vector2 = other.position
	var timer: float = other.attack_timer
	var time_before: float = game.time_in_battle
	game._physics_process(2)
	check(other.position==at and other.attack_timer==timer and game.time_in_battle==time_before,"RTS position and clocks frozen")
	check(summon.summon_left==10 and game.projectiles[0].left==3,"summon expiry and in-flight projectile frozen")
	check(control.combat.friends.size()==game.roster_ids.size(),"all deployed portraits included and summons excluded")
	await capture("puzzle-ready")
	# Known legal board is a test fixture only; drag still passes through real viewport input.
	control.board.cells.assign([0,1,0,2,3,4, 1,0,2,3,4,0, 2,3,4,0,1,2, 3,4,0,1,2,3, 4,0,1,2,3,4])
	await get_tree().process_frame
	var view: PuzzleView = active.view
	var start: Vector2 = view.origin+(PuzzleView.BOARD.position+Vector2(150,50))*view.factor
	var end: Vector2 = start+Vector2(0,100)*view.factor
	mouse(start,true)
	await get_tree().process_frame
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position=end; motion.global_position=end; motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	check(view.pointer_position.is_equal_approx(view.logical_position(end)),"held orb follows viewport cursor")
	await capture("cursor-held-orb")
	mouse(end,false)
	await get_tree().process_frame
	check(control.stage!="ready" and view.input_events>=2,"viewport mouse drag reaches puzzle controller")
	while control.stage not in ["ready","done"]: await get_tree().process_frame
	check(control.combos>=1,"viewport drag resolves combos")
	await capture("puzzle-combo")
	# Exercise the ordinary damage/death commit with a finishing turn.
	for foe: Dictionary in control.combat.enemies: foe.hp=0
	control.combat.distribute(control.combat.maximum_health*0.08,false)
	control.stage="actions"; control.action_queue.clear()
	while game.mode==&"puzzle": await get_tree().process_frame
	check(game.mode==&"battle" and other.alive() and not puzzle.alive(),"puzzle death returns to original mixed battlefield")
	check(friend.vitals.health<hp,"pooled HP persists on returning")
	var experience: int = game.battle_experience
	puzzle.vitals.damage_resolved(9999)
	check(game.battle_experience==experience,"death cannot count XP twice")
	check(other.process_mode!=Node.PROCESS_MODE_DISABLED and game.render_root.process_mode!=Node.PROCESS_MODE_DISABLED,"subtree processing restored")
	await capture("returned-battle")
	for unit: TacticalUnit in game.units.values():
		if unit.team==1 and unit.alive(): unit.vitals.damage_resolved(999999)
	context.save.enabled=true
	context.save.path="user://puzzle-world-suite.dat"
	context.save.fail_writes=1
	game._physics_process(0.01); game._physics_process(2.01)
	check(game.mode==&"results" and game.last_result=="victory","original victory flow settles after remaining enemies die")
	check(game.result_flow.stage==BattleResultFlow.Stage.SAVE_BLOCKED,"failed disk settlement cannot auto-return")
	game._retry_settlement(false)
	check(context.save.load_best().applied_results.size()>0,"retry persists encounter receipt to isolated disk")
	var settled: Dictionary=context.snapshot()
	game.finish_battle("victory")
	check(context.snapshot()==settled,"duplicate victory cannot award twice")
	await capture("victory")
	game.queue_free()
	await get_tree().process_frame

func preview() -> void:
	var panel: PuzzleBattle = load("res://features/puzzle/puzzle_battle.tscn").instantiate()
	add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	check(panel.controller.combat.enemies.size()==4 and panel.view.portraits.size()==11,"F6 standalone preview has four colors and all eleven soldiers")
	var first: Dictionary = PartyProgress.serialize().duplicate(true)
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	var view: PuzzleView=panel.view
	touch.position=view.origin+(PuzzleView.BOARD.position+Vector2(50,50))*view.factor
	touch.index=0; touch.pressed=true
	get_viewport().push_input(touch,true)
	var drag: InputEventScreenDrag=InputEventScreenDrag.new()
	drag.index=0; drag.position=touch.position+Vector2(100,0)*view.factor
	get_viewport().push_input(drag,true)
	check(panel.controller.moved and panel.controller.selected==1,"touch drag uses same continuous swap path")
	check(view.pointer_position.is_equal_approx(view.logical_position(drag.position)),"held orb follows touch position")
	var held: Vector2 = view.pointer_position
	panel.controller.focused = false
	view._drag_pointer(held+Vector2(25,25))
	check(view.pointer_position==held,"unfocused pointer cannot move held orb")
	panel.controller.focused = true
	touch.pressed=false; touch.position=drag.position
	get_viewport().push_input(touch,true)
	check(panel.controller.stage=="match","touch release starts resolution")
	panel.controller._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var stage_before: String=panel.controller.stage
	panel.controller.advance(10)
	check(panel.controller.stage==stage_before,"application focus notification pauses turn resolution")
	panel.controller._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	check(panel.controller.focused,"application focus return resumes")
	await capture("four-elements-preview")
	if DisplayServer.get_name()!="headless":
		var before_size: Vector2i=get_window().size
		get_window().size=Vector2i(800,1100)
		await get_tree().process_frame; await get_tree().process_frame
		check(view.factor>0 and view.origin.x>=-0.1 and view.origin.y>=-0.1,"portrait window fits entire board")
		await capture("portrait-preview")
		get_window().size=before_size
	var fx: PuzzleImpact=PuzzleImpact.new()
	check(PuzzleImpact.strength(10)>PuzzleImpact.strength(5) and PuzzleImpact.strength(5)>PuzzleImpact.strength(1),"combo increases impact strength")
	check(PuzzleImpact.strength(99)==PuzzleImpact.strength(10),"impact strength has a readable ceiling")
	for i: int in 80: fx.record({"kind":"attack","actor":0,"target":0,"amount":10.0,"combos":10},0)
	check(fx.hits.size()==48 and fx.offset(0).length()<=10.01,"burst effects bounded in count and displacement")
	check(fx.flash(0)>0 and fx.flash(1)==0,"only struck enemy flashes")
	fx.advance(1)
	check(fx.hits.is_empty() and fx.offset(0)==Vector2.ZERO,"all transient effects expire")
	panel.controller.stage="ready"
	panel.controller.press(0)
	var before_cells: Array[int]=panel.controller.board.cells.duplicate()
	var before_clock: float=panel.controller.remaining
	view._cue({"kind":"attack","actor":0,"target":0,"amount":125.0,"dead":false,"combos":1})
	view._cue({"kind":"attack","actor":1,"target":1,"amount":875.0,"dead":false,"combos":10})
	check(panel.controller.stage=="drag" and panel.controller.board.cells==before_cells and panel.controller.remaining==before_clock,"hit effects cannot change input board or timer")
	panel.controller.drag(1)
	check(panel.controller.selected==1 and view.impact.hits.size()==2,"drag continues during overlapping hits")
	panel.controller.focused=false
	view._process(0.2)
	check(view.impact.hits[0].age==0,"focus loss freezes effect timeline")
	panel.controller.focused=true
	view.set_process(false)
	await capture("impact-low-high-combo")
	view.impact.advance(0.09)
	view.queue_redraw()
	await capture("impact-burst")
	view.set_process(true)
	panel.controller.release()
	var muted_before: bool = GameSettings.unit_voice_muted
	var volume_before: float = GameSettings.unit_voice_volume
	GameSettings.unit_voice_muted = false
	GameSettings.unit_voice_volume = 1.0
	var spoken: Array[StringName] = []
	panel.voice_manager.response_played.connect(func(id: StringName, _event: StringName, _path: String) -> void: spoken.append(id))
	panel.controller.delay = 0.26
	panel._attack_voice({"kind":"attack","actor":0})
	check(spoken.size()==1 and spoken[0]==panel.voice_profiles[0].unit_id,"puzzle attack plays acting soldier voice")
	check(panel.controller.delay==0.26,"voice never extends board or attack delay")
	panel.controller.focused=false; panel._process(0)
	check(panel.voice_manager.player.stream_paused,"focus loss pauses voice with turn")
	panel.controller.focused=true; panel._process(0)
	check(not panel.voice_manager.player.stream_paused,"focus return resumes voice")
	GameSettings.unit_voice_muted=true
	panel._attack_voice({"kind":"attack","actor":1})
	check(spoken.size()==1,"puzzle voices honor mute setting")
	GameSettings.unit_voice_muted=muted_before
	GameSettings.unit_voice_volume=volume_before
	panel.voice_manager.apply_settings()
	check(PartyProgress.serialize()==first,"standalone puzzle never changes permanent party")
	panel.queue_free()
	await get_tree().process_frame
