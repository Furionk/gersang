@tool
class_name WorldAuthoringSnapshot
extends RefCounted
## Editor roots may have placeholder script instances after a reload/build.
## Read native/exported data only; never call a method on the edited instance.
static func copy_exports(source: Node, target: Node) -> void:
	var available: Dictionary = {}
	for property: Dictionary in source.get_property_list(): available[property["name"]] = true
	var script: Script = target.get_script()
	for property: Dictionary in script.get_script_property_list() if script!=null else []:
		var usage: int = property["usage"]
		var key: StringName = property["name"]
		if usage&PROPERTY_USAGE_STORAGE and available.has(key): target.set(key,source.get(key))
	if source is Node2D and target is Node2D:
		(target as Node2D).transform = (source as Node2D).transform
		(target as Node2D).visible = (source as Node2D).visible
	target.name = source.name if not String(source.name).is_empty() else "WorldMapSnapshot"
	if source.has_meta("authoring_archived"): target.set_meta("authoring_archived",source.get_meta("authoring_archived"))
	if source.has_meta("authoring_order"): target.set_meta("authoring_order",source.get_meta("authoring_order"))
	if source.has_meta("scenery_parts"): target.set_meta("scenery_parts",source.get_meta("scenery_parts"))
	for key: StringName in [ScenerySorting.OVERRIDE_KEY,ScenerySorting.PRESET_KEY]:
		if source.has_meta(key): target.set_meta(key,source.get_meta(key))

static func copy_children(source: Node, target: Node, snapshot: Node) -> void:
	for child: Node in source.get_children():
		var copy: Node2D
		if NativeScenery.is_author(child):
			copy=Sprite2D.new()
			NativeScenery.copy_sprite(child,copy)
		elif child is WorldMonsterRegion: copy = WorldMonsterRegion.new()
		elif child is WorldAuthorNode: copy = WorldAuthorNode.new()
		elif child is WorldRegionPolygon:
			copy = WorldRegionPolygon.new()
			copy.polygon = child.get("polygon")
			copy.offset = child.get("offset")
		elif child is WorldTileLayer:
			copy = WorldTileLayer.new()
			copy.tile_set = child.get("tile_set")
			copy.tile_map_data = child.get("tile_map_data")
			copy.enabled = child.get("enabled")
		elif child is Node2D and not child is Sprite2D and not child is WorldSceneryView:
			copy = Node2D.new()
		else: continue
		copy_exports(child,copy)
		target.add_child(copy)
		copy.owner = snapshot
		copy_children(child,copy,snapshot)

static func compile(source: Node, registry: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(source): return {"ok":false,"error":"編輯場景已卸載，請重新選取地圖。"}
	if not source is WorldMap2D: return {"ok":false,"error":"目前場景不是 WorldMap2D。"}
	var snapshot: WorldMap2D = WorldMap2D.new()
	copy_exports(source,snapshot)
	if snapshot.definition==null:
		snapshot.free()
		return {"ok":false,"error":"請先配置 WorldMapDefinition。"}
	copy_children(source,snapshot,snapshot)
	# Off-tree: no _ready, editor preview, AI, RNG, save or disk roundtrip.
	var compiled: WorldMapDefinition = snapshot.compile_definition()
	var errors: Array[String] = WorldValidator.validate(compiled,WorldCatalog.definitions if registry.is_empty() else registry,snapshot)
	snapshot.free()
	return {"ok":true,"definition":compiled,"errors":errors}
