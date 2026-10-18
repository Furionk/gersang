extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if ResourceLoader.exists("res://features/rainbow/data/skins/fire_dragon_tier_1.tres"):
		push_error("Dragon skins already authored; refusing overwrite."); quit(1); return
	var texture: Texture2D = load("res://features/rainbow/art/dragon-tiers-v2.png")
	var image: Image = texture.get_image()
	# The generated rows are not uniform. Author the observed row boundaries.
	var boundaries := [0.0,0.30,0.615,1.0]
	for tier: int in range(1,4):
		var id: String = "fire_dragon_tier_%d" % tier
		var layout := SpriteSheetLayout.new()
		layout.source_texture = texture; layout.source_size = image.get_size()
		layout.columns = 1; layout.rows = 4
		layout.frame_size = Vector2i(520,520); layout.foot_point = Vector2(260,480)
		layout.direction_rows.assign([0,0,3,3,1,1,2,2]); layout.attack_columns.assign([0])
		for facing: int in 4:
			var begin := Vector2i(facing*image.get_width()/4,int(boundaries[tier-1]*image.get_height()))
			var end := Vector2i((facing+1)*image.get_width()/4,int(boundaries[tier]*image.get_height()))
			var crop: Rect2i = image.get_region(Rect2i(begin,end-begin)).get_used_rect()
			layout.frame_rects.append(Rect2i(begin+crop.position,crop.size))
			layout.source_pivots.append(Vector2(crop.size.x*0.5,crop.size.y-2))
		for action: int in 5:
			var clip := SpriteAnimationClip.new(); clip.action = action
			clip.columns = PackedInt32Array([0]); clip.loop = action < 2
			layout.animations.append(clip)
		assert(layout.issues_for(image.get_size()).is_empty())
		var path: String = "res://features/rainbow/data/skins/%s.tres" % id
		assert(ResourceSaver.save(layout,path) == OK); layout.take_over_path(path)
		var unit: UnitDefinition = load("res://features/units/data/monsters/%s.tres" % id)
		unit.sprite_path = "res://features/rainbow/art/dragon-tiers-v2.png"
		unit.sprite_layout = layout; unit.battle_sprite_scale = 1.25; unit.world_sprite_scale = 0.6
		assert(ResourceSaver.save(unit,unit.resource_path) == OK)
		var enemy: RainbowEnemyDefinition = load("res://features/rainbow/data/enemies/%s.tres" % id)
		enemy.weapon.layout = layout; enemy.weapon.sprite_scale = 1.25
		assert(ResourceSaver.save(enemy,enemy.resource_path) == OK)
	print("DRAGON_SKINS_AUTHORED three silhouette variants, four directions each")
	quit()
