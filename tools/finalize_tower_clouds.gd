extends SceneTree
## One-shot presentation refinement; never regenerates the tower or its masks.
func _initialize()->void:call_deferred("run")
func run()->void:
	var material:ShaderMaterial=load("res://art/terrain/shenchao_tower/cloud-sea-material.tres")
	var tiles:TileSet=load("res://art/terrain/shenchao_tower/cloud-sea-v1.tres")
	var source:TileSetAtlasSource=tiles.get_source(0)
	var path:String="res://features/battle/maps/shenchao_tower.tscn"
	var arena:BattlefieldMap=load(path).instantiate()
	if source.get_tile_data(Vector2i.ZERO,0).material!=null or arena.get_node("CloudSeaBackdrop").material!=null:
		push_error("Cloud presentation already authored; refusing to overwrite.")
		arena.free();quit(1);return
	source.get_tile_data(Vector2i.ZERO,0).material=material
	assert(ResourceSaver.save(tiles)==OK)
	arena.get_node("CloudSeaBackdrop").material=material
	var packed:PackedScene=PackedScene.new()
	assert(packed.pack(arena)==OK)
	assert(ResourceSaver.save(packed,path)==OK)
	arena.free()
	print("TOWER_CLOUD_CONTINUITY_OK")
	quit()
