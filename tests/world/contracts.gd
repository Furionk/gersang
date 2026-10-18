class_name WorldContractChecks
extends RefCounted
static func run(check: Callable, progress: Dictionary) -> void:
	var first: WorldContext = WorldContext.new()
	first.initialize(progress,700,true)
	var second: WorldContext = WorldContext.new()
	second.initialize(progress,700,true)
	check.call(first.snapshot() == second.snapshot(),"T03 same seed reproduces members IDs and placement")
	var revision: int = first.state["player_party"]["roster_revision"]
	first.refresh_player(progress)
	check.call(first.state["player_party"]["roster_revision"] == revision,"unchanged roster refresh does not increment revision")
	var baseline: Dictionary = first.snapshot()
	second.tick(1)
	check.call(first.snapshot() == baseline,"T18 independent preview context leaves formal clock RNG and parties unchanged")
	var map: WorldMapDefinition = first.current_map()
	check.call(map.extent == Vector2(6144,4096),"world extent matches specification")
	var landmark: Vector2 = map.landmarks[0]["point"]
	check.call(map.from_atlas(map.to_atlas(landmark)).distance_to(landmark) < 0.01,"atlas mapping round trip")
	check.call(map.to_atlas(landmark).distance_to(Vector2(0.623,0.40)) < 0.002,"town landmark maps to painted east-coast city")
	for definition: WorldMapDefinition in first.map_definitions.values():
		check.call(WorldValidator.validate(definition,first.map_definitions).is_empty(),"T19 map validation " + definition.map_id)
	var monsters: Array = first.state["maps"]["river_bay"]["parties"].values()
	var monster: Dictionary = monsters[0]
	var active_count: int = first.state["maps"]["river_bay"]["parties"].size()
	first.state["player"]["position"] = monster["position"]+Vector2(5,0)
	first.save.enabled = true
	first.save.path = "user://world_contract_test.dat"
	first.save.fail_writes = 1
	check.call(first.encounters.try_begin("player",monster["party_id"],"player")["reason"] == "CHECKPOINT_FAILED" and first.state["mode"] == "EXPLORING","T09 checkpoint failure releases both parties")
	first.save.enabled = false
	first.state["player"]["cooldown_until_ms"] = 0
	var begun: Dictionary = first.encounters.try_begin("player",monster["party_id"],"player")
	var interrupted: Dictionary = first.snapshot()
	var enemy_members: Array = monster["deployed_units"].duplicate(true)
	check.call(begun["ok"] and interrupted["active_encounter"]["progress_before"] == progress,"T15 interrupted checkpoint has complete pre-battle progress")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var session: Node = tree.root.get_node("WorldSession")
	var old_context: WorldContext = session.get("context")
	var recovery: WorldContext = WorldContext.new()
	recovery.initialize(progress,700,true)
	recovery.publish(interrupted)
	session.set("context",recovery)
	session.call("recover")
	check.call(recovery.state["mode"] == "EXPLORING" and recovery.state["active_encounter"].is_empty() and recovery.party(monster["party_id"])["deployed_units"] == enemy_members,"T15 real recovery restores pre-battle same party without reward")
	check.call(recovery.state["applied_results"].is_empty(),"T15 no reward receipt after interrupted countdown")
	session.set("context",old_context)
	var party_progress: Node = tree.root.get_node("PartyProgress")
	party_progress.call("restore",progress)
	first.encounters.cancel(begun["encounter_id"],"LOAD_FAILED",true)
	check.call(monster["deployed_units"] == enemy_members and first.state["maps"]["river_bay"]["parties"].size() == active_count,"T09 failed battle load keeps original party and slot")
	var active: Dictionary = {}
	for candidate: Dictionary in monsters:
		if candidate["habitat_id"] == "forest": active = candidate; break
	var habitat: WorldHabitat = map.habitat("forest")
	first.state["player"]["protected_until_ms"] = 0
	first.state["player"]["cooldown_until_ms"] = 0
	first.state["player"]["position"] = active["position"]+Vector2(80,0)
	active["think_due_ms"] = 0
	MonsterBrain.tick(first,active,0)
	check.call(active["movement_state"] == "CHASE" or first.state["mode"] == "ENCOUNTER","active monster notices reachable player")
	if first.state["mode"] == "ENCOUNTER": first.encounters.cancel(first.state["active_encounter"]["encounter_id"],"TEST",true)
	active["position"] = habitat.activity_domain.bounds().position+Vector2(-80,120)
	active["movement_state"] = "RETURN"
	active["path"] = PackedVector2Array()
	active["think_due_ms"] = 0
	first.state["player"]["protected_until_ms"] = 999999
	MonsterBrain.tick(first,active,0)
	check.call(not active["path"].is_empty(),"T06 outside activity returns using chase domain")
	var nav: WorldNavigationService = WorldNavigationService.new()
	var small: WorldMapDefinition = WorldMapDefinition.new()
	small.map_id = "narrow"
	small.extent = Vector2(640,640)
	small.grid_size = 16
	small.walkable = [PolygonDomain.rectangle(Rect2(0,0,640,640))]
	small.blockers = [PolygonDomain.rectangle(Rect2(280,0,64,288)),PolygonDomain.rectangle(Rect2(280,352,64,288))]
	nav.register_map(small)
	check.call(nav.find_path("narrow","","PLAYER",Vector2(80,320),Vector2(560,320),8)["ok"],"T05 small representative can cross narrow opening")
	check.call(not nav.find_path("narrow","","PLAYER",Vector2(80,320),Vector2(560,320),40)["ok"],"T05 large radius cannot cross opening")
	var root: WorldMap2D = (load("res://features/world/data/river_bay.tscn") as PackedScene).instantiate() as WorldMap2D
	var original_ids: Array[String] = []
	var habitat_node: WorldAuthorNode
	for child: Node in WorldAuthorTree.nodes(root):
		if child is WorldAuthorNode:
			original_ids.append(child.stable_id)
			if child.kind == WorldAuthorNode.Kind.HABITAT: habitat_node = child
	var authored: WorldMapDefinition=root.compile_definition()
	check.call(authored.habitats.size() == 12 and authored.habitat("monkey_garden_region")!=null and authored.habitat("monkey_garden_hard_region")!=null and authored.habitat("monkey_garden_mania_region")!=null,"author scene preserves eight habitats and adds four monkey zones")
	var clone: WorldAuthorNode = habitat_node.duplicate() as WorldAuthorNode
	# D20/D42: Polygon2D is the native authoring source, not the old hidden Resource domain.
	var clone_area: Polygon2D = clone.get_node("RoamingArea") as Polygon2D
	var original_area: Polygon2D = habitat_node.get_node("RoamingArea") as Polygon2D
	var edited_vertices: PackedVector2Array = clone_area.polygon.duplicate()
	edited_vertices[0] += Vector2(30,30)
	clone_area.polygon = edited_vertices
	check.call(clone_area.polygon[0] != original_area.polygon[0],"T02 per-region variant does not mutate shared source")
	clone.free()
	var habitat_roots: Array[Node] = []
	for child: Node in WorldAuthorTree.nodes(root):
		if child is WorldAuthorNode and child.kind == WorldAuthorNode.Kind.HABITAT: habitat_roots.append(child)
	for child: Node in habitat_roots:
		child.get_parent().remove_child(child); child.free()
	check.call(root.compile_definition().habitats.is_empty(),"deleting last habitat never resurrects definition fallback")
	root.free()
	var invalid: PolygonDomain = PolygonDomain.rectangle(Rect2(0,0,100,100))
	invalid.holes = [PolygonDomain.rectangle(Rect2(0,20,20,20)).outer]
	check.call(not WorldValidator.polygon_errors(invalid,"fixture").is_empty(),"validator rejects hole touching outer border")
	first.state["player"].merge({"position":monster["position"]+Vector2(5,0),"protected_until_ms":0,"cooldown_until_ms":0},true)
	var final_begin: Dictionary = first.encounters.try_begin("player",monster["party_id"],"player")
	first.state["active_encounter"]["state"] = "LOADING"
	first.encounters.mark_in_battle(final_begin["encounter_id"])
	var players: Array[Dictionary] = []
	var defeated: Array[String] = []
	for member: Dictionary in first.state["active_encounter"]["player_party_snapshot"]["deployed_units"]:
		players.append({"unit_id":member["unit_id"],"hp":30.0,"mp":20.0})
	for member: Dictionary in first.state["active_encounter"]["enemy_party_snapshots"][0]["deployed_units"]:
		defeated.append(member["unit_id"])
	var result: Dictionary = {"encounter_id":final_begin["encounter_id"],"outcome":"victory","player_unit_results":players,"defeated_enemy_unit_ids":defeated,"consumed_items":[]}
	check.call(first.settlement.apply(result)["ok"],"T16 committed result before return")
	var committed: Dictionary = first.snapshot()
	var post_recovery: WorldContext = WorldContext.new()
	post_recovery.initialize(progress,700,true)
	post_recovery.publish(committed)
	session.set("context",post_recovery)
	party_progress.call("restore",committed["progress"])
	session.call("recover")
	check.call(post_recovery.state["mode"] == "EXPLORING" and post_recovery.party(monster["party_id"]).is_empty(),"T16 recovery restores consumed enemy and completes return")
	check.call(post_recovery.state["progress"] == committed["progress"] and post_recovery.settlement.apply(result).get("duplicate",false),"T16 committed recovery never awards twice")
	session.set("context",old_context)
	party_progress.call("restore",progress)
	first.encounters.complete_return(result["encounter_id"])
	var file_save: WorldSaveService = WorldSaveService.new()
	file_save.path = "user://world_contract_recovery.dat"
	var complete: Dictionary = first.snapshot()
	complete["revision"] = 20
	check.call(file_save.commit(complete)["ok"],"complete snapshot writes")
	complete["revision"] = 21
	check.call(file_save.commit(complete)["ok"],"complete snapshot replacement retains backup")
	var damaged: FileAccess = FileAccess.open(file_save.path,FileAccess.WRITE)
	damaged.store_var({"version":999},false); damaged.close()
	check.call(file_save.load_best().get("revision",-1) == 20,"corrupt main falls back to complete backup")
	first.ensure_map("well_2")
	first.state["player"].merge({"map_id":"well_2","position":Vector2(320,320),"facing":Vector2.LEFT},true)
	var floor_snapshot: Dictionary = first.snapshot()
	check.call(floor_snapshot["player"]["map_id"] == "well_2" and floor_snapshot["player"]["facing"] == Vector2.LEFT,"T24 floor identity position and facing serialize")
	var floor_restored: WorldContext = WorldContext.new()
	floor_restored.initialize(progress,700,true)
	floor_restored.publish(floor_snapshot)
	check.call(floor_restored.current_map().map_id == "well_2" and floor_restored.state["player"]["position"] == Vector2(320,320),"T24 floor snapshot restores exact position")
	var source_hash: String = FileAccess.get_sha256("res://specs/sources/world_encounter_2026-10-08.md").to_upper()
	check.call(source_hash == "67FF7A813F874197F993637AE3B901A6FED2E455DD7455BD67DF60D8220FF6FD","source document preserved byte-for-byte")
