extends Node2D
const OUT:String="res://artifacts/tests/hogwarts/gallery/"
const IDS:Array[String]=["school_dementor","school_dark_elf","school_gatekeeper","school_basilisk","school_cerberus","voldemort_illusion","ganondorf_phantom"]
var unit:UnitDefinition
func _ready()->void:call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(OUT)
	for id:String in IDS:
		unit=load("res://features/units/data/monsters/"+id+".tres");queue_redraw()
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT+id+".png")
	print("HOGWARTS_GALLERY_RENDERED 7 sheets48 poses native AtlasTexture");get_tree().quit()
func _draw()->void:
	if unit==null:return
	draw_rect(Rect2(0,0,1280,720),Color("202825"))
	var font:Font=ThemeDB.fallback_font
	draw_string(font,Vector2(12,25),str(unit.id)+" / actual native crops, feet in green / original PNG preserved",HORIZONTAL_ALIGNMENT_LEFT,-1,18)
	for row:int in 8:
		draw_string(font,Vector2(8,88+row*78),["E","SE","S","SW","W","NW","N","NE"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		for col:int in 6:
			var origin:Vector2=Vector2(160+col*195,121+row*78)
			var atlas:AtlasTexture=SpriteAtlas.frame(SpriteAtlas.texture_for(unit),unit.sprite_layout,row,col)
			draw_set_transform(origin,0,Vector2.ONE*0.4);draw_texture(atlas,-unit.sprite_layout.foot_point);draw_set_transform(Vector2.ZERO)
			draw_line(origin-Vector2(7,0),origin+Vector2(7,0),Color.GREEN)
			if row==0:draw_string(font,Vector2(origin.x-55,48),["idle","walk A","walk B","attack","cast","death"][col],HORIZONTAL_ALIGNMENT_LEFT,-1,16)
