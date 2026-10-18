extends Node
## Real disk persistence, retired school references, and actual director lifecycle.
const FIXTURE: String = "res://artifacts/entry-fix-2026-10-14/before/world_state.dat"
var passed: int = 0
var failed: int = 0
var game: GameDirector
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void:
	get_tree().create_timer(100).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func run() -> void:
	var c: WorldContext = WorldContext.new()
	c.initialize(PartyProgress.serialize(),42047,true)
	var initial: Dictionary = c.snapshot()
	for map_id: String in c.map_definitions: c.ensure_map(map_id)
	var fresh: Dictionary = c.snapshot()
	var stable: bool = true
	for runtime: Dictionary in fresh.maps.values():
		for party: Dictionary in runtime.parties.values():
			stable = stable and not party.representative_path.contains("::") and ResourceLoader.exists(party.representative_path)
			for member: Dictionary in party.deployed_units:
				stable = stable and not member.definition_path.contains("::") and ResourceLoader.exists(member.definition_path)
	check(stable,"all shipped populations save stable external unit resources")
	# Synthetic retired IDs exercise the migration even without a local save.
	var legacy: Dictionary = fresh.duplicate(true)
	var school: Dictionary = legacy.maps.hogwarts
	for party: Dictionary in school.parties.values():
		for member: Dictionary in party.deployed_units:
			var old: String = "res://features/world/data/hogwarts.tscn::retired_"+member.definition_id
			if party.representative_path==member.definition_path: party.representative_path=old
			member.definition_path=old
	check(UnitResourcePaths.rewrite_saved_paths(legacy),"retired inline school references migrate")
	check(legacy==fresh,"migration changes paths only, preserving every gameplay field")
	check(not UnitResourcePaths.rewrite_saved_paths(legacy),"migration is idempotent")
	var unsupported: Dictionary = {"definition_path":"res://features/world/data/hogwarts.tscn::unknown","definition_id":"school_dementor","definition_revision":999}
	check(not UnitResourcePaths.rewrite_saved_paths(unsupported),"unknown content revisions remain protected")
	unsupported.definition_id="unapproved_species"; unsupported.definition_revision=1
	check(not UnitResourcePaths.rewrite_saved_paths(unsupported),"unknown species are never guessed")
	var conflict: Array = [{"definition_path":"res://features/world/data/hogwarts.tscn::ambiguous","definition_id":"school_dementor","definition_revision":1},{"definition_path":"res://features/world/data/hogwarts.tscn::ambiguous","definition_id":"school_dark_elf","definition_revision":1}]
	check(not UnitResourcePaths.rewrite_saved_paths(conflict),"conflicting saved species remain protected")
	c.save.enabled=true; c.save.path="user://entry_regression_%d.dat"%OS.get_process_id()
	if FileAccess.file_exists(FIXTURE):
		var file: FileAccess = FileAccess.open(FIXTURE,FileAccess.READ)
		var saved: Dictionary = file.get_var(false); file.close()
		var preserved: Dictionary = saved.duplicate(true)
		check(UnitResourcePaths.rewrite_saved_paths(saved),"actual failing save has retired references repaired")
		var session_context: WorldContext = WorldSession.context
		WorldSession.context=c
		check(WorldSession.validate_content(saved),"actual failing save passes content validation")
		c.publish(saved); PartyProgress.restore(saved.progress); WorldSession.recover()
		check(c.state.progress==preserved.progress and c.state.applied_results==preserved.applied_results and c.state.player==preserved.player,"actual save retains player progress, position, inventory and reward receipts")
		check(c.checkpoint().ok,"repaired actual save commits to an isolated disk file")
		var reloaded: Dictionary=c.save.load_best()
		check(WorldSession.validate_content(reloaded) and reloaded==c.snapshot(),"repaired disk save reloads exactly and remains compatible")
		WorldSession.context=session_context
	# Disk writes use a unique test namespace, never the player's file.
	c.publish(initial)
	WorldSession.context=c
	game=load("res://main.tscn").instantiate(); add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.transition_cover.begin()
	await get_tree().process_frame
	await get_tree().process_frame
	check(game.transition_cover.logo.get_global_rect().get_center().distance_to(get_viewport().get_visible_rect().get_center())<1.0,"transition logo remains centered in the viewport")
	if "--capture-cover" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/web-build/transition-logo.png")
	game.transition_cover.complete()
	check(c.checkpoint().ok,"real disk checkpoint succeeds")
	for portal_id: String in ["well_door","lake_door","shaolin_door","school_door"]:
		c.publish(initial); c.paused=false
		var portal: Dictionary = {}
		for candidate: Dictionary in c.current_map().portals:
			if candidate.id==portal_id: portal=candidate
		check(not portal.is_empty(),"authored entrance exists "+portal_id)
		if portal.is_empty(): continue
		c.state.player.position=portal.point
		var result: Dictionary=c.begin_portal(portal_id)
		check(result.ok,"disk-backed dungeon entry "+portal_id+" "+str(result.get("reason","OK")))
		if not result.ok: continue
		for frame: int in 180:
			await get_tree().process_frame
			if game.mode==&"world" and c.state.mode=="EXPLORING": break
		check(c.state.mode=="EXPLORING" and c.state.control_owner.is_empty() and c.state.player.map_id==portal.target_map_id,"director completes dungeon scene and releases control "+portal_id)
	# Enter the school again and exercise countdown -> RTS -> retreat -> world.
	c.publish(initial); c.paused=false
	var school_portal: Dictionary = {}
	for portal: Dictionary in c.current_map().portals:
		if portal.id=="school_door": school_portal=portal
	c.state.player.position=school_portal.point
	var entered: Dictionary=c.begin_portal("school_door")
	if entered.ok:
		while c.state.mode=="TRANSITION": await get_tree().process_frame
		var enemy: Dictionary=c.state.maps.hogwarts.parties.values()[0]
		c.state.player.position=enemy.position; c.state.player.cooldown_until_ms=0; c.state.player.protected_until_ms=0
		var begun: Dictionary=c.encounters.try_begin("player",enemy.party_id,"player")
		check(begun.ok,"disk-backed monster encounter starts")
		if begun.ok:
			c.tick(5.1)
			while game.mode!=&"battle": await get_tree().process_frame
			check(game.living_ids(1).size()>0 and game.living_ids(0).size()>0,"countdown opens actual RTS with both teams")
			var target: TacticalUnit=game.get_unit(game.living_ids(1)[0])
			var before_hp: float=target.vitals.health
			game.apply_damage(target,10000)
			check(target.vitals.health<before_hp,"actual monster takes combat damage")
			game.finish_battle(&"retreat")
			game._retry_settlement()
			for frame: int in 300:
				await get_tree().process_frame
				if game.mode==&"world": break
			check(game.mode==&"world" and c.state.mode=="EXPLORING" and c.state.control_owner.is_empty(),"disk-backed retreat returns to unlocked world")
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(c.save.path+suffix): DirAccess.remove_absolute(c.save.path+suffix)
	print("ENTRY_PERSISTENCE_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
