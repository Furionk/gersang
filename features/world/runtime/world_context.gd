@tool
class_name WorldContext
extends RefCounted
signal changed
signal notification(text: String)
signal map_requested(token: String)
var state: Dictionary = {}
var rngs: Dictionary = {}
var navigation: WorldNavigationService = WorldNavigationService.new()
var save: WorldSaveService = WorldSaveService.new()
var encounters: EncounterService
var settlement: SettlementService
var player_path: PackedVector2Array = PackedVector2Array()
var player_target_party: String = ""
var paused: bool = false
var delta_remainder: float = 0.0
var preview: bool = false
var map_definitions: Dictionary = {}
var movement_multiplier: float = 1.0
var turn_speed: float = 16.0
var population_layout_changed: bool = false

func initialize(progress: Dictionary, seed: int = 42047, isolated: bool = false, overrides: Dictionary = {}) -> void:
	preview = isolated
	save.enabled = not isolated
	WorldCatalog.initialize()
	map_definitions = WorldCatalog.definitions.duplicate()
	map_definitions.merge(overrides,true)
	for map: WorldMapDefinition in map_definitions.values():
		navigation.register_map(map)
	state = {"version":2,"content_version":1,"revision":0,"world_time_ms":0,"id_counter":0,"mode":"EXPLORING","control_owner":"","maps":{},"rng":{},"active_encounter":{},"applied_results":{},"progress":progress.duplicate(true),"player_party":{},"player":{"party_id":"player","map_id":"river_bay","position":Vector2(5000,2200),"facing":Vector2.DOWN,"life_state":"ACTIVE","encounter_id":"","protected_until_ms":0,"cooldown_until_ms":0},"portal_protection":""}
	for stream: String in ["composition","placement","wander","battle","reward","encounter"]:
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = seed + rngs.size() * 1009
		rngs[stream] = random
	encounters = EncounterService.new()
	encounters.context = self
	settlement = SettlementService.new()
	settlement.context = self
	refresh_player(progress)
	ensure_map("river_bay")

func allocate(prefix: String) -> String:
	state["id_counter"] += 1
	return "%s_%d" % [prefix,state["id_counter"]]

func refresh_player(progress: Dictionary) -> void:
	state["progress"] = progress.duplicate(true)
	var members: Array[Dictionary] = []
	for i: int in progress["party"].size():
		var record: CharacterRecord = CharacterRecord.new()
		var path: String = str(progress["party"][i].get("definition_path",Catalog.PARTY_PATHS[i] if i<Catalog.PARTY_PATHS.size() else ""))
		if path not in MercenaryRoster.paths(): continue
		record.initialize(load(path) as UnitDefinition,str(progress["party"][i]["id"]),false)
		if not record.restore(progress["party"][i]):
			continue
		var bonus: int = 0
		for item_id: StringName in record.equipment.values():
			var item: GearItemDefinition = ItemCatalog.get_item(item_id)
			if item != null:
				bonus += item.power_bonus
		var unit: Dictionary = PartyBuilder.resolve_member(record.definition,record.level(),record.persistent_id,bonus)
		unit["resolved_stats"] = record.stats()
		unit["current_hp"] = record.health
		unit["current_mp"] = record.mana
		unit["record"] = record.serialize()
		members.append(unit)
	var old_party: Dictionary = state.get("player_party",{})
	var old_configuration: Array = []
	var configuration: Array = []
	for member: Dictionary in old_party.get("deployed_units",[]):
		old_configuration.append([member["unit_id"],member["level"],member["definition_revision"],member["rated_power"],member["resolved_stats"]])
	for member: Dictionary in members:
		configuration.append([member["unit_id"],member["level"],member["definition_revision"],member["rated_power"],member["resolved_stats"]])
	var revision: int = int(old_party.get("roster_revision",0)) + (1 if old_configuration != configuration else 0)
	state["player_party"] = {"party_id":"player","display_name":"行旅商隊","roster_revision":revision,"deployed_units":members,"reserve_units":[]}
	state["player_party"]["total_power"] = PowerCalculator.make_summary(state["player_party"])["power"]

func ensure_map(id: String) -> void:
	var map: WorldMapDefinition = map_definitions.get(id)
	if map == null:
		return
	if state["maps"].has(id):
		if WorldPopulationLayout.reconcile(self,map,state["maps"][id]): population_layout_changed = true
		if WorldPopulationLayout.add_missing_slots(self,map,state["maps"][id]): population_layout_changed = true
		if MonsterBalanceRefresh.apply(self,state["maps"][id]):population_layout_changed=true
		if preload("res://features/monkey/roster_refresh.gd").apply(self,state["maps"][id]): population_layout_changed=true
		return
	var runtime: Dictionary = {"map_id":id,"definition_version":map.content_version,"initialized":true,"parties":{},"slots":{}}
	state["maps"][id] = runtime
	for habitat: WorldHabitat in map.habitats:
		for i: int in habitat.profile.target_party_count:
			var slot_id: String = "%s/%s/%d" % [id,habitat.habitat_id,i]
			runtime["slots"][slot_id] = {"slot_id":slot_id,"habitat_id":habitat.habitat_id,"state":"EMPTY","party_id":"","generation_index":0,"respawn_due_ms":0,"pending_party":{}}
	spawn_due(id)

