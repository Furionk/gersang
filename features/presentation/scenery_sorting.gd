@tool
class_name ScenerySorting
extends RefCounted
## Presentation only. Never writes navigation, unit poses, scene ownership or saves.
enum Mode { GROUND, DEPTH, FOREGROUND }
const GROUND_Z: int = -3200
const DEPTH_Z: int = 0
const FOREGROUND_Z: int = 1000
const OVERRIDE_KEY: StringName = &"scenery_sort_override"
const PRESET_KEY: StringName = &"scenery_sort_preset"
static var _presets: Dictionary = {}
static var _catalog_ready: bool = false

static func z_for(mode: int) -> int:
	return GROUND_Z if mode==Mode.GROUND else FOREGROUND_Z if mode==Mode.FOREGROUND else DEPTH_Z

static func apply_item(item: CanvasItem, mode: int = Mode.DEPTH) -> void:
	item.z_as_relative=false
	item.z_index=z_for(mode)
	item.y_sort_enabled=false # Body, animation, bars and selection form one foot-sorted unit.

static func is_scenery_sprite(node: Node) -> bool:
	if not node is Sprite2D: return false
	if node.has_meta("world_scenery_id") or node.has_meta(PRESET_KEY): return true
	var parent: Node = node.get_parent()
	while parent!=null:
		if parent is WorldAuthorNode or parent is Sprite2D: return false
		if parent.name==&"Scenery": return true
		parent=parent.get_parent()
	return false

static func invalidate_catalog() -> void:
	_catalog_ready=false
	_presets.clear()

static func _files(folder: String) -> Array[String]:
	var result: Array[String] = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tres"): result.append(folder+"/"+file)
	for child: String in DirAccess.get_directories_at(folder): result.append_array(_files(folder+"/"+child))
	result.sort()
	return result

static func image_key(texture: Texture2D, region: Rect2) -> String:
	if texture==null: return ""
	return texture.resource_path+":"+str(region)

static func _ensure_catalog() -> void:
	if _catalog_ready: return
	_catalog_ready=true
	# Cold-load once. Exact texture + crop matching, never filename/height guessing.
	for path: String in _files("res://features/world/data/scenery"):
		var preset: WorldSceneryDefinition = load(path) as WorldSceneryDefinition
		if preset==null or preset.texture==null: continue
		var key: String = image_key(preset.texture,preset.region())
		if not _presets.has(key): _presets[key]=preset

static func sprite_region(sprite: Sprite2D) -> Dictionary:
	var texture: Texture2D = sprite.texture
	var region: Rect2 = Rect2(Vector2.ZERO,texture.get_size()) if texture!=null else Rect2()
	if texture is AtlasTexture:
		region=texture.region
		texture=texture.atlas
	if sprite.region_enabled: region=Rect2(region.position+sprite.region_rect.position,sprite.region_rect.size)
	var frame_size: Vector2 = region.size/Vector2(sprite.hframes,sprite.vframes)
	return {"texture":texture,"region":Rect2(region.position+Vector2(sprite.frame_coords)*frame_size,frame_size)}

static func preset_for(node: Node) -> WorldSceneryDefinition:
	if node.has_meta(PRESET_KEY):
		var explicit: WorldSceneryDefinition = node.get_meta(PRESET_KEY) as WorldSceneryDefinition
		if explicit!=null: return explicit
	if node is WorldAuthorNode: return node.sprite_definition
	if not node is Sprite2D: return null
	var style: WorldSceneryDefinition = node.get_meta("world_scenery_definition") as WorldSceneryDefinition if node.has_meta("world_scenery_definition") else null
	if style!=null and not style.resource_path.is_empty() and not style.resource_path.contains("::"): return style
	# Embedded old appearance copies inherit the shared material sorting preset.
	# Explicit nondefault embedded classifications remain authoritative.
	if style!=null and (style.sorting_mode!=Mode.DEPTH or style.sorting_review_required): return style
	_ensure_catalog()
	var frame: Dictionary = sprite_region(node)
	return _presets.get(image_key(frame.texture,frame.region),style)

static func mode_for(node: Node) -> int:
	var override: int = int(node.get_meta(OVERRIDE_KEY,-1))
	if override in [Mode.GROUND,Mode.DEPTH,Mode.FOREGROUND]: return override
	var preset: WorldSceneryDefinition = preset_for(node)
	return preset.sorting_mode if preset!=null else Mode.DEPTH

static func apply_map(root: Node2D) -> void:
	root.y_sort_enabled=true
	root.z_index=0; root.z_as_relative=true
	# Enable organizational ancestors, but do not Y-sort artwork within one object.
	for node: Node in WorldAuthorTree.nodes(root):
		var author: bool = node is WorldAuthorNode and node.sprite_definition!=null and node.kind in [WorldAuthorNode.Kind.SCENERY,WorldAuthorNode.Kind.LANDMARK,WorldAuthorNode.Kind.PORTAL]
		if not is_scenery_sprite(node) and not author: continue
		apply_item(node,mode_for(node))
		if author:
			var artwork: CanvasItem = node.get_node_or_null("Artwork") as CanvasItem
			if artwork!=null:
				artwork.z_as_relative=true; artwork.z_index=0; artwork.y_sort_enabled=false
		var parent: Node = node.get_parent()
		while parent!=null and parent!=root:
			if parent is Node2D:
				parent.y_sort_enabled=true; parent.z_index=0; parent.z_as_relative=true
			parent=parent.get_parent()

static func calibration(sprite: Sprite2D, image_anchor: Vector2) -> Dictionary:
	# Pivot shift + opposite texture offset preserves every rendered pixel.
	var shift: Vector2 = sprite.get_rect().position+image_anchor
	return {"position":sprite.position+sprite.transform.basis_xform(shift),"offset":sprite.offset-shift}

static func current_anchor(sprite: Sprite2D) -> Vector2:
	return -sprite.get_rect().position
