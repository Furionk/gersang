extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: PackedStringArray=OS.get_cmdline_user_args()
	var out: String = args[0] if args.size()>0 else "res://artifacts/lake-atlas-repair-2026-10-11/"
	DirAccess.make_dir_recursive_absolute(out)
	var ids: PackedStringArray=args.slice(1) if args.size()>1 else PackedStringArray(["millennium_wolf","millennium_worm"])
	for id: String in ids:
		var texture: Texture2D = load("res://features/units/art/"+id+"-v1.png")
		var layout: SpriteSheetLayout = load("res://features/units/data/layouts/"+id+"_layout.tres")
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(1200,1640); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var background: ColorRect = ColorRect.new(); background.size=viewport.size; background.color=Color(0.08,0.09,0.12); viewport.add_child(background)
		for row: int in 8:
			for column: int in 6:
				var foot: Vector2 = Vector2(column*200+100,row*200+192)
				var line: Line2D = Line2D.new(); line.points=PackedVector2Array([foot-Vector2(70,0),foot+Vector2(70,0)]); line.width=1; line.default_color=Color(0.4,0.45,0.5); viewport.add_child(line)
				var sprite: Sprite2D = Sprite2D.new(); sprite.texture=SpriteAtlas.frame(texture,layout,row,column); sprite.offset=Vector2(128,128)-layout.foot_point; sprite.scale=Vector2.ONE*0.8; sprite.position=foot; viewport.add_child(sprite)
				var label: Label = Label.new(); label.text="%d:%d"%[row,column]; label.position=Vector2(column*200+5,row*200+3); viewport.add_child(label)
		for frame: int in 3: await process_frame
		await RenderingServer.frame_post_draw
		assert(viewport.get_texture().get_image().save_png(out+id+"-48.png")==OK)
		viewport.queue_free(); await process_frame
	print("NATIVE_ATLAS_REVIEW ",ids.size()*48," native frames rendered")
	quit()
