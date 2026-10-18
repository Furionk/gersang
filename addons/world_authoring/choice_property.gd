@tool
extends EditorProperty
var choice: OptionButton
var values: Array = []
var mode: String = ""
var registry: Dictionary = {}

func _init() -> void:
	choice = OptionButton.new()
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(choice)
	add_focusable(choice)
	choice.item_selected.connect(func(index: int) -> void: emit_changed(get_edited_property(),values[index]))

func _update_property() -> void:
	choice.clear()
	values.clear()
	var object: Object = get_edited_object()
	var value: Variant = object.get(get_edited_property())
	WorldCatalog.initialize()
	var maps: Dictionary = WorldCatalog.definitions if registry.is_empty() else registry
	if mode=="monster":
		for unit: UnitDefinition in UnitResourcePaths.definitions():
			choice.add_item(unit.display_name+"  ["+String(unit.id)+"]")
			values.append(unit)
	elif mode=="target_map_id":
		for id: String in maps:
			choice.add_item(maps[id].display_name+"  ["+id+"]")
			values.append(id)
	else:
		var target: WorldMapDefinition = maps.get(object.get("target_map_id"))
		if target!=null:
			for id: String in target.entries:
				choice.add_item(id+"  "+str(target.entries[id].point))
				values.append(id)
	var found: int = -1
	for index: int in values.size():
		if (values[index] is UnitDefinition and value is UnitDefinition and values[index].id==value.id) or values[index]==value: found=index
	if found<0:
		choice.add_item("未設定／無效："+str(value))
		values.append(value)
		found=values.size()-1
	choice.select(found)

func _set_read_only(value: bool) -> void: choice.disabled = value
