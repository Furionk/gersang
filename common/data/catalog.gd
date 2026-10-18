class_name Catalog
extends RefCounted
const PARTY_PATHS: Array[String] = ["res://features/units/data/mercenaries/merchant.tres", "res://features/units/data/mercenaries/guard.tres", "res://features/units/data/mercenaries/gunner.tres", "res://features/units/data/mercenaries/mage.tres", "res://features/units/data/mercenaries/healer.tres", "res://features/units/data/mercenaries/supplier.tres", "res://features/units/data/mercenaries/controller.tres"]
const ENEMY_PATHS: Array[String] = ["res://features/units/data/monsters/beast.tres", "res://features/units/data/monsters/archer.tres", "res://features/units/data/monsters/elite.tres", "res://features/units/data/monsters/boss.tres"]
const ENCOUNTER_PATHS: Array[String] = ["res://features/world/data/meadow.tres", "res://features/world/data/mountain.tres", "res://features/world/data/cave.tres"]
const NEW_UNIT_IDS: Array[String] = ["kohime","ninja","teppo"]
static func additional_mercenaries() -> Array[UnitDefinition]:
	var registry: MercenaryCatalog=load("res://features/progression/data/additional_mercenaries.tres")
	return registry.definitions if registry!=null else [] as Array[UnitDefinition]
static func new_unit_ids() -> Array[String]:
	var result: Array[String]=[]
	for data: UnitDefinition in additional_mercenaries(): result.append(String(data.id))
	return result
static func trial_entries() -> Array[UnitTrialEntry]:
	var registry:MercenaryCatalog=load("res://features/progression/data/additional_mercenaries.tres")
	return registry.trials if registry!=null else [] as Array[UnitTrialEntry]
static func trial_entry(id:String) -> UnitTrialEntry:
	for entry:UnitTrialEntry in trial_entries():
		if entry!=null and entry.friendly!=null and entry.friendly.id==StringName(id): return entry
	return null
static func party() -> Array[UnitDefinition]:
	var result: Array[UnitDefinition] = []
	for path: String in PARTY_PATHS:
		result.append(load(path) as UnitDefinition)
	return result
static func enemy(index: int) -> UnitDefinition:
	return load(ENEMY_PATHS[index]) as UnitDefinition
static func encounters() -> Array[EncounterDefinition]:
	var result: Array[EncounterDefinition] = []
	for path: String in ENCOUNTER_PATHS:
		result.append(load(path) as EncounterDefinition)
	return result
