extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	WorldCatalog.initialize()
	for id: String in ["meadow","mountain","cave","shaolin_temple","millennium_lake"]:
		var choice: EncounterDefinition = WorldCatalog.arenas[id].encounter
		var hash_before: String = FileAccess.get_sha256(choice.battlefield_scene)
		var scene: BattlefieldMap = load(choice.battlefield_scene).instantiate()
		var data: Dictionary = BattlefieldCompiler.compile(scene)
		check(data.errors.is_empty(),id+" native scene validates")
		var owners: bool = true
		for node: Node in WorldAuthorTree.nodes(scene): owners = owners and node.owner==scene
		check(owners,id+" all native nodes saved with scene owners")
		check(scene.get_node("Terrain/Ground").get_used_cells().size()==1672 and data.zones.size()==5,id+" painted terrain and five native markers")
		var ground: GroundMap = GroundMap.new()
		ground.cells=data.cells; ground.blocked.assign(data.blocked)
		var groups: Array[Dictionary] = [{"team":0,"count":12},{"team":1,"count":15},{"team":1,"count":15},{"team":1,"count":15},{"team":1,"count":15}]
		var player_zones: Dictionary = {}
		for seed_value: int in 12:
			var random: RandomNumberGenerator = RandomNumberGenerator.new(); random.seed=seed_value
			var plan: Dictionary = BattlefieldCompiler.deployment(ground,data.zones,groups,random)
			check(plan.ok,id+" 12v60 five-group deployment seed "+str(seed_value))
			if not plan.ok: continue
			player_zones[plan.groups[0].id]=true
			var occupied: Dictionary = {}; var zones: Dictionary = {}; var safe: bool = true
			for group: Dictionary in plan.groups:
				zones[group.id]=true
				for point: Vector2 in group.points:
					if occupied.has(point) or ground._navigation_blocked(Vector2i(point/Iso.CELL)): safe=false
					occupied[point]=true
			check(safe and occupied.size()==72 and zones.size()==5,id+" no overlap / illegal landing")
			random.seed=seed_value
			check(BattlefieldCompiler.deployment(ground,data.zones,groups,random)==plan,id+" battle seed reproducible")
		check(player_zones.size()>=4,id+" player starts vary among primary locations")
		var random: RandomNumberGenerator = RandomNumberGenerator.new(); random.seed=7
		check(BattlefieldCompiler.deployment(ground,data.zones,[{"team":0,"count":12},{"team":1,"count":60}],random).ok,id+" one full 60-enemy batch fits")
		var floor: BattleTileLayer = scene.get_node("Terrain/Ground")
		floor.set_cell(Vector2i(5,5),0,Vector2i(3,0))
		var blocker: BattleTileLayer = scene.get_node("Terrain/Blockers")
		blocker.set_cell(Vector2i(23,15),0,Vector2i.ZERO)
		var walkable: BattleTileLayer = scene.get_node("Terrain/Walkable")
		walkable.erase_cell(Vector2i(23,16))
		var marker: BattleSpawnZone = scene.get_node("SpawnZones/Position_1")
		marker.position+=Vector2(8,4)
		var edited: Dictionary = BattlefieldCompiler.compile(scene)
		check(edited.errors.is_empty(),id+" native brush and marker edits valid")
		ground.blocked.assign(edited.blocked)
		check(ground.is_blocked(Vector2i(23,15)) and ground.is_blocked(Vector2i(23,16)),id+" obstacle brush and walkable hole control navigation")
		check(edited.zones[0].point.is_equal_approx(data.zones[0].point+Iso.unproject(Vector2(8,4))),id+" marker drag uses correct coordinate conversion")
		var packed: PackedScene = PackedScene.new()
		var sandbox: String = "res://artifacts/battlefield-scenes-2026-10-11/%s-edited.tscn" % id
		check(packed.pack(scene)==OK and ResourceSaver.save(packed,sandbox)==OK,id+" artist edits save")
		var reloaded: BattlefieldMap = ResourceLoader.load(sandbox,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
		check(reloaded.get_node("Terrain/Ground").get_cell_atlas_coords(Vector2i(5,5))==Vector2i(3,0) and not reloaded.get_node("Terrain/Walkable").get_used_cells().has(Vector2i(23,16)),id+" tile edits survive reload")
		var sim: Node2D = Node2D.new(); var visual: Node2D = Node2D.new(); add_child(sim); add_child(visual)
		var runtime: GroundMap = GroundMap.new()
		check(runtime.build_scene(sim,visual,reloaded).ok and runtime.floor_layer.get_cell_atlas_coords(Vector2i(5,5))==Vector2i(3,0),id+" runtime consumes saved native tiles, no regeneration")
		var wall: Array[Vector2i] = [Vector2i(15,15)]
		runtime.add_wall(500,wall); runtime.add_wall(501,wall)
		runtime.remove_wall(500)
		check(runtime.dynamic_counts.get(wall[0],0)==1,id+" overlapping ice walls retain occupancy")
		runtime.remove_wall(501)
		check(not runtime.dynamic_counts.has(wall[0]),id+" ice wall cleanup leaves artist terrain")
		await get_tree().process_frame
		sim.free(); visual.free(); ground.free(); scene.free()
		check(FileAccess.get_sha256(choice.battlefield_scene)==hash_before,id+" formal artist map never rewritten")
	# Failure injection: a valid-looking scene with no allied eligible zone must
	# release the real encounter without consuming or rerolling its fixed members.
	var invalid: BattlefieldMap = load("res://features/battle/maps/meadow.tscn").instantiate()
	for node: Node in WorldAuthorTree.nodes(invalid):
		if node is BattleSpawnZone: node.allowed_teams=BattleSpawnZone.Teams.ENEMIES
	var bad_scene: PackedScene = PackedScene.new()
	bad_scene.pack(invalid)
	var bad_path: String = "res://artifacts/battlefield-scenes-2026-10-11/enemies-only.tscn"
	ResourceSaver.save(bad_scene,bad_path); invalid.free()
	var previous: WorldContext = WorldSession.context
	var context: WorldContext = WorldContext.new()
	context.initialize(PartyProgress.serialize(),18181,true)
	WorldSession.context=context
	var game: GameDirector = load("res://main.tscn").instantiate()
	add_child(game); game.audio.muted=true
	while game.mode!=&"world": await get_tree().process_frame
	var enemy: Dictionary = context.state.maps.river_bay.parties.values().filter(func(p: Dictionary) -> bool: return p.habitat_id=="farm")[0]
	var fixed_members: Array = enemy.deployed_units.duplicate(true)
	var progress: Dictionary = context.state.progress.duplicate(true)
	context.state.player.position=enemy.position+Vector2(5,0)
	context.state.player.cooldown_until_ms=0
	context.state.player.protected_until_ms=0
	check(context.encounters.try_begin("player",enemy.party_id,"player").ok,"failure injection acquires real encounter")
	context.state.active_encounter.state="LOADING"
	game.battle_snapshot=context.state.active_encounter.duplicate(true)
	var bad_choice: EncounterDefinition = Catalog.encounters()[0].duplicate(true)
	bad_choice.battlefield_scene=bad_path
	game.start_battle(bad_choice)
	for frame: int in 120:
		if game.mode==&"world" and context.state.control_owner.is_empty(): break
		await get_tree().process_frame
	check(game.mode==&"world" and context.state.control_owner.is_empty() and context.state.active_encounter.is_empty(),"invalid spawn eligibility returns and releases encounter")
	check(context.party(enemy.party_id).deployed_units==fixed_members and context.party(enemy.party_id).life_state=="ACTIVE","invalid battlefield never consumes or rerolls enemy")
	check(context.state.progress==progress and context.state.applied_results.is_empty(),"invalid battlefield never charges resources or awards rewards")
	game.queue_free(); await get_tree().process_frame; WorldSession.context=previous
	print("BATTLEFIELD_SCENE_RESULT passed=",passed," failed=",failed)
	var report: FileAccess = FileAccess.open("res://artifacts/battlefield-scenes-2026-10-11/results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":passed,"failed":failed,"scope":"five native scenes and controlled encounter failure","manual_mouse":"unverified"},"\t")); report.close()
	get_tree().quit(0 if failed==0 else 1)
