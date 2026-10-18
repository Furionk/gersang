@tool
class_name WorldPopulationLayout
extends RefCounted
## Explicit content migration, before map presentation. Never rerolls existing members.
const REVISIONS: Dictionary = {"river_bay":[2,3,4],"shaolin_temple":[2,3,4],"well_1":[3],"well_2":[3],"millennium_lake":[2,3]}

static func can_upgrade(map: WorldMapDefinition, runtime: Dictionary) -> bool:
	var previous: Variant = runtime.get("definition_version",1)
	return previous is int and previous>=1 and map.content_version in REVISIONS.get(map.map_id,[]) and previous<map.content_version

static func add_missing_slots(context: WorldContext, map: WorldMapDefinition, runtime: Dictionary) -> bool:
	# Normal artist additions do not require a destructive content revision migration.
	# Add only missing canonical slots. Never remove, reset or reroll existing slots.
	if context.paused or not context.state["active_encounter"].is_empty() or context.state["mode"]!="EXPLORING": return false
	var added: PackedStringArray = PackedStringArray()
	for habitat: WorldHabitat in map.habitats:
		if habitat.profile==null: continue
		for index: int in habitat.profile.target_party_count:
			var id: String = "%s/%s/%d" % [map.map_id,habitat.habitat_id,index]
			if runtime["slots"].has(id): continue
			runtime["slots"][id] = {"slot_id":id,"habitat_id":habitat.habitat_id,"state":"EMPTY","party_id":"","generation_index":0,"respawn_due_ms":0,"pending_party":{}}
			added.append(id)
	if added.is_empty(): return false
	context.spawn_due(map.map_id,"",added)
	return true

static func nearest_spawn(context: WorldContext, map: WorldMapDefinition, habitat: WorldHabitat, from: Vector2) -> Dictionary:
	var cached: Dictionary = context.navigation._cache(map.map_id,habitat.habitat_id,"SPAWN",habitat.profile.radius)
	var closest: Vector2 = Vector2.ZERO
	var distance: float = INF
	var grid: AStarGrid2D = cached.get("grid")
	if grid==null: return {"ok":false}
	for cell: Vector2i in cached.get("cells",[]):
		var point: Vector2 = grid.get_point_position(cell)
		if not context.navigation.segment_legal(map.map_id,habitat.habitat_id,"WANDER",point,point,habitat.profile.radius): continue
		if not context.navigation.segment_legal(map.map_id,habitat.habitat_id,"CHASE",point,point,habitat.profile.radius): continue
		if point.distance_squared_to(from)<distance:
			closest=point
			distance=point.distance_squared_to(from)
	return {"ok":is_finite(distance),"point":closest}

