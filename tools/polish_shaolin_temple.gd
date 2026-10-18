extends SceneTree
## Focused authoring revision after actual rendered review; never a runtime hook.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String = "res://features/world/data/shaolin_temple.tscn"
	var temple: WorldMap2D = load(path).instantiate() as WorldMap2D
	temple.get_node("south_pavilion").position = Vector2(640,1120)
	var walk: WorldTileLayer = temple.get_node("Walkable_Mask") as WorldTileLayer
	var obstacles: WorldTileLayer = temple.get_node("Obstacles_TileMap") as WorldTileLayer
	for y: int in range(32,35):
		for x: int in range(44,50):
			var cell: Vector2i = Vector2i(x,y)
			walk.set_cell(cell,0,Vector2i(0,posmod(x,4)+posmod(y,4)*4))
			obstacles.erase_cell(cell)
	for y: int in range(32,35):
		for x: int in range(17,23):
			var cell: Vector2i = Vector2i(x,y)
			walk.erase_cell(cell)
			obstacles.set_cell(cell,0,Vector2i(4,posmod(x,4)+posmod(y,4)*4))
	for record: Array in [["gate_left_wall",896],["gate_right_wall",1152]]:
		if temple.has_node(record[0]): continue
		var node: WorldAuthorNode = WorldAuthorNode.new()
		node.name = record[0]
		node.stable_id = record[0]
		node.kind = WorldAuthorNode.Kind.SCENERY
		node.position = Vector2(record[1],1312)
		node.display_name = "山門旁朱牆"
		node.sprite_definition = load("res://features/world/data/scenery/shaolin_wall_x.tres") as WorldSceneryDefinition
		temple.add_child(node)
		node.owner = temple
	var atlas: TileSetAtlasSource = obstacles.tile_set.get_source(0) as TileSetAtlasSource
	for kind: int in [2,4]:
		for row: int in 16: atlas.get_tile_data(Vector2i(kind,row),0).set_custom_data("visual_kind","building")
	assert(ResourceSaver.save(obstacles.tile_set,obstacles.tile_set.resource_path)==OK)
	var layout: SpriteSheetLayout = load("res://features/units/data/layouts/shaolin_guardian_layout.tres") as SpriteSheetLayout
	for row: int in 8:
		for column: int in [3,4]:
			var rect: Rect2i = Rect2i(column*181,row*181,181,181)
			if column==3: rect.position.x-=24; rect.size.x=256
			else: rect.position.x=758; rect.size.x=148
			layout.frame_rects[row*6+column] = rect
			layout.source_pivots[row*6+column] = Vector2(column*181+90.5,row*181+181*0.91)-Vector2(rect.position)
	layout.direction_rows[3] = 1
	layout.mirrored_directions[3] = true
	layout.direction_rows[7] = 5
	layout.mirrored_directions[7] = true
	assert(ResourceSaver.save(layout,layout.resource_path)==OK)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(temple)==OK and ResourceSaver.save(packed,path)==OK)
	temple.free()
	print("SHAOLIN_POLISHED gates, unobstructed guardian view, foundation tiles, staff atlas")
	quit()