func spawn_due(id: String, only_habitat: String = "", only_slots: PackedStringArray = PackedStringArray()) -> void:
	var runtime: Dictionary = state["maps"][id]
	var map: WorldMapDefinition = map_definitions[id]
	for slot: Dictionary in runtime["slots"].values():
		if not only_slots.is_empty() and not slot["slot_id"] in only_slots: continue
		if not only_habitat.is_empty() and slot["habitat_id"]!=only_habitat: continue
		if slot["state"] not in ["EMPTY","COOLDOWN"] or int(slot["respawn_due_ms"]) > int(state["world_time_ms"]):
			continue
		var habitat: WorldHabitat = map.habitat(slot["habitat_id"])
		if habitat == null or habitat.profile.templates.is_empty():
			continue
		if slot["pending_party"].is_empty():
			var random: RandomNumberGenerator = rngs["composition"]
			var weights: PackedFloat32Array = habitat.profile.weights
			var index: int = random.rand_weighted(weights) if weights.size() == habitat.profile.templates.size() else random.randi_range(0,habitat.profile.templates.size()-1)
			slot["pending_party"] = PartyBuilder.build(habitat.profile.templates[index],random,allocate)
		var point: Dictionary = navigation.sample_spawn(id,habitat.habitat_id,habitat.profile.radius,rngs["placement"])
		if not point["ok"]:
			slot["respawn_due_ms"] = int(state["world_time_ms"]) + 1500
			slot["last_error"] = point["reason"]
			continue
		var party: Dictionary = slot["pending_party"]
		party.merge({"map_id":id,"habitat_id":habitat.habitat_id,"slot_id":slot["slot_id"],"position":point["point"],"home":point["point"],"life_state":"ACTIVE","movement_state":"IDLE","encounter_id":"","path":PackedVector2Array(),"think_due_ms":int(state["world_time_ms"]) + 200,"chase_until_ms":0})
		runtime["parties"][party["party_id"]] = party
		slot["party_id"] = party["party_id"]
		slot["pending_party"] = {}
		slot["state"] = "OCCUPIED"
		slot["generation_index"] += 1

func current_map() -> WorldMapDefinition:
	return map_definitions.get(state["player"]["map_id"])

func party(id: String) -> Dictionary:
	for map: Dictionary in state["maps"].values():
		if map["parties"].has(id):
			return map["parties"][id]
	return {}

func checkpoint() -> Dictionary:
	var candidate: Dictionary = snapshot()
	candidate["revision"] += 1
	var result: Dictionary = save.commit(candidate)
	if result["ok"]:
		state["revision"] = candidate["revision"]
	return result

func snapshot() -> Dictionary:
	var data: Dictionary = state.duplicate(true)
	for stream: String in rngs:
		data["rng"][stream] = rngs[stream].state
	return data

func publish(candidate: Dictionary) -> void:
	state = candidate.duplicate(true)
	if UnitResourcePaths.rewrite_saved_paths(state): population_layout_changed=true
	for stream: String in rngs:
		if state["rng"].has(stream):
			rngs[stream].state = state["rng"][stream]
	changed.emit()

func move_player(to: Vector2, target_party: String = "") -> Dictionary:
	if state["mode"] != "EXPLORING" or paused:
		return {"ok":false,"reason":"BUSY"}
	var player: Dictionary = state["player"]
	var path: Dictionary = navigation.find_path(player["map_id"],"","PLAYER",player["position"],to,16)
	player_target_party = target_party if path["ok"] else ""
	player_path = path["points"]
	return path

func approach_portal(portal_id: String) -> Dictionary:
	if state["mode"]!="EXPLORING" or paused:
		return {"ok":false,"reason":"BUSY"}
	for portal: Dictionary in current_map().portals:
		if portal["id"]!=portal_id: continue
		var player: Dictionary = state["player"]
		var route: Dictionary = navigation.find_portal_approach(player["map_id"],player["position"],portal["point"],float(portal["radius"]),16)
		player_target_party = ""
		player_path = route["points"]
		return route
	return {"ok":false,"reason":"PORTAL_MISSING"}

