extends SceneTree
## One-shot provenance for the new original atlas; never run at boot.
func _initialize() -> void:
	var path: String="res://features/units/data/layouts/earth_claw_v2_layout.tres"
	if FileAccess.file_exists(path):
		push_error("Already authored; do not overwrite layout")
		quit(1); return
	var source: Image=Image.load_from_file("res://features/units/art/earth-claw-v2.png")
	var layout: SpriteSheetLayout=SpriteSheetLayout.new()
	layout.source_size=source.get_size()
	layout.frame_size=Vector2i(256,256)
	layout.foot_point=Vector2(128,224)
	for row: int in 8:
		for column: int in 6:
			var begin: Vector2i=Vector2i(column*source.get_width()/6,row*source.get_height()/8)
			var end: Vector2i=Vector2i((column+1)*source.get_width()/6,(row+1)*source.get_height()/8)
			var used: Rect2i=source.get_region(Rect2i(begin,end-begin)).get_used_rect()
			layout.frame_rects.append(Rect2i(begin+used.position,used.size))
			layout.source_pivots.append(Vector2(used.size.x*0.5,used.size.y-2))
	var error: Error=ResourceSaver.save(layout,path)
	print("CLAW_LAYOUT ",error," ",layout.valid_for(source.get_size()))
	quit(error)
