extends SceneTree
## One-shot authoring only. Refuses to overwrite the shipped scene on subsequent runs.
const WORLD: String = "res://features/world/data/rainbow_temple.tscn"
func _initialize() -> void: call_deferred("run")
func save(data: Resource, path: String) -> void:
	assert(ResourceSaver.save(data, path) == OK)
	data.take_over_path(path)
func own(root: Node, branch: Node) -> void:
	for child: Node in branch.get_children(): child.owner = root; own(root, child)
func pack(root: Node, path: String) -> void:
	own(root, root)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root) == OK)
	save(packed, path)
func branch(parent: Node, title: String) -> Node2D:
	var item: Node2D = Node2D.new(); item.name = title; parent.add_child(item); return item
func marker(parent: Node, id: String, point: Vector2, kind: int) -> WorldAuthorNode:
	var item: WorldAuthorNode = WorldAuthorNode.new()
	item.name = id; item.stable_id = id; item.kind = kind
	item.coordinate_space = WorldAuthorNode.CoordinateSpace.CANVAS; item.position = Iso.project(point)
	parent.add_child(item); return item
func tiles(size: Vector2i) -> TileSet:
	var result: TileSet = TileSet.new()
	result.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	result.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	result.tile_size = size
	result.add_physics_layer()
	result.add_custom_data_layer(); result.set_custom_data_layer_name(0, "blocked"); result.set_custom_data_layer_type(0, TYPE_BOOL)
	result.add_custom_data_layer(); result.set_custom_data_layer_name(1, "visual_kind"); result.set_custom_data_layer_type(1, TYPE_STRING)
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = load("res://features/rainbow/data/stone_%d.svg" % size.x)
	source.texture_region_size = size
	for x: int in 3: source.create_tile(Vector2i(x, 0))
	result.add_source(source, 0)
	for x: int in 3:
		var data: TileData = source.get_tile_data(Vector2i(x,0),0)
		data.set_custom_data("blocked", x == 2); data.set_custom_data("visual_kind", "stone")
		data.set_collision_polygons_count(0,1)
		data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,-size.y*0.5),Vector2(size.x*0.5,0),Vector2(0,size.y*0.5),Vector2(-size.x*0.5,0)]))
	return result
