extends Node
var passed: int=0
var failed: int=0
func check(value: bool,label_: String) -> void:
	print("PASS " if value else "FAIL ",label_)
	if value: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	get_tree().create_timer(90).timeout.connect(func()->void: get_tree().quit(2))
	var context:=WorldContext.new(); context.initialize(PartyProgress.serialize(),42047,true)
	context.save.enabled=true; context.save.path="user://monkey_suite_%d.dat"%Time.get_ticks_usec()
	WorldSession.context=context
	var initial: Dictionary=context.snapshot()
	var monkey_party: Dictionary={}
	for party: Dictionary in context.state.maps.river_bay.parties.values():
		if party.habitat_id=="monkey_garden_region": monkey_party=party; break
	check(not monkey_party.is_empty(),"native river population includes monkey party")
	if monkey_party.is_empty(): get_tree().quit(1); return
	check(monkey_party.deployed_units.size()==5,"exactly five persistent members")
	var game: GameDirector=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	for outcome: String in ["retreat","defeat","victory"]:
		context.publish(initial); PartyProgress.restore(initial.progress)
		monkey_party=context.party(monkey_party.party_id)
		context.state.player.position=monkey_party.position
		var started: Dictionary=context.encounters.try_begin("player",monkey_party.party_id,"player")
		check(started.ok,"start "+outcome)
		if not started.ok: print(started); break
		check(not context.encounters.try_begin("player",monkey_party.party_id,"player").ok,"double click rejected")
		context.state.world_time_ms=context.state.active_encounter.deadline_ms
		context.encounters.tick()
		while game.mode!=&"monkey": await get_tree().process_frame
		check(game.monkey_garden.monkeys.size()==5,"3D instantiated after countdown")
		check(not game.camera.enabled and not game.hud.visible,"2D input and HUD suspended")
		var ids: Array[String]=[]
		for actor: GardenMonkey in game.monkey_garden.monkeys: ids.append(actor.unit_id)
		var before: Array=context.state.active_encounter.player_party_snapshot.deployed_units.duplicate(true)
		var remaining: float=float(before[0].current_hp)-10.0
		if outcome=="victory":
			context.save.fail_writes=1
			game._monkey_completed(outcome,remaining,ids)
			check(context.state.active_encounter.state=="SETTLING" and game.mode==&"monkey","failed save retains battle")
		var result_ids: Array[String]=[]
		if outcome=="victory": result_ids.assign(ids)
		game._monkey_completed(outcome,0.0 if outcome=="defeat" else remaining,result_ids)
		while game.mode!=&"world": await get_tree().process_frame
		check(game.camera.enabled and game.hud.visible and game.monkey_garden==null,"world restored "+outcome)
		check(is_equal_approx(PartyProgress.records[0].health,PartyProgress.records[0].stats().health if outcome=="defeat" else remaining),"main HP "+outcome)
		var preserved: bool=true
		for i: int in range(1,before.size()): preserved=preserved and is_equal_approx(PartyProgress.records[i].health,before[i].current_hp) and is_equal_approx(PartyProgress.records[i].mana,before[i].current_mp)
		check(preserved,"other soldiers unchanged "+outcome)
		check(not context.save.load_best().is_empty(),"disk result reload "+outcome)
	game.queue_free(); await get_tree().process_frame
	print("MONKEY_ENCOUNTER_RESULT passed=%d failed=%d"%[passed,failed]); get_tree().quit(1 if failed else 0)
