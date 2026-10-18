extends SceneTree
func _initialize() -> void:
	for mode: int in 6:
		var tiles: TileSet = TileSet.new()
		tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
		tiles.tile_size = Vector2i(64,32)
		tiles.tile_layout = mode as TileSet.TileLayout
		var layer: TileMapLayer = TileMapLayer.new()
		layer.tile_set = tiles
		print("LAYOUT ",mode," ",layer.map_to_local(Vector2i.ZERO)," ",layer.map_to_local(Vector2i(1,0))," ",layer.map_to_local(Vector2i(0,1)))
		layer.free()
	quit()
