@tool
class_name WorldTileGeometry
extends RefCounted
static func signed_area(polygon: PackedVector2Array) -> float:
	var result: float = 0
	for i: int in polygon.size(): result+=polygon[i].cross(polygon[(i+1)%polygon.size()])
	return result*0.5
static func simplify(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for i: int in points.size():
		var before: Vector2 = points[i]-points[posmod(i-1,points.size())]
		var after: Vector2 = points[(i+1)%points.size()]-points[i]
		if absf(before.cross(after))>0.00001: result.append(points[i])
	return result
static func cell_contours(cells: Dictionary, step: float) -> Array[PackedVector2Array]:
	var edges: Dictionary = {}
	for cell: Vector2i in cells:
		var corners: Array[Vector2i] = [cell,cell+Vector2i.RIGHT,cell+Vector2i.ONE,cell+Vector2i.DOWN]
		for i: int in 4:
			var a: Vector2i = corners[i]
			var b: Vector2i = corners[(i+1)%4]
			if edges.has(b) and a in edges[b]:
				edges[b].erase(a)
				if edges[b].is_empty(): edges.erase(b)
			else:
				if not edges.has(a): edges[a] = []
				edges[a].append(b)
	var result: Array[PackedVector2Array] = []
	while not edges.is_empty():
		var start: Vector2i = edges.keys()[0]
		var at: Vector2i = start
		var direction: Vector2i = Vector2i.RIGHT
		var polygon: PackedVector2Array = PackedVector2Array()
		var budget: int = cells.size()*4+4
		while budget>0:
			budget-=1
			polygon.append(Vector2(at)*step)
			if not edges.has(at): break
			var next: Vector2i = edges[at][0]
			var turn: float = -10
			for candidate: Vector2i in edges[at]:
				var ray: Vector2 = Vector2(candidate-at)
				var angle: float = atan2(Vector2(direction).cross(ray),Vector2(direction).dot(ray))
				if angle>turn: next=candidate; turn=angle
			edges[at].erase(next)
			if edges[at].is_empty(): edges.erase(at)
			direction = next-at
			at = next
			if at==start: break
		if at==start and polygon.size()>=3: result.append(simplify(polygon))
	return result
static func union_piece(solids: Array[PackedVector2Array], holes: Array[PackedVector2Array], piece: PackedVector2Array) -> void:
	if signed_area(piece)<0:
		holes.append(piece)
		return
	for i: int in range(holes.size()-1,-1,-1):
		var remaining: Array[PackedVector2Array] = Geometry2D.clip_polygons(holes[i],piece)
		holes.remove_at(i)
		holes.append_array(remaining)
	var merged: PackedVector2Array = piece
	var index: int = 0
	while index<solids.size():
		var union: Array[PackedVector2Array] = Geometry2D.merge_polygons(solids[index],merged)
		var positive: Array[PackedVector2Array] = []
		var negative: Array[PackedVector2Array] = []
		for polygon: PackedVector2Array in union:
			if signed_area(polygon)>0: positive.append(polygon)
			else: negative.append(polygon)
		if positive.size()==1:
			merged = positive[0]
			holes.append_array(negative)
			solids.remove_at(index)
			index=0
		else: index+=1
	solids.append(simplify(merged))
static func domains(cells: Dictionary, pieces: Array[PackedVector2Array], step: float, kind: String = "rock") -> Array[PolygonDomain]:
	var solids: Array[PackedVector2Array] = []
	var holes: Array[PackedVector2Array] = []
	for contour: PackedVector2Array in cell_contours(cells,step):
		if signed_area(contour)>0: solids.append(contour)
		else: holes.append(contour)
	for piece: PackedVector2Array in pieces: union_piece(solids,holes,piece)
	var result: Array[PolygonDomain] = []
	for solid: PackedVector2Array in solids:
		var domain: PolygonDomain = PolygonDomain.new()
		domain.outer = simplify(solid)
		domain.visual_kind = kind
		for hole: PackedVector2Array in holes:
			if not hole.is_empty() and Geometry2D.is_point_in_polygon(hole[0],solid): domain.holes.append(simplify(hole))
		result.append(domain)
	return result
