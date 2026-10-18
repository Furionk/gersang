extends Node2D
var definition: UnitDefinition
var source: Texture2D
var names: Array[String] = ["beast", "elite", "merchant"]
func _ready() -> void:
	get_tree().create_timer(20).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("capture_all")
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("202322"))
	if definition==null: return
	var font: Font = ThemeDB.fallback_font
	draw_string(font,Vector2(28,26),"%s — native per-frame atlas, fixed feet (all 8 directions / 6 poses)" % definition.id,HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color.WHITE)
	var poses: Array[String] = ["Idle","Walk A","Walk B","Attack","Cast","Death"]
	for column: int in 6:
		draw_string(font,Vector2(100+column*190,54),poses[column],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d3c195"))
	for row: int in 8:
		for column: int in 6:
			var base: Vector2 = Vector2(90+column*190,65+row*78)
			draw_rect(Rect2(base,Vector2(182,76)),Color("333b37"),false)
			var foot: Vector2 = base+Vector2(91,71)
			draw_line(foot-Vector2(9,0),foot+Vector2(9,0),Color("67cc88"))
			draw_line(foot-Vector2(0,3),foot+Vector2(0,3),Color("67cc88"))
			var frame: AtlasTexture = SpriteAtlas.frame(source,definition.sprite_layout,row,column)
			var scale_value: float = 0.4
			draw_set_transform(foot,0,Vector2(-1 if SpriteAtlas.mirrored(definition.sprite_layout,row) else 1,1))
			draw_texture_rect(frame,Rect2(-definition.sprite_layout.foot_point*scale_value,Vector2(definition.sprite_layout.frame_size)*scale_value),false)
			draw_set_transform(Vector2.ZERO)
		draw_string(font,Vector2(20,106+row*78),str(row),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
func capture_all() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This is a real rendering capture, not a headless test")
		get_tree().quit(1)
		return
	for name_text: String in names:
		definition = load(UnitResourcePaths.canonical("res://features/units/data/%s.tres" % name_text))
		source = load(definition.sprite_path)
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error: Error = get_viewport().get_texture().get_image().save_png("res://artifacts/world/%s-layout-render.png" % name_text)
		if error!=OK:
			get_tree().quit(1)
			return
		print("PASS | rendered layout gallery ",name_text)
	get_tree().quit(0)
