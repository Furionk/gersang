extends "res://tools/expand_rainbow_dungeon.gd"
## Native footprints for the eight new solid columns; no runtime obstacles are fabricated.
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_pillar_feet_v1"): world.free(); quit(1); return
	var ground: WorldTileLayer = world.get_node("Ground/Ground_TileMap")
	var walls: WorldTileLayer = world.get_node("Ground/Obstacles_TileMap")
	var mask: WorldTileLayer = world.get_node("Ground/Walkable_Mask")
	var atlas: TileSetAtlasSource = ground.tile_set.get_source(0)
	for sprite: Node in world.get_node("Scenery").get_children():
		if not str(sprite.name).begins_with("DungeonPillar"): continue
		var foot: Vector2i = Vector2i(Iso.unproject(sprite.position) / 32.0)
		for cell: Vector2i in [foot,foot-Vector2i(0,1)]:
			var tile := Vector2i(posmod(cell.x,8),1+posmod(cell.y,8))
			if not atlas.has_alternative_tile(tile,1):
				atlas.create_alternative_tile(tile,1)
				var data: TileData = atlas.get_tile_data(tile,1)
				data.set_custom_data("blocked",true); data.set_custom_data("visual_kind","stone")
				data.set_collision_polygons_count(0,1)
				data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,-16),Vector2(32,0),Vector2(0,16),Vector2(-32,0)]))
			walls.set_cell(cell,0,tile,1); mask.erase_cell(cell)
	world.set_meta("rainbow_pillar_feet_v1",true)
	pack(world,WORLD); world.free()
	print("RAINBOW_PILLAR_FEET 16 native blocked stone cells")
	quit()
