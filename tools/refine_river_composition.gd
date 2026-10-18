extends SceneTree
const MAP: String = "res://features/world/data/river_bay.tscn"
const OUT: String = "res://artifacts/river-enrichment-2026-10-10/"
func _initialize() -> void:
	var root: WorldMap2D = ResourceLoader.load(MAP,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate() as WorldMap2D
	var obstacles: WorldTileLayer = root.get_node("Ground/Obstacles_TileMap") as WorldTileLayer
	if obstacles.tile_set.has_source(2) or root.get_meta("river_composition_finalized",false):
		push_error("Already refined; edit the scene rather than rerunning over artist changes.")
		root.free(); quit(1); return
	var before: WorldMapDefinition = root.compile_definition()
	var floor: WorldTileLayer = root.get_node("Ground/Ground_TileMap") as WorldTileLayer
	var palette: Image = Image.load_from_file("res://art/terrain/native_tiles/river_biome_details.png")
	for y: int in range(128,160):
		for x: int in 512:
			var color: Color = palette.get_pixel(x,y)
			if color.a>0: palette.set_pixel(x,y,Color(color.r,color.g,color.b,1).lerp(Color(0.35,0.32,0.18,1),0.62))
	assert(palette.save_png("res://art/terrain/native_tiles/river_biome_details.png")==OK)
	var backup: WorldMap2D = load(OUT+"river-before.tscn").instantiate() as WorldMap2D
	var original_floor: WorldTileLayer = backup.get_node("Ground/Ground_TileMap") as WorldTileLayer
	var pattern: TileMapPattern = floor.get_pattern(floor.get_used_cells())
	for cell: Vector2i in floor.get_used_cells():
		if floor.get_cell_source_id(cell)!=1 or floor.get_cell_atlas_coords(cell).y!=4: continue
		var point: Vector2 = floor.logical_center(cell)
		if not Rect2(3328,2816,512,416).has_point(point) and not Rect2(3936,3136,448,448).has_point(point):
			pattern.set_cell(cell,original_floor.get_cell_source_id(cell),original_floor.get_cell_atlas_coords(cell),original_floor.get_cell_alternative_tile(cell))
	floor.clear()
	floor.set_pattern(Vector2i.ZERO,pattern)
	backup.free()
	# A duplicate atlas source retains EVERY collision polygon/alternative exactly.
	obstacles.tile_set = obstacles.tile_set.duplicate(true) as TileSet
	var base: TileSetAtlasSource = obstacles.tile_set.get_source(0) as TileSetAtlasSource
	var wet: TileSetAtlasSource = base.duplicate(true) as TileSetAtlasSource
	var old: Image = base.texture.get_image()
	var water: Image = old.duplicate() as Image
	for y: int in water.get_height():
		for x: int in water.get_width():
			var alpha: float = old.get_pixel(x,y).a
			if alpha<=0: continue
			var color: Color = old.get_pixel(128+x%64,480+y%32)
			color.a = alpha
			water.set_pixel(x,y,color)
	var water_path: String = "res://art/terrain/native_tiles/river_channel_visual.png"
	assert(water.save_png(water_path)==OK)
	wet.texture = ImageTexture.create_from_image(water)
	wet.resource_name = "河道水面（保留原阻擋）"
	obstacles.tile_set.add_source(wet,2)
	for cell: Vector2i in obstacles.get_used_cells():
		var point: Vector2 = obstacles.logical_center(cell)
		for domain: PolygonDomain in before.blockers:
			if (domain.visual_kind=="water" or domain.bounds().size.x>domain.bounds().size.y*3) and domain.contains(point):
				obstacles.set_cell(cell,2,obstacles.get_cell_atlas_coords(cell),obstacles.get_cell_alternative_tile(cell))
				break
	# Hide only old agent-generated mountain decorations inside river rectangles.
	# Retain their original nodes/IDs in a recoverable archive; no portal is moved.
	var archive: Node2D = Node2D.new()
	archive.name = "OldRiverRockDecor"
	archive.set_meta("authoring_archived",true)
	archive.hide()
	root.get_node("Technical").add_child(archive)
	archive.owner = root
	var retired: int = 0
	for node: Node in WorldAuthorTree.nodes(root):
		if not node is WorldAuthorNode or not node.stable_id.begins_with("scenery_river_bay_") or node.sprite_definition==null: continue
		if node.sprite_definition.resource_path!="res://features/world/data/scenery/mountain.tres": continue
		var point: Vector2 = WorldAuthorTree.logical_position(node,root)
		for domain: PolygonDomain in before.blockers:
			if domain.bounds().size.x>domain.bounds().size.y*3 and domain.contains(point):
				node.owner = null
				node.reparent(archive,false)
				node.owner = root
				for child: Node in node.get_children(): child.owner = root
				retired+=1
				break
	var bridge_style: WorldSceneryDefinition = load("res://features/world/data/scenery/lake_bridge.tres").duplicate() as WorldSceneryDefinition
	bridge_style.display_name = "河灣木橋"
	bridge_style.sprite_scale = 0.72
	assert(ResourceSaver.save(bridge_style,"res://features/world/data/scenery/river_biomes/bridge.tres",ResourceSaver.FLAG_CHANGE_PATH)==OK)
	var bridge: WorldAuthorNode = WorldAuthorNode.new()
	bridge.kind = WorldAuthorNode.Kind.SCENERY
	bridge.coordinate_space = WorldAuthorNode.CoordinateSpace.CANVAS
	bridge.stable_id = "river_detail_bridge"
	bridge.name = bridge.stable_id
	bridge.position = Iso.project(Vector2(1250,2050))
	bridge.display_name = "河灣木橋"
	bridge.sprite_definition = bridge_style
	bridge.set_meta("_edit_group_",true)
	root.get_node("Scenery/RiverComposition/Riverbanks").add_child(bridge)
	bridge.owner = root
	var art: Sprite2D = Sprite2D.new()
	art.name = "Artwork"
	bridge.add_child(art)
	art.owner = root
	bridge.sync_artwork()
	var after: WorldMapDefinition = root.compile_definition()
	var exact: bool = true
	for field: String in ["walkable","blockers","safe_areas"]:
		var a: Array = before.get(field)
		var b: Array = after.get(field)
		exact = exact and a.size()==b.size()
		for index: int in a.size(): exact = exact and a[index].outer==b[index].outer and a[index].holes==b[index].holes
	assert(exact and before.portals==after.portals and before.entries==after.entries)
	assert(ResourceSaver.save(obstacles.tile_set,"res://features/world/data/tiles/river_bay_enriched_obstacles.tres",ResourceSaver.FLAG_CHANGE_PATH)==OK)
	assert(ResourceSaver.save(floor.tile_set,"res://features/world/data/tiles/river_bay_enriched.tres",ResourceSaver.FLAG_CHANGE_PATH)==OK)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root)==OK and ResourceSaver.save(packed,MAP)==OK)
	var report: FileAccess = FileAccess.open(OUT+"refinement.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"retired_agent_rock_decor":retired,"new_bridge":bridge.stable_id,"navigation_exact":exact},"\t"))
	report.close()
	print("RIVER_REFINED retired=",retired," scenery=",after.scenery.size()," navigation exact")
	root.free(); quit()