func run() -> void:
	if FileAccess.file_exists(WORLD): push_error("Rainbow scene exists; authoring refused"); quit(1); return
	var slime: UnitDefinition = load("res://features/units/data/monsters/puzzle_fire.tres").duplicate()
	slime.id = &"rainbow_slime"; slime.display_name = "火焰史萊姆"
	slime.puzzle_monster = null; slime.balance_revision = 0
	slime.level = 3; slime.damage = 5; slime.strength = 4; slime.agility = 8; slime.intelligence = 5; slime.luck = 0
	slime.max_health = 220; slime.max_mana = 40; slime.speed = 100; slime.experience_reward = 45
	slime.tactical_hint = "火龍神殿入門怪；紅光起手後近距離撲擊。側移或正面防禦後反擊。原型暫用既有圖集。"
	save(slime, "res://features/units/data/monsters/rainbow_slime.tres")
	var world: WorldMap2D = WorldMap2D.new(); world.name = "RainbowTemple"
	world.native_tiles_enabled = true
	world.definition = WorldMapDefinition.new()
	world.definition.map_id = "rainbow_temple"; world.definition.display_name = "彩虹冒險 · 火龍神殿前庭"
	world.definition.kind = WorldMapDefinition.Kind.DUNGEON; world.definition.extent = Vector2(1152, 1024)
	world.definition.safe_return_map_id = "river_bay"; world.definition.safe_return_entry_id = "rainbow_return"
	var floor_root: Node2D = branch(world, "Ground")
	var world_tiles: TileSet = tiles(Vector2i(64, 32))
	for role: int in [WorldTileLayer.Role.GROUND, WorldTileLayer.Role.WALKABLE, WorldTileLayer.Role.OBSTACLES]:
		var layer: WorldTileLayer = WorldTileLayer.new()
		layer.name = {0:"Ground_TileMap", 2:"Walkable_Mask", 1:"Obstacles_TileMap"}[role]
		layer.role = role; layer.position = Vector2(-32, 0); layer.tile_set = world_tiles
		for x: int in 36:
			for y: int in 32:
				var blocked: bool = x < 2 or x > 33 or y < 2 or y > 29 or (x in [12, 23] and y in [12, 13])
				if role == 0 or (role == 1 and blocked) or (role == 2 and not blocked): layer.set_cell(Vector2i(x,y), 0, Vector2i(2 if blocked else (x+y)%2, 0))
		floor_root.add_child(layer)
	var entrances: Node2D = branch(world, "Entrances")
	marker(entrances, "entrance", Vector2(576, 800), WorldAuthorNode.Kind.ARRIVAL)
	var exit: WorldAuthorNode = marker(entrances, "rainbow_exit", Vector2(576, 900), WorldAuthorNode.Kind.PORTAL)
	exit.display_name = "返回青嶺河灣"; exit.target_map_id = "river_bay"; exit.target_entry_id = "rainbow_return"
	exit.sprite_definition = load("res://features/world/data/scenery/dungeon_gate.tres")
	var safe: WorldAuthorNode = marker(world, "entry_safe", Vector2.ZERO, WorldAuthorNode.Kind.SAFE_AREA)
	safe.domain = PolygonDomain.rectangle(Rect2(400, 730, 352, 220))
	var regions: Node2D = branch(world, "MonsterRegions")
	var area: WorldMonsterRegion = WorldMonsterRegion.new()
	area.name = "SlimeCourt"; area.stable_id = "rainbow_slime_court"; area.display_name = "火焰史萊姆 · 動作遭遇"
	area.monster = slime; area.minimum_units = 3; area.maximum_units = 3; area.minimum_level = 3; area.maximum_level = 3
	area.party_count = 2; area.aggressive = false; area.battlefields = PackedStringArray(["rainbow_temple"])
	area.habitat = WorldHabitat.new(); area.habitat.profile = SpawnProfile.new()
	area.habitat.profile.rules.max_enemy_parties = 1; area.habitat.profile.rules.reinforcement_chance = 0
	regions.add_child(area)
	for title: String in ["SpawnArea", "RoamingArea", "PursuitArea"]:
		var poly: WorldRegionPolygon = WorldRegionPolygon.new(); poly.name = title
		var points := PackedVector2Array()
		for point: Vector2 in [Vector2(400,300),Vector2(750,300),Vector2(750,650),Vector2(400,650)]: points.append(Iso.project(point))
		poly.polygon = points
		area.add_child(poly)
	pack(world, WORLD); world.free()
	var battle: BattlefieldMap = BattlefieldMap.new(); battle.name = "RainbowTempleArena"; battle.arena_id = "rainbow_temple"
	battle.battlefield_cells = Vector2i(32,28)
	var battle_tiles: TileSet = tiles(Vector2i(80,40))
	for role: int in 3:
		var layer: BattleTileLayer = BattleTileLayer.new(); layer.name = ["Ground", "Walkable", "Blockers"][role]
		layer.role = role; layer.position = Vector2(-40,0); layer.tile_set = battle_tiles
		for x: int in 32:
			for y: int in 28:
				var blocked: bool = x < 2 or x > 29 or y < 2 or y > 25 or (x in [12,19] and y in [12,13])
				if role == 0 or (role == 1 and not blocked) or (role == 2 and blocked): layer.set_cell(Vector2i(x,y),0,Vector2i(2 if blocked else (x+y)%2,0))
		battle.add_child(layer)
	var zones: Node2D = branch(battle, "SpawnZones")
	var centers: Array[Vector2] = [Vector2(640,800),Vector2(640,350),Vector2(300,350),Vector2(980,350),Vector2(980,800)]
	for i: int in 5:
		var zone: BattleSpawnZone = BattleSpawnZone.new(); zone.name = "Zone%d" % i; zone.position = Iso.project(centers[i]); zone.radius = 130; zone.capacity = 12
		zone.allowed_teams = BattleSpawnZone.Teams.ALLIES if i == 0 else BattleSpawnZone.Teams.ENEMIES
		zones.add_child(zone)
	pack(battle, "res://features/battle/maps/rainbow_temple.tscn"); battle.free()
	var encounter: EncounterDefinition = EncounterDefinition.new(); encounter.id = &"rainbow_temple"; encounter.display_name = "火龍神殿 · 動作遭遇"
	encounter.battlefield_scene = "res://features/battle/maps/rainbow_temple.tscn"
	encounter.action_profile = load("res://features/rainbow/data/default_action.tres")
	var arena: ArenaDefinition = ArenaDefinition.new(); arena.arena_id = "rainbow_temple"; arena.encounter = encounter
	save(arena,"res://features/world/data/rainbow_temple_arena.tres")
	# Append two nodes only: no reserialization of the artist's river tiles/regions.
	var path: String = "res://features/world/data/river_bay.tscn"
	var original: String = FileAccess.get_file_as_string(path)
	assert(not original.contains('name="rainbow_door"'))
	var river: WorldMap2D = load(path).instantiate()
	var def: WorldMapDefinition = river.compile_definition()
	var nav: WorldNavigationService = WorldNavigationService.new(); nav.register_map(def)
	var approach: Dictionary = nav.find_portal_approach("river_bay", def.entries.start.point, Vector2(4640,2340), 65, 16)
	assert(approach.ok,"Rainbow entrance must be reachable from the starting area")
	var point: Vector2 = approach.points[-1]
	assert(nav.segment_legal("river_bay", "", "PLAYER", point, point, 16))
	var projected: Vector2 = Iso.project(point)
	var arrival: Vector2 = point + Vector2(0, -100)
	assert(nav.segment_legal("river_bay", "", "PLAYER", arrival, arrival, 16))
	var arrival_projected: Vector2 = Iso.project(arrival)
	var addition: String = '\n[node name="rainbow_door" type="Node2D" parent="Entrances"]\nposition = Vector2(%s, %s)\nscript = ExtResource("12_qgbsx")\ncoordinate_space = 1\nkind = 4\nstable_id = "rainbow_door"\ndisplay_name = "彩虹冒險 · 火龍神殿"\ntarget_map_id = "rainbow_temple"\ntarget_entry_id = "entrance"\ntrigger_radius = 65.0\nsprite_definition = ExtResource("15_0bm7i")\n\n[node name="rainbow_return" type="Node2D" parent="Entrances"]\nposition = Vector2(%s, %s)\nscript = ExtResource("12_qgbsx")\ncoordinate_space = 1\nkind = 5\nstable_id = "rainbow_return"\n' % [projected.x,projected.y,arrival_projected.x,arrival_projected.y]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE); file.store_string(original+addition); file.close()
	river.free()
	print("RAINBOW_AUTHORED entrance=",point," 2 parties / 3 slimes each; original river content retained verbatim")
	quit()