static func advance_path(data: Dictionary, path: PackedVector2Array, amount: float, turn_rate: float = 0, delta: float = 1.0/60.0) -> PackedVector2Array:
	var heading: Vector2 = Vector2.ZERO
	while not path.is_empty() and amount > 0:
		var offset: Vector2 = path[0] - data["position"]
		var distance: float = offset.length()
		if distance > 0.01:
			heading = offset.normalized()
		if distance <= amount:
			data["position"] = path[0]
			path.remove_at(0)
			amount -= distance
		else:
			data["position"] += offset / distance * amount
			amount = 0
	if heading != Vector2.ZERO:
		data["facing"] = MovementFeel.turn_facing(data.get("facing",heading),heading,turn_rate,delta) if turn_rate > 0 else heading
	return path

func player_movement_speed() -> float:
	var members: Array = state["player_party"]["deployed_units"]
	return MovementFeel.speed(float(members[0]["resolved_stats"]["speed"]),movement_multiplier) if not members.is_empty() else 0.0

func tick(delta: float) -> void:
	if paused or state["mode"] not in ["EXPLORING","ENCOUNTER"]:
		return
	if state["mode"] == "ENCOUNTER" and state["active_encounter"].get("state","") != "COUNTDOWN":
		return
	delta_remainder += delta * 1000
	var elapsed: int = int(delta_remainder)
	delta_remainder -= elapsed
	state["world_time_ms"] += elapsed
	if state["mode"] == "ENCOUNTER":
		# Only the reserved/joining actors pause their ordinary AI. The rest of the
		# active world keeps roaming and respawning during the five-second window.
		var map: WorldMapDefinition = current_map()
		spawn_due(map.map_id)
		for monster: Dictionary in state["maps"][map.map_id]["parties"].values(): MonsterBrain.tick(self,monster,delta)
		encounters.tick(delta)
		return
	var player: Dictionary = state["player"]
	player_path = advance_path(player,player_path,player_movement_speed()*delta,turn_speed,delta)
	var map: WorldMapDefinition = current_map()
	spawn_due(map.map_id)
	for monster: Dictionary in state["maps"][map.map_id]["parties"].values():
		MonsterBrain.tick(self,monster,delta)
		if state["mode"] != "EXPLORING":
			break
	if not player_target_party.is_empty() and state["mode"] == "EXPLORING":
		var target: Dictionary = party(player_target_party)
		if target.is_empty() or target["life_state"] != "ACTIVE":
			player_target_party = ""
		elif player["position"].distance_to(target["position"]) < map.habitat(target["habitat_id"]).profile.rules.interaction_radius:
			var begin: Dictionary = encounters.try_begin("player",player_target_party,"player")
			if not begin["ok"]:
				notification.emit(begin["reason"])
			player_target_party = ""
		elif player_path.is_empty():
			move_player(target["position"],player_target_party)
	if state["mode"] == "EXPLORING":
		var inside: String = ""
		for portal: Dictionary in map.portals:
			if player["position"].distance_to(portal["point"]) <= float(portal["radius"]):
				inside = portal["id"]
				break
		if inside.is_empty():
			state["portal_protection"] = ""
		elif state["portal_protection"].is_empty():
			begin_portal(inside)

func begin_portal(portal_id: String) -> Dictionary:
	if state["mode"] != "EXPLORING" or paused:
		return {"ok":false,"reason":"BUSY"}
	var selected: Dictionary = {}
	for portal: Dictionary in current_map().portals:
		if portal["id"] == portal_id:
			selected = portal
	if selected.is_empty():
		return {"ok":false,"reason":"PORTAL_MISSING"}
	if state["player"]["position"].distance_to(selected["point"]) > float(selected["radius"]):
		return {"ok":false,"reason":"OUT_OF_RANGE"}
	var target: WorldMapDefinition = map_definitions.get(selected["target_map_id"])
	if target == null or not target.entries.has(selected["target_entry_id"]):
		return {"ok":false,"reason":"ENTRY_MISSING"}
	var entry: Dictionary = target.entries[selected["target_entry_id"]]
	if not navigation.segment_legal(target.map_id,"","PLAYER",entry["point"],entry["point"],16):
		return {"ok":false,"reason":"ILLEGAL_ENTRY"}
	var before: Dictionary = snapshot()
	var token: String = allocate("portal")
	state["control_owner"] = token
	state["mode"] = "TRANSITION"
	player_path.clear()
	player_target_party = ""
	ensure_map(target.map_id)
	state["player"].merge({"map_id":target.map_id,"position":entry["point"],"facing":entry.get("facing",Vector2.DOWN)},true)
	state["portal_protection"] = "arrival"
	var saved: Dictionary = checkpoint()
	if not saved["ok"]:
		publish(before)
		return saved
	map_requested.emit(token)
	return {"ok":true,"token":token}

func complete_portal(token: String) -> bool:
	if state["control_owner"] != token or state["mode"] != "TRANSITION":
		return false
	state["mode"] = "EXPLORING"
	state["control_owner"] = ""
	changed.emit()
	return true
