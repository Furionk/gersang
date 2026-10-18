extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var texture: Texture2D = load("res://features/rainbow/art/dragon-tiers-v3.png")
	var image: Image = texture.get_image()
	for tier: int in range(1,4):
		var id: String = "fire_dragon_tier_%d" % tier
		var layout: SpriteSheetLayout = load("res://features/rainbow/data/skins/%s.tres" % id)
		if layout.source_texture == texture: push_error("Already repaired."); quit(1); return
		layout.source_texture = texture; layout.source_size = image.get_size()
		layout.frame_rects.clear(); layout.source_pivots.clear()
		for direction: int in 4:
			var start := Vector2i(direction*image.get_width()/4,(tier-1)*image.get_height()/3)
			var end := Vector2i((direction+1)*image.get_width()/4,tier*image.get_height()/3)
			var crop: Rect2i = image.get_region(Rect2i(start,end-start)).get_used_rect()
			layout.frame_rects.append(Rect2i(start+crop.position,crop.size))
			layout.source_pivots.append(Vector2(crop.size.x*0.5,crop.size.y-2))
		assert(layout.valid_for(image.get_size()))
		assert(ResourceSaver.save(layout,layout.resource_path) == OK)
		var unit: UnitDefinition = load("res://features/units/data/monsters/%s.tres" % id)
		unit.sprite_path = "res://features/rainbow/art/dragon-tiers-v3.png"; unit.battle_sprite_scale = 1.7; unit.world_sprite_scale = 0.8
		assert(ResourceSaver.save(unit,unit.resource_path) == OK)
		var enemy: RainbowEnemyDefinition = load("res://features/rainbow/data/enemies/%s.tres" % id)
		enemy.weapon.sprite_scale = 1.7
		assert(ResourceSaver.save(enemy,enemy.resource_path) == OK)
	print("DRAGON_GUTTERS_VERIFIED four separated complete silhouettes per tier")
	quit()
