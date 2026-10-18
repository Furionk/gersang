extends SceneTree
const Bounds: Script=preload("res://features/presentation/atlas_silhouette_bounds.gd")
func _initialize() -> void:
	for id: String in ["millennium_worm","millennium_bird","millennium_wolf","millennium_lord"]:
		var path: String="res://features/units/data/layouts/"+id+"_layout.tres"
		if FileAccess.file_exists(path) and "--calibrate-current-task" not in OS.get_cmdline_user_args(): continue
		var texture: Texture2D=load("res://features/units/art/"+id+"-v1.png")
		var image: Image=texture.get_image()
		var layout: SpriteSheetLayout=SpriteSheetLayout.new()
		layout.source_size=image.get_size(); layout.frame_size=Vector2i(256,256); layout.foot_point=Vector2(128,224)
		for row: int in 8:
			for column: int in 6:
				var begin: Vector2i=Vector2i(column*image.get_width()/6,row*image.get_height()/8)
				var end: Vector2i=Vector2i((column+1)*image.get_width()/6,(row+1)*image.get_height()/8)
				var used: Rect2i=Bounds.meaningful(image.get_region(Rect2i(begin,end-begin)))
				layout.frame_rects.append(Rect2i(begin+used.position,used.size))
				layout.source_pivots.append(Vector2((end.x-begin.x)*0.5-used.position.x,used.size.y-2))
		assert(layout.valid_for(image.get_size()))
		assert(ResourceSaver.save(layout,path)==OK)
		print("LAKE_CREATURE_LAYOUT ",id," ",layout.source_size)
	quit()
