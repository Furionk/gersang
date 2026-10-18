@tool
class_name WorldNavigationService
extends RefCounted
var maps: Dictionary = {}
var caches: Dictionary = {}
var queries: int = 0

func register_map(definition: WorldMapDefinition) -> void:
	maps[definition.map_id] = definition
	for key: String in caches.keys():
		if key.begins_with(definition.map_id + ":"):
			caches.erase(key)

func _domain(map: WorldMapDefinition, habitat_id: String, mode: String) -> PolygonDomain:
	if mode == "PLAYER":
		return null
	var habitat: WorldHabitat = map.habitat(habitat_id)
	if habitat == null:
		return PolygonDomain.new()
	return habitat.spawn_domain if mode == "SPAWN" else habitat.activity_domain if mode == "WANDER" else habitat.chase_domain

func shape_legal(map_id: String, habitat_id: String, mode: String, shape: PackedVector2Array) -> bool:
	var map: WorldMapDefinition = maps.get(map_id)
	if map == null:
		return false
	var covered: bool = false
	for walkable: PolygonDomain in map.walkable:
		if walkable.covers(shape):
			covered = true
			break
	if not covered:
		return false
	var domain: PolygonDomain = _domain(map, habitat_id, mode)
	if domain != null and not domain.covers(shape):
		return false
	# Editor drafts may have an activity/spawn area extending beyond pursuit.
	# Monsters must never roam/spawn into a pose the save/encounter guard rejects.
	# PLAYER navigation and the protected movement feel are unchanged.
	if mode in ["SPAWN","WANDER"]:
		var habitat: WorldHabitat = map.habitat(habitat_id)
		if habitat!=null and not habitat.chase_domain.covers(shape): return false
		if mode=="SPAWN" and habitat!=null and not habitat.activity_domain.covers(shape): return false
	var forbidden: Array[PolygonDomain] = map.blockers.duplicate()
	if mode != "PLAYER":
		forbidden.append_array(map.safe_areas)
	for blocker: PolygonDomain in forbidden:
		# A blocker hole is passable. Inspect every contour of its intersection.
		for overlap: PackedVector2Array in Geometry2D.intersect_polygons(shape, blocker.outer):
			if PolygonDomain.area(overlap) < 0.001:
				continue
			var entirely_in_hole: bool = false
			for hole: PackedVector2Array in blocker.holes:
				var hole_domain: PolygonDomain = PolygonDomain.new()
				hole_domain.outer = hole
				if hole_domain.covers(overlap):
					entirely_in_hole = true
			if not entirely_in_hole:
				return false
	return true

func segment_legal(map_id: String, habitat_id: String, mode: String, from: Vector2, to: Vector2, radius: float) -> bool:
	if from.distance_squared_to(to) < 0.001:
		return shape_legal(map_id, habitat_id, mode, PolygonDomain.rectangle(Rect2(from - Vector2.ONE * radius, Vector2.ONE * maxf(0.02, radius * 2))).outer)
	var capsules: Array[PackedVector2Array] = Geometry2D.offset_polyline(PackedVector2Array([from,to]), maxf(0.01,radius), Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	for capsule: PackedVector2Array in capsules:
		if not shape_legal(map_id, habitat_id, mode, capsule):
			return false
	return not capsules.is_empty()

func _cache(map_id: String, habitat_id: String, mode: String, radius: float) -> Dictionary:
	var map: WorldMapDefinition = maps.get(map_id)
	if map == null:
		return {}
	var key: String = "%s:%s:%s:%s:%s" % [map_id, habitat_id, mode, radius, map.content_version]
	if caches.has(key):
		return caches[key]
	var domain: PolygonDomain = _domain(map, habitat_id, mode)
	var bounds: Rect2 = Rect2(Vector2.ZERO, map.extent)
	if domain != null:
		bounds = bounds.intersection(domain.bounds())
	var first: Vector2i = Vector2i((bounds.position / map.grid_size).floor())
	var end: Vector2i = Vector2i((bounds.end / map.grid_size).ceil())
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(first, end - first)
	grid.cell_size = Vector2.ONE * map.grid_size
	grid.offset = Vector2.ONE * map.grid_size * 0.5
	# D09 / MOVE-01: isometric vertical travel is diagonal in logical XY.
	# Both cardinal neighbors must be free; radius masks and capsule checks remain.
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	var legal_cells: Array[Vector2i] = []
	for y: int in range(first.y, end.y):
		for x: int in range(first.x, end.x):
			var cell: Vector2i = Vector2i(x,y)
			var rect: Rect2 = Rect2(Vector2(cell) * map.grid_size, Vector2.ONE * map.grid_size).grow(radius)
			var solid: bool = not shape_legal(map_id, habitat_id, mode, PolygonDomain.rectangle(rect).outer)
			grid.set_point_solid(cell, solid)
			if not solid:
				legal_cells.append(cell)
	var data: Dictionary = {"grid":grid,"cells":legal_cells,"components":{}}
	caches[key] = data
	return data

func _connection(data: Dictionary, map_id: String, habitat_id: String, mode: String, point: Vector2, radius: float) -> Variant:
	var map: WorldMapDefinition = maps[map_id]
	var grid: AStarGrid2D = data["grid"]
	var cell: Vector2i = Vector2i((point / map.grid_size).floor())
	for ring: int in 5:
		for y: int in range(-ring,ring+1):
			for x: int in range(-ring,ring+1):
				var candidate: Vector2i = cell + Vector2i(x,y)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate) and segment_legal(map_id, habitat_id, mode, point, grid.get_point_position(candidate), radius):
					return candidate
	return null

