class_name CharacterRecord
extends RefCounted
signal changed
const CURVE: ExperienceCurve = preload("res://features/progression/data/experience_curve.tres")
const ATTRIBUTES: Array[String] = ["strength", "agility", "intelligence", "luck"]
const BAG_SIZE: int = 10
var definition: UnitDefinition
var persistent_id: String
var experience: int = 0
var allocated: Dictionary = {"strength":0, "agility":0, "intelligence":0, "luck":0}
var equipment: Dictionary = {&"weapon":&"", &"body":&"", &"head":&"", &"charm":&"", &"hands":&"", &"belt":&"", &"feet":&"", &"ring_left":&"", &"ring_right":&""}
var bag: Array[Dictionary] = []
var health: float = -1
var mana: float = -1
var max_weight: float = 80
var last_error: String = ""

func initialize(data: UnitDefinition, id_text: String, starter: bool = true) -> void:
	definition = data
	persistent_id = id_text
	experience = CURVE.threshold(data.level)
	for i: int in BAG_SIZE:
		bag.append({"item":&"", "count":0})
	if starter:
		for id: StringName in [&"blade", &"coat", &"hat", &"charm", &"food", &"tea"]:
			add_item(id, 3 if id in [&"food", &"tea"] else 1, false)
	var values: Dictionary = stats()
	health = float(values["health"])
	mana = float(values["mana"])

func level() -> int:
	return CURVE.level_for(experience)
func points() -> int:
	var spent: int = 0
	for value: int in allocated.values():
		spent += value
	return maxi(0, (level() - 1) * 4 - spent)
func attributes() -> Dictionary:
	return {"strength":definition.strength + int(allocated["strength"]), "agility":definition.agility + int(allocated["agility"]), "intelligence":definition.intelligence + int(allocated["intelligence"]), "luck":definition.luck + int(allocated["luck"]), "vitality":definition.vitality}
func equipment_modifiers() -> Dictionary:
	var result: Dictionary = {}
	for id: StringName in equipment.values():
		var item: GearItemDefinition = ItemCatalog.get_item(id)
		if item != null:
			for key: String in item.modifiers:
				result[key] = float(result.get(key, 0)) + float(item.modifiers[key])
	return result
func stats() -> Dictionary:
	return CombatStats.calculate(definition, attributes(), level(), equipment_modifiers())
func equipment_skills() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	var ids: Dictionary = {}
	for id: StringName in equipment.values():
		var item: GearItemDefinition = ItemCatalog.get_item(id)
		if item == null: continue
		for skill: SkillDefinition in item.granted_skills:
			if skill != null and not ids.has(skill.id):
				result.append(skill); ids[skill.id] = true
	return result
func add_experience(amount: int) -> int:
	var old_level: int = level()
	experience = clampi(experience + maxi(0, amount), 0, CURVE.threshold(CURVE.max_level))
	changed.emit()
	return level() - old_level
func allocate(key: String, amount: int = 1) -> bool:
	if key not in ATTRIBUTES or amount <= 0 or points() <= 0:
		return false
	var spent: int = mini(mini(amount,100),points())
	allocated[key] = int(allocated[key]) + spent
	changed.emit()
	return true
func reset_allocations() -> int:
	var refunded: int = 0
	for key: String in ATTRIBUTES:
		refunded += int(allocated[key])
	if refunded<=0: return 0
	for key: String in ATTRIBUTES: allocated[key] = 0
	var values: Dictionary = stats()
	health = clampf(health,0,float(values["health"]))
	mana = clampf(mana,0,float(values["mana"]))
	changed.emit() # one save/recalculation, not one per point
	return refunded
func weight() -> float:
	var result: float = 0
	for cell: Dictionary in bag:
		var item: GearItemDefinition = ItemCatalog.get_item(cell["item"])
		if item != null:
			result += item.weight * int(cell["count"])
	for id: StringName in equipment.values():
		var item: GearItemDefinition = ItemCatalog.get_item(id)
		if item != null:
			result += item.weight
	return result
func add_item(id: StringName, count: int, notify: bool = true) -> bool:
	var item: GearItemDefinition = ItemCatalog.get_item(id)
	if item == null or count <= 0 or weight() + count * item.weight > max_weight:
		last_error = "超出負重或物品無效。"
		return false
	var capacity: int = 0
	for cell: Dictionary in bag:
		if int(cell["count"]) == 0:
			capacity += item.stack_limit()
		elif cell["item"] == id:
			capacity += item.stack_limit() - int(cell["count"])
	if capacity < count:
		last_error = "背包已滿。"
		return false
	var remaining: int = count
	for pass_index: int in 2:
		for cell: Dictionary in bag:
			if remaining == 0:
				break
			if (pass_index == 0 and cell["item"] == id) or (pass_index == 1 and int(cell["count"]) == 0):
				var added: int = mini(remaining, item.stack_limit() - int(cell["count"]))
				cell["item"] = id
				cell["count"] = int(cell["count"]) + added
				remaining -= added
	if notify:
		changed.emit()
	return true
