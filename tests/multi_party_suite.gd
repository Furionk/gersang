extends Node
var passed: int = 0
var failures: Array[String] = []
var captured: bool = false
func check(ok: bool, caption: String) -> void:
	if ok: passed+=1; print("PASS | ",caption)
	else: failures.append(caption); push_error("FAIL | "+caption)
func fixture(chance: float = 1.0) -> WorldContext:
	WorldCatalog.initialize()
	var map: WorldMapDefinition = WorldMapDefinition.new()
	map.map_id = "river_bay"
	map.extent = Vector2(1600,1600)
	map.walkable = [PolygonDomain.rectangle(Rect2(0,0,1600,1600))]
	var habitat: WorldHabitat = WorldCatalog.definitions.river_bay.habitats[0].duplicate(true) as WorldHabitat
	habitat.habitat_id = "fixture"
	habitat.spawn_domain = PolygonDomain.rectangle(Rect2(256,256,800,800))
	habitat.activity_domain = PolygonDomain.rectangle(Rect2(128,128,1200,1200))
	habitat.chase_domain = map.walkable[0].duplicate()
	habitat.profile.target_party_count = 6
	habitat.profile.rules.reinforcement_chance = chance
	habitat.profile.rules.reinforcement_join_chance=1.0
	habitat.profile.rules.reinforcement_check_ms=1000
	habitat.profile.speed = 100.0
	map.habitats = [habitat]
	var context: WorldContext = WorldContext.new()
	context.initialize(PartyProgress.serialize(),20261010,true,{"river_bay":map})
	context.state.player.position = Vector2(480,480)
	var poses: Array[Vector2] = [Vector2(520,480),Vector2(640,480),Vector2(480,640),Vector2(340,480),Vector2(480,340),Vector2(790,480)]
	var index: int = 0
	for party: Dictionary in context.state.maps.river_bay.parties.values():
		party.position = poses[index]
		party.home = poses[index]
		party.think_due_ms=99000 # deterministic recruitment fixture; live wandering is tested separately
		index+=1
	return context
func begin(context: WorldContext) -> Dictionary:
	return context.encounters.try_begin("player",context.state.maps.river_bay.parties.values()[0].party_id,"player")
func advance(context: WorldContext, seconds: float) -> void:
	for tick: int in int(round(seconds*60)): context.tick(1.0/60.0)
func result(context: WorldContext, outcome: String) -> Dictionary:
	var players: Array[Dictionary] = []
	var defeated: Array[String] = []
	var session: Dictionary = context.state.active_encounter
	for member: Dictionary in session.player_party_snapshot.deployed_units: players.append({"unit_id":member.unit_id,"hp":100.0,"mp":40.0})
	for party: Dictionary in session.enemy_party_snapshots:
		for member: Dictionary in party.deployed_units: defeated.append(member.unit_id)
	return {"encounter_id":session.encounter_id,"outcome":outcome,"player_unit_results":players,"defeated_enemy_unit_ids":defeated,"consumed_items":[]}
func shot(name_text: String) -> void:
	if not captured: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/multi-party-2026-10-10/"+name_text+".png")
func _ready() -> void:
	captured = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")
