extends SceneTree
## Render the actual native SpriteAtlas frames, not a replacement source bitmap.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var out: String="res://artifacts/kohime-art-2026-10-11/"
	DirAccess.make_dir_recursive_absolute(out)
	var data: UnitDefinition=load("res://features/units/data/mercenaries/kohime.tres")
	var texture: Texture2D=load(data.sprite_path)
	var layout: SpriteSheetLayout=data.sprite_layout
	if not layout.valid_for(texture.get_size()): quit(1); return
	var viewport: SubViewport=SubViewport.new()
	viewport.size=Vector2i(1200,1600)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background: ColorRect=ColorRect.new(); background.size=viewport.size; background.color=Color(0.07,0.09,0.11); viewport.add_child(background)
	var directions: Array[String]=["E","SE","S","SW","W","NW","N","NE"]
	var poses: Array[String]=["IDLE","WALK A","WALK B","ATTACK","CAST","DEAD"]
	for column: int in 6:
		var caption: Label=Label.new(); caption.text=poses[column]; caption.position=Vector2(column*200+40,10); viewport.add_child(caption)
	for row: int in 8:
		var caption: Label=Label.new(); caption.text=directions[row]; caption.position=Vector2(5,row*190+38); viewport.add_child(caption)
		for column: int in 6:
			var sprite: Sprite2D=Sprite2D.new()
			sprite.texture=SpriteAtlas.frame(texture,layout,row,column)
			sprite.flip_h=SpriteAtlas.mirrored(layout,row)
			sprite.scale=Vector2.ONE*0.72
			sprite.offset=Vector2(128,128)-layout.foot_point
			sprite.position=Vector2(column*200+100,row*190+183)
			viewport.add_child(sprite)
	for frame: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	var error: Error=viewport.get_texture().get_image().save_png(out+"native-48-frames.png")
	print("KOHIME_NATIVE_REVIEW 48 frames saved=",error," alpha=",texture.get_image().detect_alpha())
	quit(error)
