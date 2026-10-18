@tool
class_name EncounterService
extends RefCounted
signal battle_requested(snapshot: Dictionary)
var context: WorldContext

func try_begin(player_id: String, enemy_id: String, initiator: String) -> Dictionary:
	var state: Dictionary = context.state
	if state["mode"] != "EXPLORING" or context.paused:
		return {"ok":false,"reason":"BUSY"}
	var enemy: Dictionary = context.party(enemy_id)
	var player: Dictionary = state["player"]
	if enemy.is_empty() or enemy["life_state"] != "ACTIVE" or player_id != "player":
		return {"ok":false,"reason":"TARGET_MISSING"}
	if enemy["map_id"] != player["map_id"]:
		return {"ok":false,"reason":"WRONG_MAP"}
	if not enemy["encounter_id"].is_empty() or not player["encounter_id"].is_empty():
		return {"ok":false,"reason":"ALREADY_RESERVED"}
	var now: int = state["world_time_ms"]
	if now < int(player["protected_until_ms"]) or now < int(player["cooldown_until_ms"]):
		return {"ok":false,"reason":"PLAYER_PROTECTED"}
	var map: WorldMapDefinition = context.current_map()
	var habitat: WorldHabitat = map.habitat(enemy["habitat_id"])
	var rules: EncounterRules = habitat.profile.rules
	var limit: float = rules.engage_radius if initiator == "monster" else rules.interaction_radius
	if player["position"].distance_to(enemy["position"]) > limit:
		return {"ok":false,"reason":"OUT_OF_RANGE"}
	for safe: PolygonDomain in map.safe_areas:
		if safe.contains(player["position"]) or safe.contains(enemy["position"]):
			return {"ok":false,"reason":"SAFE_ZONE"}
	if not context.navigation.segment_legal(map.map_id,"","PLAYER",player["position"],enemy["position"],16):
		return {"ok":false,"reason":"UNREACHABLE"}
	var arena_id: String = habitat.profile.arena_pool[0] if not habitat.profile.arena_pool.is_empty() else ""
	var arena: ArenaDefinition = WorldCatalog.arenas.get(arena_id)
	if arena == null or enemy["deployed_units"].is_empty() or state["player_party"]["deployed_units"].is_empty() or enemy["deployed_units"].size() > mini(60,arena.enemy_capacity) or state["player_party"]["deployed_units"].size() > arena.player_capacity:
		return {"ok":false,"reason":"INVALID_ARENA"}
	# No await or signals until BOTH sides and world control have been reserved.
	var id: String = context.allocate("encounter")
	state["mode"] = "ENCOUNTER"
	state["control_owner"] = id
	player["life_state"] = "RESERVED"
	player["encounter_id"] = id
	enemy["life_state"] = "RESERVED"
	enemy["encounter_id"] = id
	enemy["path"] = PackedVector2Array()
	context.player_path.clear()
	var session: Dictionary = {"encounter_id":id,"initiator":initiator,"state":"COUNTDOWN","enemy_id":enemy_id,"deadline_ms":now + rules.countdown_ms,"return_map_id":map.map_id,"return_position":player["position"],"safe_return_map_id":map.safe_return_map_id,"safe_return_entry_id":map.safe_return_entry_id,"arena_id":arena_id,"player_party_snapshot":state["player_party"].duplicate(true),"enemy_party_snapshots":[enemy.duplicate(true)],"entry_power_totals":[state["player_party"]["total_power"],enemy["total_power"]],"battle_seed":context.rngs["battle"].randi(),"reward_seed":context.rngs["reward"].randi(),"progress_before":state["progress"].duplicate(true)}
	state["active_encounter"] = session
	session["enemy_ids"] = [enemy_id]
	session["approaching_ids"] = []
	session["join_rolls"] = {}
	session["arrival_rolls"] = {}
	session["join_check_due_ms"] = now+rules.reinforcement_check_ms
	session["arrival_check_due_ms"] = {}
	var checkpoint: Dictionary = context.checkpoint()
	if not checkpoint["ok"]:
		cancel(id,"CHECKPOINT_FAILED",true)
		return {"ok":false,"reason":"CHECKPOINT_FAILED"}
	context.changed.emit()
	return {"ok":true,"reason":"STARTED","encounter_id":id}

