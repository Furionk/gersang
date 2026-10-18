class_name UnitResourcePaths
extends RefCounted
const PARTY_FILES: Array[String] = ["merchant","guard","gunner","mage","healer","supplier","controller"]
static func canonical(path: String) -> String:
	# Exact legacy folder relocation; unknown resources/versions remain protected.
	if path.begins_with("res://features/units/data/enemies/") and path.ends_with(".tres"):
		var file: String = path.get_file()
		var category: String = "summons" if file=="copper_reinforcement.tres" else "monsters"
		var candidate: String = "res://features/units/data/"+category+"/"+file
		return candidate if ResourceLoader.exists(candidate) else path
	if path.get_base_dir()=="res://features/units/data" and path.ends_with(".tres"):
		var file: String = path.get_file()
		var category: String = "mercenaries" if file.get_basename() in PARTY_FILES else "summons" if file=="spirit.tres" else "monsters"
		var candidate: String = "res://features/units/data/"+category+"/"+file
		return candidate if ResourceLoader.exists(candidate) else path
	return path
static func rewrite_saved_paths(value: Variant) -> bool:
	var aliases: Dictionary = {}
	_collect_school_aliases(value,aliases)
	return _rewrite(value,aliases)

static func _collect_school_aliases(value: Variant, aliases: Dictionary) -> void:
	if value is Dictionary:
		var path: String = str(value.get("definition_path",""))
		var id: String = str(value.get("definition_id",""))
		# The first school release saved inline resources. Scene repacking retired
		# their generated IDs; migrate only a verified species AND content revision.
		if path.begins_with("res://features/world/data/hogwarts.tscn::"):
			var verified: String = ""
			if id in ["school_dementor","school_dark_elf","school_gatekeeper","school_basilisk","school_cerberus","voldemort_illusion"]:
				var candidate: String = "res://features/units/data/monsters/"+id+".tres"
				if ResourceLoader.exists(candidate):
					var definition: UnitDefinition = load(candidate) as UnitDefinition
					if definition != null and str(definition.id)==id and definition.content_revision==value.get("definition_revision",-1): verified=candidate
			# Conflicting evidence must stay protected, never guess a species.
			aliases[path] = verified if not aliases.has(path) or aliases[path]==verified else ""
		for child: Variant in value.values():
			if child is Dictionary or child is Array: _collect_school_aliases(child,aliases)
	elif value is Array:
		for child: Variant in value: _collect_school_aliases(child,aliases)

static func _rewrite(value: Variant, aliases: Dictionary) -> bool:
	var changed: bool = false
	if value is Dictionary:
		for key: Variant in value.keys():
			if key in ["definition_path","representative_path"] and value[key] is String:
				var updated: String = canonical(value[key])
				if aliases.has(updated) and not str(aliases[updated]).is_empty(): updated=aliases[updated]
				if updated!=value[key]: value[key]=updated; changed=true
			elif value[key] is Dictionary or value[key] is Array:
				changed=_rewrite(value[key],aliases) or changed
	elif value is Array:
		for child: Variant in value: changed=_rewrite(child,aliases) or changed
	return changed
static func definitions() -> Array[UnitDefinition]:
	var result: Array[UnitDefinition] = []
	for category: String in ["mercenaries","monsters","summons"]:
		var files: PackedStringArray=ResourceLoader.list_directory("res://features/units/data/"+category); files.sort()
		for file: String in files:
			if file.ends_with(".tres"):
				var definition: UnitDefinition = load("res://features/units/data/"+category+"/"+file) as UnitDefinition
				if definition!=null: result.append(definition)
	return result
