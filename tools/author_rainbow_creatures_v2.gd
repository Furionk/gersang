extends SceneTree
## Explicit asset authoring only; does not mutate population or player records.
const IDS := ["temple_hellhound","temple_double_hound","temple_lava_troll","temple_lava_bat"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if ResourceLoader.exists("res://features/rainbow/data/skins/temple_hellhound.tres"):
		push_error("Already authored. Preserve subsequent artist edits."); quit(1); return
	var texture: Texture2D = load("res://features/rainbow/art/temple-creatures-v2.png")
	var image: Image = texture.get_image()
	for species: int in 4:
		var layout := SpriteSheetLayout.new()
		layout.source_texture = texture; layout.source_size = image.get_size()
		layout.columns = 1; layout.rows = 4
		layout.frame_size = Vector2i(360,360); layout.foot_point = Vector2(180,325)
		layout.direction_rows.assign([0,0,3,3,1,1,2,2])
		layout.attack_columns.assign([0])
		for facing: int in 4:
			var begin := Vector2i(facing * image.get_width()/4, species * image.get_height()/4)
			var end := Vector2i((facing+1)*image.get_width()/4,(species+1)*image.get_height()/4)
			var crop: Rect2i = image.get_region(Rect2i(begin,end-begin)).get_used_rect()
			layout.frame_rects.append(Rect2i(begin+crop.position,crop.size))
			layout.source_pivots.append(Vector2(crop.size.x*0.5,crop.size.y-2))
		for action: int in 5:
			var clip := SpriteAnimationClip.new()
			clip.action = action; clip.columns = PackedInt32Array([0])
			clip.loop = action < 2; layout.animations.append(clip)
		assert(layout.issues_for(image.get_size()).is_empty())
		var skin_path: String = "res://features/rainbow/data/skins/%s.tres" % IDS[species]
		assert(ResourceSaver.save(layout,skin_path) == OK)
		layout.take_over_path(skin_path)
		var unit: UnitDefinition = load("res://features/units/data/monsters/lava_beast.tres").duplicate()
		unit.id = IDS[species]
		unit.display_name = ["地獄犬","雙頭犬","熔岩巨魔","熔翼蝠"][species]
		unit.sprite_path = "res://features/rainbow/art/temple-creatures-v2.png"
		unit.sprite_layout = layout
		unit.battle_sprite_scale = [0.36,0.45,0.56,0.34][species]
		unit.world_sprite_scale = unit.battle_sprite_scale * 0.55
		unit.max_health = [960,1600,2800,700][species]
		unit.damage = [38,45,65,28][species]
		unit.speed = [140,115,75,135][species]
		unit.attack_range = 360 if species == 3 else 100
		unit.balance_revision = 1
		unit.tactical_hint = ["快速追擊；橫向閃避火牙預警。","雙向夾擊；不要讓兩個頭的攻勢交錯困住。","重鎚破陣；起手慢，繞後反擊。","遠距騷擾；利用障礙隔斷火羽。"][species]
		assert(ResourceSaver.save(unit,"res://features/units/data/monsters/%s.tres" % IDS[species]) == OK)
		var enemy: RainbowEnemyDefinition = load("res://features/rainbow/data/enemies/lava_beast.tres").duplicate(true)
		enemy.unit_id = unit.id; enemy.weapon.unit_id = unit.id
		enemy.weapon.layout = layout; enemy.weapon.sprite_scale = unit.battle_sprite_scale
		enemy.pattern = ["hound","pincer","troll","bat"][species]
		enemy.body_radius = 30 if species == 2 else 0
		enemy.special_interval = [4.5,5.0,7.0,4.0][species]
		enemy.special_power = [42,52,95,35][species]
		enemy.weapon.melee_windup = [0.4,0.55,1.1,0.5][species]
		enemy.weapon.projectile_speed = 300
		enemy.weapon.projectile_count = 1
		enemy.weapon.projectile_lifetime = 1.5
		assert(ResourceSaver.save(enemy,"res://features/rainbow/data/enemies/%s.tres" % IDS[species]) == OK)
	print("RAINBOW_CREATURES_AUTHORED four original directional skins; painted animation phases pending")
	quit()