func cancel(id: String, reason: String = "PLAYER_CANCELLED", system: bool = false) -> Dictionary:
	var state: Dictionary = context.state
	var session: Dictionary = state["active_encounter"]
	if session.is_empty() or session["encounter_id"] != id or state["control_owner"] != id:
		return {"ok":false,"reason":"STALE_TOKEN"}
	if not system and (session["state"] != "COUNTDOWN" or session["initiator"] != "player"):
		return {"ok":false,"reason":"CANNOT_CANCEL"}
	for party_id: String in reserved_ids(session):
		var enemy: Dictionary = context.party(party_id)
		if not enemy.is_empty() and enemy["encounter_id"] == id:
			enemy["encounter_id"] = ""
			enemy["life_state"] = "ACTIVE"
			enemy["path"] = PackedVector2Array()
			enemy["movement_state"] = "RETURN"
			var habitat: WorldHabitat = context.current_map().habitat(enemy["habitat_id"])
			state["player"]["cooldown_until_ms"] = int(state["world_time_ms"]) + habitat.profile.rules.reengage_cooldown_ms
	state["player"]["encounter_id"] = ""
	state["player"]["life_state"] = "ACTIVE"
	state["active_encounter"] = {}
	state["control_owner"] = ""
	state["mode"] = "EXPLORING"
	context.player_target_party = ""
	context.notification.emit("遭遇取消：" + reason)
	context.changed.emit()
	return {"ok":true,"reason":reason}

static func reserved_ids(session: Dictionary) -> Array:
	var ids: Array = session.get("enemy_ids", [session.get("enemy_id", "")]).duplicate()
	ids.append_array(session.get("approaching_ids", []))
	return ids

func _recruit_nearby(session: Dictionary, rules: EncounterRules, arena: ArenaDefinition) -> void:
	if arena.encounter.monkey_profile != null: return
	var candidates: Array = context.state["maps"][session["return_map_id"]]["parties"].keys()
	candidates.sort()
	var player_point: Vector2 = context.state["player"]["position"]
	for party_id: String in candidates:
		if session["enemy_ids"].size()>=mini(4,rules.max_enemy_parties) or session["approaching_ids"].size()>=rules.max_approaching_parties: break
		var party: Dictionary = context.party(party_id)
		if party["life_state"] != "ACTIVE" or not party["encounter_id"].is_empty() or party["position"].distance_to(player_point) > rules.reinforcement_radius: continue
		var profile: SpawnProfile = context.current_map().habitat(party["habitat_id"]).profile
		var monkey_party: bool=false
		for candidate_arena: String in profile.arena_pool:
			if candidate_arena.begins_with("monkey_garden"): monkey_party=true
		if monkey_party: continue
		if party["deployed_units"].size()>mini(60,arena.enemy_capacity): continue
		var species: UnitDefinition = load(party["representative_path"]) as UnitDefinition
		var chance: float = species.reinforcement_approach_chance if species!=null and species.reinforcement_approach_chance>=0 else profile.rules.reinforcement_chance
		var accepts: bool = context.rngs["encounter"].randf()<chance
		var rolls: Array = session["join_rolls"].get(party_id,[])
		rolls.append(accepts); session["join_rolls"][party_id]=rolls
		if not accepts: continue
		var route: Dictionary = {}
		var directions: Array[Vector2] = [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]
		for attempt: int in 4:
			var direction: Vector2 = directions[(session["approaching_ids"].size()+attempt)%4]
			var distance: float = profile.rules.reinforcement_join_distance*0.75
			route = context.navigation.find_path(session["return_map_id"],party["habitat_id"],"CHASE",party["position"],player_point+direction*distance,profile.radius)
			if route["ok"] and route["points"][-1].distance_to(player_point)<=profile.rules.reinforcement_join_distance: break
		if route.is_empty() or not route["ok"] or route["points"][-1].distance_to(player_point)>profile.rules.reinforcement_join_distance: continue
		party["life_state"] = "RESERVED"
		party["encounter_id"] = session["encounter_id"]
		party["path"] = route["points"]
		party["movement_state"] = "JOIN"
		session["approaching_ids"].append(party_id)

