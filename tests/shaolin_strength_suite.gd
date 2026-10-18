extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS | ",title)
	else: failed+=1; push_error("FAIL | "+title)
func _ready() -> void: call_deferred("run")
func run() -> void:
	WorldCatalog.initialize()
	var map: WorldMapDefinition = WorldCatalog.definitions.shaolin_temple
	check(WorldValidator.validate(map,WorldCatalog.definitions).is_empty(),"four temple regions pass authoring validation")
	var c: WorldContext = WorldContext.new()
	c.initialize(PartyProgress.serialize(),53100,true)
	c.ensure_map("shaolin_temple")
	var runtime: Dictionary = c.state.maps.shaolin_temple
	check(runtime.parties.size()==30,"temple has30 real parties")
	var histogram: Dictionary = {}
	var species: Dictionary = {}
	var total: int = 0
	var bosses: int = 0
	var legal: bool = true
	for party: Dictionary in runtime.parties.values():
		histogram[party.habitat_id] = int(histogram.get(party.habitat_id,0))+1
		var habitat: WorldHabitat = map.habitat(party.habitat_id)
		legal = legal and c.navigation.segment_legal(map.map_id,party.habitat_id,"SPAWN",party.position,party.position,habitat.profile.radius) and c.navigation.segment_legal(map.map_id,party.habitat_id,"CHASE",party.position,party.position,habitat.profile.radius)
		for member: Dictionary in party.deployed_units:
			total+=1
			species[member.definition_id] = true
			check(member.level>=12 and member.level<=50,"authored enemy level "+member.unit_id)
			if member.definition_id=="shaolin_grandmaster":
				bosses+=1
				check(member.level==50 and member.resolved_stats.health>1000,"guaranteed Lv50 boss has actual scaled combat stats")
	check(histogram=={"front_patrol":10,"bronze_guardian":12,"rear_patrol":6,"inner_masters":2},"front10 middle12 rear6 core2")
	var configured_species: Dictionary = {}
	for habitat: WorldHabitat in map.habitats:
		for party: PartyTemplate in habitat.profile.templates:
			for member: MemberRule in party.members: configured_species[String(member.definition.id)] = true
	check(total>=120 and total<=214 and configured_species.size()==8 and species.size()>=6,"120–214 actual members,8 configured archetypes with weighted roster variation")
	check(bosses==2 and legal,"two Lv50 leaders and all parties on legal terrain")
	var source: WorldMap2D = preload("res://tests/world/legacy_scene_fixture.gd").load_scene("res://artifacts/shaolin-strength-2026-10-10/before.tscn").instantiate() as WorldMap2D
	var old_map: WorldMapDefinition = source.compile_definition()
	source.free()
	check(map.portals==old_map.portals and map.entries==old_map.entries,"temple entrances/arrivals unchanged")
	var geometry_same: bool = true
	for field: String in ["walkable","blockers","safe_areas"]:
		var a: Array = map.get(field)
		var b: Array = old_map.get(field)
		geometry_same = geometry_same and a.size()==b.size()
		for index: int in a.size(): geometry_same = geometry_same and a[index].outer==b[index].outer and a[index].holes==b[index].holes
	check(geometry_same,"player terrain, walls and navigation unchanged")
	var old: WorldContext = WorldContext.new()
	old.initialize(PartyProgress.serialize(),53100,true,{"shaolin_temple":old_map})
	old.ensure_map("shaolin_temple")
	var saved: Dictionary = old.snapshot()
	c.publish(saved)
	c.ensure_map("shaolin_temple")
	check(c.state.maps.shaolin_temple.parties.size()==30 and c.state.maps.river_bay==saved.maps.river_bay,"old temple updates without changing farm/world parties")
	check(c.state.progress==saved.progress and c.state.applied_results==saved.applied_results and c.state.player==saved.player,"player XP/items/vitals/position and reward receipts preserved")
	var once: Dictionary = c.snapshot()
	c.ensure_map("shaolin_temple")
	check(c.snapshot()==once,"temple revision4 migration is idempotent")
	var previous: WorldContext = WorldSession.context
	WorldSession.context = c
	c.state.player.map_id = "shaolin_temple"
	c.state.player.position = map.entries.values()[0].point
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	check(game.world_views.size()==30,"real temple renders30 representatives")
	var start_position: Vector2 = c.state.player.position
	check(c.move_player(start_position+Vector2(-64,-64)).ok,"temple entrance still accepts a legal movement command")
	for frame: int in 30: game._physics_process(1.0/60.0)
	check(c.state.player.position.distance_to(start_position)>20.0,"player actually moves in the populated temple")
	var target: Dictionary = {}
	for party: Dictionary in c.state.maps.shaolin_temple.parties.values():
		if party.habitat_id=="inner_masters": target=party; break
	c.state.player.position = target.position+Vector2(4,0)
	game.world_hero.position = c.state.player.position
	game.world_pose.reset(c.state.player.position)
	game.camera.position = Iso.project(target.position)
	if "--capture" in OS.get_cmdline_user_args():
		game.camera.position = Iso.project(map.extent*0.5)
		game.camera.zoom = Vector2.ONE*0.30
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/shaolin-strength-2026-10-10/temple30.png")
	check(c.encounters.try_begin("player",target.party_id,"player").ok,"Lv50 leader party starts encounter normally")
	c.tick(5.1)
	while game.mode!=&"battle": await get_tree().process_frame
	var actual_boss: TacticalUnit
	for unit: TacticalUnit in game.units.values():
		if unit.definition.id==&"shaolin_grandmaster": actual_boss = unit; break
	check(actual_boss!=null and actual_boss.combat_stats.level==50 and actual_boss.vitals.max_health>1000,"real RTS contains a Lv50 boss, not merely a nameplate")
	if actual_boss!=null:
		var skill_ids: Array[String] = []
		for skill: SkillDefinition in actual_boss.available_skills(): skill_ids.append(String(skill.id))
		check("enemy_copper_summon" in skill_ids and "enemy_critical" in skill_ids and "enemy_shockwave" in skill_ids,"boss has copper reinforcement/critical/shockwave skills")
		var summon: SkillDefinition
		for skill: SkillDefinition in actual_boss.available_skills():
			if skill.id==&"enemy_copper_summon": summon=skill; break
		check(actual_boss.abilities.request(summon,actual_boss.position),"Lv50 boss accepts copper reinforcement cast")
		for frame: int in 50:
			actual_boss.tick(1.0/60.0)
			game._tick_effects(1.0/60.0)
		var reinforcements: Array = game.units.values().filter(func(u: TacticalUnit) -> bool: return u.is_summon and u.summoner_id==actual_boss.unit_id)
		check(reinforcements.size()>=2 and reinforcements.size()<=3 and reinforcements.all(func(u: TacticalUnit) -> bool: return u.team==1 and u.combat_stats.level==50),"boss actually summons2–3 hostile Lv50 copper helpers")
	if "--capture" in OS.get_cmdline_user_args():
		game.camera.position = Iso.project(actual_boss.position)+Vector2(-120,0)
		game.camera.zoom = Vector2.ONE
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/shaolin-strength-2026-10-10/lv50-battle.png")
	game.retreat()
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	check(c.state.control_owner.is_empty() and not c.paused and c.state.maps.shaolin_temple.parties.size()==30,"retreat restores30 parties and releases world control")
	game.queue_free()
	await get_tree().process_frame
	WorldSession.context = previous
	var file: FileAccess = FileAccess.open("res://artifacts/shaolin-strength-2026-10-10/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"parties":30,"members":total,"archetypes":configured_species.size(),"sampled_archetypes":species.size(),"lv50_leaders":2},"\t"))
	print("SHAOLIN_STRENGTH_RESULT passed=",passed," failed=",failed," members=",total)
	get_tree().quit(0 if failed==0 else 1)
