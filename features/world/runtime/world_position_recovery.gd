@tool
class_name WorldPositionRecovery
extends RefCounted
## Geometry edits invalidate poses, not player progression or enemy identities.
static func replacement(context: WorldContext, map: WorldMapDefinition, party: Dictionary) -> Dictionary:
	var habitat: WorldHabitat = map.habitat(party.get("habitat_id",""))
	if habitat==null or not party.get("position") is Vector2 or not party.position.is_finite(): return {"ok":false}
	return WorldPopulationLayout.nearest_spawn(context,map,habitat,party.position)
static func repair(context: WorldContext) -> bool:
	if not context.state.active_encounter.is_empty(): return false
	var repairs: Array[Dictionary] = []
	for map_id: String in context.state.maps:
		var map: WorldMapDefinition = context.map_definitions[map_id]
		for party: Dictionary in context.state.maps[map_id].parties.values():
			var habitat: WorldHabitat = map.habitat(party.habitat_id)
			if context.navigation.segment_legal(map_id,party.habitat_id,"CHASE",party.position,party.position,habitat.profile.radius): continue
			var point: Dictionary = replacement(context,map,party)
			if not point.ok:
				context.paused = true
				context.notification.emit("怪物位置無合法修復點；原進度保留，請修正怪區。")
				return false
			repairs.append({"party":party,"point":point.point})
	for item: Dictionary in repairs:
		item.party.position = item.point
		item.party.home = item.point
		item.party.path = PackedVector2Array()
		item.party.movement_state = "IDLE"
		item.party.think_due_ms = int(context.state.world_time_ms)+200
	if not repairs.is_empty(): context.notification.emit("已修復 %d 支怪隊的失效位置；成員及玩家進度保留。" % repairs.size())
	return not repairs.is_empty()
