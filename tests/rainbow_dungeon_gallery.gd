extends Node2D
func _ready() -> void:
	get_window().size = Vector2i(1680,1000)
	get_window().content_scale_size = Vector2i(1680,1000)
	RenderingServer.set_default_clear_color(Color("151920"))
	var font: Font = load("res://art/fonts/NotoSansCJKtc-Regular.otf")
	var title := Label.new(); title.text = "火龍神殿 · 四種原創怪物 / 64 個原生姿勢 / 每方向：待機、左步、右步、攻擊"
	title.position = Vector2(24,20); title.add_theme_font_override("font",font); add_child(title)
	var settings: RainbowActionProfile = load("res://features/rainbow/data/default_action.tres")
	for row: int in settings.enemies.size():
		var enemy: RainbowEnemyDefinition = settings.enemies[row]
		var label := Label.new(); label.position = Vector2(24,80+row*220)
		label.text = str(enemy.unit_id) + ("  ·  BOSS" if enemy.boss else "")
		label.add_theme_font_override("font",font); label.modulate = enemy.weapon.tint; add_child(label)
		for facing: int in 4:
			for column: int in 4:
				var sprite := Sprite2D.new(); add_child(sprite)
				var layout: SpriteSheetLayout = enemy.weapon.layout
				sprite.texture = SpriteAtlas.frame(layout.source_texture,layout,[1,3,7,5][facing],column)
				sprite.position = Vector2(100+(facing*4+column)*100,245+row*220)
				sprite.offset.y = -(layout.foot_point.y-layout.frame_size.y*0.5)
				sprite.scale = Vector2.ONE * 0.29
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-dungeon/monster-gallery.png")
	for child: Node in get_children(): child.queue_free()
	await get_tree().process_frame
	var visual := Node2D.new(); add_child(visual); visual.y_sort_enabled = true
	var ground := GroundMap.new()
	ground.build_exploration(visual,WorldCatalog.definitions.rainbow_temple)
	var camera := Camera2D.new(); add_child(camera)
	camera.position = Iso.project(Vector2(2560,704)); camera.zoom = Vector2.ONE * 0.25
	for habitat: WorldHabitat in WorldCatalog.definitions.rainbow_temple.habitats:
		var monster: UnitDefinition = habitat.profile.templates[0].representative
		var sprite := Sprite2D.new(); visual.add_child(sprite)
		sprite.texture = SpriteAtlas.frame(monster.sprite_layout.source_texture,monster.sprite_layout,1,0)
		sprite.position = Iso.project(habitat.spawn_domain.bounds().get_center())
		sprite.scale = Vector2.ONE * monster.world_sprite_scale * 2.0
		sprite.offset.y = -(monster.sprite_layout.foot_point.y-monster.sprite_layout.frame_size.y*0.5)
		var label := Label.new(); visual.add_child(label); label.text = habitat.display_name
		label.position = sprite.position + Vector2(-180,50); label.scale = Vector2.ONE * 2
		label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",20)
	await get_tree().process_frame; await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-dungeon/dungeon-overview.png")
	print("RAINBOW_DUNGEON_GALLERY native 64 poses and authored map")
	get_tree().quit()
