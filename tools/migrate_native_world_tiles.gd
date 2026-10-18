extends SceneTree
const MAPS: Array[String] = ["river_bay","qingling_town","well_1","well_2"]
const STEP: float = 32
const KINDS: Array[String] = ["ground","road","water","forest","rock","building"]
const LABELS: Array[String] = ["地面","道路","水域","森林","岩石","城牆"]
func _initialize() -> void: call_deferred("run")
func texture(terrain: int, marker: bool = false) -> ImageTexture:
	# Reuse the project's established planar->diamond bitmap sampling, no source PNG edits.
	var image: Image = Image.create(64*6,32*16,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var sources: Array[Image] = []
	for path: String in ["res://art/terrain/grass.png","res://art/terrain/stone.png","res://art/terrain/cave.png"]:
		sources.append((load(path) as Texture2D).get_image())
	var base: Image = sources[terrain]
	for kind: int in 6:
		for mask: int in 16:
			for y: int in 32:
				for x: int in 64:
					var dx: float = (x-31.5)/32
					var dy: float = (y-15.5)/16
					if absf(dx)+absf(dy)>1: continue
					var u: float = (float(x)/64+float(y)/32)*0.5
					var v: float = (float(y)/32-float(x)/64)*0.5+0.5
					var color: Color = base.get_pixel(clampi(int(u*base.get_width()),0,base.get_width()-1),clampi(int(v*base.get_height()),0,base.get_height()-1))
					if marker: color = Color(0.5,0.8,0.55,0.7)
					elif kind==1: color=color.lerp(Color(0.46,0.36,0.24),0.68)
					elif kind==2: color=Color(0.08,0.27,0.35).lightened(0.03*sin(x*0.4+y*0.8))
					elif kind==3: color=color.darkened(0.25)
					elif kind==4: color=sources[1].get_pixel(clampi(int(u*sources[1].get_width()),0,sources[1].get_width()-1),clampi(int(v*sources[1].get_height()),0,sources[1].get_height()-1))
					elif kind==5: color=sources[2].get_pixel(clampi(int(u*sources[2].get_width()),0,sources[2].get_width()-1),clampi(int(v*sources[2].get_height()),0,sources[2].get_height()-1)).darkened(0.1)
					image.set_pixel(kind*64+x,mask*32+y,color)
	return ImageTexture.create_from_image(image)
func make_tiles(terrain: int, marker: bool = false) -> TileSet:
	var set: TileSet = TileSet.new()
	set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	set.tile_size = Vector2i(64,32)
	set.add_physics_layer()
	set.set_physics_layer_collision_layer(0,0)
	set.add_custom_data_layer()
	set.set_custom_data_layer_name(0,"blocked")
	set.set_custom_data_layer_type(0,TYPE_BOOL)
	set.add_custom_data_layer()
	set.set_custom_data_layer_name(1,"visual_kind")
	set.set_custom_data_layer_type(1,TYPE_STRING)
	set.add_terrain_set()
	set.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_SIDES)
	for kind: int in 2:
		set.add_terrain(0)
		set.set_terrain_name(0,kind,LABELS[kind])
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = texture(terrain,marker)
	atlas.texture_region_size = Vector2i(64,32)
	set.add_source(atlas,0)
	for kind: int in 6:
		for mask: int in 16:
			var cell: Vector2i = Vector2i(kind,mask)
			atlas.create_tile(cell)
			var data: TileData = atlas.get_tile_data(cell,0)
			data.set_custom_data("blocked",not marker and kind>=2)
			data.set_custom_data("visual_kind","mask" if marker else KINDS[kind])
			data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,-16),Vector2(32,0),Vector2(0,16),Vector2(-32,0)]))
			if kind>=2: continue
			data.terrain_set = 0
			data.terrain = kind
			var side: int = 0
			for bit: int in 16:
				if data.is_valid_terrain_peering_bit(bit):
					data.set_terrain_peering_bit(bit,kind if mask&(1<<side) else 1-kind)
					side+=1
	for kind: int in 2:
		for code: int in 81:
			var tile: Vector2i = Vector2i(kind,15)
			var alternative: int = atlas.create_alternative_tile(tile)
			var data: TileData = atlas.get_tile_data(tile,alternative)
			data.set_custom_data("blocked",false)
			data.set_custom_data("visual_kind","mask" if marker else KINDS[kind])
			data.set_collision_polygons_count(0,1)
			data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,-16),Vector2(32,0),Vector2(0,16),Vector2(-32,0)]))
			data.terrain_set = 0
			data.terrain = kind
			var digits: int = code
			for bit: int in 16:
				if data.is_valid_terrain_peering_bit(bit):
					data.set_terrain_peering_bit(bit,digits%3-1)
					digits/=3
	return set
