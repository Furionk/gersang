extends SceneTree
## One-shot authored composition. Never a boot hook; scene stays natively editable.
const MAP: String = "res://features/world/data/river_bay.tscn"
const OUT: String = "res://features/world/data/scenery/river_biomes/"
const EVIDENCE: String = "res://artifacts/river-enrichment-2026-10-10/"
var map: WorldMap2D
var prior: WorldMapDefinition
var styles: Dictionary = {}
var groups: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var placed: Array[Dictionary] = []
var routes: Array[PackedVector2Array] = []
var serial: int = 0

func _initialize() -> void:
	if "--finalize" in OS.get_cmdline_user_args():
		finalize_palette()
		return
	WorldCatalog.initialize()
	map = ResourceLoader.load(MAP,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate() as WorldMap2D
	prior = map.compile_definition()
	if map.has_node("Scenery/RiverComposition"):
		push_error("Composition already exists. Edit the native scene; do not overwrite artist work.")
		map.free(); quit(1); return
	rng.seed = 20261010
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	routes.assign(prior.roads)
	# Visual approach branches to the artist-approved portal locations.
	routes.append(PackedVector2Array([Vector2(4200,2300),Vector2(4284.5,2723.5),Vector2(4600,2840)]))
	routes.append(PackedVector2Array([Vector2(4200,2300),Vector2(4608,2464),Vector2(5184,2464)]))
	var parent: Node2D = Node2D.new()
	parent.name = "RiverComposition"
	parent.y_sort_enabled = true
	map.get_node("Scenery").add_child(parent)
	parent.owner = map
	for title: String in ["Riverbanks","Woodlands","Highlands","VillageLife","FieldEdges","GroundCover"]:
		var group: Node2D = Node2D.new()
		group.name = title
		group.y_sort_enabled = true
		parent.add_child(group)
		group.owner = map
		groups[title] = group
	import_biomes()
	var plans: Array[Dictionary] = []
	# Data work is isolated from game RNG and off the SceneTree thread.
	var worker: int = WorkerThreadPool.add_task(func() -> void: plans.assign(composition_points()))
	WorkerThreadPool.wait_for_task_completion(worker)
	for plan: Dictionary in plans:
		place(plan.group,plan.style,plan.point,plan.scale)
	place_life()
	paint_ground()
	var after: WorldMapDefinition = map.compile_definition()
	var errors: Array[String] = WorldValidator.validate(after,WorldCatalog.definitions,map)
	if not errors.is_empty() or prior.portals!=after.portals or prior.entries!=after.entries or prior.habitats.size()!=after.habitats.size() or not same_geometry(after):
		push_error("Composition rejected: "+str(errors))
		map.free(); quit(1); return
	# Reject concurrent saves, rather than replacing another artist's changes.
	if FileAccess.get_sha256(MAP)!=FileAccess.get_sha256(EVIDENCE+"river-before.tscn"):
		push_error("River map changed since backup; preserve it and rebase the composition.")
		map.free(); quit(1); return
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(map)==OK)
	assert(ResourceSaver.save(packed,MAP)==OK)
	var report: FileAccess = FileAccess.open(EVIDENCE+"composition.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"seed":20261010,"new_objects":placed.size(),"placements":placed,"geometry_unchanged":true,"portals_unchanged":true,"ground_source":1},"\t"))
	report.close()
	print("RIVER_COMPOSITION objects=",placed.size()," total=",after.scenery.size()," geometry unchanged")
	map.free()
	quit()

func import_biomes() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://art/terrain/biomes_v1/biomes.json"))
	for biome: Dictionary in manifest:
		var texture: Texture2D = load("res://art/terrain/biomes_v1/"+biome.id+"/environment-atlas-v1.png") as Texture2D
		var image: Image = texture.get_image()
		for index: int in biome.modules.size():
			var x: int = index%4
			var y: int = index/4
			var rect: Rect2i = Rect2i(Vector2i(roundi(x*image.get_width()/4.0),roundi(y*image.get_height()/3.0)),Vector2i.ZERO)
			rect.size = Vector2i(roundi((x+1)*image.get_width()/4.0),roundi((y+1)*image.get_height()/3.0))-rect.position
			var bounds: Rect2i = alpha_bounds(image,rect)
			var data: WorldSceneryDefinition = WorldSceneryDefinition.new()
			data.texture = texture
			data.display_name = biome.modules[index][1]
			data.description = "河灣環境組合；原生通行／阻擋仍由 TileMap 遮罩決定。"
			data.atlas_region = Rect2(rect)
			data.foot_anchor = Vector2(bounds.get_center().x-rect.position.x,bounds.end.y-rect.position.y-5)
			data.sprite_scale = 0.72
			var key: String = biome.id+"/"+biome.modules[index][0]
			var path: String = OUT+key.replace("/","_")+".tres"
			assert(ResourceSaver.save(data,path)==OK)
			styles[key] = data

func alpha_bounds(image: Image, rect: Rect2i) -> Rect2i:
	var low: Vector2i = rect.end
	var high: Vector2i = rect.position
	for y: int in range(rect.position.y,rect.end.y):
		for x: int in range(rect.position.x,rect.end.x):
			if image.get_pixel(x,y).a>0.18:
				low = low.min(Vector2i(x,y))
				high = high.max(Vector2i(x,y)+Vector2i.ONE)
	return Rect2i(low,high-low)

func composition_points() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var local: RandomNumberGenerator = RandomNumberGenerator.new()
	local.seed = 20261010
	# Jittered grid with shaped regional density, not an unbounded random soup.
	for y: int in range(130,3990,140):
		for x: int in range(130,6020,140):
			var point: Vector2 = Vector2(x,y)+Vector2(local.randf_range(-36,36),local.randf_range(-36,36))
			if reserved(point,170): continue
			var roll: float = local.randf()
			var group: String = "Woodlands"
			var key: String
			if y>2700 and x<2400:
				group = "Highlands"
				if roll<0.45: key = "granite_valley/alpine_shrubs"
				elif roll<0.62: key = "granite_valley/pebble_transition"
				elif roll<0.73: key = "deadwood_wastes/dead_brush"
				else: continue
			elif x<2000 and y<1900:
				if roll<0.48: key = "forest/bamboo_thicket"
				elif roll<0.8: key = "forest/canopy_mass"
				else: key = "forest/fern_cover"
			elif x>2250 and x<3950 and y<2100:
				if roll<0.52: key = "forest/canopy_mass"
				elif roll<0.82: key = "forest/mixed_boundary"
				else: key = "forest/fern_cover"
			elif x>3000 and y>2600:
				group = "FieldEdges"
				if roll<0.23: key = "forest/sparse_transition"
				elif roll<0.45: key = "granite_valley/flowering_slope"
				elif roll<0.58: key = "forest/path_fringe"
				else: continue
			else:
				group = "GroundCover"
				if roll<0.17: key = "forest/fern_cover"
				elif roll<0.3: key = "forest/sparse_transition"
				elif roll<0.41: key = "granite_valley/pebble_transition"
				else: continue
			var density: float = 0.78 if key.ends_with("canopy_mass") else 0.62
			result.append({"group":group,"style":key,"point":point,"scale":density*local.randf_range(0.86,1.1)})
	# Repeated riverbank strips follow the REAL water blockers, not a painted atlas guess.
	for domain: PolygonDomain in prior.blockers:
		if domain.visual_kind=="water" or domain.bounds().size.x>domain.bounds().size.y*3:
			var bounds: Rect2 = domain.bounds()
			for x: int in range(int(bounds.position.x+35),int(bounds.end.x),100):
				for y: float in [bounds.position.y-48,bounds.end.y+48]:
					var point: Vector2 = Vector2(x,y)
					if reserved(point,110): continue
					var key: String = "river_marsh/reed_thicket" if local.randf()<0.55 else "river_marsh/rocky_bank"
					result.append({"group":"Riverbanks","style":key,"point":point,"scale":local.randf_range(0.65,0.8)})
		else:
			# Tall solid mountains/trunks stay on existing blocked footprints.
			var bounds: Rect2 = domain.bounds()
			for y: int in range(int(bounds.position.y+60),int(bounds.end.y-30),120):
				for x: int in range(int(bounds.position.x+60),int(bounds.end.x-30),120):
					var point: Vector2 = Vector2(x,y)
					if not domain.contains(point) or reserved(point,135): continue
					var key: String = "forest/canopy_mass" if domain.visual_kind=="forest" else "granite_valley/granite_mass"
					result.append({"group":"Highlands","style":key,"point":point,"scale":local.randf_range(0.8,1.05)})
	# Continuous silhouette at the map edge, leaving portal/road gaps.
	for x: int in range(70,6100,145):
		for y: float in [24.0,4072.0]:
			var point: Vector2 = Vector2(x,y)
			if not reserved(point,140): result.append({"group":"Highlands","style":"granite_valley/granite_ridge","point":point,"scale":0.84})
	for y: int in range(160,4000,145):
		for x: float in [24.0,6120.0]:
			var point: Vector2 = Vector2(x,y)
			if not reserved(point,140): result.append({"group":"Highlands","style":"granite_valley/granite_ridge","point":point,"scale":0.84})
	return result

func reserved(point: Vector2, corridor: float) -> bool:
	for route: PackedVector2Array in routes:
		for index: int in range(1,route.size()):
			if Geometry2D.get_closest_point_to_segment(point,route[index-1],route[index]).distance_to(point)<corridor: return true
	for portal: Dictionary in prior.portals:
		if portal.point.distance_to(point)<230: return true
	for entry: Dictionary in prior.entries.values():
		if entry.point.distance_to(point)<190: return true
	# Preserve connected open fighting/clicking pockets in every habitat.
	for habitat: WorldHabitat in prior.habitats:
		if habitat.activity_domain.bounds().get_center().distance_to(point)<190: return true
	return false

func place(group: String, key: String, point: Vector2, scale: float) -> void:
	var style_key: String = key+"_"+str(snappedf(scale,0.1))
	if not styles.has(style_key):
		var base: WorldSceneryDefinition = styles[key] as WorldSceneryDefinition
		var variant: WorldSceneryDefinition = base.duplicate() as WorldSceneryDefinition
		variant.sprite_scale = snappedf(scale,0.1)
		var path: String = OUT+style_key.replace("/","_")+".tres"
		assert(ResourceSaver.save(variant,path)==OK)
		styles[style_key] = variant
	var node: WorldAuthorNode = WorldAuthorNode.new()
	node.kind = WorldAuthorNode.Kind.SCENERY
	node.coordinate_space = WorldAuthorNode.CoordinateSpace.CANVAS
	node.stable_id = "river_detail_%04d" % serial
	node.name = node.stable_id
	node.display_name = styles[style_key].display_name
	node.position = Iso.project(point)
	node.sprite_definition = styles[style_key]
	node.set_meta("_edit_group_",true)
	groups[group].add_child(node)
	node.owner = map
	var artwork: Sprite2D = Sprite2D.new()
	artwork.name = "Artwork"
	node.add_child(artwork)
	artwork.owner = map
	node.sync_artwork()
	placed.append({"id":node.stable_id,"group":group,"style":key,"point":[point.x,point.y],"scale":node.sprite_definition.sprite_scale})
	serial+=1

func place_life() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/terrain/expansion_v1/catalog.json"))
	for item: Dictionary in catalog.assets:
		if item.group!="surfaces": styles[item.id] = load(item.resource) as WorldSceneryDefinition
	styles["building"] = load("res://features/world/data/scenery/building.tres") as WorldSceneryDefinition
	# Three asymmetric lived-in hamlets/rest stops, with clear approaches.
	for center: Vector2 in [Vector2(4660,3050),Vector2(3900,3400),Vector2(4700,1570)]:
		for row: Array in [["building",Vector2(-130,-100),0.5],["market_stall",Vector2(140,-95),0.4],["stone_well",Vector2(160,120),0.32],["grain_cart",Vector2(-140,140),0.32],["storage_jars",Vector2(-60,-170),0.22],["clay_oven",Vector2(50,-180),0.28],["bamboo_fence",Vector2(230,20),0.35],["flowering_shrub",Vector2(-220,20),0.34]]:
			var point: Vector2 = center+row[1]
			if not reserved(point,95): place("VillageLife",row[0],point,row[2])
	# Seasonal accents recur in small groups rather than one red tree everywhere.
	for center: Vector2 in [Vector2(4500,1800),Vector2(3600,2200),Vector2(2600,3250)]:
		for offset: Vector2 in [Vector2(-120,0),Vector2(30,90),Vector2(160,-40)]:
			if not reserved(center+offset,140): place("FieldEdges","autumn_maple",center+offset,0.34)

func paint_ground() -> void:
	var floor: WorldTileLayer = map.get_node("Ground/Ground_TileMap") as WorldTileLayer
	floor.tile_set = floor.tile_set.duplicate(true) as TileSet
	var surface: Image = Image.load_from_file("res://art/terrain/biomes_v1/forest/ground-atlas-v1.png")
	var dry: AtlasTexture = load("res://art/terrain/expansion_v1/surfaces/cracked_earth.tres") as AtlasTexture
	var materials: Array[Image] = []
	for y: int in 2:
		for x: int in 2: materials.append(surface.get_region(Rect2i(x*627,y*627,627,627)))
	materials.append(dry.get_image())
	var atlas: Image = Image.create(64*8,32*5,false,Image.FORMAT_RGBA8)
	for material_index: int in materials.size():
		var material: Image = materials[material_index]
		for variant: int in 8:
			for py: int in 32:
				for px: int in 64:
					var uv: Vector2 = Iso.unproject(Vector2(px-31.5,py-15.5))
					if absf(uv.x)>16 or absf(uv.y)>16: continue
					var ix: int = posmod(int(uv.x*4)+variant*73,material.get_width())
					var iy: int = posmod(int(uv.y*4)+variant*41,material.get_height())
					var color: Color = material.get_pixel(ix,iy)
					if material_index==4: color = color.lerp(Color(0.35,0.32,0.18),0.62)
					color.a = 1
					atlas.set_pixel(material_index*0+variant*64+px,material_index*32+py,color)
	var atlas_path: String = "res://art/terrain/native_tiles/river_biome_details.png"
	assert(atlas.save_png(atlas_path)==OK)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(64,32)
	floor.tile_set.add_source(source,1)
	for row: int in 5:
		for col: int in 8:
			source.create_tile(Vector2i(col,row))
			var data: TileData = source.get_tile_data(Vector2i(col,row),0)
			data.set_custom_data("blocked",false)
			data.set_custom_data("visual_kind","grass")
	# Precompute native cells, then commit one pattern (no runtime terrain work).
	paint_cells(floor)
	var tiles_path: String = "res://features/world/data/tiles/river_bay_enriched.tres"
	assert(ResourceSaver.save(floor.tile_set,tiles_path,ResourceSaver.FLAG_CHANGE_PATH)==OK)

func paint_cells(floor: WorldTileLayer) -> void:
	var pattern: TileMapPattern = floor.get_pattern(floor.get_used_cells())
	for cell: Vector2i in floor.get_used_cells():
		if floor.get_cell_tile_data(cell).get_custom_data("blocked"): continue
		var point: Vector2 = floor.logical_center(cell)
		var kind: int = -1
		if point.y<2100 and point.x<4000: kind = 0 if posmod(cell.x+cell.y,7)<5 else 1
		elif point.y>2800 and point.x<2500: kind = 3
		elif Rect2(3328,2816,512,416).has_point(point) or Rect2(3936,3136,448,448).has_point(point): kind = 4
		for route: PackedVector2Array in routes:
			for index: int in range(1,route.size()):
				if Geometry2D.get_closest_point_to_segment(point,route[index-1],route[index]).distance_to(point)<72: kind = 2
		if kind>=0: pattern.set_cell(cell,1,Vector2i(posmod(cell.x*7+cell.y*11,8),kind),0)
	floor.clear()
	floor.set_pattern(Vector2i.ZERO,pattern)
	assert(floor.get_used_cells().size()==24576,"Every base floor cell must survive painting")

func same_geometry(after: WorldMapDefinition) -> bool:
	for field: String in ["walkable","blockers","safe_areas"]:
		var a: Array = prior.get(field)
		var b: Array = after.get(field)
		if a.size()!=b.size(): return false
		for index: int in a.size():
			if a[index].outer!=b[index].outer or a[index].holes!=b[index].holes: return false
	return true

func finalize_palette() -> void:
	var root: WorldMap2D = ResourceLoader.load(MAP,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate() as WorldMap2D
	if root.get_meta("river_composition_finalized",false):
		push_error("Already finalized; preserve artist changes and edit the native scene.")
		root.free(); quit(1); return
	prior = root.compile_definition()
	routes.assign(prior.roads)
	routes.append(PackedVector2Array([Vector2(4200,2300),Vector2(4284.5,2723.5),Vector2(4600,2840)]))
	routes.append(PackedVector2Array([Vector2(4200,2300),Vector2(4608,2464),Vector2(5184,2464)]))
	var floor: WorldTileLayer = root.get_node("Ground/Ground_TileMap") as WorldTileLayer
	var backup: WorldMap2D = load(EVIDENCE+"river-before.tscn").instantiate() as WorldMap2D
	floor.tile_map_data = backup.get_node("Ground/Ground_TileMap").tile_map_data.duplicate()
	backup.free()
	var source: TileSetAtlasSource = floor.tile_set.get_source(1) as TileSetAtlasSource
	source.resource_name = "河灣地色：苔土／落葉／土路／碎石／耕地"
	root.get_node("Scenery/RiverComposition").y_sort_enabled = true
	for group: Node2D in root.get_node("Scenery/RiverComposition").get_children(): group.y_sort_enabled = true
	source.texture = load("res://art/terrain/native_tiles/river_biome_details.png") as Texture2D
	for row: int in 5:
		for col: int in 8:
			source.get_tile_data(Vector2i(col,row),0).set_custom_data("blocked",false)
			source.get_tile_data(Vector2i(col,row),0).set_custom_data("visual_kind","grass")
	paint_cells(floor)
	assert(ResourceSaver.save(floor.tile_set,"res://features/world/data/tiles/river_bay_enriched.tres",ResourceSaver.FLAG_CHANGE_PATH)==OK)
	floor.tile_set = ResourceLoader.load("res://features/world/data/tiles/river_bay_enriched.tres","TileSet",ResourceLoader.CACHE_MODE_IGNORE) as TileSet
	var obstacles: WorldTileLayer = root.get_node("Ground/Obstacles_TileMap") as WorldTileLayer
	if obstacles.tile_set.has_source(2):
		(obstacles.tile_set.get_source(2) as TileSetAtlasSource).texture = load("res://art/terrain/native_tiles/river_channel_visual.png") as Texture2D
		assert(ResourceSaver.save(obstacles.tile_set,"res://features/world/data/tiles/river_bay_enriched_obstacles.tres",ResourceSaver.FLAG_CHANGE_PATH)==OK)
		obstacles.tile_set = ResourceLoader.load("res://features/world/data/tiles/river_bay_enriched_obstacles.tres","TileSet",ResourceLoader.CACHE_MODE_IGNORE) as TileSet
	var packed: PackedScene = PackedScene.new()
	root.set_meta("river_composition_finalized",true)
	assert(packed.pack(root)==OK and ResourceSaver.save(packed,MAP)==OK)
	root.free()
	print("PALETTE_FINALIZED imported external texture, native custom data")
	quit()
