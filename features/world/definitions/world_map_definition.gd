@tool
class_name WorldMapDefinition
extends Resource
var tile_authoring_errors: Array[String] = []
enum Kind { EXTERIOR, TOWN, DUNGEON }
@export var map_id: String = ""
@export var display_name: String = "地圖"
@export var kind: Kind = Kind.EXTERIOR
@export var content_version: int = 1
@export_file("*.tscn") var scene_path: String = ""
@export var extent: Vector2 = Vector2(6144, 4096)
@export var grid_size: float = 32.0
@export var terrain: int = 0
@export var atlas_rect: Rect2 = Rect2(0.3, 0.25, 0.5, 0.39)
@export var atlas_projection_origin: Vector2 = Vector2(0.4734,-0.0191)
@export var atlas_projection_scale: Vector2 = Vector2(0.000044,0.000127)
@export var safe_return_map_id: String = "qingling_town"
@export var safe_return_entry_id: String = "clinic"
@export var walkable: Array[PolygonDomain] = []
@export var blockers: Array[PolygonDomain] = []
@export var safe_areas: Array[PolygonDomain] = []
@export var habitats: Array[WorldHabitat] = []
## 已移除怪區的舊定義，只讓進行中的舊遭遇完成；不生成新槽，完成後清除。
@export var retired_habitats: Array[WorldHabitat] = []
@export var entries: Dictionary = {}
@export var portals: Array[Dictionary] = []
@export var landmarks: Array[Dictionary] = []
@export var roads: Array[PackedVector2Array] = []
@export var native_tile_layers: Array[WorldTileLayerData] = []
@export var scenery: Array[Dictionary] = []

func to_atlas(point: Vector2) -> Vector2:
	return atlas_projection_origin + Iso.project(point) * atlas_projection_scale

func from_atlas(uv: Vector2) -> Vector2:
	return Iso.unproject((uv - atlas_projection_origin) / atlas_projection_scale)

func atlas_boundary() -> PackedVector2Array:
	return PackedVector2Array([to_atlas(Vector2.ZERO),to_atlas(Vector2(extent.x,0)),to_atlas(extent),to_atlas(Vector2(0,extent.y))])

func habitat(id: String) -> WorldHabitat:
	for region: WorldHabitat in habitats:
		if region.habitat_id == id:
			return region
	for region: WorldHabitat in retired_habitats:
		if region.habitat_id==id: return region
	return null

func is_retired_habitat(id: String) -> bool:
	if habitats.any(func(h: WorldHabitat)->bool: return h.habitat_id==id): return false
	return retired_habitats.any(func(h: WorldHabitat)->bool: return h.habitat_id==id)