func tick(delta: float = 1.0/60.0) -> void:
	var session: Dictionary = context.state["active_encounter"]
	if session.is_empty() or session["state"] != "COUNTDOWN" or context.state["control_owner"] != session["encounter_id"]:
		return
	var now: int = context.state["world_time_ms"]
	var lead: Dictionary = context.party(session["enemy_id"])
	var rules: EncounterRules = context.current_map().habitat(lead["habitat_id"]).profile.rules
	var arena: ArenaDefinition = WorldCatalog.arenas[session["arena_id"]]
	if now<int(session["deadline_ms"]) and now>=int(session.get("join_check_due_ms",now)):
		session["join_check_due_ms"]=now+rules.reinforcement_check_ms
		_recruit_nearby(session,rules,arena)
	var current_count: int = 0
	for joined: Dictionary in session["enemy_party_snapshots"]: current_count+=joined["deployed_units"].size()
	if not session.has("arrival_check_due_ms"): session["arrival_check_due_ms"]={}
	if not session.has("arrival_rolls"): session["arrival_rolls"]={}
	for party_id: String in session.get("approaching_ids", []).duplicate():
		var party: Dictionary = context.party(party_id)
		if party.is_empty() or party["encounter_id"] != session["encounter_id"]: continue
		var profile: SpawnProfile = context.current_map().habitat(party["habitat_id"]).profile
		party["path"] = WorldContext.advance_path(party,party["path"],profile.speed*delta)
		if party["position"].distance_to(context.state["player"]["position"]) <= profile.rules.reinforcement_join_distance and now>=int(session["arrival_check_due_ms"].get(party_id,0)):
			session["arrival_check_due_ms"][party_id]=now+rules.reinforcement_check_ms
			if session["enemy_ids"].size()>=mini(4,rules.max_enemy_parties) or current_count+party["deployed_units"].size()>mini(60,arena.enemy_capacity): continue
			if not context.navigation.segment_legal(session["return_map_id"],party["habitat_id"],"CHASE",party["position"],context.state["player"]["position"],profile.radius): continue
			var species: UnitDefinition = load(party["representative_path"]) as UnitDefinition
			var chance: float = species.reinforcement_join_chance if species!=null and species.reinforcement_join_chance>=0 else profile.rules.reinforcement_join_chance
			var accepts: bool = context.rngs["encounter"].randf()<chance
			var rolls: Array = session["arrival_rolls"].get(party_id,[])
			rolls.append(accepts); session["arrival_rolls"][party_id]=rolls
			if not accepts:
				party["movement_state"]="HESITATE"
				continue
			party["path"] = PackedVector2Array()
			party["movement_state"] = "IDLE"
			session["approaching_ids"].erase(party_id)
			session["enemy_ids"].append(party_id)
			session["enemy_party_snapshots"].append(party.duplicate(true))
			current_count+=party["deployed_units"].size()
			session["entry_power_totals"][1] += party["total_power"]
			context.notification.emit("增援加入：%s · 第 %d 批" % [party["display_name"],session["enemy_ids"].size()])
	if int(context.state["world_time_ms"]) >= int(session["deadline_ms"]):
		# Pending approaches which did not arrive never enter the battle snapshot.
		for party_id: String in session.get("approaching_ids", []):
			var pending: Dictionary = context.party(party_id)
			if not pending.is_empty() and pending["encounter_id"] == session["encounter_id"]:
				pending.merge({"life_state":"ACTIVE","encounter_id":"","movement_state":"RETURN","path":PackedVector2Array()},true)
		session["approaching_ids"] = []
		session["state"] = "LOADING"
		if not context.checkpoint()["ok"]:
			cancel(session["encounter_id"],"FINAL_CHECKPOINT_FAILED",true)
			return
		battle_requested.emit(session.duplicate(true))

func mark_in_battle(id: String) -> bool:
	var session: Dictionary = context.state["active_encounter"]
	if session.is_empty() or context.state["control_owner"] != id or session["encounter_id"] != id or session["state"] != "LOADING":
		return false
	session["state"] = "IN_BATTLE"
	context.state["player"]["life_state"] = "IN_BATTLE"
	for party_id: String in session.get("enemy_ids", [session["enemy_id"]]):
		context.party(party_id)["life_state"] = "IN_BATTLE"
	return true

func complete_return(id: String) -> bool:
	var state: Dictionary = context.state
	if state["control_owner"] != id or not state["applied_results"].has(id):
		return false
	var session: Dictionary = state["active_encounter"]
	var protection: int = 3000
	for party_id: String in reserved_ids(session):
		var enemy: Dictionary = context.party(party_id)
		if not enemy.is_empty() and enemy["encounter_id"] == id:
			enemy["encounter_id"] = ""
			enemy["life_state"] = "ACTIVE"
			enemy["movement_state"] = "RETURN"
			protection = maxi(protection,context.map_definitions[enemy["map_id"]].habitat(enemy["habitat_id"]).profile.rules.return_protection_ms)
	state["player"].merge({"life_state":"ACTIVE","encounter_id":"","protected_until_ms":int(state["world_time_ms"]) + protection},true)
	state["active_encounter"] = {}
	state["control_owner"] = ""
	state["mode"] = "EXPLORING"
	context.changed.emit()
	return true
