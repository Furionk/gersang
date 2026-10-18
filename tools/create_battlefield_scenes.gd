extends SceneTree
## One-shot migration. Never invoked by runtime. Refuses to overwrite artist scenes.
func _initialize() -> void: call_deferred("run")
func choices() -> Array[EncounterDefinition]:
	var result: Array[EncounterDefinition] = Catalog.encounters().duplicate()
	result.append(load("res://features/world/data/shaolin_temple_arena.tres").encounter)
	result.append(load("res://features/world/data/millennium_lake_arena.tres").encounter)
	return result
func run() -> void:
	var atlas_only: bool = "--atlas-only" in OS.get_cmdline_user_args()
	for choice: EncounterDefinition in choices():
		var path: String = "res://features/battle/maps/%s.tscn" % choice.id
		var image_path: String = "res://features/battle/data/%s-tiles-v1.png" % choice.id
		if atlas_only:
			if FileAccess.file_exists(image_path): print("KEEP ",image_path); continue
			var ground: GroundMap = GroundMap.new()
			ground.terrain=choice.terrain
			ground.ground_texture=choice.ground_texture
			assert(ground._battle_tile_atlas().get_image().save_png(image_path)==OK)
			ground.free()
			continue
		if FileAccess.file_exists(path): print("KEEP ARTIST SCENE ",path); continue
		var map: BattlefieldMap = BattlefieldMap.new()
		map.name=String(choice.id).to_pascal_case()+"Battlefield"
		map.arena_id=String(choice.id)
		map.battlefield_cells=choice.battlefield_cells
		map.y_sort_enabled=true
		var tiles: TileSet = TileSet.new()
		tiles.tile_size=Vector2i(80,40)
		tiles.tile_shape=TileSet.TILE_SHAPE_ISOMETRIC
		tiles.tile_layout=TileSet.TILE_LAYOUT_DIAMOND_DOWN
		var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
		atlas.texture=load(image_path)
		atlas.texture_region_size=Vector2i(80,40)
		for variant: int in 4: atlas.create_tile(Vector2i(variant,0))
		tiles.add_source(atlas,0)
		assert(ResourceSaver.save(tiles,"res://features/battle/data/%s-tiles.tres" % choice.id)==OK)
		var terrain: Node2D = Node2D.new(); terrain.name="Terrain"; map.add_child(terrain); terrain.owner=map
		var layers: Array[BattleTileLayer] = []
		for role: int in 3:
			var layer: BattleTileLayer = BattleTileLayer.new()
			layer.name=["Ground","Walkable","Blockers"][role]
			layer.role=role
			layer.tile_set=tiles
			layer.position=Vector2(-40,0)
			layer.z_index=-3500 if role==0 else 100
			layer.visible=role==0
			layer.collision_enabled=false; layer.navigation_enabled=false
			terrain.add_child(layer); layer.owner=map; layers.append(layer)
		var obstacles: Array[Rect2i] = [Rect2i(19,8,3,4),Rect2i(24,20,4,3),Rect2i(9,25,3,3)]
		if choice.terrain==1: obstacles=[Rect2i(20,3,3,8),Rect2i(20,19,3,6),Rect2i(32,24,4,3)]
		elif choice.terrain==2: obstacles=[Rect2i(18,5,4,5),Rect2i(26,20,4,5),Rect2i(8,27,4,3)]
		var noise: FastNoiseLite = FastNoiseLite.new(); noise.seed=7471; noise.frequency=0.16
		for x: int in map.battlefield_cells.x:
			for y: int in map.battlefield_cells.y:
				var value: float = noise.get_noise_2d(x,y)
				var variant: int = 3 if absi(y-15)<=1 or absi(x-29)<=1 else 1 if value< -0.18 else 2 if value>0.18 else 0
				layers[0].set_cell(Vector2i(x,y),0,Vector2i(variant,0))
				layers[1].set_cell(Vector2i(x,y),0,Vector2i.ZERO)
				for rect: Rect2i in obstacles:
					if rect.has_point(Vector2i(x,y)): layers[2].set_cell(Vector2i(x,y),0,Vector2i.ZERO)
		var scenery: Node2D = Node2D.new(); scenery.name="Scenery"; scenery.y_sort_enabled=true; map.add_child(scenery); scenery.owner=map
		var art_path: String = "res://features/world/data/scenery/river_biomes/forest_canopy_mass_0.7.tres" if choice.terrain==0 else "res://features/world/data/scenery/river_biomes/granite_valley_granite_mass_0.8.tres" if choice.terrain==1 else "res://features/world/data/scenery/river_biomes/deadwood_wastes_rock_deadwood_mass.tres"
		if choice.id==&"millennium_lake": art_path="res://features/world/data/scenery/lake_cliff_left.tres"
		elif choice.id==&"shaolin_temple": art_path="res://features/world/data/scenery/shaolin_incense.tres"
		var art: WorldSceneryDefinition = load(art_path)
		var points: Array[Vector2] = []
		for rect: Rect2i in obstacles:
			for x: int in range(rect.position.x,rect.end.x,2):
				for y: int in range(rect.position.y,rect.end.y,2): points.append((Vector2(x,y)+Vector2.ONE*0.5)*Iso.CELL)
		for x: int in range(1,map.battlefield_cells.x,2):
			for y: int in [0,map.battlefield_cells.y-1]: points.append((Vector2(x,y)+Vector2.ONE*0.5)*Iso.CELL)
		for y: int in range(2,map.battlefield_cells.y-2,2):
			for x: int in [0,map.battlefield_cells.x-1]: points.append((Vector2(x,y)+Vector2.ONE*0.5)*Iso.CELL)
		for point: Vector2 in points:
			var style: WorldSceneryDefinition = art
			if choice.id==&"shaolin_temple":
				if point.y<Iso.CELL or point.y>float(map.battlefield_cells.y-1)*Iso.CELL: style=load("res://features/world/data/scenery/shaolin_wall_x.tres")
				elif point.x<Iso.CELL or point.x>float(map.battlefield_cells.x-1)*Iso.CELL: style=load("res://features/world/data/scenery/shaolin_wall_y.tres")
			var pivot: Node2D = Node2D.new(); pivot.name="Prop_%d" % scenery.get_child_count(); pivot.position=Iso.project(point)
			scenery.add_child(pivot); pivot.owner=map
			var sprite: Sprite2D = Sprite2D.new(); sprite.name="Artwork"; sprite.centered=false
			var texture: AtlasTexture = AtlasTexture.new(); texture.atlas=style.texture; texture.region=style.region(); texture.filter_clip=true
			sprite.texture=texture; sprite.transform=style.artwork_transform(); sprite.modulate=style.tint
			pivot.add_child(sprite); sprite.owner=map
		var zones: Node2D = Node2D.new(); zones.name="SpawnZones"; map.add_child(zones); zones.owner=map
		for point: Vector2 in [Vector2(460,730),Vector2(1160,440),Vector2(1520,880),Vector2(1160,1280),Vector2(580,1260)]:
			var zone: BattleSpawnZone = BattleSpawnZone.new(); zone.name="Position_%d" % (zones.get_child_count()+1); zone.position=Iso.project(point)
			zones.add_child(zone); zone.owner=map
		var compiled: Dictionary = BattlefieldCompiler.compile(map)
		if not compiled.errors.is_empty(): print("GENERATOR_ERRORS ",choice.id," ",compiled.errors); map.free(); quit(1); return
		var packed: PackedScene = PackedScene.new()
		assert(packed.pack(map)==OK and ResourceSaver.save(packed,path)==OK)
		print("CREATED ",path)
		map.free()
	quit()
