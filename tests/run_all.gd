extends SceneTree
var passed: int = 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var started: int

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, caption: String) -> void:
	observations.append({"test":caption,"pass":condition})
	if condition:
		passed += 1
		print("PASS | ",caption)
	else:
		failures.append(caption)
		push_error("FAIL | " + caption)

func result_for(context: WorldContext, outcome: String) -> Dictionary:
	var session: Dictionary = context.state["active_encounter"]
	var players: Array[Dictionary] = []
	var enemies: Array[String] = []
	for member: Dictionary in session["player_party_snapshot"]["deployed_units"]:
		players.append({"unit_id":member["unit_id"],"hp":30.0,"mp":20.0})
	for member: Dictionary in session["enemy_party_snapshots"][0]["deployed_units"]:
		enemies.append(member["unit_id"])
	return {"encounter_id":session["encounter_id"],"outcome":outcome,"player_unit_results":players,"defeated_enemy_unit_ids":enemies,"consumed_items":[]}

func begin(context: WorldContext, monster: Dictionary) -> Dictionary:
	context.state["player"]["position"] = monster["position"] + Vector2(5,0)
	context.state["player"]["protected_until_ms"] = 0
	context.state["player"]["cooldown_until_ms"] = 0
	return context.encounters.try_begin("player",monster["party_id"],"player")

func enter_battle(context: WorldContext, id: String) -> void:
	context.state["active_encounter"]["state"] = "LOADING"
	context.encounters.mark_in_battle(id)