func find_path(map_id: String, habitat_id: String, mode: String, from: Vector2, to: Vector2, radius: float = 16.0) -> Dictionary:
	queries += 1
	# Avoid centre-snapping and building a full grid for an unobstructed click.
	if segment_legal(map_id,habitat_id,mode,from,to,radius):
		return {"ok":true,"reason":"OK","points":PackedVector2Array([from,to])}
	var data: Dictionary = _cache(map_id, habitat_id, mode, radius)
	if data.is_empty():
		return {"ok":false,"reason":"MAP_MISSING","points":PackedVector2Array()}
	var first: Variant = _connection(data,map_id,habitat_id,mode,from,radius)
	var last: Variant = _connection(data,map_id,habitat_id,mode,to,radius)
	if first == null or last == null:
		return {"ok":false,"reason":"ILLEGAL_CONNECTION","points":PackedVector2Array()}
	var grid: AStarGrid2D = data["grid"]
	var points: PackedVector2Array = grid.get_point_path(first,last,false)
	if points.is_empty():
		return {"ok":false,"reason":"UNREACHABLE","points":points}
	points.insert(0,from)
	points.append(to)
	return {"ok":true,"reason":"OK","points":smooth_checked(map_id,habitat_id,mode,points,radius)}

func find_portal_approach(map_id: String, from: Vector2, center: Vector2, trigger_radius: float, radius: float = 16.0) -> Dictionary:
	# A moved entrance is an interaction REGION, not a mandatory standing point.
	# Never relax collision checks or return partial paths / teleport to its art.
	var reach: float = maxf(0.0,trigger_radius-0.5)
	if from.distance_to(center)<=reach and segment_legal(map_id,"","PLAYER",from,from,radius):
		return {"ok":true,"reason":"OK","points":PackedVector2Array([from])}
	var candidates: Array[Vector2] = [center]
	for fraction: float in [0.5,0.9]:
		for index: int in 16:
			candidates.append(center+Vector2.from_angle(TAU*index/16.0)*reach*fraction)
	var map: WorldMapDefinition = maps.get(map_id)
	if map==null: return {"ok":false,"reason":"MAP_MISSING","points":PackedVector2Array()}
	var first: Vector2i = Vector2i(((center-Vector2.ONE*reach)/map.grid_size).floor())
	var last: Vector2i = Vector2i(((center+Vector2.ONE*reach)/map.grid_size).ceil())
	for y: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			var point: Vector2 = (Vector2(x,y)+Vector2.ONE*0.5)*map.grid_size
			if point.distance_to(center)<=reach: candidates.append(point)
	candidates.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(from)<b.distance_squared_to(from))
	for point: Vector2 in candidates:
		if not segment_legal(map_id,"","PLAYER",point,point,radius): continue
		var route: Dictionary = find_path(map_id,"","PLAYER",from,point,radius)
		if route["ok"]: return route
	return {"ok":false,"reason":"PORTAL_NO_REACHABLE_APPROACH","points":PackedVector2Array()}

func smooth_checked(map_id: String, habitat_id: String, mode: String, points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if points.is_empty(): return result
	result.append(points[0])
	var anchor: int = 0
	while anchor < points.size()-1:
		var next: int = anchor+1
		for candidate: int in range(points.size()-1,anchor,-1):
			if segment_legal(map_id,habitat_id,mode,points[anchor],points[candidate],radius):
				next = candidate
				break
		if result[-1].distance_squared_to(points[next]) > 0.0001: result.append(points[next])
		anchor = next
	return result

func component(data: Dictionary, start: Vector2i) -> Array[Vector2i]:
	if data["components"].has(start):
		return data["components"][start]
	var grid: AStarGrid2D = data["grid"]
	var found: Dictionary = {start:true}
	var result: Array[Vector2i] = [start]
	var cursor: int = 0
	while cursor < result.size():
		var cell: Vector2i = result[cursor]
		cursor += 1
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if grid.is_in_boundsv(next) and not grid.is_point_solid(next) and not found.has(next):
				found[next] = true
				result.append(next)
	for cell: Vector2i in result:
		data["components"][cell] = result
	return result

func sample_spawn(map_id: String, habitat_id: String, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var data: Dictionary = _cache(map_id,habitat_id,"SPAWN",radius)
	if data.is_empty() or data["cells"].is_empty():
		return {"ok":false,"reason":"NO_LEGAL_CELL"}
	var grid: AStarGrid2D = data["grid"]
	for attempt: int in 24:
		var at: Vector2 = grid.get_point_position(data["cells"][rng.randi_range(0,data["cells"].size()-1)])
		if segment_legal(map_id,habitat_id,"WANDER",at,at,radius):
			return {"ok":true,"point":at}
	return {"ok":false,"reason":"NO_ACTIVITY_CONNECTION"}

func sample_wander(map_id: String, habitat_id: String, from: Vector2, radius: float, rng: RandomNumberGenerator) -> Dictionary:
	var data: Dictionary = _cache(map_id,habitat_id,"WANDER",radius)
	if data.is_empty():
		return {"ok":false,"reason":"MAP_MISSING"}
	var first: Variant = _connection(data,map_id,habitat_id,"WANDER",from,radius)
	if first == null:
		return {"ok":false,"reason":"OUTSIDE_ACTIVITY"}
	var connected: Array[Vector2i] = component(data,first)
	var grid: AStarGrid2D = data["grid"]
	return find_path(map_id,habitat_id,"WANDER",from,grid.get_point_position(connected[rng.randi_range(0,connected.size()-1)]),radius)