func run() -> void:
	var c: WorldContext = fixture()
	var original_members: Dictionary = {}
	for party: Dictionary in c.state.maps.river_bay.parties.values(): original_members[party.party_id] = party.deployed_units.duplicate(true)
	check(begin(c).ok,"primary encounter starts")
	var session: Dictionary = c.state.active_encounter
	check(session.deadline_ms-c.state.world_time_ms==5000,"countdown is five seconds")
	check(EncounterService.reserved_ids(session).size()==1,"only the clicked party is reserved at entry")
	advance(c,1.05)
	check(session.approaching_ids.size()>=3 and session.enemy_ids.size()==1,"notices approach only after a periodic chance roll")
	var old_position: Vector2 = c.party(session.approaching_ids[0]).position
	c.tick(1.0/60.0)
	check(c.party(session.approaching_ids[0]).position!=old_position,"reinforcements physically walk on countdown ticks")
	var id: String = session.encounter_id
	var snapshot: Dictionary = c.snapshot()
	check(c.save.valid(snapshot),"complete countdown snapshot accepts added RNG stream")
	var recovery: WorldContext = fixture()
	recovery.publish(snapshot)
	recovery.encounters.cancel(id,"RECOVER",true)
	check(recovery.state.maps.river_bay.parties.values().all(func(p: Dictionary) -> bool: return p.life_state=="ACTIVE" and p.encounter_id.is_empty()),"interrupted recovery releases every pending and joined party")
	var rolls: Dictionary = session.join_rolls.duplicate(true)
	var numbers: Array[int] = [5]
	for step: int in 299:
		c.tick(1.0/60.0)
		var number: int = ceili(maxf(0,float(session.deadline_ms-c.state.world_time_ms)/1000.0))
		if number>0 and number not in numbers: numbers.append(number)
	check(numbers==[5,4,3,2,1],"five visible countdown stages are driven by logical time")
	check(session.enemy_ids.size()<=4,"periodic choices never exceed four admitted batches")
	check(session.enemy_party_snapshots.size()==4 and session.approaching_ids.is_empty(),"three arrived reinforcements become four fixed snapshots")
	check(session.state=="LOADING" and c.encounters.mark_in_battle(id),"one guarded transition after five seconds")
	var expected_exp: int = 0
	for party: Dictionary in session.enemy_party_snapshots:
		check(party.deployed_units==original_members[party.party_id],"joining preserves exact members "+party.party_id)
		for unit: Dictionary in party.deployed_units: expected_exp+=unit.experience_reward
	var r: Dictionary = result(c,"victory")
	c.save.enabled = true
	c.save.fail_writes = 1
	c.save.path = "user://multi_party_suite.dat"
	check(not c.settlement.apply(r).ok,"multi-party commit failure holds original world")
	var candidate: Dictionary = c.settlement.pending[id].duplicate(true)
	check(c.state.maps.river_bay.parties.size()==6,"failed save does not consume any party")
	c.save.enabled = false
	check(c.settlement.apply(r).ok and c.state==candidate,"retry publishes the identical whole-world candidate")
	check(c.state.maps.river_bay.parties.size()==2 and c.state.applied_results[id].experience==expected_exp,"victory consumes all four slots and sums all enemy experience once")
	var settled: Dictionary = c.snapshot()
	check(c.settlement.apply(r).duplicate and c.snapshot()==settled,"duplicate multi-party result cannot award twice")
	check(c.encounters.complete_return(id),"victory return releases encounter control")
	c = fixture(0.0)
	begin(c)
	check(EncounterService.reserved_ids(c.state.active_encounter).size()==1,"zero probability recruits nobody")
	c.encounters.cancel(c.state.active_encounter.encounter_id)
	check(c.state.maps.river_bay.parties.size()==6,"cancel consumes no party")
	c = fixture()
	c.map_definitions.river_bay.habitats[0].profile.rules.reinforcement_radius = 0.0
	begin(c)
	check(EncounterService.reserved_ids(c.state.active_encounter).size()==1,"radius rejects distant candidates even at probability one")
	c = fixture()
	c.map_definitions.river_bay.habitats[0].profile.rules.max_enemy_parties = 1
	begin(c)
	check(EncounterService.reserved_ids(c.state.active_encounter).size()==1,"Inspector party cap is enforced")
	c = fixture()
	var primary_id: String = c.state.maps.river_bay.parties.values()[0].party_id
	for party: Dictionary in c.state.maps.river_bay.parties.values():
		if party.party_id!=primary_id: party.position = Vector2(840,480)
	c.map_definitions.river_bay.habitats[0].profile.rules.reinforcement_radius = 500.0
	var wall_map: WorldMapDefinition = c.map_definitions.river_bay
	wall_map.blockers = [PolygonDomain.rectangle(Rect2(720,0,64,1600))]
	c.navigation.register_map(c.map_definitions.river_bay)
	begin(c)
	check(EncounterService.reserved_ids(c.state.active_encounter).size()==1,"full impassable wall prevents cross-wall recruitment")
	c = fixture()
	begin(c)
	advance(c,5.1)
	id = c.state.active_encounter.encounter_id
	c.encounters.mark_in_battle(id)
	for party_id: String in c.state.active_encounter.enemy_ids:
		for unit: Dictionary in c.party(party_id).deployed_units: unit.current_hp = 1.0
	check(c.settlement.apply(result(c,"retreat")).ok,"retreat settles multiple batches")
	c.encounters.complete_return(id)
	check(c.state.maps.river_bay.parties.size()==6 and c.state.maps.river_bay.parties.values().all(func(p: Dictionary) -> bool: return p.encounter_id.is_empty() and p.deployed_units.all(func(u: Dictionary) -> bool: return u.current_hp==u.resolved_stats.health)),"retreat preserves and restores all four enemy batches")
	c = fixture()
	begin(c)
	advance(c,1.05)
	for party_id: String in c.state.active_encounter.approaching_ids: c.party(party_id).path = PackedVector2Array()
	advance(c,4.1)
	check(c.state.active_encounter.enemy_ids.size()==1 and c.state.maps.river_bay.parties.values().filter(func(p: Dictionary) -> bool: return p.life_state=="RESERVED").size()==1,"late reinforcements are released rather than teleported into battle")
	# Real RTS integration with four complete snapshots and distributed spawn groups.
	c = fixture()
	var previous: WorldContext = WorldSession.context
	WorldSession.context = c
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	begin(c)
	game._physics_process(1.0/60.0)
	game.camera.position = Iso.project(c.state.player.position)
	await shot("countdown-5")
	for frame: int in 120: game._physics_process(1.0/60.0)
	await shot("countdown-3")
	for frame: int in 180: game._physics_process(1.0/60.0)
	while game.mode!=&"battle": await get_tree().process_frame
	var batch_centers: Dictionary = {}
	var expected: Array[String] = []
	for party: Dictionary in game.battle_snapshot.enemy_party_snapshots:
		for unit: Dictionary in party.deployed_units: expected.append(unit.unit_id)
	for unit: TacticalUnit in game.units.values():
		if unit.team!=1: continue
		check(unit.persistent_unit_id in expected,"RTS persistent member "+unit.persistent_unit_id)
		batch_centers[unit.get_meta("enemy_batch")] = unit.position
		check(not game.ground._navigation_blocked(Vector2i(unit.position/Iso.CELL)),"RTS member spawns on navigable ground")
	check(game.living_ids(1).size()==expected.size() and batch_centers.size()==4,"RTS creates every member from four distinct batches")
	var separated: bool = true
	for a: int in batch_centers:
		for b: int in batch_centers:
			if a!=b: separated = separated and batch_centers[a].distance_to(batch_centers[b])>250.0
	check(separated,"four batches occupy different combat sectors")
	game.camera.position = Iso.project(Vector2(game.ground.cells)*Iso.CELL*0.5)
	game.camera.zoom = Vector2.ONE*0.45
	await shot("four-batch-battle")
	game.retreat()
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	check(c.state.control_owner.is_empty() and c.state.maps.river_bay.parties.size()==6,"real multi-party retreat and return release all parties")
	var choices: Array[EncounterDefinition] = Catalog.encounters().duplicate()
	choices.append(WorldCatalog.arenas.shaolin_temple.encounter)
	choices.append(WorldCatalog.arenas.millennium_lake.encounter)
	for choice: EncounterDefinition in choices:
		game.start_battle(choice)
		while game.mode!=&"battle": await get_tree().process_frame
		check(game.ground.cells==Vector2i(44,38) and game.ground.floor_layer.get_used_cells().size()==1672,"expanded native floor "+String(choice.id))
		await get_tree().physics_frame
		await get_tree().physics_frame
		var routes: bool = true
		var goals: Array[Vector2] = []
		if game.ground.authored_battlefield:
			# The Artist's scene markers replaced legacy EncounterDefinition centers.
			# Verify every current zone, never silently test discarded coordinates.
			for zone: Dictionary in game.ground.battle_zones:
				var candidates: Array[Vector2] = []
				for x: int in game.ground.cells.x:
					for y: int in game.ground.cells.y:
						var point: Vector2 = (Vector2(x,y)+Vector2.ONE*0.5)*Iso.CELL
						if point.distance_to(zone.point)<=zone.radius and game._spawn_is_free(point): candidates.append(point)
				candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(zone.point)<b.distance_squared_to(zone.point))
				if candidates.is_empty(): routes=false
				else: goals.append(candidates[0])
		else:
			for center: Vector2 in choice.enemy_spawn_centers: goals.append(game._safe_spawn(center))
		for goal: Vector2 in goals:
			var path: PackedVector2Array = NavigationServer2D.map_get_path(game.ground.region.get_navigation_map(),goal,game.get_unit(game.roster_ids[0]).position,true)
			# Headless physics-frame notifications precede the server's map sync.
			# Bound the wait, then keep the same strict complete-route assertion.
			for sync_frame: int in 30:
				if path.size()>=2 and path[-1].distance_to(game.get_unit(game.roster_ids[0]).position)<1.0: break
				await get_tree().physics_frame
				path = NavigationServer2D.map_get_path(game.ground.region.get_navigation_map(),goal,game.get_unit(game.roster_ids[0]).position,true)
			if path.size()<2 or path[-1].distance_to(game.get_unit(game.roster_ids[0]).position)>=1.0: print("ROUTE_DIAGNOSTIC ",choice.id," goal=",goal," player=",game.get_unit(game.roster_ids[0]).position," path=",path)
			routes = routes and path.size()>=2 and path[-1].distance_to(game.get_unit(game.roster_ids[0]).position)<1.0
		check(routes,"all authored spawn sectors connect to player deployment "+String(choice.id))
		game.camera.position = Iso.project(Vector2(game.ground.cells)*Iso.CELL*0.5)
		game.camera.zoom = Vector2.ONE*0.45
		await shot("arena-"+String(choice.id))
		game.finish_battle("retreat")
		game.start_world()
		while game.mode!=&"world": await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame
	WorldSession.context = previous
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"capture":captured}
	var file: FileAccess = FileAccess.open("res://artifacts/multi-party-2026-10-10/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("MULTI_PARTY_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
