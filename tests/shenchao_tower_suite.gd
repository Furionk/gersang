extends Node
var passed: int=0
var failed: int=0
func check(ok: bool,label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	var c: WorldContext=WorldContext.new();c.initialize(PartyProgress.serialize(),420,true)
	var tower: WorldMapDefinition=c.map_definitions.shenchao_tower
	var scene: WorldMap2D=load(tower.scene_path).instantiate()
	var errors: Array[String]=WorldValidator.validate(tower,c.map_definitions,scene)
	check(errors.is_empty(),"native tower validation "+str(errors))
	check(tower.habitats.size()==16,"sixteen tower groups after dark relocation")
	var before: WorldMap2D=load("res://artifacts/shenchao-tower/before/river_bay.tscn").instantiate()
	var old: WorldMapDefinition=before.compile_definition()
	var river: WorldMapDefinition=c.map_definitions.river_bay
	check(WorldValidator.validate(river,c.map_definitions).is_empty(),"river validator "+str(WorldValidator.validate(river,c.map_definitions)))
	check(river.habitats.size()==old.habitats.size(),"existing river habitats preserved")
	var geometry_same: bool=true
	for i: int in old.walkable.size(): geometry_same=geometry_same and old.walkable[i].outer==river.walkable[i].outer
	for i: int in old.blockers.size(): geometry_same=geometry_same and old.blockers[i].outer==river.blockers[i].outer
	check(geometry_same,"river native navigation preserved")
	for door: Dictionary in old.portals: check(door in river.portals,"existing portal retained "+door.id)
	c.ensure_map("shenchao_tower")
	check(c.state.maps.shenchao_tower.parties.size()==36,"36 tower parties; dark hordes moved into secret dungeon")
	var boss_count: int=0
	for party: Dictionary in c.state.maps.shenchao_tower.parties.values():
		var stable: bool=true
		for member: Dictionary in party.deployed_units:
			stable=stable and not member.definition_path.contains("::")
			if member.definition_id.begins_with("tower_3_"): boss_count+=1
		check(stable,"stable external members "+party.habitat_id)
	check(boss_count==24,"24 Lv95 kings in twelve fresh parties")
	var dark_unit: UnitDefinition=load("res://features/units/data/monsters/tower_dark.tres")
	var dark_parties: int=0
	c.ensure_map("shenchao_abyss")
	for party: Dictionary in c.state.maps.shenchao_abyss.parties.values():
		if party.habitat_id.begins_with("dark_guard_"):
			dark_parties+=1
			check(party.deployed_units.size()>=12 and party.deployed_units.size()<=18,"dark group size 12-18")
	check(dark_parties==12 and dark_unit.sprite_tint.r<0.1,"twelve near-black challenge parties")
	check(dark_unit.puzzle_monster.dark_monster and dark_unit.puzzle_monster.monster_health(99)>load("res://features/puzzle/data/tower_tier_3.tres").monster_health(95),"dark monster exceeds king HP")
	var old_tower_scene: WorldMap2D=load("res://artifacts/tower-dark/before/shenchao_tower.tscn").instantiate()
	var legacy_context: WorldContext=WorldContext.new()
	legacy_context.initialize(PartyProgress.serialize(),420,true,{"shenchao_tower":old_tower_scene.compile_definition()})
	legacy_context.ensure_map("shenchao_tower")
	var old_state: Dictionary=legacy_context.snapshot()
	var migrated: WorldContext=WorldContext.new();migrated.initialize(PartyProgress.serialize(),420,true)
	migrated.publish(old_state.duplicate(true))
	migrated.ensure_map("shenchao_tower")
	check(migrated.state.maps.shenchao_tower.parties.size()==36,"old save adds missing king slots")
	var preserved: bool=true
	for id: String in old_state.maps.shenchao_tower.parties:
		var old_party: Dictionary=old_state.maps.shenchao_tower.parties[id]
		var now_party: Dictionary=migrated.state.maps.shenchao_tower.parties[id]
		preserved=preserved and now_party.position==old_party.position and now_party.deployed_units.size()==old_party.deployed_units.size() and now_party.slot_id==old_party.slot_id
	check(preserved and migrated.state.progress==old_state.progress,"old party identity positions composition and player progress preserved")
	var locked: WorldContext=WorldContext.new();locked.initialize(PartyProgress.serialize(),420,true)
	locked.publish(old_state.duplicate(true));locked.state.active_encounter={"encounter_id":"test_lock"}
	locked.ensure_map("shenchao_tower")
	check(locked.state.maps.shenchao_tower==old_state.maps.shenchao_tower,"encounter lock defers population and balance sync")
	old_tower_scene.free()
	var king: UnitDefinition=load("res://features/units/data/monsters/tower_3_0.tres")
	var guard: UnitDefinition=load("res://features/units/data/monsters/tower_0_1.tres")
	check(king.puzzle_monster.monster_health(90)>guard.puzzle_monster.monster_health(30)*5,"king is substantially tougher")
	check(guard.puzzle_monster.monster_health(39)>guard.puzzle_monster.monster_health(30),"actual level changes HP")
	var model: PuzzleCombat=PuzzleCombat.new()
	model.setup([{"hp":100.0,"max_hp":100.0,"attack":10.0,"element":0}], [{"hp":1000.0,"max_hp":1000.0,"element":0,"rules":king.puzzle_monster},{"hp":1000.0,"max_hp":1000.0,"element":1,"rules":guard.puzzle_monster}],guard.puzzle_monster,1)
	check(model.enemies[0].cooldown_seconds==2.0 and model.enemies[1].cooldown_seconds==8,"mixed kings retain independent cooldowns")
	check(model.enemies[0].attack_fraction==0.14 and model.enemies[1].attack_fraction==0.05,"mixed enemy damage retains per-unit rules")
	c.save.enabled=true;c.save.path="user://tower_suite_%d.dat"%OS.get_process_id()
	var door: Dictionary=river.portals.filter(func(p: Dictionary) -> bool: return p.id=="tower_door")[0]
	check(c.navigation.find_portal_approach("river_bay",river.entries.start.point,door.point,door.radius,16).ok,"entrance reachable from river start")
	c.state.player.position=door.point
	var entered: Dictionary=c.begin_portal("tower_door")
	check(entered.ok,"disk-backed tower entry")
	if entered.ok: c.complete_portal(c.state.control_owner)
	check(c.state.player.map_id=="shenchao_tower","tower is active map")
	check(c.save.load_best().maps.shenchao_tower.parties.size()==36,"tower population persists on disk")
	var exit: Dictionary=tower.portals[0]
	c.state.player.position=exit.point;c.state.portal_protection=""
	var returned: Dictionary=c.begin_portal(exit.id)
	check(returned.ok,"tower return portal succeeds")
	if returned.ok: c.complete_portal(c.state.control_owner)
	check(c.state.player.map_id=="river_bay","return restores river")
	scene.free();before.free()
	await runtime()
	await runtime(1)

	print("TOWER_RESULT ",passed," passed / ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/shenchao-tower/"+label+".png")
func runtime(kind: int=0) -> void:
	var dark: bool=kind==1
	WorldSession.context.initialize(PartyProgress.serialize(),42047,true)
	var game: GameDirector=load("res://main.tscn").instantiate();add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	var c: WorldContext=game.world_context
	var entrance: Dictionary=c.current_map().portals.filter(func(p: Dictionary)->bool:return p.id=="tower_door")[0]
	game.set_process(false)
	game.camera.position=Iso.project(entrance.point)+Vector2(0,-170)
	game.camera.zoom=Vector2.ONE
	await capture("river-celestial-entrance")
	game.set_process(true)
	c.state.player.position=entrance.point
	check(c.begin_portal("tower_door").ok,"live director starts tower entry")
	for i: int in 240:
		await get_tree().process_frame
		if game.mode==&"world" and c.state.mode=="EXPLORING": break
	check(c.state.player.map_id=="shenchao_tower" and game.mode==&"world","live tower map loaded")
	await capture("tower-entry")
	game.set_process(false)
	game.camera.position=Iso.project(Vector2(1280,1920)); game.camera.zoom=Vector2.ONE*0.16
	await capture("tower-celestial-overview")
	game.camera.zoom=Vector2.ONE*0.55
	game.camera.position=Iso.project(Vector2(1280,100))+Vector2(0,-350)
	await capture("tower-celestial-crown")
	game.set_process(true)
	var map_id: String="shenchao_tower"
	if kind>0:
		var secret: Dictionary=c.current_map().portals.filter(func(p: Dictionary)->bool:return p.id=="abyss_door")[0]
		c.state.player.position=secret.point;c.state.portal_protection=""
		check(c.begin_portal("abyss_door").ok,"live secret dungeon portal")
		for i: int in 240:
			await get_tree().process_frame
			if game.mode==&"world" and c.state.mode=="EXPLORING":break
		map_id="shenchao_abyss"
		check(c.state.player.map_id==map_id,"secret dungeon loaded")
		game.set_process(false);game.camera.position=Iso.project(Vector2(1024,1024));game.camera.zoom=Vector2.ONE*0.32
		await capture("abyss-overview")
		game.set_process(true)
	var party: Dictionary={}
	for candidate: Dictionary in c.state.maps[map_id].parties.values():
		if candidate.habitat_id==("final_ghost" if kind==2 else "dark_guard_0" if dark else "tier_3_0"): party=candidate;break
	c.state.player.position=party.position+Vector2(2,0);c.state.player.protected_until_ms=0;c.state.player.cooldown_until_ms=0
	check(c.encounters.try_begin("player",party.party_id,"player").ok,"king encounter starts")
	for i: int in 310:
		if game.mode not in [&"world",&"countdown"]: break
		game._physics_process(1.0/60.0);await get_tree().process_frame
	while game.mode==&"loading": await get_tree().process_frame
	check(game.mode==&"battle","king native RTS battlefield loaded")
	if game.mode==&"battle":
		await capture("tower-celestial-arena")
		var king: TacticalUnit
		for unit: TacticalUnit in game.units.values():
			if String(unit.definition.id)==("tower_ghost" if kind==2 else "tower_dark" if dark else "tower_3_0"): king=unit
		check(king!=null,"king instantiated with stable definition")
		if king!=null:
			game.basic_attack(king,game.get_unit(game.roster_ids[0]),0)
			while game.puzzle_battle.phase!="play": await get_tree().process_frame
			var enemies: Array[Dictionary]=game.puzzle_battle.controller.combat.enemies
			check(enemies.size()==1 if kind==2 else enemies.size()>=12 and enemies.size()<=18 if dark else enemies.size()==6,"dark horde or expanded king party enters together")
			var found: bool=false
			for foe: Dictionary in enemies:
				if kind==2: found=foe.level==100 and foe.cooldown_seconds==1.6 and foe.get("texture")!=null
				elif dark: found=foe.get("dark",false) and foe.level==99
				elif String(foe.name).contains("王"): found=foe.level==95 and foe.cooldown_seconds==2.0
			check(found,"live king retains Lv95 and 2 second clock")
			await capture("final-ghost" if kind==2 else "dark-horde" if dark else "king-battle")
			for foe: Dictionary in enemies: foe.hp=0
			game.puzzle_battle.controller.stage="actions";game.puzzle_battle.controller.action_queue.clear()
			while game.mode==&"puzzle": await get_tree().process_frame
			check(game.mode==&"battle","king death returns to original battlefield")
			game._physics_process(0.01);game._physics_process(2.01)
			check(game.mode==&"results" and game.last_result=="victory","king battle uses normal victory settlement")
			var slot: Dictionary=c.state.maps[map_id].slots[party.slot_id]
			var delay: int=int(slot.respawn_due_ms)-int(c.state.world_time_ms)
			check(slot.state=="COOLDOWN" and (delay>=90000 and delay<=120000 if kind==2 else delay>=20000 and delay<=30000),"actual settlement uses configured respawn window")
	game.queue_free();await get_tree().process_frame
