class_name ItemDebugService
extends RefCounted
var director: GameDirector
var practice_records: Array[CharacterRecord] = []
var practice_serial: int = -1

func records() -> Array[CharacterRecord]:
	if director.mode != &"battle": return PartyProgress.records
	if not director.battle_records.is_empty(): return director.battle_records
	if practice_serial != director.level_serial:
		practice_serial = director.level_serial
		practice_records.clear()
		for original: CharacterRecord in PartyProgress.records:
			var record: CharacterRecord = CharacterRecord.new()
			record.initialize(original.definition,original.persistent_id,false)
			record.restore(original.serialize())
			practice_records.append(record)
		for actor: TacticalUnit in actors():
			if actor.permanent_slot >= 0 and actor.permanent_slot < practice_records.size():
				var hp: float = actor.vitals.health
				var mp: float = actor.vitals.mana
				actor.attach_character(practice_records[actor.permanent_slot],actor.permanent_slot)
				actor.vitals.health = hp
				actor.vitals.mana = mp
	return practice_records

func actors() -> Array[TacticalUnit]:
	var result: Array[TacticalUnit] = []
	for actor: TacticalUnit in director.units.values():
		if actor.team == 0: result.append(actor)
	return result

func selected_slot() -> int:
	if director.mode == &"battle" and director.selection != null:
		for id: int in director.selection.selected_ids:
			var actor: TacticalUnit = director.get_unit(id)
			if actor != null and actor.permanent_slot >= 0: return actor.permanent_slot
	return PartyProgress.selected_slot

func perform(id: StringName, operation: String, slot: int, count: int = 1, bypass_level: bool = true) -> Dictionary:
	if director.phases!=null and director.phases.frozen(): return {"ok":false,"reason":"首領變身暫停中。"}
	if not DemoRules.tools_enabled(): return {"ok":false,"reason":"非 Debug 模式。"}
	if director.mode not in [&"world",&"battle"]: return {"ok":false,"reason":"倒數、載入與結算時不能改物品。"}
	var members: Array[CharacterRecord] = records()
	if slot < 0 or slot >= members.size(): return {"ok":false,"reason":"沒有選取永久兵種。"}
	var record: CharacterRecord = members[slot]
	var item: GearItemDefinition = ItemCatalog.get_item(id)
	if item == null: return {"ok":false,"reason":"未知物品。"}
	for actor: TacticalUnit in actors():
		if actor.character == record:
			record.health = actor.vitals.health
			record.mana = actor.vitals.mana
	var ok: bool = false
	match operation:
		"grant": ok = record.add_item(id,count)
		"equip":
			ok = record.grant_and_equip(id,bypass_level)
			if ok:
				for actor: TacticalUnit in actors():
					if actor.character == record:
						actor.issue_command({"kind":"stop"})
		"use":
			for i: int in record.bag.size():
				if record.bag[i]["item"] == id:
					var result: Dictionary = PartyItemService.use_item(record,i,members,actors())
					ok = result["ok"]
					if not ok: return result
					break
	if not ok: return {"ok":false,"reason":record.last_error if record.last_error != "" else "背包沒有此道具；先按取得。"}
	for skill: SkillDefinition in record.equipment_skills(): GameSettings.register_skill(skill)
	if director.selection != null: director.selection._sync_selection()
	if director.world_hero != null and director.mode == &"world":
		director.world_hero.vitals.health = PartyProgress.records[0].health
		director.world_hero.vitals.mana = PartyProgress.records[0].mana
	return {"ok":true,"reason":"%s：%s %s%s" % [record.definition.display_name,{"grant":"取得","equip":"裝備","use":"使用"}[operation],item.display_name,"（本場臨時）" if director.mode == &"battle" else ""],"slot":slot}