static func reconcile(context: WorldContext, map: WorldMapDefinition, runtime: Dictionary) -> bool:
	var retired: bool=runtime.parties.values().any(func(p: Dictionary)->bool: return map.is_retired_habitat(p.habitat_id)) or runtime.slots.values().any(func(s: Dictionary)->bool: return map.is_retired_habitat(s.habitat_id))
	if (not can_upgrade(map,runtime) and not retired) or not context.state["active_encounter"].is_empty(): return false
	if map.map_id=="shenchao_tower" and retired:
		if context.paused or context.state.mode!="EXPLORING": return false
		# Retire only relocated dark habitats; preserve all other identities and timers.
		for id: String in runtime.parties.keys():
			if map.is_retired_habitat(runtime.parties[id].habitat_id): runtime.parties.erase(id)
		for id: String in runtime.slots.keys():
			if map.is_retired_habitat(runtime.slots[id].habitat_id): runtime.slots.erase(id)
		return true
	if map.map_id=="millennium_lake" and map.content_version>=3: return reconcile_lake(context,map,runtime)
	if map.map_id=="river_bay" and map.content_version==4 and int(runtime.get("definition_version",1))>=3:
		var before: Dictionary = context.snapshot()
		for id: String in runtime["parties"].keys():
			if runtime["parties"][id]["habitat_id"]=="farm": runtime["parties"].erase(id)
		for id: String in runtime["slots"].keys():
			if runtime["slots"][id]["habitat_id"]=="farm": runtime["slots"].erase(id)
		var habitat: WorldHabitat = map.habitat("farm")
		for index: int in habitat.profile.target_party_count:
			var id: String = "river_bay/farm/%d" % index
			runtime["slots"][id] = {"slot_id":id,"habitat_id":"farm","state":"EMPTY","party_id":"","generation_index":0,"respawn_due_ms":0,"pending_party":{}}
		context.spawn_due(map.map_id,"farm")
		if runtime["parties"].values().filter(func(p: Dictionary) -> bool: return p.habitat_id=="farm").size()!=habitat.profile.target_party_count:
			context.publish(before)
			context.paused = true
			context.notification.emit("租霸豬配置更新失敗；原世界保留，請檢查出生範圍。")
			return false
		runtime["definition_version"] = 4
		return true
	if map.content_version==3 or (map.map_id in ["river_bay","shaolin_temple"] and map.content_version==4):
		# D25: explicit human approval to rebuild ONLY these world monster populations.
		# Progress, receipts, clocks and ID allocator are untouched; allocate new IDs.
		var before: Dictionary = context.snapshot()
		context.state["maps"].erase(map.map_id)
		context.ensure_map(map.map_id)
		if context.state["maps"][map.map_id]["parties"].is_empty() and map.habitats.any(func(h: WorldHabitat) -> bool: return h.profile.target_party_count>0):
			context.publish(before)
			return false
		return true
	# Compute repairs first. No partial migration when a region has no legal landing.
	var repairs: Array[Dictionary] = []
	for party: Dictionary in runtime["parties"].values():
		var habitat: WorldHabitat = map.habitat(party["habitat_id"])
		if habitat==null: return false
		var home: Vector2 = party["home"]
		if not context.navigation.segment_legal(map.map_id,habitat.habitat_id,"SPAWN",home,home,habitat.profile.radius):
			var replacement: Dictionary = nearest_spawn(context,map,habitat,home)
			if not replacement.ok: return false
			home = replacement.point
		var point: Vector2 = party["position"]
		if not context.navigation.segment_legal(map.map_id,habitat.habitat_id,"WANDER",point,point,habitat.profile.radius): point=home
		repairs.append({"party":party,"home":home,"point":point})
	for repair: Dictionary in repairs:
		repair.party["home"] = repair.home
		repair.party["position"] = repair.point
		repair.party["path"] = PackedVector2Array()
		repair.party["movement_state"] = "IDLE"
		repair.party["think_due_ms"] = int(context.state["world_time_ms"])+200
		repair.party["chase_until_ms"] = 0
	for habitat: WorldHabitat in map.habitats:
		for index: int in habitat.profile.target_party_count:
			var id: String = "%s/%s/%d" % [map.map_id,habitat.habitat_id,index]
			if not runtime["slots"].has(id):
				runtime["slots"][id] = {"slot_id":id,"habitat_id":habitat.habitat_id,"state":"EMPTY","party_id":"","generation_index":0,"respawn_due_ms":0,"pending_party":{}}
	# Existing cooldown deadlines, generation indices and surplus occupied slots survive.
	if map.map_id=="millennium_lake" and map.content_version==2:
		for party: Dictionary in runtime.parties.values():
			var changed: bool=false
			for index: int in party.deployed_units.size():
				var member: Dictionary=party.deployed_units[index]
				if member.definition_id!="lake_guardian": continue
				var replacement: Dictionary=PartyBuilder.resolve_member(load(member.definition_path) as UnitDefinition,50,member.unit_id,int(member.get("equipment_power",0)))
				party.deployed_units[index]=replacement; changed=true
			if changed:
				party.total_power=PowerCalculator.make_summary(party).power
				party.roster_revision+=1
	runtime["definition_version"] = map.content_version
	context.spawn_due(map.map_id)
	return true

static func reconcile_lake(context: WorldContext, map: WorldMapDefinition, runtime: Dictionary) -> bool:
	var before: Dictionary=context.snapshot()
	for id: String in runtime.parties.keys():
		if map.is_retired_habitat(runtime.parties[id].habitat_id): runtime.parties.erase(id)
	for id: String in runtime.slots.keys():
		if map.is_retired_habitat(runtime.slots[id].habitat_id): runtime.slots.erase(id)
	for party: Dictionary in runtime.parties.values():
		var habitat: WorldHabitat=map.habitat(party.habitat_id)
		if habitat==null: context.publish(before); return false
		if not context.navigation.segment_legal(map.map_id,party.habitat_id,"SPAWN",party.home,party.home,habitat.profile.radius):
			var home: Dictionary=nearest_spawn(context,map,habitat,party.home)
			if not home.ok: context.publish(before); return false
			party.home=home.point
		if not context.navigation.segment_legal(map.map_id,party.habitat_id,"CHASE",party.position,party.position,habitat.profile.radius): party.position=party.home
		for index: int in party.deployed_units.size():
			var member: Dictionary=party.deployed_units[index]
			if member.definition_id!="lake_guardian": continue
			var updated: Dictionary=PartyBuilder.resolve_member(load(member.definition_path) as UnitDefinition,50,member.unit_id,int(member.get("equipment_power",0)))
			if updated!=member: party.roster_revision+=1
			party.deployed_units[index]=updated
		party.total_power=PowerCalculator.make_summary(party).power
	context.state.maps[map.map_id]=runtime
	add_missing_slots(context,map,runtime)
	runtime.definition_version=map.content_version
	return true
