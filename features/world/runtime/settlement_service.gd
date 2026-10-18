@tool
class_name SettlementService
extends RefCounted
var context: WorldContext
var pending: Dictionary = {}

func apply(result: Dictionary) -> Dictionary:
	var id: String = result.get("encounter_id","")
	if context.state["applied_results"].has(id):
		return {"ok":true,"receipt":context.state["applied_results"][id],"duplicate":true}
	var session: Dictionary = context.state["active_encounter"]
	if session.is_empty() or session["encounter_id"] != id or context.state["control_owner"] != id or session["state"] not in ["IN_BATTLE","SETTLING"] or result.get("outcome","") not in ["victory","retreat","defeat"]:
		return {"ok":false,"reason":"INVALID_RESULT"}
	if not pending.has(id):
		var candidate: Dictionary = context.snapshot()
		var outcome: String = result["outcome"]
		var enemies: Array[Dictionary] = []
		for party_id: String in session.get("enemy_ids", [session["enemy_id"]]):
			var enemy: Dictionary = candidate["maps"][session["return_map_id"]]["parties"].get(party_id,{})
			if enemy.is_empty() or enemy["encounter_id"] != id:
				return {"ok":false,"reason":"MISSING_RESERVED_PARTY"}
			enemies.append(enemy)
		var defeated: Array = result.get("defeated_enemy_unit_ids",[])
		if not result.get("consumed_items",[]).is_empty():
			return {"ok":false,"reason":"UNSUPPORTED_ITEM_CONSUMPTION"}
		var unique_defeated: Dictionary = {}
		var valid_ids: Dictionary = {}
		var total_exp: int = 0
		for enemy: Dictionary in enemies:
			for unit: Dictionary in enemy["deployed_units"]:
				valid_ids[unit["unit_id"]] = true
				if unit["unit_id"] in defeated:
					total_exp += int(unit["experience_reward"])
		for defeated_id: String in defeated:
			if not valid_ids.has(defeated_id) or unique_defeated.has(defeated_id):
				return {"ok":false,"reason":"UNKNOWN_ENEMY"}
			unique_defeated[defeated_id] = true
		if outcome == "victory" and unique_defeated.size() != valid_ids.size():
			return {"ok":false,"reason":"VICTORY_WITH_LIVING_ENEMIES"}
		var unit_results: Dictionary = {}
		for unit: Dictionary in result.get("player_unit_results",[]):
			if unit_results.has(unit.get("unit_id","")):
				return {"ok":false,"reason":"DUPLICATE_MEMBER"}
			unit_results[unit["unit_id"]] = unit
		var members: Array = session["player_party_snapshot"]["deployed_units"]
		var monkey_mode: bool = String(session.get("arena_id","")).begins_with("monkey_garden")
		if unit_results.size() != members.size():
			return {"ok":false,"reason":"MISSING_MEMBER_RESULT"}
		var updated: Array[Dictionary] = []
		for i: int in members.size():
			var member: Dictionary = members[i]
			if not unit_results.has(member["unit_id"]):
				return {"ok":false,"reason":"UNKNOWN_PLAYER"}
			var record: CharacterRecord = CharacterRecord.new()
			record.initialize(load(member["definition_path"]) as UnitDefinition,member["unit_id"],false)
			record.restore(member["record"])
			var values: Dictionary = unit_results[member["unit_id"]]
			if not values.get("hp") is float and not values.get("hp") is int:
				return {"ok":false,"reason":"INVALID_HP"}
			if not values.get("mp") is float and not values.get("mp") is int:
				return {"ok":false,"reason":"INVALID_MP"}
			if not is_finite(float(values["hp"])) or not is_finite(float(values["mp"])):
				return {"ok":false,"reason":"INVALID_VITALS"}
			record.health = clampf(float(values["hp"]),1,record.stats()["health"])
			record.mana = clampf(float(values["mp"]),0,record.stats()["mana"])
			if monkey_mode and i>0:
				record.health=float(member.current_hp); record.mana=float(member.current_mp)
			if outcome == "victory":
				record.add_experience(total_exp / members.size() + (1 if i < total_exp % members.size() else 0))
				if i == 0:
					record.add_item(&"material",1,false)
			elif outcome == "defeat" and (not monkey_mode or i==0):
				record.health = record.stats()["health"]
				record.mana = record.stats()["mana"]
			updated.append(record.serialize())
		candidate["progress"]["party"] = updated
		var receipt: Dictionary = {"encounter_id":id,"outcome":outcome,"experience":total_exp if outcome == "victory" else 0,"loot":1 if outcome == "victory" else 0,"world_time_ms":candidate["world_time_ms"]}
		for enemy: Dictionary in enemies:
			if outcome == "victory":
				var slot: Dictionary = candidate["maps"][session["return_map_id"]]["slots"][enemy["slot_id"]]
				var profile: SpawnProfile = context.map_definitions[enemy["map_id"]].habitat(enemy["habitat_id"]).profile
				var random: RandomNumberGenerator = RandomNumberGenerator.new()
				random.state = candidate["rng"]["reward"]
				slot.merge({"state":"COOLDOWN","party_id":"","respawn_due_ms":int(candidate["world_time_ms"]) + random.randi_range(profile.respawn_min_ms,profile.respawn_max_ms)},true)
				candidate["rng"]["reward"] = random.state
				candidate["maps"][session["return_map_id"]]["parties"].erase(enemy["party_id"])
			else:
				for unit: Dictionary in enemy["deployed_units"]:
					unit["current_hp"] = unit["resolved_stats"]["health"]
					unit["current_mp"] = unit["resolved_stats"]["mana"]
		candidate["player"]["map_id"] = session["return_map_id"]
		candidate["player"]["position"] = session["return_position"]
		if outcome == "defeat":
			candidate["player"]["map_id"] = session["safe_return_map_id"]
			candidate["player"]["position"] = context.map_definitions[session["safe_return_map_id"]].entries[session["safe_return_entry_id"]]["point"]
		candidate["active_encounter"]["state"] = "RETURNING"
		candidate["applied_results"][id] = receipt
		candidate["revision"] += 1
		pending[id] = candidate
		context.state["active_encounter"]["state"] = "SETTLING"
	var saved: Dictionary = context.save.commit(pending[id])
	if not saved["ok"]:
		return saved
	context.publish(pending[id])
	pending.erase(id)
	return {"ok":true,"receipt":context.state["applied_results"][id],"duplicate":false}
