extends "res://tools/expand_rainbow_dungeon.gd"
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_branch_landmarks_anchored"): quit(1); return
	for zone: int in 9:
		var sprite: Sprite2D = world.get_node("Scenery/BranchLandmark%d" % zone)
		var atlas: AtlasTexture = sprite.texture
		sprite.position += Iso.project(Vector2.ONE*16)
		sprite.offset.y = -atlas.region.size.y*0.42
	world.set_meta("rainbow_branch_landmarks_anchored",true)
	pack(world,WORLD); world.free(); quit()
