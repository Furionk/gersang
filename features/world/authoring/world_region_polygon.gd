@tool
class_name WorldRegionPolygon
extends Polygon2D
## Native Polygon2D vertex tools own all editing and Undo. No custom input handler.
@export var is_hole: bool = false
var editor_selected: bool = false

func _init() -> void:
	color = Color.TRANSPARENT

func _draw() -> void:
	if not Engine.is_editor_hint() or not editor_selected or polygon.size()<3: return
	var tint: Color = Color(1,0.5,0.2,0.18) if is_hole or name==&"PursuitArea" else Color(0.9,0.75,0.2,0.15) if name==&"SpawnArea" else Color(0.3,0.85,0.45,0.13)
	draw_colored_polygon(polygon,tint)
	var contour: PackedVector2Array = polygon.duplicate()
	contour.append(contour[0])
	draw_polyline(contour,Color(tint.r,tint.g,tint.b,0.95),2)

func logical_domain(root: Node) -> PolygonDomain:
	var result: PolygonDomain = PolygonDomain.new()
	var transform_to_map: Transform2D = WorldAuthorTree.canvas_transform(self,root)
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon: points.append(Iso.unproject(transform_to_map*(point+offset)))
	result.outer = points
	for child: Node in get_children():
		if child is WorldRegionPolygon and child.is_hole:
			result.holes.append(child.logical_domain(root).outer)
	return result
