extends "res://tests/shenchao_tower_suite.gd"
func run()->void:
	var c: WorldContext=WorldContext.new();c.initialize(PartyProgress.serialize(),420,true)
	var abyss: WorldMapDefinition=c.map_definitions.shenchao_abyss
	var scene: WorldMap2D=load(abyss.scene_path).instantiate()
	var errors: Array[String]=WorldValidator.validate(abyss,c.map_definitions,scene)
	check(errors.is_empty(),"secret dungeon native validation "+str(errors))
	var tower: WorldMapDefinition=c.map_definitions.shenchao_tower
	var door: Dictionary=tower.portals.filter(func(p: Dictionary)->bool:return p.id=="abyss_door")[0]
	check(c.navigation.find_portal_approach(tower.map_id,tower.entries.entrance.point,door.point,door.radius,16).ok,"secret portal reachable from tower entrance")
	check(c.navigation.find_portal_approach(abyss.map_id,abyss.entries.entrance.point,abyss.portals[0].point,abyss.portals[0].radius,16).ok,"secret exit reachable")
	c.ensure_map("shenchao_abyss")
	check(c.state.maps.shenchao_abyss.parties.size()==13,"twelve dark hordes plus one unique ghost")
	var stable_paths: bool=true
	var ghosts: int=0;var dark: int=0
	for p: Dictionary in c.state.maps.shenchao_abyss.parties.values():
		stable_paths=stable_paths and not p.representative_path.contains("::") and ResourceLoader.exists(p.representative_path)
		for member: Dictionary in p.deployed_units:
			stable_paths=stable_paths and not member.definition_path.contains("::") and ResourceLoader.exists(member.definition_path)
			if member.definition_id=="tower_ghost":ghosts+=1
			elif member.definition_id=="tower_dark":dark+=1
	check(stable_paths,"all abyss unit references are stable external resources")
	check(not abyss.native_tile_layers.is_empty(),"sprite floor retains native terrain authority")
	check(ghosts==1 and dark>=144 and dark<=216,"one ultimate enemy and 144-216 dark monsters")
	var unit: UnitDefinition=load("res://features/units/data/monsters/tower_ghost.tres")
	check(unit.sprite_layout.source_texture==unit.puzzle_monster.enemy_texture,"new boss art shared by world RTS and puzzle")
	check(unit.puzzle_monster.monster_health(100)>load("res://features/units/data/monsters/tower_dark.tres").puzzle_monster.monster_health(99)*8,"ultimate health exceeds eight dark monsters")
	var baseline: WorldMap2D=load("res://artifacts/secret-abyss/before/features/world/data/shenchao_tower.tscn").instantiate()
	var original: WorldMapDefinition=baseline.compile_definition()
	var geometry: bool=original.walkable.size()==tower.walkable.size() and original.blockers.size()==tower.blockers.size()
	for i: int in original.walkable.size():geometry=geometry and original.walkable[i].outer==tower.walkable[i].outer
	for i: int in original.blockers.size():geometry=geometry and original.blockers[i].outer==tower.blockers[i].outer
	check(geometry,"existing tower navigation untouched")
	var legacy: WorldContext=WorldContext.new();legacy.initialize(PartyProgress.serialize(),420,true,{"shenchao_tower":original});legacy.ensure_map("shenchao_tower")
	var snapshot: Dictionary=legacy.snapshot()
	check(snapshot.maps.shenchao_tower.parties.size()==48,"legacy fixture includes tower dark hordes")
	c.publish(snapshot.duplicate(true));c.state.active_encounter={"encounter_id":"locked"};c.ensure_map("shenchao_tower")
	check(c.state.maps.shenchao_tower==snapshot.maps.shenchao_tower,"locked encounter preserves retired dark parties")
	c.state.active_encounter={};c.paused=true;c.ensure_map("shenchao_tower")
	check(c.state.maps.shenchao_tower==snapshot.maps.shenchao_tower,"paused save defers dark relocation")
	c.paused=false;c.ensure_map("shenchao_tower")
	check(c.state.maps.shenchao_tower.parties.size()==36 and c.state.maps.shenchao_tower.slots.size()==36,"only retired dark slots removed")
	var preserved: bool=true
	for id: String in c.state.maps.shenchao_tower.parties:preserved=preserved and c.state.maps.shenchao_tower.parties[id]==snapshot.maps.shenchao_tower.parties[id]
	check(preserved and c.state.progress==snapshot.progress and c.state.maps.river_bay==snapshot.maps.river_bay,"all other parties farm and progress unchanged")
	c.ensure_map("shenchao_abyss");var stable: Dictionary=c.snapshot();c.ensure_map("shenchao_abyss");c.ensure_map("shenchao_tower")
	check(c.snapshot()==stable,"repeat migration idempotent")
	c.save.enabled=true;c.save.path="user://abyss_suite_%d.dat"%OS.get_process_id()
	c.state.player.map_id="shenchao_tower";c.state.player.position=door.point;c.state.portal_protection=""
	var entered: Dictionary=c.begin_portal("abyss_door");check(entered.ok,"disk checkpoint before secret entry")
	if entered.ok:c.complete_portal(c.state.control_owner)
	check(c.save.load_best().maps.shenchao_abyss.parties.size()==13,"secret population persists")
	c.state.player.position=abyss.portals[0].point;c.state.portal_protection=""
	var back: Dictionary=c.begin_portal("abyss_exit");check(back.ok,"secret return portal")
	if back.ok:c.complete_portal(c.state.control_owner)
	check(c.state.player.map_id=="shenchao_tower","returns to deepest tower")
	scene.free();baseline.free()
	await runtime(1)
	await runtime(2)
	print("ABYSS_RESULT ",passed," passed / ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)
