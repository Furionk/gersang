extends SceneTree
## One-shot atlas calibration; never run at boot or over an Artist layout.
func _initialize() -> void:
	var output: String="res://features/units/data/layouts/kohime_v2_layout.tres"
	if FileAccess.file_exists(output) and "--recalibrate-current-task" not in OS.get_cmdline_user_args():
		push_error("Kohime v2 layout already exists; preserve authored calibration")
		quit(1); return
	var texture: Texture2D=load("res://features/units/art/kohime-v2.png")
	var source: Image=texture.get_image()
	var layout: SpriteSheetLayout=SpriteSheetLayout.new()
	layout.source_size=source.get_size()
	layout.frame_size=Vector2i(256,256)
	layout.foot_point=Vector2(128,224)
	layout.direction_rows=[0,1,2,3,0,7,6,7]
	layout.mirrored_directions=[false,false,false,false,true,true,false,false]
	for row: int in 8:
		for column: int in 6:
			var begin: Vector2i=Vector2i(column*source.get_width()/6,row*source.get_height()/8)
			var end: Vector2i=Vector2i((column+1)*source.get_width()/6,(row+1)*source.get_height()/8)
			var local: Image=source.get_region(Rect2i(begin,end-begin))
			var used: Rect2i=significant_bounds(local)
			layout.frame_rects.append(Rect2i(begin+used.position,used.size))
			# Constant cell-center anchor avoids horizontal drift from an asymmetric cape/blade.
			layout.source_pivots.append(Vector2((end.x-begin.x)*0.5-used.position.x,used.size.y-2))
	var error: Error=ResourceSaver.save(layout,output)
	print("KOHIME_V2_LAYOUT ",layout.source_size," valid=",layout.valid_for(source.get_size())," save=",error)
	quit(error)

func significant_bounds(image: Image) -> Rect2i:
	var size: Vector2i=image.get_size()
	var seen: PackedByteArray=[]; seen.resize(size.x*size.y)
	var components: Array[Dictionary]=[]
	var largest: int=0
	for y: int in size.y:
		for x: int in size.x:
			var index: int=y*size.x+x
			if seen[index]!=0 or image.get_pixel(x,y).a<0.12: continue
			var pending: Array[Vector2i]=[Vector2i(x,y)]
			seen[index]=1
			var bounds: Rect2i=Rect2i(Vector2i(x,y),Vector2i.ONE)
			var area: int=0
			while not pending.is_empty():
				var at: Vector2i=pending.pop_back()
				area+=1; bounds=bounds.merge(Rect2i(at,Vector2i.ONE))
				for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i=at+direction
					if next.x<0 or next.y<0 or next.x>=size.x or next.y>=size.y: continue
					var next_index: int=next.y*size.x+next.x
					if seen[next_index]!=0: continue
					seen[next_index]=1
					if image.get_pixelv(next).a>=0.12: pending.append(next)
			components.append({"area":area,"bounds":bounds})
			largest=maxi(largest,area)
	var result: Rect2i
	for component: Dictionary in components:
		if component.area<maxi(64,int(largest*0.01)): continue
		result=component.bounds if result.size==Vector2i.ZERO else result.merge(component.bounds)
	# Keep a small transparent feather around the meaningful silhouette.
	return result.grow(2).intersection(Rect2i(Vector2i.ZERO,size))
