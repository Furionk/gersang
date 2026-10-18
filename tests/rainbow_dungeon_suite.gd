extends "res://tests/rainbow_action_suite.gd"
var balance: Array[Dictionary] = []
func shot(title: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-dungeon/"+title+".png")

func run() -> void:
	var settings: RainbowActionProfile = load("res://features/rainbow/data/default_action.tres")
	check(settings.enemies.size() == 14,"eight species and six higher-tier boss identities")
	for enemy: RainbowEnemyDefinition in settings.enemies:
		var data: UnitDefinition = load("res://features/units/data/monsters/%s.tres" % enemy.unit_id)
		var layout: SpriteSheetLayout = data.sprite_layout
		check(layout != null and layout.frame_rects.size() == layout.rows * layout.columns and layout.valid_for(Vector2i(layout.source_texture.get_size())),"valid authored pose layout: "+str(data.id))
		var visible: bool = true
		for rect: Rect2i in layout.frame_rects: visible = visible and layout.source_texture.get_image().get_region(rect).get_used_rect().get_area() > 100
		check(visible,"no empty animation crops: "+str(data.id))
		var new_skin: bool = str(data.id).begins_with("temple_") or str(data.id).begins_with("fire_dragon_tier_")
		check(layout.direction_rows[5] == (1 if new_skin else 2) and layout.direction_rows[7] == (2 if new_skin else 3),"back-facing rows use authored direction map: "+str(data.id))
		var member: Dictionary = PartyBuilder.resolve_member(data,data.level,"probe_"+str(data.id))
		balance.append({"id":str(data.id),"level":data.level,"hp":member.resolved_stats.health,"attack":member.resolved_stats.attack,"xp":data.experience_reward})
		check(member.resolved_stats.attack > 0 and data.puzzle_monster == null,"real resolved attack positive; no puzzle mode: "+str(data.id))
	var def: WorldMapDefinition = WorldCatalog.definitions.rainbow_temple
	var native: WorldMap2D = load(def.scene_path).instantiate()
	check(WorldValidator.validate(def,WorldCatalog.definitions,native).is_empty(),"expanded native dungeon validates")
	native.free()
	var nav := WorldNavigationService.new(); nav.register_map(def)
	check(not nav.segment_legal(def.map_id,"","PLAYER",Vector2(1312,192),Vector2(1312,192),8),"new solid column foot is blocked by native tiles")
	for habitat: WorldHabitat in def.habitats:
		check(habitat.profile.templates[0].representative.resource_path.begins_with("res://features/units/data/monsters/") and not habitat.profile.templates[0].representative.resource_path.contains("::"),"stable external unit reference: "+habitat.habitat_id)
		var point: Vector2 = habitat.spawn_domain.bounds().get_center()
		check(nav.find_path(def.map_id,"","PLAYER",def.entries.entrance.point,point,16).ok,"entrance reaches native habitat: "+habitat.habitat_id)
	for id: String in ["rainbow_temple","rainbow_forge","rainbow_sanctum","rainbow_throne"]:
		var arena: ArenaDefinition = WorldCatalog.arenas[id]
		var map: BattlefieldMap = load(arena.encounter.battlefield_scene).instantiate()
		var compiled: Dictionary = BattlefieldCompiler.compile(map)
		check(compiled.errors.is_empty() and compiled.zones.size() == 5,"five valid native spawn groups: "+id)
		check(RainbowActionBattle.eligible(arena.encounter,{"return_map_id":"rainbow_temple"}) and not RainbowActionBattle.eligible(arena.encounter,{"return_map_id":"river_bay"}),"action mode scope: "+id)
		map.free()
	context = WorldContext.new(); context.initialize(PartyProgress.serialize(),55047,true)
	context.save.enabled = true; context.save.path = "user://rainbow_dungeon_suite.dat"
	WorldSession.context = context
	game = load("res://main.tscn").instantiate(); add_child(game)
	check(await wait_world(),"real world director loaded")
	game.set_physics_process(false)
	var untouched: Dictionary = context.state.maps.river_bay.duplicate(true)
	for portal: Dictionary in context.current_map().portals:
		if portal.id == "rainbow_door": context.state.player.position = portal.point
	check(context.begin_portal("rainbow_door").ok and await wait_world(),"real portal reaches expanded dungeon")
	check(context.state.maps.rainbow_temple.parties.size() == 36,"all 36 parties materialize")
	# Simulate a pre-expansion save: retain original two slots, then add only new habitats.
	var runtime: Dictionary = context.state.maps.rainbow_temple
	for id: String in runtime.parties.keys():
		if runtime.parties[id].habitat_id != "rainbow_slime_court": runtime.parties.erase(id)
	for id: String in runtime.slots.keys():
		if runtime.slots[id].habitat_id != "rainbow_slime_court": runtime.slots.erase(id)
	var originals: Dictionary = runtime.parties.duplicate(true)
	check(WorldPopulationLayout.add_missing_slots(context,def,runtime),"old saves add new slots without reset")
	var same: bool = true
	for id: String in originals: same = same and runtime.parties.get(id,{}) == originals[id]
	check(same and runtime.parties.size() == 36,"original IDs, wounded state and positions remain intact")
	var veteran: Dictionary = runtime.parties.values().filter(func(p: Dictionary) -> bool: return p.habitat_id == "rainbow_slime_court")[0].deployed_units[0]
	var veteran_id: String = veteran.unit_id
	var veteran_level: int = veteran.level
	veteran.balance_revision = 0; veteran.resolved_stats.health = 172.0; veteran.current_hp = 68.8
	check(MonsterBalanceRefresh.apply(context,runtime),"existing wounded slime receives numeric revision")
	check(veteran.unit_id == veteran_id and veteran.level == veteran_level and is_equal_approx(veteran.current_hp/veteran.resolved_stats.health,0.4),"numeric migration preserves stable ID, level and wounded HP ratio")
	await shot("dungeon-entry")
	for habitat_id: String in ["rainbow_beast_nest","rainbow_high_priest","rainbow_dragon_throne"]:
		if not await enter_party(habitat_id): check(false,"encounter entered "+habitat_id); break
		await verify_mechanics()
		var encounter_id: String = context.state.active_encounter.encounter_id
		var location: Vector2 = context.state.active_encounter.return_position
		# Settlement probe is deliberately administrative, separate from natural-play acceptance.
		for id: int in game.living_ids(1): game.apply_damage(game.get_unit(id),1000000,false,CombatMath.Kind.MAGIC)
		for step: int in 160: game._physics_process(1.0/60.0)
		check(game.last_result == "victory" and context.state.applied_results.has(encounter_id),"boss defeat commits existing settlement: "+habitat_id)
		var snapshot: Dictionary = context.snapshot()
		check(context.settlement.apply(game.settlement_result).get("duplicate",false) and context.snapshot() == snapshot,"boss rewards cannot duplicate: "+habitat_id)
		check(context.save.load_best() == snapshot,"boss result survives disk reload: "+habitat_id)
		game.start_world(); check(await wait_world(),"return after "+habitat_id)
		check(game.action_battle == null and context.state.player.position.distance_to(location) < 1,"boss mechanics cleaned up and position restored")
	check(context.state.maps.river_bay == untouched,"all original river parties and slots preserved")
	finish()

func enter_party(habitat: String) -> bool:
	var selected: Dictionary = {}
	for party: Dictionary in context.state.maps.rainbow_temple.parties.values():
		if party.habitat_id == habitat: selected = party; break
	if selected.is_empty(): return false
	context.state.player.position = selected.position + Vector2(20,0)
	context.state.player.protected_until_ms = 0; context.state.player.cooldown_until_ms = 0
	context.refresh_player(PartyProgress.serialize())
	var result: Dictionary = context.encounters.try_begin("player",selected.party_id,"player")
	if not result.ok: print(result); return false
	for step: int in 301: context.tick(1.0/60.0)
	for frame: int in 600:
		await get_tree().process_frame
		if game.mode == &"battle":
			game.set_physics_process(false); game.action_battle.input_override = true
			return true
	return false

func verify_mechanics() -> void:
	var battle: RainbowActionBattle = game.action_battle
	var mechanics: RainbowTempleMechanics = battle.mechanics
	var enemy: RainbowActionActor = battle.actors[game.living_ids(1)[0]]
	var hero: RainbowActionActor = battle.actors[battle.controlled_id]
	for actor: RainbowActionActor in battle.actors.values():
		actor.action = &""; actor.recovery = 0; actor.stun = 0; actor.hit_stop = 0
		actor.unit.position = Vector2(1200,1050) if actor.unit.team == 0 else Vector2(800,480)
		actor.pose.reset(actor.unit.position)
		hero.unit.vitals.health = hero.unit.vitals.max_health
	hero.unit.position = Vector2(800,700); hero.pose.reset(hero.unit.position)
	enemy.unit.facing = Vector2.DOWN
	for frame: int in 2: await get_tree().physics_frame
	mechanics.begin_special(enemy)
	check(not mechanics.hazards.is_empty() and enemy.mechanic_lock,"special locks enemy and publishes warning: "+enemy.enemy.pattern)
	if mechanics.hazards.is_empty(): return
	var health: float = hero.unit.vitals.health
	mechanics.tick(0.1)
	check(hero.unit.vitals.health == health,"warning alone never damages player")
	var warning: Dictionary = mechanics.hazards[0].duplicate(true)
	# Weighted attacks can include a follow-up or annulus. Escape every published
	# footprint, rather than assuming the old fixed first cone always permits +300 X.
	var found_safe: bool = false
	for sample: int in 64:
		var candidate := Vector2(800,700) + Vector2.from_angle(sample*TAU/64.0)*420
		var safe: bool = true
		for hazard: Dictionary in mechanics.hazards:
			if RainbowTempleMechanics.contains(hazard,candidate): safe = false; break
		if safe:
			hero.unit.position = candidate; found_safe = true; break
	check(found_safe,"published attack batch has an outside sample")
	for state: Dictionary in mechanics.states.values(): state.timer = 100
	check(mechanics.hazards[0].center == warning.center and mechanics.hazards[0].direction == warning.direction,"telegraph location and facing locked after cast")
	for step: int in 150: mechanics.tick(1.0/60.0)
	check(hero.unit.vitals.health == health,"moving out of published danger avoids damage")
	mechanics.hazards.clear()
	for state: Dictionary in mechanics.states.values(): state.pending = false; state.timer = 100
	# One blast, exactly once, even over many simulation ticks.
	hero.unit.position = Vector2(800,700); hero.pose.reset(hero.unit.position)
	mechanics.add_hazard(enemy,"circle",hero.unit.position,100,0,1.4,50)
	check(not mechanics.hazards.is_empty(),"damage probe admits an avoidable published reservation")
	if mechanics.hazards.is_empty(): return
	mechanics.tick(float(mechanics.hazards[0].warning) + 0.01)
	var struck: float = hero.unit.vitals.health
	check(struck < health,"confirmed special damages through shared vitals")
	for step: int in 20: mechanics.tick(0.01)
	check(hero.unit.vitals.health == struck,"single blast cannot apply damage every frame")
	mechanics.hazards.clear()
	mechanics.add_hazard(enemy,"ring",enemy.unit.position,520,170,2.1,90)
	check(not mechanics.hazards.is_empty(),"ring schedule retains a reachable safe core")
	if mechanics.hazards.is_empty(): return
	var ring: Dictionary = mechanics.hazards[0]
	check(not RainbowTempleMechanics.contains(ring,enemy.unit.position+Vector2(80,0)) and RainbowTempleMechanics.contains(ring,enemy.unit.position+Vector2(260,0)),"ring safe core and damaging annulus agree")
	var follower: RainbowActionActor = battle.actors[game.roster_ids[1]]
	follower.unit.position = enemy.unit.position + Vector2(230,0)
	for frame: int in 3: await get_tree().physics_frame
	var escape: Dictionary = mechanics.safe_destination(follower)
	check(not escape.is_empty() and not RainbowTempleMechanics.contains(ring,escape.point,18),"AI chooses legal safe location beyond current telegraph")
	if enemy.enemy.boss:
		enemy.action = &"melee"; enemy.windup = 1.0; enemy.stun = 0; enemy.hit_stop = 0
		enemy.receive_hit(hero.unit.position,100,1,1,500)
		check(enemy.action == &"melee" and enemy.stun == 0 and enemy.impulse == Vector2.ZERO and enemy.hit_stop == 0,"boss armor prevents permanent stagger lock")
		enemy.action = &""; enemy.exposed = true
		enemy.receive_hit(hero.unit.position,100,1,0.2,50)
		check(enemy.stun > 0 and enemy.impulse == Vector2.ZERO,"exposed boss permits stagger without pinball displacement")
		enemy.stun = 0; enemy.hit_stop = 0; enemy.exposed = false
		mechanics.hazards.clear()
		var state: Dictionary = mechanics.states[enemy.unit.unit_id]
		state.pending = false; state.exposure = 0
		state.cycle = 2 if enemy.enemy.pattern == "dragon" else 1
		mechanics.begin_special(enemy)
		for step: int in 360:
			mechanics.tick(1.0/60.0)
			if state.exposure > 0: break
		check(enemy.exposed and state.exposure > 0,"completed ritual creates finite counterattack window")
		for step: int in 310: mechanics.tick(1.0/60.0)
		check(not enemy.exposed and not enemy.mechanic_lock,"counterattack window expires without permanent vulnerability")
		enemy.unit.vitals.health = enemy.unit.vitals.max_health * 0.3
		mechanics.tick(0.01)
		check(state.phase == (3 if enemy.enemy.pattern == "dragon" else 2),"HP thresholds advance boss phase")
		state.pending = false; state.exposure = 0; state.cycle = 0
		mechanics.hazards.clear(); mechanics.begin_special(enemy)
		for actor: RainbowActionActor in battle.actors.values(): actor.hit_flash = 0; actor.hit_stop = 0
		game.camera.position = Iso.project(enemy.unit.position + Vector2(100,180))
		for frame: int in 3: await get_tree().process_frame
		await shot(enemy.enemy.pattern+"-telegraph")
		mechanics.hazards.clear(); state.pending = false; state.cycle = 2 if enemy.enemy.pattern == "dragon" else 1
		mechanics.begin_special(enemy)
		await shot(enemy.enemy.pattern+"-safe-core")
	mechanics.hazards.clear()

func finish() -> void:
	var file := FileAccess.open("res://artifacts/rainbow-dungeon/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"balance":balance,"checks":observations},"\t")); file.close()
	print("RAINBOW_DUNGEON_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
