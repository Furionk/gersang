@tool
class_name WorldTileLayer
extends TileMapLayer
enum Role { GROUND, OBSTACLES, WALKABLE, SAFE, SPAWN, ACTIVITY, CHASE }
@export var role: Role = Role.GROUND
@export var region_id: String = ""
@export var logical_cell_size: float = 32.0
var editor_selected: bool = false
func _ready() -> void:
	collision_enabled = false
	navigation_enabled = false
	if role>=Role.WALKABLE:
		# Logic masks can share terrain textures; never draw them as an opaque
		# floor above buildings. Their stored cells remain navigation authority.
		hide()
		if Engine.is_editor_hint(): set_editor_selected(false)
func set_editor_selected(value: bool) -> void:
	editor_selected = value
	if role<Role.WALKABLE: return
	visible = Engine.is_editor_hint() and value
	var tint: Color = Color(0.35,1.0,0.55,0.28)
	match role:
		Role.SAFE: tint = Color(0.4,0.7,1.0,0.28)
		Role.SPAWN: tint = Color(1.0,0.85,0.25,0.28)
		Role.CHASE: tint = Color(1.0,0.5,0.15,0.28)
	self_modulate = tint
func logical_center(cell: Vector2i) -> Vector2:
	return Iso.unproject(position+map_to_local(cell))
func geometry(only_blocked: bool = false) -> Array[PolygonDomain]:
	var groups: Dictionary = {}
	for cell: Vector2i in get_used_cells():
		var data: TileData = get_cell_tile_data(cell)
		if data==null: continue
		if only_blocked and not bool(data.get_custom_data("blocked")): continue
		var kind: String = str(data.get_custom_data("visual_kind"))
		if not groups.has(kind): groups[kind] = {"full":{},"parts":[]}
		var center: Vector2 = logical_center(cell)
		var shape_count: int = data.get_collision_polygons_count(0)
		for index: int in shape_count:
			var polygon: PackedVector2Array = data.get_collision_polygon_points(0,index)
			for i: int in polygon.size():
				var point: Vector2 = polygon[i]
				if is_cell_transposed(cell): point = Vector2(point.y,point.x)
				if is_cell_flipped_h(cell): point.x = -point.x
				if is_cell_flipped_v(cell): point.y = -point.y
				polygon[i] = center+Iso.unproject(point)
			if (is_cell_flipped_h(cell)!=is_cell_flipped_v(cell))!=is_cell_transposed(cell): polygon.reverse()
			var rect: Rect2 = Rect2(Vector2(cell)*logical_cell_size,Vector2.ONE*logical_cell_size)
			if shape_count==1 and absf(WorldTileGeometry.signed_area(polygon)-logical_cell_size*logical_cell_size)<0.01 and PolygonDomain.rectangle(rect).covers(polygon):
				groups[kind]["full"][cell] = true
			else: groups[kind]["parts"].append(polygon)
	var result: Array[PolygonDomain] = []
	for kind: String in groups:
		var parts: Array[PackedVector2Array] = []
		parts.assign(groups[kind]["parts"])
		result.append_array(WorldTileGeometry.domains(groups[kind]["full"],parts,logical_cell_size,kind))
	return result
func snapshot() -> WorldTileLayerData:
	var data: WorldTileLayerData = WorldTileLayerData.new()
	data.layer_name = name
	data.tile_set = tile_set
	data.cells = tile_map_data.duplicate()
	data.offset = position
	data.z = -3500 if role==Role.GROUND else -3400
	return data