func layer(root: WorldMap2D, title: String, role: WorldTileLayer.Role, set: TileSet, id: String = "") -> WorldTileLayer:
	var node: WorldTileLayer = WorldTileLayer.new()
	node.name = title
	node.role = role
	node.region_id = id
	node.tile_set = set
	node.position = Vector2(-32,0)
	node.collision_enabled = false
	node.navigation_enabled = false
	node.z_index = -3500 if role==WorldTileLayer.Role.GROUND else -3400 if role==WorldTileLayer.Role.OBSTACLES else 100
	node.visible = role<WorldTileLayer.Role.WALKABLE
	root.add_child(node)
	node.owner = root
	return node
func paint_domain(target: WorldTileLayer, domain: PolygonDomain, kind: int) -> void:
	var bounds: Rect2 = domain.bounds()
	var from: Vector2i = Vector2i((bounds.position/STEP).floor())
	var to: Vector2i = Vector2i((bounds.end/STEP).ceil())
	var atlas: TileSetAtlasSource = target.tile_set.get_source(0) as TileSetAtlasSource
	var tile: Vector2i = Vector2i(kind,15)
	for y: int in range(from.y,to.y):
		for x: int in range(from.x,to.x):
			var cell: Vector2i = Vector2i(x,y)
			var rect: PolygonDomain = PolygonDomain.rectangle(Rect2(Vector2(cell)*STEP,Vector2.ONE*STEP))
			var polygons: Array[PackedVector2Array] = Geometry2D.intersect_polygons(domain.outer,rect.outer)
			for hole: PackedVector2Array in domain.holes:
				var next: Array[PackedVector2Array] = []
				for polygon: PackedVector2Array in polygons: next.append_array(Geometry2D.clip_polygons(polygon,hole))
				polygons = next
			if polygons.is_empty(): continue
			if domain.covers(rect.outer): target.set_cell(cell,0,tile)
			else:
				var alternate: int = atlas.create_alternative_tile(tile)
				var data: TileData = atlas.get_tile_data(tile,alternate)
				data.set_custom_data("blocked",target.role==WorldTileLayer.Role.OBSTACLES)
				data.set_custom_data("visual_kind",domain.visual_kind if target.role==WorldTileLayer.Role.OBSTACLES else "mask")
				data.set_collision_polygons_count(0,polygons.size())
				var center: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*STEP
				for i: int in polygons.size():
					var points: PackedVector2Array = polygons[i]
					for p: int in points.size(): points[p] = Iso.project(points[p]-center)
					data.set_collision_polygon_points(0,i,points)
				target.set_cell(cell,0,tile,alternate)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://features/world/data/tiles"))
	var report: Dictionary = {}
	for id: String in MAPS:
		var path: String = "res://features/world/data/%s.tscn" % id
		var root: WorldMap2D = (load(path) as PackedScene).instantiate() as WorldMap2D
		if root.native_tiles_enabled: print("SKIP already migrated ",id); root.free(); continue
		var before: WorldMapDefinition = root.compile_definition()
		var ground_set: TileSet = make_tiles(before.terrain)
		var mask_set: TileSet = make_tiles(before.terrain,true)
		var floor: WorldTileLayer = layer(root,"Ground_TileMap",WorldTileLayer.Role.GROUND,ground_set)
		var cells: Array[Vector2i] = []
		for y: int in int(before.extent.y/STEP):
			for x: int in int(before.extent.x/STEP): cells.append(Vector2i(x,y))
		floor.set_cells_terrain_connect(cells,0,0)
		var road_cells: Dictionary = {}
		for road: PackedVector2Array in before.roads:
			for i: int in range(1,road.size()):
				var a: Vector2 = road[i-1]
				var b: Vector2 = road[i]
				var bounds: Rect2 = Rect2(a,Vector2.ZERO).expand(b).grow(48)
				for y: int in range(int(floorf(bounds.position.y/STEP)),int(ceilf(bounds.end.y/STEP))):
					for x: int in range(int(floorf(bounds.position.x/STEP)),int(ceilf(bounds.end.x/STEP))):
						var cell: Vector2i = Vector2i(x,y)
						var center: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*STEP
						if center.distance_to(Geometry2D.get_closest_point_to_segment(center,a,b))<40 and Rect2(Vector2.ZERO,before.extent).has_point(center): road_cells[cell]=true
		var road_brush: Array[Vector2i] = []
		road_brush.assign(road_cells.keys())
		if not road_brush.is_empty(): floor.set_cells_terrain_connect(road_brush,0,1)
		var obstacles: WorldTileLayer = layer(root,"Obstacles_TileMap",WorldTileLayer.Role.OBSTACLES,ground_set)
		for domain: PolygonDomain in before.blockers:
			var kind: int = KINDS.find(domain.visual_kind)
			paint_domain(obstacles,domain,maxi(2,kind))
		var walk: WorldTileLayer = layer(root,"Walkable_Mask",WorldTileLayer.Role.WALKABLE,mask_set)
		for domain: PolygonDomain in before.walkable: paint_domain(walk,domain,0)
		var safe: WorldTileLayer = layer(root,"SafeArea_Mask",WorldTileLayer.Role.SAFE,mask_set)
		for domain: PolygonDomain in before.safe_areas: paint_domain(safe,domain,0)
		for habitat: WorldHabitat in before.habitats:
			for role: WorldTileLayer.Role in [WorldTileLayer.Role.SPAWN,WorldTileLayer.Role.ACTIVITY,WorldTileLayer.Role.CHASE]:
				var name_text: String = ["Spawn","Activity","Chase"][role-WorldTileLayer.Role.SPAWN]+"_"+habitat.habitat_id
				var node: WorldTileLayer = layer(root,name_text,role,mask_set,habitat.habitat_id)
				paint_domain(node,habitat.spawn_domain if role==WorldTileLayer.Role.SPAWN else habitat.activity_domain if role==WorldTileLayer.Role.ACTIVITY else habitat.chase_domain,0)
		root.native_tiles_enabled = true
		root.show_atlas_reference = false
		for node: Node in root.get_children():
			if node is WorldAuthorNode and node.kind in [WorldAuthorNode.Kind.WALKABLE,WorldAuthorNode.Kind.BLOCKER,WorldAuthorNode.Kind.SAFE_AREA,WorldAuthorNode.Kind.HABITAT]: node.hide()
		for entry: Array in [[ground_set,"terrain"],[mask_set,"masks"]]:
			var resource: TileSet = entry[0]
			var resource_path: String = "res://features/world/data/tiles/%s_%s.tres" % [id,entry[1]]
			var error: Error = ResourceSaver.save(resource,resource_path)
			if error!=OK: push_error("TileSet save failed"); quit(1); return
			resource.take_over_path(resource_path)
		var packed: PackedScene = PackedScene.new()
		if packed.pack(root)!=OK or ResourceSaver.save(packed,path)!=OK: push_error("Scene save failed"); quit(1); return
		report[id] = {"floor_cells":floor.get_used_cells().size(),"layers":root.get_children().filter(func(n: Node) -> bool: return n is WorldTileLayer).size()}
		print("MIGRATED ",id," ",report[id])
		root.free()
	var output: FileAccess = FileAccess.open("res://artifacts/tilemap-migration-2026-10-10/migration.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	quit()
