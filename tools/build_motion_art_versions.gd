extends SceneTree
## One-shot native layouts for three approved generated sibling PNGs. No unit/stat writes.
const OUTPUT: String="res://artifacts/sprite-motion-2026-10-13/"
const SHEETS: Dictionary={
	"teppo_motion_v2":{"png":"teppo-motion-v2.png","old":"teppo_layout.tres","rows":[0,1,2,1,0,7,6,7],"flip":[false,false,false,true,true,true,false,false]},
	"copper_monk_motion_v3":{"png":"copper_monk-motion-v3.png","old":"copper_monk_v2_layout.tres","rows":[0,1,2,1,0,5,6,5],"flip":[false,false,false,true,true,false,false,true]},
	"millennium_bird_motion_v2":{"png":"millennium_bird-motion-v2.png","old":"millennium_bird_layout.tres","rows":[0,1,2,1,0,7,5,7],"flip":[false,false,false,true,true,true,false,false]},
	"millennium_bird_motion_v3":{"png":"millennium_bird-motion-v3.png","old":"millennium_bird_motion_v2_layout.tres","rows":[0,1,2,1,0,6,5,6],"flip":[false,false,false,true,true,true,false,false],"bands":[0,157,314,471,628,785,944,1110]}
}
func _initialize() -> void: call_deferred("run")
func make_clip(action: int,columns: Array,fps: float,loop: bool=false) -> SpriteAnimationClip:
	var result: SpriteAnimationClip=SpriteAnimationClip.new()
	result.action=action; result.columns=PackedInt32Array(columns); result.fps=fps; result.loop=loop
	if action==3: result.instant_start_frame=1
	return result
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var report: Array[Dictionary]=[]
	for id: String in SHEETS:
		if "--only-bird-v3" in OS.get_cmdline_user_args() and id!="millennium_bird_motion_v3": continue
		var rule: Dictionary=SHEETS[id]
		var path: String="res://features/units/data/layouts/"+id+"_layout.tres"
		if FileAccess.file_exists(path): push_error("Preserve existing version: "+path); quit(1); return
		var texture: Texture2D=load("res://features/units/art/"+str(rule.png))
		var image: Image=texture.get_image()
		assert(image.detect_alpha()!=Image.ALPHA_NONE,"Transparent source required")
		var layout: SpriteSheetLayout=SpriteSheetLayout.new()
		layout.source_texture=texture; layout.source_size=image.get_size(); layout.columns=8
		if rule.has("bands"): layout.rows=7
		layout.frame_size=Vector2i(256,256); layout.foot_point=Vector2(128,224)
		layout.direction_rows.assign(rule.rows); layout.mirrored_directions.assign(rule.flip)
		for row: int in layout.rows:
			for column: int in 8:
				var start: Vector2i=Vector2i(column*image.get_width()/8,row*image.get_height()/8)
				var end: Vector2i=Vector2i((column+1)*image.get_width()/8,(row+1)*image.get_height()/8)
				if rule.has("bands"): start.y=rule.bands[row]; end.y=rule.bands[row+1]
				var used: Rect2i=AtlasSilhouetteBounds.meaningful(image.get_region(Rect2i(start,end-start)),true)
				var rect: Rect2i=Rect2i(start+used.position,used.size)
				layout.frame_rects.append(rect)
				var left: int=rect.end.x; var right: int=rect.position.x
				for y: int in range(maxi(rect.position.y,rect.end.y-12),rect.end.y):
					for x: int in range(rect.position.x,rect.end.x):
						if image.get_pixel(x,y).a>=0.3: left=mini(left,x); right=maxi(right,x)
				var foot_x: float=(left+right)*0.5 if right>=left else (start.x+end.x)*0.5
				layout.source_pivots.append(Vector2(foot_x-rect.position.x,rect.size.y-2))
		layout.animations=[make_clip(0,[0],2,true),make_clip(1,[1,2,3,4],8,true),make_clip(2,[0,5,0],12),make_clip(3,[0,6,0],12),make_clip(4,[7],3)]
		if id=="millennium_bird_motion_v3":
			# The generated correction painted the clean N cast in row4. Native
			# arbitrary rectangles can select it without editing or inventing pixels.
			layout.frame_rects[5*8+6]=layout.frame_rects[4*8+6]
			layout.source_pivots[5*8+6]=layout.source_pivots[4*8+6]
		assert(layout.valid_for(image.get_size()))
		var previous: SpriteSheetLayout=load("res://features/units/data/layouts/"+str(rule.old))
		var old_height: float=0; var new_height: float=0
		for direction: int in 8:
			old_height+=previous.frame_rects[previous.row_for("idle",direction)*previous.columns].size.y
			new_height+=layout.frame_rects[layout.row_for("idle",direction)*layout.columns].size.y
		assert(ResourceSaver.save(layout,path)==OK)
		report.append({"layout":path,"old_layout":"res://features/units/data/layouts/"+str(rule.old),"source":texture.resource_path,"columns":8,"rows":layout.rows,"source_size":str(image.get_size()),"visual_scale_ratio":old_height/maxf(new_height,1),"walk_columns":[1,2,3,4],"four_painted_walk_phases":true})
	var file: FileAccess=FileAccess.open(OUTPUT+("new-bird-v3-layout.json" if "--only-bird-v3" in OS.get_cmdline_user_args() else "new-art-layouts.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MOTION_ART_LAYOUTS created=",report.size())
	quit()
