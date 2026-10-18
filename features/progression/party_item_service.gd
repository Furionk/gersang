class_name PartyItemService
extends RefCounted

static func use_item(owner: CharacterRecord, index: int, party: Array[CharacterRecord], actors: Array[TacticalUnit] = []) -> Dictionary:
	if owner == null or index < 0 or index >= owner.bag.size() or owner.bag[index]["count"] <= 0:
		return {"ok":false,"reason":"沒有此物品。"}
	var item: GearItemDefinition = ItemCatalog.get_item(owner.bag[index]["item"])
	if item == null: return {"ok":false,"reason":"物品定義遺失。"}
	owner.last_error = ""
	if item.debug_only and not DemoRules.tools_enabled(): return {"ok":false,"reason":"此版本未開放隊伍與道具工具。"}
	if item.effect() == GearItemDefinition.Effect.NONE and item.kind != GearItemDefinition.Kind.EQUIPMENT:
		return {"ok":false,"reason":"此食品／材料目前沒有食用效果；未消耗。"}
	var affected: Array[CharacterRecord] = []
	if item.affects_party: affected.assign(party)
	else: affected.append(owner)
	for actor: TacticalUnit in actors:
		if actor.character == owner:
			owner.health = actor.vitals.health
			owner.mana = actor.vitals.mana
			if not actor.alive() and not item.revives: return {"ok":false,"reason":"兵已倒下，此道具不能復活。"}
	if item.kind == GearItemDefinition.Kind.EQUIPMENT:
		if not owner.use_item(index): return {"ok":false,"reason":owner.last_error}
	else:
		var recipients: Array[CharacterRecord] = affected
		var changed: bool = false
		for record: CharacterRecord in recipients:
			for actor: TacticalUnit in actors:
				if actor.character == record:
					record.health = actor.vitals.health
					record.mana = actor.vitals.mana
			if record.apply_consumable(item): changed = true
		# Party medicine also treats wounded summons, even when permanent members are full.
		if item.affects_party:
			for actor: TacticalUnit in actors:
				if actor.character==null and actor.team==0:
					if (item.hp_amount()>0 and actor.vitals.health<actor.vitals.max_health and (actor.alive() or item.revives)) or (item.mp_amount()>0 and actor.vitals.mana<actor.vitals.max_mana): changed=true
		if not changed: return {"ok":false,"reason":"全隊體力與法力已滿，不需要大補丸；未消耗。" if item.affects_party else owner.last_error if owner.last_error != "" else "沒有可回復的體力／法力；未消耗。"}
		owner.bag[index]["count"] -= 1
		if owner.bag[index]["count"] == 0: owner.bag[index]["item"] = &""
		# One notification after the complete party mutation, not a save per member.
		owner.changed.emit()
	for actor: TacticalUnit in actors:
		if actor.character != null:
			if actor.character not in affected: continue
			if actor.character.health > 0 and not actor.alive(): actor.revive_from_item(actor.character.health,actor.character.mana)
			else:
				actor.vitals.health = clampf(actor.character.health,0,actor.vitals.max_health)
				actor.vitals.mana = clampf(actor.character.mana,0,actor.vitals.max_mana)
			actor.vitals.changed.emit()
		elif item.affects_party and actor.team == 0:
			actor.vitals.recover(item.hp_amount(),item.mp_amount(),item.revives)
	return {"ok":true,"reason":"已使用 " + item.display_name,"item_id":item.id}
