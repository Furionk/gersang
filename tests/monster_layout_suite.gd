extends Node
var passed: int = 0
var failures: Array[String] = []
func _ready() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed+=1; print("PASS | ",title)
	else: failures.append(title); push_error("FAIL | "+title)

func run() -> void:
	WorldCatalog.initialize()
	var progress: Dictionary = PartyProgress.serialize()
	var old_defs: Dictionary = {}
	for id: String in ["river_bay","shaolin_temple"]:
		var root: WorldMap2D = preload("res://tests/world/legacy_scene_fixture.gd").load_scene("res://artifacts/monster-layout-2026-10-10/originals/features__world__data__"+id+".tscn").instantiate() as WorldMap2D
		old_defs[id] = root.compile_definition()
		root.free()
	var current: WorldContext = WorldContext.new()
	current.initialize(progress,20261011,true)
	current.ensure_map("shaolin_temple")
	check(current.state.maps.river_bay.parties.size()==22,"river retains22 fixed parties, distributed through new visual domains")
	check(current.state.maps.shaolin_temple.parties.size()==12,"temple expands from1 to12 parties")
	var samples: Dictionary = {}
	for id: String in ["river_bay","shaolin_temple"]:
		var map: WorldMapDefinition = current.map_definitions[id]
		var baseline: WorldMapDefinition = old_defs[id]
		check(map.portals==baseline.portals and map.entries==baseline.entries,"portal/arrival positions unchanged "+id)
		var base_geometry: bool = true
		for field: String in ["walkable","blockers","safe_areas"]:
			var a: Array = map.get(field)
			var b: Array = baseline.get(field)
			base_geometry = base_geometry and a.size()==b.size()
			for index: int in a.size(): base_geometry = base_geometry and a[index].outer==b[index].outer and a[index].holes==b[index].holes
		check(base_geometry,"player terrain and protected movement geometry unchanged "+id)
		for habitat: WorldHabitat in map.habitats:
			check(habitat.activity_domain.covers_domain(habitat.spawn_domain) and habitat.chase_domain.covers_domain(habitat.activity_domain),"nested set containment including visual holes "+id+"/"+habitat.habitat_id)
			var alive: Array = current.state.maps[id].parties.values().filter(func(p: Dictionary) -> bool: return p.habitat_id==habitat.habitat_id)
			check(alive.size()==habitat.profile.target_party_count,"every configured slot populated "+habitat.habitat_id)
			var moving: int = 0
			var blocked: bool = false
			for party: Dictionary in alive:
				var at: Vector2 = party.position
				var route: Dictionary = current.navigation.sample_wander(id,habitat.habitat_id,at,habitat.profile.radius,current.rngs.wander)
				var valid: bool = route.ok
				var last: Vector2 = at
				for next: Vector2 in route.get("points",PackedVector2Array()):
					valid = valid and current.navigation.segment_legal(id,habitat.habitat_id,"WANDER",last,next,habitat.profile.radius)
					last=next
				if valid and last.distance_to(at)>0.1: moving+=1
				blocked = blocked or not valid
				check(current.navigation.segment_legal(id,habitat.habitat_id,"SPAWN",at,at,habitat.profile.radius),"monster body starts in a real legal spawn "+party.party_id)
			check(not blocked and moving>0,"connected wandering around exclusions "+habitat.habitat_id)
			samples[id+"/"+habitat.habitat_id] = {"parties":alive.size(),"moving":moving,"activity_holes":habitat.activity_domain.holes.size()}
	# Confirm mismatched dense vegetation is excluded, not just a smaller rectangle.
	var river: WorldMapDefinition = current.map_definitions.river_bay
	var exclusions: int = 0
	for habitat: WorldHabitat in river.habitats: exclusions+=habitat.activity_domain.holes.size()
	check(exclusions>0,"native monster domains contain actual vegetation/rock exclusion holes")
	var outer: PolygonDomain = PolygonDomain.rectangle(Rect2(0,0,200,200))
	outer.holes = [PolygonDomain.rectangle(Rect2(60,60,40,40)).outer]
	var same: PolygonDomain = outer.duplicate(true) as PolygonDomain
	check(outer.covers_domain(same),"same holed domain is covered")
	same.holes.clear()
	check(not outer.covers_domain(same),"a domain cannot fill another domain's hole")
	same.holes = [PolygonDomain.rectangle(Rect2(50,50,60,60)).outer]
	check(outer.covers_domain(same),"larger exclusion hole is still a valid subset")
	same.outer = PolygonDomain.rectangle(Rect2(-10,0,210,200)).outer
	check(not outer.covers_domain(same),"true outside ground remains rejected")
	# Old saves: preserve all existing members/IDs and cooldowns while relocating illegal poses.
	var old: WorldContext = WorldContext.new()
	old.initialize(progress,400,true,old_defs)
	old.ensure_map("shaolin_temple")
	var snapshot: Dictionary = old.snapshot()
	var victim: Dictionary = snapshot.maps.river_bay.parties.values()[0]
	snapshot.maps.river_bay.parties.erase(victim.party_id)
	snapshot.maps.river_bay.slots[victim.slot_id].merge({"state":"COOLDOWN","party_id":"","respawn_due_ms":500000},true)
	var members: Dictionary = {}
	for runtime: Dictionary in snapshot.maps.values():
		for party: Dictionary in runtime.parties.values(): members[party.party_id]=party.deployed_units.duplicate(true)
	var restored: WorldContext = WorldContext.new()
	restored.initialize(progress,999,true)
	restored.publish(snapshot)
	var session: Node = get_tree().root.get_node("WorldSession")
	var previous: WorldContext = session.get("context")
	session.set("context",restored)
	check(session.call("validate_content",snapshot),"old layout save validates only via explicit supported revision")
	restored.ensure_map("river_bay")
	restored.ensure_map("shaolin_temple")
	var preserved: bool = true
	var positions: bool = true
	for runtime: Dictionary in restored.state.maps.values():
		for party: Dictionary in runtime.parties.values():
			if members.has(party.party_id): preserved = preserved and members[party.party_id]==party.deployed_units
			var habitat: WorldHabitat = restored.map_definitions[runtime.map_id].habitat(party.habitat_id)
			positions = positions and restored.navigation.segment_legal(runtime.map_id,habitat.habitat_id,"WANDER",party.position,party.position,habitat.profile.radius)
	check(preserved,"existing party and member IDs, levels and stats never reroll")
	check(positions,"old out-of-region monsters rehome legally before presentation")
	check(restored.state.progress==snapshot.progress and restored.state.applied_results==snapshot.applied_results,"progress and reward receipts untouched")
	check(restored.state.maps.river_bay.slots[victim.slot_id].respawn_due_ms==500000 and restored.state.maps.river_bay.slots[victim.slot_id].state=="COOLDOWN","respawn cooldown preserved; no killed party resurrection")
	check(restored.state.maps.shaolin_temple.parties.size()==12,"already-visited temple receives11 new slots without replacing its original guardian")
	var once: Dictionary = restored.snapshot()
	restored.ensure_map("river_bay"); restored.ensure_map("shaolin_temple")
	check(restored.snapshot()==once,"layout reconcile is idempotent; no repeated spawns or RNG consumption")
	var future: Dictionary = once.duplicate(true)
	future.maps.river_bay.definition_version=999
	check(not session.call("validate_content",future),"unknown future layout revision stays protected")
	var deferred: WorldContext = WorldContext.new()
	deferred.initialize(progress,999,true)
	deferred.publish(snapshot)
	deferred.state.active_encounter={"encounter_id":"test_busy"}
	deferred.ensure_map("shaolin_temple")
	check(deferred.state.maps.shaolin_temple.parties.size()==1,"active encounter defers layout migration")
	session.set("context",previous)
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"samples":samples,"river_parties":22,"temple_parties":12,"save_scope":"isolated snapshots; formal progress never written"}
	var file: FileAccess = FileAccess.open("res://artifacts/monster-layout-2026-10-10/results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MONSTER_LAYOUT_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
