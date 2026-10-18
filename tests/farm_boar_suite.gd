extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS | ",title)
	else: failed+=1; push_error("FAIL | "+title)
func _ready() -> void: call_deferred("run")
func run() -> void:
	WorldCatalog.initialize()
	var map: WorldMapDefinition = WorldCatalog.definitions.river_bay
	var farm: WorldHabitat = map.habitat("farm")
	check(farm.profile.target_party_count==12,"farm population doubles to12 parties")
	check(farm.profile.templates.size()==1 and farm.profile.templates[0].representative.id==&"beast","farm world representative is the real boar")
	var rule: MemberRule = farm.profile.templates[0].members[0]
	check(rule.definition.sprite_path=="res://features/units/art/beast.png" and rule.min_count==6 and rule.max_count==9,"every party contains6–9 original boar sprites, no mixed humanoids")
	var c: WorldContext = WorldContext.new()
	c.initialize(PartyProgress.serialize(),1104,true)
	var pigs: Array = c.state.maps.river_bay.parties.values().filter(func(p: Dictionary) -> bool: return p.habitat_id=="farm")
	var total: int = 0
	for party: Dictionary in pigs:
		total+=party.deployed_units.size()
		check(party.representative_path==rule.definition.resource_path and party.display_name=="租霸豬","correct species/name in world "+party.party_id)
		check(party.deployed_units.size()>=6 and party.deployed_units.size()<=9 and party.deployed_units.all(func(u: Dictionary) -> bool: return u.definition_id=="beast" and u.definition_path==rule.definition.resource_path),"only pigs in fixed battle roster "+party.party_id)
	check(pigs.size()==12 and total>=72 and total<=108,"72–108 actual pigs across12 parties")
	var before_root: WorldMap2D = preload("res://tests/world/legacy_scene_fixture.gd").load_scene("res://artifacts/boar-fix-2026-10-10/river_bay-before.tscn").instantiate() as WorldMap2D
	var before_map: WorldMapDefinition = before_root.compile_definition()
	before_root.free()
	check(map.portals==before_map.portals and map.entries==before_map.entries,"all artist-edited portals/arrival points preserved")
	for field: String in ["spawn_domain","activity_domain","chase_domain"]:
		var a: PolygonDomain = farm.get(field)
		var b: PolygonDomain = before_map.habitat("farm").get(field)
		check(a.outer==b.outer and a.holes==b.holes,"farm navigation domain unchanged "+field)
	var old: WorldContext = WorldContext.new()
	old.initialize(PartyProgress.serialize(),1104,true,{"river_bay":before_map})
	var saved: Dictionary = old.snapshot()
	var nonfarm: Dictionary = {}
	var slots: Dictionary = {}
	for party: Dictionary in saved.maps.river_bay.parties.values():
		if party.habitat_id!="farm": nonfarm[party.party_id] = party.duplicate(true)
	for slot: Dictionary in saved.maps.river_bay.slots.values():
		if slot.habitat_id!="farm": slots[slot.slot_id] = slot.duplicate(true)
	c.publish(saved)
	c.ensure_map("river_bay")
	var unchanged: bool = true
	for id: String in nonfarm: unchanged = unchanged and c.party(id)==nonfarm[id]
	for id: String in slots: unchanged = unchanged and c.state.maps.river_bay.slots[id]==slots[id]
	check(unchanged,"migration does not reroll or alter any other monster party/slot")
	check(c.state.progress==saved.progress and c.state.player==saved.player and c.state.applied_results==saved.applied_results and c.state.world_time_ms==saved.world_time_ms,"player progress, position, clocks and reward receipts unchanged")
	check(c.state.maps.river_bay.parties.values().filter(func(p: Dictionary) -> bool: return p.habitat_id=="farm" and p.representative_path==rule.definition.resource_path).size()==12,"already-saved humanoid farm parties become12 boar parties")
	var once: Dictionary = c.snapshot()
	c.ensure_map("river_bay")
	check(c.snapshot()==once,"boar correction is idempotent")
	var previous: WorldContext = WorldSession.context
	WorldSession.context = c
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	pigs = c.state.maps.river_bay.parties.values().filter(func(p: Dictionary) -> bool: return p.habitat_id=="farm")
	var visual_ok: bool = true
	for party: Dictionary in pigs: visual_ok = visual_ok and (game.world_views[party.party_id] as WorldPartyView).definition.id==&"beast"
	check(visual_ok,"all twelve actual world views display boars")
	var target: Dictionary = pigs[0]
	c.state.player.position = target.position+Vector2(5,0)
	game.world_hero.position = c.state.player.position
	game.world_pose.reset(c.state.player.position)
	game.camera.position = Iso.project(target.position)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/boar-fix-2026-10-10/world-boars.png")
	check(c.encounters.try_begin("player",target.party_id,"player").ok,"boar party enters normal encounter")
	c.tick(5.1)
	while game.mode!=&"battle": await get_tree().process_frame
	var all_members: Array[String] = []
	for party: Dictionary in game.battle_snapshot.enemy_party_snapshots:
		for member: Dictionary in party.deployed_units: all_members.append(member.unit_id)
	check(game.living_ids(1).size()==all_members.size(),"battle contains every fixed member from the admitted parties")
	var primary: Array[String] = []
	for member: Dictionary in target.deployed_units: primary.append(member.unit_id)
	var actual: Array = game.units.values().filter(func(u: TacticalUnit) -> bool: return u.team==1 and u.persistent_unit_id in primary)
	check(actual.size()==primary.size() and actual.all(func(u: TacticalUnit) -> bool: return u.definition.id==&"beast"),"the clicked boar party stays pigs inside real RTS")
	game.queue_free()
	await get_tree().process_frame
	WorldSession.context = previous
	var file: FileAccess = FileAccess.open("res://artifacts/boar-fix-2026-10-10/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"parties":12,"min_pigs":72,"max_pigs":108,"player_save_scope":"isolated"},"\t"))
	print("FARM_BOAR_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
