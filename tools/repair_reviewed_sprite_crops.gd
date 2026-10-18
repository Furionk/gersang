extends SceneTree
## Follow-up to actual GPU gallery findings; explicit reviewed sources only, no PNG edits.
const OUT: String="res://artifacts/sprite-motion-2026-10-13/"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var apply: bool="--apply-reviewed" in OS.get_cmdline_user_args()
	var rows: Array[Dictionary]=[]
	for id: String in ["teppo","earth_claw_v2","copper_monk_v2","ninja","kohime_v2","shaolin_guardian","millennium_lord"]:
		var path: String="res://features/units/data/layouts/"+id+"_layout.tres"
		var layout: SpriteSheetLayout=(load(path) as SpriteSheetLayout).duplicate(true)
		if layout.get_meta("silhouette_review_20261013",false): continue
		var image: Image=layout.source_texture.get_image()
		for row: int in 8:
			for column: int in 6:
				var start: Vector2i=Vector2i(maxi(0,column*181-28),maxi(0,row*181-16))
				var end: Vector2i=Vector2i(mini(image.get_width(),(column+1)*181+28),mini(image.get_height(),(row+1)*181+16))
				var used: Rect2i=AtlasSilhouetteBounds.meaningful(image.get_region(Rect2i(start,end-start)),true)
				var rect: Rect2i=Rect2i(start+used.position,used.size)
				var index: int=row*6+column
				var old: Rect2i=layout.frame_rects[index]
				# Anchor lower silhouette (feet/base), not a muzzle flash or raised weapon.
				var left: int=rect.end.x; var right: int=rect.position.x
				for y: int in range(maxi(rect.position.y,rect.end.y-14),rect.end.y):
					for x: int in range(rect.position.x,rect.end.x):
						if image.get_pixel(x,y).a>=0.3: left=mini(left,x); right=maxi(right,x)
				var foot_x: float=(left+right)*0.5 if right>=left else column*181+90.5
				layout.frame_rects[index]=rect
				layout.source_pivots[index]=Vector2(foot_x-rect.position.x,rect.size.y-2)
				rows.append({"layout":path,"index":index,"before":str(old),"after":str(rect)})
		assert(layout.valid_for(image.get_size()))
		layout.set_meta("silhouette_review_20261013",true)
		if apply:
			var uid: int=ResourceLoader.get_resource_uid(path)
			assert(ResourceSaver.save(layout,path)==OK)
			if uid!=-1: assert(ResourceSaver.set_uid(path,uid)==OK)
	var file: FileAccess=FileAccess.open(OUT+("crop-applied.json" if apply else "crop-plan.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"applied":apply,"frames":rows},"\t")); file.close()
	print("REVIEWED_CROPS frames=",rows.size()," applied=",apply)
	quit()
