class_name ItemCatalog
extends RefCounted
const IDS: Array[StringName] = [&"blade", &"coat", &"hat", &"charm", &"food", &"tea", &"material"]
static var database: Dictionary = {}
static var initialized: bool = false
static func initialize() -> void:
	if initialized: return
	initialized = true
	_scan("res://features/progression/data/items")
static func _scan(path: String) -> void:
	var files: PackedStringArray=ResourceLoader.list_directory(path); files.sort()
	for file: String in files:
		if file.ends_with("/"): _scan(path+"/"+file.trim_suffix("/")); continue
		if not file.ends_with(".tres"): continue
		var item: GearItemDefinition = load(path+"/"+file) as GearItemDefinition
		if item == null or item.id == &"": continue
		if database.has(item.id):
			push_error("Duplicate item ID: "+String(item.id))
			continue
		database[item.id] = item
static func get_item(id: StringName) -> GearItemDefinition:
	initialize()
	return database.get(id)
static func all_items() -> Array[GearItemDefinition]:
	initialize()
	var result: Array[GearItemDefinition] = []
	for item: GearItemDefinition in database.values(): result.append(item)
	return result
