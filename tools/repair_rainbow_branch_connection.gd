extends "res://tools/expand_rainbow_dungeon.gd"
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_branch_connection_repaired"): quit(1); return
	var before: WorldMap2D = load("res://artifacts/rainbow-overhaul/rainbow_temple.before.tscn").instantiate()
	for path: String in ["Ground/Ground_TileMap","Ground/Walkable_Mask","Ground/Obstacles_TileMap"]:
		var target: WorldTileLayer = world.get_node(path)
		var source: WorldTileLayer = before.get_node(path)
		for x: int in 34:
			for y: int in 32:
				var cell := Vector2i(x,y)
				var source_id: int = source.get_cell_source_id(cell)
				if source_id < 0: target.erase_cell(cell)
				else: target.set_cell(cell,source_id,source.get_cell_atlas_coords(cell),source.get_cell_alternative_tile(cell))
	var ground: WorldTileLayer = world.get_node("Ground/Ground_TileMap")
	var mask: WorldTileLayer = world.get_node("Ground/Walkable_Mask")
	var walls: WorldTileLayer = world.get_node("Ground/Obstacles_TileMap")
	for x: int in range(22,51):
		for y: int in range(28,49):
			if not (x >= 46 or y >= 44): continue
			var cell := Vector2i(x,y)
			ground.set_cell(cell,0,Vector2i(posmod(x,8),1+posmod(y,8)))
			mask.set_cell(cell,0,Vector2i.ZERO); walls.erase_cell(cell)
	world.set_meta("rainbow_branch_connection_repaired",true)
	pack(world,WORLD); before.free(); world.free()
	print("RAINBOW_CONNECTION_REPAIRED original frontcourt preserved; western loop joins BeastNest")
	quit()
