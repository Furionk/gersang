extends "res://tools/expand_rainbow_dungeon.gd"
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_landmark_routes_v2"): quit(1); return
	var walls: WorldTileLayer = world.get_node("Ground/Obstacles_TileMap")
	var mask: WorldTileLayer = world.get_node("Ground/Walkable_Mask")
	for zone: int in 9:
		var tile := Vector2i(24+(zone%3)*56,63+(zone/3)*52)
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				var cell := tile+Vector2i(dx,dy)
				walls.erase_cell(cell); mask.set_cell(cell,0,Vector2i.ZERO)
		tile.x += 10
		var sprite: Sprite2D = world.get_node("Scenery/BranchLandmark%d" % zone)
		sprite.position = Iso.project((Vector2(tile)+Vector2.ONE*0.5)*32)
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				var cell := tile+Vector2i(dx,dy)
				walls.set_cell(cell,0,Vector2i(2,0)); mask.erase_cell(cell)
	world.set_meta("rainbow_landmark_routes_v2",true)
	pack(world,WORLD); world.free(); quit()