func use_item(index: int, bypass_level: bool = false) -> bool:
	last_error = ""
	if index < 0 or index >= bag.size() or int(bag[index]["count"]) <= 0:
		return false
	var cell: Dictionary = bag[index]
	var item: GearItemDefinition = ItemCatalog.get_item(cell["item"])
	var values: Dictionary = stats()
	if item.kind == GearItemDefinition.Kind.EQUIPMENT:
		last_error = item.equip_error(level(),definition.role,bypass_level)
		if last_error != "": return false
		var old: StringName = equipment[item.slot_name()]
		equipment[item.slot_name()] = item.id
		cell["item"] = old
		cell["count"] = 0 if old == &"" else 1
	else:
		if item.affects_party:
			last_error = "全隊道具須透過隊伍物品服務使用。"
			return false
		if not apply_consumable(item): return false
		cell["count"] = int(cell["count"])-1
	if int(cell["count"]) == 0:
		cell["item"] = &""
	var updated: Dictionary = stats()
	health = clampf(health, 1, float(updated["health"]))
	mana = clampf(mana, 0, float(updated["mana"]))
	changed.emit()
	return true

func apply_consumable(item: GearItemDefinition) -> bool:
	var values: Dictionary = stats()
	if item.effect() == GearItemDefinition.Effect.LEVEL_UP:
		if level() >= CURVE.max_level:
			last_error = "已達 Lv.100；未消耗物品。"
			return false
		experience = CURVE.threshold(mini(CURVE.max_level,level()+item.levels_granted))
		return true
	var heals: bool = item.effect() in [GearItemDefinition.Effect.RESTORE_HP,GearItemDefinition.Effect.RESTORE_BOTH]
	var restores: bool = item.effect() in [GearItemDefinition.Effect.RESTORE_MP,GearItemDefinition.Effect.RESTORE_BOTH]
	if (not heals or health >= float(values["health"])) and (not restores or mana >= float(values["mana"])):
		last_error = "已滿，或物品暫無使用效果。"
		return false
	if health <= 0 and not item.revives:
		last_error = "此道具不能復活。"
		return false
	if heals: health = minf(float(values["health"]),maxf(0,health)+item.hp_amount())
	if restores: mana = minf(float(values["mana"]),mana+item.mp_amount())
	return true

func grant_and_equip(id: StringName, bypass_level: bool = false) -> bool:
	var candidate: CharacterRecord = CharacterRecord.new()
	candidate.initialize(definition,persistent_id,false)
	candidate.max_weight = max_weight
	if not candidate.restore(serialize()): return false
	if not candidate.add_item(id,1,false):
		last_error = candidate.last_error
		return false
	for i: int in candidate.bag.size():
		if candidate.bag[i]["item"] == id:
			if not candidate.use_item(i,bypass_level):
				last_error = candidate.last_error
				return false
			break
	if not restore(candidate.serialize()): return false
	changed.emit()
	return true
func unequip(slot: StringName) -> bool:
	var id: StringName = equipment.get(slot, &"")
	if id == &"":
		return false
	for cell: Dictionary in bag:
		if int(cell["count"]) == 0:
			cell["item"] = id
			cell["count"] = 1
			equipment[slot] = &""
			var values: Dictionary = stats()
			health = minf(health, float(values["health"]))
			mana = minf(mana, float(values["mana"]))
			changed.emit()
			return true
	last_error = "背包已滿，無法卸下。"
	return false
func serialize() -> Dictionary:
	return {"id":persistent_id, "definition_path":definition.resource_path, "xp":experience, "allocated":allocated.duplicate(), "equipment":equipment.duplicate(), "bag":bag.duplicate(true), "hp":health, "mp":mana}
func restore(data: Dictionary) -> bool:
	if data.get("id", "") != persistent_id or not data.get("xp") is int or not data.get("allocated") is Dictionary or not data.get("equipment") is Dictionary or not data.get("bag") is Array:
		return false
	var xp: int = data["xp"]
	if xp < 0 or xp > CURVE.threshold(100) or data["bag"].size() != BAG_SIZE:
		return false
	var allocation: Dictionary = data["allocated"]
	if allocation.size() != ATTRIBUTES.size():
		return false
	var spent: int = 0
	for key: String in ATTRIBUTES:
		if not allocation.get(key) is int or int(allocation[key]) < 0 or int(allocation[key]) > 396:
			return false
		spent += int(allocation[key])
	if spent > (CURVE.level_for(xp) - 1) * 4:
		return false
	var restored_bag: Array[Dictionary] = []
	for cell: Variant in data["bag"]:
		if not cell is Dictionary or not cell.get("count") is int:
			return false
		var id: StringName = StringName(str(cell.get("item", "")))
		var count: int = cell["count"]
		var item: GearItemDefinition = ItemCatalog.get_item(id)
		if count < 0 or (count == 0 and id != &"") or (count > 0 and (item == null or count > item.stack_limit())):
			return false
		restored_bag.append({"item":id, "count":count})
	var restored_equipment: Dictionary = {}
	for slot: StringName in GearItemDefinition.SLOT_NAMES:
		var id: StringName = StringName(str(data["equipment"].get(slot, "")))
		var item: GearItemDefinition = ItemCatalog.get_item(id)
		if id != &"" and (item == null or item.kind != GearItemDefinition.Kind.EQUIPMENT or item.slot_name() != slot):
			return false
		restored_equipment[slot] = id
	for key: String in ["hp", "mp"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < (1 if key == "hp" else 0):
			return false
	experience = xp
	allocated = allocation.duplicate()
	bag = restored_bag
	equipment = restored_equipment
	var values: Dictionary = stats()
	health = minf(float(data["hp"]), float(values["health"]))
	mana = minf(float(data["mp"]), float(values["mana"]))
	return weight() <= max_weight
