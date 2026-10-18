@tool
class_name MonsterBrain
extends RefCounted

static func tick(context: WorldContext, monster: Dictionary, delta: float) -> void:
	if monster["life_state"] != "ACTIVE":
		return
	var now: int = context.state["world_time_ms"]
	var map: WorldMapDefinition = context.current_map()
	var habitat: WorldHabitat = map.habitat(monster["habitat_id"])
	var profile: SpawnProfile = habitat.profile
	var player: Dictionary = context.state["player"]
	monster["path"] = WorldContext.advance_path(monster,monster["path"],profile.speed * delta)
	if now < int(monster["think_due_ms"]):
		return
	monster["think_due_ms"] = now + 400
	var distance: float = monster["position"].distance_to(player["position"])
	var protected_player: bool = context.state["mode"]!="EXPLORING" or now < int(player["protected_until_ms"]) or now < int(player["cooldown_until_ms"])
	var detectable: bool = profile.rules.active and not protected_player and distance <= profile.rules.aggro_radius and context.navigation.segment_legal(map.map_id,habitat.habitat_id,"CHASE",monster["position"],player["position"],profile.radius)
	if detectable and monster["movement_state"] != "RETURN":
		if monster["movement_state"] != "CHASE":
			monster["chase_until_ms"] = now + profile.rules.chase_timeout_ms
		monster["movement_state"] = "CHASE"
	if monster["movement_state"] == "CHASE":
		if now >= int(monster["chase_until_ms"]) or protected_player or not habitat.chase_domain.contains(player["position"]):
			monster["movement_state"] = "RETURN"
		elif distance <= profile.rules.engage_radius:
			context.encounters.try_begin("player",monster["party_id"],"monster")
			return
		else:
			var chase: Dictionary = context.navigation.find_path(map.map_id,habitat.habitat_id,"CHASE",monster["position"],player["position"],profile.radius)
			monster["path"] = chase["points"]
			if not chase["ok"]:
				monster["movement_state"] = "RETURN"
			return
	if monster["movement_state"] == "RETURN":
		if monster["position"].distance_to(monster["home"]) < 24:
			monster["movement_state"] = "IDLE"
			monster["path"] = PackedVector2Array()
		else:
			var mode: String = "WANDER" if context.navigation.segment_legal(map.map_id,habitat.habitat_id,"WANDER",monster["position"],monster["position"],profile.radius) else "CHASE"
			var back: Dictionary = context.navigation.find_path(map.map_id,habitat.habitat_id,mode,monster["position"],monster["home"],profile.radius)
			monster["path"] = back["points"]
			monster["last_error"] = back["reason"]
			return
	if monster["path"].is_empty():
		var wander: Dictionary = context.navigation.sample_wander(map.map_id,habitat.habitat_id,monster["position"],profile.radius,context.rngs["wander"])
		monster["path"] = wander.get("points",PackedVector2Array())
		monster["movement_state"] = "WANDER" if wander["ok"] else "IDLE"
		monster["last_error"] = wander.get("reason","OK")
		monster["think_due_ms"] = now + context.rngs["wander"].randi_range(profile.wander_pause_min_ms,profile.wander_pause_max_ms)
