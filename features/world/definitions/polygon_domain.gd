@tool
class_name PolygonDomain
extends Resource
@export var outer: PackedVector2Array = PackedVector2Array()
@export var holes: Array[PackedVector2Array] = []
@export var visual_kind: String = "rock"

static func rectangle(rect: Rect2) -> PolygonDomain:
	var domain: PolygonDomain = PolygonDomain.new()
	domain.outer = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	return domain

func contains(point: Vector2) -> bool:
	if outer.size() < 3 or not Geometry2D.is_point_in_polygon(point, outer):
		return false
	for hole: PackedVector2Array in holes:
		if Geometry2D.is_point_in_polygon(point, hole):
			return false
	return true

static func area(polygon: PackedVector2Array) -> float:
	var total: float = 0
	for i: int in polygon.size():
		total += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(total) * 0.5

func covers(polygon: PackedVector2Array) -> bool:
	# Difference/intersection of the ENTIRE shape, not corners only.
	if outer.size() < 3 or polygon.size() < 3:
		return false
	for remainder: PackedVector2Array in Geometry2D.clip_polygons(polygon, outer):
		if area(remainder) > 0.001:
			return false
	for hole: PackedVector2Array in holes:
		for overlap: PackedVector2Array in Geometry2D.intersect_polygons(polygon, hole):
			if area(overlap) > 0.001:
				return false
	return true

func translated(offset: Vector2) -> PolygonDomain:
	var copy: PolygonDomain = duplicate(true) as PolygonDomain
	for i: int in copy.outer.size():
		copy.outer[i] += offset
	for h: int in copy.holes.size():
		for i: int in copy.holes[h].size():
			copy.holes[h][i] += offset
	return copy

static func filled_area(contours: Array[PackedVector2Array]) -> float:
	var total: float = 0
	for contour: PackedVector2Array in contours: total += WorldTileGeometry.signed_area(contour)
	return absf(total)

func covers_domain(other: PolygonDomain) -> bool:
	# Both sets can contain holes. Do not mistake the other's excluded area for land.
	if other==null or outer.size()<3 or other.outer.size()<3: return false
	var outside: float = filled_area(Geometry2D.clip_polygons(other.outer,outer))
	for cut: PackedVector2Array in other.holes:
		outside -= filled_area(Geometry2D.clip_polygons(cut,outer))
	if outside>0.001: return false
	for cut: PackedVector2Array in holes:
		var occupied: float = filled_area(Geometry2D.intersect_polygons(other.outer,cut))
		for other_cut: PackedVector2Array in other.holes:
			occupied -= filled_area(Geometry2D.intersect_polygons(other_cut,cut))
		if occupied>0.001: return false
	return true

func bounds() -> Rect2:
	if outer.is_empty():
		return Rect2()
	var rect: Rect2 = Rect2(outer[0], Vector2.ZERO)
	for point: Vector2 in outer:
		rect = rect.expand(point)
	return rect
