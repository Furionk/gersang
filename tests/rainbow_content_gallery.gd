extends Node2D
func _ready() -> void:
	get_window().size = Vector2i(1700,1200)
	get_window().content_scale_size = Vector2i(1700,1200)
	RenderingServer.set_default_clear_color(Color("111b25"))
	var settings: RainbowActionProfile = load("res://features/rainbow/data/default_action.tres")
	var font: Font = load("res://art/fonts/NotoSansCJKtc-Regular.otf")
	var heading := Label.new(); heading.position = Vector2(18,8)
	heading.text = "火龍神殿 · 原生圖集檢閱   |   每組：待機 / 左步 / 右步 / 出招   ·   正右 / 正左 / 背右 / 背左"
	heading.add_theme_font_override("font",font); heading.add_theme_font_size_override("font_size",20); add_child(heading)
	for row: int in settings.weapons.size():
		var weapon: RainbowWeaponDefinition = settings.weapons[row]
		var label := Label.new(); label.position = Vector2(18,64+row*100)
		label.text = str(weapon.unit_id) + "\n" + weapon.melee_name + " / " + weapon.ranged_name
		label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",14); label.modulate = weapon.tint; add_child(label)
		for direction: int in 4:
			for column: int in 4:
				var sprite := Sprite2D.new(); add_child(sprite)
				var output_direction: int = [1,3,7,5][direction]
				sprite.texture = SpriteAtlas.frame(weapon.layout.source_texture,weapon.layout,output_direction,column)
				sprite.position = Vector2(225+(direction*4+column)*85,120+row*100)
				sprite.offset.y = -(weapon.layout.foot_point.y - weapon.layout.frame_size.y*0.5)
				sprite.scale = Vector2.ONE*0.25
		var fx := Sprite2D.new(); add_child(fx); fx.texture = weapon.effect_texture
		fx.position = Vector2(1620,75+row*100); fx.scale = Vector2.ONE*0.20
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-content/roster-gallery.png")
	print("RAINBOW_GALLERY_CAPTURED 176 native atlas frames")
	get_tree().quit()