func run() -> void:
	started = Time.get_ticks_msec()
	await process_frame
	var progress: Node = root.get_node("PartyProgress")
	check(not progress.persistence_enabled,"isolation: runner cannot overwrite player progress")
	var definition: UnitDefinition = UnitDefinition.new()
	definition.base_power = 8400
	check(PowerCalculator.unit_rating(definition,1) == 8400,"T01 authored unit rating")
	var fixture_index: int = 0
	for fixture: Array in [[8400,5000,5000],[7200,7200,7200,7200,7200,7200,10800,10800],[7200,7200,7200,7200,7200,7200,7200,7200,10800,10800,12000],[80,80,80,80],[320,320,320,320]]:
		var units: Array[Dictionary] = []
		for rating: int in fixture:
			units.append({"rated_power":rating})
		var totals: Array[int] = [18400,64800,91200,320,1280]
		check(PowerCalculator.make_summary({"deployed_units":units,"reserve_units":[{"rated_power":999999}]})["power"] == totals[fixture_index],"T01 fixed fixture " + str(fixture))
		fixture_index += 1
	check(PowerCalculator.make_summary({})["power"] == 0,"T01 empty party")
	var context: WorldContext = WorldContext.new()
	context.initialize(progress.serialize(),1234,true)
	var original: Dictionary = context.snapshot()
	var monsters: Array = context.state["maps"]["river_bay"]["parties"].values()
	var configured_population: int = 0
	for habitat: WorldHabitat in context.current_map().habitats: configured_population += habitat.profile.target_party_count
	check(monsters.size() == configured_population,"T02 exterior spawns every configured independent party")
	var monster: Dictionary = monsters[0]
	var id: String = monster["party_id"]
	var members: Array = monster["deployed_units"].duplicate(true)
	for i: int in 180:
		context.tick(1.0/60.0)
	check(monster["position"] != original["maps"]["river_bay"]["parties"][id]["position"],"world roaming is not stationary")
	check(monster["deployed_units"] == members,"T03 movement never rerolls composition")
	check(context.navigation.segment_legal("river_bay","","PLAYER",Vector2(4800,1800),Vector2(4800,1900),16),"T25 player can enter safe town area")
	check(not context.navigation.segment_legal("river_bay","forest","CHASE",Vector2(4800,1800),Vector2(4800,1900),16),"safe town excludes monsters")
	var started_encounter: Dictionary = begin(context,monster)
	check(started_encounter["ok"],"T07 passive encounter starts")
	var encounter_id: String = started_encounter.get("encounter_id","")
	check(context.encounters.try_begin("player",monsters[1]["party_id"],"monster")["reason"] == "BUSY","T07 same tick second request BUSY")
	check(context.begin_portal("town_door")["reason"] == "BUSY","T21 encounter owns portal lock")
	check(context.state["maps"]["river_bay"]["slots"][monster["slot_id"]]["state"] == "OCCUPIED","T10 reserved party occupies spawn slot")
	context.encounters.cancel(encounter_id)
	check(context.encounters.cancel(encounter_id)["reason"] == "STALE_TOKEN","T08 old cancellation is rejected")
	var next: Dictionary = begin(context,monster)
	enter_battle(context,next["encounter_id"])
	var clock: int = context.state["world_time_ms"]
	context.tick(1)
	check(context.state["world_time_ms"] == clock,"battle freezes world clock")
	var result: Dictionary = result_for(context,"victory")
	var settled: Dictionary = context.settlement.apply(result)
	check(settled["ok"],"T11 victory commits")
	var post: Dictionary = context.snapshot()
	check(context.settlement.apply(result).get("duplicate",false) and context.snapshot() == post,"T11 duplicate result has no side effects")
	check(context.party(id).is_empty() and context.state["maps"]["river_bay"]["slots"][monster["slot_id"]]["state"] == "COOLDOWN","victory consumes original party and schedules slot")
	check(context.encounters.complete_return(result["encounter_id"]),"T22 complete_return releases reservations")
	check(not context.encounters.complete_return(result["encounter_id"]),"T22 old return cannot unlock another encounter")
	var remaining: Dictionary = context.state["maps"]["river_bay"]["parties"].values()[0]
	var retry_begin: Dictionary = begin(context,remaining)
	enter_battle(context,retry_begin["encounter_id"])
	context.save.enabled = true
	context.save.path = "user://world_spec_test.dat"
	context.save.fail_writes = 2
	var retry_result: Dictionary = result_for(context,"retreat")
	check(not context.settlement.apply(retry_result)["ok"],"T14 injected save failure holds encounter")
	var candidate: Dictionary = context.settlement.pending[retry_result["encounter_id"]].duplicate(true)
	check(not context.settlement.apply(retry_result)["ok"] and context.settlement.pending[retry_result["encounter_id"]] == candidate,"T23 retry retains identical candidate and RNG")
	check(context.settlement.apply(retry_result)["ok"],"T23 third write succeeds")
	context.encounters.complete_return(retry_result["encounter_id"])
	check(context.party(remaining["party_id"])["deployed_units"] == remaining["deployed_units"],"retreat preserves original members")
	var saved: Dictionary = context.save.load_best()
	check(not saved.is_empty() and saved["revision"] == candidate["revision"],"T16 valid committed save reloads")
	context.save.enabled = false
	var authored_town_portal: Array[Dictionary] = WorldCatalog.definitions["river_bay"].portals.filter(func(p: Dictionary) -> bool: return p.id=="town_door")
	context.state["player"]["position"] = authored_town_portal[0].point
	context.state["player"]["map_id"] = "river_bay"
	var portal: Dictionary = context.begin_portal("town_door")
	check(portal["ok"] and context.state["player"]["map_id"] == "qingling_town","T13 enters town at linked entry")
	check(context.begin_portal("town_exit")["reason"] == "BUSY","T21 portal retains transition control")
	if portal.get("ok",false): context.complete_portal(portal["token"])
	check(context.state["maps"]["river_bay"]["parties"].size() == configured_population-1,"T13 map swap preserves population after one defeated party")
	var nav: WorldNavigationService = WorldNavigationService.new()
	var map: WorldMapDefinition = WorldMapDefinition.new()
	map.map_id = "nav_fixture"
	map.extent = Vector2(640,640)
	map.grid_size = 32
	var domain: PolygonDomain = PolygonDomain.rectangle(Rect2(0,0,640,640))
	domain.holes = [PolygonDomain.rectangle(Rect2(200,160,160,320)).outer]
	map.walkable = [domain]
	nav.register_map(map)
	var path: Dictionary = nav.find_path(map.map_id,"","PLAYER",Vector2(80,320),Vector2(560,320),8)
	check(path["ok"] and path["points"].size() >= 3,"T04 route detours around a hole")
	var legal: bool = true
	for i: int in range(1,path["points"].size()):
		legal = legal and nav.segment_legal(map.map_id,"","PLAYER",path["points"][i-1],path["points"][i],8)
	check(legal,"T04 every route segment legal")
	check(not nav.segment_legal(map.map_id,"","PLAYER",Vector2(80,320),Vector2(560,320),8),"T25 direct segment through hole rejected")
	WorldContractChecks.run(check,progress.serialize())
	var movement_metrics: Dictionary = WorldMovementChecks.run(check,progress.serialize())
	print("MOVEMENT_METRICS ",JSON.stringify(movement_metrics))
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if "--all" in arguments:
		for scene: String in ["test_runner","v2_suite","progression_suite","selection_input_regression","window_resize_regression","ice_wall_ai_regression","world_hud_suite","items_suite","character_sheet_suite","ui_feedback_suite","ui_humanized_suite","combat_ux_suite","party_polish_suite","world_direction_regression","battle_presentation_suite","blast_radial_suite","native_tilemap_suite","world_scenery_suite","map_projection_suite","human_authoring_suite","river_enrichment_suite","background_music_suite","unit_voice_suite","unit_voice_real_assets_suite","malfory_voice_suite","multi_party_suite","monster_layout_suite","additive_population_suite","battlefield_scene_suite","battlefield_alignment_suite","editor_workflow_core_suite","editor_workflow_data_suite","dynamic_reinforcement_suite","depth_sorting_suite","new_units_suite","mercenary_storage_suite","roster_effects_polish_suite","kohime_strength_suite","millennium_ecology_suite","victory_cleanup_suite","malfory_suite"]:
			var output: Array = []
			var code: int = OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://artifacts/world/%s-engine.log" % scene),"--quit-after","18000","res://tests/%s.tscn" % scene]),output,true)
			var engine_log: String = FileAccess.get_file_as_string("res://artifacts/world/%s-engine.log" % scene)
			var clean: bool = not engine_log.contains("ERROR:") and not engine_log.contains("SCRIPT ERROR") and not engine_log.contains("FAIL |")
			check(code == 0 and clean and engine_log.contains("PASS"),"legacy regression " + scene + " exit " + str(code))
			var log: FileAccess = FileAccess.open("res://artifacts/world/%s.log" % scene,FileAccess.WRITE)
			log.store_string("\n".join(output))
		var movement_output: Array = []
		var movement_code: int = OS.execute(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",ProjectSettings.globalize_path("res://artifacts/world/movement-scene-engine.log"),"res://tests/world/movement_regression.tscn"]),movement_output,true)
		var movement_log: String = FileAccess.get_file_as_string("res://artifacts/world/movement-scene-engine.log")
		check(movement_code==0 and not movement_log.contains("ERROR:") and movement_log.contains("WORLD_MOVEMENT_RESULT"),"movement scene regression including actual sprite/camera and 30/120 FPS")
	var report: Dictionary = {"engine":Engine.get_version_info()["string"],"passed":passed,"failed":failures.size(),"failures":failures,"tests":observations,"movement_metrics":movement_metrics,"elapsed_ms":Time.get_ticks_msec()-started,"manual_gates":{"T17":"unverified","T20":"unverified","atlas_walkthrough":"unverified"}}
	var file: FileAccess = FileAccess.open("res://artifacts/world/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("WORLD_SUITE_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
