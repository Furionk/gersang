extends Node
var game: GameDirector
var failed: int = 0
var passed: int = 0
var capture: bool = false
func _ready() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	get_tree().create_timer(40).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func check(condition: bool, text: String) -> void:
	if condition: passed += 1; print("PASS | ",text)
	else: failed += 1; push_error("FAIL | " + text)
func shot(name_text: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/world/%s.png" % name_text)
func run() -> void:
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode != &"world": await get_tree().process_frame
	game.set_physics_process(false)
	check(game.ground.cells.x > 150 and game.world_views.size() == 22,"large world with 22 animated representatives")
	game.world_context.state["player"]["position"] = Vector2(1250,1650)
	game.world_hero.position = Vector2(1250,1650)
	game.camera.position = Iso.project(game.world_hero.position)
	await get_tree().create_timer(0.2).timeout
	await shot("river-bay")
	var monster: Dictionary = game.world_context.state["maps"]["river_bay"]["parties"].values()[0]
	var party_id: String = monster["party_id"]
	var snapshot_members: Array = monster["deployed_units"].duplicate(true)
	game.world_context.state["player"]["position"] = monster["position"] + Vector2(5,0)
	game.world_hero.position = game.world_context.state["player"]["position"]
	game.camera.position = Iso.project(game.world_hero.position)
	var begin: Dictionary = game.world_context.encounters.try_begin("player",party_id,"player")
	check(begin["ok"],"native game encounter reserves party")
	game._physics_process(1.0/60.0)
	await shot("encounter-countdown")
	game.world_context.tick(5.1)
	while game.mode != &"battle": await get_tree().process_frame
	check(game.living_ids(1).size() == snapshot_members.size(),"real RTS receives original member count")
	var actual_ids: Array[String] = []
	for unit: TacticalUnit in game.units.values():
		if unit.team == 1: actual_ids.append(unit.persistent_unit_id)
	for unit: Dictionary in snapshot_members: check(unit["unit_id"] in actual_ids,"battle preserves " + unit["unit_id"])
	await shot("snapshot-battle")
	game.retreat()
	check(game.world_context.state["applied_results"].size() == 1,"real retreat creates one receipt")
	game.start_world()
	while game.mode != &"world": await get_tree().process_frame
	check(game.world_context.party(party_id)["deployed_units"] == snapshot_members,"real return keeps same enemy party")
	check(game.world_views.size() == 22 and game.world_context.state["control_owner"].is_empty(),"return restores representatives and releases lock")
	game.world_context.state["player"]["position"] = Vector2(4800,1900)
	var portal: Dictionary = game.world_context.begin_portal("town_door")
	check(portal["ok"],"town portal accepted")
	while game.mode != &"world" or game.world_context.state["mode"] != "EXPLORING": await get_tree().process_frame
	check(game.world_context.state["player"]["map_id"] == "qingling_town","town renders linked map")
	check(game.world_pose.previous == game.world_pose.current and game.world_pose.current == game.world_hero.position,"MOVE-10 actual portal resets sprite interpolation")
	await shot("qingling-town")
	for step: Array in [["qingling_town",Vector2(768,940),"town_exit","river_bay"],["river_bay",Vector2(2800,3260),"well_door","well_1"],["well_1",Vector2(1800,1300),"down","well_2"],["well_2",Vector2(240,240),"up","well_1"]]:
		game.world_context.state["player"]["position"] = step[1]
		var transition: Dictionary = game.world_context.begin_portal(step[2])
		check(transition["ok"],"portal " + step[2])
		while game.mode != &"world" or game.world_context.state["mode"] != "EXPLORING": await get_tree().process_frame
		check(game.world_context.state["player"]["map_id"] == step[3],"map restored " + step[3])
		check(game.world_pose.previous == game.world_pose.current,"MOVE-10 floor transition never interpolates across maps")
		await shot(step[3])
	# Same-tick annihilation must not choose victory.
	game.start_battle(Catalog.encounters()[0],true)
	while game.mode != &"battle": await get_tree().process_frame
	for unit: TacticalUnit in game.units.values(): unit.vitals.health = 0
	game._physics_process(1.0/60.0)
	check(game.last_result == "defeat","T12 same-tick mutual defeat policy")
	print("WORLD_INTEGRATION_RESULT ",passed," passed / ",failed," failed")
	get_tree().quit(0 if failed == 0 else 1)
