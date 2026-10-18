class_name DemoRules
extends RefCounted
const SETUP: DemoSetup=preload("res://features/progression/data/demo_setup.tres")
static func tools_enabled() -> bool: return SETUP.tools_enabled or OS.is_debug_build()
static func path(filename: String) -> String:
	var save_prefix: String=SETUP.save_namespace
	for argument: String in OS.get_cmdline_args():
		if argument.begins_with("res://tests/") or argument.begins_with("res://tools/"):
			save_prefix+="-test-%d"%OS.get_process_id()
			break
	return "user://"+save_prefix+"_"+filename
static func slot_for_key(key: int) -> int:
	return 9 if key==KEY_0 else key-KEY_1 if key>=KEY_1 and key<=KEY_9 else -1
static func make_record(data: UnitDefinition,index: int) -> CharacterRecord:
	var record: CharacterRecord=CharacterRecord.new()
	record.initialize(data,"party_%d"%index)
	if index>0: record.experience=CharacterRecord.CURVE.threshold(SETUP.mercenary_level)
	for i: int in SETUP.starting_items.size():
		var added: bool=record.add_item(SETUP.starting_items[i],SETUP.starting_counts[i],false)
		assert(added)
		if not added: push_error("初始物品無法放入背包："+String(SETUP.starting_items[i]))
	var stats: Dictionary=record.stats(); record.health=stats.health; record.mana=stats.mana
	return record
