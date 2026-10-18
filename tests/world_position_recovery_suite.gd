extends Node
var passed: int = 0
var failures: Array[String] = []
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS | ",title)
	else: failures.append(title); push_error("FAIL | "+title)
func _ready() -> void: call_deferred("run")
func run() -> void:
	var file: FileAccess = FileAccess.open("user://world_state.dat",FileAccess.READ)
	var saved: Dictionary = file.get_var(false)
	file.close()
	var hash_before: String = FileAccess.get_sha256("user://world_state.dat")
	var original_context: WorldContext = WorldSession.context
	var c: WorldContext = WorldContext.new()
	c.initialize(saved.progress,42047,true)
	WorldSession.context = c
	check(WorldSession.validate_content(saved),"actual saved progress is compatible despite recoverable monster poses")
	c.publish(saved)
	PartyProgress.restore(saved.progress)
	WorldSession.recover()
	check(not c.paused and c.state.mode=="EXPLORING" and c.state.control_owner.is_empty(),"recovery leaves movement/encounter control unlocked")
	check(c.state.progress==saved.progress and c.state.player==saved.player and c.state.applied_results==saved.applied_results,"all player stats/items/position/reward receipts retained")
	var valid: bool = true
	var identical: bool = true
	for map_id: String in c.state.maps:
		for party: Dictionary in c.state.maps[map_id].parties.values():
			var habitat: WorldHabitat = c.map_definitions[map_id].habitat(party.habitat_id)
			valid = valid and c.navigation.segment_legal(map_id,party.habitat_id,"CHASE",party.position,party.position,habitat.profile.radius)
			identical = identical and party.deployed_units==saved.maps[map_id].parties[party.party_id].deployed_units
	check(valid,"every loaded monster pose is legal after repair")
	check(identical,"repair never rerolls enemies or changes levels/IDs/stats")
	var once: Dictionary = c.snapshot()
	check(not WorldPositionRecovery.repair(c) and once==c.snapshot(),"repair is idempotent")
	var fixture_map: WorldMapDefinition = WorldMapDefinition.new()
	fixture_map.map_id = "river_bay"
	fixture_map.extent = Vector2(640,640)
	fixture_map.walkable = [PolygonDomain.rectangle(Rect2(0,0,640,640))]
	var fixture_habitat: WorldHabitat = WorldHabitat.new()
	fixture_habitat.habitat_id = "fixture"
	fixture_habitat.spawn_domain = PolygonDomain.rectangle(Rect2(96,96,448,448))
	fixture_habitat.activity_domain = PolygonDomain.rectangle(Rect2(64,64,512,512))
	fixture_habitat.chase_domain = PolygonDomain.rectangle(Rect2(192,128,256,384))
	fixture_habitat.profile = c.map_definitions.river_bay.habitats[0].profile.duplicate(true) as SpawnProfile
	fixture_habitat.profile.target_party_count = 4
	fixture_habitat.profile.rules.active = false
	fixture_map.habitats = [fixture_habitat]
	var fixture: WorldContext = WorldContext.new()
	fixture.initialize(saved.progress,1000,true,{"river_bay":fixture_map})
	fixture.state.player.position = Vector2(608,608)
	var always_legal: bool = true
	for frame: int in 600:
		fixture.tick(1.0/60.0)
		for party: Dictionary in fixture.state.maps.river_bay.parties.values():
			always_legal = always_legal and fixture.navigation.segment_legal("river_bay","fixture","CHASE",party.position,party.position,fixture_habitat.profile.radius)
	check(fixture.state.maps.river_bay.parties.size()==4 and always_legal,"non-nested draft cannot spawn/roam monsters outside the valid pursuit intersection")
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.camera.force_update_scroll()
	await get_tree().process_frame
	var start: Vector2 = c.state.player.position
	var goal: Vector2 = start+Vector2(100,-100)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.get_canvas_transform()*Iso.project(goal)
	get_viewport().push_input(event,false)
	await get_tree().process_frame
	check(not c.player_path.is_empty(),"real left mouse input issues a world movement route")
	for frame: int in 30: game._physics_process(1.0/60.0)
	check(c.state.player.position.distance_to(start)>20.0,"actual player moves after the click")
	var monster: Dictionary = c.state.maps.river_bay.parties.values()[0]
	c.state.player.position = monster.position+Vector2(5,0)
	c.state.player.protected_until_ms = 0
	c.state.player.cooldown_until_ms = 0
	check(c.encounters.try_begin("player",monster.party_id,"player").ok,"encounter checkpoint succeeds with recovered save")
	c.tick(5.1)
	while game.mode!=&"battle": await get_tree().process_frame
	check(game.living_ids(1).size()>0,"recovered world enters actual RTS battle")
	check(FileAccess.get_sha256("user://world_state.dat")==hash_before,"diagnostics/tests did not overwrite formal saved progress")
	game.queue_free()
	await get_tree().process_frame
	WorldSession.context = original_context
	print("POSITION_RECOVERY_RESULT passed=",passed," failed=",failures.size()," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
