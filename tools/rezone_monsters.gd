extends SceneTree
const OUT: String = "res://artifacts/monster-layout-2026-10-10/"
var author_map: WorldMap2D
var data: WorldMapDefinition
var boxes: Array[Rect2] = []
var nav: WorldNavigationService
var stats: Array[Dictionary] = []

func _initialize() -> void:
	WorldCatalog.initialize()
	for id: String in ["river_bay","shaolin_temple"]:
		var path: String = "res://features/world/data/"+id+".tscn"
		author_map = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate() as WorldMap2D
		if author_map.get_meta("monster_layout_revision",0)>=2:
			push_error("Already rezoned: preserve native artist changes.")
			author_map.free(); quit(1); return
		data = author_map.compile_definition()
		nav = WorldNavigationService.new()
		nav.register_map(data)
		boxes = visual_footprints(data)
		if id=="river_bay":
			reshape("river",Rect2(320,1664,960,256),Rect2(256,1504,1792,1024),Rect2(128,1344,2176,1376),Vector2(900,1800))
			reshape("forest",Rect2(2800,1056,640,352),Rect2(2368,736,1600,1184),Rect2(2144,512,2112,1568),Vector2(3100,1216))
			reshape("farm",Rect2(3328,2912,896,416),Rect2(3008,2656,1504,1024),Rect2(2752,2400,1888,1536),Vector2(3712,3104))
			reshape("mountain",Rect2(1856,3008,480,640),Rect2(896,2688,1568,1152),Rect2(704,2400,1936,1648),Vector2(2080,3400))
		else:
			var bronze: WorldMonsterRegion = author_map.get_node("MonsterRegions/bronze_guardian") as WorldMonsterRegion
			bronze.party_count = 5
			bronze.minimum_units = 2
			bronze.maximum_units = 4
			bronze.minimum_level = 8
			bronze.maximum_level = 10
			bronze.aggressive = true
			bronze.display_name = "演武院護院"
			add_region(bronze,"front_patrol","前院巡值僧",4,2,3,6,8,false)
			add_region(bronze,"rear_patrol","後院修行僧",3,3,4,10,12,true)
			reshape("bronze_guardian",Rect2(1312,864,384,320),Rect2(1280,832,448,384),Rect2(1056,800,704,448),Vector2(1440,1024))
			reshape("front_patrol",Rect2(320,864,448,352),Rect2(288,832,896,400),Rect2(288,800,896,432),Vector2(480,928))
			reshape("rear_patrol",Rect2(448,576,640,128),Rect2(288,288,896,480),Rect2(288,256,896,544),Vector2(896,640))
		author_map.definition = author_map.definition.duplicate(true) as WorldMapDefinition
		author_map.definition.content_version = 2
		author_map.set_meta("monster_layout_revision",2)
		var compiled: WorldMapDefinition = author_map.compile_definition()
		var errors: Array[String] = WorldValidator.validate(compiled,WorldCatalog.definitions,author_map)
		if not errors.is_empty():
			push_error("Invalid regions "+id+": "+str(errors))
			author_map.free(); quit(1); return
		# Validate navigation sampling before saving each map.
		var check_nav: WorldNavigationService = WorldNavigationService.new()
		check_nav.register_map(compiled)
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = 20261011
		for habitat: WorldHabitat in compiled.habitats:
			var sample: Dictionary = check_nav.sample_spawn(id,habitat.habitat_id,habitat.profile.radius,random)
			assert(sample.ok,"No legal spawn for "+habitat.habitat_id)
			assert(check_nav.sample_wander(id,habitat.habitat_id,sample.point,habitat.profile.radius,random).ok,"No connected wander for "+habitat.habitat_id)
		var original_path: String = OUT+"originals/features__world__data__"+id+".tscn"
		assert(FileAccess.get_sha256(path)==FileAccess.get_sha256(original_path),"Concurrent artist save; do not overwrite")
		var packed: PackedScene = PackedScene.new()
		assert(packed.pack(author_map)==OK and ResourceSaver.save(packed,path)==OK)
		print("REZONED | ",id," habitats=",compiled.habitats.size())
		author_map.free()
	var report: FileAccess = FileAccess.open(OUT+"authored-regions.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(stats,"\t")); report.close()
	quit()

func visual_footprints(map: WorldMapDefinition) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for entry: Dictionary in map.scenery:
		var style: WorldSceneryDefinition = entry.definition
		var path: String = style.resource_path
		var radius: Vector2 = Vector2.ZERO
		if path.contains("canopy_mass") or path.contains("bamboo_thicket") or path.contains("mixed_boundary"): radius = Vector2(58,58)
		elif path.contains("granite_mass") or path.contains("granite_ridge"): radius = Vector2(64,64)
		elif path.ends_with("/tree.tres"): radius = Vector2(32,32)
		elif path.ends_with("/mountain.tres"): radius = Vector2(55,55)
		elif path.contains("market_stall") or path.ends_with("/building.tres"): radius = Vector2(48,48)
		if radius!=Vector2.ZERO: result.append(Rect2(entry.point-radius,radius*2))
	return result

func legal_cells(bounds: Rect2) -> Dictionary:
	var result: Dictionary = {}
	var first: Vector2i = Vector2i((bounds.position/32).floor())
	var end: Vector2i = Vector2i((bounds.end/32).floor())
	for y: int in range(first.y,end.y):
		for x: int in range(first.x,end.x):
			var cell: Vector2i = Vector2i(x,y)
			var rect: Rect2 = Rect2(Vector2(cell)*32,Vector2(32,32))
			if not nav.shape_legal(data.map_id,"","PLAYER",PolygonDomain.rectangle(rect).outer): continue
			var allowed: bool = true
			for safe: PolygonDomain in data.safe_areas:
				if not Geometry2D.intersect_polygons(PolygonDomain.rectangle(rect).outer,safe.outer).is_empty(): allowed=false; break
			if not allowed: continue
			for box: Rect2 in boxes:
				if rect.intersects(box): allowed=false; break
			for portal: Dictionary in data.portals:
				if rect.get_center().distance_to(portal.point)<160: allowed=false; break
			if allowed: result[cell] = true
	return result

func component(cells: Dictionary, anchor: Vector2) -> Dictionary:
	assert(not cells.is_empty())
	var nearest: Vector2i = cells.keys()[0]
	for cell: Vector2i in cells:
		if (Vector2(cell)*32+Vector2(16,16)).distance_squared_to(anchor)<(Vector2(nearest)*32+Vector2(16,16)).distance_squared_to(anchor): nearest=cell
	var found: Dictionary = {nearest:true}
	var queue: Array[Vector2i] = [nearest]
	var cursor: int = 0
	while cursor<queue.size():
		var cell: Vector2i = queue[cursor]
		cursor+=1
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if cells.has(next) and not found.has(next): found[next]=true; queue.append(next)
	return found

func reshape(id: String, spawn_bounds: Rect2, activity_bounds: Rect2, chase_bounds: Rect2, anchor: Vector2) -> void:
	var region: WorldMonsterRegion = author_map.get_node("MonsterRegions/"+id) as WorldMonsterRegion
	var chase: Dictionary = component(legal_cells(chase_bounds),anchor)
	var activity: Dictionary = legal_cells(activity_bounds)
	for cell: Vector2i in activity.keys():
		if not chase.has(cell): activity.erase(cell)
	activity = component(activity,anchor)
	var spawn: Dictionary = {}
	for cell: Vector2i in activity:
		if spawn_bounds.has_point(Vector2(cell)*32+Vector2(16,16)): spawn[cell]=true
	spawn = component(spawn,anchor)
	for pair: Array in [["SpawnArea",spawn],["RoamingArea",activity],["PursuitArea",chase]]:
		var shapes: Array[PolygonDomain] = WorldTileGeometry.domains(pair[1],[],32,"grass")
		assert(shapes.size()==1,"Connected single domain required "+id+" "+pair[0])
		var polygon: WorldRegionPolygon = region.get_node(pair[0]) as WorldRegionPolygon
		for old: Node in polygon.get_children().duplicate(): polygon.remove_child(old); old.free()
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in shapes[0].outer: points.append(Iso.project(point)-region.position)
		polygon.polygon = points
		for index: int in shapes[0].holes.size():
			var hole: WorldRegionPolygon = WorldRegionPolygon.new()
			hole.name = "VisualExclusion_%02d" % index
			hole.is_hole = true
			var vertices: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in shapes[0].holes[index]: vertices.append(Iso.project(point)-region.position)
			hole.polygon = vertices
			polygon.add_child(hole)
			hole.owner = author_map
		stats.append({"map":data.map_id,"region":id,"shape":pair[0],"cells":pair[1].size(),"holes":shapes[0].holes.size()})

func add_region(base: WorldMonsterRegion, id: String, title: String, count: int, minimum: int, maximum: int, min_level: int, max_level: int, active: bool) -> void:
	var region: WorldMonsterRegion = base.duplicate() as WorldMonsterRegion
	region.name = id
	region.stable_id = id
	region.display_name = title
	region.party_count = count
	region.minimum_units = minimum
	region.maximum_units = maximum
	region.minimum_level = min_level
	region.maximum_level = max_level
	region.aggressive = active
	region.remove_meta("authoring_order")
	author_map.get_node("MonsterRegions").add_child(region)
	region.owner = author_map
	for child: Node in WorldAuthorTree.nodes(region): child.owner = author_map
