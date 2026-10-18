extends "res://tools/expand_rainbow_dungeon.gd"
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_branch_landmarks_v1"): quit(1); return
	var art: Texture2D = load("res://features/rainbow/art/branch-landmarks-v1.png")
	var regions: Array[Rect2] = [Rect2(0,0,768,462),Rect2(768,0,768,462),Rect2(0,462,768,562),Rect2(768,462,768,562)]
	var walls: WorldTileLayer = world.get_node("Ground/Obstacles_TileMap")
	var mask: WorldTileLayer = world.get_node("Ground/Walkable_Mask")
	for zone: int in 9:
		var row: int = zone/3; var col: int = zone%3
		var index: int = [0,0,2,1,0,2,1,3,3][zone]
		var tile := Vector2i(24+col*56,63+row*52)
		var sprite := Sprite2D.new(); sprite.name = "BranchLandmark%d" % zone
		var atlas := AtlasTexture.new(); atlas.atlas = art; atlas.region = regions[index]
		sprite.texture = atlas; sprite.scale = Vector2.ONE*0.4
		sprite.position = Iso.project((Vector2(tile)+Vector2.ONE*0.5)*32)
		sprite.offset.y = -regions[index].size.y*0.42
		sprite.set_meta("world_scenery_id","rainbow_branch_landmark_%d" % zone)
		sprite.set_meta("world_scenery_name",["雙首獸門","黑曜熔爐","四印祭壇","八燼祭殿"][index])
		sprite.set_meta("scenery_sort_override",1)
		world.get_node("Scenery").add_child(sprite)
		# Solid foot, away from patrol spawn rectangles and the central through-route.
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				var cell := tile+Vector2i(dx,dy)
				walls.set_cell(cell,0,Vector2i(2,0)); mask.erase_cell(cell)
	world.set_meta("rainbow_branch_landmarks_v1",true)
	pack(world,WORLD); world.free()
	print("RAINBOW_BRANCH_LANDMARKS nine original-art landmarks with native footprints")
	quit()
